define i32 @main() {
entry:
  %each118115_index_slot = alloca i64, align 8
  %each118115_limit_slot = alloca i64, align 8
  %slot118104 = alloca %sollang.array.i32, align 1
  %v118108_capacity_i64 = add i64 0, 128
  %v118108_capacity_positive = icmp ugt i64 %v118108_capacity_i64, 0
  %v118108_allocation = select i1 %v118108_capacity_positive, i64 %v118108_capacity_i64, i64 1
  %v118108_capacity_valid = icmp sge i64 %v118108_capacity_i64, 0
  %v118108_data = call ptr @sollang_raw_arena_create(i64 %v118108_allocation, i1 %v118108_capacity_valid)
  %v118108_0 = insertvalue %sollang.array.i32 poison, ptr %v118108_data, 0
  %v118108_1 = insertvalue %sollang.array.i32 %v118108_0, i64 0, 1
  %v118108 = insertvalue %sollang.array.i32 %v118108_1, i64 %v118108_allocation, 2
  store %sollang.array.i32 %v118108, ptr %slot118104, align 1
  %v118111 = sub i64 0, 9223372036854775808
  %v118110 = add i64 %v118111, 0
  %v118113 = add i64 18446744073709551615, 0
  %v118116_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118116 = insertvalue { i32, i32 } %v118116_start, i32 1, 1
  %each118115_range = freeze { i32, i32 } %v118116
  %each118115_first = extractvalue { i32, i32 } %each118115_range, 0
  %each118115_last = extractvalue { i32, i32 } %each118115_range, 1
  %each118115_start = sext i32 %each118115_first to i64
  %each118115_limit = sext i32 %each118115_last to i64
  store i64 %each118115_start, ptr %each118115_index_slot, align 8
  store i64 %each118115_limit, ptr %each118115_limit_slot, align 8
  br label %each118115_header
each118115_header:
  %each118115_index = load i64, ptr %each118115_index_slot, align 8
  %each118115_bound = load i64, ptr %each118115_limit_slot, align 8
  %each118115_done = icmp sgt i64 %each118115_index, %each118115_bound
  br i1 %each118115_done, label %each118115_exit, label %each118115_body
each118115_body:
  %each118115_item = trunc i64 %each118115_index to i32
  %v118120_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118120, 0
  %v118120 = insertvalue %sollang.text %v118120_ptr, i64 21, 1
  %v118121 = load %sollang.array.i32, ptr %slot118104, align 1
  %materialize118119_root0_buffer = alloca [21 x i8], align 1
  %materialize118119_root0_length = call i64 @sollang_format_i64(ptr %materialize118119_root0_buffer, i64 %v118110)
  %materialize118119_root0_ptr = getelementptr [21 x i8], ptr %materialize118119_root0_buffer, i64 0, i64 0
  %materialize118119_root1_buffer = alloca [21 x i8], align 1
  %materialize118119_root1_length = call i64 @sollang_format_u64(ptr %materialize118119_root1_buffer, i64 %v118113)
  %materialize118119_root1_ptr = getelementptr [21 x i8], ptr %materialize118119_root1_buffer, i64 0, i64 0
  %materialize118119_source_length0 = add i64 0, 1
  %materialize118119_source_length1 = add i64 %materialize118119_source_length0, %materialize118119_root0_length
  %materialize118119_source_length2 = add i64 %materialize118119_source_length1, %materialize118119_root1_length
  %materialize118119_ptr_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 0
  %materialize118119_length_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 1
  %materialize118119_capacity_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 2
  %materialize118119_data = load ptr, ptr %materialize118119_ptr_addr, align 8
  %materialize118119_used = load i64, ptr %materialize118119_length_addr, align 8
  %materialize118119_capacity = load i64, ptr %materialize118119_capacity_addr, align 8
  %materialize118119_end = add i64 %materialize118119_used, %materialize118119_source_length2
  %materialize118119_fits = icmp ule i64 %materialize118119_end, %materialize118119_capacity
  br i1 %materialize118119_fits, label %materialize118119_keep, label %materialize118119_grow
materialize118119_keep:
  br label %materialize118119_ready
materialize118119_grow:
  %materialize118119_doubled = shl i64 %materialize118119_capacity, 1
  %materialize118119_doubled_enough = icmp uge i64 %materialize118119_doubled, %materialize118119_end
  %materialize118119_new_capacity = select i1 %materialize118119_doubled_enough, i64 %materialize118119_doubled, i64 %materialize118119_end
  %materialize118119_grown = call ptr @realloc(ptr %materialize118119_data, i64 %materialize118119_new_capacity)
  br label %materialize118119_ready
materialize118119_ready:
  %materialize118119_pointer = phi ptr [ %materialize118119_data, %materialize118119_keep ], [ %materialize118119_grown, %materialize118119_grow ]
  %materialize118119_final_capacity = phi i64 [ %materialize118119_capacity, %materialize118119_keep ], [ %materialize118119_new_capacity, %materialize118119_grow ]
  %materialize118119_target = getelementptr i8, ptr %materialize118119_pointer, i64 %materialize118119_used
  %materialize118119_copy_offset0 = add i64 0, 0
  %materialize118119_literal0_target = getelementptr i8, ptr %materialize118119_target, i64 %materialize118119_copy_offset0
  %materialize118119_literal0_source = getelementptr i8, ptr @sollang_str_118120, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118119_literal0_target, ptr %materialize118119_literal0_source, i64 0, i1 false)
  %materialize118119_copy_offset1 = add i64 %materialize118119_copy_offset0, 0
  %materialize118119_root0_target = getelementptr i8, ptr %materialize118119_target, i64 %materialize118119_copy_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118119_root0_target, ptr %materialize118119_root0_ptr, i64 %materialize118119_root0_length, i1 false)
  %materialize118119_copy_offset2 = add i64 %materialize118119_copy_offset1, %materialize118119_root0_length
  %materialize118119_literal1_target = getelementptr i8, ptr %materialize118119_target, i64 %materialize118119_copy_offset2
  %materialize118119_literal1_source = getelementptr i8, ptr @sollang_str_118120, i64 9
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118119_literal1_target, ptr %materialize118119_literal1_source, i64 1, i1 false)
  %materialize118119_copy_offset3 = add i64 %materialize118119_copy_offset2, 1
  %materialize118119_root1_target = getelementptr i8, ptr %materialize118119_target, i64 %materialize118119_copy_offset3
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118119_root1_target, ptr %materialize118119_root1_ptr, i64 %materialize118119_root1_length, i1 false)
  %materialize118119_copy_offset4 = add i64 %materialize118119_copy_offset3, %materialize118119_root1_length
  %materialize118119_suffix_target = getelementptr i8, ptr %materialize118119_target, i64 %materialize118119_copy_offset4
  %materialize118119_suffix_source = getelementptr i8, ptr @sollang_str_118120, i64 21
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118119_suffix_target, ptr %materialize118119_suffix_source, i64 0, i1 false)
  store ptr %materialize118119_pointer, ptr %materialize118119_ptr_addr, align 8
  store i64 %materialize118119_end, ptr %materialize118119_length_addr, align 8
  store i64 %materialize118119_final_capacity, ptr %materialize118119_capacity_addr, align 8
  %v118119_0 = insertvalue %sollang.text poison, ptr %materialize118119_target, 0
  %v118119 = insertvalue %sollang.text %v118119_0, i64 %materialize118119_source_length2, 1
  %v118123 = freeze %sollang.text %v118119
  %v118122_runtime_ptr = extractvalue %sollang.text %v118123, 0
  %v118122_runtime_len = extractvalue %sollang.text %v118123, 1
  call void @sollang_runtime_print(ptr %v118122_runtime_ptr, i64 %v118122_runtime_len, i1 true)
  br label %each118115_continue
each118115_continue:
  %each118115_current = load i64, ptr %each118115_index_slot, align 8
  %each118115_next = add i64 %each118115_current, 1
  store i64 %each118115_next, ptr %each118115_index_slot, align 8
  br label %each118115_header
each118115_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
