define void @sollang_m144_s2(ptr %arg) {
entry:
  %calltext118106_arg0_root0_buffer = alloca [21 x i8], align 1
  %v118107_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118107, 0
  %v118107 = insertvalue %sollang.text %v118107_ptr, i64 38, 1
  %v118106_expression_literal0 = getelementptr i8, ptr @sollang_str_118107, i64 0
  call void @sollang_runtime_print(ptr %v118106_expression_literal0, i64 10, i1 false)
  %v118106_expression1_address = getelementptr inbounds %sollang.struct.m144_s0, ptr %arg, i32 0, i32 0
  %v118106_expression1 = load %sollang.array.i32, ptr %v118106_expression1_address, align 8
  %v118106_expression0_raw = extractvalue %sollang.array.i32 %v118106_expression1, 2
  %v118106_expression0 = trunc i64 %v118106_expression0_raw to i32
  %v118106_expression0_print = zext i32 %v118106_expression0 to i64
  call void @sollang_runtime_print_i64(i64 %v118106_expression0_print, i1 false, i1 false)
  %v118106_expression_suffix = getelementptr i8, ptr @sollang_str_118107, i64 38
  call void @sollang_runtime_print(ptr %v118106_expression_suffix, i64 0, i1 true)
  ret void
}

define void @sollang_m144_s3(ptr %arg) {
entry:
  %calltext118111_arg0_root0_buffer = alloca [21 x i8], align 1
  %v118112_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118112, 0
  %v118112 = insertvalue %sollang.text %v118112_ptr, i64 30, 1
  %v118111_expression_literal0 = getelementptr i8, ptr @sollang_str_118112, i64 0
  call void @sollang_runtime_print(ptr %v118111_expression_literal0, i64 9, i1 false)
  %v118111_expression3_capacity_source = load %sollang.array.i32, ptr %arg, align 8
  %v118111_expression3_raw = extractvalue %sollang.array.i32 %v118111_expression3_capacity_source, 2
  %v118111_expression3 = trunc i64 %v118111_expression3_raw to i32
  %v118111_expression3_print = zext i32 %v118111_expression3 to i64
  call void @sollang_runtime_print_i64(i64 %v118111_expression3_print, i1 false, i1 false)
  %v118111_expression_suffix = getelementptr i8, ptr @sollang_str_118112, i64 30
  call void @sollang_runtime_print(ptr %v118111_expression_suffix, i64 0, i1 true)
  ret void
}

define i32 @sollang_m144_s4(i32 %arg) {
entry:
  call void @sollang_runtime_print_i32(i32 %arg, i1 true)
  ret i32 %arg
}

define void @sollang_m144_s5() {
entry:
  %calltext118124_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118124_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118132_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118132_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118135_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118135_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118143_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118143_arg0_root1_buffer = alloca [21 x i8], align 1
  %slot118121 = alloca %sollang.array.i32, align 8
  %slot118122 = alloca %sollang.array.i32, align 8
  %v118123_data = inttoptr i64 0 to ptr
  %v118123_0 = insertvalue %sollang.array.i32 poison, ptr %v118123_data, 0
  %v118123_1 = insertvalue %sollang.array.i32 %v118123_0, i64 0, 1
  %v118123 = insertvalue %sollang.array.i32 %v118123_1, i64 0, 2
  %v118125_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118125, 0
  %v118125 = insertvalue %sollang.text %v118125_ptr, i64 30, 1
  %v118133_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118133, 0
  %v118133 = insertvalue %sollang.text %v118133_ptr, i64 21, 1
  %v118136_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118136, 0
  %v118136 = insertvalue %sollang.text %v118136_ptr, i64 30, 1
  %v118144_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118144, 0
  %v118144 = insertvalue %sollang.text %v118144_ptr, i64 21, 1
  store %sollang.array.i32 %v118123, ptr %slot118121, align 8
  %v118124_expression_literal0 = getelementptr i8, ptr @sollang_str_118125, i64 0
  call void @sollang_runtime_print(ptr %v118124_expression_literal0, i64 0, i1 false)
  %v118124_expression6_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118124_expression5_raw = extractvalue %sollang.array.i32 %v118124_expression6_mutable, 1
  %v118124_expression5 = trunc i64 %v118124_expression5_raw to i32
  %v118124_expression5_print = zext i32 %v118124_expression5 to i64
  call void @sollang_runtime_print_i64(i64 %v118124_expression5_print, i1 false, i1 false)
  %v118124_expression_literal1 = getelementptr i8, ptr @sollang_str_118125, i64 12
  call void @sollang_runtime_print(ptr %v118124_expression_literal1, i64 1, i1 false)
  %v118124_expression8_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118124_expression7_raw = extractvalue %sollang.array.i32 %v118124_expression8_mutable, 2
  %v118124_expression7 = trunc i64 %v118124_expression7_raw to i32
  %v118124_expression7_print = zext i32 %v118124_expression7 to i64
  call void @sollang_runtime_print_i64(i64 %v118124_expression7_print, i1 false, i1 false)
  %v118124_expression_suffix = getelementptr i8, ptr @sollang_str_118125, i64 30
  call void @sollang_runtime_print(ptr %v118124_expression_suffix, i64 0, i1 true)
  %v118127 = load %sollang.array.i32, ptr %slot118121, align 8
  %push118126_data = extractvalue %sollang.array.i32 %v118127, 0
  %push118126_length = extractvalue %sollang.array.i32 %v118127, 1
  %push118126_capacity = extractvalue %sollang.array.i32 %v118127, 2
  %push118126_full = icmp eq i64 %push118126_length, %push118126_capacity
  %push118126_empty = icmp eq i64 %push118126_capacity, 0
  %push118126_doubled = mul i64 %push118126_capacity, 2
  %push118126_grown_capacity = select i1 %push118126_empty, i64 4, i64 %push118126_doubled
  %push118126_append_capacity = select i1 %push118126_full, i64 %push118126_grown_capacity, i64 %push118126_capacity
  %push118126_append_bytes = mul i64 %push118126_append_capacity, 4
  br i1 %push118126_full, label %push118126_grow, label %push118126_keep
push118126_keep:
  br label %push118126_ready
push118126_grow:
  %push118126_grown_data = call ptr @malloc(i64 %push118126_append_bytes)
  %push118126_allocated = icmp ne ptr %push118126_grown_data, null
  br i1 %push118126_allocated, label %push118126_copy, label %push118126_allocation_failed
push118126_allocation_failed:
  call void @llvm.trap()
  unreachable
push118126_copy:
  %push118126_copy_bytes = mul i64 %push118126_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118126_grown_data, ptr %push118126_data, i64 %push118126_copy_bytes, i1 false)
  call void @free(ptr %push118126_data)
  br label %push118126_ready
push118126_ready:
  %push118126_append_data = phi ptr [ %push118126_data, %push118126_keep ], [ %push118126_grown_data, %push118126_copy ]
  %push118126_slot = getelementptr i32, ptr %push118126_append_data, i64 %push118126_length
  store i32 10, ptr %push118126_slot, align 4
  %push118126_new_length = add i64 %push118126_length, 1
  %push118126_array0 = insertvalue %sollang.array.i32 poison, ptr %push118126_append_data, 0
  %push118126_array1 = insertvalue %sollang.array.i32 %push118126_array0, i64 %push118126_new_length, 1
  %push118126_array2 = insertvalue %sollang.array.i32 %push118126_array1, i64 %push118126_append_capacity, 2
  store %sollang.array.i32 %push118126_array2, ptr %slot118121, align 8
  %v118130 = load %sollang.array.i32, ptr %slot118121, align 8
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
  store i32 20, ptr %push118129_slot, align 4
  %push118129_new_length = add i64 %push118129_length, 1
  %push118129_array0 = insertvalue %sollang.array.i32 poison, ptr %push118129_append_data, 0
  %push118129_array1 = insertvalue %sollang.array.i32 %push118129_array0, i64 %push118129_new_length, 1
  %push118129_array2 = insertvalue %sollang.array.i32 %push118129_array1, i64 %push118129_append_capacity, 2
  store %sollang.array.i32 %push118129_array2, ptr %slot118121, align 8
  %v118132_expression_literal0 = getelementptr i8, ptr @sollang_str_118133, i64 0
  call void @sollang_runtime_print(ptr %v118132_expression_literal0, i64 0, i1 false)
  %v118132_expression10_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118132_expression9_raw = extractvalue %sollang.array.i32 %v118132_expression10_mutable, 1
  %v118132_expression9 = trunc i64 %v118132_expression9_raw to i32
  %v118132_expression9_print = zext i32 %v118132_expression9 to i64
  call void @sollang_runtime_print_i64(i64 %v118132_expression9_print, i1 false, i1 false)
  %v118132_expression_literal1 = getelementptr i8, ptr @sollang_str_118133, i64 12
  call void @sollang_runtime_print(ptr %v118132_expression_literal1, i64 1, i1 false)
  %v118132_expression12_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118132_expression11_data = extractvalue %sollang.array.i32 %v118132_expression12_mutable, 0
  %v118132_expression11_index = sext i32 1 to i64
  %v118132_expression11_length = extractvalue %sollang.array.i32 %v118132_expression12_mutable, 1
  %v118132_expression11_in_bounds = icmp ult i64 %v118132_expression11_index, %v118132_expression11_length
  br i1 %v118132_expression11_in_bounds, label %interpolation118132_array11_valid, label %interpolation118132_array11_invalid
interpolation118132_array11_invalid:
  call void @llvm.trap()
  unreachable
interpolation118132_array11_valid:
  %v118132_expression11_ptr = getelementptr i32, ptr %v118132_expression11_data, i64 %v118132_expression11_index
  %v118132_expression11 = load i32, ptr %v118132_expression11_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118132_expression11, i1 false)
  %v118132_expression_suffix = getelementptr i8, ptr @sollang_str_118133, i64 21
  call void @sollang_runtime_print(ptr %v118132_expression_suffix, i64 0, i1 true)
  %v118134_data = call ptr @malloc(i64 16)
  %v118134_0 = insertvalue %sollang.array.i32 poison, ptr %v118134_data, 0
  %v118134_1 = insertvalue %sollang.array.i32 %v118134_0, i64 0, 1
  %v118134 = insertvalue %sollang.array.i32 %v118134_1, i64 4, 2
  store %sollang.array.i32 %v118134, ptr %slot118122, align 8
  %v118135_expression_literal0 = getelementptr i8, ptr @sollang_str_118136, i64 0
  call void @sollang_runtime_print(ptr %v118135_expression_literal0, i64 0, i1 false)
  %v118135_expression15_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118135_expression14_raw = extractvalue %sollang.array.i32 %v118135_expression15_mutable, 1
  %v118135_expression14 = trunc i64 %v118135_expression14_raw to i32
  %v118135_expression14_print = zext i32 %v118135_expression14 to i64
  call void @sollang_runtime_print_i64(i64 %v118135_expression14_print, i1 false, i1 false)
  %v118135_expression_literal1 = getelementptr i8, ptr @sollang_str_118136, i64 12
  call void @sollang_runtime_print(ptr %v118135_expression_literal1, i64 1, i1 false)
  %v118135_expression17_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118135_expression16_raw = extractvalue %sollang.array.i32 %v118135_expression17_mutable, 2
  %v118135_expression16 = trunc i64 %v118135_expression16_raw to i32
  %v118135_expression16_print = zext i32 %v118135_expression16 to i64
  call void @sollang_runtime_print_i64(i64 %v118135_expression16_print, i1 false, i1 false)
  %v118135_expression_suffix = getelementptr i8, ptr @sollang_str_118136, i64 30
  call void @sollang_runtime_print(ptr %v118135_expression_suffix, i64 0, i1 true)
  %v118138 = load %sollang.array.i32, ptr %slot118122, align 8
  %push118137_data = extractvalue %sollang.array.i32 %v118138, 0
  %push118137_length = extractvalue %sollang.array.i32 %v118138, 1
  %push118137_capacity = extractvalue %sollang.array.i32 %v118138, 2
  %push118137_full = icmp eq i64 %push118137_length, %push118137_capacity
  %push118137_empty = icmp eq i64 %push118137_capacity, 0
  %push118137_doubled = mul i64 %push118137_capacity, 2
  %push118137_grown_capacity = select i1 %push118137_empty, i64 4, i64 %push118137_doubled
  %push118137_append_capacity = select i1 %push118137_full, i64 %push118137_grown_capacity, i64 %push118137_capacity
  %push118137_append_bytes = mul i64 %push118137_append_capacity, 4
  br i1 %push118137_full, label %push118137_grow, label %push118137_keep
push118137_keep:
  br label %push118137_ready
push118137_grow:
  %push118137_grown_data = call ptr @malloc(i64 %push118137_append_bytes)
  %push118137_allocated = icmp ne ptr %push118137_grown_data, null
  br i1 %push118137_allocated, label %push118137_copy, label %push118137_allocation_failed
push118137_allocation_failed:
  call void @llvm.trap()
  unreachable
push118137_copy:
  %push118137_copy_bytes = mul i64 %push118137_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118137_grown_data, ptr %push118137_data, i64 %push118137_copy_bytes, i1 false)
  call void @free(ptr %push118137_data)
  br label %push118137_ready
push118137_ready:
  %push118137_append_data = phi ptr [ %push118137_data, %push118137_keep ], [ %push118137_grown_data, %push118137_copy ]
  %push118137_slot = getelementptr i32, ptr %push118137_append_data, i64 %push118137_length
  store i32 10, ptr %push118137_slot, align 4
  %push118137_new_length = add i64 %push118137_length, 1
  %push118137_array0 = insertvalue %sollang.array.i32 poison, ptr %push118137_append_data, 0
  %push118137_array1 = insertvalue %sollang.array.i32 %push118137_array0, i64 %push118137_new_length, 1
  %push118137_array2 = insertvalue %sollang.array.i32 %push118137_array1, i64 %push118137_append_capacity, 2
  store %sollang.array.i32 %push118137_array2, ptr %slot118122, align 8
  %v118141 = load %sollang.array.i32, ptr %slot118122, align 8
  %push118140_data = extractvalue %sollang.array.i32 %v118141, 0
  %push118140_length = extractvalue %sollang.array.i32 %v118141, 1
  %push118140_capacity = extractvalue %sollang.array.i32 %v118141, 2
  %push118140_full = icmp eq i64 %push118140_length, %push118140_capacity
  %push118140_empty = icmp eq i64 %push118140_capacity, 0
  %push118140_doubled = mul i64 %push118140_capacity, 2
  %push118140_grown_capacity = select i1 %push118140_empty, i64 4, i64 %push118140_doubled
  %push118140_append_capacity = select i1 %push118140_full, i64 %push118140_grown_capacity, i64 %push118140_capacity
  %push118140_append_bytes = mul i64 %push118140_append_capacity, 4
  br i1 %push118140_full, label %push118140_grow, label %push118140_keep
push118140_keep:
  br label %push118140_ready
push118140_grow:
  %push118140_grown_data = call ptr @malloc(i64 %push118140_append_bytes)
  %push118140_allocated = icmp ne ptr %push118140_grown_data, null
  br i1 %push118140_allocated, label %push118140_copy, label %push118140_allocation_failed
push118140_allocation_failed:
  call void @llvm.trap()
  unreachable
push118140_copy:
  %push118140_copy_bytes = mul i64 %push118140_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118140_grown_data, ptr %push118140_data, i64 %push118140_copy_bytes, i1 false)
  call void @free(ptr %push118140_data)
  br label %push118140_ready
push118140_ready:
  %push118140_append_data = phi ptr [ %push118140_data, %push118140_keep ], [ %push118140_grown_data, %push118140_copy ]
  %push118140_slot = getelementptr i32, ptr %push118140_append_data, i64 %push118140_length
  store i32 20, ptr %push118140_slot, align 4
  %push118140_new_length = add i64 %push118140_length, 1
  %push118140_array0 = insertvalue %sollang.array.i32 poison, ptr %push118140_append_data, 0
  %push118140_array1 = insertvalue %sollang.array.i32 %push118140_array0, i64 %push118140_new_length, 1
  %push118140_array2 = insertvalue %sollang.array.i32 %push118140_array1, i64 %push118140_append_capacity, 2
  store %sollang.array.i32 %push118140_array2, ptr %slot118122, align 8
  %v118143_expression_literal0 = getelementptr i8, ptr @sollang_str_118144, i64 0
  call void @sollang_runtime_print(ptr %v118143_expression_literal0, i64 0, i1 false)
  %v118143_expression19_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118143_expression18_raw = extractvalue %sollang.array.i32 %v118143_expression19_mutable, 1
  %v118143_expression18 = trunc i64 %v118143_expression18_raw to i32
  %v118143_expression18_print = zext i32 %v118143_expression18 to i64
  call void @sollang_runtime_print_i64(i64 %v118143_expression18_print, i1 false, i1 false)
  %v118143_expression_literal1 = getelementptr i8, ptr @sollang_str_118144, i64 12
  call void @sollang_runtime_print(ptr %v118143_expression_literal1, i64 1, i1 false)
  %v118143_expression21_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118143_expression20_data = extractvalue %sollang.array.i32 %v118143_expression21_mutable, 0
  %v118143_expression20_index = sext i32 1 to i64
  %v118143_expression20_length = extractvalue %sollang.array.i32 %v118143_expression21_mutable, 1
  %v118143_expression20_in_bounds = icmp ult i64 %v118143_expression20_index, %v118143_expression20_length
  br i1 %v118143_expression20_in_bounds, label %interpolation118143_array20_valid, label %interpolation118143_array20_invalid
interpolation118143_array20_invalid:
  call void @llvm.trap()
  unreachable
interpolation118143_array20_valid:
  %v118143_expression20_ptr = getelementptr i32, ptr %v118143_expression20_data, i64 %v118143_expression20_index
  %v118143_expression20 = load i32, ptr %v118143_expression20_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118143_expression20, i1 false)
  %v118143_expression_suffix = getelementptr i8, ptr @sollang_str_118144, i64 21
  call void @sollang_runtime_print(ptr %v118143_expression_suffix, i64 0, i1 true)
  %drop118121_current = load %sollang.array.i32, ptr %slot118121, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %drop118121_current)
  %drop118122_current = load %sollang.array.i32, ptr %slot118122, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %drop118122_current)
  ret void
}

define void @sollang_m144_s8() {
entry:
  %calltext118154_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118154_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118162_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118162_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118165_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118165_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118173_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118173_arg0_root1_buffer = alloca [21 x i8], align 1
  %slot118147 = alloca %sollang.array.i32, align 8
  %slot118148 = alloca %sollang.array.i32, align 8
  br i1 1, label %if118151_then, label %if118151_merge
if118151_then:
  %v118153_data = inttoptr i64 0 to ptr
  %v118153_0 = insertvalue %sollang.array.i32 poison, ptr %v118153_data, 0
  %v118153_1 = insertvalue %sollang.array.i32 %v118153_0, i64 0, 1
  %v118153 = insertvalue %sollang.array.i32 %v118153_1, i64 0, 2
  store %sollang.array.i32 %v118153, ptr %slot118147, align 8
  %v118155_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118155, 0
  %v118155 = insertvalue %sollang.text %v118155_ptr, i64 30, 1
  %v118154_expression_literal0 = getelementptr i8, ptr @sollang_str_118155, i64 0
  call void @sollang_runtime_print(ptr %v118154_expression_literal0, i64 0, i1 false)
  %v118154_expression24_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118154_expression23_raw = extractvalue %sollang.array.i32 %v118154_expression24_mutable, 1
  %v118154_expression23 = trunc i64 %v118154_expression23_raw to i32
  %v118154_expression23_print = zext i32 %v118154_expression23 to i64
  call void @sollang_runtime_print_i64(i64 %v118154_expression23_print, i1 false, i1 false)
  %v118154_expression_literal1 = getelementptr i8, ptr @sollang_str_118155, i64 12
  call void @sollang_runtime_print(ptr %v118154_expression_literal1, i64 1, i1 false)
  %v118154_expression26_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118154_expression25_raw = extractvalue %sollang.array.i32 %v118154_expression26_mutable, 2
  %v118154_expression25 = trunc i64 %v118154_expression25_raw to i32
  %v118154_expression25_print = zext i32 %v118154_expression25 to i64
  call void @sollang_runtime_print_i64(i64 %v118154_expression25_print, i1 false, i1 false)
  %v118154_expression_suffix = getelementptr i8, ptr @sollang_str_118155, i64 30
  call void @sollang_runtime_print(ptr %v118154_expression_suffix, i64 0, i1 true)
  %v118157 = load %sollang.array.i32, ptr %slot118147, align 8
  %push118156_data = extractvalue %sollang.array.i32 %v118157, 0
  %push118156_length = extractvalue %sollang.array.i32 %v118157, 1
  %push118156_capacity = extractvalue %sollang.array.i32 %v118157, 2
  %push118156_full = icmp eq i64 %push118156_length, %push118156_capacity
  %push118156_empty = icmp eq i64 %push118156_capacity, 0
  %push118156_doubled = mul i64 %push118156_capacity, 2
  %push118156_grown_capacity = select i1 %push118156_empty, i64 4, i64 %push118156_doubled
  %push118156_append_capacity = select i1 %push118156_full, i64 %push118156_grown_capacity, i64 %push118156_capacity
  %push118156_append_bytes = mul i64 %push118156_append_capacity, 4
  br i1 %push118156_full, label %push118156_grow, label %push118156_keep
push118156_keep:
  br label %push118156_ready
push118156_grow:
  %push118156_grown_data = call ptr @malloc(i64 %push118156_append_bytes)
  %push118156_allocated = icmp ne ptr %push118156_grown_data, null
  br i1 %push118156_allocated, label %push118156_copy, label %push118156_allocation_failed
push118156_allocation_failed:
  call void @llvm.trap()
  unreachable
push118156_copy:
  %push118156_copy_bytes = mul i64 %push118156_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118156_grown_data, ptr %push118156_data, i64 %push118156_copy_bytes, i1 false)
  call void @free(ptr %push118156_data)
  br label %push118156_ready
push118156_ready:
  %push118156_append_data = phi ptr [ %push118156_data, %push118156_keep ], [ %push118156_grown_data, %push118156_copy ]
  %push118156_slot = getelementptr i32, ptr %push118156_append_data, i64 %push118156_length
  store i32 10, ptr %push118156_slot, align 4
  %push118156_new_length = add i64 %push118156_length, 1
  %push118156_array0 = insertvalue %sollang.array.i32 poison, ptr %push118156_append_data, 0
  %push118156_array1 = insertvalue %sollang.array.i32 %push118156_array0, i64 %push118156_new_length, 1
  %push118156_array2 = insertvalue %sollang.array.i32 %push118156_array1, i64 %push118156_append_capacity, 2
  store %sollang.array.i32 %push118156_array2, ptr %slot118147, align 8
  %v118160 = load %sollang.array.i32, ptr %slot118147, align 8
  %push118159_data = extractvalue %sollang.array.i32 %v118160, 0
  %push118159_length = extractvalue %sollang.array.i32 %v118160, 1
  %push118159_capacity = extractvalue %sollang.array.i32 %v118160, 2
  %push118159_full = icmp eq i64 %push118159_length, %push118159_capacity
  %push118159_empty = icmp eq i64 %push118159_capacity, 0
  %push118159_doubled = mul i64 %push118159_capacity, 2
  %push118159_grown_capacity = select i1 %push118159_empty, i64 4, i64 %push118159_doubled
  %push118159_append_capacity = select i1 %push118159_full, i64 %push118159_grown_capacity, i64 %push118159_capacity
  %push118159_append_bytes = mul i64 %push118159_append_capacity, 4
  br i1 %push118159_full, label %push118159_grow, label %push118159_keep
push118159_keep:
  br label %push118159_ready
push118159_grow:
  %push118159_grown_data = call ptr @malloc(i64 %push118159_append_bytes)
  %push118159_allocated = icmp ne ptr %push118159_grown_data, null
  br i1 %push118159_allocated, label %push118159_copy, label %push118159_allocation_failed
push118159_allocation_failed:
  call void @llvm.trap()
  unreachable
push118159_copy:
  %push118159_copy_bytes = mul i64 %push118159_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118159_grown_data, ptr %push118159_data, i64 %push118159_copy_bytes, i1 false)
  call void @free(ptr %push118159_data)
  br label %push118159_ready
push118159_ready:
  %push118159_append_data = phi ptr [ %push118159_data, %push118159_keep ], [ %push118159_grown_data, %push118159_copy ]
  %push118159_slot = getelementptr i32, ptr %push118159_append_data, i64 %push118159_length
  store i32 20, ptr %push118159_slot, align 4
  %push118159_new_length = add i64 %push118159_length, 1
  %push118159_array0 = insertvalue %sollang.array.i32 poison, ptr %push118159_append_data, 0
  %push118159_array1 = insertvalue %sollang.array.i32 %push118159_array0, i64 %push118159_new_length, 1
  %push118159_array2 = insertvalue %sollang.array.i32 %push118159_array1, i64 %push118159_append_capacity, 2
  store %sollang.array.i32 %push118159_array2, ptr %slot118147, align 8
  %v118163_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118163, 0
  %v118163 = insertvalue %sollang.text %v118163_ptr, i64 21, 1
  %v118162_expression_literal0 = getelementptr i8, ptr @sollang_str_118163, i64 0
  call void @sollang_runtime_print(ptr %v118162_expression_literal0, i64 0, i1 false)
  %v118162_expression28_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118162_expression27_raw = extractvalue %sollang.array.i32 %v118162_expression28_mutable, 1
  %v118162_expression27 = trunc i64 %v118162_expression27_raw to i32
  %v118162_expression27_print = zext i32 %v118162_expression27 to i64
  call void @sollang_runtime_print_i64(i64 %v118162_expression27_print, i1 false, i1 false)
  %v118162_expression_literal1 = getelementptr i8, ptr @sollang_str_118163, i64 12
  call void @sollang_runtime_print(ptr %v118162_expression_literal1, i64 1, i1 false)
  %v118162_expression30_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118162_expression29_data = extractvalue %sollang.array.i32 %v118162_expression30_mutable, 0
  %v118162_expression29_index = sext i32 1 to i64
  %v118162_expression29_length = extractvalue %sollang.array.i32 %v118162_expression30_mutable, 1
  %v118162_expression29_in_bounds = icmp ult i64 %v118162_expression29_index, %v118162_expression29_length
  br i1 %v118162_expression29_in_bounds, label %interpolation118162_array29_valid, label %interpolation118162_array29_invalid
interpolation118162_array29_invalid:
  call void @llvm.trap()
  unreachable
interpolation118162_array29_valid:
  %v118162_expression29_ptr = getelementptr i32, ptr %v118162_expression29_data, i64 %v118162_expression29_index
  %v118162_expression29 = load i32, ptr %v118162_expression29_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118162_expression29, i1 false)
  %v118162_expression_suffix = getelementptr i8, ptr @sollang_str_118163, i64 21
  call void @sollang_runtime_print(ptr %v118162_expression_suffix, i64 0, i1 true)
  %v118164_data = call ptr @malloc(i64 16)
  %v118164_0 = insertvalue %sollang.array.i32 poison, ptr %v118164_data, 0
  %v118164_1 = insertvalue %sollang.array.i32 %v118164_0, i64 0, 1
  %v118164 = insertvalue %sollang.array.i32 %v118164_1, i64 4, 2
  store %sollang.array.i32 %v118164, ptr %slot118148, align 8
  %v118166_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118166, 0
  %v118166 = insertvalue %sollang.text %v118166_ptr, i64 30, 1
  %v118165_expression_literal0 = getelementptr i8, ptr @sollang_str_118166, i64 0
  call void @sollang_runtime_print(ptr %v118165_expression_literal0, i64 0, i1 false)
  %v118165_expression33_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118165_expression32_raw = extractvalue %sollang.array.i32 %v118165_expression33_mutable, 1
  %v118165_expression32 = trunc i64 %v118165_expression32_raw to i32
  %v118165_expression32_print = zext i32 %v118165_expression32 to i64
  call void @sollang_runtime_print_i64(i64 %v118165_expression32_print, i1 false, i1 false)
  %v118165_expression_literal1 = getelementptr i8, ptr @sollang_str_118166, i64 12
  call void @sollang_runtime_print(ptr %v118165_expression_literal1, i64 1, i1 false)
  %v118165_expression35_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118165_expression34_raw = extractvalue %sollang.array.i32 %v118165_expression35_mutable, 2
  %v118165_expression34 = trunc i64 %v118165_expression34_raw to i32
  %v118165_expression34_print = zext i32 %v118165_expression34 to i64
  call void @sollang_runtime_print_i64(i64 %v118165_expression34_print, i1 false, i1 false)
  %v118165_expression_suffix = getelementptr i8, ptr @sollang_str_118166, i64 30
  call void @sollang_runtime_print(ptr %v118165_expression_suffix, i64 0, i1 true)
  %v118168 = load %sollang.array.i32, ptr %slot118148, align 8
  %push118167_data = extractvalue %sollang.array.i32 %v118168, 0
  %push118167_length = extractvalue %sollang.array.i32 %v118168, 1
  %push118167_capacity = extractvalue %sollang.array.i32 %v118168, 2
  %push118167_full = icmp eq i64 %push118167_length, %push118167_capacity
  %push118167_empty = icmp eq i64 %push118167_capacity, 0
  %push118167_doubled = mul i64 %push118167_capacity, 2
  %push118167_grown_capacity = select i1 %push118167_empty, i64 4, i64 %push118167_doubled
  %push118167_append_capacity = select i1 %push118167_full, i64 %push118167_grown_capacity, i64 %push118167_capacity
  %push118167_append_bytes = mul i64 %push118167_append_capacity, 4
  br i1 %push118167_full, label %push118167_grow, label %push118167_keep
push118167_keep:
  br label %push118167_ready
push118167_grow:
  %push118167_grown_data = call ptr @malloc(i64 %push118167_append_bytes)
  %push118167_allocated = icmp ne ptr %push118167_grown_data, null
  br i1 %push118167_allocated, label %push118167_copy, label %push118167_allocation_failed
push118167_allocation_failed:
  call void @llvm.trap()
  unreachable
push118167_copy:
  %push118167_copy_bytes = mul i64 %push118167_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118167_grown_data, ptr %push118167_data, i64 %push118167_copy_bytes, i1 false)
  call void @free(ptr %push118167_data)
  br label %push118167_ready
push118167_ready:
  %push118167_append_data = phi ptr [ %push118167_data, %push118167_keep ], [ %push118167_grown_data, %push118167_copy ]
  %push118167_slot = getelementptr i32, ptr %push118167_append_data, i64 %push118167_length
  store i32 10, ptr %push118167_slot, align 4
  %push118167_new_length = add i64 %push118167_length, 1
  %push118167_array0 = insertvalue %sollang.array.i32 poison, ptr %push118167_append_data, 0
  %push118167_array1 = insertvalue %sollang.array.i32 %push118167_array0, i64 %push118167_new_length, 1
  %push118167_array2 = insertvalue %sollang.array.i32 %push118167_array1, i64 %push118167_append_capacity, 2
  store %sollang.array.i32 %push118167_array2, ptr %slot118148, align 8
  %v118171 = load %sollang.array.i32, ptr %slot118148, align 8
  %push118170_data = extractvalue %sollang.array.i32 %v118171, 0
  %push118170_length = extractvalue %sollang.array.i32 %v118171, 1
  %push118170_capacity = extractvalue %sollang.array.i32 %v118171, 2
  %push118170_full = icmp eq i64 %push118170_length, %push118170_capacity
  %push118170_empty = icmp eq i64 %push118170_capacity, 0
  %push118170_doubled = mul i64 %push118170_capacity, 2
  %push118170_grown_capacity = select i1 %push118170_empty, i64 4, i64 %push118170_doubled
  %push118170_append_capacity = select i1 %push118170_full, i64 %push118170_grown_capacity, i64 %push118170_capacity
  %push118170_append_bytes = mul i64 %push118170_append_capacity, 4
  br i1 %push118170_full, label %push118170_grow, label %push118170_keep
push118170_keep:
  br label %push118170_ready
push118170_grow:
  %push118170_grown_data = call ptr @malloc(i64 %push118170_append_bytes)
  %push118170_allocated = icmp ne ptr %push118170_grown_data, null
  br i1 %push118170_allocated, label %push118170_copy, label %push118170_allocation_failed
push118170_allocation_failed:
  call void @llvm.trap()
  unreachable
push118170_copy:
  %push118170_copy_bytes = mul i64 %push118170_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118170_grown_data, ptr %push118170_data, i64 %push118170_copy_bytes, i1 false)
  call void @free(ptr %push118170_data)
  br label %push118170_ready
push118170_ready:
  %push118170_append_data = phi ptr [ %push118170_data, %push118170_keep ], [ %push118170_grown_data, %push118170_copy ]
  %push118170_slot = getelementptr i32, ptr %push118170_append_data, i64 %push118170_length
  store i32 20, ptr %push118170_slot, align 4
  %push118170_new_length = add i64 %push118170_length, 1
  %push118170_array0 = insertvalue %sollang.array.i32 poison, ptr %push118170_append_data, 0
  %push118170_array1 = insertvalue %sollang.array.i32 %push118170_array0, i64 %push118170_new_length, 1
  %push118170_array2 = insertvalue %sollang.array.i32 %push118170_array1, i64 %push118170_append_capacity, 2
  store %sollang.array.i32 %push118170_array2, ptr %slot118148, align 8
  %v118174_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118174, 0
  %v118174 = insertvalue %sollang.text %v118174_ptr, i64 21, 1
  %v118173_expression_literal0 = getelementptr i8, ptr @sollang_str_118174, i64 0
  call void @sollang_runtime_print(ptr %v118173_expression_literal0, i64 0, i1 false)
  %v118173_expression37_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118173_expression36_raw = extractvalue %sollang.array.i32 %v118173_expression37_mutable, 1
  %v118173_expression36 = trunc i64 %v118173_expression36_raw to i32
  %v118173_expression36_print = zext i32 %v118173_expression36 to i64
  call void @sollang_runtime_print_i64(i64 %v118173_expression36_print, i1 false, i1 false)
  %v118173_expression_literal1 = getelementptr i8, ptr @sollang_str_118174, i64 12
  call void @sollang_runtime_print(ptr %v118173_expression_literal1, i64 1, i1 false)
  %v118173_expression39_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118173_expression38_data = extractvalue %sollang.array.i32 %v118173_expression39_mutable, 0
  %v118173_expression38_index = sext i32 1 to i64
  %v118173_expression38_length = extractvalue %sollang.array.i32 %v118173_expression39_mutable, 1
  %v118173_expression38_in_bounds = icmp ult i64 %v118173_expression38_index, %v118173_expression38_length
  br i1 %v118173_expression38_in_bounds, label %interpolation118173_array38_valid, label %interpolation118173_array38_invalid
interpolation118173_array38_invalid:
  call void @llvm.trap()
  unreachable
interpolation118173_array38_valid:
  %v118173_expression38_ptr = getelementptr i32, ptr %v118173_expression38_data, i64 %v118173_expression38_index
  %v118173_expression38 = load i32, ptr %v118173_expression38_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118173_expression38, i1 false)
  %v118173_expression_suffix = getelementptr i8, ptr @sollang_str_118174, i64 21
  call void @sollang_runtime_print(ptr %v118173_expression_suffix, i64 0, i1 true)
  %cleanup1181511_b118148_current = load %sollang.array.i32, ptr %slot118148, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181511_b118148_current)
  %cleanup1181511_b118147_current = load %sollang.array.i32, ptr %slot118147, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181511_b118147_current)
  br label %if118151_merge
if118151_merge:
  ret void
}

define void @sollang_m144_s11() {
entry:
  %calltext118189_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118189_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118197_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118197_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118200_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118200_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118208_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118208_arg0_root1_buffer = alloca [21 x i8], align 1
  %slot118177 = alloca i32, align 4
  %slot118178 = alloca %sollang.array.i32, align 8
  %slot118179 = alloca %sollang.array.i32, align 8
  store i32 0, ptr %slot118177, align 4
  br label %while118186_header
while118186_header:
  %while118186_v118184 = load i32, ptr %slot118177, align 4
  %while118186_v118183 = icmp slt i32 %while118186_v118184, 1
  br i1 %while118186_v118183, label %while118186_body, label %while118186_exit
while118186_body:
  %v118188_data = inttoptr i64 0 to ptr
  %v118188_0 = insertvalue %sollang.array.i32 poison, ptr %v118188_data, 0
  %v118188_1 = insertvalue %sollang.array.i32 %v118188_0, i64 0, 1
  %v118188 = insertvalue %sollang.array.i32 %v118188_1, i64 0, 2
  store %sollang.array.i32 %v118188, ptr %slot118178, align 8
  %v118190_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118190, 0
  %v118190 = insertvalue %sollang.text %v118190_ptr, i64 30, 1
  %v118189_expression_literal0 = getelementptr i8, ptr @sollang_str_118190, i64 0
  call void @sollang_runtime_print(ptr %v118189_expression_literal0, i64 0, i1 false)
  %v118189_expression42_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118189_expression41_raw = extractvalue %sollang.array.i32 %v118189_expression42_mutable, 1
  %v118189_expression41 = trunc i64 %v118189_expression41_raw to i32
  %v118189_expression41_print = zext i32 %v118189_expression41 to i64
  call void @sollang_runtime_print_i64(i64 %v118189_expression41_print, i1 false, i1 false)
  %v118189_expression_literal1 = getelementptr i8, ptr @sollang_str_118190, i64 12
  call void @sollang_runtime_print(ptr %v118189_expression_literal1, i64 1, i1 false)
  %v118189_expression44_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118189_expression43_raw = extractvalue %sollang.array.i32 %v118189_expression44_mutable, 2
  %v118189_expression43 = trunc i64 %v118189_expression43_raw to i32
  %v118189_expression43_print = zext i32 %v118189_expression43 to i64
  call void @sollang_runtime_print_i64(i64 %v118189_expression43_print, i1 false, i1 false)
  %v118189_expression_suffix = getelementptr i8, ptr @sollang_str_118190, i64 30
  call void @sollang_runtime_print(ptr %v118189_expression_suffix, i64 0, i1 true)
  %v118192 = load %sollang.array.i32, ptr %slot118178, align 8
  %push118191_data = extractvalue %sollang.array.i32 %v118192, 0
  %push118191_length = extractvalue %sollang.array.i32 %v118192, 1
  %push118191_capacity = extractvalue %sollang.array.i32 %v118192, 2
  %push118191_full = icmp eq i64 %push118191_length, %push118191_capacity
  %push118191_empty = icmp eq i64 %push118191_capacity, 0
  %push118191_doubled = mul i64 %push118191_capacity, 2
  %push118191_grown_capacity = select i1 %push118191_empty, i64 4, i64 %push118191_doubled
  %push118191_append_capacity = select i1 %push118191_full, i64 %push118191_grown_capacity, i64 %push118191_capacity
  %push118191_append_bytes = mul i64 %push118191_append_capacity, 4
  br i1 %push118191_full, label %push118191_grow, label %push118191_keep
push118191_keep:
  br label %push118191_ready
push118191_grow:
  %push118191_grown_data = call ptr @malloc(i64 %push118191_append_bytes)
  %push118191_allocated = icmp ne ptr %push118191_grown_data, null
  br i1 %push118191_allocated, label %push118191_copy, label %push118191_allocation_failed
push118191_allocation_failed:
  call void @llvm.trap()
  unreachable
push118191_copy:
  %push118191_copy_bytes = mul i64 %push118191_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118191_grown_data, ptr %push118191_data, i64 %push118191_copy_bytes, i1 false)
  call void @free(ptr %push118191_data)
  br label %push118191_ready
push118191_ready:
  %push118191_append_data = phi ptr [ %push118191_data, %push118191_keep ], [ %push118191_grown_data, %push118191_copy ]
  %push118191_slot = getelementptr i32, ptr %push118191_append_data, i64 %push118191_length
  store i32 10, ptr %push118191_slot, align 4
  %push118191_new_length = add i64 %push118191_length, 1
  %push118191_array0 = insertvalue %sollang.array.i32 poison, ptr %push118191_append_data, 0
  %push118191_array1 = insertvalue %sollang.array.i32 %push118191_array0, i64 %push118191_new_length, 1
  %push118191_array2 = insertvalue %sollang.array.i32 %push118191_array1, i64 %push118191_append_capacity, 2
  store %sollang.array.i32 %push118191_array2, ptr %slot118178, align 8
  %v118195 = load %sollang.array.i32, ptr %slot118178, align 8
  %push118194_data = extractvalue %sollang.array.i32 %v118195, 0
  %push118194_length = extractvalue %sollang.array.i32 %v118195, 1
  %push118194_capacity = extractvalue %sollang.array.i32 %v118195, 2
  %push118194_full = icmp eq i64 %push118194_length, %push118194_capacity
  %push118194_empty = icmp eq i64 %push118194_capacity, 0
  %push118194_doubled = mul i64 %push118194_capacity, 2
  %push118194_grown_capacity = select i1 %push118194_empty, i64 4, i64 %push118194_doubled
  %push118194_append_capacity = select i1 %push118194_full, i64 %push118194_grown_capacity, i64 %push118194_capacity
  %push118194_append_bytes = mul i64 %push118194_append_capacity, 4
  br i1 %push118194_full, label %push118194_grow, label %push118194_keep
push118194_keep:
  br label %push118194_ready
push118194_grow:
  %push118194_grown_data = call ptr @malloc(i64 %push118194_append_bytes)
  %push118194_allocated = icmp ne ptr %push118194_grown_data, null
  br i1 %push118194_allocated, label %push118194_copy, label %push118194_allocation_failed
push118194_allocation_failed:
  call void @llvm.trap()
  unreachable
push118194_copy:
  %push118194_copy_bytes = mul i64 %push118194_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118194_grown_data, ptr %push118194_data, i64 %push118194_copy_bytes, i1 false)
  call void @free(ptr %push118194_data)
  br label %push118194_ready
push118194_ready:
  %push118194_append_data = phi ptr [ %push118194_data, %push118194_keep ], [ %push118194_grown_data, %push118194_copy ]
  %push118194_slot = getelementptr i32, ptr %push118194_append_data, i64 %push118194_length
  store i32 20, ptr %push118194_slot, align 4
  %push118194_new_length = add i64 %push118194_length, 1
  %push118194_array0 = insertvalue %sollang.array.i32 poison, ptr %push118194_append_data, 0
  %push118194_array1 = insertvalue %sollang.array.i32 %push118194_array0, i64 %push118194_new_length, 1
  %push118194_array2 = insertvalue %sollang.array.i32 %push118194_array1, i64 %push118194_append_capacity, 2
  store %sollang.array.i32 %push118194_array2, ptr %slot118178, align 8
  %v118198_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118198, 0
  %v118198 = insertvalue %sollang.text %v118198_ptr, i64 21, 1
  %v118197_expression_literal0 = getelementptr i8, ptr @sollang_str_118198, i64 0
  call void @sollang_runtime_print(ptr %v118197_expression_literal0, i64 0, i1 false)
  %v118197_expression46_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118197_expression45_raw = extractvalue %sollang.array.i32 %v118197_expression46_mutable, 1
  %v118197_expression45 = trunc i64 %v118197_expression45_raw to i32
  %v118197_expression45_print = zext i32 %v118197_expression45 to i64
  call void @sollang_runtime_print_i64(i64 %v118197_expression45_print, i1 false, i1 false)
  %v118197_expression_literal1 = getelementptr i8, ptr @sollang_str_118198, i64 12
  call void @sollang_runtime_print(ptr %v118197_expression_literal1, i64 1, i1 false)
  %v118197_expression48_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118197_expression47_data = extractvalue %sollang.array.i32 %v118197_expression48_mutable, 0
  %v118197_expression47_index = sext i32 1 to i64
  %v118197_expression47_length = extractvalue %sollang.array.i32 %v118197_expression48_mutable, 1
  %v118197_expression47_in_bounds = icmp ult i64 %v118197_expression47_index, %v118197_expression47_length
  br i1 %v118197_expression47_in_bounds, label %interpolation118197_array47_valid, label %interpolation118197_array47_invalid
interpolation118197_array47_invalid:
  call void @llvm.trap()
  unreachable
interpolation118197_array47_valid:
  %v118197_expression47_ptr = getelementptr i32, ptr %v118197_expression47_data, i64 %v118197_expression47_index
  %v118197_expression47 = load i32, ptr %v118197_expression47_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118197_expression47, i1 false)
  %v118197_expression_suffix = getelementptr i8, ptr @sollang_str_118198, i64 21
  call void @sollang_runtime_print(ptr %v118197_expression_suffix, i64 0, i1 true)
  %v118199_data = call ptr @malloc(i64 16)
  %v118199_0 = insertvalue %sollang.array.i32 poison, ptr %v118199_data, 0
  %v118199_1 = insertvalue %sollang.array.i32 %v118199_0, i64 0, 1
  %v118199 = insertvalue %sollang.array.i32 %v118199_1, i64 4, 2
  store %sollang.array.i32 %v118199, ptr %slot118179, align 8
  %v118201_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118201, 0
  %v118201 = insertvalue %sollang.text %v118201_ptr, i64 30, 1
  %v118200_expression_literal0 = getelementptr i8, ptr @sollang_str_118201, i64 0
  call void @sollang_runtime_print(ptr %v118200_expression_literal0, i64 0, i1 false)
  %v118200_expression51_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118200_expression50_raw = extractvalue %sollang.array.i32 %v118200_expression51_mutable, 1
  %v118200_expression50 = trunc i64 %v118200_expression50_raw to i32
  %v118200_expression50_print = zext i32 %v118200_expression50 to i64
  call void @sollang_runtime_print_i64(i64 %v118200_expression50_print, i1 false, i1 false)
  %v118200_expression_literal1 = getelementptr i8, ptr @sollang_str_118201, i64 12
  call void @sollang_runtime_print(ptr %v118200_expression_literal1, i64 1, i1 false)
  %v118200_expression53_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118200_expression52_raw = extractvalue %sollang.array.i32 %v118200_expression53_mutable, 2
  %v118200_expression52 = trunc i64 %v118200_expression52_raw to i32
  %v118200_expression52_print = zext i32 %v118200_expression52 to i64
  call void @sollang_runtime_print_i64(i64 %v118200_expression52_print, i1 false, i1 false)
  %v118200_expression_suffix = getelementptr i8, ptr @sollang_str_118201, i64 30
  call void @sollang_runtime_print(ptr %v118200_expression_suffix, i64 0, i1 true)
  %v118203 = load %sollang.array.i32, ptr %slot118179, align 8
  %push118202_data = extractvalue %sollang.array.i32 %v118203, 0
  %push118202_length = extractvalue %sollang.array.i32 %v118203, 1
  %push118202_capacity = extractvalue %sollang.array.i32 %v118203, 2
  %push118202_full = icmp eq i64 %push118202_length, %push118202_capacity
  %push118202_empty = icmp eq i64 %push118202_capacity, 0
  %push118202_doubled = mul i64 %push118202_capacity, 2
  %push118202_grown_capacity = select i1 %push118202_empty, i64 4, i64 %push118202_doubled
  %push118202_append_capacity = select i1 %push118202_full, i64 %push118202_grown_capacity, i64 %push118202_capacity
  %push118202_append_bytes = mul i64 %push118202_append_capacity, 4
  br i1 %push118202_full, label %push118202_grow, label %push118202_keep
push118202_keep:
  br label %push118202_ready
push118202_grow:
  %push118202_grown_data = call ptr @malloc(i64 %push118202_append_bytes)
  %push118202_allocated = icmp ne ptr %push118202_grown_data, null
  br i1 %push118202_allocated, label %push118202_copy, label %push118202_allocation_failed
push118202_allocation_failed:
  call void @llvm.trap()
  unreachable
push118202_copy:
  %push118202_copy_bytes = mul i64 %push118202_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118202_grown_data, ptr %push118202_data, i64 %push118202_copy_bytes, i1 false)
  call void @free(ptr %push118202_data)
  br label %push118202_ready
push118202_ready:
  %push118202_append_data = phi ptr [ %push118202_data, %push118202_keep ], [ %push118202_grown_data, %push118202_copy ]
  %push118202_slot = getelementptr i32, ptr %push118202_append_data, i64 %push118202_length
  store i32 10, ptr %push118202_slot, align 4
  %push118202_new_length = add i64 %push118202_length, 1
  %push118202_array0 = insertvalue %sollang.array.i32 poison, ptr %push118202_append_data, 0
  %push118202_array1 = insertvalue %sollang.array.i32 %push118202_array0, i64 %push118202_new_length, 1
  %push118202_array2 = insertvalue %sollang.array.i32 %push118202_array1, i64 %push118202_append_capacity, 2
  store %sollang.array.i32 %push118202_array2, ptr %slot118179, align 8
  %v118206 = load %sollang.array.i32, ptr %slot118179, align 8
  %push118205_data = extractvalue %sollang.array.i32 %v118206, 0
  %push118205_length = extractvalue %sollang.array.i32 %v118206, 1
  %push118205_capacity = extractvalue %sollang.array.i32 %v118206, 2
  %push118205_full = icmp eq i64 %push118205_length, %push118205_capacity
  %push118205_empty = icmp eq i64 %push118205_capacity, 0
  %push118205_doubled = mul i64 %push118205_capacity, 2
  %push118205_grown_capacity = select i1 %push118205_empty, i64 4, i64 %push118205_doubled
  %push118205_append_capacity = select i1 %push118205_full, i64 %push118205_grown_capacity, i64 %push118205_capacity
  %push118205_append_bytes = mul i64 %push118205_append_capacity, 4
  br i1 %push118205_full, label %push118205_grow, label %push118205_keep
push118205_keep:
  br label %push118205_ready
push118205_grow:
  %push118205_grown_data = call ptr @malloc(i64 %push118205_append_bytes)
  %push118205_allocated = icmp ne ptr %push118205_grown_data, null
  br i1 %push118205_allocated, label %push118205_copy, label %push118205_allocation_failed
push118205_allocation_failed:
  call void @llvm.trap()
  unreachable
push118205_copy:
  %push118205_copy_bytes = mul i64 %push118205_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118205_grown_data, ptr %push118205_data, i64 %push118205_copy_bytes, i1 false)
  call void @free(ptr %push118205_data)
  br label %push118205_ready
push118205_ready:
  %push118205_append_data = phi ptr [ %push118205_data, %push118205_keep ], [ %push118205_grown_data, %push118205_copy ]
  %push118205_slot = getelementptr i32, ptr %push118205_append_data, i64 %push118205_length
  store i32 20, ptr %push118205_slot, align 4
  %push118205_new_length = add i64 %push118205_length, 1
  %push118205_array0 = insertvalue %sollang.array.i32 poison, ptr %push118205_append_data, 0
  %push118205_array1 = insertvalue %sollang.array.i32 %push118205_array0, i64 %push118205_new_length, 1
  %push118205_array2 = insertvalue %sollang.array.i32 %push118205_array1, i64 %push118205_append_capacity, 2
  store %sollang.array.i32 %push118205_array2, ptr %slot118179, align 8
  %v118209_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118209, 0
  %v118209 = insertvalue %sollang.text %v118209_ptr, i64 21, 1
  %v118208_expression_literal0 = getelementptr i8, ptr @sollang_str_118209, i64 0
  call void @sollang_runtime_print(ptr %v118208_expression_literal0, i64 0, i1 false)
  %v118208_expression55_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118208_expression54_raw = extractvalue %sollang.array.i32 %v118208_expression55_mutable, 1
  %v118208_expression54 = trunc i64 %v118208_expression54_raw to i32
  %v118208_expression54_print = zext i32 %v118208_expression54 to i64
  call void @sollang_runtime_print_i64(i64 %v118208_expression54_print, i1 false, i1 false)
  %v118208_expression_literal1 = getelementptr i8, ptr @sollang_str_118209, i64 12
  call void @sollang_runtime_print(ptr %v118208_expression_literal1, i64 1, i1 false)
  %v118208_expression57_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118208_expression56_data = extractvalue %sollang.array.i32 %v118208_expression57_mutable, 0
  %v118208_expression56_index = sext i32 1 to i64
  %v118208_expression56_length = extractvalue %sollang.array.i32 %v118208_expression57_mutable, 1
  %v118208_expression56_in_bounds = icmp ult i64 %v118208_expression56_index, %v118208_expression56_length
  br i1 %v118208_expression56_in_bounds, label %interpolation118208_array56_valid, label %interpolation118208_array56_invalid
interpolation118208_array56_invalid:
  call void @llvm.trap()
  unreachable
interpolation118208_array56_valid:
  %v118208_expression56_ptr = getelementptr i32, ptr %v118208_expression56_data, i64 %v118208_expression56_index
  %v118208_expression56 = load i32, ptr %v118208_expression56_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118208_expression56, i1 false)
  %v118208_expression_suffix = getelementptr i8, ptr @sollang_str_118209, i64 21
  call void @sollang_runtime_print(ptr %v118208_expression_suffix, i64 0, i1 true)
  %v118211 = load i32, ptr %slot118177, align 4
  %v118210 = add i32 %v118211, 1
  store i32 %v118210, ptr %slot118177, align 4
  %cleanup1181863_b118179_current = load %sollang.array.i32, ptr %slot118179, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181863_b118179_current)
  %cleanup1181863_b118178_current = load %sollang.array.i32, ptr %slot118178, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181863_b118178_current)
  br label %while118186_header
while118186_exit:
  ret void
}

define i32 @main() {
entry:
  %v118249_data = alloca [12 x i8], align 4
  %v118256_owner = alloca %sollang.bounded_dictionary.t1216, align 8
  %calltext118225_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118225_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118233_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118233_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118236_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118236_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118244_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118244_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118251_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118251_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118254_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118257_arg0_root0_buffer = alloca [21 x i8], align 1
  %callref118266_arg0 = alloca %sollang.struct.m144_s0, align 8
  %callref118269_arg0 = alloca %sollang.array.i32, align 8
  %calltext118275_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118277_arg0_root0_buffer = alloca [21 x i8], align 1
  %calltext118277_arg0_root1_buffer = alloca [21 x i8], align 1
  %calltext118277_arg0_root2_buffer = alloca [21 x i8], align 1
  %calltext118277_arg0_root3_buffer = alloca [21 x i8], align 1
  %slot118214 = alloca %sollang.array.i32, align 8
  %slot118215 = alloca %sollang.array.i32, align 8
  %v118224_data = inttoptr i64 0 to ptr
  %v118224_0 = insertvalue %sollang.array.i32 poison, ptr %v118224_data, 0
  %v118224_1 = insertvalue %sollang.array.i32 %v118224_0, i64 0, 1
  %v118224 = insertvalue %sollang.array.i32 %v118224_1, i64 0, 2
  %v118226_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118226, 0
  %v118226 = insertvalue %sollang.text %v118226_ptr, i64 30, 1
  %v118234_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118234, 0
  %v118234 = insertvalue %sollang.text %v118234_ptr, i64 21, 1
  %v118235_data = call ptr @malloc(i64 16)
  %v118235_0 = insertvalue %sollang.array.i32 poison, ptr %v118235_data, 0
  %v118235_1 = insertvalue %sollang.array.i32 %v118235_0, i64 0, 1
  %v118235 = insertvalue %sollang.array.i32 %v118235_1, i64 4, 2
  %v118237_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118237, 0
  %v118237 = insertvalue %sollang.text %v118237_ptr, i64 30, 1
  %v118245_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118245, 0
  %v118245 = insertvalue %sollang.text %v118245_ptr, i64 21, 1
  %v118252_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118252, 0
  %v118252 = insertvalue %sollang.text %v118252_ptr, i64 33, 1
  %v118255_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118255, 0
  %v118255 = insertvalue %sollang.text %v118255_ptr, i64 30, 1
  %v118258_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118258, 0
  %v118258 = insertvalue %sollang.text %v118258_ptr, i64 51, 1
  %v118263_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118263, 0
  %v118263 = insertvalue %sollang.text %v118263_ptr, i64 58, 1
  %v118276_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118276, 0
  %v118276 = insertvalue %sollang.text %v118276_ptr, i64 27, 1
  %v118278_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118278, 0
  %v118278 = insertvalue %sollang.text %v118278_ptr, i64 58, 1
  store %sollang.array.i32 %v118224, ptr %slot118214, align 8
  %v118225_expression_literal0 = getelementptr i8, ptr @sollang_str_118226, i64 0
  call void @sollang_runtime_print(ptr %v118225_expression_literal0, i64 0, i1 false)
  %v118225_expression60_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118225_expression59_raw = extractvalue %sollang.array.i32 %v118225_expression60_mutable, 1
  %v118225_expression59 = trunc i64 %v118225_expression59_raw to i32
  %v118225_expression59_print = zext i32 %v118225_expression59 to i64
  call void @sollang_runtime_print_i64(i64 %v118225_expression59_print, i1 false, i1 false)
  %v118225_expression_literal1 = getelementptr i8, ptr @sollang_str_118226, i64 12
  call void @sollang_runtime_print(ptr %v118225_expression_literal1, i64 1, i1 false)
  %v118225_expression62_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118225_expression61_raw = extractvalue %sollang.array.i32 %v118225_expression62_mutable, 2
  %v118225_expression61 = trunc i64 %v118225_expression61_raw to i32
  %v118225_expression61_print = zext i32 %v118225_expression61 to i64
  call void @sollang_runtime_print_i64(i64 %v118225_expression61_print, i1 false, i1 false)
  %v118225_expression_suffix = getelementptr i8, ptr @sollang_str_118226, i64 30
  call void @sollang_runtime_print(ptr %v118225_expression_suffix, i64 0, i1 true)
  %v118228 = load %sollang.array.i32, ptr %slot118214, align 8
  %push118227_data = extractvalue %sollang.array.i32 %v118228, 0
  %push118227_length = extractvalue %sollang.array.i32 %v118228, 1
  %push118227_capacity = extractvalue %sollang.array.i32 %v118228, 2
  %push118227_full = icmp eq i64 %push118227_length, %push118227_capacity
  %push118227_empty = icmp eq i64 %push118227_capacity, 0
  %push118227_doubled = mul i64 %push118227_capacity, 2
  %push118227_grown_capacity = select i1 %push118227_empty, i64 4, i64 %push118227_doubled
  %push118227_append_capacity = select i1 %push118227_full, i64 %push118227_grown_capacity, i64 %push118227_capacity
  %push118227_append_bytes = mul i64 %push118227_append_capacity, 4
  br i1 %push118227_full, label %push118227_grow, label %push118227_keep
push118227_keep:
  br label %push118227_ready
push118227_grow:
  %push118227_grown_data = call ptr @malloc(i64 %push118227_append_bytes)
  %push118227_allocated = icmp ne ptr %push118227_grown_data, null
  br i1 %push118227_allocated, label %push118227_copy, label %push118227_allocation_failed
push118227_allocation_failed:
  call void @llvm.trap()
  unreachable
push118227_copy:
  %push118227_copy_bytes = mul i64 %push118227_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118227_grown_data, ptr %push118227_data, i64 %push118227_copy_bytes, i1 false)
  call void @free(ptr %push118227_data)
  br label %push118227_ready
push118227_ready:
  %push118227_append_data = phi ptr [ %push118227_data, %push118227_keep ], [ %push118227_grown_data, %push118227_copy ]
  %push118227_slot = getelementptr i32, ptr %push118227_append_data, i64 %push118227_length
  store i32 10, ptr %push118227_slot, align 4
  %push118227_new_length = add i64 %push118227_length, 1
  %push118227_array0 = insertvalue %sollang.array.i32 poison, ptr %push118227_append_data, 0
  %push118227_array1 = insertvalue %sollang.array.i32 %push118227_array0, i64 %push118227_new_length, 1
  %push118227_array2 = insertvalue %sollang.array.i32 %push118227_array1, i64 %push118227_append_capacity, 2
  store %sollang.array.i32 %push118227_array2, ptr %slot118214, align 8
  %v118231 = load %sollang.array.i32, ptr %slot118214, align 8
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
  store i32 20, ptr %push118230_slot, align 4
  %push118230_new_length = add i64 %push118230_length, 1
  %push118230_array0 = insertvalue %sollang.array.i32 poison, ptr %push118230_append_data, 0
  %push118230_array1 = insertvalue %sollang.array.i32 %push118230_array0, i64 %push118230_new_length, 1
  %push118230_array2 = insertvalue %sollang.array.i32 %push118230_array1, i64 %push118230_append_capacity, 2
  store %sollang.array.i32 %push118230_array2, ptr %slot118214, align 8
  %v118233_expression_literal0 = getelementptr i8, ptr @sollang_str_118234, i64 0
  call void @sollang_runtime_print(ptr %v118233_expression_literal0, i64 0, i1 false)
  %v118233_expression64_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118233_expression63_raw = extractvalue %sollang.array.i32 %v118233_expression64_mutable, 1
  %v118233_expression63 = trunc i64 %v118233_expression63_raw to i32
  %v118233_expression63_print = zext i32 %v118233_expression63 to i64
  call void @sollang_runtime_print_i64(i64 %v118233_expression63_print, i1 false, i1 false)
  %v118233_expression_literal1 = getelementptr i8, ptr @sollang_str_118234, i64 12
  call void @sollang_runtime_print(ptr %v118233_expression_literal1, i64 1, i1 false)
  %v118233_expression66_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118233_expression65_data = extractvalue %sollang.array.i32 %v118233_expression66_mutable, 0
  %v118233_expression65_index = sext i32 1 to i64
  %v118233_expression65_length = extractvalue %sollang.array.i32 %v118233_expression66_mutable, 1
  %v118233_expression65_in_bounds = icmp ult i64 %v118233_expression65_index, %v118233_expression65_length
  br i1 %v118233_expression65_in_bounds, label %interpolation118233_array65_valid, label %interpolation118233_array65_invalid
interpolation118233_array65_invalid:
  call void @llvm.trap()
  unreachable
interpolation118233_array65_valid:
  %v118233_expression65_ptr = getelementptr i32, ptr %v118233_expression65_data, i64 %v118233_expression65_index
  %v118233_expression65 = load i32, ptr %v118233_expression65_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118233_expression65, i1 false)
  %v118233_expression_suffix = getelementptr i8, ptr @sollang_str_118234, i64 21
  call void @sollang_runtime_print(ptr %v118233_expression_suffix, i64 0, i1 true)
  store %sollang.array.i32 %v118235, ptr %slot118215, align 8
  %v118236_expression_literal0 = getelementptr i8, ptr @sollang_str_118237, i64 0
  call void @sollang_runtime_print(ptr %v118236_expression_literal0, i64 0, i1 false)
  %v118236_expression69_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118236_expression68_raw = extractvalue %sollang.array.i32 %v118236_expression69_mutable, 1
  %v118236_expression68 = trunc i64 %v118236_expression68_raw to i32
  %v118236_expression68_print = zext i32 %v118236_expression68 to i64
  call void @sollang_runtime_print_i64(i64 %v118236_expression68_print, i1 false, i1 false)
  %v118236_expression_literal1 = getelementptr i8, ptr @sollang_str_118237, i64 12
  call void @sollang_runtime_print(ptr %v118236_expression_literal1, i64 1, i1 false)
  %v118236_expression71_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118236_expression70_raw = extractvalue %sollang.array.i32 %v118236_expression71_mutable, 2
  %v118236_expression70 = trunc i64 %v118236_expression70_raw to i32
  %v118236_expression70_print = zext i32 %v118236_expression70 to i64
  call void @sollang_runtime_print_i64(i64 %v118236_expression70_print, i1 false, i1 false)
  %v118236_expression_suffix = getelementptr i8, ptr @sollang_str_118237, i64 30
  call void @sollang_runtime_print(ptr %v118236_expression_suffix, i64 0, i1 true)
  %v118239 = load %sollang.array.i32, ptr %slot118215, align 8
  %push118238_data = extractvalue %sollang.array.i32 %v118239, 0
  %push118238_length = extractvalue %sollang.array.i32 %v118239, 1
  %push118238_capacity = extractvalue %sollang.array.i32 %v118239, 2
  %push118238_full = icmp eq i64 %push118238_length, %push118238_capacity
  %push118238_empty = icmp eq i64 %push118238_capacity, 0
  %push118238_doubled = mul i64 %push118238_capacity, 2
  %push118238_grown_capacity = select i1 %push118238_empty, i64 4, i64 %push118238_doubled
  %push118238_append_capacity = select i1 %push118238_full, i64 %push118238_grown_capacity, i64 %push118238_capacity
  %push118238_append_bytes = mul i64 %push118238_append_capacity, 4
  br i1 %push118238_full, label %push118238_grow, label %push118238_keep
push118238_keep:
  br label %push118238_ready
push118238_grow:
  %push118238_grown_data = call ptr @malloc(i64 %push118238_append_bytes)
  %push118238_allocated = icmp ne ptr %push118238_grown_data, null
  br i1 %push118238_allocated, label %push118238_copy, label %push118238_allocation_failed
push118238_allocation_failed:
  call void @llvm.trap()
  unreachable
push118238_copy:
  %push118238_copy_bytes = mul i64 %push118238_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118238_grown_data, ptr %push118238_data, i64 %push118238_copy_bytes, i1 false)
  call void @free(ptr %push118238_data)
  br label %push118238_ready
push118238_ready:
  %push118238_append_data = phi ptr [ %push118238_data, %push118238_keep ], [ %push118238_grown_data, %push118238_copy ]
  %push118238_slot = getelementptr i32, ptr %push118238_append_data, i64 %push118238_length
  store i32 10, ptr %push118238_slot, align 4
  %push118238_new_length = add i64 %push118238_length, 1
  %push118238_array0 = insertvalue %sollang.array.i32 poison, ptr %push118238_append_data, 0
  %push118238_array1 = insertvalue %sollang.array.i32 %push118238_array0, i64 %push118238_new_length, 1
  %push118238_array2 = insertvalue %sollang.array.i32 %push118238_array1, i64 %push118238_append_capacity, 2
  store %sollang.array.i32 %push118238_array2, ptr %slot118215, align 8
  %v118242 = load %sollang.array.i32, ptr %slot118215, align 8
  %push118241_data = extractvalue %sollang.array.i32 %v118242, 0
  %push118241_length = extractvalue %sollang.array.i32 %v118242, 1
  %push118241_capacity = extractvalue %sollang.array.i32 %v118242, 2
  %push118241_full = icmp eq i64 %push118241_length, %push118241_capacity
  %push118241_empty = icmp eq i64 %push118241_capacity, 0
  %push118241_doubled = mul i64 %push118241_capacity, 2
  %push118241_grown_capacity = select i1 %push118241_empty, i64 4, i64 %push118241_doubled
  %push118241_append_capacity = select i1 %push118241_full, i64 %push118241_grown_capacity, i64 %push118241_capacity
  %push118241_append_bytes = mul i64 %push118241_append_capacity, 4
  br i1 %push118241_full, label %push118241_grow, label %push118241_keep
push118241_keep:
  br label %push118241_ready
push118241_grow:
  %push118241_grown_data = call ptr @malloc(i64 %push118241_append_bytes)
  %push118241_allocated = icmp ne ptr %push118241_grown_data, null
  br i1 %push118241_allocated, label %push118241_copy, label %push118241_allocation_failed
push118241_allocation_failed:
  call void @llvm.trap()
  unreachable
push118241_copy:
  %push118241_copy_bytes = mul i64 %push118241_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118241_grown_data, ptr %push118241_data, i64 %push118241_copy_bytes, i1 false)
  call void @free(ptr %push118241_data)
  br label %push118241_ready
push118241_ready:
  %push118241_append_data = phi ptr [ %push118241_data, %push118241_keep ], [ %push118241_grown_data, %push118241_copy ]
  %push118241_slot = getelementptr i32, ptr %push118241_append_data, i64 %push118241_length
  store i32 20, ptr %push118241_slot, align 4
  %push118241_new_length = add i64 %push118241_length, 1
  %push118241_array0 = insertvalue %sollang.array.i32 poison, ptr %push118241_append_data, 0
  %push118241_array1 = insertvalue %sollang.array.i32 %push118241_array0, i64 %push118241_new_length, 1
  %push118241_array2 = insertvalue %sollang.array.i32 %push118241_array1, i64 %push118241_append_capacity, 2
  store %sollang.array.i32 %push118241_array2, ptr %slot118215, align 8
  %v118244_expression_literal0 = getelementptr i8, ptr @sollang_str_118245, i64 0
  call void @sollang_runtime_print(ptr %v118244_expression_literal0, i64 0, i1 false)
  %v118244_expression73_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118244_expression72_raw = extractvalue %sollang.array.i32 %v118244_expression73_mutable, 1
  %v118244_expression72 = trunc i64 %v118244_expression72_raw to i32
  %v118244_expression72_print = zext i32 %v118244_expression72 to i64
  call void @sollang_runtime_print_i64(i64 %v118244_expression72_print, i1 false, i1 false)
  %v118244_expression_literal1 = getelementptr i8, ptr @sollang_str_118245, i64 12
  call void @sollang_runtime_print(ptr %v118244_expression_literal1, i64 1, i1 false)
  %v118244_expression75_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118244_expression74_data = extractvalue %sollang.array.i32 %v118244_expression75_mutable, 0
  %v118244_expression74_index = sext i32 1 to i64
  %v118244_expression74_length = extractvalue %sollang.array.i32 %v118244_expression75_mutable, 1
  %v118244_expression74_in_bounds = icmp ult i64 %v118244_expression74_index, %v118244_expression74_length
  br i1 %v118244_expression74_in_bounds, label %interpolation118244_array74_valid, label %interpolation118244_array74_invalid
interpolation118244_array74_invalid:
  call void @llvm.trap()
  unreachable
interpolation118244_array74_valid:
  %v118244_expression74_ptr = getelementptr i32, ptr %v118244_expression74_data, i64 %v118244_expression74_index
  %v118244_expression74 = load i32, ptr %v118244_expression74_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118244_expression74, i1 false)
  %v118244_expression_suffix = getelementptr i8, ptr @sollang_str_118245, i64 21
  call void @sollang_runtime_print(ptr %v118244_expression_suffix, i64 0, i1 true)
  call void @sollang_m144_s5()
  call void @sollang_m144_s8()
  call void @sollang_m144_s11()
  %v118249_ptr0 = getelementptr i32, ptr %v118249_data, i64 0
  store i32 7, ptr %v118249_ptr0, align 4
  %v118249_ptr1 = getelementptr i32, ptr %v118249_data, i64 1
  store i32 7, ptr %v118249_ptr1, align 4
  %v118249_ptr2 = getelementptr i32, ptr %v118249_data, i64 2
  store i32 7, ptr %v118249_ptr2, align 4
  %v118249_0 = insertvalue { ptr, i64 } poison, ptr %v118249_data, 0
  %v118249 = insertvalue { ptr, i64 } %v118249_0, i64 3, 1
  %v118251_expression_literal0 = getelementptr i8, ptr @sollang_str_118252, i64 0
  call void @sollang_runtime_print(ptr %v118251_expression_literal0, i64 0, i1 false)
  %v118251_expression77_raw = add i64 0, 3
  %v118251_expression77 = trunc i64 %v118251_expression77_raw to i32
  %v118251_expression77_print = zext i32 %v118251_expression77 to i64
  call void @sollang_runtime_print_i64(i64 %v118251_expression77_print, i1 false, i1 false)
  %v118251_expression_literal1 = getelementptr i8, ptr @sollang_str_118252, i64 18
  call void @sollang_runtime_print(ptr %v118251_expression_literal1, i64 1, i1 false)
  %v118251_expression79_data = extractvalue { ptr, i64 } %v118249, 0
  %v118251_expression79_index = sext i32 2 to i64
  %v118251_expression79_length = extractvalue { ptr, i64 } %v118249, 1
  %v118251_expression79_in_bounds = icmp ult i64 %v118251_expression79_index, %v118251_expression79_length
  br i1 %v118251_expression79_in_bounds, label %interpolation118251_array79_valid, label %interpolation118251_array79_invalid
interpolation118251_array79_invalid:
  call void @llvm.trap()
  unreachable
interpolation118251_array79_valid:
  %v118251_expression79_ptr = getelementptr i32, ptr %v118251_expression79_data, i64 %v118251_expression79_index
  %v118251_expression79 = load i32, ptr %v118251_expression79_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118251_expression79, i1 false)
  %v118251_expression_suffix = getelementptr i8, ptr @sollang_str_118252, i64 33
  call void @sollang_runtime_print(ptr %v118251_expression_suffix, i64 0, i1 true)
  %v118253_data = alloca [16 x i8], align 4
  %v118253_0 = insertvalue %sollang.array.i32 poison, ptr %v118253_data, 0
  %v118253_1 = insertvalue %sollang.array.i32 %v118253_0, i64 0, 1
  %v118253 = insertvalue %sollang.array.i32 %v118253_1, i64 4, 2
  %v118254_expression_literal0 = getelementptr i8, ptr @sollang_str_118255, i64 0
  call void @sollang_runtime_print(ptr %v118254_expression_literal0, i64 8, i1 false)
  %v118254_expression82_raw = extractvalue %sollang.array.i32 %v118253, 2
  %v118254_expression82 = trunc i64 %v118254_expression82_raw to i32
  %v118254_expression82_print = zext i32 %v118254_expression82 to i64
  call void @sollang_runtime_print_i64(i64 %v118254_expression82_print, i1 false, i1 false)
  %v118254_expression_suffix = getelementptr i8, ptr @sollang_str_118255, i64 30
  call void @sollang_runtime_print(ptr %v118254_expression_suffix, i64 0, i1 true)
  store %sollang.bounded_dictionary.t1216 zeroinitializer, ptr %v118256_owner, align 8
  %v118256_storage = getelementptr inbounds %sollang.bounded_dictionary.t1216, ptr %v118256_owner, i32 0, i32 1, i32 0
  %v118256 = load %sollang.bounded_dictionary.t1216, ptr %v118256_owner, align 8
  %v118257_expression_literal0 = getelementptr i8, ptr @sollang_str_118258, i64 0
  call void @sollang_runtime_print(ptr %v118257_expression_literal0, i64 19, i1 false)
  %v118257_expression84_raw = add i64 0, 4
  %v118257_expression84 = trunc i64 %v118257_expression84_raw to i32
  %v118257_expression84_print = zext i32 %v118257_expression84 to i64
  call void @sollang_runtime_print_i64(i64 %v118257_expression84_print, i1 false, i1 false)
  %v118257_expression_suffix = getelementptr i8, ptr @sollang_str_118258, i64 51
  call void @sollang_runtime_print(ptr %v118257_expression_suffix, i64 0, i1 true)
  %v118259_allocation_mirror = add i64 8, 23
  %v118259_allocation_offset = and i64 %v118259_allocation_mirror, -8
  %v118259_entry_bytes = mul i64 8, 8
  %v118259_allocation_bytes = add i64 %v118259_allocation_offset, %v118259_entry_bytes
  %v118259_storage = call ptr @malloc(i64 %v118259_allocation_bytes)
  %v118259_allocated = icmp ne ptr %v118259_storage, null
  br i1 %v118259_allocated, label %v118259_allocation_ready, label %v118259_allocation_failed
v118259_allocation_failed:
  call void @llvm.trap()
  unreachable
v118259_allocation_ready:
  %v118259_controls = getelementptr i8, ptr %v118259_storage, i64 0
  %v118259_entries_mirror = add i64 8, 23
  %v118259_entries_offset = and i64 %v118259_entries_mirror, -8
  %v118259_keys = getelementptr i8, ptr %v118259_storage, i64 %v118259_entries_offset
  %v118259_values = getelementptr i8, ptr %v118259_keys, i64 4
  %v118259_control_bytes = add i64 8, 16
  call void @llvm.memset.p0.i64(ptr %v118259_controls, i8 0, i64 %v118259_control_bytes, i1 false)
  %v118259_0 = insertvalue %sollang.dict poison, ptr %v118259_storage, 0
  %v118259_1 = insertvalue %sollang.dict %v118259_0, i64 0, 1
  %v118259 = insertvalue %sollang.dict %v118259_1, i64 8, 2
  %v118261 = freeze %sollang.dict %v118259
  %v118260_raw = extractvalue %sollang.dict %v118261, 2
  %v118260_capacity_fits = icmp ule i64 %v118260_raw, 2147483647
  br i1 %v118260_capacity_fits, label %v118260_capacity_ok, label %v118260_capacity_fail
v118260_capacity_fail:
  call void @llvm.trap()
  unreachable
v118260_capacity_ok:
  %v118260 = trunc i64 %v118260_raw to i32
  %v118262_expression_literal0 = getelementptr i8, ptr @sollang_str_118263, i64 0
  call void @sollang_runtime_print(ptr %v118262_expression_literal0, i64 11, i1 false)
  %v118262_expression87_raw = extractvalue %sollang.dict %v118259, 2
  %v118262_expression87 = trunc i64 %v118262_expression87_raw to i32
  %v118262_expression86 = icmp eq i32 %v118262_expression87, %v118260
  call void @sollang_runtime_print_i1(i1 %v118262_expression86, i1 false)
  %v118262_expression_suffix = getelementptr i8, ptr @sollang_str_118263, i64 58
  call void @sollang_runtime_print(ptr %v118262_expression_suffix, i64 0, i1 true)
  %v118265_data = call ptr @malloc(i64 16)
  %v118265_0 = insertvalue %sollang.array.i32 poison, ptr %v118265_data, 0
  %v118265_1 = insertvalue %sollang.array.i32 %v118265_0, i64 0, 1
  %v118265 = insertvalue %sollang.array.i32 %v118265_1, i64 4, 2
  %v118264 = insertvalue %sollang.struct.m144_s0 poison, %sollang.array.i32 %v118265, 0
  %v118267 = freeze %sollang.struct.m144_s0 %v118264
  store %sollang.struct.m144_s0 %v118267, ptr %callref118266_arg0, align 8
  %callref118266_arg0_address = getelementptr i8, ptr %callref118266_arg0, i64 0
  call void @sollang_m144_s2(ptr %callref118266_arg0_address)
  %v118268_data = call ptr @malloc(i64 16)
  %v118268_0 = insertvalue %sollang.array.i32 poison, ptr %v118268_data, 0
  %v118268_1 = insertvalue %sollang.array.i32 %v118268_0, i64 0, 1
  %v118268 = insertvalue %sollang.array.i32 %v118268_1, i64 4, 2
  %v118270 = freeze %sollang.array.i32 %v118268
  store %sollang.array.i32 %v118270, ptr %callref118269_arg0, align 8
  %callref118269_arg0_address = getelementptr i8, ptr %callref118269_arg0, i64 0
  call void @sollang_m144_s3(ptr %callref118269_arg0_address)
  %v118271_capacity_i64 = add i64 0, 4
  %v118271_capacity_positive = icmp ugt i64 %v118271_capacity_i64, 0
  %v118271_allocation = select i1 %v118271_capacity_positive, i64 %v118271_capacity_i64, i64 1
  %v118271_capacity_valid = icmp sge i64 %v118271_capacity_i64, 0
  %v118271_data = call ptr @sollang_raw_arena_create(i64 %v118271_allocation, i1 %v118271_capacity_valid)
  %v118271_0 = insertvalue %sollang.array.i32 poison, ptr %v118271_data, 0
  %v118271_1 = insertvalue %sollang.array.i32 %v118271_0, i64 0, 1
  %v118271 = insertvalue %sollang.array.i32 %v118271_1, i64 %v118271_allocation, 2
  %v118274 = freeze %sollang.array.i32 %v118271
  %v118279 = extractvalue %sollang.array.i32 %v118274, 2
  call void @sollang_runtime_print_i64(i64 %v118279, i1 false, i1 true)
  %v118275_expression_literal0 = getelementptr i8, ptr @sollang_str_118276, i64 0
  call void @sollang_runtime_print(ptr %v118275_expression_literal0, i64 6, i1 false)
  %v118275_expression90 = extractvalue %sollang.array.i32 %v118271, 2
  call void @sollang_runtime_print_i64(i64 %v118275_expression90, i1 false, i1 false)
  %v118275_expression_suffix = getelementptr i8, ptr @sollang_str_118276, i64 27
  call void @sollang_runtime_print(ptr %v118275_expression_suffix, i64 0, i1 true)
  %v118277_expression_literal0 = getelementptr i8, ptr @sollang_str_118278, i64 0
  call void @sollang_runtime_print(ptr %v118277_expression_literal0, i64 0, i1 false)
  %v118277_expression92 = call i32 @sollang_m144_s4(i32 10)
  call void @sollang_runtime_print_i32(i32 %v118277_expression92, i1 false)
  %v118277_expression_literal1 = getelementptr i8, ptr @sollang_str_118278, i64 13
  call void @sollang_runtime_print(ptr %v118277_expression_literal1, i64 1, i1 false)
  %v118277_expression95_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118277_expression94_raw = extractvalue %sollang.array.i32 %v118277_expression95_mutable, 2
  %v118277_expression94 = trunc i64 %v118277_expression94_raw to i32
  %v118277_expression94_print = zext i32 %v118277_expression94 to i64
  call void @sollang_runtime_print_i64(i64 %v118277_expression94_print, i1 false, i1 false)
  %v118277_expression_literal2 = getelementptr i8, ptr @sollang_str_118278, i64 31
  call void @sollang_runtime_print(ptr %v118277_expression_literal2, i64 1, i1 false)
  %v118277_expression96 = call i32 @sollang_m144_s4(i32 20)
  call void @sollang_runtime_print_i32(i32 %v118277_expression96, i1 false)
  %v118277_expression_literal3 = getelementptr i8, ptr @sollang_str_118278, i64 45
  call void @sollang_runtime_print(ptr %v118277_expression_literal3, i64 1, i1 false)
  %v118277_expression99_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118277_expression98_raw = extractvalue %sollang.array.i32 %v118277_expression99_mutable, 1
  %v118277_expression98 = trunc i64 %v118277_expression98_raw to i32
  %v118277_expression98_print = zext i32 %v118277_expression98 to i64
  call void @sollang_runtime_print_i64(i64 %v118277_expression98_print, i1 false, i1 false)
  %v118277_expression_suffix = getelementptr i8, ptr @sollang_str_118278, i64 58
  call void @sollang_runtime_print(ptr %v118277_expression_suffix, i64 0, i1 true)
  call void @sollang_drop_t188(%sollang.array.i32 %v118268)
  call void @sollang_drop_t1212(%sollang.struct.m144_s0 %v118264)
  call void @sollang_drop_t1217(%sollang.dict %v118259)
  call void @sollang_drop_t1216(%sollang.bounded_dictionary.t1216 %v118256)
  call void @sollang_drop_t1215(%sollang.array.i32 %v118253)
  %cleanup1182136_b118215_current = load %sollang.array.i32, ptr %slot118215, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182136_b118215_current)
  %cleanup1182136_b118214_current = load %sollang.array.i32, ptr %slot118214, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182136_b118214_current)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
