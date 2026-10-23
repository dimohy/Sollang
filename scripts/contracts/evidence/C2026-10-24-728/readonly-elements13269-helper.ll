define internal %sollang.struct.1666 @sollang_fn_sollang_compiler_semantic_diagnostics_firstArrayLiteralOperandDiagnostic(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %it, ptr %arg_0, ptr %arg_1, %sollang.struct.1666 %arg_2) #0 {
entry:
  %stack_slot0 = alloca [24 x i8], align 8
  %stack_slot1 = alloca [24 x i8], align 8
  %stack_slot2 = alloca [24 x i8], align 8
  %mutable_struct_slot0 = alloca %sollang.struct.1666, align 8
  %trap_written18 = alloca i32, align 4
  %trap_written34 = alloca i32, align 4
  %trap_written59 = alloca i32, align 4
  %trap_written84 = alloca i32, align 4
  %trap_written108 = alloca i32, align 4
  %mutable_scalar_slot111 = alloca i32, align 4
  %trap_written127 = alloca i32, align 4
  %trap_written143 = alloca i32, align 4
  %trap_written153 = alloca i32, align 4
  %trap_written164 = alloca i32, align 4
  %trap_written170 = alloca i32, align 4
  %trap_written178 = alloca i32, align 4
  %trap_written194 = alloca i32, align 4
  %mutable_scalar_slot197 = alloca i32, align 4
  %trap_written213 = alloca i32, align 4
  %mutable_scalar_slot224 = alloca i32, align 4
  %trap_written232 = alloca i32, align 4
  %trap_written252 = alloca i32, align 4
  %trap_written273 = alloca i32, align 4
  %mutable_scalar_slot276 = alloca i32, align 4
  %trap_written289 = alloca i32, align 4
  %trap_written305 = alloca i32, align 4
  %mutable_scalar_slot308 = alloca i32, align 4
  %ref_arg343 = alloca %sollang.dynamic_int_array, align 8
  %trap_written357 = alloca i32, align 4
  %trap_written371 = alloca i32, align 4
  %trap_written425 = alloca i32, align 4
  store %sollang.struct.1666 %arg_2, ptr %mutable_struct_slot0, align 8
  call void @llvm.lifetime.start.p0(i64 24, ptr %stack_slot0)
  %mutable_len_addr1 = getelementptr i8, ptr %stack_slot0, i64 8
  %mutable_capacity_addr2 = getelementptr i8, ptr %stack_slot0, i64 16
  store ptr null, ptr %stack_slot0, align 8
  store i64 0, ptr %mutable_len_addr1, align 8
  store i64 0, ptr %mutable_capacity_addr2, align 8
  call void @llvm.lifetime.start.p0(i64 24, ptr %stack_slot1)
  %mutable_len_addr3 = getelementptr i8, ptr %stack_slot1, i64 8
  %mutable_capacity_addr4 = getelementptr i8, ptr %stack_slot1, i64 16
  store ptr null, ptr %stack_slot1, align 8
  store i64 0, ptr %mutable_len_addr3, align 8
  store i64 0, ptr %mutable_capacity_addr4, align 8
  call void @llvm.lifetime.start.p0(i64 24, ptr %stack_slot2)
  %mutable_len_addr5 = getelementptr i8, ptr %stack_slot2, i64 8
  %mutable_capacity_addr6 = getelementptr i8, ptr %stack_slot2, i64 16
  store ptr null, ptr %stack_slot2, align 8
  store i64 0, ptr %mutable_len_addr5, align 8
  store i64 0, ptr %mutable_capacity_addr6, align 8
  %ref_value7 = load %sollang.struct.1657, ptr %it, align 8
  %field8 = extractvalue %sollang.struct.1657 %ref_value7, 3
  %field9 = extractvalue %sollang.struct.1622 %field8, 4
  %array_ptr10 = extractvalue %sollang.dynamic_int_array %field9, 0
  %array_len11 = extractvalue %sollang.dynamic_int_array %field9, 1
  %array_capacity12 = extractvalue %sollang.dynamic_int_array %field9, 2
  %array_each_done14 = icmp eq i64 %array_len11, 0
  br i1 %array_each_done14, label %bb_array_each_end2, label %bb_array_each_body0
bb_array_each_body0:
  %array_each_i15 = phi i64 [ 0, %entry ], [ %array_each_next13, %bb_array_each_continue1 ]
  %dynamic_inline_in_bounds16 = icmp ult i64 %array_each_i15, %array_len11
  br i1 %dynamic_inline_in_bounds16, label %bb_dynamic_inline_bounds_ok3, label %bb_dynamic_inline_bounds_fail4

bb_dynamic_inline_bounds_fail4:
  %trap_stderr17 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr17, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.204, i32 141, ptr %trap_written18, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok3:
  %dynamic_inline_slot19 = getelementptr %sollang.struct.1811, ptr %array_ptr10, i64 %array_each_i15
  %dynamic_inline_item20 = load %sollang.struct.1811, ptr %dynamic_inline_slot19, align 8
  %mutable_ptr21 = load ptr, ptr %stack_slot0, align 8
  %mutable_len22 = load i64, ptr %mutable_len_addr1, align 8
  %mutable_capacity23 = load i64, ptr %mutable_capacity_addr2, align 8
  %array_has_capacity24 = icmp ult i64 %mutable_len22, %mutable_capacity23
  br i1 %array_has_capacity24, label %bb_array_push_append5, label %bb_array_push_grow6

bb_array_push_append5:
  %array_slot25 = getelementptr i32, ptr %mutable_ptr21, i64 %mutable_len22
  store i32 -1, ptr %array_slot25, align 4
  %array_next_len26 = add i64 %mutable_len22, 1
  br label %bb_array_push_done7

bb_array_push_grow6:
  %array_has_any_capacity27 = icmp eq i64 %mutable_capacity23, 0
  %array_doubled_capacity28 = mul i64 %mutable_capacity23, 2
  %array_new_capacity29 = select i1 %array_has_any_capacity27, i64 4, i64 %array_doubled_capacity28
  %array_new_bytes30 = mul i64 %array_new_capacity29, 4
  %heap31 = call ptr @sollang_alloc(i64 %array_new_bytes30)
  %heap_ok32 = icmp ne ptr %heap31, null
  br i1 %heap_ok32, label %bb_alloc_ok8, label %bb_alloc_fail9

bb_alloc_fail9:
  %trap_stderr33 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr33, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.205, i32 125, ptr %trap_written34, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok8:
  br label %bb_array_copy10

bb_array_copy10:
  %array_copy_i36 = phi i64 [ 0, %bb_alloc_ok8 ], [ %array_copy_next_i35, %bb_array_copy_body11 ]
  %array_copy_active37 = icmp ult i64 %array_copy_i36, %mutable_len22
  br i1 %array_copy_active37, label %bb_array_copy_body11, label %bb_array_copy_done12

bb_array_copy_body11:
  %array_copy_src38 = getelementptr i32, ptr %mutable_ptr21, i64 %array_copy_i36
  %array_copy_dst39 = getelementptr i32, ptr %heap31, i64 %array_copy_i36
  %array_copy_value40 = load i32, ptr %array_copy_src38, align 4
  store i32 %array_copy_value40, ptr %array_copy_dst39, align 4
  %array_copy_next_i35 = add i64 %array_copy_i36, 1
  br label %bb_array_copy10

bb_array_copy_done12:
  call void @sollang_free(ptr %mutable_ptr21)
  %array_slot41 = getelementptr i32, ptr %heap31, i64 %mutable_len22
  store i32 -1, ptr %array_slot41, align 4
  %array_next_len42 = add i64 %mutable_len22, 1
  br label %bb_array_push_done7

bb_array_push_done7:
  %array_ptr43 = phi ptr [ %mutable_ptr21, %bb_array_push_append5 ], [ %heap31, %bb_array_copy_done12 ]
  %array_len44 = phi i64 [ %array_next_len26, %bb_array_push_append5 ], [ %array_next_len42, %bb_array_copy_done12 ]
  %array_capacity45 = phi i64 [ %mutable_capacity23, %bb_array_push_append5 ], [ %array_new_capacity29, %bb_array_copy_done12 ]
  store ptr %array_ptr43, ptr %stack_slot0, align 8
  store i64 %array_len44, ptr %mutable_len_addr1, align 8
  store i64 %array_capacity45, ptr %mutable_capacity_addr2, align 8
  %mutable_ptr46 = load ptr, ptr %stack_slot1, align 8
  %mutable_len47 = load i64, ptr %mutable_len_addr3, align 8
  %mutable_capacity48 = load i64, ptr %mutable_capacity_addr4, align 8
  %array_has_capacity49 = icmp ult i64 %mutable_len47, %mutable_capacity48
  br i1 %array_has_capacity49, label %bb_array_push_append13, label %bb_array_push_grow14

bb_array_push_append13:
  %array_slot50 = getelementptr i32, ptr %mutable_ptr46, i64 %mutable_len47
  store i32 -1, ptr %array_slot50, align 4
  %array_next_len51 = add i64 %mutable_len47, 1
  br label %bb_array_push_done15

bb_array_push_grow14:
  %array_has_any_capacity52 = icmp eq i64 %mutable_capacity48, 0
  %array_doubled_capacity53 = mul i64 %mutable_capacity48, 2
  %array_new_capacity54 = select i1 %array_has_any_capacity52, i64 4, i64 %array_doubled_capacity53
  %array_new_bytes55 = mul i64 %array_new_capacity54, 4
  %heap56 = call ptr @sollang_alloc(i64 %array_new_bytes55)
  %heap_ok57 = icmp ne ptr %heap56, null
  br i1 %heap_ok57, label %bb_alloc_ok16, label %bb_alloc_fail17

bb_alloc_fail17:
  %trap_stderr58 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr58, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.206, i32 126, ptr %trap_written59, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok16:
  br label %bb_array_copy18

bb_array_copy18:
  %array_copy_i61 = phi i64 [ 0, %bb_alloc_ok16 ], [ %array_copy_next_i60, %bb_array_copy_body19 ]
  %array_copy_active62 = icmp ult i64 %array_copy_i61, %mutable_len47
  br i1 %array_copy_active62, label %bb_array_copy_body19, label %bb_array_copy_done20

bb_array_copy_body19:
  %array_copy_src63 = getelementptr i32, ptr %mutable_ptr46, i64 %array_copy_i61
  %array_copy_dst64 = getelementptr i32, ptr %heap56, i64 %array_copy_i61
  %array_copy_value65 = load i32, ptr %array_copy_src63, align 4
  store i32 %array_copy_value65, ptr %array_copy_dst64, align 4
  %array_copy_next_i60 = add i64 %array_copy_i61, 1
  br label %bb_array_copy18

bb_array_copy_done20:
  call void @sollang_free(ptr %mutable_ptr46)
  %array_slot66 = getelementptr i32, ptr %heap56, i64 %mutable_len47
  store i32 -1, ptr %array_slot66, align 4
  %array_next_len67 = add i64 %mutable_len47, 1
  br label %bb_array_push_done15

bb_array_push_done15:
  %array_ptr68 = phi ptr [ %mutable_ptr46, %bb_array_push_append13 ], [ %heap56, %bb_array_copy_done20 ]
  %array_len69 = phi i64 [ %array_next_len51, %bb_array_push_append13 ], [ %array_next_len67, %bb_array_copy_done20 ]
  %array_capacity70 = phi i64 [ %mutable_capacity48, %bb_array_push_append13 ], [ %array_new_capacity54, %bb_array_copy_done20 ]
  store ptr %array_ptr68, ptr %stack_slot1, align 8
  store i64 %array_len69, ptr %mutable_len_addr3, align 8
  store i64 %array_capacity70, ptr %mutable_capacity_addr4, align 8
  %mutable_ptr71 = load ptr, ptr %stack_slot2, align 8
  %mutable_len72 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity73 = load i64, ptr %mutable_capacity_addr6, align 8
  %array_has_capacity74 = icmp ult i64 %mutable_len72, %mutable_capacity73
  br i1 %array_has_capacity74, label %bb_array_push_append21, label %bb_array_push_grow22

bb_array_push_append21:
  %array_slot75 = getelementptr i32, ptr %mutable_ptr71, i64 %mutable_len72
  store i32 -1, ptr %array_slot75, align 4
  %array_next_len76 = add i64 %mutable_len72, 1
  br label %bb_array_push_done23

bb_array_push_grow22:
  %array_has_any_capacity77 = icmp eq i64 %mutable_capacity73, 0
  %array_doubled_capacity78 = mul i64 %mutable_capacity73, 2
  %array_new_capacity79 = select i1 %array_has_any_capacity77, i64 4, i64 %array_doubled_capacity78
  %array_new_bytes80 = mul i64 %array_new_capacity79, 4
  %heap81 = call ptr @sollang_alloc(i64 %array_new_bytes80)
  %heap_ok82 = icmp ne ptr %heap81, null
  br i1 %heap_ok82, label %bb_alloc_ok24, label %bb_alloc_fail25

bb_alloc_fail25:
  %trap_stderr83 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr83, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.207, i32 126, ptr %trap_written84, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok24:
  br label %bb_array_copy26

bb_array_copy26:
  %array_copy_i86 = phi i64 [ 0, %bb_alloc_ok24 ], [ %array_copy_next_i85, %bb_array_copy_body27 ]
  %array_copy_active87 = icmp ult i64 %array_copy_i86, %mutable_len72
  br i1 %array_copy_active87, label %bb_array_copy_body27, label %bb_array_copy_done28

bb_array_copy_body27:
  %array_copy_src88 = getelementptr i32, ptr %mutable_ptr71, i64 %array_copy_i86
  %array_copy_dst89 = getelementptr i32, ptr %heap81, i64 %array_copy_i86
  %array_copy_value90 = load i32, ptr %array_copy_src88, align 4
  store i32 %array_copy_value90, ptr %array_copy_dst89, align 4
  %array_copy_next_i85 = add i64 %array_copy_i86, 1
  br label %bb_array_copy26

bb_array_copy_done28:
  call void @sollang_free(ptr %mutable_ptr71)
  %array_slot91 = getelementptr i32, ptr %heap81, i64 %mutable_len72
  store i32 -1, ptr %array_slot91, align 4
  %array_next_len92 = add i64 %mutable_len72, 1
  br label %bb_array_push_done23

bb_array_push_done23:
  %array_ptr93 = phi ptr [ %mutable_ptr71, %bb_array_push_append21 ], [ %heap81, %bb_array_copy_done28 ]
  %array_len94 = phi i64 [ %array_next_len76, %bb_array_push_append21 ], [ %array_next_len92, %bb_array_copy_done28 ]
  %array_capacity95 = phi i64 [ %mutable_capacity73, %bb_array_push_append21 ], [ %array_new_capacity79, %bb_array_copy_done28 ]
  store ptr %array_ptr93, ptr %stack_slot2, align 8
  store i64 %array_len94, ptr %mutable_len_addr5, align 8
  store i64 %array_capacity95, ptr %mutable_capacity_addr6, align 8
  br label %bb_array_each_continue1
bb_array_each_continue1:
  %array_each_next13 = add i64 %array_each_i15, 1
  %array_each_done96 = icmp eq i64 %array_each_next13, %array_len11
  br i1 %array_each_done96, label %bb_array_each_end2, label %bb_array_each_body0
bb_array_each_end2:
  %ref_value97 = load %sollang.struct.1657, ptr %it, align 8
  %field98 = extractvalue %sollang.struct.1657 %ref_value97, 3
  %field99 = extractvalue %sollang.struct.1622 %field98, 3
  %array_ptr100 = extractvalue %sollang.dynamic_int_array %field99, 0
  %array_len101 = extractvalue %sollang.dynamic_int_array %field99, 1
  %array_capacity102 = extractvalue %sollang.dynamic_int_array %field99, 2
  %array_each_done104 = icmp eq i64 %array_len101, 0
  br i1 %array_each_done104, label %bb_array_each_end31, label %bb_array_each_body29
bb_array_each_body29:
  %array_each_i105 = phi i64 [ 0, %bb_array_each_end2 ], [ %array_each_next103, %bb_array_each_continue30 ]
  %dynamic_inline_in_bounds106 = icmp ult i64 %array_each_i105, %array_len101
  br i1 %dynamic_inline_in_bounds106, label %bb_dynamic_inline_bounds_ok32, label %bb_dynamic_inline_bounds_fail33

bb_dynamic_inline_bounds_fail33:
  %trap_stderr107 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr107, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.208, i32 142, ptr %trap_written108, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok32:
  %dynamic_inline_slot109 = getelementptr %sollang.struct.1621, ptr %array_ptr100, i64 %array_each_i105
  %dynamic_inline_item110 = load %sollang.struct.1621, ptr %dynamic_inline_slot109, align 4
  store i32 0, ptr %mutable_scalar_slot111, align 4
  br label %bb_while_condition34
bb_while_condition34:
  %mutable_scalar112 = load i32, ptr %mutable_scalar_slot111, align 4
  %field113 = extractvalue %sollang.struct.1621 %dynamic_inline_item110, 2
  %cmp114 = icmp slt i32 %mutable_scalar112, %field113
  br i1 %cmp114, label %bb_while_body35, label %bb_while_end36
bb_while_body35:
  %field115 = extractvalue %sollang.struct.1621 %dynamic_inline_item110, 1
  %mutable_scalar116 = load i32, ptr %mutable_scalar_slot111, align 4
  %add117 = add i32 %field115, %mutable_scalar116
  %ref_value118 = load %sollang.struct.1657, ptr %it, align 8
  %field119 = extractvalue %sollang.struct.1657 %ref_value118, 3
  %field120 = extractvalue %sollang.struct.1622 %field119, 4
  %array_ptr121 = extractvalue %sollang.dynamic_int_array %field120, 0
  %array_len122 = extractvalue %sollang.dynamic_int_array %field120, 1
  %array_capacity123 = extractvalue %sollang.dynamic_int_array %field120, 2
  %index_size124 = sext i32 %add117 to i64
  %dynamic_inline_in_bounds125 = icmp ult i64 %index_size124, %array_len122
  br i1 %dynamic_inline_in_bounds125, label %bb_dynamic_inline_bounds_ok37, label %bb_dynamic_inline_bounds_fail38

bb_dynamic_inline_bounds_fail38:
  %trap_stderr126 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr126, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.209, i32 142, ptr %trap_written127, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok37:
  %dynamic_inline_slot128 = getelementptr %sollang.struct.1811, ptr %array_ptr121, i64 %index_size124
  %dynamic_inline_item129 = load %sollang.struct.1811, ptr %dynamic_inline_slot128, align 8
  %field130 = extractvalue %sollang.struct.1811 %dynamic_inline_item129, 1
  %cmp131 = icmp sge i32 %field130, 0
  br i1 %cmp131, label %bb_and_rhs39, label %bb_and_end40
bb_and_rhs39:
  %field132 = extractvalue %sollang.struct.1621 %dynamic_inline_item110, 2
  %cmp133 = icmp slt i32 %field130, %field132
  br label %bb_and_end40
bb_and_end40:
  %and134 = phi i1 [ false, %bb_dynamic_inline_bounds_ok37 ], [ %cmp133, %bb_and_rhs39 ]
  br i1 %and134, label %bb_if_then41, label %bb_if_end42
bb_if_then41:
  %field135 = extractvalue %sollang.struct.1621 %dynamic_inline_item110, 1
  %add136 = add i32 %field135, %field130
  %mutable_ptr137 = load ptr, ptr %stack_slot0, align 8
  %mutable_len138 = load i64, ptr %mutable_len_addr1, align 8
  %mutable_capacity139 = load i64, ptr %mutable_capacity_addr2, align 8
  %index_size140 = sext i32 %add136 to i64
  %array_in_bounds141 = icmp ult i64 %index_size140, %mutable_len138
  br i1 %array_in_bounds141, label %bb_array_bounds_ok43, label %bb_array_bounds_fail44

bb_array_bounds_fail44:
  %trap_stderr142 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr142, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.210, i32 133, ptr %trap_written143, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_bounds_ok43:
  %array_slot144 = getelementptr i32, ptr %mutable_ptr137, i64 %index_size140
  %array_item145 = load i32, ptr %array_slot144, align 4
  %cmp146 = icmp slt i32 %array_item145, 0
  br i1 %cmp146, label %bb_if_then45, label %bb_if_else46
bb_if_then45:
  %mutable_ptr147 = load ptr, ptr %stack_slot0, align 8
  %mutable_len148 = load i64, ptr %mutable_len_addr1, align 8
  %mutable_capacity149 = load i64, ptr %mutable_capacity_addr2, align 8
  %assignment_index150 = sext i32 %add136 to i64
  %array_assign_in_bounds151 = icmp ult i64 %assignment_index150, %mutable_len148
  br i1 %array_assign_in_bounds151, label %bb_array_assign_bounds_ok48, label %bb_array_assign_bounds_fail49

bb_array_assign_bounds_fail49:
  %trap_stderr152 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr152, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.211, i32 140, ptr %trap_written153, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_assign_bounds_ok48:
  %array_slot154 = getelementptr i32, ptr %mutable_ptr147, i64 %assignment_index150
  store i32 %add117, ptr %array_slot154, align 4
  br label %bb_if_end47
bb_if_else46:
  %mutable_ptr155 = load ptr, ptr %stack_slot2, align 8
  %mutable_len156 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity157 = load i64, ptr %mutable_capacity_addr6, align 8
  %mutable_ptr158 = load ptr, ptr %stack_slot1, align 8
  %mutable_len159 = load i64, ptr %mutable_len_addr3, align 8
  %mutable_capacity160 = load i64, ptr %mutable_capacity_addr4, align 8
  %index_size161 = sext i32 %add136 to i64
  %array_in_bounds162 = icmp ult i64 %index_size161, %mutable_len159
  br i1 %array_in_bounds162, label %bb_array_bounds_ok50, label %bb_array_bounds_fail51

bb_array_bounds_fail51:
  %trap_stderr163 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr163, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.212, i32 133, ptr %trap_written164, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_bounds_ok50:
  %array_slot165 = getelementptr i32, ptr %mutable_ptr158, i64 %index_size161
  %array_item166 = load i32, ptr %array_slot165, align 4
  %assignment_index167 = sext i32 %array_item166 to i64
  %array_assign_in_bounds168 = icmp ult i64 %assignment_index167, %mutable_len156
  br i1 %array_assign_in_bounds168, label %bb_array_assign_bounds_ok52, label %bb_array_assign_bounds_fail53

bb_array_assign_bounds_fail53:
  %trap_stderr169 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr169, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.213, i32 140, ptr %trap_written170, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_assign_bounds_ok52:
  %array_slot171 = getelementptr i32, ptr %mutable_ptr155, i64 %assignment_index167
  store i32 %add117, ptr %array_slot171, align 4
  br label %bb_if_end47
bb_if_end47:
  %mutable_ptr172 = load ptr, ptr %stack_slot1, align 8
  %mutable_len173 = load i64, ptr %mutable_len_addr3, align 8
  %mutable_capacity174 = load i64, ptr %mutable_capacity_addr4, align 8
  %assignment_index175 = sext i32 %add136 to i64
  %array_assign_in_bounds176 = icmp ult i64 %assignment_index175, %mutable_len173
  br i1 %array_assign_in_bounds176, label %bb_array_assign_bounds_ok54, label %bb_array_assign_bounds_fail55

bb_array_assign_bounds_fail55:
  %trap_stderr177 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr177, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.214, i32 140, ptr %trap_written178, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_assign_bounds_ok54:
  %array_slot179 = getelementptr i32, ptr %mutable_ptr172, i64 %assignment_index175
  store i32 %add117, ptr %array_slot179, align 4
  br label %bb_if_end42
bb_if_end42:
  %mutable_scalar180 = load i32, ptr %mutable_scalar_slot111, align 4
  %add181 = add i32 %mutable_scalar180, 1
  store i32 %add181, ptr %mutable_scalar_slot111, align 4
  br label %bb_while_condition34
bb_while_end36:
  br label %bb_array_each_continue30
bb_array_each_continue30:
  %array_each_next103 = add i64 %array_each_i105, 1
  %array_each_done182 = icmp eq i64 %array_each_next103, %array_len101
  br i1 %array_each_done182, label %bb_array_each_end31, label %bb_array_each_body29
bb_array_each_end31:
  %ref_value183 = load %sollang.struct.1657, ptr %it, align 8
  %field184 = extractvalue %sollang.struct.1657 %ref_value183, 3
  %field185 = extractvalue %sollang.struct.1622 %field184, 3
  %array_ptr186 = extractvalue %sollang.dynamic_int_array %field185, 0
  %array_len187 = extractvalue %sollang.dynamic_int_array %field185, 1
  %array_capacity188 = extractvalue %sollang.dynamic_int_array %field185, 2
  %array_each_done190 = icmp eq i64 %array_len187, 0
  br i1 %array_each_done190, label %bb_array_each_end58, label %bb_array_each_body56
bb_array_each_body56:
  %array_each_i191 = phi i64 [ 0, %bb_array_each_end31 ], [ %array_each_next189, %bb_array_each_continue57 ]
  %dynamic_inline_in_bounds192 = icmp ult i64 %array_each_i191, %array_len187
  br i1 %dynamic_inline_in_bounds192, label %bb_dynamic_inline_bounds_ok59, label %bb_dynamic_inline_bounds_fail60

bb_dynamic_inline_bounds_fail60:
  %trap_stderr193 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr193, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.215, i32 142, ptr %trap_written194, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok59:
  %dynamic_inline_slot195 = getelementptr %sollang.struct.1621, ptr %array_ptr186, i64 %array_each_i191
  %dynamic_inline_item196 = load %sollang.struct.1621, ptr %dynamic_inline_slot195, align 4
  store i32 0, ptr %mutable_scalar_slot197, align 4
  br label %bb_while_condition61
bb_while_condition61:
  %mutable_scalar198 = load i32, ptr %mutable_scalar_slot197, align 4
  %field199 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 2
  %cmp200 = icmp slt i32 %mutable_scalar198, %field199
  br i1 %cmp200, label %bb_while_body62, label %bb_while_end63
bb_while_body62:
  %field201 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 1
  %mutable_scalar202 = load i32, ptr %mutable_scalar_slot197, align 4
  %add203 = add i32 %field201, %mutable_scalar202
  %ref_value204 = load %sollang.struct.1657, ptr %it, align 8
  %field205 = extractvalue %sollang.struct.1657 %ref_value204, 3
  %field206 = extractvalue %sollang.struct.1622 %field205, 4
  %array_ptr207 = extractvalue %sollang.dynamic_int_array %field206, 0
  %array_len208 = extractvalue %sollang.dynamic_int_array %field206, 1
  %array_capacity209 = extractvalue %sollang.dynamic_int_array %field206, 2
  %index_size210 = sext i32 %add203 to i64
  %dynamic_inline_in_bounds211 = icmp ult i64 %index_size210, %array_len208
  br i1 %dynamic_inline_in_bounds211, label %bb_dynamic_inline_bounds_ok64, label %bb_dynamic_inline_bounds_fail65

bb_dynamic_inline_bounds_fail65:
  %trap_stderr212 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr212, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.216, i32 142, ptr %trap_written213, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok64:
  %dynamic_inline_slot214 = getelementptr %sollang.struct.1811, ptr %array_ptr207, i64 %index_size210
  %dynamic_inline_item215 = load %sollang.struct.1811, ptr %dynamic_inline_slot214, align 8
  %field216 = extractvalue %sollang.struct.1811 %dynamic_inline_item215, 0
  %cmp217 = icmp eq i32 %field216, 37
  br i1 %cmp217, label %bb_and_rhs66, label %bb_and_end67
bb_and_rhs66:
  %ref_value218 = load %sollang.struct.1657, ptr %it, align 8
  %field219 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 0
  %mutable_scalar220 = load i32, ptr %mutable_scalar_slot197, align 4
  %call221 = call i1 @sollang_fn_sollang_compiler_semantic_diagnostics_declarationBodyIsActive(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %it, ptr %arg_0, i32 %field219, i32 %mutable_scalar220)
  br label %bb_and_end67
bb_and_end67:
  %and222 = phi i1 [ false, %bb_dynamic_inline_bounds_ok64 ], [ %call221, %bb_and_rhs66 ]
  br i1 %and222, label %bb_if_then68, label %bb_if_end69
bb_if_then68:
  %neg223 = sub i32 0, 1
  store i32 %neg223, ptr %mutable_scalar_slot224, align 4
  %ref_value225 = load %sollang.dynamic_int_array, ptr %arg_1, align 8
  %array_ptr226 = extractvalue %sollang.dynamic_int_array %ref_value225, 0
  %array_len227 = extractvalue %sollang.dynamic_int_array %ref_value225, 1
  %array_capacity228 = extractvalue %sollang.dynamic_int_array %ref_value225, 2
  %index_size229 = sext i32 %add203 to i64
  %array_in_bounds230 = icmp ult i64 %index_size229, %array_len227
  br i1 %array_in_bounds230, label %bb_array_bounds_ok70, label %bb_array_bounds_fail71

bb_array_bounds_fail71:
  %trap_stderr231 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr231, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.217, i32 133, ptr %trap_written232, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_bounds_ok70:
  %array_slot233 = getelementptr i32, ptr %array_ptr226, i64 %index_size229
  %array_item234 = load i32, ptr %array_slot233, align 4
  %cmp235 = icmp sge i32 %array_item234, 0
  br i1 %cmp235, label %bb_and_rhs72, label %bb_and_end73
bb_and_rhs72:
  %ref_value236 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field237 = extractvalue %sollang.struct.1699 %ref_value236, 0
  %array_ptr238 = extractvalue %sollang.dynamic_int_array %field237, 0
  %array_len239 = extractvalue %sollang.dynamic_int_array %field237, 1
  %array_capacity240 = extractvalue %sollang.dynamic_int_array %field237, 2
  %array_len_value241 = trunc i64 %array_len239 to i32
  %cmp242 = icmp slt i32 %array_item234, %array_len_value241
  br label %bb_and_end73
bb_and_end73:
  %and243 = phi i1 [ false, %bb_array_bounds_ok70 ], [ %cmp242, %bb_and_rhs72 ]
  br i1 %and243, label %bb_if_then74, label %bb_if_end75
bb_if_then74:
  %ref_value244 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field245 = extractvalue %sollang.struct.1699 %ref_value244, 0
  %array_ptr246 = extractvalue %sollang.dynamic_int_array %field245, 0
  %array_len247 = extractvalue %sollang.dynamic_int_array %field245, 1
  %array_capacity248 = extractvalue %sollang.dynamic_int_array %field245, 2
  %index_size249 = sext i32 %array_item234 to i64
  %dynamic_inline_in_bounds250 = icmp ult i64 %index_size249, %array_len247
  br i1 %dynamic_inline_in_bounds250, label %bb_dynamic_inline_bounds_ok76, label %bb_dynamic_inline_bounds_fail77

bb_dynamic_inline_bounds_fail77:
  %trap_stderr251 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr251, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.218, i32 142, ptr %trap_written252, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok76:
  %dynamic_inline_slot253 = getelementptr %sollang.struct.1790, ptr %array_ptr246, i64 %index_size249
  %dynamic_inline_item254 = load %sollang.struct.1790, ptr %dynamic_inline_slot253, align 8
  %field255 = extractvalue %sollang.struct.1790 %dynamic_inline_item254, 0
  %cmp256 = icmp eq i32 %field255, 2
  br i1 %cmp256, label %bb_or_end79, label %bb_or_rhs78
bb_or_rhs78:
  %field257 = extractvalue %sollang.struct.1790 %dynamic_inline_item254, 0
  %cmp258 = icmp eq i32 %field257, 3
  br label %bb_or_end79
bb_or_end79:
  %or259 = phi i1 [ true, %bb_dynamic_inline_bounds_ok76 ], [ %cmp258, %bb_or_rhs78 ]
  br i1 %or259, label %bb_or_end81, label %bb_or_rhs80
bb_or_rhs80:
  %field260 = extractvalue %sollang.struct.1790 %dynamic_inline_item254, 0
  %cmp261 = icmp eq i32 %field260, 4
  br label %bb_or_end81
bb_or_end81:
  %or262 = phi i1 [ true, %bb_or_end79 ], [ %cmp261, %bb_or_rhs80 ]
  br i1 %or262, label %bb_or_end83, label %bb_or_rhs82
bb_or_rhs82:
  %field263 = extractvalue %sollang.struct.1790 %dynamic_inline_item254, 0
  %cmp264 = icmp eq i32 %field263, 12
  br label %bb_or_end83
bb_or_end83:
  %or265 = phi i1 [ true, %bb_or_end81 ], [ %cmp264, %bb_or_rhs82 ]
  br i1 %or265, label %bb_if_then84, label %bb_if_end85
bb_if_then84:
  %field266 = extractvalue %sollang.struct.1790 %dynamic_inline_item254, 4
  store i32 %field266, ptr %mutable_scalar_slot224, align 4
  br label %bb_if_end85
bb_if_end85:
  br label %bb_if_end75
bb_if_end75:
  %mutable_ptr267 = load ptr, ptr %stack_slot0, align 8
  %mutable_len268 = load i64, ptr %mutable_len_addr1, align 8
  %mutable_capacity269 = load i64, ptr %mutable_capacity_addr2, align 8
  %index_size270 = sext i32 %add203 to i64
  %array_in_bounds271 = icmp ult i64 %index_size270, %mutable_len268
  br i1 %array_in_bounds271, label %bb_array_bounds_ok86, label %bb_array_bounds_fail87

bb_array_bounds_fail87:
  %trap_stderr272 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr272, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.219, i32 133, ptr %trap_written273, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_bounds_ok86:
  %array_slot274 = getelementptr i32, ptr %mutable_ptr267, i64 %index_size270
  %array_item275 = load i32, ptr %array_slot274, align 4
  store i32 %array_item275, ptr %mutable_scalar_slot276, align 4
  br label %bb_while_condition88
bb_while_condition88:
  %mutable_scalar277 = load i32, ptr %mutable_scalar_slot276, align 4
  %cmp278 = icmp sge i32 %mutable_scalar277, 0
  br i1 %cmp278, label %bb_while_body89, label %bb_while_end90
bb_while_body89:
  %ref_value279 = load %sollang.struct.1657, ptr %it, align 8
  %field280 = extractvalue %sollang.struct.1657 %ref_value279, 3
  %field281 = extractvalue %sollang.struct.1622 %field280, 4
  %array_ptr282 = extractvalue %sollang.dynamic_int_array %field281, 0
  %array_len283 = extractvalue %sollang.dynamic_int_array %field281, 1
  %array_capacity284 = extractvalue %sollang.dynamic_int_array %field281, 2
  %mutable_scalar285 = load i32, ptr %mutable_scalar_slot276, align 4
  %index_size286 = sext i32 %mutable_scalar285 to i64
  %dynamic_inline_in_bounds287 = icmp ult i64 %index_size286, %array_len283
  br i1 %dynamic_inline_in_bounds287, label %bb_dynamic_inline_bounds_ok91, label %bb_dynamic_inline_bounds_fail92

bb_dynamic_inline_bounds_fail92:
  %trap_stderr288 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr288, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.220, i32 142, ptr %trap_written289, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok91:
  %dynamic_inline_slot290 = getelementptr %sollang.struct.1811, ptr %array_ptr282, i64 %index_size286
  %dynamic_inline_item291 = load %sollang.struct.1811, ptr %dynamic_inline_slot290, align 8
  %field292 = extractvalue %sollang.struct.1811 %dynamic_inline_item291, 0
  %cmp293 = icmp ne i32 %field292, 12
  br i1 %cmp293, label %bb_and_rhs93, label %bb_and_end94
bb_and_rhs93:
  %field294 = extractvalue %sollang.struct.1811 %dynamic_inline_item291, 0
  %cmp295 = icmp ne i32 %field294, 16
  br label %bb_and_end94
bb_and_end94:
  %and296 = phi i1 [ false, %bb_dynamic_inline_bounds_ok91 ], [ %cmp295, %bb_and_rhs93 ]
  br i1 %and296, label %bb_if_then95, label %bb_if_end96
bb_if_then95:
  %ref_value297 = load %sollang.dynamic_int_array, ptr %arg_1, align 8
  %array_ptr298 = extractvalue %sollang.dynamic_int_array %ref_value297, 0
  %array_len299 = extractvalue %sollang.dynamic_int_array %ref_value297, 1
  %array_capacity300 = extractvalue %sollang.dynamic_int_array %ref_value297, 2
  %mutable_scalar301 = load i32, ptr %mutable_scalar_slot276, align 4
  %index_size302 = sext i32 %mutable_scalar301 to i64
  %array_in_bounds303 = icmp ult i64 %index_size302, %array_len299
  br i1 %array_in_bounds303, label %bb_array_bounds_ok97, label %bb_array_bounds_fail98

bb_array_bounds_fail98:
  %trap_stderr304 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr304, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.221, i32 133, ptr %trap_written305, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_bounds_ok97:
  %array_slot306 = getelementptr i32, ptr %array_ptr298, i64 %index_size302
  %array_item307 = load i32, ptr %array_slot306, align 4
  store i32 %array_item307, ptr %mutable_scalar_slot308, align 4
  %field309 = extractvalue %sollang.struct.1811 %dynamic_inline_item291, 0
  %cmp310 = icmp eq i32 %field309, 15
  br i1 %cmp310, label %bb_if_then99, label %bb_if_end100
bb_if_then99:
  %ref_value311 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field312 = extractvalue %sollang.struct.1699 %ref_value311, 0
  %array_ptr313 = extractvalue %sollang.dynamic_int_array %field312, 0
  %array_len314 = extractvalue %sollang.dynamic_int_array %field312, 1
  %array_capacity315 = extractvalue %sollang.dynamic_int_array %field312, 2
  %ref_field316 = getelementptr inbounds %sollang.struct.1699, ptr %arg_0, i32 0, i32 0
  %mutable_scalar317 = load i32, ptr %mutable_scalar_slot308, align 4
  %numeric_call318 = call i32 @sollang_fn_$736F6C6C616E672E636F6D70696C65722E73656D616E7469632E747970655F6964732E6D6174657269616C697A656452656164547970654964(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %ref_field316, i32 %mutable_scalar317)
  store i32 %numeric_call318, ptr %mutable_scalar_slot308, align 4
  br label %bb_if_end100
bb_if_end100:
  %mutable_scalar319 = load i32, ptr %mutable_scalar_slot308, align 4
  %cmp320 = icmp sge i32 %mutable_scalar319, 0
  br i1 %cmp320, label %bb_and_rhs101, label %bb_and_end102
bb_and_rhs101:
  %mutable_scalar321 = load i32, ptr %mutable_scalar_slot308, align 4
  %ref_value322 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field323 = extractvalue %sollang.struct.1699 %ref_value322, 0
  %array_ptr324 = extractvalue %sollang.dynamic_int_array %field323, 0
  %array_len325 = extractvalue %sollang.dynamic_int_array %field323, 1
  %array_capacity326 = extractvalue %sollang.dynamic_int_array %field323, 2
  %array_len_value327 = trunc i64 %array_len325 to i32
  %cmp328 = icmp slt i32 %mutable_scalar321, %array_len_value327
  br label %bb_and_end102
bb_and_end102:
  %and329 = phi i1 [ false, %bb_if_end100 ], [ %cmp328, %bb_and_rhs101 ]
  br i1 %and329, label %bb_if_then103, label %bb_if_end104
bb_if_then103:
  %mutable_scalar330 = load i32, ptr %mutable_scalar_slot224, align 4
  %cmp331 = icmp slt i32 %mutable_scalar330, 0
  br i1 %cmp331, label %bb_if_then105, label %bb_if_end106
bb_if_then105:
  %mutable_scalar332 = load i32, ptr %mutable_scalar_slot308, align 4
  store i32 %mutable_scalar332, ptr %mutable_scalar_slot224, align 4
  br label %bb_if_end106
bb_if_end106:
  %ref_value333 = load %sollang.struct.1657, ptr %it, align 8
  %field334 = extractvalue %sollang.struct.1657 %ref_value333, 3
  %ref_field335 = getelementptr inbounds %sollang.struct.1657, ptr %it, i32 0, i32 3
  %ref_field336 = getelementptr inbounds %sollang.struct.1699, ptr %arg_0, i32 0, i32 0
  %mutable_ptr337 = load ptr, ptr %stack_slot0, align 8
  %mutable_len338 = load i64, ptr %mutable_len_addr1, align 8
  %mutable_capacity339 = load i64, ptr %mutable_capacity_addr2, align 8
  %generic_array_value340 = insertvalue %sollang.dynamic_int_array poison, ptr %mutable_ptr337, 0
  %generic_array_value341 = insertvalue %sollang.dynamic_int_array %generic_array_value340, i64 %mutable_len338, 1
  %generic_array_value342 = insertvalue %sollang.dynamic_int_array %generic_array_value341, i64 %mutable_capacity339, 2
  store %sollang.dynamic_int_array %generic_array_value342, ptr %ref_arg343, align 8
  %mutable_scalar344 = load i32, ptr %mutable_scalar_slot276, align 4
  %mutable_scalar345 = load i32, ptr %mutable_scalar_slot224, align 4
  %field346 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 0
  %call347 = call i1 @sollang_fn_sollang_compiler_semantic_diagnostics_arrayElementUsesNumericLiteralContext(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %ref_field335, ptr %ref_field336, ptr %ref_arg343, i32 %mutable_scalar344, i32 %mutable_scalar345, i32 %field346)
  %ref_value348 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field349 = extractvalue %sollang.struct.1699 %ref_value348, 0
  %array_ptr350 = extractvalue %sollang.dynamic_int_array %field349, 0
  %array_len351 = extractvalue %sollang.dynamic_int_array %field349, 1
  %array_capacity352 = extractvalue %sollang.dynamic_int_array %field349, 2
  %mutable_scalar353 = load i32, ptr %mutable_scalar_slot224, align 4
  %index_size354 = sext i32 %mutable_scalar353 to i64
  %dynamic_inline_in_bounds355 = icmp ult i64 %index_size354, %array_len351
  br i1 %dynamic_inline_in_bounds355, label %bb_dynamic_inline_bounds_ok107, label %bb_dynamic_inline_bounds_fail108

bb_dynamic_inline_bounds_fail108:
  %trap_stderr356 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr356, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.222, i32 143, ptr %trap_written357, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok107:
  %dynamic_inline_slot358 = getelementptr %sollang.struct.1790, ptr %array_ptr350, i64 %index_size354
  %dynamic_inline_item359 = load %sollang.struct.1790, ptr %dynamic_inline_slot358, align 8
  %field360 = extractvalue %sollang.struct.1790 %dynamic_inline_item359, 8
  %not361 = xor i1 %field360, true
  br i1 %not361, label %bb_and_rhs109, label %bb_and_end110
bb_and_rhs109:
  %ref_value362 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field363 = extractvalue %sollang.struct.1699 %ref_value362, 0
  %array_ptr364 = extractvalue %sollang.dynamic_int_array %field363, 0
  %array_len365 = extractvalue %sollang.dynamic_int_array %field363, 1
  %array_capacity366 = extractvalue %sollang.dynamic_int_array %field363, 2
  %mutable_scalar367 = load i32, ptr %mutable_scalar_slot308, align 4
  %index_size368 = sext i32 %mutable_scalar367 to i64
  %dynamic_inline_in_bounds369 = icmp ult i64 %index_size368, %array_len365
  br i1 %dynamic_inline_in_bounds369, label %bb_dynamic_inline_bounds_ok111, label %bb_dynamic_inline_bounds_fail112

bb_dynamic_inline_bounds_fail112:
  %trap_stderr370 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr370, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.223, i32 143, ptr %trap_written371, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok111:
  %dynamic_inline_slot372 = getelementptr %sollang.struct.1790, ptr %array_ptr364, i64 %index_size368
  %dynamic_inline_item373 = load %sollang.struct.1790, ptr %dynamic_inline_slot372, align 8
  %field374 = extractvalue %sollang.struct.1790 %dynamic_inline_item373, 8
  %not375 = xor i1 %field374, true
  br label %bb_and_end110
bb_and_end110:
  %and376 = phi i1 [ false, %bb_dynamic_inline_bounds_ok107 ], [ %not375, %bb_dynamic_inline_bounds_ok111 ]
  br i1 %and376, label %bb_and_rhs113, label %bb_and_end114
bb_and_rhs113:
  %not377 = xor i1 %call347, true
  br label %bb_and_end114
bb_and_end114:
  %and378 = phi i1 [ false, %bb_and_end110 ], [ %not377, %bb_and_rhs113 ]
  br i1 %and378, label %bb_and_rhs115, label %bb_and_end116
bb_and_rhs115:
  %ref_value379 = load %sollang.struct.1699, ptr %arg_0, align 8
  %field380 = extractvalue %sollang.struct.1699 %ref_value379, 0
  %array_ptr381 = extractvalue %sollang.dynamic_int_array %field380, 0
  %array_len382 = extractvalue %sollang.dynamic_int_array %field380, 1
  %array_capacity383 = extractvalue %sollang.dynamic_int_array %field380, 2
  %ref_field384 = getelementptr inbounds %sollang.struct.1699, ptr %arg_0, i32 0, i32 0
  %mutable_scalar385 = load i32, ptr %mutable_scalar_slot308, align 4
  %mutable_scalar386 = load i32, ptr %mutable_scalar_slot224, align 4
  %call387 = call i1 @sollang_fn_sollang_compiler_semantic_diagnostics_indexedOperandTypesMatch(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %ref_field384, i32 %mutable_scalar385, i32 %mutable_scalar386)
  %not388 = xor i1 %call387, true
  br label %bb_and_end116
bb_and_end116:
  %and389 = phi i1 [ false, %bb_and_end114 ], [ %not388, %bb_and_rhs115 ]
  br i1 %and389, label %bb_and_rhs117, label %bb_and_end118
bb_and_rhs117:
  %ref_value390 = load %sollang.struct.1657, ptr %it, align 8
  %field391 = extractvalue %sollang.struct.1657 %ref_value390, 3
  %ref_field392 = getelementptr inbounds %sollang.struct.1657, ptr %it, i32 0, i32 3
  %field393 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 0
  %mutable_scalar394 = load i32, ptr %mutable_scalar_slot276, align 4
  %field395 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 1
  %sub396 = sub i32 %mutable_scalar394, %field395
  %mutable_struct397 = load %sollang.struct.1666, ptr %mutable_struct_slot0, align 8
  %field398 = extractvalue %sollang.struct.1666 %mutable_struct397, 1
  %mutable_struct399 = load %sollang.struct.1666, ptr %mutable_struct_slot0, align 8
  %field400 = extractvalue %sollang.struct.1666 %mutable_struct399, 3
  %call401 = call i1 @sollang_fn_sollang_compiler_semantic_diagnostics_diagnosticOriginBefore(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %ref_field392, i32 %field393, i32 %sub396, i32 %field398, i32 %field400)
  br label %bb_and_end118
bb_and_end118:
  %and402 = phi i1 [ false, %bb_and_end116 ], [ %call401, %bb_and_rhs117 ]
  br i1 %and402, label %bb_if_then119, label %bb_if_end120
bb_if_then119:
  %struct_init403 = insertvalue %sollang.struct.1666 poison, i32 15, 0
  %field404 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 0
  %struct_init405 = insertvalue %sollang.struct.1666 %struct_init403, i32 %field404, 1
  %mutable_scalar406 = load i32, ptr %mutable_scalar_slot197, align 4
  %struct_init407 = insertvalue %sollang.struct.1666 %struct_init405, i32 %mutable_scalar406, 2
  %mutable_scalar408 = load i32, ptr %mutable_scalar_slot276, align 4
  %field409 = extractvalue %sollang.struct.1621 %dynamic_inline_item196, 1
  %sub410 = sub i32 %mutable_scalar408, %field409
  %struct_init411 = insertvalue %sollang.struct.1666 %struct_init407, i32 %sub410, 3
  %field412 = extractvalue %sollang.struct.1811 %dynamic_inline_item291, 8
  %struct_init413 = insertvalue %sollang.struct.1666 %struct_init411, i32 %field412, 4
  %mutable_scalar414 = load i32, ptr %mutable_scalar_slot224, align 4
  %struct_init415 = insertvalue %sollang.struct.1666 %struct_init413, i32 %mutable_scalar414, 5
  %mutable_scalar416 = load i32, ptr %mutable_scalar_slot308, align 4
  %struct_init417 = insertvalue %sollang.struct.1666 %struct_init415, i32 %mutable_scalar416, 6
  store %sollang.struct.1666 %struct_init417, ptr %mutable_struct_slot0, align 4
  br label %bb_if_end120
bb_if_end120:
  br label %bb_if_end104
bb_if_end104:
  br label %bb_if_end96
bb_if_end96:
  %mutable_ptr418 = load ptr, ptr %stack_slot2, align 8
  %mutable_len419 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity420 = load i64, ptr %mutable_capacity_addr6, align 8
  %mutable_scalar421 = load i32, ptr %mutable_scalar_slot276, align 4
  %index_size422 = sext i32 %mutable_scalar421 to i64
  %array_in_bounds423 = icmp ult i64 %index_size422, %mutable_len419
  br i1 %array_in_bounds423, label %bb_array_bounds_ok121, label %bb_array_bounds_fail122

bb_array_bounds_fail122:
  %trap_stderr424 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr424, ptr @.slg.str.module.x736F6C6C616E672E636F6D70696C65722E73656D616E7469632E646961676E6F7374696373.224, i32 134, ptr %trap_written425, ptr null)
  call void @llvm.trap()
  unreachable

bb_array_bounds_ok121:
  %array_slot426 = getelementptr i32, ptr %mutable_ptr418, i64 %index_size422
  %array_item427 = load i32, ptr %array_slot426, align 4
  store i32 %array_item427, ptr %mutable_scalar_slot276, align 4
  br label %bb_while_condition88
bb_while_end90:
  br label %bb_if_end69
bb_if_end69:
  %mutable_scalar428 = load i32, ptr %mutable_scalar_slot197, align 4
  %add429 = add i32 %mutable_scalar428, 1
  store i32 %add429, ptr %mutable_scalar_slot197, align 4
  br label %bb_while_condition61
bb_while_end63:
  br label %bb_array_each_continue57
bb_array_each_continue57:
  %array_each_next189 = add i64 %array_each_i191, 1
  %array_each_done430 = icmp eq i64 %array_each_next189, %array_len187
  br i1 %array_each_done430, label %bb_array_each_end58, label %bb_array_each_body56
bb_array_each_end58:
  %mutable_struct431 = load %sollang.struct.1666, ptr %mutable_struct_slot0, align 8
  %mutable_ptr432 = load ptr, ptr %stack_slot2, align 8
  %mutable_len433 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity434 = load i64, ptr %mutable_capacity_addr6, align 8
  call void @sollang_free(ptr %mutable_ptr432)
  call void @llvm.lifetime.end.p0(i64 24, ptr %stack_slot2)
  %mutable_ptr435 = load ptr, ptr %stack_slot1, align 8
  %mutable_len436 = load i64, ptr %mutable_len_addr3, align 8
  %mutable_capacity437 = load i64, ptr %mutable_capacity_addr4, align 8
  call void @sollang_free(ptr %mutable_ptr435)
  call void @llvm.lifetime.end.p0(i64 24, ptr %stack_slot1)
  %mutable_ptr438 = load ptr, ptr %stack_slot0, align 8
  %mutable_len439 = load i64, ptr %mutable_len_addr1, align 8
  %mutable_capacity440 = load i64, ptr %mutable_capacity_addr2, align 8
  call void @sollang_free(ptr %mutable_ptr438)
  call void @llvm.lifetime.end.p0(i64 24, ptr %stack_slot0)
  %mutable_struct441 = load %sollang.struct.1666, ptr %mutable_struct_slot0, align 8
  ret %sollang.struct.1666 %mutable_struct431
}
