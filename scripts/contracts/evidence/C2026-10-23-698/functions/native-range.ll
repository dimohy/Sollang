define i32 @main() {
entry:
  %each118104_index_slot = alloca i64, align 8
  %each118104_limit_slot = alloca i64, align 8
  %each118108_index_slot = alloca i64, align 8
  %each118108_limit_slot = alloca i64, align 8
  %v118105_start = insertvalue { i32, i32 } poison, i32 1, 0
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
  %v118115 = freeze i32 %each118104_item
  %v118109_start = insertvalue { i32, i32 } poison, i32 1, 0
  %v118109 = insertvalue { i32, i32 } %v118109_start, i32 3, 1
  %each118108_range = freeze { i32, i32 } %v118109
  %each118108_first = extractvalue { i32, i32 } %each118108_range, 0
  %each118108_last = extractvalue { i32, i32 } %each118108_range, 1
  %each118108_start = sext i32 %each118108_first to i64
  %each118108_limit = sext i32 %each118108_last to i64
  store i64 %each118108_start, ptr %each118108_index_slot, align 8
  store i64 %each118108_limit, ptr %each118108_limit_slot, align 8
  br label %each118108_header
each118108_header:
  %each118108_index = load i64, ptr %each118108_index_slot, align 8
  %each118108_bound = load i64, ptr %each118108_limit_slot, align 8
  %each118108_done = icmp sgt i64 %each118108_index, %each118108_bound
  br i1 %each118108_done, label %each118108_exit, label %each118108_body
each118108_body:
  %each118108_item = trunc i64 %each118108_index to i32
  %v118117 = freeze i32 %each118108_item
  %v118114 = mul i32 %v118115, 10
  %v118113 = add i32 %v118114, %v118117
  call void @sollang_runtime_print_i32(i32 %v118113, i1 true)
  br label %each118108_continue
each118108_continue:
  %each118108_current = load i64, ptr %each118108_index_slot, align 8
  %each118108_next = add i64 %each118108_current, 1
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
