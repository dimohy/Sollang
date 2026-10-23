define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define i32 @main() {
entry:
  %if118146_result = alloca %sollang.text, align 8
  %stream118109_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118109_index_slot, align 4
  %stream118109_end = add i32 1, 0
  br label %stream118109_header
stream118109_header:
  %stream118109_item = load i32, ptr %stream118109_index_slot, align 4
  %stream118109_done = icmp sgt i32 %stream118109_item, %stream118109_end
  br i1 %stream118109_done, label %stream118109_exit, label %stream118109_body
stream118109_body:
  %v118115 = freeze i32 %stream118109_item
  %v118114 = sub i32 %v118115, 12
  %v118113 = trunc i32 %v118114 to i8
  %v118118_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118118, 0
  %v118118 = insertvalue %sollang.text %v118118_ptr, i64 9, 1
  %calltext118153_arg0_root0_ptr = extractvalue %sollang.text %stream118109_item, 0
  %calltext118153_arg0_root0_length = extractvalue %sollang.text %stream118109_item, 1
  %calltext118153_arg0_length0 = add i64 0, 0
  %calltext118153_arg0_length1 = add i64 %calltext118153_arg0_length0, %calltext118153_arg0_root0_length
  %calltext118153_arg0_length1_ok = icmp uge i64 %calltext118153_arg0_length1, %calltext118153_arg0_length0
  br i1 %calltext118153_arg0_length1_ok, label %calltext118153_arg0_length1_ready, label %calltext118153_arg0_length1_overflow
calltext118153_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118153_arg0_length1_ready:
  %calltext118153_arg0_empty = icmp eq i64 %calltext118153_arg0_length1, 0
  %calltext118153_arg0_allocation_length = select i1 %calltext118153_arg0_empty, i64 1, i64 %calltext118153_arg0_length1
  %calltext118153_arg0_buffer = alloca i8, i64 %calltext118153_arg0_allocation_length, align 1
  %calltext118153_arg0_offset0 = add i64 0, 0
  %calltext118153_arg0_literal0_target = getelementptr i8, ptr %calltext118153_arg0_buffer, i64 %calltext118153_arg0_offset0
  %calltext118153_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118118, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118153_arg0_literal0_target, ptr %calltext118153_arg0_literal0_source, i64 0, i1 false)
  %calltext118153_arg0_offset1 = add i64 %calltext118153_arg0_offset0, 0
  %calltext118153_arg0_root0_target = getelementptr i8, ptr %calltext118153_arg0_buffer, i64 %calltext118153_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118153_arg0_root0_target, ptr %calltext118153_arg0_root0_ptr, i64 %calltext118153_arg0_root0_length, i1 false)
  %calltext118153_arg0_offset2 = add i64 %calltext118153_arg0_offset1, %calltext118153_arg0_root0_length
  %calltext118153_arg0_suffix_target = getelementptr i8, ptr %calltext118153_arg0_buffer, i64 %calltext118153_arg0_offset2
  %calltext118153_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118118, i64 9
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118153_arg0_suffix_target, ptr %calltext118153_arg0_suffix_source, i64 0, i1 false)
  %calltext118153_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118153_arg0_buffer, 0
  %calltext118153_arg0 = insertvalue %sollang.text %calltext118153_arg0_value0, i64 %calltext118153_arg0_length1, 1
  %v118153 = call i64 @sollang_m144_s0(%sollang.text %calltext118153_arg0)
  call void @sollang_runtime_print_i64(i64 %v118153, i1 false, i1 true)
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
  %stream118119_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118119_index_slot, align 4
  %stream118119_end = add i32 1, 0
  br label %stream118119_header
stream118119_header:
  %stream118119_item = load i32, ptr %stream118119_index_slot, align 4
  %stream118119_done = icmp sgt i32 %stream118119_item, %stream118119_end
  br i1 %stream118119_done, label %stream118119_exit, label %stream118119_body
stream118119_body:
  %v118125 = freeze i32 %stream118119_item
  %v118124 = sext i32 %v118125 to i64
  %v118123 = add i64 %v118124, 18446744073709551614
  %v118128_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118128, 0
  %v118128 = insertvalue %sollang.text %v118128_ptr, i64 9, 1
  %calltext118154_arg0_root0_ptr = extractvalue %sollang.text %stream118119_item, 0
  %calltext118154_arg0_root0_length = extractvalue %sollang.text %stream118119_item, 1
  %calltext118154_arg0_length0 = add i64 0, 0
  %calltext118154_arg0_length1 = add i64 %calltext118154_arg0_length0, %calltext118154_arg0_root0_length
  %calltext118154_arg0_length1_ok = icmp uge i64 %calltext118154_arg0_length1, %calltext118154_arg0_length0
  br i1 %calltext118154_arg0_length1_ok, label %calltext118154_arg0_length1_ready, label %calltext118154_arg0_length1_overflow
calltext118154_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118154_arg0_length1_ready:
  %calltext118154_arg0_empty = icmp eq i64 %calltext118154_arg0_length1, 0
  %calltext118154_arg0_allocation_length = select i1 %calltext118154_arg0_empty, i64 1, i64 %calltext118154_arg0_length1
  %calltext118154_arg0_buffer = alloca i8, i64 %calltext118154_arg0_allocation_length, align 1
  %calltext118154_arg0_offset0 = add i64 0, 0
  %calltext118154_arg0_literal0_target = getelementptr i8, ptr %calltext118154_arg0_buffer, i64 %calltext118154_arg0_offset0
  %calltext118154_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118128, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118154_arg0_literal0_target, ptr %calltext118154_arg0_literal0_source, i64 0, i1 false)
  %calltext118154_arg0_offset1 = add i64 %calltext118154_arg0_offset0, 0
  %calltext118154_arg0_root0_target = getelementptr i8, ptr %calltext118154_arg0_buffer, i64 %calltext118154_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118154_arg0_root0_target, ptr %calltext118154_arg0_root0_ptr, i64 %calltext118154_arg0_root0_length, i1 false)
  %calltext118154_arg0_offset2 = add i64 %calltext118154_arg0_offset1, %calltext118154_arg0_root0_length
  %calltext118154_arg0_suffix_target = getelementptr i8, ptr %calltext118154_arg0_buffer, i64 %calltext118154_arg0_offset2
  %calltext118154_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118128, i64 9
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118154_arg0_suffix_target, ptr %calltext118154_arg0_suffix_source, i64 0, i1 false)
  %calltext118154_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118154_arg0_buffer, 0
  %calltext118154_arg0 = insertvalue %sollang.text %calltext118154_arg0_value0, i64 %calltext118154_arg0_length1, 1
  %v118154 = call i64 @sollang_m144_s0(%sollang.text %calltext118154_arg0)
  call void @sollang_runtime_print_i64(i64 %v118154, i1 false, i1 true)
  br label %stream118119_continue
stream118119_continue:
  %stream118119_current = load i32, ptr %stream118119_index_slot, align 4
  %stream118119_last = icmp sge i32 %stream118119_current, %stream118119_end
  %stream118119_next = add i32 %stream118119_current, 1
  store i32 %stream118119_next, ptr %stream118119_index_slot, align 4
  br i1 %stream118119_last, label %stream118119_exit, label %stream118119_header
stream118119_exit:
  %v118120_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118120 = insertvalue { i32, i32 } %v118120_start, i32 1, 1
  %stream118129_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118129_index_slot, align 4
  %stream118129_end = add i32 1, 0
  br label %stream118129_header
stream118129_header:
  %stream118129_item = load i32, ptr %stream118129_index_slot, align 4
  %stream118129_done = icmp sgt i32 %stream118129_item, %stream118129_end
  br i1 %stream118129_done, label %stream118129_exit, label %stream118129_body
stream118129_body:
  %v118134 = freeze i32 %stream118129_item
  %v118133 = icmp sgt i32 %v118134, 0
  %v118137_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118137, 0
  %v118137 = insertvalue %sollang.text %v118137_ptr, i64 7, 1
  %calltext118155_arg0_root0_ptr = extractvalue %sollang.text %stream118129_item, 0
  %calltext118155_arg0_root0_length = extractvalue %sollang.text %stream118129_item, 1
  %calltext118155_arg0_length0 = add i64 0, 0
  %calltext118155_arg0_length1 = add i64 %calltext118155_arg0_length0, %calltext118155_arg0_root0_length
  %calltext118155_arg0_length1_ok = icmp uge i64 %calltext118155_arg0_length1, %calltext118155_arg0_length0
  br i1 %calltext118155_arg0_length1_ok, label %calltext118155_arg0_length1_ready, label %calltext118155_arg0_length1_overflow
calltext118155_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118155_arg0_length1_ready:
  %calltext118155_arg0_empty = icmp eq i64 %calltext118155_arg0_length1, 0
  %calltext118155_arg0_allocation_length = select i1 %calltext118155_arg0_empty, i64 1, i64 %calltext118155_arg0_length1
  %calltext118155_arg0_buffer = alloca i8, i64 %calltext118155_arg0_allocation_length, align 1
  %calltext118155_arg0_offset0 = add i64 0, 0
  %calltext118155_arg0_literal0_target = getelementptr i8, ptr %calltext118155_arg0_buffer, i64 %calltext118155_arg0_offset0
  %calltext118155_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118137, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118155_arg0_literal0_target, ptr %calltext118155_arg0_literal0_source, i64 0, i1 false)
  %calltext118155_arg0_offset1 = add i64 %calltext118155_arg0_offset0, 0
  %calltext118155_arg0_root0_target = getelementptr i8, ptr %calltext118155_arg0_buffer, i64 %calltext118155_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118155_arg0_root0_target, ptr %calltext118155_arg0_root0_ptr, i64 %calltext118155_arg0_root0_length, i1 false)
  %calltext118155_arg0_offset2 = add i64 %calltext118155_arg0_offset1, %calltext118155_arg0_root0_length
  %calltext118155_arg0_suffix_target = getelementptr i8, ptr %calltext118155_arg0_buffer, i64 %calltext118155_arg0_offset2
  %calltext118155_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118137, i64 7
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118155_arg0_suffix_target, ptr %calltext118155_arg0_suffix_source, i64 0, i1 false)
  %calltext118155_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118155_arg0_buffer, 0
  %calltext118155_arg0 = insertvalue %sollang.text %calltext118155_arg0_value0, i64 %calltext118155_arg0_length1, 1
  %v118155 = call i64 @sollang_m144_s0(%sollang.text %calltext118155_arg0)
  call void @sollang_runtime_print_i64(i64 %v118155, i1 false, i1 true)
  br label %stream118129_continue
stream118129_continue:
  %stream118129_current = load i32, ptr %stream118129_index_slot, align 4
  %stream118129_last = icmp sge i32 %stream118129_current, %stream118129_end
  %stream118129_next = add i32 %stream118129_current, 1
  store i32 %stream118129_next, ptr %stream118129_index_slot, align 4
  br i1 %stream118129_last, label %stream118129_exit, label %stream118129_header
stream118129_exit:
  %v118130_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118130 = insertvalue { i32, i32 } %v118130_start, i32 1, 1
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118143 = icmp sgt i32 %v118144, 0
  br i1 %v118143, label %if118146_then, label %if118146_else
if118146_then:
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118148_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118148, 0
  %v118148 = insertvalue %sollang.text %v118148_ptr, i64 2, 1
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  store %sollang.text %v118148, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_else:
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118150_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118150, 0
  %v118150 = insertvalue %sollang.text %v118150_ptr, i64 2, 1
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  store %sollang.text %v118150, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_merge:
  %v118146 = load %sollang.text, ptr %if118146_result, align 8
  %v118148_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118148, 0
  %v118148 = insertvalue %sollang.text %v118148_ptr, i64 2, 1
  br i1 %v118143, label %if118146_then, label %if118146_else
if118146_then:
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118148_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118148, 0
  %v118148 = insertvalue %sollang.text %v118148_ptr, i64 2, 1
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  store %sollang.text %v118148, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_else:
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118150_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118150, 0
  %v118150 = insertvalue %sollang.text %v118150_ptr, i64 2, 1
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  store %sollang.text %v118150, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_merge:
  %v118146 = load %sollang.text, ptr %if118146_result, align 8
  %v118150_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118150, 0
  %v118150 = insertvalue %sollang.text %v118150_ptr, i64 2, 1
  br i1 %v118143, label %if118146_then, label %if118146_else
if118146_then:
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118148_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118148, 0
  %v118148 = insertvalue %sollang.text %v118148_ptr, i64 2, 1
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  store %sollang.text %v118148, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_else:
  %stream118138_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118138_index_slot, align 4
  %stream118138_end = add i32 1, 0
  br label %stream118138_header
stream118138_header:
  %stream118138_item = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_done = icmp sgt i32 %stream118138_item, %stream118138_end
  br i1 %stream118138_done, label %stream118138_exit, label %stream118138_body
stream118138_body:
  %v118144 = freeze i32 %stream118138_item
  %v118150_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118150, 0
  %v118150 = insertvalue %sollang.text %v118150_ptr, i64 2, 1
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  store %sollang.text %v118150, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_merge:
  %v118146 = load %sollang.text, ptr %if118146_result, align 8
  %v118152_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118152, 0
  %v118152 = insertvalue %sollang.text %v118152_ptr, i64 7, 1
  %calltext118156_arg0_root0_ptr = extractvalue %sollang.text %stream118138_item, 0
  %calltext118156_arg0_root0_length = extractvalue %sollang.text %stream118138_item, 1
  %calltext118156_arg0_length0 = add i64 0, 0
  %calltext118156_arg0_length1 = add i64 %calltext118156_arg0_length0, %calltext118156_arg0_root0_length
  %calltext118156_arg0_length1_ok = icmp uge i64 %calltext118156_arg0_length1, %calltext118156_arg0_length0
  br i1 %calltext118156_arg0_length1_ok, label %calltext118156_arg0_length1_ready, label %calltext118156_arg0_length1_overflow
calltext118156_arg0_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118156_arg0_length1_ready:
  %calltext118156_arg0_empty = icmp eq i64 %calltext118156_arg0_length1, 0
  %calltext118156_arg0_allocation_length = select i1 %calltext118156_arg0_empty, i64 1, i64 %calltext118156_arg0_length1
  %calltext118156_arg0_buffer = alloca i8, i64 %calltext118156_arg0_allocation_length, align 1
  %calltext118156_arg0_offset0 = add i64 0, 0
  %calltext118156_arg0_literal0_target = getelementptr i8, ptr %calltext118156_arg0_buffer, i64 %calltext118156_arg0_offset0
  %calltext118156_arg0_literal0_source = getelementptr i8, ptr @sollang_str_118152, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118156_arg0_literal0_target, ptr %calltext118156_arg0_literal0_source, i64 0, i1 false)
  %calltext118156_arg0_offset1 = add i64 %calltext118156_arg0_offset0, 0
  %calltext118156_arg0_root0_target = getelementptr i8, ptr %calltext118156_arg0_buffer, i64 %calltext118156_arg0_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118156_arg0_root0_target, ptr %calltext118156_arg0_root0_ptr, i64 %calltext118156_arg0_root0_length, i1 false)
  %calltext118156_arg0_offset2 = add i64 %calltext118156_arg0_offset1, %calltext118156_arg0_root0_length
  %calltext118156_arg0_suffix_target = getelementptr i8, ptr %calltext118156_arg0_buffer, i64 %calltext118156_arg0_offset2
  %calltext118156_arg0_suffix_source = getelementptr i8, ptr @sollang_str_118152, i64 7
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118156_arg0_suffix_target, ptr %calltext118156_arg0_suffix_source, i64 0, i1 false)
  %calltext118156_arg0_value0 = insertvalue %sollang.text poison, ptr %calltext118156_arg0_buffer, 0
  %calltext118156_arg0 = insertvalue %sollang.text %calltext118156_arg0_value0, i64 %calltext118156_arg0_length1, 1
  %v118156 = call i64 @sollang_m144_s0(%sollang.text %calltext118156_arg0)
  call void @sollang_runtime_print_i64(i64 %v118156, i1 false, i1 true)
  br label %stream118138_continue
stream118138_continue:
  %stream118138_current = load i32, ptr %stream118138_index_slot, align 4
  %stream118138_last = icmp sge i32 %stream118138_current, %stream118138_end
  %stream118138_next = add i32 %stream118138_current, 1
  store i32 %stream118138_next, ptr %stream118138_index_slot, align 4
  br i1 %stream118138_last, label %stream118138_exit, label %stream118138_header
stream118138_exit:
  %v118139_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118139 = insertvalue { i32, i32 } %v118139_start, i32 1, 1
  br i1 %v118143, label %if118146_then, label %if118146_else
if118146_then:
  store %sollang.text %v118148, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_else:
  store %sollang.text %v118150, ptr %if118146_result, align 8
  br label %if118146_merge
if118146_merge:
  %v118146 = load %sollang.text, ptr %if118146_result, align 8
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
