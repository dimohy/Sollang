define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define i32 @main() {
entry:
  %each118123_index_slot = alloca i64, align 8
  %each118123_limit_slot = alloca i64, align 8
  %calltext118135_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118136_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118137_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118138_arg0_root0_buffer = alloca [21 x i8], align 1
  %v118114 = sub i8 0, 128
  %v118113 = add i8 %v118114, 0
  %v118116 = add i8 255, 0
  %v118119 = sub i64 0, 9223372036854775808
  %v118118 = add i64 %v118119, 0
  %v118121 = add i64 18446744073709551615, 0
  %v118124_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118124 = insertvalue { i32, i32 } %v118124_start, i32 1, 1
  %each118123_range = freeze { i32, i32 } %v118124
  %each118123_first = extractvalue { i32, i32 } %each118123_range, 0
  %each118123_last = extractvalue { i32, i32 } %each118123_range, 1
  %each118123_start = sext i32 %each118123_first to i64
  %each118123_limit = sext i32 %each118123_last to i64
  store i64 %each118123_start, ptr %each118123_index_slot, align 8
  store i64 %each118123_limit, ptr %each118123_limit_slot, align 8
  br label %each118123_header
each118123_header:
  %each118123_index = load i64, ptr %each118123_index_slot, align 8
  %each118123_bound = load i64, ptr %each118123_limit_slot, align 8
  %each118123_done = icmp sgt i64 %each118123_index, %each118123_bound
  br i1 %each118123_done, label %each118123_exit, label %each118123_body
each118123_body:
  %each118123_item = trunc i64 %each118123_index to i32
  %v118128_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118128, 0
  %v118128 = insertvalue %sollang.text %v118128_ptr, i64 9, 1
  %calltext118135_arg0_root0_integer = sext i8 %v118113 to i64
  %calltext118135_arg0_root0_length = call i64 @sollang_format_i64(ptr %calltext118135_arg0_root0_buffer, i64 %calltext118135_arg0_root0_integer)
  %calltext118135_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118135_arg0_root0_buffer, i64 0, i64 0
  %calltext118135_arg0_length0 = add i64 0, 0
  %calltext118135_arg0_length1 = add i64 %calltext118135_arg0_length0, %calltext118135_arg0_root0_length
  %calltext118135_arg0_length1_ok = icmp uge i64 %calltext118135_arg0_length1, %calltext118135_arg0_length0
  br i1 %calltext118135_arg0_length1_ok, label %calltext118135_arg0_length1_ready, label %calltext118135_arg0_length1_overflow
calltext118135_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118135_arg0_length1_ready:
  %calltext118135_arg0_empty = icmp eq i64 %calltext118135_arg0_length1, 0
  %calltext118135_arg0_allocation_length = select i1 %calltext118135_arg0_empty, i64 1, i64 %calltext118135_arg0_length1
  %calltext118135_arg0_buffer = alloca i8, i64 %calltext118135_arg0_allocation_length, align 1
  %calltext118135_arg0_offset0 = add i64 0, 0
  %calltext118135_arg0_literal0_target = getelementptr i8, ptr %calltext118135_arg0_buffer, i64 %calltext118135_arg0_offset0
  %calltext118135_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118128, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118135_arg0_literal0_target, ptr %calltext118135_arg0_literal0_source, i64 0, i1 false)
  %calltext118135_arg0_offset1 = add i64 %calltext118135_arg0_offset0, 0
  %calltext118135_arg0_root0_target = getelementptr i8, ptr %calltext118135_arg0_buffer, i64 %calltext118135_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118135_arg0_root0_target, ptr %calltext118135_arg0_root0_ptr, i64 %calltext118135_arg0_root0_length, i1 false)
  %calltext118135_arg0_offset2 = add i64 %calltext118135_arg0_offset1, %calltext118135_arg0_root0_length
  %calltext118135_arg0_suffix_target = getelementptr i8, ptr %calltext118135_arg0_buffer, i64 %calltext118135_arg0_offset2
  %calltext118135_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118128, i64 9
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118135_arg0_suffix_target, ptr %calltext118135_arg0_suffix_source, i64 0, i1 false)
  %calltext118135_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118135_arg0_buffer, 0
  %calltext118135_arg0 = insertvalue %sollang.text %calltext118135_arg0_value0, i64 %calltext118135_arg0_length1, 1
  %v118135 = call i64 @sollang_m144_s0(%sollang.text %calltext118135_arg0)
  call void @sollang_runtime_print_i64(i64 %v118135, i1 false, i1 true)
  %v118130_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118130, 0
  %v118130 = insertvalue %sollang.text %v118130_ptr, i64 12, 1
  %calltext118136_arg0_root0_integer = zext i8 %v118116 to i64
  %calltext118136_arg0_root0_length = call i64 @sollang_format_u64(ptr %calltext118136_arg0_root0_buffer, i64 %calltext118136_arg0_root0_integer)
  %calltext118136_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118136_arg0_root0_buffer, i64 0, i64 0
  %calltext118136_arg0_length0 = add i64 0, 0
  %calltext118136_arg0_length1 = add i64 %calltext118136_arg0_length0, %calltext118136_arg0_root0_length
  %calltext118136_arg0_length1_ok = icmp uge i64 %calltext118136_arg0_length1, %calltext118136_arg0_length0
  br i1 %calltext118136_arg0_length1_ok, label %calltext118136_arg0_length1_ready, label %calltext118136_arg0_length1_overflow
calltext118136_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118136_arg0_length1_ready:
  %calltext118136_arg0_empty = icmp eq i64 %calltext118136_arg0_length1, 0
  %calltext118136_arg0_allocation_length = select i1 %calltext118136_arg0_empty, i64 1, i64 %calltext118136_arg0_length1
  %calltext118136_arg0_buffer = alloca i8, i64 %calltext118136_arg0_allocation_length, align 1
  %calltext118136_arg0_offset0 = add i64 0, 0
  %calltext118136_arg0_literal0_target = getelementptr i8, ptr %calltext118136_arg0_buffer, i64 %calltext118136_arg0_offset0
  %calltext118136_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118130, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118136_arg0_literal0_target, ptr %calltext118136_arg0_literal0_source, i64 0, i1 false)
  %calltext118136_arg0_offset1 = add i64 %calltext118136_arg0_offset0, 0
  %calltext118136_arg0_root0_target = getelementptr i8, ptr %calltext118136_arg0_buffer, i64 %calltext118136_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118136_arg0_root0_target, ptr %calltext118136_arg0_root0_ptr, i64 %calltext118136_arg0_root0_length, i1 false)
  %calltext118136_arg0_offset2 = add i64 %calltext118136_arg0_offset1, %calltext118136_arg0_root0_length
  %calltext118136_arg0_suffix_target = getelementptr i8, ptr %calltext118136_arg0_buffer, i64 %calltext118136_arg0_offset2
  %calltext118136_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118130, i64 12
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118136_arg0_suffix_target, ptr %calltext118136_arg0_suffix_source, i64 0, i1 false)
  %calltext118136_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118136_arg0_buffer, 0
  %calltext118136_arg0 = insertvalue %sollang.text %calltext118136_arg0_value0, i64 %calltext118136_arg0_length1, 1
  %v118136 = call i64 @sollang_m144_s0(%sollang.text %calltext118136_arg0)
  call void @sollang_runtime_print_i64(i64 %v118136, i1 false, i1 true)
  %v118132_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118132, 0
  %v118132 = insertvalue %sollang.text %v118132_ptr, i64 9, 1
  %calltext118137_arg0_root0_length = call i64 @sollang_format_i64(ptr %calltext118137_arg0_root0_buffer, i64 %v118118)
  %calltext118137_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118137_arg0_root0_buffer, i64 0, i64 0
  %calltext118137_arg0_length0 = add i64 0, 0
  %calltext118137_arg0_length1 = add i64 %calltext118137_arg0_length0, %calltext118137_arg0_root0_length
  %calltext118137_arg0_length1_ok = icmp uge i64 %calltext118137_arg0_length1, %calltext118137_arg0_length0
  br i1 %calltext118137_arg0_length1_ok, label %calltext118137_arg0_length1_ready, label %calltext118137_arg0_length1_overflow
calltext118137_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118137_arg0_length1_ready:
  %calltext118137_arg0_empty = icmp eq i64 %calltext118137_arg0_length1, 0
  %calltext118137_arg0_allocation_length = select i1 %calltext118137_arg0_empty, i64 1, i64 %calltext118137_arg0_length1
  %calltext118137_arg0_buffer = alloca i8, i64 %calltext118137_arg0_allocation_length, align 1
  %calltext118137_arg0_offset0 = add i64 0, 0
  %calltext118137_arg0_literal0_target = getelementptr i8, ptr %calltext118137_arg0_buffer, i64 %calltext118137_arg0_offset0
  %calltext118137_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118132, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118137_arg0_literal0_target, ptr %calltext118137_arg0_literal0_source, i64 0, i1 false)
  %calltext118137_arg0_offset1 = add i64 %calltext118137_arg0_offset0, 0
  %calltext118137_arg0_root0_target = getelementptr i8, ptr %calltext118137_arg0_buffer, i64 %calltext118137_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118137_arg0_root0_target, ptr %calltext118137_arg0_root0_ptr, i64 %calltext118137_arg0_root0_length, i1 false)
  %calltext118137_arg0_offset2 = add i64 %calltext118137_arg0_offset1, %calltext118137_arg0_root0_length
  %calltext118137_arg0_suffix_target = getelementptr i8, ptr %calltext118137_arg0_buffer, i64 %calltext118137_arg0_offset2
  %calltext118137_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118132, i64 9
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118137_arg0_suffix_target, ptr %calltext118137_arg0_suffix_source, i64 0, i1 false)
  %calltext118137_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118137_arg0_buffer, 0
  %calltext118137_arg0 = insertvalue %sollang.text %calltext118137_arg0_value0, i64 %calltext118137_arg0_length1, 1
  %v118137 = call i64 @sollang_m144_s0(%sollang.text %calltext118137_arg0)
  call void @sollang_runtime_print_i64(i64 %v118137, i1 false, i1 true)
  %v118134_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118134, 0
  %v118134 = insertvalue %sollang.text %v118134_ptr, i64 11, 1
  %calltext118138_arg0_root0_length = call i64 @sollang_format_u64(ptr %calltext118138_arg0_root0_buffer, i64 %v118121)
  %calltext118138_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118138_arg0_root0_buffer, i64 0, i64 0
  %calltext118138_arg0_length0 = add i64 0, 0
  %calltext118138_arg0_length1 = add i64 %calltext118138_arg0_length0, %calltext118138_arg0_root0_length
  %calltext118138_arg0_length1_ok = icmp uge i64 %calltext118138_arg0_length1, %calltext118138_arg0_length0
  br i1 %calltext118138_arg0_length1_ok, label %calltext118138_arg0_length1_ready, label %calltext118138_arg0_length1_overflow
calltext118138_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118138_arg0_length1_ready:
  %calltext118138_arg0_empty = icmp eq i64 %calltext118138_arg0_length1, 0
  %calltext118138_arg0_allocation_length = select i1 %calltext118138_arg0_empty, i64 1, i64 %calltext118138_arg0_length1
  %calltext118138_arg0_buffer = alloca i8, i64 %calltext118138_arg0_allocation_length, align 1
  %calltext118138_arg0_offset0 = add i64 0, 0
  %calltext118138_arg0_literal0_target = getelementptr i8, ptr %calltext118138_arg0_buffer, i64 %calltext118138_arg0_offset0
  %calltext118138_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118134, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118138_arg0_literal0_target, ptr %calltext118138_arg0_literal0_source, i64 0, i1 false)
  %calltext118138_arg0_offset1 = add i64 %calltext118138_arg0_offset0, 0
  %calltext118138_arg0_root0_target = getelementptr i8, ptr %calltext118138_arg0_buffer, i64 %calltext118138_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118138_arg0_root0_target, ptr %calltext118138_arg0_root0_ptr, i64 %calltext118138_arg0_root0_length, i1 false)
  %calltext118138_arg0_offset2 = add i64 %calltext118138_arg0_offset1, %calltext118138_arg0_root0_length
  %calltext118138_arg0_suffix_target = getelementptr i8, ptr %calltext118138_arg0_buffer, i64 %calltext118138_arg0_offset2
  %calltext118138_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118134, i64 11
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118138_arg0_suffix_target, ptr %calltext118138_arg0_suffix_source, i64 0, i1 false)
  %calltext118138_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118138_arg0_buffer, 0
  %calltext118138_arg0 = insertvalue %sollang.text %calltext118138_arg0_value0, i64 %calltext118138_arg0_length1, 1
  %v118138 = call i64 @sollang_m144_s0(%sollang.text %calltext118138_arg0)
  call void @sollang_runtime_print_i64(i64 %v118138, i1 false, i1 true)
  br label %each118123_continue
each118123_continue:
  %each118123_current = load i64, ptr %each118123_index_slot, align 8
  %each118123_next = add i64 %each118123_current, 1
  store i64 %each118123_next, ptr %each118123_index_slot, align 8
  br label %each118123_header
each118123_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
