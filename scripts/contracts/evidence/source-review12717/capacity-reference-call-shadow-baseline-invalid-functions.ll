define ptr @sollang_m144_s0(ptr %arg) {
entry:
  %v118106 = load %sollang.array.i32, ptr %arg, align 8
  ret ptr %arg
}

define ptr @sollang_m144_s1(ptr %arg) {
entry:
  %v118110 = load %sollang.dict, ptr %arg, align 8
  ret ptr %arg
}

define i32 @main() {
entry:
  %callref118126_arg0 = alloca %sollang.array.i32, align 8
  %callref118133_arg0 = alloca %sollang.array.i32, align 8
  %callref118145_arg0 = alloca %sollang.dict, align 8
  %callref118152_arg0 = alloca %sollang.dict, align 8
  %slot118113 = alloca i32, align 4
  %slot118116 = alloca i32, align 4
  %v118118_data = call ptr @malloc(i64 16)
  %v118118_0 = insertvalue %sollang.array.i32 poison, ptr %v118118_data, 0
  %v118118_1 = insertvalue %sollang.array.i32 %v118118_0, i64 0, 1
  %v118118 = insertvalue %sollang.array.i32 %v118118_1, i64 4, 2
  store i32 1, ptr %slot118113, align 4
  store i32 2, ptr %slot118113, align 4
  %v118122 = load i32, ptr %slot118113, align 4
  %v118127 = freeze %sollang.array.i32 %v118118
  %v118129 = freeze %sollang.array.i32 %v118118
  %v118134 = freeze %sollang.array.i32 %v118118
  %v118136 = freeze %sollang.array.i32 %v118118
  call void @sollang_runtime_print_i32(i32 %v118122, i1 true)
  store %sollang.array.i32 %v118127, ptr %callref118126_arg0, align 8
  %callref118126_arg0_address = getelementptr i8, ptr %callref118126_arg0, i64 0
  %v118126 = call ptr @sollang_m144_s0(ptr %callref118126_arg0_address)
  %v118128_raw = extractvalue %sollang.array.i32 %v118129, 1
  %v118128 = trunc i64 %v118128_raw to i32
  %v118135_raw = extractvalue %sollang.array.i32 %v118136, 2
  %v118135_capacity_fits = icmp ule i64 %v118135_raw, 2147483647
  br i1 %v118135_capacity_fits, label %v118135_capacity_ok, label %v118135_capacity_fail
v118135_capacity_fail:
  call void @llvm.trap()
  unreachable
v118135_capacity_ok:
  %v118135 = trunc i64 %v118135_raw to i32
  %v118125_length_source = load %sollang.array.i32, ptr %v118126, align 8
  %v118125_raw = extractvalue %sollang.array.i32 %v118125_length_source, 1
  %v118125 = trunc i64 %v118125_raw to i32
  %v118124 = icmp eq i32 %v118125, %v118128
  call void @sollang_runtime_print_i1(i1 %v118124, i1 true)
  store %sollang.array.i32 %v118134, ptr %callref118133_arg0, align 8
  %callref118133_arg0_address = getelementptr i8, ptr %callref118133_arg0, i64 0
  %v118133 = call ptr @sollang_m144_s0(ptr %callref118133_arg0_address)
  %v118132_capacity_source = load %sollang.array.i32, ptr %slot118113, align 8
  %v118132_capacity_source = load %sollang.array.i32, ptr %v118133, align 8
  %v118132_raw = extractvalue %sollang.array.i32 %v118132_capacity_source, 2
  %v118132_capacity_fits = icmp ule i64 %v118132_raw, 2147483647
  br i1 %v118132_capacity_fits, label %v118132_capacity_ok, label %v118132_capacity_fail
v118132_capacity_fail:
  call void @llvm.trap()
  unreachable
v118132_capacity_ok:
  %v118132 = trunc i64 %v118132_raw to i32
  %v118131 = icmp eq i32 %v118132, %v118135
  call void @sollang_runtime_print_i1(i1 %v118131, i1 true)
  %v118137_allocation_mirror = add i64 8, 23
  %v118137_allocation_offset = and i64 %v118137_allocation_mirror, -8
  %v118137_entry_bytes = mul i64 8, 8
  %v118137_allocation_bytes = add i64 %v118137_allocation_offset, %v118137_entry_bytes
  %v118137_storage = call ptr @malloc(i64 %v118137_allocation_bytes)
  %v118137_allocated = icmp ne ptr %v118137_storage, null
  br i1 %v118137_allocated, label %v118137_allocation_ready, label %v118137_allocation_failed
v118137_allocation_failed:
  call void @llvm.trap()
  unreachable
v118137_allocation_ready:
  %v118137_controls = getelementptr i8, ptr %v118137_storage, i64 0
  %v118137_entries_mirror = add i64 8, 23
  %v118137_entries_offset = and i64 %v118137_entries_mirror, -8
  %v118137_keys = getelementptr i8, ptr %v118137_storage, i64 %v118137_entries_offset
  %v118137_values = getelementptr i8, ptr %v118137_keys, i64 4
  %v118137_control_bytes = add i64 8, 16
  call void @llvm.memset.p0.i64(ptr %v118137_controls, i8 0, i64 %v118137_control_bytes, i1 false)
  %v118137_0 = insertvalue %sollang.dict poison, ptr %v118137_storage, 0
  %v118137_1 = insertvalue %sollang.dict %v118137_0, i64 0, 1
  %v118137 = insertvalue %sollang.dict %v118137_1, i64 8, 2
  store i32 1, ptr %slot118116, align 4
  store i32 2, ptr %slot118116, align 4
  %v118141 = load i32, ptr %slot118116, align 4
  %v118146 = freeze %sollang.dict %v118137
  %v118148 = freeze %sollang.dict %v118137
  %v118153 = freeze %sollang.dict %v118137
  %v118155 = freeze %sollang.dict %v118137
  call void @sollang_runtime_print_i32(i32 %v118141, i1 true)
  store %sollang.dict %v118146, ptr %callref118145_arg0, align 8
  %callref118145_arg0_address = getelementptr i8, ptr %callref118145_arg0, i64 0
  %v118145 = call ptr @sollang_m144_s1(ptr %callref118145_arg0_address)
  %v118147_raw = extractvalue %sollang.dict %v118148, 1
  %v118147 = trunc i64 %v118147_raw to i32
  %v118154_raw = extractvalue %sollang.dict %v118155, 2
  %v118154_capacity_fits = icmp ule i64 %v118154_raw, 2147483647
  br i1 %v118154_capacity_fits, label %v118154_capacity_ok, label %v118154_capacity_fail
v118154_capacity_fail:
  call void @llvm.trap()
  unreachable
v118154_capacity_ok:
  %v118154 = trunc i64 %v118154_raw to i32
  %v118144_length_source = load %sollang.dict, ptr %v118145, align 8
  %v118144_raw = extractvalue %sollang.dict %v118144_length_source, 1
  %v118144 = trunc i64 %v118144_raw to i32
  %v118143 = icmp eq i32 %v118144, %v118147
  call void @sollang_runtime_print_i1(i1 %v118143, i1 true)
  store %sollang.dict %v118153, ptr %callref118152_arg0, align 8
  %callref118152_arg0_address = getelementptr i8, ptr %callref118152_arg0, i64 0
  %v118152 = call ptr @sollang_m144_s1(ptr %callref118152_arg0_address)
  %v118151_capacity_source = load %sollang.dict, ptr %slot118116, align 8
  %v118151_capacity_source = load %sollang.dict, ptr %v118152, align 8
  %v118151_raw = extractvalue %sollang.dict %v118151_capacity_source, 2
  %v118151_capacity_fits = icmp ule i64 %v118151_raw, 2147483647
  br i1 %v118151_capacity_fits, label %v118151_capacity_ok, label %v118151_capacity_fail
v118151_capacity_fail:
  call void @llvm.trap()
  unreachable
v118151_capacity_ok:
  %v118151 = trunc i64 %v118151_raw to i32
  %v118150 = icmp eq i32 %v118151, %v118154
  call void @sollang_runtime_print_i1(i1 %v118150, i1 true)
  call void @sollang_drop_t1212(%sollang.dict %v118137)
  call void @sollang_drop_t371(%sollang.array.i32 %v118118)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
