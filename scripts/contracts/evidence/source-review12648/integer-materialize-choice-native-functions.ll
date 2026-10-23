define i32 @main() {
entry:
  %each118108_index_slot = alloca i64, align 8
  %each118108_limit_slot = alloca i64, align 8
  %deferred_text118116_tag = alloca i64, align 8
  %if118116_result = alloca %sollang.text, align 8
  %deferred_text118118_root0_slot = alloca i32, align 4
  %deferred_text118118_root1_slot = alloca i32, align 4
  %deferred_text118120_root4_slot = alloca i32, align 4
  %deferred_text118120_root7_slot = alloca i32, align 4
  %calltext118112_arg0_leaf118118_root0_buffer = alloca [21 x i8], align 1
  %calltext118112_arg0_leaf118118_root1_buffer = alloca [21 x i8], align 1
  %calltext118112_arg0_leaf118120_root0_buffer = alloca [21 x i8], align 1
  %calltext118112_arg0_leaf118120_root1_buffer = alloca [21 x i8], align 1
  %slot118104 = alloca %sollang.array.i32, align 1
  %v118106_capacity_i64 = add i64 0, 32
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
  %v118114 = freeze i32 %each118108_item
  %v118121 = load %sollang.array.i32, ptr %slot118104, align 1
  %v118113 = icmp sgt i32 %v118114, 0
  br i1 %v118113, label %if118116_then, label %if118116_else
if118116_then:
  %v118118_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118118, 0
  %v118118 = insertvalue %sollang.text %v118118_ptr, i64 21, 1
  store i32 %each_role_m144_s3, ptr %deferred_text118118_root0_slot, align 4
  %v118118_expression1 = add i32 %each_role_m144_s3, 1
  store i32 %v118118_expression1, ptr %deferred_text118118_root1_slot, align 4
  store i64 118118, ptr %deferred_text118116_tag, align 8
  store %sollang.text poison, ptr %if118116_result, align 8
  br label %if118116_merge
if118116_else:
  %v118120_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118120, 0
  %v118120 = insertvalue %sollang.text %v118120_ptr, i64 27, 1
  %v118120_expression4 = add i32 %each_role_m144_s3, 10
  store i32 %v118120_expression4, ptr %deferred_text118120_root4_slot, align 4
  %v118120_expression7 = add i32 %each_role_m144_s3, 11
  store i32 %v118120_expression7, ptr %deferred_text118120_root7_slot, align 4
  store i64 118120, ptr %deferred_text118116_tag, align 8
  store %sollang.text poison, ptr %if118116_result, align 8
  br label %if118116_merge
if118116_merge:
  %v118116 = load %sollang.text, ptr %if118116_result, align 8
  %calltext118112_arg0_tag = load i64, ptr %deferred_text118116_tag, align 8
  %calltext118112_arg0_is118118 = icmp eq i64 %calltext118112_arg0_tag, 118118
  br i1 %calltext118112_arg0_is118118, label %calltext118112_arg0_leaf118118_start, label %calltext118112_arg0_leaf118118_next
calltext118112_arg0_leaf118118_start:
  %calltext118112_arg0_leaf118118_root0_value = load i32, ptr %deferred_text118118_root0_slot, align 4
  %calltext118112_arg0_leaf118118_root0_integer = sext i32 %calltext118112_arg0_leaf118118_root0_value to i64
  %calltext118112_arg0_leaf118118_root0_length = call i64 @sollang_format_i64(ptr %calltext118112_arg0_leaf118118_root0_buffer, i64 %calltext118112_arg0_leaf118118_root0_integer)
  %calltext118112_arg0_leaf118118_root0_ptr = getelementptr [21 x i8], ptr %calltext118112_arg0_leaf118118_root0_buffer, i64 0, i64 0
  %calltext118112_arg0_leaf118118_root1_value = load i32, ptr %deferred_text118118_root1_slot, align 4
  %calltext118112_arg0_leaf118118_root1_integer = sext i32 %calltext118112_arg0_leaf118118_root1_value to i64
  %calltext118112_arg0_leaf118118_root1_length = call i64 @sollang_format_i64(ptr %calltext118112_arg0_leaf118118_root1_buffer, i64 %calltext118112_arg0_leaf118118_root1_integer)
  %calltext118112_arg0_leaf118118_root1_ptr = getelementptr [21 x i8], ptr %calltext118112_arg0_leaf118118_root1_buffer, i64 0, i64 0
  %calltext118112_arg0_leaf118118_length0 = add i64 0, 1
  %calltext118112_arg0_leaf118118_length1 = add i64 %calltext118112_arg0_leaf118118_length0, %calltext118112_arg0_leaf118118_root0_length
  %calltext118112_arg0_leaf118118_length1_ok = icmp uge i64 %calltext118112_arg0_leaf118118_length1, %calltext118112_arg0_leaf118118_length0
  br i1 %calltext118112_arg0_leaf118118_length1_ok, label %calltext118112_arg0_leaf118118_length1_ready, label %calltext118112_arg0_leaf118118_length1_overflow
calltext118112_arg0_leaf118118_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118112_arg0_leaf118118_length1_ready:
  %calltext118112_arg0_leaf118118_length2 = add i64 %calltext118112_arg0_leaf118118_length1, %calltext118112_arg0_leaf118118_root1_length
  %calltext118112_arg0_leaf118118_length2_ok = icmp uge i64 %calltext118112_arg0_leaf118118_length2, %calltext118112_arg0_leaf118118_length1
  br i1 %calltext118112_arg0_leaf118118_length2_ok, label %calltext118112_arg0_leaf118118_length2_ready, label %calltext118112_arg0_leaf118118_length2_overflow
calltext118112_arg0_leaf118118_length2_overflow:
  call void @llvm.trap()
  unreachable
calltext118112_arg0_leaf118118_length2_ready:
  %calltext118112_arg0_leaf118118_empty = icmp eq i64 %calltext118112_arg0_leaf118118_length2, 0
  %calltext118112_arg0_leaf118118_allocation_length = select i1 %calltext118112_arg0_leaf118118_empty, i64 1, i64 %calltext118112_arg0_leaf118118_length2
  %calltext118112_arg0_leaf118118_buffer = alloca i8, i64 %calltext118112_arg0_leaf118118_allocation_length, align 1
  %calltext118112_arg0_leaf118118_offset0 = add i64 0, 0
  %calltext118112_arg0_leaf118118_literal0_target = getelementptr i8, ptr %calltext118112_arg0_leaf118118_buffer, i64 %calltext118112_arg0_leaf118118_offset0
  %calltext118112_arg0_leaf118118_literal0_source = getelementptr i8, ptr @sollang_str_118118, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118118_literal0_target, ptr %calltext118112_arg0_leaf118118_literal0_source, i64 0, i1 false)
  %calltext118112_arg0_leaf118118_offset1 = add i64 %calltext118112_arg0_leaf118118_offset0, 0
  %calltext118112_arg0_leaf118118_root0_target = getelementptr i8, ptr %calltext118112_arg0_leaf118118_buffer, i64 %calltext118112_arg0_leaf118118_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118118_root0_target, ptr %calltext118112_arg0_leaf118118_root0_ptr, i64 %calltext118112_arg0_leaf118118_root0_length, i1 false)
  %calltext118112_arg0_leaf118118_offset2 = add i64 %calltext118112_arg0_leaf118118_offset1, %calltext118112_arg0_leaf118118_root0_length
  %calltext118112_arg0_leaf118118_literal1_target = getelementptr i8, ptr %calltext118112_arg0_leaf118118_buffer, i64 %calltext118112_arg0_leaf118118_offset2
  %calltext118112_arg0_leaf118118_literal1_source = getelementptr i8, ptr @sollang_str_118118, i64 8
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118118_literal1_target, ptr %calltext118112_arg0_leaf118118_literal1_source, i64 1, i1 false)
  %calltext118112_arg0_leaf118118_offset3 = add i64 %calltext118112_arg0_leaf118118_offset2, 1
  %calltext118112_arg0_leaf118118_root1_target = getelementptr i8, ptr %calltext118112_arg0_leaf118118_buffer, i64 %calltext118112_arg0_leaf118118_offset3
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118118_root1_target, ptr %calltext118112_arg0_leaf118118_root1_ptr, i64 %calltext118112_arg0_leaf118118_root1_length, i1 false)
  %calltext118112_arg0_leaf118118_offset4 = add i64 %calltext118112_arg0_leaf118118_offset3, %calltext118112_arg0_leaf118118_root1_length
  %calltext118112_arg0_leaf118118_suffix_target = getelementptr i8, ptr %calltext118112_arg0_leaf118118_buffer, i64 %calltext118112_arg0_leaf118118_offset4
  %calltext118112_arg0_leaf118118_suffix_source = getelementptr i8, ptr @sollang_str_118118, i64 21
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118118_suffix_target, ptr %calltext118112_arg0_leaf118118_suffix_source, i64 0, i1 false)
  %calltext118112_arg0_leaf118118_value0 = insertvalue %sollang.text poison, ptr %calltext118112_arg0_leaf118118_buffer, 0
  %calltext118112_arg0_leaf118118 = insertvalue %sollang.text %calltext118112_arg0_leaf118118_value0, i64 %calltext118112_arg0_leaf118118_length2, 1
  br label %calltext118112_arg0_leaf118118_done
calltext118112_arg0_leaf118118_done:
  br label %calltext118112_arg0_end
calltext118112_arg0_leaf118118_next:
  %calltext118112_arg0_is118120 = icmp eq i64 %calltext118112_arg0_tag, 118120
  br i1 %calltext118112_arg0_is118120, label %calltext118112_arg0_leaf118120_start, label %calltext118112_arg0_leaf118120_next
calltext118112_arg0_leaf118120_start:
  %calltext118112_arg0_leaf118120_root0_value = load i32, ptr %deferred_text118120_root4_slot, align 4
  %calltext118112_arg0_leaf118120_root0_integer = sext i32 %calltext118112_arg0_leaf118120_root0_value to i64
  %calltext118112_arg0_leaf118120_root0_length = call i64 @sollang_format_i64(ptr %calltext118112_arg0_leaf118120_root0_buffer, i64 %calltext118112_arg0_leaf118120_root0_integer)
  %calltext118112_arg0_leaf118120_root0_ptr = getelementptr [21 x i8], ptr %calltext118112_arg0_leaf118120_root0_buffer, i64 0, i64 0
  %calltext118112_arg0_leaf118120_root1_value = load i32, ptr %deferred_text118120_root7_slot, align 4
  %calltext118112_arg0_leaf118120_root1_integer = sext i32 %calltext118112_arg0_leaf118120_root1_value to i64
  %calltext118112_arg0_leaf118120_root1_length = call i64 @sollang_format_i64(ptr %calltext118112_arg0_leaf118120_root1_buffer, i64 %calltext118112_arg0_leaf118120_root1_integer)
  %calltext118112_arg0_leaf118120_root1_ptr = getelementptr [21 x i8], ptr %calltext118112_arg0_leaf118120_root1_buffer, i64 0, i64 0
  %calltext118112_arg0_leaf118120_length0 = add i64 0, 1
  %calltext118112_arg0_leaf118120_length1 = add i64 %calltext118112_arg0_leaf118120_length0, %calltext118112_arg0_leaf118120_root0_length
  %calltext118112_arg0_leaf118120_length1_ok = icmp uge i64 %calltext118112_arg0_leaf118120_length1, %calltext118112_arg0_leaf118120_length0
  br i1 %calltext118112_arg0_leaf118120_length1_ok, label %calltext118112_arg0_leaf118120_length1_ready, label %calltext118112_arg0_leaf118120_length1_overflow
calltext118112_arg0_leaf118120_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118112_arg0_leaf118120_length1_ready:
  %calltext118112_arg0_leaf118120_length2 = add i64 %calltext118112_arg0_leaf118120_length1, %calltext118112_arg0_leaf118120_root1_length
  %calltext118112_arg0_leaf118120_length2_ok = icmp uge i64 %calltext118112_arg0_leaf118120_length2, %calltext118112_arg0_leaf118120_length1
  br i1 %calltext118112_arg0_leaf118120_length2_ok, label %calltext118112_arg0_leaf118120_length2_ready, label %calltext118112_arg0_leaf118120_length2_overflow
calltext118112_arg0_leaf118120_length2_overflow:
  call void @llvm.trap()
  unreachable
calltext118112_arg0_leaf118120_length2_ready:
  %calltext118112_arg0_leaf118120_empty = icmp eq i64 %calltext118112_arg0_leaf118120_length2, 0
  %calltext118112_arg0_leaf118120_allocation_length = select i1 %calltext118112_arg0_leaf118120_empty, i64 1, i64 %calltext118112_arg0_leaf118120_length2
  %calltext118112_arg0_leaf118120_buffer = alloca i8, i64 %calltext118112_arg0_leaf118120_allocation_length, align 1
  %calltext118112_arg0_leaf118120_offset0 = add i64 0, 0
  %calltext118112_arg0_leaf118120_literal0_target = getelementptr i8, ptr %calltext118112_arg0_leaf118120_buffer, i64 %calltext118112_arg0_leaf118120_offset0
  %calltext118112_arg0_leaf118120_literal0_source = getelementptr i8, ptr @sollang_str_118120, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118120_literal0_target, ptr %calltext118112_arg0_leaf118120_literal0_source, i64 0, i1 false)
  %calltext118112_arg0_leaf118120_offset1 = add i64 %calltext118112_arg0_leaf118120_offset0, 0
  %calltext118112_arg0_leaf118120_root0_target = getelementptr i8, ptr %calltext118112_arg0_leaf118120_buffer, i64 %calltext118112_arg0_leaf118120_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118120_root0_target, ptr %calltext118112_arg0_leaf118120_root0_ptr, i64 %calltext118112_arg0_leaf118120_root0_length, i1 false)
  %calltext118112_arg0_leaf118120_offset2 = add i64 %calltext118112_arg0_leaf118120_offset1, %calltext118112_arg0_leaf118120_root0_length
  %calltext118112_arg0_leaf118120_literal1_target = getelementptr i8, ptr %calltext118112_arg0_leaf118120_buffer, i64 %calltext118112_arg0_leaf118120_offset2
  %calltext118112_arg0_leaf118120_literal1_source = getelementptr i8, ptr @sollang_str_118120, i64 13
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118120_literal1_target, ptr %calltext118112_arg0_leaf118120_literal1_source, i64 1, i1 false)
  %calltext118112_arg0_leaf118120_offset3 = add i64 %calltext118112_arg0_leaf118120_offset2, 1
  %calltext118112_arg0_leaf118120_root1_target = getelementptr i8, ptr %calltext118112_arg0_leaf118120_buffer, i64 %calltext118112_arg0_leaf118120_offset3
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118120_root1_target, ptr %calltext118112_arg0_leaf118120_root1_ptr, i64 %calltext118112_arg0_leaf118120_root1_length, i1 false)
  %calltext118112_arg0_leaf118120_offset4 = add i64 %calltext118112_arg0_leaf118120_offset3, %calltext118112_arg0_leaf118120_root1_length
  %calltext118112_arg0_leaf118120_suffix_target = getelementptr i8, ptr %calltext118112_arg0_leaf118120_buffer, i64 %calltext118112_arg0_leaf118120_offset4
  %calltext118112_arg0_leaf118120_suffix_source = getelementptr i8, ptr @sollang_str_118120, i64 27
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118112_arg0_leaf118120_suffix_target, ptr %calltext118112_arg0_leaf118120_suffix_source, i64 0, i1 false)
  %calltext118112_arg0_leaf118120_value0 = insertvalue %sollang.text poison, ptr %calltext118112_arg0_leaf118120_buffer, 0
  %calltext118112_arg0_leaf118120 = insertvalue %sollang.text %calltext118112_arg0_leaf118120_value0, i64 %calltext118112_arg0_leaf118120_length2, 1
  br label %calltext118112_arg0_leaf118120_done
calltext118112_arg0_leaf118120_done:
  br label %calltext118112_arg0_end
calltext118112_arg0_leaf118120_next:
  call void @llvm.trap()
  unreachable
calltext118112_arg0_end:
  %calltext118112_arg0 = phi %sollang.text [ %calltext118112_arg0_leaf118118, %calltext118112_arg0_leaf118118_done ], [ %calltext118112_arg0_leaf118120, %calltext118112_arg0_leaf118120_done ]
  %materialize118112_source_ptr = extractvalue %sollang.text %calltext118112_arg0, 0
  %materialize118112_source_length = extractvalue %sollang.text %calltext118112_arg0, 1
  %materialize118112_ptr_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 0
  %materialize118112_length_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 1
  %materialize118112_capacity_addr = getelementptr inbounds %sollang.array.i32, ptr %slot118104, i32 0, i32 2
  %materialize118112_data = load ptr, ptr %materialize118112_ptr_addr, align 8
  %materialize118112_used = load i64, ptr %materialize118112_length_addr, align 8
  %materialize118112_capacity = load i64, ptr %materialize118112_capacity_addr, align 8
  %materialize118112_end = add i64 %materialize118112_used, %materialize118112_source_length
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
  call void @llvm.memcpy.p0.p0.i64(ptr %materialize118112_target, ptr %materialize118112_source_ptr, i64 %materialize118112_source_length, i1 false)
  store ptr %materialize118112_pointer, ptr %materialize118112_ptr_addr, align 8
  store i64 %materialize118112_end, ptr %materialize118112_length_addr, align 8
  store i64 %materialize118112_final_capacity, ptr %materialize118112_capacity_addr, align 8
  %v118112_0 = insertvalue %sollang.text poison, ptr %materialize118112_target, 0
  %v118112 = insertvalue %sollang.text %v118112_0, i64 %materialize118112_source_length, 1
  %v118123 = freeze %sollang.text %v118112
  %v118122_runtime_ptr = extractvalue %sollang.text %v118123, 0
  %v118122_runtime_len = extractvalue %sollang.text %v118123, 1
  call void @sollang_runtime_print(ptr %v118122_runtime_ptr, i64 %v118122_runtime_len, i1 true)
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
