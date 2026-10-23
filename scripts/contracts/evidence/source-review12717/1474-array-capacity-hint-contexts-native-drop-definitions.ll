define internal void @sollang_drop_t371(%sollang.array.i32 %value) {
entry:
  %data = extractvalue %sollang.array.i32 %value, 0
  %length = extractvalue %sollang.array.i32 %value, 1
  call void @free(ptr %data)
  ret void
}
