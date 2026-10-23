define i64 @sollang_m144_s0(%sollang.text %arg) {
entry:
  %v118106 = extractvalue %sollang.text %arg, 1
  ret i64 %v118106
}

define i32 @main() {
entry:
  %each118109_index_slot = alloca i64, align 8
  %each118109_limit_slot = alloca i64, align 8
  %deferred_text118117_tag = alloca i64, align 8
  %if118117_result = alloca %sollang.text, align 8
  %deferred_text118119_root0_slot = alloca i1, align 1
  %deferred_text118121_root3_slot = alloca i1, align 1
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
  %v118115 = freeze i32 %each118109_item
  %v118114 = icmp sgt i32 %v118115, 0
  br i1 %v118114, label %if118117_then, label %if118117_else
if118117_then:
  %v118119_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118119, 0
  %v118119 = insertvalue %sollang.text %v118119_ptr, i64 12, 1
  %v118119_expression0 = icmp sgt i32 %each_role_m144_s3, 0
  store i1 %v118119_expression0, ptr %deferred_text118119_root0_slot, align 1
  store i64 118119, ptr %deferred_text118117_tag, align 8
  store %sollang.text poison, ptr %if118117_result, align 8
  br label %if118117_merge
if118117_else:
  %v118121_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118121, 0
  %v118121 = insertvalue %sollang.text %v118121_ptr, i64 12, 1
  %v118121_expression3 = icmp sgt i32 %each_role_m144_s3, 0
  store i1 %v118121_expression3, ptr %deferred_text118121_root3_slot, align 1
  store i64 118121, ptr %deferred_text118117_tag, align 8
  store %sollang.text poison, ptr %if118117_result, align 8
  br label %if118117_merge
if118117_merge:
  %v118117 = load %sollang.text, ptr %if118117_result, align 8
  %calltext118123_arg0_tag = load i64, ptr %deferred_text118117_tag, align 8
  %calltext118123_arg0_is118119 = icmp eq i64 %calltext118123_arg0_tag, 118119
  br i1 %calltext118123_arg0_is118119, label %calltext118123_arg0_leaf118119_start, label %calltext118123_arg0_leaf118119_next
calltext118123_arg0_leaf118119_start:
  %calltext118123_arg0_leaf118119_root0_value = load i1, ptr %deferred_text118119_root0_slot, align 1
  %calltext118123_arg0_leaf118119_root0_ptr = select i1 %calltext118123_arg0_leaf118119_root0_value, ptr @sollang_bool_true_bytes, ptr @sollang_bool_false_bytes
  %calltext118123_arg0_leaf118119_root0_length = select i1 %calltext118123_arg0_leaf118119_root0_value, i64 4, i64 5
  %calltext118123_arg0_leaf118119_length0 = add i64 0, 0
  %calltext118123_arg0_leaf118119_length1 = add i64 %calltext118123_arg0_leaf118119_length0, %calltext118123_arg0_leaf118119_root0_length
  %calltext118123_arg0_leaf118119_length1_ok = icmp uge i64 %calltext118123_arg0_leaf118119_length1, %calltext118123_arg0_leaf118119_length0
  br i1 %calltext118123_arg0_leaf118119_length1_ok, label %calltext118123_arg0_leaf118119_length1_ready, label %calltext118123_arg0_leaf118119_length1_overflow
calltext118123_arg0_leaf118119_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118123_arg0_leaf118119_length1_ready:
  %calltext118123_arg0_leaf118119_empty = icmp eq i64 %calltext118123_arg0_leaf118119_length1, 0
  %calltext118123_arg0_leaf118119_allocation_length = select i1 %calltext118123_arg0_leaf118119_empty, i64 1, i64 %calltext118123_arg0_leaf118119_length1
  %calltext118123_arg0_leaf118119_buffer = alloca i8, i64 %calltext118123_arg0_leaf118119_allocation_length, align 1
  %calltext118123_arg0_leaf118119_offset0 = add i64 0, 0
  %calltext118123_arg0_leaf118119_literal0_target = getelementptr i8, ptr %calltext118123_arg0_leaf118119_buffer, i64 %calltext118123_arg0_leaf118119_offset0
  %calltext118123_arg0_leaf118119_literal0_source = getelementptr i8, ptr @sollang_str_118119, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118123_arg0_leaf118119_literal0_target, ptr %calltext118123_arg0_leaf118119_literal0_source, i64 0, i1 false)
  %calltext118123_arg0_leaf118119_offset1 = add i64 %calltext118123_arg0_leaf118119_offset0, 0
  %calltext118123_arg0_leaf118119_root0_target = getelementptr i8, ptr %calltext118123_arg0_leaf118119_buffer, i64 %calltext118123_arg0_leaf118119_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118123_arg0_leaf118119_root0_target, ptr %calltext118123_arg0_leaf118119_root0_ptr, i64 %calltext118123_arg0_leaf118119_root0_length, i1 false)
  %calltext118123_arg0_leaf118119_offset2 = add i64 %calltext118123_arg0_leaf118119_offset1, %calltext118123_arg0_leaf118119_root0_length
  %calltext118123_arg0_leaf118119_suffix_target = getelementptr i8, ptr %calltext118123_arg0_leaf118119_buffer, i64 %calltext118123_arg0_leaf118119_offset2
  %calltext118123_arg0_leaf118119_suffix_source = getelementptr i8, ptr @sollang_str_118119, i64 12
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118123_arg0_leaf118119_suffix_target, ptr %calltext118123_arg0_leaf118119_suffix_source, i64 0, i1 false)
  %calltext118123_arg0_leaf118119_value0 = insertvalue %sollang.text poison, ptr %calltext118123_arg0_leaf118119_buffer, 0
  %calltext118123_arg0_leaf118119 = insertvalue %sollang.text %calltext118123_arg0_leaf118119_value0, i64 %calltext118123_arg0_leaf118119_length1, 1
  br label %calltext118123_arg0_leaf118119_done
calltext118123_arg0_leaf118119_done:
  br label %calltext118123_arg0_end
calltext118123_arg0_leaf118119_next:
  %calltext118123_arg0_is118121 = icmp eq i64 %calltext118123_arg0_tag, 118121
  br i1 %calltext118123_arg0_is118121, label %calltext118123_arg0_leaf118121_start, label %calltext118123_arg0_leaf118121_next
calltext118123_arg0_leaf118121_start:
  %calltext118123_arg0_leaf118121_root0_value = load i1, ptr %deferred_text118121_root3_slot, align 1
  %calltext118123_arg0_leaf118121_root0_ptr = select i1 %calltext118123_arg0_leaf118121_root0_value, ptr @sollang_bool_true_bytes, ptr @sollang_bool_false_bytes
  %calltext118123_arg0_leaf118121_root0_length = select i1 %calltext118123_arg0_leaf118121_root0_value, i64 4, i64 5
  %calltext118123_arg0_leaf118121_length0 = add i64 0, 0
  %calltext118123_arg0_leaf118121_length1 = add i64 %calltext118123_arg0_leaf118121_length0, %calltext118123_arg0_leaf118121_root0_length
  %calltext118123_arg0_leaf118121_length1_ok = icmp uge i64 %calltext118123_arg0_leaf118121_length1, %calltext118123_arg0_leaf118121_length0
  br i1 %calltext118123_arg0_leaf118121_length1_ok, label %calltext118123_arg0_leaf118121_length1_ready, label %calltext118123_arg0_leaf118121_length1_overflow
calltext118123_arg0_leaf118121_length1_overflow:
  call void @llvm.trap()
  unreachable
calltext118123_arg0_leaf118121_length1_ready:
  %calltext118123_arg0_leaf118121_empty = icmp eq i64 %calltext118123_arg0_leaf118121_length1, 0
  %calltext118123_arg0_leaf118121_allocation_length = select i1 %calltext118123_arg0_leaf118121_empty, i64 1, i64 %calltext118123_arg0_leaf118121_length1
  %calltext118123_arg0_leaf118121_buffer = alloca i8, i64 %calltext118123_arg0_leaf118121_allocation_length, align 1
  %calltext118123_arg0_leaf118121_offset0 = add i64 0, 0
  %calltext118123_arg0_leaf118121_literal0_target = getelementptr i8, ptr %calltext118123_arg0_leaf118121_buffer, i64 %calltext118123_arg0_leaf118121_offset0
  %calltext118123_arg0_leaf118121_literal0_source = getelementptr i8, ptr @sollang_str_118121, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118123_arg0_leaf118121_literal0_target, ptr %calltext118123_arg0_leaf118121_literal0_source, i64 0, i1 false)
  %calltext118123_arg0_leaf118121_offset1 = add i64 %calltext118123_arg0_leaf118121_offset0, 0
  %calltext118123_arg0_leaf118121_root0_target = getelementptr i8, ptr %calltext118123_arg0_leaf118121_buffer, i64 %calltext118123_arg0_leaf118121_offset1
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118123_arg0_leaf118121_root0_target, ptr %calltext118123_arg0_leaf118121_root0_ptr, i64 %calltext118123_arg0_leaf118121_root0_length, i1 false)
  %calltext118123_arg0_leaf118121_offset2 = add i64 %calltext118123_arg0_leaf118121_offset1, %calltext118123_arg0_leaf118121_root0_length
  %calltext118123_arg0_leaf118121_suffix_target = getelementptr i8, ptr %calltext118123_arg0_leaf118121_buffer, i64 %calltext118123_arg0_leaf118121_offset2
  %calltext118123_arg0_leaf118121_suffix_source = getelementptr i8, ptr @sollang_str_118121, i64 12
  call void @llvm.memcpy.p0.p0.i64(ptr %calltext118123_arg0_leaf118121_suffix_target, ptr %calltext118123_arg0_leaf118121_suffix_source, i64 0, i1 false)
  %calltext118123_arg0_leaf118121_value0 = insertvalue %sollang.text poison, ptr %calltext118123_arg0_leaf118121_buffer, 0
  %calltext118123_arg0_leaf118121 = insertvalue %sollang.text %calltext118123_arg0_leaf118121_value0, i64 %calltext118123_arg0_leaf118121_length1, 1
  br label %calltext118123_arg0_leaf118121_done
calltext118123_arg0_leaf118121_done:
  br label %calltext118123_arg0_end
calltext118123_arg0_leaf118121_next:
  call void @llvm.trap()
  unreachable
calltext118123_arg0_end:
  %calltext118123_arg0 = phi %sollang.text [ %calltext118123_arg0_leaf118119, %calltext118123_arg0_leaf118119_done ], [ %calltext118123_arg0_leaf118121, %calltext118123_arg0_leaf118121_done ]
  %v118123 = call i64 @sollang_m144_s0(%sollang.text %calltext118123_arg0)
  call void @sollang_runtime_print_i64(i64 %v118123, i1 false, i1 true)
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
