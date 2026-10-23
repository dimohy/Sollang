declare i32 @probe_ReadFile(ptr, ptr, i32, ptr, ptr)
declare i32 @probe_GetLastError()
declare ptr @probe_GetStdHandle(i32)
define internal i64 @sollang_runtime_read_standard_input_chunk(ptr %data, i64 %capacity) {
entry:
  %handle = call ptr @probe_GetStdHandle(i32 -10)
  %capacity32 = trunc i64 %capacity to i32
  %read_slot = alloca i32, align 4
  %ok = call i32 @probe_ReadFile(ptr %handle, ptr %data, i32 %capacity32, ptr %read_slot, ptr null)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %success, label %inspect_error
inspect_error:
  %error = call i32 @probe_GetLastError()
  %broken_pipe = icmp eq i32 %error, 109
  br i1 %broken_pipe, label %eof, label %failure
eof:
  ret i64 0
success:
  %read32 = load i32, ptr %read_slot, align 4
  %read64 = zext i32 %read32 to i64
  ret i64 %read64
failure:
  ret i64 -1
}
define i64 @exercise(i64 %capacity) {
entry:
  %answer = call i64 @sollang_runtime_read_standard_input_chunk(ptr null, i64 %capacity)
  ret i64 %answer
}
