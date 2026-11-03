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
}
