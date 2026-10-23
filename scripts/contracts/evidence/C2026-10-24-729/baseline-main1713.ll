define i32 @main() {
entry:
  %each118155_index_slot = alloca i64, align 8
  %each118155_limit_slot = alloca i64, align 8
  %each118171_index_slot = alloca i64, align 8
  %each118171_limit_slot = alloca i64, align 8
  %each118193_index_slot = alloca i64, align 8
  %each118193_limit_slot = alloca i64, align 8
  %slot118130 = alloca %sollang.array.i32, align 8
  %v118138_enum_slot = alloca %sollang.enum.t32, align 8
  store %sollang.enum.t32 zeroinitializer, ptr %v118138_enum_slot, align 8
  %v118138_enum_tag = getelementptr inbounds %sollang.enum.t32, ptr %v118138_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118138_enum_tag, align 4
  %v118138 = load %sollang.enum.t32, ptr %v118138_enum_slot, align 8
  %v118137 = insertvalue %sollang.struct.m0_s8 poison, %sollang.enum.t32 %v118138, 0
  %v118140_enum_slot = alloca %sollang.enum.t32, align 8
  store %sollang.enum.t32 zeroinitializer, ptr %v118140_enum_slot, align 8
  %v118140_enum_tag = getelementptr inbounds %sollang.enum.t32, ptr %v118140_enum_slot, i32 0, i32 0
  store i32 1, ptr %v118140_enum_tag, align 4
  %v118140 = load %sollang.enum.t32, ptr %v118140_enum_slot, align 8
  %v118139 = insertvalue %sollang.struct.m0_s8 poison, %sollang.enum.t32 %v118140, 0
  %v118141 = freeze %sollang.struct.m144_s0 zeroinitializer
  %v118143 = sub i32 0, 3
  %v118145 = sub i32 0, 1
  %v118147 = sub i32 0, 1
  %v118149 = sub i32 0, 1
  %v118142_data = call ptr @malloc(i64 32)
  %v118142_ptr0 = getelementptr i32, ptr %v118142_data, i64 0
  store i32 %v118143, ptr %v118142_ptr0, align 4
  %v118142_ptr1 = getelementptr i32, ptr %v118142_data, i64 1
  store i32 %v118145, ptr %v118142_ptr1, align 4
  %v118142_ptr2 = getelementptr i32, ptr %v118142_data, i64 2
  store i32 %v118147, ptr %v118142_ptr2, align 4
  %v118142_ptr3 = getelementptr i32, ptr %v118142_data, i64 3
  store i32 %v118149, ptr %v118142_ptr3, align 4
  %v118142_ptr4 = getelementptr i32, ptr %v118142_data, i64 4
  store i32 2, ptr %v118142_ptr4, align 4
  %v118142_ptr5 = getelementptr i32, ptr %v118142_data, i64 5
  store i32 4, ptr %v118142_ptr5, align 4
  %v118142_ptr6 = getelementptr i32, ptr %v118142_data, i64 6
  store i32 4, ptr %v118142_ptr6, align 4
  %v118142_ptr7 = getelementptr i32, ptr %v118142_data, i64 7
  store i32 9, ptr %v118142_ptr7, align 4
  %v118142_0 = insertvalue %sollang.array.i32 poison, ptr %v118142_data, 0
  %v118142_1 = insertvalue %sollang.array.i32 %v118142_0, i64 8, 1
  %v118142 = insertvalue %sollang.array.i32 %v118142_1, i64 8, 2
  store %sollang.array.i32 %v118142, ptr %slot118130, align 8
  %v118157 = sub i32 0, 5
  %v118156_start = insertvalue { i32, i32 } poison, i32 %v118157, 0
  %v118156 = insertvalue { i32, i32 } %v118156_start, i32 11, 1
  %each118155_range = freeze { i32, i32 } %v118156
  %each118155_first = extractvalue { i32, i32 } %each118155_range, 0
  %each118155_last = extractvalue { i32, i32 } %each118155_range, 1
  %each118155_start = sext i32 %each118155_first to i64
  %each118155_limit = sext i32 %each118155_last to i64
  store i64 %each118155_start, ptr %each118155_index_slot, align 8
  store i64 %each118155_limit, ptr %each118155_limit_slot, align 8
  br label %each118155_header
each118155_header:
  %each118155_index = load i64, ptr %each118155_index_slot, align 8
  %each118155_bound = load i64, ptr %each118155_limit_slot, align 8
  %each118155_done = icmp sgt i64 %each118155_index, %each118155_bound
  br i1 %each118155_done, label %each118155_exit, label %each118155_body
each118155_body:
  %each118155_item = trunc i64 %each118155_index to i32
  %each_role_m144_s20 = freeze i32 %each118155_item
  %v118163 = freeze i32 %each118155_item
  %v118161 = freeze %sollang.struct.m0_s8 %v118137
  %v118162 = load %sollang.array.i32, ptr %slot118130, align 8
  %v118164 = freeze %sollang.struct.m144_s0 %v118141
  %call118160_arg1_slice_data = extractvalue %sollang.array.i32 %v118162, 0
  %call118160_arg1_slice_length = extractvalue %sollang.array.i32 %v118162, 1
  %call118160_arg1_slice0 = insertvalue { ptr, i64 } poison, ptr %call118160_arg1_slice_data, 0
  %call118160_arg1_slice = insertvalue { ptr, i64 } %call118160_arg1_slice0, i64 %call118160_arg1_slice_length, 1
  %v118160 = call %sollang.struct.m0_s11 @sollang_m0_s228_g118204(%sollang.struct.m0_s8 %v118161, { ptr, i64 } %call118160_arg1_slice, i32 %v118163, %sollang.struct.m144_s0 %v118164)
  %v118166_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118166, 0
  %v118166 = insertvalue %sollang.text %v118166_ptr, i64 43, 1
  %v118165_expression_literal0 = getelementptr i8, ptr @sollang_str_118166, i64 0
  call void @sollang_runtime_print(ptr %v118165_expression_literal0, i64 4, i1 false)
  %v118165_expression0_print = zext i32 %each_role_m144_s20 to i64
  call void @sollang_runtime_print_i64(i64 %v118165_expression0_print, i1 false, i1 false)
  %v118165_expression_literal1 = getelementptr i8, ptr @sollang_str_118166, i64 11
  call void @sollang_runtime_print(ptr %v118165_expression_literal1, i64 1, i1 false)
  %v118165_expression1 = extractvalue %sollang.struct.m0_s11 %v118160, 0
  call void @sollang_runtime_print_i32(i32 %v118165_expression1, i1 false)
  %v118165_expression_literal2 = getelementptr i8, ptr @sollang_str_118166, i64 27
  call void @sollang_runtime_print(ptr %v118165_expression_literal2, i64 1, i1 false)
  %v118165_expression3 = extractvalue %sollang.struct.m0_s11 %v118160, 1
  call void @sollang_runtime_print_i1(i1 %v118165_expression3, i1 false)
  %v118165_expression_suffix = getelementptr i8, ptr @sollang_str_118166, i64 43
  call void @sollang_runtime_print(ptr %v118165_expression_suffix, i64 0, i1 true)
  br label %each118155_continue
each118155_continue:
  %each118155_current = load i64, ptr %each118155_index_slot, align 8
  %each118155_next = add i64 %each118155_current, 1
  store i64 %each118155_next, ptr %each118155_index_slot, align 8
  br label %each118155_header
each118155_exit:
  %v118168 = freeze %sollang.struct.m0_s8 %v118139
  %v118169 = load %sollang.array.i32, ptr %slot118130, align 8
  %v118170 = freeze %sollang.struct.m144_s0 %v118141
  %callmut118167_arg1_ptr = getelementptr inbounds %sollang.array.i32, ptr %slot118130, i32 0, i32 0
  %callmut118167_arg1_len = getelementptr inbounds %sollang.array.i32, ptr %slot118130, i32 0, i32 1
  %callmut118167_arg1_capacity = getelementptr inbounds %sollang.array.i32, ptr %slot118130, i32 0, i32 2
  %callmut118167_arg1_0 = insertvalue %sollang.mutable_container poison, ptr %callmut118167_arg1_ptr, 0
  %callmut118167_arg1_1 = insertvalue %sollang.mutable_container %callmut118167_arg1_0, ptr %callmut118167_arg1_len, 1
  %callmut118167_arg1 = insertvalue %sollang.mutable_container %callmut118167_arg1_1, ptr %callmut118167_arg1_capacity, 2
  call void @sollang_m0_s100_g118215(%sollang.struct.m0_s8 %v118168, %sollang.mutable_container %callmut118167_arg1, %sollang.struct.m144_s0 %v118170)
  %v118173 = sub i32 0, 5
  %v118172_start = insertvalue { i32, i32 } poison, i32 %v118173, 0
  %v118172 = insertvalue { i32, i32 } %v118172_start, i32 11, 1
  %each118171_range = freeze { i32, i32 } %v118172
  %each118171_first = extractvalue { i32, i32 } %each118171_range, 0
  %each118171_last = extractvalue { i32, i32 } %each118171_range, 1
  %each118171_start = sext i32 %each118171_first to i64
  %each118171_limit = sext i32 %each118171_last to i64
  store i64 %each118171_start, ptr %each118171_index_slot, align 8
  store i64 %each118171_limit, ptr %each118171_limit_slot, align 8
  br label %each118171_header
each118171_header:
  %each118171_index = load i64, ptr %each118171_index_slot, align 8
  %each118171_bound = load i64, ptr %each118171_limit_slot, align 8
  %each118171_done = icmp sgt i64 %each118171_index, %each118171_bound
  br i1 %each118171_done, label %each118171_exit, label %each118171_body
each118171_body:
  %each118171_item = trunc i64 %each118171_index to i32
  %each_role_m144_s21 = freeze i32 %each118171_item
  %v118179 = freeze i32 %each118171_item
  %v118177 = freeze %sollang.struct.m0_s8 %v118139
  %v118178 = load %sollang.array.i32, ptr %slot118130, align 8
  %v118180 = freeze %sollang.struct.m144_s0 %v118141
  %call118176_arg1_slice_data = extractvalue %sollang.array.i32 %v118178, 0
  %call118176_arg1_slice_length = extractvalue %sollang.array.i32 %v118178, 1
  %call118176_arg1_slice0 = insertvalue { ptr, i64 } poison, ptr %call118176_arg1_slice_data, 0
  %call118176_arg1_slice = insertvalue { ptr, i64 } %call118176_arg1_slice0, i64 %call118176_arg1_slice_length, 1
  %v118176 = call %sollang.struct.m0_s11 @sollang_m0_s228_g118204(%sollang.struct.m0_s8 %v118177, { ptr, i64 } %call118176_arg1_slice, i32 %v118179, %sollang.struct.m144_s0 %v118180)
  %v118182_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118182, 0
  %v118182 = insertvalue %sollang.text %v118182_ptr, i64 44, 1
  %v118181_expression_literal0 = getelementptr i8, ptr @sollang_str_118182, i64 0
  call void @sollang_runtime_print(ptr %v118181_expression_literal0, i64 5, i1 false)
  %v118181_expression5_print = zext i32 %each_role_m144_s21 to i64
  call void @sollang_runtime_print_i64(i64 %v118181_expression5_print, i1 false, i1 false)
  %v118181_expression_literal1 = getelementptr i8, ptr @sollang_str_118182, i64 12
  call void @sollang_runtime_print(ptr %v118181_expression_literal1, i64 1, i1 false)
  %v118181_expression6 = extractvalue %sollang.struct.m0_s11 %v118176, 0
  call void @sollang_runtime_print_i32(i32 %v118181_expression6, i1 false)
  %v118181_expression_literal2 = getelementptr i8, ptr @sollang_str_118182, i64 28
  call void @sollang_runtime_print(ptr %v118181_expression_literal2, i64 1, i1 false)
  %v118181_expression8 = extractvalue %sollang.struct.m0_s11 %v118176, 1
  call void @sollang_runtime_print_i1(i1 %v118181_expression8, i1 false)
  %v118181_expression_suffix = getelementptr i8, ptr @sollang_str_118182, i64 44
  call void @sollang_runtime_print(ptr %v118181_expression_suffix, i64 0, i1 true)
  br label %each118171_continue
each118171_continue:
  %each118171_current = load i64, ptr %each118171_index_slot, align 8
  %each118171_next = add i64 %each118171_current, 1
  store i64 %each118171_next, ptr %each118171_index_slot, align 8
  br label %each118171_header
each118171_exit:
  %v118183_data = inttoptr i64 0 to ptr
  %v118183_0 = insertvalue %sollang.array.i32 poison, ptr %v118183_data, 0
  %v118183_1 = insertvalue %sollang.array.i32 %v118183_0, i64 0, 1
  %v118183 = insertvalue %sollang.array.i32 %v118183_1, i64 0, 2
  %v118185 = freeze %sollang.struct.m0_s8 %v118137
  %v118186 = freeze %sollang.array.i32 %v118183
  %v118188 = freeze %sollang.struct.m144_s0 %v118141
  %call118184_arg1_slice_data = extractvalue %sollang.array.i32 %v118186, 0
  %call118184_arg1_slice_length = extractvalue %sollang.array.i32 %v118186, 1
  %call118184_arg1_slice0 = insertvalue { ptr, i64 } poison, ptr %call118184_arg1_slice_data, 0
  %call118184_arg1_slice = insertvalue { ptr, i64 } %call118184_arg1_slice0, i64 %call118184_arg1_slice_length, 1
  %v118184 = call %sollang.struct.m0_s11 @sollang_m0_s228_g118204(%sollang.struct.m0_s8 %v118185, { ptr, i64 } %call118184_arg1_slice, i32 0, %sollang.struct.m144_s0 %v118188)
  %v118190_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118190, 0
  %v118190 = insertvalue %sollang.text %v118190_ptr, i64 37, 1
  %v118189_expression_literal0 = getelementptr i8, ptr @sollang_str_118190, i64 0
  call void @sollang_runtime_print(ptr %v118189_expression_literal0, i64 6, i1 false)
  %v118189_expression10 = extractvalue %sollang.struct.m0_s11 %v118184, 0
  call void @sollang_runtime_print_i32(i32 %v118189_expression10, i1 false)
  %v118189_expression_literal1 = getelementptr i8, ptr @sollang_str_118190, i64 21
  call void @sollang_runtime_print(ptr %v118189_expression_literal1, i64 1, i1 false)
  %v118189_expression12 = extractvalue %sollang.struct.m0_s11 %v118184, 1
  call void @sollang_runtime_print_i1(i1 %v118189_expression12, i1 false)
  %v118189_expression_suffix = getelementptr i8, ptr @sollang_str_118190, i64 37
  call void @sollang_runtime_print(ptr %v118189_expression_suffix, i64 0, i1 true)
  %v118191_data = call ptr @malloc(i64 4)
  %v118191_ptr0 = getelementptr i32, ptr %v118191_data, i64 0
  store i32 7, ptr %v118191_ptr0, align 4
  %v118191_0 = insertvalue %sollang.array.i32 poison, ptr %v118191_data, 0
  %v118191_1 = insertvalue %sollang.array.i32 %v118191_0, i64 1, 1
  %v118191 = insertvalue %sollang.array.i32 %v118191_1, i64 1, 2
  %v118194_start = insertvalue { i32, i32 } poison, i32 6, 0
  %v118194 = insertvalue { i32, i32 } %v118194_start, i32 8, 1
  %each118193_range = freeze { i32, i32 } %v118194
  %each118193_first = extractvalue { i32, i32 } %each118193_range, 0
  %each118193_last = extractvalue { i32, i32 } %each118193_range, 1
  %each118193_start = sext i32 %each118193_first to i64
  %each118193_limit = sext i32 %each118193_last to i64
  store i64 %each118193_start, ptr %each118193_index_slot, align 8
  store i64 %each118193_limit, ptr %each118193_limit_slot, align 8
  br label %each118193_header
each118193_header:
  %each118193_index = load i64, ptr %each118193_index_slot, align 8
  %each118193_bound = load i64, ptr %each118193_limit_slot, align 8
  %each118193_done = icmp sgt i64 %each118193_index, %each118193_bound
  br i1 %each118193_done, label %each118193_exit, label %each118193_body
each118193_body:
  %each118193_item = trunc i64 %each118193_index to i32
  %each_role_m144_s22 = freeze i32 %each118193_item
  %v118200 = freeze i32 %each118193_item
  %v118198 = freeze %sollang.struct.m0_s8 %v118137
  %v118199 = freeze %sollang.array.i32 %v118191
  %v118201 = freeze %sollang.struct.m144_s0 %v118141
  %call118197_arg1_slice_data = extractvalue %sollang.array.i32 %v118199, 0
  %call118197_arg1_slice_length = extractvalue %sollang.array.i32 %v118199, 1
  %call118197_arg1_slice0 = insertvalue { ptr, i64 } poison, ptr %call118197_arg1_slice_data, 0
  %call118197_arg1_slice = insertvalue { ptr, i64 } %call118197_arg1_slice0, i64 %call118197_arg1_slice_length, 1
  %v118197 = call %sollang.struct.m0_s11 @sollang_m0_s228_g118204(%sollang.struct.m0_s8 %v118198, { ptr, i64 } %call118197_arg1_slice, i32 %v118200, %sollang.struct.m144_s0 %v118201)
  %v118203_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118203, 0
  %v118203 = insertvalue %sollang.text %v118203_ptr, i64 46, 1
  %v118202_expression_literal0 = getelementptr i8, ptr @sollang_str_118203, i64 0
  call void @sollang_runtime_print(ptr %v118202_expression_literal0, i64 7, i1 false)
  %v118202_expression14_print = zext i32 %each_role_m144_s22 to i64
  call void @sollang_runtime_print_i64(i64 %v118202_expression14_print, i1 false, i1 false)
  %v118202_expression_literal1 = getelementptr i8, ptr @sollang_str_118203, i64 14
  call void @sollang_runtime_print(ptr %v118202_expression_literal1, i64 1, i1 false)
  %v118202_expression15 = extractvalue %sollang.struct.m0_s11 %v118197, 0
  call void @sollang_runtime_print_i32(i32 %v118202_expression15, i1 false)
  %v118202_expression_literal2 = getelementptr i8, ptr @sollang_str_118203, i64 30
  call void @sollang_runtime_print(ptr %v118202_expression_literal2, i64 1, i1 false)
  %v118202_expression17 = extractvalue %sollang.struct.m0_s11 %v118197, 1
  call void @sollang_runtime_print_i1(i1 %v118202_expression17, i1 false)
  %v118202_expression_suffix = getelementptr i8, ptr @sollang_str_118203, i64 46
  call void @sollang_runtime_print(ptr %v118202_expression_suffix, i64 0, i1 true)
  br label %each118193_continue
each118193_continue:
  %each118193_current = load i64, ptr %each118193_index_slot, align 8
  %each118193_next = add i64 %each118193_current, 1
  store i64 %each118193_next, ptr %each118193_index_slot, align 8
  br label %each118193_header
each118193_exit:
  call void @sollang_drop_t371(%sollang.array.i32 %v118191)
  call void @sollang_drop_t70(%sollang.struct.m0_s11 %v118184)
  call void @sollang_drop_t371(%sollang.array.i32 %v118183)
  %cleanup1181266_b118130_current = load %sollang.array.i32, ptr %slot118130, align 8
  call void @sollang_drop_t371(%sollang.array.i32 %cleanup1181266_b118130_current)
  call void @sollang_drop_t1213(%sollang.struct.m144_s0 %v118141)
  call void @sollang_drop_t36(%sollang.struct.m0_s8 %v118139)
  call void @sollang_drop_t36(%sollang.struct.m0_s8 %v118137)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
