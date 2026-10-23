define i32 @main() {
entry:
  %each118105_index_slot = alloca i64, align 8
  %each118105_limit_slot = alloca i64, align 8
  %v118106_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118106 = insertvalue { i32, i32 } %v118106_start, i32 1, 1
  %each118105_range = freeze { i32, i32 } %v118106
  %each118105_first = extractvalue { i32, i32 } %each118105_range, 0
  %each118105_last = extractvalue { i32, i32 } %each118105_range, 1
  %each118105_start = sext i32 %each118105_first to i64
  %each118105_limit = sext i32 %each118105_last to i64
  store i64 %each118105_start, ptr %each118105_index_slot, align 8
  store i64 %each118105_limit, ptr %each118105_limit_slot, align 8
  br label %each118105_header
each118105_header:
  %each118105_index = load i64, ptr %each118105_index_slot, align 8
  %each118105_bound = load i64, ptr %each118105_limit_slot, align 8
  %each118105_done = icmp sgt i64 %each118105_index, %each118105_bound
  br i1 %each118105_done, label %each118105_exit, label %each118105_body
each118105_body:
  %each118105_item = trunc i64 %each118105_index to i32
  %each_role_m144_s2 = freeze i32 %each118105_item
  %v118110_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118110, 0
  %v118110 = insertvalue %sollang.text %v118110_ptr, i64 8, 1
  %calltext118109_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118109_arg0_root0_integer = sext i32 %each_role_m144_s2 to i64
  %calltext118109_arg0_root0_length = call i64 @sollang_format_i64(ptr %calltext118109_arg0_root0_buffer, i64 %calltext118109_arg0_root0_integer)
  %calltext118109_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118109_arg0_root0_buffer, i64 0, i64 0
  %calltext118109_arg0_length0 = add i64 0, 0
  %calltext118109_arg0_length1 = add i64 %calltext118109_arg0_length0, %calltext118109_arg0_root0_length
  %calltext118109_arg0_length1_ok = icmp uge i64 %calltext118109_arg0_length1, %calltext118109_arg0_length0
  br i1 %calltext118109_arg0_length1_ok, label %calltext118109_arg0_length1_ready, label %calltext118109_arg0_length1_overflow
calltext118109_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118109_arg0_length1_ready:
  %calltext118109_arg0_empty = icmp eq i64 %calltext118109_arg0_length1, 0
  %calltext118109_arg0_allocation_length = select i1 %calltext118109_arg0_empty, i64 1, i64 %calltext118109_arg0_length1
  %calltext118109_arg0_buffer = alloca i8, i64 %calltext118109_arg0_allocation_length, align 1
  %calltext118109_arg0_offset0 = add i64 0, 0
  %calltext118109_arg0_literal0_target = getelementptr i8, ptr %calltext118109_arg0_buffer, i64 %calltext118109_arg0_offset0
  %calltext118109_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118110, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118109_arg0_literal0_target, ptr %calltext118109_arg0_literal0_source, i64 0, i1 false)
  %calltext118109_arg0_offset1 = add i64 %calltext118109_arg0_offset0, 0
  %calltext118109_arg0_root0_target = getelementptr i8, ptr %calltext118109_arg0_buffer, i64 %calltext118109_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118109_arg0_root0_target, ptr %calltext118109_arg0_root0_ptr, i64 %calltext118109_arg0_root0_length, i1 false)
  %calltext118109_arg0_offset2 = add i64 %calltext118109_arg0_offset1, %calltext118109_arg0_root0_length
  %calltext118109_arg0_suffix_target = getelementptr i8, ptr %calltext118109_arg0_buffer, i64 %calltext118109_arg0_offset2
  %calltext118109_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118110, i64 8
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118109_arg0_suffix_target, ptr %calltext118109_arg0_suffix_source, i64 0, i1 false)
  %calltext118109_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118109_arg0_buffer, 0
  %calltext118109_arg0 = insertvalue %sollang.text %calltext118109_arg0_value0, i64 %calltext118109_arg0_length1, 1
  %v118111_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118111, 0
  %v118111 = insertvalue %sollang.text %v118111_ptr, i64 12, 1
  %v118109_expression1 = add i32 %each_role_m144_s2, 1
  %calltext118109_arg1_root0_buffer = alloca [21 x i8], align 1
  %calltext118109_arg1_root0_integer = sext i32 %v118109_expression1 to i64
  %calltext118109_arg1_root0_length = call i64 @sollang_format_i64(ptr %calltext118109_arg1_root0_buffer, i64 %calltext118109_arg1_root0_integer)
  %calltext118109_arg1_root0_ptr = getelementptr [21 x i8], ptr %calltext118109_arg1_root0_buffer, i64 0, i64 0
  %calltext118109_arg1_length0 = add i64 0, 0
  %calltext118109_arg1_length1 = add i64 %calltext118109_arg1_length0, %calltext118109_arg1_root0_length
  %calltext118109_arg1_length1_ok = icmp uge i64 %calltext118109_arg1_length1, %calltext118109_arg1_length0
  br i1 %calltext118109_arg1_length1_ok, label %calltext118109_arg1_length1_ready, label %calltext118109_arg1_length1_overflow
calltext118109_arg1_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118109_arg1_length1_ready:
  %calltext118109_arg1_empty = icmp eq i64 %calltext118109_arg1_length1, 0
  %calltext118109_arg1_allocation_length = select i1 %calltext118109_arg1_empty, i64 1, i64 %calltext118109_arg1_length1
  %calltext118109_arg1_buffer = alloca i8, i64 %calltext118109_arg1_allocation_length, align 1
  %calltext118109_arg1_offset0 = add i64 0, 0
  %calltext118109_arg1_literal0_target = getelementptr i8, ptr %calltext118109_arg1_buffer, i64 %calltext118109_arg1_offset0
  %calltext118109_arg1_literal0_source = getelementptr i8, ptr @sollang_str_118111, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118109_arg1_literal0_target, ptr %calltext118109_arg1_literal0_source, i64 0, i1 false)
  %calltext118109_arg1_offset1 = add i64 %calltext118109_arg1_offset0, 0
  %calltext118109_arg1_root0_target = getelementptr i8, ptr %calltext118109_arg1_buffer, i64 %calltext118109_arg1_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118109_arg1_root0_target, ptr %calltext118109_arg1_root0_ptr, i64 %calltext118109_arg1_root0_length, i1 false)
  %calltext118109_arg1_offset2 = add i64 %calltext118109_arg1_offset1, %calltext118109_arg1_root0_length
  %calltext118109_arg1_suffix_target = getelementptr i8, ptr %calltext118109_arg1_buffer, i64 %calltext118109_arg1_offset2
  %calltext118109_arg1_suffix_source = getelementptr i8, ptr @sollang_str_118111, i64 12
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118109_arg1_suffix_target, ptr %calltext118109_arg1_suffix_source, i64 0, i1 false)
  %calltext118109_arg1_value0 = insertvalue %sollang.text poison, ptr %calltext118109_arg1_buffer, 0
  %calltext118109_arg1 = insertvalue %sollang.text %calltext118109_arg1_value0, i64 %calltext118109_arg1_length1, 1
  %v118109 = call i1 @sollang_text_equal(%sollang.text %calltext118109_arg0, %sollang.text %calltext118109_arg1)
  %v118113 = freeze i1 %v118109
  call void @sollang_runtime_print_i1(i1 %v118113, i1 true)
  br label %each118105_continue
each118105_continue:
  %each118105_current = load i64, ptr %each118105_index_slot, align 8
  %each118105_next = add i64 %each118105_current, 1
  store i64 %each118105_next, ptr %each118105_index_slot, align 8
  br label %each118105_header
each118105_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
