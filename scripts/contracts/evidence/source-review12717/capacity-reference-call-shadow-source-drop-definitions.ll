define internal void @sollang_drop_t1212(%sollang.dict %value) {
entry:
  %dict_storage = extractvalue %sollang.dict %value, 0
  %length = extractvalue %sollang.dict %value, 1
  %capacity = extractvalue %sollang.dict %value, 2
  %dict_controls = getelementptr i8, ptr %dict_storage, i64 0
  %dict_entries_mirror = add i64 %capacity, 23
  %dict_entries_offset = and i64 %dict_entries_mirror, -8
  %dict_keys = getelementptr i8, ptr %dict_storage, i64 %dict_entries_offset
  %dict_values = getelementptr i8, ptr %dict_keys, i64 4
  call void @free(ptr %dict_storage)
  ret void
}

define internal void @sollang_drop_t188(%sollang.array.i32 %value) {
entry:
  %data = extractvalue %sollang.array.i32 %value, 0
  %length = extractvalue %sollang.array.i32 %value, 1
  call void @free(ptr %data)
  ret void
}
