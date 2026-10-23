define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define i32 @main() {
entry:
  %each118109_index_slot = alloca i64, align 8
  %each118109_limit_slot = alloca i64, align 8
  %v118110_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118110 = insertvalue { i32, i32 } %v118110_start, i32 1, 1
  %each118109_range = freeze { i32, i32 } %v118110
  %each118109_first = extractvalue { i32, i32 } %each118109_range, 0
  %each118109_last = extractvalue { i32, i32 } %each118109_range, 1
  %each118109_start = sext i32 %each118109_first to i64
  %each118109_limit = sext i32 %each118109_last to i64
  store i64 %each118109_start, ptr %each118109_index_slot, align 8
  store i64 %each118109_limit, ptr %each118109_limit_slot, align 8
  br label %each118109_header
each118109_header:
  %each118109_index = load i64, ptr %each118109_index_slot, align 8
  %each118109_bound = load i64, ptr %each118109_limit_slot, align 8
  %each118109_done = icmp sgt i64 %each118109_index, %each118109_bound
  br i1 %each118109_done, label %each118109_exit, label %each118109_body
each118109_body:
  %each118109_item = trunc i64 %each118109_index to i32
  %each_role_m144_s3 = freeze i32 %each118109_item
  %v118114_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118114, 0
  %v118114 = insertvalue %sollang.text %v118114_ptr, i64 26, 1
  %v118115_expression1 = icmp sgt i32 %each_role_m144_s3, 0
  %v118115_expression0_logical_slot = alloca i1, align 1
  store i1 0, ptr %v118115_expression0_logical_slot, align 1
  br i1 %v118115_expression1, label %interpolation118115_logical0_rhs, label %interpolation118115_logical0_end
interpolation118115_logical0_rhs:
  %v118115_expression4 = icmp slt i32 %each_role_m144_s3, 2
  store i1 %v118115_expression4, ptr %v118115_expression0_logical_slot, align 1
  br label %interpolation118115_logical0_end
interpolation118115_logical0_end:
  %v118115_expression0 = load i1, ptr %v118115_expression0_logical_slot, align 1
  %calltext118115_arg0_root0_value = or i1 false, %v118115_expression0
  %calltext118115_arg0_root0_buffer = alloca [5 x i8], align 1
  %calltext118115_arg0_root0_ptr = getelementptr [5 x i8], ptr %calltext118115_arg0_root0_buffer, i64 0, i64 0
  %calltext118115_arg0_root0_byte0 = select i1 %calltext118115_arg0_root0_value, i8 116, i8 102
  %calltext118115_arg0_root0_byte1 = select i1 %calltext118115_arg0_root0_value, i8 114, i8 97
  %calltext118115_arg0_root0_byte2 = select i1 %calltext118115_arg0_root0_value, i8 117, i8 108
  %calltext118115_arg0_root0_byte3 = select i1 %calltext118115_arg0_root0_value, i8 101, i8 115
  store i8 %calltext118115_arg0_root0_byte0, ptr %calltext118115_arg0_root0_ptr, align 1
  %calltext118115_arg0_root0_ptr1 = getelementptr i8, ptr %calltext118115_arg0_root0_ptr, i64 1
  store i8 %calltext118115_arg0_root0_byte1, ptr %calltext118115_arg0_root0_ptr1, align 1
  %calltext118115_arg0_root0_ptr2 = getelementptr i8, ptr %calltext118115_arg0_root0_ptr, i64 2
  store i8 %calltext118115_arg0_root0_byte2, ptr %calltext118115_arg0_root0_ptr2, align 1
  %calltext118115_arg0_root0_ptr3 = getelementptr i8, ptr %calltext118115_arg0_root0_ptr, i64 3
  store i8 %calltext118115_arg0_root0_byte3, ptr %calltext118115_arg0_root0_ptr3, align 1
  %calltext118115_arg0_root0_ptr4 = getelementptr i8, ptr %calltext118115_arg0_root0_ptr, i64 4
  store i8 101, ptr %calltext118115_arg0_root0_ptr4, align 1
  %calltext118115_arg0_root0_length = select i1 %calltext118115_arg0_root0_value, i64 4, i64 5
  %calltext118115_arg0_length0 = add i64 0, 0
  %calltext118115_arg0_length1 = add i64 %calltext118115_arg0_length0, %calltext118115_arg0_root0_length
  %calltext118115_arg0_length1_ok = icmp uge i64 %calltext118115_arg0_length1, %calltext118115_arg0_length0
  br i1 %calltext118115_arg0_length1_ok, label %calltext118115_arg0_length1_ready, label %calltext118115_arg0_length1_overflow
calltext118115_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118115_arg0_length1_ready:
  %calltext118115_arg0_empty = icmp eq i64 %calltext118115_arg0_length1, 0
  %calltext118115_arg0_allocation_length = select i1 %calltext118115_arg0_empty, i64 1, i64 %calltext118115_arg0_length1
  %calltext118115_arg0_buffer = alloca i8, i64 %calltext118115_arg0_allocation_length, align 1
  %calltext118115_arg0_offset0 = add i64 0, 0
  %calltext118115_arg0_literal0_target = getelementptr i8, ptr %calltext118115_arg0_buffer, i64 %calltext118115_arg0_offset0
  %calltext118115_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118114, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118115_arg0_literal0_target, ptr %calltext118115_arg0_literal0_source, i64 0, i1 false)
  %calltext118115_arg0_offset1 = add i64 %calltext118115_arg0_offset0, 0
  %calltext118115_arg0_root0_target = getelementptr i8, ptr %calltext118115_arg0_buffer, i64 %calltext118115_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118115_arg0_root0_target, ptr %calltext118115_arg0_root0_ptr, i64 %calltext118115_arg0_root0_length, i1 false)
  %calltext118115_arg0_offset2 = add i64 %calltext118115_arg0_offset1, %calltext118115_arg0_root0_length
  %calltext118115_arg0_suffix_target = getelementptr i8, ptr %calltext118115_arg0_buffer, i64 %calltext118115_arg0_offset2
  %calltext118115_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118114, i64 26
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118115_arg0_suffix_target, ptr %calltext118115_arg0_suffix_source, i64 0, i1 false)
  %calltext118115_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118115_arg0_buffer, 0
  %calltext118115_arg0 = insertvalue %sollang.text %calltext118115_arg0_value0, i64 %calltext118115_arg0_length1, 1
  %v118115 = call i64 @sollang_m144_s0(%sollang.text %calltext118115_arg0)
  call void @sollang_runtime_print_i64(i64 %v118115, i1 false, i1 true)
  br label %each118109_continue
each118109_continue:
  %each118109_current = load i64, ptr %each118109_index_slot, align 8
  %each118109_next = add i64 %each118109_current, 1
  store i64 %each118109_next, ptr %each118109_index_slot, align 8
  br label %each118109_header
each118109_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
