define i32 @main() {
entry:
  %slot118104 = alloca i32, align 4
  %slot118105 = alloca i1, align 1
  store i32 0, ptr %slot118104, align 4
  store i1 0, ptr %slot118105, align 1
  %stream118110_index_slot = alloca i32, align 4
  store i32 1, ptr %stream118110_index_slot, align 4
  %stream118110_end = add i32 3, 0
  br label %stream118110_header
stream118110_header:
  %stream118110_item = load i32, ptr %stream118110_index_slot, align 4
  %stream118110_done = icmp sgt i32 %stream118110_item, %stream118110_end
  br i1 %stream118110_done, label %stream118110_exit, label %stream118110_body
stream118110_body:
  %v118114 = freeze i32 %stream118110_item
  %v118116 = load i1, ptr %slot118105, align 1
  %v118111_start = insertvalue { i32, i32 } poison, i32 1, 0
  %v118111 = insertvalue { i32, i32 } %v118111_start, i32 3, 1
  %v118115 = xor i1 %v118116, true
  store i1 %v118115, ptr %slot118105, align 1
  %v118118 = load i32, ptr %slot118104, align 4
  %v118117 = add i32 %v118118, 1
  store i32 %v118117, ptr %slot118104, align 4
  br label %stream118110_continue
stream118110_continue:
  %stream118110_current = load i32, ptr %stream118110_index_slot, align 4
  %stream118110_last = icmp sge i32 %stream118110_current, %stream118110_end
  %stream118110_next = add i32 %stream118110_current, 1
  store i32 %stream118110_next, ptr %stream118110_index_slot, align 4
  br i1 %stream118110_last, label %stream118110_exit, label %stream118110_header
stream118110_exit:
  %v118121 = load i32, ptr %slot118104, align 4
  call void @sollang_runtime_print_i32(i32 %v118121, i1 true)
  %v118123 = load i1, ptr %slot118105, align 1
  br i1 %v118123, label %if118124_then, label %if118124_else
if118124_then:
  call void @sollang_runtime_print_i32(i32 1, i1 true)
  br label %if118124_merge
if118124_else:
  call void @sollang_runtime_print_i32(i32 0, i1 true)
  br label %if118124_merge
if118124_merge:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
