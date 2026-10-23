define i64 @sollang_m144_s0(%sollang.text %arg, %sollang.text %arg1) {
entry:
  %v118112 = freeze %sollang.text %arg1
  %v118109 = extractvalue %sollang.text %arg, 1
  %v118111 = extractvalue %sollang.text %arg1, 1
  %v118114 = freeze i64 %v118109
  %v118115 = freeze i64 %v118111
  %v118113 = add i64 %v118114, %v118115
  ret i64 %v118113
}

define i32 @main() {
entry:
  %each118117_index_slot = alloca i64, align 8
  %each118117_limit_slot = alloca i64, align 8
  %v118118_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118118 = insertvalue { i32, i32 } %v118118_start, i32 1, 1
  %each118117_range = freeze { i32, i32 } %v118118
  %each118117_first = extractvalue { i32, i32 } %each118117_range, 0
  %each118117_last = extractvalue { i32, i32 } %each118117_range, 1
  %each118117_start = sext i32 %each118117_first to i64
  %each118117_limit = sext i32 %each118117_last to i64
  store i64 %each118117_start, ptr %each118117_index_slot, align 8
  store i64 %each118117_limit, ptr %each118117_limit_slot, align 8
  br label %each118117_header
each118117_header:
  %each118117_index = load i64, ptr %each118117_index_slot, align 8
  %each118117_bound = load i64, ptr %each118117_limit_slot, align 8
  %each118117_done = icmp sgt i64 %each118117_index, %each118117_bound
  br i1 %each118117_done, label %each118117_exit, label %each118117_body
each118117_body:
  %each118117_item = trunc i64 %each118117_index to i32
  %each_role_m144_s6 = freeze i32 %each118117_item
  %v118123_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118123, 0
  %v118123 = insertvalue %sollang.text %v118123_ptr, i64 8, 1
  %v118124_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118124, 0
  %v118124 = insertvalue %sollang.text %v118124_ptr, i64 15, 1
  %calltext118122_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118122_arg0_root0_integer = sext i32 %each_role_m144_s6 to i64
  %calltext118122_arg0_root0_length = call i64 @sollang_format_i64(ptr %calltext118122_arg0_root0_buffer, i64 %calltext118122_arg0_root0_integer)
  %calltext118122_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118122_arg0_root0_buffer, i64 0, i64 0
  %calltext118122_arg0_length0 = add i64 0, 0
  %calltext118122_arg0_length1 = add i64 %calltext118122_arg0_length0, %calltext118122_arg0_root0_length
  %calltext118122_arg0_length1_ok = icmp uge i64 %calltext118122_arg0_length1, %calltext118122_arg0_length0
  br i1 %calltext118122_arg0_length1_ok, label %calltext118122_arg0_length1_ready, label %calltext118122_arg0_length1_overflow
calltext118122_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118122_arg0_length1_ready:
  %calltext118122_arg0_empty = icmp eq i64 %calltext118122_arg0_length1, 0
  %calltext118122_arg0_allocation_length = select i1 %calltext118122_arg0_empty, i64 1, i64 %calltext118122_arg0_length1
  %calltext118122_arg0_buffer = alloca i8, i64 %calltext118122_arg0_allocation_length, align 1
  %calltext118122_arg0_offset0 = add i64 0, 0
  %calltext118122_arg0_literal0_target = getelementptr i8, ptr %calltext118122_arg0_buffer, i64 %calltext118122_arg0_offset0
  %calltext118122_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118123, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118122_arg0_literal0_target, ptr %calltext118122_arg0_literal0_source, i64 0, i1 false)
  %calltext118122_arg0_offset1 = add i64 %calltext118122_arg0_offset0, 0
  %calltext118122_arg0_root0_target = getelementptr i8, ptr %calltext118122_arg0_buffer, i64 %calltext118122_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118122_arg0_root0_target, ptr %calltext118122_arg0_root0_ptr, i64 %calltext118122_arg0_root0_length, i1 false)
  %calltext118122_arg0_offset2 = add i64 %calltext118122_arg0_offset1, %calltext118122_arg0_root0_length
  %calltext118122_arg0_suffix_target = getelementptr i8, ptr %calltext118122_arg0_buffer, i64 %calltext118122_arg0_offset2
  %calltext118122_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118123, i64 8
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118122_arg0_suffix_target, ptr %calltext118122_arg0_suffix_source, i64 0, i1 false)
  %calltext118122_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118122_arg0_buffer, 0
  %calltext118122_arg0 = insertvalue %sollang.text %calltext118122_arg0_value0, i64 %calltext118122_arg0_length1, 1
  %v118122_expression1 = add i32 %each_role_m144_s6, 10
  %calltext118122_arg1_root0_buffer = alloca [21 x i8], align 1
  %calltext118122_arg1_root0_integer = sext i32 %v118122_expression1 to i64
  %calltext118122_arg1_root0_length = call i64 @sollang_format_i64(ptr %calltext118122_arg1_root0_buffer, i64 %calltext118122_arg1_root0_integer)
  %calltext118122_arg1_root0_ptr = getelementptr [21 x i8], ptr %calltext118122_arg1_root0_buffer, i64 0, i64 0
  %calltext118122_arg1_length0 = add i64 0, 2
  %calltext118122_arg1_length1 = add i64 %calltext118122_arg1_length0, %calltext118122_arg1_root0_length
  %calltext118122_arg1_length1_ok = icmp uge i64 %calltext118122_arg1_length1, %calltext118122_arg1_length0
  br i1 %calltext118122_arg1_length1_ok, label %calltext118122_arg1_length1_ready, label %calltext118122_arg1_length1_overflow
calltext118122_arg1_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118122_arg1_length1_ready:
  %calltext118122_arg1_empty = icmp eq i64 %calltext118122_arg1_length1, 0
  %calltext118122_arg1_allocation_length = select i1 %calltext118122_arg1_empty, i64 1, i64 %calltext118122_arg1_length1
  %calltext118122_arg1_buffer = alloca i8, i64 %calltext118122_arg1_allocation_length, align 1
  %calltext118122_arg1_offset0 = add i64 0, 0
  %calltext118122_arg1_literal0_target = getelementptr i8, ptr %calltext118122_arg1_buffer, i64 %calltext118122_arg1_offset0
  %calltext118122_arg1_literal0_source = getelementptr i8, ptr @sollang_str_118124, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118122_arg1_literal0_target, ptr %calltext118122_arg1_literal0_source, i64 2, i1 false)
  %calltext118122_arg1_offset1 = add i64 %calltext118122_arg1_offset0, 2
  %calltext118122_arg1_root0_target = getelementptr i8, ptr %calltext118122_arg1_buffer, i64 %calltext118122_arg1_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118122_arg1_root0_target, ptr %calltext118122_arg1_root0_ptr, i64 %calltext118122_arg1_root0_length, i1 false)
  %calltext118122_arg1_offset2 = add i64 %calltext118122_arg1_offset1, %calltext118122_arg1_root0_length
  %calltext118122_arg1_suffix_target = getelementptr i8, ptr %calltext118122_arg1_buffer, i64 %calltext118122_arg1_offset2
  %calltext118122_arg1_suffix_source = getelementptr i8, ptr @sollang_str_118124, i64 15
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118122_arg1_suffix_target, ptr %calltext118122_arg1_suffix_source, i64 0, i1 false)
  %calltext118122_arg1_value0 = insertvalue %sollang.text poison, ptr %calltext118122_arg1_buffer, 0
  %calltext118122_arg1 = insertvalue %sollang.text %calltext118122_arg1_value0, i64 %calltext118122_arg1_length1, 1
  %v118122 = call i64 @sollang_m144_s0(%sollang.text %calltext118122_arg0, %sollang.text %calltext118122_arg1)
  call void @sollang_runtime_print_i64(i64 %v118122, i1 false, i1 true)
  br label %each118117_continue
each118117_continue:
  %each118117_current = load i64, ptr %each118117_index_slot, align 8
  %each118117_next = add i64 %each118117_current, 1
  store i64 %each118117_next, ptr %each118117_index_slot, align 8
  br label %each118117_header
each118117_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
