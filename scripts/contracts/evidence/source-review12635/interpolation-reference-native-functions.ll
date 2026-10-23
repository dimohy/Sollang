define i32 @sollang_m144_s0(ptr %arg) {
entry:
  %v118107 = load i32, ptr %arg, align 4
  %v118106 = add i32 %v118107, 1
  ret i32 %v118106
}

define i32 @main() {
entry:
  %each118110_index_slot = alloca i64, align 8
  %each118110_limit_slot = alloca i64, align 8
  %v118114_expression0_arg0_ref = alloca i32, align 4
  %v118111_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118111 = insertvalue { i32, i32 } %v118111_start, i32 1, 1
  %each118110_range = freeze { i32, i32 } %v118111
  %each118110_first = extractvalue { i32, i32 } %each118110_range, 0
  %each118110_last = extractvalue { i32, i32 } %each118110_range, 1
  %each118110_start = sext i32 %each118110_first to i64
  %each118110_limit = sext i32 %each118110_last to i64
  store i64 %each118110_start, ptr %each118110_index_slot, align 8
  store i64 %each118110_limit, ptr %each118110_limit_slot, align 8
  br label %each118110_header
each118110_header:
  %each118110_index = load i64, ptr %each118110_index_slot, align 8
  %each118110_bound = load i64, ptr %each118110_limit_slot, align 8
  %each118110_done = icmp sgt i64 %each118110_index, %each118110_bound
  br i1 %each118110_done, label %each118110_exit, label %each118110_body
each118110_body:
  %each118110_item = trunc i64 %each118110_index to i32
  %each_role_m144_s3 = freeze i32 %each118110_item
  %v118115_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118115, 0
  %v118115 = insertvalue %sollang.text %v118115_ptr, i64 27, 1
  %v118114_expression_literal0 = getelementptr i8, ptr @sollang_str_118115, i64 0
  call void @sollang_runtime_print(ptr %v118114_expression_literal0, i64 6, i1 false)
  store i32 %each_role_m144_s3, ptr %v118114_expression0_arg0_ref, align 4
  %v118114_expression0 = call i32 @sollang_m144_s0(ptr %v118114_expression0_arg0_ref)
  call void @sollang_runtime_print_i32(i32 %v118114_expression0, i1 false)
  %v118114_expression_suffix = getelementptr i8, ptr @sollang_str_118115, i64 27
  call void @sollang_runtime_print(ptr %v118114_expression_suffix, i64 0, i1 true)
  br label %each118110_continue
each118110_continue:
  %each118110_current = load i64, ptr %each118110_index_slot, align 8
  %each118110_next = add i64 %each118110_current, 1
  store i64 %each118110_next, ptr %each118110_index_slot, align 8
  br label %each118110_header
each118110_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
