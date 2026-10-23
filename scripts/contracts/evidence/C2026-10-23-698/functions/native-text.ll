define i32 @main() {
entry:
  %each118104_index_slot = alloca i64, align 8
  %each118104_limit_slot = alloca i64, align 8
  %each118108_index_slot = alloca i64, align 8
  %v118105_end_inclusive = sub i32 2, 1
  %v118105_end_is_minimum = icmp eq i32 2, -2147483648
  %v118105_normalized_start = select i1 %v118105_end_is_minimum, i32 0, i32 0
  %v118105_normalized_end = select i1 %v118105_end_is_minimum, i32 -1, i32 %v118105_end_inclusive
  %v118105_start = insertvalue { i32, i32 } poison, i32 %v118105_normalized_start, 0
  %v118105 = insertvalue { i32, i32 } %v118105_start, i32 %v118105_normalized_end, 1
  %each118104_range = freeze { i32, i32 } %v118105
  %each118104_first = extractvalue { i32, i32 } %each118104_range, 0
  %each118104_last = extractvalue { i32, i32 } %each118104_range, 1
  %each118104_start = sext i32 %each118104_first to i64
  %each118104_limit = sext i32 %each118104_last to i64
  store i64 %each118104_start, ptr %each118104_index_slot, align 8
  store i64 %each118104_limit, ptr %each118104_limit_slot, align 8
  br label %each118104_header
each118104_header:
  %each118104_index = load i64, ptr %each118104_index_slot, align 8
  %each118104_bound = load i64, ptr %each118104_limit_slot, align 8
  %each118104_done = icmp sgt i64 %each118104_index, %each118104_bound
  br i1 %each118104_done, label %each118104_exit, label %each118104_body
each118104_body:
  %each118104_item = trunc i64 %each118104_index to i32
  %v118109_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118109, 0
  %v118109 = insertvalue %sollang.text %v118109_ptr, i64 2, 1
  %each118108_data = extractvalue %sollang.text %v118109, 0
  %each118108_length = extractvalue %sollang.text %v118109, 1
  store i64 0, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_header:
  %each118108_index = load i64, ptr %each118108_index_slot, align 8
  %each118108_done = icmp uge i64 %each118108_index, %each118108_length
  br i1 %each118108_done, label %each118108_exit, label %each118108_body
each118108_body:
  %each118108_utf8 = call i64 @sollang_utf8_decode(ptr %each118108_data, i64 %each118108_length, i64 %each118108_index)
  %each118108_valid = icmp ne i64 %each118108_utf8, -1
  br i1 %each118108_valid, label %each118108_decoded, label %each118108_invalid
each118108_invalid:
  call void @llvm.trap()
  unreachable
each118108_decoded:
  %each118108_item = trunc i64 %each118108_utf8 to i32
  %each118108_width = lshr i64 %each118108_utf8, 32
  %v118112 = freeze i32 %each118108_item
  %v118111 = add i32 %v118112, 0
  %v118110_runtime_integer = zext i32 %v118111 to i64
  call void @sollang_runtime_print_i64(i64 %v118110_runtime_integer, i1 false, i1 true)
  br label %each118108_continue
each118108_continue:
  %each118108_next = add i64 %each118108_index, %each118108_width
  store i64 %each118108_next, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_exit:
  br label %each118104_continue
each118104_continue:
  %each118104_current = load i64, ptr %each118104_index_slot, align 8
  %each118104_next = add i64 %each118104_current, 1
  store i64 %each118104_next, ptr %each118104_index_slot, align 8
  br label %each118104_header
each118104_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
