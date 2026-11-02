target triple = "x86_64-pc-windows-msvc"
@message = private constant [3 x i8] c"42\0A"
declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare dllimport void @ExitProcess(i32) noreturn
define void @sollang_start() {
entry:
  %written = alloca i32, align 4
  %handle = call ptr @GetStdHandle(i32 -11)
  %ok = call i32 @WriteFile(ptr %handle, ptr @message, i32 3, ptr %written, ptr null)
  call void @ExitProcess(i32 0)
  unreachable
}
declare dllimport i32 @CoInitializeEx(ptr, i32)
declare dllimport i32 @WSAStartup(i16, ptr)
declare dllimport i32 @BCryptGenRandom(ptr, ptr, i32, i32)
