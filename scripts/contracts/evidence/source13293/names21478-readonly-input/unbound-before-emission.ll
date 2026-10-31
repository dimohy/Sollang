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
@sollang_bool_true_bytes = private constant [4 x i8] c"true"
@sollang_bool_false_bytes = private constant [5 x i8] c"false"
%sollang.source_text = type { ptr, i64, ptr, i64 }
%sollang.text = type { ptr, i64 }
%sollang.stream = type { ptr, ptr, ptr }
%sollang.event_stream = type { ptr, ptr, ptr }
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
%sollang.enum.t113 = type { i32, [1 x i64] }
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
%sollang.struct.m8_s8 = type { %sollang.int_slice }
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
%sollang.struct.m40_s2 = type { i64, i64, i64, i64, i64, i64, i64, %sollang.int_slice, i32 }
%sollang.struct.m20_s0 = type { %sollang.enum.t389, i64 }
%sollang.struct.m20_s24 = type { %sollang.struct.m20_s16, %sollang.struct.m20_s22 }
%sollang.struct.m20_s27 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.m40_s2 }
%sollang.struct.m20_s35 = type { i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.t395, i64, i32, i32, i32, i32, i32, i1, i64, i1, %sollang.struct.m40_s2, i32, i32, i32, i32, i1, %sollang.array.i32, %sollang.struct.m91_s2, i1, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32, %sollang.array.i32, i1, %sollang.struct.m20_s0 }
%sollang.struct.m20_s3 = type { %sollang.array.i32, %sollang.struct.m91_s2, i1, %sollang.struct.m90_s2, %sollang.struct.m90_s2, %sollang.struct.m90_s2, i1, i1, i1, i32, i32, i32 }
%sollang.struct.m21_s2 = type { %sollang.array.i32 }
%sollang.struct.m21_s4 = type { %sollang.int_slice }
%sollang.struct.m22_s6 = type { %sollang.int_slice }
%sollang.struct.m22_s3 = type { %sollang.struct.m21_s2, %sollang.int_slice }
%sollang.struct.m22_s0 = type { %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m25_s2 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m25_s0 = type { %sollang.enum.t417 }
%sollang.struct.m31_s89 = type { %sollang.int_slice, %sollang.int_slice, i32, i64 }
%sollang.struct.m29_s8 = type { %sollang.struct.m31_s89, %sollang.struct.m31_s89 }
%sollang.struct.m34_s5 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m34_s0 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.m34_s9 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
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
%sollang.struct.m47_s5 = type { %sollang.struct.m48_s11, %sollang.enum.t139, i1, %sollang.array.i32, %sollang.array.i32, i64 }
%sollang.struct.m47_s100 = type { i64, i8 }
%sollang.struct.m47_s0 = type { %sollang.enum.t550, i64 }
%sollang.struct.m106_s18 = type { %sollang.enum.t550, i64 }
%sollang.struct.m47_s172 = type { %sollang.array.i32, i64 }
%sollang.struct.m109_s0 = type { i32, %sollang.array.i32, %sollang.array.i32, i64, %sollang.array.i32 }
%sollang.struct.m123_s6 = type { %sollang.int_slice, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.int_slice, %sollang.array.i32 }
%sollang.struct.m123_s13 = type { %sollang.int_slice, %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m47_s30 = type { %sollang.array.i32, %sollang.enum.t139, %sollang.enum.t139, i1, i32, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.struct.m103_s0, %sollang.struct.m103_s0, i64, i64, i1, %sollang.int_slice, %sollang.array.i32, %sollang.int_slice, %sollang.array.i32, i1, i1, %sollang.array.i32, %sollang.struct.m117_s3, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, %sollang.array.i32, i64, i32, i64, i1, i1, %sollang.struct.m115_s13, %sollang.struct.m111_s0, %sollang.struct.m111_s6, %sollang.struct.m118_s22, %sollang.struct.m118_s31, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.m109_s6 = type { %sollang.array.i32, i64, %sollang.array.i32 }
%sollang.struct.m125_s0 = type { %sollang.enum.t1198, %sollang.struct.m126_s0 }
%sollang.struct.m123_s17 = type { %sollang.array.i32, %sollang.array.i32 }
%sollang.struct.m108_s0 = type { i32, i64, i64, %sollang.array.i32, i64 }
%sollang.struct.m121_s0 = type { %sollang.enum.t1186, %sollang.struct.m126_s0, %sollang.int_slice }
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
%sollang.struct.m107_s34 = type { i64, i64, %sollang.array.i32, %sollang.int_slice }
%sollang.struct.m107_s29 = type { i1, i64, i64, %sollang.array.i32 }
%sollang.struct.m107_s66 = type { %sollang.enum.t593, i64 }
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
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)
%sollang.dyn = type { ptr, ptr }
%sollang.mutable_container = type { ptr, ptr, ptr }
%sollang.int_slice = type { ptr, i64 }
%sollang.array.i32 = type { ptr, i64, i64 }
define internal void @sollang_drop_t371(%sollang.array.i32 %value) {
entry:
  %data = extractvalue %sollang.array.i32 %value, 0
  %length = extractvalue %sollang.array.i32 %value, 1
  call void @sollang_free(ptr %data)
  ret void
}
declare void @llvm.trap()
declare dllimport void @ExitProcess(i32)
@sollang_str_34359740977 = private unnamed_addr constant [0 x i8] c""
@sollang_str_34359741005 = private unnamed_addr constant [0 x i8] c""
@sollang_str_34359741009 = private unnamed_addr constant [0 x i8] c""
@sollang_str_34359741013 = private unnamed_addr constant [0 x i8] c""
@sollang_str_38654705736 = private unnamed_addr constant [1 x i8] c"0"
@sollang_str_38654705741 = private unnamed_addr constant [1 x i8] c"1"
@sollang_str_38654705746 = private unnamed_addr constant [1 x i8] c"2"
@sollang_str_38654705751 = private unnamed_addr constant [1 x i8] c"3"
@sollang_str_38654705756 = private unnamed_addr constant [1 x i8] c"4"
@sollang_str_38654705761 = private unnamed_addr constant [1 x i8] c"5"
@sollang_str_38654705766 = private unnamed_addr constant [1 x i8] c"6"
@sollang_str_38654705771 = private unnamed_addr constant [1 x i8] c"7"
@sollang_str_38654705776 = private unnamed_addr constant [1 x i8] c"8"
@sollang_str_38654705781 = private unnamed_addr constant [1 x i8] c"9"
@sollang_str_38654705786 = private unnamed_addr constant [1 x i8] c"a"
@sollang_str_38654705791 = private unnamed_addr constant [1 x i8] c"b"
@sollang_str_38654705796 = private unnamed_addr constant [1 x i8] c"c"
@sollang_str_38654705801 = private unnamed_addr constant [1 x i8] c"d"
@sollang_str_38654705806 = private unnamed_addr constant [1 x i8] c"e"
@sollang_str_38654705808 = private unnamed_addr constant [1 x i8] c"f"
@sollang_str_38654706776 = private unnamed_addr constant [1296 x i8] c"$((Int(self.bytes[0]) / 16) -> hexDigit)$((Int(self.bytes[0]) % 16) -> hexDigit)$((Int(self.bytes[1]) / 16) -> hexDigit)$((Int(self.bytes[1]) % 16) -> hexDigit)$((Int(self.bytes[2]) / 16) -> hexDigit)$((Int(self.bytes[2]) % 16) -> hexDigit)$((Int(self.bytes[3]) / 16) -> hexDigit)$((Int(self.bytes[3]) % 16) -> hexDigit)-$((Int(self.bytes[4]) / 16) -> hexDigit)$((Int(self.bytes[4]) % 16) -> hexDigit)$((Int(self.bytes[5]) / 16) -> hexDigit)$((Int(self.bytes[5]) % 16) -> hexDigit)-$((Int(self.bytes[6]) / 16) -> hexDigit)$((Int(self.bytes[6]) % 16) -> hexDigit)$((Int(self.bytes[7]) / 16) -> hexDigit)$((Int(self.bytes[7]) % 16) -> hexDigit)-$((Int(self.bytes[8]) / 16) -> hexDigit)$((Int(self.bytes[8]) % 16) -> hexDigit)$((Int(self.bytes[9]) / 16) -> hexDigit)$((Int(self.bytes[9]) % 16) -> hexDigit)-$((Int(self.bytes[10]) / 16) -> hexDigit)$((Int(self.bytes[10]) % 16) -> hexDigit)$((Int(self.bytes[11]) / 16) -> hexDigit)$((Int(self.bytes[11]) % 16) -> hexDigit)$((Int(self.bytes[12]) / 16) -> hexDigit)$((Int(self.bytes[12]) % 16) -> hexDigit)$((Int(self.bytes[13]) / 16) -> hexDigit)$((Int(self.bytes[13]) % 16) -> hexDigit)$((Int(self.bytes[14]) / 16) -> hexDigit)$((Int(self.bytes[14]) % 16) -> hexDigit)$((Int(self.bytes[15]) / 16) -> hexDigit)$((Int(self.bytes[15]) % 16) -> hexDigit)"
@sollang_str_42949673109 = private unnamed_addr constant [2 x i8] c"io"
@sollang_str_55834574945 = private unnamed_addr constant [2 x i8] c"io"
@sollang_str_55834575319 = private unnamed_addr constant [23 x i8] c"path is not valid UTF-8"
@sollang_str_55834575653 = private unnamed_addr constant [19 x i8] c"absolute child path"
@sollang_str_55834575877 = private unnamed_addr constant [18 x i8] c"path styles differ"
@sollang_str_55834575885 = private unnamed_addr constant [29 x i8] c"cannot join an absolute child"
@sollang_str_55834575926 = private unnamed_addr constant [18 x i8] c"path styles differ"
@sollang_str_55834576268 = private unnamed_addr constant [17 x i8] c"path contains NUL"
@sollang_str_55834576322 = private unnamed_addr constant [20 x i8] c"invalid drive prefix"
@sollang_str_55834576415 = private unnamed_addr constant [26 x i8] c"unsupported path namespace"
@sollang_str_55834576445 = private unnamed_addr constant [26 x i8] c"unsupported path namespace"
@sollang_str_55834576470 = private unnamed_addr constant [16 x i8] c"invalid UNC path"
@sollang_str_55834576777 = private unnamed_addr constant [17 x i8] c"path escapes root"
@sollang_str_55834576790 = private unnamed_addr constant [19 x i8] c"incomplete UNC path"
@sollang_str_60129542150 = private unnamed_addr constant [0 x i8] c""
@sollang_str_60129542226 = private unnamed_addr constant [0 x i8] c""
@sollang_str_150323855404 = private unnamed_addr constant [10 x i8] c"ext binder"
@sollang_str_150323855412 = private unnamed_addr constant [10 x i8] c"res binder"
@sollang_str_150323855448 = private unnamed_addr constant [11 x i8] c"c e traffic"
@sollang_str_150323855452 = private unnamed_addr constant [12 x i8] c"e exp master"
@sollang_str_150323855489 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_150323855496 = private unnamed_addr constant [12 x i8] c"c hs traffic"
@sollang_str_150323855500 = private unnamed_addr constant [12 x i8] c"s hs traffic"
@sollang_str_150323855504 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_150323855563 = private unnamed_addr constant [12 x i8] c"c ap traffic"
@sollang_str_150323855567 = private unnamed_addr constant [12 x i8] c"s ap traffic"
@sollang_str_150323855571 = private unnamed_addr constant [10 x i8] c"exp master"
@sollang_str_150323855598 = private unnamed_addr constant [10 x i8] c"res master"
@sollang_str_150323855608 = private unnamed_addr constant [8 x i8] c"finished"
@sollang_str_150323855637 = private unnamed_addr constant [11 x i8] c"traffic upd"
@sollang_str_197568496234 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_197568496244 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_223338299675 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_223338299686 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_223338299710 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_223338301171 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_223338301224 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_223338301277 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_223338304199 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_223338304210 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_223338304214 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_223338304488 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_223338304495 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_223338304825 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_223338304864 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_223338304869 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_287762808893 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_287762808934 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_287762808982 = private unnamed_addr constant [6 x i8] c"signal"
@sollang_str_287762809003 = private unnamed_addr constant [4 x i8] c"kill"
@sollang_str_420906795630 = private unnamed_addr constant [7 x i8] c"chunked"
@sollang_str_420906795712 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_420906795745 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_420906796180 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_420906796185 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_420906796384 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_420906796409 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_425201762366 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_425201762373 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_425201762394 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_425201762829 = private unnamed_addr constant [3 x i8] c"GET"
@sollang_str_425201762836 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_425201762843 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_433791697180 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_433791697188 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_433791697281 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_433791697284 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_433791697287 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_433791697290 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_433791697293 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_433791697332 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_433791697338 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_433791697495 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_433791697501 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_433791697508 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_433791697514 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_433791698026 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_433791698084 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_433791698263 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_433791698295 = private unnamed_addr constant [7 x i8] c"OPTIONS"
@sollang_str_433791698487 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_433791698747 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_433791698762 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_433791698763 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_433791698770 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_433791698771 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_433791698774 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_438086664423 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_438086664426 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_438086664429 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_438086664432 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_438086664470 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_438086664476 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_438086664606 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_438086664612 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_438086664619 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_438086664625 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_438086664764 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_438086664778 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_438086664924 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_438086665190 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_438086665191 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_438086665198 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_438086665199 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_438086665202 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_476741369942 = private unnamed_addr constant [9 x i8] c"client in"
@sollang_str_476741369946 = private unnamed_addr constant [9 x i8] c"server in"
@sollang_str_476741369954 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_476741369956 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_476741369963 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_476741369965 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_476741369972 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_476741369974 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_549755813908 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_549755813910 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_549755813917 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_549755813919 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_549755813926 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_549755813928 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_622770257932 = private unnamed_addr constant [8 x i8] c"item=$it"
@sollang_str_622770257943 = private unnamed_addr constant [8 x i8] c"item=$it"
define i32 @main() {
entry:
  %v622770257938 = freeze i32 1
  %v622770257943_ptr = insertvalue %sollang.text poison, ptr @sollang_str_622770257943, 0
  %v622770257943 = insertvalue %sollang.text %v622770257943_ptr, i64 8, 1
  %v622770257942_expression_literal0 = getelementptr i8, ptr @sollang_str_622770257943, i64 0
  call void @sollang_runtime_print(ptr %v622770257942_expression_literal0, i64 5, i1 false)
  call void @sollang_runtime_print_i32(i32 %v622770257938, i1 false)
  %v622770257942_expression_suffix = getelementptr i8, ptr @sollang_str_622770257943, i64 8
  call void @sollang_runtime_print(ptr %v622770257942_expression_suffix, i64 0, i1 true)
  %v622770257940 = freeze i32 1
  %heap_v622770257939 = call ptr @sollang_alloc(i64 4)
  %v622770257939_data = getelementptr i8, ptr %heap_v622770257939, i64 0
  %v622770257939_allocation_ok = icmp ne ptr %v622770257939_data, null
  br i1 %v622770257939_allocation_ok, label %v622770257939_allocation_ready, label %v622770257939_allocation_failed
v622770257939_allocation_failed:
  %v622770257939_allocation_diagnostic = alloca [22 x i8], align 1
  store [22 x i8] c"\6D\61\69\6E\3A\61\6C\6C\6F\63\61\74\69\6F\6E\5F\66\61\69\6C\65\64", ptr %v622770257939_allocation_diagnostic, align 1
  call void @sollang_runtime_eprint(ptr %v622770257939_allocation_diagnostic, i64 22, i1 false)
  call void @llvm.trap()
  unreachable
v622770257939_allocation_ready:
  %v622770257939_ptr0 = getelementptr i32, ptr %v622770257939_data, i64 0
  store i32 %v622770257940, ptr %v622770257939_ptr0, align 4
  %v622770257939_0 = insertvalue %sollang.array.i32 poison, ptr %v622770257939_data, 0
  %v622770257939_1 = insertvalue %sollang.array.i32 %v622770257939_0, i64 1, 1
  %v622770257939 = insertvalue %sollang.array.i32 %v622770257939_1, i64 1, 2
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
define void @sollang_x0B7379732E72756E74696D650107010D6F70656E496E745772697465723E01067075626C6963010D6F70656E496E7457726974657201047061746818013A01045465787416022D3E0104556E697420013D0109696E7472696E736963(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  %ok = call i32 @sollang_legacy_int_open_write_i64_file(ptr %data, i64 %length)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_x0B7379732E72756E74696D65010701087772697465496E743901067075626C696301087772697465496E74010576616C756518013A0103496E7416022D3E0104556E697420013D0109696E7472696E736963(i32 %arg) {
entry:
  %wide = sext i32 %arg to i64
  %ok = call i32 @sollang_legacy_int_write_i64_file(i64 %wide)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_x0B7379732E72756E74696D650107010E636C6F7365496E745772697465723301067075626C6963010E636C6F7365496E7457726974657218013A16022D3E0104556E697420013D0109696E7472696E736963() {
entry:
  %ok = call i32 @sollang_legacy_int_close_write_i64_file()
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_x0B7379732E72756E74696D650107010D6F70656E496E745265616465723E01067075626C6963010D6F70656E496E7452656164657201047061746818013A01045465787416022D3E0104556E697420013D0109696E7472696E736963(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  %ok = call i32 @sollang_legacy_int_platform_open_read_file(ptr %data, i64 %length)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define void @sollang_x0B7379732E72756E74696D650107010E636C6F7365496E745265616465723301067075626C6963010E636C6F7365496E7452656164657218013A16022D3E0104556E697420013D0109696E7472696E736963() {
entry:
  %ok = call i32 @sollang_legacy_int_platform_close_read_file()
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}
define i32 @sollang_x0B7379732E72756E74696D650107010A636C6F73657374496E743B01067075626C6963010A636C6F73657374496E74010674617267657418013A0103496E7416022D3E0103496E7420013D0109696E7472696E736963(i32 %arg) {
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
define void @sollang_x0B7379732E72756E74696D65010701057072696E743701067075626C696301057072696E74010576616C756518013A01045465787416022D3E0104556E697420013D0109696E7472696E736963(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 false)
  ret void
}
define void @sollang_x0B7379732E72756E74696D65010701077072696E746C6E3901067075626C696301077072696E746C6E010576616C756518013A01045465787416022D3E0104556E697420013D0109696E7472696E736963(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 true)
  ret void
}
define i32 @sollang_x0B7379732E72756E74696D650107010772656164496E743901067075626C6963010772656164496E74010670726F6D707418013A01045465787416022D3E0103496E7420013D0109696E7472696E736963(%sollang.text %arg) {
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
define void @sollang_x0B7379732E72756E74696D650107010A7365656452616E646F6D3B01067075626C6963010A7365656452616E646F6D010576616C756518013A0103496E7416022D3E0104556E697420013D0109696E7472696E736963(i32 %arg) {
entry:
  %seed = sext i32 %arg to i64
  store i64 %seed, ptr @sollang_stage2_random_state, align 8
  ret void
}
define i32 @sollang_x0B7379732E72756E74696D650107010B72616E646F6D42656C6F774201067075626C6963010B72616E646F6D42656C6F77010C6D61784578636C757369766518013A0103496E7416022D3E0103496E7420013D0109696E7472696E736963(i32 %arg) {
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

define i64 @sollang_x0B7379732E72756E74696D65010701096E6F774D696C6C69732E01067075626C696301096E6F774D696C6C697318013A16022D3E01044C6F6E6720013D0109696E7472696E736963() {
entry:
  %value = call i64 @GetTickCount64()
  ret i64 %value
}
define i64 @sollang_x0B7379732E72756E74696D650107010C7574634E6F774D696C6C69733101067075626C6963010C7574634E6F774D696C6C697318013A16022D3E01044C6F6E6720013D0109696E7472696E736963() {
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
define i8 @sollang_x0B7379732E72756E74696D65010701166D6F6E6F746F6E696353757370656E64506F6C6963793C01067075626C696301166D6F6E6F746F6E696353757370656E64506F6C69637918013A16022D3E010555496E743820013D0109696E7472696E736963() { ret i8 0 }
define void @sollang_x0B7379732E72756E74696D6501070106657072696E743801067075626C69630106657072696E74010576616C756518013A01045465787416022D3E0104556E697420013D0109696E7472696E736963(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_eprint(ptr %data, i64 %length, i1 false)
  ret void
}
define void @sollang_x0B7379732E72756E74696D6501070108657072696E746C6E3A01067075626C69630108657072696E746C6E010576616C756518013A01045465787416022D3E0104556E697420013D0109696E7472696E736963(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_eprintln(ptr %data, i64 %length)
  ret void
}
define void @sollang_x0B7379732E72756E74696D6501070113666C7573685374616E646172644F75747075744701067075626C69630113666C7573685374616E646172644F757470757418013A16022D3E0104556E69740104757365730107436F6E736F6C6520013D0109696E7472696E736963() {
entry:
  call void @sollang_runtime_flush_stdout()
  ret void
}
