namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.windows_link_policy",
    "selfhost/generated/windows_link_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/WindowsLinkPolicy.cs")]
internal static class WindowsLinkPolicy
{
    internal const string EntryPointName = "sollang_start";

    public static string EntryPoint() => EntryPointName;
    public static ulong TargetBytesPerPartition() => 1048576UL;

    public static string ObjectArguments() => "-target;x86_64-pc-windows-msvc;:optimization:;-fno-addrsig;-mno-stack-arg-probe;-Werror;-Wno-override-module";
    public static string BitcodeArguments() => "-target;x86_64-pc-windows-msvc;:optimization:;-flto=full;-emit-llvm;-Werror;-Wno-override-module";
    public static string LinkArguments() => "/nologo;/machine:x64;/nodefaultlib;/opt:ref;/opt:icf;/fixed;/stack:8388608,65536;/merge:.rdata=.text;/merge:.pdata=.text;/merge:.xdata=.text";
    public static string ExecutableArguments() => "/subsystem:console;/entry:" + EntryPointName;
    public static string LibraryArguments() => "/dll;/noentry";

    // Rows: base name; DLL; optional declaration prefix; comma-separated exports.
    // Row order is both import-library creation order and final link order.
    public static string ImportLibraries() => "kernel32;kernel32.dll;;GetStdHandle,ExitProcess,GetConsoleMode,WriteConsoleW,CreateProcessW,GetProcessId,GetExitCodeProcess,TerminateProcess,CreatePipe,ReadFile,GetOverlappedResult,WriteFile,CreateFileA,CreateFileW,CloseHandle,GetCurrentProcess,GetCurrentProcessId,DuplicateHandle,SetFilePointerEx,GetFileSizeEx,GetFinalPathNameByHandleW,GetFullPathNameW,GetFileInformationByHandle,SetEndOfFile,CreateFileMappingA,MapViewOfFile,FlushViewOfFile,FlushFileBuffers,MoveFileExA,MoveFileExW,DeleteFileA,DeleteFileW,UnmapViewOfFile,GetTickCount64,GetSystemTimePreciseAsFileTime,Sleep,GetCommandLineW,WideCharToMultiByte,MultiByteToWideChar,GetEnvironmentStringsW,FreeEnvironmentStringsW,CompareStringOrdinal,GetEnvironmentVariableW,GetLastError,SetLastError,LoadLibraryA,GetProcAddress,CreateIoCompletionPort,GetQueuedCompletionStatusEx,PostQueuedCompletionStatus,CancelIoEx,SetFileCompletionNotificationModes,FreeLibrary,CreateDirectoryA,CreateDirectoryW,GetFileAttributesA,GetFileAttributesW,FindFirstFileA,FindFirstFileW,FindNextFileA,FindNextFileW,FindClose,LocalFree,GetProcessHeap,HeapAlloc,HeapFree,CreateThread,CreateEventA,SetEvent,SetConsoleMode,ReadConsoleInputW,CancelSynchronousIo,ResetEvent,CreateSemaphoreA,ReleaseSemaphore,GetActiveProcessorCount,WaitForSingleObject,AcquireSRWLockExclusive,ReleaseSRWLockExclusive,InitializeConditionVariable,SleepConditionVariableSRW,WakeAllConditionVariable,__chkstk|shell32;shell32.dll;;CommandLineToArgvW|ole32;ole32.dll;declare dllimport i32 @CoInitializeEx;CoInitializeEx,CoUninitialize,CoCreateInstance|ws2_32;ws2_32.dll;declare dllimport i32 @WSAStartup;WSAStartup,WSACleanup,WSAGetLastError,WSASocketW,WSADuplicateSocketW,closesocket,bind,getsockname,getpeername,listen,accept,connect,recv,WSARecv,send,WSASend,WSAGetOverlappedResult,recvfrom,WSARecvFrom,sendto,shutdown,setsockopt,getsockopt,ioctlsocket,WSAPoll,GetAddrInfoW,FreeAddrInfoW,inet_pton,inet_ntop|bcrypt;bcrypt.dll;declare dllimport i32 @BCryptGenRandom;BCryptGenRandom|ucrtbase;ucrtbase.dll;;_wspawnvp,memcpy,strlen";
}
