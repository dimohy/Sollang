define i32 @main() {
entry:
  %slot118104 = alloca i32, align 4
  store i32 0, ptr %slot118104, align 4
  br label %while118111_header
while118111_header:
  %while118111_v118109 = load i32, ptr %slot118104, align 4
  %while118111_v118108 = icmp slt i32 %while118111_v118109, 2
  br i1 %while118111_v118108, label %while118111_body, label %while118111_exit
while118111_body:
  %each118113_count = freeze i32 2
  %each118113_limit = sext i32 %each118113_count to i64
  %each118113_index_slot = alloca i64, align 8
  %each118113_limit_slot = alloca i64, align 8
  store i64 1, ptr %each118113_index_slot, align 8
  store i64 %each118113_limit, ptr %each118113_limit_slot, align 8
  br label %each118113_header
each118113_header:
  %each118113_index = load i64, ptr %each118113_index_slot, align 8
  %each118113_bound = load i64, ptr %each118113_limit_slot, align 8
  %each118113_done = icmp sgt i64 %each118113_index, %each118113_bound
  br i1 %each118113_done, label %each118113_exit, label %each118113_body
each118113_body:
  %each118113_item = trunc i64 %each118113_index to i32
  %v118116 = freeze i32 %each118113_item
  call void @sollang_runtime_print_i32(i32 %v118116, i1 true)
  br label %each118113_continue
each118113_continue:
  %each118113_current = load i64, ptr %each118113_index_slot, align 8
  %each118113_next = add i64 %each118113_current, 1
  store i64 %each118113_next, ptr %each118113_index_slot, align 8
  br label %each118113_header
each118113_exit:
  %v118118 = load i32, ptr %slot118104, align 4
  %v118117 = add i32 %v118118, 1
  store i32 %v118117, ptr %slot118104, align 4
  br label %while118111_header
while118111_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
