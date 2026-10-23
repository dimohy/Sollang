define internal i1 @sollang_mouse_event_next_raw(ptr %context, ptr %x, ptr %y, ptr %delta, ptr %button, ptr %kind) {
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
  call void @sollang_mouse_event_stream_drop(ptr %context, i1 false)
  ret i1 true

closed:
  call void @sollang_mouse_event_stream_drop(ptr %context, i1 false)
  ret i1 false
}
define internal void @sollang_mouse_event_stream_drop(ptr %context, i1 %destroy) {
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
define internal void @sollang_linux_mouse_signal(ptr %context) {
entry:
  %one = alloca i64, align 8
  store i64 1, ptr %one, align 8
  %fd_address = getelementptr i8, ptr %context, i64 28
  %fd = load i32, ptr %fd_address, align 4
  %written = call i64 @write(i32 %fd, ptr %one, i64 8)
  ret void
}

@freed = internal global i32 0
@bad = internal global i32 0
@joined = internal global i32 0
@signals = internal global i32 0
@closed = internal global i32 0
define internal void @increment(ptr %counter) {
  %n = load i32, ptr %counter
  %next = add i32 %n, 1
  store i32 %next, ptr %counter
  ret void
}
define internal void @require(i1 %ok) {
  %failed = xor i1 %ok, true
  %n = zext i1 %failed to i32
  %old = load i32, ptr @bad
  %sum = add i32 %old, %n
  store i32 %sum, ptr @bad
  ret void
}
define internal void @sollang_free(ptr %allocation) {
  call void @increment(ptr @freed)
  ret void
}
define internal void @free(ptr %allocation) {
  call void @sollang_free(ptr %allocation)
  ret void
}
declare void @llvm.trap()

@ctx = internal global [80 x i8] zeroinitializer, align 8
@buffer = internal global [40 x i8] zeroinitializer, align 8
@original = internal global [128 x i8] zeroinitializer, align 8

@sollang_mouse_disable = internal global [16 x i8] zeroinitializer
define internal i64 @write(i32 %fd, ptr %bytes, i64 %length) {
  call void @increment(ptr @signals)
  ret i64 %length
}
define internal i64 @read(i32 %fd, ptr %bytes, i64 %length) { ret i64 %length }
define internal i32 @pthread_join(i64 %thread, ptr %result) {
  call void @increment(ptr @joined)
  ret i32 0
}
define internal i32 @tcsetattr(i32 %fd, i32 %mode, ptr %state) { ret i32 0 }
define internal i32 @close(i32 %fd) {
  call void @increment(ptr @closed)
  ret i32 0
}

define i32 @main() {
  %capacity = getelementptr i8, ptr @ctx, i64 0
  store i32 2, ptr %capacity
  %count = getelementptr i8, ptr @ctx, i64 16
  store i32 1, ptr %count
  %cancel = getelementptr i8, ptr @ctx, i64 20
  store atomic i32 0, ptr %cancel release, align 4
  %buffer = getelementptr i8, ptr @ctx, i64 40
  store ptr @buffer, ptr %buffer

  %thread = getelementptr i8, ptr @ctx, i64 32
  store i64 3, ptr %thread
  %event = getelementptr i8, ptr @ctx, i64 28
  store i32 4, ptr %event
  %original = getelementptr i8, ptr @ctx, i64 48
  store ptr @original, ptr %original

  %values = alloca [5 x i32], align 4
  %y = getelementptr i8, ptr %values, i64 4
  %delta = getelementptr i8, ptr %values, i64 8
  %button = getelementptr i8, ptr %values, i64 12
  %kind = getelementptr i8, ptr %values, i64 16
  %value = call i1 @sollang_mouse_event_next_raw(ptr @ctx, ptr %values, ptr %y, ptr %delta, ptr %button, ptr %kind)
  %value_ok = icmp eq i1 %value, true
  call void @require(i1 %value_ok)

  %early_frees = load i32, ptr @freed
  %not_freed = icmp eq i32 %early_frees, 0
  call void @require(i1 %not_freed)
  %early_joins = load i32, ptr @joined
  %not_joined = icmp eq i32 %early_joins, 0
  call void @require(i1 %not_joined)

  call void @sollang_mouse_event_stream_drop(ptr @ctx, i1 true)

  %frees = load i32, ptr @freed
  %exact_free = icmp eq i32 %frees, 3
  call void @require(i1 %exact_free)
  %joins = load i32, ptr @joined
  %exact_join = icmp eq i32 %joins, 1
  call void @require(i1 %exact_join)
  %closes = load i32, ptr @closed
  %exact_close = icmp eq i32 %closes, 1
  call void @require(i1 %exact_close)
  %bad = load i32, ptr @bad
  %ok = icmp eq i32 %bad, 0
  %exit = select i1 %ok, i32 0, i32 17
  ret i32 %exit
}
