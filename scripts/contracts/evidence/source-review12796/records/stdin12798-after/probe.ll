declare i32 @probe_ReadFile(ptr, ptr, i32, ptr, ptr)
declare i32 @probe_GetLastError()
declare ptr @probe_GetStdHandle(i32)
define internal i32 @sollang_read_stdin(ptr %stdin, ptr %data, i64 %len64, ptr %read) {
entry:
  %exceeds_dword = icmp ugt i64 %len64, 4294967295
  %bounded_len = select i1 %exceeds_dword, i64 4294967295, i64 %len64
  %len = trunc i64 %bounded_len to i32
  %ok = call i32 @probe_ReadFile(ptr %stdin, ptr %data, i32 %len, ptr %read, ptr null)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %success, label %inspect_error

inspect_error:
  %error = call i32 @probe_GetLastError()
  %broken_pipe = icmp eq i32 %error, 109
  br i1 %broken_pipe, label %eof, label %failure

eof:
  store i32 0, ptr %read, align 4
  ret i32 1

success:
  ret i32 1

failure:
  ret i32 0
}
define i64 @exercise(i64 %capacity) {
entry:
  %read = alloca i32
  store i32 123, ptr %read
  %ok = call i32 @sollang_read_stdin(ptr null, ptr null, i64 %capacity, ptr %read)
  %success = icmp ne i32 %ok, 0
  %count = load i32, ptr %read
  %wide = zext i32 %count to i64
  %answer = select i1 %success, i64 %wide, i64 -1
  ret i64 %answer
}
