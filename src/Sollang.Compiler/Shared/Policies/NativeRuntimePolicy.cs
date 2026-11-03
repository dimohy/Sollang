namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.runtime",
    "selfhost/llvm/runtime.slg",
    "src/Sollang.Compiler/Shared/Policies/NativeRuntimePolicy.cs", MultilineText = true, Region = "NativeRuntime")]
internal static class NativeRuntimePolicy
{
    public static ulong TaskResultAddressField() => 21UL;
    public static ulong TaskResultCompletionField() => 22UL;

    internal const string AsyncFileOpenReadMethod = "openReadAsync";
    internal const string AsyncFileOpenWriteMethod = "openWriteAsync";
    internal const string AsyncFileReadBufferMethod = "readIntoAtAsync";
    internal const string AsyncFileWriteBufferMethod = "writeRangeAtAsync";
    internal const string AsyncFileOpenReadQualified = "sys.file." + AsyncFileOpenReadMethod;
    internal const string AsyncFileOpenWriteQualified = "sys.file." + AsyncFileOpenWriteMethod;
    internal const string AsyncFileReadBufferQualified = "sys.file.File." + AsyncFileReadBufferMethod;
    internal const string AsyncFileWriteBufferQualified = "sys.file.FileWriter." + AsyncFileWriteBufferMethod;

    public static string AsyncFileOpenReadName() => AsyncFileOpenReadMethod;
    public static string AsyncFileOpenWriteName() => AsyncFileOpenWriteMethod;
    public static string AsyncFileReadBufferName() => AsyncFileReadBufferMethod;
    public static string AsyncFileWriteBufferName() => AsyncFileWriteBufferMethod;
    public static ulong AsyncFileOpenReadOperation() => 3UL;
    public static ulong AsyncFileOpenWriteOperation() => 4UL;
    public static ulong AsyncFileReadBufferOperation() => 5UL;
    public static ulong AsyncFileWriteBufferOperation() => 6UL;

    public static string AsyncFileOpenTaskStartFunction() =>
        """
        define internal %sollang.task @sollang_file_open_task_start(i64 %context_size, ptr %path, i64 %length, i32 %operation, ptr %complete) #0 {
        entry:
          %allocation_size = add i64 %context_size, %length
          %context = call ptr @sollang_alloc(i64 %allocation_size)
          %allocated = icmp ne ptr %context, null
          br i1 %allocated, label %initialize, label %allocation_failed
        allocation_failed:
          call void @llvm.trap()
          unreachable
        initialize:
          %owned_path = getelementptr i8, ptr %context, i64 %context_size
          call void @llvm.memcpy.p0.p0.i64(ptr %owned_path, ptr %path, i64 %length, i1 false)
          %handle = call ptr @sollang_task_start(ptr @sollang_file_operation_task_worker, ptr @sollang_free, ptr @sollang_file_operation_task_cancel, ptr %context)
          %started = icmp ne ptr %handle, null
          br i1 %started, label %ready, label %start_failed
        start_failed:
          call void @sollang_free(ptr %context)
          call void @llvm.trap()
          unreachable
        ready:
          %size_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 11
          store i32 0, ptr %size_slot, align 4
          %data_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 13
          store ptr %owned_path, ptr %data_slot, align 8
          %file_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 17
          store i64 -1, ptr %file_slot, align 8
          %length_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 18
          store i64 %length, ptr %length_slot, align 8
          %ownership_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 19
          store i32 2, ptr %ownership_slot, align 4
          %operation_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 20
          store i32 %operation, ptr %operation_slot, align 4
          %complete_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 22
          store ptr %complete, ptr %complete_slot, align 8
          %task0 = insertvalue %sollang.task poison, ptr %handle, 0
          %task = insertvalue %sollang.task %task0, ptr %context, 1
          ret %sollang.task %task
        }
        """;

    public static string AsyncFileBufferTaskStartFunction() =>
        """
        define internal %sollang.task @sollang_file_buffer_task_start(i64 %context_size, ptr %cancel, ptr %complete, i64 %source_handle, ptr %data, i64 %buffer_length, i64 %input_offset, i64 %length, i64 %offset, i1 %cancelled, i32 %requested_operation) #0 {
        entry:
          %context = call ptr @sollang_alloc(i64 %context_size)
          %allocated = icmp ne ptr %context, null
          br i1 %allocated, label %initialize, label %allocation_failed
        allocation_failed:
          call void @llvm.trap()
          unreachable
        initialize:
          %handle = call ptr @sollang_task_start(ptr @sollang_file_operation_task_worker, ptr @sollang_free, ptr %cancel, ptr %context)
          %started = icmp ne ptr %handle, null
          br i1 %started, label %ready, label %start_failed
        start_failed:
          call void @sollang_free(ptr %context)
          call void @llvm.trap()
          unreachable
        ready:
          %offset_in_bounds = icmp ule i64 %input_offset, %buffer_length
          %remaining = sub i64 %buffer_length, %input_offset
          %length_in_bounds = icmp ule i64 %length, %remaining
          %range_valid = and i1 %offset_in_bounds, %length_in_bounds
          %valid_operation = select i1 %range_valid, i32 %requested_operation, i32 7
          %operation = select i1 %cancelled, i32 8, i32 %valid_operation
          %length_fits = icmp ule i64 %length, 2147483647
          %bounded_length = select i1 %length_fits, i64 %length, i64 2147483647
          %size = trunc i64 %bounded_length to i32
          %size_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 11
          store i32 %size, ptr %size_slot, align 4
          %pointer = getelementptr i8, ptr %data, i64 %input_offset
          %pointer_value = ptrtoint ptr %pointer to i64
          %data_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 13
          store i64 %pointer_value, ptr %data_slot, align 8
          %owned_handle = call i64 @sollang_platform_duplicate_owned_file(i64 %source_handle)
          %file_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 17
          store i64 %owned_handle, ptr %file_slot, align 8
          %offset_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 18
          store i64 %offset, ptr %offset_slot, align 8
          %ownership_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 19
          store i32 1, ptr %ownership_slot, align 4
          %operation_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 20
          store i32 %operation, ptr %operation_slot, align 4
          %complete_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 22
          store ptr %complete, ptr %complete_slot, align 8
          %task0 = insertvalue %sollang.task poison, ptr %handle, 0
          %task = insertvalue %sollang.task %task0, ptr %context, 1
          ret %sollang.task %task
        }
        """;

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

    // One compiled environment ABI and platform helper body for CSharp and SLG.
    public static string EnvironmentResultType() => "%sollang.environment_result = type { ptr, i64, i1, i1 }";

    public static string EnvironmentWindowsGlobals() =>
        """
        @sollang_environment_allocations = internal global ptr null
        @sollang_environment_empty = internal constant [1 x i8] zeroinitializer, align 1
        """;

    public static string EnvironmentWindowsFunctions() =>
        """
        define internal i1 @sollang_track_environment_allocation(ptr %allocation) #0 {
        entry:
          %node = call ptr @sollang_alloc(i64 16)
          %ok = icmp ne ptr %node, null
          br i1 %ok, label %store, label %fail

        store:
          store ptr %allocation, ptr %node, align 8
          %next_slot = getelementptr i8, ptr %node, i64 8
          %initial_head = load atomic ptr, ptr @sollang_environment_allocations acquire, align 8
          br label %publish

        publish:
          %head = phi ptr [ %initial_head, %store ], [ %observed_head, %publish ]
          store ptr %head, ptr %next_slot, align 8
          %exchange = cmpxchg ptr @sollang_environment_allocations, ptr %head, ptr %node acq_rel acquire, align 8
          %observed_head = extractvalue { ptr, i1 } %exchange, 0
          %published = extractvalue { ptr, i1 } %exchange, 1
          br i1 %published, label %done, label %publish

        done:
          ret i1 true

        fail:
          ret i1 false
        }

        define internal %sollang.environment_result @sollang_environment(ptr %name, i64 %name_len) #0 {
        entry:
          %empty = icmp eq i64 %name_len, 0
          br i1 %empty, label %missing, label %check_length

        check_length:
          %name_fits_i32 = icmp ule i64 %name_len, 2147483647
          br i1 %name_fits_i32, label %validate, label %error

        validate:
          %vi = phi i64 [ 0, %check_length ], [ %vnext, %valid_byte ]
          %validated = icmp eq i64 %vi, %name_len
          br i1 %validated, label %key_size, label %check_byte

        check_byte:
          %name_byte_ptr = getelementptr i8, ptr %name, i64 %vi
          %name_byte = load i8, ptr %name_byte_ptr, align 1
          %name_byte_valid = icmp ne i8 %name_byte, 0
          br i1 %name_byte_valid, label %valid_byte, label %error

        valid_byte:
          %vnext = add i64 %vi, 1
          br label %validate

        key_size:
          %name_len32 = trunc i64 %name_len to i32
          %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %name, i32 %name_len32, ptr null, i32 0)
          %wide_valid = icmp sgt i32 %wide_chars, 0
          br i1 %wide_valid, label %key_alloc, label %error

        key_alloc:
          %wide_chars_plus_null = add i32 %wide_chars, 1
          %wide_chars64 = zext i32 %wide_chars_plus_null to i64
          %key_bytes = mul i64 %wide_chars64, 2
          %wide_key = call ptr @sollang_alloc(i64 %key_bytes)
          %key_ok = icmp ne ptr %wide_key, null
          br i1 %key_ok, label %key_convert, label %error

        key_convert:
          %key_written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %name, i32 %name_len32, ptr %wide_key, i32 %wide_chars)
          %key_converted = icmp eq i32 %key_written, %wide_chars
          br i1 %key_converted, label %key_terminate, label %free_key_error

        key_terminate:
          %key_end = getelementptr i16, ptr %wide_key, i32 %wide_chars
          store i16 0, ptr %key_end, align 2
          call void @SetLastError(i32 0)
          %required = call i32 @GetEnvironmentVariableW(ptr %wide_key, ptr null, i32 0)
          %last_error = call i32 @GetLastError()
          %has_size = icmp ne i32 %required, 0
          br i1 %has_size, label %value_alloc, label %zero_result

        zero_result:
          call void @sollang_free(ptr %wide_key)
          br label %classify_zero

        classify_zero:
          %zero_error = phi i32 [ %last_error, %zero_result ], [ %value_error, %free_wide_empty ]
          %not_found = icmp eq i32 %zero_error, 203
          br i1 %not_found, label %missing, label %check_empty_value

        check_empty_value:
          %empty_succeeded = icmp eq i32 %zero_error, 0
          br i1 %empty_succeeded, label %empty_present, label %error

        empty_present:
          %empty_ptr = getelementptr inbounds [1 x i8], ptr @sollang_environment_empty, i64 0, i64 0
          %e0 = insertvalue %sollang.environment_result zeroinitializer, ptr %empty_ptr, 0
          %e1 = insertvalue %sollang.environment_result %e0, i1 true, 2
          %e2 = insertvalue %sollang.environment_result %e1, i1 true, 3
          ret %sollang.environment_result %e2

        value_alloc:
          %required64 = zext i32 %required to i64
          %wide_bytes = mul i64 %required64, 2
          %wide_value = call ptr @sollang_alloc(i64 %wide_bytes)
          %wide_value_ok = icmp ne ptr %wide_value, null
          br i1 %wide_value_ok, label %value_read, label %free_key_error

        value_read:
          call void @SetLastError(i32 0)
          %value_chars = call i32 @GetEnvironmentVariableW(ptr %wide_key, ptr %wide_value, i32 %required)
          %value_error = call i32 @GetLastError()
          call void @sollang_free(ptr %wide_key)
          %value_empty = icmp eq i32 %value_chars, 0
          br i1 %value_empty, label %free_wide_empty, label %value_read_check

        free_wide_empty:
          call void @sollang_free(ptr %wide_value)
          br label %classify_zero

        value_read_check:
          %value_read_ok = icmp ult i32 %value_chars, %required
          br i1 %value_read_ok, label %utf8_size, label %free_wide_error

        utf8_size:
          %utf8_bytes32 = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide_value, i32 %value_chars, ptr null, i32 0, ptr null, ptr null)
          %utf8_size_ok = icmp sgt i32 %utf8_bytes32, 0
          br i1 %utf8_size_ok, label %utf8_alloc, label %free_wide_error

        utf8_alloc:
          %utf8_bytes = zext i32 %utf8_bytes32 to i64
          %utf8 = call ptr @sollang_alloc(i64 %utf8_bytes)
          %utf8_ok = icmp ne ptr %utf8, null
          br i1 %utf8_ok, label %utf8_convert, label %free_wide_error

        utf8_convert:
          %utf8_written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide_value, i32 %value_chars, ptr %utf8, i32 %utf8_bytes32, ptr null, ptr null)
          call void @sollang_free(ptr %wide_value)
          %utf8_converted = icmp eq i32 %utf8_written, %utf8_bytes32
          br i1 %utf8_converted, label %track, label %free_utf8_error

        track:
          %tracked = call i1 @sollang_track_environment_allocation(ptr %utf8)
          br i1 %tracked, label %present, label %free_utf8_error

        present:
          %p0 = insertvalue %sollang.environment_result poison, ptr %utf8, 0
          %p1 = insertvalue %sollang.environment_result %p0, i64 %utf8_bytes, 1
          %p2 = insertvalue %sollang.environment_result %p1, i1 true, 2
          %p3 = insertvalue %sollang.environment_result %p2, i1 true, 3
          ret %sollang.environment_result %p3

        free_utf8_error:
          call void @sollang_free(ptr %utf8)
          br label %error

        free_wide_error:
          call void @sollang_free(ptr %wide_value)
          br label %error

        free_key_error:
          call void @sollang_free(ptr %wide_key)
          br label %error

        missing:
          %m0 = insertvalue %sollang.environment_result zeroinitializer, i1 true, 3
          ret %sollang.environment_result %m0

        error:
          ret %sollang.environment_result zeroinitializer
        }

        define internal void @sollang_dispose_environment() #0 {
        entry:
          %head = load ptr, ptr @sollang_environment_allocations, align 8
          br label %loop

        loop:
          %node = phi ptr [ %head, %entry ], [ %next, %free_node ]
          %done = icmp eq ptr %node, null
          br i1 %done, label %finish, label %free_node

        free_node:
          %allocation = load ptr, ptr %node, align 8
          %next_slot = getelementptr i8, ptr %node, i64 8
          %next = load ptr, ptr %next_slot, align 8
          call void @sollang_free(ptr %allocation)
          call void @sollang_free(ptr %node)
          br label %loop

        finish:
          ret void
        }
        """;

    public static string EnvironmentLinuxFunctions() =>
        """
        define internal %sollang.environment_result @sollang_environment(ptr %name, i64 %name_len) #0 {
        entry:
          %bytes = add i64 %name_len, 1
          %key = call ptr @sollang_alloc(i64 %bytes)
          %allocated = icmp ne ptr %key, null
          br i1 %allocated, label %copy, label %error

        copy:
          %i = phi i64 [ 0, %entry ], [ %next, %store_byte ]
          %done = icmp eq i64 %i, %name_len
          br i1 %done, label %terminate, label %copy_byte

        copy_byte:
          %source = getelementptr i8, ptr %name, i64 %i
          %byte = load i8, ptr %source, align 1
          %valid = icmp ne i8 %byte, 0
          br i1 %valid, label %store_byte, label %invalid_key

        store_byte:
          %destination = getelementptr i8, ptr %key, i64 %i
          store i8 %byte, ptr %destination, align 1
          %next = add i64 %i, 1
          br label %copy

        terminate:
          %end = getelementptr i8, ptr %key, i64 %name_len
          store i8 0, ptr %end, align 1
          %value = call ptr @getenv(ptr %key)
          call void @sollang_free(ptr %key)
          %found = icmp ne ptr %value, null
          br i1 %found, label %length, label %missing

        length:
          %j = phi i64 [ 0, %terminate ], [ %j_next, %length_more ]
          %value_byte_ptr = getelementptr i8, ptr %value, i64 %j
          %value_byte = load i8, ptr %value_byte_ptr, align 1
          %length_done = icmp eq i8 %value_byte, 0
          br i1 %length_done, label %present, label %length_more

        length_more:
          %j_next = add i64 %j, 1
          br label %length

        present:
          %p0 = insertvalue %sollang.environment_result poison, ptr %value, 0
          %p1 = insertvalue %sollang.environment_result %p0, i64 %j, 1
          %p2 = insertvalue %sollang.environment_result %p1, i1 true, 2
          %p3 = insertvalue %sollang.environment_result %p2, i1 true, 3
          ret %sollang.environment_result %p3

        missing:
          %m0 = insertvalue %sollang.environment_result zeroinitializer, i1 true, 3
          ret %sollang.environment_result %m0

        invalid_key:
          call void @sollang_free(ptr %key)
          br label %error

        error:
          ret %sollang.environment_result zeroinitializer
        }
        """;

    // Bounded concurrent joins share the same platform and lifecycle instructions.

    // Both backends select worker-backed joins from the same compiled decision.
    public static bool StreamJoinUsesWorkers(bool merge, bool latest, bool hasEvent) =>
        (merge || latest) && hasEvent;

    public static string StreamJoinWorkerFunctions() =>
        """
        define internal void @sollang_stream_join_enqueue_locked(ptr %runtime, i32 %event) #0 {
        entry:
          %count = load i32, ptr %runtime, align 4
          %tail_address = getelementptr i8, ptr %runtime, i64 12
          %tail = load i32, ptr %tail_address, align 4
          %queue_address = getelementptr i8, ptr %runtime, i64 72
          %queue = load ptr, ptr %queue_address, align 8
          %event_address = getelementptr i32, ptr %queue, i32 %tail
          store i32 %event, ptr %event_address, align 4
          %next_tail_unwrapped = add i32 %tail, 1
          %next_tail = urem i32 %next_tail_unwrapped, %count
          store i32 %next_tail, ptr %tail_address, align 4
          %queued_address = getelementptr i8, ptr %runtime, i64 16
          %queued = load i32, ptr %queued_address, align 4
          %queue_full = icmp eq i32 %queued, %count
          br i1 %queue_full, label %invalid, label %append

        append:
          %next_queued = add i32 %queued, 1
          store i32 %next_queued, ptr %queued_address, align 4
          ret void

        invalid:
          call void @llvm.trap()
          unreachable
        }

        define internal void @sollang_stream_join_worker_exit_locked(ptr %runtime) #0 {
        entry:
          %exited_address = getelementptr i8, ptr %runtime, i64 104
          %exited = load i32, ptr %exited_address, align 4
          %next_exited = add i32 %exited, 1
          store i32 %next_exited, ptr %exited_address, align 4
          call void @sollang_stream_join_wake_all(ptr %runtime)
          call void @sollang_stream_join_unlock(ptr %runtime)
          ret void
        }

        define internal void @sollang_stream_join_worker_exit(ptr %runtime) #0 {
        entry:
          call void @sollang_stream_join_lock(ptr %runtime)
          call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
          ret void
        }

        define internal void @sollang_stream_join_worker_run(ptr %argument) #0 {
        entry:
          %runtime = load ptr, ptr %argument, align 8
          %index_address = getelementptr i8, ptr %argument, i64 8
          %index = load i32, ptr %index_address, align 4
          %item_size_address = getelementptr i8, ptr %runtime, i64 24
          %item_size = load i64, ptr %item_size_address, align 8
          %slots_address = getelementptr i8, ptr %runtime, i64 56
          %slots = load ptr, ptr %slots_address, align 8
          %index64 = zext i32 %index to i64
          %slot_offset = mul i64 %index64, %item_size
          %slot = getelementptr i8, ptr %slots, i64 %slot_offset
          %pull_address = getelementptr i8, ptr %runtime, i64 32
          %pull = load ptr, ptr %pull_address, align 8
          %drop_address = getelementptr i8, ptr %runtime, i64 40
          %drop = load ptr, ptr %drop_address, align 8
          %owner_address = getelementptr i8, ptr %runtime, i64 48
          %owner = load ptr, ptr %owner_address, align 8
          %full_array_address = getelementptr i8, ptr %runtime, i64 64
          %full_array = load ptr, ptr %full_array_address, align 8
          %full_address = getelementptr i8, ptr %full_array, i32 %index
          br label %check

        check:
          call void @sollang_stream_join_lock(ptr %runtime)
          %cancel_address = getelementptr i8, ptr %runtime, i64 20
          %cancelled = load i32, ptr %cancel_address, align 4
          %active = icmp eq i32 %cancelled, 0
          br i1 %active, label %register_pull, label %cancelled_before_pull

        register_pull:
          %pulling_address = getelementptr i8, ptr %runtime, i64 100
          %pulling = load i32, ptr %pulling_address, align 4
          %next_pulling = add i32 %pulling, 1
          store i32 %next_pulling, ptr %pulling_address, align 4
          call void @sollang_stream_join_unlock(ptr %runtime)
          br label %pull_value

        cancelled_before_pull:
          call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
          ret void

        pull_value:
          %has_value = call i1 %pull(ptr %owner, i32 %index, ptr %slot)
          call void @sollang_stream_join_lock(ptr %runtime)
          %pulling_after = load i32, ptr %pulling_address, align 4
          %next_pulling_after = sub i32 %pulling_after, 1
          store i32 %next_pulling_after, ptr %pulling_address, align 4
          call void @sollang_stream_join_wake_all(ptr %runtime)
          %cancelled_after_pull = load i32, ptr %cancel_address, align 4
          %cancelled_now = icmp ne i32 %cancelled_after_pull, 0
          br i1 %has_value, label %publish_or_drop, label %complete_or_cancel

        publish_or_drop:
          br i1 %cancelled_now, label %drop_unpublished, label %publish

        drop_unpublished:
          call void @sollang_stream_join_unlock(ptr %runtime)
          call void %drop(ptr %owner, i32 %index, ptr %slot)
          call void @sollang_stream_join_worker_exit(ptr %runtime)
          ret void

        publish:
          store i8 1, ptr %full_address, align 1
          call void @sollang_stream_join_enqueue_locked(ptr %runtime, i32 %index)
          call void @sollang_stream_join_wake_all(ptr %runtime)
          br label %backpressure

        backpressure:
          %full = load i8, ptr %full_address, align 1
          %still_full = icmp ne i8 %full, 0
          %cancelled_while_full = load i32, ptr %cancel_address, align 4
          %not_cancelled = icmp eq i32 %cancelled_while_full, 0
          %must_wait = and i1 %still_full, %not_cancelled
          br i1 %must_wait, label %wait_release, label %released

        wait_release:
          call void @sollang_stream_join_wait(ptr %runtime)
          br label %backpressure

        released:
          call void @sollang_stream_join_unlock(ptr %runtime)
          br i1 %not_cancelled, label %check, label %cancelled_after_release

        cancelled_after_release:
          call void @sollang_stream_join_worker_exit(ptr %runtime)
          ret void

        complete_or_cancel:
          br i1 %cancelled_now, label %unlock_done, label %complete

        complete:
          %active_address = getelementptr i8, ptr %runtime, i64 4
          %active_count = load i32, ptr %active_address, align 4
          %next_active = sub i32 %active_count, 1
          store i32 %next_active, ptr %active_address, align 4
          %completion_event = or i32 %index, -2147483648
          call void @sollang_stream_join_enqueue_locked(ptr %runtime, i32 %completion_event)
          call void @sollang_stream_join_wake_all(ptr %runtime)
          call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
          ret void

        unlock_done:
          call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
          ret void
        }
        """;

    public static string StreamJoinLifecycleFunctions() =>
        """
        define internal ptr @sollang_stream_join_runtime_create(i32 %count, i64 %item_size, ptr %pull, ptr %drop, ptr %owner) #0 {
        entry:
          %valid_count = icmp sgt i32 %count, 0
          %valid_size = icmp ugt i64 %item_size, 0
          %valid = and i1 %valid_count, %valid_size
          br i1 %valid, label %allocate, label %invalid

        allocate:
          %runtime = call ptr @sollang_alloc(i64 208)
          %runtime_ok = icmp ne ptr %runtime, null
          br i1 %runtime_ok, label %allocate_arrays, label %invalid

        allocate_arrays:
          call void @llvm.memset.p0.i64(ptr %runtime, i8 0, i64 208, i1 false)
          %count64 = zext i32 %count to i64
          %slots_size = mul i64 %count64, %item_size
          %slots = call ptr @sollang_alloc(i64 %slots_size)
          %full = call ptr @sollang_alloc(i64 %count64)
          %queue_size = mul i64 %count64, 4
          %queue = call ptr @sollang_alloc(i64 %queue_size)
          %thread_size = mul i64 %count64, 8
          %threads = call ptr @sollang_alloc(i64 %thread_size)
          %argument_size = mul i64 %count64, 16
          %arguments = call ptr @sollang_alloc(i64 %argument_size)
          %slots_ok = icmp ne ptr %slots, null
          %full_ok = icmp ne ptr %full, null
          %queue_ok = icmp ne ptr %queue, null
          %threads_ok = icmp ne ptr %threads, null
          %arguments_ok = icmp ne ptr %arguments, null
          %arrays_ok0 = and i1 %slots_ok, %full_ok
          %arrays_ok1 = and i1 %queue_ok, %threads_ok
          %arrays_ok2 = and i1 %arrays_ok0, %arrays_ok1
          %arrays_ok = and i1 %arrays_ok2, %arguments_ok
          br i1 %arrays_ok, label %initialize, label %free_arrays

        initialize:
          call void @llvm.memset.p0.i64(ptr %full, i8 0, i64 %count64, i1 false)
          store i32 %count, ptr %runtime, align 4
          %active_address = getelementptr i8, ptr %runtime, i64 4
          store i32 %count, ptr %active_address, align 4
          %item_size_address = getelementptr i8, ptr %runtime, i64 24
          store i64 %item_size, ptr %item_size_address, align 8
          %pull_address = getelementptr i8, ptr %runtime, i64 32
          store ptr %pull, ptr %pull_address, align 8
          %drop_address = getelementptr i8, ptr %runtime, i64 40
          store ptr %drop, ptr %drop_address, align 8
          %owner_address = getelementptr i8, ptr %runtime, i64 48
          store ptr %owner, ptr %owner_address, align 8
          %slots_address = getelementptr i8, ptr %runtime, i64 56
          store ptr %slots, ptr %slots_address, align 8
          %full_address = getelementptr i8, ptr %runtime, i64 64
          store ptr %full, ptr %full_address, align 8
          %queue_address = getelementptr i8, ptr %runtime, i64 72
          store ptr %queue, ptr %queue_address, align 8
          %threads_address = getelementptr i8, ptr %runtime, i64 80
          store ptr %threads, ptr %threads_address, align 8
          %arguments_address = getelementptr i8, ptr %runtime, i64 88
          store ptr %arguments, ptr %arguments_address, align 8
          %sync_ok = call i1 @sollang_stream_join_sync_init(ptr %runtime)
          br i1 %sync_ok, label %start_loop, label %free_arrays

        start_loop:
          br label %start

        start:
          %index = phi i32 [ 0, %start_loop ], [ %next_index, %started ]
          %all_started = icmp eq i32 %index, %count
          br i1 %all_started, label %ready, label %start_one

        start_one:
          %index64_start = zext i32 %index to i64
          %argument_offset = mul i64 %index64_start, 16
          %argument = getelementptr i8, ptr %arguments, i64 %argument_offset
          store ptr %runtime, ptr %argument, align 8
          %argument_index = getelementptr i8, ptr %argument, i64 8
          store i32 %index, ptr %argument_index, align 4
          %thread = getelementptr i64, ptr %threads, i32 %index
          %thread_ok = call i1 @sollang_stream_join_thread_start(ptr %thread, ptr %argument)
          br i1 %thread_ok, label %started, label %start_failed

        started:
          %next_index = add i32 %index, 1
          %created_address = getelementptr i8, ptr %runtime, i64 96
          store i32 %next_index, ptr %created_address, align 4
          br label %start

        ready:
          ret ptr %runtime

        start_failed:
          call void @sollang_stream_join_runtime_cancel(ptr %runtime)
          call void @sollang_stream_join_runtime_join_destroy(ptr %runtime)
          ret ptr null

        free_arrays:
          call void @sollang_free(ptr %arguments)
          call void @sollang_free(ptr %threads)
          call void @sollang_free(ptr %queue)
          call void @sollang_free(ptr %full)
          call void @sollang_free(ptr %slots)
          call void @sollang_free(ptr %runtime)
          ret ptr null

        invalid:
          ret ptr null
        }

        define internal i1 @sollang_stream_join_runtime_next_event(ptr %runtime, ptr %index_output, ptr %kind_output, ptr %slot_output) #0 {
        entry:
          call void @sollang_stream_join_lock(ptr %runtime)
          br label %inspect

        inspect:
          %queued_address = getelementptr i8, ptr %runtime, i64 16
          %queued = load i32, ptr %queued_address, align 4
          %has_event = icmp sgt i32 %queued, 0
          br i1 %has_event, label %pop, label %empty

        empty:
          %cancel_address = getelementptr i8, ptr %runtime, i64 20
          %cancelled = load i32, ptr %cancel_address, align 4
          %is_cancelled = icmp ne i32 %cancelled, 0
          %active_address = getelementptr i8, ptr %runtime, i64 4
          %active = load i32, ptr %active_address, align 4
          %complete = icmp eq i32 %active, 0
          %finished = or i1 %is_cancelled, %complete
          br i1 %finished, label %done, label %wait

        wait:
          call void @sollang_stream_join_wait(ptr %runtime)
          br label %inspect

        pop:
          %head_address = getelementptr i8, ptr %runtime, i64 8
          %head = load i32, ptr %head_address, align 4
          %queue_address = getelementptr i8, ptr %runtime, i64 72
          %queue = load ptr, ptr %queue_address, align 8
          %event_address = getelementptr i32, ptr %queue, i32 %head
          %event = load i32, ptr %event_address, align 4
          %count = load i32, ptr %runtime, align 4
          %next_head_unwrapped = add i32 %head, 1
          %next_head = urem i32 %next_head_unwrapped, %count
          store i32 %next_head, ptr %head_address, align 4
          %next_queued = sub i32 %queued, 1
          store i32 %next_queued, ptr %queued_address, align 4
          %kind = lshr i32 %event, 31
          %index = and i32 %event, 2147483647
          store i32 %index, ptr %index_output, align 4
          store i32 %kind, ptr %kind_output, align 4
          %item_size_address = getelementptr i8, ptr %runtime, i64 24
          %item_size = load i64, ptr %item_size_address, align 8
          %index64 = zext i32 %index to i64
          %slot_offset = mul i64 %index64, %item_size
          %slots_address = getelementptr i8, ptr %runtime, i64 56
          %slots = load ptr, ptr %slots_address, align 8
          %slot = getelementptr i8, ptr %slots, i64 %slot_offset
          store ptr %slot, ptr %slot_output, align 8
          call void @sollang_stream_join_unlock(ptr %runtime)
          ret i1 true

        done:
          call void @sollang_stream_join_unlock(ptr %runtime)
          ret i1 false
        }

        define internal void @sollang_stream_join_runtime_release(ptr %runtime, i32 %index) #0 {
        entry:
          call void @sollang_stream_join_lock(ptr %runtime)
          %full_array_address = getelementptr i8, ptr %runtime, i64 64
          %full_array = load ptr, ptr %full_array_address, align 8
          %full_address = getelementptr i8, ptr %full_array, i32 %index
          store i8 0, ptr %full_address, align 1
          call void @sollang_stream_join_wake_all(ptr %runtime)
          call void @sollang_stream_join_unlock(ptr %runtime)
          ret void
        }

        define internal void @sollang_stream_join_runtime_cancel(ptr %runtime) #0 {
        entry:
          call void @sollang_stream_join_lock(ptr %runtime)
          %cancel_address = getelementptr i8, ptr %runtime, i64 20
          store atomic i32 1, ptr %cancel_address release, align 4
          call void @sollang_stream_join_wake_all(ptr %runtime)
          br label %settle

        settle:
          %created_address = getelementptr i8, ptr %runtime, i64 96
          %created = load i32, ptr %created_address, align 4
          %pulling_address = getelementptr i8, ptr %runtime, i64 100
          %pulling = load i32, ptr %pulling_address, align 4
          %exited_address = getelementptr i8, ptr %runtime, i64 104
          %exited = load i32, ptr %exited_address, align 4
          %settled = add i32 %pulling, %exited
          %all_settled = icmp eq i32 %settled, %created
          br i1 %all_settled, label %done, label %wait

        wait:
          call void @sollang_stream_join_wait(ptr %runtime)
          br label %settle

        done:
          call void @sollang_stream_join_unlock(ptr %runtime)
          ret void
        }

        define internal void @sollang_stream_join_runtime_join_destroy(ptr %runtime) #0 {
        entry:
          %created_address = getelementptr i8, ptr %runtime, i64 96
          %created = load i32, ptr %created_address, align 4
          %threads_address = getelementptr i8, ptr %runtime, i64 80
          %threads = load ptr, ptr %threads_address, align 8
          br label %join

        join:
          %join_index = phi i32 [ 0, %entry ], [ %next_join, %join_one ]
          %all_joined = icmp eq i32 %join_index, %created
          br i1 %all_joined, label %drop_pending, label %join_one

        join_one:
          %thread = getelementptr i64, ptr %threads, i32 %join_index
          call void @sollang_stream_join_thread_join(ptr %thread)
          %next_join = add i32 %join_index, 1
          br label %join

        drop_pending:
          %count = load i32, ptr %runtime, align 4
          %full_array_address = getelementptr i8, ptr %runtime, i64 64
          %full_array = load ptr, ptr %full_array_address, align 8
          %item_size_address = getelementptr i8, ptr %runtime, i64 24
          %item_size = load i64, ptr %item_size_address, align 8
          %slots_address = getelementptr i8, ptr %runtime, i64 56
          %slots = load ptr, ptr %slots_address, align 8
          %drop_address = getelementptr i8, ptr %runtime, i64 40
          %drop = load ptr, ptr %drop_address, align 8
          %owner_address = getelementptr i8, ptr %runtime, i64 48
          %owner = load ptr, ptr %owner_address, align 8
          br label %drop_loop

        drop_loop:
          %drop_index = phi i32 [ 0, %drop_pending ], [ %next_drop, %drop_continue ]
          %all_dropped = icmp eq i32 %drop_index, %count
          br i1 %all_dropped, label %destroy, label %inspect_pending

        inspect_pending:
          %full_address = getelementptr i8, ptr %full_array, i32 %drop_index
          %full = load i8, ptr %full_address, align 1
          %has_pending = icmp ne i8 %full, 0
          br i1 %has_pending, label %drop_one, label %drop_continue

        drop_one:
          %drop_index64 = zext i32 %drop_index to i64
          %slot_offset = mul i64 %drop_index64, %item_size
          %slot = getelementptr i8, ptr %slots, i64 %slot_offset
          call void %drop(ptr %owner, i32 %drop_index, ptr %slot)
          br label %drop_continue

        drop_continue:
          %next_drop = add i32 %drop_index, 1
          br label %drop_loop

        destroy:
          call void @sollang_stream_join_sync_destroy(ptr %runtime)
          %arguments_address = getelementptr i8, ptr %runtime, i64 88
          %arguments = load ptr, ptr %arguments_address, align 8
          %queue_address = getelementptr i8, ptr %runtime, i64 72
          %queue = load ptr, ptr %queue_address, align 8
          call void @sollang_free(ptr %arguments)
          call void @sollang_free(ptr %threads)
          call void @sollang_free(ptr %queue)
          call void @sollang_free(ptr %full_array)
          call void @sollang_free(ptr %slots)
          call void @sollang_free(ptr %runtime)
          ret void
        }
        """;

    public static string StreamJoinWindowsFunctions() =>
        """
        define internal i32 @sollang_windows_stream_join_worker(ptr %argument) #0 {
        entry:
          call void @sollang_stream_join_worker_run(ptr %argument)
          ret i32 0
        }

        define internal i1 @sollang_stream_join_sync_init(ptr %runtime) #0 {
        entry:
          %sync = getelementptr i8, ptr %runtime, i64 112
          store ptr null, ptr %sync, align 8
          %condition = getelementptr i8, ptr %runtime, i64 120
          call void @InitializeConditionVariable(ptr %condition)
          ret i1 true
        }

        define internal void @sollang_stream_join_lock(ptr %runtime) #0 {
        entry:
          %sync = getelementptr i8, ptr %runtime, i64 112
          call void @AcquireSRWLockExclusive(ptr %sync)
          ret void
        }

        define internal void @sollang_stream_join_unlock(ptr %runtime) #0 {
        entry:
          %sync = getelementptr i8, ptr %runtime, i64 112
          call void @ReleaseSRWLockExclusive(ptr %sync)
          ret void
        }

        define internal void @sollang_stream_join_wait(ptr %runtime) #0 {
        entry:
          %sync = getelementptr i8, ptr %runtime, i64 112
          %condition = getelementptr i8, ptr %runtime, i64 120
          %waited = call i32 @SleepConditionVariableSRW(ptr %condition, ptr %sync, i32 -1, i32 0)
          ret void
        }

        define internal void @sollang_stream_join_wake_all(ptr %runtime) #0 {
        entry:
          %condition = getelementptr i8, ptr %runtime, i64 120
          call void @WakeAllConditionVariable(ptr %condition)
          ret void
        }

        define internal void @sollang_stream_join_sync_destroy(ptr %runtime) #0 {
        entry:
          ret void
        }

        define internal i1 @sollang_stream_join_thread_start(ptr %thread_slot, ptr %argument) #0 {
        entry:
          %thread = call ptr @CreateThread(ptr null, i64 0, ptr @sollang_windows_stream_join_worker, ptr %argument, i32 0, ptr null)
          store ptr %thread, ptr %thread_slot, align 8
          %ok = icmp ne ptr %thread, null
          ret i1 %ok
        }

        define internal void @sollang_stream_join_thread_join(ptr %thread_slot) #0 {
        entry:
          %thread = load ptr, ptr %thread_slot, align 8
          %waited = call i32 @WaitForSingleObject(ptr %thread, i32 -1)
          %closed = call i32 @CloseHandle(ptr %thread)
          ret void
        }
        """;

    public static string StreamJoinLinuxFunctions() =>
        """
        define internal ptr @sollang_linux_stream_join_worker(ptr %argument) #0 {
        entry:
          call void @sollang_stream_join_worker_run(ptr %argument)
          ret ptr null
        }

        define internal i1 @sollang_stream_join_sync_init(ptr %runtime) #0 {
        entry:
          %mutex = getelementptr i8, ptr %runtime, i64 112
          %mutex_result = call i32 @pthread_mutex_init(ptr %mutex, ptr null)
          %mutex_ok = icmp eq i32 %mutex_result, 0
          br i1 %mutex_ok, label %initialize_condition, label %fail

        initialize_condition:
          %condition = getelementptr i8, ptr %runtime, i64 152
          %condition_result = call i32 @pthread_cond_init(ptr %condition, ptr null)
          %condition_ok = icmp eq i32 %condition_result, 0
          br i1 %condition_ok, label %ready, label %destroy_mutex

        destroy_mutex:
          %destroyed = call i32 @pthread_mutex_destroy(ptr %mutex)
          br label %fail

        ready:
          ret i1 true

        fail:
          ret i1 false
        }

        define internal void @sollang_stream_join_lock(ptr %runtime) #0 {
        entry:
          %mutex = getelementptr i8, ptr %runtime, i64 112
          %locked = call i32 @pthread_mutex_lock(ptr %mutex)
          ret void
        }

        define internal void @sollang_stream_join_unlock(ptr %runtime) #0 {
        entry:
          %mutex = getelementptr i8, ptr %runtime, i64 112
          %unlocked = call i32 @pthread_mutex_unlock(ptr %mutex)
          ret void
        }

        define internal void @sollang_stream_join_wait(ptr %runtime) #0 {
        entry:
          %mutex = getelementptr i8, ptr %runtime, i64 112
          %condition = getelementptr i8, ptr %runtime, i64 152
          %waited = call i32 @pthread_cond_wait(ptr %condition, ptr %mutex)
          ret void
        }

        define internal void @sollang_stream_join_wake_all(ptr %runtime) #0 {
        entry:
          %condition = getelementptr i8, ptr %runtime, i64 152
          %woken = call i32 @pthread_cond_broadcast(ptr %condition)
          ret void
        }

        define internal void @sollang_stream_join_sync_destroy(ptr %runtime) #0 {
        entry:
          %condition = getelementptr i8, ptr %runtime, i64 152
          %condition_destroyed = call i32 @pthread_cond_destroy(ptr %condition)
          %mutex = getelementptr i8, ptr %runtime, i64 112
          %mutex_destroyed = call i32 @pthread_mutex_destroy(ptr %mutex)
          ret void
        }

        define internal i1 @sollang_stream_join_thread_start(ptr %thread_slot, ptr %argument) #0 {
        entry:
          %created = call i32 @pthread_create(ptr %thread_slot, ptr null, ptr @sollang_linux_stream_join_worker, ptr %argument)
          %ok = icmp eq i32 %created, 0
          ret i1 %ok
        }

        define internal void @sollang_stream_join_thread_join(ptr %thread_slot) #0 {
        entry:
          %thread = load i64, ptr %thread_slot, align 8
          %joined = call i32 @pthread_join(i64 %thread, ptr null)
          ret void
        }
        """;

    public static string StreamJoinWindowsDeclarations() =>
        """
        declare dllimport void @AcquireSRWLockExclusive(ptr)
        declare dllimport void @ReleaseSRWLockExclusive(ptr)
        declare dllimport void @InitializeConditionVariable(ptr)
        declare dllimport i32 @SleepConditionVariableSRW(ptr, ptr, i32, i32)
        declare dllimport void @WakeAllConditionVariable(ptr)
        """;

    public static string StreamJoinLinuxDeclarations() =>
        """
        declare i32 @pthread_cond_init(ptr, ptr)
        declare i32 @pthread_cond_destroy(ptr)
        declare i32 @pthread_cond_wait(ptr, ptr)
        declare i32 @pthread_cond_broadcast(ptr)
        """;
    public static string MouseWindowsFunctions() =>
        """
        define internal i32 @sollang_mouse_event_worker(ptr %context) #0 {
        entry:
          %input = load ptr, ptr %context, align 8
          %record = alloca [20 x i8], align 4
          %read = alloca i32, align 4
          br label %wait

        wait:
          %cancel_address = getelementptr i8, ptr %context, i64 32
          %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
          %active = icmp eq i32 %cancelled, 0
          br i1 %active, label %read_input, label %done

        read_input:
          %ok = call i32 @ReadConsoleInputW(ptr %input, ptr %record, i32 1, ptr %read)
          %read_ok = icmp ne i32 %ok, 0
          br i1 %read_ok, label %inspect, label %closed

        inspect:
          %event_type = load i16, ptr %record, align 2
          %is_mouse = icmp eq i16 %event_type, 2
          br i1 %is_mouse, label %mouse, label %wait

        mouse:
          %x_slot = getelementptr i8, ptr %record, i64 4
          %x16 = load i16, ptr %x_slot, align 2
          %x = sext i16 %x16 to i32
          %y_slot = getelementptr i8, ptr %record, i64 6
          %y16 = load i16, ptr %y_slot, align 2
          %y = sext i16 %y16 to i32
          %buttons_address = getelementptr i8, ptr %record, i64 8
          %buttons = load i32, ptr %buttons_address, align 4
          %flags_address = getelementptr i8, ptr %record, i64 16
          %flags = load i32, ptr %flags_address, align 4
          %wheel_bits = and i32 %flags, 12
          %is_wheel = icmp ne i32 %wheel_bits, 0
          br i1 %is_wheel, label %wheel, label %non_wheel

        wheel:
          %wheel_delta = ashr i32 %buttons, 16
          br label %enqueue

        non_wheel:
          %previous_address = getelementptr i8, ptr %context, i64 64
          %previous = load i32, ptr %previous_address, align 4
          %changed = xor i32 %previous, %buttons
          store i32 %buttons, ptr %previous_address, align 4
          %has_change = icmp ne i32 %changed, 0
          br i1 %has_change, label %button_change, label %move

        button_change:
          %changed0 = and i32 %changed, 1
          %is0 = icmp ne i32 %changed0, 0
          %changed1 = and i32 %changed, 4
          %is1 = icmp ne i32 %changed1, 0
          %changed2 = and i32 %changed, 2
          %is2 = icmp ne i32 %changed2, 0
          %button12 = select i1 %is2, i32 2, i32 3
          %button1 = select i1 %is1, i32 1, i32 %button12
          %button_index = select i1 %is0, i32 0, i32 %button1
          %pressed_bits = and i32 %buttons, %changed
          %pressed = icmp ne i32 %pressed_bits, 0
          %button_kind = select i1 %pressed, i32 1, i32 2
          br label %enqueue

        move:
          br label %enqueue

        enqueue:
          %delta = phi i32 [ %wheel_delta, %wheel ], [ 0, %button_change ], [ 0, %move ]
          %button = phi i32 [ -1, %wheel ], [ %button_index, %button_change ], [ -1, %move ]
          %kind = phi i32 [ 3, %wheel ], [ %button_kind, %button_change ], [ 0, %move ]
          br label %queue_lock

        queue_lock:
          %lock_address = getelementptr i8, ptr %context, i64 68
          %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
          %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
          br i1 %lock_acquired, label %queue_state, label %queue_lock

        queue_state:
          %capacity_address = getelementptr i8, ptr %context, i64 12
          %capacity = load i32, ptr %capacity_address, align 4
          %head_address = getelementptr i8, ptr %context, i64 20
          %head = load i32, ptr %head_address, align 4
          %tail_address = getelementptr i8, ptr %context, i64 24
          %tail = load i32, ptr %tail_address, align 4
          %count_address = getelementptr i8, ptr %context, i64 28
          %count = load i32, ptr %count_address, align 4
          %full = icmp uge i32 %count, %capacity
          br i1 %full, label %overflow, label %write

        overflow:
          %policy_address = getelementptr i8, ptr %context, i64 16
          %policy = load i32, ptr %policy_address, align 4
          %drop_newest = icmp eq i32 %policy, 0
          br i1 %drop_newest, label %unlock_drop, label %not_drop_newest

        not_drop_newest:
          %coalesce = icmp eq i32 %policy, 2
          %is_move = icmp eq i32 %kind, 0
          %coalesce_move = and i1 %coalesce, %is_move
          br i1 %coalesce_move, label %replace_move_check, label %drop_oldest

        replace_move_check:
          %last_tail_unwrapped = add i32 %tail, %capacity
          %last_tail = sub i32 %last_tail_unwrapped, 1
          %last_index = urem i32 %last_tail, %capacity
          %last_index64 = zext i32 %last_index to i64
          %last_offset = mul i64 %last_index64, 20
          %buffer_address0 = getelementptr i8, ptr %context, i64 56
          %buffer0 = load ptr, ptr %buffer_address0, align 8
          %last_record = getelementptr i8, ptr %buffer0, i64 %last_offset
          %last_kind_address = getelementptr i8, ptr %last_record, i64 16
          %last_kind = load i32, ptr %last_kind_address, align 4
          %last_is_move = icmp eq i32 %last_kind, 0
          br i1 %last_is_move, label %replace_move, label %unlock_drop

        replace_move:
          store i32 %x, ptr %last_record, align 4
          %last_y = getelementptr i8, ptr %last_record, i64 4
          store i32 %y, ptr %last_y, align 4
          br label %signal

        drop_oldest:
          %next_head_unwrapped = add i32 %head, 1
          %next_head = urem i32 %next_head_unwrapped, %capacity
          store i32 %next_head, ptr %head_address, align 4
          %reduced_count = sub i32 %count, 1
          store i32 %reduced_count, ptr %count_address, align 4
          br label %write

        write:
          %index64 = zext i32 %tail to i64
          %offset = mul i64 %index64, 20
          %buffer_address = getelementptr i8, ptr %context, i64 56
          %buffer = load ptr, ptr %buffer_address, align 8
          %slot = getelementptr i8, ptr %buffer, i64 %offset
          store i32 %x, ptr %slot, align 4
          %slot_y = getelementptr i8, ptr %slot, i64 4
          store i32 %y, ptr %slot_y, align 4
          %slot_delta = getelementptr i8, ptr %slot, i64 8
          store i32 %delta, ptr %slot_delta, align 4
          %slot_button = getelementptr i8, ptr %slot, i64 12
          store i32 %button, ptr %slot_button, align 4
          %slot_kind = getelementptr i8, ptr %slot, i64 16
          store i32 %kind, ptr %slot_kind, align 4
          %next_tail_unwrapped = add i32 %tail, 1
          %next_tail = urem i32 %next_tail_unwrapped, %capacity
          store i32 %next_tail, ptr %tail_address, align 4
          %current_count = load i32, ptr %count_address, align 4
          %next_count = add i32 %current_count, 1
          store i32 %next_count, ptr %count_address, align 4
          br label %signal

        unlock_drop:
          store atomic i32 0, ptr %lock_address release, align 4
          br label %wait

        signal:
          store atomic i32 0, ptr %lock_address release, align 4
          %event_address = getelementptr i8, ptr %context, i64 48
          %event = load ptr, ptr %event_address, align 8
          %signalled = call i32 @SetEvent(ptr %event)
          br label %wait

        closed:
          store atomic i32 1, ptr %cancel_address release, align 4
          %closed_event_address = getelementptr i8, ptr %context, i64 48
          %closed_event = load ptr, ptr %closed_event_address, align 8
          %closed_signalled = call i32 @SetEvent(ptr %closed_event)
          br label %done

        done:
          ret i32 0
        }

        define internal ptr @sollang_mouse_event_stream_create(i32 %requested_capacity, i32 %overflow) #0 {
        entry:
          %capacity_low = icmp slt i32 %requested_capacity, 2
          %capacity_high = icmp sgt i32 %requested_capacity, 65536
          %capacity_invalid = or i1 %capacity_low, %capacity_high
          %overflow_invalid = icmp ugt i32 %overflow, 2
          %invalid = or i1 %capacity_invalid, %overflow_invalid
          br i1 %invalid, label %fail, label %input_handle

        input_handle:
          %input = call ptr @GetStdHandle(i32 -10)
          %valid = icmp ne ptr %input, inttoptr (i64 -1 to ptr)
          br i1 %valid, label %mode, label %fail

        mode:
          %original_address = alloca i32, align 4
          %got_mode = call i32 @GetConsoleMode(ptr %input, ptr %original_address)
          %mode_ok = icmp ne i32 %got_mode, 0
          br i1 %mode_ok, label %allocate_context, label %fail

        allocate_context:
          %context = call ptr @sollang_alloc(i64 80)
          %allocated = icmp ne ptr %context, null
          br i1 %allocated, label %allocate_buffer, label %fail

        allocate_buffer:
          %capacity64 = zext i32 %requested_capacity to i64
          %buffer_bytes = mul i64 %capacity64, 20
          %buffer = call ptr @sollang_alloc(i64 %buffer_bytes)
          %buffer_allocated = icmp ne ptr %buffer, null
          br i1 %buffer_allocated, label %create_event, label %free_context

        create_event:
          %event = call ptr @CreateEventA(ptr null, i32 0, i32 0, ptr null)
          %event_ok = icmp ne ptr %event, null
          br i1 %event_ok, label %initialize, label %free_buffer

        initialize:
          %original = load i32, ptr %original_address, align 4
          %with_mouse = or i32 %original, 144
          %interactive = and i32 %with_mouse, -65
          %enabled = call i32 @SetConsoleMode(ptr %input, i32 %interactive)
          %enabled_ok = icmp ne i32 %enabled, 0
          br i1 %enabled_ok, label %initialize_context, label %close_event

        initialize_context:
          store ptr %input, ptr %context, align 8
          %mode_slot = getelementptr i8, ptr %context, i64 8
          store i32 %original, ptr %mode_slot, align 4
          %capacity_slot = getelementptr i8, ptr %context, i64 12
          store i32 %requested_capacity, ptr %capacity_slot, align 4
          %overflow_slot = getelementptr i8, ptr %context, i64 16
          store i32 %overflow, ptr %overflow_slot, align 4
          %head_slot = getelementptr i8, ptr %context, i64 20
          store i32 0, ptr %head_slot, align 4
          %tail_slot = getelementptr i8, ptr %context, i64 24
          store i32 0, ptr %tail_slot, align 4
          %count_slot = getelementptr i8, ptr %context, i64 28
          store i32 0, ptr %count_slot, align 4
          %cancel_slot = getelementptr i8, ptr %context, i64 32
          store atomic i32 0, ptr %cancel_slot release, align 4
          %event_slot = getelementptr i8, ptr %context, i64 48
          store ptr %event, ptr %event_slot, align 8
          %buffer_slot = getelementptr i8, ptr %context, i64 56
          store ptr %buffer, ptr %buffer_slot, align 8
          %buttons_slot = getelementptr i8, ptr %context, i64 64
          store i32 0, ptr %buttons_slot, align 4
          %lock_slot = getelementptr i8, ptr %context, i64 68
          store atomic i32 0, ptr %lock_slot release, align 4
          %thread = call ptr @CreateThread(ptr null, i64 0, ptr @sollang_mouse_event_worker, ptr %context, i32 0, ptr null)
          %thread_ok = icmp ne ptr %thread, null
          br i1 %thread_ok, label %ready, label %restore

        ready:
          %thread_slot = getelementptr i8, ptr %context, i64 40
          store ptr %thread, ptr %thread_slot, align 8
          ret ptr %context

        restore:
          %restored_after_thread = call i32 @SetConsoleMode(ptr %input, i32 %original)
          br label %close_event

        close_event:
          %event_closed = call i32 @CloseHandle(ptr %event)
          br label %free_buffer

        free_buffer:
          call void @sollang_free(ptr %buffer)
          br label %free_context

        free_context:
          call void @sollang_free(ptr %context)
          br label %fail

        fail:
          ret ptr null
        }

        define internal i1 @sollang_mouse_event_next_raw(ptr %context, ptr %x, ptr %y, ptr %delta, ptr %button, ptr %kind) #0 {
        entry:
          br label %queue_lock

        queue_lock:
          %lock_address = getelementptr i8, ptr %context, i64 68
          %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
          %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
          br i1 %lock_acquired, label %poll, label %queue_lock

        poll:
          %count_address = getelementptr i8, ptr %context, i64 28
          %count = load i32, ptr %count_address, align 4
          %available = icmp ugt i32 %count, 0
          br i1 %available, label %read, label %unlock_empty

        unlock_empty:
          store atomic i32 0, ptr %lock_address release, align 4
          br label %empty

        empty:
          %cancel_address = getelementptr i8, ptr %context, i64 32
          %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
          %active = icmp eq i32 %cancelled, 0
          br i1 %active, label %wait, label %closed

        wait:
          %event_address = getelementptr i8, ptr %context, i64 48
          %event = load ptr, ptr %event_address, align 8
          %waited = call i32 @WaitForSingleObject(ptr %event, i32 -1)
          br label %queue_lock

        read:
          %capacity_address = getelementptr i8, ptr %context, i64 12
          %capacity = load i32, ptr %capacity_address, align 4
          %head_address = getelementptr i8, ptr %context, i64 20
          %head = load i32, ptr %head_address, align 4
          %index64 = zext i32 %head to i64
          %offset = mul i64 %index64, 20
          %buffer_address = getelementptr i8, ptr %context, i64 56
          %buffer = load ptr, ptr %buffer_address, align 8
          %slot = getelementptr i8, ptr %buffer, i64 %offset
          %x_value = load i32, ptr %slot, align 4
          store i32 %x_value, ptr %x, align 4
          %slot_y = getelementptr i8, ptr %slot, i64 4
          %y_value = load i32, ptr %slot_y, align 4
          store i32 %y_value, ptr %y, align 4
          %slot_delta = getelementptr i8, ptr %slot, i64 8
          %delta_value = load i32, ptr %slot_delta, align 4
          store i32 %delta_value, ptr %delta, align 4
          %slot_button = getelementptr i8, ptr %slot, i64 12
          %button_value = load i32, ptr %slot_button, align 4
          store i32 %button_value, ptr %button, align 4
          %slot_kind = getelementptr i8, ptr %slot, i64 16
          %kind_value = load i32, ptr %slot_kind, align 4
          store i32 %kind_value, ptr %kind, align 4
          %next_head_unwrapped = add i32 %head, 1
          %next_head = urem i32 %next_head_unwrapped, %capacity
          store i32 %next_head, ptr %head_address, align 4
          %next_count = sub i32 %count, 1
          store i32 %next_count, ptr %count_address, align 4
          store atomic i32 0, ptr %lock_address release, align 4
          ret i1 true

        closed:
          ret i1 false
        }

        define internal void @sollang_mouse_event_stream_drop(ptr %context, i1 %destroy) #0 {
        entry:
          %cancel_address = getelementptr i8, ptr %context, i64 32
          store atomic i32 1, ptr %cancel_address release, align 4
          %thread_address = getelementptr i8, ptr %context, i64 40
          %thread = load ptr, ptr %thread_address, align 8
          %cancelled = call i32 @CancelSynchronousIo(ptr %thread)
          %event_address = getelementptr i8, ptr %context, i64 48
          %event = load ptr, ptr %event_address, align 8
          %signalled = call i32 @SetEvent(ptr %event)
          br i1 %destroy, label %join_worker, label %cancelled_only

        cancelled_only:
          ret void

        join_worker:
          %cancel_pending = call i32 @CancelSynchronousIo(ptr %thread)
          %joined = call i32 @WaitForSingleObject(ptr %thread, i32 1)
          switch i32 %joined, label %join_failed [
            i32 0, label %cleanup
            i32 258, label %join_worker
          ]

        join_failed:
          call void @llvm.trap()
          unreachable

        cleanup:
          %thread_closed = call i32 @CloseHandle(ptr %thread)
          %event_closed = call i32 @CloseHandle(ptr %event)
          %input = load ptr, ptr %context, align 8
          %mode_slot = getelementptr i8, ptr %context, i64 8
          %original = load i32, ptr %mode_slot, align 4
          %restored = call i32 @SetConsoleMode(ptr %input, i32 %original)
          %buffer_address = getelementptr i8, ptr %context, i64 56
          %buffer = load ptr, ptr %buffer_address, align 8
          call void @sollang_free(ptr %buffer)
          call void @sollang_free(ptr %context)
          ret void
        }
        """;

    public static string MouseLinuxWorkerFunctions() =>
        """
        @sollang_mouse_enable = private constant [16 x i8] c"\1B[?1003h\1B[?1006h"
        @sollang_mouse_disable = private constant [16 x i8] c"\1B[?1003l\1B[?1006l"

        define internal i32 @sollang_linux_mouse_read_byte(ptr %context) #0 {
        entry:
          %poll_record = alloca [8 x i8], align 4
          %byte = alloca i8, align 1
          store i32 0, ptr %poll_record, align 4
          %events = getelementptr i8, ptr %poll_record, i64 4
          store i16 1, ptr %events, align 2
          br label %wait

        wait:
          %cancel_address = getelementptr i8, ptr %context, i64 20
          %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
          %active = icmp eq i32 %cancelled, 0
          br i1 %active, label %poll, label %closed

        poll:
          %ready = call i32 @poll(ptr %poll_record, i64 1, i32 50)
          %has_input = icmp sgt i32 %ready, 0
          br i1 %has_input, label %read_byte, label %wait

        read_byte:
          %read_count = call i64 @read(i32 0, ptr %byte, i64 1)
          %read_ok = icmp eq i64 %read_count, 1
          br i1 %read_ok, label %got_value, label %wait

        got_value:
          %raw = load i8, ptr %byte, align 1
          %byte_value = zext i8 %raw to i32
          ret i32 %byte_value

        closed:
          ret i32 -1
        }

        define internal void @sollang_linux_mouse_signal(ptr %context) #0 {
        entry:
          %one = alloca i64, align 8
          store i64 1, ptr %one, align 8
          %fd_address = getelementptr i8, ptr %context, i64 28
          %fd = load i32, ptr %fd_address, align 4
          %written = call i64 @write(i32 %fd, ptr %one, i64 8)
          ret void
        }

        define internal void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 %delta, i32 %button, i32 %kind) #0 {
        entry:
          br label %queue_lock

        queue_lock:
          %lock_address = getelementptr i8, ptr %context, i64 24
          %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
          %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
          br i1 %lock_acquired, label %queue_state, label %queue_lock

        queue_state:
          %capacity = load i32, ptr %context, align 4
          %policy_address = getelementptr i8, ptr %context, i64 4
          %policy = load i32, ptr %policy_address, align 4
          %count_address = getelementptr i8, ptr %context, i64 16
          %count = load i32, ptr %count_address, align 4
          %full = icmp uge i32 %count, %capacity
          br i1 %full, label %overflow, label %write

        overflow:
          %drop_newest = icmp eq i32 %policy, 0
          br i1 %drop_newest, label %unlock_drop, label %not_drop_newest

        not_drop_newest:
          %coalesce = icmp eq i32 %policy, 2
          %is_move = icmp eq i32 %kind, 0
          %coalesce_move = and i1 %coalesce, %is_move
          br i1 %coalesce_move, label %replace_move_check, label %drop_oldest

        replace_move_check:
          %tail_address0 = getelementptr i8, ptr %context, i64 12
          %tail0 = load i32, ptr %tail_address0, align 4
          %tail_plus_capacity = add i32 %tail0, %capacity
          %last_unwrapped = sub i32 %tail_plus_capacity, 1
          %last_index = urem i32 %last_unwrapped, %capacity
          %last_index64 = zext i32 %last_index to i64
          %last_offset = mul i64 %last_index64, 20
          %buffer_address0 = getelementptr i8, ptr %context, i64 40
          %buffer0 = load ptr, ptr %buffer_address0, align 8
          %last_record = getelementptr i8, ptr %buffer0, i64 %last_offset
          %last_kind_address = getelementptr i8, ptr %last_record, i64 16
          %last_kind = load i32, ptr %last_kind_address, align 4
          %last_is_move = icmp eq i32 %last_kind, 0
          br i1 %last_is_move, label %replace_move, label %unlock_drop

        replace_move:
          store i32 %x, ptr %last_record, align 4
          %last_y = getelementptr i8, ptr %last_record, i64 4
          store i32 %y, ptr %last_y, align 4
          br label %unlock_signal

        drop_oldest:
          %head_address = getelementptr i8, ptr %context, i64 8
          %head = load i32, ptr %head_address, align 4
          %next_head_unwrapped = add i32 %head, 1
          %next_head = urem i32 %next_head_unwrapped, %capacity
          store i32 %next_head, ptr %head_address, align 4
          %reduced_count = sub i32 %count, 1
          store i32 %reduced_count, ptr %count_address, align 4
          br label %write

        write:
          %tail_address = getelementptr i8, ptr %context, i64 12
          %tail = load i32, ptr %tail_address, align 4
          %tail64 = zext i32 %tail to i64
          %offset = mul i64 %tail64, 20
          %buffer_address = getelementptr i8, ptr %context, i64 40
          %buffer = load ptr, ptr %buffer_address, align 8
          %slot = getelementptr i8, ptr %buffer, i64 %offset
          store i32 %x, ptr %slot, align 4
          %slot_y = getelementptr i8, ptr %slot, i64 4
          store i32 %y, ptr %slot_y, align 4
          %slot_delta = getelementptr i8, ptr %slot, i64 8
          store i32 %delta, ptr %slot_delta, align 4
          %slot_button = getelementptr i8, ptr %slot, i64 12
          store i32 %button, ptr %slot_button, align 4
          %slot_kind = getelementptr i8, ptr %slot, i64 16
          store i32 %kind, ptr %slot_kind, align 4
          %next_tail_unwrapped = add i32 %tail, 1
          %next_tail = urem i32 %next_tail_unwrapped, %capacity
          store i32 %next_tail, ptr %tail_address, align 4
          %current_count = load i32, ptr %count_address, align 4
          %next_count = add i32 %current_count, 1
          store i32 %next_count, ptr %count_address, align 4
          br label %unlock_signal

        unlock_drop:
          store atomic i32 0, ptr %lock_address release, align 4
          ret void

        unlock_signal:
          store atomic i32 0, ptr %lock_address release, align 4
          call void @sollang_linux_mouse_signal(ptr %context)
          ret void
        }

        define internal ptr @sollang_linux_mouse_worker(ptr %context) #0 {
        entry:
          %button_value = alloca i32, align 4
          %x_value = alloca i32, align 4
          %y_value = alloca i32, align 4
          br label %seek_escape

        seek_escape:
          %escape = call i32 @sollang_linux_mouse_read_byte(ptr %context)
          %escape_closed = icmp slt i32 %escape, 0
          br i1 %escape_closed, label %done, label %check_escape

        check_escape:
          %is_escape = icmp eq i32 %escape, 27
          br i1 %is_escape, label %expect_bracket, label %seek_escape

        expect_bracket:
          %bracket = call i32 @sollang_linux_mouse_read_byte(ptr %context)
          %is_bracket = icmp eq i32 %bracket, 91
          br i1 %is_bracket, label %expect_less, label %seek_escape

        expect_less:
          %less = call i32 @sollang_linux_mouse_read_byte(ptr %context)
          %is_less = icmp eq i32 %less, 60
          br i1 %is_less, label %button_start, label %seek_escape

        button_start:
          store i32 0, ptr %button_value, align 4
          br label %button_digit

        button_digit:
          %button_char = call i32 @sollang_linux_mouse_read_byte(ptr %context)
          %button_is_digit_low = icmp sge i32 %button_char, 48
          %button_is_digit_high = icmp sle i32 %button_char, 57
          %button_is_digit = and i1 %button_is_digit_low, %button_is_digit_high
          br i1 %button_is_digit, label %button_accumulate, label %button_separator

        button_accumulate:
          %button_old = load i32, ptr %button_value, align 4
          %button_times_ten = mul i32 %button_old, 10
          %button_digit_value = sub i32 %button_char, 48
          %button_next = add i32 %button_times_ten, %button_digit_value
          store i32 %button_next, ptr %button_value, align 4
          br label %button_digit

        button_separator:
          %button_has_separator = icmp eq i32 %button_char, 59
          br i1 %button_has_separator, label %x_start, label %seek_escape

        x_start:
          store i32 0, ptr %x_value, align 4
          br label %x_digit

        x_digit:
          %x_char = call i32 @sollang_linux_mouse_read_byte(ptr %context)
          %x_is_digit_low = icmp sge i32 %x_char, 48
          %x_is_digit_high = icmp sle i32 %x_char, 57
          %x_is_digit = and i1 %x_is_digit_low, %x_is_digit_high
          br i1 %x_is_digit, label %x_accumulate, label %x_separator

        x_accumulate:
          %x_old = load i32, ptr %x_value, align 4
          %x_times_ten = mul i32 %x_old, 10
          %x_digit_value = sub i32 %x_char, 48
          %x_next = add i32 %x_times_ten, %x_digit_value
          store i32 %x_next, ptr %x_value, align 4
          br label %x_digit

        x_separator:
          %x_has_separator = icmp eq i32 %x_char, 59
          br i1 %x_has_separator, label %y_start, label %seek_escape

        y_start:
          store i32 0, ptr %y_value, align 4
          br label %y_digit

        y_digit:
          %y_char = call i32 @sollang_linux_mouse_read_byte(ptr %context)
          %y_is_digit_low = icmp sge i32 %y_char, 48
          %y_is_digit_high = icmp sle i32 %y_char, 57
          %y_is_digit = and i1 %y_is_digit_low, %y_is_digit_high
          br i1 %y_is_digit, label %y_accumulate, label %finish_event

        y_accumulate:
          %y_old = load i32, ptr %y_value, align 4
          %y_times_ten = mul i32 %y_old, 10
          %y_digit_value = sub i32 %y_char, 48
          %y_next = add i32 %y_times_ten, %y_digit_value
          store i32 %y_next, ptr %y_value, align 4
          br label %y_digit

        finish_event:
          %is_press = icmp eq i32 %y_char, 77
          %is_release = icmp eq i32 %y_char, 109
          %valid_final = or i1 %is_press, %is_release
          br i1 %valid_final, label %classify, label %seek_escape

        classify:
          %raw_button = load i32, ptr %button_value, align 4
          %raw_x = load i32, ptr %x_value, align 4
          %raw_y = load i32, ptr %y_value, align 4
          %x = sub i32 %raw_x, 1
          %y = sub i32 %raw_y, 1
          %wheel_bit = and i32 %raw_button, 64
          %is_wheel = icmp ne i32 %wheel_bit, 0
          br i1 %is_wheel, label %wheel, label %non_wheel

        wheel:
          %wheel_direction = and i32 %raw_button, 1
          %wheel_down = icmp ne i32 %wheel_direction, 0
          %delta = select i1 %wheel_down, i32 -120, i32 120
          call void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 %delta, i32 -1, i32 3)
          br label %seek_escape

        non_wheel:
          %motion_bit = and i32 %raw_button, 32
          %is_motion = icmp ne i32 %motion_bit, 0
          br i1 %is_motion, label %move, label %button

        move:
          call void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 0, i32 -1, i32 0)
          br label %seek_escape

        button:
          %button_index = and i32 %raw_button, 3
          %kind = select i1 %is_release, i32 2, i32 1
          call void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 0, i32 %button_index, i32 %kind)
          br label %seek_escape

        done:
          call void @sollang_linux_mouse_signal(ptr %context)
          ret ptr null
        }
        """;

    public static string MouseLinuxLifecycleFunctions() =>
        """
        define internal ptr @sollang_mouse_event_stream_create(i32 %requested_capacity, i32 %overflow) #0 {
        entry:
          %capacity_low = icmp slt i32 %requested_capacity, 2
          %capacity_high = icmp sgt i32 %requested_capacity, 65536
          %capacity_invalid = or i1 %capacity_low, %capacity_high
          %overflow_invalid = icmp ugt i32 %overflow, 2
          %invalid = or i1 %capacity_invalid, %overflow_invalid
          br i1 %invalid, label %fail, label %tty

        tty:
          %interactive = call i32 @isatty(i32 0)
          %is_tty = icmp ne i32 %interactive, 0
          br i1 %is_tty, label %allocate_context, label %fail

        allocate_context:
          %context = call ptr @sollang_alloc(i64 64)
          %context_ok = icmp ne ptr %context, null
          br i1 %context_ok, label %allocate_buffer, label %fail

        allocate_buffer:
          %capacity64 = zext i32 %requested_capacity to i64
          %buffer_bytes = mul i64 %capacity64, 20
          %buffer = call ptr @sollang_alloc(i64 %buffer_bytes)
          %buffer_ok = icmp ne ptr %buffer, null
          br i1 %buffer_ok, label %allocate_termios, label %free_context

        allocate_termios:
          %original = call ptr @sollang_alloc(i64 64)
          %original_ok = icmp ne ptr %original, null
          br i1 %original_ok, label %read_termios, label %free_buffer

        read_termios:
          %got_termios = call i32 @tcgetattr(i32 0, ptr %original)
          %termios_ok = icmp eq i32 %got_termios, 0
          br i1 %termios_ok, label %configure_termios, label %free_termios

        configure_termios:
          %current = alloca [64 x i8], align 8
          call void @llvm.memcpy.p0.p0.i64(ptr %current, ptr %original, i64 64, i1 false)
          %lflag_address = getelementptr i8, ptr %current, i64 12
          %lflag = load i32, ptr %lflag_address, align 4
          %raw_lflag = and i32 %lflag, -11
          store i32 %raw_lflag, ptr %lflag_address, align 4
          %vtime = getelementptr i8, ptr %current, i64 22
          store i8 0, ptr %vtime, align 1
          %vmin = getelementptr i8, ptr %current, i64 23
          store i8 1, ptr %vmin, align 1
          %set_termios = call i32 @tcsetattr(i32 0, i32 0, ptr %current)
          %termios_set = icmp eq i32 %set_termios, 0
          br i1 %termios_set, label %create_event, label %free_termios

        create_event:
          %event_fd = call i32 @eventfd(i32 0, i32 0)
          %event_ok = icmp sge i32 %event_fd, 0
          br i1 %event_ok, label %initialize, label %restore

        initialize:
          store i32 %requested_capacity, ptr %context, align 4
          %policy_address = getelementptr i8, ptr %context, i64 4
          store i32 %overflow, ptr %policy_address, align 4
          %head_address = getelementptr i8, ptr %context, i64 8
          store i32 0, ptr %head_address, align 4
          %tail_address = getelementptr i8, ptr %context, i64 12
          store i32 0, ptr %tail_address, align 4
          %count_address = getelementptr i8, ptr %context, i64 16
          store i32 0, ptr %count_address, align 4
          %cancel_address = getelementptr i8, ptr %context, i64 20
          store atomic i32 0, ptr %cancel_address release, align 4
          %lock_address = getelementptr i8, ptr %context, i64 24
          store atomic i32 0, ptr %lock_address release, align 4
          %event_address = getelementptr i8, ptr %context, i64 28
          store i32 %event_fd, ptr %event_address, align 4
          %buffer_address = getelementptr i8, ptr %context, i64 40
          store ptr %buffer, ptr %buffer_address, align 8
          %termios_address = getelementptr i8, ptr %context, i64 48
          store ptr %original, ptr %termios_address, align 8
          %enabled = call i64 @write(i32 1, ptr @sollang_mouse_enable, i64 16)
          %thread_slot = alloca i64, align 8
          %created = call i32 @pthread_create(ptr %thread_slot, ptr null, ptr @sollang_linux_mouse_worker, ptr %context)
          %thread_ok = icmp eq i32 %created, 0
          br i1 %thread_ok, label %ready, label %close_event

        ready:
          %thread = load i64, ptr %thread_slot, align 8
          %thread_address = getelementptr i8, ptr %context, i64 32
          store i64 %thread, ptr %thread_address, align 8
          ret ptr %context

        close_event:
          %closed_event = call i32 @close(i32 %event_fd)
          br label %restore

        restore:
          %restored = call i32 @tcsetattr(i32 0, i32 0, ptr %original)
          br label %free_termios

        free_termios:
          call void @sollang_free(ptr %original)
          br label %free_buffer

        free_buffer:
          call void @sollang_free(ptr %buffer)
          br label %free_context

        free_context:
          call void @sollang_free(ptr %context)
          br label %fail

        fail:
          ret ptr null
        }

        define internal i1 @sollang_mouse_event_next_raw(ptr %context, ptr %x, ptr %y, ptr %delta, ptr %button, ptr %kind) #0 {
        entry:
          br label %queue_lock

        queue_lock:
          %lock_address = getelementptr i8, ptr %context, i64 24
          %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
          %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
          br i1 %lock_acquired, label %queue_state, label %queue_lock

        queue_state:
          %count_address = getelementptr i8, ptr %context, i64 16
          %count = load i32, ptr %count_address, align 4
          %available = icmp ugt i32 %count, 0
          br i1 %available, label %read, label %unlock_empty

        unlock_empty:
          store atomic i32 0, ptr %lock_address release, align 4
          %cancel_address = getelementptr i8, ptr %context, i64 20
          %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
          %active = icmp eq i32 %cancelled, 0
          br i1 %active, label %wait, label %closed

        wait:
          %counter = alloca i64, align 8
          %event_address = getelementptr i8, ptr %context, i64 28
          %event_fd = load i32, ptr %event_address, align 4
          %read_signal = call i64 @read(i32 %event_fd, ptr %counter, i64 8)
          br label %queue_lock

        read:
          %capacity = load i32, ptr %context, align 4
          %head_address = getelementptr i8, ptr %context, i64 8
          %head = load i32, ptr %head_address, align 4
          %head64 = zext i32 %head to i64
          %offset = mul i64 %head64, 20
          %buffer_address = getelementptr i8, ptr %context, i64 40
          %buffer = load ptr, ptr %buffer_address, align 8
          %slot = getelementptr i8, ptr %buffer, i64 %offset
          %x_value = load i32, ptr %slot, align 4
          store i32 %x_value, ptr %x, align 4
          %slot_y = getelementptr i8, ptr %slot, i64 4
          %y_value = load i32, ptr %slot_y, align 4
          store i32 %y_value, ptr %y, align 4
          %slot_delta = getelementptr i8, ptr %slot, i64 8
          %delta_value = load i32, ptr %slot_delta, align 4
          store i32 %delta_value, ptr %delta, align 4
          %slot_button = getelementptr i8, ptr %slot, i64 12
          %button_value = load i32, ptr %slot_button, align 4
          store i32 %button_value, ptr %button, align 4
          %slot_kind = getelementptr i8, ptr %slot, i64 16
          %kind_value = load i32, ptr %slot_kind, align 4
          store i32 %kind_value, ptr %kind, align 4
          %next_head_unwrapped = add i32 %head, 1
          %next_head = urem i32 %next_head_unwrapped, %capacity
          store i32 %next_head, ptr %head_address, align 4
          %next_count = sub i32 %count, 1
          store i32 %next_count, ptr %count_address, align 4
          store atomic i32 0, ptr %lock_address release, align 4
          ret i1 true

        closed:
          ret i1 false
        }

        define internal void @sollang_mouse_event_stream_drop(ptr %context, i1 %destroy) #0 {
        entry:
          %cancel_address = getelementptr i8, ptr %context, i64 20
          store atomic i32 1, ptr %cancel_address release, align 4
          call void @sollang_linux_mouse_signal(ptr %context)
          br i1 %destroy, label %join_worker, label %cancelled_only

        cancelled_only:
          ret void

        join_worker:
          %thread_address = getelementptr i8, ptr %context, i64 32
          %thread = load i64, ptr %thread_address, align 8
          %joined = call i32 @pthread_join(i64 %thread, ptr null)
          %disabled = call i64 @write(i32 1, ptr @sollang_mouse_disable, i64 16)
          %termios_address = getelementptr i8, ptr %context, i64 48
          %original = load ptr, ptr %termios_address, align 8
          %restored = call i32 @tcsetattr(i32 0, i32 0, ptr %original)
          %event_address = getelementptr i8, ptr %context, i64 28
          %event_fd = load i32, ptr %event_address, align 4
          %closed_event = call i32 @close(i32 %event_fd)
          %buffer_address = getelementptr i8, ptr %context, i64 40
          %buffer = load ptr, ptr %buffer_address, align 8
          call void @sollang_free(ptr %original)
          call void @sollang_free(ptr %buffer)
          call void @sollang_free(ptr %context)
          ret void
        }
        """;


    public static string AsyncFilePushRequestFunction() =>
        """
        define internal void @sollang_file_push_request(ptr %control) #0 {
        entry:
          %next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 16
          br label %push

        push:
          %head = load atomic ptr, ptr @sollang_file_request_head acquire, align 8
          store ptr %head, ptr %next_slot, align 8
          %exchange = cmpxchg ptr @sollang_file_request_head, ptr %head, ptr %control release monotonic
          %pushed = extractvalue { ptr, i1 } %exchange, 1
          br i1 %pushed, label %signal, label %push

        signal:
          call void @sollang_platform_file_worker_signal_request()
          ret void
        }
        """;

    public static string IoPushCompletionFunction() =>
        """
        define internal void @sollang_io_push_completion(ptr %control) #0 {
        entry:
          %next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 16
          br label %push

        push:
          %head = load atomic ptr, ptr @sollang_io_completion_head acquire, align 8
          store ptr %head, ptr %next_slot, align 8
          %exchange = cmpxchg ptr @sollang_io_completion_head, ptr %head, ptr %control release monotonic
          %pushed = extractvalue { ptr, i1 } %exchange, 1
          br i1 %pushed, label %done, label %push

        done:
          ret void
        }
        """;

    public static string AsyncFileWorkerFunction() =>
        """
        define internal void @sollang_file_worker_run() #0 {
        entry:
          br label %wait

        wait:
          call void @sollang_platform_file_worker_wait_request()
          %stopping_value = load atomic i32, ptr @sollang_file_worker_stopping acquire, align 4
          %stopping = icmp ne i32 %stopping_value, 0
          br i1 %stopping, label %stopped, label %take_batch

        take_batch:
          %batch = atomicrmw xchg ptr @sollang_file_request_head, ptr null acq_rel
          br label %reverse

        reverse:
          %current = phi ptr [ %batch, %take_batch ], [ %next, %reverse_one ]
          %reversed = phi ptr [ null, %take_batch ], [ %current, %reverse_one ]
          %has_current = icmp ne ptr %current, null
          br i1 %has_current, label %reverse_one, label %process

        reverse_one:
          %current_next_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 16
          %next = load ptr, ptr %current_next_slot, align 8
          store ptr %reversed, ptr %current_next_slot, align 8
          br label %reverse

        process:
          %request = phi ptr [ %reversed, %reverse ], [ %next_request_value, %process_bridge ]
          %has_request = icmp ne ptr %request, null
          br i1 %has_request, label %read, label %signal

        read:
          %request_next_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 16
          %request_next = load ptr, ptr %request_next_slot, align 8
          %phase_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 12
          %phase = load atomic i32, ptr %phase_slot acquire, align 4
          %cancelled_before_read = icmp eq i32 %phase, 3
          br i1 %cancelled_before_read, label %record_cancelled, label %perform_read

        perform_read:
          %size_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 11
          %size = load i32, ptr %size_slot, align 4
          %size64 = zext i32 %size to i64
          %data_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 13
          %explicit_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 19
          %explicit = load i32, ptr %explicit_slot, align 4
          %is_explicit = icmp ne i32 %explicit, 0
          br i1 %is_explicit, label %inspect_owned_operation, label %perform_compatibility_read

        perform_compatibility_read:
          %compatibility_result = call %sollang.file_count_result @sollang_platform_read_file_bytes(ptr %data_slot, i64 %size64)
          br label %record_read

        inspect_owned_operation:
          %operation_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 20
          %operation = load i32, ptr %operation_slot, align 4
          %is_open_read = icmp eq i32 %operation, 3
          br i1 %is_open_read, label %perform_owned_open_read, label %inspect_owned_open_write

        inspect_owned_open_write:
          %is_open_write = icmp eq i32 %operation, 4
          br i1 %is_open_write, label %perform_owned_open_write, label %inspect_owned_sync

        inspect_owned_sync:
          %is_sync = icmp eq i32 %operation, 2
          br i1 %is_sync, label %perform_owned_sync, label %inspect_owned_transfer

        inspect_owned_transfer:
          %is_write = icmp eq i32 %operation, 1
          br i1 %is_write, label %perform_owned_write, label %inspect_owned_buffer_read

        inspect_owned_buffer_read:
          %is_buffer_read = icmp eq i32 %operation, 5
          br i1 %is_buffer_read, label %perform_owned_buffer_read, label %inspect_owned_buffer_write

        inspect_owned_buffer_write:
          %is_buffer_write = icmp eq i32 %operation, 6
          br i1 %is_buffer_write, label %perform_owned_buffer_write, label %inspect_owned_noop

        inspect_owned_noop:
          %is_noop = icmp eq i32 %operation, 7
          %is_cancelled_noop = icmp eq i32 %operation, 8
          %is_known_noop = or i1 %is_noop, %is_cancelled_noop
          br i1 %is_known_noop, label %perform_owned_noop, label %perform_owned_read

        perform_owned_read:
          %owned_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          %owned_handle = load i64, ptr %owned_handle_slot, align 8
          %owned_offset_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 18
          %owned_offset = load i64, ptr %owned_offset_slot, align 8
          %owned_result = call %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %owned_handle, ptr %data_slot, i64 %size64, i64 %owned_offset)
          br label %record_read

        perform_owned_buffer_read:
          %buffer_read_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          %buffer_read_handle = load i64, ptr %buffer_read_handle_slot, align 8
          %buffer_read_offset_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 18
          %buffer_read_offset = load i64, ptr %buffer_read_offset_slot, align 8
          %buffer_read_pointer_value = load i64, ptr %data_slot, align 8
          %buffer_read_pointer = inttoptr i64 %buffer_read_pointer_value to ptr
          %buffer_read_result = call %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %buffer_read_handle, ptr %buffer_read_pointer, i64 %size64, i64 %buffer_read_offset)
          br label %record_read

        perform_owned_write:
          %write_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          %write_handle = load i64, ptr %write_handle_slot, align 8
          %write_offset_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 18
          %write_offset = load i64, ptr %write_offset_slot, align 8
          %write_result = call %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %write_handle, ptr %data_slot, i64 %size64, i64 %write_offset)
          br label %record_read

        perform_owned_buffer_write:
          %buffer_write_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          %buffer_write_handle = load i64, ptr %buffer_write_handle_slot, align 8
          %buffer_write_offset_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 18
          %buffer_write_offset = load i64, ptr %buffer_write_offset_slot, align 8
          %buffer_write_pointer_value = load i64, ptr %data_slot, align 8
          %buffer_write_pointer = inttoptr i64 %buffer_write_pointer_value to ptr
          %buffer_write_result = call %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %buffer_write_handle, ptr %buffer_write_pointer, i64 %size64, i64 %buffer_write_offset)
          br label %record_read

        perform_owned_noop:
          %noop_result0 = insertvalue %sollang.file_count_result poison, i64 0, 0
          %noop_result = insertvalue %sollang.file_count_result %noop_result0, i32 0, 1
          br label %record_read

        perform_owned_sync:
          %sync_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          %sync_handle = load i64, ptr %sync_handle_slot, align 8
          %sync_ok = call i32 @sollang_platform_sync_owned_file(i64 %sync_handle)
          %sync_result0 = insertvalue %sollang.file_count_result poison, i64 0, 0
          %sync_result = insertvalue %sollang.file_count_result %sync_result0, i32 %sync_ok, 1
          br label %record_read

        perform_owned_open_read:
          %open_read_path = load ptr, ptr %data_slot, align 8
          %open_read_length_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 18
          %open_read_length = load i64, ptr %open_read_length_slot, align 8
          %open_read_result = call %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %open_read_path, i64 %open_read_length)
          br label %record_open

        perform_owned_open_write:
          %open_write_path = load ptr, ptr %data_slot, align 8
          %open_write_length_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 18
          %open_write_length = load i64, ptr %open_write_length_slot, align 8
          %open_write_result = call %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %open_write_path, i64 %open_write_length)
          br label %record_open

        record_open:
          %open_result = phi %sollang.file_handle_result [ %open_read_result, %perform_owned_open_read ], [ %open_write_result, %perform_owned_open_write ]
          %open_handle = extractvalue %sollang.file_handle_result %open_result, 0
          %open_ok = extractvalue %sollang.file_handle_result %open_result, 1
          %open_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          store i64 %open_handle, ptr %open_handle_slot, align 8
          %open_count_result0 = insertvalue %sollang.file_count_result poison, i64 0, 0
          %open_count_result = insertvalue %sollang.file_count_result %open_count_result0, i32 %open_ok, 1
          br label %record_read

        record_read:
          %result = phi %sollang.file_count_result [ %compatibility_result, %perform_compatibility_read ], [ %owned_result, %perform_owned_read ], [ %buffer_read_result, %perform_owned_buffer_read ], [ %write_result, %perform_owned_write ], [ %buffer_write_result, %perform_owned_buffer_write ], [ %noop_result, %perform_owned_noop ], [ %sync_result, %perform_owned_sync ], [ %open_count_result, %record_open ]
          %count = extractvalue %sollang.file_count_result %result, 0
          %ok = extractvalue %sollang.file_count_result %result, 1
          %count_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 14
          store i64 %count, ptr %count_slot, align 8
          %ok_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 15
          store i32 %ok, ptr %ok_slot, align 4
          ; Completion may publish only from pending. A cancellation that
          ; wins this transition must remain visible to the drain.
          %completion_exchange = cmpxchg ptr %phase_slot, i32 1, i32 2 release monotonic
          br label %queue_completion

        record_cancelled:
          %cancel_count_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 14
          store i64 0, ptr %cancel_count_slot, align 8
          %cancel_ok_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 15
          store i32 0, ptr %cancel_ok_slot, align 4
          br label %queue_completion

        queue_completion:
          %completion_explicit_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 19
          %completion_explicit = load i32, ptr %completion_explicit_slot, align 4
          %completion_is_duplicate = icmp eq i32 %completion_explicit, 1
          br i1 %completion_is_duplicate, label %close_owned_request, label %inspect_transferred_open

        inspect_transferred_open:
          %completion_is_open = icmp eq i32 %completion_explicit, 2
          br i1 %completion_is_open, label %inspect_open_completion, label %push_completed_request

        inspect_open_completion:
          %open_completion_phase = load atomic i32, ptr %phase_slot acquire, align 4
          %open_completion_cancelled = icmp eq i32 %open_completion_phase, 3
          br i1 %open_completion_cancelled, label %close_owned_request, label %push_completed_request

        close_owned_request:
          %completion_handle_slot = getelementptr %sollang.task_control, ptr %request, i32 0, i32 17
          %completion_handle = load i64, ptr %completion_handle_slot, align 8
          call void @sollang_platform_close_owned_file(i64 %completion_handle)
          store i32 0, ptr %completion_explicit_slot, align 4
          br label %push_completed_request

        push_completed_request:
          call void @sollang_io_push_completion(ptr %request)
          br label %next_request

        next_request:
          br label %process_next

        process_next:
          %next_request_value = phi ptr [ %request_next, %next_request ]
          %next_request_present = icmp ne ptr %next_request_value, null
          br i1 %next_request_present, label %process_bridge, label %signal

        process_bridge:
          br label %process

        signal:
          call void @sollang_platform_io_signal_completion()
          br label %wait

        stopped:
          ret void
        }
        """;

    public static string IoDrainCompletionsFunction() =>
        """
        define internal i1 @sollang_io_drain_completions() #0 {
        entry:
          %batch = atomicrmw xchg ptr @sollang_io_completion_head, ptr null acq_rel
          %has_batch = icmp ne ptr %batch, null
          br i1 %has_batch, label %clear_signal, label %none

        clear_signal:
          call void @sollang_platform_io_clear_completion()
          br label %reverse

        reverse:
          %current = phi ptr [ %batch, %clear_signal ], [ %next, %reverse_one ]
          %reversed = phi ptr [ null, %clear_signal ], [ %current, %reverse_one ]
          %has_current = icmp ne ptr %current, null
          br i1 %has_current, label %reverse_one, label %drain

        reverse_one:
          %current_next_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 16
          %next = load ptr, ptr %current_next_slot, align 8
          store ptr %reversed, ptr %current_next_slot, align 8
          br label %reverse

        drain:
          %control = phi ptr [ %reversed, %reverse ], [ %control_next, %continue ]
          %has_control = icmp ne ptr %control, null
          br i1 %has_control, label %inspect, label %done

        inspect:
          %control_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 16
          %control_next = load ptr, ptr %control_next_slot, align 8
          store ptr null, ptr %control_next_slot, align 8
          %phase_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 12
          %phase = load atomic i32, ptr %phase_slot acquire, align 4
          %cancelled = icmp eq i32 %phase, 3
          br i1 %cancelled, label %destroy_cancelled, label %wake

        destroy_cancelled:
          %cancel_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 6
          %cancel = load ptr, ptr %cancel_slot, align 8
          call void %cancel(ptr %control)
          call void @sollang_free(ptr %control)
          br label %continue

        wake:
          call void @sollang_task_enqueue_ready(ptr %control)
          br label %continue

        continue:
          %remaining = atomicrmw sub ptr @sollang_io_outstanding, i64 1 acq_rel
          br label %drain

        done:
          ret i1 true

        none:
          ret i1 false
        }
        """;

    public static string AsyncFileSubmitFunction() =>
        """
        define internal void @sollang_file_submit(ptr %control, i32 %size) #0 {
        entry:
          %started = load i1, ptr @sollang_file_worker_started, align 1
          br i1 %started, label %initialize, label %start

        start:
          %start_ok = call i1 @sollang_platform_file_worker_start()
          br i1 %start_ok, label %mark_started, label %failed

        mark_started:
          store i1 true, ptr @sollang_file_worker_started, align 1
          br label %initialize

        initialize:
          %size_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 11
          store i32 %size, ptr %size_slot, align 4
          %phase_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 12
          store atomic i32 1, ptr %phase_slot release, align 4
          %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
          store i32 6, ptr %status_slot, align 4
          %old_count = atomicrmw add ptr @sollang_io_outstanding, i64 1 acq_rel
          call void @sollang_file_push_request(ptr %control)
          ret void

        failed:
          call void @llvm.trap()
          unreachable
        }
        """;

    public static string IoWaitIdleFunction() =>
        """
        define internal void @sollang_file_wait_idle() #0 {
        entry:
          br label %check

        check:
          %outstanding = load atomic i64, ptr @sollang_io_outstanding acquire, align 8
          %idle = icmp eq i64 %outstanding, 0
          br i1 %idle, label %done, label %wait

        wait:
          call void @sollang_platform_io_wait_completion(i64 -1)
          %progress = call i1 @sollang_io_drain_completions()
          br label %check

        done:
          ret void
        }
        """;

    public static string ComputeWindowsFunctions() =>
        """
        define internal i32 @sollang_windows_compute_worker(ptr %unused) #0 {
        entry:
          br label %wait

        wait:
          %semaphore = load ptr, ptr @sollang_compute_semaphore, align 8
          %waited = call i32 @WaitForSingleObject(ptr %semaphore, i32 -1)
          %stopping_value = load atomic i32, ptr @sollang_compute_stopping acquire, align 4
          %stopping = icmp ne i32 %stopping_value, 0
          br i1 %stopping, label %stopped, label %take

        take:
          %group = load atomic ptr, ptr @sollang_compute_group_current acquire, align 8
          %count_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 3
          %count = load i64, ptr %count_slot, align 8
          br label %claim

        claim:
          %index = atomicrmw add ptr @sollang_compute_next, i64 1 acq_rel
          %failure_limit_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11
          %failure_limit = load atomic i64, ptr %failure_limit_slot acquire, align 8
          %within_count = icmp ult i64 %index, %count
          %before_failure = icmp ult i64 %index, %failure_limit
          %has_work = and i1 %within_count, %before_failure
          br i1 %has_work, label %work, label %complete

        work:
          %callback_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 0
          %callback = load ptr, ptr %callback_slot, align 8
          %running_before = atomicrmw add ptr @sollang_compute_running, i32 1 acq_rel
          %running_now = add i32 %running_before, 1
          %peak_before = atomicrmw max ptr @sollang_compute_peak, i32 %running_now acq_rel
          %gate_pair = cmpxchg ptr @sollang_compute_parent_gate, i32 0, i32 1 acq_rel acquire
          %gate_owner = extractvalue { i32, i1 } %gate_pair, 1
          br i1 %gate_owner, label %wait_parent, label %worker_callback

        wait_parent:
          %parent_gate = load atomic i32, ptr @sollang_compute_parent_gate acquire, align 4
          %parent_ready = icmp eq i32 %parent_gate, 2
          br i1 %parent_ready, label %worker_callback, label %wait_parent

        worker_callback:
          call void @sollang_compute_output_enter(ptr %group, i64 %index)
          call void %callback(ptr %group, i64 %index)
          call void @sollang_compute_output_leave()
          %running_after = atomicrmw sub ptr @sollang_compute_running, i32 1 acq_rel
          br label %claim

        complete:
          %previous = atomicrmw sub ptr @sollang_compute_active, i32 1 acq_rel
          %last = icmp eq i32 %previous, 1
          br i1 %last, label %signal, label %barrier

        barrier:
          %barrier_event = load ptr, ptr @sollang_compute_completion_event, align 8
          %barrier_waited = call i32 @WaitForSingleObject(ptr %barrier_event, i32 -1)
          %departed_before = atomicrmw add ptr @sollang_compute_barrier_departed, i32 1 acq_rel
          br label %wait

        signal:
          %event = load ptr, ptr @sollang_compute_completion_event, align 8
          %signalled = call i32 @SetEvent(ptr %event)
          br label %wait

        stopped:
          ret i32 0
        }

        define internal i1 @sollang_compute_start() #0 {
        entry:
          %existing = load i32, ptr @sollang_compute_worker_count, align 4
          %already = icmp sgt i32 %existing, 0
          br i1 %already, label %ready, label %create_sync

        create_sync:
          %output_ready = call i1 @sollang_compute_output_initialize()
          br i1 %output_ready, label %create_platform_sync, label %fail

        create_platform_sync:
          %semaphore = call ptr @CreateSemaphoreA(ptr null, i32 0, i32 64, ptr null)
          %semaphore_ok = icmp ne ptr %semaphore, null
          br i1 %semaphore_ok, label %create_event, label %fail

        create_event:
          store ptr %semaphore, ptr @sollang_compute_semaphore, align 8
          %event = call ptr @CreateEventA(ptr null, i32 1, i32 0, ptr null)
          %event_ok = icmp ne ptr %event, null
          br i1 %event_ok, label %count, label %fail

        count:
          store ptr %event, ptr @sollang_compute_completion_event, align 8
          %reported = call i32 @GetActiveProcessorCount(i16 -1)
          %positive = icmp sgt i32 %reported, 0
          %at_least_one = select i1 %positive, i32 %reported, i32 1
          %configured = load i32, ptr @sollang_compute_worker_limit, align 4
          %has_configured = icmp sgt i32 %configured, 0
          %selected = select i1 %has_configured, i32 %configured, i32 %at_least_one
          %too_many = icmp sgt i32 %selected, 64
          %bounded = select i1 %too_many, i32 64, i32 %selected
          br label %create_workers

        create_workers:
          %index = phi i32 [ 0, %count ], [ %next, %created ]
          %done = icmp eq i32 %index, %bounded
          br i1 %done, label %publish, label %create_one

        create_one:
          %worker = call ptr @CreateThread(ptr null, i64 0, ptr @sollang_windows_compute_worker, ptr null, i32 0, ptr null)
          %worker_ok = icmp ne ptr %worker, null
          br i1 %worker_ok, label %created, label %publish

        created:
          %slot = getelementptr [64 x ptr], ptr @sollang_compute_worker_handles, i32 0, i32 %index
          store ptr %worker, ptr %slot, align 8
          %next = add i32 %index, 1
          br label %create_workers

        publish:
          %created_count = phi i32 [ %bounded, %create_workers ], [ %index, %create_one ]
          store i32 %created_count, ptr @sollang_compute_worker_count, align 4
          %has_workers = icmp sgt i32 %created_count, 0
          br i1 %has_workers, label %ready, label %fail

        ready:
          ret i1 true

        fail:
          call void @sollang_compute_output_dispose()
          ret i1 false
        }

        define internal void @sollang_compute_execute(ptr %group) #0 {
        entry:
          %started = call i1 @sollang_compute_start()
          br i1 %started, label %submit, label %failed

        submit:
          %count_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 3
          %count = load i64, ptr %count_slot, align 8
          %empty = icmp eq i64 %count, 0
          br i1 %empty, label %cleanup_empty, label %publish

        cleanup_empty:
          %empty_sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5
          %empty_sinks = load ptr, ptr %empty_sinks_slot, align 8
          call void @sollang_memory_output_sink_array_dispose(ptr %empty_sinks, i64 0)
          br label %done

        publish:
          store atomic i64 0, ptr @sollang_compute_next release, align 8
          store atomic i32 0, ptr @sollang_compute_peak release, align 4
          store atomic i32 0, ptr @sollang_compute_parent_gate release, align 4
          %workers = load i32, ptr @sollang_compute_worker_count, align 4
          store atomic i32 %workers, ptr @sollang_compute_active release, align 4
          store atomic ptr %group, ptr @sollang_compute_group_current release, align 8
          %event = load ptr, ptr @sollang_compute_completion_event, align 8
          %reset = call i32 @ResetEvent(ptr %event)
          %help_first_index = atomicrmw add ptr @sollang_compute_next, i64 1 acq_rel
          %semaphore = load ptr, ptr @sollang_compute_semaphore, align 8
          %released = call i32 @ReleaseSemaphore(ptr %semaphore, i32 %workers, ptr null)
          %help_has_peer_work = icmp ugt i64 %count, 1
          br i1 %help_has_peer_work, label %help_wait_worker, label %help_begin

        help_wait_worker:
          %help_worker_gate = load atomic i32, ptr @sollang_compute_parent_gate acquire, align 4
          %help_worker_ready = icmp eq i32 %help_worker_gate, 1
          br i1 %help_worker_ready, label %help_begin, label %help_wait_worker

        help_begin:
          br label %help_work

        help_claim:
          %help_claimed_index = atomicrmw add ptr @sollang_compute_next, i64 1 acq_rel
          %help_failure_limit_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11
          %help_failure_limit = load atomic i64, ptr %help_failure_limit_slot acquire, align 8
          %help_within_count = icmp ult i64 %help_claimed_index, %count
          %help_before_failure = icmp ult i64 %help_claimed_index, %help_failure_limit
          %help_has_work = and i1 %help_within_count, %help_before_failure
          br i1 %help_has_work, label %help_work, label %help_wait

        help_work:
          %help_index = phi i64 [ %help_first_index, %help_begin ], [ %help_claimed_index, %help_claim ]
          %help_callback_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 0
          %help_callback = load ptr, ptr %help_callback_slot, align 8
          %help_running_before = atomicrmw add ptr @sollang_compute_running, i32 1 acq_rel
          %help_running_now = add i32 %help_running_before, 1
          %help_peak_before = atomicrmw max ptr @sollang_compute_peak, i32 %help_running_now acq_rel
          store atomic i32 2, ptr @sollang_compute_parent_gate release, align 4
          call void @sollang_compute_output_enter(ptr %group, i64 %help_index)
          call void %help_callback(ptr %group, i64 %help_index)
          call void @sollang_compute_output_leave()
          %help_running_after = atomicrmw sub ptr @sollang_compute_running, i32 1 acq_rel
          br label %help_claim

        help_wait:
          %waited = call i32 @WaitForSingleObject(ptr %event, i32 -1)
          br label %await_departure

        await_departure:
          %departed = load atomic i32, ptr @sollang_compute_barrier_departed acquire, align 4
          %expected_departed = sub i32 %workers, 1
          %all_departed = icmp eq i32 %departed, %expected_departed
          br i1 %all_departed, label %flush_prepare, label %await_departure

        flush_prepare:
          store atomic i32 0, ptr @sollang_compute_barrier_departed release, align 4
          %sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5
          %sinks = load ptr, ptr %sinks_slot, align 8
          %flush_failure_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11
          %flush_failure = load atomic i64, ptr %flush_failure_slot acquire, align 8
          %failure_before_end = icmp ult i64 %flush_failure, %count
          %flush_prefix = select i1 %failure_before_end, i64 %flush_failure, i64 %count
          call void @sollang_memory_output_sink_array_flush_prefix(ptr %sinks, i64 %count, i64 %flush_prefix, ptr %group, ptr @sollang_memory_output_sink_write)
          store atomic ptr null, ptr @sollang_compute_group_current release, align 8
          br label %done

        failed:
          call void @llvm.trap()
          unreachable

        done:
          ret void
        }

        define internal void @sollang_compute_shutdown() #0 {
        entry:
          %workers = load i32, ptr @sollang_compute_worker_count, align 4
          %started = icmp sgt i32 %workers, 0
          br i1 %started, label %stop, label %done

        stop:
          store atomic i32 1, ptr @sollang_compute_stopping release, align 4
          %semaphore = load ptr, ptr @sollang_compute_semaphore, align 8
          %released = call i32 @ReleaseSemaphore(ptr %semaphore, i32 %workers, ptr null)
          br label %join

        join:
          %index = phi i32 [ 0, %stop ], [ %next, %joined ]
          %all_joined = icmp eq i32 %index, %workers
          br i1 %all_joined, label %cleanup, label %join_one

        join_one:
          %slot = getelementptr [64 x ptr], ptr @sollang_compute_worker_handles, i32 0, i32 %index
          %worker = load ptr, ptr %slot, align 8
          %waited = call i32 @WaitForSingleObject(ptr %worker, i32 -1)
          %closed = call i32 @CloseHandle(ptr %worker)
          store ptr null, ptr %slot, align 8
          br label %joined

        joined:
          %next = add i32 %index, 1
          br label %join

        cleanup:
          call void @sollang_compute_output_dispose()
          %closed_semaphore = call i32 @CloseHandle(ptr %semaphore)
          %event = load ptr, ptr @sollang_compute_completion_event, align 8
          %closed_event = call i32 @CloseHandle(ptr %event)
          store ptr null, ptr @sollang_compute_semaphore, align 8
          store ptr null, ptr @sollang_compute_completion_event, align 8
          store i32 0, ptr @sollang_compute_worker_count, align 4
          br label %done

        done:
          ret void
        }
        """;

    public static string ComputeLinuxFunctions() =>
        """
        define internal ptr @sollang_linux_compute_worker(ptr %unused) #0 {
        entry:
          %event_value = alloca i64, align 8
          br label %wait

        wait:
          %work_fd = load i32, ptr @sollang_compute_work_event_fd, align 4
          %waited = call i64 @read(i32 %work_fd, ptr %event_value, i64 8)
          %stopping_value = load atomic i32, ptr @sollang_compute_stopping acquire, align 4
          %stopping = icmp ne i32 %stopping_value, 0
          br i1 %stopping, label %stopped, label %take

        take:
          %generation = load atomic i32, ptr @sollang_compute_generation acquire, align 4
          %group = load atomic ptr, ptr @sollang_compute_group_current acquire, align 8
          %count_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 3
          %count = load i64, ptr %count_slot, align 8
          br label %claim

        claim:
          %index = atomicrmw add ptr @sollang_compute_next, i64 1 acq_rel
          %failure_limit_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11
          %failure_limit = load atomic i64, ptr %failure_limit_slot acquire, align 8
          %within_count = icmp ult i64 %index, %count
          %before_failure = icmp ult i64 %index, %failure_limit
          %has_work = and i1 %within_count, %before_failure
          br i1 %has_work, label %work, label %complete

        work:
          %callback_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 0
          %callback = load ptr, ptr %callback_slot, align 8
          %running_before = atomicrmw add ptr @sollang_compute_running, i32 1 acq_rel
          %running_now = add i32 %running_before, 1
          %peak_before = atomicrmw max ptr @sollang_compute_peak, i32 %running_now acq_rel
          %gate_pair = cmpxchg ptr @sollang_compute_parent_gate, i32 0, i32 1 acq_rel acquire
          %gate_owner = extractvalue { i32, i1 } %gate_pair, 1
          br i1 %gate_owner, label %wait_parent, label %worker_callback

        wait_parent:
          %parent_gate = load atomic i32, ptr @sollang_compute_parent_gate acquire, align 4
          %parent_ready = icmp eq i32 %parent_gate, 2
          br i1 %parent_ready, label %worker_callback, label %wait_parent

        worker_callback:
          call void @sollang_compute_output_enter(ptr %group, i64 %index)
          call void %callback(ptr %group, i64 %index)
          call void @sollang_compute_output_leave()
          %running_after = atomicrmw sub ptr @sollang_compute_running, i32 1 acq_rel
          br label %claim

        complete:
          %previous = atomicrmw sub ptr @sollang_compute_active, i32 1 acq_rel
          %last = icmp eq i32 %previous, 1
          br i1 %last, label %signal, label %barrier_check

        barrier_check:
          %current_generation = load atomic i32, ptr @sollang_compute_generation acquire, align 4
          %generation_advanced = icmp ne i32 %current_generation, %generation
          br i1 %generation_advanced, label %wait, label %barrier_wait

        barrier_wait:
          %futex_waited = call i64 (i64, ...) @syscall(i64 202, ptr @sollang_compute_generation, i32 128, i32 %generation, ptr null, ptr null, i32 0)
          br label %barrier_check

        signal:
          %generation_before = atomicrmw add ptr @sollang_compute_generation, i32 1 acq_rel
          %futex_woken = call i64 (i64, ...) @syscall(i64 202, ptr @sollang_compute_generation, i32 129, i32 2147483647, ptr null, ptr null, i32 0)
          store i64 1, ptr %event_value, align 8
          %completion_fd = load i32, ptr @sollang_compute_completion_event_fd, align 4
          %signalled = call i64 @write(i32 %completion_fd, ptr %event_value, i64 8)
          br label %wait

        stopped:
          ret ptr null
        }

        define internal i1 @sollang_compute_start() #0 {
        entry:
          %existing = load i32, ptr @sollang_compute_worker_count, align 4
          %already = icmp sgt i32 %existing, 0
          br i1 %already, label %ready, label %create_work_event

        create_work_event:
          %output_ready = call i1 @sollang_compute_output_initialize()
          br i1 %output_ready, label %create_platform_sync, label %fail

        create_platform_sync:
          %work_fd = call i32 @eventfd(i32 0, i32 1)
          %work_ok = icmp sge i32 %work_fd, 0
          br i1 %work_ok, label %create_completion_event, label %fail

        create_completion_event:
          store i32 %work_fd, ptr @sollang_compute_work_event_fd, align 4
          %completion_fd = call i32 @eventfd(i32 0, i32 0)
          %completion_ok = icmp sge i32 %completion_fd, 0
          br i1 %completion_ok, label %count, label %close_work

        count:
          store i32 %completion_fd, ptr @sollang_compute_completion_event_fd, align 4
          %reported = call i64 @sysconf(i32 84)
          %positive = icmp sgt i64 %reported, 0
          %at_least_one = select i1 %positive, i64 %reported, i64 1
          %configured32 = load i32, ptr @sollang_compute_worker_limit, align 4
          %configured = sext i32 %configured32 to i64
          %has_configured = icmp sgt i64 %configured, 0
          %selected = select i1 %has_configured, i64 %configured, i64 %at_least_one
          %too_many = icmp sgt i64 %selected, 64
          %bounded64 = select i1 %too_many, i64 64, i64 %selected
          %bounded = trunc i64 %bounded64 to i32
          br label %create_workers

        create_workers:
          %index = phi i32 [ 0, %count ], [ %next, %created ]
          %done = icmp eq i32 %index, %bounded
          br i1 %done, label %publish, label %create_one

        create_one:
          %slot = getelementptr [64 x i64], ptr @sollang_compute_worker_threads, i32 0, i32 %index
          %create = call i32 @pthread_create(ptr %slot, ptr null, ptr @sollang_linux_compute_worker, ptr null)
          %worker_ok = icmp eq i32 %create, 0
          br i1 %worker_ok, label %created, label %publish

        created:
          %next = add i32 %index, 1
          br label %create_workers

        publish:
          %created_count = phi i32 [ %bounded, %create_workers ], [ %index, %create_one ]
          store i32 %created_count, ptr @sollang_compute_worker_count, align 4
          %has_workers = icmp sgt i32 %created_count, 0
          br i1 %has_workers, label %ready, label %close_both

        close_work:
          %closed_work_only = call i32 @close(i32 %work_fd)
          store i32 -1, ptr @sollang_compute_work_event_fd, align 4
          br label %fail

        close_both:
          %closed_completion = call i32 @close(i32 %completion_fd)
          %closed_work = call i32 @close(i32 %work_fd)
          store i32 -1, ptr @sollang_compute_completion_event_fd, align 4
          store i32 -1, ptr @sollang_compute_work_event_fd, align 4
          br label %fail

        ready:
          ret i1 true

        fail:
          call void @sollang_compute_output_dispose()
          ret i1 false
        }

        define internal void @sollang_compute_execute(ptr %group) #0 {
        entry:
          %started = call i1 @sollang_compute_start()
          br i1 %started, label %submit, label %failed

        submit:
          %count_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 3
          %count = load i64, ptr %count_slot, align 8
          %empty = icmp eq i64 %count, 0
          br i1 %empty, label %cleanup_empty, label %publish

        cleanup_empty:
          %empty_sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5
          %empty_sinks = load ptr, ptr %empty_sinks_slot, align 8
          call void @sollang_memory_output_sink_array_dispose(ptr %empty_sinks, i64 0)
          br label %done

        publish:
          store atomic i64 0, ptr @sollang_compute_next release, align 8
          store atomic i32 0, ptr @sollang_compute_peak release, align 4
          store atomic i32 0, ptr @sollang_compute_parent_gate release, align 4
          %workers = load i32, ptr @sollang_compute_worker_count, align 4
          store atomic i32 %workers, ptr @sollang_compute_active release, align 4
          store atomic ptr %group, ptr @sollang_compute_group_current release, align 8
          %workers64 = zext i32 %workers to i64
          %event_value = alloca i64, align 8
          store i64 %workers64, ptr %event_value, align 8
          %help_first_index = atomicrmw add ptr @sollang_compute_next, i64 1 acq_rel
          %work_fd = load i32, ptr @sollang_compute_work_event_fd, align 4
          %released = call i64 @write(i32 %work_fd, ptr %event_value, i64 8)
          %help_has_peer_work = icmp ugt i64 %count, 1
          br i1 %help_has_peer_work, label %help_wait_worker, label %help_begin

        help_wait_worker:
          %help_worker_gate = load atomic i32, ptr @sollang_compute_parent_gate acquire, align 4
          %help_worker_ready = icmp eq i32 %help_worker_gate, 1
          br i1 %help_worker_ready, label %help_begin, label %help_wait_worker

        help_begin:
          br label %help_work

        help_claim:
          %help_claimed_index = atomicrmw add ptr @sollang_compute_next, i64 1 acq_rel
          %help_failure_limit_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11
          %help_failure_limit = load atomic i64, ptr %help_failure_limit_slot acquire, align 8
          %help_within_count = icmp ult i64 %help_claimed_index, %count
          %help_before_failure = icmp ult i64 %help_claimed_index, %help_failure_limit
          %help_has_work = and i1 %help_within_count, %help_before_failure
          br i1 %help_has_work, label %help_work, label %help_wait

        help_work:
          %help_index = phi i64 [ %help_first_index, %help_begin ], [ %help_claimed_index, %help_claim ]
          %help_callback_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 0
          %help_callback = load ptr, ptr %help_callback_slot, align 8
          %help_running_before = atomicrmw add ptr @sollang_compute_running, i32 1 acq_rel
          %help_running_now = add i32 %help_running_before, 1
          %help_peak_before = atomicrmw max ptr @sollang_compute_peak, i32 %help_running_now acq_rel
          store atomic i32 2, ptr @sollang_compute_parent_gate release, align 4
          call void @sollang_compute_output_enter(ptr %group, i64 %help_index)
          call void %help_callback(ptr %group, i64 %help_index)
          call void @sollang_compute_output_leave()
          %help_running_after = atomicrmw sub ptr @sollang_compute_running, i32 1 acq_rel
          br label %help_claim

        help_wait:
          %completion_fd = load i32, ptr @sollang_compute_completion_event_fd, align 4
          %waited = call i64 @read(i32 %completion_fd, ptr %event_value, i64 8)
          br label %flush_prepare

        flush_prepare:
          %sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5
          %sinks = load ptr, ptr %sinks_slot, align 8
          %flush_failure_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11
          %flush_failure = load atomic i64, ptr %flush_failure_slot acquire, align 8
          %failure_before_end = icmp ult i64 %flush_failure, %count
          %flush_prefix = select i1 %failure_before_end, i64 %flush_failure, i64 %count
          call void @sollang_memory_output_sink_array_flush_prefix(ptr %sinks, i64 %count, i64 %flush_prefix, ptr %group, ptr @sollang_memory_output_sink_write)
          store atomic ptr null, ptr @sollang_compute_group_current release, align 8
          br label %done

        failed:
          unreachable

        done:
          ret void
        }

        define internal void @sollang_compute_shutdown() #0 {
        entry:
          %workers = load i32, ptr @sollang_compute_worker_count, align 4
          %started = icmp sgt i32 %workers, 0
          br i1 %started, label %stop, label %done

        stop:
          store atomic i32 1, ptr @sollang_compute_stopping release, align 4
          %workers64 = zext i32 %workers to i64
          %event_value = alloca i64, align 8
          store i64 %workers64, ptr %event_value, align 8
          %work_fd = load i32, ptr @sollang_compute_work_event_fd, align 4
          %released = call i64 @write(i32 %work_fd, ptr %event_value, i64 8)
          br label %join

        join:
          %index = phi i32 [ 0, %stop ], [ %next, %joined ]
          %all_joined = icmp eq i32 %index, %workers
          br i1 %all_joined, label %cleanup, label %join_one

        join_one:
          %slot = getelementptr [64 x i64], ptr @sollang_compute_worker_threads, i32 0, i32 %index
          %worker = load i64, ptr %slot, align 8
          %joined_status = call i32 @pthread_join(i64 %worker, ptr null)
          store i64 0, ptr %slot, align 8
          br label %joined

        joined:
          %next = add i32 %index, 1
          br label %join

        cleanup:
          call void @sollang_compute_output_dispose()
          %completion_fd = load i32, ptr @sollang_compute_completion_event_fd, align 4
          %closed_completion = call i32 @close(i32 %completion_fd)
          %closed_work = call i32 @close(i32 %work_fd)
          store i32 -1, ptr @sollang_compute_completion_event_fd, align 4
          store i32 -1, ptr @sollang_compute_work_event_fd, align 4
          store i32 0, ptr @sollang_compute_worker_count, align 4
          br label %done

        done:
          ret void
        }
        """;

    public static string ComputeQueryFunctions() =>
        """
        define internal i32 @sollang_compute_workers() #0 {
        entry:
          %started = call i1 @sollang_compute_start()
          br i1 %started, label %read, label %failed

        read:
          %workers = load i32, ptr @sollang_compute_worker_count, align 4
          ret i32 %workers

        failed:
          ret i32 0
        }

        define internal i32 @sollang_compute_limit_workers(i32 %requested) #0 {
        entry:
          %existing = load i32, ptr @sollang_compute_worker_count, align 4
          %already_started = icmp sgt i32 %existing, 0
          br i1 %already_started, label %started, label %configure

        configure:
          %positive = icmp sgt i32 %requested, 0
          %at_least_one = select i1 %positive, i32 %requested, i32 1
          %too_many = icmp sgt i32 %at_least_one, 64
          %bounded = select i1 %too_many, i32 64, i32 %at_least_one
          store i32 %bounded, ptr @sollang_compute_worker_limit, align 4
          %started_ok = call i1 @sollang_compute_start()
          br i1 %started_ok, label %read, label %failed

        started:
          ret i32 %existing

        read:
          %workers = load i32, ptr @sollang_compute_worker_count, align 4
          ret i32 %workers

        failed:
          ret i32 0
        }

        define internal i32 @sollang_compute_peak_workers() #0 {
        entry:
          %peak = load atomic i32, ptr @sollang_compute_peak acquire, align 4
          ret i32 %peak
        }
        """;

    public static string MemoryOutputSinkFunctions() =>
        """
        define internal void @sollang_memory_output_sink_append(ptr %sink, ptr %data, i64 %len) #0 {
        entry:
          %data_slot = getelementptr %sollang.output_sink, ptr %sink, i32 0, i32 0
          %length_slot = getelementptr %sollang.output_sink, ptr %sink, i32 0, i32 1
          %capacity_slot = getelementptr %sollang.output_sink, ptr %sink, i32 0, i32 2
          %length = load i64, ptr %length_slot, align 8
          %capacity = load i64, ptr %capacity_slot, align 8
          %required = add i64 %length, %len
          %fits = icmp ule i64 %required, %capacity
          br i1 %fits, label %append, label %grow

        grow:
          %doubled = shl i64 %capacity, 1
          %minimum = icmp ult i64 %doubled, 256
          %base_capacity = select i1 %minimum, i64 256, i64 %doubled
          %enough = icmp uge i64 %base_capacity, %required
          %new_capacity = select i1 %enough, i64 %base_capacity, i64 %required
          %new_data = call ptr @sollang_alloc(i64 %new_capacity)
          %old_data = load ptr, ptr %data_slot, align 8
          %has_old = icmp ne ptr %old_data, null
          br i1 %has_old, label %copy_old, label %publish

        copy_old:
          call void @llvm.memcpy.p0.p0.i64(ptr %new_data, ptr %old_data, i64 %length, i1 false)
          call void @sollang_free(ptr %old_data)
          br label %publish

        publish:
          store ptr %new_data, ptr %data_slot, align 8
          store i64 %new_capacity, ptr %capacity_slot, align 8
          br label %append

        append:
          %current_data = load ptr, ptr %data_slot, align 8
          %destination = getelementptr i8, ptr %current_data, i64 %length
          call void @llvm.memcpy.p0.p0.i64(ptr %destination, ptr %data, i64 %len, i1 false)
          store i64 %required, ptr %length_slot, align 8
          ret void
        }

        define internal void @sollang_memory_output_sink_array_flush_prefix(ptr %sinks, i64 %count, i64 %prefix, ptr %context, ptr %writer) #0 {
        entry:
          br label %flush_loop

        flush_loop:
          %index = phi i64 [ 0, %entry ], [ %next, %flush_one_done ]
          %done = icmp eq i64 %index, %count
          br i1 %done, label %finish, label %flush_one

        flush_one:
          %sink = getelementptr %sollang.output_sink, ptr %sinks, i64 %index
          %data_slot = getelementptr %sollang.output_sink, ptr %sink, i32 0, i32 0
          %length_slot = getelementptr %sollang.output_sink, ptr %sink, i32 0, i32 1
          %data = load ptr, ptr %data_slot, align 8
          %length = load i64, ptr %length_slot, align 8
          %has_data = icmp ne ptr %data, null
          %in_prefix = icmp ult i64 %index, %prefix
          %should_write = and i1 %has_data, %in_prefix
          br i1 %should_write, label %write, label %dispose_one

        write:
          call void %writer(ptr %context, ptr %data, i64 %length)
          br label %dispose_one

        dispose_one:
          call void @sollang_free(ptr %data)
          br label %flush_one_done

        flush_one_done:
          %next = add i64 %index, 1
          br label %flush_loop

        finish:
          call void @sollang_free(ptr %sinks)
          ret void
        }

        define internal void @sollang_memory_output_sink_array_flush(ptr %sinks, i64 %count, ptr %context, ptr %writer) #0 {
        entry:
          call void @sollang_memory_output_sink_array_flush_prefix(ptr %sinks, i64 %count, i64 %count, ptr %context, ptr %writer)
          ret void
        }

        define internal void @sollang_memory_output_sink_array_dispose(ptr %sinks, i64 %count) #0 {
        entry:
          br label %dispose_loop

        dispose_loop:
          %index = phi i64 [ 0, %entry ], [ %next, %dispose_one ]
          %done = icmp eq i64 %index, %count
          br i1 %done, label %finish, label %dispose_one

        dispose_one:
          %sink = getelementptr %sollang.output_sink, ptr %sinks, i64 %index
          %data_slot = getelementptr %sollang.output_sink, ptr %sink, i32 0, i32 0
          %data = load ptr, ptr %data_slot, align 8
          call void @sollang_free(ptr %data)
          %next = add i64 %index, 1
          br label %dispose_loop

        finish:
          call void @sollang_free(ptr %sinks)
          ret void
        }
        """;

    public static string ComputeDirectOutputFunctions() =>
        """
        define internal i1 @sollang_compute_output_initialize() #0 {
        entry:
          ret i1 true
        }

        define internal void @sollang_compute_output_enter(ptr %group, i64 %index) #0 {
        entry:
          ret void
        }

        define internal void @sollang_compute_output_leave() #0 {
        entry:
          ret void
        }

        define internal void @sollang_compute_output_dispose() #0 {
        entry:
          ret void
        }
        """;

    public static string ComputeWindowsOutputFunctions() =>
        """
        define internal i1 @sollang_compute_output_initialize() #0 {
        entry:
          %key = call i32 @TlsAlloc()
          %ok = icmp ne i32 %key, -1
          store i32 %key, ptr @sollang_output_sink_tls, align 4
          ret i1 %ok
        }

        define internal void @sollang_compute_output_enter(ptr %group, i64 %index) #0 {
        entry:
          %sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5
          %sinks = load ptr, ptr %sinks_slot, align 8
          %sink = getelementptr %sollang.output_sink, ptr %sinks, i64 %index
          %key = load i32, ptr @sollang_output_sink_tls, align 4
          %ignored = call i32 @TlsSetValue(i32 %key, ptr %sink)
          ret void
        }

        define internal void @sollang_compute_output_leave() #0 {
        entry:
          %key = load i32, ptr @sollang_output_sink_tls, align 4
          %ignored = call i32 @TlsSetValue(i32 %key, ptr null)
          ret void
        }

        define internal void @sollang_compute_output_dispose() #0 {
        entry:
          %key = load i32, ptr @sollang_output_sink_tls, align 4
          %ready = icmp ne i32 %key, -1
          br i1 %ready, label %dispose, label %done
        dispose:
          %ignored = call i32 @TlsFree(i32 %key)
          store i32 -1, ptr @sollang_output_sink_tls, align 4
          br label %done
        done:
          ret void
        }
        """;

    public static string ComputeLinuxOutputFunctions() =>
        """
        define internal i1 @sollang_compute_output_initialize() #0 {
        entry:
          %status = call i32 @pthread_key_create(ptr @sollang_output_sink_tls, ptr null)
          %ok = icmp eq i32 %status, 0
          store i1 %ok, ptr @sollang_output_sink_tls_ready, align 1
          ret i1 %ok
        }

        define internal void @sollang_compute_output_enter(ptr %group, i64 %index) #0 {
        entry:
          %sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5
          %sinks = load ptr, ptr %sinks_slot, align 8
          %sink = getelementptr %sollang.output_sink, ptr %sinks, i64 %index
          %key = load i32, ptr @sollang_output_sink_tls, align 4
          %ignored = call i32 @pthread_setspecific(i32 %key, ptr %sink)
          ret void
        }

        define internal void @sollang_compute_output_leave() #0 {
        entry:
          %key = load i32, ptr @sollang_output_sink_tls, align 4
          %ignored = call i32 @pthread_setspecific(i32 %key, ptr null)
          ret void
        }

        define internal void @sollang_compute_output_dispose() #0 {
        entry:
          %ready = load i1, ptr @sollang_output_sink_tls_ready, align 1
          br i1 %ready, label %dispose, label %done
        dispose:
          %key = load i32, ptr @sollang_output_sink_tls, align 4
          %ignored = call i32 @pthread_key_delete(i32 %key)
          store i1 false, ptr @sollang_output_sink_tls_ready, align 1
          br label %done
        done:
          ret void
        }
        """;

    public static string AsyncWindowsIoFunctions() =>
        """
        define internal i1 @sollang_platform_io_ensure_signal() #0 {
        entry:
          %existing = load ptr, ptr @sollang_io_completion_event, align 8
          %ready = icmp ne ptr %existing, null
          br i1 %ready, label %success, label %create
        create:
          %event = call ptr @CreateEventA(ptr null, i32 0, i32 0, ptr null)
          %created = icmp ne ptr %event, null
          br i1 %created, label %publish, label %fail
        publish:
          store ptr %event, ptr @sollang_io_completion_event, align 8
          br label %success
        success:
          ret i1 true
        fail:
          ret i1 false
        }

        define internal void @sollang_platform_io_signal_completion() #0 {
        entry:
          %event = load ptr, ptr @sollang_io_completion_event, align 8
          %ignored = call i32 @SetEvent(ptr %event)
          ret void
        }

        define internal void @sollang_platform_io_clear_completion() #0 {
        entry:
          ret void
        }

        define internal void @sollang_platform_io_wait_completion(i64 %requested) #0 {
        entry:
          %infinite = icmp slt i64 %requested, 0
          %too_large = icmp ugt i64 %requested, 4294967294
          %bounded = select i1 %too_large, i64 4294967294, i64 %requested
          %finite = trunc i64 %bounded to i32
          %timeout = select i1 %infinite, i32 -1, i32 %finite
          %event = load ptr, ptr @sollang_io_completion_event, align 8
          %ignored = call i32 @WaitForSingleObject(ptr %event, i32 %timeout)
          ret void
        }

        define internal void @sollang_platform_io_shutdown() #0 {
        entry:
          %event = load ptr, ptr @sollang_io_completion_event, align 8
          %present = icmp ne ptr %event, null
          br i1 %present, label %close, label %done
        close:
          %closed = call i32 @CloseHandle(ptr %event)
          store ptr null, ptr @sollang_io_completion_event, align 8
          br label %done
        done:
          ret void
        }
        """;

    public static string AsyncWindowsFileWorkerFunctions() =>
        """
        define internal i32 @sollang_windows_file_worker(ptr %unused) #0 {
        entry:
          call void @sollang_file_worker_run()
          ret i32 0
        }

        define internal i1 @sollang_platform_file_worker_start() #0 {
        entry:
          %request_event = call ptr @CreateEventA(ptr null, i32 0, i32 0, ptr null)
          %request_ok = icmp ne ptr %request_event, null
          br i1 %request_ok, label %ensure_completion, label %fail

        ensure_completion:
          store ptr %request_event, ptr @sollang_file_request_event, align 8
          %completion_ok = call i1 @sollang_platform_io_ensure_signal()
          br i1 %completion_ok, label %thread, label %fail

        thread:
          %worker = call ptr @CreateThread(ptr null, i64 0, ptr @sollang_windows_file_worker, ptr null, i32 0, ptr null)
          %worker_ok = icmp ne ptr %worker, null
          br i1 %worker_ok, label %ready, label %fail

        ready:
          store ptr %worker, ptr @sollang_file_worker_handle, align 8
          ret i1 true

        fail:
          ret i1 false
        }

        define internal void @sollang_platform_file_worker_signal_request() #0 {
        entry:
          %event = load ptr, ptr @sollang_file_request_event, align 8
          %ignored = call i32 @SetEvent(ptr %event)
          ret void
        }

        define internal void @sollang_platform_file_worker_wait_request() #0 {
        entry:
          %event = load ptr, ptr @sollang_file_request_event, align 8
          %ignored = call i32 @WaitForSingleObject(ptr %event, i32 -1)
          ret void
        }

        define internal void @sollang_platform_file_worker_join() #0 {
        entry:
          %worker = load ptr, ptr @sollang_file_worker_handle, align 8
          %waited = call i32 @WaitForSingleObject(ptr %worker, i32 -1)
          %closed_worker = call i32 @CloseHandle(ptr %worker)
          %request_event = load ptr, ptr @sollang_file_request_event, align 8
          %closed_request = call i32 @CloseHandle(ptr %request_event)
          store ptr null, ptr @sollang_file_worker_handle, align 8
          store ptr null, ptr @sollang_file_request_event, align 8
          ret void
        }
        """;

    public static string AsyncLinuxIoFunctions() =>
        """
        define internal i1 @sollang_platform_io_ensure_signal() #0 {
        entry:
          %existing = load i32, ptr @sollang_io_completion_event_fd, align 4
          %ready = icmp sge i32 %existing, 0
          br i1 %ready, label %success, label %create
        create:
          ; EFD_NONBLOCK keeps a raced signal clear from blocking the completion drain.
          %completion_fd = call i32 @eventfd(i32 0, i32 2048)
          %created = icmp sge i32 %completion_fd, 0
          br i1 %created, label %publish, label %fail
        publish:
          store i32 %completion_fd, ptr @sollang_io_completion_event_fd, align 4
          br label %success
        success:
          ret i1 true
        fail:
          ret i1 false
        }

        define internal void @sollang_platform_io_signal_completion() #0 {
        entry:
          %value = alloca i64, align 8
          store i64 1, ptr %value, align 8
          %fd = load i32, ptr @sollang_io_completion_event_fd, align 4
          %ignored = call i64 @write(i32 %fd, ptr %value, i64 8)
          ret void
        }

        define internal void @sollang_platform_io_clear_completion() #0 {
        entry:
          %value = alloca i64, align 8
          %fd = load i32, ptr @sollang_io_completion_event_fd, align 4
          %ignored = call i64 @read(i32 %fd, ptr %value, i64 8)
          ret void
        }

        define internal void @sollang_platform_io_wait_completion(i64 %requested) #0 {
        entry:
          %pollfd = alloca [8 x i8], align 4
          %fd = load i32, ptr @sollang_io_completion_event_fd, align 4
          store i32 %fd, ptr %pollfd, align 4
          %events_slot = getelementptr i8, ptr %pollfd, i64 4
          store i16 1, ptr %events_slot, align 2
          %revents_slot = getelementptr i8, ptr %pollfd, i64 6
          store i16 0, ptr %revents_slot, align 2
          %infinite = icmp slt i64 %requested, 0
          %too_large = icmp sgt i64 %requested, 2147483647
          %bounded = select i1 %too_large, i64 2147483647, i64 %requested
          %finite = trunc i64 %bounded to i32
          %timeout = select i1 %infinite, i32 -1, i32 %finite
          %ignored = call i32 @poll(ptr %pollfd, i64 1, i32 %timeout)
          ret void
        }

        define internal void @sollang_platform_io_shutdown() #0 {
        entry:
          %completion_fd = load i32, ptr @sollang_io_completion_event_fd, align 4
          %present = icmp sge i32 %completion_fd, 0
          br i1 %present, label %close_completion, label %done
        close_completion:
          %closed = call i32 @close(i32 %completion_fd)
          store i32 -1, ptr @sollang_io_completion_event_fd, align 4
          br label %done
        done:
          ret void
        }
        """;

    public static string AsyncLinuxFileWorkerFunctions() =>
        """
        define internal ptr @sollang_linux_file_worker(ptr %unused) #0 {
        entry:
          call void @sollang_file_worker_run()
          ret ptr null
        }

        define internal i1 @sollang_platform_file_worker_start() #0 {
        entry:
          %request_fd = call i32 @eventfd(i32 0, i32 0)
          %request_ok = icmp sge i32 %request_fd, 0
          br i1 %request_ok, label %ensure_completion, label %fail

        ensure_completion:
          store i32 %request_fd, ptr @sollang_file_request_event_fd, align 4
          %completion_ok = call i1 @sollang_platform_io_ensure_signal()
          br i1 %completion_ok, label %thread, label %fail

        thread:
          %thread_slot = alloca i64, align 8
          %create = call i32 @pthread_create(ptr %thread_slot, ptr null, ptr @sollang_linux_file_worker, ptr null)
          %thread_ok = icmp eq i32 %create, 0
          br i1 %thread_ok, label %ready, label %fail

        ready:
          %worker_thread = load i64, ptr %thread_slot, align 8
          store i64 %worker_thread, ptr @sollang_file_worker_thread, align 8
          ret i1 true

        fail:
          ret i1 false
        }

        define internal void @sollang_platform_file_worker_signal_request() #0 {
        entry:
          %value = alloca i64, align 8
          store i64 1, ptr %value, align 8
          %fd = load i32, ptr @sollang_file_request_event_fd, align 4
          %ignored = call i64 @write(i32 %fd, ptr %value, i64 8)
          ret void
        }

        define internal void @sollang_platform_file_worker_wait_request() #0 {
        entry:
          %value = alloca i64, align 8
          %fd = load i32, ptr @sollang_file_request_event_fd, align 4
          %ignored = call i64 @read(i32 %fd, ptr %value, i64 8)
          ret void
        }

        define internal void @sollang_platform_file_worker_join() #0 {
        entry:
          %thread = load i64, ptr @sollang_file_worker_thread, align 8
          %joined = call i32 @pthread_join(i64 %thread, ptr null)
          %request_fd = load i32, ptr @sollang_file_request_event_fd, align 4
          %closed_request = call i32 @close(i32 %request_fd)
          store i64 0, ptr @sollang_file_worker_thread, align 8
          store i32 -1, ptr @sollang_file_request_event_fd, align 4
          ret void
        }
        """;

    public static string IoShutdownFunction() =>
        """
        define internal void @sollang_io_shutdown() #0 {
        entry:
          call void @sollang_platform_io_shutdown()
          ret void
        }
        """;

    public static string AsyncFileShutdownFunction() =>
        """
        define internal void @sollang_async_shutdown() #0 {
        entry:
          %started = load i1, ptr @sollang_file_worker_started, align 1
          br i1 %started, label %stop, label %done

        stop:
          call void @sollang_file_wait_idle()
          store atomic i32 1, ptr @sollang_file_worker_stopping release, align 4
          call void @sollang_platform_file_worker_signal_request()
          call void @sollang_platform_file_worker_join()
          store i1 false, ptr @sollang_file_worker_started, align 1
          br label %done

        done:
          call void @sollang_io_shutdown()
          ret void
        }
        """;

    public static string AsyncFileTaskWorkerFunction() =>
        """
        define internal i1 @sollang_file_operation_task_worker(ptr %control) #0 {
        entry:
          %phase_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 12
          %phase = load atomic i32, ptr %phase_slot acquire, align 4
          %initial = icmp eq i32 %phase, 0
          br i1 %initial, label %submit, label %inspect

        submit:
          %size_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 11
          %size = load i32, ptr %size_slot, align 4
          call void @sollang_file_submit(ptr %control, i32 %size)
          ret i1 false

        inspect:
          %complete = icmp eq i32 %phase, 2
          ret i1 %complete
        }
        """;

    public static string AsyncFileTaskCancelFunction() =>
        """
        define internal void @sollang_file_operation_task_cancel(ptr %control) #0 {
        entry:
          %explicit_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 19
          %explicit = load i32, ptr %explicit_slot, align 4
          %owns_handle = icmp ne i32 %explicit, 0
          br i1 %owns_handle, label %close_handle, label %destroy_context

        close_handle:
          %handle_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 17
          %handle = load i64, ptr %handle_slot, align 8
          call void @sollang_platform_close_owned_file(i64 %handle)
          store i32 0, ptr %explicit_slot, align 4
          br label %destroy_context

        destroy_context:
          %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
          %context = load ptr, ptr %context_slot, align 8
          call void @sollang_free(ptr %context)
          ret void
        }
        """;

}
