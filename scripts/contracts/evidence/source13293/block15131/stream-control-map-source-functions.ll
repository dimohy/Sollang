define i32 @main() {
entry:
  %if118121_result = alloca i32, align 4
  %slot118104 = alloca i32, align 4
  store i32 0, ptr %slot118104, align 4
  br label %while118111_header
while118111_header:
  %while118111_v118109 = load i32, ptr %slot118104, align 4
  %while118111_v118108 = icmp slt i32 %while118111_v118109, 2
  br i1 %while118111_v118108, label %while118111_body, label %while118111_exit
while118111_body:
  %stream118113_index_slot = alloca i32, align 4
  store i32 0, ptr %stream118113_index_slot, align 4
  %stream118113_end = add i32 1, 0
  br label %stream118113_header
stream118113_header:
  %stream118113_item = load i32, ptr %stream118113_index_slot, align 4
  %stream118113_done = icmp sgt i32 %stream118113_item, %stream118113_end
  br i1 %stream118113_done, label %stream118113_exit, label %stream118113_body
stream118113_body:
  %v118119 = freeze i32 %stream118113_item
  %v118124 = freeze i32 %stream118113_item
  %v118128 = freeze i32 %stream118113_item
  %v118118 = icmp sgt i32 %v118119, 0
  br i1 %v118118, label %if118121_then, label %if118121_else
if118121_then:
  %v118123 = add i32 %v118124, 10
  store i32 %v118123, ptr %if118121_result, align 4
  br label %if118121_merge
if118121_else:
  %v118127 = sub i32 %v118128, 1
  store i32 %v118127, ptr %if118121_result, align 4
  br label %if118121_merge
if118121_merge:
  %v118121 = load i32, ptr %if118121_result, align 4
  %v118131 = freeze i32 %v118121
  call void @sollang_runtime_print_i32(i32 %v118121, i1 true)
  br label %stream118113_continue
stream118113_continue:
  %stream118113_current = load i32, ptr %stream118113_index_slot, align 4
  %stream118113_last = icmp sge i32 %stream118113_current, %stream118113_end
  %stream118113_next = add i32 %stream118113_current, 1
  store i32 %stream118113_next, ptr %stream118113_index_slot, align 4
  br i1 %stream118113_last, label %stream118113_exit, label %stream118113_header
stream118113_exit:
  %v118114_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118114 = insertvalue { i32, i32 } %v118114_start, i32 1, 1
  %v118133 = load i32, ptr %slot118104, align 4
  %v118132 = add i32 %v118133, 1
  store i32 %v118132, ptr %slot118104, align 4
  br label %while118111_header
while118111_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
