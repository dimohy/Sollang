define internal ptr @sollang_socket_completion_waiter(ptr %state) #0 {
        entry:
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
          %pending_capacity_slot = getelementptr i8, ptr %state, i64 48
          %pending_capacity = load i64, ptr %pending_capacity_slot, align 8
          br label %wait
        wait:
          %waited = call i32 @epoll_wait(i32 %epoll, ptr %completion_table, i32 1, i32 -1)
          %wait_ok = icmp sgt i32 %waited, 0
          br i1 %wait_ok, label %inspect, label %wait_failure
        wait_failure:
          %wait_error = call i32 @sollang_socket_errno()
          %interrupted = icmp eq i32 %wait_error, 4
          br i1 %interrupted, label %wait, label %trap
        inspect:
          call void @sollang_socket_completion_lock(ptr %state)
          %event_mask = load i32, ptr %completion_table, align 4
          %event_data_slot = getelementptr i8, ptr %completion_table, i64 4
          %event_data = load i64, ptr %event_data_slot, align 1
          %is_wakeup = icmp eq i64 %event_data, 0
          br i1 %is_wakeup, label %inspect_wakeup, label %decode_registration
        inspect_wakeup:
          %stopping_slot = getelementptr i8, ptr %state, i64 96
          %stopping = load atomic i32, ptr %stopping_slot acquire, align 4
          %must_stop = icmp ne i32 %stopping, 0
          br i1 %must_stop, label %done_locked, label %drain_wakeup
        drain_wakeup:
          %wakeup_value = alloca i64, align 8
          %wakeup_read = call i64 @read(i32 %wakeup, ptr %wakeup_value, i64 8)
          br label %cancel_scan
        cancel_scan:
          %cancel_index = phi i64 [ 0, %drain_wakeup ], [ %cancel_next, %cancel_continue ]
          %cancel_done = icmp uge i64 %cancel_index, %pending_capacity
          br i1 %cancel_done, label %unlock_wait, label %cancel_check
        cancel_check:
          %cancel_offset = mul nuw i64 %cancel_index, 128
          %cancel_entry = getelementptr i8, ptr %pending_table, i64 %cancel_offset
          %cancel_active = load atomic i64, ptr %cancel_entry acquire, align 8
          %cancel_is_pending = icmp eq i64 %cancel_active, 1
          %cancel_requested_slot = getelementptr i8, ptr %cancel_entry, i64 72
          %cancel_requested = load atomic i32, ptr %cancel_requested_slot acquire, align 4
          %cancel_marked = icmp ne i32 %cancel_requested, 0
          %cancel_terminal = and i1 %cancel_is_pending, %cancel_marked
          br i1 %cancel_terminal, label %publish_cancel, label %cancel_continue
        publish_cancel:
          call void @sollang_socket_completion_publish_locked(ptr %state, ptr %cancel_entry, i32 125, i64 0)
          br label %cancel_continue
        cancel_continue:
          %cancel_next = add nuw i64 %cancel_index, 1
          br label %cancel_scan
        decode_registration:
          %registration_base = lshr i64 %event_data, 1
          %registration_index = sub i64 %registration_base, 1
          %registration_offset = mul nuw i64 %registration_index, 32
          %registration_entry = getelementptr i8, ptr %registration_table, i64 %registration_offset
          br label %pending_scan
        pending_scan:
          %pending_index = phi i64 [ 0, %decode_registration ], [ %pending_next, %pending_continue ]
          %pending_done = icmp uge i64 %pending_index, %pending_capacity
          br i1 %pending_done, label %rearm_registration, label %pending_check
        pending_check:
          %pending_offset = mul nuw i64 %pending_index, 128
          %pending_entry = getelementptr i8, ptr %pending_table, i64 %pending_offset
          %pending_active = load atomic i64, ptr %pending_entry acquire, align 8
          %is_pending = icmp eq i64 %pending_active, 1
          %pending_registration_slot = getelementptr i8, ptr %pending_entry, i64 16
          %pending_registration = load i64, ptr %pending_registration_slot, align 8
          %registration_matches = icmp eq i64 %pending_registration, %registration_index
          %pending_matches = and i1 %is_pending, %registration_matches
          br i1 %pending_matches, label %inspect_direction, label %pending_continue
        inspect_direction:
          %direction_slot = getelementptr i8, ptr %pending_entry, i64 24
          %direction = load i32, ptr %direction_slot, align 4
          %is_receive = icmp eq i32 %direction, 0
          %ready_bit = select i1 %is_receive, i32 1, i32 4
          %readiness_mask = or i32 %ready_bit, 24
          %ready_mask = and i32 %event_mask, %readiness_mask
          %is_ready = icmp ne i32 %ready_mask, 0
          br i1 %is_ready, label %issue, label %pending_continue
        issue:
          %socket_slot = getelementptr i8, ptr %registration_entry, i64 16
          %socket64 = load i64, ptr %socket_slot, align 8
          %socket = trunc i64 %socket64 to i32
          %buffer_slot = getelementptr i8, ptr %pending_entry, i64 32
          %buffer = load ptr, ptr %buffer_slot, align 8
          %range_offset_slot = getelementptr i8, ptr %pending_entry, i64 56
          %range_offset = load i64, ptr %range_offset_slot, align 8
          %range_length_slot = getelementptr i8, ptr %pending_entry, i64 64
          %range_length = load i64, ptr %range_length_slot, align 8
          %data = getelementptr i8, ptr %buffer, i64 %range_offset
          br i1 %is_receive, label %issue_receive, label %issue_send
        issue_receive:
          %received = call i64 @recv(i32 %socket, ptr %data, i64 %range_length, i32 64)
          br label %classify
        issue_send:
          %sent = call i64 @send(i32 %socket, ptr %data, i64 %range_length, i32 16448)
          br label %classify
        classify:
          %transferred = phi i64 [ %received, %issue_receive ], [ %sent, %issue_send ]
          %completed = icmp sge i64 %transferred, 0
          br i1 %completed, label %publish_success, label %classify_failure
        classify_failure:
          %completion_error = call i32 @sollang_socket_errno()
          %would_block = icmp eq i32 %completion_error, 11
          br i1 %would_block, label %pending_continue, label %publish_failure
        publish_success:
          br label %publish_terminal
        publish_failure:
          br label %publish_terminal
        publish_terminal:
          %terminal_status = phi i32 [ 0, %publish_success ], [ %completion_error, %publish_failure ]
          %terminal_transferred = phi i64 [ %transferred, %publish_success ], [ 0, %publish_failure ]
          call void @sollang_socket_completion_publish_locked(ptr %state, ptr %pending_entry, i32 %terminal_status, i64 %terminal_transferred)
          br label %pending_continue
        rearm_registration:
          %rearm_error = call i32 @sollang_socket_completion_rearm_locked(ptr %state, i64 %registration_index, i32 0)
          %rearm_failed = icmp ne i32 %rearm_error, 0
          br i1 %rearm_failed, label %fail_registration, label %unlock_wait
        fail_registration:
          call void @sollang_socket_completion_fail_registration_locked(ptr %state, i64 %registration_index, i32 %rearm_error)
          br label %unlock_wait
        pending_continue:
          %pending_next = add nuw i64 %pending_index, 1
          br label %pending_scan
        unlock_wait:
          call void @sollang_socket_completion_unlock(ptr %state)
          br label %wait
        done_locked:
          call void @sollang_socket_completion_unlock(ptr %state)
          br label %done
        done:
          ret ptr null
        trap:
          call void @llvm.trap()
          unreachable
        }