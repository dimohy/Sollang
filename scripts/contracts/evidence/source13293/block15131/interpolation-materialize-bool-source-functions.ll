define i32 @main() {
entry:
  %each118108_index_slot = alloca i64, align 8
  %each118108_limit_slot = alloca i64, align 8
  %slot118104 = alloca %sollang.array.i32, align 1
  %v118106_capacity_i64 = add i64 0, 64
  %v118106_capacity_positive = icmp ugt i64 %v118106_capacity_i64, 0
  %v118106_allocation = select i1 %v118106_capacity_positive, i64 %v118106_capacity_i64, i64 1
  %v118106_capacity_valid = icmp sge i64 %v118106_capacity_i64, 0
  %v118106_data = call ptr @sollang_raw_arena_create(i64 %v118106_allocation, i1 %v118106_capacity_valid)
  %v118106_0 = insertvalue %sollang.array.i32 poison, ptr %v118106_data, 0
  %v118106_1 = insertvalue %sollang.array.i32 %v118106_0, i64 0, 1
  %v118106 = insertvalue %sollang.array.i32 %v118106_1, i64 %v118106_allocation, 2
  store %sollang.array.i32 %v118106, ptr %slot118104, align 1
  %v118109_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118109 = insertvalue { i32, i32 } %v118109_start, i32 1, 1
  %each118108_range = freeze { i32, i32 } %v118109
  %each118108_first = extractvalue { i32, i32 } %each118108_range, 0
  %each118108_last = extractvalue { i32, i32 } %each118108_range, 1
  %each118108_start = sext i32 %each118108_first to i64
  %each118108_limit = sext i32 %each118108_last to i64
  store i64 %each118108_start, ptr %each118108_index_slot, align 8
  store i64 %each118108_limit, ptr %each118108_limit_slot, align 8
  br label %each118108_header
each118108_header:
  %each118108_index = load i64, ptr %each118108_index_slot, align 8
  %each118108_bound = load i64, ptr %each118108_limit_slot, align 8
  %each118108_done = icmp sgt i64 %each118108_index, %each118108_bound
  br i1 %each118108_done, label %each118108_exit, label %each118108_body
each118108_body:
  %each118108_item = trunc i64 %each118108_index to i32
  %each_role_m144_s3 = freeze i32 %each118108_item
  %v118113_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118113, 0
  %v118113 = insertvalue %sollang.text %v118113_ptr, i64 17, 1
  %v118114 = load %sollang.array.i32, ptr %slot118104, align 1
  %v118112_expression0 = icmp sgt i32 %each_role_m144_s3, 0
  %materialize118112_root0_value = or i1 false, %v118112_expression0
  %materialize118112_root0_ptr = select i1 %materialize118112_root0_value, ptr @sollang_bool_true_bytes, ptr @sollang_bool_false_bytes
  %materialize118112_root0_length = select i1 %materialize118112_root0_value, i64 4, i64 5
  %materialize118112_source_length0 = add i64 0, 5
  %materialize118112_source_length1 = add i64 %materialize118112_source_length0, %materialize118112_root0_length
  %materialize118112_ptr_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 0
  %materialize118112_length_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 1
  %materialize118112_capacity_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 2
  %materialize118112_data = load ptr, ptr %materialize118112_ptr_addr, align 8
  %materialize118112_used = load i64, ptr %materialize118112_length_addr, align 8
  %materialize118112_capacity = load i64, ptr %materialize118112_capacity_addr, align 8
  %materialize118112_end = add i64 %materialize118112_used, %materialize118112_source_length1
  %materialize118112_fits = icmp ule i64 %materialize118112_end, %materialize118112_capacity
  br i1 %materialize118112_fits, label %materialize118112_keep, label %materialize118112_grow
materialize118112_keep:
  br label %materialize118112_ready
materialize118112_grow:
  %materialize118112_doubled = shl i64 %materialize118112_capacity, 1
  %materialize118112_doubled_enough = icmp uge i64 %materialize118112_doubled, %materialize118112_end
  %materialize118112_new_capacity = select i1 %materialize118112_doubled_enough, i64 %materialize118112_doubled, i64 %materialize118112_end
  %materialize118112_grown = call ptr @realloc(ptr %materialize118112_data, i64 %materialize118112_new_capacity)
  br label %materialize118112_ready
materialize118112_ready:
  %materialize118112_pointer = phi ptr [ %materialize118112_data, %materialize118112_keep ], [ %materialize118112_grown, %materialize118112_grow ]
  %materialize118112_final_capacity = phi i64 [ %materialize118112_capacity, %materialize118112_keep ], [ %materialize118112_new_capacity, %materialize118112_grow ]
  %materialize118112_target = getelementptr i8, ptr %materialize118112_pointer, i64 %materialize118112_used
  %materialize118112_copy_offset0 = add i64 0, 0
  %materialize118112_literal0_target = getelementptr i8, ptr %materialize118112_target, i64 %materialize118112_copy_offset0
  %materialize118112_literal0_source = getelementptr i8, ptr @sollang_str_118113, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118112_literal0_target, ptr %materialize118112_literal0_source, i64 5, i1 false)
  %materialize118112_copy_offset1 = add i64 %materialize118112_copy_offset0, 5
  %materialize118112_root0_target = getelementptr i8, ptr %materialize118112_target, i64 %materialize118112_copy_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118112_root0_target, ptr %materialize118112_root0_ptr, i64 %materialize118112_root0_length, i1 false)
  %materialize118112_copy_offset2 = add i64 %materialize118112_copy_offset1, %materialize118112_root0_length
  %materialize118112_suffix_target = getelementptr i8, ptr %materialize118112_target, i64 %materialize118112_copy_offset2
  %materialize118112_suffix_source = getelementptr i8, ptr @sollang_str_118113, i64 17
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118112_suffix_target, ptr %materialize118112_suffix_source, i64 0, i1 false)
  store ptr %materialize118112_pointer, ptr %materialize118112_ptr_addr, align 8
  store i64 %materialize118112_end, ptr %materialize118112_length_addr, align 8
  store i64 %materialize118112_final_capacity, ptr %materialize118112_capacity_addr, align 8
  %v118112_0 = insertvalue %sollang.text poison, ptr %materialize118112_target, 0
  %v118112 = insertvalue %sollang.text %v118112_0, i64 %materialize118112_source_length1, 1
  %v118116 = freeze %sollang.text %v118112
  %v118115_runtime_ptr = extractvalue %sollang.text %v118116, 0
  %v118115_runtime_len = extractvalue %sollang.text %v118116, 1
  call void @sollang_runtime_print(ptr %v118115_runtime_ptr, i64 %v118115_runtime_len, i1 true)
  br label %each118108_continue
each118108_continue:
  %each118108_current = load i64, ptr %each118108_index_slot, align 8
  %each118108_next = add i64 %each118108_current, 1
  store i64 %each118108_next, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
