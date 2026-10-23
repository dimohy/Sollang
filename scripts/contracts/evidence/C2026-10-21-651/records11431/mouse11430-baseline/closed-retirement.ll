define internal i1 @sollang_mouse_event_next_raw(ptr %context, ptr %x, ptr %y, ptr %delta, ptr %button, ptr %kind) {
entry:
  %active_next_address = getelementptr i8, ptr %context, i64 72
  %previous_active_next = atomicrmw add ptr %active_next_address, i32 1 acq_rel, align 4
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
  %active_before_value_return = atomicrmw sub ptr %active_next_address, i32 1 acq_rel, align 4
  call void @sollang_mouse_event_stream_drop(ptr %context)
  %value_event_address = getelementptr i8, ptr %context, i64 48
  %value_event = load ptr, ptr %value_event_address, align 8
  %value_signalled = call i32 @SetEvent(ptr %value_event)
  ret i1 true

closed:
  %active_before_closed_return = atomicrmw sub ptr %active_next_address, i32 1 acq_rel, align 4
  call void @sollang_mouse_event_stream_drop(ptr %context)
  %closed_event_address = getelementptr i8, ptr %context, i64 48
  %closed_event = load ptr, ptr %closed_event_address, align 8
  %closed_signalled = call i32 @SetEvent(ptr %closed_event)
  ret i1 false
}

define internal void @sollang_mouse_event_stream_drop(ptr %context) {
entry:
  %cancel_address = getelementptr i8, ptr %context, i64 32
  store atomic i32 1, ptr %cancel_address release, align 4
  %thread_address = getelementptr i8, ptr %context, i64 40
  %thread = load ptr, ptr %thread_address, align 8
  %cancelled = call i32 @CancelSynchronousIo(ptr %thread)
  %event_address = getelementptr i8, ptr %context, i64 48
  %event = load ptr, ptr %event_address, align 8
  %signalled = call i32 @SetEvent(ptr %event)
  %joined = call i32 @WaitForSingleObject(ptr %thread, i32 -1)
  %thread_closed = call i32 @CloseHandle(ptr %thread)
  br label %wait_active_next

wait_active_next:
  %active_next_address = getelementptr i8, ptr %context, i64 72
  %active_next = load atomic i32, ptr %active_next_address acquire, align 4
  %next_idle = icmp eq i32 %active_next, 0
  br i1 %next_idle, label %cleanup, label %wait_next_exit

wait_next_exit:
  %next_waited = call i32 @WaitForSingleObject(ptr %event, i32 -1)
  br label %wait_active_next

cleanup:
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


@ctx = internal global [80 x i8] zeroinitializer, align 8
@buffer = internal global [40 x i8] zeroinitializer, align 8
@event_closed = internal global i1 false
@invalid_event_uses = internal global i32 0
define internal i32 @SetEvent(ptr %event) {
entry:
  %closed = load i1, ptr @event_closed
  %bad = zext i1 %closed to i32
  %n = load i32, ptr @invalid_event_uses
  %next = add i32 %n, %bad
  store i32 %next, ptr @invalid_event_uses
  ret i32 1
}
define internal i32 @CancelSynchronousIo(ptr %thread) { ret i32 1 }
define internal i32 @WaitForSingleObject(ptr %handle, i32 %timeout) { ret i32 0 }
define internal i32 @CloseHandle(ptr %handle) {
entry:
  %is_event = icmp eq ptr %handle, inttoptr(i64 4 to ptr)
  %closed = load i1, ptr @event_closed
  %next = or i1 %closed, %is_event
  store i1 %next, ptr @event_closed
  ret i32 1
}
define internal i32 @SetConsoleMode(ptr %input, i32 %mode) { ret i32 1 }
define internal void @sollang_free(ptr %allocation) { ret void }
define i32 @main() {
entry:
  %capacity = getelementptr i8, ptr @ctx, i64 12
  store i32 2, ptr %capacity
  %count = getelementptr i8, ptr @ctx, i64 28
  store i32 0, ptr %count
  %cancel = getelementptr i8, ptr @ctx, i64 32
  store atomic i32 1, ptr %cancel release, align 4
  %thread = getelementptr i8, ptr @ctx, i64 40
  store ptr inttoptr(i64 3 to ptr), ptr %thread
  %event = getelementptr i8, ptr @ctx, i64 48
  store ptr inttoptr(i64 4 to ptr), ptr %event
  %buffer = getelementptr i8, ptr @ctx, i64 56
  store ptr @buffer, ptr %buffer
  %values = alloca [5 x i32], align 4
  %y = getelementptr i8, ptr %values, i64 4
  %delta = getelementptr i8, ptr %values, i64 8
  %button = getelementptr i8, ptr %values, i64 12
  %kind = getelementptr i8, ptr %values, i64 16
  %value = call i1 @sollang_mouse_event_next_raw(ptr @ctx, ptr %values, ptr %y, ptr %delta, ptr %button, ptr %kind)

  %bad = load i32, ptr @invalid_event_uses
  %ok = icmp eq i32 %bad, 0
  %exit = select i1 %ok, i32 0, i32 17
  ret i32 %exit
}
