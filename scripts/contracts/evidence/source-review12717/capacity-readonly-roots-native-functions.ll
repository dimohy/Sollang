define i32 @sollang_m144_s0(ptr %arg) {
entry:
  %v118107 = load %sollang.array.i32, ptr %arg, align 8
  %v118106_capacity_source = load %sollang.array.i32, ptr %arg, align 8
  %v118106_raw = extractvalue %sollang.array.i32 %v118106_capacity_source, 2
  %v118106_capacity_fits = icmp ule i64 %v118106_raw, 2147483647
  br i1 %v118106_capacity_fits, label %v118106_capacity_ok, label %v118106_capacity_fail
v118106_capacity_fail:
  call void @llvm.trap()
  unreachable
v118106_capacity_ok:
  %v118106 = trunc i64 %v118106_raw to i32
  ret i32 %v118106
}

define i32 @sollang_m144_s1(ptr %arg) {
entry:
  %v118112 = load %sollang.dict, ptr %arg, align 8
  %v118111_capacity_source = load %sollang.dict, ptr %arg, align 8
  %v118111_raw = extractvalue %sollang.dict %v118111_capacity_source, 2
  %v118111_capacity_fits = icmp ule i64 %v118111_raw, 2147483647
  br i1 %v118111_capacity_fits, label %v118111_capacity_ok, label %v118111_capacity_fail
v118111_capacity_fail:
  call void @llvm.trap()
  unreachable
v118111_capacity_ok:
  %v118111 = trunc i64 %v118111_raw to i32
  ret i32 %v118111
}

define i32 @main() {
entry:
  %callref118119_arg0 = alloca %sollang.array.i32, align 8
  %callref118126_arg0 = alloca %sollang.dict, align 8
  %v118116_data = call ptr @malloc(i64 16)
  %v118116_0 = insertvalue %sollang.array.i32 poison, ptr %v118116_data, 0
  %v118116_1 = insertvalue %sollang.array.i32 %v118116_0, i64 0, 1
  %v118116 = insertvalue %sollang.array.i32 %v118116_1, i64 4, 2
  %v118120 = freeze %sollang.array.i32 %v118116
  %v118122 = freeze %sollang.array.i32 %v118116
  store %sollang.array.i32 %v118120, ptr %callref118119_arg0, align 8
  %callref118119_arg0_address = getelementptr i8, ptr %callref118119_arg0, i64 0
  %v118119 = call i32 @sollang_m144_s0(ptr %callref118119_arg0_address)
  %v118121_raw = extractvalue %sollang.array.i32 %v118122, 2
  %v118121_capacity_fits = icmp ule i64 %v118121_raw, 2147483647
  br i1 %v118121_capacity_fits, label %v118121_capacity_ok, label %v118121_capacity_fail
v118121_capacity_fail:
  call void @llvm.trap()
  unreachable
v118121_capacity_ok:
  %v118121 = trunc i64 %v118121_raw to i32
  %v118118 = icmp eq i32 %v118119, %v118121
  call void @sollang_runtime_print_i1(i1 %v118118, i1 true)
  %v118123_allocation_mirror = add i64 8, 23
  %v118123_allocation_offset = and i64 %v118123_allocation_mirror, -8
  %v118123_entry_bytes = mul i64 8, 8
  %v118123_allocation_bytes = add i64 %v118123_allocation_offset, %v118123_entry_bytes
  %v118123_storage = call ptr @malloc(i64 %v118123_allocation_bytes)
  %v118123_allocated = icmp ne ptr %v118123_storage, null
  br i1 %v118123_allocated, label %v118123_allocation_ready, label %v118123_allocation_failed
v118123_allocation_failed:
  call void @llvm.trap()
  unreachable
v118123_allocation_ready:
  %v118123_controls = getelementptr i8, ptr %v118123_storage, i64 0
  %v118123_entries_mirror = add i64 8, 23
  %v118123_entries_offset = and i64 %v118123_entries_mirror, -8
  %v118123_keys = getelementptr i8, ptr %v118123_storage, i64 %v118123_entries_offset
  %v118123_values = getelementptr i8, ptr %v118123_keys, i64 4
  %v118123_control_bytes = add i64 8, 16
  call void @llvm.memset.p0.i64(ptr %v118123_controls, i8 0, i64 %v118123_control_bytes, i1 false)
  %v118123_0 = insertvalue %sollang.dict poison, ptr %v118123_storage, 0
  %v118123_1 = insertvalue %sollang.dict %v118123_0, i64 0, 1
  %v118123 = insertvalue %sollang.dict %v118123_1, i64 8, 2
  %v118127 = freeze %sollang.dict %v118123
  %v118129 = freeze %sollang.dict %v118123
  store %sollang.dict %v118127, ptr %callref118126_arg0, align 8
  %callref118126_arg0_address = getelementptr i8, ptr %callref118126_arg0, i64 0
  %v118126 = call i32 @sollang_m144_s1(ptr %callref118126_arg0_address)
  %v118128_raw = extractvalue %sollang.dict %v118129, 2
  %v118128_capacity_fits = icmp ule i64 %v118128_raw, 2147483647
  br i1 %v118128_capacity_fits, label %v118128_capacity_ok, label %v118128_capacity_fail
v118128_capacity_fail:
  call void @llvm.trap()
  unreachable
v118128_capacity_ok:
  %v118128 = trunc i64 %v118128_raw to i32
  %v118125 = icmp eq i32 %v118126, %v118128
  call void @sollang_runtime_print_i1(i1 %v118125, i1 true)
  call void @sollang_drop_t1212(%sollang.dict %v118123)
  call void @sollang_drop_t371(%sollang.array.i32 %v118116)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
