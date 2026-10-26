; sollang workers = 1
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"
declare ptr @GetStdHandle(i32)
declare i32 @GetConsoleMode(ptr, ptr)
declare i32 @WriteConsoleW(ptr, ptr, i32, ptr, ptr)
declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare i32 @MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)
declare ptr @GetProcessHeap()
declare ptr @HeapAlloc(ptr, i32, i64)
declare i32 @HeapFree(ptr, i32, ptr)
define internal i32 @sollang_write_stream_chunk(ptr %handle, ptr %data, i32 %len, ptr %written, i1 %is_console) {
entry:
  %empty = icmp eq i32 %len, 0
  br i1 %empty, label %success_empty, label %classify

success_empty:
  store i32 0, ptr %written, align 4
  ret i32 1

classify:
  br i1 %is_console, label %console_prepare, label %redirected

redirected:
  br label %redirected_write

redirected_write:
  %redirected_offset = phi i32 [ 0, %redirected ], [ %redirected_next, %redirected_advance ]
  %redirected_remaining = sub i32 %len, %redirected_offset
  %redirected_offset64 = zext i32 %redirected_offset to i64
  %redirected_data = getelementptr i8, ptr %data, i64 %redirected_offset64
  store i32 0, ptr %written, align 4
  %redirected_ok = call i32 @WriteFile(ptr %handle, ptr %redirected_data, i32 %redirected_remaining, ptr %written, ptr null)
  %redirected_count = load i32, ptr %written, align 4
  %redirected_succeeded = icmp ne i32 %redirected_ok, 0
  %redirected_progress = icmp ugt i32 %redirected_count, 0
  %redirected_bounded = icmp ule i32 %redirected_count, %redirected_remaining
  %redirected_valid0 = and i1 %redirected_succeeded, %redirected_progress
  %redirected_valid = and i1 %redirected_valid0, %redirected_bounded
  br i1 %redirected_valid, label %redirected_advance, label %write_failed

redirected_advance:
  %redirected_next = add i32 %redirected_offset, %redirected_count
  %redirected_complete = icmp eq i32 %redirected_next, %len
  br i1 %redirected_complete, label %write_succeeded, label %redirected_write

console_prepare:
  %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %len, ptr null, i32 0)
  %valid_utf8 = icmp sgt i32 %wide_chars, 0
  br i1 %valid_utf8, label %allocate, label %conversion_failed

allocate:
  %wide_bytes32 = shl i32 %wide_chars, 1
  %wide_bytes = zext i32 %wide_bytes32 to i64
  %heap = call ptr @GetProcessHeap()
  %wide = call ptr @HeapAlloc(ptr %heap, i32 0, i64 %wide_bytes)
  %wide_written = alloca i32, align 4
  %allocated = icmp ne ptr %wide, null
  br i1 %allocated, label %convert, label %conversion_failed

convert:
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %len, ptr %wide, i32 %wide_chars)
  %converted_all = icmp eq i32 %converted, %wide_chars
  br i1 %converted_all, label %console_write, label %conversion_free

console_write:
  %console_offset = phi i32 [ 0, %convert ], [ %console_next, %console_advance ]
  %console_remaining = sub i32 %wide_chars, %console_offset
  %console_offset64 = zext i32 %console_offset to i64
  %console_data = getelementptr i16, ptr %wide, i64 %console_offset64
  store i32 0, ptr %wide_written, align 4
  %console_ok = call i32 @WriteConsoleW(ptr %handle, ptr %console_data, i32 %console_remaining, ptr %wide_written, ptr null)
  %console_count = load i32, ptr %wide_written, align 4
  %console_succeeded = icmp ne i32 %console_ok, 0
  %console_progress = icmp ugt i32 %console_count, 0
  %console_bounded = icmp ule i32 %console_count, %console_remaining
  %console_valid0 = and i1 %console_succeeded, %console_progress
  %console_valid = and i1 %console_valid0, %console_bounded
  br i1 %console_valid, label %console_advance, label %console_write_failed

console_advance:
  %console_next = add i32 %console_offset, %console_count
  %console_complete = icmp eq i32 %console_next, %wide_chars
  br i1 %console_complete, label %console_write_succeeded, label %console_write

console_write_succeeded:
  %freed = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %write_succeeded

console_write_failed:
  %freed_after_write_failure = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %write_failed

write_succeeded:
  store i32 %len, ptr %written, align 4
  ret i32 1

write_failed:
  store i32 0, ptr %written, align 4
  ret i32 0

conversion_free:
  %freed_after_failure = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %conversion_failed

conversion_failed:
  store i32 0, ptr %written, align 4
  ret i32 0
}

define internal i32 @sollang_write_stream(ptr %handle, ptr %data, i64 %len64, ptr %written, i1 %is_console) {
entry:
  %empty = icmp eq i64 %len64, 0
  br i1 %empty, label %success_empty, label %prepare

success_empty:
  store i32 0, ptr %written, align 4
  ret i32 1

prepare:
  %offset = phi i64 [ 0, %entry ], [ %next, %advance ]
  %remaining = sub i64 %len64, %offset
  %current = getelementptr i8, ptr %data, i64 %offset
  %more = icmp ugt i64 %remaining, 1048576
  %proposed = select i1 %more, i64 1048576, i64 %remaining
  %split_console = and i1 %more, %is_console
  br i1 %split_console, label %trim_boundary, label %write

trim_boundary:
  %boundary = phi i64 [ 1048576, %prepare ], [ %previous, %trim_next ]
  %boundary_ptr = getelementptr i8, ptr %current, i64 %boundary
  %boundary_byte = load i8, ptr %boundary_ptr, align 1
  %prefix = and i8 %boundary_byte, -64
  %continuation = icmp eq i8 %prefix, -128
  br i1 %continuation, label %trim_next, label %write

trim_next:
  %can_trim = icmp ugt i64 %boundary, 1048573
  %previous = sub i64 %boundary, 1
  br i1 %can_trim, label %trim_boundary, label %failure

write:
  %chunk64 = phi i64 [ %proposed, %prepare ], [ %boundary, %trim_boundary ]
  %chunk32 = trunc i64 %chunk64 to i32
  %ok = call i32 @sollang_write_stream_chunk(ptr %handle, ptr %current, i32 %chunk32, ptr %written, i1 %is_console)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %advance, label %failure

advance:
  %next = add i64 %offset, %chunk64
  %complete = icmp eq i64 %next, %len64
  br i1 %complete, label %success, label %prepare

success:
  ret i32 1

failure:
  store i32 0, ptr %written, align 4
  ret i32 0
}

define internal i32 @sollang_runtime_write_stdout_all(ptr %handle, ptr %data, i64 %len) {
entry:
  %written = alloca i32, align 4
  %mode = alloca i32, align 4
  %empty = icmp eq i64 %len, 0
  br i1 %empty, label %success, label %classify
classify:
  %console_status = call i32 @GetConsoleMode(ptr %handle, ptr %mode)
  %is_console = icmp ne i32 %console_status, 0
  %ok = call i32 @sollang_write_stream(ptr %handle, ptr %data, i64 %len, ptr %written, i1 %is_console)
  ret i32 %ok
success:
  ret i32 1
}
define internal i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr %data, i32 %len) {
entry:
  %length = zext i32 %len to i64
  %ok = call i32 @sollang_runtime_write_stdout_all(ptr %handle, ptr %data, i64 %length)
  ret i32 %ok
}
@sollang_runtime_newline = private constant [1 x i8] c"\0A"
@sollang_runtime_stdout_buffer = private global [1048576 x i8] zeroinitializer
@sollang_runtime_stdout_count = private global i64 0
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1 immarg)
define internal void @sollang_runtime_flush_stdout() {
entry:
  %count = load i64, ptr @sollang_runtime_stdout_count, align 8
  %has_data = icmp ugt i64 %count, 0
  br i1 %has_data, label %write, label %done
write:
  %handle = call ptr @GetStdHandle(i32 -11)
  %count32 = trunc i64 %count to i32
  %ok = call i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr @sollang_runtime_stdout_buffer, i32 %count32)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %clear, label %failure
clear:
  store i64 0, ptr @sollang_runtime_stdout_count, align 8
  br label %done
failure:
  call void @llvm.trap()
  unreachable
done:
  ret void
}
define internal void @sollang_runtime_append_stdout(ptr %data, i64 %len) {
entry:
  %count = load i64, ptr @sollang_runtime_stdout_count, align 8
  %total = add i64 %count, %len
  %available = sub i64 1048576, %count
  %fits = icmp ule i64 %len, %available
  br i1 %fits, label %append, label %flush
flush:
  call void @sollang_runtime_flush_stdout()
  %large = icmp ugt i64 %len, 1048576
  br i1 %large, label %direct, label %append_empty
direct:
  %handle = call ptr @GetStdHandle(i32 -11)
  %ok = call i32 @sollang_runtime_write_stdout_all(ptr %handle, ptr %data, i64 %len)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %direct_done, label %direct_failure
direct_done:
  ret void
direct_failure:
  call void @llvm.trap()
  unreachable
append_empty:
  call void @llvm.memcpy.p0.p0.i64(ptr @sollang_runtime_stdout_buffer, ptr %data, i64 %len, i1 false)
  store i64 %len, ptr @sollang_runtime_stdout_count, align 8
  ret void
append:
  %slot = getelementptr i8, ptr @sollang_runtime_stdout_buffer, i64 %count
  call void @llvm.memcpy.p0.p0.i64(ptr %slot, ptr %data, i64 %len, i1 false)
  store i64 %total, ptr @sollang_runtime_stdout_count, align 8
  ret void
}
define internal void @sollang_runtime_print(ptr %data, i64 %len, i1 %newline) {
entry:
  call void @sollang_runtime_append_stdout(ptr %data, i64 %len)
  br i1 %newline, label %write_newline, label %done
write_newline:
  call void @sollang_runtime_append_stdout(ptr @sollang_runtime_newline, i64 1)
  br label %done
done:
  ret void
}
@sollang_runtime_error_newline = private constant [2 x i8] c"\0D\0A"
define internal void @sollang_runtime_eprint(ptr %data, i64 %len, i1 %newline) {
entry:
  %handle = call ptr @GetStdHandle(i32 -12)
  %ok = call i32 @sollang_runtime_write_stdout_all(ptr %handle, ptr %data, i64 %len)
  br i1 %newline, label %write_newline, label %done
write_newline:
  %newline_ok = call i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr @sollang_runtime_error_newline, i32 2)
  br label %done
done:
  ret void
}
define internal void @sollang_runtime_eprintln(ptr %data, i64 %len) {
entry:
  call void @sollang_runtime_eprint(ptr %data, i64 %len, i1 true)
  ret void
}
define internal i64 @sollang_format_u64(ptr %dest, i64 %value) {
entry:
  br label %count
count:
  %count_n = phi i64 [ %value, %entry ], [ %count_q, %count_more ]
  %length = phi i64 [ 1, %entry ], [ %next_length, %count_more ]
  %count_q = udiv i64 %count_n, 10
  %count_done = icmp eq i64 %count_q, 0
  br i1 %count_done, label %write_entry, label %count_more
count_more:
  %next_length = add i64 %length, 1
  br label %count
write_entry:
  %last_index = sub i64 %length, 1
  br label %write
write:
  %write_n = phi i64 [ %value, %write_entry ], [ %write_q, %write ]
  %index = phi i64 [ %last_index, %write_entry ], [ %previous_index, %write ]
  %digit = urem i64 %write_n, 10
  %write_q = udiv i64 %write_n, 10
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  %slot = getelementptr i8, ptr %dest, i64 %index
  store i8 %ascii, ptr %slot, align 1
  %previous_index = sub i64 %index, 1
  %write_done = icmp eq i64 %write_q, 0
  br i1 %write_done, label %return, label %write
return:
  ret i64 %length
}
define internal i64 @sollang_format_i64(ptr %dest, i64 %value) {
entry:
  %negative = icmp slt i64 %value, 0
  br i1 %negative, label %negative_value, label %positive_value
negative_value:
  store i8 45, ptr %dest, align 1
  %digits_dest = getelementptr i8, ptr %dest, i64 1
  %magnitude = sub i64 0, %value
  %negative_digits = call i64 @sollang_format_u64(ptr %digits_dest, i64 %magnitude)
  %negative_length = add i64 %negative_digits, 1
  ret i64 %negative_length
positive_value:
  %positive_length = call i64 @sollang_format_u64(ptr %dest, i64 %value)
  ret i64 %positive_length
}
define internal void @sollang_runtime_print_i32(i32 %value, i1 %newline) {
entry:
  %buffer = alloca [12 x i8], align 1
  %end = getelementptr [12 x i8], ptr %buffer, i64 0, i64 12
  %wide = sext i32 %value to i64
  %negative = icmp slt i64 %wide, 0
  %negated = sub i64 0, %wide
  %magnitude = select i1 %negative, i64 %negated, i64 %wide
  br label %digits
digits:
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done
digits_done:
  br i1 %negative, label %write_sign, label %emit
write_sign:
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit
emit:
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_print(ptr %start, i64 %length, i1 %newline)
  ret void
}
define internal void @sollang_runtime_print_i64(i64 %value, i1 %signed, i1 %newline) {
entry:
  %buffer = alloca [21 x i8], align 1
  %end = getelementptr [21 x i8], ptr %buffer, i64 0, i64 21
  %negative_value = icmp slt i64 %value, 0
  %negative = and i1 %signed, %negative_value
  %negated = sub i64 0, %value
  %magnitude = select i1 %negative, i64 %negated, i64 %value
  br label %digits
digits:
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done
digits_done:
  br i1 %negative, label %write_sign, label %emit
write_sign:
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit
emit:
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_print(ptr %start, i64 %length, i1 %newline)
  ret void
}
@sollang_runtime_bool_true = private constant [4 x i8] c"true"
@sollang_runtime_bool_false = private constant [5 x i8] c"false"
define internal void @sollang_runtime_print_i1(i1 %value, i1 %newline) {
entry:
  %data = select i1 %value, ptr @sollang_runtime_bool_true, ptr @sollang_runtime_bool_false
  %length = select i1 %value, i64 4, i64 5
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 %newline)
  ret void
}
define internal void @sollang_runtime_eprint_i32(i32 %value, i1 %newline) {
entry:
  %buffer = alloca [12 x i8], align 1
  %end = getelementptr [12 x i8], ptr %buffer, i64 0, i64 12
  %wide = sext i32 %value to i64
  %negative = icmp slt i64 %wide, 0
  %negated = sub i64 0, %wide
  %magnitude = select i1 %negative, i64 %negated, i64 %wide
  br label %digits
digits:
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done
digits_done:
  br i1 %negative, label %write_sign, label %emit
write_sign:
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit
emit:
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_eprint(ptr %start, i64 %length, i1 %newline)
  ret void
}
define internal void @sollang_runtime_eprint_i64(i64 %value, i1 %signed, i1 %newline) {
entry:
  %buffer = alloca [21 x i8], align 1
  %end = getelementptr [21 x i8], ptr %buffer, i64 0, i64 21
  %negative_value = icmp slt i64 %value, 0
  %negative = and i1 %signed, %negative_value
  %negated = sub i64 0, %value
  %magnitude = select i1 %negative, i64 %negated, i64 %value
  br label %digits
digits:
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done
digits_done:
  br i1 %negative, label %write_sign, label %emit
write_sign:
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit
emit:
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_eprint(ptr %start, i64 %length, i1 %newline)
  ret void
}
define internal void @sollang_runtime_eprint_i1(i1 %value, i1 %newline) {
entry:
  %data = select i1 %value, ptr @sollang_runtime_bool_true, ptr @sollang_runtime_bool_false
  %length = select i1 %value, i64 4, i64 5
  call void @sollang_runtime_eprint(ptr %data, i64 %length, i1 %newline)
  ret void
}
declare dllimport ptr @CreateFileA(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport i32 @DeleteFileW(ptr)
declare dllimport i32 @WaitForSingleObject(ptr, i32)
declare dllimport i32 @CloseHandle(ptr)
declare dllimport i32 @CreateDirectoryW(ptr, ptr)
declare dllimport i32 @GetFileAttributesW(ptr)
declare dllimport ptr @FindFirstFileW(ptr, ptr)
declare dllimport i32 @FindNextFileW(ptr, ptr)
declare dllimport i32 @FindClose(ptr)
declare dllimport void @SetLastError(i32)
declare dllimport i32 @GetLastError()
declare dllimport i32 @GetFinalPathNameByHandleW(ptr, ptr, i32, i32)
declare dllimport i32 @GetFullPathNameW(ptr, i32, ptr, ptr)
declare dllimport i32 @GetFileInformationByHandle(ptr, ptr)
declare dllimport i32 @WideCharToMultiByte(i32, i32, ptr, i32, ptr, i32, ptr, ptr)
declare dllimport ptr @GetCommandLineW()
declare dllimport ptr @CommandLineToArgvW(ptr, ptr)
declare dllimport ptr @LocalFree(ptr)
declare dllimport ptr @GetCurrentProcess()
declare dllimport i32 @DuplicateHandle(ptr, ptr, ptr, ptr, i32, i32, i32)
declare dllimport i32 @CreateProcessW(ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr)
declare dllimport ptr @GetEnvironmentStringsW()
declare dllimport i32 @FreeEnvironmentStringsW(ptr)
declare dllimport i32 @CompareStringOrdinal(ptr, i32, ptr, i32, i32)
declare dllimport i32 @GetProcessId(ptr)
declare dllimport i32 @GetExitCodeProcess(ptr, ptr)
declare dllimport i32 @TerminateProcess(ptr, i32)
%sollang.process_result = type { i32, i32 }
%sollang.process_poll_result = type { i32, i32 }
%sollang.process_spawn_result = type { i64, i64, i32 }
%sollang.process_capture_result = type { i32, ptr, i64, i64, i1, ptr, i64, i64, i1, i32 }
%sollang.process_environment_result = type { ptr, i64, i64, i1 }
@sollang_process_error_spawn = private constant [5 x i8] c"spawn"
@sollang_process_error_wait = private constant [4 x i8] c"wait"
@sollang_process_error_signal = private constant [6 x i8] c"signal"
@sollang_process_error_capture = private constant [7 x i8] c"capture"
@sollang_bool_true_bytes = private constant [4 x i8] c"true"
@sollang_bool_false_bytes = private constant [5 x i8] c"false"
@sollang_diagnostic_next_session_id = internal global i64 1
define internal { ptr, i32 } @sollang_diagnostic_start(i32 %capacity) {
entry:
  %minimum_ok = icmp sge i32 %capacity, 1
  %maximum_ok = icmp sle i32 %capacity, 65535
  %valid = and i1 %minimum_ok, %maximum_ok
  br i1 %valid, label %check_id, label %invalid
invalid:
  ret { ptr, i32 } { ptr null, i32 0 }
check_id:
  %id = load i64, ptr @sollang_diagnostic_next_session_id, align 8
  %available = icmp ne i64 %id, -1
  br i1 %available, label %allocate, label %exhausted
exhausted:
  ret { ptr, i32 } { ptr null, i32 1 }
allocate:
  %wide_capacity = sext i32 %capacity to i64
  %records_bytes = mul i64 %wide_capacity, 112
  %bytes = add i64 %records_bytes, 48
  %session = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %session, null
  br i1 %allocated, label %initialize, label %allocation_failed
allocation_failed:
  ret { ptr, i32 } { ptr null, i32 2 }
initialize:
  %next_id = add i64 %id, 1
  store i64 %next_id, ptr @sollang_diagnostic_next_session_id, align 8
  store i64 %id, ptr %session, align 8
  %capacity_slot = getelementptr i8, ptr %session, i64 8
  store i64 %wide_capacity, ptr %capacity_slot, align 8
  %count_slot = getelementptr i8, ptr %session, i64 16
  store i64 0, ptr %count_slot, align 8
  %untracked_slot = getelementptr i8, ptr %session, i64 24
  store i64 0, ptr %untracked_slot, align 8
  %records_slot = getelementptr i8, ptr %session, i64 32
  %records = getelementptr i8, ptr %session, i64 48
  store ptr %records, ptr %records_slot, align 8
  %untracked_head_slot = getelementptr i8, ptr %session, i64 40
  store ptr null, ptr %untracked_head_slot, align 8
  %success0 = insertvalue { ptr, i32 } poison, ptr %session, 0
  %success = insertvalue { ptr, i32 } %success0, i32 -1, 1
  ret { ptr, i32 } %success
}
define internal i32 @sollang_diagnostic_observed_status(ptr %record) {
entry:
  %terminal_slot = getelementptr i8, ptr %record, i64 24
  %terminal = load i32, ptr %terminal_slot, align 4
  %frozen = icmp sge i32 %terminal, 0
  br i1 %frozen, label %frozen_status, label %live
frozen_status:
  ret i32 %terminal
live:
  %control_slot = getelementptr i8, ptr %record, i64 16
  %control = load ptr, ptr %control_slot, align 8
  %has_control = icmp ne ptr %control, null
  br i1 %has_control, label %read_control, label %no_control
no_control:
  ret i32 0
read_control:
  %status_slot = getelementptr i8, ptr %control, i64 32
  %status = load i32, ptr %status_slot, align 4
  ret i32 %status
}

define internal { i1, i64, i64, i64 } @sollang_diagnostic_close(ptr %session) {
entry:
  %count_slot = getelementptr i8, ptr %session, i64 16
  %count = load i64, ptr %count_slot, align 8
  %records_slot = getelementptr i8, ptr %session, i64 32
  %records = load ptr, ptr %records_slot, align 8
  br label %inspect_loop
inspect_loop:
  %index = phi i64 [ 0, %entry ], [ %next, %inspect_next ]
  %any_busy = phi i1 [ false, %entry ], [ %combined_busy, %inspect_next ]
  %more = icmp ult i64 %index, %count
  br i1 %more, label %inspect, label %inspect_done
inspect:
  %offset = mul i64 %index, 112
  %record = getelementptr i8, ptr %records, i64 %offset
  %status = call i32 @sollang_diagnostic_observed_status(ptr %record)
  %completed = icmp eq i32 %status, 2
  %cancelled = icmp eq i32 %status, 3
  %terminal = or i1 %completed, %cancelled
  %active = xor i1 %terminal, true
  %combined_busy = or i1 %any_busy, %active
  br label %inspect_next
inspect_next:
  %next = add i64 %index, 1
  br label %inspect_loop
inspect_done:
  br i1 %any_busy, label %busy, label %detach_start
busy:
  ret { i1, i64, i64, i64 } zeroinitializer
detach_start:
  %id = load i64, ptr %session, align 8
  %untracked_slot = getelementptr i8, ptr %session, i64 24
  %untracked = load i64, ptr %untracked_slot, align 8
  br label %detach_loop
detach_loop:
  %detach_index = phi i64 [ 0, %detach_start ], [ %detach_next, %advance ]
  %detach_more = icmp ult i64 %detach_index, %count
  br i1 %detach_more, label %detach, label %done
detach:
  %detach_offset = mul i64 %detach_index, 112
  %detach_record = getelementptr i8, ptr %records, i64 %detach_offset
  %observed = call i32 @sollang_diagnostic_observed_status(ptr %detach_record)
  %terminal_slot = getelementptr i8, ptr %detach_record, i64 24
  store i32 %observed, ptr %terminal_slot, align 4
  %control_slot = getelementptr i8, ptr %detach_record, i64 16
  store ptr null, ptr %control_slot, align 8
  %header_slot = getelementptr i8, ptr %detach_record, i64 104
  %header = load ptr, ptr %header_slot, align 8
  %has_header = icmp ne ptr %header, null
  br i1 %has_header, label %detach_header, label %advance
detach_header:
  store ptr null, ptr %header, align 8
  %record_slot = getelementptr i8, ptr %header, i64 8
  store ptr null, ptr %record_slot, align 8
  store ptr null, ptr %header_slot, align 8
  br label %advance
advance:
  %detach_next = add i64 %detach_index, 1
  br label %detach_loop
done:
  %untracked_head_slot = getelementptr i8, ptr %session, i64 40
  %untracked_header = load ptr, ptr %untracked_head_slot, align 8
  %has_untracked_header = icmp ne ptr %untracked_header, null
  br i1 %has_untracked_header, label %detach_untracked, label %release_session
detach_untracked:
  call void @sollang_diagnostic_unlink_untracked(ptr %untracked_header)
  store ptr null, ptr %untracked_header, align 8
  %untracked_record_slot = getelementptr i8, ptr %untracked_header, i64 8
  store ptr null, ptr %untracked_record_slot, align 8
  br label %done
release_session:
  call void @free(ptr %session)
  %summary0 = insertvalue { i1, i64, i64, i64 } poison, i1 true, 0
  %summary1 = insertvalue { i1, i64, i64, i64 } %summary0, i64 %id, 1
  %summary2 = insertvalue { i1, i64, i64, i64 } %summary1, i64 %count, 2
  %summary = insertvalue { i1, i64, i64, i64 } %summary2, i64 %untracked, 3
  ret { i1, i64, i64, i64 } %summary
}
define internal void @sollang_diagnostic_mark_terminal(ptr %header, i32 %terminal) {
entry:
  %record_slot = getelementptr i8, ptr %header, i64 8
  %record = load ptr, ptr %record_slot, align 8
  %tracked = icmp ne ptr %record, null
  br i1 %tracked, label %mark, label %done
mark:
  %control_slot = getelementptr i8, ptr %record, i64 16
  store ptr null, ptr %control_slot, align 8
  %terminal_slot = getelementptr i8, ptr %record, i64 24
  store i32 %terminal, ptr %terminal_slot, align 4
  %resume_slot = getelementptr i8, ptr %record, i64 28
  store i32 0, ptr %resume_slot, align 4
  br label %clear
clear:
  %offset = phi i64 [ 32, %mark ], [ %next, %clear ]
  %slot = getelementptr i8, ptr %record, i64 %offset
  store i64 0, ptr %slot, align 8
  %next = add i64 %offset, 8
  %more = icmp ult i64 %next, 104
  br i1 %more, label %clear, label %done
done:
  ret void
}
define internal void @sollang_diagnostic_suspend(ptr %header, ptr %child, i32 %resume, ptr %module, i64 %module_length, ptr %symbol, i64 %symbol_length, i64 %byte, i64 %line, i64 %column, i64 %deadline) {
entry:
  %record_slot = getelementptr i8, ptr %header, i64 8
  %record = load ptr, ptr %record_slot, align 8
  %tracked = icmp ne ptr %record, null
  br i1 %tracked, label %child_test, label %done
child_test:
  %has_child = icmp ne ptr %child, null
  br i1 %has_child, label %child_id, label %write
child_id:
  %id_slot = getelementptr i8, ptr %child, i64 16
  %id = load i64, ptr %id_slot, align 8
  br label %write
write:
  %awaited = phi i64 [ 0, %child_test ], [ %id, %child_id ]
  %field28 = getelementptr i8, ptr %record, i64 28
  store i32 %resume, ptr %field28, align 4
  %field32 = getelementptr i8, ptr %record, i64 32
  store i64 %awaited, ptr %field32, align 8
  %field40 = getelementptr i8, ptr %record, i64 40
  store i64 %deadline, ptr %field40, align 8
  %field48 = getelementptr i8, ptr %record, i64 48
  store ptr %module, ptr %field48, align 8
  %field56 = getelementptr i8, ptr %record, i64 56
  store i64 %module_length, ptr %field56, align 8
  %field64 = getelementptr i8, ptr %record, i64 64
  store ptr %symbol, ptr %field64, align 8
  %field72 = getelementptr i8, ptr %record, i64 72
  store i64 %symbol_length, ptr %field72, align 8
  %field80 = getelementptr i8, ptr %record, i64 80
  store i64 %byte, ptr %field80, align 8
  %field88 = getelementptr i8, ptr %record, i64 88
  store i64 %line, ptr %field88, align 8
  %field96 = getelementptr i8, ptr %record, i64 96
  store i64 %column, ptr %field96, align 8
  br label %done
done:
  ret void
}
define internal void @sollang_diagnostic_unlink_untracked(ptr %header) {
entry:
  %session = load ptr, ptr %header, align 8
  %linked = icmp ne ptr %session, null
  br i1 %linked, label %unlink, label %clear
unlink:
  %previous_slot = getelementptr i8, ptr %header, i64 32
  %next_slot = getelementptr i8, ptr %header, i64 40
  %previous = load ptr, ptr %previous_slot, align 8
  %next = load ptr, ptr %next_slot, align 8
  %has_previous = icmp ne ptr %previous, null
  br i1 %has_previous, label %previous_next, label %session_head
previous_next:
  %previous_next_slot = getelementptr i8, ptr %previous, i64 40
  store ptr %next, ptr %previous_next_slot, align 8
  br label %inspect_next
session_head:
  %head_slot = getelementptr i8, ptr %session, i64 40
  store ptr %next, ptr %head_slot, align 8
  br label %inspect_next
inspect_next:
  %has_next = icmp ne ptr %next, null
  br i1 %has_next, label %next_previous, label %clear
next_previous:
  %next_previous_slot = getelementptr i8, ptr %next, i64 32
  store ptr %previous, ptr %next_previous_slot, align 8
  br label %clear
clear:
  %clear_previous_slot = getelementptr i8, ptr %header, i64 32
  %clear_next_slot = getelementptr i8, ptr %header, i64 40
  store ptr null, ptr %clear_previous_slot, align 8
  store ptr null, ptr %clear_next_slot, align 8
  ret void
}
define internal void @sollang_diagnostic_release_header(ptr %header, i32 %terminal) {
entry:
  call void @sollang_diagnostic_mark_terminal(ptr %header, i32 %terminal)
  %record_slot = getelementptr i8, ptr %header, i64 8
  %record = load ptr, ptr %record_slot, align 8
  %has_record = icmp ne ptr %record, null
  br i1 %has_record, label %freeze, label %unlink_untracked
freeze:
  %terminal_slot = getelementptr i8, ptr %record, i64 24
  store i32 %terminal, ptr %terminal_slot, align 4
  %control_slot = getelementptr i8, ptr %record, i64 16
  store ptr null, ptr %control_slot, align 8
  %header_slot = getelementptr i8, ptr %record, i64 104
  store ptr null, ptr %header_slot, align 8
  br label %detach
unlink_untracked:
  call void @sollang_diagnostic_unlink_untracked(ptr %header)
  br label %detach
detach:
  store ptr null, ptr %header, align 8
  store ptr null, ptr %record_slot, align 8
  ret void
}
define internal void @sollang_diagnostic_inherit(ptr %header, ptr %control, ptr %parent) {
entry:
  %has_parent = icmp ne ptr %parent, null
  br i1 %has_parent, label %read, label %done
read:
  %session = load ptr, ptr %parent, align 8
  %has_session = icmp ne ptr %session, null
  br i1 %has_session, label %attach, label %done
attach:
  %parent_id_slot = getelementptr i8, ptr %parent, i64 16
  %parent_id = load i64, ptr %parent_id_slot, align 8
  %child_parent_slot = getelementptr i8, ptr %header, i64 24
  store i64 %parent_id, ptr %child_parent_slot, align 8
  %ignored = call i32 @sollang_diagnostic_track(ptr %session, ptr %header, ptr %control)
  br label %done
done:
  ret void
}
define internal i32 @sollang_diagnostic_track(ptr %session, ptr %header, ptr %control) {
entry:
  %existing = load ptr, ptr %header, align 8
  %record_slot = getelementptr i8, ptr %header, i64 8
  %untracked = icmp eq ptr %existing, null
  br i1 %untracked, label %attach, label %already
already:
  %same = icmp eq ptr %existing, %session
  br i1 %same, label %same_session, label %cross
same_session:
  %previous_record = load ptr, ptr %record_slot, align 8
  %capacity_rejected = icmp eq ptr %previous_record, null
  br i1 %capacity_rejected, label %capacity, label %duplicate
cross:
  ret i32 1
duplicate:
  ret i32 0
capacity:
  ret i32 2
attach:
  %capacity_slot = getelementptr i8, ptr %session, i64 8
  %capacity_value = load i64, ptr %capacity_slot, align 8
  %count_slot = getelementptr i8, ptr %session, i64 16
  %count = load i64, ptr %count_slot, align 8
  %available = icmp ult i64 %count, %capacity_value
  br i1 %available, label %record, label %full
full:
  store ptr %session, ptr %header, align 8
  %head_slot = getelementptr i8, ptr %session, i64 40
  %head = load ptr, ptr %head_slot, align 8
  %previous_slot = getelementptr i8, ptr %header, i64 32
  %next_slot = getelementptr i8, ptr %header, i64 40
  store ptr null, ptr %previous_slot, align 8
  store ptr %head, ptr %next_slot, align 8
  %has_head = icmp ne ptr %head, null
  br i1 %has_head, label %link_head, label %publish_head
link_head:
  %head_previous_slot = getelementptr i8, ptr %head, i64 32
  store ptr %header, ptr %head_previous_slot, align 8
  br label %publish_head
publish_head:
  store ptr %header, ptr %head_slot, align 8
  %untracked_slot = getelementptr i8, ptr %session, i64 24
  %untracked_count = load i64, ptr %untracked_slot, align 8
  %untracked_next = add i64 %untracked_count, 1
  store i64 %untracked_next, ptr %untracked_slot, align 8
  ret i32 2
record:
  %records_slot = getelementptr i8, ptr %session, i64 32
  %records = load ptr, ptr %records_slot, align 8
  %offset = mul i64 %count, 112
  %new_record = getelementptr i8, ptr %records, i64 %offset
  br label %initialize
initialize:
  %field = phi i64 [ 0, %record ], [ %next_field, %initialize ]
  %field_slot = getelementptr i64, ptr %new_record, i64 %field
  store i64 0, ptr %field_slot, align 8
  %next_field = add i64 %field, 1
  %more_fields = icmp ult i64 %next_field, 14
  br i1 %more_fields, label %initialize, label %publish
publish:
  %task_id = add i64 %count, 1
  store i64 %task_id, ptr %new_record, align 8
  %parent_slot = getelementptr i8, ptr %header, i64 24
  %parent_id = load i64, ptr %parent_slot, align 8
  %record_parent_slot = getelementptr i8, ptr %new_record, i64 8
  store i64 %parent_id, ptr %record_parent_slot, align 8
  %control_slot = getelementptr i8, ptr %new_record, i64 16
  store ptr %control, ptr %control_slot, align 8
  %terminal_slot = getelementptr i8, ptr %new_record, i64 24
  store i32 -1, ptr %terminal_slot, align 4
  %header_slot = getelementptr i8, ptr %new_record, i64 104
  store ptr %header, ptr %header_slot, align 8
  store ptr %session, ptr %header, align 8
  store ptr %new_record, ptr %record_slot, align 8
  %task_id_slot = getelementptr i8, ptr %header, i64 16
  store i64 %task_id, ptr %task_id_slot, align 8
  %next_count = add i64 %count, 1
  store i64 %next_count, ptr %count_slot, align 8
  ret i32 -1
}
@sollang_diagnostic_module118368 = private constant [58 x i8] c"\70\72\6F\62\65\73\2E\61\73\79\6E\63\5F\74\61\73\6B\5F\6F\62\73\65\72\76\61\62\69\6C\69\74\79\2E\67\65\6E\65\72\69\63\5F\73\75\73\70\65\6E\73\69\6F\6E\5F\6C\6F\63\61\74\6F\72"
@sollang_diagnostic_symbol118368 = private constant [12 x i8] c"\75\6E\69\63\6F\64\65\41\77\61\69\74"
@sollang_diagnostic_module118286 = private constant [58 x i8] c"\70\72\6F\62\65\73\2E\61\73\79\6E\63\5F\74\61\73\6B\5F\6F\62\73\65\72\76\61\62\69\6C\69\74\79\2E\67\65\6E\65\72\69\63\5F\73\75\73\70\65\6E\73\69\6F\6E\5F\6C\6F\63\61\74\6F\72"
@sollang_diagnostic_symbol118286 = private constant [7 x i8] c"\6F\62\73\65\72\76\65"
%sollang.source_text = type { ptr, i64, ptr, i64 }
%sollang.file_handle_result = type { i64, i32 }
%sollang.file_count_result = type { i64, i32 }
@sollang_file_error_io = private constant [2 x i8] c"io"
@sollang_file_error_range = private constant [5 x i8] c"range"
@sollang_file_error_truncated = private constant [9 x i8] c"truncated"
@sollang_file_error_invalid = private constant [7 x i8] c"invalid"
%sollang.directory_result = type { ptr, i64, i64, i32 }
%sollang.path_query_result = type { ptr, i64, i8, i64, i64, i32 }
%sollang.path_absolute_result = type { ptr, i64, i32 }
%sollang.directory_node = type { ptr, i64, i8, [7 x i8] }
@sollang_directory_error_io = private constant [2 x i8] c"io"
%sollang.text = type { ptr, i64 }
%sollang.task = type { ptr, ptr }
%sollang.task_control = type { ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, i64, ptr, ptr, i32, i32, i64, i64, i32, ptr, i64, i64, i32, i32, ptr, ptr }
%sollang.diagnostic_task_control = type { %sollang.task_control, ptr }
define internal void @sollang_diagnostic_sleep_destroy(ptr %context) {
entry:
  %header = getelementptr i8, ptr %context, i64 8
  call void @sollang_diagnostic_release_header(ptr %header, i32 2)
  call void @free(ptr %context)
  ret void
}
define internal void @sollang_diagnostic_sleep_cancel(ptr %control) {
entry:
  %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %context_slot, align 8
  %header = getelementptr i8, ptr %context, i64 8
  call void @sollang_diagnostic_release_header(ptr %header, i32 3)
  call void @free(ptr %context)
  ret void
}
define internal i1 @sollang_diagnostic_sleep_worker(ptr %control) {
entry:
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %ready = icmp sge i64 %now, %deadline
  br i1 %ready, label %complete, label %pending
complete:
  %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %context_slot, align 8
  %header = getelementptr i8, ptr %context, i64 8
  call void @sollang_diagnostic_release_header(ptr %header, i32 2)
  ret i1 true
pending:
  call void @sollang_timer_park(ptr %control, i64 %deadline)
  ret i1 false
}
@sollang_task_ready_head = internal global ptr null
@sollang_task_ready_tail = internal global ptr null
@sollang_task_timer_head = internal global ptr null
@sollang_io_outstanding = internal global i64 0
%sollang.stream = type { ptr, ptr, ptr }
%sollang.event_stream = type { ptr, ptr, ptr }
define internal i1 @sollang_range_stream_next(ptr %context, ptr %output) {
entry:
  %done_address = getelementptr i8, ptr %context, i64 8
  %done = load i1, ptr %done_address, align 1
  br i1 %done, label %finished, label %active
active:
  %current = load i32, ptr %context, align 4
  %end_address = getelementptr i8, ptr %context, i64 4
  %end = load i32, ptr %end_address, align 4
  %past_end = icmp sgt i32 %current, %end
  br i1 %past_end, label %mark_finished, label %yield
yield:
  store i32 %current, ptr %output, align 4
  %is_last = icmp eq i32 %current, %end
  br i1 %is_last, label %mark_finished_after_yield, label %advance
advance:
  %next = add i32 %current, 1
  store i32 %next, ptr %context, align 4
  ret i1 true
mark_finished_after_yield:
  store i1 true, ptr %done_address, align 1
  ret i1 true
mark_finished:
  store i1 true, ptr %done_address, align 1
  ret i1 false
finished:
  ret i1 false
}
define internal void @sollang_stream_heap_drop(ptr %context, i1 %destroy) {
entry:
  br i1 %destroy, label %release, label %done
release:
  call void @free(ptr %context)
  br label %done
done:
  ret void
}
define internal %sollang.stream @sollang_range_stream_create({ i32, i32 } %range) {
entry:
  %context = call ptr @malloc(i64 12)
  %start = extractvalue { i32, i32 } %range, 0
  %end = extractvalue { i32, i32 } %range, 1
  store i32 %start, ptr %context, align 4
  %end_address = getelementptr i8, ptr %context, i64 4
  store i32 %end, ptr %end_address, align 4
  %done_address = getelementptr i8, ptr %context, i64 8
  store i1 false, ptr %done_address, align 1
  %with_context = insertvalue %sollang.stream poison, ptr %context, 0
  %with_next = insertvalue %sollang.stream %with_context, ptr @sollang_range_stream_next, 1
  %result = insertvalue %sollang.stream %with_next, ptr @sollang_stream_heap_drop, 2
  ret %sollang.stream %result
}
%sollang.enum.t32 = type { i32, [0 x i64] }
%sollang.enum.t43 = type { i32, [0 x i64] }
%sollang.enum.t55 = type { i32, [0 x i64] }
%sollang.enum.t58 = type { i32, [0 x i64] }
%sollang.enum.t78 = type { i32, [1 x i64] }
%sollang.enum.t85 = type { i32, [1 x i64] }
%sollang.enum.t88 = type { i32, [1 x i64] }
%sollang.enum.t99 = type { i32, [0 x i64] }
%sollang.enum.t100 = type { i32, [0 x i64] }
%sollang.enum.t106 = type { i32, [3 x i64] }
%sollang.enum.t113 = type { i32, [4 x i64] }
%sollang.enum.t115 = type { i32, [4 x i64] }
%sollang.enum.t116 = type { i32, [4 x i64] }
%sollang.enum.t117 = type { i32, [2 x i64] }
%sollang.enum.t118 = type { i32, [8 x i64] }
%sollang.enum.t119 = type { i32, [2 x i64] }
%sollang.enum.t120 = type { i32, [4 x i64] }
%sollang.enum.t121 = type { i32, [2 x i64] }
%sollang.enum.t122 = type { i32, [2 x i64] }
%sollang.enum.t124 = type { i32, [3 x i64] }
%sollang.enum.t125 = type { i32, [0 x i64] }
%sollang.enum.t131 = type { i32, [2 x i64] }
%sollang.enum.t132 = type { i32, [3 x i64] }
%sollang.enum.t137 = type { i32, [0 x i64] }
%sollang.enum.t139 = type { i32, [4 x i64] }
%sollang.enum.t140 = type { i32, [2 x i64] }
%sollang.enum.t141 = type { i32, [2 x i64] }
%sollang.enum.t143 = type { i32, [2 x i64] }
%sollang.enum.t144 = type { i32, [4 x i64] }
%sollang.enum.t145 = type { i32, [0 x i64] }
%sollang.enum.t146 = type { i32, [0 x i64] }
%sollang.enum.t150 = type { i32, [0 x i64] }
%sollang.enum.t153 = type { i32, [3 x i64] }
%sollang.enum.t154 = type { i32, [12 x i64] }
%sollang.enum.t155 = type { i32, [3 x i64] }
%sollang.enum.t156 = type { i32, [4 x i64] }
%sollang.enum.t173 = type { i32, [0 x i64] }
%sollang.enum.t174 = type { i32, [0 x i64] }
%sollang.enum.t176 = type { i32, [0 x i64] }
%sollang.enum.t188 = type { i32, [1 x i64] }
%sollang.enum.t189 = type { i32, [1 x i64] }
%sollang.enum.t190 = type { i32, [2 x i64] }
%sollang.enum.t191 = type { i32, [2 x i64] }
%sollang.enum.t192 = type { i32, [2 x i64] }
%sollang.enum.t193 = type { i32, [6 x i64] }
%sollang.enum.t194 = type { i32, [1 x i64] }
%sollang.enum.t195 = type { i32, [1 x i64] }
%sollang.enum.t196 = type { i32, [1 x i64] }
%sollang.enum.t197 = type { i32, [1 x i64] }
%sollang.enum.t198 = type { i32, [11 x i64] }
%sollang.enum.t199 = type { i32, [0 x i64] }
%sollang.enum.t201 = type { i32, [3 x i64] }
%sollang.enum.t202 = type { i32, [1 x i64] }
%sollang.enum.t204 = type { i32, [12 x i64] }
%sollang.enum.t208 = type { i32, [29 x i64] }
%sollang.enum.t209 = type { i32, [12 x i64] }
%sollang.enum.t210 = type { i32, [2 x i64] }
%sollang.enum.t212 = type { i32, [2 x i64] }
%sollang.enum.t214 = type { i32, [3 x i64] }
%sollang.enum.t215 = type { i32, [0 x i64] }
%sollang.enum.t221 = type { i32, [0 x i64] }
%sollang.enum.t223 = type { i32, [2 x i64] }
%sollang.enum.t224 = type { i32, [1 x i64] }
%sollang.enum.t225 = type { i32, [1 x i64] }
%sollang.enum.t227 = type { i32, [0 x i64] }
%sollang.enum.t230 = type { i32, [4 x i64] }
%sollang.enum.t231 = type { i32, [3 x i64] }
%sollang.enum.t236 = type { i32, [2 x i64] }
%sollang.enum.t246 = type { i32, [2 x i64] }
%sollang.enum.t247 = type { i32, [2 x i64] }
%sollang.enum.t248 = type { i32, [2 x i64] }
%sollang.enum.t249 = type { i32, [7 x i64] }
%sollang.enum.t250 = type { i32, [7 x i64] }
%sollang.enum.t251 = type { i32, [0 x i64] }
%sollang.enum.t252 = type { i32, [0 x i64] }
%sollang.enum.t253 = type { i32, [2 x i64] }
%sollang.enum.t254 = type { i32, [2 x i64] }
%sollang.enum.t257 = type { i32, [7 x i64] }
%sollang.enum.t258 = type { i32, [4 x i64] }
%sollang.enum.t259 = type { i32, [2 x i64] }
%sollang.enum.t263 = type { i32, [2 x i64] }
%sollang.enum.t264 = type { i32, [2 x i64] }
%sollang.enum.t270 = type { i32, [2 x i64] }
%sollang.enum.t275 = type { i32, [1 x i64] }
%sollang.enum.t276 = type { i32, [0 x i64] }
%sollang.enum.t278 = type { i32, [0 x i64] }
%sollang.enum.t284 = type { i32, [0 x i64] }
%sollang.enum.t290 = type { i32, [3 x i64] }
%sollang.enum.t291 = type { i32, [44 x i64] }
%sollang.enum.t292 = type { i32, [2 x i64] }
%sollang.enum.t293 = type { i32, [13 x i64] }
%sollang.enum.t294 = type { i32, [2 x i64] }
%sollang.enum.t295 = type { i32, [0 x i64] }
%sollang.enum.t296 = type { i32, [0 x i64] }
%sollang.enum.t299 = type { i32, [0 x i64] }
%sollang.enum.t301 = type { i32, [0 x i64] }
%sollang.enum.t303 = type { i32, [0 x i64] }
%sollang.enum.t308 = type { i32, [1 x i64] }
%sollang.enum.t309 = type { i32, [7 x i64] }
%sollang.enum.t310 = type { i32, [1 x i64] }
%sollang.enum.t313 = type { i32, [3 x i64] }
%sollang.enum.t316 = type { i32, [1 x i64] }
%sollang.enum.t317 = type { i32, [0 x i64] }
%sollang.enum.t319 = type { i32, [0 x i64] }
%sollang.enum.t328 = type { i32, [0 x i64] }
%sollang.enum.t329 = type { i32, [0 x i64] }
%sollang.enum.t336 = type { i32, [3 x i64] }
%sollang.enum.t337 = type { i32, [4 x i64] }
%sollang.enum.t338 = type { i32, [105 x i64] }
%sollang.enum.t339 = type { i32, [2 x i64] }
%sollang.enum.t340 = type { i32, [9 x i64] }
%sollang.enum.t341 = type { i32, [26 x i64] }
%sollang.enum.t342 = type { i32, [81 x i64] }
%sollang.enum.t343 = type { i32, [2 x i64] }
%sollang.enum.t346 = type { i32, [3 x i64] }
%sollang.enum.t347 = type { i32, [0 x i64] }
%sollang.enum.t351 = type { i32, [0 x i64] }
%sollang.enum.t372 = type { i32, [2 x i64] }
%sollang.enum.t373 = type { i32, [4 x i64] }
%sollang.enum.t374 = type { i32, [4 x i64] }
%sollang.enum.t375 = type { i32, [72 x i64] }
%sollang.enum.t376 = type { i32, [2 x i64] }
%sollang.enum.t377 = type { i32, [2 x i64] }
%sollang.enum.t378 = type { i32, [2 x i64] }
%sollang.enum.t379 = type { i32, [13 x i64] }
%sollang.enum.t380 = type { i32, [26 x i64] }
%sollang.enum.t381 = type { i32, [5 x i64] }
%sollang.enum.t382 = type { i32, [2 x i64] }
%sollang.enum.t386 = type { i32, [2 x i64] }
%sollang.enum.t387 = type { i32, [72 x i64] }
%sollang.enum.t388 = type { i32, [3 x i64] }
%sollang.enum.t389 = type { i32, [0 x i64] }
%sollang.enum.t395 = type { i32, [0 x i64] }
%sollang.enum.t401 = type { i32, [3 x i64] }
%sollang.enum.t402 = type { i32, [13 x i64] }
%sollang.enum.t403 = type { i32, [70 x i64] }
%sollang.enum.t404 = type { i32, [2 x i64] }
%sollang.enum.t405 = type { i32, [40 x i64] }
%sollang.enum.t409 = type { i32, [3 x i64] }
%sollang.enum.t415 = type { i32, [3 x i64] }
%sollang.enum.t417 = type { i32, [0 x i64] }
%sollang.enum.t420 = type { i32, [0 x i64] }
%sollang.enum.t426 = type { i32, [8 x i64] }
%sollang.enum.t427 = type { i32, [1 x i64] }
%sollang.enum.t428 = type { i32, [2 x i64] }
%sollang.enum.t429 = type { i32, [2 x i64] }
%sollang.enum.t430 = type { i32, [2 x i64] }
%sollang.enum.t436 = type { i32, [3 x i64] }
%sollang.enum.t442 = type { i32, [0 x i64] }
%sollang.enum.t443 = type { i32, [0 x i64] }
%sollang.enum.t444 = type { i32, [0 x i64] }
%sollang.enum.t452 = type { i32, [2 x i64] }
%sollang.enum.t453 = type { i32, [2 x i64] }
%sollang.enum.t454 = type { i32, [2 x i64] }
%sollang.enum.t455 = type { i32, [5 x i64] }
%sollang.enum.t456 = type { i32, [11 x i64] }
%sollang.enum.t457 = type { i32, [9 x i64] }
%sollang.enum.t459 = type { i32, [3 x i64] }
%sollang.enum.t460 = type { i32, [0 x i64] }
%sollang.enum.t461 = type { i32, [0 x i64] }
%sollang.enum.t465 = type { i32, [2 x i64] }
%sollang.enum.t466 = type { i32, [2 x i64] }
%sollang.enum.t467 = type { i32, [2 x i64] }
%sollang.enum.t468 = type { i32, [2 x i64] }
%sollang.enum.t469 = type { i32, [2 x i64] }
%sollang.enum.t470 = type { i32, [0 x i64] }
%sollang.enum.t477 = type { i32, [2 x i64] }
%sollang.enum.t478 = type { i32, [2 x i64] }
%sollang.enum.t479 = type { i32, [2 x i64] }
%sollang.enum.t480 = type { i32, [3 x i64] }
%sollang.enum.t481 = type { i32, [4 x i64] }
%sollang.enum.t482 = type { i32, [2 x i64] }
%sollang.enum.t483 = type { i32, [3 x i64] }
%sollang.enum.t484 = type { i32, [0 x i64] }
%sollang.enum.t486 = type { i32, [2 x i64] }
%sollang.enum.t497 = type { i32, [5 x i64] }
%sollang.enum.t498 = type { i32, [10 x i64] }
%sollang.enum.t499 = type { i32, [10 x i64] }
%sollang.enum.t500 = type { i32, [11 x i64] }
%sollang.enum.t501 = type { i32, [11 x i64] }
%sollang.enum.t510 = type { i32, [8 x i64] }
%sollang.enum.t511 = type { i32, [8 x i64] }
%sollang.enum.t512 = type { i32, [2 x i64] }
%sollang.enum.t522 = type { i32, [16 x i64] }
%sollang.enum.t524 = type { i32, [7 x i64] }
%sollang.enum.t525 = type { i32, [7 x i64] }
%sollang.enum.t526 = type { i32, [3 x i64] }
%sollang.enum.t527 = type { i32, [0 x i64] }
%sollang.enum.t528 = type { i32, [0 x i64] }
%sollang.enum.t531 = type { i32, [0 x i64] }
%sollang.enum.t534 = type { i32, [0 x i64] }
%sollang.enum.t542 = type { i32, [3 x i64] }
%sollang.enum.t543 = type { i32, [3 x i64] }
%sollang.enum.t544 = type { i32, [13 x i64] }
%sollang.enum.t545 = type { i32, [12 x i64] }
%sollang.enum.t546 = type { i32, [4 x i64] }
%sollang.enum.t547 = type { i32, [2 x i64] }
%sollang.enum.t548 = type { i32, [2 x i64] }
%sollang.enum.t549 = type { i32, [2 x i64] }
%sollang.enum.t550 = type { i32, [0 x i64] }
%sollang.enum.t593 = type { i32, [7 x i64] }
%sollang.enum.t607 = type { i32, [2 x i64] }
%sollang.enum.t608 = type { i32, [2 x i64] }
%sollang.enum.t609 = type { i32, [9 x i64] }
%sollang.enum.t610 = type { i32, [21 x i64] }
%sollang.enum.t611 = type { i32, [4 x i64] }
%sollang.enum.t612 = type { i32, [9 x i64] }
%sollang.enum.t613 = type { i32, [2 x i64] }
%sollang.enum.t614 = type { i32, [5 x i64] }
%sollang.enum.t615 = type { i32, [2 x i64] }
%sollang.enum.t616 = type { i32, [14 x i64] }
%sollang.enum.t618 = type { i32, [11 x i64] }
%sollang.enum.t619 = type { i32, [16 x i64] }
%sollang.enum.t620 = type { i32, [7 x i64] }
%sollang.enum.t623 = type { i32, [7 x i64] }
%sollang.enum.t624 = type { i32, [4 x i64] }
%sollang.enum.t625 = type { i32, [6 x i64] }
%sollang.enum.t626 = type { i32, [7 x i64] }
%sollang.enum.t627 = type { i32, [6 x i64] }
%sollang.enum.t628 = type { i32, [5 x i64] }
%sollang.enum.t629 = type { i32, [2 x i64] }
%sollang.enum.t630 = type { i32, [4 x i64] }
%sollang.enum.t631 = type { i32, [10 x i64] }
%sollang.enum.t632 = type { i32, [131 x i64] }
%sollang.enum.t633 = type { i32, [2 x i64] }
%sollang.enum.t634 = type { i32, [16 x i64] }
%sollang.enum.t635 = type { i32, [7 x i64] }
%sollang.enum.t636 = type { i32, [10 x i64] }
%sollang.enum.t638 = type { i32, [5 x i64] }
%sollang.enum.t640 = type { i32, [2 x i64] }
%sollang.enum.t641 = type { i32, [17 x i64] }
%sollang.enum.t642 = type { i32, [2 x i64] }
%sollang.enum.t643 = type { i32, [2 x i64] }
%sollang.enum.t644 = type { i32, [3 x i64] }
%sollang.enum.t647 = type { i32, [1 x i64] }
%sollang.enum.t648 = type { i32, [0 x i64] }
%sollang.enum.t649 = type { i32, [0 x i64] }
%sollang.enum.t650 = type { i32, [0 x i64] }
%sollang.enum.t653 = type { i32, [0 x i64] }
%sollang.enum.t662 = type { i32, [2 x i64] }
%sollang.enum.t663 = type { i32, [3 x i64] }
%sollang.enum.t664 = type { i32, [17 x i64] }
%sollang.enum.t666 = type { i32, [2 x i64] }
%sollang.enum.t667 = type { i32, [2 x i64] }
%sollang.enum.t675 = type { i32, [0 x i64] }
%sollang.enum.t676 = type { i32, [0 x i64] }
%sollang.enum.t685 = type { i32, [12 x i64] }
%sollang.enum.t686 = type { i32, [4 x i64] }
%sollang.enum.t687 = type { i32, [3 x i64] }
%sollang.enum.t688 = type { i32, [3 x i64] }
%sollang.enum.t689 = type { i32, [4 x i64] }
%sollang.enum.t690 = type { i32, [2 x i64] }
%sollang.enum.t692 = type { i32, [3 x i64] }
%sollang.enum.t693 = type { i32, [0 x i64] }
%sollang.enum.t697 = type { i32, [6 x i64] }
%sollang.enum.t698 = type { i32, [3 x i64] }
%sollang.enum.t699 = type { i32, [0 x i64] }
%sollang.enum.t700 = type { i32, [0 x i64] }
%sollang.enum.t701 = type { i32, [0 x i64] }
%sollang.enum.t713 = type { i32, [2 x i64] }
%sollang.enum.t714 = type { i32, [2 x i64] }
%sollang.enum.t715 = type { i32, [2 x i64] }
%sollang.enum.t716 = type { i32, [2 x i64] }
%sollang.enum.t717 = type { i32, [2 x i64] }
%sollang.enum.t718 = type { i32, [12 x i64] }
%sollang.enum.t719 = type { i32, [6 x i64] }
%sollang.enum.t720 = type { i32, [3 x i64] }
%sollang.enum.t721 = type { i32, [2 x i64] }
%sollang.enum.t722 = type { i32, [8 x i64] }
%sollang.enum.t724 = type { i32, [2 x i64] }
%sollang.enum.t725 = type { i32, [4 x i64] }
%sollang.enum.t728 = type { i32, [3 x i64] }
%sollang.enum.t729 = type { i32, [0 x i64] }
%sollang.enum.t730 = type { i32, [0 x i64] }
%sollang.enum.t731 = type { i32, [0 x i64] }
%sollang.enum.t739 = type { i32, [4 x i64] }
%sollang.enum.t740 = type { i32, [4 x i64] }
%sollang.enum.t741 = type { i32, [7 x i64] }
%sollang.enum.t742 = type { i32, [4 x i64] }
%sollang.enum.t744 = type { i32, [9 x i64] }
%sollang.enum.t745 = type { i32, [2 x i64] }
%sollang.enum.t746 = type { i32, [4 x i64] }
%sollang.enum.t747 = type { i32, [0 x i64] }
%sollang.enum.t748 = type { i32, [0 x i64] }
%sollang.enum.t752 = type { i32, [2 x i64] }
%sollang.enum.t753 = type { i32, [3 x i64] }
%sollang.enum.t754 = type { i32, [0 x i64] }
%sollang.enum.t755 = type { i32, [0 x i64] }
%sollang.enum.t756 = type { i32, [0 x i64] }
%sollang.enum.t759 = type { i32, [2 x i64] }
%sollang.enum.t762 = type { i32, [3 x i64] }
%sollang.enum.t773 = type { i32, [0 x i64] }
%sollang.enum.t774 = type { i32, [3 x i64] }
%sollang.enum.t775 = type { i32, [6 x i64] }
%sollang.enum.t776 = type { i32, [1 x i64] }
%sollang.enum.t777 = type { i32, [2 x i64] }
%sollang.enum.t778 = type { i32, [3 x i64] }
%sollang.enum.t779 = type { i32, [8 x i64] }
%sollang.enum.t780 = type { i32, [2 x i64] }
%sollang.enum.t781 = type { i32, [1 x i64] }
%sollang.enum.t782 = type { i32, [2 x i64] }
%sollang.enum.t783 = type { i32, [3 x i64] }
%sollang.enum.t784 = type { i32, [2 x i64] }
%sollang.enum.t786 = type { i32, [16 x i64] }
%sollang.enum.t787 = type { i32, [0 x i64] }
%sollang.enum.t788 = type { i32, [0 x i64] }
%sollang.enum.t789 = type { i32, [2 x i64] }
%sollang.enum.t790 = type { i32, [4 x i64] }
%sollang.enum.t791 = type { i32, [3 x i64] }
%sollang.enum.t792 = type { i32, [18 x i64] }
%sollang.enum.t793 = type { i32, [3 x i64] }
%sollang.enum.t794 = type { i32, [16 x i64] }
%sollang.enum.t795 = type { i32, [2 x i64] }
%sollang.enum.t796 = type { i32, [2 x i64] }
%sollang.enum.t797 = type { i32, [2 x i64] }
%sollang.enum.t799 = type { i32, [1 x i64] }
%sollang.enum.t800 = type { i32, [2 x i64] }
%sollang.enum.t801 = type { i32, [2 x i64] }
%sollang.enum.t802 = type { i32, [5 x i64] }
%sollang.enum.t803 = type { i32, [2 x i64] }
%sollang.enum.t806 = type { i32, [9 x i64] }
%sollang.enum.t807 = type { i32, [7 x i64] }
%sollang.enum.t808 = type { i32, [3 x i64] }
%sollang.enum.t809 = type { i32, [2 x i64] }
%sollang.enum.t811 = type { i32, [0 x i64] }
%sollang.enum.t817 = type { i32, [1 x i64] }
%sollang.enum.t819 = type { i32, [0 x i64] }
%sollang.enum.t820 = type { i32, [0 x i64] }
%sollang.enum.t822 = type { i32, [1 x i64] }
%sollang.enum.t823 = type { i32, [1 x i64] }
%sollang.enum.t826 = type { i32, [26 x i64] }
%sollang.enum.t827 = type { i32, [4 x i64] }
%sollang.enum.t828 = type { i32, [2 x i64] }
%sollang.enum.t829 = type { i32, [2 x i64] }
%sollang.enum.t830 = type { i32, [2 x i64] }
%sollang.enum.t831 = type { i32, [50 x i64] }
%sollang.enum.t832 = type { i32, [2 x i64] }
%sollang.enum.t833 = type { i32, [3 x i64] }
%sollang.enum.t834 = type { i32, [2 x i64] }
%sollang.enum.t835 = type { i32, [2 x i64] }
%sollang.enum.t837 = type { i32, [2 x i64] }
%sollang.enum.t838 = type { i32, [2 x i64] }
%sollang.enum.t843 = type { i32, [0 x i64] }
%sollang.enum.t844 = type { i32, [0 x i64] }
%sollang.enum.t846 = type { i32, [0 x i64] }
%sollang.enum.t847 = type { i32, [4 x i64] }
%sollang.enum.t849 = type { i32, [0 x i64] }
%sollang.enum.t852 = type { i32, [0 x i64] }
%sollang.enum.t855 = type { i32, [0 x i64] }
%sollang.enum.t859 = type { i32, [1 x i64] }
%sollang.enum.t862 = type { i32, [1 x i64] }
%sollang.enum.t864 = type { i32, [1 x i64] }
%sollang.enum.t866 = type { i32, [1 x i64] }
%sollang.enum.t868 = type { i32, [5 x i64] }
%sollang.enum.t869 = type { i32, [1 x i64] }
%sollang.enum.t870 = type { i32, [0 x i64] }
%sollang.enum.t871 = type { i32, [0 x i64] }
%sollang.enum.t872 = type { i32, [0 x i64] }
%sollang.enum.t881 = type { i32, [9 x i64] }
%sollang.enum.t882 = type { i32, [24 x i64] }
%sollang.enum.t883 = type { i32, [2 x i64] }
%sollang.enum.t884 = type { i32, [12 x i64] }
%sollang.enum.t885 = type { i32, [11 x i64] }
%sollang.enum.t886 = type { i32, [2 x i64] }
%sollang.enum.t887 = type { i32, [32 x i64] }
%sollang.enum.t888 = type { i32, [34 x i64] }
%sollang.enum.t889 = type { i32, [2 x i64] }
%sollang.enum.t890 = type { i32, [9 x i64] }
%sollang.enum.t891 = type { i32, [31 x i64] }
%sollang.enum.t892 = type { i32, [2 x i64] }
%sollang.enum.t893 = type { i32, [15 x i64] }
%sollang.enum.t894 = type { i32, [34 x i64] }
%sollang.enum.t895 = type { i32, [2 x i64] }
%sollang.enum.t896 = type { i32, [2 x i64] }
%sollang.enum.t897 = type { i32, [6 x i64] }
%sollang.enum.t898 = type { i32, [2 x i64] }
%sollang.enum.t899 = type { i32, [2 x i64] }
%sollang.enum.t900 = type { i32, [2 x i64] }
%sollang.enum.t902 = type { i32, [14 x i64] }
%sollang.enum.t903 = type { i32, [9 x i64] }
%sollang.enum.t904 = type { i32, [5 x i64] }
%sollang.enum.t905 = type { i32, [5 x i64] }
%sollang.enum.t906 = type { i32, [4 x i64] }
%sollang.enum.t907 = type { i32, [2 x i64] }
%sollang.enum.t909 = type { i32, [2 x i64] }
%sollang.enum.t914 = type { i32, [66 x i64] }
%sollang.enum.t915 = type { i32, [1 x i64] }
%sollang.enum.t917 = type { i32, [1 x i64] }
%sollang.enum.t918 = type { i32, [2 x i64] }
%sollang.enum.t919 = type { i32, [81 x i64] }
%sollang.enum.t920 = type { i32, [2 x i64] }
%sollang.enum.t921 = type { i32, [3 x i64] }
%sollang.enum.t922 = type { i32, [0 x i64] }
%sollang.enum.t923 = type { i32, [4 x i64] }
%sollang.enum.t926 = type { i32, [1 x i64] }
%sollang.enum.t928 = type { i32, [1 x i64] }
%sollang.enum.t930 = type { i32, [3 x i64] }
%sollang.enum.t931 = type { i32, [5 x i64] }
%sollang.enum.t932 = type { i32, [2 x i64] }
%sollang.enum.t933 = type { i32, [14 x i64] }
%sollang.enum.t934 = type { i32, [2 x i64] }
%sollang.enum.t935 = type { i32, [32 x i64] }
%sollang.enum.t936 = type { i32, [4 x i64] }
%sollang.enum.t937 = type { i32, [2 x i64] }
%sollang.enum.t939 = type { i32, [5 x i64] }
%sollang.enum.t940 = type { i32, [2 x i64] }
%sollang.enum.t942 = type { i32, [0 x i64] }
%sollang.enum.t943 = type { i32, [0 x i64] }
%sollang.enum.t945 = type { i32, [4 x i64] }
%sollang.enum.t948 = type { i32, [1 x i64] }
%sollang.enum.t949 = type { i32, [1 x i64] }
%sollang.enum.t951 = type { i32, [2 x i64] }
%sollang.enum.t952 = type { i32, [5 x i64] }
%sollang.enum.t953 = type { i32, [2 x i64] }
%sollang.enum.t954 = type { i32, [2 x i64] }
%sollang.enum.t955 = type { i32, [32 x i64] }
%sollang.enum.t956 = type { i32, [2 x i64] }
%sollang.enum.t957 = type { i32, [4 x i64] }
%sollang.enum.t959 = type { i32, [2 x i64] }
%sollang.enum.t962 = type { i32, [1 x i64] }
%sollang.enum.t966 = type { i32, [2 x i64] }
%sollang.enum.t967 = type { i32, [4 x i64] }
%sollang.enum.t968 = type { i32, [2 x i64] }
%sollang.enum.t969 = type { i32, [2 x i64] }
%sollang.enum.t970 = type { i32, [2 x i64] }
%sollang.enum.t971 = type { i32, [2 x i64] }
%sollang.enum.t972 = type { i32, [2 x i64] }
%sollang.enum.t973 = type { i32, [0 x i64] }
%sollang.enum.t977 = type { i32, [2 x i64] }
%sollang.enum.t978 = type { i32, [3 x i64] }
%sollang.enum.t979 = type { i32, [2 x i64] }
%sollang.enum.t981 = type { i32, [1 x i64] }
%sollang.enum.t984 = type { i32, [3 x i64] }
%sollang.enum.t985 = type { i32, [4 x i64] }
%sollang.enum.t986 = type { i32, [9 x i64] }
%sollang.enum.t987 = type { i32, [2 x i64] }
%sollang.enum.t988 = type { i32, [32 x i64] }
%sollang.enum.t989 = type { i32, [3 x i64] }
%sollang.enum.t991 = type { i32, [5 x i64] }
%sollang.enum.t992 = type { i32, [2 x i64] }
%sollang.enum.t993 = type { i32, [0 x i64] }
%sollang.enum.t997 = type { i32, [10 x i64] }
%sollang.enum.t998 = type { i32, [11 x i64] }
%sollang.enum.t999 = type { i32, [2 x i64] }
%sollang.enum.t1000 = type { i32, [1 x i64] }
%sollang.enum.t1001 = type { i32, [0 x i64] }
%sollang.enum.t1003 = type { i32, [5 x i64] }
%sollang.enum.t1004 = type { i32, [3 x i64] }
%sollang.enum.t1005 = type { i32, [3 x i64] }
%sollang.enum.t1006 = type { i32, [0 x i64] }
%sollang.enum.t1010 = type { i32, [0 x i64] }
%sollang.enum.t1012 = type { i32, [10 x i64] }
%sollang.enum.t1013 = type { i32, [33 x i64] }
%sollang.enum.t1014 = type { i32, [35 x i64] }
%sollang.enum.t1015 = type { i32, [1 x i64] }
%sollang.enum.t1018 = type { i32, [1 x i64] }
%sollang.enum.t1019 = type { i32, [0 x i64] }
%sollang.enum.t1020 = type { i32, [0 x i64] }
%sollang.enum.t1026 = type { i32, [5 x i64] }
%sollang.enum.t1027 = type { i32, [3 x i64] }
%sollang.enum.t1028 = type { i32, [15 x i64] }
%sollang.enum.t1029 = type { i32, [3 x i64] }
%sollang.enum.t1030 = type { i32, [2 x i64] }
%sollang.enum.t1031 = type { i32, [3 x i64] }
%sollang.enum.t1036 = type { i32, [0 x i64] }
%sollang.enum.t1037 = type { i32, [0 x i64] }
%sollang.enum.t1039 = type { i32, [2 x i64] }
%sollang.enum.t1045 = type { i32, [7 x i64] }
%sollang.enum.t1046 = type { i32, [3 x i64] }
%sollang.enum.t1047 = type { i32, [3 x i64] }
%sollang.enum.t1048 = type { i32, [15 x i64] }
%sollang.enum.t1049 = type { i32, [25 x i64] }
%sollang.enum.t1050 = type { i32, [7 x i64] }
%sollang.enum.t1051 = type { i32, [5 x i64] }
%sollang.enum.t1052 = type { i32, [9 x i64] }
%sollang.enum.t1053 = type { i32, [31 x i64] }
%sollang.enum.t1054 = type { i32, [3 x i64] }
%sollang.enum.t1055 = type { i32, [8 x i64] }
%sollang.enum.t1059 = type { i32, [2 x i64] }
%sollang.enum.t1060 = type { i32, [2 x i64] }
%sollang.enum.t1061 = type { i32, [12 x i64] }
%sollang.enum.t1062 = type { i32, [6 x i64] }
%sollang.enum.t1064 = type { i32, [0 x i64] }
%sollang.enum.t1065 = type { i32, [0 x i64] }
%sollang.enum.t1069 = type { i32, [2 x i64] }
%sollang.enum.t1070 = type { i32, [9 x i64] }
%sollang.enum.t1071 = type { i32, [6 x i64] }
%sollang.enum.t1073 = type { i32, [2 x i64] }
%sollang.enum.t1075 = type { i32, [8 x i64] }
%sollang.enum.t1079 = type { i32, [3 x i64] }
%sollang.enum.t1080 = type { i32, [26 x i64] }
%sollang.enum.t1081 = type { i32, [4 x i64] }
%sollang.enum.t1082 = type { i32, [5 x i64] }
%sollang.enum.t1083 = type { i32, [8 x i64] }
%sollang.enum.t1084 = type { i32, [40 x i64] }
%sollang.enum.t1085 = type { i32, [9 x i64] }
%sollang.enum.t1086 = type { i32, [3 x i64] }
%sollang.enum.t1090 = type { i32, [10 x i64] }
%sollang.enum.t1091 = type { i32, [5 x i64] }
%sollang.enum.t1092 = type { i32, [3 x i64] }
%sollang.enum.t1095 = type { i32, [8 x i64] }
%sollang.enum.t1102 = type { i32, [2 x i64] }
%sollang.enum.t1103 = type { i32, [4 x i64] }
%sollang.enum.t1113 = type { i32, [2 x i64] }
%sollang.enum.t1114 = type { i32, [9 x i64] }
%sollang.enum.t1115 = type { i32, [3 x i64] }
%sollang.enum.t1116 = type { i32, [7 x i64] }
%sollang.enum.t1117 = type { i32, [11 x i64] }
%sollang.enum.t1118 = type { i32, [7 x i64] }
%sollang.enum.t1129 = type { i32, [6 x i64] }
%sollang.enum.t1131 = type { i32, [11 x i64] }
%sollang.enum.t1132 = type { i32, [18 x i64] }
%sollang.enum.t1134 = type { i32, [149 x i64] }
%sollang.enum.t1135 = type { i32, [3 x i64] }
%sollang.enum.t1136 = type { i32, [2 x i64] }
%sollang.enum.t1147 = type { i32, [2 x i64] }
%sollang.enum.t1148 = type { i32, [2 x i64] }
%sollang.enum.t1150 = type { i32, [12 x i64] }
%sollang.enum.t1151 = type { i32, [9 x i64] }
%sollang.enum.t1152 = type { i32, [5 x i64] }
%sollang.enum.t1153 = type { i32, [5 x i64] }
%sollang.enum.t1154 = type { i32, [6 x i64] }
%sollang.enum.t1155 = type { i32, [6 x i64] }
%sollang.enum.t1156 = type { i32, [2 x i64] }
%sollang.enum.t1160 = type { i32, [14 x i64] }
%sollang.enum.t1167 = type { i32, [6 x i64] }
%sollang.enum.t1168 = type { i32, [6 x i64] }
%sollang.enum.t1169 = type { i32, [0 x i64] }
%sollang.enum.t1170 = type { i32, [0 x i64] }
%sollang.enum.t1173 = type { i32, [4 x i64] }
%sollang.enum.t1174 = type { i32, [5 x i64] }
%sollang.enum.t1175 = type { i32, [4 x i64] }
%sollang.enum.t1176 = type { i32, [21 x i64] }
%sollang.enum.t1177 = type { i32, [4 x i64] }
%sollang.enum.t1178 = type { i32, [5 x i64] }
%sollang.enum.t1181 = type { i32, [2 x i64] }
%sollang.enum.t1183 = type { i32, [3 x i64] }
%sollang.enum.t1184 = type { i32, [4 x i64] }
%sollang.enum.t1185 = type { i32, [2 x i64] }
%sollang.enum.t1186 = type { i32, [0 x i64] }
%sollang.enum.t1188 = type { i32, [6 x i64] }
%sollang.enum.t1191 = type { i32, [5 x i64] }
%sollang.enum.t1192 = type { i32, [5 x i64] }
%sollang.enum.t1195 = type { i32, [16 x i64] }
%sollang.enum.t1196 = type { i32, [7 x i64] }
%sollang.enum.t1197 = type { i32, [6 x i64] }
%sollang.enum.t1198 = type { i32, [0 x i64] }
%sollang.enum.t1199 = type { i32, [4 x i64] }
%sollang.enum.t1201 = type { i32, [5 x i64] }
%sollang.enum.t1202 = type { i32, [2 x i64] }
%sollang.enum.t1204 = type { i32, [2 x i64] }
%sollang.enum.t1206 = type { i32, [4 x i64] }
%sollang.enum.t1209 = type { i32, [9 x i64] }
%sollang.enum.t1211 = type { i32, [4 x i64] }
%sollang.enum.t1254 = type { i32, [3 x i64] }
%sollang.struct.m0_s10 = type {  }
%sollang.struct.m0_s8 = type { %sollang.enum.t32 }
%sollang.struct.m0_s14 = type { i32, i32 }
%sollang.struct.m0_s11 = type { i32, i1 }
%sollang.struct.m1_s7 = type { %sollang.enum.t99, i64 }
%sollang.struct.m1_s38 = type { %sollang.array.i32, i32, i32 }
%sollang.struct.m1_s42 = type { %sollang.array.i32, i32 }
%sollang.struct.m1_s29 = type { i32, i32 }
%sollang.struct.m1_s32 = type { %sollang.array.i32, i32, %sollang.array.i32, i32, i32 }
%sollang.struct.m1_s26 = type { i32, %sollang.enum.t100 }
%sollang.struct.m2_s6 = type { %sollang.text, %sollang.text }
%sollang.struct.m2_s9 = type { %sollang.text }
%sollang.struct.m2_s19 = type { %sollang.enum.t125 }
%sollang.struct.m2_s11 = type { %sollang.enum.t125, %sollang.text }
%sollang.struct.m3_s0 = type { i8, i8, i8, i8 }
%sollang.struct.m3_s8 = type { i16, i16, i16, i16, i16, i16, i16, i16 }
%sollang.struct.m3_s5 = type { %sollang.struct.m3_s0, i16 }
%sollang.struct.m3_s17 = type { %sollang.struct.m3_s8, i16, i32, i32 }
%sollang.struct.m3_s28 = type { %sollang.enum.t137, i64 }
%sollang.struct.m4_s19 = type { i32, i32, i32 }
%sollang.struct.m4_s27 = type { %sollang.enum.t146, i64, i1 }
%sollang.struct.m4_s16 = type { %sollang.enum.t145, i64 }
%sollang.struct.m4_s31 = type { %sollang.source_text, i64, i64, i32, i1, %sollang.struct.m4_s19, %sollang.struct.m4_s27 }
%sollang.struct.m4_s23 = type { %sollang.enum.t146, i64, i64 }
%sollang.struct.m6_s2 = type { i64, i64 }
%sollang.struct.m6_s5 = type { i64 }
%sollang.struct.m6_s0 = type { i64 }
%sollang.struct.m6_s38 = type { %sollang.array.i32, %sollang.struct.m6_s0, i64, %sollang.enum.t174 }
%sollang.struct.m6_s59 = type { %sollang.enum.t176 }
%sollang.struct.m6_s7 = type { i64, i64, i64 }
%sollang.struct.m6_s11 = type { i8 }
%sollang.struct.m6_s13 = type { i8 }
%sollang.struct.m6_s15 = type { i64, i64 }
%sollang.struct.m6_s18 = type { i64 }
%sollang.struct.m6_s22 = type { %sollang.struct.m6_s5 }
%sollang.struct.m6_s24 = type { i64 }
%sollang.struct.m6_s20 = type { %sollang.struct.m6_s2 }
%sollang.struct.m6_s30 = type { %sollang.struct.m6_s0, %sollang.enum.t173, %sollang.struct.m6_s0 }
%sollang.struct.m6_s43 = type { %sollang.struct.m6_s38, %sollang.struct.m6_s2, %sollang.struct.m6_s2, i64 }
%sollang.struct.m7_s7 = type { i64, i64, i1 }
%sollang.struct.m7_s14 = type { %sollang.struct.m7_s7, %sollang.enum.t201, %sollang.enum.t202, %sollang.struct.m7_s7 }
%sollang.struct.m7_s29 = type { i1, i1, i1, i1, i1 }
%sollang.struct.m7_s22 = type { %sollang.source_text, %sollang.struct.m7_s7, %sollang.enum.t204, %sollang.struct.m7_s7, %sollang.struct.m7_s7, %sollang.struct.m7_s7 }
%sollang.struct.m7_s0 = type { %sollang.enum.t199, i64 }
%sollang.struct.m30_s2 = type { i8 }
%sollang.struct.m8_s8 = type { { ptr, i64 } }
%sollang.struct.m8_s0 = type { %sollang.enum.t215, i64 }
%sollang.struct.m8_s10 = type { i8 }
%sollang.struct.m8_s12 = type { %sollang.struct.m6_s13, %sollang.struct.m30_s2 }
%sollang.struct.m12_s0 = type { %sollang.array.i32, %sollang.enum.t150 }
%sollang.struct.m9_s0 = type { %sollang.array.i32, i64 }
%sollang.struct.m9_s3 = type { %sollang.struct.m12_s0, %sollang.enum.t227 }
%sollang.struct.m10_s0 = type { i64 }
%sollang.struct.m10_s2 = type { i64 }
%sollang.struct.m10_s13 = type { %sollang.struct.m10_s0, %sollang.array.i32, i64, i1 }
%sollang.struct.m10_s18 = type { %sollang.struct.m10_s0, %sollang.array.i32, %sollang.enum.t236 }
%sollang.struct.m10_s22 = type { %sollang.struct.m10_s2, %sollang.array.i32, i64 }
%sollang.struct.m10_s26 = type { %sollang.struct.m10_s2, %sollang.array.i32, %sollang.enum.t236 }
%sollang.struct.m10_s4 = type { %sollang.text, %sollang.text }
%sollang.struct.m12_s8 = type { %sollang.struct.m12_s0, %sollang.enum.t227, i64, i64 }
%sollang.struct.m12_s3 = type { %sollang.array.i32, i8, i64, i64 }
%sollang.struct.m13_s30 = type { i32 }
%sollang.struct.m13_s0 = type { %sollang.text, %sollang.text, i1 }
%sollang.struct.m13_s32 = type { i32 }
%sollang.struct.m13_s37 = type { i64 }
%sollang.struct.m13_s21 = type { %sollang.array.i32, %sollang.text, i1, %sollang.array.i32, i1, %sollang.enum.t263, %sollang.enum.t264, %sollang.enum.t264 }
%sollang.struct.m13_s12 = type { i64, i64 }
%sollang.struct.m13_s15 = type { %sollang.struct.m13_s30, %sollang.array.i32, %sollang.array.i32, i1, i1 }
%sollang.struct.m13_s39 = type { i64, %sollang.struct.m13_s37, i32, i32 }
%sollang.struct.m13_s44 = type { i32, i32 }
%sollang.struct.m16_s3 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m19_s62 = type { %sollang.struct.m19_s19 }
%sollang.struct.m16_s11 = type { i32, i32, i32 }
%sollang.struct.m39_s3 = type { %sollang.enum.t484, i32 }
%sollang.struct.m16_s0 = type { %sollang.enum.t276, i64 }
%sollang.struct.m16_s46 = type { i32, i32, i32, i32, i32, i32, i32, i32 }
%sollang.struct.m16_s9 = type { %sollang.struct.m16_s3 }
%sollang.struct.m16_s15 = type { %sollang.struct.m16_s3, %sollang.enum.t278, i32, %sollang.array.i32, %sollang.array.i32, i32, i32, i32, %sollang.array.i32, i32, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m16_s11, i32, %sollang.struct.m39_s3, %sollang.array.i32, %sollang.array.i32, i32, i32, i32, %sollang.array.i32, i32, i32, %sollang.array.i32, i32, i1, %sollang.struct.m16_s0 }
%sollang.struct.m16_s55 = type { %sollang.struct.m16_s46, %sollang.enum.t284, i32, i32, i32, i32, i32, i32, %sollang.struct.m39_s3, %sollang.array.i32 }
%sollang.struct.m19_s0 = type { %sollang.enum.t347, i64 }
%sollang.struct.m17_s22 = type { %sollang.text, %sollang.text, i32, i64, i32, i32 }
%sollang.struct.m17_s46 = type { i64 }
%sollang.struct.m17_s20 = type { i32 }
%sollang.struct.m17_s29 = type { i64, %sollang.enum.t308, %sollang.enum.t295, %sollang.enum.t296, %sollang.enum.t308, i64, %sollang.enum.t309 }
%sollang.struct.m17_s37 = type { i64, i64, i64, i1 }
%sollang.struct.m17_s42 = type { i64, i64, i64 }
%sollang.struct.m17_s48 = type { %sollang.struct.m17_s46, %sollang.enum.t299 }
%sollang.struct.m18_s3 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m82_s26 = type { i64, i32, i32 }
%sollang.struct.m75_s10 = type { %sollang.struct.m81_s6, %sollang.struct.m77_s7, %sollang.struct.m85_s8, i32, i32, i32 }
%sollang.struct.m76_s26 = type { %sollang.struct.m75_s10, %sollang.struct.m76_s3, i32, %sollang.array.i32, %sollang.enum.t914 }
%sollang.struct.m18_s0 = type { %sollang.enum.t317, i64 }
%sollang.struct.m18_s9 = type { %sollang.struct.m18_s3 }
%sollang.struct.m18_s11 = type { i32, i32, i32, i32, i32, i32, i1 }
%sollang.struct.m18_s19 = type { i32, i32, i32, i32, i32, i32, %sollang.enum.t319, %sollang.struct.m82_s26, %sollang.struct.m75_s10, %sollang.struct.m76_s26, i32, i1, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m18_s0 }
%sollang.struct.m74_s7 = type { %sollang.struct.m75_s168, i32, i32, i32, i32 }
%sollang.struct.m75_s168 = type { %sollang.array.i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.struct.m82_s12 }
%sollang.struct.m18_s38 = type { i32, i32 }
%sollang.struct.m18_s41 = type { i32, i32 }
%sollang.struct.m18_s44 = type { i32, i32 }
%sollang.struct.m18_s47 = type { i1, i64 }
%sollang.struct.m82_s12 = type { i32, i32 }
%sollang.struct.m19_s3 = type { i32, i32 }
%sollang.struct.m19_s76 = type { i32, i32 }
%sollang.struct.m19_s6 = type { %sollang.struct.m19_s3 }
%sollang.struct.m19_s93 = type { %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i32 }
%sollang.struct.m19_s19 = type { %sollang.struct.m19_s6, i32, i32, i32, i32, i32, i32, %sollang.enum.t351, i32, i32, i32, i32, i32, i32, i32, i1, i32, i32, i32, i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.struct.m19_s93, %sollang.struct.m19_s93, %sollang.struct.m19_s93, i32, i32, i32, i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, i32, i1, %sollang.struct.m19_s0, i1, i1 }
%sollang.struct.m19_s73 = type { i32, i32 }
%sollang.struct.m19_s11 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.m19_s76 }
%sollang.struct.m19_s106 = type { i32, %sollang.array.i32 }
%sollang.struct.m19_s64 = type { i32, i32, i32 }
%sollang.struct.m19_s68 = type { i32, i32, i32, i32 }
%sollang.struct.m19_s99 = type { %sollang.struct.m19_s93, %sollang.struct.m19_s93 }
%sollang.struct.m19_s102 = type { %sollang.struct.m19_s73, i32, %sollang.array.i32 }
%sollang.struct.m19_s119 = type { i1, i32 }
%sollang.struct.m19_s111 = type { i32 }
%sollang.struct.m19_s113 = type { i1, i32 }
%sollang.struct.m19_s79 = type { i32, i32 }
%sollang.struct.m19_s82 = type { i32, i32, i32 }
%sollang.struct.m19_s86 = type { i32, i32, i32 }
%sollang.struct.m19_s90 = type { i32, i32 }
%sollang.struct.m19_s109 = type { i32 }
%sollang.struct.m19_s116 = type { i1, i32 }
%sollang.struct.m19_s8 = type { i32, i32 }
%sollang.struct.m91_s2 = type { %sollang.array.i32, i32 }
%sollang.struct.m90_s2 = type { %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i32 }
%sollang.struct.m20_s16 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m20_s22 = type { i1 }
%sollang.struct.m40_s2 = type { i64, i64, i64, i64, i64, i64, i64, { ptr, i64 }, i32 }
%sollang.struct.m20_s0 = type { %sollang.enum.t389, i64 }
%sollang.struct.m20_s24 = type { %sollang.struct.m20_s16, %sollang.struct.m20_s22 }
%sollang.struct.m20_s27 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.m40_s2 }
%sollang.struct.m20_s35 = type { i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t395, i64, i32, i32, i32, i32, i32, i1, i64, i1, %sollang.struct.m40_s2, i32, i32, i32, i32, i1, %sollang.array.i32, %sollang.struct.m91_s2, i1, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m20_s0 }
%sollang.struct.m20_s3 = type { %sollang.array.i32, %sollang.struct.m91_s2, i1, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32 }
%sollang.struct.m21_s2 = type { %sollang.array.i32 }
%sollang.struct.m21_s4 = type { { ptr, i64 } }
%sollang.struct.m22_s6 = type { { ptr, i64 } }
%sollang.struct.m22_s3 = type { %sollang.struct.m21_s2, { ptr, i64 } }
%sollang.struct.m22_s0 = type { %sollang.array.i32, { ptr, i64 } }
%sollang.struct.m25_s2 = type { { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 } }
%sollang.struct.m25_s0 = type { %sollang.enum.t417 }
%sollang.struct.m31_s89 = type { { ptr, i64 }, { ptr, i64 }, i32, i64 }
%sollang.struct.m29_s8 = type { %sollang.struct.m31_s89, %sollang.struct.m31_s89 }
%sollang.struct.m34_s5 = type { { ptr, i64 }, { ptr, i64 }, { ptr, i64 } }
%sollang.struct.m34_s0 = type { { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 } }
%sollang.struct.m34_s9 = type { { ptr, i64 }, { ptr, i64 }, { ptr, i64 } }
%sollang.struct.m36_s9 = type { %sollang.enum.t443, %sollang.enum.t444 }
%sollang.struct.m36_s0 = type { %sollang.enum.t442, i64 }
%sollang.struct.m36_s3 = type { i32, i32 }
%sollang.struct.m36_s6 = type { i32, i32 }
%sollang.struct.m36_s12 = type { %sollang.struct.m36_s9, i32, i32, i64, i8, i8, i32 }
%sollang.struct.m36_s20 = type { %sollang.struct.m36_s9, i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.m36_s35 = type { i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.m37_s3 = type { %sollang.enum.t460, i64 }
%sollang.struct.m37_s6 = type { %sollang.enum.t461, i64 }
%sollang.struct.m37_s9 = type { %sollang.enum.t461, i32, i32 }
%sollang.struct.m38_s9 = type { i1 }
%sollang.struct.m38_s0 = type { %sollang.enum.t470, i64 }
%sollang.struct.m38_s3 = type { i32, i32 }
%sollang.struct.m38_s6 = type { i32, i32 }
%sollang.struct.m38_s11 = type { %sollang.struct.m38_s9, i32, i32, i64 }
%sollang.struct.m38_s16 = type { i32, i32, i64, i32, i64 }
%sollang.struct.m40_s0 = type { i64 }
%sollang.struct.m41_s24 = type { %sollang.array.i32, i32, i32, i32, i1 }
%sollang.struct.m41_s30 = type { %sollang.struct.m41_s24, %sollang.array.i32, i32, i1 }
%sollang.struct.m41_s35 = type { %sollang.struct.m41_s24, %sollang.array.i32, %sollang.enum.t486 }
%sollang.struct.m41_s39 = type { %sollang.struct.m41_s24, %sollang.array.i32, i32, i1 }
%sollang.struct.m41_s44 = type { %sollang.struct.m41_s24, %sollang.array.i32, %sollang.enum.t486 }
%sollang.struct.m41_s5 = type { i1 }
%sollang.struct.m41_s7 = type { %sollang.struct.m1_s38, %sollang.array.i32, i32, i1 }
%sollang.struct.m41_s12 = type { %sollang.struct.m1_s38, %sollang.array.i32, %sollang.enum.t486 }
%sollang.struct.m41_s16 = type { %sollang.struct.m1_s42, %sollang.array.i32, i32 }
%sollang.struct.m41_s20 = type { %sollang.struct.m1_s42, %sollang.array.i32, %sollang.enum.t486 }
%sollang.struct.m42_s0 = type { %sollang.struct.m10_s0, i64 }
%sollang.struct.m42_s3 = type { %sollang.struct.m10_s2, i64 }
%sollang.struct.m42_s6 = type { %sollang.struct.m42_s0, %sollang.array.i32, i32, i1 }
%sollang.struct.m42_s11 = type { %sollang.struct.m42_s0, %sollang.array.i32, %sollang.enum.t236 }
%sollang.struct.m42_s15 = type { %sollang.struct.m42_s3, %sollang.array.i32, i32 }
%sollang.struct.m42_s19 = type { %sollang.struct.m42_s3, %sollang.array.i32, %sollang.enum.t236 }
%sollang.struct.m1_s13 = type {  }
%sollang.struct.m1_s17 = type {  }
%sollang.struct.m48_s52 = type { i64 }
%sollang.struct.m48_s9 = type { i64 }
%sollang.struct.m48_s188 = type { %sollang.enum.t653, i32 }
%sollang.struct.m43_s0 = type { %sollang.struct.m48_s52, i64 }
%sollang.struct.m48_s62 = type { i64, %sollang.enum.t649, %sollang.array.i32, i64, i64, %sollang.enum.t650, %sollang.enum.t275, %sollang.enum.t662, %sollang.enum.t308 }
%sollang.struct.m43_s6 = type { %sollang.struct.m43_s0, %sollang.array.i32, i64, i1 }
%sollang.struct.m43_s11 = type { %sollang.struct.m43_s0, %sollang.array.i32, %sollang.struct.m48_s188 }
%sollang.struct.m43_s15 = type { %sollang.struct.m43_s0, %sollang.array.i32, i64 }
%sollang.struct.m43_s19 = type { %sollang.struct.m43_s0, %sollang.array.i32, %sollang.struct.m48_s188 }
%sollang.struct.m43_s3 = type { %sollang.struct.m48_s9, %sollang.struct.m48_s188 }
%sollang.struct.m44_s17 = type { %sollang.enum.t528, i64, i64 }
%sollang.struct.m44_s14 = type { %sollang.enum.t527, i32 }
%sollang.struct.m45_s12 = type { i64, i64 }
%sollang.struct.m45_s6 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m45_s15 = type { %sollang.struct.m45_s12, %sollang.struct.m45_s12 }
%sollang.struct.m45_s3 = type { %sollang.enum.t531, i64 }
%sollang.struct.m45_s18 = type { %sollang.struct.m45_s6 }
%sollang.struct.m45_s20 = type { %sollang.source_text, %sollang.struct.m45_s12, %sollang.struct.m45_s12, %sollang.enum.t534, %sollang.array.i32, i64 }
%sollang.struct.m45_s27 = type { %sollang.source_text, %sollang.enum.t534, i32, %sollang.struct.m45_s12, %sollang.array.i32, i64 }
%sollang.struct.m45_s34 = type { %sollang.array.i32, i64 }
%sollang.struct.m48_s11 = type { i64 }
%sollang.struct.m47_s97 = type { i64, i64 }
%sollang.struct.m48_s168 = type { %sollang.enum.t139, %sollang.array.i32, i1 }
%sollang.struct.m47_s12 = type { i64, i64, i64, i64 }
%sollang.struct.m47_s3 = type { { ptr, i64 } }
%sollang.struct.m47_s17 = type { i64, i64, i32, i32, i32, i64, %sollang.struct.m47_s12 }
%sollang.struct.m103_s0 = type { i1, i32, { ptr, i64 }, %sollang.struct.m127_s0 }
%sollang.struct.m117_s3 = type { %sollang.array.i32, i64 }
%sollang.struct.m107_s8 = type { i64, i64, i64 }
%sollang.struct.m107_s12 = type { i64, i64 }
%sollang.struct.m107_s15 = type { %sollang.array.i32 }
%sollang.struct.m107_s17 = type { i64, i64 }
%sollang.struct.m115_s13 = type { %sollang.array.i32 }
%sollang.struct.m111_s0 = type { i1, i64, i64, i64, i64 }
%sollang.struct.m111_s6 = type { i64, i64, i64, i64, i1 }
%sollang.struct.m118_s22 = type { i64, i64, i64, i64, i64 }
%sollang.struct.m118_s31 = type { i1, i64, i64, i1, i1, i64, i64, i64, i64, i64, i64, i32, %sollang.array.i32, i32, i32, i32, i32, %sollang.array.i32, i32, i32, i32 }
%sollang.struct.m118_s17 = type { i64, i64, i1, i64 }
%sollang.struct.m118_s11 = type { i64, i64, i64, i1, i64 }
%sollang.struct.m47_s75 = type { %sollang.struct.m118_s17, i1, i1, i64 }
%sollang.struct.m47_s80 = type { %sollang.struct.m118_s11, i1, i1, i64, i1, i64 }
%sollang.struct.m47_s5 = type { %sollang.struct.m48_s11, %sollang.enum.t139, i1, %sollang.array.i32, %sollang.array.i32, i64 }
%sollang.struct.m47_s100 = type { i64, i8 }
%sollang.struct.m47_s0 = type { %sollang.enum.t550, i64 }
%sollang.struct.m106_s18 = type { %sollang.enum.t550, i64 }
%sollang.struct.m47_s172 = type { %sollang.array.i32, i64 }
%sollang.struct.m109_s0 = type { i32, %sollang.array.i32, %sollang.array.i32, i64, %sollang.array.i32 }
%sollang.struct.m123_s6 = type { { ptr, i64 }, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, { ptr, i64 }, %sollang.array.i32 }
%sollang.struct.m123_s13 = type { { ptr, i64 }, %sollang.array.i32, { ptr, i64 } }
%sollang.struct.m47_s30 = type { %sollang.array.i32, %sollang.enum.t139, %sollang.enum.t139, i1, i32, { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, %sollang.struct.m103_s0, %sollang.struct.m103_s0, i64, i64, i1, { ptr, i64 }, %sollang.array.i32, { ptr, i64 }, %sollang.array.i32, i1, i1, %sollang.array.i32, %sollang.struct.m117_s3, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i64, i32, i64, i1, i1, %sollang.struct.m115_s13, %sollang.struct.m111_s0, %sollang.struct.m111_s6, %sollang.struct.m118_s22, %sollang.struct.m118_s31, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.m109_s6 = type { %sollang.array.i32, i64, %sollang.array.i32 }
%sollang.struct.m125_s0 = type { %sollang.enum.t1198, %sollang.struct.m126_s0 }
%sollang.struct.m123_s17 = type { %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m108_s0 = type { i32, i64, i64, %sollang.array.i32, i64 }
%sollang.struct.m121_s0 = type { %sollang.enum.t1186, %sollang.struct.m126_s0, { ptr, i64 } }
%sollang.struct.m128_s0 = type { i64, %sollang.array.i32, i64 }
%sollang.struct.m130_s0 = type { i32, %sollang.array.i32 }
%sollang.struct.m47_s110 = type { i64, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.m47_s25 = type { %sollang.struct.m47_s3, %sollang.enum.t139, %sollang.struct.m47_s17, i1 }
%sollang.struct.m47_s87 = type { i64, %sollang.struct.m47_s75, %sollang.struct.m47_s80 }
%sollang.struct.m47_s91 = type { i64, %sollang.struct.m47_s75 }
%sollang.struct.m47_s94 = type { i64, %sollang.struct.m47_s80 }
%sollang.struct.m103_s9 = type { i64, i1, %sollang.array.i32 }
%sollang.struct.m107_s42 = type { i64, i64, i64, %sollang.array.i32 }
%sollang.struct.m107_s3 = type { i64, i64, i1, %sollang.array.i32 }
%sollang.struct.m48_s17 = type { %sollang.array.i32 }
%sollang.struct.m48_s7 = type { i64 }
%sollang.struct.m48_s85 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s62 }
%sollang.struct.m48_s96 = type { %sollang.struct.m48_s62, %sollang.struct.m48_s188 }
%sollang.struct.m48_s92 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s62, %sollang.struct.m48_s188 }
%sollang.struct.m48_s48 = type { i64, i64, i64 }
%sollang.struct.m48_s39 = type { i64, %sollang.enum.t647, %sollang.enum.t648 }
%sollang.struct.m48_s143 = type { i64, %sollang.array.i32 }
%sollang.struct.m48_s43 = type { i64, i1, i1, i1 }
%sollang.struct.m48_s0 = type { %sollang.enum.t139, i32, i1 }
%sollang.struct.m48_s4 = type { %sollang.enum.t139, i1 }
%sollang.struct.m48_s13 = type { ptr, i64, i64 }
%sollang.struct.m48_s72 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s9, %sollang.struct.m48_s188 }
%sollang.struct.m48_s76 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s9 }
%sollang.struct.m48_s79 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s188 }
%sollang.struct.m48_s172 = type { %sollang.enum.t139, i64, i1 }
%sollang.struct.m49_s34 = type { %sollang.enum.t676, i32 }
%sollang.struct.m49_s24 = type { i32, i32, i32, i32 }
%sollang.struct.m49_s29 = type { i32, i32, i32, i32 }
%sollang.struct.m49_s20 = type { %sollang.enum.t675, i64, i32 }
%sollang.struct.m49_s42 = type { %sollang.source_text, i64, i64, i32, i32, i1, %sollang.struct.m49_s34, %sollang.struct.m49_s24 }
%sollang.struct.m49_s51 = type { %sollang.struct.m49_s29, i32, i32, i32, i32 }
%sollang.struct.m49_s57 = type { i64, i64, i64, i32, i1, i1 }
%sollang.struct.m49_s37 = type { i32, i32, i32, i1 }
%sollang.struct.m50_s10 = type { %sollang.enum.t693, i64, i64 }
%sollang.struct.m50_s0 = type { i32, i32, i32 }
%sollang.struct.m50_s14 = type { %sollang.source_text, i64, i32, i32 }
%sollang.struct.m51_s35 = type { %sollang.array.i32, i32 }
%sollang.struct.m51_s38 = type { %sollang.enum.t701, i64, i64, i1, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m51_s15 = type { i32, i32, i32, i32 }
%sollang.struct.m51_s20 = type { %sollang.enum.t700, i64, i64, i64, i64, i32, i32 }
%sollang.struct.m51_s12 = type { %sollang.enum.t699, i64 }
%sollang.struct.m51_s49 = type { %sollang.source_text, i64, i64, i8, i32, %sollang.struct.m51_s15, %sollang.array.i32 }
%sollang.struct.m51_s110 = type { i64, i64, i32 }
%sollang.struct.m51_s57 = type { %sollang.array.i32, i32, i32, i32, i8, %sollang.array.i32 }
%sollang.struct.m51_s46 = type { %sollang.array.i32, i32 }
%sollang.struct.m52_s17 = type { %sollang.enum.t729, i64, i64, i64 }
%sollang.struct.m52_s61 = type { i32 }
%sollang.struct.m52_s58 = type { i8, i64 }
%sollang.struct.m52_s50 = type { %sollang.enum.t731, i64, i64, i64, i1, %sollang.enum.t730, i64 }
%sollang.struct.m52_s0 = type { i32, i32, i32, i32 }
%sollang.struct.m52_s25 = type { %sollang.source_text, i64, i64, i32, i32, i1, i1, i32, i32 }
%sollang.struct.m52_s22 = type { i64, i64 }
%sollang.struct.m54_s3 = type { i32, i32 }
%sollang.struct.m54_s0 = type { %sollang.enum.t747, i64 }
%sollang.struct.m54_s6 = type { %sollang.enum.t748 }
%sollang.struct.m57_s20 = type { i32, %sollang.enum.t756 }
%sollang.struct.m57_s17 = type { %sollang.enum.t755, i32 }
%sollang.struct.m57_s0 = type { i32, i32, i32, i32, %sollang.enum.t754 }
%sollang.struct.m83_s5 = type { i32 }
%sollang.struct.m74_s0 = type { %sollang.enum.t329, i64 }
%sollang.struct.m74_s13 = type { %sollang.array.i32, %sollang.struct.m82_s12 }
%sollang.struct.m74_s63 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m82_s15 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m74_s28 = type { %sollang.struct.m75_s168, %sollang.struct.m83_s5, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i32, i32, %sollang.enum.t811, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t811 }
%sollang.struct.m74_s58 = type { %sollang.array.i32 }
%sollang.struct.m75_s159 = type { i32, i32, %sollang.enum.t847, %sollang.enum.t847 }
%sollang.struct.m82_s9 = type { %sollang.array.i32, i32 }
%sollang.struct.m74_s3 = type { i32, i32, i32 }
%sollang.struct.m81_s6 = type { %sollang.struct.m82_s6, i32 }
%sollang.struct.m77_s7 = type { %sollang.struct.m81_s6, i32, i32 }
%sollang.struct.m85_s8 = type { %sollang.struct.m81_s6, i32, i32, i32 }
%sollang.struct.m75_s49 = type { i32, i32, i32, i32, i32, %sollang.enum.t844, i32, i32 }
%sollang.struct.m75_s76 = type { %sollang.struct.m81_s6, i32, i32, %sollang.enum.t846, i32, i32, i32, i32, %sollang.enum.t847, %sollang.enum.t847 }
%sollang.struct.m75_s111 = type { %sollang.array.i32, i32, i32, i32, %sollang.array.i32, i32 }
%sollang.struct.m77_s29 = type { %sollang.struct.m81_s6, i32, i32, i32, %sollang.enum.t922, i32, i32, i32, %sollang.array.i32, %sollang.enum.t923 }
%sollang.struct.m75_s134 = type { %sollang.array.i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i32, i32 }
%sollang.struct.m85_s16 = type { %sollang.struct.m81_s6, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.array.i32 }
%sollang.struct.m75_s0 = type { %sollang.enum.t328, i64 }
%sollang.struct.m75_s180 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m75_s183 = type { %sollang.struct.m75_s159, %sollang.struct.m82_s12 }
%sollang.struct.m81_s35 = type { %sollang.struct.m82_s6, i32, i32, i32, %sollang.enum.t943, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.struct.m81_s17, %sollang.array.i32, i32, i32, i32, %sollang.enum.t945, i32, i32, i32, i32, i32, i32, %sollang.enum.t945 }
%sollang.struct.m75_s97 = type { %sollang.struct.m75_s10, %sollang.struct.m75_s76, %sollang.enum.t849, i32, %sollang.array.i32, i32, i32, %sollang.array.i32 }
%sollang.struct.m75_s122 = type { %sollang.struct.m75_s111, %sollang.struct.m77_s29, %sollang.enum.t852, %sollang.array.i32, %sollang.array.i32, i32, i32 }
%sollang.struct.m75_s149 = type { %sollang.struct.m75_s134, %sollang.struct.m85_s16, %sollang.enum.t855, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m75_s164 = type { i32, i32, %sollang.struct.m82_s12 }
%sollang.struct.m81_s9 = type { %sollang.struct.m82_s9, %sollang.struct.m82_s12 }
%sollang.struct.m77_s11 = type { %sollang.array.i32, i32, %sollang.struct.m82_s12 }
%sollang.struct.m85_s13 = type { %sollang.array.i32, %sollang.struct.m82_s12 }
%sollang.struct.m75_s34 = type { %sollang.enum.t843, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t844, i32, i32 }
%sollang.struct.m75_s3 = type { i32, i32, i32, i32, i32, i32 }
%sollang.struct.m76_s7 = type { %sollang.struct.m75_s97, %sollang.struct.m81_s35 }
%sollang.struct.m76_s10 = type { %sollang.struct.m75_s122, %sollang.struct.m81_s35 }
%sollang.struct.m76_s13 = type { %sollang.struct.m75_s149, %sollang.struct.m81_s35 }
%sollang.struct.m76_s3 = type { i32, i32, i32 }
%sollang.struct.m76_s0 = type { %sollang.enum.t317, i64 }
%sollang.struct.m77_s0 = type { %sollang.enum.t871, i64 }
%sollang.struct.m77_s50 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m77_s44 = type { %sollang.array.i32, i32 }
%sollang.struct.m77_s3 = type { i32, i32, i32 }
%sollang.struct.m82_s6 = type { i32, i32 }
%sollang.struct.m81_s17 = type { %sollang.enum.t942, i32 }
%sollang.struct.m81_s0 = type { %sollang.enum.t870, i64 }
%sollang.struct.m81_s62 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m81_s3 = type { i32, i32 }
%sollang.struct.m82_s18 = type { i32, i32 }
%sollang.struct.m82_s0 = type { %sollang.enum.t819, i64 }
%sollang.struct.m82_s33 = type { i32, i32 }
%sollang.struct.m82_s3 = type { i32, i32 }
%sollang.struct.m82_s24 = type { i32 }
%sollang.struct.m83_s0 = type { %sollang.enum.t820, i64 }
%sollang.struct.m83_s29 = type { i32, %sollang.enum.t973, i32 }
%sollang.struct.m83_s3 = type { i32 }
%sollang.struct.m85_s0 = type { %sollang.enum.t872, i64 }
%sollang.struct.m85_s30 = type { %sollang.array.i32 }
%sollang.struct.m85_s3 = type { i32, i32, i32, i32 }
%sollang.struct.m90_s7 = type { %sollang.struct.m90_s2, i32 }
%sollang.struct.m90_s12 = type { i32, i32, i32 }
%sollang.struct.m90_s10 = type { i32 }
%sollang.struct.m91_s5 = type { %sollang.struct.m91_s2, i32 }
%sollang.struct.m92_s9 = type { %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32, i32 }
%sollang.struct.m92_s24 = type { %sollang.array.i32, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32 }
%sollang.struct.m92_s6 = type { i32, i32 }
%sollang.struct.m92_s20 = type { i32, i32, i32 }
%sollang.struct.m97_s0 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m97_s6 = type { %sollang.struct.m97_s0 }
%sollang.struct.m97_s17 = type { %sollang.enum.t1018, %sollang.struct.m97_s0 }
%sollang.struct.m97_s42 = type { %sollang.struct.m97_s0, %sollang.enum.t1019, %sollang.enum.t1020, i64, i64, i64, i64, %sollang.array.i32, i1, i64, i32 }
%sollang.struct.m97_s20 = type { i64, i64, i1 }
%sollang.struct.m97_s54 = type { i1, i64, i1, i1 }
%sollang.struct.m97_s8 = type { %sollang.struct.m97_s6, %sollang.text }
%sollang.struct.m98_s15 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32 }
%sollang.struct.m98_s21 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32, %sollang.enum.t1036, %sollang.enum.t1037 }
%sollang.struct.m98_s29 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32, %sollang.enum.t1036, %sollang.enum.t1037, %sollang.array.i32, %sollang.struct.m45_s27, i64 }
%sollang.struct.m98_s0 = type { %sollang.enum.t139, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32 }
%sollang.struct.m100_s31 = type { %sollang.array.i32, i64, %sollang.enum.t1037, %sollang.enum.t1036 }
%sollang.struct.m98_s40 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32, %sollang.array.i32, i64, %sollang.array.i32, i64, %sollang.struct.m97_s42, i1, i1, i1 }
%sollang.struct.m100_s0 = type { i32, i32, i32, i32 }
%sollang.struct.m100_s5 = type { %sollang.struct.m100_s0 }
%sollang.struct.m100_s19 = type { %sollang.struct.m100_s0, %sollang.array.i32, %sollang.text, i32, i32, i1, i1, i1, i64, %sollang.enum.t1037, %sollang.enum.t1036 }
%sollang.struct.m101_s0 = type { i32, i32, i32, i32 }
%sollang.struct.m101_s5 = type { %sollang.struct.m101_s0 }
%sollang.struct.m101_s14 = type { %sollang.struct.m101_s0, %sollang.array.i32, i32, i32, i1, i1, i1, i64, %sollang.enum.t1064 }
%sollang.struct.m101_s24 = type { %sollang.array.i32, i64, %sollang.enum.t1064, %sollang.enum.t1065 }
%sollang.struct.m102_s17 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, i32, %sollang.array.i32, i64 }
%sollang.struct.m102_s26 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, i32, %sollang.array.i32, %sollang.struct.m45_s20, i64, %sollang.array.i32, i64, i1 }
%sollang.struct.m102_s0 = type { %sollang.struct.m48_s0, %sollang.struct.m45_s6 }
%sollang.struct.m102_s13 = type { %sollang.struct.m48_s7, %sollang.struct.m45_s18, i32 }
%sollang.struct.m102_s36 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, i32, %sollang.array.i32, %sollang.struct.m45_s20, i64, %sollang.array.i32, i64, %sollang.struct.m97_s42 }
%sollang.struct.m127_s0 = type { %sollang.struct.m113_s33 }
%sollang.struct.m103_s5 = type { i64, i1, %sollang.enum.t593 }
%sollang.struct.m118_s28 = type { i64, i64 }
%sollang.struct.m104_s0 = type { i1, i1, i1, %sollang.struct.m118_s22, %sollang.struct.m118_s28 }
%sollang.struct.m105_s0 = type { i64, i8 }
%sollang.struct.m105_s3 = type { %sollang.array.i32, i64 }
%sollang.struct.m105_s6 = type { %sollang.array.i32, i64 }
%sollang.struct.m105_s9 = type { %sollang.array.i32, i64 }
%sollang.struct.m105_s12 = type { i64, %sollang.array.i32 }
%sollang.struct.m107_s39 = type { i64, i64 }
%sollang.struct.m107_s0 = type { i64, %sollang.array.i32 }
%sollang.struct.m107_s20 = type { i1, i64 }
%sollang.struct.m107_s23 = type { i64, i64 }
%sollang.struct.m107_s26 = type { i1, i64 }
%sollang.struct.m107_s34 = type { i64, i64, %sollang.array.i32, { ptr, i64 } }
%sollang.struct.m107_s29 = type { i1, i64, i64, %sollang.array.i32 }
%sollang.struct.m107_s66 = type { %sollang.enum.t593, i64 }
%sollang.struct.m110_s0 = type { { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 }, { ptr, i64 } }
%sollang.struct.m112_s0 = type { { ptr, i64 } }
%sollang.struct.m112_s2 = type { %sollang.struct.m47_s3, { ptr, i64 }, %sollang.struct.m112_s0 }
%sollang.struct.m112_s6 = type { %sollang.struct.m112_s0, { ptr, i64 }, %sollang.struct.m3_s5, i64, %sollang.array.i32, { ptr, i64 } }
%sollang.struct.m112_s19 = type { %sollang.struct.m112_s0, %sollang.struct.m47_s87 }
%sollang.struct.m112_s13 = type { %sollang.struct.m47_s30, %sollang.struct.m47_s87, %sollang.struct.m112_s0 }
%sollang.struct.m112_s17 = type { %sollang.array.i32 }
%sollang.struct.m116_s9 = type { %sollang.struct.m22_s3, { ptr, i64 } }
%sollang.struct.m116_s7 = type { %sollang.struct.m21_s2 }
%sollang.struct.m113_s33 = type { %sollang.struct.m116_s9, %sollang.struct.m116_s7 }
%sollang.struct.m114_s0 = type { i32, i64 }
%sollang.struct.m113_s7 = type { i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i64, i64 }
%sollang.struct.m113_s19 = type { i32, %sollang.array.i32, %sollang.array.i32, i64, i64 }
%sollang.struct.m113_s29 = type { i8, i64, %sollang.array.i32 }
%sollang.struct.m113_s25 = type { i1, i64, %sollang.array.i32 }
%sollang.struct.m113_s2 = type { i32, i64, %sollang.array.i32, i64 }
%sollang.struct.m113_s14 = type { i32, i64, %sollang.array.i32, i64 }
%sollang.struct.m115_s0 = type { i64, i64, i64, i1, i1 }
%sollang.struct.m115_s6 = type { %sollang.struct.m111_s0, %sollang.struct.m111_s6, i64, i64, i64, i64 }
%sollang.struct.m116_s4 = type { { ptr, i64 }, { ptr, i64 } }
%sollang.struct.m116_s0 = type { { ptr, i64 } }
%sollang.struct.m116_s2 = type { { ptr, i64 } }
%sollang.struct.m117_s0 = type { %sollang.struct.m118_s11, i64 }
%sollang.struct.m118_s6 = type { i64, i64, %sollang.enum.t1169, %sollang.enum.t1170 }
%sollang.struct.m119_s0 = type { %sollang.array.i32 }
%sollang.struct.m119_s2 = type { i16, %sollang.array.i32 }
%sollang.struct.m126_s0 = type { %sollang.array.i32 }
%sollang.struct.m122_s0 = type { i8, %sollang.array.i32, i64 }
%sollang.struct.m122_s4 = type { i16, %sollang.array.i32, i64 }
%sollang.struct.m128_s4 = type { i64 }
%sollang.struct.m129_s0 = type { i64, i64 }
%sollang.struct.m131_s0 = type { %sollang.array.i32, %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m132_s0 = type { i8, i64, i64, i64 }
%sollang.product.t1253 = type { %sollang.task, %sollang.enum.t303 }
%sollang.dyn = type { ptr, ptr }
%sollang.mutable_container = type { ptr, ptr, ptr }
%sollang.array.i32 = type { ptr, i64, i64 }
declare ptr @malloc(i64)
declare ptr @realloc(ptr, i64)
declare void @free(ptr)
define internal void @sollang_drop_t172(%sollang.struct.m6_s0 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t177(%sollang.struct.m6_s59 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t188(%sollang.enum.t188 %value) {
entry:
  %slot = alloca %sollang.enum.t188, align 8
  store %sollang.enum.t188 %value, ptr %slot, align 8
  %tag = extractvalue %sollang.enum.t188 %value, 0
  %payload = getelementptr inbounds %sollang.enum.t188, ptr %slot, i32 0, i32 1
  %is0 = icmp eq i32 %tag, 0
  br i1 %is0, label %tag0, label %tag1
tag0:
  %first = load %sollang.struct.m6_s0, ptr %payload, align 8
  call void @sollang_drop_t172(%sollang.struct.m6_s0 %first)
  br label %done
tag1:
  %second = load %sollang.struct.m6_s59, ptr %payload, align 8
  call void @sollang_drop_t177(%sollang.struct.m6_s59 %second)
  br label %done
done:
  ret void
}
define internal void @sollang_drop_t297(%sollang.struct.m17_s22 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t298(%sollang.struct.m17_s46 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t300(%sollang.struct.m17_s20 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t304(%sollang.struct.m17_s29 %value) {
entry:
  %field6 = extractvalue %sollang.struct.m17_s29 %value, 6
  call void @sollang_drop_t309(%sollang.enum.t309 %field6)
  ret void
}
define internal void @sollang_drop_t305(%sollang.struct.m17_s37 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t306(%sollang.struct.m17_s42 %value) {
entry:
  ret void
}
define internal void @sollang_drop_t307(%sollang.struct.m17_s48 %value) {
entry:
  %field0 = extractvalue %sollang.struct.m17_s48 %value, 0
  call void @sollang_drop_t298(%sollang.struct.m17_s46 %field0)
  ret void
}
define internal void @sollang_drop_t309(%sollang.enum.t309 %value) {
entry:
  %slot = alloca %sollang.enum.t309, align 8
  store %sollang.enum.t309 %value, ptr %slot, align 8
  %tag = extractvalue %sollang.enum.t309 %value, 0
  %payload = getelementptr inbounds %sollang.enum.t309, ptr %slot, i32 0, i32 1
  %is0 = icmp eq i32 %tag, 0
  br i1 %is0, label %tag0, label %tag1
tag0:
  br label %done
tag1:
  %some = load %sollang.struct.m17_s22, ptr %payload, align 8
  call void @sollang_drop_t297(%sollang.struct.m17_s22 %some)
  br label %done
done:
  ret void
}
define internal void @sollang_drop_t310(%sollang.enum.t310 %value) {
entry:
  %slot = alloca %sollang.enum.t310, align 8
  store %sollang.enum.t310 %value, ptr %slot, align 8
  %tag = extractvalue %sollang.enum.t310 %value, 0
  %payload = getelementptr inbounds %sollang.enum.t310, ptr %slot, i32 0, i32 1
  %is0 = icmp eq i32 %tag, 0
  br i1 %is0, label %tag0, label %tag1
tag0:
  %first = load %sollang.struct.m17_s46, ptr %payload, align 8
  call void @sollang_drop_t298(%sollang.struct.m17_s46 %first)
  br label %done
tag1:
  br label %done
done:
  ret void
}
define internal void @sollang_drop_t313(%sollang.enum.t313 %value) {
entry:
  %slot = alloca %sollang.enum.t313, align 8
  store %sollang.enum.t313 %value, ptr %slot, align 8
  %tag = extractvalue %sollang.enum.t313 %value, 0
  %payload = getelementptr inbounds %sollang.enum.t313, ptr %slot, i32 0, i32 1
  %is0 = icmp eq i32 %tag, 0
  br i1 %is0, label %tag0, label %tag1
tag0:
  %first = load %sollang.struct.m17_s42, ptr %payload, align 8
  call void @sollang_drop_t306(%sollang.struct.m17_s42 %first)
  br label %done
tag1:
  %second = load %sollang.struct.m17_s48, ptr %payload, align 8
  call void @sollang_drop_t307(%sollang.struct.m17_s48 %second)
  br label %done
done:
  ret void
}
define internal void @sollang_drop_t1212([2 x %sollang.struct.m17_s29] %value) {
entry:
  %storage = alloca [2 x %sollang.struct.m17_s29], align 8
  store [2 x %sollang.struct.m17_s29] %value, ptr %storage, align 8
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %continue ]
  %in_range = icmp ult i64 %index, 2
  br i1 %in_range, label %item, label %done
item:
  %slot = getelementptr [2 x %sollang.struct.m17_s29], ptr %storage, i64 0, i64 %index
  %element = load %sollang.struct.m17_s29, ptr %slot, align 8
  call void @sollang_drop_t304(%sollang.struct.m17_s29 %element)
  br label %continue
continue:
  %next = add i64 %index, 1
  br label %loop
done:
  ret void
}
define internal void @sollang_drop_t1251(%sollang.task %value) {
entry:
  %handle = extractvalue %sollang.task %value, 0
  %context = extractvalue %sollang.task %value, 1
  %joined = call i1 @sollang_task_join(ptr %handle)
  br i1 %joined, label %joined_ok, label %invalid
joined_ok:
  %drop_task_handle = getelementptr i8, ptr %handle, i64 0
  %drop_completion_slot = getelementptr %sollang.task_control, ptr %drop_task_handle, i32 0, i32 22
  %drop_completion = load ptr, ptr %drop_completion_slot, align 8
  %drop_needs_completion = icmp ne ptr %drop_completion, null
  br i1 %drop_needs_completion, label %task_result_drop_complete, label %task_result_drop_ready
task_result_drop_complete:
  call void %drop_completion(ptr %drop_task_handle)
  store ptr null, ptr %drop_completion_slot, align 8
  br label %task_result_drop_ready
task_result_drop_ready:
  %result_address_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 21
  %result_address = load ptr, ptr %result_address_slot, align 8
  %released = call i1 @sollang_task_release(ptr %handle)
  br i1 %released, label %done, label %invalid
invalid:
  call void @llvm.trap()
  unreachable
done:
  ret void
}
define internal void @sollang_drop_t1253(%sollang.product.t1253 %value) {
entry:
  %field0 = extractvalue %sollang.product.t1253 %value, 0
  call void @sollang_drop_t1251(%sollang.task %field0)
  ret void
}
define internal void @sollang_drop_t1254(%sollang.enum.t1254 %value) {
entry:
  %slot = alloca %sollang.enum.t1254, align 8
  store %sollang.enum.t1254 %value, ptr %slot, align 8
  %tag = extractvalue %sollang.enum.t1254 %value, 0
  %payload = getelementptr inbounds %sollang.enum.t1254, ptr %slot, i32 0, i32 1
  %is0 = icmp eq i32 %tag, 0
  br i1 %is0, label %tag0, label %tag1
tag0:
  %first = load %sollang.task, ptr %payload, align 8
  call void @sollang_drop_t1251(%sollang.task %first)
  br label %done
tag1:
  %second = load %sollang.product.t1253, ptr %payload, align 8
  call void @sollang_drop_t1253(%sollang.product.t1253 %second)
  br label %done
done:
  ret void
}
declare void @llvm.trap()
declare dllimport void @ExitProcess(i32)
@sollang_str_7763 = private unnamed_addr constant [0 x i8] c""
@sollang_str_7791 = private unnamed_addr constant [0 x i8] c""
@sollang_str_7795 = private unnamed_addr constant [0 x i8] c""
@sollang_str_7799 = private unnamed_addr constant [0 x i8] c""
@sollang_str_7921 = private unnamed_addr constant [1 x i8] c"0"
@sollang_str_7926 = private unnamed_addr constant [1 x i8] c"1"
@sollang_str_7931 = private unnamed_addr constant [1 x i8] c"2"
@sollang_str_7936 = private unnamed_addr constant [1 x i8] c"3"
@sollang_str_7941 = private unnamed_addr constant [1 x i8] c"4"
@sollang_str_7946 = private unnamed_addr constant [1 x i8] c"5"
@sollang_str_7951 = private unnamed_addr constant [1 x i8] c"6"
@sollang_str_7956 = private unnamed_addr constant [1 x i8] c"7"
@sollang_str_7961 = private unnamed_addr constant [1 x i8] c"8"
@sollang_str_7966 = private unnamed_addr constant [1 x i8] c"9"
@sollang_str_7971 = private unnamed_addr constant [1 x i8] c"a"
@sollang_str_7976 = private unnamed_addr constant [1 x i8] c"b"
@sollang_str_7981 = private unnamed_addr constant [1 x i8] c"c"
@sollang_str_7986 = private unnamed_addr constant [1 x i8] c"d"
@sollang_str_7991 = private unnamed_addr constant [1 x i8] c"e"
@sollang_str_7993 = private unnamed_addr constant [1 x i8] c"f"
@sollang_str_8961 = private unnamed_addr constant [1296 x i8] c"$((Int(self.bytes[0]) / 16) -> hexDigit)$((Int(self.bytes[0]) % 16) -> hexDigit)$((Int(self.bytes[1]) / 16) -> hexDigit)$((Int(self.bytes[1]) % 16) -> hexDigit)$((Int(self.bytes[2]) / 16) -> hexDigit)$((Int(self.bytes[2]) % 16) -> hexDigit)$((Int(self.bytes[3]) / 16) -> hexDigit)$((Int(self.bytes[3]) % 16) -> hexDigit)-$((Int(self.bytes[4]) / 16) -> hexDigit)$((Int(self.bytes[4]) % 16) -> hexDigit)$((Int(self.bytes[5]) / 16) -> hexDigit)$((Int(self.bytes[5]) % 16) -> hexDigit)-$((Int(self.bytes[6]) / 16) -> hexDigit)$((Int(self.bytes[6]) % 16) -> hexDigit)$((Int(self.bytes[7]) / 16) -> hexDigit)$((Int(self.bytes[7]) % 16) -> hexDigit)-$((Int(self.bytes[8]) / 16) -> hexDigit)$((Int(self.bytes[8]) % 16) -> hexDigit)$((Int(self.bytes[9]) / 16) -> hexDigit)$((Int(self.bytes[9]) % 16) -> hexDigit)-$((Int(self.bytes[10]) / 16) -> hexDigit)$((Int(self.bytes[10]) % 16) -> hexDigit)$((Int(self.bytes[11]) / 16) -> hexDigit)$((Int(self.bytes[11]) % 16) -> hexDigit)$((Int(self.bytes[12]) / 16) -> hexDigit)$((Int(self.bytes[12]) % 16) -> hexDigit)$((Int(self.bytes[13]) / 16) -> hexDigit)$((Int(self.bytes[13]) % 16) -> hexDigit)$((Int(self.bytes[14]) / 16) -> hexDigit)$((Int(self.bytes[14]) % 16) -> hexDigit)$((Int(self.bytes[15]) / 16) -> hexDigit)$((Int(self.bytes[15]) % 16) -> hexDigit)"
@sollang_str_9112 = private unnamed_addr constant [2 x i8] c"io"
@sollang_str_9447 = private unnamed_addr constant [2 x i8] c"io"
@sollang_str_9821 = private unnamed_addr constant [23 x i8] c"path is not valid UTF-8"
@sollang_str_10155 = private unnamed_addr constant [19 x i8] c"absolute child path"
@sollang_str_10379 = private unnamed_addr constant [18 x i8] c"path styles differ"
@sollang_str_10387 = private unnamed_addr constant [29 x i8] c"cannot join an absolute child"
@sollang_str_10428 = private unnamed_addr constant [18 x i8] c"path styles differ"
@sollang_str_10770 = private unnamed_addr constant [17 x i8] c"path contains NUL"
@sollang_str_10824 = private unnamed_addr constant [20 x i8] c"invalid drive prefix"
@sollang_str_10917 = private unnamed_addr constant [26 x i8] c"unsupported path namespace"
@sollang_str_10947 = private unnamed_addr constant [26 x i8] c"unsupported path namespace"
@sollang_str_10972 = private unnamed_addr constant [16 x i8] c"invalid UNC path"
@sollang_str_11279 = private unnamed_addr constant [17 x i8] c"path escapes root"
@sollang_str_11292 = private unnamed_addr constant [19 x i8] c"incomplete UNC path"
@sollang_str_11326 = private unnamed_addr constant [0 x i8] c""
@sollang_str_11402 = private unnamed_addr constant [0 x i8] c""
@sollang_str_35991 = private unnamed_addr constant [10 x i8] c"ext binder"
@sollang_str_35999 = private unnamed_addr constant [10 x i8] c"res binder"
@sollang_str_36035 = private unnamed_addr constant [11 x i8] c"c e traffic"
@sollang_str_36039 = private unnamed_addr constant [12 x i8] c"e exp master"
@sollang_str_36076 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_36083 = private unnamed_addr constant [12 x i8] c"c hs traffic"
@sollang_str_36087 = private unnamed_addr constant [12 x i8] c"s hs traffic"
@sollang_str_36091 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_36150 = private unnamed_addr constant [12 x i8] c"c ap traffic"
@sollang_str_36154 = private unnamed_addr constant [12 x i8] c"s ap traffic"
@sollang_str_36158 = private unnamed_addr constant [10 x i8] c"exp master"
@sollang_str_36185 = private unnamed_addr constant [10 x i8] c"res master"
@sollang_str_36195 = private unnamed_addr constant [8 x i8] c"finished"
@sollang_str_36224 = private unnamed_addr constant [11 x i8] c"traffic upd"
@sollang_str_42019 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_42029 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_50952 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_50963 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_50987 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_52448 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_52501 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_52554 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_55476 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_55487 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_55491 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_55765 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_55772 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_56102 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_56141 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_56146 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_58431 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_58472 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_58520 = private unnamed_addr constant [6 x i8] c"signal"
@sollang_str_58541 = private unnamed_addr constant [4 x i8] c"kill"
@sollang_str_94361 = private unnamed_addr constant [7 x i8] c"chunked"
@sollang_str_94443 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_94476 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_94911 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_94916 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_95115 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_95140 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_95925 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_95932 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_95953 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_96388 = private unnamed_addr constant [3 x i8] c"GET"
@sollang_str_96395 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_96402 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_97052 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_97060 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_97153 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_97156 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_97159 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_97162 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_97165 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_97204 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_97210 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_97367 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_97373 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_97380 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_97386 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_97898 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_97956 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_98135 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_98167 = private unnamed_addr constant [7 x i8] c"OPTIONS"
@sollang_str_98359 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_98619 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_98634 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_98635 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_98642 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_98643 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_98646 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_98904 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_98907 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_98910 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_98913 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_98951 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_98957 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_99087 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_99093 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_99100 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_99106 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_99245 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_99259 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_99405 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_99671 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_99672 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_99679 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_99680 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_99683 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_104592 = private unnamed_addr constant [9 x i8] c"client in"
@sollang_str_104596 = private unnamed_addr constant [9 x i8] c"server in"
@sollang_str_104604 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_104606 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_104613 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_104615 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_104622 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_104624 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_115483 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_115485 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_115492 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_115494 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_115501 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_115503 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_118113 = private unnamed_addr constant [9 x i8] c"Some($id)"
@sollang_str_118118 = private unnamed_addr constant [4 x i8] c"None"
@sollang_str_118129 = private unnamed_addr constant [7 x i8] c"Pending"
@sollang_str_118134 = private unnamed_addr constant [7 x i8] c"Running"
@sollang_str_118139 = private unnamed_addr constant [9 x i8] c"Completed"
@sollang_str_118144 = private unnamed_addr constant [9 x i8] c"Cancelled"
@sollang_str_118155 = private unnamed_addr constant [4 x i8] c"None"
@sollang_str_118160 = private unnamed_addr constant [5 x i8] c"Ready"
@sollang_str_118165 = private unnamed_addr constant [5 x i8] c"Timer"
@sollang_str_118170 = private unnamed_addr constant [12 x i8] c"AwaitBlocked"
@sollang_str_118181 = private unnamed_addr constant [197 x i8] c"Some(sourceModule=$(locator.sourceModule);functionSymbol=$(locator.functionSymbol);resumeState=$(locator.resumeState);byteOffset=$(locator.byteOffset);line=$(locator.line);column=$(locator.column))"
@sollang_str_118186 = private unnamed_addr constant [4 x i8] c"None"
@sollang_str_118197 = private unnamed_addr constant [1 x i8] c"0"
@sollang_str_118200 = private unnamed_addr constant [7 x i8] c"nonzero"
@sollang_str_118205 = private unnamed_addr constant [41 x i8] c"task taskId=$(value.taskId) parentTaskId="
@sollang_str_118210 = private unnamed_addr constant [11 x i8] c" lifecycle="
@sollang_str_118215 = private unnamed_addr constant [11 x i8] c" waitState="
@sollang_str_118220 = private unnamed_addr constant [15 x i8] c" awaitedTaskId="
@sollang_str_118225 = private unnamed_addr constant [21 x i8] c" timerDeadlineMillis="
@sollang_str_118230 = private unnamed_addr constant [12 x i8] c" suspension="
@sollang_str_118235 = private unnamed_addr constant [0 x i8] c""
@sollang_str_118241 = private unnamed_addr constant [124 x i8] c"snapshot sessionId=$(result.sessionId) written=$(result.written) available=$(result.available) truncated=$(result.truncated)"
@sollang_str_118271 = private unnamed_addr constant [10 x i8] c"\ED\95\9C\EA\B8\80\F0\9F\98\80"
@sollang_str_118283 = private unnamed_addr constant [14 x i8] c"duration-error"
@sollang_str_118357 = private unnamed_addr constant [11 x i8] c"track-error"
@sollang_str_118363 = private unnamed_addr constant [10 x i8] c"open-error"
@sollang_str_118371 = private unnamed_addr constant [10 x i8] c"\ED\95\9C\EA\B8\80\F0\9F\98\80"
@sollang_str_118383 = private unnamed_addr constant [14 x i8] c"duration-error"
define %sollang.enum.t188 @sollang_m6_s61(i64 %arg, i64 %arg1) {
entry:
  %if3922_result = alloca %sollang.enum.t188, align 8
  %if3934_result = alloca %sollang.enum.t188, align 8
  %v3919 = icmp slt i64 %arg, 0
  br i1 %v3919, label %if3922_then, label %if3922_else
if3922_then:
  %v3926_enum_slot = alloca %sollang.enum.t176, align 8
  store %sollang.enum.t176 zeroinitializer, ptr %v3926_enum_slot, align 8
  %v3926_enum_tag = getelementptr inbounds %sollang.enum.t176, ptr %v3926_enum_slot, i32 0, i32 0
  store i32 0, ptr %v3926_enum_tag, align 4
  %v3926 = load %sollang.enum.t176, ptr %v3926_enum_slot, align 8
  %v3925 = insertvalue %sollang.struct.m6_s59 poison, %sollang.enum.t176 %v3926, 0
  %v3924_enum_slot = alloca %sollang.enum.t188, align 8
  store %sollang.enum.t188 zeroinitializer, ptr %v3924_enum_slot, align 8
  %v3924_enum_tag = getelementptr inbounds %sollang.enum.t188, ptr %v3924_enum_slot, i32 0, i32 0
  store i32 1, ptr %v3924_enum_tag, align 4
  %v3924_enum_payload = getelementptr inbounds %sollang.enum.t188, ptr %v3924_enum_slot, i32 0, i32 1
  store %sollang.struct.m6_s59 %v3925, ptr %v3924_enum_payload, align 8
  %v3924 = load %sollang.enum.t188, ptr %v3924_enum_slot, align 8
  store %sollang.enum.t188 %v3924, ptr %if3922_result, align 8
  br label %if3922_merge
if3922_else:
  %v3933 = freeze i64 %arg1
  %v3931 = sdiv i64 9223372036854775807, %arg1
  %v3929 = icmp sgt i64 %arg, %v3931
  br i1 %v3929, label %if3934_then, label %if3934_else
if3934_then:
  %v3938_enum_slot = alloca %sollang.enum.t176, align 8
  store %sollang.enum.t176 zeroinitializer, ptr %v3938_enum_slot, align 8
  %v3938_enum_tag = getelementptr inbounds %sollang.enum.t176, ptr %v3938_enum_slot, i32 0, i32 0
  store i32 3, ptr %v3938_enum_tag, align 4
  %v3938 = load %sollang.enum.t176, ptr %v3938_enum_slot, align 8
  %v3937 = insertvalue %sollang.struct.m6_s59 poison, %sollang.enum.t176 %v3938, 0
  %v3936_enum_slot = alloca %sollang.enum.t188, align 8
  store %sollang.enum.t188 zeroinitializer, ptr %v3936_enum_slot, align 8
  %v3936_enum_tag = getelementptr inbounds %sollang.enum.t188, ptr %v3936_enum_slot, i32 0, i32 0
  store i32 1, ptr %v3936_enum_tag, align 4
  %v3936_enum_payload = getelementptr inbounds %sollang.enum.t188, ptr %v3936_enum_slot, i32 0, i32 1
  store %sollang.struct.m6_s59 %v3937, ptr %v3936_enum_payload, align 8
  %v3936 = load %sollang.enum.t188, ptr %v3936_enum_slot, align 8
  store %sollang.enum.t188 %v3936, ptr %if3934_result, align 8
  br label %if3934_merge
if3934_else:
  %v3944 = freeze i64 %arg1
  %v3942 = mul i64 %arg, %arg1
  %v3941 = insertvalue %sollang.struct.m6_s0 poison, i64 %v3942, 0
  %v3940_enum_slot = alloca %sollang.enum.t188, align 8
  store %sollang.enum.t188 zeroinitializer, ptr %v3940_enum_slot, align 8
  %v3940_enum_tag = getelementptr inbounds %sollang.enum.t188, ptr %v3940_enum_slot, i32 0, i32 0
  store i32 0, ptr %v3940_enum_tag, align 4
  %v3940_enum_payload = getelementptr inbounds %sollang.enum.t188, ptr %v3940_enum_slot, i32 0, i32 1
  store %sollang.struct.m6_s0 %v3941, ptr %v3940_enum_payload, align 8
  %v3940 = load %sollang.enum.t188, ptr %v3940_enum_slot, align 8
  store %sollang.enum.t188 %v3940, ptr %if3934_result, align 8
  br label %if3934_merge
if3934_merge:
  %v3934 = load %sollang.enum.t188, ptr %if3934_result, align 8
  store %sollang.enum.t188 %v3934, ptr %if3922_result, align 8
  br label %if3922_merge
if3922_merge:
  %v3922 = load %sollang.enum.t188, ptr %if3922_result, align 8
  ret %sollang.enum.t188 %v3922
}
define %sollang.enum.t188 @sollang_m6_s86(i64 %arg) {
entry:
  %v4174 = call %sollang.enum.t188 @sollang_m6_s61(i64 %arg, i64 1)
  ret %sollang.enum.t188 %v4174
}
define void @sollang_m144_s0(%sollang.enum.t308 %arg) {
entry:
  %v118108_subject_slot = alloca %sollang.enum.t308, align 8
  %v118108_tag = extractvalue %sollang.enum.t308 %arg, 0
  store %sollang.enum.t308 %arg, ptr %v118108_subject_slot, align 8
  %v118108_is_arm0 = icmp eq i32 %v118108_tag, 1
  br i1 %v118108_is_arm0, label %match118108_arm0, label %match118108_next0
match118108_arm0:
  %v118108_arm0_payload = getelementptr inbounds %sollang.enum.t308, ptr %v118108_subject_slot, i32 0, i32 1
  %v118110 = load i64, ptr %v118108_arm0_payload, align 8
  %v118113_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118113, 0
  %v118113 = insertvalue %sollang.text %v118113_ptr, i64 9, 1
  %v118112_expression_literal0 = getelementptr i8, ptr @sollang_str_118113, i64 0
  call void @sollang_runtime_print(ptr %v118112_expression_literal0, i64 5, i1 false)
  call void @sollang_runtime_print_i64(i64 %v118110, i1 false, i1 false)
  %v118112_expression_suffix = getelementptr i8, ptr @sollang_str_118113, i64 8
  call void @sollang_runtime_print(ptr %v118112_expression_suffix, i64 1, i1 false)
  br label %match118108_merge
match118108_next0:
  %v118108_is_arm1 = icmp eq i32 %v118108_tag, 0
  br i1 %v118108_is_arm1, label %match118108_arm1, label %match118108_next1
match118108_arm1:
  %v118108_arm1_payload = getelementptr inbounds %sollang.enum.t308, ptr %v118108_subject_slot, i32 0, i32 1
  %v118115 = load i64, ptr %v118108_arm1_payload, align 8
  %v118118_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118118, 0
  %v118118 = insertvalue %sollang.text %v118118_ptr, i64 4, 1
  call void @sollang_runtime_print(ptr @sollang_str_118118, i64 4, i1 false)
  br label %match118108_merge
match118108_next1:
  call void @llvm.trap()
  unreachable
match118108_merge:
  ret void
}
define void @sollang_m144_s3(%sollang.enum.t295 %arg) {
entry:
  %v118124_subject_slot = alloca %sollang.enum.t295, align 8
  %v118124_tag = extractvalue %sollang.enum.t295 %arg, 0
  store %sollang.enum.t295 %arg, ptr %v118124_subject_slot, align 8
  %v118124_is_arm0 = icmp eq i32 %v118124_tag, 0
  br i1 %v118124_is_arm0, label %match118124_arm0, label %match118124_next0
match118124_arm0:
  %v118129_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118129, 0
  %v118129 = insertvalue %sollang.text %v118129_ptr, i64 7, 1
  call void @sollang_runtime_print(ptr @sollang_str_118129, i64 7, i1 false)
  br label %match118124_merge
match118124_next0:
  %v118124_is_arm1 = icmp eq i32 %v118124_tag, 1
  br i1 %v118124_is_arm1, label %match118124_arm1, label %match118124_next1
match118124_arm1:
  %v118134_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118134, 0
  %v118134 = insertvalue %sollang.text %v118134_ptr, i64 7, 1
  call void @sollang_runtime_print(ptr @sollang_str_118134, i64 7, i1 false)
  br label %match118124_merge
match118124_next1:
  %v118124_is_arm2 = icmp eq i32 %v118124_tag, 2
  br i1 %v118124_is_arm2, label %match118124_arm2, label %match118124_next2
match118124_arm2:
  %v118139_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118139, 0
  %v118139 = insertvalue %sollang.text %v118139_ptr, i64 9, 1
  call void @sollang_runtime_print(ptr @sollang_str_118139, i64 9, i1 false)
  br label %match118124_merge
match118124_next2:
  %v118124_is_arm3 = icmp eq i32 %v118124_tag, 3
  br i1 %v118124_is_arm3, label %match118124_arm3, label %match118124_next3
match118124_arm3:
  %v118144_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118144, 0
  %v118144 = insertvalue %sollang.text %v118144_ptr, i64 9, 1
  call void @sollang_runtime_print(ptr @sollang_str_118144, i64 9, i1 false)
  br label %match118124_merge
match118124_next3:
  call void @llvm.trap()
  unreachable
match118124_merge:
  ret void
}
define void @sollang_m144_s8(%sollang.enum.t296 %arg) {
entry:
  %v118150_subject_slot = alloca %sollang.enum.t296, align 8
  %v118150_tag = extractvalue %sollang.enum.t296 %arg, 0
  store %sollang.enum.t296 %arg, ptr %v118150_subject_slot, align 8
  %v118150_is_arm0 = icmp eq i32 %v118150_tag, 0
  br i1 %v118150_is_arm0, label %match118150_arm0, label %match118150_next0
match118150_arm0:
  %v118155_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118155, 0
  %v118155 = insertvalue %sollang.text %v118155_ptr, i64 4, 1
  call void @sollang_runtime_print(ptr @sollang_str_118155, i64 4, i1 false)
  br label %match118150_merge
match118150_next0:
  %v118150_is_arm1 = icmp eq i32 %v118150_tag, 1
  br i1 %v118150_is_arm1, label %match118150_arm1, label %match118150_next1
match118150_arm1:
  %v118160_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118160, 0
  %v118160 = insertvalue %sollang.text %v118160_ptr, i64 5, 1
  call void @sollang_runtime_print(ptr @sollang_str_118160, i64 5, i1 false)
  br label %match118150_merge
match118150_next1:
  %v118150_is_arm2 = icmp eq i32 %v118150_tag, 2
  br i1 %v118150_is_arm2, label %match118150_arm2, label %match118150_next2
match118150_arm2:
  %v118165_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118165, 0
  %v118165 = insertvalue %sollang.text %v118165_ptr, i64 5, 1
  call void @sollang_runtime_print(ptr @sollang_str_118165, i64 5, i1 false)
  br label %match118150_merge
match118150_next2:
  %v118150_is_arm3 = icmp eq i32 %v118150_tag, 3
  br i1 %v118150_is_arm3, label %match118150_arm3, label %match118150_next3
match118150_arm3:
  %v118170_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118170, 0
  %v118170 = insertvalue %sollang.text %v118170_ptr, i64 12, 1
  call void @sollang_runtime_print(ptr @sollang_str_118170, i64 12, i1 false)
  br label %match118150_merge
match118150_next3:
  call void @llvm.trap()
  unreachable
match118150_merge:
  ret void
}
define void @sollang_m144_s13(%sollang.enum.t309 %arg) {
entry:
  %v118176_subject_slot = alloca %sollang.enum.t309, align 8
  %v118176_tag = extractvalue %sollang.enum.t309 %arg, 0
  store %sollang.enum.t309 %arg, ptr %v118176_subject_slot, align 8
  %v118176_is_arm0 = icmp eq i32 %v118176_tag, 1
  br i1 %v118176_is_arm0, label %match118176_arm0, label %match118176_next0
match118176_arm0:
  %v118176_arm0_payload = getelementptr inbounds %sollang.enum.t309, ptr %v118176_subject_slot, i32 0, i32 1
  %v118178 = load %sollang.struct.m17_s22, ptr %v118176_arm0_payload, align 8
  %v118181_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118181, 0
  %v118181 = insertvalue %sollang.text %v118181_ptr, i64 197, 1
  %v118180_expression_literal0 = getelementptr i8, ptr @sollang_str_118181, i64 0
  call void @sollang_runtime_print(ptr %v118180_expression_literal0, i64 18, i1 false)
  %v118180_expression1 = extractvalue %sollang.struct.m17_s22 %v118178, 0
  %v118180_expression1_text_ptr = extractvalue %sollang.text %v118180_expression1, 0
  %v118180_expression1_text_len = extractvalue %sollang.text %v118180_expression1, 1
  call void @sollang_runtime_print(ptr %v118180_expression1_text_ptr, i64 %v118180_expression1_text_len, i1 false)
  %v118180_expression_literal1 = getelementptr i8, ptr @sollang_str_118181, i64 41
  call void @sollang_runtime_print(ptr %v118180_expression_literal1, i64 16, i1 false)
  %v118180_expression3 = extractvalue %sollang.struct.m17_s22 %v118178, 1
  %v118180_expression3_text_ptr = extractvalue %sollang.text %v118180_expression3, 0
  %v118180_expression3_text_len = extractvalue %sollang.text %v118180_expression3, 1
  call void @sollang_runtime_print(ptr %v118180_expression3_text_ptr, i64 %v118180_expression3_text_len, i1 false)
  %v118180_expression_literal2 = getelementptr i8, ptr @sollang_str_118181, i64 82
  call void @sollang_runtime_print(ptr %v118180_expression_literal2, i64 13, i1 false)
  %v118180_expression5 = extractvalue %sollang.struct.m17_s22 %v118178, 2
  call void @sollang_runtime_print_i32(i32 %v118180_expression5, i1 false)
  %v118180_expression_literal3 = getelementptr i8, ptr @sollang_str_118181, i64 117
  call void @sollang_runtime_print(ptr %v118180_expression_literal3, i64 12, i1 false)
  %v118180_expression7 = extractvalue %sollang.struct.m17_s22 %v118178, 3
  call void @sollang_runtime_print_i64(i64 %v118180_expression7, i1 false, i1 false)
  %v118180_expression_literal4 = getelementptr i8, ptr @sollang_str_118181, i64 150
  call void @sollang_runtime_print(ptr %v118180_expression_literal4, i64 6, i1 false)
  %v118180_expression9 = extractvalue %sollang.struct.m17_s22 %v118178, 4
  call void @sollang_runtime_print_i32(i32 %v118180_expression9, i1 false)
  %v118180_expression_literal5 = getelementptr i8, ptr @sollang_str_118181, i64 171
  call void @sollang_runtime_print(ptr %v118180_expression_literal5, i64 8, i1 false)
  %v118180_expression11 = extractvalue %sollang.struct.m17_s22 %v118178, 5
  call void @sollang_runtime_print_i32(i32 %v118180_expression11, i1 false)
  %v118180_expression_suffix = getelementptr i8, ptr @sollang_str_118181, i64 196
  call void @sollang_runtime_print(ptr %v118180_expression_suffix, i64 1, i1 false)
  br label %match118176_merge
match118176_next0:
  %v118176_is_arm1 = icmp eq i32 %v118176_tag, 0
  br i1 %v118176_is_arm1, label %match118176_arm1, label %match118176_next1
match118176_arm1:
  %v118176_arm1_payload = getelementptr inbounds %sollang.enum.t309, ptr %v118176_subject_slot, i32 0, i32 1
  %v118183 = load %sollang.struct.m17_s22, ptr %v118176_arm1_payload, align 8
  %v118186_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118186, 0
  %v118186 = insertvalue %sollang.text %v118186_ptr, i64 4, 1
  call void @sollang_runtime_print(ptr @sollang_str_118186, i64 4, i1 false)
  br label %match118176_merge
match118176_next1:
  call void @llvm.trap()
  unreachable
match118176_merge:
  ret void
}
define void @sollang_m144_s16(i64 %arg) {
entry:
  %v118191 = icmp eq i64 %arg, 0
  br i1 %v118191, label %if118194_then, label %if118194_else
if118194_then:
  %v118197_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118197, 0
  %v118197 = insertvalue %sollang.text %v118197_ptr, i64 1, 1
  call void @sollang_runtime_print(ptr @sollang_str_118197, i64 1, i1 false)
  br label %if118194_merge
if118194_else:
  %v118200_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118200, 0
  %v118200 = insertvalue %sollang.text %v118200_ptr, i64 7, 1
  call void @sollang_runtime_print(ptr @sollang_str_118200, i64 7, i1 false)
  br label %if118194_merge
if118194_merge:
  ret void
}
define void @sollang_m144_s17(%sollang.struct.m17_s29 %arg) {
entry:
  %v118205_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118205, 0
  %v118205 = insertvalue %sollang.text %v118205_ptr, i64 41, 1
  %v118210_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118210, 0
  %v118210 = insertvalue %sollang.text %v118210_ptr, i64 11, 1
  %v118215_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118215, 0
  %v118215 = insertvalue %sollang.text %v118215_ptr, i64 11, 1
  %v118220_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118220, 0
  %v118220 = insertvalue %sollang.text %v118220_ptr, i64 15, 1
  %v118225_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118225, 0
  %v118225 = insertvalue %sollang.text %v118225_ptr, i64 21, 1
  %v118230_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118230, 0
  %v118230 = insertvalue %sollang.text %v118230_ptr, i64 12, 1
  %v118235_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118235, 0
  %v118235 = insertvalue %sollang.text %v118235_ptr, i64 0, 1
  %v118204_expression_literal0 = getelementptr i8, ptr @sollang_str_118205, i64 0
  call void @sollang_runtime_print(ptr %v118204_expression_literal0, i64 12, i1 false)
  %v118204_expression13 = extractvalue %sollang.struct.m17_s29 %arg, 0
  call void @sollang_runtime_print_i64(i64 %v118204_expression13, i1 false, i1 false)
  %v118204_expression_suffix = getelementptr i8, ptr @sollang_str_118205, i64 27
  call void @sollang_runtime_print(ptr %v118204_expression_suffix, i64 14, i1 false)
  %v118207 = extractvalue %sollang.struct.m17_s29 %arg, 1
  %v118212 = extractvalue %sollang.struct.m17_s29 %arg, 2
  %v118217 = extractvalue %sollang.struct.m17_s29 %arg, 3
  %v118222 = extractvalue %sollang.struct.m17_s29 %arg, 4
  %v118227 = extractvalue %sollang.struct.m17_s29 %arg, 5
  %v118232 = extractvalue %sollang.struct.m17_s29 %arg, 6
  call void @sollang_m144_s0(%sollang.enum.t308 %v118207)
  call void @sollang_runtime_print(ptr @sollang_str_118210, i64 11, i1 false)
  call void @sollang_m144_s3(%sollang.enum.t295 %v118212)
  call void @sollang_runtime_print(ptr @sollang_str_118215, i64 11, i1 false)
  call void @sollang_m144_s8(%sollang.enum.t296 %v118217)
  call void @sollang_runtime_print(ptr @sollang_str_118220, i64 15, i1 false)
  call void @sollang_m144_s0(%sollang.enum.t308 %v118222)
  call void @sollang_runtime_print(ptr @sollang_str_118225, i64 21, i1 false)
  call void @sollang_m144_s16(i64 %v118227)
  call void @sollang_runtime_print(ptr @sollang_str_118230, i64 12, i1 false)
  call void @sollang_m144_s13(%sollang.enum.t309 %v118232)
  call void @sollang_runtime_print(ptr @sollang_str_118235, i64 0, i1 true)
  ret void
}
define { ptr, i64 } @sollang_m144_s18(%sollang.struct.m17_s37 %arg, { ptr, i64 } %arg1) {
entry:
  %v118241_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118241, 0
  %v118241 = insertvalue %sollang.text %v118241_ptr, i64 124, 1
  %v118244 = freeze { ptr, i64 } %arg1
  %v118257 = freeze { ptr, i64 } %arg1
  %v118240_expression_literal0 = getelementptr i8, ptr @sollang_str_118241, i64 0
  call void @sollang_runtime_print(ptr %v118240_expression_literal0, i64 19, i1 false)
  %v118240_expression15 = extractvalue %sollang.struct.m17_s37 %arg, 0
  call void @sollang_runtime_print_i64(i64 %v118240_expression15, i1 false, i1 false)
  %v118240_expression_literal1 = getelementptr i8, ptr @sollang_str_118241, i64 38
  call void @sollang_runtime_print(ptr %v118240_expression_literal1, i64 9, i1 false)
  %v118240_expression17 = extractvalue %sollang.struct.m17_s37 %arg, 1
  call void @sollang_runtime_print_i64(i64 %v118240_expression17, i1 false, i1 false)
  %v118240_expression_literal2 = getelementptr i8, ptr @sollang_str_118241, i64 64
  call void @sollang_runtime_print(ptr %v118240_expression_literal2, i64 11, i1 false)
  %v118240_expression19 = extractvalue %sollang.struct.m17_s37 %arg, 2
  call void @sollang_runtime_print_i64(i64 %v118240_expression19, i1 false, i1 false)
  %v118240_expression_literal3 = getelementptr i8, ptr @sollang_str_118241, i64 94
  call void @sollang_runtime_print(ptr %v118240_expression_literal3, i64 11, i1 false)
  %v118240_expression21 = extractvalue %sollang.struct.m17_s37 %arg, 3
  call void @sollang_runtime_print_i1(i1 %v118240_expression21, i1 false)
  %v118240_expression_suffix = getelementptr i8, ptr @sollang_str_118241, i64 124
  call void @sollang_runtime_print(ptr %v118240_expression_suffix, i64 0, i1 true)
  %v118243_data = extractvalue { ptr, i64 } %arg1, 0
  %v118243_length = extractvalue { ptr, i64 } %arg1, 1
  %v118243_in_bounds = icmp ult i64 0, %v118243_length
  br i1 %v118243_in_bounds, label %v118243_index_ok, label %v118243_index_fail
v118243_index_fail:
  call void @llvm.trap()
  unreachable
v118243_index_ok:
  %v118243_ptr = getelementptr %sollang.struct.m17_s29, ptr %v118243_data, i64 0
  %v118243 = load %sollang.struct.m17_s29, ptr %v118243_ptr, align 8
  %v118248 = extractvalue %sollang.struct.m17_s37 %arg, 1
  call void @sollang_m144_s17(%sollang.struct.m17_s29 %v118243)
  %v118247 = icmp ugt i64 %v118248, 1
  br i1 %v118247, label %if118251_then, label %if118251_merge
if118251_then:
  %v118255 = freeze { ptr, i64 } %arg1
  %v118254_data = extractvalue { ptr, i64 } %arg1, 0
  %v118254_length = extractvalue { ptr, i64 } %arg1, 1
  %v118254_in_bounds = icmp ult i64 1, %v118254_length
  br i1 %v118254_in_bounds, label %v118254_index_ok, label %v118254_index_fail
v118254_index_fail:
  call void @llvm.trap()
  unreachable
v118254_index_ok:
  %v118254_ptr = getelementptr %sollang.struct.m17_s29, ptr %v118254_data, i64 1
  %v118254 = load %sollang.struct.m17_s29, ptr %v118254_ptr, align 8
  call void @sollang_m144_s17(%sollang.struct.m17_s29 %v118254)
  br label %if118251_merge
if118251_merge:
  %return_fixed118236_source = extractvalue { ptr, i64 } %arg1, 0
  %return_fixed118236_data = call ptr @malloc(i64 256)
  call void @llvm.memcpy.p0.p0.i64(ptr %return_fixed118236_data, ptr %return_fixed118236_source, i64 256, i1 false)
  %return_fixed118236_0 = insertvalue { ptr, i64 } poison, ptr %return_fixed118236_data, 0
  %return_fixed118236 = insertvalue { ptr, i64 } %return_fixed118236_0, i64 2, 1
  ret { ptr, i64 } %return_fixed118236
}
define %sollang.struct.m17_s29 @sollang_m144_s20() {
entry:
  %v118262_enum_slot = alloca %sollang.enum.t308, align 8
  store %sollang.enum.t308 zeroinitializer, ptr %v118262_enum_slot, align 8
  %v118262_enum_tag = getelementptr inbounds %sollang.enum.t308, ptr %v118262_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118262_enum_tag, align 4
  %v118262 = load %sollang.enum.t308, ptr %v118262_enum_slot, align 8
  %v118263_enum_slot = alloca %sollang.enum.t295, align 8
  store %sollang.enum.t295 zeroinitializer, ptr %v118263_enum_slot, align 8
  %v118263_enum_tag = getelementptr inbounds %sollang.enum.t295, ptr %v118263_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118263_enum_tag, align 4
  %v118263 = load %sollang.enum.t295, ptr %v118263_enum_slot, align 8
  %v118264_enum_slot = alloca %sollang.enum.t296, align 8
  store %sollang.enum.t296 zeroinitializer, ptr %v118264_enum_slot, align 8
  %v118264_enum_tag = getelementptr inbounds %sollang.enum.t296, ptr %v118264_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118264_enum_tag, align 4
  %v118264 = load %sollang.enum.t296, ptr %v118264_enum_slot, align 8
  %v118265_enum_slot = alloca %sollang.enum.t308, align 8
  store %sollang.enum.t308 zeroinitializer, ptr %v118265_enum_slot, align 8
  %v118265_enum_tag = getelementptr inbounds %sollang.enum.t308, ptr %v118265_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118265_enum_tag, align 4
  %v118265 = load %sollang.enum.t308, ptr %v118265_enum_slot, align 8
  %v118267_enum_slot = alloca %sollang.enum.t309, align 8
  store %sollang.enum.t309 zeroinitializer, ptr %v118267_enum_slot, align 8
  %v118267_enum_tag = getelementptr inbounds %sollang.enum.t309, ptr %v118267_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118267_enum_tag, align 4
  %v118267 = load %sollang.enum.t309, ptr %v118267_enum_slot, align 8
  %v118260_f0 = insertvalue %sollang.struct.m17_s29 poison, i64 0, 0
  %v118260_f1 = insertvalue %sollang.struct.m17_s29 %v118260_f0, %sollang.enum.t308 %v118262, 1
  %v118260_f2 = insertvalue %sollang.struct.m17_s29 %v118260_f1, %sollang.enum.t295 %v118263, 2
  %v118260_f3 = insertvalue %sollang.struct.m17_s29 %v118260_f2, %sollang.enum.t296 %v118264, 3
  %v118260_f4 = insertvalue %sollang.struct.m17_s29 %v118260_f3, %sollang.enum.t308 %v118265, 4
  %v118260_f5 = insertvalue %sollang.struct.m17_s29 %v118260_f4, i64 0, 5
  %v118260 = insertvalue %sollang.struct.m17_s29 %v118260_f5, %sollang.enum.t309 %v118267, 6
  ret %sollang.struct.m17_s29 %v118260
}
define internal void @sollang_m144_s25_async_destroy(ptr %context) {
entry:
  %header = getelementptr i8, ptr %context, i64 32
  call void @sollang_diagnostic_release_header(ptr %header, i32 2)
  call void @free(ptr %context)
  ret void
}
define i1 @sollang_m144_s25_async_worker(ptr %control) {
entry:
  %async_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_context = load ptr, ptr %async_context_slot, align 8
  %v118306_subject_slot = alloca %sollang.enum.t310, align 8
  %v118309_owned = alloca i1, align 1
  store i1 false, ptr %v118309_owned, align 1
  %v118318_subject_slot = alloca %sollang.enum.t1254, align 8
  %v118320_owned = alloca i1, align 1
  store i1 false, ptr %v118320_owned, align 1
  %v118349_owned = alloca i1, align 1
  store i1 false, ptr %v118349_owned, align 1
  %async_frame_slot = getelementptr i8, ptr %async_context, i64 8
  %async_local118288 = alloca %sollang.enum.t310, align 8
  %slot118289 = alloca %sollang.struct.m17_s46, align 8
  %async_local118290 = alloca %sollang.task, align 8
  %async_local118291 = alloca %sollang.enum.t1254, align 8
  %slot118292 = alloca { ptr, i64 }, align 8
  %async_local118293 = alloca %sollang.struct.m17_s37, align 8
  %slot118294 = alloca { ptr, i64 }, align 8
  %async_local118295 = alloca %sollang.struct.m17_s37, align 8
  %slot118296 = alloca { ptr, i64 }, align 8
  %async_local118320 = alloca %sollang.task, align 8
  %async_local118349 = alloca %sollang.product.t1253, align 8
  %async_resume_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state = load i32, ptr %async_resume_state_slot, align 4
  switch i32 %async_resume_state, label %async_state_invalid [ i32 0, label %async_state_start i32 1, label %async_resume1 i32 2, label %async_resume2 i32 3, label %async_resume3 i32 4, label %async_resume4 ]
async_state_invalid:
  call void @llvm.trap()
  unreachable
async_state_start:
  %v118302 = insertvalue %sollang.struct.m17_s20 poison, i32 2, 0
  %v118301_diagnostic_input = extractvalue %sollang.struct.m17_s20 %v118302, 0
  %v118301_diagnostic_result_slot = alloca %sollang.enum.t310, align 8
  store %sollang.enum.t310 zeroinitializer, ptr %v118301_diagnostic_result_slot, align 8
  %v118301_diagnostic_tag = getelementptr inbounds %sollang.enum.t310, ptr %v118301_diagnostic_result_slot, i32 0, i32 0
  %v118301_diagnostic_payload = getelementptr inbounds %sollang.enum.t310, ptr %v118301_diagnostic_result_slot, i32 0, i32 1
  %v118301_diagnostic_raw = call { ptr, i32 } @sollang_diagnostic_start(i32 %v118301_diagnostic_input)
  %v118301_diagnostic_session = extractvalue { ptr, i32 } %v118301_diagnostic_raw, 0
  %v118301_diagnostic_error = extractvalue { ptr, i32 } %v118301_diagnostic_raw, 1
  %v118301_diagnostic_ok = icmp eq i32 %v118301_diagnostic_error, -1
  %v118301_diagnostic_discriminant = select i1 %v118301_diagnostic_ok, i32 0, i32 1
  store i32 %v118301_diagnostic_discriminant, ptr %v118301_diagnostic_tag, align 4
  br i1 %v118301_diagnostic_ok, label %diagnostic118301_ok, label %diagnostic118301_error
diagnostic118301_ok:
  %v118301_diagnostic_token = ptrtoint ptr %v118301_diagnostic_session to i64
  store i64 %v118301_diagnostic_token, ptr %v118301_diagnostic_payload, align 8
  br label %diagnostic118301_merge
diagnostic118301_error:
  store i32 %v118301_diagnostic_error, ptr %v118301_diagnostic_payload, align 4
  br label %diagnostic118301_merge
diagnostic118301_merge:
  %v118301 = load %sollang.enum.t310, ptr %v118301_diagnostic_result_slot, align 8
  store %sollang.enum.t310 %v118301, ptr %async_local118288, align 8
  %v118305 = load %sollang.enum.t310, ptr %async_local118288, align 8
  %v118306_tag = extractvalue %sollang.enum.t310 %v118305, 0
  store %sollang.enum.t310 %v118305, ptr %v118306_subject_slot, align 8
  %v118306_is_arm0 = icmp eq i32 %v118306_tag, 0
  br i1 %v118306_is_arm0, label %match118306_arm0, label %match118306_next0
match118306_arm0:
  %v118306_arm0_payload = getelementptr inbounds %sollang.enum.t310, ptr %v118306_subject_slot, i32 0, i32 1
  %v118309 = load %sollang.struct.m17_s46, ptr %v118306_arm0_payload, align 8
  store i1 true, ptr %v118309_owned, align 1
  %v118311 = freeze %sollang.struct.m17_s46 %v118309
  store %sollang.struct.m17_s46 %v118309, ptr %slot118289, align 8
  %callenv118312_diagnostic_parent = getelementptr i8, ptr %async_context, i64 32
  %v118312 = call %sollang.task @sollang_m144_s21_g118368(ptr %callenv118312_diagnostic_parent)
  store %sollang.task %v118312, ptr %async_local118290, align 8
  %v118314 = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  %v118315 = load %sollang.task, ptr %async_local118290, align 1
  %v118313_track_token = extractvalue %sollang.struct.m17_s46 %v118314, 0
  %v118313_track_session = inttoptr i64 %v118313_track_token to ptr
  %v118313_track_task = freeze %sollang.task %v118315
  %v118313_track_control = extractvalue %sollang.task %v118313_track_task, 0
  %v118313_track_context = extractvalue %sollang.task %v118313_track_task, 1
  %v118313_track_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %v118313_track_control, i32 0, i32 1
  %v118313_track_header = load ptr, ptr %v118313_track_header_slot, align 8
  %v118313_track_error = call i32 @sollang_diagnostic_track(ptr %v118313_track_session, ptr %v118313_track_header, ptr %v118313_track_control)
  %v118313_track_ok = icmp eq i32 %v118313_track_error, -1
  %v118313_track_tag_value = select i1 %v118313_track_ok, i32 0, i32 1
  %v118313_track_result_slot = alloca %sollang.enum.t1254, align 8
  store %sollang.enum.t1254 zeroinitializer, ptr %v118313_track_result_slot, align 8
  %v118313_track_tag = getelementptr inbounds %sollang.enum.t1254, ptr %v118313_track_result_slot, i32 0, i32 0
  store i32 %v118313_track_tag_value, ptr %v118313_track_tag, align 4
  %v118313_track_payload = getelementptr inbounds %sollang.enum.t1254, ptr %v118313_track_result_slot, i32 0, i32 1
  store %sollang.task %v118313_track_task, ptr %v118313_track_payload, align 8
  br i1 %v118313_track_ok, label %track118313_merge, label %track118313_error
track118313_error:
  %v118313_track_kind = getelementptr i8, ptr %v118313_track_payload, i64 16
  store i32 %v118313_track_error, ptr %v118313_track_kind, align 4
  br label %track118313_merge
track118313_merge:
  %v118313 = load %sollang.enum.t1254, ptr %v118313_track_result_slot, align 8
  store %sollang.enum.t1254 %v118313, ptr %async_local118291, align 8
  %v118317 = load %sollang.enum.t1254, ptr %async_local118291, align 8
  %v118318_tag = extractvalue %sollang.enum.t1254 %v118317, 0
  store %sollang.enum.t1254 %v118317, ptr %v118318_subject_slot, align 8
  %v118318_is_arm0 = icmp eq i32 %v118318_tag, 0
  br i1 %v118318_is_arm0, label %match118318_arm0, label %match118318_next0
match118318_arm0:
  %v118318_arm0_payload = getelementptr inbounds %sollang.enum.t1254, ptr %v118318_subject_slot, i32 0, i32 1
  %v118320 = load %sollang.task, ptr %v118318_arm0_payload, align 8
  store i1 true, ptr %v118320_owned, align 1
  store %sollang.task %v118320, ptr %async_local118320, align 8
  %v118323 = call %sollang.struct.m17_s29 @sollang_m144_s20()
  %v118324 = call %sollang.struct.m17_s29 @sollang_m144_s20()
  %v118322_data = call ptr @malloc(i64 256)
  %v118322_ptr0 = getelementptr %sollang.struct.m17_s29, ptr %v118322_data, i64 0
  store %sollang.struct.m17_s29 %v118323, ptr %v118322_ptr0, align 8
  %v118322_ptr1 = getelementptr %sollang.struct.m17_s29, ptr %v118322_data, i64 1
  store %sollang.struct.m17_s29 %v118324, ptr %v118322_ptr1, align 8
  %v118322_0 = insertvalue { ptr, i64 } poison, ptr %v118322_data, 0
  %v118322 = insertvalue { ptr, i64 } %v118322_0, i64 2, 1
  store { ptr, i64 } %v118322, ptr %slot118292, align 8
  %diagnostic_suspend1_header = getelementptr i8, ptr %async_context, i64 32
  call void @sollang_diagnostic_suspend(ptr %diagnostic_suspend1_header, ptr null, i32 1, ptr @sollang_diagnostic_module118286, i64 58, ptr @sollang_diagnostic_symbol118286, i64 7, i64 3531, i64 93, i64 21, i64 0)
  %async_frame1_store = call ptr @malloc(i64 41)
  %async_frame1_allocated = icmp ne ptr %async_frame1_store, null
  br i1 %async_frame1_allocated, label %async_frame1_ready, label %async_frame1_failed
async_frame1_failed:
  call void @llvm.trap()
  unreachable
async_frame1_ready:
  store ptr %async_frame1_store, ptr %async_frame_slot, align 8
  %async_frame1_118289_store_address = getelementptr i8, ptr %async_frame1_store, i64 0
  %async_frame1_118289_stored = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  store %sollang.struct.m17_s46 %async_frame1_118289_stored, ptr %async_frame1_118289_store_address, align 8
  %async_frame1_118292_store_address = getelementptr i8, ptr %async_frame1_store, i64 8
  %async_frame1_118292_stored = load { ptr, i64 }, ptr %slot118292, align 8
  store { ptr, i64 } %async_frame1_118292_stored, ptr %async_frame1_118292_store_address, align 8
  %async_frame1_118320_store_address = getelementptr i8, ptr %async_frame1_store, i64 24
  %async_frame1_118320_stored = load %sollang.task, ptr %async_local118320, align 8
  store %sollang.task %async_frame1_118320_stored, ptr %async_frame1_118320_store_address, align 8
  %async_frame1_118320_store_flag_address = getelementptr i8, ptr %async_frame1_store, i64 40
  %async_frame1_118320_store_flag = load i1, ptr %v118320_owned, align 1
  store i1 %async_frame1_118320_store_flag, ptr %async_frame1_118320_store_flag_address, align 1
  store i32 1, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume1:
  %async_frame1_load = load ptr, ptr %async_frame_slot, align 8
  %async_frame1_118289_load_address = getelementptr i8, ptr %async_frame1_load, i64 0
  %async_frame1_118289_loaded = load %sollang.struct.m17_s46, ptr %async_frame1_118289_load_address, align 8
  store %sollang.struct.m17_s46 %async_frame1_118289_loaded, ptr %slot118289, align 8
  %async_frame1_118292_load_address = getelementptr i8, ptr %async_frame1_load, i64 8
  %async_frame1_118292_loaded = load { ptr, i64 }, ptr %async_frame1_118292_load_address, align 8
  store { ptr, i64 } %async_frame1_118292_loaded, ptr %slot118292, align 8
  %async_frame1_118320_load_address = getelementptr i8, ptr %async_frame1_load, i64 24
  %async_frame1_118320_loaded = load %sollang.task, ptr %async_frame1_118320_load_address, align 8
  store %sollang.task %async_frame1_118320_loaded, ptr %async_local118320, align 8
  %async_frame1_118320_load_flag_address = getelementptr i8, ptr %async_frame1_load, i64 40
  %async_frame1_118320_load_flag = load i1, ptr %async_frame1_118320_load_flag_address, align 1
  store i1 %async_frame1_118320_load_flag, ptr %v118320_owned, align 1
  call void @free(ptr %async_frame1_load)
  store ptr null, ptr %async_frame_slot, align 8
  %v118327 = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  %v118328 = load { ptr, i64 }, ptr %slot118292, align 8
  %snap118326_output_fixed = load { ptr, i64 }, ptr %slot118292, align 8
  %snap118326_output = extractvalue { ptr, i64 } %snap118326_output_fixed, 0
  %snap118326_token = extractvalue %sollang.struct.m17_s46 %v118327, 0
  %snap118326_session = inttoptr i64 %snap118326_token to ptr
  %snap118326_count_slot = getelementptr i8, ptr %snap118326_session, i64 16
  %snap118326_count = load i64, ptr %snap118326_count_slot, align 8
  %snap118326_records_slot = getelementptr i8, ptr %snap118326_session, i64 32
  %snap118326_records = load ptr, ptr %snap118326_records_slot, align 8
  %snap118326_row0_present = icmp ugt i64 %snap118326_count, 0
  br i1 %snap118326_row0_present, label %snap118326_row0_write, label %snap118326_row0_next
snap118326_row0_write:
  %snap118326_row0_record = getelementptr i8, ptr %snap118326_records, i64 0
  %snap118326_row0_destination = getelementptr %sollang.struct.m17_s29, ptr %snap118326_output, i64 0
  store %sollang.struct.m17_s29 zeroinitializer, ptr %snap118326_row0_destination, align 8
  %snap118326_row0_field0 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 0
  %snap118326_row0_field1 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 1
  %snap118326_row0_field2 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 2
  %snap118326_row0_field3 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 3
  %snap118326_row0_field4 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 4
  %snap118326_row0_field5 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 5
  %snap118326_row0_field6 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row0_destination, i32 0, i32 6
  %snap118326_row0_task_slot = getelementptr i8, ptr %snap118326_row0_record, i64 0
  %snap118326_row0_task = load i64, ptr %snap118326_row0_task_slot, align 8
  %snap118326_row0_parent_slot = getelementptr i8, ptr %snap118326_row0_record, i64 8
  %snap118326_row0_parent = load i64, ptr %snap118326_row0_parent_slot, align 8
  %snap118326_row0_awaited_slot = getelementptr i8, ptr %snap118326_row0_record, i64 32
  %snap118326_row0_awaited = load i64, ptr %snap118326_row0_awaited_slot, align 8
  %snap118326_row0_deadline_slot = getelementptr i8, ptr %snap118326_row0_record, i64 40
  %snap118326_row0_deadline = load i64, ptr %snap118326_row0_deadline_slot, align 8
  %snap118326_row0_resume_slot = getelementptr i8, ptr %snap118326_row0_record, i64 28
  %snap118326_row0_resume = load i32, ptr %snap118326_row0_resume_slot, align 4
  %snap118326_row0_status = call i32 @sollang_diagnostic_observed_status(ptr %snap118326_row0_record)
  store i64 %snap118326_row0_task, ptr %snap118326_row0_field0, align 8
  %snap118326_row0_field1_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row0_field1, i32 0, i32 0
  %snap118326_row0_field1_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row0_field1, i32 0, i32 1
  %snap118326_row0_field1_present = icmp ne i64 %snap118326_row0_parent, 0
  %snap118326_row0_field1_ordinal = zext i1 %snap118326_row0_field1_present to i32
  store i32 %snap118326_row0_field1_ordinal, ptr %snap118326_row0_field1_tag, align 4
  store i64 %snap118326_row0_parent, ptr %snap118326_row0_field1_payload, align 8
  %snap118326_row0_field4_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row0_field4, i32 0, i32 0
  %snap118326_row0_field4_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row0_field4, i32 0, i32 1
  %snap118326_row0_field4_present = icmp ne i64 %snap118326_row0_awaited, 0
  %snap118326_row0_field4_ordinal = zext i1 %snap118326_row0_field4_present to i32
  store i32 %snap118326_row0_field4_ordinal, ptr %snap118326_row0_field4_tag, align 4
  store i64 %snap118326_row0_awaited, ptr %snap118326_row0_field4_payload, align 8
  %snap118326_row0_completed = icmp eq i32 %snap118326_row0_status, 2
  %snap118326_row0_cancelled = icmp eq i32 %snap118326_row0_status, 3
  %snap118326_row0_running = icmp eq i32 %snap118326_row0_status, 1
  %snap118326_row0_pending_running = select i1 %snap118326_row0_running, i32 1, i32 0
  %snap118326_row0_completed_earlier = select i1 %snap118326_row0_completed, i32 2, i32 %snap118326_row0_pending_running
  %snap118326_row0_lifecycle = select i1 %snap118326_row0_cancelled, i32 3, i32 %snap118326_row0_completed_earlier
  %snap118326_row0_lifecycle_slot = getelementptr inbounds %sollang.enum.t295, ptr %snap118326_row0_field2, i32 0, i32 0
  store i32 %snap118326_row0_lifecycle, ptr %snap118326_row0_lifecycle_slot, align 4
  %snap118326_row0_ready = icmp eq i32 %snap118326_row0_status, 0
  %snap118326_row0_timer = icmp eq i32 %snap118326_row0_status, 4
  %snap118326_row0_blocked = icmp eq i32 %snap118326_row0_status, 5
  %snap118326_row0_ready_tag = select i1 %snap118326_row0_ready, i32 1, i32 0
  %snap118326_row0_timer_tag = select i1 %snap118326_row0_timer, i32 2, i32 %snap118326_row0_ready_tag
  %snap118326_row0_wait = select i1 %snap118326_row0_blocked, i32 3, i32 %snap118326_row0_timer_tag
  %snap118326_row0_wait_slot = getelementptr inbounds %sollang.enum.t296, ptr %snap118326_row0_field3, i32 0, i32 0
  store i32 %snap118326_row0_wait, ptr %snap118326_row0_wait_slot, align 4
  %snap118326_row0_visible_deadline = select i1 %snap118326_row0_timer, i64 %snap118326_row0_deadline, i64 0
  store i64 %snap118326_row0_visible_deadline, ptr %snap118326_row0_field5, align 8
  %snap118326_row0_has_resume = icmp ne i32 %snap118326_row0_resume, 0
  %snap118326_row0_no_deadline = icmp eq i64 %snap118326_row0_deadline, 0
  %snap118326_row0_visible_state = or i1 %snap118326_row0_no_deadline, %snap118326_row0_timer
  %snap118326_row0_has_locator = and i1 %snap118326_row0_has_resume, %snap118326_row0_visible_state
  br i1 %snap118326_row0_has_locator, label %snap118326_row0_locator, label %snap118326_row0_done
snap118326_row0_locator:
  %snap118326_row0_locator_tag = getelementptr inbounds %sollang.enum.t309, ptr %snap118326_row0_field6, i32 0, i32 0
  %snap118326_row0_locator_payload = getelementptr inbounds %sollang.enum.t309, ptr %snap118326_row0_field6, i32 0, i32 1
  store i32 1, ptr %snap118326_row0_locator_tag, align 4
  %snap118326_row0_locator_field0 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row0_locator_payload, i32 0, i32 0
  %snap118326_row0_locator_field1 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row0_locator_payload, i32 0, i32 1
  %snap118326_row0_locator_field2 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row0_locator_payload, i32 0, i32 2
  %snap118326_row0_locator_field3 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row0_locator_payload, i32 0, i32 3
  %snap118326_row0_locator_field4 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row0_locator_payload, i32 0, i32 4
  %snap118326_row0_locator_field5 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row0_locator_payload, i32 0, i32 5
  %snap118326_row0_text0_ptr_slot = getelementptr i8, ptr %snap118326_row0_record, i64 48
  %snap118326_row0_text0_ptr = load ptr, ptr %snap118326_row0_text0_ptr_slot, align 8
  %snap118326_row0_text0_len_slot = getelementptr i8, ptr %snap118326_row0_record, i64 56
  %snap118326_row0_text0_len = load i64, ptr %snap118326_row0_text0_len_slot, align 8
  %snap118326_row0_text0_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118326_row0_text0_ptr, 0
  %snap118326_row0_text0 = insertvalue %sollang.text %snap118326_row0_text0_0, i64 %snap118326_row0_text0_len, 1
  store %sollang.text %snap118326_row0_text0, ptr %snap118326_row0_locator_field0, align 8
  %snap118326_row0_text1_ptr_slot = getelementptr i8, ptr %snap118326_row0_record, i64 64
  %snap118326_row0_text1_ptr = load ptr, ptr %snap118326_row0_text1_ptr_slot, align 8
  %snap118326_row0_text1_len_slot = getelementptr i8, ptr %snap118326_row0_record, i64 72
  %snap118326_row0_text1_len = load i64, ptr %snap118326_row0_text1_len_slot, align 8
  %snap118326_row0_text1_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118326_row0_text1_ptr, 0
  %snap118326_row0_text1 = insertvalue %sollang.text %snap118326_row0_text1_0, i64 %snap118326_row0_text1_len, 1
  store %sollang.text %snap118326_row0_text1, ptr %snap118326_row0_locator_field1, align 8
  store i32 %snap118326_row0_resume, ptr %snap118326_row0_locator_field2, align 4
  %snap118326_row0_byte_slot = getelementptr i8, ptr %snap118326_row0_record, i64 80
  %snap118326_row0_byte = load i64, ptr %snap118326_row0_byte_slot, align 8
  store i64 %snap118326_row0_byte, ptr %snap118326_row0_locator_field3, align 8
  %snap118326_row0_coordinate4_slot = getelementptr i8, ptr %snap118326_row0_record, i64 88
  %snap118326_row0_coordinate4 = load i64, ptr %snap118326_row0_coordinate4_slot, align 8
  %snap118326_row0_coordinate4_narrow = trunc i64 %snap118326_row0_coordinate4 to i32
  store i32 %snap118326_row0_coordinate4_narrow, ptr %snap118326_row0_locator_field4, align 4
  %snap118326_row0_coordinate5_slot = getelementptr i8, ptr %snap118326_row0_record, i64 96
  %snap118326_row0_coordinate5 = load i64, ptr %snap118326_row0_coordinate5_slot, align 8
  %snap118326_row0_coordinate5_narrow = trunc i64 %snap118326_row0_coordinate5 to i32
  store i32 %snap118326_row0_coordinate5_narrow, ptr %snap118326_row0_locator_field5, align 4
  br label %snap118326_row0_done
snap118326_row0_done:
  br label %snap118326_row0_next
snap118326_row0_next:
  %snap118326_row1_present = icmp ugt i64 %snap118326_count, 1
  br i1 %snap118326_row1_present, label %snap118326_row1_write, label %snap118326_row1_next
snap118326_row1_write:
  %snap118326_row1_record = getelementptr i8, ptr %snap118326_records, i64 112
  %snap118326_row1_destination = getelementptr %sollang.struct.m17_s29, ptr %snap118326_output, i64 1
  store %sollang.struct.m17_s29 zeroinitializer, ptr %snap118326_row1_destination, align 8
  %snap118326_row1_field0 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 0
  %snap118326_row1_field1 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 1
  %snap118326_row1_field2 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 2
  %snap118326_row1_field3 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 3
  %snap118326_row1_field4 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 4
  %snap118326_row1_field5 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 5
  %snap118326_row1_field6 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118326_row1_destination, i32 0, i32 6
  %snap118326_row1_task_slot = getelementptr i8, ptr %snap118326_row1_record, i64 0
  %snap118326_row1_task = load i64, ptr %snap118326_row1_task_slot, align 8
  %snap118326_row1_parent_slot = getelementptr i8, ptr %snap118326_row1_record, i64 8
  %snap118326_row1_parent = load i64, ptr %snap118326_row1_parent_slot, align 8
  %snap118326_row1_awaited_slot = getelementptr i8, ptr %snap118326_row1_record, i64 32
  %snap118326_row1_awaited = load i64, ptr %snap118326_row1_awaited_slot, align 8
  %snap118326_row1_deadline_slot = getelementptr i8, ptr %snap118326_row1_record, i64 40
  %snap118326_row1_deadline = load i64, ptr %snap118326_row1_deadline_slot, align 8
  %snap118326_row1_resume_slot = getelementptr i8, ptr %snap118326_row1_record, i64 28
  %snap118326_row1_resume = load i32, ptr %snap118326_row1_resume_slot, align 4
  %snap118326_row1_status = call i32 @sollang_diagnostic_observed_status(ptr %snap118326_row1_record)
  store i64 %snap118326_row1_task, ptr %snap118326_row1_field0, align 8
  %snap118326_row1_field1_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row1_field1, i32 0, i32 0
  %snap118326_row1_field1_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row1_field1, i32 0, i32 1
  %snap118326_row1_field1_present = icmp ne i64 %snap118326_row1_parent, 0
  %snap118326_row1_field1_ordinal = zext i1 %snap118326_row1_field1_present to i32
  store i32 %snap118326_row1_field1_ordinal, ptr %snap118326_row1_field1_tag, align 4
  store i64 %snap118326_row1_parent, ptr %snap118326_row1_field1_payload, align 8
  %snap118326_row1_field4_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row1_field4, i32 0, i32 0
  %snap118326_row1_field4_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118326_row1_field4, i32 0, i32 1
  %snap118326_row1_field4_present = icmp ne i64 %snap118326_row1_awaited, 0
  %snap118326_row1_field4_ordinal = zext i1 %snap118326_row1_field4_present to i32
  store i32 %snap118326_row1_field4_ordinal, ptr %snap118326_row1_field4_tag, align 4
  store i64 %snap118326_row1_awaited, ptr %snap118326_row1_field4_payload, align 8
  %snap118326_row1_completed = icmp eq i32 %snap118326_row1_status, 2
  %snap118326_row1_cancelled = icmp eq i32 %snap118326_row1_status, 3
  %snap118326_row1_running = icmp eq i32 %snap118326_row1_status, 1
  %snap118326_row1_pending_running = select i1 %snap118326_row1_running, i32 1, i32 0
  %snap118326_row1_completed_earlier = select i1 %snap118326_row1_completed, i32 2, i32 %snap118326_row1_pending_running
  %snap118326_row1_lifecycle = select i1 %snap118326_row1_cancelled, i32 3, i32 %snap118326_row1_completed_earlier
  %snap118326_row1_lifecycle_slot = getelementptr inbounds %sollang.enum.t295, ptr %snap118326_row1_field2, i32 0, i32 0
  store i32 %snap118326_row1_lifecycle, ptr %snap118326_row1_lifecycle_slot, align 4
  %snap118326_row1_ready = icmp eq i32 %snap118326_row1_status, 0
  %snap118326_row1_timer = icmp eq i32 %snap118326_row1_status, 4
  %snap118326_row1_blocked = icmp eq i32 %snap118326_row1_status, 5
  %snap118326_row1_ready_tag = select i1 %snap118326_row1_ready, i32 1, i32 0
  %snap118326_row1_timer_tag = select i1 %snap118326_row1_timer, i32 2, i32 %snap118326_row1_ready_tag
  %snap118326_row1_wait = select i1 %snap118326_row1_blocked, i32 3, i32 %snap118326_row1_timer_tag
  %snap118326_row1_wait_slot = getelementptr inbounds %sollang.enum.t296, ptr %snap118326_row1_field3, i32 0, i32 0
  store i32 %snap118326_row1_wait, ptr %snap118326_row1_wait_slot, align 4
  %snap118326_row1_visible_deadline = select i1 %snap118326_row1_timer, i64 %snap118326_row1_deadline, i64 0
  store i64 %snap118326_row1_visible_deadline, ptr %snap118326_row1_field5, align 8
  %snap118326_row1_has_resume = icmp ne i32 %snap118326_row1_resume, 0
  %snap118326_row1_no_deadline = icmp eq i64 %snap118326_row1_deadline, 0
  %snap118326_row1_visible_state = or i1 %snap118326_row1_no_deadline, %snap118326_row1_timer
  %snap118326_row1_has_locator = and i1 %snap118326_row1_has_resume, %snap118326_row1_visible_state
  br i1 %snap118326_row1_has_locator, label %snap118326_row1_locator, label %snap118326_row1_done
snap118326_row1_locator:
  %snap118326_row1_locator_tag = getelementptr inbounds %sollang.enum.t309, ptr %snap118326_row1_field6, i32 0, i32 0
  %snap118326_row1_locator_payload = getelementptr inbounds %sollang.enum.t309, ptr %snap118326_row1_field6, i32 0, i32 1
  store i32 1, ptr %snap118326_row1_locator_tag, align 4
  %snap118326_row1_locator_field0 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row1_locator_payload, i32 0, i32 0
  %snap118326_row1_locator_field1 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row1_locator_payload, i32 0, i32 1
  %snap118326_row1_locator_field2 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row1_locator_payload, i32 0, i32 2
  %snap118326_row1_locator_field3 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row1_locator_payload, i32 0, i32 3
  %snap118326_row1_locator_field4 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row1_locator_payload, i32 0, i32 4
  %snap118326_row1_locator_field5 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118326_row1_locator_payload, i32 0, i32 5
  %snap118326_row1_text0_ptr_slot = getelementptr i8, ptr %snap118326_row1_record, i64 48
  %snap118326_row1_text0_ptr = load ptr, ptr %snap118326_row1_text0_ptr_slot, align 8
  %snap118326_row1_text0_len_slot = getelementptr i8, ptr %snap118326_row1_record, i64 56
  %snap118326_row1_text0_len = load i64, ptr %snap118326_row1_text0_len_slot, align 8
  %snap118326_row1_text0_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118326_row1_text0_ptr, 0
  %snap118326_row1_text0 = insertvalue %sollang.text %snap118326_row1_text0_0, i64 %snap118326_row1_text0_len, 1
  store %sollang.text %snap118326_row1_text0, ptr %snap118326_row1_locator_field0, align 8
  %snap118326_row1_text1_ptr_slot = getelementptr i8, ptr %snap118326_row1_record, i64 64
  %snap118326_row1_text1_ptr = load ptr, ptr %snap118326_row1_text1_ptr_slot, align 8
  %snap118326_row1_text1_len_slot = getelementptr i8, ptr %snap118326_row1_record, i64 72
  %snap118326_row1_text1_len = load i64, ptr %snap118326_row1_text1_len_slot, align 8
  %snap118326_row1_text1_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118326_row1_text1_ptr, 0
  %snap118326_row1_text1 = insertvalue %sollang.text %snap118326_row1_text1_0, i64 %snap118326_row1_text1_len, 1
  store %sollang.text %snap118326_row1_text1, ptr %snap118326_row1_locator_field1, align 8
  store i32 %snap118326_row1_resume, ptr %snap118326_row1_locator_field2, align 4
  %snap118326_row1_byte_slot = getelementptr i8, ptr %snap118326_row1_record, i64 80
  %snap118326_row1_byte = load i64, ptr %snap118326_row1_byte_slot, align 8
  store i64 %snap118326_row1_byte, ptr %snap118326_row1_locator_field3, align 8
  %snap118326_row1_coordinate4_slot = getelementptr i8, ptr %snap118326_row1_record, i64 88
  %snap118326_row1_coordinate4 = load i64, ptr %snap118326_row1_coordinate4_slot, align 8
  %snap118326_row1_coordinate4_narrow = trunc i64 %snap118326_row1_coordinate4 to i32
  store i32 %snap118326_row1_coordinate4_narrow, ptr %snap118326_row1_locator_field4, align 4
  %snap118326_row1_coordinate5_slot = getelementptr i8, ptr %snap118326_row1_record, i64 96
  %snap118326_row1_coordinate5 = load i64, ptr %snap118326_row1_coordinate5_slot, align 8
  %snap118326_row1_coordinate5_narrow = trunc i64 %snap118326_row1_coordinate5 to i32
  store i32 %snap118326_row1_coordinate5_narrow, ptr %snap118326_row1_locator_field5, align 4
  br label %snap118326_row1_done
snap118326_row1_done:
  br label %snap118326_row1_next
snap118326_row1_next:
  %snap118326_id_slot = getelementptr i8, ptr %snap118326_session, i64 0
  %snap118326_id = load i64, ptr %snap118326_id_slot, align 8
  %snap118326_truncated = icmp ugt i64 %snap118326_count, 2
  %snap118326_written = select i1 %snap118326_truncated, i64 2, i64 %snap118326_count
  %snap118326_summary0 = insertvalue %sollang.struct.m17_s37 zeroinitializer, i64 %snap118326_id, 0
  %snap118326_summary1 = insertvalue %sollang.struct.m17_s37 %snap118326_summary0, i64 %snap118326_written, 1
  %snap118326_summary2 = insertvalue %sollang.struct.m17_s37 %snap118326_summary1, i64 %snap118326_count, 2
  %snap118326_summary3 = insertvalue %sollang.struct.m17_s37 %snap118326_summary2, i1 %snap118326_truncated, 3
  %v118326 = freeze %sollang.struct.m17_s37 %snap118326_summary3
  store %sollang.struct.m17_s37 %v118326, ptr %async_local118293, align 8
  %v118330 = load %sollang.struct.m17_s37, ptr %async_local118293, align 8
  %v118331 = load { ptr, i64 }, ptr %slot118292, align 8
  %v118329 = call { ptr, i64 } @sollang_m144_s18(%sollang.struct.m17_s37 %v118330, { ptr, i64 } %v118331)
  %named_fixed_call118329_1 = extractvalue { ptr, i64 } %v118331, 0
  call void @free(ptr %named_fixed_call118329_1)
  store { ptr, i64 } %v118329, ptr %slot118294, align 8
  %diagnostic_suspend2_header = getelementptr i8, ptr %async_context, i64 32
  call void @sollang_diagnostic_suspend(ptr %diagnostic_suspend2_header, ptr null, i32 2, ptr @sollang_diagnostic_module118286, i64 58, ptr @sollang_diagnostic_symbol118286, i64 7, i64 3699, i64 96, i64 21, i64 0)
  %async_frame2_store = call ptr @malloc(i64 73)
  %async_frame2_allocated = icmp ne ptr %async_frame2_store, null
  br i1 %async_frame2_allocated, label %async_frame2_ready, label %async_frame2_failed
async_frame2_failed:
  call void @llvm.trap()
  unreachable
async_frame2_ready:
  store ptr %async_frame2_store, ptr %async_frame_slot, align 8
  %async_frame2_118289_store_address = getelementptr i8, ptr %async_frame2_store, i64 0
  %async_frame2_118289_stored = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  store %sollang.struct.m17_s46 %async_frame2_118289_stored, ptr %async_frame2_118289_store_address, align 8
  %async_frame2_118293_store_address = getelementptr i8, ptr %async_frame2_store, i64 8
  %async_frame2_118293_stored = load %sollang.struct.m17_s37, ptr %async_local118293, align 8
  store %sollang.struct.m17_s37 %async_frame2_118293_stored, ptr %async_frame2_118293_store_address, align 8
  %async_frame2_118294_store_address = getelementptr i8, ptr %async_frame2_store, i64 40
  %async_frame2_118294_stored = load { ptr, i64 }, ptr %slot118294, align 8
  store { ptr, i64 } %async_frame2_118294_stored, ptr %async_frame2_118294_store_address, align 8
  %async_frame2_118320_store_address = getelementptr i8, ptr %async_frame2_store, i64 56
  %async_frame2_118320_stored = load %sollang.task, ptr %async_local118320, align 8
  store %sollang.task %async_frame2_118320_stored, ptr %async_frame2_118320_store_address, align 8
  %async_frame2_118320_store_flag_address = getelementptr i8, ptr %async_frame2_store, i64 72
  %async_frame2_118320_store_flag = load i1, ptr %v118320_owned, align 1
  store i1 %async_frame2_118320_store_flag, ptr %async_frame2_118320_store_flag_address, align 1
  store i32 2, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume2:
  %async_frame2_load = load ptr, ptr %async_frame_slot, align 8
  %async_frame2_118289_load_address = getelementptr i8, ptr %async_frame2_load, i64 0
  %async_frame2_118289_loaded = load %sollang.struct.m17_s46, ptr %async_frame2_118289_load_address, align 8
  store %sollang.struct.m17_s46 %async_frame2_118289_loaded, ptr %slot118289, align 8
  %async_frame2_118293_load_address = getelementptr i8, ptr %async_frame2_load, i64 8
  %async_frame2_118293_loaded = load %sollang.struct.m17_s37, ptr %async_frame2_118293_load_address, align 8
  store %sollang.struct.m17_s37 %async_frame2_118293_loaded, ptr %async_local118293, align 8
  %async_frame2_118294_load_address = getelementptr i8, ptr %async_frame2_load, i64 40
  %async_frame2_118294_loaded = load { ptr, i64 }, ptr %async_frame2_118294_load_address, align 8
  store { ptr, i64 } %async_frame2_118294_loaded, ptr %slot118294, align 8
  %async_frame2_118320_load_address = getelementptr i8, ptr %async_frame2_load, i64 56
  %async_frame2_118320_loaded = load %sollang.task, ptr %async_frame2_118320_load_address, align 8
  store %sollang.task %async_frame2_118320_loaded, ptr %async_local118320, align 8
  %async_frame2_118320_load_flag_address = getelementptr i8, ptr %async_frame2_load, i64 72
  %async_frame2_118320_load_flag = load i1, ptr %async_frame2_118320_load_flag_address, align 1
  store i1 %async_frame2_118320_load_flag, ptr %v118320_owned, align 1
  call void @free(ptr %async_frame2_load)
  store ptr null, ptr %async_frame_slot, align 8
  %v118334 = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  %v118335 = load { ptr, i64 }, ptr %slot118294, align 8
  %snap118333_output_fixed = load { ptr, i64 }, ptr %slot118294, align 8
  %snap118333_output = extractvalue { ptr, i64 } %snap118333_output_fixed, 0
  %snap118333_token = extractvalue %sollang.struct.m17_s46 %v118334, 0
  %snap118333_session = inttoptr i64 %snap118333_token to ptr
  %snap118333_count_slot = getelementptr i8, ptr %snap118333_session, i64 16
  %snap118333_count = load i64, ptr %snap118333_count_slot, align 8
  %snap118333_records_slot = getelementptr i8, ptr %snap118333_session, i64 32
  %snap118333_records = load ptr, ptr %snap118333_records_slot, align 8
  %snap118333_row0_present = icmp ugt i64 %snap118333_count, 0
  br i1 %snap118333_row0_present, label %snap118333_row0_write, label %snap118333_row0_next
snap118333_row0_write:
  %snap118333_row0_record = getelementptr i8, ptr %snap118333_records, i64 0
  %snap118333_row0_destination = getelementptr %sollang.struct.m17_s29, ptr %snap118333_output, i64 0
  store %sollang.struct.m17_s29 zeroinitializer, ptr %snap118333_row0_destination, align 8
  %snap118333_row0_field0 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 0
  %snap118333_row0_field1 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 1
  %snap118333_row0_field2 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 2
  %snap118333_row0_field3 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 3
  %snap118333_row0_field4 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 4
  %snap118333_row0_field5 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 5
  %snap118333_row0_field6 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row0_destination, i32 0, i32 6
  %snap118333_row0_task_slot = getelementptr i8, ptr %snap118333_row0_record, i64 0
  %snap118333_row0_task = load i64, ptr %snap118333_row0_task_slot, align 8
  %snap118333_row0_parent_slot = getelementptr i8, ptr %snap118333_row0_record, i64 8
  %snap118333_row0_parent = load i64, ptr %snap118333_row0_parent_slot, align 8
  %snap118333_row0_awaited_slot = getelementptr i8, ptr %snap118333_row0_record, i64 32
  %snap118333_row0_awaited = load i64, ptr %snap118333_row0_awaited_slot, align 8
  %snap118333_row0_deadline_slot = getelementptr i8, ptr %snap118333_row0_record, i64 40
  %snap118333_row0_deadline = load i64, ptr %snap118333_row0_deadline_slot, align 8
  %snap118333_row0_resume_slot = getelementptr i8, ptr %snap118333_row0_record, i64 28
  %snap118333_row0_resume = load i32, ptr %snap118333_row0_resume_slot, align 4
  %snap118333_row0_status = call i32 @sollang_diagnostic_observed_status(ptr %snap118333_row0_record)
  store i64 %snap118333_row0_task, ptr %snap118333_row0_field0, align 8
  %snap118333_row0_field1_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row0_field1, i32 0, i32 0
  %snap118333_row0_field1_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row0_field1, i32 0, i32 1
  %snap118333_row0_field1_present = icmp ne i64 %snap118333_row0_parent, 0
  %snap118333_row0_field1_ordinal = zext i1 %snap118333_row0_field1_present to i32
  store i32 %snap118333_row0_field1_ordinal, ptr %snap118333_row0_field1_tag, align 4
  store i64 %snap118333_row0_parent, ptr %snap118333_row0_field1_payload, align 8
  %snap118333_row0_field4_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row0_field4, i32 0, i32 0
  %snap118333_row0_field4_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row0_field4, i32 0, i32 1
  %snap118333_row0_field4_present = icmp ne i64 %snap118333_row0_awaited, 0
  %snap118333_row0_field4_ordinal = zext i1 %snap118333_row0_field4_present to i32
  store i32 %snap118333_row0_field4_ordinal, ptr %snap118333_row0_field4_tag, align 4
  store i64 %snap118333_row0_awaited, ptr %snap118333_row0_field4_payload, align 8
  %snap118333_row0_completed = icmp eq i32 %snap118333_row0_status, 2
  %snap118333_row0_cancelled = icmp eq i32 %snap118333_row0_status, 3
  %snap118333_row0_running = icmp eq i32 %snap118333_row0_status, 1
  %snap118333_row0_pending_running = select i1 %snap118333_row0_running, i32 1, i32 0
  %snap118333_row0_completed_earlier = select i1 %snap118333_row0_completed, i32 2, i32 %snap118333_row0_pending_running
  %snap118333_row0_lifecycle = select i1 %snap118333_row0_cancelled, i32 3, i32 %snap118333_row0_completed_earlier
  %snap118333_row0_lifecycle_slot = getelementptr inbounds %sollang.enum.t295, ptr %snap118333_row0_field2, i32 0, i32 0
  store i32 %snap118333_row0_lifecycle, ptr %snap118333_row0_lifecycle_slot, align 4
  %snap118333_row0_ready = icmp eq i32 %snap118333_row0_status, 0
  %snap118333_row0_timer = icmp eq i32 %snap118333_row0_status, 4
  %snap118333_row0_blocked = icmp eq i32 %snap118333_row0_status, 5
  %snap118333_row0_ready_tag = select i1 %snap118333_row0_ready, i32 1, i32 0
  %snap118333_row0_timer_tag = select i1 %snap118333_row0_timer, i32 2, i32 %snap118333_row0_ready_tag
  %snap118333_row0_wait = select i1 %snap118333_row0_blocked, i32 3, i32 %snap118333_row0_timer_tag
  %snap118333_row0_wait_slot = getelementptr inbounds %sollang.enum.t296, ptr %snap118333_row0_field3, i32 0, i32 0
  store i32 %snap118333_row0_wait, ptr %snap118333_row0_wait_slot, align 4
  %snap118333_row0_visible_deadline = select i1 %snap118333_row0_timer, i64 %snap118333_row0_deadline, i64 0
  store i64 %snap118333_row0_visible_deadline, ptr %snap118333_row0_field5, align 8
  %snap118333_row0_has_resume = icmp ne i32 %snap118333_row0_resume, 0
  %snap118333_row0_no_deadline = icmp eq i64 %snap118333_row0_deadline, 0
  %snap118333_row0_visible_state = or i1 %snap118333_row0_no_deadline, %snap118333_row0_timer
  %snap118333_row0_has_locator = and i1 %snap118333_row0_has_resume, %snap118333_row0_visible_state
  br i1 %snap118333_row0_has_locator, label %snap118333_row0_locator, label %snap118333_row0_done
snap118333_row0_locator:
  %snap118333_row0_locator_tag = getelementptr inbounds %sollang.enum.t309, ptr %snap118333_row0_field6, i32 0, i32 0
  %snap118333_row0_locator_payload = getelementptr inbounds %sollang.enum.t309, ptr %snap118333_row0_field6, i32 0, i32 1
  store i32 1, ptr %snap118333_row0_locator_tag, align 4
  %snap118333_row0_locator_field0 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row0_locator_payload, i32 0, i32 0
  %snap118333_row0_locator_field1 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row0_locator_payload, i32 0, i32 1
  %snap118333_row0_locator_field2 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row0_locator_payload, i32 0, i32 2
  %snap118333_row0_locator_field3 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row0_locator_payload, i32 0, i32 3
  %snap118333_row0_locator_field4 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row0_locator_payload, i32 0, i32 4
  %snap118333_row0_locator_field5 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row0_locator_payload, i32 0, i32 5
  %snap118333_row0_text0_ptr_slot = getelementptr i8, ptr %snap118333_row0_record, i64 48
  %snap118333_row0_text0_ptr = load ptr, ptr %snap118333_row0_text0_ptr_slot, align 8
  %snap118333_row0_text0_len_slot = getelementptr i8, ptr %snap118333_row0_record, i64 56
  %snap118333_row0_text0_len = load i64, ptr %snap118333_row0_text0_len_slot, align 8
  %snap118333_row0_text0_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118333_row0_text0_ptr, 0
  %snap118333_row0_text0 = insertvalue %sollang.text %snap118333_row0_text0_0, i64 %snap118333_row0_text0_len, 1
  store %sollang.text %snap118333_row0_text0, ptr %snap118333_row0_locator_field0, align 8
  %snap118333_row0_text1_ptr_slot = getelementptr i8, ptr %snap118333_row0_record, i64 64
  %snap118333_row0_text1_ptr = load ptr, ptr %snap118333_row0_text1_ptr_slot, align 8
  %snap118333_row0_text1_len_slot = getelementptr i8, ptr %snap118333_row0_record, i64 72
  %snap118333_row0_text1_len = load i64, ptr %snap118333_row0_text1_len_slot, align 8
  %snap118333_row0_text1_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118333_row0_text1_ptr, 0
  %snap118333_row0_text1 = insertvalue %sollang.text %snap118333_row0_text1_0, i64 %snap118333_row0_text1_len, 1
  store %sollang.text %snap118333_row0_text1, ptr %snap118333_row0_locator_field1, align 8
  store i32 %snap118333_row0_resume, ptr %snap118333_row0_locator_field2, align 4
  %snap118333_row0_byte_slot = getelementptr i8, ptr %snap118333_row0_record, i64 80
  %snap118333_row0_byte = load i64, ptr %snap118333_row0_byte_slot, align 8
  store i64 %snap118333_row0_byte, ptr %snap118333_row0_locator_field3, align 8
  %snap118333_row0_coordinate4_slot = getelementptr i8, ptr %snap118333_row0_record, i64 88
  %snap118333_row0_coordinate4 = load i64, ptr %snap118333_row0_coordinate4_slot, align 8
  %snap118333_row0_coordinate4_narrow = trunc i64 %snap118333_row0_coordinate4 to i32
  store i32 %snap118333_row0_coordinate4_narrow, ptr %snap118333_row0_locator_field4, align 4
  %snap118333_row0_coordinate5_slot = getelementptr i8, ptr %snap118333_row0_record, i64 96
  %snap118333_row0_coordinate5 = load i64, ptr %snap118333_row0_coordinate5_slot, align 8
  %snap118333_row0_coordinate5_narrow = trunc i64 %snap118333_row0_coordinate5 to i32
  store i32 %snap118333_row0_coordinate5_narrow, ptr %snap118333_row0_locator_field5, align 4
  br label %snap118333_row0_done
snap118333_row0_done:
  br label %snap118333_row0_next
snap118333_row0_next:
  %snap118333_row1_present = icmp ugt i64 %snap118333_count, 1
  br i1 %snap118333_row1_present, label %snap118333_row1_write, label %snap118333_row1_next
snap118333_row1_write:
  %snap118333_row1_record = getelementptr i8, ptr %snap118333_records, i64 112
  %snap118333_row1_destination = getelementptr %sollang.struct.m17_s29, ptr %snap118333_output, i64 1
  store %sollang.struct.m17_s29 zeroinitializer, ptr %snap118333_row1_destination, align 8
  %snap118333_row1_field0 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 0
  %snap118333_row1_field1 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 1
  %snap118333_row1_field2 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 2
  %snap118333_row1_field3 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 3
  %snap118333_row1_field4 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 4
  %snap118333_row1_field5 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 5
  %snap118333_row1_field6 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118333_row1_destination, i32 0, i32 6
  %snap118333_row1_task_slot = getelementptr i8, ptr %snap118333_row1_record, i64 0
  %snap118333_row1_task = load i64, ptr %snap118333_row1_task_slot, align 8
  %snap118333_row1_parent_slot = getelementptr i8, ptr %snap118333_row1_record, i64 8
  %snap118333_row1_parent = load i64, ptr %snap118333_row1_parent_slot, align 8
  %snap118333_row1_awaited_slot = getelementptr i8, ptr %snap118333_row1_record, i64 32
  %snap118333_row1_awaited = load i64, ptr %snap118333_row1_awaited_slot, align 8
  %snap118333_row1_deadline_slot = getelementptr i8, ptr %snap118333_row1_record, i64 40
  %snap118333_row1_deadline = load i64, ptr %snap118333_row1_deadline_slot, align 8
  %snap118333_row1_resume_slot = getelementptr i8, ptr %snap118333_row1_record, i64 28
  %snap118333_row1_resume = load i32, ptr %snap118333_row1_resume_slot, align 4
  %snap118333_row1_status = call i32 @sollang_diagnostic_observed_status(ptr %snap118333_row1_record)
  store i64 %snap118333_row1_task, ptr %snap118333_row1_field0, align 8
  %snap118333_row1_field1_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row1_field1, i32 0, i32 0
  %snap118333_row1_field1_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row1_field1, i32 0, i32 1
  %snap118333_row1_field1_present = icmp ne i64 %snap118333_row1_parent, 0
  %snap118333_row1_field1_ordinal = zext i1 %snap118333_row1_field1_present to i32
  store i32 %snap118333_row1_field1_ordinal, ptr %snap118333_row1_field1_tag, align 4
  store i64 %snap118333_row1_parent, ptr %snap118333_row1_field1_payload, align 8
  %snap118333_row1_field4_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row1_field4, i32 0, i32 0
  %snap118333_row1_field4_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118333_row1_field4, i32 0, i32 1
  %snap118333_row1_field4_present = icmp ne i64 %snap118333_row1_awaited, 0
  %snap118333_row1_field4_ordinal = zext i1 %snap118333_row1_field4_present to i32
  store i32 %snap118333_row1_field4_ordinal, ptr %snap118333_row1_field4_tag, align 4
  store i64 %snap118333_row1_awaited, ptr %snap118333_row1_field4_payload, align 8
  %snap118333_row1_completed = icmp eq i32 %snap118333_row1_status, 2
  %snap118333_row1_cancelled = icmp eq i32 %snap118333_row1_status, 3
  %snap118333_row1_running = icmp eq i32 %snap118333_row1_status, 1
  %snap118333_row1_pending_running = select i1 %snap118333_row1_running, i32 1, i32 0
  %snap118333_row1_completed_earlier = select i1 %snap118333_row1_completed, i32 2, i32 %snap118333_row1_pending_running
  %snap118333_row1_lifecycle = select i1 %snap118333_row1_cancelled, i32 3, i32 %snap118333_row1_completed_earlier
  %snap118333_row1_lifecycle_slot = getelementptr inbounds %sollang.enum.t295, ptr %snap118333_row1_field2, i32 0, i32 0
  store i32 %snap118333_row1_lifecycle, ptr %snap118333_row1_lifecycle_slot, align 4
  %snap118333_row1_ready = icmp eq i32 %snap118333_row1_status, 0
  %snap118333_row1_timer = icmp eq i32 %snap118333_row1_status, 4
  %snap118333_row1_blocked = icmp eq i32 %snap118333_row1_status, 5
  %snap118333_row1_ready_tag = select i1 %snap118333_row1_ready, i32 1, i32 0
  %snap118333_row1_timer_tag = select i1 %snap118333_row1_timer, i32 2, i32 %snap118333_row1_ready_tag
  %snap118333_row1_wait = select i1 %snap118333_row1_blocked, i32 3, i32 %snap118333_row1_timer_tag
  %snap118333_row1_wait_slot = getelementptr inbounds %sollang.enum.t296, ptr %snap118333_row1_field3, i32 0, i32 0
  store i32 %snap118333_row1_wait, ptr %snap118333_row1_wait_slot, align 4
  %snap118333_row1_visible_deadline = select i1 %snap118333_row1_timer, i64 %snap118333_row1_deadline, i64 0
  store i64 %snap118333_row1_visible_deadline, ptr %snap118333_row1_field5, align 8
  %snap118333_row1_has_resume = icmp ne i32 %snap118333_row1_resume, 0
  %snap118333_row1_no_deadline = icmp eq i64 %snap118333_row1_deadline, 0
  %snap118333_row1_visible_state = or i1 %snap118333_row1_no_deadline, %snap118333_row1_timer
  %snap118333_row1_has_locator = and i1 %snap118333_row1_has_resume, %snap118333_row1_visible_state
  br i1 %snap118333_row1_has_locator, label %snap118333_row1_locator, label %snap118333_row1_done
snap118333_row1_locator:
  %snap118333_row1_locator_tag = getelementptr inbounds %sollang.enum.t309, ptr %snap118333_row1_field6, i32 0, i32 0
  %snap118333_row1_locator_payload = getelementptr inbounds %sollang.enum.t309, ptr %snap118333_row1_field6, i32 0, i32 1
  store i32 1, ptr %snap118333_row1_locator_tag, align 4
  %snap118333_row1_locator_field0 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row1_locator_payload, i32 0, i32 0
  %snap118333_row1_locator_field1 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row1_locator_payload, i32 0, i32 1
  %snap118333_row1_locator_field2 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row1_locator_payload, i32 0, i32 2
  %snap118333_row1_locator_field3 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row1_locator_payload, i32 0, i32 3
  %snap118333_row1_locator_field4 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row1_locator_payload, i32 0, i32 4
  %snap118333_row1_locator_field5 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118333_row1_locator_payload, i32 0, i32 5
  %snap118333_row1_text0_ptr_slot = getelementptr i8, ptr %snap118333_row1_record, i64 48
  %snap118333_row1_text0_ptr = load ptr, ptr %snap118333_row1_text0_ptr_slot, align 8
  %snap118333_row1_text0_len_slot = getelementptr i8, ptr %snap118333_row1_record, i64 56
  %snap118333_row1_text0_len = load i64, ptr %snap118333_row1_text0_len_slot, align 8
  %snap118333_row1_text0_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118333_row1_text0_ptr, 0
  %snap118333_row1_text0 = insertvalue %sollang.text %snap118333_row1_text0_0, i64 %snap118333_row1_text0_len, 1
  store %sollang.text %snap118333_row1_text0, ptr %snap118333_row1_locator_field0, align 8
  %snap118333_row1_text1_ptr_slot = getelementptr i8, ptr %snap118333_row1_record, i64 64
  %snap118333_row1_text1_ptr = load ptr, ptr %snap118333_row1_text1_ptr_slot, align 8
  %snap118333_row1_text1_len_slot = getelementptr i8, ptr %snap118333_row1_record, i64 72
  %snap118333_row1_text1_len = load i64, ptr %snap118333_row1_text1_len_slot, align 8
  %snap118333_row1_text1_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118333_row1_text1_ptr, 0
  %snap118333_row1_text1 = insertvalue %sollang.text %snap118333_row1_text1_0, i64 %snap118333_row1_text1_len, 1
  store %sollang.text %snap118333_row1_text1, ptr %snap118333_row1_locator_field1, align 8
  store i32 %snap118333_row1_resume, ptr %snap118333_row1_locator_field2, align 4
  %snap118333_row1_byte_slot = getelementptr i8, ptr %snap118333_row1_record, i64 80
  %snap118333_row1_byte = load i64, ptr %snap118333_row1_byte_slot, align 8
  store i64 %snap118333_row1_byte, ptr %snap118333_row1_locator_field3, align 8
  %snap118333_row1_coordinate4_slot = getelementptr i8, ptr %snap118333_row1_record, i64 88
  %snap118333_row1_coordinate4 = load i64, ptr %snap118333_row1_coordinate4_slot, align 8
  %snap118333_row1_coordinate4_narrow = trunc i64 %snap118333_row1_coordinate4 to i32
  store i32 %snap118333_row1_coordinate4_narrow, ptr %snap118333_row1_locator_field4, align 4
  %snap118333_row1_coordinate5_slot = getelementptr i8, ptr %snap118333_row1_record, i64 96
  %snap118333_row1_coordinate5 = load i64, ptr %snap118333_row1_coordinate5_slot, align 8
  %snap118333_row1_coordinate5_narrow = trunc i64 %snap118333_row1_coordinate5 to i32
  store i32 %snap118333_row1_coordinate5_narrow, ptr %snap118333_row1_locator_field5, align 4
  br label %snap118333_row1_done
snap118333_row1_done:
  br label %snap118333_row1_next
snap118333_row1_next:
  %snap118333_id_slot = getelementptr i8, ptr %snap118333_session, i64 0
  %snap118333_id = load i64, ptr %snap118333_id_slot, align 8
  %snap118333_truncated = icmp ugt i64 %snap118333_count, 2
  %snap118333_written = select i1 %snap118333_truncated, i64 2, i64 %snap118333_count
  %snap118333_summary0 = insertvalue %sollang.struct.m17_s37 zeroinitializer, i64 %snap118333_id, 0
  %snap118333_summary1 = insertvalue %sollang.struct.m17_s37 %snap118333_summary0, i64 %snap118333_written, 1
  %snap118333_summary2 = insertvalue %sollang.struct.m17_s37 %snap118333_summary1, i64 %snap118333_count, 2
  %snap118333_summary3 = insertvalue %sollang.struct.m17_s37 %snap118333_summary2, i1 %snap118333_truncated, 3
  %v118333 = freeze %sollang.struct.m17_s37 %snap118333_summary3
  store %sollang.struct.m17_s37 %v118333, ptr %async_local118295, align 8
  %v118337 = load %sollang.struct.m17_s37, ptr %async_local118295, align 8
  %v118338 = load { ptr, i64 }, ptr %slot118294, align 8
  %v118336 = call { ptr, i64 } @sollang_m144_s18(%sollang.struct.m17_s37 %v118337, { ptr, i64 } %v118338)
  %named_fixed_call118336_1 = extractvalue { ptr, i64 } %v118338, 0
  call void @free(ptr %named_fixed_call118336_1)
  store { ptr, i64 } %v118336, ptr %slot118296, align 8
  %v118339_child_handle_slot = getelementptr i8, ptr %async_context, i64 16
  %v118339_child_context_slot = getelementptr i8, ptr %async_context, i64 24
  %v118339_pending_task = load %sollang.task, ptr %async_local118320, align 8
  %v118339_pending_handle = extractvalue %sollang.task %v118339_pending_task, 0
  %v118339_pending_context = extractvalue %sollang.task %v118339_pending_task, 1
  store ptr %v118339_pending_handle, ptr %v118339_child_handle_slot, align 8
  store ptr %v118339_pending_context, ptr %v118339_child_context_slot, align 8
  %v118339_pending_status_slot = getelementptr %sollang.task_control, ptr %v118339_pending_handle, i32 0, i32 4
  %v118339_pending_status = load i32, ptr %v118339_pending_status_slot, align 4
  %v118339_already_completed = icmp eq i32 %v118339_pending_status, 2
  br i1 %v118339_already_completed, label %await118339_ready, label %await118339_suspend
await118339_suspend:
  %diagnostic_suspend3_header = getelementptr i8, ptr %async_context, i64 32
  %diagnostic_suspend3_child_slot = getelementptr %sollang.diagnostic_task_control, ptr %v118339_pending_handle, i32 0, i32 1
  %diagnostic_suspend3_child = load ptr, ptr %diagnostic_suspend3_child_slot, align 8
  call void @sollang_diagnostic_suspend(ptr %diagnostic_suspend3_header, ptr %diagnostic_suspend3_child, i32 3, ptr @sollang_diagnostic_module118286, i64 58, ptr @sollang_diagnostic_symbol118286, i64 7, i64 3884, i64 99, i64 32, i64 0)
  call void @sollang_task_park_on(ptr %control, ptr %v118339_pending_handle)
  %async_frame3_store = call ptr @malloc(i64 88)
  %async_frame3_allocated = icmp ne ptr %async_frame3_store, null
  br i1 %async_frame3_allocated, label %async_frame3_ready, label %async_frame3_failed
async_frame3_failed:
  call void @llvm.trap()
  unreachable
async_frame3_ready:
  store ptr %async_frame3_store, ptr %async_frame_slot, align 8
  %async_frame3_118289_store_address = getelementptr i8, ptr %async_frame3_store, i64 0
  %async_frame3_118289_stored = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  store %sollang.struct.m17_s46 %async_frame3_118289_stored, ptr %async_frame3_118289_store_address, align 8
  %async_frame3_118293_store_address = getelementptr i8, ptr %async_frame3_store, i64 8
  %async_frame3_118293_stored = load %sollang.struct.m17_s37, ptr %async_local118293, align 8
  store %sollang.struct.m17_s37 %async_frame3_118293_stored, ptr %async_frame3_118293_store_address, align 8
  %async_frame3_118295_store_address = getelementptr i8, ptr %async_frame3_store, i64 40
  %async_frame3_118295_stored = load %sollang.struct.m17_s37, ptr %async_local118295, align 8
  store %sollang.struct.m17_s37 %async_frame3_118295_stored, ptr %async_frame3_118295_store_address, align 8
  %async_frame3_118296_store_address = getelementptr i8, ptr %async_frame3_store, i64 72
  %async_frame3_118296_stored = load { ptr, i64 }, ptr %slot118296, align 8
  store { ptr, i64 } %async_frame3_118296_stored, ptr %async_frame3_118296_store_address, align 8
  store i32 3, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume3:
  %async_frame3_load = load ptr, ptr %async_frame_slot, align 8
  %async_frame3_118289_load_address = getelementptr i8, ptr %async_frame3_load, i64 0
  %async_frame3_118289_loaded = load %sollang.struct.m17_s46, ptr %async_frame3_118289_load_address, align 8
  store %sollang.struct.m17_s46 %async_frame3_118289_loaded, ptr %slot118289, align 8
  %async_frame3_118293_load_address = getelementptr i8, ptr %async_frame3_load, i64 8
  %async_frame3_118293_loaded = load %sollang.struct.m17_s37, ptr %async_frame3_118293_load_address, align 8
  store %sollang.struct.m17_s37 %async_frame3_118293_loaded, ptr %async_local118293, align 8
  %async_frame3_118295_load_address = getelementptr i8, ptr %async_frame3_load, i64 40
  %async_frame3_118295_loaded = load %sollang.struct.m17_s37, ptr %async_frame3_118295_load_address, align 8
  store %sollang.struct.m17_s37 %async_frame3_118295_loaded, ptr %async_local118295, align 8
  %async_frame3_118296_load_address = getelementptr i8, ptr %async_frame3_load, i64 72
  %async_frame3_118296_loaded = load { ptr, i64 }, ptr %async_frame3_118296_load_address, align 8
  store { ptr, i64 } %async_frame3_118296_loaded, ptr %slot118296, align 8
  call void @free(ptr %async_frame3_load)
  store ptr null, ptr %async_frame_slot, align 8
  br label %await118339_ready
await118339_ready:
  %v118339_resumed_handle_slot = getelementptr i8, ptr %async_context, i64 16
  %v118339_resumed_context_slot = getelementptr i8, ptr %async_context, i64 24
  %v118339_task_handle = load ptr, ptr %v118339_resumed_handle_slot, align 8
  %v118339_task_context = load ptr, ptr %v118339_resumed_context_slot, align 8
  store ptr null, ptr %v118339_resumed_handle_slot, align 8
  store ptr null, ptr %v118339_resumed_context_slot, align 8
  %v118339_task_joined = call i1 @sollang_task_join(ptr %v118339_task_handle)
  br i1 %v118339_task_joined, label %await118339_joined, label %await118339_failed
await118339_failed:
  call void @llvm.trap()
  unreachable
await118339_joined:
  %v118339_completion_slot = getelementptr %sollang.task_control, ptr %v118339_task_handle, i32 0, i32 22
  %v118339_completion = load ptr, ptr %v118339_completion_slot, align 8
  %v118339_needs_completion = icmp ne ptr %v118339_completion, null
  br i1 %v118339_needs_completion, label %task_result_v118339_complete, label %task_result_v118339_ready
task_result_v118339_complete:
  call void %v118339_completion(ptr %v118339_task_handle)
  store ptr null, ptr %v118339_completion_slot, align 8
  br label %task_result_v118339_ready
task_result_v118339_ready:
  %v118339_task_released = call i1 @sollang_task_release(ptr %v118339_task_handle)
  br i1 %v118339_task_released, label %await118339_released, label %await118339_release_failed
await118339_release_failed:
  call void @llvm.trap()
  unreachable
await118339_released:
  store i1 false, ptr %v118320_owned, align 1
  %v118341 = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  %v118342 = load { ptr, i64 }, ptr %slot118296, align 8
  %snap118340_output_fixed = load { ptr, i64 }, ptr %slot118296, align 8
  %snap118340_output = extractvalue { ptr, i64 } %snap118340_output_fixed, 0
  %snap118340_token = extractvalue %sollang.struct.m17_s46 %v118341, 0
  %snap118340_session = inttoptr i64 %snap118340_token to ptr
  %snap118340_count_slot = getelementptr i8, ptr %snap118340_session, i64 16
  %snap118340_count = load i64, ptr %snap118340_count_slot, align 8
  %snap118340_records_slot = getelementptr i8, ptr %snap118340_session, i64 32
  %snap118340_records = load ptr, ptr %snap118340_records_slot, align 8
  %snap118340_row0_present = icmp ugt i64 %snap118340_count, 0
  br i1 %snap118340_row0_present, label %snap118340_row0_write, label %snap118340_row0_next
snap118340_row0_write:
  %snap118340_row0_record = getelementptr i8, ptr %snap118340_records, i64 0
  %snap118340_row0_destination = getelementptr %sollang.struct.m17_s29, ptr %snap118340_output, i64 0
  store %sollang.struct.m17_s29 zeroinitializer, ptr %snap118340_row0_destination, align 8
  %snap118340_row0_field0 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 0
  %snap118340_row0_field1 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 1
  %snap118340_row0_field2 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 2
  %snap118340_row0_field3 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 3
  %snap118340_row0_field4 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 4
  %snap118340_row0_field5 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 5
  %snap118340_row0_field6 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row0_destination, i32 0, i32 6
  %snap118340_row0_task_slot = getelementptr i8, ptr %snap118340_row0_record, i64 0
  %snap118340_row0_task = load i64, ptr %snap118340_row0_task_slot, align 8
  %snap118340_row0_parent_slot = getelementptr i8, ptr %snap118340_row0_record, i64 8
  %snap118340_row0_parent = load i64, ptr %snap118340_row0_parent_slot, align 8
  %snap118340_row0_awaited_slot = getelementptr i8, ptr %snap118340_row0_record, i64 32
  %snap118340_row0_awaited = load i64, ptr %snap118340_row0_awaited_slot, align 8
  %snap118340_row0_deadline_slot = getelementptr i8, ptr %snap118340_row0_record, i64 40
  %snap118340_row0_deadline = load i64, ptr %snap118340_row0_deadline_slot, align 8
  %snap118340_row0_resume_slot = getelementptr i8, ptr %snap118340_row0_record, i64 28
  %snap118340_row0_resume = load i32, ptr %snap118340_row0_resume_slot, align 4
  %snap118340_row0_status = call i32 @sollang_diagnostic_observed_status(ptr %snap118340_row0_record)
  store i64 %snap118340_row0_task, ptr %snap118340_row0_field0, align 8
  %snap118340_row0_field1_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row0_field1, i32 0, i32 0
  %snap118340_row0_field1_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row0_field1, i32 0, i32 1
  %snap118340_row0_field1_present = icmp ne i64 %snap118340_row0_parent, 0
  %snap118340_row0_field1_ordinal = zext i1 %snap118340_row0_field1_present to i32
  store i32 %snap118340_row0_field1_ordinal, ptr %snap118340_row0_field1_tag, align 4
  store i64 %snap118340_row0_parent, ptr %snap118340_row0_field1_payload, align 8
  %snap118340_row0_field4_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row0_field4, i32 0, i32 0
  %snap118340_row0_field4_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row0_field4, i32 0, i32 1
  %snap118340_row0_field4_present = icmp ne i64 %snap118340_row0_awaited, 0
  %snap118340_row0_field4_ordinal = zext i1 %snap118340_row0_field4_present to i32
  store i32 %snap118340_row0_field4_ordinal, ptr %snap118340_row0_field4_tag, align 4
  store i64 %snap118340_row0_awaited, ptr %snap118340_row0_field4_payload, align 8
  %snap118340_row0_completed = icmp eq i32 %snap118340_row0_status, 2
  %snap118340_row0_cancelled = icmp eq i32 %snap118340_row0_status, 3
  %snap118340_row0_running = icmp eq i32 %snap118340_row0_status, 1
  %snap118340_row0_pending_running = select i1 %snap118340_row0_running, i32 1, i32 0
  %snap118340_row0_completed_earlier = select i1 %snap118340_row0_completed, i32 2, i32 %snap118340_row0_pending_running
  %snap118340_row0_lifecycle = select i1 %snap118340_row0_cancelled, i32 3, i32 %snap118340_row0_completed_earlier
  %snap118340_row0_lifecycle_slot = getelementptr inbounds %sollang.enum.t295, ptr %snap118340_row0_field2, i32 0, i32 0
  store i32 %snap118340_row0_lifecycle, ptr %snap118340_row0_lifecycle_slot, align 4
  %snap118340_row0_ready = icmp eq i32 %snap118340_row0_status, 0
  %snap118340_row0_timer = icmp eq i32 %snap118340_row0_status, 4
  %snap118340_row0_blocked = icmp eq i32 %snap118340_row0_status, 5
  %snap118340_row0_ready_tag = select i1 %snap118340_row0_ready, i32 1, i32 0
  %snap118340_row0_timer_tag = select i1 %snap118340_row0_timer, i32 2, i32 %snap118340_row0_ready_tag
  %snap118340_row0_wait = select i1 %snap118340_row0_blocked, i32 3, i32 %snap118340_row0_timer_tag
  %snap118340_row0_wait_slot = getelementptr inbounds %sollang.enum.t296, ptr %snap118340_row0_field3, i32 0, i32 0
  store i32 %snap118340_row0_wait, ptr %snap118340_row0_wait_slot, align 4
  %snap118340_row0_visible_deadline = select i1 %snap118340_row0_timer, i64 %snap118340_row0_deadline, i64 0
  store i64 %snap118340_row0_visible_deadline, ptr %snap118340_row0_field5, align 8
  %snap118340_row0_has_resume = icmp ne i32 %snap118340_row0_resume, 0
  %snap118340_row0_no_deadline = icmp eq i64 %snap118340_row0_deadline, 0
  %snap118340_row0_visible_state = or i1 %snap118340_row0_no_deadline, %snap118340_row0_timer
  %snap118340_row0_has_locator = and i1 %snap118340_row0_has_resume, %snap118340_row0_visible_state
  br i1 %snap118340_row0_has_locator, label %snap118340_row0_locator, label %snap118340_row0_done
snap118340_row0_locator:
  %snap118340_row0_locator_tag = getelementptr inbounds %sollang.enum.t309, ptr %snap118340_row0_field6, i32 0, i32 0
  %snap118340_row0_locator_payload = getelementptr inbounds %sollang.enum.t309, ptr %snap118340_row0_field6, i32 0, i32 1
  store i32 1, ptr %snap118340_row0_locator_tag, align 4
  %snap118340_row0_locator_field0 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row0_locator_payload, i32 0, i32 0
  %snap118340_row0_locator_field1 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row0_locator_payload, i32 0, i32 1
  %snap118340_row0_locator_field2 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row0_locator_payload, i32 0, i32 2
  %snap118340_row0_locator_field3 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row0_locator_payload, i32 0, i32 3
  %snap118340_row0_locator_field4 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row0_locator_payload, i32 0, i32 4
  %snap118340_row0_locator_field5 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row0_locator_payload, i32 0, i32 5
  %snap118340_row0_text0_ptr_slot = getelementptr i8, ptr %snap118340_row0_record, i64 48
  %snap118340_row0_text0_ptr = load ptr, ptr %snap118340_row0_text0_ptr_slot, align 8
  %snap118340_row0_text0_len_slot = getelementptr i8, ptr %snap118340_row0_record, i64 56
  %snap118340_row0_text0_len = load i64, ptr %snap118340_row0_text0_len_slot, align 8
  %snap118340_row0_text0_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118340_row0_text0_ptr, 0
  %snap118340_row0_text0 = insertvalue %sollang.text %snap118340_row0_text0_0, i64 %snap118340_row0_text0_len, 1
  store %sollang.text %snap118340_row0_text0, ptr %snap118340_row0_locator_field0, align 8
  %snap118340_row0_text1_ptr_slot = getelementptr i8, ptr %snap118340_row0_record, i64 64
  %snap118340_row0_text1_ptr = load ptr, ptr %snap118340_row0_text1_ptr_slot, align 8
  %snap118340_row0_text1_len_slot = getelementptr i8, ptr %snap118340_row0_record, i64 72
  %snap118340_row0_text1_len = load i64, ptr %snap118340_row0_text1_len_slot, align 8
  %snap118340_row0_text1_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118340_row0_text1_ptr, 0
  %snap118340_row0_text1 = insertvalue %sollang.text %snap118340_row0_text1_0, i64 %snap118340_row0_text1_len, 1
  store %sollang.text %snap118340_row0_text1, ptr %snap118340_row0_locator_field1, align 8
  store i32 %snap118340_row0_resume, ptr %snap118340_row0_locator_field2, align 4
  %snap118340_row0_byte_slot = getelementptr i8, ptr %snap118340_row0_record, i64 80
  %snap118340_row0_byte = load i64, ptr %snap118340_row0_byte_slot, align 8
  store i64 %snap118340_row0_byte, ptr %snap118340_row0_locator_field3, align 8
  %snap118340_row0_coordinate4_slot = getelementptr i8, ptr %snap118340_row0_record, i64 88
  %snap118340_row0_coordinate4 = load i64, ptr %snap118340_row0_coordinate4_slot, align 8
  %snap118340_row0_coordinate4_narrow = trunc i64 %snap118340_row0_coordinate4 to i32
  store i32 %snap118340_row0_coordinate4_narrow, ptr %snap118340_row0_locator_field4, align 4
  %snap118340_row0_coordinate5_slot = getelementptr i8, ptr %snap118340_row0_record, i64 96
  %snap118340_row0_coordinate5 = load i64, ptr %snap118340_row0_coordinate5_slot, align 8
  %snap118340_row0_coordinate5_narrow = trunc i64 %snap118340_row0_coordinate5 to i32
  store i32 %snap118340_row0_coordinate5_narrow, ptr %snap118340_row0_locator_field5, align 4
  br label %snap118340_row0_done
snap118340_row0_done:
  br label %snap118340_row0_next
snap118340_row0_next:
  %snap118340_row1_present = icmp ugt i64 %snap118340_count, 1
  br i1 %snap118340_row1_present, label %snap118340_row1_write, label %snap118340_row1_next
snap118340_row1_write:
  %snap118340_row1_record = getelementptr i8, ptr %snap118340_records, i64 112
  %snap118340_row1_destination = getelementptr %sollang.struct.m17_s29, ptr %snap118340_output, i64 1
  store %sollang.struct.m17_s29 zeroinitializer, ptr %snap118340_row1_destination, align 8
  %snap118340_row1_field0 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 0
  %snap118340_row1_field1 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 1
  %snap118340_row1_field2 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 2
  %snap118340_row1_field3 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 3
  %snap118340_row1_field4 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 4
  %snap118340_row1_field5 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 5
  %snap118340_row1_field6 = getelementptr inbounds %sollang.struct.m17_s29, ptr %snap118340_row1_destination, i32 0, i32 6
  %snap118340_row1_task_slot = getelementptr i8, ptr %snap118340_row1_record, i64 0
  %snap118340_row1_task = load i64, ptr %snap118340_row1_task_slot, align 8
  %snap118340_row1_parent_slot = getelementptr i8, ptr %snap118340_row1_record, i64 8
  %snap118340_row1_parent = load i64, ptr %snap118340_row1_parent_slot, align 8
  %snap118340_row1_awaited_slot = getelementptr i8, ptr %snap118340_row1_record, i64 32
  %snap118340_row1_awaited = load i64, ptr %snap118340_row1_awaited_slot, align 8
  %snap118340_row1_deadline_slot = getelementptr i8, ptr %snap118340_row1_record, i64 40
  %snap118340_row1_deadline = load i64, ptr %snap118340_row1_deadline_slot, align 8
  %snap118340_row1_resume_slot = getelementptr i8, ptr %snap118340_row1_record, i64 28
  %snap118340_row1_resume = load i32, ptr %snap118340_row1_resume_slot, align 4
  %snap118340_row1_status = call i32 @sollang_diagnostic_observed_status(ptr %snap118340_row1_record)
  store i64 %snap118340_row1_task, ptr %snap118340_row1_field0, align 8
  %snap118340_row1_field1_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row1_field1, i32 0, i32 0
  %snap118340_row1_field1_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row1_field1, i32 0, i32 1
  %snap118340_row1_field1_present = icmp ne i64 %snap118340_row1_parent, 0
  %snap118340_row1_field1_ordinal = zext i1 %snap118340_row1_field1_present to i32
  store i32 %snap118340_row1_field1_ordinal, ptr %snap118340_row1_field1_tag, align 4
  store i64 %snap118340_row1_parent, ptr %snap118340_row1_field1_payload, align 8
  %snap118340_row1_field4_tag = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row1_field4, i32 0, i32 0
  %snap118340_row1_field4_payload = getelementptr inbounds %sollang.enum.t308, ptr %snap118340_row1_field4, i32 0, i32 1
  %snap118340_row1_field4_present = icmp ne i64 %snap118340_row1_awaited, 0
  %snap118340_row1_field4_ordinal = zext i1 %snap118340_row1_field4_present to i32
  store i32 %snap118340_row1_field4_ordinal, ptr %snap118340_row1_field4_tag, align 4
  store i64 %snap118340_row1_awaited, ptr %snap118340_row1_field4_payload, align 8
  %snap118340_row1_completed = icmp eq i32 %snap118340_row1_status, 2
  %snap118340_row1_cancelled = icmp eq i32 %snap118340_row1_status, 3
  %snap118340_row1_running = icmp eq i32 %snap118340_row1_status, 1
  %snap118340_row1_pending_running = select i1 %snap118340_row1_running, i32 1, i32 0
  %snap118340_row1_completed_earlier = select i1 %snap118340_row1_completed, i32 2, i32 %snap118340_row1_pending_running
  %snap118340_row1_lifecycle = select i1 %snap118340_row1_cancelled, i32 3, i32 %snap118340_row1_completed_earlier
  %snap118340_row1_lifecycle_slot = getelementptr inbounds %sollang.enum.t295, ptr %snap118340_row1_field2, i32 0, i32 0
  store i32 %snap118340_row1_lifecycle, ptr %snap118340_row1_lifecycle_slot, align 4
  %snap118340_row1_ready = icmp eq i32 %snap118340_row1_status, 0
  %snap118340_row1_timer = icmp eq i32 %snap118340_row1_status, 4
  %snap118340_row1_blocked = icmp eq i32 %snap118340_row1_status, 5
  %snap118340_row1_ready_tag = select i1 %snap118340_row1_ready, i32 1, i32 0
  %snap118340_row1_timer_tag = select i1 %snap118340_row1_timer, i32 2, i32 %snap118340_row1_ready_tag
  %snap118340_row1_wait = select i1 %snap118340_row1_blocked, i32 3, i32 %snap118340_row1_timer_tag
  %snap118340_row1_wait_slot = getelementptr inbounds %sollang.enum.t296, ptr %snap118340_row1_field3, i32 0, i32 0
  store i32 %snap118340_row1_wait, ptr %snap118340_row1_wait_slot, align 4
  %snap118340_row1_visible_deadline = select i1 %snap118340_row1_timer, i64 %snap118340_row1_deadline, i64 0
  store i64 %snap118340_row1_visible_deadline, ptr %snap118340_row1_field5, align 8
  %snap118340_row1_has_resume = icmp ne i32 %snap118340_row1_resume, 0
  %snap118340_row1_no_deadline = icmp eq i64 %snap118340_row1_deadline, 0
  %snap118340_row1_visible_state = or i1 %snap118340_row1_no_deadline, %snap118340_row1_timer
  %snap118340_row1_has_locator = and i1 %snap118340_row1_has_resume, %snap118340_row1_visible_state
  br i1 %snap118340_row1_has_locator, label %snap118340_row1_locator, label %snap118340_row1_done
snap118340_row1_locator:
  %snap118340_row1_locator_tag = getelementptr inbounds %sollang.enum.t309, ptr %snap118340_row1_field6, i32 0, i32 0
  %snap118340_row1_locator_payload = getelementptr inbounds %sollang.enum.t309, ptr %snap118340_row1_field6, i32 0, i32 1
  store i32 1, ptr %snap118340_row1_locator_tag, align 4
  %snap118340_row1_locator_field0 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row1_locator_payload, i32 0, i32 0
  %snap118340_row1_locator_field1 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row1_locator_payload, i32 0, i32 1
  %snap118340_row1_locator_field2 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row1_locator_payload, i32 0, i32 2
  %snap118340_row1_locator_field3 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row1_locator_payload, i32 0, i32 3
  %snap118340_row1_locator_field4 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row1_locator_payload, i32 0, i32 4
  %snap118340_row1_locator_field5 = getelementptr inbounds %sollang.struct.m17_s22, ptr %snap118340_row1_locator_payload, i32 0, i32 5
  %snap118340_row1_text0_ptr_slot = getelementptr i8, ptr %snap118340_row1_record, i64 48
  %snap118340_row1_text0_ptr = load ptr, ptr %snap118340_row1_text0_ptr_slot, align 8
  %snap118340_row1_text0_len_slot = getelementptr i8, ptr %snap118340_row1_record, i64 56
  %snap118340_row1_text0_len = load i64, ptr %snap118340_row1_text0_len_slot, align 8
  %snap118340_row1_text0_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118340_row1_text0_ptr, 0
  %snap118340_row1_text0 = insertvalue %sollang.text %snap118340_row1_text0_0, i64 %snap118340_row1_text0_len, 1
  store %sollang.text %snap118340_row1_text0, ptr %snap118340_row1_locator_field0, align 8
  %snap118340_row1_text1_ptr_slot = getelementptr i8, ptr %snap118340_row1_record, i64 64
  %snap118340_row1_text1_ptr = load ptr, ptr %snap118340_row1_text1_ptr_slot, align 8
  %snap118340_row1_text1_len_slot = getelementptr i8, ptr %snap118340_row1_record, i64 72
  %snap118340_row1_text1_len = load i64, ptr %snap118340_row1_text1_len_slot, align 8
  %snap118340_row1_text1_0 = insertvalue %sollang.text zeroinitializer, ptr %snap118340_row1_text1_ptr, 0
  %snap118340_row1_text1 = insertvalue %sollang.text %snap118340_row1_text1_0, i64 %snap118340_row1_text1_len, 1
  store %sollang.text %snap118340_row1_text1, ptr %snap118340_row1_locator_field1, align 8
  store i32 %snap118340_row1_resume, ptr %snap118340_row1_locator_field2, align 4
  %snap118340_row1_byte_slot = getelementptr i8, ptr %snap118340_row1_record, i64 80
  %snap118340_row1_byte = load i64, ptr %snap118340_row1_byte_slot, align 8
  store i64 %snap118340_row1_byte, ptr %snap118340_row1_locator_field3, align 8
  %snap118340_row1_coordinate4_slot = getelementptr i8, ptr %snap118340_row1_record, i64 88
  %snap118340_row1_coordinate4 = load i64, ptr %snap118340_row1_coordinate4_slot, align 8
  %snap118340_row1_coordinate4_narrow = trunc i64 %snap118340_row1_coordinate4 to i32
  store i32 %snap118340_row1_coordinate4_narrow, ptr %snap118340_row1_locator_field4, align 4
  %snap118340_row1_coordinate5_slot = getelementptr i8, ptr %snap118340_row1_record, i64 96
  %snap118340_row1_coordinate5 = load i64, ptr %snap118340_row1_coordinate5_slot, align 8
  %snap118340_row1_coordinate5_narrow = trunc i64 %snap118340_row1_coordinate5 to i32
  store i32 %snap118340_row1_coordinate5_narrow, ptr %snap118340_row1_locator_field5, align 4
  br label %snap118340_row1_done
snap118340_row1_done:
  br label %snap118340_row1_next
snap118340_row1_next:
  %snap118340_id_slot = getelementptr i8, ptr %snap118340_session, i64 0
  %snap118340_id = load i64, ptr %snap118340_id_slot, align 8
  %snap118340_truncated = icmp ugt i64 %snap118340_count, 2
  %snap118340_written = select i1 %snap118340_truncated, i64 2, i64 %snap118340_count
  %snap118340_summary0 = insertvalue %sollang.struct.m17_s37 zeroinitializer, i64 %snap118340_id, 0
  %snap118340_summary1 = insertvalue %sollang.struct.m17_s37 %snap118340_summary0, i64 %snap118340_written, 1
  %snap118340_summary2 = insertvalue %sollang.struct.m17_s37 %snap118340_summary1, i64 %snap118340_count, 2
  %snap118340_summary3 = insertvalue %sollang.struct.m17_s37 %snap118340_summary2, i1 %snap118340_truncated, 3
  %v118340 = freeze %sollang.struct.m17_s37 %snap118340_summary3
  %v118344 = freeze %sollang.struct.m17_s37 %v118340
  %v118345 = load { ptr, i64 }, ptr %slot118296, align 8
  %v118343 = call { ptr, i64 } @sollang_m144_s18(%sollang.struct.m17_s37 %v118344, { ptr, i64 } %v118345)
  %named_fixed_call118343_1 = extractvalue { ptr, i64 } %v118345, 0
  call void @free(ptr %named_fixed_call118343_1)
  %v118347 = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  %v118346_diagnostic_input = extractvalue %sollang.struct.m17_s46 %v118347, 0
  %v118346_diagnostic_result_slot = alloca %sollang.enum.t313, align 8
  store %sollang.enum.t313 zeroinitializer, ptr %v118346_diagnostic_result_slot, align 8
  %v118346_diagnostic_tag = getelementptr inbounds %sollang.enum.t313, ptr %v118346_diagnostic_result_slot, i32 0, i32 0
  %v118346_diagnostic_payload = getelementptr inbounds %sollang.enum.t313, ptr %v118346_diagnostic_result_slot, i32 0, i32 1
  %v118346_diagnostic_session = inttoptr i64 %v118346_diagnostic_input to ptr
  %v118346_diagnostic_raw = call { i1, i64, i64, i64 } @sollang_diagnostic_close(ptr %v118346_diagnostic_session)
  %v118346_diagnostic_ok = extractvalue { i1, i64, i64, i64 } %v118346_diagnostic_raw, 0
  %v118346_diagnostic_discriminant = select i1 %v118346_diagnostic_ok, i32 0, i32 1
  store i32 %v118346_diagnostic_discriminant, ptr %v118346_diagnostic_tag, align 4
  br i1 %v118346_diagnostic_ok, label %diagnostic118346_ok, label %diagnostic118346_error
diagnostic118346_ok:
  %v118346_diagnostic_summary1 = extractvalue { i1, i64, i64, i64 } %v118346_diagnostic_raw, 1
  %v118346_diagnostic_summary_slot1 = getelementptr i8, ptr %v118346_diagnostic_payload, i64 0
  store i64 %v118346_diagnostic_summary1, ptr %v118346_diagnostic_summary_slot1, align 8
  %v118346_diagnostic_summary2 = extractvalue { i1, i64, i64, i64 } %v118346_diagnostic_raw, 2
  %v118346_diagnostic_summary_slot2 = getelementptr i8, ptr %v118346_diagnostic_payload, i64 8
  store i64 %v118346_diagnostic_summary2, ptr %v118346_diagnostic_summary_slot2, align 8
  %v118346_diagnostic_summary3 = extractvalue { i1, i64, i64, i64 } %v118346_diagnostic_raw, 3
  %v118346_diagnostic_summary_slot3 = getelementptr i8, ptr %v118346_diagnostic_payload, i64 16
  store i64 %v118346_diagnostic_summary3, ptr %v118346_diagnostic_summary_slot3, align 8
  br label %diagnostic118346_merge
diagnostic118346_error:
  store i64 %v118346_diagnostic_input, ptr %v118346_diagnostic_payload, align 8
  br label %diagnostic118346_merge
diagnostic118346_merge:
  %v118346 = load %sollang.enum.t313, ptr %v118346_diagnostic_result_slot, align 8
  call void @sollang_drop_t313(%sollang.enum.t313 %v118346)
  %cleanup1183185_b118298_fixed_carrier = freeze { ptr, i64 } %v118343
  %cleanup1183185_b118298_fixed_data = extractvalue { ptr, i64 } %cleanup1183185_b118298_fixed_carrier, 0
  %cleanup1183185_b118298_fixed = load [2 x %sollang.struct.m17_s29], ptr %cleanup1183185_b118298_fixed_data, align 8
  call void @sollang_drop_t1212([2 x %sollang.struct.m17_s29] %cleanup1183185_b118298_fixed)
  call void @free(ptr %cleanup1183185_b118298_fixed_data)
  call void @sollang_drop_t305(%sollang.struct.m17_s37 %v118340)
  %cleanup1183185_b118295_current = load %sollang.struct.m17_s37, ptr %async_local118295, align 8
  call void @sollang_drop_t305(%sollang.struct.m17_s37 %cleanup1183185_b118295_current)
  %cleanup1183185_b118293_current = load %sollang.struct.m17_s37, ptr %async_local118293, align 8
  call void @sollang_drop_t305(%sollang.struct.m17_s37 %cleanup1183185_b118293_current)
  br label %match118318_merge
match118318_next0:
  %v118318_is_arm1 = icmp eq i32 %v118318_tag, 1
  br i1 %v118318_is_arm1, label %match118318_arm1, label %match118318_next1
match118318_arm1:
  %v118318_arm1_payload = getelementptr inbounds %sollang.enum.t1254, ptr %v118318_subject_slot, i32 0, i32 1
  %v118349 = load %sollang.product.t1253, ptr %v118318_arm1_payload, align 8
  store i1 true, ptr %v118349_owned, align 1
  store %sollang.product.t1253 %v118349, ptr %async_local118349, align 8
  %v118353 = load %sollang.product.t1253, ptr %async_local118349, align 8
  %v118351 = extractvalue %sollang.product.t1253 %v118353, 0
  %v118352_child_handle_slot = getelementptr i8, ptr %async_context, i64 16
  %v118352_child_context_slot = getelementptr i8, ptr %async_context, i64 24
  %v118352_pending_handle = extractvalue %sollang.task %v118351, 0
  %v118352_pending_context = extractvalue %sollang.task %v118351, 1
  store ptr %v118352_pending_handle, ptr %v118352_child_handle_slot, align 8
  store ptr %v118352_pending_context, ptr %v118352_child_context_slot, align 8
  %v118352_pending_status_slot = getelementptr %sollang.task_control, ptr %v118352_pending_handle, i32 0, i32 4
  %v118352_pending_status = load i32, ptr %v118352_pending_status_slot, align 4
  %v118352_already_completed = icmp eq i32 %v118352_pending_status, 2
  br i1 %v118352_already_completed, label %await118352_ready, label %await118352_suspend
await118352_suspend:
  %diagnostic_suspend4_header = getelementptr i8, ptr %async_context, i64 32
  %diagnostic_suspend4_child_slot = getelementptr %sollang.diagnostic_task_control, ptr %v118352_pending_handle, i32 0, i32 1
  %diagnostic_suspend4_child = load ptr, ptr %diagnostic_suspend4_child_slot, align 8
  call void @sollang_diagnostic_suspend(ptr %diagnostic_suspend4_header, ptr %diagnostic_suspend4_child, i32 4, ptr @sollang_diagnostic_module118286, i64 58, ptr @sollang_diagnostic_symbol118286, i64 7, i64 4166, i64 105, i64 35, i64 0)
  call void @sollang_task_park_on(ptr %control, ptr %v118352_pending_handle)
  %async_frame4_store = call ptr @malloc(i64 33)
  %async_frame4_allocated = icmp ne ptr %async_frame4_store, null
  br i1 %async_frame4_allocated, label %async_frame4_ready, label %async_frame4_failed
async_frame4_failed:
  call void @llvm.trap()
  unreachable
async_frame4_ready:
  store ptr %async_frame4_store, ptr %async_frame_slot, align 8
  %async_frame4_118289_store_address = getelementptr i8, ptr %async_frame4_store, i64 0
  %async_frame4_118289_stored = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  store %sollang.struct.m17_s46 %async_frame4_118289_stored, ptr %async_frame4_118289_store_address, align 8
  %async_frame4_118349_store_address = getelementptr i8, ptr %async_frame4_store, i64 8
  %async_frame4_118349_stored = load %sollang.product.t1253, ptr %async_local118349, align 8
  store %sollang.product.t1253 %async_frame4_118349_stored, ptr %async_frame4_118349_store_address, align 8
  %async_frame4_118349_store_flag_address = getelementptr i8, ptr %async_frame4_store, i64 32
  %async_frame4_118349_store_flag = load i1, ptr %v118349_owned, align 1
  store i1 %async_frame4_118349_store_flag, ptr %async_frame4_118349_store_flag_address, align 1
  store i32 4, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume4:
  %async_frame4_load = load ptr, ptr %async_frame_slot, align 8
  %async_frame4_118289_load_address = getelementptr i8, ptr %async_frame4_load, i64 0
  %async_frame4_118289_loaded = load %sollang.struct.m17_s46, ptr %async_frame4_118289_load_address, align 8
  store %sollang.struct.m17_s46 %async_frame4_118289_loaded, ptr %slot118289, align 8
  %async_frame4_118349_load_address = getelementptr i8, ptr %async_frame4_load, i64 8
  %async_frame4_118349_loaded = load %sollang.product.t1253, ptr %async_frame4_118349_load_address, align 8
  store %sollang.product.t1253 %async_frame4_118349_loaded, ptr %async_local118349, align 8
  %async_frame4_118349_load_flag_address = getelementptr i8, ptr %async_frame4_load, i64 32
  %async_frame4_118349_load_flag = load i1, ptr %async_frame4_118349_load_flag_address, align 1
  store i1 %async_frame4_118349_load_flag, ptr %v118349_owned, align 1
  call void @free(ptr %async_frame4_load)
  store ptr null, ptr %async_frame_slot, align 8
  br label %await118352_ready
await118352_ready:
  %v118352_resumed_handle_slot = getelementptr i8, ptr %async_context, i64 16
  %v118352_resumed_context_slot = getelementptr i8, ptr %async_context, i64 24
  %v118352_task_handle = load ptr, ptr %v118352_resumed_handle_slot, align 8
  %v118352_task_context = load ptr, ptr %v118352_resumed_context_slot, align 8
  store ptr null, ptr %v118352_resumed_handle_slot, align 8
  store ptr null, ptr %v118352_resumed_context_slot, align 8
  %v118352_task_joined = call i1 @sollang_task_join(ptr %v118352_task_handle)
  br i1 %v118352_task_joined, label %await118352_joined, label %await118352_failed
await118352_failed:
  call void @llvm.trap()
  unreachable
await118352_joined:
  %v118352_completion_slot = getelementptr %sollang.task_control, ptr %v118352_task_handle, i32 0, i32 22
  %v118352_completion = load ptr, ptr %v118352_completion_slot, align 8
  %v118352_needs_completion = icmp ne ptr %v118352_completion, null
  br i1 %v118352_needs_completion, label %task_result_v118352_complete, label %task_result_v118352_ready
task_result_v118352_complete:
  call void %v118352_completion(ptr %v118352_task_handle)
  store ptr null, ptr %v118352_completion_slot, align 8
  br label %task_result_v118352_ready
task_result_v118352_ready:
  %v118352_task_released = call i1 @sollang_task_release(ptr %v118352_task_handle)
  br i1 %v118352_task_released, label %await118352_released, label %await118352_release_failed
await118352_release_failed:
  call void @llvm.trap()
  unreachable
await118352_released:
  %v118355 = load %sollang.struct.m17_s46, ptr %slot118289, align 8
  %v118354_diagnostic_input = extractvalue %sollang.struct.m17_s46 %v118355, 0
  %v118354_diagnostic_result_slot = alloca %sollang.enum.t313, align 8
  store %sollang.enum.t313 zeroinitializer, ptr %v118354_diagnostic_result_slot, align 8
  %v118354_diagnostic_tag = getelementptr inbounds %sollang.enum.t313, ptr %v118354_diagnostic_result_slot, i32 0, i32 0
  %v118354_diagnostic_payload = getelementptr inbounds %sollang.enum.t313, ptr %v118354_diagnostic_result_slot, i32 0, i32 1
  %v118354_diagnostic_session = inttoptr i64 %v118354_diagnostic_input to ptr
  %v118354_diagnostic_raw = call { i1, i64, i64, i64 } @sollang_diagnostic_close(ptr %v118354_diagnostic_session)
  %v118354_diagnostic_ok = extractvalue { i1, i64, i64, i64 } %v118354_diagnostic_raw, 0
  %v118354_diagnostic_discriminant = select i1 %v118354_diagnostic_ok, i32 0, i32 1
  store i32 %v118354_diagnostic_discriminant, ptr %v118354_diagnostic_tag, align 4
  br i1 %v118354_diagnostic_ok, label %diagnostic118354_ok, label %diagnostic118354_error
diagnostic118354_ok:
  %v118354_diagnostic_summary1 = extractvalue { i1, i64, i64, i64 } %v118354_diagnostic_raw, 1
  %v118354_diagnostic_summary_slot1 = getelementptr i8, ptr %v118354_diagnostic_payload, i64 0
  store i64 %v118354_diagnostic_summary1, ptr %v118354_diagnostic_summary_slot1, align 8
  %v118354_diagnostic_summary2 = extractvalue { i1, i64, i64, i64 } %v118354_diagnostic_raw, 2
  %v118354_diagnostic_summary_slot2 = getelementptr i8, ptr %v118354_diagnostic_payload, i64 8
  store i64 %v118354_diagnostic_summary2, ptr %v118354_diagnostic_summary_slot2, align 8
  %v118354_diagnostic_summary3 = extractvalue { i1, i64, i64, i64 } %v118354_diagnostic_raw, 3
  %v118354_diagnostic_summary_slot3 = getelementptr i8, ptr %v118354_diagnostic_payload, i64 16
  store i64 %v118354_diagnostic_summary3, ptr %v118354_diagnostic_summary_slot3, align 8
  br label %diagnostic118354_merge
diagnostic118354_error:
  store i64 %v118354_diagnostic_input, ptr %v118354_diagnostic_payload, align 8
  br label %diagnostic118354_merge
diagnostic118354_merge:
  %v118354 = load %sollang.enum.t313, ptr %v118354_diagnostic_result_slot, align 8
  %v118357_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118357, 0
  %v118357 = insertvalue %sollang.text %v118357_ptr, i64 11, 1
  call void @sollang_runtime_print(ptr @sollang_str_118357, i64 11, i1 true)
  %v118349_still_owned = load i1, ptr %v118349_owned, align 1
  br i1 %v118349_still_owned, label %match118318_arm1_drop, label %match118318_arm1_drop_done
match118318_arm1_drop:
  %dropg118349_p0 = load %sollang.product.t1253, ptr %async_local118349, align 8
  br label %match118318_arm1_drop_done
match118318_arm1_drop_done:
  call void @sollang_drop_t313(%sollang.enum.t313 %v118354)
  br label %match118318_merge
match118318_next1:
  call void @llvm.trap()
  unreachable
match118318_merge:
  br label %match118306_merge
match118306_next0:
  %v118306_is_arm1 = icmp eq i32 %v118306_tag, 1
  br i1 %v118306_is_arm1, label %match118306_arm1, label %match118306_next1
match118306_arm1:
  %v118306_arm1_payload = getelementptr inbounds %sollang.enum.t310, ptr %v118306_subject_slot, i32 0, i32 1
  %v118360 = load %sollang.enum.t301, ptr %v118306_arm1_payload, align 8
  %v118363_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118363, 0
  %v118363 = insertvalue %sollang.text %v118363_ptr, i64 10, 1
  call void @sollang_runtime_print(ptr @sollang_str_118363, i64 10, i1 true)
  br label %match118306_merge
match118306_next1:
  call void @llvm.trap()
  unreachable
match118306_merge:
  %diagnostic_complete_header118286 = getelementptr i8, ptr %async_context, i64 32
  call void @sollang_diagnostic_mark_terminal(ptr %diagnostic_complete_header118286, i32 2)
  ret i1 true
}
define internal void @sollang_m144_s25_async_cancel(ptr %control) {
entry:
  %async_cancel_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_cancel_context = load ptr, ptr %async_cancel_context_slot, align 8
  %async_context = freeze ptr %async_cancel_context
  %async_cancel_status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %async_cancel_status = load i32, ptr %async_cancel_status_slot, align 4
  %async_cancel_completed = icmp eq i32 %async_cancel_status, 2
  br i1 %async_cancel_completed, label %async_cancel_result, label %async_cancel_pending
async_cancel_result:
  br label %async_cancel_cleanup
async_cancel_pending:
  %async_cancel_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_cancel_state = load i32, ptr %async_cancel_state_slot, align 4
  switch i32 %async_cancel_state, label %async_cancel_invalid [ i32 0, label %async_cancel_initial i32 1, label %async_cancel_state1 i32 2, label %async_cancel_state2 i32 3, label %async_cancel_state3 i32 4, label %async_cancel_state4 ]
async_cancel_initial:
  br label %async_cancel_cleanup
async_cancel_invalid:
  call void @llvm.trap()
  unreachable
async_cancel_state1:
  %async_cancel_spill_slot1 = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_spill_frame1 = load ptr, ptr %async_cancel_spill_slot1, align 8
  %async_cancel_owned_address1_118289 = getelementptr i8, ptr %async_cancel_spill_frame1, i64 0
  %async_cancel_owned_value1_118289 = load %sollang.struct.m17_s46, ptr %async_cancel_owned_address1_118289, align 8
  %async_cancel_owned_address1_118292 = getelementptr i8, ptr %async_cancel_spill_frame1, i64 8
  %async_cancel_owned_value1_118292 = load { ptr, i64 }, ptr %async_cancel_owned_address1_118292, align 8
  %async_cancel_spill_address1_118320 = getelementptr i8, ptr %async_cancel_spill_frame1, i64 24
  %async_cancel_spill_task1_118320 = load %sollang.task, ptr %async_cancel_spill_address1_118320, align 8
  %async_cancel_spill_handle1_118320 = extractvalue %sollang.task %async_cancel_spill_task1_118320, 0
  %async_cancel_owned_flag_address1_118320 = getelementptr i8, ptr %async_cancel_spill_frame1, i64 40
  %async_cancel_owned_flag1_118320 = load i1, ptr %async_cancel_owned_flag_address1_118320, align 1
  br i1 %async_cancel_owned_flag1_118320, label %async_cancel_owned_run1_118320, label %async_cancel_owned_skip1_118320
async_cancel_owned_run1_118320:
  %async_cancel_spill_ok1_118320 = call i1 @sollang_task_cancel(ptr %async_cancel_spill_handle1_118320)
  br i1 %async_cancel_spill_ok1_118320, label %async_cancel_spill_done1_118320, label %async_cancel_invalid
async_cancel_spill_done1_118320:
  br label %async_cancel_owned_skip1_118320
async_cancel_owned_skip1_118320:
  %async_cancel_owned_data1_118292 = extractvalue { ptr, i64 } %async_cancel_owned_value1_118292, 0
  %async_cancel_owned_inline1_118292 = load [2 x %sollang.struct.m17_s29], ptr %async_cancel_owned_data1_118292, align 8
  call void @sollang_drop_t1212([2 x %sollang.struct.m17_s29] %async_cancel_owned_inline1_118292)
  call void @sollang_drop_t298(%sollang.struct.m17_s46 %async_cancel_owned_value1_118289)
  br label %async_cancel_cleanup
async_cancel_state2:
  %async_cancel_spill_slot2 = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_spill_frame2 = load ptr, ptr %async_cancel_spill_slot2, align 8
  %async_cancel_owned_address2_118289 = getelementptr i8, ptr %async_cancel_spill_frame2, i64 0
  %async_cancel_owned_value2_118289 = load %sollang.struct.m17_s46, ptr %async_cancel_owned_address2_118289, align 8
  %async_cancel_owned_address2_118293 = getelementptr i8, ptr %async_cancel_spill_frame2, i64 8
  %async_cancel_owned_value2_118293 = load %sollang.struct.m17_s37, ptr %async_cancel_owned_address2_118293, align 8
  %async_cancel_owned_address2_118294 = getelementptr i8, ptr %async_cancel_spill_frame2, i64 40
  %async_cancel_owned_value2_118294 = load { ptr, i64 }, ptr %async_cancel_owned_address2_118294, align 8
  %async_cancel_spill_address2_118320 = getelementptr i8, ptr %async_cancel_spill_frame2, i64 56
  %async_cancel_spill_task2_118320 = load %sollang.task, ptr %async_cancel_spill_address2_118320, align 8
  %async_cancel_spill_handle2_118320 = extractvalue %sollang.task %async_cancel_spill_task2_118320, 0
  %async_cancel_owned_flag_address2_118320 = getelementptr i8, ptr %async_cancel_spill_frame2, i64 72
  %async_cancel_owned_flag2_118320 = load i1, ptr %async_cancel_owned_flag_address2_118320, align 1
  br i1 %async_cancel_owned_flag2_118320, label %async_cancel_owned_run2_118320, label %async_cancel_owned_skip2_118320
async_cancel_owned_run2_118320:
  %async_cancel_spill_ok2_118320 = call i1 @sollang_task_cancel(ptr %async_cancel_spill_handle2_118320)
  br i1 %async_cancel_spill_ok2_118320, label %async_cancel_spill_done2_118320, label %async_cancel_invalid
async_cancel_spill_done2_118320:
  br label %async_cancel_owned_skip2_118320
async_cancel_owned_skip2_118320:
  %async_cancel_owned_data2_118294 = extractvalue { ptr, i64 } %async_cancel_owned_value2_118294, 0
  %async_cancel_owned_inline2_118294 = load [2 x %sollang.struct.m17_s29], ptr %async_cancel_owned_data2_118294, align 8
  call void @sollang_drop_t1212([2 x %sollang.struct.m17_s29] %async_cancel_owned_inline2_118294)
  call void @sollang_drop_t305(%sollang.struct.m17_s37 %async_cancel_owned_value2_118293)
  call void @sollang_drop_t298(%sollang.struct.m17_s46 %async_cancel_owned_value2_118289)
  br label %async_cancel_cleanup
async_cancel_state3:
  %async_cancel_child_slot3 = getelementptr i8, ptr %async_cancel_context, i64 16
  %async_cancel_child3 = load ptr, ptr %async_cancel_child_slot3, align 8
  %async_cancel_child_ok3 = call i1 @sollang_task_cancel(ptr %async_cancel_child3)
  br i1 %async_cancel_child_ok3, label %async_cancel_child_done3, label %async_cancel_invalid
async_cancel_child_done3:
  %async_cancel_spill_slot3 = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_spill_frame3 = load ptr, ptr %async_cancel_spill_slot3, align 8
  %async_cancel_owned_address3_118289 = getelementptr i8, ptr %async_cancel_spill_frame3, i64 0
  %async_cancel_owned_value3_118289 = load %sollang.struct.m17_s46, ptr %async_cancel_owned_address3_118289, align 8
  %async_cancel_owned_address3_118293 = getelementptr i8, ptr %async_cancel_spill_frame3, i64 8
  %async_cancel_owned_value3_118293 = load %sollang.struct.m17_s37, ptr %async_cancel_owned_address3_118293, align 8
  %async_cancel_owned_address3_118295 = getelementptr i8, ptr %async_cancel_spill_frame3, i64 40
  %async_cancel_owned_value3_118295 = load %sollang.struct.m17_s37, ptr %async_cancel_owned_address3_118295, align 8
  %async_cancel_owned_address3_118296 = getelementptr i8, ptr %async_cancel_spill_frame3, i64 72
  %async_cancel_owned_value3_118296 = load { ptr, i64 }, ptr %async_cancel_owned_address3_118296, align 8
  %async_cancel_owned_data3_118296 = extractvalue { ptr, i64 } %async_cancel_owned_value3_118296, 0
  %async_cancel_owned_inline3_118296 = load [2 x %sollang.struct.m17_s29], ptr %async_cancel_owned_data3_118296, align 8
  call void @sollang_drop_t1212([2 x %sollang.struct.m17_s29] %async_cancel_owned_inline3_118296)
  call void @sollang_drop_t305(%sollang.struct.m17_s37 %async_cancel_owned_value3_118295)
  call void @sollang_drop_t305(%sollang.struct.m17_s37 %async_cancel_owned_value3_118293)
  call void @sollang_drop_t298(%sollang.struct.m17_s46 %async_cancel_owned_value3_118289)
  br label %async_cancel_cleanup
async_cancel_state4:
  %async_cancel_child_slot4 = getelementptr i8, ptr %async_cancel_context, i64 16
  %async_cancel_child4 = load ptr, ptr %async_cancel_child_slot4, align 8
  %async_cancel_child_ok4 = call i1 @sollang_task_cancel(ptr %async_cancel_child4)
  br i1 %async_cancel_child_ok4, label %async_cancel_child_done4, label %async_cancel_invalid
async_cancel_child_done4:
  %async_cancel_spill_slot4 = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_spill_frame4 = load ptr, ptr %async_cancel_spill_slot4, align 8
  %async_cancel_owned_address4_118289 = getelementptr i8, ptr %async_cancel_spill_frame4, i64 0
  %async_cancel_owned_value4_118289 = load %sollang.struct.m17_s46, ptr %async_cancel_owned_address4_118289, align 8
  %async_cancel_owned_address4_118349 = getelementptr i8, ptr %async_cancel_spill_frame4, i64 8
  %async_cancel_owned_value4_118349 = load %sollang.product.t1253, ptr %async_cancel_owned_address4_118349, align 8
  %async_cancel_owned_flag_address4_118349 = getelementptr i8, ptr %async_cancel_spill_frame4, i64 32
  %async_cancel_owned_flag4_118349 = load i1, ptr %async_cancel_owned_flag_address4_118349, align 1
  br i1 %async_cancel_owned_flag4_118349, label %async_cancel_owned_run4_118349, label %async_cancel_owned_skip4_118349
async_cancel_owned_run4_118349:
  call void @sollang_drop_t1253(%sollang.product.t1253 %async_cancel_owned_value4_118349)
  br label %async_cancel_owned_skip4_118349
async_cancel_owned_skip4_118349:
  call void @sollang_drop_t298(%sollang.struct.m17_s46 %async_cancel_owned_value4_118289)
  br label %async_cancel_cleanup
async_cancel_cleanup:
  %async_cancel_frame_slot = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_frame = load ptr, ptr %async_cancel_frame_slot, align 8
  call void @free(ptr %async_cancel_frame)
  %async_cancel_header = getelementptr i8, ptr %async_cancel_context, i64 32
  call void @sollang_diagnostic_release_header(ptr %async_cancel_header, i32 3)
  call void @free(ptr %async_cancel_context)
  ret void
}
define %sollang.task @sollang_m144_s25(ptr %diagnostic_parent) {
entry:
  %async_context = call ptr @malloc(i64 80)
  %async_context_allocated = icmp ne ptr %async_context, null
  br i1 %async_context_allocated, label %async_initialize, label %async_allocation_failed
async_allocation_failed:
  call void @llvm.trap()
  unreachable
async_initialize:
  %async_header_slot0 = getelementptr i8, ptr %async_context, i64 32
  store ptr null, ptr %async_header_slot0, align 8
  %async_header_slot1 = getelementptr i8, ptr %async_context, i64 40
  store ptr null, ptr %async_header_slot1, align 8
  %async_header_slot2 = getelementptr i8, ptr %async_context, i64 48
  store i64 0, ptr %async_header_slot2, align 8
  %async_header_slot3 = getelementptr i8, ptr %async_context, i64 56
  store i64 0, ptr %async_header_slot3, align 8
  %async_header_slot4 = getelementptr i8, ptr %async_context, i64 64
  store ptr null, ptr %async_header_slot4, align 8
  %async_header_slot5 = getelementptr i8, ptr %async_context, i64 72
  store ptr null, ptr %async_header_slot5, align 8
  %async_initial_frame_slot = getelementptr i8, ptr %async_context, i64 8
  store ptr null, ptr %async_initial_frame_slot, align 8
  %async_initial_child_slot = getelementptr i8, ptr %async_context, i64 16
  %async_initial_child_context_slot = getelementptr i8, ptr %async_context, i64 24
  store ptr null, ptr %async_initial_child_slot, align 8
  store ptr null, ptr %async_initial_child_context_slot, align 8
  %async_handle = call ptr @sollang_task_start(ptr @sollang_m144_s25_async_worker, ptr @sollang_m144_s25_async_destroy, ptr @sollang_m144_s25_async_cancel, ptr %async_context)
  %async_started = icmp ne ptr %async_handle, null
  br i1 %async_started, label %async_ready, label %async_start_failed
async_start_failed:
  call void @free(ptr %async_context)
  call void @llvm.trap()
  unreachable
async_ready:
  %async_inherited_header = getelementptr i8, ptr %async_context, i64 32
  %async_created_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %async_handle, i32 0, i32 1
  store ptr %async_inherited_header, ptr %async_created_header_slot, align 8
  call void @sollang_diagnostic_inherit(ptr %async_inherited_header, ptr %async_handle, ptr %diagnostic_parent)
  %async_task_handle = insertvalue %sollang.task poison, ptr %async_handle, 0
  %async_task = insertvalue %sollang.task %async_task_handle, ptr %async_context, 1
  ret %sollang.task %async_task
}
define i32 @main() {
entry:
  %v118366 = call %sollang.task @sollang_m144_s25(ptr null)
  %v118367_task_handle = extractvalue %sollang.task %v118366, 0
  %v118367_task_context = extractvalue %sollang.task %v118366, 1
  %v118367_task_joined = call i1 @sollang_task_join(ptr %v118367_task_handle)
  br i1 %v118367_task_joined, label %await118367_joined, label %await118367_failed
await118367_failed:
  call void @llvm.trap()
  unreachable
await118367_joined:
  %v118367_completion_slot = getelementptr %sollang.task_control, ptr %v118367_task_handle, i32 0, i32 22
  %v118367_completion = load ptr, ptr %v118367_completion_slot, align 8
  %v118367_needs_completion = icmp ne ptr %v118367_completion, null
  br i1 %v118367_needs_completion, label %task_result_v118367_complete, label %task_result_v118367_ready
task_result_v118367_complete:
  call void %v118367_completion(ptr %v118367_task_handle)
  store ptr null, ptr %v118367_completion_slot, align 8
  br label %task_result_v118367_ready
task_result_v118367_ready:
  %v118367_task_released = call i1 @sollang_task_release(ptr %v118367_task_handle)
  br i1 %v118367_task_released, label %await118367_released, label %await118367_release_failed
await118367_release_failed:
  call void @llvm.trap()
  unreachable
await118367_released:
  call void @sollang_async_shutdown()
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
define internal void @sollang_m144_s21_g118368_async_destroy(ptr %context) {
entry:
  %header = getelementptr i8, ptr %context, i64 32
  call void @sollang_diagnostic_release_header(ptr %header, i32 2)
  call void @free(ptr %context)
  ret void
}
define i1 @sollang_m144_s21_g118368_async_worker(ptr %control) {
entry:
  %async_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_context = load ptr, ptr %async_context_slot, align 8
  %v118374_subject_slot = alloca %sollang.enum.t188, align 8
  %v118376_owned = alloca i1, align 1
  store i1 false, ptr %v118376_owned, align 1
  %async_frame_slot = getelementptr i8, ptr %async_context, i64 8
  %async_local118376 = alloca %sollang.struct.m6_s0, align 8
  %async_resume_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state = load i32, ptr %async_resume_state_slot, align 4
  switch i32 %async_resume_state, label %async_state_invalid [ i32 0, label %async_state_start i32 1, label %async_resume1 ]
async_state_invalid:
  call void @llvm.trap()
  unreachable
async_state_start:
  %v118371_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118371, 0
  %v118371 = insertvalue %sollang.text %v118371_ptr, i64 10, 1
  call void @sollang_runtime_print(ptr @sollang_str_118371, i64 10, i1 true)
  %v118372 = call %sollang.enum.t188 @sollang_m6_s86(i64 5)
  %v118374_tag = extractvalue %sollang.enum.t188 %v118372, 0
  store %sollang.enum.t188 %v118372, ptr %v118374_subject_slot, align 8
  %v118374_is_arm0 = icmp eq i32 %v118374_tag, 0
  br i1 %v118374_is_arm0, label %match118374_arm0, label %match118374_next0
match118374_arm0:
  %v118374_arm0_payload = getelementptr inbounds %sollang.enum.t188, ptr %v118374_subject_slot, i32 0, i32 1
  %v118376 = load %sollang.struct.m6_s0, ptr %v118374_arm0_payload, align 8
  store i1 true, ptr %v118376_owned, align 1
  store %sollang.struct.m6_s0 %v118376, ptr %async_local118376, align 8
  %v118378 = load %sollang.struct.m6_s0, ptr %async_local118376, align 8
  %v118384_sleep_millis = extractvalue %sollang.struct.m6_s0 %v118378, 0
  %v118384_sleep_positive = icmp sgt i64 %v118384_sleep_millis, 0
  %v118384_sleep_normalized = select i1 %v118384_sleep_positive, i64 %v118384_sleep_millis, i64 0
  %v118384_sleep_now = call i64 @sollang_now_millis()
  %v118384_sleep_remaining = sub i64 9223372036854775807, %v118384_sleep_now
  %v118384_sleep_too_large = icmp sgt i64 %v118384_sleep_normalized, %v118384_sleep_remaining
  %v118384_sleep_finite_deadline = add i64 %v118384_sleep_now, %v118384_sleep_normalized
  %v118384_sleep_deadline = select i1 %v118384_sleep_too_large, i64 9223372036854775807, i64 %v118384_sleep_finite_deadline
  %v118384_sleep_context = call ptr @malloc(i64 56)
  %v118384_sleep_allocated = icmp ne ptr %v118384_sleep_context, null
  br i1 %v118384_sleep_allocated, label %sleep118384_initialize, label %sleep118384_allocation_failed
sleep118384_allocation_failed:
  call void @llvm.trap()
  unreachable
sleep118384_initialize:
  store i8 0, ptr %v118384_sleep_context, align 1
  %v118384_sleep_header = getelementptr i8, ptr %v118384_sleep_context, i64 8
  store { ptr, ptr, i64, i64, ptr, ptr } zeroinitializer, ptr %v118384_sleep_header, align 8
  %v118384_sleep_handle = call ptr @sollang_task_start(ptr @sollang_diagnostic_sleep_worker, ptr @sollang_diagnostic_sleep_destroy, ptr @sollang_diagnostic_sleep_cancel, ptr %v118384_sleep_context)
  %v118384_sleep_started = icmp ne ptr %v118384_sleep_handle, null
  br i1 %v118384_sleep_started, label %sleep118384_ready, label %sleep118384_start_failed
sleep118384_start_failed:
  call void @free(ptr %v118384_sleep_context)
  call void @llvm.trap()
  unreachable
sleep118384_ready:
  %v118384_sleep_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %v118384_sleep_handle, i32 0, i32 1
  store ptr %v118384_sleep_header, ptr %v118384_sleep_header_slot, align 8
  %v118384_sleep_parent = getelementptr i8, ptr %async_context, i64 32
  call void @sollang_diagnostic_inherit(ptr %v118384_sleep_header, ptr %v118384_sleep_handle, ptr %v118384_sleep_parent)
  %v118384_sleep_deadline_slot = getelementptr %sollang.task_control, ptr %v118384_sleep_handle, i32 0, i32 8
  store i64 %v118384_sleep_deadline, ptr %v118384_sleep_deadline_slot, align 8
  %v118384_task_handle = insertvalue %sollang.task poison, ptr %v118384_sleep_handle, 0
  %v118384 = insertvalue %sollang.task %v118384_task_handle, ptr %v118384_sleep_context, 1
  %v118385_child_handle_slot = getelementptr i8, ptr %async_context, i64 16
  %v118385_child_context_slot = getelementptr i8, ptr %async_context, i64 24
  %v118385_pending_handle = extractvalue %sollang.task %v118384, 0
  %v118385_pending_context = extractvalue %sollang.task %v118384, 1
  store ptr %v118385_pending_handle, ptr %v118385_child_handle_slot, align 8
  store ptr %v118385_pending_context, ptr %v118385_child_context_slot, align 8
  %v118385_pending_status_slot = getelementptr %sollang.task_control, ptr %v118385_pending_handle, i32 0, i32 4
  %v118385_pending_status = load i32, ptr %v118385_pending_status_slot, align 4
  %v118385_already_completed = icmp eq i32 %v118385_pending_status, 2
  br i1 %v118385_already_completed, label %await118385_ready, label %await118385_suspend
await118385_suspend:
  %diagnostic_suspend1_header = getelementptr i8, ptr %async_context, i64 32
  %diagnostic_suspend1_child_slot = getelementptr %sollang.diagnostic_task_control, ptr %v118385_pending_handle, i32 0, i32 1
  %diagnostic_suspend1_child = load ptr, ptr %diagnostic_suspend1_child_slot, align 8
  call void @sollang_diagnostic_suspend(ptr %diagnostic_suspend1_header, ptr %diagnostic_suspend1_child, i32 1, ptr @sollang_diagnostic_module118368, i64 58, ptr @sollang_diagnostic_symbol118368, i64 12, i64 2900, i64 78, i64 39, i64 0)
  %diagnostic_suspend1_deadline_slot = getelementptr %sollang.task_control, ptr %v118385_pending_handle, i32 0, i32 8
  %diagnostic_suspend1_deadline = load i64, ptr %diagnostic_suspend1_deadline_slot, align 8
  call void @sollang_diagnostic_suspend(ptr %diagnostic_suspend1_child, ptr null, i32 1, ptr @sollang_diagnostic_module118368, i64 58, ptr @sollang_diagnostic_symbol118368, i64 12, i64 2891, i64 78, i64 30, i64 %diagnostic_suspend1_deadline)
  call void @sollang_task_park_on(ptr %control, ptr %v118385_pending_handle)
  store i32 1, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume1:
  br label %await118385_ready
await118385_ready:
  %v118385_resumed_handle_slot = getelementptr i8, ptr %async_context, i64 16
  %v118385_resumed_context_slot = getelementptr i8, ptr %async_context, i64 24
  %v118385_task_handle = load ptr, ptr %v118385_resumed_handle_slot, align 8
  %v118385_task_context = load ptr, ptr %v118385_resumed_context_slot, align 8
  store ptr null, ptr %v118385_resumed_handle_slot, align 8
  store ptr null, ptr %v118385_resumed_context_slot, align 8
  %v118385_task_joined = call i1 @sollang_task_join(ptr %v118385_task_handle)
  br i1 %v118385_task_joined, label %await118385_joined, label %await118385_failed
await118385_failed:
  call void @llvm.trap()
  unreachable
await118385_joined:
  %v118385_completion_slot = getelementptr %sollang.task_control, ptr %v118385_task_handle, i32 0, i32 22
  %v118385_completion = load ptr, ptr %v118385_completion_slot, align 8
  %v118385_needs_completion = icmp ne ptr %v118385_completion, null
  br i1 %v118385_needs_completion, label %task_result_v118385_complete, label %task_result_v118385_ready
task_result_v118385_complete:
  call void %v118385_completion(ptr %v118385_task_handle)
  store ptr null, ptr %v118385_completion_slot, align 8
  br label %task_result_v118385_ready
task_result_v118385_ready:
  %v118385_task_released = call i1 @sollang_task_release(ptr %v118385_task_handle)
  br i1 %v118385_task_released, label %await118385_released, label %await118385_release_failed
await118385_release_failed:
  call void @llvm.trap()
  unreachable
await118385_released:
  br label %match118374_merge
match118374_next0:
  %v118374_is_arm1 = icmp eq i32 %v118374_tag, 1
  br i1 %v118374_is_arm1, label %match118374_arm1, label %match118374_next1
match118374_arm1:
  %v118374_arm1_payload = getelementptr inbounds %sollang.enum.t188, ptr %v118374_subject_slot, i32 0, i32 1
  %v118380 = load %sollang.struct.m6_s59, ptr %v118374_arm1_payload, align 8
  %v118383_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118383, 0
  %v118383 = insertvalue %sollang.text %v118383_ptr, i64 14, 1
  call void @sollang_runtime_print(ptr @sollang_str_118383, i64 14, i1 true)
  call void @sollang_drop_t177(%sollang.struct.m6_s59 %v118380)
  br label %match118374_merge
match118374_next1:
  call void @llvm.trap()
  unreachable
match118374_merge:
  %diagnostic_complete_header118368 = getelementptr i8, ptr %async_context, i64 32
  call void @sollang_diagnostic_mark_terminal(ptr %diagnostic_complete_header118368, i32 2)
  ret i1 true
}
define internal void @sollang_m144_s21_g118368_async_cancel(ptr %control) {
entry:
  %async_cancel_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_cancel_context = load ptr, ptr %async_cancel_context_slot, align 8
  %async_context = freeze ptr %async_cancel_context
  %async_cancel_status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %async_cancel_status = load i32, ptr %async_cancel_status_slot, align 4
  %async_cancel_completed = icmp eq i32 %async_cancel_status, 2
  br i1 %async_cancel_completed, label %async_cancel_result, label %async_cancel_pending
async_cancel_result:
  br label %async_cancel_cleanup
async_cancel_pending:
  %async_cancel_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_cancel_state = load i32, ptr %async_cancel_state_slot, align 4
  switch i32 %async_cancel_state, label %async_cancel_invalid [ i32 0, label %async_cancel_initial i32 1, label %async_cancel_state1 ]
async_cancel_initial:
  br label %async_cancel_cleanup
async_cancel_invalid:
  call void @llvm.trap()
  unreachable
async_cancel_state1:
  %async_cancel_child_slot1 = getelementptr i8, ptr %async_cancel_context, i64 16
  %async_cancel_child1 = load ptr, ptr %async_cancel_child_slot1, align 8
  %async_cancel_child_ok1 = call i1 @sollang_task_cancel(ptr %async_cancel_child1)
  br i1 %async_cancel_child_ok1, label %async_cancel_child_done1, label %async_cancel_invalid
async_cancel_child_done1:
  br label %async_cancel_cleanup
async_cancel_cleanup:
  %async_cancel_frame_slot = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_frame = load ptr, ptr %async_cancel_frame_slot, align 8
  call void @free(ptr %async_cancel_frame)
  %async_cancel_header = getelementptr i8, ptr %async_cancel_context, i64 32
  call void @sollang_diagnostic_release_header(ptr %async_cancel_header, i32 3)
  call void @free(ptr %async_cancel_context)
  ret void
}
define %sollang.task @sollang_m144_s21_g118368(ptr %diagnostic_parent) {
entry:
  %async_context = call ptr @malloc(i64 80)
  %async_context_allocated = icmp ne ptr %async_context, null
  br i1 %async_context_allocated, label %async_initialize, label %async_allocation_failed
async_allocation_failed:
  call void @llvm.trap()
  unreachable
async_initialize:
  %async_header_slot0 = getelementptr i8, ptr %async_context, i64 32
  store ptr null, ptr %async_header_slot0, align 8
  %async_header_slot1 = getelementptr i8, ptr %async_context, i64 40
  store ptr null, ptr %async_header_slot1, align 8
  %async_header_slot2 = getelementptr i8, ptr %async_context, i64 48
  store i64 0, ptr %async_header_slot2, align 8
  %async_header_slot3 = getelementptr i8, ptr %async_context, i64 56
  store i64 0, ptr %async_header_slot3, align 8
  %async_header_slot4 = getelementptr i8, ptr %async_context, i64 64
  store ptr null, ptr %async_header_slot4, align 8
  %async_header_slot5 = getelementptr i8, ptr %async_context, i64 72
  store ptr null, ptr %async_header_slot5, align 8
  %async_initial_frame_slot = getelementptr i8, ptr %async_context, i64 8
  store ptr null, ptr %async_initial_frame_slot, align 8
  %async_initial_child_slot = getelementptr i8, ptr %async_context, i64 16
  %async_initial_child_context_slot = getelementptr i8, ptr %async_context, i64 24
  store ptr null, ptr %async_initial_child_slot, align 8
  store ptr null, ptr %async_initial_child_context_slot, align 8
  %async_handle = call ptr @sollang_task_start(ptr @sollang_m144_s21_g118368_async_worker, ptr @sollang_m144_s21_g118368_async_destroy, ptr @sollang_m144_s21_g118368_async_cancel, ptr %async_context)
  %async_started = icmp ne ptr %async_handle, null
  br i1 %async_started, label %async_ready, label %async_start_failed
async_start_failed:
  call void @free(ptr %async_context)
  call void @llvm.trap()
  unreachable
async_ready:
  %async_inherited_header = getelementptr i8, ptr %async_context, i64 32
  %async_created_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %async_handle, i32 0, i32 1
  store ptr %async_inherited_header, ptr %async_created_header_slot, align 8
  call void @sollang_diagnostic_inherit(ptr %async_inherited_header, ptr %async_handle, ptr %diagnostic_parent)
  %async_task_handle = insertvalue %sollang.task poison, ptr %async_handle, 0
  %async_task = insertvalue %sollang.task %async_task_handle, ptr %async_context, 1
  ret %sollang.task %async_task
}
define internal ptr @sollang_process_copy_text(ptr %data, i64 %length) {
entry:
  %capacity = add i64 %length, 1
  %copy = call ptr @malloc(i64 %capacity)
  %allocated = icmp ne ptr %copy, null
  br i1 %allocated, label %loop, label %fail
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %body ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %terminate, label %body
body:
  %source = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %source, align 1
  %destination = getelementptr i8, ptr %copy, i64 %index
  store i8 %byte, ptr %destination, align 1
  %next = add i64 %index, 1
  br label %loop
terminate:
  %null_slot = getelementptr i8, ptr %copy, i64 %length
  store i8 0, ptr %null_slot, align 1
  ret ptr %copy
fail:
  ret ptr null
}
define internal void @sollang_process_dispose_argv(ptr %argv, i64 %count) {
entry:
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %body ]
  %done = icmp eq i64 %index, %count
  br i1 %done, label %finish, label %body
body:
  %slot = getelementptr ptr, ptr %argv, i64 %index
  %value = load ptr, ptr %slot, align 8
  call void @free(ptr %value)
  %next = add i64 %index, 1
  br label %loop
finish:
  call void @free(ptr %argv)
  ret void
}
define internal ptr @sollang_process_build_argv(ptr %records, i64 %count) {
entry:
  %slots = add i64 %count, 1
  %bytes = mul i64 %slots, 8
  %argv = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %argv, null
  br i1 %allocated, label %loop, label %fail
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %stored ]
  %done = icmp eq i64 %index, %count
  br i1 %done, label %terminate, label %copy
copy:
  %record = getelementptr %sollang.text, ptr %records, i64 %index
  %data_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  %data = load ptr, ptr %data_slot, align 8
  %length_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 1
  %length = load i64, ptr %length_slot, align 8
  %value = call ptr @sollang_process_copy_text(ptr %data, i64 %length)
  %copied = icmp ne ptr %value, null
  br i1 %copied, label %stored, label %cleanup
stored:
  %slot = getelementptr ptr, ptr %argv, i64 %index
  store ptr %value, ptr %slot, align 8
  %next = add i64 %index, 1
  br label %loop
cleanup:
  call void @sollang_process_dispose_argv(ptr %argv, i64 %index)
  ret ptr null
terminate:
  %null_slot = getelementptr ptr, ptr %argv, i64 %count
  store ptr null, ptr %null_slot, align 8
  ret ptr %argv
fail:
  ret ptr null
}
declare i64 @_get_osfhandle(i32)
define internal ptr @sollang_process_quote_windows_arg(ptr %source, i32 %chars) {
entry:
  %chars64 = zext i32 %chars to i64
  %double = mul i64 %chars64, 2
  %capacity = add i64 %double, 3
  %bytes = mul i64 %capacity, 2
  %output = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %output, null
  br i1 %allocated, label %initialize, label %fail
initialize:
  store i16 34, ptr %output, align 2
  %index_slot = alloca i32, align 4
  %output_slot = alloca i64, align 8
  %slashes_slot = alloca i64, align 8
  store i32 0, ptr %index_slot, align 4
  store i64 1, ptr %output_slot, align 8
  store i64 0, ptr %slashes_slot, align 8
  br label %loop
loop:
  %index = load i32, ptr %index_slot, align 4
  %done = icmp eq i32 %index, %chars
  br i1 %done, label %finish_prepare, label %read
read:
  %character_ptr = getelementptr i16, ptr %source, i32 %index
  %character = load i16, ptr %character_ptr, align 2
  %is_slash = icmp eq i16 %character, 92
  br i1 %is_slash, label %remember_slash, label %flush_prepare
remember_slash:
  %slashes = load i64, ptr %slashes_slot, align 8
  %more_slashes = add i64 %slashes, 1
  store i64 %more_slashes, ptr %slashes_slot, align 8
  %slash_next = add i32 %index, 1
  store i32 %slash_next, ptr %index_slot, align 4
  br label %loop
flush_prepare:
  %pending = load i64, ptr %slashes_slot, align 8
  %is_quote = icmp eq i16 %character, 34
  %doubled = mul i64 %pending, 2
  %escaped = add i64 %doubled, 1
  %flush_count = select i1 %is_quote, i64 %escaped, i64 %pending
  br label %flush_loop
flush_loop:
  %flush_index = phi i64 [ 0, %flush_prepare ], [ %flush_next, %flush_body ]
  %flush_done = icmp eq i64 %flush_index, %flush_count
  br i1 %flush_done, label %write_character, label %flush_body
flush_body:
  %flush_output = load i64, ptr %output_slot, align 8
  %flush_ptr = getelementptr i16, ptr %output, i64 %flush_output
  store i16 92, ptr %flush_ptr, align 2
  %flush_output_next = add i64 %flush_output, 1
  store i64 %flush_output_next, ptr %output_slot, align 8
  %flush_next = add i64 %flush_index, 1
  br label %flush_loop
write_character:
  %output_index = load i64, ptr %output_slot, align 8
  %output_ptr = getelementptr i16, ptr %output, i64 %output_index
  store i16 %character, ptr %output_ptr, align 2
  %output_next = add i64 %output_index, 1
  store i64 %output_next, ptr %output_slot, align 8
  store i64 0, ptr %slashes_slot, align 8
  %index_next = add i32 %index, 1
  store i32 %index_next, ptr %index_slot, align 4
  br label %loop
finish_prepare:
  %trailing = load i64, ptr %slashes_slot, align 8
  %finish_count = mul i64 %trailing, 2
  br label %finish_loop
finish_loop:
  %finish_index = phi i64 [ 0, %finish_prepare ], [ %finish_next, %finish_body ]
  %finish_done = icmp eq i64 %finish_index, %finish_count
  br i1 %finish_done, label %close_quote, label %finish_body
finish_body:
  %finish_output = load i64, ptr %output_slot, align 8
  %finish_ptr = getelementptr i16, ptr %output, i64 %finish_output
  store i16 92, ptr %finish_ptr, align 2
  %finish_output_next = add i64 %finish_output, 1
  store i64 %finish_output_next, ptr %output_slot, align 8
  %finish_next = add i64 %finish_index, 1
  br label %finish_loop
close_quote:
  %close_index = load i64, ptr %output_slot, align 8
  %quote_ptr = getelementptr i16, ptr %output, i64 %close_index
  store i16 34, ptr %quote_ptr, align 2
  %null_index = add i64 %close_index, 1
  %null_ptr = getelementptr i16, ptr %output, i64 %null_index
  store i16 0, ptr %null_ptr, align 2
  ret ptr %output
fail:
  ret ptr null
}
define internal ptr @sollang_process_build_windows_argv(ptr %records, i64 %count, ptr %program_slot) {
entry:
  store ptr null, ptr %program_slot, align 8
  %slots = add i64 %count, 1
  %argv_bytes = mul i64 %slots, 8
  %argv = call ptr @malloc(i64 %argv_bytes)
  %allocated = icmp ne ptr %argv, null
  br i1 %allocated, label %loop, label %fail
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %store ]
  %done = icmp eq i64 %index, %count
  br i1 %done, label %terminate, label %measure
measure:
  %record = getelementptr %sollang.text, ptr %records, i64 %index
  %data_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  %data = load ptr, ptr %data_slot, align 8
  %length_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 1
  %length64 = load i64, ptr %length_slot, align 8
  %length_fits = icmp ule i64 %length64, 2147483647
  br i1 %length_fits, label %convert_size, label %cleanup
convert_size:
  %length = trunc i64 %length64 to i32
  %chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr null, i32 0)
  %chars_valid = icmp sgt i32 %chars, 0
  %empty = icmp eq i32 %length, 0
  %valid = or i1 %chars_valid, %empty
  br i1 %valid, label %allocate_wide, label %cleanup
allocate_wide:
  %chars_with_null = add i32 %chars, 1
  %chars_with_null64 = zext i32 %chars_with_null to i64
  %wide_bytes = mul i64 %chars_with_null64, 2
  %wide = call ptr @malloc(i64 %wide_bytes)
  %wide_ok = icmp ne ptr %wide, null
  br i1 %wide_ok, label %convert, label %cleanup
convert:
  %written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr %wide, i32 %chars)
  %converted = icmp eq i32 %written, %chars
  br i1 %converted, label %terminate_wide, label %free_wide_error
terminate_wide:
  %wide_end = getelementptr i16, ptr %wide, i32 %chars
  store i16 0, ptr %wide_end, align 2
  %quoted = call ptr @sollang_process_quote_windows_arg(ptr %wide, i32 %chars)
  %quoted_ok = icmp ne ptr %quoted, null
  br i1 %quoted_ok, label %preserve_program, label %free_wide_error
preserve_program:
  %is_program = icmp eq i64 %index, 0
  br i1 %is_program, label %store_program, label %free_unquoted
store_program:
  store ptr %wide, ptr %program_slot, align 8
  br label %store
free_unquoted:
  call void @free(ptr %wide)
  br label %store
store:
  %slot = getelementptr ptr, ptr %argv, i64 %index
  store ptr %quoted, ptr %slot, align 8
  %next = add i64 %index, 1
  br label %loop
free_wide_error:
  call void @free(ptr %wide)
  br label %cleanup
cleanup:
  %failed_program = load ptr, ptr %program_slot, align 8
  call void @free(ptr %failed_program)
  store ptr null, ptr %program_slot, align 8
  call void @sollang_process_dispose_argv(ptr %argv, i64 %index)
  ret ptr null
terminate:
  %null_slot = getelementptr ptr, ptr %argv, i64 %count
  store ptr null, ptr %null_slot, align 8
  ret ptr %argv
fail:
  ret ptr null
}
define internal ptr @sollang_process_windows_text(ptr %data, i64 %length64) {
entry:
  %length_fits = icmp ule i64 %length64, 2147483647
  br i1 %length_fits, label %measure, label %fail
measure:
  %length = trunc i64 %length64 to i32
  %chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr null, i32 0)
  %chars_valid = icmp sgt i32 %chars, 0
  %empty = icmp eq i32 %length, 0
  %valid = or i1 %chars_valid, %empty
  br i1 %valid, label %allocate, label %fail
allocate:
  %with_null = add i32 %chars, 1
  %with_null64 = zext i32 %with_null to i64
  %bytes = mul i64 %with_null64, 2
  %wide = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %wide, null
  br i1 %allocated, label %convert, label %fail
convert:
  %written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr %wide, i32 %chars)
  %converted = icmp eq i32 %written, %chars
  br i1 %converted, label %terminate, label %free_fail
terminate:
  %end = getelementptr i16, ptr %wide, i32 %chars
  store i16 0, ptr %end, align 2
  ret ptr %wide
free_fail:
  call void @free(ptr %wide)
  br label %fail
fail:
  ret ptr null
}
define internal ptr @sollang_process_windows_path(ptr %data, i64 %length) {
entry:
  %present = icmp ugt i64 %length, 0
  br i1 %present, label %check, label %fail
check:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %convert, label %inspect
inspect:
  %byte_ptr = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %fail, label %advance
advance:
  %next = add i64 %index, 1
  br label %check
convert:
  %wide = call ptr @sollang_process_windows_text(ptr %data, i64 %length)
  ret ptr %wide
fail:
  ret ptr null
}
define internal ptr @sollang_process_join_windows_args(ptr %argv, i64 %count) {
entry:
  %index_slot = alloca i64, align 8
  %offset_slot = alloca i64, align 8
  store i64 0, ptr %index_slot, align 8
  store i64 0, ptr %offset_slot, align 8
  br label %measure_outer
measure_outer:
  %index = load i64, ptr %index_slot, align 8
  %outer_done = icmp eq i64 %index, %count
  br i1 %outer_done, label %allocate, label %measure_inner
measure_inner:
  %character_index = phi i64 [ 0, %measure_outer ], [ %character_next, %measure_more ]
  %argument_slot = getelementptr ptr, ptr %argv, i64 %index
  %argument = load ptr, ptr %argument_slot, align 8
  %character_ptr = getelementptr i16, ptr %argument, i64 %character_index
  %character = load i16, ptr %character_ptr, align 2
  %argument_done = icmp eq i16 %character, 0
  br i1 %argument_done, label %measure_argument_done, label %measure_more
measure_more:
  %character_next = add i64 %character_index, 1
  br label %measure_inner
measure_argument_done:
  %offset = load i64, ptr %offset_slot, align 8
  %needs_space = icmp ne i64 %index, 0
  %space = zext i1 %needs_space to i64
  %with_argument = add i64 %offset, %character_index
  %next_offset = add i64 %with_argument, %space
  store i64 %next_offset, ptr %offset_slot, align 8
  %next_index = add i64 %index, 1
  store i64 %next_index, ptr %index_slot, align 8
  br label %measure_outer
allocate:
  %total = load i64, ptr %offset_slot, align 8
  %with_null = add i64 %total, 1
  %bytes = mul i64 %with_null, 2
  %command = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %command, null
  br i1 %allocated, label %copy_setup, label %fail
copy_setup:
  store i64 0, ptr %index_slot, align 8
  store i64 0, ptr %offset_slot, align 8
  br label %copy_outer
copy_outer:
  %copy_index = load i64, ptr %index_slot, align 8
  %copy_done = icmp eq i64 %copy_index, %count
  br i1 %copy_done, label %terminate, label %copy_space
copy_space:
  %copy_offset = load i64, ptr %offset_slot, align 8
  %copy_needs_space = icmp ne i64 %copy_index, 0
  br i1 %copy_needs_space, label %store_space, label %copy_inner
store_space:
  %space_ptr = getelementptr i16, ptr %command, i64 %copy_offset
  store i16 32, ptr %space_ptr, align 2
  %after_space = add i64 %copy_offset, 1
  store i64 %after_space, ptr %offset_slot, align 8
  br label %copy_inner
copy_inner:
  %copy_character_index = phi i64 [ 0, %copy_space ], [ 0, %store_space ], [ %copy_character_next, %copy_more ]
  %copy_argument_slot = getelementptr ptr, ptr %argv, i64 %copy_index
  %copy_argument = load ptr, ptr %copy_argument_slot, align 8
  %copy_character_ptr = getelementptr i16, ptr %copy_argument, i64 %copy_character_index
  %copy_character = load i16, ptr %copy_character_ptr, align 2
  %copy_argument_done = icmp eq i16 %copy_character, 0
  br i1 %copy_argument_done, label %copy_argument_finish, label %copy_more
copy_more:
  %current_offset = load i64, ptr %offset_slot, align 8
  %destination = getelementptr i16, ptr %command, i64 %current_offset
  store i16 %copy_character, ptr %destination, align 2
  %destination_next = add i64 %current_offset, 1
  store i64 %destination_next, ptr %offset_slot, align 8
  %copy_character_next = add i64 %copy_character_index, 1
  br label %copy_inner
copy_argument_finish:
  %copy_index_next = add i64 %copy_index, 1
  store i64 %copy_index_next, ptr %index_slot, align 8
  br label %copy_outer
terminate:
  %final_offset = load i64, ptr %offset_slot, align 8
  %null_ptr = getelementptr i16, ptr %command, i64 %final_offset
  store i16 0, ptr %null_ptr, align 2
  ret ptr %command
fail:
  ret ptr null
}
define internal i64 @sollang_windows_wide_length(ptr %text) {
entry:
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %more ]
  %at = getelementptr i16, ptr %text, i64 %index
  %character = load i16, ptr %at, align 2
  %done = icmp eq i16 %character, 0
  br i1 %done, label %result, label %more
more:
  %next = add i64 %index, 1
  br label %loop
result:
  ret i64 %index
}

define internal i64 @sollang_windows_environment_name_length(ptr %entry) {
entry_block:
  %first = load i16, ptr %entry, align 2
  %hidden = icmp eq i16 %first, 61
  %start = select i1 %hidden, i64 1, i64 0
  br label %loop
loop:
  %index = phi i64 [ %start, %entry_block ], [ %next, %more ]
  %at = getelementptr i16, ptr %entry, i64 %index
  %character = load i16, ptr %at, align 2
  %separator = icmp eq i16 %character, 61
  %end = icmp eq i16 %character, 0
  %done = or i1 %separator, %end
  br i1 %done, label %result, label %more
more:
  %next = add i64 %index, 1
  br label %loop
result:
  ret i64 %index
}

define internal i1 @sollang_windows_environment_text_valid(ptr %data, i64 %length, i1 %name) {
entry:
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %more ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %valid, label %inspect
inspect:
  %at = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %at, align 1
  %nul = icmp eq i8 %byte, 0
  %equal = icmp eq i8 %byte, 61
  %name_equal = and i1 %name, %equal
  %invalid = or i1 %nul, %name_equal
  br i1 %invalid, label %failure, label %more
more:
  %next = add i64 %index, 1
  br label %loop
valid:
  ret i1 true
failure:
  ret i1 false
}

define internal i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %count, ptr %name, i64 %name_length) {
entry:
  %name_fits = icmp ule i64 %name_length, 2147483647
  br i1 %name_fits, label %loop, label %missing
loop:
  %remaining = phi i64 [ %count, %entry ], [ %index, %different ]
  %done = icmp eq i64 %remaining, 0
  br i1 %done, label %missing, label %inspect
inspect:
  %index = sub i64 %remaining, 1
  %entry_slot = getelementptr ptr, ptr %entries, i64 %index
  %candidate = load ptr, ptr %entry_slot, align 8
  %length_slot = getelementptr i64, ptr %name_lengths, i64 %index
  %candidate_length64 = load i64, ptr %length_slot, align 8
  %candidate_fits = icmp ule i64 %candidate_length64, 2147483647
  br i1 %candidate_fits, label %compare, label %different
compare:
  %candidate_length = trunc i64 %candidate_length64 to i32
  %target_length = trunc i64 %name_length to i32
  %order = call i32 @CompareStringOrdinal(ptr %candidate, i32 %candidate_length, ptr %name, i32 %target_length, i32 1)
  %matches = icmp eq i32 %order, 2
  br i1 %matches, label %found, label %different
different:
  br label %loop
found:
  ret i64 %index
missing:
  ret i64 -1
}

define internal void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %count, ptr %parent) {
entry:
  %has_entries = icmp ne ptr %entries, null
  br i1 %has_entries, label %entry_loop, label %free_arrays
entry_loop:
  %index = phi i64 [ 0, %entry ], [ %next, %entry_more ]
  %entries_done = icmp eq i64 %index, %count
  br i1 %entries_done, label %free_arrays, label %entry_more
entry_more:
  %slot = getelementptr ptr, ptr %entries, i64 %index
  %value = load ptr, ptr %slot, align 8
  call void @free(ptr %value)
  %next = add i64 %index, 1
  br label %entry_loop
free_arrays:
  call void @free(ptr %entries)
  call void @free(ptr %name_lengths)
  call void @free(ptr %list)
  %has_parent = icmp ne ptr %parent, null
  br i1 %has_parent, label %free_parent, label %cleanup_done
free_parent:
  %parent_freed = call i32 @FreeEnvironmentStringsW(ptr %parent)
  br label %cleanup_done
cleanup_done:
  ret void
}

define internal %sollang.process_environment_result @sollang_windows_build_environment(ptr %changes, i64 %change_count, i1 %inherits) {
entry:
  %has_changes = icmp ne i64 %change_count, 0
  %cleared = xor i1 %inherits, true
  %custom = or i1 %has_changes, %cleared
  br i1 %custom, label %allocate_entries, label %fast
fast:
  %fast0 = insertvalue %sollang.process_environment_result poison, ptr null, 0
  %fast1 = insertvalue %sollang.process_environment_result %fast0, i64 0, 1
  %fast2 = insertvalue %sollang.process_environment_result %fast1, i64 -1, 2
  %fast3 = insertvalue %sollang.process_environment_result %fast2, i1 true, 3
  ret %sollang.process_environment_result %fast3
allocate_entries:
  %entry_slots0 = select i1 %has_changes, i64 %change_count, i64 1
  %entry_bytes = mul i64 %entry_slots0, 8
  %entries = call ptr @malloc(i64 %entry_bytes)
  %entries_ok = icmp ne ptr %entries, null
  br i1 %entries_ok, label %allocate_lengths, label %failure
allocate_lengths:
  %name_lengths = call ptr @malloc(i64 %entry_bytes)
  %lengths_ok = icmp ne ptr %name_lengths, null
  br i1 %lengths_ok, label %initialize_entries, label %free_entries_failure
initialize_entries:
  %init_index = phi i64 [ 0, %allocate_lengths ], [ %init_next, %init_more ]
  %init_done = icmp eq i64 %init_index, %change_count
  br i1 %init_done, label %convert_changes, label %init_more
init_more:
  %init_slot = getelementptr ptr, ptr %entries, i64 %init_index
  store ptr null, ptr %init_slot, align 8
  %init_next = add i64 %init_index, 1
  br label %initialize_entries
convert_changes:
  %change_index = phi i64 [ 0, %initialize_entries ], [ %change_next_removed, %store_removed ], [ %change_next_set, %store_set ]
  %changes_done = icmp eq i64 %change_index, %change_count
  br i1 %changes_done, label %parent_select, label %load_change
load_change:
  %change = getelementptr { %sollang.text, %sollang.text, i1 }, ptr %changes, i64 %change_index
  %name_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 0
  %name = load %sollang.text, ptr %name_slot, align 8
  %name_data = extractvalue %sollang.text %name, 0
  %name_length = extractvalue %sollang.text %name, 1
  %name_nonempty = icmp ne i64 %name_length, 0
  %name_valid0 = call i1 @sollang_windows_environment_text_valid(ptr %name_data, i64 %name_length, i1 true)
  %name_valid = and i1 %name_nonempty, %name_valid0
  %value_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 1
  %value = load %sollang.text, ptr %value_slot, align 8
  %value_data = extractvalue %sollang.text %value, 0
  %value_length = extractvalue %sollang.text %value, 1
  %value_valid = call i1 @sollang_windows_environment_text_valid(ptr %value_data, i64 %value_length, i1 false)
  %text_valid = and i1 %name_valid, %value_valid
  br i1 %text_valid, label %convert_name, label %build_failure
convert_name:
  %wide_name = call ptr @sollang_process_windows_text(ptr %name_data, i64 %name_length)
  %wide_name_ok = icmp ne ptr %wide_name, null
  br i1 %wide_name_ok, label %measure_name, label %build_failure
measure_name:
  %wide_name_length = call i64 @sollang_windows_wide_length(ptr %wide_name)
  %name_length_store = getelementptr i64, ptr %name_lengths, i64 %change_index
  store i64 %wide_name_length, ptr %name_length_store, align 8
  %removed_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 2
  %removed = load i1, ptr %removed_slot, align 1
  br i1 %removed, label %store_removed, label %convert_value
store_removed:
  %removed_entry_slot = getelementptr ptr, ptr %entries, i64 %change_index
  store ptr %wide_name, ptr %removed_entry_slot, align 8
  %change_next_removed = add i64 %change_index, 1
  br label %convert_changes
convert_value:
  %wide_value = call ptr @sollang_process_windows_text(ptr %value_data, i64 %value_length)
  %wide_value_ok = icmp ne ptr %wide_value, null
  br i1 %wide_value_ok, label %allocate_entry, label %free_name_failure
allocate_entry:
  %wide_value_length = call i64 @sollang_windows_wide_length(ptr %wide_value)
  %entry_without_end = add i64 %wide_name_length, %wide_value_length
  %entry_chars = add i64 %entry_without_end, 2
  %wide_entry_bytes = mul i64 %entry_chars, 2
  %wide_entry = call ptr @malloc(i64 %wide_entry_bytes)
  %wide_entry_ok = icmp ne ptr %wide_entry, null
  br i1 %wide_entry_ok, label %copy_entry, label %free_name_value_failure
copy_entry:
  %wide_name_bytes = mul i64 %wide_name_length, 2
  call void @llvm.memcpy.p0.p0.i64(ptr %wide_entry, ptr %wide_name, i64 %wide_name_bytes, i1 false)
  %separator = getelementptr i16, ptr %wide_entry, i64 %wide_name_length
  store i16 61, ptr %separator, align 2
  %value_offset = add i64 %wide_name_length, 1
  %value_destination = getelementptr i16, ptr %wide_entry, i64 %value_offset
  %wide_value_bytes = mul i64 %wide_value_length, 2
  call void @llvm.memcpy.p0.p0.i64(ptr %value_destination, ptr %wide_value, i64 %wide_value_bytes, i1 false)
  %entry_end_offset = add i64 %value_offset, %wide_value_length
  %entry_end = getelementptr i16, ptr %wide_entry, i64 %entry_end_offset
  store i16 0, ptr %entry_end, align 2
  call void @free(ptr %wide_name)
  call void @free(ptr %wide_value)
  br label %store_set
store_set:
  %set_entry_slot = getelementptr ptr, ptr %entries, i64 %change_index
  store ptr %wide_entry, ptr %set_entry_slot, align 8
  %change_next_set = add i64 %change_index, 1
  br label %convert_changes
free_name_failure:
  call void @free(ptr %wide_name)
  br label %build_failure
free_name_value_failure:
  call void @free(ptr %wide_name)
  call void @free(ptr %wide_value)
  br label %build_failure
parent_select:
  br i1 %inherits, label %load_parent, label %allocate_list
load_parent:
  %parent = call ptr @GetEnvironmentStringsW()
  %parent_ok = icmp ne ptr %parent, null
  br i1 %parent_ok, label %count_parent, label %build_failure
count_parent:
  %parent_count = phi i64 [ 0, %load_parent ], [ %parent_count_next, %parent_more ]
  %parent_cursor = phi ptr [ %parent, %load_parent ], [ %parent_next, %parent_more ]
  %parent_first = load i16, ptr %parent_cursor, align 2
  %parent_done = icmp eq i16 %parent_first, 0
  br i1 %parent_done, label %allocate_list, label %parent_more
parent_more:
  %parent_length = call i64 @sollang_windows_wide_length(ptr %parent_cursor)
  %parent_stride = add i64 %parent_length, 1
  %parent_next = getelementptr i16, ptr %parent_cursor, i64 %parent_stride
  %parent_count_next = add i64 %parent_count, 1
  br label %count_parent
allocate_list:
  %selected_parent = phi ptr [ null, %parent_select ], [ %parent, %count_parent ]
  %selected_parent_count = phi i64 [ 0, %parent_select ], [ %parent_count, %count_parent ]
  %maximum_count = add i64 %selected_parent_count, %change_count
  %list_slots = add i64 %maximum_count, 1
  %list_bytes = mul i64 %list_slots, 8
  %list = call ptr @malloc(i64 %list_bytes)
  %list_ok = icmp ne ptr %list, null
  br i1 %list_ok, label %copy_parent, label %build_failure_with_parent
copy_parent:
  %copy_parent_index = phi i64 [ 0, %allocate_list ], [ %copy_parent_next, %copy_parent_continue ]
  %copy_parent_cursor = phi ptr [ %selected_parent, %allocate_list ], [ %copy_parent_cursor_next, %copy_parent_continue ]
  %kept_count = phi i64 [ 0, %allocate_list ], [ %kept_next, %copy_parent_continue ]
  %copy_parent_done = icmp eq i64 %copy_parent_index, %selected_parent_count
  br i1 %copy_parent_done, label %append_changes, label %copy_parent_inspect
copy_parent_inspect:
  %parent_entry_length = call i64 @sollang_windows_wide_length(ptr %copy_parent_cursor)
  %parent_name_length = call i64 @sollang_windows_environment_name_length(ptr %copy_parent_cursor)
  %parent_change = call i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %change_count, ptr %copy_parent_cursor, i64 %parent_name_length)
  %parent_overridden = icmp sge i64 %parent_change, 0
  br i1 %parent_overridden, label %copy_parent_skip, label %copy_parent_keep
copy_parent_keep:
  %parent_destination = getelementptr ptr, ptr %list, i64 %kept_count
  store ptr %copy_parent_cursor, ptr %parent_destination, align 8
  %kept_after_copy = add i64 %kept_count, 1
  br label %copy_parent_continue
copy_parent_skip:
  br label %copy_parent_continue
copy_parent_continue:
  %kept_next = phi i64 [ %kept_after_copy, %copy_parent_keep ], [ %kept_count, %copy_parent_skip ]
  %copy_parent_stride = add i64 %parent_entry_length, 1
  %copy_parent_cursor_next = getelementptr i16, ptr %copy_parent_cursor, i64 %copy_parent_stride
  %copy_parent_next = add i64 %copy_parent_index, 1
  br label %copy_parent
append_changes:
  %append_index = phi i64 [ 0, %copy_parent ], [ %append_next, %append_continue ]
  %output_count = phi i64 [ %kept_count, %copy_parent ], [ %output_next, %append_continue ]
  %append_done = icmp eq i64 %append_index, %change_count
  br i1 %append_done, label %sort_outer, label %append_inspect
append_inspect:
  %append_entry_slot = getelementptr ptr, ptr %entries, i64 %append_index
  %append_entry = load ptr, ptr %append_entry_slot, align 8
  %append_name_length_slot = getelementptr i64, ptr %name_lengths, i64 %append_index
  %append_name_length = load i64, ptr %append_name_length_slot, align 8
  %latest = call i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %change_count, ptr %append_entry, i64 %append_name_length)
  %is_latest = icmp eq i64 %latest, %append_index
  br i1 %is_latest, label %append_latest, label %append_skip
append_latest:
  %append_change = getelementptr { %sollang.text, %sollang.text, i1 }, ptr %changes, i64 %append_index
  %append_removed_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %append_change, i32 0, i32 2
  %append_removed = load i1, ptr %append_removed_slot, align 1
  br i1 %append_removed, label %append_skip, label %append_keep
append_keep:
  %append_destination = getelementptr ptr, ptr %list, i64 %output_count
  store ptr %append_entry, ptr %append_destination, align 8
  %output_after_append = add i64 %output_count, 1
  br label %append_continue
append_skip:
  br label %append_continue
append_continue:
  %output_next = phi i64 [ %output_after_append, %append_keep ], [ %output_count, %append_skip ]
  %append_next = add i64 %append_index, 1
  br label %append_changes
sort_outer:
  %sort_index = phi i64 [ 1, %append_changes ], [ %sort_next, %sort_store ]
  %sort_done = icmp uge i64 %sort_index, %output_count
  br i1 %sort_done, label %measure_block, label %sort_load
sort_load:
  %sort_key_slot = getelementptr ptr, ptr %list, i64 %sort_index
  %sort_key = load ptr, ptr %sort_key_slot, align 8
  br label %sort_inner
sort_inner:
  %sort_position = phi i64 [ %sort_index, %sort_load ], [ %sort_previous, %sort_shift ]
  %at_start = icmp eq i64 %sort_position, 0
  br i1 %at_start, label %sort_store, label %sort_compare
sort_compare:
  %sort_previous = sub i64 %sort_position, 1
  %sort_previous_slot = getelementptr ptr, ptr %list, i64 %sort_previous
  %sort_previous_value = load ptr, ptr %sort_previous_slot, align 8
  %sort_order = call i32 @CompareStringOrdinal(ptr %sort_key, i32 -1, ptr %sort_previous_value, i32 -1, i32 1)
  %sort_before = icmp eq i32 %sort_order, 1
  br i1 %sort_before, label %sort_shift, label %sort_store
sort_shift:
  %sort_shift_destination = getelementptr ptr, ptr %list, i64 %sort_position
  store ptr %sort_previous_value, ptr %sort_shift_destination, align 8
  br label %sort_inner
sort_store:
  %sort_destination = getelementptr ptr, ptr %list, i64 %sort_position
  store ptr %sort_key, ptr %sort_destination, align 8
  %sort_next = add i64 %sort_index, 1
  br label %sort_outer
measure_block:
  %measure_index = phi i64 [ 0, %sort_outer ], [ %measure_next, %measure_more ]
  %measure_chars = phi i64 [ 0, %sort_outer ], [ %measure_total, %measure_more ]
  %measure_done = icmp eq i64 %measure_index, %output_count
  br i1 %measure_done, label %allocate_block, label %measure_more
measure_more:
  %measure_slot = getelementptr ptr, ptr %list, i64 %measure_index
  %measure_entry = load ptr, ptr %measure_slot, align 8
  %measure_length = call i64 @sollang_windows_wide_length(ptr %measure_entry)
  %measure_with_null = add i64 %measure_length, 1
  %measure_total = add i64 %measure_chars, %measure_with_null
  %measure_next = add i64 %measure_index, 1
  br label %measure_block
allocate_block:
  %empty_block = icmp eq i64 %output_count, 0
  %nonempty_chars = add i64 %measure_chars, 1
  %block_chars = select i1 %empty_block, i64 2, i64 %nonempty_chars
  %block_bytes = mul i64 %block_chars, 2
  %block = call ptr @malloc(i64 %block_bytes)
  %block_ok = icmp ne ptr %block, null
  br i1 %block_ok, label %copy_block, label %build_failure_with_list
copy_block:
  %block_index = phi i64 [ 0, %allocate_block ], [ %block_next, %block_more ]
  %block_offset = phi i64 [ 0, %allocate_block ], [ %block_offset_next, %block_more ]
  %block_done = icmp eq i64 %block_index, %output_count
  br i1 %block_done, label %terminate_block, label %block_more
block_more:
  %block_entry_slot = getelementptr ptr, ptr %list, i64 %block_index
  %block_entry = load ptr, ptr %block_entry_slot, align 8
  %block_entry_length = call i64 @sollang_windows_wide_length(ptr %block_entry)
  %block_copy_chars = add i64 %block_entry_length, 1
  %block_copy_bytes = mul i64 %block_copy_chars, 2
  %block_destination = getelementptr i16, ptr %block, i64 %block_offset
  call void @llvm.memcpy.p0.p0.i64(ptr %block_destination, ptr %block_entry, i64 %block_copy_bytes, i1 false)
  %block_offset_next = add i64 %block_offset, %block_copy_chars
  %block_next = add i64 %block_index, 1
  br label %copy_block
terminate_block:
  %final_null = getelementptr i16, ptr %block, i64 %block_offset
  store i16 0, ptr %final_null, align 2
  %empty_second = getelementptr i16, ptr %block, i64 1
  br i1 %empty_block, label %terminate_empty, label %finish
terminate_empty:
  store i16 0, ptr %empty_second, align 2
  br label %finish
finish:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %change_count, ptr %selected_parent)
  %ok0 = insertvalue %sollang.process_environment_result poison, ptr %block, 0
  %ok1 = insertvalue %sollang.process_environment_result %ok0, i64 0, 1
  %ok2 = insertvalue %sollang.process_environment_result %ok1, i64 -1, 2
  %ok3 = insertvalue %sollang.process_environment_result %ok2, i1 true, 3
  ret %sollang.process_environment_result %ok3
build_failure_with_list:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %change_count, ptr %selected_parent)
  br label %failure
build_failure_with_parent:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr null, i64 %change_count, ptr %selected_parent)
  br label %failure
build_failure:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr null, i64 %change_count, ptr null)
  br label %failure
free_entries_failure:
  call void @free(ptr %entries)
  br label %failure
failure:
  ret %sollang.process_environment_result zeroinitializer
}


define internal ptr @sollang_process_inherit_windows_handle(ptr %source) {
entry:
  %process = call ptr @GetCurrentProcess()
  %target_slot = alloca ptr, align 8
  %duplicated = call i32 @DuplicateHandle(ptr %process, ptr %source, ptr %process, ptr %target_slot, i32 0, i32 1, i32 2)
  %ok = icmp ne i32 %duplicated, 0
  br i1 %ok, label %success, label %fail
success:
  %target = load ptr, ptr %target_slot, align 8
  ret ptr %target
fail:
  ret ptr null
}
define internal i64 @sollang_process_spawn_windows(ptr %program, ptr %argv, i64 %count, ptr %working_directory, ptr %environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override) {
entry:
  %command = call ptr @sollang_process_join_windows_args(ptr %argv, i64 %count)
  %command_ok = icmp ne ptr %command, null
  br i1 %command_ok, label %handles, label %fail
handles:
  %stdin_default_value = call i64 @_get_osfhandle(i32 0)
  %stdin_default = inttoptr i64 %stdin_default_value to ptr
  %has_stdin_override = icmp ne ptr %stdin_override, null
  %stdin_source = select i1 %has_stdin_override, ptr %stdin_override, ptr %stdin_default
  %stdout_default_value = call i64 @_get_osfhandle(i32 1)
  %stdout_default = inttoptr i64 %stdout_default_value to ptr
  %has_stdout_override = icmp ne ptr %stdout_override, null
  %stdout_source = select i1 %has_stdout_override, ptr %stdout_override, ptr %stdout_default
  %stderr_default_value = call i64 @_get_osfhandle(i32 2)
  %stderr_default = inttoptr i64 %stderr_default_value to ptr
  %has_stderr_override = icmp ne ptr %stderr_override, null
  %stderr_source = select i1 %has_stderr_override, ptr %stderr_override, ptr %stderr_default
  %stdin_handle = call ptr @sollang_process_inherit_windows_handle(ptr %stdin_source)
  %stdout_handle = call ptr @sollang_process_inherit_windows_handle(ptr %stdout_source)
  %stderr_handle = call ptr @sollang_process_inherit_windows_handle(ptr %stderr_source)
  %stdin_ok = icmp ne ptr %stdin_handle, null
  %stdout_ok = icmp ne ptr %stdout_handle, null
  %stderr_ok = icmp ne ptr %stderr_handle, null
  %io_ok0 = and i1 %stdin_ok, %stdout_ok
  %io_ok = and i1 %io_ok0, %stderr_ok
  br i1 %io_ok, label %create, label %close_handles_fail
create:
  %startup = alloca [104 x i8], align 8
  %process_info = alloca [24 x i8], align 8
  call void @llvm.memset.p0.i64(ptr %startup, i8 0, i64 104, i1 false)
  call void @llvm.memset.p0.i64(ptr %process_info, i8 0, i64 24, i1 false)
  store i32 104, ptr %startup, align 4
  %flags_ptr = getelementptr i8, ptr %startup, i64 60
  store i32 256, ptr %flags_ptr, align 4
  %stdin_ptr = getelementptr i8, ptr %startup, i64 80
  store ptr %stdin_handle, ptr %stdin_ptr, align 8
  %stdout_ptr = getelementptr i8, ptr %startup, i64 88
  store ptr %stdout_handle, ptr %stdout_ptr, align 8
  %stderr_ptr = getelementptr i8, ptr %startup, i64 96
  store ptr %stderr_handle, ptr %stderr_ptr, align 8
  %has_environment = icmp ne ptr %environment, null
  %creation_flags = select i1 %has_environment, i32 1024, i32 0
  %created = call i32 @CreateProcessW(ptr %program, ptr %command, ptr null, ptr null, i32 1, i32 %creation_flags, ptr %environment, ptr %working_directory, ptr %startup, ptr %process_info)
  %created_ok = icmp ne i32 %created, 0
  br i1 %created_ok, label %spawned, label %close_handles_fail
spawned:
  %process_handle = load ptr, ptr %process_info, align 8
  %thread_ptr = getelementptr i8, ptr %process_info, i64 8
  %thread_handle = load ptr, ptr %thread_ptr, align 8
  %closed_thread = call i32 @CloseHandle(ptr %thread_handle)
  %closed_stdin = call i32 @CloseHandle(ptr %stdin_handle)
  %closed_stdout = call i32 @CloseHandle(ptr %stdout_handle)
  %closed_stderr = call i32 @CloseHandle(ptr %stderr_handle)
  call void @free(ptr %command)
  %token = ptrtoint ptr %process_handle to i64
  ret i64 %token
close_handles_fail:
  br i1 %stdin_ok, label %close_stdin, label %close_stdout
close_stdin:
  %closed_stdin_fail = call i32 @CloseHandle(ptr %stdin_handle)
  br label %close_stdout
close_stdout:
  br i1 %stdout_ok, label %close_stdout_present, label %close_stderr
close_stdout_present:
  %closed_stdout_fail = call i32 @CloseHandle(ptr %stdout_handle)
  br label %close_stderr
close_stderr:
  br i1 %stderr_ok, label %close_stderr_present, label %free_fail
close_stderr_present:
  %closed_stderr_fail = call i32 @CloseHandle(ptr %stderr_handle)
  br label %free_fail
free_fail:
  call void @free(ptr %command)
  br label %fail
fail:
  ret i64 -1
}
define internal %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override) {
entry:
  %has_program = icmp ugt i64 %count, 0
  br i1 %has_program, label %build, label %error
build:
  %program_slot = alloca ptr, align 8
  %argv = call ptr @sollang_process_build_windows_argv(ptr %records, i64 %count, ptr %program_slot)
  %built = icmp ne ptr %argv, null
  br i1 %built, label %spawn, label %error
spawn:
  %program = load ptr, ptr %program_slot, align 8
  br i1 %has_working_directory, label %working_directory_convert, label %spawn_ready
working_directory_convert:
  %working_directory_wide = call ptr @sollang_process_windows_text(ptr %working_directory_data, i64 %working_directory_length)
  %working_directory_ok = icmp ne ptr %working_directory_wide, null
  br i1 %working_directory_ok, label %working_directory_ready, label %build_error
working_directory_ready:
  br label %spawn_ready
spawn_ready:
  %working_directory = phi ptr [ null, %spawn ], [ %working_directory_wide, %working_directory_ready ]
  %environment_result = call %sollang.process_environment_result @sollang_windows_build_environment(ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  %environment = extractvalue %sollang.process_environment_result %environment_result, 0
  %environment_ok = extractvalue %sollang.process_environment_result %environment_result, 3
  br i1 %environment_ok, label %environment_ready, label %environment_error
environment_ready:
  %raw = call i64 @sollang_process_spawn_windows(ptr %program, ptr %argv, i64 %count, ptr %working_directory, ptr %environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override)
  call void @free(ptr %environment)
  call void @free(ptr %working_directory)
  call void @free(ptr %program)
  call void @sollang_process_dispose_argv(ptr %argv, i64 %count)
  %spawned = icmp ne i64 %raw, -1
  br i1 %spawned, label %read_process_id, label %error
environment_error:
  call void @free(ptr %working_directory)
  call void @free(ptr %program)
  call void @sollang_process_dispose_argv(ptr %argv, i64 %count)
  br label %error
build_error:
  call void @free(ptr %program)
  call void @sollang_process_dispose_argv(ptr %argv, i64 %count)
  br label %error
read_process_id:
  %handle = inttoptr i64 %raw to ptr
  %process_id32 = call i32 @GetProcessId(ptr %handle)
  %process_id_ok = icmp ne i32 %process_id32, 0
  br i1 %process_id_ok, label %success, label %process_id_error
process_id_error:
  %terminated_id_error = call i32 @TerminateProcess(ptr %handle, i32 1)
  %reaped_id_error = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %closed_id_error = call i32 @CloseHandle(ptr %handle)
  br label %error
success:
  %process_id = zext i32 %process_id32 to i64
  %ok0 = insertvalue %sollang.process_spawn_result poison, i64 %raw, 0
  %ok1 = insertvalue %sollang.process_spawn_result %ok0, i64 %process_id, 1
  %ok2 = insertvalue %sollang.process_spawn_result %ok1, i32 0, 2
  ret %sollang.process_spawn_result %ok2
error:
  %error0 = insertvalue %sollang.process_spawn_result poison, i64 0, 0
  %error1 = insertvalue %sollang.process_spawn_result %error0, i64 0, 1
  %error2 = insertvalue %sollang.process_spawn_result %error1, i32 1, 2
  ret %sollang.process_spawn_result %error2
}
define internal %sollang.process_spawn_result @sollang_spawn_process_with_stdout(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdout_override) {
entry:
  %result = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr null, ptr %stdout_override, ptr null)
  ret %sollang.process_spawn_result %result
}
@sollang_process_null_windows = private unnamed_addr constant [4 x i8] c"NUL\00"
define internal ptr @sollang_process_open_windows_stdio(i32 %mode, ptr %path, i64 %path_length, i1 %input) {
entry:
  %inherits = icmp eq i32 %mode, 0
  br i1 %inherits, label %inherit, label %select_file
select_file:
  %is_file = icmp eq i32 %mode, 1
  br i1 %is_file, label %copy_path, label %select_null
select_null:
  %is_null = icmp eq i32 %mode, 2
  br i1 %is_null, label %open_null, label %failure
copy_path:
  %path_copy = call ptr @sollang_process_windows_path(ptr %path, i64 %path_length)
  %path_ok = icmp ne ptr %path_copy, null
  br i1 %path_ok, label %open, label %failure
open:
  %access = select i1 %input, i32 -2147483648, i32 1073741824
  %creation = select i1 %input, i32 3, i32 2
  %handle = call ptr @CreateFileW(ptr %path_copy, i32 %access, i32 1, ptr null, i32 %creation, i32 128, ptr null)
  call void @free(ptr %path_copy)
  ret ptr %handle
open_null:
  %null_access = select i1 %input, i32 -2147483648, i32 1073741824
  %null_creation = select i1 %input, i32 3, i32 2
  %null_handle = call ptr @CreateFileA(ptr @sollang_process_null_windows, i32 %null_access, i32 3, ptr null, i32 %null_creation, i32 128, ptr null)
  ret ptr %null_handle
inherit:
  ret ptr null
failure:
  ret ptr inttoptr (i64 -1 to ptr)
}
define internal void @sollang_process_close_windows_stdio(ptr %handle) {
entry:
  %value = ptrtoint ptr %handle to i64
  %present = icmp ne i64 %value, 0
  %valid = icmp ne i64 %value, -1
  %should_close = and i1 %present, %valid
  br i1 %should_close, label %close, label %done
close:
  %closed = call i32 @CloseHandle(ptr %handle)
  br label %done
done:
  ret void
}
define internal %sollang.process_spawn_result @sollang_spawn_process_configured(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length) {
entry:
  %stdin_inherits = icmp eq i32 %stdin_mode, 0
  %stdout_inherits = icmp eq i32 %stdout_mode, 0
  %stderr_inherits = icmp eq i32 %stderr_mode, 0
  %output_inherits = and i1 %stdout_inherits, %stderr_inherits
  %all_inherit = and i1 %stdin_inherits, %output_inherits
  br i1 %all_inherit, label %inherit, label %open
inherit:
  %inherited = call %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  ret %sollang.process_spawn_result %inherited
open:
  %stdin_handle = call ptr @sollang_process_open_windows_stdio(i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i1 true)
  %stdout_handle = call ptr @sollang_process_open_windows_stdio(i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i1 false)
  %stderr_handle = call ptr @sollang_process_open_windows_stdio(i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length, i1 false)
  %stdin_value = ptrtoint ptr %stdin_handle to i64
  %stdout_value = ptrtoint ptr %stdout_handle to i64
  %stderr_value = ptrtoint ptr %stderr_handle to i64
  %stdin_ok = icmp ne i64 %stdin_value, -1
  %stdout_ok = icmp ne i64 %stdout_value, -1
  %stderr_ok = icmp ne i64 %stderr_value, -1
  %stdio_ok0 = and i1 %stdin_ok, %stdout_ok
  %stdio_ok = and i1 %stdio_ok0, %stderr_ok
  br i1 %stdio_ok, label %spawn, label %open_failure
spawn:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdin_handle, ptr %stdout_handle, ptr %stderr_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdin_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdout_handle)
  call void @sollang_process_close_windows_stdio(ptr %stderr_handle)
  ret %sollang.process_spawn_result %spawned
open_failure:
  call void @sollang_process_close_windows_stdio(ptr %stdin_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdout_handle)
  call void @sollang_process_close_windows_stdio(ptr %stderr_handle)
  ret %sollang.process_spawn_result { i64 0, i64 0, i32 1 }
}
define internal %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment) {
entry:
  %result = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr null, ptr null, ptr null)
  ret %sollang.process_spawn_result %result
}
define internal %sollang.process_result @sollang_wait_process(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %wait, label %error
wait:
  %handle = inttoptr i64 %token to ptr
  %waited = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %wait_ok = icmp eq i32 %waited, 0
  br i1 %wait_ok, label %read_exit, label %terminate_error
read_exit:
  %exit_slot = alloca i32, align 4
  %read = call i32 @GetExitCodeProcess(ptr %handle, ptr %exit_slot)
  %read_ok = icmp ne i32 %read, 0
  br i1 %read_ok, label %success, label %terminate_error
success:
  %exit_code = load i32, ptr %exit_slot, align 4
  %closed = call i32 @CloseHandle(ptr %handle)
  %ok0 = insertvalue %sollang.process_result poison, i32 %exit_code, 0
  %ok1 = insertvalue %sollang.process_result %ok0, i32 0, 1
  ret %sollang.process_result %ok1
terminate_error:
  %terminated = call i32 @TerminateProcess(ptr %handle, i32 1)
  %reaped = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %closed_error = call i32 @CloseHandle(ptr %handle)
  br label %error
error:
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 2, 1
  ret %sollang.process_result %error1
}
define internal %sollang.process_poll_result @sollang_poll_process(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %poll, label %poll_error
poll:
  %handle = inttoptr i64 %token to ptr
  %waited = call i32 @WaitForSingleObject(ptr %handle, i32 0)
  %exited = icmp eq i32 %waited, 0
  %running = icmp eq i32 %waited, 258
  br i1 %exited, label %read_exit, label %classify_pending
classify_pending:
  br i1 %running, label %poll_running, label %poll_error
read_exit:
  %exit_slot = alloca i32, align 4
  %read = call i32 @GetExitCodeProcess(ptr %handle, ptr %exit_slot)
  %read_ok = icmp ne i32 %read, 0
  br i1 %read_ok, label %close_exit, label %poll_error
close_exit:
  %exit_code = load i32, ptr %exit_slot, align 4
  %closed = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %closed, 0
  br i1 %close_ok, label %poll_exited, label %poll_error
poll_exited:
  %exited0 = insertvalue %sollang.process_poll_result poison, i32 %exit_code, 0
  %exited1 = insertvalue %sollang.process_poll_result %exited0, i32 1, 1
  ret %sollang.process_poll_result %exited1
poll_running:
  ret %sollang.process_poll_result { i32 0, i32 0 }
poll_error:
  ret %sollang.process_poll_result { i32 0, i32 2 }
}
define internal i1 @sollang_kill_process(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %terminate, label %failure
terminate:
  %handle = inttoptr i64 %token to ptr
  %terminated = call i32 @TerminateProcess(ptr %handle, i32 1)
  %succeeded = icmp ne i32 %terminated, 0
  ret i1 %succeeded
failure:
  ret i1 false
}
define internal void @sollang_drop_process_child(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %dispose, label %done
dispose:
  %handle = inttoptr i64 %token to ptr
  %terminated = call i32 @TerminateProcess(ptr %handle, i32 1)
  %reaped = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %closed = call i32 @CloseHandle(ptr %handle)
  br label %done
done:
  ret void
}
define internal %sollang.process_result @sollang_run_process(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment) {
entry:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %error = extractvalue %sollang.process_spawn_result %spawned, 2
  %ok = icmp eq i32 %error, 0
  br i1 %ok, label %wait, label %spawn_error
wait:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result
spawn_error:
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 1, 1
  ret %sollang.process_result %error1
}
define internal %sollang.process_result @sollang_run_process_configured(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length) {
entry:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_configured(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %error = extractvalue %sollang.process_spawn_result %spawned, 2
  %ok = icmp eq i32 %error, 0
  br i1 %ok, label %wait, label %spawn_error
wait:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result
spawn_error:
  ret %sollang.process_result { i32 0, i32 1 }
}
define internal %sollang.process_result @sollang_run_process_to_file(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %path, i64 %path_length) {
entry:
  %path_copy = call ptr @sollang_process_windows_path(ptr %path, i64 %path_length)
  %path_ok = icmp ne ptr %path_copy, null
  br i1 %path_ok, label %open, label %error
open:
  %output = call ptr @CreateFileW(ptr %path_copy, i32 1073741824, i32 1, ptr null, i32 2, i32 128, ptr null)
  call void @free(ptr %path_copy)
  %output_handle_value = ptrtoint ptr %output to i64
  %opened = icmp ne i64 %output_handle_value, -1
  br i1 %opened, label %run, label %error
run:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_with_stdout(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %output)
  %closed_output = call i32 @CloseHandle(ptr %output)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %spawn_error = extractvalue %sollang.process_spawn_result %spawned, 2
  %spawn_ok = icmp eq i32 %spawn_error, 0
  br i1 %spawn_ok, label %wait, label %error
wait:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result
error:
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 1, 1
  ret %sollang.process_result %error1
}
define internal void @sollang_directory_copy(ptr %destination, ptr %source, i64 %length) {
entry:
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %body ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %finish, label %body
body:
  %source_slot = getelementptr i8, ptr %source, i64 %index
  %byte = load i8, ptr %source_slot, align 1
  %destination_slot = getelementptr i8, ptr %destination, i64 %index
  store i8 %byte, ptr %destination_slot, align 1
  %next = add i64 %index, 1
  br label %loop
finish:
  ret void
}

define internal i32 @sollang_directory_compare_nodes(ptr %left, ptr %right) {
entry:
  %left_len_slot = getelementptr %sollang.directory_node, ptr %left, i32 0, i32 1
  %left_len = load i64, ptr %left_len_slot, align 8
  %right_len_slot = getelementptr %sollang.directory_node, ptr %right, i32 0, i32 1
  %right_len = load i64, ptr %right_len_slot, align 8
  %left_name = getelementptr i8, ptr %left, i64 24
  %right_name = getelementptr i8, ptr %right, i64 24
  %left_shorter = icmp ult i64 %left_len, %right_len
  %minimum = select i1 %left_shorter, i64 %left_len, i64 %right_len
  br label %compare
compare:
  %index = phi i64 [ 0, %entry ], [ %next, %equal_byte ]
  %within = icmp ult i64 %index, %minimum
  br i1 %within, label %compare_byte, label %compare_length
compare_byte:
  %left_ptr = getelementptr i8, ptr %left_name, i64 %index
  %right_ptr = getelementptr i8, ptr %right_name, i64 %index
  %left_byte = load i8, ptr %left_ptr, align 1
  %right_byte = load i8, ptr %right_ptr, align 1
  %same = icmp eq i8 %left_byte, %right_byte
  br i1 %same, label %equal_byte, label %different_byte
equal_byte:
  %next = add i64 %index, 1
  br label %compare
different_byte:
  %less = icmp ult i8 %left_byte, %right_byte
  %byte_result = select i1 %less, i32 -1, i32 1
  ret i32 %byte_result
compare_length:
  %same_length = icmp eq i64 %left_len, %right_len
  br i1 %same_length, label %equal, label %different_length
different_length:
  %length_result = select i1 %left_shorter, i32 -1, i32 1
  ret i32 %length_result
equal:
  ret i32 0
}

define internal ptr @sollang_directory_insert_sorted(ptr %head, ptr %node) {
entry:
  %empty = icmp eq ptr %head, null
  br i1 %empty, label %only, label %compare_head
only:
  %only_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr null, ptr %only_next, align 8
  ret ptr %node
compare_head:
  %head_order = call i32 @sollang_directory_compare_nodes(ptr %node, ptr %head)
  %before_head = icmp slt i32 %head_order, 0
  br i1 %before_head, label %prepend, label %scan_start
prepend:
  %prepend_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr %head, ptr %prepend_next, align 8
  ret ptr %node
scan_start:
  %head_next_slot = getelementptr %sollang.directory_node, ptr %head, i32 0, i32 0
  %head_next = load ptr, ptr %head_next_slot, align 8
  br label %scan
scan:
  %previous = phi ptr [ %head, %scan_start ], [ %current, %advance ]
  %current = phi ptr [ %head_next, %scan_start ], [ %next, %advance ]
  %at_end = icmp eq ptr %current, null
  br i1 %at_end, label %append, label %compare_current
compare_current:
  %order = call i32 @sollang_directory_compare_nodes(ptr %node, ptr %current)
  %before = icmp slt i32 %order, 0
  br i1 %before, label %insert, label %advance
advance:
  %current_next_slot = getelementptr %sollang.directory_node, ptr %current, i32 0, i32 0
  %next = load ptr, ptr %current_next_slot, align 8
  br label %scan
insert:
  %node_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr %current, ptr %node_next, align 8
  %previous_next = getelementptr %sollang.directory_node, ptr %previous, i32 0, i32 0
  store ptr %node, ptr %previous_next, align 8
  ret ptr %head
append:
  %append_node_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr null, ptr %append_node_next, align 8
  %append_previous_next = getelementptr %sollang.directory_node, ptr %previous, i32 0, i32 0
  store ptr %node, ptr %append_previous_next, align 8
  ret ptr %head
}

define internal void @sollang_directory_free_nodes(ptr %head) {
entry:
  br label %loop
loop:
  %node = phi ptr [ %head, %entry ], [ %next, %body ]
  %done = icmp eq ptr %node, null
  br i1 %done, label %finish, label %body
body:
  %next_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  %next = load ptr, ptr %next_slot, align 8
  call void @free(ptr %node)
  br label %loop
finish:
  ret void
}

define internal ptr @sollang_directory_serialize(ptr %head, i64 %total) {
entry:
  %empty = icmp eq i64 %total, 0
  br i1 %empty, label %empty_result, label %allocate
empty_result:
  ret ptr null
allocate:
  %output = call ptr @malloc(i64 %total)
  %allocated = icmp ne ptr %output, null
  br i1 %allocated, label %loop, label %allocation_failed
allocation_failed:
  call void @sollang_directory_free_nodes(ptr %head)
  ret ptr null
loop:
  %node = phi ptr [ %head, %allocate ], [ %next_node, %body ]
  %offset = phi i64 [ 0, %allocate ], [ %next_offset, %body ]
  %done = icmp eq ptr %node, null
  br i1 %done, label %finish, label %body
body:
  %next_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  %next_node = load ptr, ptr %next_slot, align 8
  %length_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 1
  %length = load i64, ptr %length_slot, align 8
  %kind_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 2
  %kind = load i8, ptr %kind_slot, align 1
  %record = getelementptr i8, ptr %output, i64 %offset
  store i8 %kind, ptr %record, align 1
  %length32 = trunc i64 %length to i32
  %length0 = trunc i32 %length32 to i8
  %length_shift1 = lshr i32 %length32, 8
  %length1 = trunc i32 %length_shift1 to i8
  %length_shift2 = lshr i32 %length32, 16
  %length2 = trunc i32 %length_shift2 to i8
  %length_shift3 = lshr i32 %length32, 24
  %length3 = trunc i32 %length_shift3 to i8
  %length_ptr0 = getelementptr i8, ptr %record, i64 1
  %length_ptr1 = getelementptr i8, ptr %record, i64 2
  %length_ptr2 = getelementptr i8, ptr %record, i64 3
  %length_ptr3 = getelementptr i8, ptr %record, i64 4
  store i8 %length0, ptr %length_ptr0, align 1
  store i8 %length1, ptr %length_ptr1, align 1
  store i8 %length2, ptr %length_ptr2, align 1
  store i8 %length3, ptr %length_ptr3, align 1
  %destination = getelementptr i8, ptr %record, i64 5
  %source = getelementptr i8, ptr %node, i64 24
  call void @sollang_directory_copy(ptr %destination, ptr %source, i64 %length)
  %record_size = add i64 %length, 5
  %next_offset = add i64 %offset, %record_size
  call void @free(ptr %node)
  br label %loop
finish:
  ret ptr %output
}
define internal %sollang.path_absolute_result @sollang_platform_absolute_path(ptr %path, i64 %len, i32 %style) {
entry:
  %native_style = icmp eq i32 %style, 1
  %nonempty = icmp ugt i64 %len, 0
  %bounded = icmp ult i64 %len, 2147483647
  %sized = and i1 %nonempty, %bounded
  %valid = and i1 %native_style, %sized
  br i1 %valid, label %scan, label %fail
scan:
  %scan_index = phi i64 [0, %entry], [%scan_next, %scan_step]
  %only_spaces = phi i1 [true, %entry], [%remaining_spaces, %scan_step]
  %byte_ptr = getelementptr i8, ptr %path, i64 %scan_index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %fail, label %scan_step
scan_step:
  %space = icmp eq i8 %byte, 32
  %remaining_spaces = and i1 %only_spaces, %space
  %scan_next = add i64 %scan_index, 1
  %scan_done = icmp eq i64 %scan_next, %len
  br i1 %scan_done, label %validated, label %scan
validated:
  br i1 %remaining_spaces, label %fail, label %measure
measure:
  %len32 = trunc i64 %len to i32
  %input_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr null, i32 0)
  %input_valid = icmp sgt i32 %input_chars, 0
  br i1 %input_valid, label %allocate_input, label %fail
allocate_input:
  %input_chars64 = zext i32 %input_chars to i64
  %input_capacity = add i64 %input_chars64, 1
  %input_bytes = mul i64 %input_capacity, 2
  %input = call ptr @malloc(i64 %input_bytes)
  %input_ok = icmp ne ptr %input, null
  br i1 %input_ok, label %convert_input, label %fail
convert_input:
  %input_written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr %input, i32 %input_chars)
  %converted = icmp eq i32 %input_written, %input_chars
  br i1 %converted, label %terminate_input, label %input_fail
terminate_input:
  %input_end = getelementptr i16, ptr %input, i64 %input_chars64
  store i16 0, ptr %input_end, align 2
  %has_prefix = icmp uge i64 %len, 4
  br i1 %has_prefix, label %inspect_prefix, label %measure_absolute
inspect_prefix:
  %prefix0 = load i8, ptr %path, align 1
  %prefix1_ptr = getelementptr i8, ptr %path, i64 1
  %prefix2_ptr = getelementptr i8, ptr %path, i64 2
  %prefix3_ptr = getelementptr i8, ptr %path, i64 3
  %prefix1 = load i8, ptr %prefix1_ptr, align 1
  %prefix2 = load i8, ptr %prefix2_ptr, align 1
  %prefix3 = load i8, ptr %prefix3_ptr, align 1
  %slash0 = icmp eq i8 %prefix0, 92
  %slash1 = icmp eq i8 %prefix1, 92
  %question1 = icmp eq i8 %prefix1, 63
  %question2 = icmp eq i8 %prefix2, 63
  %slash3 = icmp eq i8 %prefix3, 92
  %extended_second = or i1 %slash1, %question1
  %extended_front = and i1 %slash0, %extended_second
  %extended_back = and i1 %question2, %slash3
  %extended = and i1 %extended_front, %extended_back
  br i1 %extended, label %preserve_extended, label %measure_absolute
preserve_extended:
  %preserved = call ptr @malloc(i64 %len)
  %preserved_ok = icmp ne ptr %preserved, null
  br i1 %preserved_ok, label %copy_extended, label %input_fail
copy_extended:
  call void @llvm.memcpy.p0.p0.i64(ptr %preserved, ptr %path, i64 %len, i1 false)
  call void @free(ptr %input)
  %extended_result0 = insertvalue %sollang.path_absolute_result poison, ptr %preserved, 0
  %extended_result1 = insertvalue %sollang.path_absolute_result %extended_result0, i64 %len, 1
  %extended_result2 = insertvalue %sollang.path_absolute_result %extended_result1, i32 1, 2
  ret %sollang.path_absolute_result %extended_result2
measure_absolute:
  %needed = call i32 @GetFullPathNameW(ptr %input, i32 0, ptr null, ptr null)
  %has_size = icmp ugt i32 %needed, 0
  br i1 %has_size, label %allocate_absolute, label %input_fail
allocate_absolute:
  %needed64 = zext i32 %needed to i64
  %absolute_bytes = mul i64 %needed64, 2
  %absolute = call ptr @malloc(i64 %absolute_bytes)
  %absolute_ok = icmp ne ptr %absolute, null
  br i1 %absolute_ok, label %resolve, label %input_fail
resolve:
  %written = call i32 @GetFullPathNameW(ptr %input, i32 %needed, ptr %absolute, ptr null)
  %resolved_nonempty = icmp ugt i32 %written, 0
  %resolved_fits = icmp ult i32 %written, %needed
  %resolved = and i1 %resolved_nonempty, %resolved_fits
  call void @free(ptr %input)
  br i1 %resolved, label %measure_output, label %absolute_fail
measure_output:
  %utf8_size = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %absolute, i32 %written, ptr null, i32 0, ptr null, ptr null)
  %output_nonempty = icmp sgt i32 %utf8_size, 0
  br i1 %output_nonempty, label %allocate_output, label %absolute_fail
allocate_output:
  %utf8_size64 = zext i32 %utf8_size to i64
  %output = call ptr @malloc(i64 %utf8_size64)
  %output_ok = icmp ne ptr %output, null
  br i1 %output_ok, label %convert_output, label %absolute_fail
convert_output:
  %output_written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %absolute, i32 %written, ptr %output, i32 %utf8_size, ptr null, ptr null)
  %output_complete = icmp eq i32 %output_written, %utf8_size
  call void @free(ptr %absolute)
  br i1 %output_complete, label %success, label %output_fail
success:
  %result0 = insertvalue %sollang.path_absolute_result poison, ptr %output, 0
  %result1 = insertvalue %sollang.path_absolute_result %result0, i64 %utf8_size64, 1
  %result2 = insertvalue %sollang.path_absolute_result %result1, i32 1, 2
  ret %sollang.path_absolute_result %result2
output_fail:
  call void @free(ptr %output)
  br label %fail
absolute_fail:
  call void @free(ptr %absolute)
  br label %fail
input_fail:
  call void @free(ptr %input)
  br label %fail
fail:
  ret %sollang.path_absolute_result zeroinitializer
}
define internal i32 @sollang_platform_create_directory(ptr %path, i64 %len, i32 %style) {
entry:
  %style_ok = icmp eq i32 %style, 1
  %length_ok = icmp ule i64 %len, 32766
  %valid = and i1 %style_ok, %length_ok
  br i1 %valid, label %prepare, label %fail
prepare:
  %capacity = add i64 %len, 1
  %buffer_size = mul i64 %capacity, 2
  %buffer = call ptr @malloc(i64 %buffer_size)
  %buffer_ok = icmp ne ptr %buffer, null
  br i1 %buffer_ok, label %convert, label %fail
convert:
  %capacity32 = trunc i64 %capacity to i32
  %converted = call i32 @sollang_windows_utf8_path(ptr %path, i64 %len, ptr %buffer, i32 %capacity32)
  %path_ok = icmp ne i32 %converted, 0
  br i1 %path_ok, label %create, label %fail_free
create:
  %created = call i32 @CreateDirectoryW(ptr %buffer, ptr null)
  %created_ok = icmp ne i32 %created, 0
  br i1 %created_ok, label %success_free, label %inspect_existing
inspect_existing:
  %attributes = call i32 @GetFileAttributesW(ptr %buffer)
  %attributes_valid = icmp ne i32 %attributes, -1
  %directory_bits = and i32 %attributes, 16
  %is_directory = icmp ne i32 %directory_bits, 0
  %exists_as_directory = and i1 %attributes_valid, %is_directory
  br i1 %exists_as_directory, label %success_free, label %fail_free
success_free:
  call void @free(ptr %buffer)
  ret i32 1
fail_free:
  call void @free(ptr %buffer)
  br label %fail
fail:
  ret i32 0
}
define internal %sollang.directory_result @sollang_platform_read_directory(ptr %path, i64 %len, i32 %style) {
entry:
  %style_ok = icmp eq i32 %style, 1
  %length_ok = icmp ule i64 %len, 32764
  %valid = and i1 %style_ok, %length_ok
  br i1 %valid, label %prepare, label %fail
prepare:
  %buffer_size = add i64 %len, 3
  %pattern = call ptr @malloc(i64 %buffer_size)
  %pattern_ok = icmp ne ptr %pattern, null
  br i1 %pattern_ok, label %copy_path, label %fail
copy_path:
  call void @sollang_directory_copy(ptr %pattern, ptr %path, i64 %len)
  %has_path = icmp ugt i64 %len, 0
  br i1 %has_path, label %inspect_last, label %append_separator
inspect_last:
  %last_index = sub i64 %len, 1
  %last_ptr = getelementptr i8, ptr %pattern, i64 %last_index
  %last = load i8, ptr %last_ptr, align 1
  %last_slash = icmp eq i8 %last, 47
  %last_backslash = icmp eq i8 %last, 92
  %has_separator = or i1 %last_slash, %last_backslash
  br i1 %has_separator, label %append_star, label %append_separator
append_separator:
  %separator_ptr = getelementptr i8, ptr %pattern, i64 %len
  store i8 92, ptr %separator_ptr, align 1
  %separator_star_index = add i64 %len, 1
  %separator_star_ptr = getelementptr i8, ptr %pattern, i64 %separator_star_index
  store i8 42, ptr %separator_star_ptr, align 1
  %separator_zero_index = add i64 %len, 2
  %separator_zero_ptr = getelementptr i8, ptr %pattern, i64 %separator_zero_index
  store i8 0, ptr %separator_zero_ptr, align 1
  br label %open
append_star:
  %star_ptr = getelementptr i8, ptr %pattern, i64 %len
  store i8 42, ptr %star_ptr, align 1
  %star_zero_index = add i64 %len, 1
  %star_zero_ptr = getelementptr i8, ptr %pattern, i64 %star_zero_index
  store i8 0, ptr %star_zero_ptr, align 1
  br label %open
open:
  %pattern_extra = phi i64 [ 2, %append_separator ], [ 1, %append_star ]
  %pattern_capacity = add i64 %len, 3
  %wide_bytes = mul i64 %pattern_capacity, 2
  %wide_pattern = call ptr @malloc(i64 %wide_bytes)
  %wide_ok = icmp ne ptr %wide_pattern, null
  br i1 %wide_ok, label %convert_pattern, label %pattern_fail
convert_pattern:
  %actual_pattern_length = add i64 %len, %pattern_extra
  %capacity32 = trunc i64 %pattern_capacity to i32
  %converted = call i32 @sollang_windows_utf8_path(ptr %pattern, i64 %actual_pattern_length, ptr %wide_pattern, i32 %capacity32)
  call void @free(ptr %pattern)
  %converted_ok = icmp ne i32 %converted, 0
  br i1 %converted_ok, label %open_wide, label %wide_fail
open_wide:
  %find_data = alloca [592 x i8], align 8
  %utf8_name = alloca [1040 x i8], align 1
  %handle = call ptr @FindFirstFileW(ptr %wide_pattern, ptr %find_data)
  call void @free(ptr %wide_pattern)
  %invalid = icmp eq ptr %handle, inttoptr (i64 -1 to ptr)
  br i1 %invalid, label %fail, label %enumerate
pattern_fail:
  call void @free(ptr %pattern)
  br label %fail
wide_fail:
  call void @free(ptr %wide_pattern)
  br label %fail
enumerate:
  %head = phi ptr [ null, %open_wide ], [ %advanced_head, %advance ]
  %count = phi i64 [ 0, %open_wide ], [ %advanced_count, %advance ]
  %total = phi i64 [ 0, %open_wide ], [ %advanced_total, %advance ]
  %name = getelementptr i8, ptr %find_data, i64 44
  br label %name_length
name_length:
  %name_index = phi i64 [ 0, %enumerate ], [ %name_next, %name_continue ]
  %name_slot = getelementptr i16, ptr %name, i64 %name_index
  %name_unit = load i16, ptr %name_slot, align 2
  %name_end = icmp eq i16 %name_unit, 0
  %name_limit = icmp eq i64 %name_index, 259
  %name_done = or i1 %name_end, %name_limit
  br i1 %name_done, label %inspect_name, label %name_continue
name_continue:
  %name_next = add i64 %name_index, 1
  br label %name_length
inspect_name:
  %first = load i16, ptr %name, align 2
  %second_ptr = getelementptr i16, ptr %name, i64 1
  %second = load i16, ptr %second_ptr, align 2
  %length_one = icmp eq i64 %name_index, 1
  %length_two = icmp eq i64 %name_index, 2
  %first_dot = icmp eq i16 %first, 46
  %second_dot = icmp eq i16 %second, 46
  %dot = and i1 %length_one, %first_dot
  %two_dots = and i1 %first_dot, %second_dot
  %dotdot = and i1 %length_two, %two_dots
  %special = or i1 %dot, %dotdot
  br i1 %special, label %skip, label %convert_name
convert_name:
  %name_index32 = trunc i64 %name_index to i32
  %utf8_length32 = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %name, i32 %name_index32, ptr %utf8_name, i32 1040, ptr null, ptr null)
  %name_valid = icmp sgt i32 %utf8_length32, 0
  br i1 %name_valid, label %allocate_node, label %conversion_failed
allocate_node:
  %utf8_length = zext i32 %utf8_length32 to i64
  %node_size = add i64 %utf8_length, 24
  %node = call ptr @malloc(i64 %node_size)
  %node_ok = icmp ne ptr %node, null
  br i1 %node_ok, label %initialize_node, label %allocation_failed
initialize_node:
  %node_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr null, ptr %node_next, align 8
  %node_length = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 1
  store i64 %utf8_length, ptr %node_length, align 8
  %attributes = load i32, ptr %find_data, align 4
  %reparse_bits = and i32 %attributes, 1024
  %is_reparse = icmp ne i32 %reparse_bits, 0
  %directory_bits = and i32 %attributes, 16
  %is_directory = icmp ne i32 %directory_bits, 0
  %ordinary_kind = select i1 %is_directory, i8 1, i8 0
  %kind = select i1 %is_reparse, i8 2, i8 %ordinary_kind
  %node_kind = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 2
  store i8 %kind, ptr %node_kind, align 1
  %node_name = getelementptr i8, ptr %node, i64 24
  call void @sollang_directory_copy(ptr %node_name, ptr %utf8_name, i64 %utf8_length)
  %inserted_head = call ptr @sollang_directory_insert_sorted(ptr %head, ptr %node)
  %inserted_count = add i64 %count, 1
  %record_size = add i64 %utf8_length, 5
  %inserted_total = add i64 %total, %record_size
  br label %advance
skip:
  br label %advance
advance:
  %advanced_head = phi ptr [ %head, %skip ], [ %inserted_head, %initialize_node ]
  %advanced_count = phi i64 [ %count, %skip ], [ %inserted_count, %initialize_node ]
  %advanced_total = phi i64 [ %total, %skip ], [ %inserted_total, %initialize_node ]
  call void @SetLastError(i32 0)
  %has_next_status = call i32 @FindNextFileW(ptr %handle, ptr %find_data)
  %has_next = icmp ne i32 %has_next_status, 0
  br i1 %has_next, label %enumerate, label %finish_enumeration
finish_enumeration:
  %last_error = call i32 @GetLastError()
  %normal_end = icmp eq i32 %last_error, 18
  br i1 %normal_end, label %close_success, label %enumeration_failed
close_success:
  %closed = call i32 @FindClose(ptr %handle)
  %raw = call ptr @sollang_directory_serialize(ptr %advanced_head, i64 %advanced_total)
  %has_payload = icmp ugt i64 %advanced_total, 0
  %raw_missing = icmp eq ptr %raw, null
  %serialization_failed = and i1 %has_payload, %raw_missing
  br i1 %serialization_failed, label %fail, label %success
success:
  %success0 = insertvalue %sollang.directory_result poison, ptr %raw, 0
  %success1 = insertvalue %sollang.directory_result %success0, i64 %advanced_total, 1
  %success2 = insertvalue %sollang.directory_result %success1, i64 %advanced_count, 2
  %success3 = insertvalue %sollang.directory_result %success2, i32 1, 3
  ret %sollang.directory_result %success3
allocation_failed:
  call void @sollang_directory_free_nodes(ptr %head)
  %allocation_closed = call i32 @FindClose(ptr %handle)
  br label %fail
conversion_failed:
  call void @sollang_directory_free_nodes(ptr %head)
  %conversion_closed = call i32 @FindClose(ptr %handle)
  br label %fail
enumeration_failed:
  call void @sollang_directory_free_nodes(ptr %advanced_head)
  %failure_closed = call i32 @FindClose(ptr %handle)
  br label %fail
fail:
  %failure0 = insertvalue %sollang.directory_result poison, ptr null, 0
  %failure1 = insertvalue %sollang.directory_result %failure0, i64 0, 1
  %failure2 = insertvalue %sollang.directory_result %failure1, i64 0, 2
  %failure3 = insertvalue %sollang.directory_result %failure2, i32 0, 3
  ret %sollang.directory_result %failure3
}
define internal %sollang.path_query_result @sollang_platform_query_path(ptr %path, i64 %len, i32 %style) {
entry:
  %style_ok = icmp eq i32 %style, 1
  %len32 = trunc i64 %len to i32
  %len_roundtrip = zext i32 %len32 to i64
  %length_ok = icmp eq i64 %len_roundtrip, %len
  %input_ok = and i1 %style_ok, %length_ok
  br i1 %input_ok, label %measure_input, label %fail
measure_input:
  %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr null, i32 0)
  %wide_ok = icmp sgt i32 %wide_chars, 0
  br i1 %wide_ok, label %allocate_input, label %fail
allocate_input:
  %wide_chars64 = zext i32 %wide_chars to i64
  %wide_with_zero = add i64 %wide_chars64, 1
  %wide_bytes = mul i64 %wide_with_zero, 2
  %wide_input = call ptr @malloc(i64 %wide_bytes)
  %wide_input_ok = icmp ne ptr %wide_input, null
  br i1 %wide_input_ok, label %convert_input, label %fail
convert_input:
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr %wide_input, i32 %wide_chars)
  %converted_ok = icmp eq i32 %converted, %wide_chars
  br i1 %converted_ok, label %terminate_input, label %input_fail
terminate_input:
  %wide_zero = getelementptr i16, ptr %wide_input, i64 %wide_chars64
  store i16 0, ptr %wide_zero, align 2
  %handle = call ptr @CreateFileW(ptr %wide_input, i32 0, i32 7, ptr null, i32 3, i32 33554432, ptr null)
  call void @free(ptr %wide_input)
  %invalid_handle = inttoptr i64 -1 to ptr
  %handle_ok = icmp ne ptr %handle, %invalid_handle
  br i1 %handle_ok, label %measure_canonical, label %fail
measure_canonical:
  %canonical_chars = call i32 @GetFinalPathNameByHandleW(ptr %handle, ptr null, i32 0, i32 0)
  %canonical_ok = icmp sgt i32 %canonical_chars, 0
  br i1 %canonical_ok, label %allocate_canonical, label %handle_fail
allocate_canonical:
  %canonical_capacity = add i32 %canonical_chars, 1
  %canonical_capacity64 = zext i32 %canonical_capacity to i64
  %canonical_wide_bytes = mul i64 %canonical_capacity64, 2
  %canonical_wide = call ptr @malloc(i64 %canonical_wide_bytes)
  %canonical_wide_ok = icmp ne ptr %canonical_wide, null
  br i1 %canonical_wide_ok, label %read_canonical, label %handle_fail
read_canonical:
  %canonical_written = call i32 @GetFinalPathNameByHandleW(ptr %handle, ptr %canonical_wide, i32 %canonical_capacity, i32 0)
  %canonical_written_positive = icmp sgt i32 %canonical_written, 0
  %canonical_written_fits = icmp ule i32 %canonical_written, %canonical_chars
  %canonical_written_ok = and i1 %canonical_written_positive, %canonical_written_fits
  br i1 %canonical_written_ok, label %metadata, label %canonical_wide_fail
metadata:
  %information = alloca [52 x i8], align 8
  %information_status = call i32 @GetFileInformationByHandle(ptr %handle, ptr %information)
  %information_ok = icmp ne i32 %information_status, 0
  br i1 %information_ok, label %measure_utf8, label %canonical_wide_fail
measure_utf8:
  %utf8_bytes = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %canonical_wide, i32 %canonical_written, ptr null, i32 0, ptr null, ptr null)
  %utf8_ok = icmp sgt i32 %utf8_bytes, 0
  br i1 %utf8_ok, label %allocate_utf8, label %canonical_wide_fail
allocate_utf8:
  %utf8_bytes64 = zext i32 %utf8_bytes to i64
  %canonical_utf8 = call ptr @malloc(i64 %utf8_bytes64)
  %canonical_utf8_ok = icmp ne ptr %canonical_utf8, null
  br i1 %canonical_utf8_ok, label %convert_canonical, label %canonical_wide_fail
convert_canonical:
  %utf8_written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %canonical_wide, i32 %canonical_written, ptr %canonical_utf8, i32 %utf8_bytes, ptr null, ptr null)
  %utf8_written_ok = icmp eq i32 %utf8_written, %utf8_bytes
  br i1 %utf8_written_ok, label %success, label %utf8_fail
success:
  %attributes = load i32, ptr %information, align 4
  %directory_bits = and i32 %attributes, 16
  %is_directory = icmp ne i32 %directory_bits, 0
  %kind = select i1 %is_directory, i8 1, i8 0
  %size_high_ptr = getelementptr i8, ptr %information, i64 32
  %size_high32 = load i32, ptr %size_high_ptr, align 4
  %size_low_ptr = getelementptr i8, ptr %information, i64 36
  %size_low32 = load i32, ptr %size_low_ptr, align 4
  %size_high = zext i32 %size_high32 to i64
  %size_low = zext i32 %size_low32 to i64
  %size_shifted = shl i64 %size_high, 32
  %size = or i64 %size_shifted, %size_low
  %time_low_ptr = getelementptr i8, ptr %information, i64 20
  %time_low32 = load i32, ptr %time_low_ptr, align 4
  %time_high_ptr = getelementptr i8, ptr %information, i64 24
  %time_high32 = load i32, ptr %time_high_ptr, align 4
  %time_low = zext i32 %time_low32 to i64
  %time_high = zext i32 %time_high32 to i64
  %time_shifted = shl i64 %time_high, 32
  %file_time = or i64 %time_shifted, %time_low
  %unix_ticks = sub i64 %file_time, 116444736000000000
  %modified_nanos = mul i64 %unix_ticks, 100
  call void @free(ptr %canonical_wide)
  %closed = call i32 @CloseHandle(ptr %handle)
  %result0 = insertvalue %sollang.path_query_result poison, ptr %canonical_utf8, 0
  %result1 = insertvalue %sollang.path_query_result %result0, i64 %utf8_bytes64, 1
  %result2 = insertvalue %sollang.path_query_result %result1, i8 %kind, 2
  %result3 = insertvalue %sollang.path_query_result %result2, i64 %size, 3
  %result4 = insertvalue %sollang.path_query_result %result3, i64 %modified_nanos, 4
  %result5 = insertvalue %sollang.path_query_result %result4, i32 1, 5
  ret %sollang.path_query_result %result5
utf8_fail:
  call void @free(ptr %canonical_utf8)
  br label %canonical_wide_fail
canonical_wide_fail:
  call void @free(ptr %canonical_wide)
  br label %handle_fail
handle_fail:
  %failed_closed = call i32 @CloseHandle(ptr %handle)
  br label %fail
input_fail:
  call void @free(ptr %wide_input)
  br label %fail
fail:
  %failure_path0 = insertvalue %sollang.path_query_result poison, ptr null, 0
  %failure_path1 = insertvalue %sollang.path_query_result %failure_path0, i64 0, 1
  %failure_path2 = insertvalue %sollang.path_query_result %failure_path1, i8 3, 2
  %failure_path3 = insertvalue %sollang.path_query_result %failure_path2, i64 0, 3
  %failure_path4 = insertvalue %sollang.path_query_result %failure_path3, i64 0, 4
  %failure_path5 = insertvalue %sollang.path_query_result %failure_path4, i32 0, 5
  ret %sollang.path_query_result %failure_path5
}
define internal i32 @sollang_windows_utf8_path(ptr %data, i64 %length, ptr %wide, i32 %capacity) {
entry:
  %positive = icmp ugt i64 %length, 0
  %fits_i32 = icmp ule i64 %length, 2147483647
  %length_valid = and i1 %positive, %fits_i32
  br i1 %length_valid, label %check, label %failure
check:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %convert, label %inspect
inspect:
  %byte_ptr = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %failure, label %advance
advance:
  %next = add i64 %index, 1
  br label %check
convert:
  %length32 = trunc i64 %length to i32
  %room = sub i32 %capacity, 1
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length32, ptr %wide, i32 %room)
  %converted_ok = icmp sgt i32 %converted, 0
  br i1 %converted_ok, label %terminate, label %failure
terminate:
  %zero = getelementptr i16, ptr %wide, i32 %converted
  store i16 0, ptr %zero, align 2
  ret i32 1
failure:
  ret i32 0
}
declare dllimport i32 @ReadFile(ptr, ptr, i32, ptr, ptr)
declare dllimport i32 @GetOverlappedResult(ptr, ptr, ptr, i32)
declare dllimport i32 @FlushFileBuffers(ptr)
declare dllimport i32 @MoveFileExW(ptr, ptr, i32)
define internal i32 @sollang_platform_create_exclusive_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %copy, label %failure
copy:
  %valid = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %valid, 0
  br i1 %valid_path, label %create, label %failure
create:
  %handle = call ptr @CreateFileW(ptr %buffer_ptr, i32 1073741824, i32 0, ptr null, i32 1, i32 128, ptr null)
  %handle_value = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_value, -1
  br i1 %invalid, label %classify, label %close
classify:
  %error = call i32 @GetLastError()
  %file_exists = icmp eq i32 %error, 80
  %already_exists = icmp eq i32 %error, 183
  %exists = or i1 %file_exists, %already_exists
  %status = select i1 %exists, i32 0, i32 -1
  ret i32 %status
close:
  %closed = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %closed, 0
  %close_status = select i1 %close_ok, i32 1, i32 -1
  ret i32 %close_status
failure:
  ret i32 -1
}

define internal i32 @sollang_platform_remove_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %copy, label %failure
copy:
  %valid = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %valid, 0
  br i1 %valid_path, label %remove, label %failure
remove:
  %removed = call i32 @DeleteFileW(ptr %buffer_ptr)
  %success = icmp ne i32 %removed, 0
  br i1 %success, label %removed_file, label %classify
classify:
  %error = call i32 @GetLastError()
  %file_missing = icmp eq i32 %error, 2
  %path_missing = icmp eq i32 %error, 3
  %missing = or i1 %file_missing, %path_missing
  %status = select i1 %missing, i32 0, i32 -1
  ret i32 %status
removed_file:
  ret i32 1
failure:
  ret i32 -1
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %convert, label %failure
convert:
  %copied = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %copied, 0
  br i1 %valid_path, label %open, label %failure
open:
  %handle = call ptr @CreateFileW(ptr %buffer_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 1073741952, ptr null)
  %handle_value = ptrtoint ptr %handle to i64
  %valid_handle = icmp ne i64 %handle_value, -1
  br i1 %valid_handle, label %success, label %failure
success:
  %result0 = insertvalue %sollang.file_handle_result poison, i64 %handle_value, 0
  %result1 = insertvalue %sollang.file_handle_result %result0, i32 1, 1
  ret %sollang.file_handle_result %result1
failure:
  %failure0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %failure1 = insertvalue %sollang.file_handle_result %failure0, i32 0, 1
  ret %sollang.file_handle_result %failure1
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %convert, label %failure
convert:
  %copied = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %copied, 0
  br i1 %valid_path, label %open, label %failure
open:
  %handle = call ptr @CreateFileW(ptr %buffer_ptr, i32 1073741824, i32 1, ptr null, i32 2, i32 1073741952, ptr null)
  %handle_value = ptrtoint ptr %handle to i64
  %valid_handle = icmp ne i64 %handle_value, -1
  br i1 %valid_handle, label %success, label %failure
success:
  %result0 = insertvalue %sollang.file_handle_result poison, i64 %handle_value, 0
  %result1 = insertvalue %sollang.file_handle_result %result0, i32 1, 1
  ret %sollang.file_handle_result %result1
failure:
  %failure0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %failure1 = insertvalue %sollang.file_handle_result %failure0, i32 0, 1
  ret %sollang.file_handle_result %failure1
}

define internal %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %handle_value, ptr %data, i64 %length, i64 %offset) {
entry:
  %valid_handle = icmp ne i64 %handle_value, -1
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %fits = icmp ule i64 %length, 4294967295
  %ready0 = and i1 %valid_handle, %valid_offset
  %ready = and i1 %ready0, %fits
  br i1 %ready, label %read, label %failure
read:
  %handle = inttoptr i64 %handle_value to ptr
  %overlapped = alloca [32 x i8], align 8
  store [32 x i8] zeroinitializer, ptr %overlapped, align 8
  %offset_low_slot = getelementptr i8, ptr %overlapped, i64 16
  %offset_low = trunc i64 %offset to i32
  store i32 %offset_low, ptr %offset_low_slot, align 4
  %offset_high_slot = getelementptr i8, ptr %overlapped, i64 20
  %offset_shifted = lshr i64 %offset, 32
  %offset_high = trunc i64 %offset_shifted to i32
  store i32 %offset_high, ptr %offset_high_slot, align 4
  %count_slot = alloca i32, align 4
  store i32 0, ptr %count_slot, align 4
  %length32 = trunc i64 %length to i32
  %started = call i32 @ReadFile(ptr %handle, ptr %data, i32 %length32, ptr null, ptr %overlapped)
  %completed = call i32 @GetOverlappedResult(ptr %handle, ptr %overlapped, ptr %count_slot, i32 1)
  %ok = icmp ne i32 %completed, 0
  br i1 %ok, label %success, label %classify_failure
classify_failure:
  %error = call i32 @GetLastError()
  %eof = icmp eq i32 %error, 38
  br i1 %eof, label %success, label %failure
success:
  %count32 = load i32, ptr %count_slot, align 4
  %count = zext i32 %count32 to i64
  %result0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %result1 = insertvalue %sollang.file_count_result %result0, i32 1, 1
  ret %sollang.file_count_result %result1
failure:
  %failure0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %failure1 = insertvalue %sollang.file_count_result %failure0, i32 0, 1
  ret %sollang.file_count_result %failure1
}

define internal %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %handle_value, ptr %data, i64 %length, i64 %offset) {
entry:
  %valid_handle = icmp ne i64 %handle_value, -1
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %fits = icmp ule i64 %length, 4294967295
  %ready0 = and i1 %valid_handle, %valid_offset
  %ready = and i1 %ready0, %fits
  br i1 %ready, label %write, label %failure
write:
  %handle = inttoptr i64 %handle_value to ptr
  %overlapped = alloca [32 x i8], align 8
  store [32 x i8] zeroinitializer, ptr %overlapped, align 8
  %offset_low_slot = getelementptr i8, ptr %overlapped, i64 16
  %offset_low = trunc i64 %offset to i32
  store i32 %offset_low, ptr %offset_low_slot, align 4
  %offset_high_slot = getelementptr i8, ptr %overlapped, i64 20
  %offset_shifted = lshr i64 %offset, 32
  %offset_high = trunc i64 %offset_shifted to i32
  store i32 %offset_high, ptr %offset_high_slot, align 4
  %count_slot = alloca i32, align 4
  store i32 0, ptr %count_slot, align 4
  %length32 = trunc i64 %length to i32
  %started = call i32 @WriteFile(ptr %handle, ptr %data, i32 %length32, ptr null, ptr %overlapped)
  %completed = call i32 @GetOverlappedResult(ptr %handle, ptr %overlapped, ptr %count_slot, i32 1)
  %ok = icmp ne i32 %completed, 0
  br i1 %ok, label %success, label %failure
success:
  %count32 = load i32, ptr %count_slot, align 4
  %count = zext i32 %count32 to i64
  %result0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %result1 = insertvalue %sollang.file_count_result %result0, i32 1, 1
  ret %sollang.file_count_result %result1
failure:
  %failure0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %failure1 = insertvalue %sollang.file_count_result %failure0, i32 0, 1
  ret %sollang.file_count_result %failure1
}

define internal i32 @sollang_platform_sync_owned_file(i64 %handle_value) {
entry:
  %valid = icmp ne i64 %handle_value, -1
  br i1 %valid, label %sync, label %failure
sync:
  %handle = inttoptr i64 %handle_value to ptr
  %result = call i32 @FlushFileBuffers(ptr %handle)
  ret i32 %result
failure:
  ret i32 0
}

define internal void @sollang_platform_close_owned_file(i64 %handle_value) {
entry:
  %valid = icmp ne i64 %handle_value, -1
  br i1 %valid, label %close, label %done
close:
  %handle = inttoptr i64 %handle_value to ptr
  %ignored = call i32 @CloseHandle(ptr %handle)
  br label %done
done:
  ret void
}

define internal i32 @sollang_platform_atomic_replace_file(ptr %temporary, i64 %temporary_length, ptr %destination, i64 %destination_length) {
entry:
  %temporary_buffer = alloca [260 x i16], align 2
  %temporary_ptr = getelementptr inbounds [260 x i16], ptr %temporary_buffer, i64 0, i64 0
  %temporary_fits = icmp ule i64 %temporary_length, 259
  br i1 %temporary_fits, label %convert_temporary, label %failure
convert_temporary:
  %temporary_copied = call i32 @sollang_windows_utf8_path(ptr %temporary, i64 %temporary_length, ptr %temporary_ptr, i32 260)
  %temporary_ok = icmp ne i32 %temporary_copied, 0
  br i1 %temporary_ok, label %destination_path, label %failure
destination_path:
  %destination_buffer = alloca [260 x i16], align 2
  %destination_ptr = getelementptr inbounds [260 x i16], ptr %destination_buffer, i64 0, i64 0
  %destination_fits = icmp ule i64 %destination_length, 259
  br i1 %destination_fits, label %convert_destination, label %failure
convert_destination:
  %destination_copied = call i32 @sollang_windows_utf8_path(ptr %destination, i64 %destination_length, ptr %destination_ptr, i32 260)
  %destination_ok = icmp ne i32 %destination_copied, 0
  br i1 %destination_ok, label %replace, label %failure
replace:
  %result = call i32 @MoveFileExW(ptr %temporary_ptr, ptr %destination_ptr, i32 9)
  ret i32 %result
failure:
  ret i32 0
}
@sollang_binary_writer_handle = internal global i64 -1
@sollang_binary_writer_offset = internal global i64 0
@sollang_binary_reader_handle = internal global i64 -1
@sollang_binary_reader_offset = internal global i64 0

define internal void @sollang_binary_open_writer(ptr %path, i64 %length) {
entry:
  %old = load i64, ptr @sollang_binary_writer_handle, align 8
  call void @sollang_platform_close_owned_file(i64 %old)
  store i64 -1, ptr @sollang_binary_writer_handle, align 8
  %opened = call %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %path, i64 %length)
  %handle = extractvalue %sollang.file_handle_result %opened, 0
  %status = extractvalue %sollang.file_handle_result %opened, 1
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %ready, label %failure
ready:
  store i64 %handle, ptr @sollang_binary_writer_handle, align 8
  store i64 0, ptr @sollang_binary_writer_offset, align 8
  ret void
failure:
  call void @llvm.trap()
  unreachable
}

define internal void @sollang_binary_write(ptr %data, i64 %length) {
entry:
  %handle = load i64, ptr @sollang_binary_writer_handle, align 8
  %valid = icmp ne i64 %handle, -1
  br i1 %valid, label %write, label %failure
write:
  %offset = load i64, ptr @sollang_binary_writer_offset, align 8
  %result = call %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %handle, ptr %data, i64 %length, i64 %offset)
  %count = extractvalue %sollang.file_count_result %result, 0
  %status = extractvalue %sollang.file_count_result %result, 1
  %called = icmp ne i32 %status, 0
  %full = icmp eq i64 %count, %length
  %ok = and i1 %called, %full
  br i1 %ok, label %advance, label %failure
advance:
  %next = add i64 %offset, %count
  store i64 %next, ptr @sollang_binary_writer_offset, align 8
  ret void
failure:
  call void @llvm.trap()
  unreachable
}

define internal void @sollang_binary_close_writer() {
entry:
  %handle = load i64, ptr @sollang_binary_writer_handle, align 8
  store i64 -1, ptr @sollang_binary_writer_handle, align 8
  store i64 0, ptr @sollang_binary_writer_offset, align 8
  %valid = icmp ne i64 %handle, -1
  br i1 %valid, label %sync, label %done
sync:
  %status = call i32 @sollang_platform_sync_owned_file(i64 %handle)
  call void @sollang_platform_close_owned_file(i64 %handle)
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %done, label %failure
failure:
  call void @llvm.trap()
  unreachable
done:
  ret void
}

define internal void @sollang_binary_open_reader(ptr %path, i64 %length) {
entry:
  %old = load i64, ptr @sollang_binary_reader_handle, align 8
  call void @sollang_platform_close_owned_file(i64 %old)
  store i64 -1, ptr @sollang_binary_reader_handle, align 8
  %opened = call %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %path, i64 %length)
  %handle = extractvalue %sollang.file_handle_result %opened, 0
  %status = extractvalue %sollang.file_handle_result %opened, 1
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %ready, label %failure
ready:
  store i64 %handle, ptr @sollang_binary_reader_handle, align 8
  store i64 0, ptr @sollang_binary_reader_offset, align 8
  ret void
failure:
  call void @llvm.trap()
  unreachable
}

define internal %sollang.file_count_result @sollang_binary_read(ptr %data, i64 %length) {
entry:
  %handle = load i64, ptr @sollang_binary_reader_handle, align 8
  %offset = load i64, ptr @sollang_binary_reader_offset, align 8
  %valid = icmp ne i64 %handle, -1
  br i1 %valid, label %read, label %failure
read:
  %result = call %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %handle, ptr %data, i64 %length, i64 %offset)
  %count = extractvalue %sollang.file_count_result %result, 0
  %next = add i64 %offset, %count
  store i64 %next, ptr @sollang_binary_reader_offset, align 8
  ret %sollang.file_count_result %result
failure:
  %error0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %error1 = insertvalue %sollang.file_count_result %error0, i32 0, 1
  ret %sollang.file_count_result %error1
}

define internal void @sollang_binary_close_reader() {
entry:
  %handle = load i64, ptr @sollang_binary_reader_handle, align 8
  store i64 -1, ptr @sollang_binary_reader_handle, align 8
  store i64 0, ptr @sollang_binary_reader_offset, align 8
  call void @sollang_platform_close_owned_file(i64 %handle)
  ret void
}
%sollang.legacy_int_result = type { i64, i32 }
@sollang_legacy_int_writer_buffer = internal global [8192 x i64] zeroinitializer
@sollang_legacy_int_writer_buffer_count = internal global i64 0
define internal i32 @sollang_legacy_int_copy_text_to_c_path(ptr %data, i64 %len, ptr %out) {
entry:
  %too_long = icmp ugt i64 %len, 259
  br i1 %too_long, label %fail, label %copy

copy:
  %i = phi i64 [ 0, %entry ], [ %next, %copy_body ]
  %done = icmp eq i64 %i, %len
  br i1 %done, label %nul, label %copy_body

copy_body:
  %src = getelementptr i8, ptr %data, i64 %i
  %ch = load i8, ptr %src, align 1
  %dst = getelementptr i8, ptr %out, i64 %i
  store i8 %ch, ptr %dst, align 1
  %next = add i64 %i, 1
  br label %copy

nul:
  %nul_ptr = getelementptr i8, ptr %out, i64 %len
  store i8 0, ptr %nul_ptr, align 1
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_legacy_int_open_write_i64_file(ptr %path, i64 %len) {
entry:
  store i64 0, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %ok = call i32 @sollang_legacy_int_platform_open_write_file(ptr %path, i64 %len)
  ret i32 %ok
}

define internal i32 @sollang_legacy_int_flush_i64_file() {
entry:
  %count = load i64, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %success, label %flush

flush:
  %bytes = mul i64 %count, 8
  %ok = call i32 @sollang_legacy_int_platform_write_file_bytes(ptr @sollang_legacy_int_writer_buffer, i64 %bytes)
  %is_ok = icmp ne i32 %ok, 0
  br i1 %is_ok, label %reset, label %fail

reset:
  store i64 0, ptr @sollang_legacy_int_writer_buffer_count, align 8
  br label %success

success:
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_legacy_int_write_i64_file(i64 %value) {
entry:
  %count = load i64, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %slot = getelementptr inbounds [8192 x i64], ptr @sollang_legacy_int_writer_buffer, i64 0, i64 %count
  store i64 %value, ptr %slot, align 8
  %next = add i64 %count, 1
  store i64 %next, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %full = icmp eq i64 %next, 8192
  br i1 %full, label %flush, label %success

flush:
  %ok = call i32 @sollang_legacy_int_flush_i64_file()
  ret i32 %ok

success:
  ret i32 1
}

define internal i32 @sollang_legacy_int_close_write_i64_file() {
entry:
  %flush_ok = call i32 @sollang_legacy_int_flush_i64_file()
  %flush_is_ok = icmp ne i32 %flush_ok, 0
  br i1 %flush_is_ok, label %close, label %fail

close:
  %close_ok = call i32 @sollang_legacy_int_platform_close_write_file()
  ret i32 %close_ok

fail:
  ret i32 0
}

define internal %sollang.legacy_int_result @sollang_legacy_int_closest_i64_file(i64 %target) {
entry:
  %count_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_i64_file_count()
  %count = extractvalue %sollang.legacy_int_result %count_result, 0
  %count_ok = extractvalue %sollang.legacy_int_result %count_result, 1
  %count_is_ok = icmp ne i32 %count_ok, 0
  %has_values = icmp sgt i64 %count, 0
  %can_search = and i1 %count_is_ok, %has_values
  br i1 %can_search, label %search, label %fail

search:
  br label %loop

loop:
  %low = phi i64 [ 0, %search ], [ %next_low, %step ]
  %high = phi i64 [ %count, %search ], [ %next_high, %step ]
  %active = icmp slt i64 %low, %high
  br i1 %active, label %probe, label %choose

probe:
  %span = sub i64 %high, %low
  %half = sdiv i64 %span, 2
  %mid = add i64 %low, %half
  %mid_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %mid)
  %mid_value = extractvalue %sollang.legacy_int_result %mid_result, 0
  %mid_ok = extractvalue %sollang.legacy_int_result %mid_result, 1
  %mid_is_ok = icmp ne i32 %mid_ok, 0
  br i1 %mid_is_ok, label %compare_mid, label %fail

compare_mid:
  %less = icmp slt i64 %mid_value, %target
  br i1 %less, label %move_low, label %move_high

move_low:
  %low_plus = add i64 %mid, 1
  br label %step

move_high:
  br label %step

step:
  %next_low = phi i64 [ %low_plus, %move_low ], [ %low, %move_high ]
  %next_high = phi i64 [ %high, %move_low ], [ %mid, %move_high ]
  br label %loop

choose:
  %at_start = icmp eq i64 %low, 0
  br i1 %at_start, label %read_low, label %check_end

check_end:
  %at_end = icmp eq i64 %low, %count
  br i1 %at_end, label %read_prev_only, label %read_pair

read_low:
  %first_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 0)
  ret %sollang.legacy_int_result %first_result

read_prev_only:
  %last_index = sub i64 %count, 1
  %last_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %last_index)
  ret %sollang.legacy_int_result %last_result

read_pair:
  %prev_index = sub i64 %low, 1
  %prev_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %prev_index)
  %next_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %low)
  %prev_ok = extractvalue %sollang.legacy_int_result %prev_result, 1
  %next_ok = extractvalue %sollang.legacy_int_result %next_result, 1
  %prev_is_ok = icmp ne i32 %prev_ok, 0
  %next_is_ok = icmp ne i32 %next_ok, 0
  %both_ok = and i1 %prev_is_ok, %next_is_ok
  br i1 %both_ok, label %compare_pair, label %fail

compare_pair:
  %prev_value = extractvalue %sollang.legacy_int_result %prev_result, 0
  %next_value = extractvalue %sollang.legacy_int_result %next_result, 0
  %prev_diff = sub i64 %target, %prev_value
  %next_diff = sub i64 %next_value, %target
  %prefer_prev = icmp sle i64 %prev_diff, %next_diff
  br i1 %prefer_prev, label %return_prev, label %return_next

return_prev:
  ret %sollang.legacy_int_result %prev_result

return_next:
  ret %sollang.legacy_int_result %next_result

fail:
  %fail0 = insertvalue %sollang.legacy_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.legacy_int_result %fail0, i32 0, 1
  ret %sollang.legacy_int_result %fail1
}
define internal void @sollang_legacy_int_require(i32 %status) {
entry:
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %done, label %failure
failure:
  call void @ExitProcess(i32 1)
unreachable
done:
  ret void
}
define void @sollang_m61_s0(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  %ok = call i32 @sollang_legacy_int_open_write_i64_file(ptr %data, i64 %length)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_m61_s1(i32 %arg) {
entry:
  %wide = sext i32 %arg to i64
  %ok = call i32 @sollang_legacy_int_write_i64_file(i64 %wide)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_m61_s2() {
entry:
  %ok = call i32 @sollang_legacy_int_close_write_i64_file()
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_m61_s3(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  %ok = call i32 @sollang_legacy_int_platform_open_read_file(ptr %data, i64 %length)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_m61_s5() {
entry:
  %ok = call i32 @sollang_legacy_int_platform_close_read_file()
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define i32 @sollang_m61_s4(i32 %arg) {
entry:
  %wide = sext i32 %arg to i64
  %result = call %sollang.legacy_int_result @sollang_legacy_int_closest_i64_file(i64 %wide)
  %status = extractvalue %sollang.legacy_int_result %result, 1
  call void @sollang_legacy_int_require(i32 %status)
  %value = extractvalue %sollang.legacy_int_result %result, 0
  %narrow = trunc i64 %value to i32
  ret i32 %narrow
}
declare dllimport i32 @SetFilePointerEx(ptr, i64, ptr, i32)
@sollang_legacy_int_file_writer = internal global ptr null
@sollang_legacy_int_file_reader = internal global ptr null

define internal i32 @sollang_legacy_int_platform_open_write_file(ptr %path, i64 %len) {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_legacy_int_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:
  %handle = call ptr @CreateFileA(ptr %buf_ptr, i32 1073741824, i32 0, ptr null, i32 2, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:
  store ptr %handle, ptr @sollang_legacy_int_file_writer, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_legacy_int_platform_write_file_bytes(ptr %data, i64 %len64) {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_writer, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %write, label %fail

write:
  %written = alloca i32, align 4
  %len = trunc i64 %len64 to i32
  %ok = call i32 @WriteFile(ptr %handle, ptr %data, i32 %len, ptr %written, ptr null)
  %written32 = load i32, ptr %written, align 4
  %written64 = zext i32 %written32 to i64
  %write_ok = icmp ne i32 %ok, 0
  %full = icmp eq i64 %written64, %len64
  %all_ok = and i1 %write_ok, %full
  %result = zext i1 %all_ok to i32
  ret i32 %result

fail:
  ret i32 0
}

define internal i32 @sollang_legacy_int_platform_close_write_file() {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_writer, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %close, label %fail

close:
  %ok = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %ok, 0
  br i1 %close_ok, label %success, label %fail

success:
  store ptr null, ptr @sollang_legacy_int_file_writer, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_legacy_int_platform_open_read_file(ptr %path, i64 %len) {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_legacy_int_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:
  %handle = call ptr @CreateFileA(ptr %buf_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:
  store ptr %handle, ptr @sollang_legacy_int_file_reader, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal %sollang.legacy_int_result @sollang_legacy_int_platform_i64_file_count() {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %size, label %fail

size:
  %size_ptr = alloca i64, align 8
  %ok = call i32 @GetFileSizeEx(ptr %handle, ptr %size_ptr)
  %size_ok = icmp ne i32 %ok, 0
  br i1 %size_ok, label %check, label %fail

check:
  %bytes = load i64, ptr %size_ptr, align 8
  %rem = urem i64 %bytes, 8
  %aligned = icmp eq i64 %rem, 0
  br i1 %aligned, label %success, label %fail

success:
  %count = udiv i64 %bytes, 8
  %ok0 = insertvalue %sollang.legacy_int_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.legacy_int_result %ok0, i32 1, 1
  ret %sollang.legacy_int_result %ok1

fail:
  %fail0 = insertvalue %sollang.legacy_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.legacy_int_result %fail0, i32 0, 1
  ret %sollang.legacy_int_result %fail1
}

define internal %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %index) {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %seek, label %fail

seek:
  %offset = mul i64 %index, 8
  %seek_ok = call i32 @SetFilePointerEx(ptr %handle, i64 %offset, ptr null, i32 0)
  %seek_is_ok = icmp ne i32 %seek_ok, 0
  br i1 %seek_is_ok, label %read, label %fail

read:
  %value_ptr = alloca i64, align 8
  %read_bytes = alloca i32, align 4
  %ok = call i32 @ReadFile(ptr %handle, ptr %value_ptr, i32 8, ptr %read_bytes, ptr null)
  %read_ok = icmp ne i32 %ok, 0
  %read_count = load i32, ptr %read_bytes, align 4
  %read_full = icmp eq i32 %read_count, 8
  %all_ok = and i1 %read_ok, %read_full
  br i1 %all_ok, label %success, label %fail

success:
  %value = load i64, ptr %value_ptr, align 8
  %ok0 = insertvalue %sollang.legacy_int_result poison, i64 %value, 0
  %ok1 = insertvalue %sollang.legacy_int_result %ok0, i32 1, 1
  ret %sollang.legacy_int_result %ok1

fail:
  %fail0 = insertvalue %sollang.legacy_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.legacy_int_result %fail0, i32 0, 1
  ret %sollang.legacy_int_result %fail1
}

define internal i32 @sollang_legacy_int_platform_close_read_file() {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %close, label %fail

close:
  %ok = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %ok, 0
  br i1 %close_ok, label %success, label %fail

success:
  store ptr null, ptr @sollang_legacy_int_file_reader, align 8
  ret i32 1

fail:
  ret i32 0
}
declare i32 @getchar()
declare dllimport i32 @GetFileSizeEx(ptr, ptr)
declare dllimport ptr @CreateFileMappingA(ptr, ptr, i32, i32, i32, ptr)
declare dllimport ptr @MapViewOfFile(ptr, i32, i32, i32, i64)
declare dllimport i32 @UnmapViewOfFile(ptr)
declare dllimport i64 @GetTickCount64()
declare dllimport void @GetSystemTimePreciseAsFileTime(ptr)
@sollang_stage2_random_state = internal global i64 88172645463325252
define void @sollang_m59_s0(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 false)
  ret void
}
define void @sollang_m59_s1(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 true)
  ret void
}
define i32 @sollang_m59_s2(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 false)
  %value_slot = alloca i32, align 4
  %started_slot = alloca i1, align 1
  %negative_slot = alloca i1, align 1
  store i32 0, ptr %value_slot, align 4
  store i1 false, ptr %started_slot, align 1
  store i1 false, ptr %negative_slot, align 1
  br label %read
read:
  %character = call i32 @getchar()
  %eof = icmp eq i32 %character, -1
  br i1 %eof, label %done, label %classify
classify:
  %digit_low = icmp sge i32 %character, 48
  %digit_high = icmp sle i32 %character, 57
  %digit = and i1 %digit_low, %digit_high
  br i1 %digit, label %append, label %non_digit
append:
  %previous = load i32, ptr %value_slot, align 4
  %scaled = mul i32 %previous, 10
  %digit_value = sub i32 %character, 48
  %updated = add i32 %scaled, %digit_value
  store i32 %updated, ptr %value_slot, align 4
  store i1 true, ptr %started_slot, align 1
  br label %read
non_digit:
  %started = load i1, ptr %started_slot, align 1
  br i1 %started, label %done, label %prefix
prefix:
  %minus = icmp eq i32 %character, 45
  br i1 %minus, label %mark_negative, label %read
mark_negative:
  store i1 true, ptr %negative_slot, align 1
  br label %read
done:
  %magnitude = load i32, ptr %value_slot, align 4
  %negative = load i1, ptr %negative_slot, align 1
  %negated = sub i32 0, %magnitude
  %result = select i1 %negative, i32 %negated, i32 %magnitude
  ret i32 %result
}
define void @sollang_m67_s0(i32 %arg) {
entry:
  %seed = sext i32 %arg to i64
  store i64 %seed, ptr @sollang_stage2_random_state, align 8
  ret void
}
define i32 @sollang_m67_s1(i32 %arg) {
entry:
  %valid = icmp sgt i32 %arg, 0
  br i1 %valid, label %next, label %failure
next:
  %state = load i64, ptr @sollang_stage2_random_state, align 8
  %product = mul i64 %state, 6364136223846793005
  %updated = add i64 %product, 1442695040888963407
  store i64 %updated, ptr @sollang_stage2_random_state, align 8
  %bound = zext i32 %arg to i64
  %value = urem i64 %updated, %bound
  %result = trunc i64 %value to i32
  ret i32 %result
failure:
  ret i32 0
}

define i64 @sollang_m58_s0() {
entry:
  %value = call i64 @GetTickCount64()
  ret i64 %value
}
define i64 @sollang_m58_s1() {
entry:
  %filetime = alloca [2 x i32], align 4
  call void @GetSystemTimePreciseAsFileTime(ptr %filetime)
  %low_ptr = getelementptr inbounds [2 x i32], ptr %filetime, i64 0, i64 0
  %high_ptr = getelementptr inbounds [2 x i32], ptr %filetime, i64 0, i64 1
  %low32 = load i32, ptr %low_ptr, align 4
  %high32 = load i32, ptr %high_ptr, align 4
  %low = zext i32 %low32 to i64
  %high = zext i32 %high32 to i64
  %shifted = shl i64 %high, 32
  %ticks = or i64 %shifted, %low
  %unix_ticks = sub i64 %ticks, 116444736000000000
  %millis = udiv i64 %unix_ticks, 10000
  ret i64 %millis
}
define i8 @sollang_m58_s2() { ret i8 0 }
define void @sollang_m59_s3(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_eprint(ptr %data, i64 %length, i1 false)
  ret void
}
define void @sollang_m59_s4(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_eprintln(ptr %data, i64 %length)
  ret void
}
define void @sollang_m59_s5() {
entry:
  call void @sollang_runtime_flush_stdout()
  ret void
}
declare dllimport i32 @BCryptGenRandom(ptr, ptr, i32, i32)
define internal i1 @sollang_secure_random_fill(ptr %buffer, i64 %length) {
entry:
  %empty = icmp eq i64 %length, 0
  br i1 %empty, label %success, label %fill
fill:
  %offset = phi i64 [ 0, %entry ], [ %next_offset, %continue ]
  %remaining = sub i64 %length, %offset
  %large = icmp ugt i64 %remaining, 4294967295
  %chunk64 = select i1 %large, i64 4294967295, i64 %remaining
  %chunk = trunc i64 %chunk64 to i32
  %target = getelementptr i8, ptr %buffer, i64 %offset
  %status = call i32 @BCryptGenRandom(ptr null, ptr %target, i32 %chunk, i32 2)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %continue, label %failure
continue:
  %next_offset = add i64 %offset, %chunk64
  %done = icmp eq i64 %next_offset, %length
  br i1 %done, label %success, label %fill
success:
  ret i1 true
failure:
  ret i1 false
}
define %sollang.enum.t436 @sollang_m67_s2(i64 %arg) {
entry:
  %empty = icmp eq i64 %arg, 0
  %allocation_size = select i1 %empty, i64 1, i64 %arg
  %buffer = call ptr @malloc(i64 %allocation_size)
  %filled = call i1 @sollang_secure_random_fill(ptr %buffer, i64 %arg)
  br i1 %filled, label %success, label %failure
success:
  %success_slot = alloca %sollang.enum.t436, align 8
  store %sollang.enum.t436 zeroinitializer, ptr %success_slot, align 8
  %success_tag = getelementptr inbounds %sollang.enum.t436, ptr %success_slot, i32 0, i32 0
  store i32 0, ptr %success_tag, align 4
  %success_payload = getelementptr inbounds %sollang.enum.t436, ptr %success_slot, i32 0, i32 1
  %bytes0 = insertvalue %sollang.array.i32 poison, ptr %buffer, 0
  %bytes1 = insertvalue %sollang.array.i32 %bytes0, i64 %arg, 1
  %bytes = insertvalue %sollang.array.i32 %bytes1, i64 %arg, 2
  store %sollang.array.i32 %bytes, ptr %success_payload, align 8
  %success_result = load %sollang.enum.t436, ptr %success_slot, align 8
  ret %sollang.enum.t436 %success_result
failure:
  call void @free(ptr %buffer)
  %failure_slot = alloca %sollang.enum.t436, align 8
  store %sollang.enum.t436 zeroinitializer, ptr %failure_slot, align 8
  %failure_tag = getelementptr inbounds %sollang.enum.t436, ptr %failure_slot, i32 0, i32 0
  store i32 1, ptr %failure_tag, align 4
  %failure_result = load %sollang.enum.t436, ptr %failure_slot, align 8
  ret %sollang.enum.t436 %failure_result
}
define internal i64 @sollang_now_millis() {
entry:
  %value = call i64 @sollang_m58_s0()
  ret i64 %value
}
declare dllimport void @Sleep(i32)
define internal void @sollang_wait_millis(i64 %requested) {
entry:
  %too_large = icmp ugt i64 %requested, 4294967294
  %bounded = select i1 %too_large, i64 4294967294, i64 %requested
  %millis = trunc i64 %bounded to i32
  call void @Sleep(i32 %millis)
  ret void
}
define internal i1 @sollang_file_drain_completions() {
entry:
  ret i1 false
}

define internal void @sollang_platform_io_wait_completion(i64 %requested) {
entry:
  ret void
}

define internal void @sollang_file_wait_idle() {
entry:
  ret void
}

define internal void @sollang_async_shutdown() {
entry:
  ret void
}
define internal void @sollang_task_enqueue_ready(ptr %control) {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  store i32 0, ptr %status_slot, align 4
  %next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 3
  store ptr null, ptr %next_slot, align 8
  %tail = load ptr, ptr @sollang_task_ready_tail, align 8
  %empty = icmp eq ptr %tail, null
  br i1 %empty, label %first, label %append

first:
  store ptr %control, ptr @sollang_task_ready_head, align 8
  br label %queued

append:
  %tail_next_slot = getelementptr %sollang.task_control, ptr %tail, i32 0, i32 3
  store ptr %control, ptr %tail_next_slot, align 8
  br label %queued

queued:
  store ptr %control, ptr @sollang_task_ready_tail, align 8
  ret void
}

define internal void @sollang_task_park_on(ptr %parent, ptr %child) {
entry:
  %child_status_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 4
  %child_status = load i32, ptr %child_status_slot, align 4
  %completed = icmp eq i32 %child_status, 2
  br i1 %completed, label %done, label %park

park:
  %child_waiter_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 9
  %existing_waiter = load ptr, ptr %child_waiter_slot, align 8
  %available = icmp eq ptr %existing_waiter, null
  br i1 %available, label %attach, label %invalid

attach:
  store ptr %parent, ptr %child_waiter_slot, align 8
  %parent_child_slot = getelementptr %sollang.task_control, ptr %parent, i32 0, i32 10
  store ptr %child, ptr %parent_child_slot, align 8
  %parent_status_slot = getelementptr %sollang.task_control, ptr %parent, i32 0, i32 4
  store i32 5, ptr %parent_status_slot, align 4
  br label %done

invalid:
  call void @llvm.trap()
  unreachable

done:
  ret void
}

define internal void @sollang_task_wake_waiter(ptr %child) {
entry:
  %waiter_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 9
  %waiter = load ptr, ptr %waiter_slot, align 8
  %has_waiter = icmp ne ptr %waiter, null
  br i1 %has_waiter, label %wake, label %done

wake:
  store ptr null, ptr %waiter_slot, align 8
  %waiter_child_slot = getelementptr %sollang.task_control, ptr %waiter, i32 0, i32 10
  store ptr null, ptr %waiter_child_slot, align 8
  call void @sollang_task_enqueue_ready(ptr %waiter)
  br label %done

done:
  ret void
}

define internal void @sollang_timer_park(ptr %control, i64 %deadline) {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  store i32 4, ptr %status_slot, align 4
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  store i64 %deadline, ptr %deadline_slot, align 8
  %head = load ptr, ptr @sollang_task_timer_head, align 8
  br label %scan

scan:
  %previous = phi ptr [ null, %entry ], [ %current, %advance ]
  %current = phi ptr [ %head, %entry ], [ %next, %advance ]
  %has_current = icmp ne ptr %current, null
  br i1 %has_current, label %compare, label %insert

compare:
  %current_deadline_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 8
  %current_deadline = load i64, ptr %current_deadline_slot, align 8
  %before_current = icmp slt i64 %deadline, %current_deadline
  br i1 %before_current, label %insert, label %advance

advance:
  %current_next_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 7
  %next = load ptr, ptr %current_next_slot, align 8
  br label %scan

insert:
  %control_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 7
  store ptr %current, ptr %control_next_slot, align 8
  %at_head = icmp eq ptr %previous, null
  br i1 %at_head, label %insert_head, label %insert_after

insert_head:
  store ptr %control, ptr @sollang_task_timer_head, align 8
  ret void

insert_after:
  %previous_next_slot = getelementptr %sollang.task_control, ptr %previous, i32 0, i32 7
  store ptr %control, ptr %previous_next_slot, align 8
  ret void
}

define internal void @sollang_timer_wake_due() {
entry:
  br label %scan

scan:
  %head = load ptr, ptr @sollang_task_timer_head, align 8
  %has_head = icmp ne ptr %head, null
  br i1 %has_head, label %check, label %done

check:
  %deadline_slot = getelementptr %sollang.task_control, ptr %head, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %due = icmp sge i64 %now, %deadline
  br i1 %due, label %wake, label %done

wake:
  %timer_next_slot = getelementptr %sollang.task_control, ptr %head, i32 0, i32 7
  %timer_next = load ptr, ptr %timer_next_slot, align 8
  store ptr %timer_next, ptr @sollang_task_timer_head, align 8
  store ptr null, ptr %timer_next_slot, align 8
  call void @sollang_task_enqueue_ready(ptr %head)
  br label %scan

done:
  ret void
}

define internal i1 @sollang_timer_wait_next() {
entry:
  %file_progress = call i1 @sollang_file_drain_completions()
  call void @sollang_timer_wake_due()
  %ready = load ptr, ptr @sollang_task_ready_head, align 8
  %has_ready = icmp ne ptr %ready, null
  br i1 %has_ready, label %progress, label %inspect_timer

inspect_timer:
  %timer = load ptr, ptr @sollang_task_timer_head, align 8
  %has_timer = icmp ne ptr %timer, null
  %file_outstanding = load atomic i64, ptr @sollang_io_outstanding acquire, align 8
  %has_file = icmp ne i64 %file_outstanding, 0
  br i1 %has_timer, label %timer_timeout, label %inspect_file

inspect_file:
  br i1 %has_file, label %wait_file_only, label %stalled

timer_timeout:
  %deadline_slot = getelementptr %sollang.task_control, ptr %timer, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %remaining_raw = sub i64 %deadline, %now
  %positive = icmp sgt i64 %remaining_raw, 0
  %remaining = select i1 %positive, i64 %remaining_raw, i64 0
  br i1 %has_file, label %wait_file_or_timer, label %wait_timer_only

wait_file_or_timer:
  call void @sollang_platform_io_wait_completion(i64 %remaining)
  %file_timer_progress = call i1 @sollang_file_drain_completions()
  call void @sollang_timer_wake_due()
  br label %progress

wait_file_only:
  call void @sollang_platform_io_wait_completion(i64 -1)
  %file_only_progress = call i1 @sollang_file_drain_completions()
  br label %progress

wait_timer_only:
  call void @sollang_wait_millis(i64 %remaining)
  call void @sollang_timer_wake_due()
  br label %progress

progress:
  ret i1 true

stalled:
  ret i1 false
}

define internal i1 @sollang_sleep_worker(ptr %control) {
entry:
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %ready = icmp sge i64 %now, %deadline
  br i1 %ready, label %complete, label %pending

complete:
  ret i1 true

pending:
  call void @sollang_timer_park(ptr %control, i64 %deadline)
  ret i1 false
}

define internal void @sollang_sleep_cancel(ptr %control) {
entry:
  %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %context_slot, align 8
  call void @free(ptr %context)
  ret void
}

define internal ptr @sollang_task_start(ptr %worker, ptr %destroy, ptr %cancel, ptr %context) {
entry:
  %control = call ptr @malloc(i64 168)
  %allocated = icmp ne ptr %control, null
  br i1 %allocated, label %initialize, label %fail

initialize:
  %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  store ptr %context, ptr %context_slot, align 8
  %resume_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 1
  store ptr %worker, ptr %resume_slot, align 8
  %destroy_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 2
  store ptr %destroy, ptr %destroy_slot, align 8
  %next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 3
  store ptr null, ptr %next_slot, align 8
  %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  store i32 0, ptr %status_slot, align 4
  %state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  store i32 0, ptr %state_slot, align 4
  %cancel_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 6
  store ptr %cancel, ptr %cancel_slot, align 8
  %timer_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 7
  store ptr null, ptr %timer_next_slot, align 8
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  store i64 0, ptr %deadline_slot, align 8
  %waiter_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 9
  store ptr null, ptr %waiter_slot, align 8
  %waiting_child_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 10
  store ptr null, ptr %waiting_child_slot, align 8
  %file_size_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 11
  store i32 0, ptr %file_size_slot, align 4
  %file_phase_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 12
  store i32 0, ptr %file_phase_slot, align 4
  %file_data_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 13
  store i64 0, ptr %file_data_slot, align 8
  %file_count_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 14
  store i64 0, ptr %file_count_slot, align 8
  %file_ok_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 15
  store i32 0, ptr %file_ok_slot, align 4
  %file_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 16
  store ptr null, ptr %file_next_slot, align 8
  %file_handle_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 17
  store i64 -1, ptr %file_handle_slot, align 8
  %file_offset_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 18
  store i64 0, ptr %file_offset_slot, align 8
  %file_explicit_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 19
  store i32 0, ptr %file_explicit_slot, align 4
  %file_operation_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 20
  store i32 0, ptr %file_operation_slot, align 4
  %result_address_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 21
  store ptr %context, ptr %result_address_slot, align 8
  %result_completion_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 22
  store ptr null, ptr %result_completion_slot, align 8
  %diagnostic_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %control, i32 0, i32 1
  store ptr null, ptr %diagnostic_header_slot, align 8
  call void @sollang_task_enqueue_ready(ptr %control)
  ret ptr %control

fail:
  ret ptr null
}

define internal i1 @sollang_task_join(ptr %handle) {
entry:
  br label %poll

poll:
  %target_status_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 4
  %target_status = load i32, ptr %target_status_slot, align 4
  %completed = icmp eq i32 %target_status, 2
  br i1 %completed, label %success, label %dequeue

dequeue:
  %ready = load ptr, ptr @sollang_task_ready_head, align 8
  %has_ready = icmp ne ptr %ready, null
  br i1 %has_ready, label %run, label %wait

wait:
  %timer_progress = call i1 @sollang_timer_wait_next()
  br i1 %timer_progress, label %poll, label %fail

run:
  %next_slot = getelementptr %sollang.task_control, ptr %ready, i32 0, i32 3
  %next = load ptr, ptr %next_slot, align 8
  store ptr %next, ptr @sollang_task_ready_head, align 8
  %became_empty = icmp eq ptr %next, null
  br i1 %became_empty, label %clear_tail, label %invoke

clear_tail:
  store ptr null, ptr @sollang_task_ready_tail, align 8
  br label %invoke

invoke:
  %ready_status_slot = getelementptr %sollang.task_control, ptr %ready, i32 0, i32 4
  store i32 1, ptr %ready_status_slot, align 4
  %resume_slot = getelementptr %sollang.task_control, ptr %ready, i32 0, i32 1
  %worker = load ptr, ptr %resume_slot, align 8
  %worker_complete = call i1 %worker(ptr %ready)
  br i1 %worker_complete, label %complete, label %requeue

complete:
  store i32 2, ptr %ready_status_slot, align 4
  call void @sollang_task_wake_waiter(ptr %ready)
  br label %poll

requeue:
  %pending_status = load i32, ptr %ready_status_slot, align 4
  %waiting = icmp uge i32 %pending_status, 4
  br i1 %waiting, label %poll, label %requeue_ready

requeue_ready:
  call void @sollang_task_enqueue_ready(ptr %ready)
  br label %poll

success:
  ret i1 true

fail:
  ret i1 false
}

define internal i1 @sollang_task_release(ptr %handle) {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 4
  %status = load i32, ptr %status_slot, align 4
  %completed = icmp eq i32 %status, 2
  br i1 %completed, label %destroy, label %fail

destroy:
  %destroy_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 2
  %destroy_fn = load ptr, ptr %destroy_slot, align 8
  %context_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 0
  %context = load ptr, ptr %context_slot, align 8
  %diagnostic_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %handle, i32 0, i32 1
  %diagnostic_header = load ptr, ptr %diagnostic_header_slot, align 8
  %diagnostic_present = icmp ne ptr %diagnostic_header, null
  br i1 %diagnostic_present, label %diagnostic_release, label %context_destroy
diagnostic_release:
  call void @sollang_diagnostic_release_header(ptr %diagnostic_header, i32 2)
  br label %context_destroy
context_destroy:
  call void %destroy_fn(ptr %context)
  call void @free(ptr %handle)
  ret i1 true

fail:
  ret i1 false
}

define internal i1 @sollang_task_cancel(ptr %handle) {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 4
  %status = load i32, ptr %status_slot, align 4
  %completed = icmp eq i32 %status, 2
  br i1 %completed, label %destroy, label %check_queued

check_queued:
  %queued = icmp eq i32 %status, 0
  br i1 %queued, label %ready_find, label %check_timer

check_timer:
  %waiting_timer = icmp eq i32 %status, 4
  br i1 %waiting_timer, label %timer_find, label %check_child

check_child:
  %waiting_child = icmp eq i32 %status, 5
  br i1 %waiting_child, label %detach_child, label %check_file

detach_child:
  %waiting_child_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 10
  %child = load ptr, ptr %waiting_child_slot, align 8
  %has_child = icmp ne ptr %child, null
  br i1 %has_child, label %clear_child_waiter, label %fail

clear_child_waiter:
  %child_waiter_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 9
  store ptr null, ptr %child_waiter_slot, align 8
  store ptr null, ptr %waiting_child_slot, align 8
  store i32 3, ptr %status_slot, align 4
  br label %destroy

check_file:
  %waiting_file = icmp eq i32 %status, 6
  br i1 %waiting_file, label %cancel_file, label %check_socket_completion

check_socket_completion:
  %waiting_socket_completion = icmp eq i32 %status, 7
  br i1 %waiting_socket_completion, label %cancel_socket_completion, label %fail

cancel_socket_completion:
  %socket_phase_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 12
  store atomic i32 3, ptr %socket_phase_slot release, align 4
  store i32 3, ptr %status_slot, align 4
  %socket_cancel_phase_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 19
  store atomic i32 1, ptr %socket_cancel_phase_slot release, align 4
  %socket_cancel_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 6
  %socket_cancel_fn = load ptr, ptr %socket_cancel_slot, align 8
  call void %socket_cancel_fn(ptr %handle)
  ret i1 true

cancel_file:
  %file_phase_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 12
  store atomic i32 3, ptr %file_phase_slot release, align 4
  store i32 3, ptr %status_slot, align 4
  ret i1 true

ready_find:
  %ready_head = load ptr, ptr @sollang_task_ready_head, align 8
  br label %ready_scan

ready_scan:
  %ready_previous = phi ptr [ null, %ready_find ], [ %ready_current, %ready_advance ]
  %ready_current = phi ptr [ %ready_head, %ready_find ], [ %ready_next, %ready_advance ]
  %ready_has_current = icmp ne ptr %ready_current, null
  br i1 %ready_has_current, label %ready_compare, label %fail

ready_compare:
  %ready_found = icmp eq ptr %ready_current, %handle
  br i1 %ready_found, label %ready_unlink, label %ready_advance

ready_advance:
  %ready_current_next_slot = getelementptr %sollang.task_control, ptr %ready_current, i32 0, i32 3
  %ready_next = load ptr, ptr %ready_current_next_slot, align 8
  br label %ready_scan

ready_unlink:
  %handle_ready_next_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 3
  %handle_ready_next = load ptr, ptr %handle_ready_next_slot, align 8
  %ready_is_head = icmp eq ptr %ready_previous, null
  br i1 %ready_is_head, label %ready_unlink_head, label %ready_unlink_after

ready_unlink_head:
  store ptr %handle_ready_next, ptr @sollang_task_ready_head, align 8
  br label %ready_repair_tail

ready_unlink_after:
  %ready_previous_next_slot = getelementptr %sollang.task_control, ptr %ready_previous, i32 0, i32 3
  store ptr %handle_ready_next, ptr %ready_previous_next_slot, align 8
  br label %ready_repair_tail

ready_repair_tail:
  %ready_tail = load ptr, ptr @sollang_task_ready_tail, align 8
  %ready_is_tail = icmp eq ptr %ready_tail, %handle
  br i1 %ready_is_tail, label %ready_replace_tail, label %mark_cancelled

ready_replace_tail:
  store ptr %ready_previous, ptr @sollang_task_ready_tail, align 8
  br label %mark_cancelled

timer_find:
  %timer_head = load ptr, ptr @sollang_task_timer_head, align 8
  br label %timer_scan

timer_scan:
  %timer_previous = phi ptr [ null, %timer_find ], [ %timer_current, %timer_advance ]
  %timer_current = phi ptr [ %timer_head, %timer_find ], [ %timer_next, %timer_advance ]
  %timer_has_current = icmp ne ptr %timer_current, null
  br i1 %timer_has_current, label %timer_compare, label %fail

timer_compare:
  %timer_found = icmp eq ptr %timer_current, %handle
  br i1 %timer_found, label %timer_unlink, label %timer_advance

timer_advance:
  %timer_current_next_slot = getelementptr %sollang.task_control, ptr %timer_current, i32 0, i32 7
  %timer_next = load ptr, ptr %timer_current_next_slot, align 8
  br label %timer_scan

timer_unlink:
  %handle_timer_next_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 7
  %handle_timer_next = load ptr, ptr %handle_timer_next_slot, align 8
  %timer_is_head = icmp eq ptr %timer_previous, null
  br i1 %timer_is_head, label %timer_unlink_head, label %timer_unlink_after

timer_unlink_head:
  store ptr %handle_timer_next, ptr @sollang_task_timer_head, align 8
  br label %mark_cancelled

timer_unlink_after:
  %timer_previous_next_slot = getelementptr %sollang.task_control, ptr %timer_previous, i32 0, i32 7
  store ptr %handle_timer_next, ptr %timer_previous_next_slot, align 8
  br label %mark_cancelled

mark_cancelled:
  store i32 3, ptr %status_slot, align 4
  br label %destroy

destroy:
  %cancel_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 6
  %cancel_fn = load ptr, ptr %cancel_slot, align 8
  %diagnostic_header_slot = getelementptr %sollang.diagnostic_task_control, ptr %handle, i32 0, i32 1
  %diagnostic_header = load ptr, ptr %diagnostic_header_slot, align 8
  %diagnostic_present = icmp ne ptr %diagnostic_header, null
  br i1 %diagnostic_present, label %diagnostic_release, label %context_cancel
diagnostic_release:
  %diagnostic_terminal = select i1 %completed, i32 2, i32 3
  call void @sollang_diagnostic_release_header(ptr %diagnostic_header, i32 %diagnostic_terminal)
  br label %context_cancel
context_cancel:
  call void %cancel_fn(ptr %handle)
  call void @free(ptr %handle)
  ret i1 true

fail:
  ret i1 false
}
define %sollang.source_text @sollang_runtime_map_text(%sollang.text %path) {
entry:
  %path_data = extractvalue %sollang.text %path, 0
  %path_length = extractvalue %sollang.text %path, 1
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %path_ok = call i32 @sollang_windows_utf8_path(ptr %path_data, i64 %path_length, ptr %buffer_ptr, i32 260)
  %valid = icmp ne i32 %path_ok, 0
  br i1 %valid, label %open, label %failure
open:
  %file = call ptr @CreateFileW(ptr %buffer_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 128, ptr null)
  %file_value = ptrtoint ptr %file to i64
  %opened = icmp ne i64 %file_value, -1
  br i1 %opened, label %size, label %failure
size:
  %size_slot = alloca i64, align 8
  %size_status = call i32 @GetFileSizeEx(ptr %file, ptr %size_slot)
  %size_ok = icmp ne i32 %size_status, 0
  br i1 %size_ok, label %size_known, label %close_failure
size_known:
  %length = load i64, ptr %size_slot, align 8
  %empty = icmp eq i64 %length, 0
  br i1 %empty, label %empty_success, label %mapping
empty_success:
  %empty_closed = call i32 @CloseHandle(ptr %file)
  ret %sollang.source_text zeroinitializer
mapping:
  %mapping_handle = call ptr @CreateFileMappingA(ptr %file, ptr null, i32 2, i32 0, i32 0, ptr null)
  %mapping_ok = icmp ne ptr %mapping_handle, null
  br i1 %mapping_ok, label %view, label %close_failure
view:
  %base = call ptr @MapViewOfFile(ptr %mapping_handle, i32 4, i32 0, i32 0, i64 %length)
  %base_ok = icmp ne ptr %base, null
  br i1 %base_ok, label %success, label %mapping_failure
success:
  %mapping_closed = call i32 @CloseHandle(ptr %mapping_handle)
  %file_closed = call i32 @CloseHandle(ptr %file)
  %result0 = insertvalue %sollang.source_text poison, ptr %base, 0
  %result1 = insertvalue %sollang.source_text %result0, i64 %length, 1
  %result2 = insertvalue %sollang.source_text %result1, ptr %base, 2
  %result3 = insertvalue %sollang.source_text %result2, i64 %length, 3
  ret %sollang.source_text %result3
mapping_failure:
  %failed_mapping_closed = call i32 @CloseHandle(ptr %mapping_handle)
  br label %close_failure
close_failure:
  %failed_file_closed = call i32 @CloseHandle(ptr %file)
  br label %failure
failure:
  call void @llvm.trap()
  unreachable
}

define void @sollang_runtime_unmap_text(%sollang.source_text %source) {
entry:
  %base = extractvalue %sollang.source_text %source, 2
  %owned = icmp ne ptr %base, null
  br i1 %owned, label %release, label %done
release:
  %length = extractvalue %sollang.source_text %source, 3
  %heap_owned = icmp eq i64 %length, -1
  br i1 %heap_owned, label %free_owned, label %unmap
free_owned:
  call void @free(ptr %base)
  br label %done
unmap:
  %ignored = call i32 @UnmapViewOfFile(ptr %base)
  br label %done
done:
  ret void
}
