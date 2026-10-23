define i32 @main() {
entry:
  %each118104_index_slot = alloca i64, align 8
  %each118104_limit_slot = alloca i64, align 8
  %v118105_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118105 = insertvalue { i32, i32 } %v118105_start, i32 1, 1
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
  %v118109 = insertvalue %sollang.text %v118109_ptr, i64 25, 1
  %v118108_expression_literal0 = getelementptr i8, ptr @sollang_str_118109, i64 0
  call void @sollang_runtime_print(ptr %v118108_expression_literal0, i64 4, i1 false)
  %v118108_expression1_data = alloca [8 x i8], align 4
  %v118108_expression1_ptr0 = getelementptr i32, ptr %v118108_expression1_data, i64 0
  store i32 1, ptr %v118108_expression1_ptr0, align 4
  %v118108_expression1_ptr1 = getelementptr i32, ptr %v118108_expression1_data, i64 1
  store i32 2, ptr %v118108_expression1_ptr1, align 4
  %v118108_expression1_0 = insertvalue %sollang.array.i32 poison, ptr %v118108_expression1_data, 0
  %v118108_expression1_1 = insertvalue %sollang.array.i32 %v118108_expression1_0, i64 2, 1
  %v118108_expression1 = insertvalue %sollang.array.i32 %v118108_expression1_1, i64 2, 2
  %v118108_expression0_raw = extractvalue %sollang.array.i32 %v118108_expression1, 1
  %v118108_expression0 = trunc i64 %v118108_expression0_raw to i32
  %v118108_expression0_print = zext i32 %v118108_expression0 to i64
  call void @sollang_runtime_print_i64(i64 %v118108_expression0_print, i1 false, i1 false)
  %v118108_expression_suffix = getelementptr i8, ptr @sollang_str_118109, i64 25
  call void @sollang_runtime_print(ptr %v118108_expression_suffix, i64 0, i1 true)
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
