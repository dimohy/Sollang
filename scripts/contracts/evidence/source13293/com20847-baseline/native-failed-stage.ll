; sollang workers = 1
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"
declare ptr @GetProcessHeap()
declare ptr @HeapAlloc(ptr, i32, i64)
declare i32 @HeapFree(ptr, i32, ptr)
define internal ptr @sollang_alloc(i64 %bytes) {
entry:
  %heap = call ptr @GetProcessHeap()
  %value = call ptr @HeapAlloc(ptr %heap, i32 0, i64 %bytes)
  ret ptr %value
}
define internal void @sollang_free(ptr %value) {
entry:
  %is_null = icmp eq ptr %value, null
  br i1 %is_null, label %done, label %release
release:
  %heap = call ptr @GetProcessHeap()
  %ignored = call i32 @HeapFree(ptr %heap, i32 0, ptr %value)
  br label %done
done:
  ret void
}
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1 immarg)
declare ptr @GetStdHandle(i32)
declare i32 @GetConsoleMode(ptr, ptr)
declare i32 @WriteConsoleW(ptr, ptr, i32, ptr, ptr)
declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare i32 @MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)
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
declare dllimport ptr @CreateFileA(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport i32 @CloseHandle(ptr)
declare dllimport i32 @CoInitializeEx(ptr, i32)
declare dllimport void @CoUninitialize()
declare dllimport i32 @CoCreateInstance(ptr, ptr, i32, ptr, ptr)
declare dllimport ptr @LoadLibraryA(ptr)
declare dllimport ptr @GetProcAddress(ptr, ptr)
declare dllimport i32 @FreeLibrary(ptr)
@sollang_com_dll_get_class_object_name = private unnamed_addr constant [18 x i8] c"DllGetClassObject\00"
@sollang_com_iid_class_factory = private constant { i32, i16, i16, [8 x i8] } { i32 1, i16 0, i16 0, [8 x i8] [i8 192, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 70] }
define internal ptr @sollang_com_vtable_target(ptr %instance, i64 %slot) {
entry:
  %vtable = load ptr, ptr %instance, align 8
  %slot_address = getelementptr ptr, ptr %vtable, i64 %slot
  %target = load ptr, ptr %slot_address, align 8
  ret ptr %target
}
define internal void @sollang_com_require_status(i32 %status) {
entry:
  %ok = icmp sge i32 %status, 0
  br i1 %ok, label %done, label %fail
fail:
  call void @llvm.trap()
  unreachable
done:
  ret void
}
define internal void @sollang_com_require_pointer(ptr %value) {
entry:
  %ok = icmp ne ptr %value, null
  br i1 %ok, label %done, label %fail
fail:
  call void @llvm.trap()
  unreachable
done:
  ret void
}
define internal ptr @sollang_com_clone(ptr %instance) {
entry:
  %add_ref = call ptr @sollang_com_vtable_target(ptr %instance, i64 1)
  %references = call i32 %add_ref(ptr %instance)
  ret ptr %instance
}
define internal { ptr, i32 } @sollang_com_query(ptr %instance, ptr %iid) {
entry:
  %output = alloca ptr, align 8
  store ptr null, ptr %output, align 8
  %query = call ptr @sollang_com_vtable_target(ptr %instance, i64 0)
  %status = call i32 %query(ptr %instance, ptr %iid, ptr %output)
  %value = load ptr, ptr %output, align 8
  %status_ok = icmp sge i32 %status, 0
  %value_ok = icmp ne ptr %value, null
  %ok = and i1 %status_ok, %value_ok
  br i1 %ok, label %done, label %failure
failure:
  br i1 %value_ok, label %release_failure, label %failed
release_failure:
  call void @sollang_com_release(ptr %value)
  br label %failed
failed:
  %effective_status = select i1 %status_ok, i32 -2147467261, i32 %status
  br label %done
done:
  %result_pointer = phi ptr [ %value, %entry ], [ null, %failed ]
  %result_status = phi i32 [ %status, %entry ], [ %effective_status, %failed ]
  %with_instance = insertvalue { ptr, i32 } poison, ptr %result_pointer, 0
  %result = insertvalue { ptr, i32 } %with_instance, i32 %result_status, 1
  ret { ptr, i32 } %result
}
define internal void @sollang_com_release(ptr %instance) {
entry:
  %present = icmp ne ptr %instance, null
  br i1 %present, label %release, label %done
release:
  %target = call ptr @sollang_com_vtable_target(ptr %instance, i64 2)
  %references = call i32 %target(ptr %instance)
  br label %done
done:
  ret void
}
define internal { ptr, i32 } @sollang_com_activate_registered(ptr %clsid, ptr %iid) {
entry:
  %output = alloca ptr, align 8
  store ptr null, ptr %output, align 8
  %status = call i32 @CoCreateInstance(ptr %clsid, ptr null, i32 1, ptr %iid, ptr %output)
  %instance = load ptr, ptr %output, align 8
  %with_instance = insertvalue { ptr, i32 } poison, ptr %instance, 0
  %result = insertvalue { ptr, i32 } %with_instance, i32 %status, 1
  ret { ptr, i32 } %result
}
define internal { ptr, i32 } @sollang_com_activate_factory(ptr %factory, ptr %iid) {
entry:
  %output = alloca ptr, align 8
  store ptr null, ptr %output, align 8
  %create = call ptr @sollang_com_vtable_target(ptr %factory, i64 3)
  %status = call i32 %create(ptr %factory, ptr null, ptr %iid, ptr %output)
  %instance = load ptr, ptr %output, align 8
  %with_instance = insertvalue { ptr, i32 } poison, ptr %instance, 0
  %result = insertvalue { ptr, i32 } %with_instance, i32 %status, 1
  ret { ptr, i32 } %result
}
define internal { ptr, ptr, i32 } @sollang_com_bind_factory(ptr %server_name, ptr %clsid) {
entry:
  %server = call ptr @LoadLibraryA(ptr %server_name)
  %server_ok = icmp ne ptr %server, null
  br i1 %server_ok, label %symbol, label %server_failed
symbol:
  %get_class_object = call ptr @GetProcAddress(ptr %server, ptr @sollang_com_dll_get_class_object_name)
  %symbol_ok = icmp ne ptr %get_class_object, null
  br i1 %symbol_ok, label %factory, label %symbol_failed
factory:
  %output = alloca ptr, align 8
  store ptr null, ptr %output, align 8
  %status = call i32 %get_class_object(ptr %clsid, ptr @sollang_com_iid_class_factory, ptr %output)
  %value = load ptr, ptr %output, align 8
  %status_ok = icmp sge i32 %status, 0
  %value_ok = icmp ne ptr %value, null
  %ready = and i1 %status_ok, %value_ok
  br i1 %ready, label %done, label %factory_failed
server_failed:
  %server_failure0 = insertvalue { ptr, ptr, i32 } zeroinitializer, i32 -2147467259, 2
  ret { ptr, ptr, i32 } %server_failure0
symbol_failed:
  %closed_symbol = call i32 @FreeLibrary(ptr %server)
  %symbol_failure0 = insertvalue { ptr, ptr, i32 } zeroinitializer, i32 -2147467259, 2
  ret { ptr, ptr, i32 } %symbol_failure0
factory_failed:
  %closed_factory = call i32 @FreeLibrary(ptr %server)
  %factory_failure0 = insertvalue { ptr, ptr, i32 } zeroinitializer, i32 %status, 2
  ret { ptr, ptr, i32 } %factory_failure0
done:
  %with_server = insertvalue { ptr, ptr, i32 } poison, ptr %server, 0
  %with_factory = insertvalue { ptr, ptr, i32 } %with_server, ptr %value, 1
  %result = insertvalue { ptr, ptr, i32 } %with_factory, i32 %status, 2
  ret { ptr, ptr, i32 } %result
}
@sollang_bool_true_bytes = private constant [4 x i8] c"true"
@sollang_bool_false_bytes = private constant [5 x i8] c"false"
%sollang.source_text = type { ptr, i64, ptr, i64 }
%sollang.text = type { ptr, i64 }
%sollang.stream = type { ptr, ptr, ptr }
%sollang.event_stream = type { ptr, ptr, ptr }
%sollang.enum.t27 = type { i32, [1 x i64] }
%sollang.enum.t34 = type { i32, [0 x i64] }
%sollang.enum.t45 = type { i32, [0 x i64] }
%sollang.enum.t57 = type { i32, [0 x i64] }
%sollang.enum.t60 = type { i32, [0 x i64] }
%sollang.enum.t80 = type { i32, [1 x i64] }
%sollang.enum.t87 = type { i32, [1 x i64] }
%sollang.enum.t90 = type { i32, [1 x i64] }
%sollang.enum.t101 = type { i32, [0 x i64] }
%sollang.enum.t102 = type { i32, [0 x i64] }
%sollang.enum.t108 = type { i32, [3 x i64] }
%sollang.enum.t115 = type { i32, [1 x i64] }
%sollang.enum.t117 = type { i32, [4 x i64] }
%sollang.enum.t118 = type { i32, [4 x i64] }
%sollang.enum.t119 = type { i32, [2 x i64] }
%sollang.enum.t120 = type { i32, [8 x i64] }
%sollang.enum.t121 = type { i32, [2 x i64] }
%sollang.enum.t122 = type { i32, [4 x i64] }
%sollang.enum.t123 = type { i32, [2 x i64] }
%sollang.enum.t124 = type { i32, [2 x i64] }
%sollang.enum.t126 = type { i32, [3 x i64] }
%sollang.enum.t127 = type { i32, [0 x i64] }
%sollang.enum.t133 = type { i32, [2 x i64] }
%sollang.enum.t134 = type { i32, [3 x i64] }
%sollang.enum.t139 = type { i32, [0 x i64] }
%sollang.enum.t141 = type { i32, [4 x i64] }
%sollang.enum.t142 = type { i32, [2 x i64] }
%sollang.enum.t143 = type { i32, [2 x i64] }
%sollang.enum.t145 = type { i32, [2 x i64] }
%sollang.enum.t146 = type { i32, [4 x i64] }
%sollang.enum.t147 = type { i32, [0 x i64] }
%sollang.enum.t148 = type { i32, [0 x i64] }
%sollang.enum.t152 = type { i32, [0 x i64] }
%sollang.enum.t155 = type { i32, [3 x i64] }
%sollang.enum.t156 = type { i32, [12 x i64] }
%sollang.enum.t157 = type { i32, [3 x i64] }
%sollang.enum.t158 = type { i32, [4 x i64] }
%sollang.enum.t175 = type { i32, [0 x i64] }
%sollang.enum.t176 = type { i32, [0 x i64] }
%sollang.enum.t178 = type { i32, [0 x i64] }
%sollang.enum.t190 = type { i32, [1 x i64] }
%sollang.enum.t191 = type { i32, [1 x i64] }
%sollang.enum.t192 = type { i32, [2 x i64] }
%sollang.enum.t193 = type { i32, [2 x i64] }
%sollang.enum.t194 = type { i32, [2 x i64] }
%sollang.enum.t195 = type { i32, [6 x i64] }
%sollang.enum.t196 = type { i32, [1 x i64] }
%sollang.enum.t197 = type { i32, [1 x i64] }
%sollang.enum.t198 = type { i32, [1 x i64] }
%sollang.enum.t199 = type { i32, [1 x i64] }
%sollang.enum.t200 = type { i32, [11 x i64] }
%sollang.enum.t201 = type { i32, [0 x i64] }
%sollang.enum.t203 = type { i32, [3 x i64] }
%sollang.enum.t204 = type { i32, [1 x i64] }
%sollang.enum.t206 = type { i32, [12 x i64] }
%sollang.enum.t210 = type { i32, [29 x i64] }
%sollang.enum.t211 = type { i32, [12 x i64] }
%sollang.enum.t212 = type { i32, [2 x i64] }
%sollang.enum.t214 = type { i32, [2 x i64] }
%sollang.enum.t216 = type { i32, [3 x i64] }
%sollang.enum.t217 = type { i32, [0 x i64] }
%sollang.enum.t223 = type { i32, [0 x i64] }
%sollang.enum.t225 = type { i32, [2 x i64] }
%sollang.enum.t226 = type { i32, [1 x i64] }
%sollang.enum.t227 = type { i32, [1 x i64] }
%sollang.enum.t229 = type { i32, [0 x i64] }
%sollang.enum.t232 = type { i32, [4 x i64] }
%sollang.enum.t233 = type { i32, [3 x i64] }
%sollang.enum.t238 = type { i32, [2 x i64] }
%sollang.enum.t248 = type { i32, [2 x i64] }
%sollang.enum.t249 = type { i32, [2 x i64] }
%sollang.enum.t250 = type { i32, [2 x i64] }
%sollang.enum.t251 = type { i32, [7 x i64] }
%sollang.enum.t252 = type { i32, [7 x i64] }
%sollang.enum.t253 = type { i32, [0 x i64] }
%sollang.enum.t254 = type { i32, [0 x i64] }
%sollang.enum.t255 = type { i32, [2 x i64] }
%sollang.enum.t256 = type { i32, [2 x i64] }
%sollang.enum.t259 = type { i32, [7 x i64] }
%sollang.enum.t260 = type { i32, [4 x i64] }
%sollang.enum.t261 = type { i32, [2 x i64] }
%sollang.enum.t265 = type { i32, [2 x i64] }
%sollang.enum.t266 = type { i32, [2 x i64] }
%sollang.enum.t272 = type { i32, [2 x i64] }
%sollang.enum.t277 = type { i32, [1 x i64] }
%sollang.enum.t278 = type { i32, [0 x i64] }
%sollang.enum.t280 = type { i32, [0 x i64] }
%sollang.enum.t286 = type { i32, [0 x i64] }
%sollang.enum.t292 = type { i32, [3 x i64] }
%sollang.enum.t293 = type { i32, [44 x i64] }
%sollang.enum.t294 = type { i32, [2 x i64] }
%sollang.enum.t295 = type { i32, [13 x i64] }
%sollang.enum.t296 = type { i32, [2 x i64] }
%sollang.enum.t297 = type { i32, [0 x i64] }
%sollang.enum.t298 = type { i32, [0 x i64] }
%sollang.enum.t301 = type { i32, [0 x i64] }
%sollang.enum.t303 = type { i32, [0 x i64] }
%sollang.enum.t305 = type { i32, [0 x i64] }
%sollang.enum.t310 = type { i32, [1 x i64] }
%sollang.enum.t311 = type { i32, [7 x i64] }
%sollang.enum.t312 = type { i32, [1 x i64] }
%sollang.enum.t315 = type { i32, [3 x i64] }
%sollang.enum.t318 = type { i32, [1 x i64] }
%sollang.enum.t319 = type { i32, [0 x i64] }
%sollang.enum.t321 = type { i32, [0 x i64] }
%sollang.enum.t330 = type { i32, [0 x i64] }
%sollang.enum.t331 = type { i32, [0 x i64] }
%sollang.enum.t338 = type { i32, [3 x i64] }
%sollang.enum.t339 = type { i32, [4 x i64] }
%sollang.enum.t340 = type { i32, [105 x i64] }
%sollang.enum.t341 = type { i32, [2 x i64] }
%sollang.enum.t342 = type { i32, [9 x i64] }
%sollang.enum.t343 = type { i32, [26 x i64] }
%sollang.enum.t344 = type { i32, [81 x i64] }
%sollang.enum.t345 = type { i32, [2 x i64] }
%sollang.enum.t348 = type { i32, [3 x i64] }
%sollang.enum.t349 = type { i32, [0 x i64] }
%sollang.enum.t353 = type { i32, [0 x i64] }
%sollang.enum.t374 = type { i32, [2 x i64] }
%sollang.enum.t375 = type { i32, [4 x i64] }
%sollang.enum.t376 = type { i32, [4 x i64] }
%sollang.enum.t377 = type { i32, [72 x i64] }
%sollang.enum.t378 = type { i32, [2 x i64] }
%sollang.enum.t379 = type { i32, [2 x i64] }
%sollang.enum.t380 = type { i32, [2 x i64] }
%sollang.enum.t381 = type { i32, [13 x i64] }
%sollang.enum.t382 = type { i32, [26 x i64] }
%sollang.enum.t383 = type { i32, [5 x i64] }
%sollang.enum.t384 = type { i32, [2 x i64] }
%sollang.enum.t388 = type { i32, [2 x i64] }
%sollang.enum.t389 = type { i32, [72 x i64] }
%sollang.enum.t390 = type { i32, [3 x i64] }
%sollang.enum.t391 = type { i32, [0 x i64] }
%sollang.enum.t397 = type { i32, [0 x i64] }
%sollang.enum.t403 = type { i32, [3 x i64] }
%sollang.enum.t404 = type { i32, [13 x i64] }
%sollang.enum.t405 = type { i32, [70 x i64] }
%sollang.enum.t406 = type { i32, [2 x i64] }
%sollang.enum.t407 = type { i32, [40 x i64] }
%sollang.enum.t411 = type { i32, [3 x i64] }
%sollang.enum.t417 = type { i32, [3 x i64] }
%sollang.enum.t419 = type { i32, [0 x i64] }
%sollang.enum.t422 = type { i32, [0 x i64] }
%sollang.enum.t428 = type { i32, [8 x i64] }
%sollang.enum.t429 = type { i32, [1 x i64] }
%sollang.enum.t430 = type { i32, [2 x i64] }
%sollang.enum.t431 = type { i32, [2 x i64] }
%sollang.enum.t432 = type { i32, [2 x i64] }
%sollang.enum.t438 = type { i32, [3 x i64] }
%sollang.enum.t444 = type { i32, [0 x i64] }
%sollang.enum.t445 = type { i32, [0 x i64] }
%sollang.enum.t446 = type { i32, [0 x i64] }
%sollang.enum.t454 = type { i32, [2 x i64] }
%sollang.enum.t455 = type { i32, [2 x i64] }
%sollang.enum.t456 = type { i32, [2 x i64] }
%sollang.enum.t457 = type { i32, [5 x i64] }
%sollang.enum.t458 = type { i32, [11 x i64] }
%sollang.enum.t459 = type { i32, [9 x i64] }
%sollang.enum.t461 = type { i32, [3 x i64] }
%sollang.enum.t462 = type { i32, [0 x i64] }
%sollang.enum.t463 = type { i32, [0 x i64] }
%sollang.enum.t467 = type { i32, [2 x i64] }
%sollang.enum.t468 = type { i32, [2 x i64] }
%sollang.enum.t469 = type { i32, [2 x i64] }
%sollang.enum.t470 = type { i32, [2 x i64] }
%sollang.enum.t471 = type { i32, [2 x i64] }
%sollang.enum.t472 = type { i32, [0 x i64] }
%sollang.enum.t479 = type { i32, [2 x i64] }
%sollang.enum.t480 = type { i32, [2 x i64] }
%sollang.enum.t481 = type { i32, [2 x i64] }
%sollang.enum.t482 = type { i32, [3 x i64] }
%sollang.enum.t483 = type { i32, [4 x i64] }
%sollang.enum.t484 = type { i32, [2 x i64] }
%sollang.enum.t485 = type { i32, [3 x i64] }
%sollang.enum.t486 = type { i32, [0 x i64] }
%sollang.enum.t488 = type { i32, [2 x i64] }
%sollang.enum.t499 = type { i32, [5 x i64] }
%sollang.enum.t500 = type { i32, [10 x i64] }
%sollang.enum.t501 = type { i32, [10 x i64] }
%sollang.enum.t502 = type { i32, [11 x i64] }
%sollang.enum.t503 = type { i32, [11 x i64] }
%sollang.enum.t512 = type { i32, [8 x i64] }
%sollang.enum.t513 = type { i32, [8 x i64] }
%sollang.enum.t514 = type { i32, [2 x i64] }
%sollang.enum.t524 = type { i32, [16 x i64] }
%sollang.enum.t526 = type { i32, [7 x i64] }
%sollang.enum.t527 = type { i32, [7 x i64] }
%sollang.enum.t528 = type { i32, [3 x i64] }
%sollang.enum.t529 = type { i32, [0 x i64] }
%sollang.enum.t530 = type { i32, [0 x i64] }
%sollang.enum.t533 = type { i32, [0 x i64] }
%sollang.enum.t536 = type { i32, [0 x i64] }
%sollang.enum.t544 = type { i32, [3 x i64] }
%sollang.enum.t545 = type { i32, [3 x i64] }
%sollang.enum.t546 = type { i32, [13 x i64] }
%sollang.enum.t547 = type { i32, [12 x i64] }
%sollang.enum.t548 = type { i32, [4 x i64] }
%sollang.enum.t549 = type { i32, [2 x i64] }
%sollang.enum.t550 = type { i32, [2 x i64] }
%sollang.enum.t551 = type { i32, [2 x i64] }
%sollang.enum.t552 = type { i32, [0 x i64] }
%sollang.enum.t595 = type { i32, [7 x i64] }
%sollang.enum.t609 = type { i32, [2 x i64] }
%sollang.enum.t610 = type { i32, [2 x i64] }
%sollang.enum.t611 = type { i32, [9 x i64] }
%sollang.enum.t612 = type { i32, [21 x i64] }
%sollang.enum.t613 = type { i32, [4 x i64] }
%sollang.enum.t614 = type { i32, [9 x i64] }
%sollang.enum.t615 = type { i32, [2 x i64] }
%sollang.enum.t616 = type { i32, [5 x i64] }
%sollang.enum.t617 = type { i32, [2 x i64] }
%sollang.enum.t618 = type { i32, [14 x i64] }
%sollang.enum.t620 = type { i32, [11 x i64] }
%sollang.enum.t621 = type { i32, [16 x i64] }
%sollang.enum.t622 = type { i32, [7 x i64] }
%sollang.enum.t625 = type { i32, [7 x i64] }
%sollang.enum.t626 = type { i32, [4 x i64] }
%sollang.enum.t627 = type { i32, [6 x i64] }
%sollang.enum.t628 = type { i32, [7 x i64] }
%sollang.enum.t629 = type { i32, [6 x i64] }
%sollang.enum.t630 = type { i32, [5 x i64] }
%sollang.enum.t631 = type { i32, [2 x i64] }
%sollang.enum.t632 = type { i32, [4 x i64] }
%sollang.enum.t633 = type { i32, [10 x i64] }
%sollang.enum.t634 = type { i32, [131 x i64] }
%sollang.enum.t635 = type { i32, [2 x i64] }
%sollang.enum.t636 = type { i32, [16 x i64] }
%sollang.enum.t637 = type { i32, [7 x i64] }
%sollang.enum.t638 = type { i32, [10 x i64] }
%sollang.enum.t640 = type { i32, [5 x i64] }
%sollang.enum.t642 = type { i32, [2 x i64] }
%sollang.enum.t643 = type { i32, [17 x i64] }
%sollang.enum.t644 = type { i32, [2 x i64] }
%sollang.enum.t645 = type { i32, [2 x i64] }
%sollang.enum.t646 = type { i32, [3 x i64] }
%sollang.enum.t649 = type { i32, [1 x i64] }
%sollang.enum.t650 = type { i32, [0 x i64] }
%sollang.enum.t651 = type { i32, [0 x i64] }
%sollang.enum.t652 = type { i32, [0 x i64] }
%sollang.enum.t655 = type { i32, [0 x i64] }
%sollang.enum.t664 = type { i32, [2 x i64] }
%sollang.enum.t665 = type { i32, [3 x i64] }
%sollang.enum.t666 = type { i32, [17 x i64] }
%sollang.enum.t668 = type { i32, [2 x i64] }
%sollang.enum.t669 = type { i32, [2 x i64] }
%sollang.enum.t677 = type { i32, [0 x i64] }
%sollang.enum.t678 = type { i32, [0 x i64] }
%sollang.enum.t687 = type { i32, [12 x i64] }
%sollang.enum.t688 = type { i32, [4 x i64] }
%sollang.enum.t689 = type { i32, [3 x i64] }
%sollang.enum.t690 = type { i32, [3 x i64] }
%sollang.enum.t691 = type { i32, [4 x i64] }
%sollang.enum.t692 = type { i32, [2 x i64] }
%sollang.enum.t694 = type { i32, [3 x i64] }
%sollang.enum.t695 = type { i32, [0 x i64] }
%sollang.enum.t699 = type { i32, [6 x i64] }
%sollang.enum.t700 = type { i32, [3 x i64] }
%sollang.enum.t701 = type { i32, [0 x i64] }
%sollang.enum.t702 = type { i32, [0 x i64] }
%sollang.enum.t703 = type { i32, [0 x i64] }
%sollang.enum.t715 = type { i32, [2 x i64] }
%sollang.enum.t716 = type { i32, [2 x i64] }
%sollang.enum.t717 = type { i32, [2 x i64] }
%sollang.enum.t718 = type { i32, [2 x i64] }
%sollang.enum.t719 = type { i32, [2 x i64] }
%sollang.enum.t720 = type { i32, [12 x i64] }
%sollang.enum.t721 = type { i32, [6 x i64] }
%sollang.enum.t722 = type { i32, [3 x i64] }
%sollang.enum.t723 = type { i32, [2 x i64] }
%sollang.enum.t724 = type { i32, [8 x i64] }
%sollang.enum.t726 = type { i32, [2 x i64] }
%sollang.enum.t727 = type { i32, [4 x i64] }
%sollang.enum.t730 = type { i32, [3 x i64] }
%sollang.enum.t731 = type { i32, [0 x i64] }
%sollang.enum.t732 = type { i32, [0 x i64] }
%sollang.enum.t733 = type { i32, [0 x i64] }
%sollang.enum.t741 = type { i32, [4 x i64] }
%sollang.enum.t742 = type { i32, [4 x i64] }
%sollang.enum.t743 = type { i32, [7 x i64] }
%sollang.enum.t744 = type { i32, [4 x i64] }
%sollang.enum.t746 = type { i32, [9 x i64] }
%sollang.enum.t747 = type { i32, [2 x i64] }
%sollang.enum.t748 = type { i32, [4 x i64] }
%sollang.enum.t749 = type { i32, [0 x i64] }
%sollang.enum.t750 = type { i32, [0 x i64] }
%sollang.enum.t754 = type { i32, [2 x i64] }
%sollang.enum.t755 = type { i32, [3 x i64] }
%sollang.enum.t756 = type { i32, [0 x i64] }
%sollang.enum.t757 = type { i32, [0 x i64] }
%sollang.enum.t758 = type { i32, [0 x i64] }
%sollang.enum.t761 = type { i32, [2 x i64] }
%sollang.enum.t764 = type { i32, [3 x i64] }
%sollang.enum.t775 = type { i32, [0 x i64] }
%sollang.enum.t776 = type { i32, [3 x i64] }
%sollang.enum.t777 = type { i32, [6 x i64] }
%sollang.enum.t778 = type { i32, [1 x i64] }
%sollang.enum.t779 = type { i32, [2 x i64] }
%sollang.enum.t780 = type { i32, [3 x i64] }
%sollang.enum.t781 = type { i32, [8 x i64] }
%sollang.enum.t782 = type { i32, [2 x i64] }
%sollang.enum.t783 = type { i32, [1 x i64] }
%sollang.enum.t784 = type { i32, [2 x i64] }
%sollang.enum.t785 = type { i32, [3 x i64] }
%sollang.enum.t786 = type { i32, [2 x i64] }
%sollang.enum.t788 = type { i32, [16 x i64] }
%sollang.enum.t789 = type { i32, [0 x i64] }
%sollang.enum.t790 = type { i32, [0 x i64] }
%sollang.enum.t791 = type { i32, [2 x i64] }
%sollang.enum.t792 = type { i32, [4 x i64] }
%sollang.enum.t793 = type { i32, [3 x i64] }
%sollang.enum.t794 = type { i32, [18 x i64] }
%sollang.enum.t795 = type { i32, [3 x i64] }
%sollang.enum.t796 = type { i32, [16 x i64] }
%sollang.enum.t797 = type { i32, [2 x i64] }
%sollang.enum.t798 = type { i32, [2 x i64] }
%sollang.enum.t799 = type { i32, [2 x i64] }
%sollang.enum.t801 = type { i32, [1 x i64] }
%sollang.enum.t802 = type { i32, [2 x i64] }
%sollang.enum.t803 = type { i32, [2 x i64] }
%sollang.enum.t804 = type { i32, [5 x i64] }
%sollang.enum.t805 = type { i32, [2 x i64] }
%sollang.enum.t808 = type { i32, [9 x i64] }
%sollang.enum.t809 = type { i32, [7 x i64] }
%sollang.enum.t810 = type { i32, [3 x i64] }
%sollang.enum.t811 = type { i32, [2 x i64] }
%sollang.enum.t813 = type { i32, [0 x i64] }
%sollang.enum.t819 = type { i32, [1 x i64] }
%sollang.enum.t821 = type { i32, [0 x i64] }
%sollang.enum.t822 = type { i32, [0 x i64] }
%sollang.enum.t824 = type { i32, [1 x i64] }
%sollang.enum.t825 = type { i32, [1 x i64] }
%sollang.enum.t828 = type { i32, [26 x i64] }
%sollang.enum.t829 = type { i32, [4 x i64] }
%sollang.enum.t830 = type { i32, [2 x i64] }
%sollang.enum.t831 = type { i32, [2 x i64] }
%sollang.enum.t832 = type { i32, [2 x i64] }
%sollang.enum.t833 = type { i32, [50 x i64] }
%sollang.enum.t834 = type { i32, [2 x i64] }
%sollang.enum.t835 = type { i32, [3 x i64] }
%sollang.enum.t836 = type { i32, [2 x i64] }
%sollang.enum.t837 = type { i32, [2 x i64] }
%sollang.enum.t839 = type { i32, [2 x i64] }
%sollang.enum.t840 = type { i32, [2 x i64] }
%sollang.enum.t845 = type { i32, [0 x i64] }
%sollang.enum.t846 = type { i32, [0 x i64] }
%sollang.enum.t848 = type { i32, [0 x i64] }
%sollang.enum.t849 = type { i32, [4 x i64] }
%sollang.enum.t851 = type { i32, [0 x i64] }
%sollang.enum.t854 = type { i32, [0 x i64] }
%sollang.enum.t857 = type { i32, [0 x i64] }
%sollang.enum.t861 = type { i32, [1 x i64] }
%sollang.enum.t864 = type { i32, [1 x i64] }
%sollang.enum.t866 = type { i32, [1 x i64] }
%sollang.enum.t868 = type { i32, [1 x i64] }
%sollang.enum.t870 = type { i32, [5 x i64] }
%sollang.enum.t871 = type { i32, [1 x i64] }
%sollang.enum.t872 = type { i32, [0 x i64] }
%sollang.enum.t873 = type { i32, [0 x i64] }
%sollang.enum.t874 = type { i32, [0 x i64] }
%sollang.enum.t883 = type { i32, [9 x i64] }
%sollang.enum.t884 = type { i32, [24 x i64] }
%sollang.enum.t885 = type { i32, [2 x i64] }
%sollang.enum.t886 = type { i32, [12 x i64] }
%sollang.enum.t887 = type { i32, [11 x i64] }
%sollang.enum.t888 = type { i32, [2 x i64] }
%sollang.enum.t889 = type { i32, [32 x i64] }
%sollang.enum.t890 = type { i32, [34 x i64] }
%sollang.enum.t891 = type { i32, [2 x i64] }
%sollang.enum.t892 = type { i32, [9 x i64] }
%sollang.enum.t893 = type { i32, [31 x i64] }
%sollang.enum.t894 = type { i32, [2 x i64] }
%sollang.enum.t895 = type { i32, [15 x i64] }
%sollang.enum.t896 = type { i32, [34 x i64] }
%sollang.enum.t897 = type { i32, [2 x i64] }
%sollang.enum.t898 = type { i32, [2 x i64] }
%sollang.enum.t899 = type { i32, [6 x i64] }
%sollang.enum.t900 = type { i32, [2 x i64] }
%sollang.enum.t901 = type { i32, [2 x i64] }
%sollang.enum.t902 = type { i32, [2 x i64] }
%sollang.enum.t904 = type { i32, [14 x i64] }
%sollang.enum.t905 = type { i32, [9 x i64] }
%sollang.enum.t906 = type { i32, [5 x i64] }
%sollang.enum.t907 = type { i32, [5 x i64] }
%sollang.enum.t908 = type { i32, [4 x i64] }
%sollang.enum.t909 = type { i32, [2 x i64] }
%sollang.enum.t911 = type { i32, [2 x i64] }
%sollang.enum.t916 = type { i32, [66 x i64] }
%sollang.enum.t917 = type { i32, [1 x i64] }
%sollang.enum.t919 = type { i32, [1 x i64] }
%sollang.enum.t920 = type { i32, [2 x i64] }
%sollang.enum.t921 = type { i32, [81 x i64] }
%sollang.enum.t922 = type { i32, [2 x i64] }
%sollang.enum.t923 = type { i32, [3 x i64] }
%sollang.enum.t924 = type { i32, [0 x i64] }
%sollang.enum.t925 = type { i32, [4 x i64] }
%sollang.enum.t928 = type { i32, [1 x i64] }
%sollang.enum.t930 = type { i32, [1 x i64] }
%sollang.enum.t932 = type { i32, [3 x i64] }
%sollang.enum.t933 = type { i32, [5 x i64] }
%sollang.enum.t934 = type { i32, [2 x i64] }
%sollang.enum.t935 = type { i32, [14 x i64] }
%sollang.enum.t936 = type { i32, [2 x i64] }
%sollang.enum.t937 = type { i32, [32 x i64] }
%sollang.enum.t938 = type { i32, [4 x i64] }
%sollang.enum.t939 = type { i32, [2 x i64] }
%sollang.enum.t941 = type { i32, [5 x i64] }
%sollang.enum.t942 = type { i32, [2 x i64] }
%sollang.enum.t944 = type { i32, [0 x i64] }
%sollang.enum.t945 = type { i32, [0 x i64] }
%sollang.enum.t947 = type { i32, [4 x i64] }
%sollang.enum.t950 = type { i32, [1 x i64] }
%sollang.enum.t951 = type { i32, [1 x i64] }
%sollang.enum.t953 = type { i32, [2 x i64] }
%sollang.enum.t954 = type { i32, [5 x i64] }
%sollang.enum.t955 = type { i32, [2 x i64] }
%sollang.enum.t956 = type { i32, [2 x i64] }
%sollang.enum.t957 = type { i32, [32 x i64] }
%sollang.enum.t958 = type { i32, [2 x i64] }
%sollang.enum.t959 = type { i32, [4 x i64] }
%sollang.enum.t961 = type { i32, [2 x i64] }
%sollang.enum.t964 = type { i32, [1 x i64] }
%sollang.enum.t968 = type { i32, [2 x i64] }
%sollang.enum.t969 = type { i32, [4 x i64] }
%sollang.enum.t970 = type { i32, [2 x i64] }
%sollang.enum.t971 = type { i32, [2 x i64] }
%sollang.enum.t972 = type { i32, [2 x i64] }
%sollang.enum.t973 = type { i32, [2 x i64] }
%sollang.enum.t974 = type { i32, [2 x i64] }
%sollang.enum.t975 = type { i32, [0 x i64] }
%sollang.enum.t979 = type { i32, [2 x i64] }
%sollang.enum.t980 = type { i32, [3 x i64] }
%sollang.enum.t981 = type { i32, [2 x i64] }
%sollang.enum.t983 = type { i32, [1 x i64] }
%sollang.enum.t986 = type { i32, [3 x i64] }
%sollang.enum.t987 = type { i32, [4 x i64] }
%sollang.enum.t988 = type { i32, [9 x i64] }
%sollang.enum.t989 = type { i32, [2 x i64] }
%sollang.enum.t990 = type { i32, [32 x i64] }
%sollang.enum.t991 = type { i32, [3 x i64] }
%sollang.enum.t993 = type { i32, [5 x i64] }
%sollang.enum.t994 = type { i32, [2 x i64] }
%sollang.enum.t995 = type { i32, [0 x i64] }
%sollang.enum.t999 = type { i32, [10 x i64] }
%sollang.enum.t1000 = type { i32, [11 x i64] }
%sollang.enum.t1001 = type { i32, [2 x i64] }
%sollang.enum.t1002 = type { i32, [1 x i64] }
%sollang.enum.t1003 = type { i32, [0 x i64] }
%sollang.enum.t1005 = type { i32, [5 x i64] }
%sollang.enum.t1006 = type { i32, [3 x i64] }
%sollang.enum.t1007 = type { i32, [3 x i64] }
%sollang.enum.t1008 = type { i32, [0 x i64] }
%sollang.enum.t1012 = type { i32, [0 x i64] }
%sollang.enum.t1014 = type { i32, [10 x i64] }
%sollang.enum.t1015 = type { i32, [33 x i64] }
%sollang.enum.t1016 = type { i32, [35 x i64] }
%sollang.enum.t1017 = type { i32, [1 x i64] }
%sollang.enum.t1020 = type { i32, [1 x i64] }
%sollang.enum.t1021 = type { i32, [0 x i64] }
%sollang.enum.t1022 = type { i32, [0 x i64] }
%sollang.enum.t1028 = type { i32, [5 x i64] }
%sollang.enum.t1029 = type { i32, [3 x i64] }
%sollang.enum.t1030 = type { i32, [15 x i64] }
%sollang.enum.t1031 = type { i32, [3 x i64] }
%sollang.enum.t1032 = type { i32, [2 x i64] }
%sollang.enum.t1033 = type { i32, [3 x i64] }
%sollang.enum.t1038 = type { i32, [0 x i64] }
%sollang.enum.t1039 = type { i32, [0 x i64] }
%sollang.enum.t1041 = type { i32, [2 x i64] }
%sollang.enum.t1047 = type { i32, [7 x i64] }
%sollang.enum.t1048 = type { i32, [3 x i64] }
%sollang.enum.t1049 = type { i32, [3 x i64] }
%sollang.enum.t1050 = type { i32, [15 x i64] }
%sollang.enum.t1051 = type { i32, [25 x i64] }
%sollang.enum.t1052 = type { i32, [7 x i64] }
%sollang.enum.t1053 = type { i32, [5 x i64] }
%sollang.enum.t1054 = type { i32, [9 x i64] }
%sollang.enum.t1055 = type { i32, [31 x i64] }
%sollang.enum.t1056 = type { i32, [3 x i64] }
%sollang.enum.t1057 = type { i32, [8 x i64] }
%sollang.enum.t1061 = type { i32, [2 x i64] }
%sollang.enum.t1062 = type { i32, [2 x i64] }
%sollang.enum.t1063 = type { i32, [12 x i64] }
%sollang.enum.t1064 = type { i32, [6 x i64] }
%sollang.enum.t1066 = type { i32, [0 x i64] }
%sollang.enum.t1067 = type { i32, [0 x i64] }
%sollang.enum.t1071 = type { i32, [2 x i64] }
%sollang.enum.t1072 = type { i32, [9 x i64] }
%sollang.enum.t1073 = type { i32, [6 x i64] }
%sollang.enum.t1075 = type { i32, [2 x i64] }
%sollang.enum.t1077 = type { i32, [8 x i64] }
%sollang.enum.t1081 = type { i32, [3 x i64] }
%sollang.enum.t1082 = type { i32, [26 x i64] }
%sollang.enum.t1083 = type { i32, [4 x i64] }
%sollang.enum.t1084 = type { i32, [5 x i64] }
%sollang.enum.t1085 = type { i32, [8 x i64] }
%sollang.enum.t1086 = type { i32, [40 x i64] }
%sollang.enum.t1087 = type { i32, [9 x i64] }
%sollang.enum.t1088 = type { i32, [3 x i64] }
%sollang.enum.t1092 = type { i32, [10 x i64] }
%sollang.enum.t1093 = type { i32, [5 x i64] }
%sollang.enum.t1094 = type { i32, [3 x i64] }
%sollang.enum.t1097 = type { i32, [8 x i64] }
%sollang.enum.t1104 = type { i32, [2 x i64] }
%sollang.enum.t1105 = type { i32, [4 x i64] }
%sollang.enum.t1115 = type { i32, [2 x i64] }
%sollang.enum.t1116 = type { i32, [9 x i64] }
%sollang.enum.t1117 = type { i32, [3 x i64] }
%sollang.enum.t1118 = type { i32, [7 x i64] }
%sollang.enum.t1119 = type { i32, [11 x i64] }
%sollang.enum.t1120 = type { i32, [7 x i64] }
%sollang.enum.t1131 = type { i32, [6 x i64] }
%sollang.enum.t1133 = type { i32, [11 x i64] }
%sollang.enum.t1134 = type { i32, [18 x i64] }
%sollang.enum.t1136 = type { i32, [149 x i64] }
%sollang.enum.t1137 = type { i32, [3 x i64] }
%sollang.enum.t1138 = type { i32, [2 x i64] }
%sollang.enum.t1149 = type { i32, [2 x i64] }
%sollang.enum.t1150 = type { i32, [2 x i64] }
%sollang.enum.t1152 = type { i32, [12 x i64] }
%sollang.enum.t1153 = type { i32, [9 x i64] }
%sollang.enum.t1154 = type { i32, [5 x i64] }
%sollang.enum.t1155 = type { i32, [5 x i64] }
%sollang.enum.t1156 = type { i32, [6 x i64] }
%sollang.enum.t1157 = type { i32, [6 x i64] }
%sollang.enum.t1158 = type { i32, [2 x i64] }
%sollang.enum.t1162 = type { i32, [14 x i64] }
%sollang.enum.t1169 = type { i32, [6 x i64] }
%sollang.enum.t1170 = type { i32, [6 x i64] }
%sollang.enum.t1171 = type { i32, [0 x i64] }
%sollang.enum.t1172 = type { i32, [0 x i64] }
%sollang.enum.t1175 = type { i32, [4 x i64] }
%sollang.enum.t1176 = type { i32, [5 x i64] }
%sollang.enum.t1177 = type { i32, [4 x i64] }
%sollang.enum.t1178 = type { i32, [21 x i64] }
%sollang.enum.t1179 = type { i32, [4 x i64] }
%sollang.enum.t1180 = type { i32, [5 x i64] }
%sollang.enum.t1183 = type { i32, [2 x i64] }
%sollang.enum.t1185 = type { i32, [3 x i64] }
%sollang.enum.t1186 = type { i32, [4 x i64] }
%sollang.enum.t1187 = type { i32, [2 x i64] }
%sollang.enum.t1188 = type { i32, [0 x i64] }
%sollang.enum.t1190 = type { i32, [6 x i64] }
%sollang.enum.t1193 = type { i32, [5 x i64] }
%sollang.enum.t1194 = type { i32, [5 x i64] }
%sollang.enum.t1197 = type { i32, [16 x i64] }
%sollang.enum.t1198 = type { i32, [7 x i64] }
%sollang.enum.t1199 = type { i32, [6 x i64] }
%sollang.enum.t1200 = type { i32, [0 x i64] }
%sollang.enum.t1201 = type { i32, [4 x i64] }
%sollang.enum.t1203 = type { i32, [5 x i64] }
%sollang.enum.t1204 = type { i32, [2 x i64] }
%sollang.enum.t1206 = type { i32, [2 x i64] }
%sollang.enum.t1208 = type { i32, [4 x i64] }
%sollang.enum.t1211 = type { i32, [9 x i64] }
%sollang.enum.t1213 = type { i32, [4 x i64] }
%sollang.struct.m0_s10 = type {  }
%sollang.struct.m0_s8 = type { %sollang.enum.t34 }
%sollang.struct.m0_s14 = type { i32, i32 }
%sollang.struct.m0_s11 = type { i32, i1 }
%sollang.struct.m1_s7 = type { %sollang.enum.t101, i64 }
%sollang.struct.m1_s38 = type { %sollang.array.i32, i32, i32 }
%sollang.struct.m1_s42 = type { %sollang.array.i32, i32 }
%sollang.struct.m1_s29 = type { i32, i32 }
%sollang.struct.m1_s32 = type { %sollang.array.i32, i32, %sollang.array.i32, i32, i32 }
%sollang.struct.m1_s26 = type { i32, %sollang.enum.t102 }
%sollang.struct.m2_s6 = type { %sollang.text, %sollang.text }
%sollang.struct.m2_s9 = type { %sollang.text }
%sollang.struct.m2_s19 = type { %sollang.enum.t127 }
%sollang.struct.m2_s11 = type { %sollang.enum.t127, %sollang.text }
%sollang.struct.m3_s0 = type { i8, i8, i8, i8 }
%sollang.struct.m3_s8 = type { i16, i16, i16, i16, i16, i16, i16, i16 }
%sollang.struct.m3_s5 = type { %sollang.struct.m3_s0, i16 }
%sollang.struct.m3_s17 = type { %sollang.struct.m3_s8, i16, i32, i32 }
%sollang.struct.m3_s28 = type { %sollang.enum.t139, i64 }
%sollang.struct.m4_s19 = type { i32, i32, i32 }
%sollang.struct.m4_s27 = type { %sollang.enum.t148, i64, i1 }
%sollang.struct.m4_s16 = type { %sollang.enum.t147, i64 }
%sollang.struct.m4_s31 = type { %sollang.source_text, i64, i64, i32, i1, %sollang.struct.m4_s19, %sollang.struct.m4_s27 }
%sollang.struct.m4_s23 = type { %sollang.enum.t148, i64, i64 }
%sollang.struct.m6_s2 = type { i64, i64 }
%sollang.struct.m6_s5 = type { i64 }
%sollang.struct.m6_s0 = type { i64 }
%sollang.struct.m6_s38 = type { %sollang.array.i32, %sollang.struct.m6_s0, i64, %sollang.enum.t176 }
%sollang.struct.m6_s59 = type { %sollang.enum.t178 }
%sollang.struct.m6_s7 = type { i64, i64, i64 }
%sollang.struct.m6_s11 = type { i8 }
%sollang.struct.m6_s13 = type { i8 }
%sollang.struct.m6_s15 = type { i64, i64 }
%sollang.struct.m6_s18 = type { i64 }
%sollang.struct.m6_s22 = type { %sollang.struct.m6_s5 }
%sollang.struct.m6_s24 = type { i64 }
%sollang.struct.m6_s20 = type { %sollang.struct.m6_s2 }
%sollang.struct.m6_s30 = type { %sollang.struct.m6_s0, %sollang.enum.t175, %sollang.struct.m6_s0 }
%sollang.struct.m6_s43 = type { %sollang.struct.m6_s38, %sollang.struct.m6_s2, %sollang.struct.m6_s2, i64 }
%sollang.struct.m7_s7 = type { i64, i64, i1 }
%sollang.struct.m7_s14 = type { %sollang.struct.m7_s7, %sollang.enum.t203, %sollang.enum.t204, %sollang.struct.m7_s7 }
%sollang.struct.m7_s29 = type { i1, i1, i1, i1, i1 }
%sollang.struct.m7_s22 = type { %sollang.source_text, %sollang.struct.m7_s7, %sollang.enum.t206, %sollang.struct.m7_s7, %sollang.struct.m7_s7, %sollang.struct.m7_s7 }
%sollang.struct.m7_s0 = type { %sollang.enum.t201, i64 }
%sollang.struct.m30_s2 = type { i8 }
%sollang.struct.m8_s8 = type { %sollang.int_slice }
%sollang.struct.m8_s0 = type { %sollang.enum.t217, i64 }
%sollang.struct.m8_s10 = type { i8 }
%sollang.struct.m8_s12 = type { %sollang.struct.m6_s13, %sollang.struct.m30_s2 }
%sollang.struct.m12_s0 = type { %sollang.array.i32, %sollang.enum.t152 }
%sollang.struct.m9_s0 = type { %sollang.array.i32, i64 }
%sollang.struct.m9_s3 = type { %sollang.struct.m12_s0, %sollang.enum.t229 }
%sollang.struct.m10_s0 = type { i64 }
%sollang.struct.m10_s2 = type { i64 }
%sollang.struct.m10_s13 = type { %sollang.struct.m10_s0, %sollang.array.i32, i64, i1 }
%sollang.struct.m10_s18 = type { %sollang.struct.m10_s0, %sollang.array.i32, %sollang.enum.t238 }
%sollang.struct.m10_s22 = type { %sollang.struct.m10_s2, %sollang.array.i32, i64 }
%sollang.struct.m10_s26 = type { %sollang.struct.m10_s2, %sollang.array.i32, %sollang.enum.t238 }
%sollang.struct.m10_s4 = type { %sollang.text, %sollang.text }
%sollang.struct.m12_s8 = type { %sollang.struct.m12_s0, %sollang.enum.t229, i64, i64 }
%sollang.struct.m12_s3 = type { %sollang.array.i32, i8, i64, i64 }
%sollang.struct.m13_s30 = type { i32 }
%sollang.struct.m13_s0 = type { %sollang.text, %sollang.text, i1 }
%sollang.struct.m13_s32 = type { i32 }
%sollang.struct.m13_s37 = type { i64 }
%sollang.struct.m13_s21 = type { %sollang.array.i32, %sollang.text, i1, %sollang.array.i32, i1, %sollang.enum.t265, %sollang.enum.t266, %sollang.enum.t266 }
%sollang.struct.m13_s12 = type { i64, i64 }
%sollang.struct.m13_s15 = type { %sollang.struct.m13_s30, %sollang.array.i32, %sollang.array.i32, i1, i1 }
%sollang.struct.m13_s39 = type { i64, %sollang.struct.m13_s37, i32, i32 }
%sollang.struct.m13_s44 = type { i32, i32 }
%sollang.struct.m16_s3 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m19_s62 = type { %sollang.struct.m19_s19 }
%sollang.struct.m16_s11 = type { i32, i32, i32 }
%sollang.struct.m39_s3 = type { %sollang.enum.t486, i32 }
%sollang.struct.m16_s0 = type { %sollang.enum.t278, i64 }
%sollang.struct.m16_s46 = type { i32, i32, i32, i32, i32, i32, i32, i32 }
%sollang.struct.m16_s9 = type { %sollang.struct.m16_s3 }
%sollang.struct.m16_s15 = type { %sollang.struct.m16_s3, %sollang.enum.t280, i32, %sollang.array.i32, %sollang.array.i32, i32, i32, i32, %sollang.array.i32, i32, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m16_s11, i32, %sollang.struct.m39_s3, %sollang.array.i32, %sollang.array.i32, i32, i32, i32, %sollang.array.i32, i32, i32, %sollang.array.i32, i32, i1, %sollang.struct.m16_s0 }
%sollang.struct.m16_s55 = type { %sollang.struct.m16_s46, %sollang.enum.t286, i32, i32, i32, i32, i32, i32, %sollang.struct.m39_s3, %sollang.array.i32 }
%sollang.struct.m19_s0 = type { %sollang.enum.t349, i64 }
%sollang.struct.m17_s22 = type { %sollang.text, %sollang.text, i32, i64, i32, i32 }
%sollang.struct.m17_s46 = type { i64 }
%sollang.struct.m17_s20 = type { i32 }
%sollang.struct.m17_s29 = type { i64, %sollang.enum.t310, %sollang.enum.t297, %sollang.enum.t298, %sollang.enum.t310, i64, %sollang.enum.t311 }
%sollang.struct.m17_s37 = type { i64, i64, i64, i1 }
%sollang.struct.m17_s42 = type { i64, i64, i64 }
%sollang.struct.m17_s48 = type { %sollang.struct.m17_s46, %sollang.enum.t301 }
%sollang.struct.m18_s3 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m82_s26 = type { i64, i32, i32 }
%sollang.struct.m75_s10 = type { %sollang.struct.m81_s6, %sollang.struct.m77_s7, %sollang.struct.m85_s8, i32, i32, i32 }
%sollang.struct.m76_s26 = type { %sollang.struct.m75_s10, %sollang.struct.m76_s3, i32, %sollang.array.i32, %sollang.enum.t916 }
%sollang.struct.m18_s0 = type { %sollang.enum.t319, i64 }
%sollang.struct.m18_s9 = type { %sollang.struct.m18_s3 }
%sollang.struct.m18_s11 = type { i32, i32, i32, i32, i32, i32, i1 }
%sollang.struct.m18_s19 = type { i32, i32, i32, i32, i32, i32, %sollang.enum.t321, %sollang.struct.m82_s26, %sollang.struct.m75_s10, %sollang.struct.m76_s26, i32, i1, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m18_s0 }
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
%sollang.struct.m19_s19 = type { %sollang.struct.m19_s6, i32, i32, i32, i32, i32, i32, %sollang.enum.t353, i32, i32, i32, i32, i32, i32, i32, i1, i32, i32, i32, i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.struct.m19_s93, %sollang.struct.m19_s93, %sollang.struct.m19_s93, i32, i32, i32, i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, i32, i1, %sollang.struct.m19_s0, i1, i1 }
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
%sollang.struct.m40_s2 = type { i64, i64, i64, i64, i64, i64, i64, %sollang.int_slice, i32 }
%sollang.struct.m20_s0 = type { %sollang.enum.t391, i64 }
%sollang.struct.m20_s24 = type { %sollang.struct.m20_s16, %sollang.struct.m20_s22 }
%sollang.struct.m20_s27 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.m40_s2 }
%sollang.struct.m20_s35 = type { i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t397, i64, i32, i32, i32, i32, i32, i1, i64, i1, %sollang.struct.m40_s2, i32, i32, i32, i32, i1, %sollang.array.i32, %sollang.struct.m91_s2, i1, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m20_s0 }
%sollang.struct.m20_s3 = type { %sollang.array.i32, %sollang.struct.m91_s2, i1, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32 }
%sollang.struct.m21_s2 = type { %sollang.array.i32 }
%sollang.struct.m21_s4 = type { %sollang.int_slice }
%sollang.struct.m22_s6 = type { %sollang.int_slice }
%sollang.struct.m22_s3 = type { %sollang.struct.m21_s2, %sollang.int_slice }
%sollang.struct.m22_s0 = type { %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m25_s2 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m25_s0 = type { %sollang.enum.t419 }
%sollang.struct.m31_s89 = type { %sollang.int_slice, %sollang.int_slice, i32, i64 }
%sollang.struct.m29_s8 = type { %sollang.struct.m31_s89, %sollang.struct.m31_s89 }
%sollang.struct.m34_s5 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m34_s0 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m34_s9 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m36_s9 = type { %sollang.enum.t445, %sollang.enum.t446 }
%sollang.struct.m36_s0 = type { %sollang.enum.t444, i64 }
%sollang.struct.m36_s3 = type { i32, i32 }
%sollang.struct.m36_s6 = type { i32, i32 }
%sollang.struct.m36_s12 = type { %sollang.struct.m36_s9, i32, i32, i64, i8, i8, i32 }
%sollang.struct.m36_s20 = type { %sollang.struct.m36_s9, i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.m36_s35 = type { i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.m37_s3 = type { %sollang.enum.t462, i64 }
%sollang.struct.m37_s6 = type { %sollang.enum.t463, i64 }
%sollang.struct.m37_s9 = type { %sollang.enum.t463, i32, i32 }
%sollang.struct.m38_s9 = type { i1 }
%sollang.struct.m38_s0 = type { %sollang.enum.t472, i64 }
%sollang.struct.m38_s3 = type { i32, i32 }
%sollang.struct.m38_s6 = type { i32, i32 }
%sollang.struct.m38_s11 = type { %sollang.struct.m38_s9, i32, i32, i64 }
%sollang.struct.m38_s16 = type { i32, i32, i64, i32, i64 }
%sollang.struct.m40_s0 = type { i64 }
%sollang.struct.m41_s24 = type { %sollang.array.i32, i32, i32, i32, i1 }
%sollang.struct.m41_s30 = type { %sollang.struct.m41_s24, %sollang.array.i32, i32, i1 }
%sollang.struct.m41_s35 = type { %sollang.struct.m41_s24, %sollang.array.i32, %sollang.enum.t488 }
%sollang.struct.m41_s39 = type { %sollang.struct.m41_s24, %sollang.array.i32, i32, i1 }
%sollang.struct.m41_s44 = type { %sollang.struct.m41_s24, %sollang.array.i32, %sollang.enum.t488 }
%sollang.struct.m41_s5 = type { i1 }
%sollang.struct.m41_s7 = type { %sollang.struct.m1_s38, %sollang.array.i32, i32, i1 }
%sollang.struct.m41_s12 = type { %sollang.struct.m1_s38, %sollang.array.i32, %sollang.enum.t488 }
%sollang.struct.m41_s16 = type { %sollang.struct.m1_s42, %sollang.array.i32, i32 }
%sollang.struct.m41_s20 = type { %sollang.struct.m1_s42, %sollang.array.i32, %sollang.enum.t488 }
%sollang.struct.m42_s0 = type { %sollang.struct.m10_s0, i64 }
%sollang.struct.m42_s3 = type { %sollang.struct.m10_s2, i64 }
%sollang.struct.m42_s6 = type { %sollang.struct.m42_s0, %sollang.array.i32, i32, i1 }
%sollang.struct.m42_s11 = type { %sollang.struct.m42_s0, %sollang.array.i32, %sollang.enum.t238 }
%sollang.struct.m42_s15 = type { %sollang.struct.m42_s3, %sollang.array.i32, i32 }
%sollang.struct.m42_s19 = type { %sollang.struct.m42_s3, %sollang.array.i32, %sollang.enum.t238 }
%sollang.struct.m1_s13 = type {  }
%sollang.struct.m1_s17 = type {  }
%sollang.struct.m48_s52 = type { i64 }
%sollang.struct.m48_s9 = type { i64 }
%sollang.struct.m48_s188 = type { %sollang.enum.t655, i32 }
%sollang.struct.m43_s0 = type { %sollang.struct.m48_s52, i64 }
%sollang.struct.m48_s62 = type { i64, %sollang.enum.t651, %sollang.array.i32, i64, i64, %sollang.enum.t652, %sollang.enum.t277, %sollang.enum.t664, %sollang.enum.t310 }
%sollang.struct.m43_s6 = type { %sollang.struct.m43_s0, %sollang.array.i32, i64, i1 }
%sollang.struct.m43_s11 = type { %sollang.struct.m43_s0, %sollang.array.i32, %sollang.struct.m48_s188 }
%sollang.struct.m43_s15 = type { %sollang.struct.m43_s0, %sollang.array.i32, i64 }
%sollang.struct.m43_s19 = type { %sollang.struct.m43_s0, %sollang.array.i32, %sollang.struct.m48_s188 }
%sollang.struct.m43_s3 = type { %sollang.struct.m48_s9, %sollang.struct.m48_s188 }
%sollang.struct.m44_s17 = type { %sollang.enum.t530, i64, i64 }
%sollang.struct.m44_s14 = type { %sollang.enum.t529, i32 }
%sollang.struct.m45_s12 = type { i64, i64 }
%sollang.struct.m45_s6 = type { i32, i32, i32, i32, i32 }
%sollang.struct.m45_s15 = type { %sollang.struct.m45_s12, %sollang.struct.m45_s12 }
%sollang.struct.m45_s3 = type { %sollang.enum.t533, i64 }
%sollang.struct.m45_s18 = type { %sollang.struct.m45_s6 }
%sollang.struct.m45_s20 = type { %sollang.source_text, %sollang.struct.m45_s12, %sollang.struct.m45_s12, %sollang.enum.t536, %sollang.array.i32, i64 }
%sollang.struct.m45_s27 = type { %sollang.source_text, %sollang.enum.t536, i32, %sollang.struct.m45_s12, %sollang.array.i32, i64 }
%sollang.struct.m45_s34 = type { %sollang.array.i32, i64 }
%sollang.struct.m48_s11 = type { i64 }
%sollang.struct.m47_s97 = type { i64, i64 }
%sollang.struct.m48_s168 = type { %sollang.enum.t141, %sollang.array.i32, i1 }
%sollang.struct.m47_s12 = type { i64, i64, i64, i64 }
%sollang.struct.m47_s3 = type { %sollang.int_slice }
%sollang.struct.m47_s17 = type { i64, i64, i32, i32, i32, i64, %sollang.struct.m47_s12 }
%sollang.struct.m103_s0 = type { i1, i32, %sollang.int_slice, %sollang.struct.m127_s0 }
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
%sollang.struct.m47_s5 = type { %sollang.struct.m48_s11, %sollang.enum.t141, i1, %sollang.array.i32, %sollang.array.i32, i64 }
%sollang.struct.m47_s100 = type { i64, i8 }
%sollang.struct.m47_s0 = type { %sollang.enum.t552, i64 }
%sollang.struct.m106_s18 = type { %sollang.enum.t552, i64 }
%sollang.struct.m47_s172 = type { %sollang.array.i32, i64 }
%sollang.struct.m109_s0 = type { i32, %sollang.array.i32, %sollang.array.i32, i64, %sollang.array.i32 }
%sollang.struct.m123_s6 = type { %sollang.int_slice, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.int_slice, %sollang.array.i32 }
%sollang.struct.m123_s13 = type { %sollang.int_slice, %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m47_s30 = type { %sollang.array.i32, %sollang.enum.t141, %sollang.enum.t141, i1, i32, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.struct.m103_s0, %sollang.struct.m103_s0, i64, i64, i1, %sollang.int_slice, %sollang.array.i32, %sollang.int_slice, %sollang.array.i32, i1, i1, %sollang.array.i32, %sollang.struct.m117_s3, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i64, i32, i64, i1, i1, %sollang.struct.m115_s13, %sollang.struct.m111_s0, %sollang.struct.m111_s6, %sollang.struct.m118_s22, %sollang.struct.m118_s31, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.m109_s6 = type { %sollang.array.i32, i64, %sollang.array.i32 }
%sollang.struct.m125_s0 = type { %sollang.enum.t1200, %sollang.struct.m126_s0 }
%sollang.struct.m123_s17 = type { %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m108_s0 = type { i32, i64, i64, %sollang.array.i32, i64 }
%sollang.struct.m121_s0 = type { %sollang.enum.t1188, %sollang.struct.m126_s0, %sollang.int_slice }
%sollang.struct.m128_s0 = type { i64, %sollang.array.i32, i64 }
%sollang.struct.m130_s0 = type { i32, %sollang.array.i32 }
%sollang.struct.m47_s110 = type { i64, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.m47_s25 = type { %sollang.struct.m47_s3, %sollang.enum.t141, %sollang.struct.m47_s17, i1 }
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
%sollang.struct.m48_s39 = type { i64, %sollang.enum.t649, %sollang.enum.t650 }
%sollang.struct.m48_s143 = type { i64, %sollang.array.i32 }
%sollang.struct.m48_s43 = type { i64, i1, i1, i1 }
%sollang.struct.m48_s0 = type { %sollang.enum.t141, i32, i1 }
%sollang.struct.m48_s4 = type { %sollang.enum.t141, i1 }
%sollang.struct.m48_s13 = type { ptr, i64, i64 }
%sollang.struct.m48_s72 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s9, %sollang.struct.m48_s188 }
%sollang.struct.m48_s76 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s9 }
%sollang.struct.m48_s79 = type { %sollang.struct.m48_s52, %sollang.struct.m48_s188 }
%sollang.struct.m48_s172 = type { %sollang.enum.t141, i64, i1 }
%sollang.struct.m49_s34 = type { %sollang.enum.t678, i32 }
%sollang.struct.m49_s24 = type { i32, i32, i32, i32 }
%sollang.struct.m49_s29 = type { i32, i32, i32, i32 }
%sollang.struct.m49_s20 = type { %sollang.enum.t677, i64, i32 }
%sollang.struct.m49_s42 = type { %sollang.source_text, i64, i64, i32, i32, i1, %sollang.struct.m49_s34, %sollang.struct.m49_s24 }
%sollang.struct.m49_s51 = type { %sollang.struct.m49_s29, i32, i32, i32, i32 }
%sollang.struct.m49_s57 = type { i64, i64, i64, i32, i1, i1 }
%sollang.struct.m49_s37 = type { i32, i32, i32, i1 }
%sollang.struct.m50_s10 = type { %sollang.enum.t695, i64, i64 }
%sollang.struct.m50_s0 = type { i32, i32, i32 }
%sollang.struct.m50_s14 = type { %sollang.source_text, i64, i32, i32 }
%sollang.struct.m51_s35 = type { %sollang.array.i32, i32 }
%sollang.struct.m51_s38 = type { %sollang.enum.t703, i64, i64, i1, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m51_s15 = type { i32, i32, i32, i32 }
%sollang.struct.m51_s20 = type { %sollang.enum.t702, i64, i64, i64, i64, i32, i32 }
%sollang.struct.m51_s12 = type { %sollang.enum.t701, i64 }
%sollang.struct.m51_s49 = type { %sollang.source_text, i64, i64, i8, i32, %sollang.struct.m51_s15, %sollang.array.i32 }
%sollang.struct.m51_s110 = type { i64, i64, i32 }
%sollang.struct.m51_s57 = type { %sollang.array.i32, i32, i32, i32, i8, %sollang.array.i32 }
%sollang.struct.m51_s46 = type { %sollang.array.i32, i32 }
%sollang.struct.m52_s17 = type { %sollang.enum.t731, i64, i64, i64 }
%sollang.struct.m52_s61 = type { i32 }
%sollang.struct.m52_s58 = type { i8, i64 }
%sollang.struct.m52_s50 = type { %sollang.enum.t733, i64, i64, i64, i1, %sollang.enum.t732, i64 }
%sollang.struct.m52_s0 = type { i32, i32, i32, i32 }
%sollang.struct.m52_s25 = type { %sollang.source_text, i64, i64, i32, i32, i1, i1, i32, i32 }
%sollang.struct.m52_s22 = type { i64, i64 }
%sollang.struct.m54_s3 = type { i32, i32 }
%sollang.struct.m54_s0 = type { %sollang.enum.t749, i64 }
%sollang.struct.m54_s6 = type { %sollang.enum.t750 }
%sollang.struct.m57_s20 = type { i32, %sollang.enum.t758 }
%sollang.struct.m57_s17 = type { %sollang.enum.t757, i32 }
%sollang.struct.m57_s0 = type { i32, i32, i32, i32, %sollang.enum.t756 }
%sollang.struct.m83_s5 = type { i32 }
%sollang.struct.m74_s0 = type { %sollang.enum.t331, i64 }
%sollang.struct.m74_s13 = type { %sollang.array.i32, %sollang.struct.m82_s12 }
%sollang.struct.m74_s63 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m82_s15 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m74_s28 = type { %sollang.struct.m75_s168, %sollang.struct.m83_s5, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i32, i32, %sollang.enum.t813, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t813 }
%sollang.struct.m74_s58 = type { %sollang.array.i32 }
%sollang.struct.m75_s159 = type { i32, i32, %sollang.enum.t849, %sollang.enum.t849 }
%sollang.struct.m82_s9 = type { %sollang.array.i32, i32 }
%sollang.struct.m74_s3 = type { i32, i32, i32 }
%sollang.struct.m81_s6 = type { %sollang.struct.m82_s6, i32 }
%sollang.struct.m77_s7 = type { %sollang.struct.m81_s6, i32, i32 }
%sollang.struct.m85_s8 = type { %sollang.struct.m81_s6, i32, i32, i32 }
%sollang.struct.m75_s49 = type { i32, i32, i32, i32, i32, %sollang.enum.t846, i32, i32 }
%sollang.struct.m75_s76 = type { %sollang.struct.m81_s6, i32, i32, %sollang.enum.t848, i32, i32, i32, i32, %sollang.enum.t849, %sollang.enum.t849 }
%sollang.struct.m75_s111 = type { %sollang.array.i32, i32, i32, i32, %sollang.array.i32, i32 }
%sollang.struct.m77_s29 = type { %sollang.struct.m81_s6, i32, i32, i32, %sollang.enum.t924, i32, i32, i32, %sollang.array.i32, %sollang.enum.t925 }
%sollang.struct.m75_s134 = type { %sollang.array.i32, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i32, i32 }
%sollang.struct.m85_s16 = type { %sollang.struct.m81_s6, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.array.i32 }
%sollang.struct.m75_s0 = type { %sollang.enum.t330, i64 }
%sollang.struct.m75_s180 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m75_s183 = type { %sollang.struct.m75_s159, %sollang.struct.m82_s12 }
%sollang.struct.m81_s35 = type { %sollang.struct.m82_s6, i32, i32, i32, %sollang.enum.t945, i32, i32, i32, %sollang.array.i32, %sollang.array.i32, %sollang.struct.m81_s17, %sollang.array.i32, i32, i32, i32, %sollang.enum.t947, i32, i32, i32, i32, i32, i32, %sollang.enum.t947 }
%sollang.struct.m75_s97 = type { %sollang.struct.m75_s10, %sollang.struct.m75_s76, %sollang.enum.t851, i32, %sollang.array.i32, i32, i32, %sollang.array.i32 }
%sollang.struct.m75_s122 = type { %sollang.struct.m75_s111, %sollang.struct.m77_s29, %sollang.enum.t854, %sollang.array.i32, %sollang.array.i32, i32, i32 }
%sollang.struct.m75_s149 = type { %sollang.struct.m75_s134, %sollang.struct.m85_s16, %sollang.enum.t857, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m75_s164 = type { i32, i32, %sollang.struct.m82_s12 }
%sollang.struct.m81_s9 = type { %sollang.struct.m82_s9, %sollang.struct.m82_s12 }
%sollang.struct.m77_s11 = type { %sollang.array.i32, i32, %sollang.struct.m82_s12 }
%sollang.struct.m85_s13 = type { %sollang.array.i32, %sollang.struct.m82_s12 }
%sollang.struct.m75_s34 = type { %sollang.enum.t845, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t846, i32, i32 }
%sollang.struct.m75_s3 = type { i32, i32, i32, i32, i32, i32 }
%sollang.struct.m76_s7 = type { %sollang.struct.m75_s97, %sollang.struct.m81_s35 }
%sollang.struct.m76_s10 = type { %sollang.struct.m75_s122, %sollang.struct.m81_s35 }
%sollang.struct.m76_s13 = type { %sollang.struct.m75_s149, %sollang.struct.m81_s35 }
%sollang.struct.m76_s3 = type { i32, i32, i32 }
%sollang.struct.m76_s0 = type { %sollang.enum.t319, i64 }
%sollang.struct.m77_s0 = type { %sollang.enum.t873, i64 }
%sollang.struct.m77_s50 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m77_s44 = type { %sollang.array.i32, i32 }
%sollang.struct.m77_s3 = type { i32, i32, i32 }
%sollang.struct.m82_s6 = type { i32, i32 }
%sollang.struct.m81_s17 = type { %sollang.enum.t944, i32 }
%sollang.struct.m81_s0 = type { %sollang.enum.t872, i64 }
%sollang.struct.m81_s62 = type { i32, %sollang.struct.m82_s12 }
%sollang.struct.m81_s3 = type { i32, i32 }
%sollang.struct.m82_s18 = type { i32, i32 }
%sollang.struct.m82_s0 = type { %sollang.enum.t821, i64 }
%sollang.struct.m82_s33 = type { i32, i32 }
%sollang.struct.m82_s3 = type { i32, i32 }
%sollang.struct.m82_s24 = type { i32 }
%sollang.struct.m83_s0 = type { %sollang.enum.t822, i64 }
%sollang.struct.m83_s29 = type { i32, %sollang.enum.t975, i32 }
%sollang.struct.m83_s3 = type { i32 }
%sollang.struct.m85_s0 = type { %sollang.enum.t874, i64 }
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
%sollang.struct.m97_s17 = type { %sollang.enum.t1020, %sollang.struct.m97_s0 }
%sollang.struct.m97_s42 = type { %sollang.struct.m97_s0, %sollang.enum.t1021, %sollang.enum.t1022, i64, i64, i64, i64, %sollang.array.i32, i1, i64, i32 }
%sollang.struct.m97_s20 = type { i64, i64, i1 }
%sollang.struct.m97_s54 = type { i1, i64, i1, i1 }
%sollang.struct.m97_s8 = type { %sollang.struct.m97_s6, %sollang.text }
%sollang.struct.m98_s15 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32 }
%sollang.struct.m98_s21 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32, %sollang.enum.t1038, %sollang.enum.t1039 }
%sollang.struct.m98_s29 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32, %sollang.enum.t1038, %sollang.enum.t1039, %sollang.array.i32, %sollang.struct.m45_s27, i64 }
%sollang.struct.m98_s0 = type { %sollang.enum.t141, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32 }
%sollang.struct.m100_s31 = type { %sollang.array.i32, i64, %sollang.enum.t1039, %sollang.enum.t1038 }
%sollang.struct.m98_s40 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, %sollang.struct.m97_s6, i32, i32, %sollang.array.i32, i64, %sollang.array.i32, i64, %sollang.struct.m97_s42, i1, i1, i1 }
%sollang.struct.m100_s0 = type { i32, i32, i32, i32 }
%sollang.struct.m100_s5 = type { %sollang.struct.m100_s0 }
%sollang.struct.m100_s19 = type { %sollang.struct.m100_s0, %sollang.array.i32, %sollang.text, i32, i32, i1, i1, i1, i64, %sollang.enum.t1039, %sollang.enum.t1038 }
%sollang.struct.m101_s0 = type { i32, i32, i32, i32 }
%sollang.struct.m101_s5 = type { %sollang.struct.m101_s0 }
%sollang.struct.m101_s14 = type { %sollang.struct.m101_s0, %sollang.array.i32, i32, i32, i1, i1, i1, i64, %sollang.enum.t1066 }
%sollang.struct.m101_s24 = type { %sollang.array.i32, i64, %sollang.enum.t1066, %sollang.enum.t1067 }
%sollang.struct.m102_s17 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, i32, %sollang.array.i32, i64 }
%sollang.struct.m102_s26 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, i32, %sollang.array.i32, %sollang.struct.m45_s20, i64, %sollang.array.i32, i64, i1 }
%sollang.struct.m102_s0 = type { %sollang.struct.m48_s0, %sollang.struct.m45_s6 }
%sollang.struct.m102_s13 = type { %sollang.struct.m48_s7, %sollang.struct.m45_s18, i32 }
%sollang.struct.m102_s36 = type { %sollang.struct.m48_s9, %sollang.struct.m45_s18, i32, %sollang.array.i32, %sollang.struct.m45_s20, i64, %sollang.array.i32, i64, %sollang.struct.m97_s42 }
%sollang.struct.m127_s0 = type { %sollang.struct.m113_s33 }
%sollang.struct.m103_s5 = type { i64, i1, %sollang.enum.t595 }
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
%sollang.struct.m107_s34 = type { i64, i64, %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m107_s29 = type { i1, i64, i64, %sollang.array.i32 }
%sollang.struct.m107_s66 = type { %sollang.enum.t595, i64 }
%sollang.struct.m110_s0 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m112_s0 = type { %sollang.int_slice }
%sollang.struct.m112_s2 = type { %sollang.struct.m47_s3, %sollang.int_slice, %sollang.struct.m112_s0 }
%sollang.struct.m112_s6 = type { %sollang.struct.m112_s0, %sollang.int_slice, %sollang.struct.m3_s5, i64, %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m112_s19 = type { %sollang.struct.m112_s0, %sollang.struct.m47_s87 }
%sollang.struct.m112_s13 = type { %sollang.struct.m47_s30, %sollang.struct.m47_s87, %sollang.struct.m112_s0 }
%sollang.struct.m112_s17 = type { %sollang.array.i32 }
%sollang.struct.m116_s9 = type { %sollang.struct.m22_s3, %sollang.int_slice }
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
%sollang.struct.m116_s4 = type { %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m116_s0 = type { %sollang.int_slice }
%sollang.struct.m116_s2 = type { %sollang.int_slice }
%sollang.struct.m117_s0 = type { %sollang.struct.m118_s11, i64 }
%sollang.struct.m118_s6 = type { i64, i64, %sollang.enum.t1171, %sollang.enum.t1172 }
%sollang.struct.m119_s0 = type { %sollang.array.i32 }
%sollang.struct.m119_s2 = type { i16, %sollang.array.i32 }
%sollang.struct.m126_s0 = type { %sollang.array.i32 }
%sollang.struct.m122_s0 = type { i8, %sollang.array.i32, i64 }
%sollang.struct.m122_s4 = type { i16, %sollang.array.i32, i64 }
%sollang.struct.m128_s4 = type { i64 }
%sollang.struct.m129_s0 = type { i64, i64 }
%sollang.struct.m131_s0 = type { %sollang.array.i32, %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m132_s0 = type { i8, i64, i64, i64 }
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)
@sollang_com_iid_m144_s0 = private constant { i32, i16, i16, [8 x i8] } { i32 1276159099, i16 29277, i16 16851, [8 x i8] [i8 181, i8 166, i8 112, i8 214, i8 125, i8 59, i8 235, i8 17] }
@sollang_com_clsid_m144_a1 = private constant { i32, i16, i16, [8 x i8] } { i32 2324751013, i16 31277, i16 20010, [8 x i8] [i8 152, i8 160, i8 107, i8 92, i8 42, i8 18, i8 197, i8 1] }
define internal %sollang.enum.t27 @sollang_m144_s3() {
entry:
  %raw = call { ptr, i32 } @sollang_com_activate_registered(ptr @sollang_com_clsid_m144_a1, ptr @sollang_com_iid_m144_s0)
  %instance = extractvalue { ptr, i32 } %raw, 0
  %status = extractvalue { ptr, i32 } %raw, 1
  %status_ok = icmp sge i32 %status, 0
  %pointer_ok = icmp ne ptr %instance, null
  %ok = and i1 %status_ok, %pointer_ok
  %result_slot = alloca %sollang.enum.t27, align 8
  store %sollang.enum.t27 zeroinitializer, ptr %result_slot, align 8
  br i1 %ok, label %success, label %failure
success:
  %success_tag = getelementptr %sollang.enum.t27, ptr %result_slot, i32 0, i32 0
  store i32 0, ptr %success_tag, align 4
  %success_payload = getelementptr %sollang.enum.t27, ptr %result_slot, i32 0, i32 1
  store ptr %instance, ptr %success_payload, align 8
  br label %done
failure:
  %failure_tag = getelementptr %sollang.enum.t27, ptr %result_slot, i32 0, i32 0
  store i32 1, ptr %failure_tag, align 4
  %failure_payload = getelementptr %sollang.enum.t27, ptr %result_slot, i32 0, i32 1
  store i32 %status, ptr %failure_payload, align 4
  br label %done
done:
  %result = load %sollang.enum.t27, ptr %result_slot, align 8
  ret %sollang.enum.t27 %result
}
define internal ptr @sollang_m144_s4(ptr %arg) {
entry:
  %result = call ptr @sollang_com_clone(ptr %arg)
  ret ptr %result
}
define internal void @sollang_com_init() {
entry:
  %apartment_status = call i32 @CoInitializeEx(ptr null, i32 4)
  call void @sollang_com_require_status(i32 %apartment_status)
  ret void
}
define internal void @sollang_com_cleanup() {
entry:
  call void @CoUninitialize()
  ret void
}
%sollang.dyn = type { ptr, ptr }
%sollang.mutable_container = type { ptr, ptr, ptr }
%sollang.int_slice = type { ptr, i64 }
%sollang.array.i32 = type { ptr, i64, i64 }
define internal void @sollang_drop_t26(ptr %value) {
entry:
  call void @sollang_com_release(ptr %value)
  ret void
}
define internal void @sollang_drop_t27(%sollang.enum.t27 %value) {
entry:
  %slot = alloca %sollang.enum.t27, align 8
  store %sollang.enum.t27 %value, ptr %slot, align 8
  %tag = extractvalue %sollang.enum.t27 %value, 0
  %payload = getelementptr inbounds %sollang.enum.t27, ptr %slot, i32 0, i32 1
  %is0 = icmp eq i32 %tag, 0
  br i1 %is0, label %tag0, label %tag1
tag0:
  %first = load ptr, ptr %payload, align 8
  call void @sollang_drop_t26(ptr %first)
  br label %done
tag1:
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
@sollang_str_35993 = private unnamed_addr constant [10 x i8] c"ext binder"
@sollang_str_36001 = private unnamed_addr constant [10 x i8] c"res binder"
@sollang_str_36037 = private unnamed_addr constant [11 x i8] c"c e traffic"
@sollang_str_36041 = private unnamed_addr constant [12 x i8] c"e exp master"
@sollang_str_36078 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_36085 = private unnamed_addr constant [12 x i8] c"c hs traffic"
@sollang_str_36089 = private unnamed_addr constant [12 x i8] c"s hs traffic"
@sollang_str_36093 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_36152 = private unnamed_addr constant [12 x i8] c"c ap traffic"
@sollang_str_36156 = private unnamed_addr constant [12 x i8] c"s ap traffic"
@sollang_str_36160 = private unnamed_addr constant [10 x i8] c"exp master"
@sollang_str_36187 = private unnamed_addr constant [10 x i8] c"res master"
@sollang_str_36197 = private unnamed_addr constant [8 x i8] c"finished"
@sollang_str_36226 = private unnamed_addr constant [11 x i8] c"traffic upd"
@sollang_str_42021 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_42031 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_50954 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_50965 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_50989 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_52450 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_52503 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_52556 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_55478 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_55489 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_55493 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_55767 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_55774 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_56104 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_56143 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_56148 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_58433 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_58474 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_58522 = private unnamed_addr constant [6 x i8] c"signal"
@sollang_str_58543 = private unnamed_addr constant [4 x i8] c"kill"
@sollang_str_94363 = private unnamed_addr constant [7 x i8] c"chunked"
@sollang_str_94445 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_94478 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_94913 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_94918 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_95117 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_95142 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_95927 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_95934 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_95955 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_96390 = private unnamed_addr constant [3 x i8] c"GET"
@sollang_str_96397 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_96404 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_97054 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_97062 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_97155 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_97158 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_97161 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_97164 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_97167 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_97206 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_97212 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_97369 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_97375 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_97382 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_97388 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_97900 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_97958 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_98137 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_98169 = private unnamed_addr constant [7 x i8] c"OPTIONS"
@sollang_str_98361 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_98621 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_98636 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_98637 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_98644 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_98645 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_98648 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_98906 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_98909 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_98912 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_98915 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_98953 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_98959 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_99089 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_99095 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_99102 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_99108 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_99247 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_99261 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_99407 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_99673 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_99674 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_99681 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_99682 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_99685 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_104594 = private unnamed_addr constant [9 x i8] c"client in"
@sollang_str_104598 = private unnamed_addr constant [9 x i8] c"server in"
@sollang_str_104606 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_104608 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_104615 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_104617 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_104624 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_104626 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_115485 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_115487 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_115494 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_115496 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_115503 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_115505 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_118118 = private unnamed_addr constant [7 x i8] c"created"
define i32 @main() {
entry:
  %v118113_subject_slot = alloca %sollang.enum.t27, align 8
  call void @sollang_com_init()
  %v118112 = call %sollang.enum.t27 @sollang_m144_s3()
  %v118113_tag = extractvalue %sollang.enum.t27 %v118112, 0
  store %sollang.enum.t27 %v118112, ptr %v118113_subject_slot, align 8
  %v118113_is_arm0 = icmp eq i32 %v118113_tag, 0
  br i1 %v118113_is_arm0, label %match118113_arm0, label %match118113_next0
match118113_arm0:
  %v118113_arm0_payload = getelementptr inbounds %sollang.enum.t27, ptr %v118113_subject_slot, i32 0, i32 1
  %v118115 = load ptr, ptr %v118113_arm0_payload, align 8
  %v118118_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118118, 0
  %v118118 = insertvalue %sollang.text %v118118_ptr, i64 7, 1
  call void @sollang_runtime_print(ptr @sollang_str_118118, i64 7, i1 true)
  call void @sollang_drop_t26(ptr %v118115)
  br label %match118113_merge
match118113_next0:
  %v118113_is_arm1 = icmp eq i32 %v118113_tag, 1
  br i1 %v118113_is_arm1, label %match118113_arm1, label %match118113_next1
match118113_arm1:
  %v118113_arm1_payload = getelementptr inbounds %sollang.enum.t27, ptr %v118113_subject_slot, i32 0, i32 1
  %v118120 = load i32, ptr %v118113_arm1_payload, align 4
  %v118123 = freeze i32 %v118120
  call void @sollang_runtime_print_i32(i32 %v118123, i1 true)
  br label %match118113_merge
match118113_next1:
  call void @llvm.trap()
  unreachable
match118113_merge:
  call void @sollang_com_cleanup()
  call void @sollang_runtime_flush_stdout()
  ret i32 0
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
declare dllimport i32 @ReadFile(ptr, ptr, i32, ptr, ptr)
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
