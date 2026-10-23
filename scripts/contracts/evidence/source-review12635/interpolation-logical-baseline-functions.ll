define i32 @main() {
entry:
  %each118104_index_slot = alloca i64, align 8
  %each118104_limit_slot = alloca i64, align 8
  %v118105_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118105 = insertvalue { i32, i32 } %v118105_start, i32 2, 1
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
  %each_role_m144_s1 = freeze i32 %each118104_item
  %v118109_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118109, 0
  %v118109 = insertvalue %sollang.text %v118109_ptr, i64 32, 1
  %v118108_expression_literal0 = getelementptr i8, ptr @sollang_str_118109, i64 0
  call void @sollang_runtime_print(ptr %v118108_expression_literal0, i64 6, i1 false)
  %v118108_expression1 = icmp sgt i32 %each_role_m144_s1, 0
  %v118108_expression0_logical_slot = alloca i1, align 1
  store i1 0, ptr %v118108_expression0_logical_slot, align 1
  br i1 %v118108_expression1, label %interpolation118108_logical0_rhs, label %interpolation118108_logical0_end
interpolation118108_logical0_rhs:
  %v118108_expression4 = icmp slt i32 %each_role_m144_s1, 2
  store i1 %v118108_expression4, ptr %v118108_expression0_logical_slot, align 1
  br label %interpolation118108_logical0_end
interpolation118108_logical0_end:
  %v118108_expression0 = load i1, ptr %v118108_expression0_logical_slot, align 1
  call void @sollang_runtime_print_i1(i1 %v118108_expression0, i1 false)
  %v118108_expression_suffix = getelementptr i8, ptr @sollang_str_118109, i64 32
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
