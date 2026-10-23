define internal i64 @sollang_runtime_read_standard_input_chunk(ptr %data, i64 %capacity) {
entry:
  %handle = call ptr @GetStdHandle(i32 -10)
  %exceeds_dword = icmp ugt i64 %capacity, 4294967295
  %bounded_capacity = select i1 %exceeds_dword, i64 4294967295, i64 %capacity
  %capacity32 = trunc i64 %bounded_capacity to i32
  %read_slot = alloca i32, align 4
  %ok = call i32 @ReadFile(ptr %handle, ptr %data, i32 %capacity32, ptr %read_slot, ptr null)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %success, label %inspect_error
inspect_error:
  %error = call i32 @GetLastError()
  %broken_pipe = icmp eq i32 %error, 109
  br i1 %broken_pipe, label %eof, label %failure
eof:
  ret i64 0
success:
  %read32 = load i32, ptr %read_slot, align 4
  %read64 = zext i32 %read32 to i64
  ret i64 %read64
failure:
  ret i64 -1
}
define %sollang.source_text @sollang_runtime_read_standard_input() {
entry:
  %buffer_slot = alloca ptr, align 8
  %length_slot = alloca i64, align 8
  %capacity_slot = alloca i64, align 8
  %initial = call ptr @malloc(i64 4096)
  %initial_ok = icmp ne ptr %initial, null
  br i1 %initial_ok, label %initialize, label %failure
initialize:
  store ptr %initial, ptr %buffer_slot, align 8
  store i64 0, ptr %length_slot, align 8
  store i64 4096, ptr %capacity_slot, align 8
  br label %read
read:
  %buffer = load ptr, ptr %buffer_slot, align 8
  %length = load i64, ptr %length_slot, align 8
  %capacity = load i64, ptr %capacity_slot, align 8
  %available = sub i64 %capacity, %length
  %destination = getelementptr i8, ptr %buffer, i64 %length
  %count = call i64 @sollang_runtime_read_standard_input_chunk(ptr %destination, i64 %available)
  %read_failed = icmp slt i64 %count, 0
  br i1 %read_failed, label %release_failure, label %advance
advance:
  %eof = icmp eq i64 %count, 0
  %next_length = add i64 %length, %count
  store i64 %next_length, ptr %length_slot, align 8
  br i1 %eof, label %success, label %inspect_capacity
inspect_capacity:
  %full = icmp eq i64 %next_length, %capacity
  br i1 %full, label %grow, label %read
grow:
  %next_capacity = mul i64 %capacity, 2
  %resized = call ptr @realloc(ptr %buffer, i64 %next_capacity)
  %resize_ok = icmp ne ptr %resized, null
  br i1 %resize_ok, label %store_resize, label %release_failure
store_resize:
  store ptr %resized, ptr %buffer_slot, align 8
  store i64 %next_capacity, ptr %capacity_slot, align 8
  br label %read
success:
  %final_buffer = load ptr, ptr %buffer_slot, align 8
  %final_length = load i64, ptr %length_slot, align 8
  %result0 = insertvalue %sollang.source_text poison, ptr %final_buffer, 0
  %result1 = insertvalue %sollang.source_text %result0, i64 %final_length, 1
  %result2 = insertvalue %sollang.source_text %result1, ptr %final_buffer, 2
  %result3 = insertvalue %sollang.source_text %result2, i64 -1, 3
  ret %sollang.source_text %result3
release_failure:
  %failed_buffer = load ptr, ptr %buffer_slot, align 8
  call void @free(ptr %failed_buffer)
  br label %failure
failure:
  call void @llvm.trap()
  unreachable
}
define %sollang.source_text @sollang_runtime_read_standard_input_chunk_once(i64 %capacity) {
entry:
  %zero_capacity = icmp eq i64 %capacity, 0
  %allocation_size = select i1 %zero_capacity, i64 1, i64 %capacity
  %buffer = call ptr @malloc(i64 %allocation_size)
  %allocated = icmp ne ptr %buffer, null
  br i1 %allocated, label %read, label %failure
read:
  %count = call i64 @sollang_runtime_read_standard_input_chunk(ptr %buffer, i64 %capacity)
  %read_failed = icmp slt i64 %count, 0
  br i1 %read_failed, label %release_failure, label %success
success:
  %result0 = insertvalue %sollang.source_text poison, ptr %buffer, 0
  %result1 = insertvalue %sollang.source_text %result0, i64 %count, 1
  %result2 = insertvalue %sollang.source_text %result1, ptr %buffer, 2
  %result3 = insertvalue %sollang.source_text %result2, i64 -1, 3
  ret %sollang.source_text %result3
release_failure:
  call void @free(ptr %buffer)
  br label %failure
failure:
  call void @llvm.trap()
  unreachable
}
