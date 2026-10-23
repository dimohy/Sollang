define void @sollang_m144_s0(ptr %arg) {
entry:
  %each118106_index_slot = alloca i64, align 8
  %each118108_index_slot = alloca i64, align 8
  %v118107 = load %sollang.array.i32, ptr %arg, align 8
  %each118106_source = load %sollang.array.i32, ptr %arg, align 8
  %each118106_data = extractvalue %sollang.array.i32 %each118106_source, 0
  %each118106_length = extractvalue %sollang.array.i32 %each118106_source, 1
  store i64 0, ptr %each118106_index_slot, align 8
  br label %each118106_header
each118106_header:
  %each118106_index = load i64, ptr %each118106_index_slot, align 8
  %each118106_done = icmp eq i64 %each118106_index, %each118106_length
  br i1 %each118106_done, label %each118106_exit, label %each118106_body
each118106_body:
  %each118106_item_ptr = getelementptr i32, ptr %each118106_data, i64 %each118106_index
  %each118106_item = load i32, ptr %each118106_item_ptr, align 4
  %v118110 = freeze i32 %each118106_item
  %v118112 = freeze i32 %each118106_item
  %v118111 = add i32 %v118112, 1
  %v118109_data = call ptr @malloc(i64 8)
  %v118109_ptr0 = getelementptr i32, ptr %v118109_data, i64 0
  store i32 %v118110, ptr %v118109_ptr0, align 4
  %v118109_ptr1 = getelementptr i32, ptr %v118109_data, i64 1
  store i32 %v118111, ptr %v118109_ptr1, align 4
  %v118109_0 = insertvalue { ptr, i64 } poison, ptr %v118109_data, 0
  %v118109 = insertvalue { ptr, i64 } %v118109_0, i64 2, 1
  %each118108_data = extractvalue { ptr, i64 } %v118109, 0
  %each118108_length = extractvalue { ptr, i64 } %v118109, 1
  store i64 0, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_header:
  %each118108_index = load i64, ptr %each118108_index_slot, align 8
  %each118108_done = icmp eq i64 %each118108_index, %each118108_length
  br i1 %each118108_done, label %each118108_exit, label %each118108_body
each118108_body:
  %each118108_item_ptr = getelementptr i32, ptr %each118108_data, i64 %each118108_index
  %each118108_item = load i32, ptr %each118108_item_ptr, align 4
  %v118115 = freeze i32 %each118108_item
  call void @sollang_runtime_print_i32(i32 %v118115, i1 true)
  br label %each118108_continue
each118108_continue:
  %each118108_next = add i64 %each118108_index, 1
  store i64 %each118108_next, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_exit:
  br label %each118106_continue
each118106_continue:
  %each118106_next = add i64 %each118106_index, 1
  store i64 %each118106_next, ptr %each118106_index_slot, align 8
  br label %each118106_header
each118106_exit:
  ret void
}

define i32 @main() {
entry:
  %callref118121_arg0 = alloca %sollang.array.i32, align 8
  %v118118_data = call ptr @malloc(i64 8)
  %v118118_ptr0 = getelementptr i32, ptr %v118118_data, i64 0
  store i32 2, ptr %v118118_ptr0, align 4
  %v118118_ptr1 = getelementptr i32, ptr %v118118_data, i64 1
  store i32 4, ptr %v118118_ptr1, align 4
  %v118118_0 = insertvalue %sollang.array.i32 poison, ptr %v118118_data, 0
  %v118118_1 = insertvalue %sollang.array.i32 %v118118_0, i64 2, 1
  %v118118 = insertvalue %sollang.array.i32 %v118118_1, i64 2, 2
  %v118122 = freeze %sollang.array.i32 %v118118
  store %sollang.array.i32 %v118122, ptr %callref118121_arg0, align 8
  %callref118121_arg0_address = getelementptr i8, ptr %callref118121_arg0, i64 0
  call void @sollang_m144_s0(ptr %callref118121_arg0_address)
  call void @sollang_drop_t371(%sollang.array.i32 %v118118)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
