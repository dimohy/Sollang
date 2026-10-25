define i32 @main() {
entry:
  %slot118104 = alloca i32, align 4
  store i32 0, ptr %slot118104, align 4
  %stream118107_index_slot = alloca i32, align 4
  store i32 2147483646, ptr %stream118107_index_slot, align 4
  %stream118107_end = add i32 2147483647, 0
  br label %stream118107_header
stream118107_header:
  %stream118107_item = load i32, ptr %stream118107_index_slot, align 4
  %stream118107_done = icmp sgt i32 %stream118107_item, %stream118107_end
  br i1 %stream118107_done, label %stream118107_exit, label %stream118107_body
stream118107_body:
  %v118111 = freeze i32 %stream118107_item
  %v118108_start = insertvalue { i32, i32 } poison, i32 2147483646, 0
  %v118108 = insertvalue { i32, i32 } %v118108_start, i32 2147483647, 1
  %v118113 = load i32, ptr %slot118104, align 4
  %v118112 = add i32 %v118113, 1
  store i32 %v118112, ptr %slot118104, align 4
  br label %stream118107_continue
stream118107_continue:
  %stream118107_current = load i32, ptr %stream118107_index_slot, align 4
  %stream118107_last = icmp sge i32 %stream118107_current, %stream118107_end
  %stream118107_next = add i32 %stream118107_current, 1
  store i32 %stream118107_next, ptr %stream118107_index_slot, align 4
  br i1 %stream118107_last, label %stream118107_exit, label %stream118107_header
stream118107_exit:
  %v118116 = load i32, ptr %slot118104, align 4
  call void @sollang_runtime_print_i32(i32 %v118116, i1 true)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
