define void @sollang_m144_s0() {
entry:
  %slot118105 = alloca %sollang.array.i32, align 8
  %slot118106 = alloca %sollang.array.i32, align 8
  %v118107_data = inttoptr i64 0 to ptr
  %v118107_0 = insertvalue %sollang.array.i32 poison, ptr %v118107_data, 0
  %v118107_1 = insertvalue %sollang.array.i32 %v118107_0, i64 0, 1
  %v118107 = insertvalue %sollang.array.i32 %v118107_1, i64 0, 2
  store %sollang.array.i32 %v118107, ptr %slot118105, align 8
  %v118109 = load %sollang.array.i32, ptr %slot118105, align 8
  %v118111 = load %sollang.array.i32, ptr %slot118105, align 8
  %v118113 = load %sollang.array.i32, ptr %slot118105, align 8
  %v118141_raw = extractvalue %sollang.array.i32 %v118109, 1
  %v118141 = trunc i64 %v118141_raw to i32
  %v118142_capacity_source = load %sollang.array.i32, ptr %slot118105, align 8
  %v118142_raw = extractvalue %sollang.array.i32 %v118142_capacity_source, 2
  %v118142_capacity_fits = icmp ule i64 %v118142_raw, 2147483647
  br i1 %v118142_capacity_fits, label %v118142_capacity_ok, label %v118142_capacity_fail
v118142_capacity_fail:
  call void @llvm.trap()
  unreachable
v118142_capacity_ok:
  %v118142 = trunc i64 %v118142_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118141, i1 true)
  call void @sollang_runtime_print_i32(i32 %v118142, i1 true)
  %push118112_data = extractvalue %sollang.array.i32 %v118113, 0
  %push118112_length = extractvalue %sollang.array.i32 %v118113, 1
  %push118112_capacity = extractvalue %sollang.array.i32 %v118113, 2
  %push118112_full = icmp eq i64 %push118112_length, %push118112_capacity
  %push118112_empty = icmp eq i64 %push118112_capacity, 0
  %push118112_doubled = mul i64 %push118112_capacity, 2
  %push118112_grown_capacity = select i1 %push118112_empty, i64 4, i64 %push118112_doubled
  %push118112_append_capacity = select i1 %push118112_full, i64 %push118112_grown_capacity, i64 %push118112_capacity
  %push118112_append_bytes = mul i64 %push118112_append_capacity, 4
  br i1 %push118112_full, label %push118112_grow, label %push118112_keep
push118112_keep:
  br label %push118112_ready
push118112_grow:
  %push118112_grown_data = call ptr @malloc(i64 %push118112_append_bytes)
  %push118112_allocated = icmp ne ptr %push118112_grown_data, null
  br i1 %push118112_allocated, label %push118112_copy, label %push118112_allocation_failed
push118112_allocation_failed:
  call void @llvm.trap()
  unreachable
push118112_copy:
  %push118112_copy_bytes = mul i64 %push118112_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118112_grown_data, ptr %push118112_data, i64 %push118112_copy_bytes, i1 false)
  call void @free(ptr %push118112_data)
  br label %push118112_ready
push118112_ready:
  %push118112_append_data = phi ptr [ %push118112_data, %push118112_keep ], [ %push118112_grown_data, %push118112_copy ]
  %push118112_slot = getelementptr i32, ptr %push118112_append_data, i64 %push118112_length
  store i32 10, ptr %push118112_slot, align 4
  %push118112_new_length = add i64 %push118112_length, 1
  %push118112_array0 = insertvalue %sollang.array.i32 poison, ptr %push118112_append_data, 0
  %push118112_array1 = insertvalue %sollang.array.i32 %push118112_array0, i64 %push118112_new_length, 1
  %push118112_array2 = insertvalue %sollang.array.i32 %push118112_array1, i64 %push118112_append_capacity, 2
  store %sollang.array.i32 %push118112_array2, ptr %slot118105, align 8
  %v118116 = load %sollang.array.i32, ptr %slot118105, align 8
  %push118115_data = extractvalue %sollang.array.i32 %v118116, 0
  %push118115_length = extractvalue %sollang.array.i32 %v118116, 1
  %push118115_capacity = extractvalue %sollang.array.i32 %v118116, 2
  %push118115_full = icmp eq i64 %push118115_length, %push118115_capacity
  %push118115_empty = icmp eq i64 %push118115_capacity, 0
  %push118115_doubled = mul i64 %push118115_capacity, 2
  %push118115_grown_capacity = select i1 %push118115_empty, i64 4, i64 %push118115_doubled
  %push118115_append_capacity = select i1 %push118115_full, i64 %push118115_grown_capacity, i64 %push118115_capacity
  %push118115_append_bytes = mul i64 %push118115_append_capacity, 4
  br i1 %push118115_full, label %push118115_grow, label %push118115_keep
push118115_keep:
  br label %push118115_ready
push118115_grow:
  %push118115_grown_data = call ptr @malloc(i64 %push118115_append_bytes)
  %push118115_allocated = icmp ne ptr %push118115_grown_data, null
  br i1 %push118115_allocated, label %push118115_copy, label %push118115_allocation_failed
push118115_allocation_failed:
  call void @llvm.trap()
  unreachable
push118115_copy:
  %push118115_copy_bytes = mul i64 %push118115_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118115_grown_data, ptr %push118115_data, i64 %push118115_copy_bytes, i1 false)
  call void @free(ptr %push118115_data)
  br label %push118115_ready
push118115_ready:
  %push118115_append_data = phi ptr [ %push118115_data, %push118115_keep ], [ %push118115_grown_data, %push118115_copy ]
  %push118115_slot = getelementptr i32, ptr %push118115_append_data, i64 %push118115_length
  store i32 20, ptr %push118115_slot, align 4
  %push118115_new_length = add i64 %push118115_length, 1
  %push118115_array0 = insertvalue %sollang.array.i32 poison, ptr %push118115_append_data, 0
  %push118115_array1 = insertvalue %sollang.array.i32 %push118115_array0, i64 %push118115_new_length, 1
  %push118115_array2 = insertvalue %sollang.array.i32 %push118115_array1, i64 %push118115_append_capacity, 2
  store %sollang.array.i32 %push118115_array2, ptr %slot118105, align 8
  %v118119 = load %sollang.array.i32, ptr %slot118105, align 8
  %v118122 = load %sollang.array.i32, ptr %slot118105, align 8
  %v118143_raw = extractvalue %sollang.array.i32 %v118119, 1
  %v118143 = trunc i64 %v118143_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118143, i1 true)
  %v118121_data = extractvalue %sollang.array.i32 %v118122, 0
  %v118121_length = extractvalue %sollang.array.i32 %v118122, 1
  %v118121_in_bounds = icmp ult i64 1, %v118121_length
  br i1 %v118121_in_bounds, label %v118121_index_ok, label %v118121_index_fail
v118121_index_fail:
  call void @llvm.trap()
  unreachable
v118121_index_ok:
  %v118121_ptr = getelementptr i32, ptr %v118121_data, i64 1
  %v118121 = load i32, ptr %v118121_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118121, i1 true)
  %v118124_data = call ptr @malloc(i64 16)
  %v118124_0 = insertvalue %sollang.array.i32 poison, ptr %v118124_data, 0
  %v118124_1 = insertvalue %sollang.array.i32 %v118124_0, i64 0, 1
  %v118124 = insertvalue %sollang.array.i32 %v118124_1, i64 4, 2
  store %sollang.array.i32 %v118124, ptr %slot118106, align 8
  %v118126 = load %sollang.array.i32, ptr %slot118106, align 8
  %v118128 = load %sollang.array.i32, ptr %slot118106, align 8
  %v118130 = load %sollang.array.i32, ptr %slot118106, align 8
  %v118144_raw = extractvalue %sollang.array.i32 %v118126, 1
  %v118144 = trunc i64 %v118144_raw to i32
  %v118145_capacity_source = load %sollang.array.i32, ptr %slot118106, align 8
  %v118145_raw = extractvalue %sollang.array.i32 %v118145_capacity_source, 2
  %v118145_capacity_fits = icmp ule i64 %v118145_raw, 2147483647
  br i1 %v118145_capacity_fits, label %v118145_capacity_ok, label %v118145_capacity_fail
v118145_capacity_fail:
  call void @llvm.trap()
  unreachable
v118145_capacity_ok:
  %v118145 = trunc i64 %v118145_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118144, i1 true)
  call void @sollang_runtime_print_i32(i32 %v118145, i1 true)
  %push118129_data = extractvalue %sollang.array.i32 %v118130, 0
  %push118129_length = extractvalue %sollang.array.i32 %v118130, 1
  %push118129_capacity = extractvalue %sollang.array.i32 %v118130, 2
  %push118129_full = icmp eq i64 %push118129_length, %push118129_capacity
  %push118129_empty = icmp eq i64 %push118129_capacity, 0
  %push118129_doubled = mul i64 %push118129_capacity, 2
  %push118129_grown_capacity = select i1 %push118129_empty, i64 4, i64 %push118129_doubled
  %push118129_append_capacity = select i1 %push118129_full, i64 %push118129_grown_capacity, i64 %push118129_capacity
  %push118129_append_bytes = mul i64 %push118129_append_capacity, 4
  br i1 %push118129_full, label %push118129_grow, label %push118129_keep
push118129_keep:
  br label %push118129_ready
push118129_grow:
  %push118129_grown_data = call ptr @malloc(i64 %push118129_append_bytes)
  %push118129_allocated = icmp ne ptr %push118129_grown_data, null
  br i1 %push118129_allocated, label %push118129_copy, label %push118129_allocation_failed
push118129_allocation_failed:
  call void @llvm.trap()
  unreachable
push118129_copy:
  %push118129_copy_bytes = mul i64 %push118129_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118129_grown_data, ptr %push118129_data, i64 %push118129_copy_bytes, i1 false)
  call void @free(ptr %push118129_data)
  br label %push118129_ready
push118129_ready:
  %push118129_append_data = phi ptr [ %push118129_data, %push118129_keep ], [ %push118129_grown_data, %push118129_copy ]
  %push118129_slot = getelementptr i32, ptr %push118129_append_data, i64 %push118129_length
  store i32 10, ptr %push118129_slot, align 4
  %push118129_new_length = add i64 %push118129_length, 1
  %push118129_array0 = insertvalue %sollang.array.i32 poison, ptr %push118129_append_data, 0
  %push118129_array1 = insertvalue %sollang.array.i32 %push118129_array0, i64 %push118129_new_length, 1
  %push118129_array2 = insertvalue %sollang.array.i32 %push118129_array1, i64 %push118129_append_capacity, 2
  store %sollang.array.i32 %push118129_array2, ptr %slot118106, align 8
  %v118133 = load %sollang.array.i32, ptr %slot118106, align 8
  %push118132_data = extractvalue %sollang.array.i32 %v118133, 0
  %push118132_length = extractvalue %sollang.array.i32 %v118133, 1
  %push118132_capacity = extractvalue %sollang.array.i32 %v118133, 2
  %push118132_full = icmp eq i64 %push118132_length, %push118132_capacity
  %push118132_empty = icmp eq i64 %push118132_capacity, 0
  %push118132_doubled = mul i64 %push118132_capacity, 2
  %push118132_grown_capacity = select i1 %push118132_empty, i64 4, i64 %push118132_doubled
  %push118132_append_capacity = select i1 %push118132_full, i64 %push118132_grown_capacity, i64 %push118132_capacity
  %push118132_append_bytes = mul i64 %push118132_append_capacity, 4
  br i1 %push118132_full, label %push118132_grow, label %push118132_keep
push118132_keep:
  br label %push118132_ready
push118132_grow:
  %push118132_grown_data = call ptr @malloc(i64 %push118132_append_bytes)
  %push118132_allocated = icmp ne ptr %push118132_grown_data, null
  br i1 %push118132_allocated, label %push118132_copy, label %push118132_allocation_failed
push118132_allocation_failed:
  call void @llvm.trap()
  unreachable
push118132_copy:
  %push118132_copy_bytes = mul i64 %push118132_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118132_grown_data, ptr %push118132_data, i64 %push118132_copy_bytes, i1 false)
  call void @free(ptr %push118132_data)
  br label %push118132_ready
push118132_ready:
  %push118132_append_data = phi ptr [ %push118132_data, %push118132_keep ], [ %push118132_grown_data, %push118132_copy ]
  %push118132_slot = getelementptr i32, ptr %push118132_append_data, i64 %push118132_length
  store i32 20, ptr %push118132_slot, align 4
  %push118132_new_length = add i64 %push118132_length, 1
  %push118132_array0 = insertvalue %sollang.array.i32 poison, ptr %push118132_append_data, 0
  %push118132_array1 = insertvalue %sollang.array.i32 %push118132_array0, i64 %push118132_new_length, 1
  %push118132_array2 = insertvalue %sollang.array.i32 %push118132_array1, i64 %push118132_append_capacity, 2
  store %sollang.array.i32 %push118132_array2, ptr %slot118106, align 8
  %v118136 = load %sollang.array.i32, ptr %slot118106, align 8
  %v118139 = load %sollang.array.i32, ptr %slot118106, align 8
  %v118146_raw = extractvalue %sollang.array.i32 %v118136, 1
  %v118146 = trunc i64 %v118146_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118146, i1 true)
  %v118138_data = extractvalue %sollang.array.i32 %v118139, 0
  %v118138_length = extractvalue %sollang.array.i32 %v118139, 1
  %v118138_in_bounds = icmp ult i64 1, %v118138_length
  br i1 %v118138_in_bounds, label %v118138_index_ok, label %v118138_index_fail
v118138_index_fail:
  call void @llvm.trap()
  unreachable
v118138_index_ok:
  %v118138_ptr = getelementptr i32, ptr %v118138_data, i64 1
  %v118138 = load i32, ptr %v118138_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118138, i1 true)
  %drop118105_current = load %sollang.array.i32, ptr %slot118105, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %drop118105_current)
  %drop118106_current = load %sollang.array.i32, ptr %slot118106, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %drop118106_current)
  ret void
}

define void @sollang_m144_s3() {
entry:
  %slot118149 = alloca %sollang.array.i32, align 8
  %slot118150 = alloca %sollang.array.i32, align 8
  br i1 1, label %if118153_then, label %if118153_merge
if118153_then:
  %v118155_data = inttoptr i64 0 to ptr
  %v118155_0 = insertvalue %sollang.array.i32 poison, ptr %v118155_data, 0
  %v118155_1 = insertvalue %sollang.array.i32 %v118155_0, i64 0, 1
  %v118155 = insertvalue %sollang.array.i32 %v118155_1, i64 0, 2
  store %sollang.array.i32 %v118155, ptr %slot118149, align 8
  %v118157 = load %sollang.array.i32, ptr %slot118149, align 8
  %v118189_raw = extractvalue %sollang.array.i32 %v118157, 1
  %v118189 = trunc i64 %v118189_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118189, i1 true)
  %v118159 = load %sollang.array.i32, ptr %slot118149, align 8
  %v118190_capacity_source = load %sollang.array.i32, ptr %slot118149, align 8
  %v118190_raw = extractvalue %sollang.array.i32 %v118190_capacity_source, 2
  %v118190_capacity_fits = icmp ule i64 %v118190_raw, 2147483647
  br i1 %v118190_capacity_fits, label %v118190_capacity_ok, label %v118190_capacity_fail
v118190_capacity_fail:
  call void @llvm.trap()
  unreachable
v118190_capacity_ok:
  %v118190 = trunc i64 %v118190_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118190, i1 true)
  %v118161 = load %sollang.array.i32, ptr %slot118149, align 8
  %push118160_data = extractvalue %sollang.array.i32 %v118161, 0
  %push118160_length = extractvalue %sollang.array.i32 %v118161, 1
  %push118160_capacity = extractvalue %sollang.array.i32 %v118161, 2
  %push118160_full = icmp eq i64 %push118160_length, %push118160_capacity
  %push118160_empty = icmp eq i64 %push118160_capacity, 0
  %push118160_doubled = mul i64 %push118160_capacity, 2
  %push118160_grown_capacity = select i1 %push118160_empty, i64 4, i64 %push118160_doubled
  %push118160_append_capacity = select i1 %push118160_full, i64 %push118160_grown_capacity, i64 %push118160_capacity
  %push118160_append_bytes = mul i64 %push118160_append_capacity, 4
  br i1 %push118160_full, label %push118160_grow, label %push118160_keep
push118160_keep:
  br label %push118160_ready
push118160_grow:
  %push118160_grown_data = call ptr @malloc(i64 %push118160_append_bytes)
  %push118160_allocated = icmp ne ptr %push118160_grown_data, null
  br i1 %push118160_allocated, label %push118160_copy, label %push118160_allocation_failed
push118160_allocation_failed:
  call void @llvm.trap()
  unreachable
push118160_copy:
  %push118160_copy_bytes = mul i64 %push118160_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118160_grown_data, ptr %push118160_data, i64 %push118160_copy_bytes, i1 false)
  call void @free(ptr %push118160_data)
  br label %push118160_ready
push118160_ready:
  %push118160_append_data = phi ptr [ %push118160_data, %push118160_keep ], [ %push118160_grown_data, %push118160_copy ]
  %push118160_slot = getelementptr i32, ptr %push118160_append_data, i64 %push118160_length
  store i32 10, ptr %push118160_slot, align 4
  %push118160_new_length = add i64 %push118160_length, 1
  %push118160_array0 = insertvalue %sollang.array.i32 poison, ptr %push118160_append_data, 0
  %push118160_array1 = insertvalue %sollang.array.i32 %push118160_array0, i64 %push118160_new_length, 1
  %push118160_array2 = insertvalue %sollang.array.i32 %push118160_array1, i64 %push118160_append_capacity, 2
  store %sollang.array.i32 %push118160_array2, ptr %slot118149, align 8
  %v118164 = load %sollang.array.i32, ptr %slot118149, align 8
  %push118163_data = extractvalue %sollang.array.i32 %v118164, 0
  %push118163_length = extractvalue %sollang.array.i32 %v118164, 1
  %push118163_capacity = extractvalue %sollang.array.i32 %v118164, 2
  %push118163_full = icmp eq i64 %push118163_length, %push118163_capacity
  %push118163_empty = icmp eq i64 %push118163_capacity, 0
  %push118163_doubled = mul i64 %push118163_capacity, 2
  %push118163_grown_capacity = select i1 %push118163_empty, i64 4, i64 %push118163_doubled
  %push118163_append_capacity = select i1 %push118163_full, i64 %push118163_grown_capacity, i64 %push118163_capacity
  %push118163_append_bytes = mul i64 %push118163_append_capacity, 4
  br i1 %push118163_full, label %push118163_grow, label %push118163_keep
push118163_keep:
  br label %push118163_ready
push118163_grow:
  %push118163_grown_data = call ptr @malloc(i64 %push118163_append_bytes)
  %push118163_allocated = icmp ne ptr %push118163_grown_data, null
  br i1 %push118163_allocated, label %push118163_copy, label %push118163_allocation_failed
push118163_allocation_failed:
  call void @llvm.trap()
  unreachable
push118163_copy:
  %push118163_copy_bytes = mul i64 %push118163_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118163_grown_data, ptr %push118163_data, i64 %push118163_copy_bytes, i1 false)
  call void @free(ptr %push118163_data)
  br label %push118163_ready
push118163_ready:
  %push118163_append_data = phi ptr [ %push118163_data, %push118163_keep ], [ %push118163_grown_data, %push118163_copy ]
  %push118163_slot = getelementptr i32, ptr %push118163_append_data, i64 %push118163_length
  store i32 20, ptr %push118163_slot, align 4
  %push118163_new_length = add i64 %push118163_length, 1
  %push118163_array0 = insertvalue %sollang.array.i32 poison, ptr %push118163_append_data, 0
  %push118163_array1 = insertvalue %sollang.array.i32 %push118163_array0, i64 %push118163_new_length, 1
  %push118163_array2 = insertvalue %sollang.array.i32 %push118163_array1, i64 %push118163_append_capacity, 2
  store %sollang.array.i32 %push118163_array2, ptr %slot118149, align 8
  %v118167 = load %sollang.array.i32, ptr %slot118149, align 8
  %v118191_raw = extractvalue %sollang.array.i32 %v118167, 1
  %v118191 = trunc i64 %v118191_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118191, i1 true)
  %v118170 = load %sollang.array.i32, ptr %slot118149, align 8
  %v118169_data = extractvalue %sollang.array.i32 %v118170, 0
  %v118169_length = extractvalue %sollang.array.i32 %v118170, 1
  %v118169_in_bounds = icmp ult i64 1, %v118169_length
  br i1 %v118169_in_bounds, label %v118169_index_ok, label %v118169_index_fail
v118169_index_fail:
  call void @llvm.trap()
  unreachable
v118169_index_ok:
  %v118169_ptr = getelementptr i32, ptr %v118169_data, i64 1
  %v118169 = load i32, ptr %v118169_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118169, i1 true)
  %v118172_data = call ptr @malloc(i64 16)
  %v118172_0 = insertvalue %sollang.array.i32 poison, ptr %v118172_data, 0
  %v118172_1 = insertvalue %sollang.array.i32 %v118172_0, i64 0, 1
  %v118172 = insertvalue %sollang.array.i32 %v118172_1, i64 4, 2
  store %sollang.array.i32 %v118172, ptr %slot118150, align 8
  %v118174 = load %sollang.array.i32, ptr %slot118150, align 8
  %v118192_raw = extractvalue %sollang.array.i32 %v118174, 1
  %v118192 = trunc i64 %v118192_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118192, i1 true)
  %v118176 = load %sollang.array.i32, ptr %slot118150, align 8
  %v118193_capacity_source = load %sollang.array.i32, ptr %slot118150, align 8
  %v118193_raw = extractvalue %sollang.array.i32 %v118193_capacity_source, 2
  %v118193_capacity_fits = icmp ule i64 %v118193_raw, 2147483647
  br i1 %v118193_capacity_fits, label %v118193_capacity_ok, label %v118193_capacity_fail
v118193_capacity_fail:
  call void @llvm.trap()
  unreachable
v118193_capacity_ok:
  %v118193 = trunc i64 %v118193_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118193, i1 true)
  %v118178 = load %sollang.array.i32, ptr %slot118150, align 8
  %push118177_data = extractvalue %sollang.array.i32 %v118178, 0
  %push118177_length = extractvalue %sollang.array.i32 %v118178, 1
  %push118177_capacity = extractvalue %sollang.array.i32 %v118178, 2
  %push118177_full = icmp eq i64 %push118177_length, %push118177_capacity
  %push118177_empty = icmp eq i64 %push118177_capacity, 0
  %push118177_doubled = mul i64 %push118177_capacity, 2
  %push118177_grown_capacity = select i1 %push118177_empty, i64 4, i64 %push118177_doubled
  %push118177_append_capacity = select i1 %push118177_full, i64 %push118177_grown_capacity, i64 %push118177_capacity
  %push118177_append_bytes = mul i64 %push118177_append_capacity, 4
  br i1 %push118177_full, label %push118177_grow, label %push118177_keep
push118177_keep:
  br label %push118177_ready
push118177_grow:
  %push118177_grown_data = call ptr @malloc(i64 %push118177_append_bytes)
  %push118177_allocated = icmp ne ptr %push118177_grown_data, null
  br i1 %push118177_allocated, label %push118177_copy, label %push118177_allocation_failed
push118177_allocation_failed:
  call void @llvm.trap()
  unreachable
push118177_copy:
  %push118177_copy_bytes = mul i64 %push118177_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118177_grown_data, ptr %push118177_data, i64 %push118177_copy_bytes, i1 false)
  call void @free(ptr %push118177_data)
  br label %push118177_ready
push118177_ready:
  %push118177_append_data = phi ptr [ %push118177_data, %push118177_keep ], [ %push118177_grown_data, %push118177_copy ]
  %push118177_slot = getelementptr i32, ptr %push118177_append_data, i64 %push118177_length
  store i32 10, ptr %push118177_slot, align 4
  %push118177_new_length = add i64 %push118177_length, 1
  %push118177_array0 = insertvalue %sollang.array.i32 poison, ptr %push118177_append_data, 0
  %push118177_array1 = insertvalue %sollang.array.i32 %push118177_array0, i64 %push118177_new_length, 1
  %push118177_array2 = insertvalue %sollang.array.i32 %push118177_array1, i64 %push118177_append_capacity, 2
  store %sollang.array.i32 %push118177_array2, ptr %slot118150, align 8
  %v118181 = load %sollang.array.i32, ptr %slot118150, align 8
  %push118180_data = extractvalue %sollang.array.i32 %v118181, 0
  %push118180_length = extractvalue %sollang.array.i32 %v118181, 1
  %push118180_capacity = extractvalue %sollang.array.i32 %v118181, 2
  %push118180_full = icmp eq i64 %push118180_length, %push118180_capacity
  %push118180_empty = icmp eq i64 %push118180_capacity, 0
  %push118180_doubled = mul i64 %push118180_capacity, 2
  %push118180_grown_capacity = select i1 %push118180_empty, i64 4, i64 %push118180_doubled
  %push118180_append_capacity = select i1 %push118180_full, i64 %push118180_grown_capacity, i64 %push118180_capacity
  %push118180_append_bytes = mul i64 %push118180_append_capacity, 4
  br i1 %push118180_full, label %push118180_grow, label %push118180_keep
push118180_keep:
  br label %push118180_ready
push118180_grow:
  %push118180_grown_data = call ptr @malloc(i64 %push118180_append_bytes)
  %push118180_allocated = icmp ne ptr %push118180_grown_data, null
  br i1 %push118180_allocated, label %push118180_copy, label %push118180_allocation_failed
push118180_allocation_failed:
  call void @llvm.trap()
  unreachable
push118180_copy:
  %push118180_copy_bytes = mul i64 %push118180_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118180_grown_data, ptr %push118180_data, i64 %push118180_copy_bytes, i1 false)
  call void @free(ptr %push118180_data)
  br label %push118180_ready
push118180_ready:
  %push118180_append_data = phi ptr [ %push118180_data, %push118180_keep ], [ %push118180_grown_data, %push118180_copy ]
  %push118180_slot = getelementptr i32, ptr %push118180_append_data, i64 %push118180_length
  store i32 20, ptr %push118180_slot, align 4
  %push118180_new_length = add i64 %push118180_length, 1
  %push118180_array0 = insertvalue %sollang.array.i32 poison, ptr %push118180_append_data, 0
  %push118180_array1 = insertvalue %sollang.array.i32 %push118180_array0, i64 %push118180_new_length, 1
  %push118180_array2 = insertvalue %sollang.array.i32 %push118180_array1, i64 %push118180_append_capacity, 2
  store %sollang.array.i32 %push118180_array2, ptr %slot118150, align 8
  %v118184 = load %sollang.array.i32, ptr %slot118150, align 8
  %v118194_raw = extractvalue %sollang.array.i32 %v118184, 1
  %v118194 = trunc i64 %v118194_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118194, i1 true)
  %v118187 = load %sollang.array.i32, ptr %slot118150, align 8
  %v118186_data = extractvalue %sollang.array.i32 %v118187, 0
  %v118186_length = extractvalue %sollang.array.i32 %v118187, 1
  %v118186_in_bounds = icmp ult i64 1, %v118186_length
  br i1 %v118186_in_bounds, label %v118186_index_ok, label %v118186_index_fail
v118186_index_fail:
  call void @llvm.trap()
  unreachable
v118186_index_ok:
  %v118186_ptr = getelementptr i32, ptr %v118186_data, i64 1
  %v118186 = load i32, ptr %v118186_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118186, i1 true)
  %cleanup1181531_b118150_current = load %sollang.array.i32, ptr %slot118150, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181531_b118150_current)
  %cleanup1181531_b118149_current = load %sollang.array.i32, ptr %slot118149, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181531_b118149_current)
  br label %if118153_merge
if118153_merge:
  ret void
}

define void @sollang_m144_s6() {
entry:
  %slot118197 = alloca i32, align 4
  %slot118198 = alloca %sollang.array.i32, align 8
  %slot118199 = alloca %sollang.array.i32, align 8
  store i32 0, ptr %slot118197, align 4
  br label %while118206_header
while118206_header:
  %while118206_v118204 = load i32, ptr %slot118197, align 4
  %while118206_v118203 = icmp slt i32 %while118206_v118204, 1
  br i1 %while118206_v118203, label %while118206_body, label %while118206_exit
while118206_body:
  %v118208_data = inttoptr i64 0 to ptr
  %v118208_0 = insertvalue %sollang.array.i32 poison, ptr %v118208_data, 0
  %v118208_1 = insertvalue %sollang.array.i32 %v118208_0, i64 0, 1
  %v118208 = insertvalue %sollang.array.i32 %v118208_1, i64 0, 2
  store %sollang.array.i32 %v118208, ptr %slot118198, align 8
  %v118210 = load %sollang.array.i32, ptr %slot118198, align 8
  %v118245_raw = extractvalue %sollang.array.i32 %v118210, 1
  %v118245 = trunc i64 %v118245_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118245, i1 true)
  %v118212 = load %sollang.array.i32, ptr %slot118198, align 8
  %v118246_capacity_source = load %sollang.array.i32, ptr %slot118198, align 8
  %v118246_raw = extractvalue %sollang.array.i32 %v118246_capacity_source, 2
  %v118246_capacity_fits = icmp ule i64 %v118246_raw, 2147483647
  br i1 %v118246_capacity_fits, label %v118246_capacity_ok, label %v118246_capacity_fail
v118246_capacity_fail:
  call void @llvm.trap()
  unreachable
v118246_capacity_ok:
  %v118246 = trunc i64 %v118246_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118246, i1 true)
  %v118214 = load %sollang.array.i32, ptr %slot118198, align 8
  %push118213_data = extractvalue %sollang.array.i32 %v118214, 0
  %push118213_length = extractvalue %sollang.array.i32 %v118214, 1
  %push118213_capacity = extractvalue %sollang.array.i32 %v118214, 2
  %push118213_full = icmp eq i64 %push118213_length, %push118213_capacity
  %push118213_empty = icmp eq i64 %push118213_capacity, 0
  %push118213_doubled = mul i64 %push118213_capacity, 2
  %push118213_grown_capacity = select i1 %push118213_empty, i64 4, i64 %push118213_doubled
  %push118213_append_capacity = select i1 %push118213_full, i64 %push118213_grown_capacity, i64 %push118213_capacity
  %push118213_append_bytes = mul i64 %push118213_append_capacity, 4
  br i1 %push118213_full, label %push118213_grow, label %push118213_keep
push118213_keep:
  br label %push118213_ready
push118213_grow:
  %push118213_grown_data = call ptr @malloc(i64 %push118213_append_bytes)
  %push118213_allocated = icmp ne ptr %push118213_grown_data, null
  br i1 %push118213_allocated, label %push118213_copy, label %push118213_allocation_failed
push118213_allocation_failed:
  call void @llvm.trap()
  unreachable
push118213_copy:
  %push118213_copy_bytes = mul i64 %push118213_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118213_grown_data, ptr %push118213_data, i64 %push118213_copy_bytes, i1 false)
  call void @free(ptr %push118213_data)
  br label %push118213_ready
push118213_ready:
  %push118213_append_data = phi ptr [ %push118213_data, %push118213_keep ], [ %push118213_grown_data, %push118213_copy ]
  %push118213_slot = getelementptr i32, ptr %push118213_append_data, i64 %push118213_length
  store i32 10, ptr %push118213_slot, align 4
  %push118213_new_length = add i64 %push118213_length, 1
  %push118213_array0 = insertvalue %sollang.array.i32 poison, ptr %push118213_append_data, 0
  %push118213_array1 = insertvalue %sollang.array.i32 %push118213_array0, i64 %push118213_new_length, 1
  %push118213_array2 = insertvalue %sollang.array.i32 %push118213_array1, i64 %push118213_append_capacity, 2
  store %sollang.array.i32 %push118213_array2, ptr %slot118198, align 8
  %v118217 = load %sollang.array.i32, ptr %slot118198, align 8
  %push118216_data = extractvalue %sollang.array.i32 %v118217, 0
  %push118216_length = extractvalue %sollang.array.i32 %v118217, 1
  %push118216_capacity = extractvalue %sollang.array.i32 %v118217, 2
  %push118216_full = icmp eq i64 %push118216_length, %push118216_capacity
  %push118216_empty = icmp eq i64 %push118216_capacity, 0
  %push118216_doubled = mul i64 %push118216_capacity, 2
  %push118216_grown_capacity = select i1 %push118216_empty, i64 4, i64 %push118216_doubled
  %push118216_append_capacity = select i1 %push118216_full, i64 %push118216_grown_capacity, i64 %push118216_capacity
  %push118216_append_bytes = mul i64 %push118216_append_capacity, 4
  br i1 %push118216_full, label %push118216_grow, label %push118216_keep
push118216_keep:
  br label %push118216_ready
push118216_grow:
  %push118216_grown_data = call ptr @malloc(i64 %push118216_append_bytes)
  %push118216_allocated = icmp ne ptr %push118216_grown_data, null
  br i1 %push118216_allocated, label %push118216_copy, label %push118216_allocation_failed
push118216_allocation_failed:
  call void @llvm.trap()
  unreachable
push118216_copy:
  %push118216_copy_bytes = mul i64 %push118216_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118216_grown_data, ptr %push118216_data, i64 %push118216_copy_bytes, i1 false)
  call void @free(ptr %push118216_data)
  br label %push118216_ready
push118216_ready:
  %push118216_append_data = phi ptr [ %push118216_data, %push118216_keep ], [ %push118216_grown_data, %push118216_copy ]
  %push118216_slot = getelementptr i32, ptr %push118216_append_data, i64 %push118216_length
  store i32 20, ptr %push118216_slot, align 4
  %push118216_new_length = add i64 %push118216_length, 1
  %push118216_array0 = insertvalue %sollang.array.i32 poison, ptr %push118216_append_data, 0
  %push118216_array1 = insertvalue %sollang.array.i32 %push118216_array0, i64 %push118216_new_length, 1
  %push118216_array2 = insertvalue %sollang.array.i32 %push118216_array1, i64 %push118216_append_capacity, 2
  store %sollang.array.i32 %push118216_array2, ptr %slot118198, align 8
  %v118220 = load %sollang.array.i32, ptr %slot118198, align 8
  %v118247_raw = extractvalue %sollang.array.i32 %v118220, 1
  %v118247 = trunc i64 %v118247_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118247, i1 true)
  %v118223 = load %sollang.array.i32, ptr %slot118198, align 8
  %v118222_data = extractvalue %sollang.array.i32 %v118223, 0
  %v118222_length = extractvalue %sollang.array.i32 %v118223, 1
  %v118222_in_bounds = icmp ult i64 1, %v118222_length
  br i1 %v118222_in_bounds, label %v118222_index_ok, label %v118222_index_fail
v118222_index_fail:
  call void @llvm.trap()
  unreachable
v118222_index_ok:
  %v118222_ptr = getelementptr i32, ptr %v118222_data, i64 1
  %v118222 = load i32, ptr %v118222_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118222, i1 true)
  %v118225_data = call ptr @malloc(i64 16)
  %v118225_0 = insertvalue %sollang.array.i32 poison, ptr %v118225_data, 0
  %v118225_1 = insertvalue %sollang.array.i32 %v118225_0, i64 0, 1
  %v118225 = insertvalue %sollang.array.i32 %v118225_1, i64 4, 2
  store %sollang.array.i32 %v118225, ptr %slot118199, align 8
  %v118227 = load %sollang.array.i32, ptr %slot118199, align 8
  %v118248_raw = extractvalue %sollang.array.i32 %v118227, 1
  %v118248 = trunc i64 %v118248_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118248, i1 true)
  %v118229 = load %sollang.array.i32, ptr %slot118199, align 8
  %v118249_capacity_source = load %sollang.array.i32, ptr %slot118199, align 8
  %v118249_raw = extractvalue %sollang.array.i32 %v118249_capacity_source, 2
  %v118249_capacity_fits = icmp ule i64 %v118249_raw, 2147483647
  br i1 %v118249_capacity_fits, label %v118249_capacity_ok, label %v118249_capacity_fail
v118249_capacity_fail:
  call void @llvm.trap()
  unreachable
v118249_capacity_ok:
  %v118249 = trunc i64 %v118249_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118249, i1 true)
  %v118231 = load %sollang.array.i32, ptr %slot118199, align 8
  %push118230_data = extractvalue %sollang.array.i32 %v118231, 0
  %push118230_length = extractvalue %sollang.array.i32 %v118231, 1
  %push118230_capacity = extractvalue %sollang.array.i32 %v118231, 2
  %push118230_full = icmp eq i64 %push118230_length, %push118230_capacity
  %push118230_empty = icmp eq i64 %push118230_capacity, 0
  %push118230_doubled = mul i64 %push118230_capacity, 2
  %push118230_grown_capacity = select i1 %push118230_empty, i64 4, i64 %push118230_doubled
  %push118230_append_capacity = select i1 %push118230_full, i64 %push118230_grown_capacity, i64 %push118230_capacity
  %push118230_append_bytes = mul i64 %push118230_append_capacity, 4
  br i1 %push118230_full, label %push118230_grow, label %push118230_keep
push118230_keep:
  br label %push118230_ready
push118230_grow:
  %push118230_grown_data = call ptr @malloc(i64 %push118230_append_bytes)
  %push118230_allocated = icmp ne ptr %push118230_grown_data, null
  br i1 %push118230_allocated, label %push118230_copy, label %push118230_allocation_failed
push118230_allocation_failed:
  call void @llvm.trap()
  unreachable
push118230_copy:
  %push118230_copy_bytes = mul i64 %push118230_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118230_grown_data, ptr %push118230_data, i64 %push118230_copy_bytes, i1 false)
  call void @free(ptr %push118230_data)
  br label %push118230_ready
push118230_ready:
  %push118230_append_data = phi ptr [ %push118230_data, %push118230_keep ], [ %push118230_grown_data, %push118230_copy ]
  %push118230_slot = getelementptr i32, ptr %push118230_append_data, i64 %push118230_length
  store i32 10, ptr %push118230_slot, align 4
  %push118230_new_length = add i64 %push118230_length, 1
  %push118230_array0 = insertvalue %sollang.array.i32 poison, ptr %push118230_append_data, 0
  %push118230_array1 = insertvalue %sollang.array.i32 %push118230_array0, i64 %push118230_new_length, 1
  %push118230_array2 = insertvalue %sollang.array.i32 %push118230_array1, i64 %push118230_append_capacity, 2
  store %sollang.array.i32 %push118230_array2, ptr %slot118199, align 8
  %v118234 = load %sollang.array.i32, ptr %slot118199, align 8
  %push118233_data = extractvalue %sollang.array.i32 %v118234, 0
  %push118233_length = extractvalue %sollang.array.i32 %v118234, 1
  %push118233_capacity = extractvalue %sollang.array.i32 %v118234, 2
  %push118233_full = icmp eq i64 %push118233_length, %push118233_capacity
  %push118233_empty = icmp eq i64 %push118233_capacity, 0
  %push118233_doubled = mul i64 %push118233_capacity, 2
  %push118233_grown_capacity = select i1 %push118233_empty, i64 4, i64 %push118233_doubled
  %push118233_append_capacity = select i1 %push118233_full, i64 %push118233_grown_capacity, i64 %push118233_capacity
  %push118233_append_bytes = mul i64 %push118233_append_capacity, 4
  br i1 %push118233_full, label %push118233_grow, label %push118233_keep
push118233_keep:
  br label %push118233_ready
push118233_grow:
  %push118233_grown_data = call ptr @malloc(i64 %push118233_append_bytes)
  %push118233_allocated = icmp ne ptr %push118233_grown_data, null
  br i1 %push118233_allocated, label %push118233_copy, label %push118233_allocation_failed
push118233_allocation_failed:
  call void @llvm.trap()
  unreachable
push118233_copy:
  %push118233_copy_bytes = mul i64 %push118233_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118233_grown_data, ptr %push118233_data, i64 %push118233_copy_bytes, i1 false)
  call void @free(ptr %push118233_data)
  br label %push118233_ready
push118233_ready:
  %push118233_append_data = phi ptr [ %push118233_data, %push118233_keep ], [ %push118233_grown_data, %push118233_copy ]
  %push118233_slot = getelementptr i32, ptr %push118233_append_data, i64 %push118233_length
  store i32 20, ptr %push118233_slot, align 4
  %push118233_new_length = add i64 %push118233_length, 1
  %push118233_array0 = insertvalue %sollang.array.i32 poison, ptr %push118233_append_data, 0
  %push118233_array1 = insertvalue %sollang.array.i32 %push118233_array0, i64 %push118233_new_length, 1
  %push118233_array2 = insertvalue %sollang.array.i32 %push118233_array1, i64 %push118233_append_capacity, 2
  store %sollang.array.i32 %push118233_array2, ptr %slot118199, align 8
  %v118237 = load %sollang.array.i32, ptr %slot118199, align 8
  %v118250_raw = extractvalue %sollang.array.i32 %v118237, 1
  %v118250 = trunc i64 %v118250_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118250, i1 true)
  %v118240 = load %sollang.array.i32, ptr %slot118199, align 8
  %v118239_data = extractvalue %sollang.array.i32 %v118240, 0
  %v118239_length = extractvalue %sollang.array.i32 %v118240, 1
  %v118239_in_bounds = icmp ult i64 1, %v118239_length
  br i1 %v118239_in_bounds, label %v118239_index_ok, label %v118239_index_fail
v118239_index_fail:
  call void @llvm.trap()
  unreachable
v118239_index_ok:
  %v118239_ptr = getelementptr i32, ptr %v118239_data, i64 1
  %v118239 = load i32, ptr %v118239_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118239, i1 true)
  %v118243 = load i32, ptr %slot118197, align 4
  %v118242 = add i32 %v118243, 1
  store i32 %v118242, ptr %slot118197, align 4
  %cleanup1182063_b118199_current = load %sollang.array.i32, ptr %slot118199, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182063_b118199_current)
  %cleanup1182063_b118198_current = load %sollang.array.i32, ptr %slot118198, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182063_b118198_current)
  br label %while118206_header
while118206_exit:
  ret void
}

define i32 @main() {
entry:
  %v118292_data = alloca [12 x i8], align 4
  %slot118252 = alloca %sollang.array.i32, align 8
  %slot118253 = alloca %sollang.array.i32, align 8
  %v118255_data = inttoptr i64 0 to ptr
  %v118255_0 = insertvalue %sollang.array.i32 poison, ptr %v118255_data, 0
  %v118255_1 = insertvalue %sollang.array.i32 %v118255_0, i64 0, 1
  %v118255 = insertvalue %sollang.array.i32 %v118255_1, i64 0, 2
  %v118272_data = call ptr @malloc(i64 16)
  %v118272_0 = insertvalue %sollang.array.i32 poison, ptr %v118272_data, 0
  %v118272_1 = insertvalue %sollang.array.i32 %v118272_0, i64 0, 1
  %v118272 = insertvalue %sollang.array.i32 %v118272_1, i64 4, 2
  store %sollang.array.i32 %v118255, ptr %slot118252, align 8
  %v118257 = load %sollang.array.i32, ptr %slot118252, align 8
  %v118259 = load %sollang.array.i32, ptr %slot118252, align 8
  %v118261 = load %sollang.array.i32, ptr %slot118252, align 8
  %v118300_raw = extractvalue %sollang.array.i32 %v118257, 1
  %v118300 = trunc i64 %v118300_raw to i32
  %v118301_capacity_source = load %sollang.array.i32, ptr %slot118252, align 8
  %v118301_raw = extractvalue %sollang.array.i32 %v118301_capacity_source, 2
  %v118301_capacity_fits = icmp ule i64 %v118301_raw, 2147483647
  br i1 %v118301_capacity_fits, label %v118301_capacity_ok, label %v118301_capacity_fail
v118301_capacity_fail:
  call void @llvm.trap()
  unreachable
v118301_capacity_ok:
  %v118301 = trunc i64 %v118301_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118300, i1 true)
  call void @sollang_runtime_print_i32(i32 %v118301, i1 true)
  %push118260_data = extractvalue %sollang.array.i32 %v118261, 0
  %push118260_length = extractvalue %sollang.array.i32 %v118261, 1
  %push118260_capacity = extractvalue %sollang.array.i32 %v118261, 2
  %push118260_full = icmp eq i64 %push118260_length, %push118260_capacity
  %push118260_empty = icmp eq i64 %push118260_capacity, 0
  %push118260_doubled = mul i64 %push118260_capacity, 2
  %push118260_grown_capacity = select i1 %push118260_empty, i64 4, i64 %push118260_doubled
  %push118260_append_capacity = select i1 %push118260_full, i64 %push118260_grown_capacity, i64 %push118260_capacity
  %push118260_append_bytes = mul i64 %push118260_append_capacity, 4
  br i1 %push118260_full, label %push118260_grow, label %push118260_keep
push118260_keep:
  br label %push118260_ready
push118260_grow:
  %push118260_grown_data = call ptr @malloc(i64 %push118260_append_bytes)
  %push118260_allocated = icmp ne ptr %push118260_grown_data, null
  br i1 %push118260_allocated, label %push118260_copy, label %push118260_allocation_failed
push118260_allocation_failed:
  call void @llvm.trap()
  unreachable
push118260_copy:
  %push118260_copy_bytes = mul i64 %push118260_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118260_grown_data, ptr %push118260_data, i64 %push118260_copy_bytes, i1 false)
  call void @free(ptr %push118260_data)
  br label %push118260_ready
push118260_ready:
  %push118260_append_data = phi ptr [ %push118260_data, %push118260_keep ], [ %push118260_grown_data, %push118260_copy ]
  %push118260_slot = getelementptr i32, ptr %push118260_append_data, i64 %push118260_length
  store i32 10, ptr %push118260_slot, align 4
  %push118260_new_length = add i64 %push118260_length, 1
  %push118260_array0 = insertvalue %sollang.array.i32 poison, ptr %push118260_append_data, 0
  %push118260_array1 = insertvalue %sollang.array.i32 %push118260_array0, i64 %push118260_new_length, 1
  %push118260_array2 = insertvalue %sollang.array.i32 %push118260_array1, i64 %push118260_append_capacity, 2
  store %sollang.array.i32 %push118260_array2, ptr %slot118252, align 8
  %v118264 = load %sollang.array.i32, ptr %slot118252, align 8
  %push118263_data = extractvalue %sollang.array.i32 %v118264, 0
  %push118263_length = extractvalue %sollang.array.i32 %v118264, 1
  %push118263_capacity = extractvalue %sollang.array.i32 %v118264, 2
  %push118263_full = icmp eq i64 %push118263_length, %push118263_capacity
  %push118263_empty = icmp eq i64 %push118263_capacity, 0
  %push118263_doubled = mul i64 %push118263_capacity, 2
  %push118263_grown_capacity = select i1 %push118263_empty, i64 4, i64 %push118263_doubled
  %push118263_append_capacity = select i1 %push118263_full, i64 %push118263_grown_capacity, i64 %push118263_capacity
  %push118263_append_bytes = mul i64 %push118263_append_capacity, 4
  br i1 %push118263_full, label %push118263_grow, label %push118263_keep
push118263_keep:
  br label %push118263_ready
push118263_grow:
  %push118263_grown_data = call ptr @malloc(i64 %push118263_append_bytes)
  %push118263_allocated = icmp ne ptr %push118263_grown_data, null
  br i1 %push118263_allocated, label %push118263_copy, label %push118263_allocation_failed
push118263_allocation_failed:
  call void @llvm.trap()
  unreachable
push118263_copy:
  %push118263_copy_bytes = mul i64 %push118263_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118263_grown_data, ptr %push118263_data, i64 %push118263_copy_bytes, i1 false)
  call void @free(ptr %push118263_data)
  br label %push118263_ready
push118263_ready:
  %push118263_append_data = phi ptr [ %push118263_data, %push118263_keep ], [ %push118263_grown_data, %push118263_copy ]
  %push118263_slot = getelementptr i32, ptr %push118263_append_data, i64 %push118263_length
  store i32 20, ptr %push118263_slot, align 4
  %push118263_new_length = add i64 %push118263_length, 1
  %push118263_array0 = insertvalue %sollang.array.i32 poison, ptr %push118263_append_data, 0
  %push118263_array1 = insertvalue %sollang.array.i32 %push118263_array0, i64 %push118263_new_length, 1
  %push118263_array2 = insertvalue %sollang.array.i32 %push118263_array1, i64 %push118263_append_capacity, 2
  store %sollang.array.i32 %push118263_array2, ptr %slot118252, align 8
  %v118267 = load %sollang.array.i32, ptr %slot118252, align 8
  %v118270 = load %sollang.array.i32, ptr %slot118252, align 8
  %v118302_raw = extractvalue %sollang.array.i32 %v118267, 1
  %v118302 = trunc i64 %v118302_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118302, i1 true)
  %v118269_data = extractvalue %sollang.array.i32 %v118270, 0
  %v118269_length = extractvalue %sollang.array.i32 %v118270, 1
  %v118269_in_bounds = icmp ult i64 1, %v118269_length
  br i1 %v118269_in_bounds, label %v118269_index_ok, label %v118269_index_fail
v118269_index_fail:
  call void @llvm.trap()
  unreachable
v118269_index_ok:
  %v118269_ptr = getelementptr i32, ptr %v118269_data, i64 1
  %v118269 = load i32, ptr %v118269_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118269, i1 true)
  store %sollang.array.i32 %v118272, ptr %slot118253, align 8
  %v118274 = load %sollang.array.i32, ptr %slot118253, align 8
  %v118276 = load %sollang.array.i32, ptr %slot118253, align 8
  %v118278 = load %sollang.array.i32, ptr %slot118253, align 8
  %v118303_raw = extractvalue %sollang.array.i32 %v118274, 1
  %v118303 = trunc i64 %v118303_raw to i32
  %v118304_capacity_source = load %sollang.array.i32, ptr %slot118253, align 8
  %v118304_raw = extractvalue %sollang.array.i32 %v118304_capacity_source, 2
  %v118304_capacity_fits = icmp ule i64 %v118304_raw, 2147483647
  br i1 %v118304_capacity_fits, label %v118304_capacity_ok, label %v118304_capacity_fail
v118304_capacity_fail:
  call void @llvm.trap()
  unreachable
v118304_capacity_ok:
  %v118304 = trunc i64 %v118304_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118303, i1 true)
  call void @sollang_runtime_print_i32(i32 %v118304, i1 true)
  %push118277_data = extractvalue %sollang.array.i32 %v118278, 0
  %push118277_length = extractvalue %sollang.array.i32 %v118278, 1
  %push118277_capacity = extractvalue %sollang.array.i32 %v118278, 2
  %push118277_full = icmp eq i64 %push118277_length, %push118277_capacity
  %push118277_empty = icmp eq i64 %push118277_capacity, 0
  %push118277_doubled = mul i64 %push118277_capacity, 2
  %push118277_grown_capacity = select i1 %push118277_empty, i64 4, i64 %push118277_doubled
  %push118277_append_capacity = select i1 %push118277_full, i64 %push118277_grown_capacity, i64 %push118277_capacity
  %push118277_append_bytes = mul i64 %push118277_append_capacity, 4
  br i1 %push118277_full, label %push118277_grow, label %push118277_keep
push118277_keep:
  br label %push118277_ready
push118277_grow:
  %push118277_grown_data = call ptr @malloc(i64 %push118277_append_bytes)
  %push118277_allocated = icmp ne ptr %push118277_grown_data, null
  br i1 %push118277_allocated, label %push118277_copy, label %push118277_allocation_failed
push118277_allocation_failed:
  call void @llvm.trap()
  unreachable
push118277_copy:
  %push118277_copy_bytes = mul i64 %push118277_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118277_grown_data, ptr %push118277_data, i64 %push118277_copy_bytes, i1 false)
  call void @free(ptr %push118277_data)
  br label %push118277_ready
push118277_ready:
  %push118277_append_data = phi ptr [ %push118277_data, %push118277_keep ], [ %push118277_grown_data, %push118277_copy ]
  %push118277_slot = getelementptr i32, ptr %push118277_append_data, i64 %push118277_length
  store i32 10, ptr %push118277_slot, align 4
  %push118277_new_length = add i64 %push118277_length, 1
  %push118277_array0 = insertvalue %sollang.array.i32 poison, ptr %push118277_append_data, 0
  %push118277_array1 = insertvalue %sollang.array.i32 %push118277_array0, i64 %push118277_new_length, 1
  %push118277_array2 = insertvalue %sollang.array.i32 %push118277_array1, i64 %push118277_append_capacity, 2
  store %sollang.array.i32 %push118277_array2, ptr %slot118253, align 8
  %v118281 = load %sollang.array.i32, ptr %slot118253, align 8
  %push118280_data = extractvalue %sollang.array.i32 %v118281, 0
  %push118280_length = extractvalue %sollang.array.i32 %v118281, 1
  %push118280_capacity = extractvalue %sollang.array.i32 %v118281, 2
  %push118280_full = icmp eq i64 %push118280_length, %push118280_capacity
  %push118280_empty = icmp eq i64 %push118280_capacity, 0
  %push118280_doubled = mul i64 %push118280_capacity, 2
  %push118280_grown_capacity = select i1 %push118280_empty, i64 4, i64 %push118280_doubled
  %push118280_append_capacity = select i1 %push118280_full, i64 %push118280_grown_capacity, i64 %push118280_capacity
  %push118280_append_bytes = mul i64 %push118280_append_capacity, 4
  br i1 %push118280_full, label %push118280_grow, label %push118280_keep
push118280_keep:
  br label %push118280_ready
push118280_grow:
  %push118280_grown_data = call ptr @malloc(i64 %push118280_append_bytes)
  %push118280_allocated = icmp ne ptr %push118280_grown_data, null
  br i1 %push118280_allocated, label %push118280_copy, label %push118280_allocation_failed
push118280_allocation_failed:
  call void @llvm.trap()
  unreachable
push118280_copy:
  %push118280_copy_bytes = mul i64 %push118280_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118280_grown_data, ptr %push118280_data, i64 %push118280_copy_bytes, i1 false)
  call void @free(ptr %push118280_data)
  br label %push118280_ready
push118280_ready:
  %push118280_append_data = phi ptr [ %push118280_data, %push118280_keep ], [ %push118280_grown_data, %push118280_copy ]
  %push118280_slot = getelementptr i32, ptr %push118280_append_data, i64 %push118280_length
  store i32 20, ptr %push118280_slot, align 4
  %push118280_new_length = add i64 %push118280_length, 1
  %push118280_array0 = insertvalue %sollang.array.i32 poison, ptr %push118280_append_data, 0
  %push118280_array1 = insertvalue %sollang.array.i32 %push118280_array0, i64 %push118280_new_length, 1
  %push118280_array2 = insertvalue %sollang.array.i32 %push118280_array1, i64 %push118280_append_capacity, 2
  store %sollang.array.i32 %push118280_array2, ptr %slot118253, align 8
  %v118284 = load %sollang.array.i32, ptr %slot118253, align 8
  %v118287 = load %sollang.array.i32, ptr %slot118253, align 8
  %v118305_raw = extractvalue %sollang.array.i32 %v118284, 1
  %v118305 = trunc i64 %v118305_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118305, i1 true)
  %v118286_data = extractvalue %sollang.array.i32 %v118287, 0
  %v118286_length = extractvalue %sollang.array.i32 %v118287, 1
  %v118286_in_bounds = icmp ult i64 1, %v118286_length
  br i1 %v118286_in_bounds, label %v118286_index_ok, label %v118286_index_fail
v118286_index_fail:
  call void @llvm.trap()
  unreachable
v118286_index_ok:
  %v118286_ptr = getelementptr i32, ptr %v118286_data, i64 1
  %v118286 = load i32, ptr %v118286_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118286, i1 true)
  call void @sollang_m144_s0()
  call void @sollang_m144_s3()
  call void @sollang_m144_s6()
  %v118292_ptr0 = getelementptr i32, ptr %v118292_data, i64 0
  store i32 7, ptr %v118292_ptr0, align 4
  %v118292_ptr1 = getelementptr i32, ptr %v118292_data, i64 1
  store i32 7, ptr %v118292_ptr1, align 4
  %v118292_ptr2 = getelementptr i32, ptr %v118292_data, i64 2
  store i32 7, ptr %v118292_ptr2, align 4
  %v118292_0 = insertvalue { ptr, i64 } poison, ptr %v118292_data, 0
  %v118292 = insertvalue { ptr, i64 } %v118292_0, i64 3, 1
  %v118295 = freeze { ptr, i64 } %v118292
  %v118298 = freeze { ptr, i64 } %v118292
  %v118306_raw = extractvalue { ptr, i64 } %v118295, 1
  %v118306 = trunc i64 %v118306_raw to i32
  call void @sollang_runtime_print_i32(i32 %v118306, i1 true)
  %v118297_data = extractvalue { ptr, i64 } %v118298, 0
  %v118297_length = extractvalue { ptr, i64 } %v118298, 1
  %v118297_in_bounds = icmp ult i64 2, %v118297_length
  br i1 %v118297_in_bounds, label %v118297_index_ok, label %v118297_index_fail
v118297_index_fail:
  call void @llvm.trap()
  unreachable
v118297_index_ok:
  %v118297_ptr = getelementptr i32, ptr %v118297_data, i64 2
  %v118297 = load i32, ptr %v118297_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118297, i1 true)
  %cleanup1182516_b118253_current = load %sollang.array.i32, ptr %slot118253, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182516_b118253_current)
  %cleanup1182516_b118252_current = load %sollang.array.i32, ptr %slot118252, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182516_b118252_current)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
