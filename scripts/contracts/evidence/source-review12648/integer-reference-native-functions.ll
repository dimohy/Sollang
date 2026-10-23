define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define void @sollang_m144_s1(ptr %arg) {
entry:
  %each118111_index_slot = alloca i64, align 8
  %each118111_limit_slot = alloca i64, align 8
  %calltext118117_arg0_root0_buffer = alloca [21 x i8], align 1
  %v118112_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118112 = insertvalue { i32, i32 } %v118112_start, i32 1, 1
  %each118111_range = freeze { i32, i32 } %v118112
  %each118111_first = extractvalue { i32, i32 } %each118111_range, 0
  %each118111_last = extractvalue { i32, i32 } %each118111_range, 1
  %each118111_start = sext i32 %each118111_first to i64
  %each118111_limit = sext i32 %each118111_last to i64
  store i64 %each118111_start, ptr %each118111_index_slot, align 8
  store i64 %each118111_limit, ptr %each118111_limit_slot, align 8
  br label %each118111_header
each118111_header:
  %each118111_index = load i64, ptr %each118111_index_slot, align 8
  %each118111_bound = load i64, ptr %each118111_limit_slot, align 8
  %each118111_done = icmp sgt i64 %each118111_index, %each118111_bound
  br i1 %each118111_done, label %each118111_exit, label %each118111_body
each118111_body:
  %each118111_item = trunc i64 %each118111_index to i32
  %v118116_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118116, 0
  %v118116 = insertvalue %sollang.text %v118116_ptr, i64 8, 1
  %v118117_expression0_reference_value = load i32, ptr %arg, align 4
  %calltext118117_arg0_root0_integer = sext i32 %v118117_expression0_reference_value to i64
  %calltext118117_arg0_root0_length = call i64 @sollang_format_i64(ptr %calltext118117_arg0_root0_buffer, i64 %calltext118117_arg0_root0_integer)
  %calltext118117_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118117_arg0_root0_buffer, i64 0, i64 0
  %calltext118117_arg0_length0 = add i64 0, 0
  %calltext118117_arg0_length1 = add i64 %calltext118117_arg0_length0, %calltext118117_arg0_root0_length
  %calltext118117_arg0_length1_ok = icmp uge i64 %calltext118117_arg0_length1, %calltext118117_arg0_length0
  br i1 %calltext118117_arg0_length1_ok, label %calltext118117_arg0_length1_ready, label %calltext118117_arg0_length1_overflow
calltext118117_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118117_arg0_length1_ready:
  %calltext118117_arg0_empty = icmp eq i64 %calltext118117_arg0_length1, 0
  %calltext118117_arg0_allocation_length = select i1 %calltext118117_arg0_empty, i64 1, i64 %calltext118117_arg0_length1
  %calltext118117_arg0_buffer = alloca i8, i64 %calltext118117_arg0_allocation_length, align 1
  %calltext118117_arg0_offset0 = add i64 0, 0
  %calltext118117_arg0_literal0_target = getelementptr i8, ptr %calltext118117_arg0_buffer, i64 %calltext118117_arg0_offset0
  %calltext118117_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118116, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118117_arg0_literal0_target, ptr %calltext118117_arg0_literal0_source, i64 0, i1 false)
  %calltext118117_arg0_offset1 = add i64 %calltext118117_arg0_offset0, 0
  %calltext118117_arg0_root0_target = getelementptr i8, ptr %calltext118117_arg0_buffer, i64 %calltext118117_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118117_arg0_root0_target, ptr %calltext118117_arg0_root0_ptr, i64 %calltext118117_arg0_root0_length, i1 false)
  %calltext118117_arg0_offset2 = add i64 %calltext118117_arg0_offset1, %calltext118117_arg0_root0_length
  %calltext118117_arg0_suffix_target = getelementptr i8, ptr %calltext118117_arg0_buffer, i64 %calltext118117_arg0_offset2
  %calltext118117_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118116, i64 8
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118117_arg0_suffix_target, ptr %calltext118117_arg0_suffix_source, i64 0, i1 false)
  %calltext118117_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118117_arg0_buffer, 0
  %calltext118117_arg0 = insertvalue %sollang.text %calltext118117_arg0_value0, i64 %calltext118117_arg0_length1, 1
  %v118117 = call i64 @sollang_m144_s0(%sollang.text %calltext118117_arg0)
  call void @sollang_runtime_print_i64(i64 %v118117, i1 false, i1 true)
  br label %each118111_continue
each118111_continue:
  %each118111_current = load i64, ptr %each118111_index_slot, align 8
  %each118111_next = add i64 %each118111_current, 1
  store i64 %each118111_next, ptr %each118111_index_slot, align 8
  br label %each118111_header
each118111_exit:
  ret void
}

define i32 @main() {
entry:
  %callref118122_arg0 = alloca i32, align 4
  %v118120 = sub i32 0, 17
  %v118123 = freeze i32 %v118120
  store i32 %v118123, ptr %callref118122_arg0, align 4
  %callref118122_arg0_address = getelementptr i8, ptr %callref118122_arg0, i64 0
  call void @sollang_m144_s1(ptr %callref118122_arg0_address)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
