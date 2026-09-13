using System.Text;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LinuxLlvmRuntimePlatform
{
    public override void EmitSocketPrimitives(StringBuilder functions)
    {
        functions.AppendLine("declare i32 @socket(i32, i32, i32)");
        functions.AppendLine("declare i32 @bind(i32, ptr, i32)");
        functions.AppendLine("declare i32 @getsockname(i32, ptr, ptr)");
        functions.AppendLine("declare i32 @getpeername(i32, ptr, ptr)");
        functions.AppendLine("declare i32 @listen(i32, i32)");
        functions.AppendLine("declare i32 @accept4(i32, ptr, ptr, i32)");
        functions.AppendLine("declare i32 @connect(i32, ptr, i32)");
        functions.AppendLine("declare i64 @recv(i32, ptr, i64, i32)");
        functions.AppendLine("declare i64 @send(i32, ptr, i64, i32)");
        functions.AppendLine("declare i64 @recvmsg(i32, ptr, i32)");
        functions.AppendLine("declare i64 @sendmsg(i32, ptr, i32)");
        functions.AppendLine("declare i64 @recvfrom(i32, ptr, i64, i32, ptr, ptr)");
        functions.AppendLine("declare i64 @sendto(i32, ptr, i64, i32, ptr, i32)");
        functions.AppendLine("declare i32 @shutdown(i32, i32)");
        functions.AppendLine("declare i32 @setsockopt(i32, i32, i32, ptr, i32)");
        functions.AppendLine("declare i32 @getsockopt(i32, i32, i32, ptr, ptr)");
        functions.AppendLine("declare i32 @fcntl(i32, i32, ...)");
        functions.AppendLine("declare i32 @poll(ptr, i64, i32)");
        if (UsesSocketCompletion)
        {
            functions.AppendLine("declare i32 @epoll_create1(i32)");
            functions.AppendLine("declare i32 @epoll_ctl(i32, i32, i32, ptr)");
            functions.AppendLine("declare i32 @epoll_wait(i32, ptr, i32, i32)");
        }
        functions.AppendLine("declare i32 @getaddrinfo(ptr, ptr, ptr, ptr)");
        functions.AppendLine("declare void @freeaddrinfo(ptr)");
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

        define internal i32 @sollang_socket_errno() #0 {
        entry:
          %address = call ptr @__errno_location()
          %code = load i32, ptr %address, align 4
          ret i32 %code
        }

        define internal i32 @sollang_socket_error_kind(i32 %code) #0 {
        entry:
          switch i32 %code, label %other [
            i32 22, label %invalid_argument
            i32 98, label %address_in_use
            i32 111, label %connection_refused
            i32 104, label %connection_reset
            i32 110, label %timed_out
            i32 4, label %interrupted
            i32 11, label %would_block
            i32 97, label %unsupported
            i32 95, label %unsupported
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
          %descriptor = trunc i64 %socket to i32
          %clone32 = call i32 @dup(i32 %descriptor)
          %failed = icmp slt i32 %clone32, 0
          br i1 %failed, label %failure, label %success

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        success:
          %clone = sext i32 %clone32 to i64
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %clone, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal i16 @sollang_socket_network_port(i16 %port) #0 {
        entry:
          %low = shl i16 %port, 8
          %high = lshr i16 %port, 8
          %network = or i16 %low, %high
          ret i16 %network
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_nonblocking(i64 %socket, i1 %enabled) #0 {
        entry:
          %descriptor = trunc i64 %socket to i32
          %flags = call i32 (i32, i32, ...) @fcntl(i32 %descriptor, i32 3)
          %get_failed = icmp slt i32 %flags, 0
          br i1 %get_failed, label %failure, label %select_flags

        select_flags:
          %with_nonblocking = or i32 %flags, 2048
          %without_nonblocking = and i32 %flags, -2049
          %next_flags = select i1 %enabled, i32 %with_nonblocking, i32 %without_nonblocking
          %status = call i32 (i32, i32, ...) @fcntl(i32 %descriptor, i32 4, i32 %next_flags)
          %set_failed = icmp slt i32 %status, 0
          br i1 %set_failed, label %failure, label %success

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        success:
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_poll(i64 %socket, i32 %mode, i1 %has_timeout, i64 %milliseconds) #0 {
        entry:
          %descriptor = alloca { i32, i16, i16 }, align 4
          %fd = getelementptr inbounds { i32, i16, i16 }, ptr %descriptor, i32 0, i32 0
          %events = getelementptr inbounds { i32, i16, i16 }, ptr %descriptor, i32 0, i32 1
          %revents = getelementptr inbounds { i32, i16, i16 }, ptr %descriptor, i32 0, i32 2
          %socket32 = trunc i64 %socket to i32
          store i32 %socket32, ptr %fd, align 4
          %is_read = icmp eq i32 %mode, 0
          %requested = select i1 %is_read, i16 1, i16 4
          %is_error = icmp eq i32 %mode, 2
          %event_mask = select i1 %is_error, i16 0, i16 %requested
          store i16 %event_mask, ptr %events, align 2
          store i16 0, ptr %revents, align 2
          %timeout_overflow = icmp sgt i64 %milliseconds, 2147483647
          %bounded_timeout = select i1 %timeout_overflow, i64 2147483647, i64 %milliseconds
          %timeout32 = trunc i64 %bounded_timeout to i32
          %timeout = select i1 %has_timeout, i32 %timeout32, i32 -1
          %status = call i32 @poll(ptr %descriptor, i64 1, i32 %timeout)
          %failed = icmp slt i32 %status, 0
          br i1 %failed, label %failure, label %success

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        success:
          %returned = load i16, ptr %revents, align 2
          %normal_mask = or i16 %event_mask, 56
          %selected_mask = select i1 %is_error, i16 56, i16 %normal_mask
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
          %descriptors = alloca { i32, i16, i16 }, i64 %interest_count, align 4
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
          %handle64 = load i64, ptr %owner, align 8
          %handle = trunc i64 %handle64 to i32
          %mode_address = getelementptr i8, ptr %interest, i64 %mode_offset
          %mode = load i32, ptr %mode_address, align 4
          %mode_valid = icmp ule i32 %mode, 2
          br i1 %mode_valid, label %store_descriptor, label %invalid_argument

        store_descriptor:
          %descriptor = getelementptr { i32, i16, i16 }, ptr %descriptors, i64 %index
          %descriptor_fd = getelementptr { i32, i16, i16 }, ptr %descriptor, i32 0, i32 0
          %descriptor_events = getelementptr { i32, i16, i16 }, ptr %descriptor, i32 0, i32 1
          %descriptor_revents = getelementptr { i32, i16, i16 }, ptr %descriptor, i32 0, i32 2
          %wants_read = icmp ne i32 %mode, 1
          %wants_write = icmp ne i32 %mode, 0
          %read_mask = select i1 %wants_read, i16 1, i16 0
          %write_mask = select i1 %wants_write, i16 4, i16 0
          %requested = or i16 %read_mask, %write_mask
          store i32 %handle, ptr %descriptor_fd, align 4
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
          %status = call i32 @poll(ptr %descriptors, i64 %interest_count, i32 %timeout)
          %failed = icmp slt i32 %status, 0
          br i1 %failed, label %failure, label %scan_prepare

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failure_result

        scan_prepare:
          %output_count_address = alloca i64, align 8
          store i64 0, ptr %output_count_address, align 8
          br label %scan

        scan:
          %scan_index = phi i64 [ 0, %scan_prepare ], [ %scan_next, %advance ]
          %scan_descriptor = getelementptr { i32, i16, i16 }, ptr %descriptors, i64 %scan_index
          %scan_events_address = getelementptr { i32, i16, i16 }, ptr %scan_descriptor, i32 0, i32 1
          %scan_revents_address = getelementptr { i32, i16, i16 }, ptr %scan_descriptor, i32 0, i32 2
          %scan_events = load i16, ptr %scan_events_address, align 2
          %scan_revents = load i16, ptr %scan_revents_address, align 2
          %read_interest_bits = and i16 %scan_events, 1
          %read_interested = icmp ne i16 %read_interest_bits, 0
          %read_ready_bits = and i16 %scan_revents, 17
          %read_ready_raw = icmp ne i16 %read_ready_bits, 0
          %readable = and i1 %read_interested, %read_ready_raw
          %write_interest_bits = and i16 %scan_events, 4
          %write_interested = icmp ne i16 %write_interest_bits, 0
          %write_ready_bits = and i16 %scan_revents, 4
          %write_ready_raw = icmp ne i16 %write_ready_bits, 0
          %writable = and i1 %write_interested, %write_ready_raw
          %error_bits = and i16 %scan_revents, 56
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
          store i16 10, ptr %storage, align 2
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
          ret i32 10

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
            i32 10, label %ipv6
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
          %socket = call i32 @socket(i32 %family, i32 524289, i32 6)
          %created = icmp sge i32 %socket, 0
          br i1 %created, label %configure, label %create_failed

        configure:
          br i1 %reuse, label %set_reuse, label %bind_socket

        set_reuse:
          %reuse_value = alloca i32, align 4
          store i32 1, ptr %reuse_value, align 4
          %reuse_status = call i32 @setsockopt(i32 %socket, i32 1, i32 2, ptr %reuse_value, i32 4)
          %reuse_ok = icmp eq i32 %reuse_status, 0
          br i1 %reuse_ok, label %bind_socket, label %socket_failed

        bind_socket:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %bind_status = call i32 @bind(i32 %socket, ptr %socket_address, i32 %address_size)
          %bind_ok = icmp eq i32 %bind_status, 0
          br i1 %bind_ok, label %listen_socket, label %socket_failed

        listen_socket:
          %backlog32 = trunc i64 %backlog to i32
          %listen_status = call i32 @listen(i32 %socket, i32 %backlog32)
          %listen_ok = icmp eq i32 %listen_status, 0
          br i1 %listen_ok, label %success, label %socket_failed

        socket_failed:
          %socket_error = call i32 @sollang_socket_errno()
          %close_failed_socket = call i32 @close(i32 %socket)
          %socket_kind = call i32 @sollang_socket_error_kind(i32 %socket_error)
          %socket_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %socket_kind, i32 %socket_error)
          ret %sollang.socket_result %socket_result

        create_failed:
          %create_error = call i32 @sollang_socket_errno()
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
          %socket64 = sext i32 %socket to i64
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket64, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_connect(ptr %endpoint) #0 {
        entry:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
          %address_valid = icmp ne i32 %family, 0
          br i1 %address_valid, label %create, label %invalid_address

        create:
          %socket = call i32 @socket(i32 %family, i32 524289, i32 6)
          %created = icmp sge i32 %socket, 0
          br i1 %created, label %connect_socket, label %create_failed

        connect_socket:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %connect_status = call i32 @connect(i32 %socket, ptr %socket_address, i32 %address_size)
          %connect_ok = icmp eq i32 %connect_status, 0
          br i1 %connect_ok, label %success, label %connect_failed

        connect_failed:
          %connect_error = call i32 @sollang_socket_errno()
          %close_failed_socket = call i32 @close(i32 %socket)
          %connect_kind = call i32 @sollang_socket_error_kind(i32 %connect_error)
          %connect_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %connect_kind, i32 %connect_error)
          ret %sollang.socket_result %connect_result

        create_failed:
          %create_error = call i32 @sollang_socket_errno()
          %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
          %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
          ret %sollang.socket_result %create_result

        invalid_address:
          %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %address_result

        success:
          %socket64 = sext i32 %socket to i64
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket64, i32 -1, i32 0)
          ret %sollang.socket_result %success_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_accept(i64 %listener) #0 {
        entry:
          %listener32 = trunc i64 %listener to i32
          %socket = call i32 @accept4(i32 %listener32, ptr null, ptr null, i32 524288)
          %accepted = icmp sge i32 %socket, 0
          br i1 %accepted, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %socket64 = sext i32 %socket to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %socket64, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_receive(i64 %socket, ptr %buffer, i64 %capacity, i32 %flags) #0 {
        entry:
          %positive = icmp ugt i64 %capacity, 0
          %fits = icmp ule i64 %capacity, 2147483647
          %valid = and i1 %positive, %fits
          br i1 %valid, label %receive, label %invalid_argument

        receive:
          %socket32 = trunc i64 %socket to i32
          %count = call i64 @recv(i32 %socket32, ptr %buffer, i64 %capacity, i32 %flags)
          %ok = icmp sge i64 %count, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success:
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
          %socket32 = trunc i64 %socket to i32
          %count = call i64 @send(i32 %socket32, ptr %buffer, i64 %length, i32 16384)
          %ok = icmp sge i64 %count, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid

        success:
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
          %native_buffers = alloca { ptr, i64 }, i64 %buffer_count, align 8
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
          br i1 %length_valid, label %store_buffer, label %invalid_argument

        store_buffer:
          %start = getelementptr i8, ptr %data, i64 %range_offset
          %native_buffer = getelementptr { ptr, i64 }, ptr %native_buffers, i64 %index
          %native_data = getelementptr { ptr, i64 }, ptr %native_buffer, i32 0, i32 0
          %native_length = getelementptr { ptr, i64 }, ptr %native_buffer, i32 0, i32 1
          store ptr %start, ptr %native_data, align 8
          store i64 %range_length, ptr %native_length, align 8
          %next = add i64 %index, 1
          %done = icmp eq i64 %next, %buffer_count
          br i1 %done, label %send_buffers, label %build

        send_buffers:
          %message = alloca { ptr, i32, ptr, i64, ptr, i64, i32 }, align 8
          %message_name = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 0
          %message_name_length = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 1
          %message_buffers = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 2
          %message_buffer_count = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 3
          %message_control = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 4
          %message_control_length = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 5
          %message_flags = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 6
          store ptr null, ptr %message_name, align 8
          store i32 0, ptr %message_name_length, align 4
          store ptr %native_buffers, ptr %message_buffers, align 8
          store i64 %buffer_count, ptr %message_buffer_count, align 8
          store ptr null, ptr %message_control, align 8
          store i64 0, ptr %message_control_length, align 8
          store i32 0, ptr %message_flags, align 4
          %socket32 = trunc i64 %socket to i32
          %sent = call i64 @sendmsg(i32 %socket32, ptr %message, i32 16384)
          %ok = icmp sge i64 %sent, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
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
          %native_buffers = alloca { ptr, i64 }, i64 %buffer_count, align 8
          br label %build

        build:
          %index = phi i64 [ 0, %prepare ], [ %next, %store_buffer ]
          %descriptor_offset = mul i64 %index, %stride
          %descriptor = getelementptr i8, ptr %buffers, i64 %descriptor_offset
          %bytes = getelementptr i8, ptr %descriptor, i64 %bytes_field_offset
          %data = load ptr, ptr %bytes, align 8
          %capacity_address = getelementptr i8, ptr %bytes, i64 16
          %capacity = load i64, ptr %capacity_address, align 8
          %native_buffer = getelementptr { ptr, i64 }, ptr %native_buffers, i64 %index
          %native_data = getelementptr { ptr, i64 }, ptr %native_buffer, i32 0, i32 0
          %native_length = getelementptr { ptr, i64 }, ptr %native_buffer, i32 0, i32 1
          br label %store_buffer

        store_buffer:
          store ptr %data, ptr %native_data, align 8
          store i64 %capacity, ptr %native_length, align 8
          %next = add i64 %index, 1
          %done = icmp eq i64 %next, %buffer_count
          br i1 %done, label %receive_buffers, label %build

        receive_buffers:
          %message = alloca { ptr, i32, ptr, i64, ptr, i64, i32 }, align 8
          %message_name = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 0
          %message_name_length = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 1
          %message_buffers = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 2
          %message_buffer_count = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 3
          %message_control = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 4
          %message_control_length = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 5
          %message_flags = getelementptr { ptr, i32, ptr, i64, ptr, i64, i32 }, ptr %message, i32 0, i32 6
          store ptr null, ptr %message_name, align 8
          store i32 0, ptr %message_name_length, align 4
          store ptr %native_buffers, ptr %message_buffers, align 8
          store i64 %buffer_count, ptr %message_buffer_count, align 8
          store ptr null, ptr %message_control, align 8
          store i64 0, ptr %message_control_length, align 8
          store i32 0, ptr %message_flags, align 4
          %socket32 = trunc i64 %socket to i32
          %received = call i64 @recvmsg(i32 %socket32, ptr %message, i32 0)
          %ok = icmp sge i64 %received, 0
          br i1 %ok, label %publish_prepare, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        publish_prepare:
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
          %socket32 = trunc i64 %socket to i32
          %status = call i32 @shutdown(i32 %socket32, i32 %direction)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_no_delay(i64 %socket, i1 %enabled) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %value = alloca i32, align 4
          %value32 = zext i1 %enabled to i32
          store i32 %value32, ptr %value, align 4
          %status = call i32 @setsockopt(i32 %socket32, i32 6, i32 1, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_no_delay(i64 %socket) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %value = alloca i32, align 4
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 4
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i32 %socket32, i32 6, i32 1, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
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
          %socket32 = trunc i64 %socket to i32
          %value = alloca i32, align 4
          %value32 = zext i1 %enabled to i32
          store i32 %value32, ptr %value, align 4
          %status = call i32 @setsockopt(i32 %socket32, i32 1, i32 9, ptr %value, i32 4)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_keep_alive(i64 %socket) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %value = alloca i32, align 4
          %length = alloca i32, align 4
          store i32 0, ptr %value, align 4
          store i32 4, ptr %length, align 4
          %status = call i32 @getsockopt(i32 %socket32, i32 1, i32 9, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
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
          %fits = icmp ule i64 %checked_millis, 2147483647000
          %duration_valid = and i1 %positive, %fits
          %disabled = xor i1 %enabled, true
          %valid = or i1 %disabled, %duration_valid
          br i1 %valid, label %configure, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 22)
          ret %sollang.socket_result %invalid

        configure:
          %socket32 = trunc i64 %socket to i32
          %value = alloca [2 x i32], align 4
          %onoff = zext i1 %enabled to i32
          %rounded = add i64 %checked_millis, 999
          %seconds64 = udiv i64 %rounded, 1000
          %seconds = trunc i64 %seconds64 to i32
          %onoff_address = getelementptr inbounds [2 x i32], ptr %value, i32 0, i32 0
          %seconds_address = getelementptr inbounds [2 x i32], ptr %value, i32 0, i32 1
          store i32 %onoff, ptr %onoff_address, align 4
          store i32 %seconds, ptr %seconds_address, align 4
          %status = call i32 @setsockopt(i32 %socket32, i32 1, i32 13, ptr %value, i32 8)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_linger(i64 %socket) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %value = alloca [2 x i32], align 4
          %length = alloca i32, align 4
          store i64 0, ptr %value, align 4
          store i32 8, ptr %length, align 4
          %status = call i32 @getsockopt(i32 %socket32, i32 1, i32 13, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %decode, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        decode:
          %onoff_address = getelementptr inbounds [2 x i32], ptr %value, i32 0, i32 0
          %seconds_address = getelementptr inbounds [2 x i32], ptr %value, i32 0, i32 1
          %onoff = load i32, ptr %onoff_address, align 4
          %seconds = load i32, ptr %seconds_address, align 4
          %enabled = icmp ne i32 %onoff, 0
          %seconds64 = zext i32 %seconds to i64
          %millis = mul i64 %seconds64, 1000
          %selected = select i1 %enabled, i64 %millis, i64 -1
          %result = call %sollang.socket_result @sollang_socket_result(i64 %selected, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_read_timeout(i64 %socket, i1 %has_timeout, i64 %millis) #0 {
        entry:
          %positive = icmp sgt i64 %millis, 0
          %disabled = xor i1 %has_timeout, true
          %valid = or i1 %disabled, %positive
          br i1 %valid, label %configure, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 22)
          ret %sollang.socket_result %invalid

        configure:
          %socket32 = trunc i64 %socket to i32
          %value = alloca [2 x i64], align 8
          %seconds = udiv i64 %millis, 1000
          %remainder = urem i64 %millis, 1000
          %microseconds = mul i64 %remainder, 1000
          %selected_seconds = select i1 %has_timeout, i64 %seconds, i64 0
          %selected_microseconds = select i1 %has_timeout, i64 %microseconds, i64 0
          %seconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 0
          %microseconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 1
          store i64 %selected_seconds, ptr %seconds_address, align 8
          store i64 %selected_microseconds, ptr %microseconds_address, align 8
          %status = call i32 @setsockopt(i32 %socket32, i32 1, i32 20, ptr %value, i32 16)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_read_timeout(i64 %socket) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %value = alloca [2 x i64], align 8
          %length = alloca i32, align 4
          call void @llvm.memset.p0.i64(ptr %value, i8 0, i64 16, i1 false)
          store i32 16, ptr %length, align 4
          %status = call i32 @getsockopt(i32 %socket32, i32 1, i32 20, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %decode, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        decode:
          %seconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 0
          %microseconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 1
          %seconds = load i64, ptr %seconds_address, align 8
          %microseconds = load i64, ptr %microseconds_address, align 8
          %seconds_valid = icmp ule i64 %seconds, 9223372036854775
          %microseconds_valid = icmp ult i64 %microseconds, 1000000
          %valid = and i1 %seconds_valid, %microseconds_valid
          br i1 %valid, label %success, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 22)
          ret %sollang.socket_result %invalid

        success:
          %rounded_numerator = add i64 %microseconds, 999
          %rounded_millis = udiv i64 %rounded_numerator, 1000
          %base_millis = mul i64 %seconds, 1000
          %remaining = sub i64 9223372036854775807, %base_millis
          %rounded_fits = icmp ule i64 %rounded_millis, %remaining
          br i1 %rounded_fits, label %publish, label %invalid_argument

        publish:
          %millis = add i64 %base_millis, %rounded_millis
          %disabled_seconds = icmp eq i64 %seconds, 0
          %disabled_microseconds = icmp eq i64 %microseconds, 0
          %disabled = and i1 %disabled_seconds, %disabled_microseconds
          %timeout = select i1 %disabled, i64 -1, i64 %millis
          %result = call %sollang.socket_result @sollang_socket_result(i64 %timeout, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_set_write_timeout(i64 %socket, i1 %has_timeout, i64 %millis) #0 {
        entry:
          %positive = icmp sgt i64 %millis, 0
          %disabled = xor i1 %has_timeout, true
          %valid = or i1 %disabled, %positive
          br i1 %valid, label %configure, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 22)
          ret %sollang.socket_result %invalid

        configure:
          %socket32 = trunc i64 %socket to i32
          %value = alloca [2 x i64], align 8
          %seconds = udiv i64 %millis, 1000
          %remainder = urem i64 %millis, 1000
          %microseconds = mul i64 %remainder, 1000
          %selected_seconds = select i1 %has_timeout, i64 %seconds, i64 0
          %selected_microseconds = select i1 %has_timeout, i64 %microseconds, i64 0
          %seconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 0
          %microseconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 1
          store i64 %selected_seconds, ptr %seconds_address, align 8
          store i64 %selected_microseconds, ptr %microseconds_address, align 8
          %status = call i32 @setsockopt(i32 %socket32, i32 1, i32 21, ptr %value, i32 16)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        success:
          %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_write_timeout(i64 %socket) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %value = alloca [2 x i64], align 8
          %length = alloca i32, align 4
          call void @llvm.memset.p0.i64(ptr %value, i8 0, i64 16, i1 false)
          store i32 16, ptr %length, align 4
          %status = call i32 @getsockopt(i32 %socket32, i32 1, i32 21, ptr %value, ptr %length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %decode, label %failure

        failure:
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed

        decode:
          %seconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 0
          %microseconds_address = getelementptr inbounds [2 x i64], ptr %value, i32 0, i32 1
          %seconds = load i64, ptr %seconds_address, align 8
          %microseconds = load i64, ptr %microseconds_address, align 8
          %seconds_valid = icmp ule i64 %seconds, 9223372036854775
          %microseconds_valid = icmp ult i64 %microseconds, 1000000
          %valid = and i1 %seconds_valid, %microseconds_valid
          br i1 %valid, label %success, label %invalid_argument

        invalid_argument:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 22)
          ret %sollang.socket_result %invalid

        success:
          %rounded_numerator = add i64 %microseconds, 999
          %rounded_millis = udiv i64 %rounded_numerator, 1000
          %base_millis = mul i64 %seconds, 1000
          %remaining = sub i64 9223372036854775807, %base_millis
          %rounded_fits = icmp ule i64 %rounded_millis, %remaining
          br i1 %rounded_fits, label %publish, label %invalid_argument

        publish:
          %millis = add i64 %base_millis, %rounded_millis
          %disabled_seconds = icmp eq i64 %seconds, 0
          %disabled_microseconds = icmp eq i64 %microseconds, 0
          %disabled = and i1 %disabled_seconds, %disabled_microseconds
          %timeout = select i1 %disabled, i64 -1, i64 %millis
          %result = call %sollang.socket_result @sollang_socket_result(i64 %timeout, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_bind_datagram(ptr %endpoint, i1 %reuse) #0 {
        entry:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
          %valid = icmp ne i32 %family, 0
          br i1 %valid, label %create, label %invalid_address
        create:
          %socket = call i32 @socket(i32 %family, i32 524290, i32 17)
          %created = icmp sge i32 %socket, 0
          br i1 %created, label %configure, label %create_failed
        configure:
          br i1 %reuse, label %set_reuse, label %bind_socket
        set_reuse:
          %reuse_value = alloca i32, align 4
          store i32 1, ptr %reuse_value, align 4
          %reuse_status = call i32 @setsockopt(i32 %socket, i32 1, i32 2, ptr %reuse_value, i32 4)
          %reuse_ok = icmp eq i32 %reuse_status, 0
          br i1 %reuse_ok, label %bind_socket, label %socket_failed
        bind_socket:
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %bind_status = call i32 @bind(i32 %socket, ptr %socket_address, i32 %address_size)
          %bind_ok = icmp eq i32 %bind_status, 0
          br i1 %bind_ok, label %success, label %socket_failed
        socket_failed:
          %socket_error = call i32 @sollang_socket_errno()
          %ignored_close = call i32 @close(i32 %socket)
          %socket_kind = call i32 @sollang_socket_error_kind(i32 %socket_error)
          %socket_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %socket_kind, i32 %socket_error)
          ret %sollang.socket_result %socket_result
        create_failed:
          %create_error = call i32 @sollang_socket_errno()
          %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
          %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
          ret %sollang.socket_result %create_result
        invalid_address:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %invalid_result
        success:
          %handle = sext i32 %socket to i64
          %success_result = call %sollang.socket_result @sollang_socket_result(i64 %handle, i32 -1, i32 0)
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
          %socket32 = trunc i64 %socket to i32
          %is_ipv4 = icmp eq i32 %family, 2
          %address_size = select i1 %is_ipv4, i32 16, i32 28
          %count = call i64 @sendto(i32 %socket32, ptr %buffer, i64 %length, i32 16384, ptr %socket_address, i32 %address_size)
          %ok = icmp sge i64 %count, 0
          br i1 %ok, label %success, label %failure
        failure:
          %error = call i32 @sollang_socket_errno()
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
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        }

        define internal %sollang.socket_result @sollang_platform_socket_local_port(i64 %socket) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %address = alloca [28 x i8], align 8
          %address_length = alloca i32, align 4
          store i32 28, ptr %address_length, align 4
          %status = call i32 @getsockname(i32 %socket32, ptr %address, ptr %address_length)
          %ok = icmp eq i32 %status, 0
          br i1 %ok, label %success, label %failure
        failure:
          %error = call i32 @sollang_socket_errno()
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
          %socket32 = trunc i64 %socket to i32
          %address = alloca [28 x i8], align 8
          %address_length = alloca i32, align 4
          store i32 28, ptr %address_length, align 4
          %status = call i32 @getsockname(i32 %socket32, ptr %address, ptr %address_length)
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
          %error = call i32 @sollang_socket_errno()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
        invalid_address:
          %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
          ret %sollang.socket_result %invalid
        }

        define internal %sollang.socket_result @sollang_platform_socket_remote_endpoint(i64 %socket, ptr %endpoint) #0 {
        entry:
          %socket32 = trunc i64 %socket to i32
          %address = alloca [28 x i8], align 8
          %address_length = alloca i32, align 4
          store i32 28, ptr %address_length, align 4
          %status = call i32 @getpeername(i32 %socket32, ptr %address, ptr %address_length)
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
          %error = call i32 @sollang_socket_errno()
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
          %socket32 = trunc i64 %socket to i32
          %source = alloca [28 x i8], align 8
          %source_length = alloca i32, align 4
          store i32 28, ptr %source_length, align 4
          %receive_flags = or i32 %flags, 32
          %actual_count = call i64 @recvfrom(i32 %socket32, ptr %buffer, i64 %capacity, i32 %receive_flags, ptr %source, ptr %source_length)
          %ok = icmp sge i64 %actual_count, 0
          br i1 %ok, label %pack, label %failure
        pack:
          %was_truncated = icmp ugt i64 %actual_count, %capacity
          %truncated8 = zext i1 %was_truncated to i8
          store i8 %truncated8, ptr %truncated, align 1
          %count = select i1 %was_truncated, i64 %capacity, i64 %actual_count
          %family = call i32 @sollang_socket_endpoint(ptr %source, ptr %endpoint)
          %packed = icmp ne i32 %family, 0
          br i1 %packed, label %publish, label %invalid_address
        publish:
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        failure:
          %error = call i32 @sollang_socket_errno()
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
          %valid = icmp sge i64 %socket, 0
          br i1 %valid, label %close_socket, label %done

        close_socket:
          %socket32 = trunc i64 %socket to i32
          %ignored = call i32 @close(i32 %socket32)
          br label %done

        done:
          ret void
        }

        """;

    private const string CompletionRuntime = """
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
          br i1 %valid, label %create_epoll, label %invalid
        create_epoll:
          %epoll = call i32 @epoll_create1(i32 524288)
          %epoll_ok = icmp sge i32 %epoll, 0
          br i1 %epoll_ok, label %create_wakeup, label %epoll_failed
        create_wakeup:
          %wakeup = call i32 @eventfd(i32 0, i32 526336)
          %wakeup_ok = icmp sge i32 %wakeup, 0
          br i1 %wakeup_ok, label %register_wakeup, label %wakeup_failed
        register_wakeup:
          %wakeup_event = alloca [12 x i8], align 4
          store i32 1, ptr %wakeup_event, align 4
          %wakeup_data = getelementptr i8, ptr %wakeup_event, i64 4
          store i64 0, ptr %wakeup_data, align 1
          %wakeup_registered = call i32 @epoll_ctl(i32 %epoll, i32 1, i32 %wakeup, ptr %wakeup_event)
          %wakeup_registration_ok = icmp eq i32 %wakeup_registered, 0
          br i1 %wakeup_registration_ok, label %allocate_state, label %wakeup_registration_failed
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
          %epoll64 = sext i32 %epoll to i64
          store i64 %epoll64, ptr %state, align 8
          %wakeup_slot = getelementptr i8, ptr %state, i64 8
          %wakeup64 = sext i32 %wakeup to i64
          store i64 %wakeup64, ptr %wakeup_slot, align 8
          %registration_table_slot = getelementptr i8, ptr %state, i64 16
          store ptr %registration_table, ptr %registration_table_slot, align 8
          %pending_table_slot = getelementptr i8, ptr %state, i64 24
          store ptr %pending_table, ptr %pending_table_slot, align 8
          %completion_table_slot = getelementptr i8, ptr %state, i64 32
          store ptr %completion_table, ptr %completion_table_slot, align 8
          %registrations_slot = getelementptr i8, ptr %state, i64 40
          store i64 %registrations, ptr %registrations_slot, align 8
          %pending_slot = getelementptr i8, ptr %state, i64 48
          store i64 %pending, ptr %pending_slot, align 8
          %batch_slot = getelementptr i8, ptr %state, i64 56
          store i64 %batch, ptr %batch_slot, align 8
          %registration_count = getelementptr i8, ptr %state, i64 64
          store i64 0, ptr %registration_count, align 8
          %pending_count = getelementptr i8, ptr %state, i64 72
          store i64 0, ptr %pending_count, align 8
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
          %state_close_wakeup = call i32 @close(i32 %wakeup)
          %state_close_epoll = call i32 @close(i32 %epoll)
          %allocation_error = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 8, i32 12)
          ret %sollang.socket_result %allocation_error
        wakeup_registration_failed:
          %registration_error = call i32 @sollang_socket_errno()
          %registration_kind = call i32 @sollang_socket_error_kind(i32 %registration_error)
          %registration_close_wakeup = call i32 @close(i32 %wakeup)
          %registration_close_epoll = call i32 @close(i32 %epoll)
          %registration_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %registration_kind, i32 %registration_error)
          ret %sollang.socket_result %registration_result
        wakeup_failed:
          %wakeup_error = call i32 @sollang_socket_errno()
          %wakeup_kind = call i32 @sollang_socket_error_kind(i32 %wakeup_error)
          %wakeup_close_epoll = call i32 @close(i32 %epoll)
          %wakeup_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %wakeup_kind, i32 %wakeup_error)
          ret %sollang.socket_result %wakeup_result
        epoll_failed:
          %epoll_error = call i32 @sollang_socket_errno()
          %epoll_kind = call i32 @sollang_socket_error_kind(i32 %epoll_error)
          %epoll_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %epoll_kind, i32 %epoll_error)
          ret %sollang.socket_result %epoll_result
        invalid:
          %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
          ret %sollang.socket_result %invalid_result
        }

        define internal %sollang.socket_result @sollang_platform_socket_completion_register_stream(i64 %identity, i64 %socket, i64 %key) #0 {
        entry:
          %identity_ok = icmp ugt i64 %identity, 0
          %socket_ok = icmp sge i64 %socket, 0
          %valid = and i1 %identity_ok, %socket_ok
          br i1 %valid, label %load_state, label %invalid_argument
        load_state:
          %state = inttoptr i64 %identity to ptr
          %table_slot = getelementptr i8, ptr %state, i64 16
          %table = load ptr, ptr %table_slot, align 8
          %capacity_slot = getelementptr i8, ptr %state, i64 40
          %capacity = load i64, ptr %capacity_slot, align 8
          %count_slot = getelementptr i8, ptr %state, i64 64
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
          %table_slot = getelementptr i8, ptr %state, i64 16
          %table = load ptr, ptr %table_slot, align 8
          %capacity_slot = getelementptr i8, ptr %state, i64 40
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
          br i1 %unassociated, label %publish, label %associated_failure
        publish:
          %socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %socket = load i64, ptr %socket_slot, align 8
          store i64 0, ptr %registration_entry, align 8
          store i64 0, ptr %key_slot, align 8
          store i64 -1, ptr %socket_slot, align 8
          %submission_state_slot = getelementptr i8, ptr %registration_entry, i64 24
          store i64 0, ptr %submission_state_slot, align 8
          %count_slot = getelementptr i8, ptr %state, i64 64
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

        define internal void @sollang_platform_socket_completion_close(i64 %identity) #0 {
        entry:
          %valid = icmp ugt i64 %identity, 0
          br i1 %valid, label %close_reactor, label %done
        close_reactor:
          %state = inttoptr i64 %identity to ptr
          %epoll64 = load i64, ptr %state, align 8
          %epoll = trunc i64 %epoll64 to i32
          %wakeup_slot = getelementptr i8, ptr %state, i64 8
          %wakeup64 = load i64, ptr %wakeup_slot, align 8
          %wakeup = trunc i64 %wakeup64 to i32
          %registration_table_slot = getelementptr i8, ptr %state, i64 16
          %registration_table = load ptr, ptr %registration_table_slot, align 8
          %pending_table_slot = getelementptr i8, ptr %state, i64 24
          %pending_table = load ptr, ptr %pending_table_slot, align 8
          %completion_table_slot = getelementptr i8, ptr %state, i64 32
          %completion_table = load ptr, ptr %completion_table_slot, align 8
          %registration_capacity_slot = getelementptr i8, ptr %state, i64 40
          %registration_capacity = load i64, ptr %registration_capacity_slot, align 8
          br label %close_registration_loop
        close_registration_loop:
          %registration_index = phi i64 [ 0, %close_reactor ], [ %registration_next, %close_registration_continue ]
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
          %registered_socket64 = load i64, ptr %registered_socket_slot, align 8
          %registered_socket = trunc i64 %registered_socket64 to i32
          %registered_socket_closed = call i32 @close(i32 %registered_socket)
          store i64 0, ptr %registration_entry, align 8
          br label %close_registration_continue
        close_registration_continue:
          %registration_next = add nuw i64 %registration_index, 1
          br label %close_registration_loop
        close_handles:
          %closed_wakeup = call i32 @close(i32 %wakeup)
          %closed_epoll = call i32 @close(i32 %epoll)
          call void @sollang_free(ptr %completion_table)
          call void @sollang_free(ptr %pending_table)
          call void @sollang_free(ptr %registration_table)
          call void @sollang_free(ptr %state)
          br label %done
        done:
          ret void
        }
        """;
}
