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
  %transferred_slot = getelementptr i8, ptr %completion_table, i64 24
  %completion_succeeded = icmp eq i32 %completion_status, 0
  br i1 %completion_succeeded, label %record_success, label %resolve_failure
resolve_failure:
  %registration_table_slot = getelementptr i8, ptr %state, i64 8
  %registration_table = load ptr, ptr %registration_table_slot, align 8
  %registration_index_slot = getelementptr i8, ptr %pending_record, i64 16
  %registration_index = load i64, ptr %registration_index_slot, align 8
  %registration_offset = mul nuw i64 %registration_index, 32
  %registration_entry = getelementptr i8, ptr %registration_table, i64 %registration_offset
  %socket_slot = getelementptr i8, ptr %registration_entry, i64 16
  %socket = load i64, ptr %socket_slot, align 8
  %completion_flags = alloca i32, align 4
  store i32 0, ptr %completion_flags, align 4
  %resolved = call i32 @WSAGetOverlappedResult(i64 %socket, ptr %overlapped, ptr %transferred_slot, i32 0, ptr %completion_flags)
  %resolved_failed = icmp eq i32 %resolved, 0
  br i1 %resolved_failed, label %record_failure, label %trap
record_failure:
  %completion_error = call i32 @WSAGetLastError()
  br label %record_status
record_success:
  br label %record_status
record_status:
  %published_status = phi i32 [ 0, %record_success ], [ %completion_error, %record_failure ]
  %record_status_slot = getelementptr i8, ptr %pending_record, i64 116
  store i32 %published_status, ptr %record_status_slot, align 4
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