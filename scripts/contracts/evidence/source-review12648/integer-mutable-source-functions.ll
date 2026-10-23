define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define i32 @main() {
entry:
  %each118112_index_slot = alloca i64, align 8
  %each118112_limit_slot = alloca i64, align 8
  %calltext118121_arg0_root0_buffer = alloca [21 x i8], align 1
  %slot118109 = alloca i32, align 4
  store i32 0, ptr %slot118109, align 4
  %v118113_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118113 = insertvalue { i32, i32 } %v118113_start, i32 1, 1
  %each118112_range = freeze { i32, i32 } %v118113
  %each118112_first = extractvalue { i32, i32 } %each118112_range, 0
  %each118112_last = extractvalue { i32, i32 } %each118112_range, 1
  %each118112_start = sext i32 %each118112_first to i64
  %each118112_limit = sext i32 %each118112_last to i64
  store i64 %each118112_start, ptr %each118112_index_slot, align 8
  store i64 %each118112_limit, ptr %each118112_limit_slot, align 8
  br label %each118112_header
each118112_header:
  %each118112_index = load i64, ptr %each118112_index_slot, align 8
  %each118112_bound = load i64, ptr %each118112_limit_slot, align 8
  %each118112_done = icmp sgt i64 %each118112_index, %each118112_bound
  br i1 %each118112_done, label %each118112_exit, label %each118112_body
each118112_body:
  %each118112_item = trunc i64 %each118112_index to i32
  %v118117_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118117, 0
  %v118117 = insertvalue %sollang.text %v118117_ptr, i64 11, 1
  %v118121_expression0_mutable = load i32, ptr %slot118109, align 8
  %calltext118121_arg0_root0_integer = sext i32 %v118121_expression0_mutable to i64
  %calltext118121_arg0_root0_length = call i64 @sollang_format_i64(ptr %calltext118121_arg0_root0_buffer, i64 %calltext118121_arg0_root0_integer)
  %calltext118121_arg0_root0_ptr = getelementptr [21 x i8], ptr %calltext118121_arg0_root0_buffer, i64 0, i64 0
  %calltext118121_arg0_length0 = add i64 0, 2
  %calltext118121_arg0_length1 = add i64 %calltext118121_arg0_length0, %calltext118121_arg0_root0_length
  %calltext118121_arg0_length1_ok = icmp uge i64 %calltext118121_arg0_length1, %calltext118121_arg0_length0
  br i1 %calltext118121_arg0_length1_ok, label %calltext118121_arg0_length1_ready, label %calltext118121_arg0_length1_overflow
calltext118121_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118121_arg0_length1_ready:
  %calltext118121_arg0_empty = icmp eq i64 %calltext118121_arg0_length1, 0
  %calltext118121_arg0_allocation_length = select i1 %calltext118121_arg0_empty, i64 1, i64 %calltext118121_arg0_length1
  %calltext118121_arg0_buffer = alloca i8, i64 %calltext118121_arg0_allocation_length, align 1
  %calltext118121_arg0_offset0 = add i64 0, 0
  %calltext118121_arg0_literal0_target = getelementptr i8, ptr %calltext118121_arg0_buffer, i64 %calltext118121_arg0_offset0
  %calltext118121_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118117, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118121_arg0_literal0_target, ptr %calltext118121_arg0_literal0_source, i64 2, i1 false)
  %calltext118121_arg0_offset1 = add i64 %calltext118121_arg0_offset0, 2
  %calltext118121_arg0_root0_target = getelementptr i8, ptr %calltext118121_arg0_buffer, i64 %calltext118121_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118121_arg0_root0_target, ptr %calltext118121_arg0_root0_ptr, i64 %calltext118121_arg0_root0_length, i1 false)
  %calltext118121_arg0_offset2 = add i64 %calltext118121_arg0_offset1, %calltext118121_arg0_root0_length
  %calltext118121_arg0_suffix_target = getelementptr i8, ptr %calltext118121_arg0_buffer, i64 %calltext118121_arg0_offset2
  %calltext118121_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118117, i64 11
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118121_arg0_suffix_target, ptr %calltext118121_arg0_suffix_source, i64 0, i1 false)
  %calltext118121_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118121_arg0_buffer, 0
  %calltext118121_arg0 = insertvalue %sollang.text %calltext118121_arg0_value0, i64 %calltext118121_arg0_length1, 1
  %v118121 = call i64 @sollang_m144_s0(%sollang.text %calltext118121_arg0)
  call void @sollang_runtime_print_i64(i64 %v118121, i1 false, i1 true)
  %v118119 = load i32, ptr %slot118109, align 4
  %v118118 = add i32 %v118119, 1
  store i32 %v118118, ptr %slot118109, align 4
  br label %each118112_continue
each118112_continue:
  %each118112_current = load i64, ptr %each118112_index_slot, align 8
  %each118112_next = add i64 %each118112_current, 1
  store i64 %each118112_next, ptr %each118112_index_slot, align 8
  br label %each118112_header
each118112_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
