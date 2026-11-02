namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.runtime",
    "selfhost/llvm/runtime.slg",
    "src/Sollang.Compiler/Shared/Policies/NativeRuntimePolicy.cs", MultilineText = true, Region = "NativeRuntime")]
internal static class NativeRuntimePolicy
{
    public static string WindowsEntryPoint() => WindowsLinkPolicy.EntryPointName;
    public static string WindowsFloatingPointGlobal() => "@_fltused = global i32 0";

    public static string LegacyReadFunction() =>
        """
        define internal %sollang.read_int_result @sollang_read_i64(ptr %stdin, ptr %read) #0 {
        entry:
          %buf = alloca [64 x i8], align 1
          %ok = call i32 @sollang_read_stdin(ptr %stdin, ptr %buf, i64 64, ptr %read)
          %read_ok = icmp ne i32 %ok, 0
          br i1 %read_ok, label %prepare, label %fail

        prepare:
          %read32 = load i32, ptr %read, align 4
          %len = zext i32 %read32 to i64
          br label %skip

        skip:
          %skip_idx = phi i64 [ 0, %prepare ], [ %skip_next, %skip_ws ]
          %skip_has = icmp ult i64 %skip_idx, %len
          br i1 %skip_has, label %skip_char, label %fail

        skip_char:
          %skip_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %skip_idx
          %skip_ch = load i8, ptr %skip_ptr, align 1
          %skip_sp = icmp eq i8 %skip_ch, 32
          %skip_tab = icmp eq i8 %skip_ch, 9
          %skip_cr = icmp eq i8 %skip_ch, 13
          %skip_lf = icmp eq i8 %skip_ch, 10
          %skip_sp_tab = or i1 %skip_sp, %skip_tab
          %skip_cr_lf = or i1 %skip_cr, %skip_lf
          %skip_is_ws = or i1 %skip_sp_tab, %skip_cr_lf
          br i1 %skip_is_ws, label %skip_ws, label %digit_entry

        skip_ws:
          %skip_next = add i64 %skip_idx, 1
          br label %skip

        digit_entry:
          %first_ge = icmp uge i8 %skip_ch, 48
          %first_le = icmp ule i8 %skip_ch, 57
          %first_digit = and i1 %first_ge, %first_le
          br i1 %first_digit, label %digits, label %fail

        digits:
          %digit_idx = phi i64 [ %skip_idx, %digit_entry ], [ %digit_next, %digit_continue ]
          %value = phi i64 [ 0, %digit_entry ], [ %value_next, %digit_continue ]
          %digit_has = icmp ult i64 %digit_idx, %len
          br i1 %digit_has, label %digit_char, label %success

        digit_char:
          %digit_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %digit_idx
          %digit_ch = load i8, ptr %digit_ptr, align 1
          %digit_ge = icmp uge i8 %digit_ch, 48
          %digit_le = icmp ule i8 %digit_ch, 57
          %is_digit = and i1 %digit_ge, %digit_le
          br i1 %is_digit, label %digit_continue, label %trail_entry

        digit_continue:
          %digit64 = zext i8 %digit_ch to i64
          %digit_value = sub i64 %digit64, 48
          %value_x10 = mul i64 %value, 10
          %value_next = add i64 %value_x10, %digit_value
          %digit_next = add i64 %digit_idx, 1
          br label %digits

        trail_entry:
          br label %trail

        trail:
          %trail_idx = phi i64 [ %digit_idx, %trail_entry ], [ %trail_next, %trail_ws ]
          %trail_has = icmp ult i64 %trail_idx, %len
          br i1 %trail_has, label %trail_char, label %success

        trail_char:
          %trail_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %trail_idx
          %trail_ch = load i8, ptr %trail_ptr, align 1
          %trail_sp = icmp eq i8 %trail_ch, 32
          %trail_tab = icmp eq i8 %trail_ch, 9
          %trail_cr = icmp eq i8 %trail_ch, 13
          %trail_lf = icmp eq i8 %trail_ch, 10
          %trail_sp_tab = or i1 %trail_sp, %trail_tab
          %trail_cr_lf = or i1 %trail_cr, %trail_lf
          %trail_is_ws = or i1 %trail_sp_tab, %trail_cr_lf
          br i1 %trail_is_ws, label %trail_ws, label %fail

        trail_ws:
          %trail_next = add i64 %trail_idx, 1
          br label %trail

        success:
          %success_value = phi i64 [ %value, %digits ], [ %value, %trail ]
          %success0 = insertvalue %sollang.read_int_result poison, i64 %success_value, 0
          %success1 = insertvalue %sollang.read_int_result %success0, i32 1, 1
          ret %sollang.read_int_result %success1

        fail:
          %fail0 = insertvalue %sollang.read_int_result poison, i64 0, 0
          %fail1 = insertvalue %sollang.read_int_result %fail0, i32 0, 1
          ret %sollang.read_int_result %fail1
        }
        """;

    public static string LegacyWindowsReadFunction() =>
        """
        define internal i32 @sollang_read_stdin(ptr %stdin, ptr %data, i64 %len64, ptr %read) #0 {
        entry:
          %exceeds_dword = icmp ugt i64 %len64, 4294967295
          %bounded_len = select i1 %exceeds_dword, i64 4294967295, i64 %len64
          %len = trunc i64 %bounded_len to i32
          %ok = call i32 @ReadFile(ptr %stdin, ptr %data, i32 %len, ptr %read, ptr null)
          %succeeded = icmp ne i32 %ok, 0
          br i1 %succeeded, label %success, label %inspect_error

        inspect_error:
          %error = call i32 @GetLastError()
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
        """;
    public static string WindowsStandardHandles() =>
        """
        handles:
          %has_stdin_override = icmp ne ptr %stdin_override, null
          %stdin_default = call ptr @GetStdHandle(i32 -10)
          %stdin_source = select i1 %has_stdin_override, ptr %stdin_override, ptr %stdin_default
          %has_stdout_override = icmp ne ptr %stdout_override, null
          %stdout_default = call ptr @GetStdHandle(i32 -11)
          %stdout_source = select i1 %has_stdout_override, ptr %stdout_override, ptr %stdout_default
          %has_stderr_override = icmp ne ptr %stderr_override, null
          %stderr_default = call ptr @GetStdHandle(i32 -12)
          %stderr_source = select i1 %has_stderr_override, ptr %stderr_override, ptr %stderr_default
        """;
    public static string MemoryFunctions() =>
        """
        define dso_local ptr @memset(ptr %dest, i32 %value, i64 %count) #0 {
        entry:
          %byte = trunc i32 %value to i8
          br label %loop

        loop:
          %i = phi i64 [ 0, %entry ], [ %next, %body ]
          %active = icmp ult i64 %i, %count
          br i1 %active, label %body, label %done

        body:
          %slot = getelementptr i8, ptr %dest, i64 %i
          store i8 %byte, ptr %slot, align 1
          %next = add i64 %i, 1
          br label %loop

        done:
          ret ptr %dest
        }

        define dso_local ptr @memcpy(ptr %dest, ptr %source, i64 %count) #0 {
        entry:
          br label %loop

        loop:
          %i = phi i64 [ 0, %entry ], [ %next, %body ]
          %active = icmp ult i64 %i, %count
          br i1 %active, label %body, label %done

        body:
          %src_slot = getelementptr i8, ptr %source, i64 %i
          %dst_slot = getelementptr i8, ptr %dest, i64 %i
          %byte = load i8, ptr %src_slot, align 1
          store i8 %byte, ptr %dst_slot, align 1
          %next = add i64 %i, 1
          br label %loop

        done:
          ret ptr %dest
        }

        define dso_local ptr @memmove(ptr %dest, ptr %source, i64 %count) #0 {
        entry:
          %same = icmp eq ptr %dest, %source
          %empty = icmp eq i64 %count, 0
          %done_early = or i1 %same, %empty
          br i1 %done_early, label %done, label %choose_direction

        choose_direction:
          %forward = icmp ult ptr %dest, %source
          br i1 %forward, label %forward_loop, label %backward_loop

        forward_loop:
          %forward_i = phi i64 [ 0, %choose_direction ], [ %forward_next, %forward_body ]
          %forward_active = icmp ult i64 %forward_i, %count
          br i1 %forward_active, label %forward_body, label %done

        forward_body:
          %forward_src = getelementptr i8, ptr %source, i64 %forward_i
          %forward_dst = getelementptr i8, ptr %dest, i64 %forward_i
          %forward_byte = load i8, ptr %forward_src, align 1
          store i8 %forward_byte, ptr %forward_dst, align 1
          %forward_next = add i64 %forward_i, 1
          br label %forward_loop

        backward_loop:
          %backward_i = phi i64 [ %count, %choose_direction ], [ %backward_next, %backward_body ]
          %backward_active = icmp ugt i64 %backward_i, 0
          br i1 %backward_active, label %backward_body, label %done

        backward_body:
          %backward_next = sub i64 %backward_i, 1
          %backward_src = getelementptr i8, ptr %source, i64 %backward_next
          %backward_dst = getelementptr i8, ptr %dest, i64 %backward_next
          %backward_byte = load i8, ptr %backward_src, align 1
          store i8 %backward_byte, ptr %backward_dst, align 1
          br label %backward_loop

        done:
          ret ptr %dest
        }
        """;
}
