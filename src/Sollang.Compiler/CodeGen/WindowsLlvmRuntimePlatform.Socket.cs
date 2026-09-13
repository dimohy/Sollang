using System.Text;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class WindowsLlvmRuntimePlatform
{
    public override void EmitSocketPrimitives(StringBuilder functions)
    {
        functions.AppendLine("declare dllimport i32 @WSAStartup(i16, ptr)");
        functions.AppendLine("declare dllimport i32 @WSACleanup()");
        functions.AppendLine("declare dllimport i32 @WSAGetLastError()");
        functions.AppendLine("declare dllimport i64 @WSASocketW(i32, i32, i32, ptr, i32, i32)");
        functions.AppendLine("declare dllimport i32 @WSADuplicateSocketW(i64, i32, ptr)");
        functions.AppendLine("declare dllimport i32 @GetCurrentProcessId()");
        functions.AppendLine("declare dllimport i32 @closesocket(i64)");
        functions.AppendLine("declare dllimport i32 @bind(i64, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @getsockname(i64, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @getpeername(i64, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @listen(i64, i32)");
        functions.AppendLine("declare dllimport i64 @accept(i64, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @connect(i64, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @recv(i64, ptr, i32, i32)");
        functions.AppendLine("declare dllimport i32 @send(i64, ptr, i32, i32)");
        functions.AppendLine("declare dllimport i32 @WSARecv(i64, ptr, i32, ptr, ptr, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @WSASend(i64, ptr, i32, ptr, i32, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @recvfrom(i64, ptr, i32, i32, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @WSARecvFrom(i64, ptr, i32, ptr, ptr, ptr, ptr, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @sendto(i64, ptr, i32, i32, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @shutdown(i64, i32)");
        functions.AppendLine("declare dllimport i32 @setsockopt(i64, i32, i32, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @getsockopt(i64, i32, i32, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @ioctlsocket(i64, i32, ptr)");
        functions.AppendLine("declare dllimport i32 @WSAPoll(ptr, i32, i32)");
        functions.AppendLine("declare dllimport i32 @GetAddrInfoW(ptr, ptr, ptr, ptr)");
        functions.AppendLine("declare dllimport void @FreeAddrInfoW(ptr)");
        functions.AppendLine();
        functions.AppendLine(SocketRuntime);
        if (UsesSocketCompletion)
        {
            functions.AppendLine(CompletionRuntime);
        }
        functions.AppendLine(DnsRuntime);
    }

    private const string SocketRuntime = """
        define internal %sollang.socket_result @sollang_socket_result(i64 %value, i32 %kind, i32 %code) #0 {
        entry:
          %with_value = insertvalue %sollang.socket_result poison, i64 %value, 0
          %with_kind = insertvalue %sollang.socket_result %with_value, i32 %kind, 1
          %result = insertvalue %sollang.socket_result %with_kind, i32 %code, 2
          ret %sollang.socket_result %result
        }

        define internal i32 @sollang_socket_error_kind(i32 %code) #0 {
        entry:
          switch i32 %code, label %other [
            i32 10022, label %invalid_argument
            i32 10048, label %address_in_use
            i32 10061, label %connection_refused
            i32 10054, label %connection_reset
            i32 10060, label %timed_out
            i32 10004, label %interrupted
            i32 10035, label %would_block
            i32 10047, label %unsupported
            i32 10045, label %unsupported
          ]

        invalid_argument:
          ret i32 1
        address_in_use:
          ret i32 2
        connection_refused:
          ret i32 3
        connection_reset:
          ret i32 4
        timed_out:
          ret i32 5
        interrupted:
          ret i32 6
        would_block:
          ret i32 10
        unsupported:
          ret i32 7
        other:
          ret i32 8
        }

        define internal %sollang.socket_result @sollang_platform_socket_try_clone(i64 %socket) #0 {
        entry:
          %protocol_info = alloca [640 x i8], align 8
          %process_id = call i32 @GetCurrentProcessId()
          %duplicate_status = call i32 @WSADuplicateSocketW(i64 %socket, i32 %process_id, ptr %protocol_info)
          %duplicate_failed = icmp ne i32 %duplicate_status, 0
          br i1 %duplicate_failed, label %failure, label %create

        create:
          %clone = call i64 @WSASocketW(i32 -1, i32 -1, i32 -1, ptr %protocol_info, i32 0, i32 129)
          %create_failed = icmp eq i64 %clone, -1
          br i1 %create_failed, label %failure, label %success

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %clone, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal i32 @sollang_winsock_ensure_started() #0 {
        entry:
          br label %retry

        retry:
          %state = load atomic i32, ptr @sollang_winsock_state acquire, align 4
          %ready = icmp eq i32 %state, 1
          br i1 %ready, label %success, label %check_failed

        check_failed:
          %failed = icmp slt i32 %state, 0
          br i1 %failed, label %previous_failure, label %claim_start

        previous_failure:
          %previous_code = sub i32 0, %state
          ret i32 %previous_code

        claim_start:
          %initializing = icmp eq i32 %state, 2
          br i1 %initializing, label %retry, label %claim

        claim:
          %claimed = cmpxchg ptr @sollang_winsock_state, i32 0, i32 2 acq_rel acquire
          %won = extractvalue { i32, i1 } %claimed, 1
          br i1 %won, label %start, label %retry

        start:
          %data = alloca [408 x i8], align 8
          %status = call i32 @WSAStartup(i16 514, ptr %data)
          %started = icmp eq i32 %status, 0
          br i1 %started, label %mark_ready, label %mark_failed

        mark_ready:
          store atomic i32 1, ptr @sollang_winsock_state release, align 4
          br label %success

        mark_failed:
          %stored_failure = sub i32 0, %status
          store atomic i32 %stored_failure, ptr @sollang_winsock_state release, align 4
          ret i32 %status

        success:
          ret i32 0
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_nonblocking(i64 %socket, i1 %enabled) #0 {
        entry:
          %mode = alloca i32, align 4
          %value = zext i1 %enabled to i32
          store i32 %value, ptr %mode, align 4
          %status = call i32 @ioctlsocket(i64 %socket, i32 -2147195266, ptr %mode)
          %failed = icmp ne i32 %status, 0
          br i1 %failed, label %failure, label %success

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_poll(i64 %socket, i32 %mode, i1 %has_timeout, i64 %milliseconds) #0 {
        entry:
          %descriptor = alloca { i64, i16, i16 }, align 8
          %fd = getelementptr inbounds { i64, i16, i16 }, ptr %descriptor, i32 0, i32 0
          %events = getelementptr inbounds { i64, i16, i16 }, ptr %descriptor, i32 0, i32 1
          %revents = getelementptr inbounds { i64, i16, i16 }, ptr %descriptor, i32 0, i32 2
          store i64 %socket, ptr %fd, align 8
          %is_read = icmp eq i32 %mode, 0
          %requested = select i1 %is_read, i16 256, i16 16
          %is_error = icmp eq i32 %mode, 2
          %event_mask = select i1 %is_error, i16 0, i16 %requested
          store i16 %event_mask, ptr %events, align 2
          store i16 0, ptr %revents, align 2
          %timeout_overflow = icmp sgt i64 %milliseconds, 2147483647
          %bounded_timeout = select i1 %timeout_overflow, i64 2147483647, i64 %milliseconds
          %timeout32 = trunc i64 %bounded_timeout to i32
          %timeout = select i1 %has_timeout, i32 %timeout32, i32 -1
          %status = call i32 @WSAPoll(ptr %descriptor, i32 1, i32 %timeout)
          %failed = icmp slt i32 %status, 0
          br i1 %failed, label %failure, label %success

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        success:
          %returned = load i16, ptr %revents, align 2
          %normal_mask = or i16 %event_mask, 7
          %selected_mask = select i1 %is_error, i16 7, i16 %normal_mask
          %matched_bits = and i16 %returned, %selected_mask
          %ready = icmp ne i16 %matched_bits, 0
          %ready64 = zext i1 %ready to i64
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %ready64, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_reactor_wait(ptr %interests, i64 %interest_count, i64 %interest_stride, i64 %key_offset, i64 %source_offset, i64 %mode_offset, i64 %maximum_events, ptr %event_buffer, ptr %event_length_address, i64 %event_capacity, i64 %event_stride, i64 %event_key_offset, i64 %event_read_offset, i64 %event_write_offset, i64 %event_error_offset, i1 %has_timeout, i64 %milliseconds) #0 {
        entry:
          %within_declared = icmp ule i64 %interest_count, %maximum_events
          %within_stack = icmp ule i64 %interest_count, 1024
          %count_valid = and i1 %within_declared, %within_stack
          %capacity_valid = icmp ule i64 %interest_count, %event_capacity
          %shape_valid = and i1 %count_valid, %capacity_valid
          br i1 %shape_valid, label %check_empty, label %invalid_argument

        check_empty:
          %empty = icmp eq i64 %interest_count, 0
          br i1 %empty, label %success_empty, label %prepare

        prepare:
          %descriptors = alloca { i64, i16, i16 }, i64 %interest_count, align 8
          br label %build

        build:
          %index = phi i64 [ 0, %prepare ], [ %next, %store_descriptor ]
          %interest_byte_offset = mul i64 %index, %interest_stride
          %interest = getelementptr i8, ptr %interests, i64 %interest_byte_offset
          %source = getelementptr i8, ptr %interest, i64 %source_offset
          %source_tag = load i32, ptr %source, align 4
          %source_valid = icmp ule i32 %source_tag, 2
          br i1 %source_valid, label %load_owner, label %invalid_argument

        load_owner:
          %source_payload = getelementptr i8, ptr %source, i64 8
          %owner = load ptr, ptr %source_payload, align 8
          %owner_valid = icmp ne ptr %owner, null
          br i1 %owner_valid, label %load_mode, label %invalid_argument

        load_mode:
          %handle = load i64, ptr %owner, align 8
          %mode_address = getelementptr i8, ptr %interest, i64 %mode_offset
          %mode = load i32, ptr %mode_address, align 4
          %mode_valid = icmp ule i32 %mode, 2
          br i1 %mode_valid, label %store_descriptor, label %invalid_argument

        store_descriptor:
          %descriptor = getelementptr { i64, i16, i16 }, ptr %descriptors, i64 %index
          %descriptor_fd = getelementptr { i64, i16, i16 }, ptr %descriptor, i32 0, i32 0
          %descriptor_events = getelementptr { i64, i16, i16 }, ptr %descriptor, i32 0, i32 1
          %descriptor_revents = getelementptr { i64, i16, i16 }, ptr %descriptor, i32 0, i32 2
          %wants_read = icmp ne i32 %mode, 1
          %wants_write = icmp ne i32 %mode, 0
          %read_mask = select i1 %wants_read, i16 256, i16 0
          %write_mask = select i1 %wants_write, i16 16, i16 0
          %requested = or i16 %read_mask, %write_mask
          store i64 %handle, ptr %descriptor_fd, align 8
          store i16 %requested, ptr %descriptor_events, align 2
          store i16 0, ptr %descriptor_revents, align 2
          %next = add i64 %index, 1
          %built = icmp eq i64 %next, %interest_count
          br i1 %built, label %wait, label %build

        wait:
          %timeout_overflow = icmp sgt i64 %milliseconds, 2147483647
          %bounded_timeout = select i1 %timeout_overflow, i64 2147483647, i64 %milliseconds
          %timeout32 = trunc i64 %bounded_timeout to i32
          %timeout = select i1 %has_timeout, i32 %timeout32, i32 -1
          %count32 = trunc i64 %interest_count to i32
          %status = call i32 @WSAPoll(ptr %descriptors, i32 %count32, i32 %timeout)
          %failed = icmp slt i32 %status, 0
          br i1 %failed, label %failure, label %scan_prepare

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        scan_prepare:
          %output_count_address = alloca i64, align 8
          store i64 0, ptr %output_count_address, align 8
          br label %scan

        scan:
          %scan_index = phi i64 [ 0, %scan_prepare ], [ %scan_next, %advance ]
          %scan_descriptor = getelementptr { i64, i16, i16 }, ptr %descriptors, i64 %scan_index
          %scan_events_address = getelementptr { i64, i16, i16 }, ptr %scan_descriptor, i32 0, i32 1
          %scan_revents_address = getelementptr { i64, i16, i16 }, ptr %scan_descriptor, i32 0, i32 2
          %scan_events = load i16, ptr %scan_events_address, align 2
          %scan_revents = load i16, ptr %scan_revents_address, align 2
          %read_interest_bits = and i16 %scan_events, 256
          %read_interested = icmp ne i16 %read_interest_bits, 0
          %read_ready_bits = and i16 %scan_revents, 770
          %read_ready_raw = icmp ne i16 %read_ready_bits, 0
          %readable = and i1 %read_interested, %read_ready_raw
          %write_interest_bits = and i16 %scan_events, 16
          %write_interested = icmp ne i16 %write_interest_bits, 0
          %write_ready_bits = and i16 %scan_revents, 16
          %write_ready_raw = icmp ne i16 %write_ready_bits, 0
          %writable = and i1 %write_interested, %write_ready_raw
          %error_bits = and i16 %scan_revents, 7
          %has_error = icmp ne i16 %error_bits, 0
          %read_or_write = or i1 %readable, %writable
          %ready = or i1 %read_or_write, %has_error
          br i1 %ready, label %publish, label %advance

        publish:
          %output_count = load i64, ptr %output_count_address, align 8
          %event_byte_offset = mul i64 %output_count, %event_stride
          %event = getelementptr i8, ptr %event_buffer, i64 %event_byte_offset
          %interest_scan_offset = mul i64 %scan_index, %interest_stride
          %scan_interest = getelementptr i8, ptr %interests, i64 %interest_scan_offset
          %key_address = getelementptr i8, ptr %scan_interest, i64 %key_offset
          %key = load i64, ptr %key_address, align 8
          %event_key = getelementptr i8, ptr %event, i64 %event_key_offset
          %event_read = getelementptr i8, ptr %event, i64 %event_read_offset
          %event_write = getelementptr i8, ptr %event, i64 %event_write_offset
          %event_error = getelementptr i8, ptr %event, i64 %event_error_offset
          store i64 %key, ptr %event_key, align 8
          store i1 %readable, ptr %event_read, align 1
          store i1 %writable, ptr %event_write, align 1
          store i1 %has_error, ptr %event_error, align 1
          %output_next = add i64 %output_count, 1
          store i64 %output_next, ptr %output_count_address, align 8
          br label %advance

        advance:
          %scan_next = add i64 %scan_index, 1
          %scan_done = icmp eq i64 %scan_next, %interest_count
          br i1 %scan_done, label %success, label %scan

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success_empty:
          store i64 0, ptr %event_length_address, align 8
          %empty_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %empty_result

        success:
          %published = load i64, ptr %output_count_address, align 8
          store i64 %published, ptr %event_length_address, align 8
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %published, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal void @sollang_platform_socket_cleanup() #0 {
        entry:
          %claimed = cmpxchg ptr @sollang_winsock_state, i32 1, i32 0 acq_rel acquire
          %started = extractvalue { i32, i1 } %claimed, 1
          br i1 %started, label %cleanup, label %done

        cleanup:
          %ignored = call i32 @WSACleanup()
          br label %done

        done:
          ret void
        }

        define internal i16 @sollang_socket_network_port(i16 %port) #0 {
        entry:
          %low = shl i16 %port, 8
          %high = lshr i16 %port, 8
          %network = or i16 %low, %high
          ret i16 %network
        }

        define internal i32 @sollang_socket_network_u32(i32 %value) #0 {
        entry:
          %a = shl i32 %value, 24
          %b0 = shl i32 %value, 8
          %b = and i32 %b0, 16711680
          %c0 = lshr i32 %value, 8
          %c = and i32 %c0, 65280
          %d = lshr i32 %value, 24
          %ab = or i32 %a, %b
          %cd = or i32 %c, %d
          %network = or i32 %ab, %cd
          ret i32 %network
        }

        define internal i32 @sollang_socket_address(ptr %endpoint, ptr %storage) #0 {
        entry:
          call void @llvm.memset.p0.i64(ptr %storage, i8 0, i64 28, i1 false)
          %family = load i32, ptr %endpoint, align 4
          switch i32 %family, label %invalid [
            i32 4, label %ipv4
            i32 6, label %ipv6
          ]

        ipv4:
          store i16 2, ptr %storage, align 2
          %port4_source = getelementptr i8, ptr %endpoint, i64 20
          %port4 = load i16, ptr %port4_source, align 2
          %network_port4 = call i16 @sollang_socket_network_port(i16 %port4)
          %port4_target = getelementptr i8, ptr %storage, i64 2
          store i16 %network_port4, ptr %port4_target, align 2
          br label %ipv4_copy

        ipv4_copy:
          %octet = phi i64 [ 0, %ipv4 ], [ %octet_next, %ipv4_copy ]
          %endpoint_offset = mul i64 %octet, 2
          %endpoint_index = add i64 %endpoint_offset, 4
          %octet_source = getelementptr i8, ptr %endpoint, i64 %endpoint_index
          %octet_word = load i16, ptr %octet_source, align 2
          %octet_value = trunc i16 %octet_word to i8
          %socket_index = add i64 %octet, 4
          %octet_target = getelementptr i8, ptr %storage, i64 %socket_index
          store i8 %octet_value, ptr %octet_target, align 1
          %octet_next = add i64 %octet, 1
          %octets_complete = icmp eq i64 %octet_next, 4
          br i1 %octets_complete, label %ipv4_done, label %ipv4_copy

        ipv4_done:
          ret i32 2

        ipv6:
          store i16 23, ptr %storage, align 2
          %port6_source = getelementptr i8, ptr %endpoint, i64 20
          %port6 = load i16, ptr %port6_source, align 2
          %network_port6 = call i16 @sollang_socket_network_port(i16 %port6)
          %port6_target = getelementptr i8, ptr %storage, i64 2
          store i16 %network_port6, ptr %port6_target, align 2
          %flow_source = getelementptr i8, ptr %endpoint, i64 24
          %flow = load i32, ptr %flow_source, align 4
          %network_flow = call i32 @sollang_socket_network_u32(i32 %flow)
          %flow_target = getelementptr i8, ptr %storage, i64 4
          store i32 %network_flow, ptr %flow_target, align 4
          %scope_source = getelementptr i8, ptr %endpoint, i64 28
          %scope = load i32, ptr %scope_source, align 4
          %scope_target = getelementptr i8, ptr %storage, i64 24
          store i32 %scope, ptr %scope_target, align 4
          br label %ipv6_copy

        ipv6_copy:
          %group = phi i64 [ 0, %ipv6 ], [ %group_next, %ipv6_copy ]
          %group_offset = mul i64 %group, 2
          %group_source_index = add i64 %group_offset, 4
          %group_source = getelementptr i8, ptr %endpoint, i64 %group_source_index
          %group_value = load i16, ptr %group_source, align 2
          %network_group = call i16 @sollang_socket_network_port(i16 %group_value)
          %group_target_index = add i64 %group_offset, 8
          %group_target = getelementptr i8, ptr %storage, i64 %group_target_index
          store i16 %network_group, ptr %group_target, align 2
          %group_next = add i64 %group, 1
          %groups_complete = icmp eq i64 %group_next, 8
          br i1 %groups_complete, label %ipv6_done, label %ipv6_copy

        ipv6_done:
          ret i32 23

        invalid:
          ret i32 0
        }

        define internal i32 @sollang_socket_endpoint(ptr %source, ptr %endpoint) #0 {
        entry:
          call void @llvm.memset.p0.i64(ptr %endpoint, i8 0, i64 32, i1 false)
          %family16 = load i16, ptr %source, align 2
          %family = zext i16 %family16 to i32
          switch i32 %family, label %invalid [
            i32 2, label %ipv4
            i32 23, label %ipv6
          ]

        ipv4:
          store i32 4, ptr %endpoint, align 4
          br label %ipv4_copy

        ipv4_copy:
          %octet = phi i64 [ 0, %ipv4 ], [ %octet_next, %ipv4_copy ]
          %source_index = add i64 %octet, 4
          %octet_source = getelementptr i8, ptr %source, i64 %source_index
          %octet_value = load i8, ptr %octet_source, align 1
          %octet_word = zext i8 %octet_value to i16
          %endpoint_offset = mul i64 %octet, 2
          %endpoint_index = add i64 %endpoint_offset, 4
          %octet_target = getelementptr i8, ptr %endpoint, i64 %endpoint_index
          store i16 %octet_word, ptr %octet_target, align 2
          %octet_next = add i64 %octet, 1
          %octets_complete = icmp eq i64 %octet_next, 4
          br i1 %octets_complete, label %publish_ipv4, label %ipv4_copy

        publish_ipv4:
          %network_port4_address = getelementptr i8, ptr %source, i64 2
          %network_port4 = load i16, ptr %network_port4_address, align 2
          %port4 = call i16 @sollang_socket_network_port(i16 %network_port4)
          %port4_target = getelementptr i8, ptr %endpoint, i64 20
          store i16 %port4, ptr %port4_target, align 2
          ret i32 4

        ipv6:
          store i32 6, ptr %endpoint, align 4
          br label %ipv6_copy

        ipv6_copy:
          %group = phi i64 [ 0, %ipv6 ], [ %group_next, %ipv6_copy ]
          %group_offset = mul i64 %group, 2
          %source_index6 = add i64 %group_offset, 8
          %group_source = getelementptr i8, ptr %source, i64 %source_index6
          %network_group = load i16, ptr %group_source, align 2
          %group_value = call i16 @sollang_socket_network_port(i16 %network_group)
          %endpoint_index6 = add i64 %group_offset, 4
          %group_target = getelementptr i8, ptr %endpoint, i64 %endpoint_index6
          store i16 %group_value, ptr %group_target, align 2
          %group_next = add i64 %group, 1
          %groups_complete = icmp eq i64 %group_next, 8
          br i1 %groups_complete, label %publish_ipv6, label %ipv6_copy

        publish_ipv6:
          %network_port6_address = getelementptr i8, ptr %source, i64 2
          %network_port6 = load i16, ptr %network_port6_address, align 2
          %port6 = call i16 @sollang_socket_network_port(i16 %network_port6)
          %port6_target = getelementptr i8, ptr %endpoint, i64 20
          store i16 %port6, ptr %port6_target, align 2
          %network_flow_address = getelementptr i8, ptr %source, i64 4
          %network_flow = load i32, ptr %network_flow_address, align 4
          %flow = call i32 @sollang_socket_network_u32(i32 %network_flow)
          %flow_target = getelementptr i8, ptr %endpoint, i64 24
          store i32 %flow, ptr %flow_target, align 4
          %scope_address = getelementptr i8, ptr %source, i64 24
          %scope = load i32, ptr %scope_address, align 4
          %scope_target = getelementptr i8, ptr %endpoint, i64 28
          store i32 %scope, ptr %scope_target, align 4
          ret i32 6

        invalid:
          ret i32 0
        }

        define internal %sollang.socket_result @sollang_platform_socket_listen(ptr %endpoint, i64 %backlog, i1 %reuse) #0 {
        entry:
          %started = call i32 @sollang_winsock_ensure_started()
          %start_ok = icmp eq i32 %started, 0
          br i1 %start_ok, label %validate_backlog, label %start_failed

        start_failed:
          %start_kind = call i32 @sollang_socket_error_kind(i32 %started)
          %start_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %start_kind, i32 %started)
          ret %sollang.socket_result %start_result

        validate_backlog:
          %backlog_positive = icmp sgt i64 %backlog, 0
          %backlog_fits = icmp sle i64 %backlog, 2147483647
          %backlog_valid = and i1 %backlog_positive, %backlog_fits
          br i1 %backlog_valid, label %parse, label %invalid_argument

        parse:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
          %address_valid = icmp ne i32 %family, 0
          br i1 %address_valid, label %create, label %invalid_address

        create:
          %socket = call i64 @WSASocketW(i32 %family, i32 1, i32 6, ptr null, i32 0, i32 129)
          %created = icmp ne i64 %socket, -1
          br i1 %created, label %configure, label %create_failed

        configure:
          br i1 %reuse, label %set_reuse, label %bind_socket

        set_reuse:
          %reuse_value = alloca i32, align 4
          store i32 1, ptr %reuse_value, align 4
          %reuse_status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4, ptr %reuse_value, i32 4)
          %reuse_ok = icmp eq i32 %reuse_status, 0
          br i1 %reuse_ok, label %bind_socket, label %socket_failed

        bind_socket:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %bind_status = call i32 @bind(i64 %socket, ptr %socket_address, i32 %address_size)
          %bind_ok = icmp eq i32 %bind_status, 0
          br i1 %bind_ok, label %listen_socket, label %socket_failed

        listen_socket:
          %backlog32 = trunc i64 %backlog to i32
          %listen_status = call i32 @listen(i64 %socket, i32 %backlog32)
          %listen_ok = icmp eq i32 %listen_status, 0
          br i1 %listen_ok, label %success, label %socket_failed

        socket_failed:
          %socket_error = call i32 @WSAGetLastError()
          %close_failed_socket = call i32 @closesocket(i64 %socket)
          %socket_kind = call i32 @sollang_socket_error_kind(i32 %socket_error)
          %socket_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %socket_kind, i32 %socket_error)
          ret %sollang.socket_result %socket_result

        create_failed:
          %create_error = call i32 @WSAGetLastError()
          %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
          %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
          ret %sollang.socket_result %create_result

        invalid_address:
          %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %address_result

        invalid_argument:
          %argument_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %argument_result

        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_connect(ptr %endpoint) #0 {
        entry:
          %started = call i32 @sollang_winsock_ensure_started()
          %start_ok = icmp eq i32 %started, 0
          br i1 %start_ok, label %parse, label %start_failed

        start_failed:
          %start_kind = call i32 @sollang_socket_error_kind(i32 %started)
          %start_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %start_kind, i32 %started)
          ret %sollang.socket_result %start_result

        parse:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
          %address_valid = icmp ne i32 %family, 0
          br i1 %address_valid, label %create, label %invalid_address

        create:
          %socket = call i64 @WSASocketW(i32 %family, i32 1, i32 6, ptr null, i32 0, i32 129)
          %created = icmp ne i64 %socket, -1
          br i1 %created, label %connect_socket, label %create_failed

        connect_socket:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %connect_status = call i32 @connect(i64 %socket, ptr %socket_address, i32 %address_size)
          %connect_ok = icmp eq i32 %connect_status, 0
          br i1 %connect_ok, label %success, label %connect_failed

        connect_failed:
          %connect_error = call i32 @WSAGetLastError()
          %close_failed_socket = call i32 @closesocket(i64 %socket)
          %connect_kind = call i32 @sollang_socket_error_kind(i32 %connect_error)
          %connect_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %connect_kind, i32 %connect_error)
          ret %sollang.socket_result %connect_result

        create_failed:
          %create_error = call i32 @WSAGetLastError()
          %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
          %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
          ret %sollang.socket_result %create_result

        invalid_address:
          %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %address_result

        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_accept(i64 %listener) #0 {
        entry:
          %socket = call i64 @accept(i64 %listener, ptr null, ptr null)
          %accepted = icmp ne i64 %socket, -1
          br i1 %accepted, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_receive(i64 %socket, ptr %buffer, i64 %capacity, i32 %flags) #0 {
        entry:
          %positive = icmp ugt i64 %capacity, 0
          %fits = icmp ule i64 %capacity, 2147483647
          %valid = and i1 %positive, %fits
          br i1 %valid, label %receive, label %invalid_argument

        receive:
          %capacity32 = trunc i64 %capacity to i32
          %count32 = call i32 @recv(i64 %socket, ptr %buffer, i32 %capacity32, i32 %flags)
          %ok = icmp sge i32 %count32, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success:
          %count = zext i32 %count32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_receive_append(i64 %socket, ptr %buffer, i64 %buffer_length, i64 %buffer_capacity) #0 {
        entry:
          %length_valid = icmp ult i64 %buffer_length, %buffer_capacity
          br i1 %length_valid, label %receive_append, label %invalid_argument

        receive_append:
          %start = getelementptr i8, ptr %buffer, i64 %buffer_length
          %remaining = sub i64 %buffer_capacity, %buffer_length
          %result = call %sollang.socket_result @sollang_platform_socket_receive(i64 %socket, ptr %start, i64 %remaining, i32 0)
          ret %sollang.socket_result %result

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid
        }

        define internal %sollang.socket_result @sollang_platform_socket_send(i64 %socket, ptr %buffer, i64 %length) #0 {
        entry:
          %fits = icmp ule i64 %length, 2147483647
          br i1 %fits, label %send_bytes, label %invalid_argument

        send_bytes:
          %length32 = trunc i64 %length to i32
          %count32 = call i32 @send(i64 %socket, ptr %buffer, i32 %length32, i32 0)
          %ok = icmp sge i32 %count32, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success:
          %count = zext i32 %count32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_send_range(i64 %socket, ptr %buffer, i64 %buffer_length, i64 %offset, i64 %length) #0 {
        entry:
          %offset_valid = icmp ule i64 %offset, %buffer_length
          br i1 %offset_valid, label %check_length, label %invalid_argument

        check_length:
          %remaining = sub i64 %buffer_length, %offset
          %length_valid = icmp ule i64 %length, %remaining
          br i1 %length_valid, label %send_range, label %invalid_argument

        send_range:
          %start = getelementptr i8, ptr %buffer, i64 %offset
          %result = call %sollang.socket_result @sollang_platform_socket_send(i64 %socket, ptr %start, i64 %length)
          ret %sollang.socket_result %result

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid
        }

        define internal %sollang.socket_result @sollang_platform_socket_send_vectored(i64 %socket, ptr %buffers, i64 %buffer_count, i64 %stride, i64 %bytes_field_offset, i64 %offset_field_offset, i64 %length_field_offset) #0 {
        entry:
          %count_valid = icmp ule i64 %buffer_count, 64
          br i1 %count_valid, label %check_empty, label %invalid_argument

        check_empty:
          %empty = icmp eq i64 %buffer_count, 0
          br i1 %empty, label %success_empty, label %prepare

        prepare:
          %native_buffers = alloca { i32, ptr }, i64 %buffer_count, align 8
          br label %build

        build:
          %index = phi i64 [ 0, %prepare ], [ %next, %store_buffer ]
          %descriptor_offset = mul i64 %index, %stride
          %descriptor = getelementptr i8, ptr %buffers, i64 %descriptor_offset
          %bytes_address = getelementptr i8, ptr %descriptor, i64 %bytes_field_offset
          %bytes = load ptr, ptr %bytes_address, align 8
          %bytes_valid = icmp ne ptr %bytes, null
          br i1 %bytes_valid, label %load_range, label %invalid_argument

        load_range:
          %data = load ptr, ptr %bytes, align 8
          %buffer_length_address = getelementptr i8, ptr %bytes, i64 8
          %buffer_length = load i64, ptr %buffer_length_address, align 8
          %range_offset_address = getelementptr i8, ptr %descriptor, i64 %offset_field_offset
          %range_offset = load i64, ptr %range_offset_address, align 8
          %range_length_address = getelementptr i8, ptr %descriptor, i64 %length_field_offset
          %range_length = load i64, ptr %range_length_address, align 8
          %offset_valid = icmp ule i64 %range_offset, %buffer_length
          br i1 %offset_valid, label %check_range_length, label %invalid_argument

        check_range_length:
          %remaining = sub i64 %buffer_length, %range_offset
          %length_valid = icmp ule i64 %range_length, %remaining
          %length_fits = icmp ule i64 %range_length, 4294967295
          %range_valid = and i1 %length_valid, %length_fits
          br i1 %range_valid, label %store_buffer, label %invalid_argument

        store_buffer:
          %start = getelementptr i8, ptr %data, i64 %range_offset
          %native_buffer = getelementptr { i32, ptr }, ptr %native_buffers, i64 %index
          %native_length = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 0
          %native_data = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 1
          %range_length32 = trunc i64 %range_length to i32
          store i32 %range_length32, ptr %native_length, align 4
          store ptr %start, ptr %native_data, align 8
          %next = add i64 %index, 1
          %done = icmp eq i64 %next, %buffer_count
          br i1 %done, label %send_buffers, label %build

        send_buffers:
          %sent_address = alloca i32, align 4
          %buffer_count32 = trunc i64 %buffer_count to i32
          %status = call i32 @WSASend(i64 %socket, ptr %native_buffers, i32 %buffer_count32, ptr %sent_address, i32 0, ptr null, ptr null)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success_empty:
          %empty_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %empty_result

        success:
          %sent32 = load i32, ptr %sent_address, align 4
          %sent = zext i32 %sent32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %sent, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_receive_vectored(i64 %socket, ptr %buffers, i64 %buffer_count, i64 %stride, i64 %bytes_field_offset) #0 {
        entry:
          %count_valid = icmp ule i64 %buffer_count, 64
          br i1 %count_valid, label %check_empty, label %invalid_argument

        check_empty:
          %empty = icmp eq i64 %buffer_count, 0
          br i1 %empty, label %success_empty, label %prepare

        prepare:
          %native_buffers = alloca { i32, ptr }, i64 %buffer_count, align 8
          br label %build

        build:
          %index = phi i64 [ 0, %prepare ], [ %next, %store_buffer ]
          %descriptor_offset = mul i64 %index, %stride
          %descriptor = getelementptr i8, ptr %buffers, i64 %descriptor_offset
          %bytes = getelementptr i8, ptr %descriptor, i64 %bytes_field_offset
          %data = load ptr, ptr %bytes, align 8
          %capacity_address = getelementptr i8, ptr %bytes, i64 16
          %capacity = load i64, ptr %capacity_address, align 8
          %capacity_fits = icmp ule i64 %capacity, 4294967295
          br i1 %capacity_fits, label %store_buffer, label %invalid_argument

        store_buffer:
          %native_buffer = getelementptr { i32, ptr }, ptr %native_buffers, i64 %index
          %native_length = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 0
          %native_data = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 1
          %capacity32 = trunc i64 %capacity to i32
          store i32 %capacity32, ptr %native_length, align 4
          store ptr %data, ptr %native_data, align 8
          %next = add i64 %index, 1
          %done = icmp eq i64 %next, %buffer_count
          br i1 %done, label %receive_buffers, label %build

        receive_buffers:
          %received_address = alloca i32, align 4
          %flags_address = alloca i32, align 4
          store i32 0, ptr %flags_address, align 4
          %buffer_count32 = trunc i64 %buffer_count to i32
          %status = call i32 @WSARecv(i64 %socket, ptr %native_buffers, i32 %buffer_count32, ptr %received_address, ptr %flags_address, ptr null, ptr null)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %publish_prepare, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        publish_prepare:
          %received32 = load i32, ptr %received_address, align 4
          %received = zext i32 %received32 to i64
          br label %publish

        publish:
          %publish_index = phi i64 [ 0, %publish_prepare ], [ %publish_next, %publish_store ]
          %remaining = phi i64 [ %received, %publish_prepare ], [ %remaining_next, %publish_store ]
          %publish_descriptor_offset = mul i64 %publish_index, %stride
          %publish_descriptor = getelementptr i8, ptr %buffers, i64 %publish_descriptor_offset
          %publish_bytes = getelementptr i8, ptr %publish_descriptor, i64 %bytes_field_offset
          %publish_capacity_address = getelementptr i8, ptr %publish_bytes, i64 16
          %publish_capacity = load i64, ptr %publish_capacity_address, align 8
          %fills_segment = icmp uge i64 %remaining, %publish_capacity
          %published_length = select i1 %fills_segment, i64 %publish_capacity, i64 %remaining
          %remaining_next = sub i64 %remaining, %published_length
          %published_length_address = getelementptr i8, ptr %publish_bytes, i64 8
          br label %publish_store

        publish_store:
          store i64 %published_length, ptr %published_length_address, align 8
          %publish_next = add i64 %publish_index, 1
          %publish_done = icmp eq i64 %publish_next, %buffer_count
          br i1 %publish_done, label %success, label %publish

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success_empty:
          %empty_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %empty_result

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 %received, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_shutdown(i64 %socket, i32 %direction) #0 {
        entry:
          %status = call i32 @shutdown(i64 %socket, i32 %direction)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_no_delay(i64 %socket, i1 %enabled) #0 {
        entry:
          %value = alloca i32, align 4
          %value32 = zext i1 %enabled to i32
          store i32 %value32, ptr %value, align 4
          %status = call i32 @setsockopt(i64 %socket, i32 6, i32 1, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_no_delay(i64 %socket) #0 {
        entry:
          %value = alloca i32, align 4
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 4
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i64 %socket, i32 6, i32 1, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %value32 = load i32, ptr %value, align 4
          %value64 = zext i32 %value32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %value64, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_keep_alive(i64 %socket, i1 %enabled) #0 {
        entry:
          %value = alloca i32, align 4
          %value32 = zext i1 %enabled to i32
          store i32 %value32, ptr %value, align 4
          %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 8, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_keep_alive(i64 %socket) #0 {
        entry:
          %value = alloca i32, align 4
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 4
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 8, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %value32 = load i32, ptr %value, align 4
          %value64 = zext i32 %value32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %value64, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_linger(i64 %socket, i1 %enabled, i64 %millis) #0 {
        entry:
          %checked_millis = select i1 %enabled, i64 %millis, i64 1
          %positive = icmp sgt i64 %checked_millis, 0
          %fits = icmp ule i64 %checked_millis, 65535000
          %duration_valid = and i1 %positive, %fits
          %disabled = xor i1 %enabled, true
          %valid = or i1 %disabled, %duration_valid
          br i1 %valid, label %configure, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 10022)
          ret %sollang.socket_result %invalid

        configure:
          %value = alloca [2 x i16], align 2
          %onoff = zext i1 %enabled to i16
          %rounded = add i64 %checked_millis, 999
          %seconds64 = udiv i64 %rounded, 1000
          %seconds = trunc i64 %seconds64 to i16
          %onoff_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 0
          %seconds_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 1
          store i16 %onoff, ptr %onoff_address, align 2
          store i16 %seconds, ptr %seconds_address, align 2
          %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 128, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_linger(i64 %socket) #0 {
        entry:
          %value = alloca [2 x i16], align 2
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 2
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 128, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %decode, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        decode:
          %onoff_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 0
          %seconds_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 1
          %onoff = load i16, ptr %onoff_address, align 2
          %seconds = load i16, ptr %seconds_address, align 2
          %enabled = icmp ne i16 %onoff, 0
          %seconds64 = zext i16 %seconds to i64
          %millis = mul i64 %seconds64, 1000
          %selected = select i1 %enabled, i64 %millis, i64 -1
          %result = call %sollang.socket_result @sollang_socket_result(i64 %selected, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_read_timeout(i64 %socket, i1 %has_timeout, i64 %millis) #0 {
        entry:
          %positive = icmp sgt i64 %millis, 0
          %fits = icmp ule i64 %millis, 4294967295
          %duration_valid = and i1 %positive, %fits
          %disabled = xor i1 %has_timeout, true
          %valid = or i1 %disabled, %duration_valid
          br i1 %valid, label %configure, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 10022)
          ret %sollang.socket_result %invalid

        configure:
          %value = alloca i32, align 4
          %millis32 = trunc i64 %millis to i32
          %selected = select i1 %has_timeout, i32 %millis32, i32 0
          store i32 %selected, ptr %value, align 4
          %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4102, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_read_timeout(i64 %socket) #0 {
        entry:
          %value = alloca i32, align 4
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 4
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 4102, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %value32 = load i32, ptr %value, align 4
          %value64 = zext i32 %value32 to i64
          %disabled = icmp eq i32 %value32, 0
          %timeout = select i1 %disabled, i64 -1, i64 %value64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %timeout, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_write_timeout(i64 %socket, i1 %has_timeout, i64 %millis) #0 {
        entry:
          %positive = icmp sgt i64 %millis, 0
          %fits = icmp ule i64 %millis, 4294967295
          %duration_valid = and i1 %positive, %fits
          %disabled = xor i1 %has_timeout, true
          %valid = or i1 %disabled, %duration_valid
          br i1 %valid, label %configure, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 10022)
          ret %sollang.socket_result %invalid

        configure:
          %value = alloca i32, align 4
          %millis32 = trunc i64 %millis to i32
          %selected = select i1 %has_timeout, i32 %millis32, i32 0
          store i32 %selected, ptr %value, align 4
          %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4101, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_write_timeout(i64 %socket) #0 {
        entry:
          %value = alloca i32, align 4
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 4
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 4101, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %value32 = load i32, ptr %value, align 4
          %value64 = zext i32 %value32 to i64
          %disabled = icmp eq i32 %value32, 0
          %timeout = select i1 %disabled, i64 -1, i64 %value64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %timeout, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_bind_datagram(ptr %endpoint, i1 %reuse) #0 {
        entry:
          %started = call i32 @sollang_winsock_ensure_started()
          %start_ok = icmp eq i32 %started, 0
          br i1 %start_ok, label %parse, label %start_failed
        start_failed:
          %start_kind = call i32 @sollang_socket_error_kind(i32 %started)
          %start_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %start_kind, i32 %started)
          ret %sollang.socket_result %start_result
        parse:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
          %address_valid = icmp ne i32 %family, 0
          br i1 %address_valid, label %create, label %invalid_address
        create:
          %socket = call i64 @WSASocketW(i32 %family, i32 2, i32 17, ptr null, i32 0, i32 129)
          %created = icmp ne i64 %socket, -1
          br i1 %created, label %configure, label %create_failed
        configure:
          br i1 %reuse, label %set_reuse, label %bind_socket
        set_reuse:
          %reuse_value = alloca i32, align 4
          store i32 1, ptr %reuse_value, align 4
          %reuse_status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4, ptr %reuse_value, i32 4)
          %reuse_ok = icmp eq i32 %reuse_status, 0
          br i1 %reuse_ok, label %bind_socket, label %socket_failed
        bind_socket:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %bind_status = call i32 @bind(i64 %socket, ptr %socket_address, i32 %address_size)
          %bind_ok = icmp eq i32 %bind_status, 0
          br i1 %bind_ok, label %success, label %socket_failed
        socket_failed:
          %socket_error = call i32 @WSAGetLastError()
          %ignored_close = call i32 @closesocket(i64 %socket)
          %socket_kind = call i32 @sollang_socket_error_kind(i32 %socket_error)
          %socket_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %socket_kind, i32 %socket_error)
          ret %sollang.socket_result %socket_result
        create_failed:
          %create_error = call i32 @WSAGetLastError()
          %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
          %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
          ret %sollang.socket_result %create_result
        invalid_address:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %invalid_result
        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_send_to(i64 %socket, ptr %endpoint, ptr %buffer, i64 %length) #0 {
        entry:
          %fits = icmp ule i64 %length, 2147483647
          br i1 %fits, label %parse, label %invalid_argument
        parse:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
          %valid = icmp ne i32 %family, 0
          br i1 %valid, label %send_datagram, label %invalid_address
        send_datagram:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %length32 = trunc i64 %length to i32
          %count32 = call i32 @sendto(i64 %socket, ptr %buffer, i32 %length32, i32 0, ptr %socket_address, i32 %address_size)
          %ok = icmp sge i32 %count32, 0
          br i1 %ok, label %success, label %failure
        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
        invalid_address:
          %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %address_result
        invalid_argument:
          %argument_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %argument_result
        success:
          %count = zext i32 %count32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_local_port(i64 %socket) #0 {
        entry:
          %address = alloca [28 x i8], align 8
          %address_length = alloca i32, align 4
          store i32 28, ptr %address_length, align 4
          %status = call i32 @getsockname(i64 %socket, ptr %address, ptr %address_length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure
        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
        success:
          %network_port_address = getelementptr i8, ptr %address, i64 2
          %network_port = load i16, ptr %network_port_address, align 2
          %port16 = call i16 @sollang_socket_network_port(i16 %network_port)
          %port = zext i16 %port16 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %port, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_local_endpoint(i64 %socket, ptr %endpoint) #0 {
        entry:
          %address = alloca [28 x i8], align 8
          %address_length = alloca i32, align 4
          store i32 28, ptr %address_length, align 4
          %status = call i32 @getsockname(i64 %socket, ptr %address, ptr %address_length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %pack, label %failure
        pack:
          %family = call i32 @sollang_socket_endpoint(ptr %address, ptr %endpoint)
          %packed = icmp ne i32 %family, 0
          br i1 %packed, label %success, label %invalid_address
        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
        invalid_address:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %invalid
        }

        define internal %sollang.socket_result @sollang_platform_socket_remote_endpoint(i64 %socket, ptr %endpoint) #0 {
        entry:
          %address = alloca [28 x i8], align 8
          %address_length = alloca i32, align 4
          store i32 28, ptr %address_length, align 4
          %status = call i32 @getpeername(i64 %socket, ptr %address, ptr %address_length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %pack, label %failure
        pack:
          %family = call i32 @sollang_socket_endpoint(ptr %address, ptr %endpoint)
          %packed = icmp ne i32 %family, 0
          br i1 %packed, label %success, label %invalid_address
        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
        invalid_address:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %invalid
        }

        define internal %sollang.socket_result @sollang_platform_socket_receive_from(i64 %socket, ptr %buffer, i64 %capacity, i32 %flags, ptr %endpoint, ptr %truncated) #0 {
        entry:
          store i8 0, ptr %truncated, align 1
          %positive = icmp ugt i64 %capacity, 0
          %fits = icmp ule i64 %capacity, 2147483647
          %valid = and i1 %positive, %fits
          br i1 %valid, label %receive, label %invalid_argument
        receive:
          %source = alloca [28 x i8], align 8
          %source_length = alloca i32, align 4
          %received = alloca i32, align 4
          %received_flags = alloca i32, align 4
          %wsabuf = alloca { i32, ptr }, align 8
          store i32 28, ptr %source_length, align 4
          store i32 0, ptr %received, align 4
          store i32 %flags, ptr %received_flags, align 4
          %capacity32 = trunc i64 %capacity to i32
          %wsabuf_length = getelementptr inbounds { i32, ptr }, ptr %wsabuf, i32 0, i32 0
          %wsabuf_buffer = getelementptr inbounds { i32, ptr }, ptr %wsabuf, i32 0, i32 1
          store i32 %capacity32, ptr %wsabuf_length, align 4
          store ptr %buffer, ptr %wsabuf_buffer, align 8
          %status = call i32 @WSARecvFrom(i64 %socket, ptr %wsabuf, i32 1, ptr %received, ptr %received_flags, ptr %source, ptr %source_length, ptr null, ptr null)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %received_ok, label %classify_failure
        received_ok:
          %received32 = load i32, ptr %received, align 4
          %count_ok = zext i32 %received32 to i64
          br label %pack
        classify_failure:
          %error = call i32 @WSAGetLastError()
          %message_too_large = icmp eq i32 %error, 10040
          br i1 %message_too_large, label %received_truncated, label %failure
        received_truncated:
          store i8 1, ptr %truncated, align 1
          br label %pack
        pack:
          %count = phi i64 [ %count_ok, %received_ok ], [ %capacity, %received_truncated ]
          %family = call i32 @sollang_socket_endpoint(ptr %source, ptr %endpoint)
          %packed = icmp ne i32 %family, 0
          br i1 %packed, label %publish, label %invalid_address
        publish:
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        failure:
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
        invalid_address:
          %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %address_result
        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid
        }

        define internal void @sollang_platform_close_socket(i64 %socket) #0 {
        entry:
          %valid = icmp ne i64 %socket, -1
          br i1 %valid, label %close, label %done

        close:
          %ignored = call i32 @closesocket(i64 %socket)
          br label %done

        done:
          ret void
        }

        """;

    private const string CompletionRuntime = """
        define internal i32 @sollang_socket_completion_waiter(ptr %state) #0 {
        entry:
          %port = load ptr, ptr %state, align 8
          %completion_table_slot = getelementptr i8, ptr %state, i64 24
          %completion_table = load ptr, ptr %completion_table_slot, align 8
          br label %wait
        wait:
          %removed = alloca i32, align 4
          store i32 0, ptr %removed, align 4
          %waited = call i32 @GetQueuedCompletionStatusEx(ptr %port, ptr %completion_table, i32 1, ptr %removed, i32 -1, i32 0)
          %wait_ok = icmp ne i32 %waited, 0
          br i1 %wait_ok, label %inspect, label %trap
        inspect:
          %overlapped_slot = getelementptr i8, ptr %completion_table, i64 8
          %overlapped = load ptr, ptr %overlapped_slot, align 8
          %is_stop = icmp eq ptr %overlapped, null
          br i1 %is_stop, label %check_stop, label %record
        check_stop:
          %stopping_slot = getelementptr i8, ptr %state, i64 80
          %stopping = load atomic i32, ptr %stopping_slot acquire, align 4
          %must_stop = icmp ne i32 %stopping, 0
          br i1 %must_stop, label %done, label %trap
        record:
          %pending_record = getelementptr i8, ptr %overlapped, i64 -72
          %active = load atomic i64, ptr %pending_record acquire, align 8
          %is_pending = icmp eq i64 %active, 1
          br i1 %is_pending, label %publish, label %trap
        publish:
          %completion_status_slot = getelementptr i8, ptr %completion_table, i64 16
          %completion_status64 = load i64, ptr %completion_status_slot, align 8
          %completion_status = trunc i64 %completion_status64 to i32
          %record_status_slot = getelementptr i8, ptr %pending_record, i64 116
          store i32 %completion_status, ptr %record_status_slot, align 4
          %transferred_slot = getelementptr i8, ptr %completion_table, i64 24
          %transferred = load i32, ptr %transferred_slot, align 4
          %record_transferred_slot = getelementptr i8, ptr %pending_record, i64 120
          store i32 %transferred, ptr %record_transferred_slot, align 4
          store atomic i64 2, ptr %pending_record release, align 8
          %pending_count_slot = getelementptr i8, ptr %state, i64 64
          %remaining = atomicrmw sub ptr %pending_count_slot, i64 1 acq_rel
          %task_slot = getelementptr i8, ptr %state, i64 88
          %task = atomicrmw xchg ptr %task_slot, ptr null acq_rel
          %has_task = icmp ne ptr %task, null
          br i1 %has_task, label %wake, label %signal_only
        wake:
          call void @sollang_io_push_completion(ptr %task)
          br label %signal_only
        signal_only:
          call void @sollang_platform_io_signal_completion()
          br label %wait
        done:
          ret i32 0
        trap:
          call void @llvm.trap()
          unreachable
        }

        define internal void @sollang_socket_completion_record_task(ptr %control, %sollang.socket_result %raw) #0 {
        entry:
          %value = extractvalue %sollang.socket_result %raw, 0
          %value_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 14
          store i64 %value, ptr %value_slot, align 8
          %kind = extractvalue %sollang.socket_result %raw, 1
          %kind_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 15
          store i32 %kind, ptr %kind_slot, align 4
          %code = extractvalue %sollang.socket_result %raw, 2
          %code_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 11
          store i32 %code, ptr %code_slot, align 4
          ret void
        }

        define internal i1 @sollang_socket_completion_dequeue_task_worker(ptr %control) #0 {
        entry:
          %descriptor_value_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 13
          %descriptor_value = load i64, ptr %descriptor_value_slot, align 8
          %descriptor = inttoptr i64 %descriptor_value to ptr
          %identity_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 17
          %identity = load i64, ptr %identity_slot, align 8
          %phase_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 12
          %phase = load atomic i32, ptr %phase_slot acquire, align 4
          %already_recorded = icmp eq i32 %phase, 2
          br i1 %already_recorded, label %done, label %probe
        probe:
          %cancelled_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 20
          %cancelled32 = load i32, ptr %cancelled_slot, align 4
          %cancelled = icmp ne i32 %cancelled32, 0
          %raw = call %sollang.socket_result @sollang_platform_socket_completion_dequeue(i64 %identity, i1 %cancelled, ptr %descriptor)
          %kind = extractvalue %sollang.socket_result %raw, 1
          %is_pending = icmp eq i32 %kind, -2
          br i1 %is_pending, label %inspect_phase, label %record
        inspect_phase:
          %initial = icmp eq i32 %phase, 0
          br i1 %initial, label %arm, label %trap
        arm:
          %state = inttoptr i64 %identity to ptr
          %task_slot = getelementptr i8, ptr %state, i64 88
          %old_count = atomicrmw add ptr @sollang_io_outstanding, i64 1 acq_rel
          store atomic i32 1, ptr %phase_slot release, align 4
          %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
          store i32 6, ptr %status_slot, align 4
          %registration = cmpxchg ptr %task_slot, ptr null, ptr %control acq_rel acquire
          %registered = extractvalue { ptr, i1 } %registration, 1
          br i1 %registered, label %race_probe, label %trap
        race_probe:
          %race_raw = call %sollang.socket_result @sollang_platform_socket_completion_dequeue(i64 %identity, i1 false, ptr %descriptor)
          %race_kind = extractvalue %sollang.socket_result %race_raw, 1
          %race_pending = icmp eq i32 %race_kind, -2
          br i1 %race_pending, label %parked, label %race_record
        race_record:
          call void @sollang_socket_completion_record_task(ptr %control, %sollang.socket_result %race_raw)
          store atomic i32 2, ptr %phase_slot release, align 4
          %unregister = cmpxchg ptr %task_slot, ptr %control, ptr null acq_rel acquire
          %unregistered = extractvalue { ptr, i1 } %unregister, 1
          br i1 %unregistered, label %complete_inline, label %parked
        complete_inline:
          %rolled_back = atomicrmw sub ptr @sollang_io_outstanding, i64 1 acq_rel
          ret i1 true
        record:
          call void @sollang_socket_completion_record_task(ptr %control, %sollang.socket_result %raw)
          ret i1 true
        done:
          ret i1 true
        parked:
          ret i1 false
        trap:
          call void @llvm.trap()
          unreachable
        }

        define internal void @sollang_socket_completion_dequeue_task_cancel(ptr %control) #0 {
        entry:
          %identity_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 17
          %identity = load i64, ptr %identity_slot, align 8
          call void @sollang_platform_socket_completion_close(i64 %identity)
          %descriptor_value_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 13
          %descriptor_value = load i64, ptr %descriptor_value_slot, align 8
          %descriptor = inttoptr i64 %descriptor_value to ptr
          call void @sollang_free(ptr %descriptor)
          %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
          %context = load ptr, ptr %context_slot, align 8
          call void @sollang_free(ptr %context)
          ret void
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_create(i64 %registrations, i64 %pending, i64 %batch) #0 {
        entry:
          %registrations_min = icmp uge i64 %registrations, 1
          %registrations_max = icmp ule i64 %registrations, 1024
          %pending_min = icmp uge i64 %pending, 1
          %pending_relation = icmp ule i64 %pending, %registrations
          %batch_min = icmp uge i64 %batch, 1
          %batch_relation = icmp ule i64 %batch, %pending
          %valid0 = and i1 %registrations_min, %registrations_max
          %valid1 = and i1 %pending_min, %pending_relation
          %valid2 = and i1 %batch_min, %batch_relation
          %valid3 = and i1 %valid0, %valid1
          %valid = and i1 %valid3, %valid2
          br i1 %valid, label %create_port, label %invalid
        create_port:
          %invalid_handle = inttoptr i64 -1 to ptr
          %port = call ptr @CreateIoCompletionPort(ptr %invalid_handle, ptr null, i64 0, i32 0)
          %port_ok = icmp ne ptr %port, null
          br i1 %port_ok, label %allocate_state, label %port_failed
        allocate_state:
          %state = call ptr @sollang_alloc(i64 96)
          %state_ok = icmp ne ptr %state, null
          br i1 %state_ok, label %allocate_registrations, label %state_allocation_failed
        allocate_registrations:
          %registration_bytes = mul nuw i64 %registrations, 32
          %registration_table = call ptr @sollang_alloc(i64 %registration_bytes)
          %registration_table_ok = icmp ne ptr %registration_table, null
          br i1 %registration_table_ok, label %allocate_pending, label %registration_allocation_failed
        allocate_pending:
          %pending_bytes = mul nuw i64 %pending, 128
          %pending_table = call ptr @sollang_alloc(i64 %pending_bytes)
          %pending_table_ok = icmp ne ptr %pending_table, null
          br i1 %pending_table_ok, label %allocate_completions, label %pending_allocation_failed
        allocate_completions:
          %completion_bytes = mul nuw i64 %batch, 32
          %completion_table = call ptr @sollang_alloc(i64 %completion_bytes)
          %completion_table_ok = icmp ne ptr %completion_table, null
          br i1 %completion_table_ok, label %initialize, label %completion_allocation_failed
        initialize:
          call void @llvm.memset.p0.i64(ptr %registration_table, i8 0, i64 %registration_bytes, i1 false)
          call void @llvm.memset.p0.i64(ptr %pending_table, i8 0, i64 %pending_bytes, i1 false)
          call void @llvm.memset.p0.i64(ptr %completion_table, i8 0, i64 %completion_bytes, i1 false)
          store ptr %port, ptr %state, align 8
          %registration_table_slot = getelementptr i8, ptr %state, i64 8
          store ptr %registration_table, ptr %registration_table_slot, align 8
          %pending_table_slot = getelementptr i8, ptr %state, i64 16
          store ptr %pending_table, ptr %pending_table_slot, align 8
          %completion_table_slot = getelementptr i8, ptr %state, i64 24
          store ptr %completion_table, ptr %completion_table_slot, align 8
          %registrations_slot = getelementptr i8, ptr %state, i64 32
          store i64 %registrations, ptr %registrations_slot, align 8
          %pending_slot = getelementptr i8, ptr %state, i64 40
          store i64 %pending, ptr %pending_slot, align 8
          %batch_slot = getelementptr i8, ptr %state, i64 48
          store i64 %batch, ptr %batch_slot, align 8
          %registration_count = getelementptr i8, ptr %state, i64 56
          store i64 0, ptr %registration_count, align 8
          %pending_count = getelementptr i8, ptr %state, i64 64
          store i64 0, ptr %pending_count, align 8
          %waiter_handle = getelementptr i8, ptr %state, i64 72
          store ptr null, ptr %waiter_handle, align 8
          %stopping = getelementptr i8, ptr %state, i64 80
          store atomic i32 0, ptr %stopping release, align 4
          %waiting_task = getelementptr i8, ptr %state, i64 88
          store atomic ptr null, ptr %waiting_task release, align 8
          %identity = ptrtoint ptr %state to i64
          %success = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 -1, i32 0)
          ret %sollang.socket_result %success
        completion_allocation_failed:
          call void @sollang_free(ptr %pending_table)
          br label %pending_allocation_failed
        pending_allocation_failed:
          call void @sollang_free(ptr %registration_table)
          br label %registration_allocation_failed
        registration_allocation_failed:
          call void @sollang_free(ptr %state)
          br label %state_allocation_failed
        state_allocation_failed:
          %closed = call i32 @CloseHandle(ptr %port)
          %allocation_error = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 8, i32 8)
          ret %sollang.socket_result %allocation_error
        port_failed:
          %port_error = call i32 @GetLastError()
          %port_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 8, i32 %port_error)
          ret %sollang.socket_result %port_result
        invalid:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_register_stream(i64 %identity, i64 %socket, i64 %key) #0 {
        entry:
          %identity_ok = icmp ugt i64 %identity, 0
          %socket_ok = icmp ne i64 %socket, -1
          %valid = and i1 %identity_ok, %socket_ok
          br i1 %valid, label %load_state, label %invalid_argument
        load_state:
          %state = inttoptr i64 %identity to ptr
          %table_slot = getelementptr i8, ptr %state, i64 8
          %table = load ptr, ptr %table_slot, align 8
          %capacity_slot = getelementptr i8, ptr %state, i64 32
          %capacity = load i64, ptr %capacity_slot, align 8
          %count_slot = getelementptr i8, ptr %state, i64 56
          %count = load i64, ptr %count_slot, align 8
          br label %duplicate_loop
        duplicate_loop:
          %duplicate_index = phi i64 [ 0, %load_state ], [ %duplicate_next, %duplicate_continue ]
          %duplicate_done = icmp uge i64 %duplicate_index, %capacity
          br i1 %duplicate_done, label %free_loop, label %duplicate_check
        duplicate_check:
          %duplicate_offset = mul nuw i64 %duplicate_index, 32
          %duplicate_entry = getelementptr i8, ptr %table, i64 %duplicate_offset
          %duplicate_active = load i64, ptr %duplicate_entry, align 8
          %duplicate_active_ok = icmp ne i64 %duplicate_active, 0
          %duplicate_key_slot = getelementptr i8, ptr %duplicate_entry, i64 8
          %duplicate_key = load i64, ptr %duplicate_key_slot, align 8
          %duplicate_key_ok = icmp eq i64 %duplicate_key, %key
          %duplicate = and i1 %duplicate_active_ok, %duplicate_key_ok
          br i1 %duplicate, label %duplicate_failure, label %duplicate_continue
        duplicate_continue:
          %duplicate_next = add nuw i64 %duplicate_index, 1
          br label %duplicate_loop
        free_loop:
          %free_index = phi i64 [ 0, %duplicate_loop ], [ %free_next, %free_continue ]
          %free_done = icmp uge i64 %free_index, %capacity
          br i1 %free_done, label %capacity_failure, label %free_check
        free_check:
          %free_offset = mul nuw i64 %free_index, 32
          %free_entry = getelementptr i8, ptr %table, i64 %free_offset
          %free_active = load i64, ptr %free_entry, align 8
          %is_free = icmp eq i64 %free_active, 0
          br i1 %is_free, label %publish, label %free_continue
        free_continue:
          %free_next = add nuw i64 %free_index, 1
          br label %free_loop
        publish:
          %key_slot = getelementptr i8, ptr %free_entry, i64 8
          store i64 %key, ptr %key_slot, align 8
          %socket_slot = getelementptr i8, ptr %free_entry, i64 16
          store i64 %socket, ptr %socket_slot, align 8
          %submission_state_slot = getelementptr i8, ptr %free_entry, i64 24
          store i64 0, ptr %submission_state_slot, align 8
          %next_count = add nuw i64 %count, 1
          store i64 %next_count, ptr %count_slot, align 8
          store i64 1, ptr %free_entry, align 8
          %success = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 -1, i32 0)
          ret %sollang.socket_result %success
        duplicate_failure:
          %duplicate_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 1, i32 0)
          ret %sollang.socket_result %duplicate_result
        capacity_failure:
          %capacity_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 8, i32 0)
          ret %sollang.socket_result %capacity_result
        invalid_argument:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 1, i32 0)
          ret %sollang.socket_result %invalid_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_remove_stream(i64 %identity, i64 %key) #0 {
        entry:
          %valid = icmp ugt i64 %identity, 0
          br i1 %valid, label %load_state, label %not_found
        load_state:
          %state = inttoptr i64 %identity to ptr
          %table_slot = getelementptr i8, ptr %state, i64 8
          %table = load ptr, ptr %table_slot, align 8
          %capacity_slot = getelementptr i8, ptr %state, i64 32
          %capacity = load i64, ptr %capacity_slot, align 8
          br label %scan
        scan:
          %index = phi i64 [ 0, %load_state ], [ %next, %continue ]
          %done = icmp uge i64 %index, %capacity
          br i1 %done, label %not_found, label %check
        check:
          %offset = mul nuw i64 %index, 32
          %registration_entry = getelementptr i8, ptr %table, i64 %offset
          %active = load i64, ptr %registration_entry, align 8
          %active_ok = icmp ne i64 %active, 0
          %key_slot = getelementptr i8, ptr %registration_entry, i64 8
          %entry_key = load i64, ptr %key_slot, align 8
          %key_ok = icmp eq i64 %entry_key, %key
          %match = and i1 %active_ok, %key_ok
          br i1 %match, label %check_unassociated, label %continue
        continue:
          %next = add nuw i64 %index, 1
          br label %scan
        check_unassociated:
          %association_state_slot = getelementptr i8, ptr %registration_entry, i64 24
          %association_state = load i64, ptr %association_state_slot, align 8
          %unassociated = icmp eq i64 %association_state, 0
          br i1 %unassociated, label %remove, label %associated_failure
        remove:
          %socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %socket = load i64, ptr %socket_slot, align 8
          store i64 0, ptr %registration_entry, align 8
          store i64 0, ptr %key_slot, align 8
          store i64 -1, ptr %socket_slot, align 8
          %submission_state_slot = getelementptr i8, ptr %registration_entry, i64 24
          store i64 0, ptr %submission_state_slot, align 8
          %count_slot = getelementptr i8, ptr %state, i64 56
          %count = load i64, ptr %count_slot, align 8
          %next_count = sub nuw i64 %count, 1
          store i64 %next_count, ptr %count_slot, align 8
          %success = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
          ret %sollang.socket_result %success
        not_found:
          %failure = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %failure
        associated_failure:
          %associated_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %associated_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_submit(i64 %identity, i64 %registration_key, i64 %application_key, i32 %direction, ptr %buffer, i64 %buffer_length, i64 %buffer_capacity, i64 %range_offset, i64 %range_length, i32 %slot_state) #0 {
        entry:
          %identity_ok = icmp ugt i64 %identity, 0
          %vacant = icmp eq i32 %slot_state, 0
          %offset_ok = icmp ule i64 %range_offset, %buffer_length
          %remaining = sub i64 %buffer_length, %range_offset
          %length_ok = icmp ule i64 %range_length, %remaining
          %length_native_ok = icmp ule i64 %range_length, 2147483647
          %range_ok = and i1 %offset_ok, %length_ok
          %native_range_ok = and i1 %range_ok, %length_native_ok
          %valid0 = and i1 %identity_ok, %vacant
          %valid = and i1 %valid0, %native_range_ok
          br i1 %valid, label %load_state, label %invalid_argument
        load_state:
          %state = inttoptr i64 %identity to ptr
          %port = load ptr, ptr %state, align 8
          %registration_table_slot = getelementptr i8, ptr %state, i64 8
          %registration_table = load ptr, ptr %registration_table_slot, align 8
          %pending_table_slot = getelementptr i8, ptr %state, i64 16
          %pending_table = load ptr, ptr %pending_table_slot, align 8
          %registration_capacity_slot = getelementptr i8, ptr %state, i64 32
          %registration_capacity = load i64, ptr %registration_capacity_slot, align 8
          %pending_capacity_slot = getelementptr i8, ptr %state, i64 40
          %pending_capacity = load i64, ptr %pending_capacity_slot, align 8
          br label %registration_scan
        registration_scan:
          %registration_index = phi i64 [ 0, %load_state ], [ %registration_next, %registration_continue ]
          %registration_done = icmp uge i64 %registration_index, %registration_capacity
          br i1 %registration_done, label %registration_missing, label %registration_check
        registration_check:
          %registration_offset = mul nuw i64 %registration_index, 32
          %registration_entry = getelementptr i8, ptr %registration_table, i64 %registration_offset
          %registration_active = load i64, ptr %registration_entry, align 8
          %registration_active_ok = icmp ne i64 %registration_active, 0
          %registration_key_slot = getelementptr i8, ptr %registration_entry, i64 8
          %registered_key = load i64, ptr %registration_key_slot, align 8
          %registration_key_ok = icmp eq i64 %registered_key, %registration_key
          %registration_match = and i1 %registration_active_ok, %registration_key_ok
          br i1 %registration_match, label %duplicate_scan, label %registration_continue
        registration_continue:
          %registration_next = add nuw i64 %registration_index, 1
          br label %registration_scan
        duplicate_scan:
          %duplicate_index = phi i64 [ 0, %registration_check ], [ %duplicate_next, %duplicate_continue ]
          %duplicate_done = icmp uge i64 %duplicate_index, %pending_capacity
          br i1 %duplicate_done, label %free_scan, label %duplicate_check
        duplicate_check:
          %duplicate_offset = mul nuw i64 %duplicate_index, 128
          %duplicate_entry = getelementptr i8, ptr %pending_table, i64 %duplicate_offset
          %duplicate_active = load atomic i64, ptr %duplicate_entry acquire, align 8
          %duplicate_active_ok = icmp ne i64 %duplicate_active, 0
          %duplicate_key_slot = getelementptr i8, ptr %duplicate_entry, i64 8
          %duplicate_key = load i64, ptr %duplicate_key_slot, align 8
          %duplicate_key_ok = icmp eq i64 %duplicate_key, %application_key
          %duplicate_match = and i1 %duplicate_active_ok, %duplicate_key_ok
          br i1 %duplicate_match, label %duplicate_failure, label %duplicate_continue
        duplicate_continue:
          %duplicate_next = add nuw i64 %duplicate_index, 1
          br label %duplicate_scan
        free_scan:
          %free_index = phi i64 [ 0, %duplicate_scan ], [ %free_next, %free_continue ]
          %free_done = icmp uge i64 %free_index, %pending_capacity
          br i1 %free_done, label %pending_capacity_failure, label %free_check
        free_check:
          %free_offset = mul nuw i64 %free_index, 128
          %pending_entry = getelementptr i8, ptr %pending_table, i64 %free_offset
          %pending_active = load atomic i64, ptr %pending_entry acquire, align 8
          %is_free = icmp eq i64 %pending_active, 0
          br i1 %is_free, label %prepare, label %free_continue
        free_continue:
          %free_next = add nuw i64 %free_index, 1
          br label %free_scan
        prepare:
          %application_key_slot = getelementptr i8, ptr %pending_entry, i64 8
          store i64 %application_key, ptr %application_key_slot, align 8
          %pending_registration_slot = getelementptr i8, ptr %pending_entry, i64 16
          store i64 %registration_index, ptr %pending_registration_slot, align 8
          %direction_slot = getelementptr i8, ptr %pending_entry, i64 24
          store i32 %direction, ptr %direction_slot, align 4
          %buffer_slot = getelementptr i8, ptr %pending_entry, i64 32
          store ptr %buffer, ptr %buffer_slot, align 8
          %buffer_length_slot = getelementptr i8, ptr %pending_entry, i64 40
          store i64 %buffer_length, ptr %buffer_length_slot, align 8
          %buffer_capacity_slot = getelementptr i8, ptr %pending_entry, i64 48
          store i64 %buffer_capacity, ptr %buffer_capacity_slot, align 8
          %range_offset_slot = getelementptr i8, ptr %pending_entry, i64 56
          store i64 %range_offset, ptr %range_offset_slot, align 8
          %range_length_slot = getelementptr i8, ptr %pending_entry, i64 64
          store i64 %range_length, ptr %range_length_slot, align 8
          %overlapped = getelementptr i8, ptr %pending_entry, i64 72
          call void @llvm.memset.p0.i64(ptr %overlapped, i8 0, i64 32, i1 false)
          %cancel_requested = getelementptr i8, ptr %pending_entry, i64 112
          store atomic i32 0, ptr %cancel_requested release, align 4
          %waiter_slot = getelementptr i8, ptr %state, i64 72
          %waiter = load ptr, ptr %waiter_slot, align 8
          %waiter_started = icmp ne ptr %waiter, null
          br i1 %waiter_started, label %inspect_association, label %start_waiter
        start_waiter:
          %signal_ready = call i1 @sollang_platform_io_ensure_signal()
          br i1 %signal_ready, label %create_waiter, label %waiter_start_failure
        create_waiter:
          %new_waiter = call ptr @CreateThread(ptr null, i64 0, ptr @sollang_socket_completion_waiter, ptr %state, i32 0, ptr null)
          %new_waiter_ok = icmp ne ptr %new_waiter, null
          br i1 %new_waiter_ok, label %publish_waiter, label %waiter_start_failure
        publish_waiter:
          store ptr %new_waiter, ptr %waiter_slot, align 8
          br label %inspect_association
        inspect_association:
          %association_slot = getelementptr i8, ptr %registration_entry, i64 24
          %association = load i64, ptr %association_slot, align 8
          %unassociated = icmp eq i64 %association, 0
          br i1 %unassociated, label %associate, label %issue
        associate:
          %socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %socket = load i64, ptr %socket_slot, align 8
          %socket_handle = inttoptr i64 %socket to ptr
          %native_identity_base = add nuw i64 %registration_index, 1
          %native_identity_shifted = shl i64 %native_identity_base, 1
          %native_identity = or i64 %native_identity_shifted, 1
          %associated_port = call ptr @CreateIoCompletionPort(ptr %socket_handle, ptr %port, i64 %native_identity, i32 0)
          %association_ok = icmp eq ptr %associated_port, %port
          br i1 %association_ok, label %set_completion_mode, label %association_failure
        set_completion_mode:
          %completion_mode_set = call i32 @SetFileCompletionNotificationModes(ptr %socket_handle, i8 3)
          %completion_mode_ok = icmp ne i32 %completion_mode_set, 0
          br i1 %completion_mode_ok, label %publish_association, label %completion_mode_failure
        publish_association:
          store i64 %native_identity, ptr %association_slot, align 8
          br label %issue
        issue:
          %registered_socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %registered_socket = load i64, ptr %registered_socket_slot, align 8
          %pending_count_slot = getelementptr i8, ptr %state, i64 64
          %previous_pending_count = atomicrmw add ptr %pending_count_slot, i64 1 acq_rel
          store atomic i64 1, ptr %pending_entry release, align 8
          %data = getelementptr i8, ptr %buffer, i64 %range_offset
          %native_length = trunc i64 %range_length to i32
          %wsabuf = alloca [16 x i8], align 8
          store i32 %native_length, ptr %wsabuf, align 4
          %wsabuf_pointer = getelementptr i8, ptr %wsabuf, i64 8
          store ptr %data, ptr %wsabuf_pointer, align 8
          %transferred = alloca i32, align 4
          store i32 0, ptr %transferred, align 4
          %flags = alloca i32, align 4
          store i32 0, ptr %flags, align 4
          %is_receive = icmp eq i32 %direction, 0
          br i1 %is_receive, label %issue_receive, label %issue_send
        issue_receive:
          %receive_status = call i32 @WSARecv(i64 %registered_socket, ptr %wsabuf, i32 1, ptr %transferred, ptr %flags, ptr %overlapped, ptr null)
          br label %classify_issue
        issue_send:
          %send_status = call i32 @WSASend(i64 %registered_socket, ptr %wsabuf, i32 1, ptr %transferred, i32 0, ptr %overlapped, ptr null)
          br label %classify_issue
        classify_issue:
          %status = phi i32 [ %receive_status, %issue_receive ], [ %send_status, %issue_send ]
          %completed = icmp eq i32 %status, 0
          br i1 %completed, label %synchronous_completion, label %classify_failure
        synchronous_completion:
          store atomic i64 0, ptr %pending_entry release, align 8
          %sync_count_rollback = atomicrmw sub ptr %pending_count_slot, i64 1 acq_rel
          %completed32 = load i32, ptr %transferred, align 4
          %completed64 = zext i32 %completed32 to i64
          %completed_result = call %sollang.socket_result @sollang_socket_result(i64 %completed64, i32 -1, i32 0)
          ret %sollang.socket_result %completed_result
        classify_failure:
          %issue_error = call i32 @WSAGetLastError()
          %is_pending = icmp eq i32 %issue_error, 997
          br i1 %is_pending, label %publish_pending, label %issue_failure
        publish_pending:
          %operation_identity = add nuw i64 %free_index, 1
          %pending_result = call %sollang.socket_result @sollang_socket_result(i64 %operation_identity, i32 -2, i32 0)
          ret %sollang.socket_result %pending_result
        waiter_start_failure:
          %waiter_error = call i32 @GetLastError()
          %waiter_failure = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 8, i32 %waiter_error)
          ret %sollang.socket_result %waiter_failure
        issue_failure:
          store atomic i64 0, ptr %pending_entry release, align 8
          %failure_count_rollback = atomicrmw sub ptr %pending_count_slot, i64 1 acq_rel
          %issue_kind = call i32 @sollang_socket_error_kind(i32 %issue_error)
          %issue_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %issue_kind, i32 %issue_error)
          ret %sollang.socket_result %issue_result
        association_failure:
          %association_error = call i32 @GetLastError()
          %association_kind = call i32 @sollang_socket_error_kind(i32 %association_error)
          %association_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %association_kind, i32 %association_error)
          ret %sollang.socket_result %association_result
        completion_mode_failure:
          %completion_mode_error = call i32 @GetLastError()
          %completion_mode_kind = call i32 @sollang_socket_error_kind(i32 %completion_mode_error)
          %completion_mode_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %completion_mode_kind, i32 %completion_mode_error)
          ret %sollang.socket_result %completion_mode_result
        duplicate_failure:
          %duplicate_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %duplicate_result
        pending_capacity_failure:
          %pending_capacity_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 8, i32 0)
          ret %sollang.socket_result %pending_capacity_result
        registration_missing:
          %registration_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %registration_result
        invalid_argument:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_cancel(i64 %identity, i64 %application_key) #0 {
        entry:
          %valid = icmp ugt i64 %identity, 0
          br i1 %valid, label %load_state, label %not_found
        load_state:
          %state = inttoptr i64 %identity to ptr
          %registration_table_slot = getelementptr i8, ptr %state, i64 8
          %registration_table = load ptr, ptr %registration_table_slot, align 8
          %pending_table_slot = getelementptr i8, ptr %state, i64 16
          %pending_table = load ptr, ptr %pending_table_slot, align 8
          %pending_capacity_slot = getelementptr i8, ptr %state, i64 40
          %pending_capacity = load i64, ptr %pending_capacity_slot, align 8
          br label %scan
        scan:
          %index = phi i64 [ 0, %load_state ], [ %next, %continue ]
          %done = icmp uge i64 %index, %pending_capacity
          br i1 %done, label %not_found, label %check
        check:
          %offset = mul nuw i64 %index, 128
          %pending_record = getelementptr i8, ptr %pending_table, i64 %offset
          %active = load atomic i64, ptr %pending_record acquire, align 8
          %active_ok = icmp ne i64 %active, 0
          %key_slot = getelementptr i8, ptr %pending_record, i64 8
          %key = load i64, ptr %key_slot, align 8
          %key_ok = icmp eq i64 %key, %application_key
          %match = and i1 %active_ok, %key_ok
          br i1 %match, label %request_cancel, label %continue
        continue:
          %next = add nuw i64 %index, 1
          br label %scan
        request_cancel:
          %cancel_requested = getelementptr i8, ptr %pending_record, i64 112
          store atomic i32 1, ptr %cancel_requested release, align 4
          %registration_index_slot = getelementptr i8, ptr %pending_record, i64 16
          %registration_index = load i64, ptr %registration_index_slot, align 8
          %registration_offset = mul nuw i64 %registration_index, 32
          %registration_entry = getelementptr i8, ptr %registration_table, i64 %registration_offset
          %socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %socket = load i64, ptr %socket_slot, align 8
          %socket_handle = inttoptr i64 %socket to ptr
          %overlapped = getelementptr i8, ptr %pending_record, i64 72
          %cancelled = call i32 @CancelIoEx(ptr %socket_handle, ptr %overlapped)
          %cancel_ok = icmp ne i32 %cancelled, 0
          br i1 %cancel_ok, label %success, label %classify_cancel_error
        classify_cancel_error:
          %cancel_error = call i32 @GetLastError()
          %completion_won = icmp eq i32 %cancel_error, 1168
          br i1 %completion_won, label %success, label %cancel_failure
        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        cancel_failure:
          %cancel_kind = call i32 @sollang_socket_error_kind(i32 %cancel_error)
          %cancel_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 %cancel_kind, i32 %cancel_error)
          ret %sollang.socket_result %cancel_result
        not_found:
          %not_found_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 1, i32 0)
          ret %sollang.socket_result %not_found_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_dequeue(i64 %identity, i1 %cancelled, ptr %descriptor) #0 {
        entry:
          %valid = icmp ugt i64 %identity, 0
          br i1 %valid, label %check_cancelled, label %invalid_argument
        check_cancelled:
          br i1 %cancelled, label %wait_cancelled, label %load_state
        load_state:
          %state = inttoptr i64 %identity to ptr
          %pending_table_slot = getelementptr i8, ptr %state, i64 16
          %pending_table = load ptr, ptr %pending_table_slot, align 8
          %pending_capacity_slot = getelementptr i8, ptr %state, i64 40
          %pending_capacity = load i64, ptr %pending_capacity_slot, align 8
          br label %scan_completed
        scan_completed:
          %completed_index = phi i64 [ 0, %load_state ], [ %completed_next, %completed_continue ]
          %completed_done = icmp uge i64 %completed_index, %pending_capacity
          br i1 %completed_done, label %wait_pending, label %completed_check
        completed_check:
          %completed_offset = mul nuw i64 %completed_index, 128
          %pending_record = getelementptr i8, ptr %pending_table, i64 %completed_offset
          %active = load atomic i64, ptr %pending_record acquire, align 8
          %entry_completed = icmp eq i64 %active, 2
          br i1 %entry_completed, label %claim_completed, label %completed_continue
        completed_continue:
          %completed_next = add nuw i64 %completed_index, 1
          br label %scan_completed
        claim_completed:
          %claim = cmpxchg ptr %pending_record, i64 2, i64 3 acq_rel acquire
          %claimed = extractvalue { i64, i1 } %claim, 1
          br i1 %claimed, label %copy_descriptor, label %completed_continue
        copy_descriptor:
          %application_key_slot = getelementptr i8, ptr %pending_record, i64 8
          %application_key = load i64, ptr %application_key_slot, align 8
          store i64 %application_key, ptr %descriptor, align 8
          %entry_direction_slot = getelementptr i8, ptr %pending_record, i64 24
          %entry_direction = load i32, ptr %entry_direction_slot, align 4
          %descriptor_direction_slot = getelementptr i8, ptr %descriptor, i64 8
          store i32 %entry_direction, ptr %descriptor_direction_slot, align 4
          %entry_buffer_slot = getelementptr i8, ptr %pending_record, i64 32
          %entry_buffer = load ptr, ptr %entry_buffer_slot, align 8
          %descriptor_buffer_slot = getelementptr i8, ptr %descriptor, i64 16
          store ptr %entry_buffer, ptr %descriptor_buffer_slot, align 8
          %entry_length_slot = getelementptr i8, ptr %pending_record, i64 40
          %entry_length = load i64, ptr %entry_length_slot, align 8
          %descriptor_length_slot = getelementptr i8, ptr %descriptor, i64 24
          store i64 %entry_length, ptr %descriptor_length_slot, align 8
          %entry_capacity_slot = getelementptr i8, ptr %pending_record, i64 48
          %entry_capacity = load i64, ptr %entry_capacity_slot, align 8
          %descriptor_capacity_slot = getelementptr i8, ptr %descriptor, i64 32
          store i64 %entry_capacity, ptr %descriptor_capacity_slot, align 8
          %entry_offset_slot = getelementptr i8, ptr %pending_record, i64 56
          %entry_offset = load i64, ptr %entry_offset_slot, align 8
          %descriptor_offset_slot = getelementptr i8, ptr %descriptor, i64 40
          store i64 %entry_offset, ptr %descriptor_offset_slot, align 8
          %entry_requested_slot = getelementptr i8, ptr %pending_record, i64 64
          %entry_requested = load i64, ptr %entry_requested_slot, align 8
          %descriptor_requested_slot = getelementptr i8, ptr %descriptor, i64 48
          store i64 %entry_requested, ptr %descriptor_requested_slot, align 8
          %completion_status_slot = getelementptr i8, ptr %pending_record, i64 116
          %completion_status32 = load i32, ptr %completion_status_slot, align 4
          %completion_status = sext i32 %completion_status32 to i64
          %transferred32_slot = getelementptr i8, ptr %pending_record, i64 120
          %transferred32 = load i32, ptr %transferred32_slot, align 4
          %transferred64 = zext i32 %transferred32 to i64
          %descriptor_transferred_slot = getelementptr i8, ptr %descriptor, i64 56
          store i64 %transferred64, ptr %descriptor_transferred_slot, align 8
          %cancel_requested_slot = getelementptr i8, ptr %pending_record, i64 112
          %cancel_requested = load atomic i32, ptr %cancel_requested_slot acquire, align 4
          %completion_succeeded = icmp eq i64 %completion_status, 0
          %cancel_requested_bool = icmp ne i32 %cancel_requested, 0
          %completion_failed = xor i1 %completion_succeeded, true
          %terminal_cancelled = and i1 %cancel_requested_bool, %completion_failed
          %terminal_state = select i1 %terminal_cancelled, i32 3, i32 2
          %descriptor_state_slot = getelementptr i8, ptr %descriptor, i64 64
          store i32 %terminal_state, ptr %descriptor_state_slot, align 4
          %failed_kind = select i1 %terminal_cancelled, i32 6, i32 8
          %terminal_kind = select i1 %completion_succeeded, i32 -1, i32 %failed_kind
          %descriptor_kind_slot = getelementptr i8, ptr %descriptor, i64 68
          store i32 %terminal_kind, ptr %descriptor_kind_slot, align 4
          %completion_code = trunc i64 %completion_status to i32
          %descriptor_code_slot = getelementptr i8, ptr %descriptor, i64 72
          store i32 %completion_code, ptr %descriptor_code_slot, align 4
          %native_identity = ptrtoint ptr %pending_record to i64
          %descriptor_identity_slot = getelementptr i8, ptr %descriptor, i64 80
          store i64 %native_identity, ptr %descriptor_identity_slot, align 8
          store ptr null, ptr %entry_buffer_slot, align 8
          store atomic i64 0, ptr %pending_record release, align 8
          %success = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %success
        wait_pending:
          %pending_count_slot = getelementptr i8, ptr %state, i64 64
          %pending_count = load atomic i64, ptr %pending_count_slot acquire, align 8
          %has_pending = icmp ne i64 %pending_count, 0
          br i1 %has_pending, label %still_pending, label %not_found
        still_pending:
          %pending_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 -2, i32 0)
          ret %sollang.socket_result %pending_result
        not_found:
          %not_found_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 1, i32 0)
          ret %sollang.socket_result %not_found_result
        wait_cancelled:
          %cancelled_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 6, i32 0)
          ret %sollang.socket_result %cancelled_result
        invalid_argument:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 %identity, i32 1, i32 0)
          ret %sollang.socket_result %invalid_result
        }

        define internal void @sollang_platform_socket_completion_close(i64 %identity) #0 {
        entry:
          %valid = icmp ugt i64 %identity, 0
          br i1 %valid, label %close, label %done
        close:
          %state = inttoptr i64 %identity to ptr
          %port = load ptr, ptr %state, align 8
          %registration_table_slot = getelementptr i8, ptr %state, i64 8
          %registration_table = load ptr, ptr %registration_table_slot, align 8
          %pending_table_slot = getelementptr i8, ptr %state, i64 16
          %pending_table = load ptr, ptr %pending_table_slot, align 8
          %completion_table_slot = getelementptr i8, ptr %state, i64 24
          %completion_table = load ptr, ptr %completion_table_slot, align 8
          %registration_capacity_slot = getelementptr i8, ptr %state, i64 32
          %registration_capacity = load i64, ptr %registration_capacity_slot, align 8
          %pending_capacity_slot = getelementptr i8, ptr %state, i64 40
          %pending_capacity = load i64, ptr %pending_capacity_slot, align 8
          %pending_count_slot = getelementptr i8, ptr %state, i64 64
          %pending_count = load i64, ptr %pending_count_slot, align 8
          br label %cancel_pending_loop
        cancel_pending_loop:
          %cancel_index = phi i64 [ 0, %close ], [ %cancel_next, %cancel_pending_continue ]
          %cancel_done = icmp uge i64 %cancel_index, %pending_capacity
          br i1 %cancel_done, label %wait_pending_loop, label %cancel_pending_check
        cancel_pending_check:
          %cancel_offset = mul nuw i64 %cancel_index, 128
          %cancel_entry = getelementptr i8, ptr %pending_table, i64 %cancel_offset
          %cancel_active = load atomic i64, ptr %cancel_entry acquire, align 8
          %cancel_is_pending = icmp eq i64 %cancel_active, 1
          br i1 %cancel_is_pending, label %cancel_pending_request, label %cancel_pending_continue
        cancel_pending_request:
          %cancel_registration_index_slot = getelementptr i8, ptr %cancel_entry, i64 16
          %cancel_registration_index = load i64, ptr %cancel_registration_index_slot, align 8
          %cancel_registration_offset = mul nuw i64 %cancel_registration_index, 32
          %cancel_registration_entry = getelementptr i8, ptr %registration_table, i64 %cancel_registration_offset
          %cancel_socket_slot = getelementptr i8, ptr %cancel_registration_entry, i64 16
          %cancel_socket = load i64, ptr %cancel_socket_slot, align 8
          %cancel_socket_handle = inttoptr i64 %cancel_socket to ptr
          %cancel_overlapped = getelementptr i8, ptr %cancel_entry, i64 72
          %cancel_requested_slot = getelementptr i8, ptr %cancel_entry, i64 112
          store atomic i32 1, ptr %cancel_requested_slot release, align 4
          %cancelled = call i32 @CancelIoEx(ptr %cancel_socket_handle, ptr %cancel_overlapped)
          %cancel_ok = icmp ne i32 %cancelled, 0
          br i1 %cancel_ok, label %cancel_pending_continue, label %cancel_pending_error
        cancel_pending_error:
          %cancel_error = call i32 @GetLastError()
          %completion_already_won = icmp eq i32 %cancel_error, 1168
          br i1 %completion_already_won, label %cancel_pending_continue, label %close_trap
        cancel_pending_continue:
          %cancel_next = add nuw i64 %cancel_index, 1
          br label %cancel_pending_loop
        wait_pending_loop:
          %remaining_pending = load atomic i64, ptr %pending_count_slot acquire, align 8
          %pending_done = icmp eq i64 %remaining_pending, 0
          br i1 %pending_done, label %stop_waiter, label %wait_pending_signal
        wait_pending_signal:
          call void @sollang_platform_io_wait_completion(i64 -1)
          br label %wait_pending_loop
        stop_waiter:
          %waiting_task_slot = getelementptr i8, ptr %state, i64 88
          %waiting_task = load atomic ptr, ptr %waiting_task_slot acquire, align 8
          %waiting_task_clear = icmp eq ptr %waiting_task, null
          br i1 %waiting_task_clear, label %stop_waiter_ready, label %close_trap
        stop_waiter_ready:
          %stopping_slot = getelementptr i8, ptr %state, i64 80
          store atomic i32 1, ptr %stopping_slot release, align 4
          %waiter_slot = getelementptr i8, ptr %state, i64 72
          %waiter = load ptr, ptr %waiter_slot, align 8
          %has_waiter = icmp ne ptr %waiter, null
          br i1 %has_waiter, label %wake_waiter_stop, label %release_pending_loop
        wake_waiter_stop:
          %posted = call i32 @PostQueuedCompletionStatus(ptr %port, i32 0, i64 0, ptr null)
          %post_ok = icmp ne i32 %posted, 0
          br i1 %post_ok, label %join_waiter, label %close_trap
        join_waiter:
          %joined = call i32 @WaitForSingleObject(ptr %waiter, i32 -1)
          %join_ok = icmp eq i32 %joined, 0
          br i1 %join_ok, label %close_waiter_handle, label %close_trap
        close_waiter_handle:
          %waiter_closed = call i32 @CloseHandle(ptr %waiter)
          store ptr null, ptr %waiter_slot, align 8
          br label %release_pending_loop
        release_pending_loop:
          %release_index = phi i64 [ 0, %stop_waiter_ready ], [ 0, %close_waiter_handle ], [ %released_next, %clear_pending_entry ], [ %skipped_next, %release_pending_continue ]
          %release_done = icmp uge i64 %release_index, %pending_capacity
          br i1 %release_done, label %pending_drained, label %release_pending_check
        release_pending_check:
          %release_offset = mul nuw i64 %release_index, 128
          %completed_entry = getelementptr i8, ptr %pending_table, i64 %release_offset
          %completed_active = load atomic i64, ptr %completed_entry acquire, align 8
          %completed_is_free = icmp eq i64 %completed_active, 0
          br i1 %completed_is_free, label %release_pending_continue, label %drop_pending_owner
        drop_pending_owner:
          %completed_is_terminal = icmp eq i64 %completed_active, 2
          br i1 %completed_is_terminal, label %inspect_pending_owner, label %close_trap
        inspect_pending_owner:
          %completed_buffer_slot = getelementptr i8, ptr %completed_entry, i64 32
          %completed_buffer = load ptr, ptr %completed_buffer_slot, align 8
          %completed_has_buffer = icmp ne ptr %completed_buffer, null
          br i1 %completed_has_buffer, label %free_pending_buffer, label %clear_pending_entry
        free_pending_buffer:
          call void @sollang_free(ptr %completed_buffer)
          br label %clear_pending_entry
        clear_pending_entry:
          store ptr null, ptr %completed_buffer_slot, align 8
          store atomic i64 0, ptr %completed_entry release, align 8
          %released_next = add nuw i64 %release_index, 1
          br label %release_pending_loop
        release_pending_continue:
          %skipped_next = add nuw i64 %release_index, 1
          br label %release_pending_loop
        pending_drained:
          store i64 0, ptr %pending_count_slot, align 8
          br label %close_registration_loop
        close_registration_loop:
          %registration_index = phi i64 [ 0, %pending_drained ], [ %registration_next, %close_registration_continue ]
          %registrations_done = icmp uge i64 %registration_index, %registration_capacity
          br i1 %registrations_done, label %close_handles, label %close_registration
        close_registration:
          %registration_offset = mul nuw i64 %registration_index, 32
          %registration_entry = getelementptr i8, ptr %registration_table, i64 %registration_offset
          %registration_active = load i64, ptr %registration_entry, align 8
          %registration_is_active = icmp ne i64 %registration_active, 0
          br i1 %registration_is_active, label %close_registered_socket, label %close_registration_continue
        close_registered_socket:
          %registered_socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %registered_socket = load i64, ptr %registered_socket_slot, align 8
          %registered_socket_closed = call i32 @closesocket(i64 %registered_socket)
          store i64 0, ptr %registration_entry, align 8
          br label %close_registration_continue
        close_registration_continue:
          %registration_next = add nuw i64 %registration_index, 1
          br label %close_registration_loop
        close_handles:
          %closed = call i32 @CloseHandle(ptr %port)
          call void @sollang_free(ptr %completion_table)
          call void @sollang_free(ptr %pending_table)
          call void @sollang_free(ptr %registration_table)
          call void @sollang_free(ptr %state)
          br label %done
        close_trap:
          call void @llvm.trap()
          unreachable
        done:
          ret void
        }
        """;
}
