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
        functions.AppendLine("declare dllimport i32 @closesocket(i64)");
        functions.AppendLine("declare dllimport i32 @bind(i64, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @getsockname(i64, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @listen(i64, i32)");
        functions.AppendLine("declare dllimport i64 @accept(i64, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @connect(i64, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @recv(i64, ptr, i32, i32)");
        functions.AppendLine("declare dllimport i32 @send(i64, ptr, i32, i32)");
        functions.AppendLine("declare dllimport i32 @recvfrom(i64, ptr, i32, i32, ptr, ptr)");
        functions.AppendLine("declare dllimport i32 @sendto(i64, ptr, i32, i32, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @shutdown(i64, i32)");
        functions.AppendLine("declare dllimport i32 @setsockopt(i64, i32, i32, ptr, i32)");
        functions.AppendLine("declare dllimport i32 @inet_pton(i32, ptr, ptr)");
        functions.AppendLine("declare dllimport ptr @inet_ntop(i32, ptr, ptr, i64)");
        functions.AppendLine("declare i64 @strlen(ptr)");
        functions.AppendLine();
        functions.AppendLine(SocketRuntime);
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
        unsupported:
          ret i32 7
        other:
          ret i32 8
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

        define internal i32 @sollang_socket_address(ptr %text, i64 %length, i16 %port, ptr %storage) #0 {
        entry:
          %nonempty = icmp ugt i64 %length, 0
          %fits = icmp ule i64 %length, 45
          %valid_length = and i1 %nonempty, %fits
          br i1 %valid_length, label %copy, label %invalid

        copy:
          %buffer = alloca [46 x i8], align 1
          call void @llvm.memcpy.p0.p0.i64(ptr %buffer, ptr %text, i64 %length, i1 false)
          %end = getelementptr i8, ptr %buffer, i64 %length
          store i8 0, ptr %end, align 1
          br label %validate_loop

        validate_loop:
          %index = phi i64 [ 0, %copy ], [ %next, %validate_byte ]
          %complete = icmp eq i64 %index, %length
          br i1 %complete, label %parse_ipv4, label %validate_byte

        validate_byte:
          %byte_address = getelementptr i8, ptr %buffer, i64 %index
          %byte = load i8, ptr %byte_address, align 1
          %embedded_null = icmp eq i8 %byte, 0
          %next = add i64 %index, 1
          br i1 %embedded_null, label %invalid, label %validate_loop

        parse_ipv4:
          call void @llvm.memset.p0.i64(ptr %storage, i8 0, i64 28, i1 false)
          store i16 2, ptr %storage, align 2
          %port_address4 = getelementptr i8, ptr %storage, i64 2
          %network_port4 = call i16 @sollang_socket_network_port(i16 %port)
          store i16 %network_port4, ptr %port_address4, align 2
          %address4 = getelementptr i8, ptr %storage, i64 4
          %parsed4 = call i32 @inet_pton(i32 2, ptr %buffer, ptr %address4)
          %is_ipv4 = icmp eq i32 %parsed4, 1
          br i1 %is_ipv4, label %ipv4, label %parse_ipv6

        parse_ipv6:
          call void @llvm.memset.p0.i64(ptr %storage, i8 0, i64 28, i1 false)
          store i16 23, ptr %storage, align 2
          %port_address6 = getelementptr i8, ptr %storage, i64 2
          %network_port6 = call i16 @sollang_socket_network_port(i16 %port)
          store i16 %network_port6, ptr %port_address6, align 2
          %address6 = getelementptr i8, ptr %storage, i64 8
          %parsed6 = call i32 @inet_pton(i32 23, ptr %buffer, ptr %address6)
          %is_ipv6 = icmp eq i32 %parsed6, 1
          br i1 %is_ipv6, label %ipv6, label %invalid

        ipv4:
          ret i32 2
        ipv6:
          ret i32 23
        invalid:
          ret i32 0
        }

        define internal %sollang.socket_result @sollang_platform_socket_listen(ptr %address, i64 %address_length, i16 %port, i64 %backlog, i1 %reuse) #0 {
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
          %family = call i32 @sollang_socket_address(ptr %address, i64 %address_length, i16 %port, ptr %socket_address)
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

        define internal %sollang.socket_result @sollang_platform_socket_connect(ptr %address, i64 %address_length, i16 %port) #0 {
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
          %family = call i32 @sollang_socket_address(ptr %address, i64 %address_length, i16 %port, ptr %socket_address)
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

        define internal %sollang.socket_result @sollang_platform_socket_receive(i64 %socket, ptr %buffer, i64 %capacity) #0 {
        entry:
          %positive = icmp ugt i64 %capacity, 0
          %fits = icmp ule i64 %capacity, 2147483647
          %valid = and i1 %positive, %fits
          br i1 %valid, label %receive, label %invalid_argument

        receive:
          %capacity32 = trunc i64 %capacity to i32
          %count32 = call i32 @recv(i64 %socket, ptr %buffer, i32 %capacity32, i32 0)
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

        define internal %sollang.socket_result @sollang_platform_socket_shutdown(i64 %socket) #0 {
        entry:
          %status = call i32 @shutdown(i64 %socket, i32 2)
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

        define internal %sollang.socket_result @sollang_platform_socket_bind_datagram(ptr %address, i64 %address_length, i16 %port, i1 %reuse) #0 {
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
          %family = call i32 @sollang_socket_address(ptr %address, i64 %address_length, i16 %port, ptr %socket_address)
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

        define internal %sollang.socket_result @sollang_platform_socket_send_to(i64 %socket, ptr %address, i64 %address_length, i16 %port, ptr %buffer, i64 %length) #0 {
        entry:
          %fits = icmp ule i64 %length, 2147483647
          br i1 %fits, label %parse, label %invalid_argument
        parse:
          %socket_address = alloca [28 x i8], align 8
          %family = call i32 @sollang_socket_address(ptr %address, i64 %address_length, i16 %port, ptr %socket_address)
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

        define internal %sollang.socket_result @sollang_platform_socket_receive_from(i64 %socket, ptr %buffer, i64 %capacity, ptr %address_text, ptr %address_length_out, ptr %port_out) #0 {
        entry:
          %positive = icmp ugt i64 %capacity, 0
          %fits = icmp ule i64 %capacity, 2147483647
          %valid = and i1 %positive, %fits
          br i1 %valid, label %receive, label %invalid_argument
        receive:
          %source = alloca [28 x i8], align 8
          %source_length = alloca i32, align 4
          store i32 28, ptr %source_length, align 4
          %capacity32 = trunc i64 %capacity to i32
          %count32 = call i32 @recvfrom(i64 %socket, ptr %buffer, i32 %capacity32, i32 0, ptr %source, ptr %source_length)
          %ok = icmp sge i32 %count32, 0
          br i1 %ok, label %format, label %failure
        format:
          %family16 = load i16, ptr %source, align 2
          %family = zext i16 %family16 to i32
          %is_ipv4 = icmp eq i32 %family, 2
          %address4 = getelementptr i8, ptr %source, i64 4
          %address6 = getelementptr i8, ptr %source, i64 8
          %address_data = select i1 %is_ipv4, ptr %address4, ptr %address6
          %formatted = call ptr @inet_ntop(i32 %family, ptr %address_data, ptr %address_text, i64 46)
          %format_ok = icmp ne ptr %formatted, null
          br i1 %format_ok, label %publish, label %failure
        publish:
          %address_length = call i64 @strlen(ptr %address_text)
          store i64 %address_length, ptr %address_length_out, align 8
          %network_port_address = getelementptr i8, ptr %source, i64 2
          %network_port = load i16, ptr %network_port_address, align 2
          %port = call i16 @sollang_socket_network_port(i16 %network_port)
          store i16 %port, ptr %port_out, align 2
          %count = zext i32 %count32 to i64
          %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
          ret %sollang.socket_result %result
        failure:
          %error = call i32 @WSAGetLastError()
          %kind = call i32 @sollang_socket_error_kind(i32 %error)
          %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
          ret %sollang.socket_result %failed
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
}
