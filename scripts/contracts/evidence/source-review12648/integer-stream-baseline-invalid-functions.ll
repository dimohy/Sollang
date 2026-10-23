define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define i32 @main() {
entry:
  %stream118109_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118109_index_slot, align 4
  %stream118109_end = add i32 1, 0
  br label %stream118109_header
stream118109_header:
  %stream118109_item = load i32, ptr %stream118109_index_slot, align 4
  %stream118109_done = icmp sgt i32 %stream118109_item, %stream118109_end
  br i1 %stream118109_done, label %stream118109_exit, label %stream118109_body
stream118109_body:
  %v118114 = freeze i32 %stream118109_item
  %v118113 = add i32 %v118114, 10
  %v118117_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118117, 0
  %v118117 = insertvalue %sollang.text %v118117_ptr, i64 9, 1
  %calltext118118_arg0_root0_ptr = extractvalue %sollang.text %stream118109_item, 0
  %calltext118118_arg0_root0_length = extractvalue %sollang.text %stream118109_item, 1
  %calltext118118_arg0_length0 = add i64 0, 0
  %calltext118118_arg0_length1 = add i64 %calltext118118_arg0_length0, %calltext118118_arg0_root0_length
  %calltext118118_arg0_length1_ok = icmp uge i64 %calltext118118_arg0_length1, %calltext118118_arg0_length0
  br i1 %calltext118118_arg0_length1_ok, label %calltext118118_arg0_length1_ready, label %calltext118118_arg0_length1_overflow
calltext118118_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118118_arg0_length1_ready:
  %calltext118118_arg0_empty = icmp eq i64 %calltext118118_arg0_length1, 0
  %calltext118118_arg0_allocation_length = select i1 %calltext118118_arg0_empty, i64 1, i64 %calltext118118_arg0_length1
  %calltext118118_arg0_buffer = alloca i8, i64 %calltext118118_arg0_allocation_length, align 1
  %calltext118118_arg0_offset0 = add i64 0, 0
  %calltext118118_arg0_literal0_target = getelementptr i8, ptr %calltext118118_arg0_buffer, i64 %calltext118118_arg0_offset0
  %calltext118118_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118117, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118118_arg0_literal0_target, ptr %calltext118118_arg0_literal0_source, i64 0, i1 false)
  %calltext118118_arg0_offset1 = add i64 %calltext118118_arg0_offset0, 0
  %calltext118118_arg0_root0_target = getelementptr i8, ptr %calltext118118_arg0_buffer, i64 %calltext118118_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118118_arg0_root0_target, ptr %calltext118118_arg0_root0_ptr, i64 %calltext118118_arg0_root0_length, i1 false)
  %calltext118118_arg0_offset2 = add i64 %calltext118118_arg0_offset1, %calltext118118_arg0_root0_length
  %calltext118118_arg0_suffix_target = getelementptr i8, ptr %calltext118118_arg0_buffer, i64 %calltext118118_arg0_offset2
  %calltext118118_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118117, i64 9
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118118_arg0_suffix_target, ptr %calltext118118_arg0_suffix_source, i64 0, i1 false)
  %calltext118118_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118118_arg0_buffer, 0
  %calltext118118_arg0 = insertvalue %sollang.text %calltext118118_arg0_value0, i64 %calltext118118_arg0_length1, 1
  %v118118 = call i64 @sollang_m144_s0(%sollang.text %calltext118118_arg0)
  call void @sollang_runtime_print_i64(i64 %v118118, i1 false, i1 true)
  br label %stream118109_continue
stream118109_continue:
  %stream118109_current = load i32, ptr %stream118109_index_slot, align 4
  %stream118109_last = icmp sge i32 %stream118109_current, %stream118109_end
  %stream118109_next = add i32 %stream118109_current, 1
  store i32 %stream118109_next, ptr %stream118109_index_slot, align 4
  br i1 %stream118109_last, label %stream118109_exit, label %stream118109_header
stream118109_exit:
  %v118110_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118110 = insertvalue { i32, i32 } %v118110_start, i32 1, 1
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
