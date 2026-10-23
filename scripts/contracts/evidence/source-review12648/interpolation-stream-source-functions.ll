define i32 @main() {
entry:
  %v118109_expression0_logical_slot = alloca i1, align 1
  %v118111_expression0_logical_slot = alloca i1, align 1
  %stream118104_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118104_index_slot, align 4
  %stream118104_end = add i32 2, 0
  br label %stream118104_header
stream118104_header:
  %stream118104_item = load i32, ptr %stream118104_index_slot, align 4
  %stream118104_done = icmp sgt i32 %stream118104_item, %stream118104_end
  br i1 %stream118104_done, label %stream118104_exit, label %stream118104_body
stream118104_body:
  %v118108_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118108, 0
  %v118108 = insertvalue %sollang.text %v118108_ptr, i64 32, 1
  %v118110 = freeze %sollang.text %v118108
  %v118109_expression_literal0 = getelementptr i8, ptr @sollang_str_118108, i64 0
  call void @sollang_runtime_print(ptr %v118109_expression_literal0, i64 6, i1 false)
  %v118109_expression1 = icmp sgt i32 %stream118104_item, 0
  store i1 0, ptr %v118109_expression0_logical_slot, align 1
  br i1 %v118109_expression1, label %interpolation118109_logical0_rhs, label %interpolation118109_logical0_end
interpolation118109_logical0_rhs:
  %v118109_expression4 = icmp slt i32 %stream118104_item, 2
  store i1 %v118109_expression4, ptr %v118109_expression0_logical_slot, align 1
  br label %interpolation118109_logical0_end
interpolation118109_logical0_end:
  %v118109_expression0 = load i1, ptr %v118109_expression0_logical_slot, align 1
  call void @sollang_runtime_print_i1(i1 %v118109_expression0, i1 false)
  %v118109_expression_suffix = getelementptr i8, ptr @sollang_str_118108, i64 32
  call void @sollang_runtime_print(ptr %v118109_expression_suffix, i64 0, i1 true)
  br label %stream118104_continue
stream118104_continue:
  %stream118104_current = load i32, ptr %stream118104_index_slot, align 4
  %stream118104_last = icmp sge i32 %stream118104_current, %stream118104_end
  %stream118104_next = add i32 %stream118104_current, 1
  store i32 %stream118104_next, ptr %stream118104_index_slot, align 4
  br i1 %stream118104_last, label %stream118104_exit, label %stream118104_header
stream118104_exit:
  %v118105_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118105 = insertvalue { i32, i32 } %v118105_start, i32 2, 1
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
