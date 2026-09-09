namespace Sollang.Compiler.CodeGen;

internal sealed partial class WindowsLlvmRuntimePlatform
{
    private const string DnsRuntime = """
        define internal i32 @sollang_dns_windows_error_kind(i32 %code) #0 {
        entry:
          switch i32 %code, label %system [
            i32 11001, label %not_found
            i32 11002, label %temporary
            i32 10047, label %family
          ]
        not_found:
          ret i32 3
        temporary:
          ret i32 4
        family:
          ret i32 5
        system:
          ret i32 8
        }

        define internal %sollang.socket_result @sollang_platform_dns_lookup(i32 %policy, ptr %host, i64 %length, i16 %port, i64 %max_host, i64 %maximum, ptr %output) #0 {
        entry:
          %valid_maximum_low = icmp ugt i64 %maximum, 0
          %valid_maximum_high = icmp ule i64 %maximum, 64
          %valid_maximum = and i1 %valid_maximum_low, %valid_maximum_high
          %valid_host_limit_low = icmp ugt i64 %max_host, 0
          %valid_host_limit_high = icmp ule i64 %max_host, 253
          %valid_host_limit = and i1 %valid_host_limit_low, %valid_host_limit_high
          %valid_limits = and i1 %valid_maximum, %valid_host_limit
          br i1 %valid_limits, label %validate_host, label %invalid_limit

        invalid_limit:
          %invalid_limit_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 0, i32 0)
          ret %sollang.socket_result %invalid_limit_result

        validate_host:
          %host_not_empty = icmp ugt i64 %length, 0
          br i1 %host_not_empty, label %validate_host_length, label %invalid_host

        validate_host_length:
          %within_policy_limit = icmp ule i64 %length, %max_host
          %within_dns_limit = icmp ule i64 %length, 253
          %within_host_limit = and i1 %within_policy_limit, %within_dns_limit
          br i1 %within_host_limit, label %start_host_copy, label %host_too_long

        host_too_long:
          %host_too_long_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 2, i32 0)
          ret %sollang.socket_result %host_too_long_result

        start_host_copy:
          %wide_host = alloca [254 x i16], align 2
          br label %copy_host

        copy_host:
          %host_index = phi i64 [ 0, %start_host_copy ], [ %host_next, %copy_host_character ]
          %numeric = phi i1 [ true, %start_host_copy ], [ %numeric_next, %copy_host_character ]
          %host_complete = icmp eq i64 %host_index, %length
          br i1 %host_complete, label %finish_host, label %validate_host_character

        validate_host_character:
          %host_source = getelementptr i8, ptr %host, i64 %host_index
          %character = load i8, ptr %host_source, align 1
          %lower_a = icmp uge i8 %character, 97
          %lower_z = icmp ule i8 %character, 122
          %lower = and i1 %lower_a, %lower_z
          %upper_a = icmp uge i8 %character, 65
          %upper_z = icmp ule i8 %character, 90
          %upper = and i1 %upper_a, %upper_z
          %digit_0 = icmp uge i8 %character, 48
          %digit_9 = icmp ule i8 %character, 57
          %digit = and i1 %digit_0, %digit_9
          %hyphen = icmp eq i8 %character, 45
          %dot = icmp eq i8 %character, 46
          %letter = or i1 %lower, %upper
          %alphanumeric = or i1 %letter, %digit
          %punctuation = or i1 %hyphen, %dot
          %allowed = or i1 %alphanumeric, %punctuation
          br i1 %allowed, label %copy_host_character, label %invalid_host

        copy_host_character:
          %wide_character = zext i8 %character to i16
          %host_target = getelementptr i16, ptr %wide_host, i64 %host_index
          store i16 %wide_character, ptr %host_target, align 2
          %numeric_character = or i1 %digit, %dot
          %numeric_next = and i1 %numeric, %numeric_character
          %host_next = add i64 %host_index, 1
          br label %copy_host

        finish_host:
          br i1 %numeric, label %invalid_host, label %terminate_host

        terminate_host:
          %terminator = getelementptr i16, ptr %wide_host, i64 %length
          store i16 0, ptr %terminator, align 2
          %started = call i32 @sollang_winsock_ensure_started()
          %start_ok = icmp eq i32 %started, 0
          br i1 %start_ok, label %prepare_lookup, label %startup_failed

        startup_failed:
          %startup_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 8, i32 %started)
          ret %sollang.socket_result %startup_result

        invalid_host:
          %invalid_host_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 1, i32 0)
          ret %sollang.socket_result %invalid_host_result

        prepare_lookup:
          %hints = alloca [48 x i8], align 8
          call void @llvm.memset.p0.i64(ptr %hints, i8 0, i64 48, i1 false)
          %is_ipv4 = icmp eq i32 %policy, 1
          %is_ipv6 = icmp eq i32 %policy, 2
          %selected_ipv6 = select i1 %is_ipv6, i32 23, i32 0
          %selected_family = select i1 %is_ipv4, i32 2, i32 %selected_ipv6
          %family_address = getelementptr i8, ptr %hints, i64 4
          store i32 %selected_family, ptr %family_address, align 4
          %results = alloca ptr, align 8
          store ptr null, ptr %results, align 8
          %lookup_code = call i32 @GetAddrInfoW(ptr %wide_host, ptr null, ptr %hints, ptr %results)
          %lookup_ok = icmp eq i32 %lookup_code, 0
          br i1 %lookup_ok, label %begin_results, label %lookup_failed

        lookup_failed:
          %lookup_kind = call i32 @sollang_dns_windows_error_kind(i32 %lookup_code)
          %lookup_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 %lookup_kind, i32 %lookup_code)
          ret %sollang.socket_result %lookup_result

        begin_results:
          %first = load ptr, ptr %results, align 8
          %candidate = alloca [32 x i8], align 8
          br label %visit_result

        visit_result:
          %current = phi ptr [ %first, %begin_results ], [ %following, %next_result ]
          %count = phi i64 [ 0, %begin_results ], [ %next_count, %next_result ]
          %finished = icmp eq ptr %current, null
          br i1 %finished, label %finish_results, label %convert_result

        convert_result:
          %address_pointer = getelementptr i8, ptr %current, i64 32
          %address = load ptr, ptr %address_pointer, align 8
          %has_address = icmp ne ptr %address, null
          br i1 %has_address, label %convert_address, label %skip_result

        convert_address:
          %converted_family = call i32 @sollang_socket_endpoint(ptr %address, ptr %candidate)
          %supported_family = icmp ne i32 %converted_family, 0
          br i1 %supported_family, label %set_port, label %skip_result

        set_port:
          %port_target = getelementptr i8, ptr %candidate, i64 20
          store i16 %port, ptr %port_target, align 2
          br label %scan_duplicate

        scan_duplicate:
          %scan_index = phi i64 [ 0, %set_port ], [ %scan_next, %not_duplicate ]
          %scan_complete = icmp eq i64 %scan_index, %count
          br i1 %scan_complete, label %publish_result, label %compare_result

        compare_result:
          %existing_offset = mul i64 %scan_index, 32
          %existing = getelementptr i8, ptr %output, i64 %existing_offset
          %existing0 = load i64, ptr %existing, align 1
          %candidate0 = load i64, ptr %candidate, align 1
          %equal0 = icmp eq i64 %existing0, %candidate0
          %existing8 = getelementptr i8, ptr %existing, i64 8
          %candidate8 = getelementptr i8, ptr %candidate, i64 8
          %existing1 = load i64, ptr %existing8, align 1
          %candidate1 = load i64, ptr %candidate8, align 1
          %equal1 = icmp eq i64 %existing1, %candidate1
          %equal01 = and i1 %equal0, %equal1
          %existing16 = getelementptr i8, ptr %existing, i64 16
          %candidate16 = getelementptr i8, ptr %candidate, i64 16
          %existing2 = load i64, ptr %existing16, align 1
          %candidate2 = load i64, ptr %candidate16, align 1
          %equal2 = icmp eq i64 %existing2, %candidate2
          %existing24 = getelementptr i8, ptr %existing, i64 24
          %candidate24 = getelementptr i8, ptr %candidate, i64 24
          %existing3 = load i64, ptr %existing24, align 1
          %candidate3 = load i64, ptr %candidate24, align 1
          %equal3 = icmp eq i64 %existing3, %candidate3
          %equal23 = and i1 %equal2, %equal3
          %duplicate = and i1 %equal01, %equal23
          br i1 %duplicate, label %skip_result, label %not_duplicate

        not_duplicate:
          %scan_next = add i64 %scan_index, 1
          br label %scan_duplicate

        publish_result:
          %limit_reached = icmp eq i64 %count, %maximum
          br i1 %limit_reached, label %result_limit, label %copy_result

        copy_result:
          %output_offset = mul i64 %count, 32
          %output_item = getelementptr i8, ptr %output, i64 %output_offset
          call void @llvm.memcpy.p0.p0.i64(ptr %output_item, ptr %candidate, i64 32, i1 false)
          %published_count = add i64 %count, 1
          br label %skip_result

        skip_result:
          %next_count = phi i64 [ %count, %convert_result ], [ %count, %convert_address ], [ %count, %compare_result ], [ %published_count, %copy_result ]
          br label %next_result

        next_result:
          %next_address = getelementptr i8, ptr %current, i64 40
          %following = load ptr, ptr %next_address, align 8
          br label %visit_result

        result_limit:
          call void @FreeAddrInfoW(ptr %first)
          %limit_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 6, i32 0)
          ret %sollang.socket_result %limit_result

        finish_results:
          %has_first = icmp ne ptr %first, null
          br i1 %has_first, label %release_results, label %no_results

        release_results:
          call void @FreeAddrInfoW(ptr %first)
          %has_results = icmp ugt i64 %count, 0
          br i1 %has_results, label %lookup_success, label %no_results

        no_results:
          %not_found_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 3, i32 0)
          ret %sollang.socket_result %not_found_result

        lookup_success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }
        """;
}
