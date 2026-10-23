define %sollang.enum.t1212 @sollang_m144_s0(i32 %arg, i1 %arg1) {
entry:
  br i1 %arg1, label %while118113_bool118108_rhs, label %while118113_exit
while118113_bool118108_rhs:
  %while118113_v118110 = icmp eq i32 %arg, 1
  br i1 %while118113_v118110, label %while118113_body, label %while118113_exit
while118113_body:
  br label %if118113_then
while118113_exit:
  br label %if118113_merge
if118113_then:
  %v118116_enum_slot = alloca %sollang.enum.t1212, align 8
  store %sollang.enum.t1212 zeroinitializer, ptr %v118116_enum_slot, align 8
  %v118116_enum_tag = getelementptr inbounds %sollang.enum.t1212, ptr %v118116_enum_slot, i32 0, i32 0
  store i32 1, ptr %v118116_enum_tag, align 4
  %v118116_enum_payload = getelementptr inbounds %sollang.enum.t1212, ptr %v118116_enum_slot, i32 0, i32 1
  store i32 9, ptr %v118116_enum_payload, align 4
  %v118116 = load %sollang.enum.t1212, ptr %v118116_enum_slot, align 8
  ret %sollang.enum.t1212 %v118116
if118113_merge:
  %v118119 = add i32 %arg, 10
  %v118118_enum_slot = alloca %sollang.enum.t1212, align 8
  store %sollang.enum.t1212 zeroinitializer, ptr %v118118_enum_slot, align 8
  %v118118_enum_tag = getelementptr inbounds %sollang.enum.t1212, ptr %v118118_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118118_enum_tag, align 4
  %v118118_enum_payload = getelementptr inbounds %sollang.enum.t1212, ptr %v118118_enum_slot, i32 0, i32 1
  store i32 %v118119, ptr %v118118_enum_payload, align 4
  %v118118 = load %sollang.enum.t1212, ptr %v118118_enum_slot, align 8
  ret %sollang.enum.t1212 %v118118
}

define %sollang.enum.t1213 @sollang_m144_s2(i1 %arg) {
entry:
  %interpolation118134_try1_slot = alloca %sollang.enum.t1212, align 8
  %interpolation118134_try1_return_slot = alloca %sollang.enum.t1213, align 8
  %slot118125 = alloca i32, align 4
  %v118139_enum_slot = alloca %sollang.enum.t1213, align 8
  store %sollang.enum.t1213 zeroinitializer, ptr %v118139_enum_slot, align 8
  %v118139_enum_tag = getelementptr inbounds %sollang.enum.t1213, ptr %v118139_enum_slot, i32 0, i32 0
  store i32 0, ptr %v118139_enum_tag, align 4
  %v118139 = load %sollang.enum.t1213, ptr %v118139_enum_slot, align 8
  store i32 0, ptr %slot118125, align 4
  br label %while118132_header
while118132_header:
  %while118132_v118130 = load i32, ptr %slot118125, align 4
  %while118132_v118129 = icmp slt i32 %while118132_v118130, 2
  br i1 %while118132_v118129, label %while118132_body, label %while118132_exit
while118132_body:
  %v118135_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118135, 0
  %v118135 = insertvalue %sollang.text %v118135_ptr, i64 35, 1
  %v118134_expression_literal0 = getelementptr i8, ptr @sollang_str_118135, i64 0
  call void @sollang_runtime_print(ptr %v118134_expression_literal0, i64 6, i1 false)
  %v118134_expression2_mutable = load i32, ptr %slot118125, align 8
  %v118134_expression0 = call %sollang.enum.t1212 @sollang_m144_s0(i32 %v118134_expression2_mutable, i1 %arg)
  store %sollang.enum.t1212 %v118134_expression0, ptr %interpolation118134_try1_slot, align 8
  %interpolation118134_try1_tag = extractvalue %sollang.enum.t1212 %v118134_expression0, 0
  %interpolation118134_try1_is_error = icmp eq i32 %interpolation118134_try1_tag, 1
  br i1 %interpolation118134_try1_is_error, label %interpolation118134_try1_error, label %interpolation118134_try1_ok
interpolation118134_try1_error:
  %interpolation118134_try1_error_addr = getelementptr inbounds %sollang.enum.t1212, ptr %interpolation118134_try1_slot, i32 0, i32 1
  %interpolation118134_try1_error_value = load i32, ptr %interpolation118134_try1_error_addr, align 4
  store %sollang.enum.t1213 zeroinitializer, ptr %interpolation118134_try1_return_slot, align 8
  %interpolation118134_try1_return_tag = getelementptr inbounds %sollang.enum.t1213, ptr %interpolation118134_try1_return_slot, i32 0, i32 0
  store i32 1, ptr %interpolation118134_try1_return_tag, align 4
  %interpolation118134_try1_return_payload = getelementptr inbounds %sollang.enum.t1213, ptr %interpolation118134_try1_return_slot, i32 0, i32 1
  store i32 %interpolation118134_try1_error_value, ptr %interpolation118134_try1_return_payload, align 4
  %interpolation118134_try1_return_value = load %sollang.enum.t1213, ptr %interpolation118134_try1_return_slot, align 8
  ret %sollang.enum.t1213 %interpolation118134_try1_return_value
interpolation118134_try1_ok:
  %interpolation118134_try1_ok_addr = getelementptr inbounds %sollang.enum.t1212, ptr %interpolation118134_try1_slot, i32 0, i32 1
  %v118134_expression1 = load i32, ptr %interpolation118134_try1_ok_addr, align 4
  %v118134_expression1_print = zext i32 %v118134_expression1 to i64
  call void @sollang_runtime_print_i64(i64 %v118134_expression1_print, i1 false, i1 false)
  %v118134_expression_suffix = getelementptr i8, ptr @sollang_str_118135, i64 35
  call void @sollang_runtime_print(ptr %v118134_expression_suffix, i64 0, i1 true)
  %v118137 = load i32, ptr %slot118125, align 4
  %v118136 = add i32 %v118137, 1
  store i32 %v118136, ptr %slot118125, align 4
  br label %while118132_header
while118132_exit:
  ret %sollang.enum.t1213 %v118139
}

define i32 @main() {
entry:
  %v118144_subject_slot = alloca %sollang.enum.t1213, align 8
  %v118158_subject_slot = alloca %sollang.enum.t1213, align 8
  %v118142 = call %sollang.enum.t1213 @sollang_m144_s2(i1 0)
  %v118144_tag = extractvalue %sollang.enum.t1213 %v118142, 0
  store %sollang.enum.t1213 %v118142, ptr %v118144_subject_slot, align 8
  %v118144_is_arm0 = icmp eq i32 %v118144_tag, 0
  br i1 %v118144_is_arm0, label %match118144_arm0, label %match118144_next0
match118144_arm0:
  %v118149_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118149, 0
  %v118149 = insertvalue %sollang.text %v118149_ptr, i64 2, 1
  call void @sollang_runtime_print(ptr @sollang_str_118149, i64 2, i1 true)
  br label %match118144_merge
match118144_next0:
  %v118144_is_arm1 = icmp eq i32 %v118144_tag, 1
  br i1 %v118144_is_arm1, label %match118144_arm1, label %match118144_next1
match118144_arm1:
  %v118144_arm1_payload = getelementptr inbounds %sollang.enum.t1213, ptr %v118144_subject_slot, i32 0, i32 1
  %v118151 = load i32, ptr %v118144_arm1_payload, align 4
  %v118154_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118154, 0
  %v118154 = insertvalue %sollang.text %v118154_ptr, i64 12, 1
  %v118153_expression_literal0 = getelementptr i8, ptr @sollang_str_118154, i64 0
  call void @sollang_runtime_print(ptr %v118153_expression_literal0, i64 6, i1 false)
  call void @sollang_runtime_print_i32(i32 %v118151, i1 false)
  %v118153_expression_suffix = getelementptr i8, ptr @sollang_str_118154, i64 12
  call void @sollang_runtime_print(ptr %v118153_expression_suffix, i64 0, i1 true)
  br label %match118144_merge
match118144_next1:
  call void @llvm.trap()
  unreachable
match118144_merge:
  %v118156 = call %sollang.enum.t1213 @sollang_m144_s2(i1 1)
  %v118158_tag = extractvalue %sollang.enum.t1213 %v118156, 0
  store %sollang.enum.t1213 %v118156, ptr %v118158_subject_slot, align 8
  %v118158_is_arm0 = icmp eq i32 %v118158_tag, 0
  br i1 %v118158_is_arm0, label %match118158_arm0, label %match118158_next0
match118158_arm0:
  %v118163_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118163, 0
  %v118163 = insertvalue %sollang.text %v118163_ptr, i64 2, 1
  call void @sollang_runtime_print(ptr @sollang_str_118163, i64 2, i1 true)
  br label %match118158_merge
match118158_next0:
  %v118158_is_arm1 = icmp eq i32 %v118158_tag, 1
  br i1 %v118158_is_arm1, label %match118158_arm1, label %match118158_next1
match118158_arm1:
  %v118158_arm1_payload = getelementptr inbounds %sollang.enum.t1213, ptr %v118158_subject_slot, i32 0, i32 1
  %v118165 = load i32, ptr %v118158_arm1_payload, align 4
  %v118168_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118168, 0
  %v118168 = insertvalue %sollang.text %v118168_ptr, i64 12, 1
  %v118167_expression_literal0 = getelementptr i8, ptr @sollang_str_118168, i64 0
  call void @sollang_runtime_print(ptr %v118167_expression_literal0, i64 6, i1 false)
  call void @sollang_runtime_print_i32(i32 %v118165, i1 false)
  %v118167_expression_suffix = getelementptr i8, ptr @sollang_str_118168, i64 12
  call void @sollang_runtime_print(ptr %v118167_expression_suffix, i64 0, i1 true)
  br label %match118158_merge
match118158_next1:
  call void @llvm.trap()
  unreachable
match118158_merge:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
