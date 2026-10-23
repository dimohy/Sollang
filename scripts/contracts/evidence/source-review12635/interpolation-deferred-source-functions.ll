define i32 @main() {
entry:
  %v118105_owner = alloca %sollang.bounded_dictionary.t1247, align 8
  %each118108_index_slot = alloca i64, align 8
  %each118108_limit_slot = alloca i64, align 8
  %deferred_text118116_tag = alloca i64, align 8
  %if118116_result = alloca %sollang.text, align 8
  %v118118_expression0_logical_slot = alloca i1, align 1
  %deferred_text118118_root0_slot = alloca i1, align 1
  %deferred_text118120_value_slot = alloca %sollang.text, align 8
  %deferred_text118125_tag = alloca i64, align 8
  %if118125_result = alloca %sollang.text, align 8
  %v118127_expression7_owner = alloca %sollang.bounded_dictionary.t1247, align 8
  %deferred_text118127_root7_slot = alloca i32, align 4
  %deferred_text118129_value_slot = alloca %sollang.text, align 8
  store %sollang.bounded_dictionary.t1247 zeroinitializer, ptr %v118105_owner, align 8
  %v118105_storage = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %v118105_owner, i32 0, i32 1, i32 0
  %bd118105_0_key_operand = add i32 0, 1
  %bd118105_0_value_operand = add i32 0, 10
  %bd118105_0_hash_key = sext i32 %bd118105_0_key_operand to i64
  %bd118105_0_hash_high = lshr i64 %bd118105_0_hash_key, 32
  %bd118105_0_hash_fold = xor i64 %bd118105_0_hash_key, %bd118105_0_hash_high
  %bd118105_0_hash = mul i64 %bd118105_0_hash_fold, -7046029254386353131
  %bd118105_0_h2_shifted = lshr i64 %bd118105_0_hash, 57
  %bd118105_0_h2_raw = and i64 %bd118105_0_h2_shifted, 127
  %bd118105_0_h2_zero = icmp eq i64 %bd118105_0_h2_raw, 0
  %bd118105_0_h2_value = select i1 %bd118105_0_h2_zero, i64 1, i64 %bd118105_0_h2_raw
  %bd118105_0_h2 = trunc i64 %bd118105_0_h2_value to i8
  %bd118105_0_probe_keys = getelementptr i8, ptr %v118105_storage, i64 32
  %bd118105_0_group_mask = sub i64 16, 1
  %bd118105_0_group_start = and i64 %bd118105_0_hash, %bd118105_0_group_mask
  %bd118105_0_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bd118105_0_group_has_capacity, label %bd118105_0_group_first, label %bd118105_0_group_no_capacity
bd118105_0_group_no_capacity:
  br label %bd118105_0_group_done
bd118105_0_group_first:
  %bd118105_0_group_control_ptr = getelementptr i8, ptr %v118105_storage, i64 %bd118105_0_group_start
  %bd118105_0_group_control = load i8, ptr %bd118105_0_group_control_ptr, align 1
  %bd118105_0_group_empty = icmp eq i8 %bd118105_0_group_control, 0
  br i1 %bd118105_0_group_empty, label %bd118105_0_group_vacant, label %bd118105_0_group_occupied
bd118105_0_group_occupied:
  %bd118105_0_group_h2_match = icmp eq i8 %bd118105_0_group_control, %bd118105_0_h2
  br i1 %bd118105_0_group_h2_match, label %bd118105_0_group_compare, label %bd118105_0_group_fallback
bd118105_0_group_compare:
  %bd118105_0_group_key_ptr = getelementptr [8 x i8], ptr %bd118105_0_probe_keys, i64 %bd118105_0_group_start
  %bd118105_0_group_key = load i32, ptr %bd118105_0_group_key_ptr, align 4
  %bd118105_0_group_equal = icmp eq i32 %bd118105_0_group_key, %bd118105_0_key_operand
  br i1 %bd118105_0_group_equal, label %bd118105_0_group_match, label %bd118105_0_group_fallback
bd118105_0_group_match:
  br label %bd118105_0_group_done
bd118105_0_group_vacant:
  br label %bd118105_0_group_done
bd118105_0_group_fallback:
  %bd118105_0_group_grouped_mask = sub i64 16, 1
  %bd118105_0_group_grouped_start = and i64 %bd118105_0_hash, %bd118105_0_group_grouped_mask
  br label %bd118105_0_group_grouped_entry
bd118105_0_group_grouped_entry:
  br label %bd118105_0_group_grouped_group
bd118105_0_group_grouped_group:
  %bd118105_0_group_grouped_probe = phi i64 [ 0, %bd118105_0_group_grouped_entry ], [ %bd118105_0_group_grouped_next_probe, %bd118105_0_group_grouped_next_group ]
  %bd118105_0_group_grouped_first_deleted = phi i64 [ 16, %bd118105_0_group_grouped_entry ], [ %bd118105_0_group_grouped_next_deleted, %bd118105_0_group_grouped_next_group ]
  %bd118105_0_group_grouped_active = icmp ult i64 %bd118105_0_group_grouped_probe, 16
  br i1 %bd118105_0_group_grouped_active, label %bd118105_0_group_grouped_body, label %bd118105_0_group_grouped_miss
bd118105_0_group_grouped_body:
  %bd118105_0_group_grouped_unwrapped = add i64 %bd118105_0_group_grouped_start, %bd118105_0_group_grouped_probe
  %bd118105_0_group_grouped_group_start = and i64 %bd118105_0_group_grouped_unwrapped, %bd118105_0_group_grouped_mask
  %bd118105_0_group_grouped_control_ptr = getelementptr i8, ptr %v118105_storage, i64 %bd118105_0_group_grouped_group_start
  %bd118105_0_group_grouped_controls = load <16 x i8>, ptr %bd118105_0_group_grouped_control_ptr, align 1
  %bd118105_0_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bd118105_0_h2, i64 0
  %bd118105_0_group_grouped_h2_vector = shufflevector <16 x i8> %bd118105_0_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118105_0_group_grouped_matches = icmp eq <16 x i8> %bd118105_0_group_grouped_controls, %bd118105_0_group_grouped_h2_vector
  %bd118105_0_group_grouped_match_bits = bitcast <16 x i1> %bd118105_0_group_grouped_matches to i16
  %bd118105_0_group_grouped_empties = icmp eq <16 x i8> %bd118105_0_group_grouped_controls, zeroinitializer
  %bd118105_0_group_grouped_empty_bits = bitcast <16 x i1> %bd118105_0_group_grouped_empties to i16
  %bd118105_0_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bd118105_0_group_grouped_deleted_vector = shufflevector <16 x i8> %bd118105_0_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118105_0_group_grouped_deleted_matches = icmp eq <16 x i8> %bd118105_0_group_grouped_controls, %bd118105_0_group_grouped_deleted_vector
  %bd118105_0_group_grouped_deleted_bits = bitcast <16 x i1> %bd118105_0_group_grouped_deleted_matches to i16
  %bd118105_0_group_grouped_has_deleted = icmp ne i16 %bd118105_0_group_grouped_deleted_bits, 0
  %bd118105_0_group_grouped_no_previous_deleted = icmp eq i64 %bd118105_0_group_grouped_first_deleted, 16
  %bd118105_0_group_grouped_capture_deleted = and i1 %bd118105_0_group_grouped_has_deleted, %bd118105_0_group_grouped_no_previous_deleted
  %bd118105_0_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bd118105_0_group_grouped_deleted_bits, i1 false)
  %bd118105_0_group_grouped_deleted_offset = zext i16 %bd118105_0_group_grouped_deleted_offset16 to i64
  %bd118105_0_group_grouped_deleted_unwrapped = add i64 %bd118105_0_group_grouped_group_start, %bd118105_0_group_grouped_deleted_offset
  %bd118105_0_group_grouped_deleted_slot = and i64 %bd118105_0_group_grouped_deleted_unwrapped, %bd118105_0_group_grouped_mask
  %bd118105_0_group_grouped_captured_deleted = select i1 %bd118105_0_group_grouped_capture_deleted, i64 %bd118105_0_group_grouped_deleted_slot, i64 %bd118105_0_group_grouped_first_deleted
  br label %bd118105_0_group_grouped_candidates
bd118105_0_group_grouped_candidates:
  %bd118105_0_group_grouped_candidate_bits = phi i16 [ %bd118105_0_group_grouped_match_bits, %bd118105_0_group_grouped_body ], [ %bd118105_0_group_grouped_cleared_bits, %bd118105_0_group_grouped_candidate_next ]
  %bd118105_0_group_grouped_has_candidate = icmp ne i16 %bd118105_0_group_grouped_candidate_bits, 0
  br i1 %bd118105_0_group_grouped_has_candidate, label %bd118105_0_group_grouped_candidate, label %bd118105_0_group_grouped_decision
bd118105_0_group_grouped_candidate:
  %bd118105_0_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bd118105_0_group_grouped_candidate_bits, i1 false)
  %bd118105_0_group_grouped_candidate_offset = zext i16 %bd118105_0_group_grouped_candidate_offset16 to i64
  %bd118105_0_group_grouped_candidate_unwrapped = add i64 %bd118105_0_group_grouped_group_start, %bd118105_0_group_grouped_candidate_offset
  %bd118105_0_group_grouped_candidate_slot = and i64 %bd118105_0_group_grouped_candidate_unwrapped, %bd118105_0_group_grouped_mask
  %bd118105_0_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bd118105_0_probe_keys, i64 %bd118105_0_group_grouped_candidate_slot
  %bd118105_0_group_grouped_key = load i32, ptr %bd118105_0_group_grouped_key_ptr, align 4
  %bd118105_0_group_grouped_candidate_equal = icmp eq i32 %bd118105_0_group_grouped_key, %bd118105_0_key_operand
  br i1 %bd118105_0_group_grouped_candidate_equal, label %bd118105_0_group_grouped_match, label %bd118105_0_group_grouped_candidate_next
bd118105_0_group_grouped_candidate_next:
  %bd118105_0_group_grouped_bits_minus_one = sub i16 %bd118105_0_group_grouped_candidate_bits, 1
  %bd118105_0_group_grouped_cleared_bits = and i16 %bd118105_0_group_grouped_candidate_bits, %bd118105_0_group_grouped_bits_minus_one
  br label %bd118105_0_group_grouped_candidates
bd118105_0_group_grouped_decision:
  %bd118105_0_group_grouped_has_empty = icmp ne i16 %bd118105_0_group_grouped_empty_bits, 0
  br i1 %bd118105_0_group_grouped_has_empty, label %bd118105_0_group_grouped_empty, label %bd118105_0_group_grouped_next_group
bd118105_0_group_grouped_empty:
  %bd118105_0_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bd118105_0_group_grouped_empty_bits, i1 false)
  %bd118105_0_group_grouped_empty_offset = zext i16 %bd118105_0_group_grouped_empty_offset16 to i64
  %bd118105_0_group_grouped_empty_unwrapped = add i64 %bd118105_0_group_grouped_group_start, %bd118105_0_group_grouped_empty_offset
  %bd118105_0_group_grouped_empty_slot = and i64 %bd118105_0_group_grouped_empty_unwrapped, %bd118105_0_group_grouped_mask
  %bd118105_0_group_grouped_use_empty = icmp eq i64 %bd118105_0_group_grouped_captured_deleted, 16
  %bd118105_0_group_grouped_insertion_slot = select i1 %bd118105_0_group_grouped_use_empty, i64 %bd118105_0_group_grouped_empty_slot, i64 %bd118105_0_group_grouped_captured_deleted
  br label %bd118105_0_group_grouped_done
bd118105_0_group_grouped_match:
  br label %bd118105_0_group_grouped_done
bd118105_0_group_grouped_next_group:
  %bd118105_0_group_grouped_next_probe = add i64 %bd118105_0_group_grouped_probe, 16
  %bd118105_0_group_grouped_next_deleted = add i64 %bd118105_0_group_grouped_captured_deleted, 0
  br label %bd118105_0_group_grouped_group
bd118105_0_group_grouped_miss:
  %bd118105_0_group_grouped_no_deleted = icmp eq i64 %bd118105_0_group_grouped_first_deleted, 16
  %bd118105_0_group_grouped_miss_slot = select i1 %bd118105_0_group_grouped_no_deleted, i64 0, i64 %bd118105_0_group_grouped_first_deleted
  br label %bd118105_0_group_grouped_done
bd118105_0_group_grouped_done:
  %bd118105_0_group_grouped_found = phi i1 [ false, %bd118105_0_group_grouped_empty ], [ true, %bd118105_0_group_grouped_match ], [ false, %bd118105_0_group_grouped_miss ]
  %bd118105_0_group_grouped_slot = phi i64 [ %bd118105_0_group_grouped_insertion_slot, %bd118105_0_group_grouped_empty ], [ %bd118105_0_group_grouped_candidate_slot, %bd118105_0_group_grouped_match ], [ %bd118105_0_group_grouped_miss_slot, %bd118105_0_group_grouped_miss ]
  br label %bd118105_0_group_done
bd118105_0_group_done:
  %bd118105_0_group_found = phi i1 [ true, %bd118105_0_group_match ], [ false, %bd118105_0_group_vacant ], [ %bd118105_0_group_grouped_found, %bd118105_0_group_grouped_done ], [ false, %bd118105_0_group_no_capacity ]
  %bd118105_0_group_slot = phi i64 [ %bd118105_0_group_start, %bd118105_0_group_match ], [ %bd118105_0_group_start, %bd118105_0_group_vacant ], [ %bd118105_0_group_grouped_slot, %bd118105_0_group_grouped_done ], [ 0, %bd118105_0_group_no_capacity ]
  %bd118105_0_slot = add i64 %bd118105_0_group_slot, 0
  %bd118105_0_exists = or i1 %bd118105_0_group_found, false
  br label %bd118105_0_insert
bd118105_0_insert:
  %bd118105_0_key_entry_offset = mul i64 %bd118105_0_slot, 8
  %bd118105_0_key_entries_field_offset = add i64 32, 0
  %bd118105_0_key_field_offset = add i64 %bd118105_0_key_entry_offset, %bd118105_0_key_entries_field_offset
  %bd118105_0_key_ptr = getelementptr i8, ptr %v118105_storage, i64 %bd118105_0_key_field_offset
  store i32 %bd118105_0_key_operand, ptr %bd118105_0_key_ptr, align 4
  %bd118105_0_value_entry_offset = mul i64 %bd118105_0_slot, 8
  %bd118105_0_value_entries_field_offset = add i64 32, 4
  %bd118105_0_value_field_offset = add i64 %bd118105_0_value_entry_offset, %bd118105_0_value_entries_field_offset
  %bd118105_0_value_ptr = getelementptr i8, ptr %v118105_storage, i64 %bd118105_0_value_field_offset
  store i32 %bd118105_0_value_operand, ptr %bd118105_0_value_ptr, align 4
  %bd118105_0_control_control_ptr = getelementptr i8, ptr %v118105_storage, i64 %bd118105_0_slot
  store i8 %bd118105_0_h2, ptr %bd118105_0_control_control_ptr, align 1
  %bd118105_0_control_mirror_needed = icmp ult i64 %bd118105_0_slot, 16
  %bd118105_0_control_mirror_candidate = add i64 %bd118105_0_slot, 16
  %bd118105_0_control_mirror_slot = select i1 %bd118105_0_control_mirror_needed, i64 %bd118105_0_control_mirror_candidate, i64 %bd118105_0_slot
  %bd118105_0_control_mirror_ptr = getelementptr i8, ptr %v118105_storage, i64 %bd118105_0_control_mirror_slot
  store i8 %bd118105_0_h2, ptr %bd118105_0_control_mirror_ptr, align 1
  %v118105_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %v118105_owner, i32 0, i32 0
  store i64 1, ptr %v118105_length_ptr, align 8
  %v118105 = load %sollang.bounded_dictionary.t1247, ptr %v118105_owner, align 8
  %v118109_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118109 = insertvalue { i32, i32 } %v118109_start, i32 2, 1
  %each118108_range = freeze { i32, i32 } %v118109
  %each118108_first = extractvalue { i32, i32 } %each118108_range, 0
  %each118108_last = extractvalue { i32, i32 } %each118108_range, 1
  %each118108_start = sext i32 %each118108_first to i64
  %each118108_limit = sext i32 %each118108_last to i64
  store i64 %each118108_start, ptr %each118108_index_slot, align 8
  store i64 %each118108_limit, ptr %each118108_limit_slot, align 8
  br label %each118108_header
each118108_header:
  %each118108_index = load i64, ptr %each118108_index_slot, align 8
  %each118108_bound = load i64, ptr %each118108_limit_slot, align 8
  %each118108_done = icmp sgt i64 %each118108_index, %each118108_bound
  br i1 %each118108_done, label %each118108_exit, label %each118108_body
each118108_body:
  %each118108_item = trunc i64 %each118108_index to i32
  %each_role_m144_s2 = freeze i32 %each118108_item
  %v118114 = freeze i32 %each118108_item
  %v118123 = freeze i32 %each118108_item
  %v118113 = icmp sgt i32 %v118114, 0
  br i1 %v118113, label %if118116_then, label %if118116_else
if118116_then:
  %v118118_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118118, 0
  %v118118 = insertvalue %sollang.text %v118118_ptr, i64 34, 1
  %v118118_expression1 = icmp sgt i32 %each_role_m144_s2, 0
  store i1 0, ptr %v118118_expression0_logical_slot, align 1
  br i1 %v118118_expression1, label %interpolation118118_logical0_rhs, label %interpolation118118_logical0_end
interpolation118118_logical0_rhs:
  %v118118_expression4 = icmp slt i32 %each_role_m144_s2, 2
  store i1 %v118118_expression4, ptr %v118118_expression0_logical_slot, align 1
  br label %interpolation118118_logical0_end
interpolation118118_logical0_end:
  %v118118_expression0 = load i1, ptr %v118118_expression0_logical_slot, align 1
  store i1 %v118118_expression0, ptr %deferred_text118118_root0_slot, align 1
  store i64 118118, ptr %deferred_text118116_tag, align 8
  store %sollang.text poison, ptr %if118116_result, align 8
  br label %if118116_merge
if118116_else:
  %v118120_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118120, 0
  %v118120 = insertvalue %sollang.text %v118120_ptr, i64 4, 1
  store %sollang.text %v118120, ptr %deferred_text118120_value_slot, align 8
  store i64 118120, ptr %deferred_text118116_tag, align 8
  store %sollang.text poison, ptr %if118116_result, align 8
  br label %if118116_merge
if118116_merge:
  %v118116 = load %sollang.text, ptr %if118116_result, align 8
  %deferred_console118112_tag = load i64, ptr %deferred_text118116_tag, align 8
  %deferred_console118112_is118118 = icmp eq i64 %deferred_console118112_tag, 118118
  br i1 %deferred_console118112_is118118, label %deferred_console118112_leaf118118, label %deferred_console118112_next118118
deferred_console118112_leaf118118:
  %deferred_console118112_leaf118118_literal0 = getelementptr i8, ptr @sollang_str_118118, i64 0
  call void @sollang_runtime_print(ptr %deferred_console118112_leaf118118_literal0, i64 8, i1 false)
  %deferred_console118112_leaf118118_root0_value = load i1, ptr %deferred_text118118_root0_slot, align 1
  call void @sollang_runtime_print_i1(i1 %deferred_console118112_leaf118118_root0_value, i1 false)
  %deferred_console118112_leaf118118_suffix = getelementptr i8, ptr @sollang_str_118118, i64 34
  call void @sollang_runtime_print(ptr %deferred_console118112_leaf118118_suffix, i64 0, i1 true)
  br label %deferred_console118112_end
deferred_console118112_next118118:
  %deferred_console118112_is118120 = icmp eq i64 %deferred_console118112_tag, 118120
  br i1 %deferred_console118112_is118120, label %deferred_console118112_leaf118120, label %deferred_console118112_next118120
deferred_console118112_leaf118120:
  %deferred_console118112_leaf118120_value = load %sollang.text, ptr %deferred_text118120_value_slot, align 8
  %deferred_console118112_leaf118120_ptr = extractvalue %sollang.text %deferred_console118112_leaf118120_value, 0
  %deferred_console118112_leaf118120_len = extractvalue %sollang.text %deferred_console118112_leaf118120_value, 1
  call void @sollang_runtime_print(ptr %deferred_console118112_leaf118120_ptr, i64 %deferred_console118112_leaf118120_len, i1 true)
  br label %deferred_console118112_end
deferred_console118112_next118120:
  call void @llvm.trap()
  unreachable
deferred_console118112_end:
  %v118122 = icmp sgt i32 %v118123, 0
  br i1 %v118122, label %if118125_then, label %if118125_else
if118125_then:
  %v118127_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118127, 0
  %v118127 = insertvalue %sollang.text %v118127_ptr, i64 23, 1
  store %sollang.bounded_dictionary.t1247 %v118105, ptr %v118127_expression7_owner, align 8
  %v118127_expression7_storage = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %v118127_expression7_owner, i32 0, i32 1, i32 0
  %v118127_expression7_query = freeze i32 1
  %v118127_expression7_find_hash_key = sext i32 %v118127_expression7_query to i64
  %v118127_expression7_find_hash_high = lshr i64 %v118127_expression7_find_hash_key, 32
  %v118127_expression7_find_hash_fold = xor i64 %v118127_expression7_find_hash_key, %v118127_expression7_find_hash_high
  %v118127_expression7_find_hash = mul i64 %v118127_expression7_find_hash_fold, -7046029254386353131
  %v118127_expression7_find_h2_shifted = lshr i64 %v118127_expression7_find_hash, 57
  %v118127_expression7_find_h2_raw = and i64 %v118127_expression7_find_h2_shifted, 127
  %v118127_expression7_find_h2_zero = icmp eq i64 %v118127_expression7_find_h2_raw, 0
  %v118127_expression7_find_h2_value = select i1 %v118127_expression7_find_h2_zero, i64 1, i64 %v118127_expression7_find_h2_raw
  %v118127_expression7_find_h2 = trunc i64 %v118127_expression7_find_h2_value to i8
  %v118127_expression7_find_probe_keys = getelementptr i8, ptr %v118127_expression7_storage, i64 32
  %v118127_expression7_find_group_mask = sub i64 16, 1
  %v118127_expression7_find_group_start = and i64 %v118127_expression7_find_hash, %v118127_expression7_find_group_mask
  br label %v118127_expression7_find_group_first
v118127_expression7_find_group_first:
  %v118127_expression7_find_group_control_ptr = getelementptr i8, ptr %v118127_expression7_storage, i64 %v118127_expression7_find_group_start
  %v118127_expression7_find_group_control = load i8, ptr %v118127_expression7_find_group_control_ptr, align 1
  %v118127_expression7_find_group_empty = icmp eq i8 %v118127_expression7_find_group_control, 0
  br i1 %v118127_expression7_find_group_empty, label %v118127_expression7_find_group_vacant, label %v118127_expression7_find_group_occupied
v118127_expression7_find_group_occupied:
  %v118127_expression7_find_group_h2_match = icmp eq i8 %v118127_expression7_find_group_control, %v118127_expression7_find_h2
  br i1 %v118127_expression7_find_group_h2_match, label %v118127_expression7_find_group_compare, label %v118127_expression7_find_group_fallback
v118127_expression7_find_group_compare:
  %v118127_expression7_find_group_key_ptr = getelementptr [8 x i8], ptr %v118127_expression7_find_probe_keys, i64 %v118127_expression7_find_group_start
  %v118127_expression7_find_group_key = load i32, ptr %v118127_expression7_find_group_key_ptr, align 4
  %v118127_expression7_find_group_equal = icmp eq i32 %v118127_expression7_find_group_key, %v118127_expression7_query
  br i1 %v118127_expression7_find_group_equal, label %v118127_expression7_find_group_match, label %v118127_expression7_find_group_fallback
v118127_expression7_find_group_match:
  br label %v118127_expression7_find_group_done
v118127_expression7_find_group_vacant:
  br label %v118127_expression7_find_group_done
v118127_expression7_find_group_fallback:
  %v118127_expression7_find_group_grouped_mask = sub i64 16, 1
  %v118127_expression7_find_group_grouped_start = and i64 %v118127_expression7_find_hash, %v118127_expression7_find_group_grouped_mask
  br label %v118127_expression7_find_group_grouped_entry
v118127_expression7_find_group_grouped_entry:
  br label %v118127_expression7_find_group_grouped_group
v118127_expression7_find_group_grouped_group:
  %v118127_expression7_find_group_grouped_probe = phi i64 [ 0, %v118127_expression7_find_group_grouped_entry ], [ %v118127_expression7_find_group_grouped_next_probe, %v118127_expression7_find_group_grouped_next_group ]
  %v118127_expression7_find_group_grouped_active = icmp ult i64 %v118127_expression7_find_group_grouped_probe, 16
  br i1 %v118127_expression7_find_group_grouped_active, label %v118127_expression7_find_group_grouped_body, label %v118127_expression7_find_group_grouped_miss
v118127_expression7_find_group_grouped_body:
  %v118127_expression7_find_group_grouped_unwrapped = add i64 %v118127_expression7_find_group_grouped_start, %v118127_expression7_find_group_grouped_probe
  %v118127_expression7_find_group_grouped_group_start = and i64 %v118127_expression7_find_group_grouped_unwrapped, %v118127_expression7_find_group_grouped_mask
  %v118127_expression7_find_group_grouped_control_ptr = getelementptr i8, ptr %v118127_expression7_storage, i64 %v118127_expression7_find_group_grouped_group_start
  %v118127_expression7_find_group_grouped_controls = load <16 x i8>, ptr %v118127_expression7_find_group_grouped_control_ptr, align 1
  %v118127_expression7_find_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %v118127_expression7_find_h2, i64 0
  %v118127_expression7_find_group_grouped_h2_vector = shufflevector <16 x i8> %v118127_expression7_find_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %v118127_expression7_find_group_grouped_matches = icmp eq <16 x i8> %v118127_expression7_find_group_grouped_controls, %v118127_expression7_find_group_grouped_h2_vector
  %v118127_expression7_find_group_grouped_match_bits = bitcast <16 x i1> %v118127_expression7_find_group_grouped_matches to i16
  %v118127_expression7_find_group_grouped_empties = icmp eq <16 x i8> %v118127_expression7_find_group_grouped_controls, zeroinitializer
  %v118127_expression7_find_group_grouped_empty_bits = bitcast <16 x i1> %v118127_expression7_find_group_grouped_empties to i16
  br label %v118127_expression7_find_group_grouped_candidates
v118127_expression7_find_group_grouped_candidates:
  %v118127_expression7_find_group_grouped_candidate_bits = phi i16 [ %v118127_expression7_find_group_grouped_match_bits, %v118127_expression7_find_group_grouped_body ], [ %v118127_expression7_find_group_grouped_cleared_bits, %v118127_expression7_find_group_grouped_candidate_next ]
  %v118127_expression7_find_group_grouped_has_candidate = icmp ne i16 %v118127_expression7_find_group_grouped_candidate_bits, 0
  br i1 %v118127_expression7_find_group_grouped_has_candidate, label %v118127_expression7_find_group_grouped_candidate, label %v118127_expression7_find_group_grouped_decision
v118127_expression7_find_group_grouped_candidate:
  %v118127_expression7_find_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %v118127_expression7_find_group_grouped_candidate_bits, i1 false)
  %v118127_expression7_find_group_grouped_candidate_offset = zext i16 %v118127_expression7_find_group_grouped_candidate_offset16 to i64
  %v118127_expression7_find_group_grouped_candidate_unwrapped = add i64 %v118127_expression7_find_group_grouped_group_start, %v118127_expression7_find_group_grouped_candidate_offset
  %v118127_expression7_find_group_grouped_candidate_slot = and i64 %v118127_expression7_find_group_grouped_candidate_unwrapped, %v118127_expression7_find_group_grouped_mask
  %v118127_expression7_find_group_grouped_key_ptr = getelementptr [8 x i8], ptr %v118127_expression7_find_probe_keys, i64 %v118127_expression7_find_group_grouped_candidate_slot
  %v118127_expression7_find_group_grouped_key = load i32, ptr %v118127_expression7_find_group_grouped_key_ptr, align 4
  %v118127_expression7_find_group_grouped_candidate_equal = icmp eq i32 %v118127_expression7_find_group_grouped_key, %v118127_expression7_query
  br i1 %v118127_expression7_find_group_grouped_candidate_equal, label %v118127_expression7_find_group_grouped_match, label %v118127_expression7_find_group_grouped_candidate_next
v118127_expression7_find_group_grouped_candidate_next:
  %v118127_expression7_find_group_grouped_bits_minus_one = sub i16 %v118127_expression7_find_group_grouped_candidate_bits, 1
  %v118127_expression7_find_group_grouped_cleared_bits = and i16 %v118127_expression7_find_group_grouped_candidate_bits, %v118127_expression7_find_group_grouped_bits_minus_one
  br label %v118127_expression7_find_group_grouped_candidates
v118127_expression7_find_group_grouped_decision:
  %v118127_expression7_find_group_grouped_has_empty = icmp ne i16 %v118127_expression7_find_group_grouped_empty_bits, 0
  br i1 %v118127_expression7_find_group_grouped_has_empty, label %v118127_expression7_find_group_grouped_miss, label %v118127_expression7_find_group_grouped_next_group
v118127_expression7_find_group_grouped_match:
  br label %v118127_expression7_find_group_grouped_done
v118127_expression7_find_group_grouped_next_group:
  %v118127_expression7_find_group_grouped_next_probe = add i64 %v118127_expression7_find_group_grouped_probe, 16
  br label %v118127_expression7_find_group_grouped_group
v118127_expression7_find_group_grouped_miss:
  br label %v118127_expression7_find_group_grouped_done
v118127_expression7_find_group_grouped_done:
  %v118127_expression7_find_group_grouped_found = phi i1 [ true, %v118127_expression7_find_group_grouped_match ], [ false, %v118127_expression7_find_group_grouped_miss ]
  %v118127_expression7_find_group_grouped_slot = phi i64 [ %v118127_expression7_find_group_grouped_candidate_slot, %v118127_expression7_find_group_grouped_match ], [ 0, %v118127_expression7_find_group_grouped_miss ]
  br label %v118127_expression7_find_group_done
v118127_expression7_find_group_done:
  %v118127_expression7_find_group_found = phi i1 [ true, %v118127_expression7_find_group_match ], [ false, %v118127_expression7_find_group_vacant ], [ %v118127_expression7_find_group_grouped_found, %v118127_expression7_find_group_grouped_done ]
  %v118127_expression7_find_group_slot = phi i64 [ %v118127_expression7_find_group_start, %v118127_expression7_find_group_match ], [ 0, %v118127_expression7_find_group_vacant ], [ %v118127_expression7_find_group_grouped_slot, %v118127_expression7_find_group_grouped_done ]
  %v118127_expression7_find_slot = add i64 %v118127_expression7_find_group_slot, 0
  %v118127_expression7_find_exists = or i1 %v118127_expression7_find_group_found, false
  br i1 %v118127_expression7_find_exists, label %v118127_expression7_find_found, label %v118127_expression7_find_missing
v118127_expression7_find_missing:
  call void @llvm.trap()
  unreachable
v118127_expression7_find_found:
  %v118127_expression7_value_entry_offset = mul i64 %v118127_expression7_find_slot, 8
  %v118127_expression7_value_entries_field_offset = add i64 32, 4
  %v118127_expression7_value_field_offset = add i64 %v118127_expression7_value_entry_offset, %v118127_expression7_value_entries_field_offset
  %v118127_expression7_value_ptr = getelementptr i8, ptr %v118127_expression7_storage, i64 %v118127_expression7_value_field_offset
  %v118127_expression7 = load i32, ptr %v118127_expression7_value_ptr, align 4
  store i32 %v118127_expression7, ptr %deferred_text118127_root7_slot, align 4
  store i64 118127, ptr %deferred_text118125_tag, align 8
  store %sollang.text poison, ptr %if118125_result, align 8
  br label %if118125_merge
if118125_else:
  %v118129_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118129, 0
  %v118129 = insertvalue %sollang.text %v118129_ptr, i64 4, 1
  store %sollang.text %v118129, ptr %deferred_text118129_value_slot, align 8
  store i64 118129, ptr %deferred_text118125_tag, align 8
  store %sollang.text poison, ptr %if118125_result, align 8
  br label %if118125_merge
if118125_merge:
  %v118125 = load %sollang.text, ptr %if118125_result, align 8
  %deferred_console118121_tag = load i64, ptr %deferred_text118125_tag, align 8
  %deferred_console118121_is118127 = icmp eq i64 %deferred_console118121_tag, 118127
  br i1 %deferred_console118121_is118127, label %deferred_console118121_leaf118127, label %deferred_console118121_next118127
deferred_console118121_leaf118127:
  %deferred_console118121_leaf118127_literal7 = getelementptr i8, ptr @sollang_str_118127, i64 0
  call void @sollang_runtime_print(ptr %deferred_console118121_leaf118127_literal7, i64 11, i1 false)
  %deferred_console118121_leaf118127_root7_value = load i32, ptr %deferred_text118127_root7_slot, align 4
  %deferred_console118121_leaf118127_root7_wide = sext i32 %deferred_console118121_leaf118127_root7_value to i64
  call void @sollang_runtime_print_i64(i64 %deferred_console118121_leaf118127_root7_wide, i1 true, i1 false)
  %deferred_console118121_leaf118127_suffix = getelementptr i8, ptr @sollang_str_118127, i64 23
  call void @sollang_runtime_print(ptr %deferred_console118121_leaf118127_suffix, i64 0, i1 true)
  br label %deferred_console118121_end
deferred_console118121_next118127:
  %deferred_console118121_is118129 = icmp eq i64 %deferred_console118121_tag, 118129
  br i1 %deferred_console118121_is118129, label %deferred_console118121_leaf118129, label %deferred_console118121_next118129
deferred_console118121_leaf118129:
  %deferred_console118121_leaf118129_value = load %sollang.text, ptr %deferred_text118129_value_slot, align 8
  %deferred_console118121_leaf118129_ptr = extractvalue %sollang.text %deferred_console118121_leaf118129_value, 0
  %deferred_console118121_leaf118129_len = extractvalue %sollang.text %deferred_console118121_leaf118129_value, 1
  call void @sollang_runtime_print(ptr %deferred_console118121_leaf118129_ptr, i64 %deferred_console118121_leaf118129_len, i1 true)
  br label %deferred_console118121_end
deferred_console118121_next118129:
  call void @llvm.trap()
  unreachable
deferred_console118121_end:
  br label %each118108_continue
each118108_continue:
  %each118108_current = load i64, ptr %each118108_index_slot, align 8
  %each118108_next = add i64 %each118108_current, 1
  store i64 %each118108_next, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_exit:
  call void @sollang_drop_t1247(%sollang.bounded_dictionary.t1247 %v118105)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
