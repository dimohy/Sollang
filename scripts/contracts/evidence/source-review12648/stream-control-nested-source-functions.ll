define i32 @main() {
entry:
  %stream118104_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118104_index_slot, align 4
  %stream118104_end = add i32 1, 0
  br label %stream118104_header
stream118104_header:
  %stream118104_item = load i32, ptr %stream118104_index_slot, align 4
  %stream118104_done = icmp sgt i32 %stream118104_item, %stream118104_end
  br i1 %stream118104_done, label %stream118104_exit, label %stream118104_body
stream118104_body:
  %v118109 = freeze i32 %stream118104_item
  %v118108 = add i32 %v118109, 1
  %v118113 = freeze i32 %v118108
  %v118123 = freeze i32 %v118108
  %v118112 = icmp sgt i32 %v118113, 0
  br i1 %v118112, label %if118115_then, label %if118115_merge
if118115_then:
  %stream118117_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118117_index_slot, align 4
  %stream118117_end = add i32 1, 0
  br label %stream118117_header
stream118117_header:
  %stream118117_item = load i32, ptr %stream118117_index_slot, align 4
  %stream118117_done = icmp sgt i32 %stream118117_item, %stream118117_end
  br i1 %stream118117_done, label %stream118117_exit, label %stream118117_body
stream118117_body:
  %v118122 = freeze i32 %stream118117_item
  %v118121 = add i32 %v118122, %v118123
  %v118125 = freeze i32 %v118121
  call void @sollang_runtime_print_i32(i32 %v118121, i1 true)
  br label %stream118117_continue
stream118117_continue:
  %stream118117_current = load i32, ptr %stream118117_index_slot, align 4
  %stream118117_last = icmp sge i32 %stream118117_current, %stream118117_end
  %stream118117_next = add i32 %stream118117_current, 1
  store i32 %stream118117_next, ptr %stream118117_index_slot, align 4
  br i1 %stream118117_last, label %stream118117_exit, label %stream118117_header
stream118117_exit:
  %v118118_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118118 = insertvalue { i32, i32 } %v118118_start, i32 1, 1
  br label %if118115_merge
if118115_merge:
  br label %stream118104_continue
stream118104_continue:
  %stream118104_current = load i32, ptr %stream118104_index_slot, align 4
  %stream118104_last = icmp sge i32 %stream118104_current, %stream118104_end
  %stream118104_next = add i32 %stream118104_current, 1
  store i32 %stream118104_next, ptr %stream118104_index_slot, align 4
  br i1 %stream118104_last, label %stream118104_exit, label %stream118104_header
stream118104_exit:
  %v118105_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118105 = insertvalue { i32, i32 } %v118105_start, i32 1, 1
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
