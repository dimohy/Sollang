define void @sollang_m144_s0(ptr %arg) {
entry:
  %slot118106 = alloca i32, align 4
  store i32 0, ptr %slot118106, align 4
  br label %while118113_header
while118113_header:
  %while118113_v118111 = load i32, ptr %slot118106, align 4
  %while118113_v118110 = icmp slt i32 %while118113_v118111, 2
  br i1 %while118113_v118110, label %while118113_body, label %while118113_exit
while118113_body:
  %v118116_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118116, 0
  %v118116 = insertvalue %sollang.text %v118116_ptr, i64 16, 1
  %v118115_expression_literal0 = getelementptr i8, ptr @sollang_str_118116, i64 0
  call void @sollang_runtime_print(ptr %v118115_expression_literal0, i64 4, i1 false)
  %v118115_expression0_owner = freeze ptr %arg
  %v118115_expression0_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118115_expression0_owner, i32 0, i32 1, i32 0
  %v118115_expression0_query = freeze i32 1
  %v118115_expression0_find_hash_key = sext i32 %v118115_expression0_query to i64
  %v118115_expression0_find_hash_high = lshr i64 %v118115_expression0_find_hash_key, 32
  %v118115_expression0_find_hash_fold = xor i64 %v118115_expression0_find_hash_key, %v118115_expression0_find_hash_high
  %v118115_expression0_find_hash = mul i64 %v118115_expression0_find_hash_fold, -7046029254386353131
  %v118115_expression0_find_h2_shifted = lshr i64 %v118115_expression0_find_hash, 57
  %v118115_expression0_find_h2_raw = and i64 %v118115_expression0_find_h2_shifted, 127
  %v118115_expression0_find_h2_zero = icmp eq i64 %v118115_expression0_find_h2_raw, 0
  %v118115_expression0_find_h2_value = select i1 %v118115_expression0_find_h2_zero, i64 1, i64 %v118115_expression0_find_h2_raw
  %v118115_expression0_find_h2 = trunc i64 %v118115_expression0_find_h2_value to i8
  %v118115_expression0_find_probe_keys = getelementptr i8, ptr %v118115_expression0_storage, i64 32
  %v118115_expression0_find_group_mask = sub i64 16, 1
  %v118115_expression0_find_group_start = and i64 %v118115_expression0_find_hash, %v118115_expression0_find_group_mask
  br label %v118115_expression0_find_group_first
v118115_expression0_find_group_first:
  %v118115_expression0_find_group_control_ptr = getelementptr i8, ptr %v118115_expression0_storage, i64 %v118115_expression0_find_group_start
  %v118115_expression0_find_group_control = load i8, ptr %v118115_expression0_find_group_control_ptr, align 1
  %v118115_expression0_find_group_empty = icmp eq i8 %v118115_expression0_find_group_control, 0
  br i1 %v118115_expression0_find_group_empty, label %v118115_expression0_find_group_vacant, label %v118115_expression0_find_group_occupied
v118115_expression0_find_group_occupied:
  %v118115_expression0_find_group_h2_match = icmp eq i8 %v118115_expression0_find_group_control, %v118115_expression0_find_h2
  br i1 %v118115_expression0_find_group_h2_match, label %v118115_expression0_find_group_compare, label %v118115_expression0_find_group_fallback
v118115_expression0_find_group_compare:
  %v118115_expression0_find_group_key_ptr = getelementptr [8 x i8], ptr %v118115_expression0_find_probe_keys, i64 %v118115_expression0_find_group_start
  %v118115_expression0_find_group_key = load i32, ptr %v118115_expression0_find_group_key_ptr, align 4
  %v118115_expression0_find_group_equal = icmp eq i32 %v118115_expression0_find_group_key, %v118115_expression0_query
  br i1 %v118115_expression0_find_group_equal, label %v118115_expression0_find_group_match, label %v118115_expression0_find_group_fallback
v118115_expression0_find_group_match:
  br label %v118115_expression0_find_group_done
v118115_expression0_find_group_vacant:
  br label %v118115_expression0_find_group_done
v118115_expression0_find_group_fallback:
  %v118115_expression0_find_group_grouped_mask = sub i64 16, 1
  %v118115_expression0_find_group_grouped_start = and i64 %v118115_expression0_find_hash, %v118115_expression0_find_group_grouped_mask
  br label %v118115_expression0_find_group_grouped_entry
v118115_expression0_find_group_grouped_entry:
  br label %v118115_expression0_find_group_grouped_group
v118115_expression0_find_group_grouped_group:
  %v118115_expression0_find_group_grouped_probe = phi i64 [ 0, %v118115_expression0_find_group_grouped_entry ], [ %v118115_expression0_find_group_grouped_next_probe, %v118115_expression0_find_group_grouped_next_group ]
  %v118115_expression0_find_group_grouped_active = icmp ult i64 %v118115_expression0_find_group_grouped_probe, 16
  br i1 %v118115_expression0_find_group_grouped_active, label %v118115_expression0_find_group_grouped_body, label %v118115_expression0_find_group_grouped_miss
v118115_expression0_find_group_grouped_body:
  %v118115_expression0_find_group_grouped_unwrapped = add i64 %v118115_expression0_find_group_grouped_start, %v118115_expression0_find_group_grouped_probe
  %v118115_expression0_find_group_grouped_group_start = and i64 %v118115_expression0_find_group_grouped_unwrapped, %v118115_expression0_find_group_grouped_mask
  %v118115_expression0_find_group_grouped_control_ptr = getelementptr i8, ptr %v118115_expression0_storage, i64 %v118115_expression0_find_group_grouped_group_start
  %v118115_expression0_find_group_grouped_controls = load <16 x i8>, ptr %v118115_expression0_find_group_grouped_control_ptr, align 1
  %v118115_expression0_find_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %v118115_expression0_find_h2, i64 0
  %v118115_expression0_find_group_grouped_h2_vector = shufflevector <16 x i8> %v118115_expression0_find_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %v118115_expression0_find_group_grouped_matches = icmp eq <16 x i8> %v118115_expression0_find_group_grouped_controls, %v118115_expression0_find_group_grouped_h2_vector
  %v118115_expression0_find_group_grouped_match_bits = bitcast <16 x i1> %v118115_expression0_find_group_grouped_matches to i16
  %v118115_expression0_find_group_grouped_empties = icmp eq <16 x i8> %v118115_expression0_find_group_grouped_controls, zeroinitializer
  %v118115_expression0_find_group_grouped_empty_bits = bitcast <16 x i1> %v118115_expression0_find_group_grouped_empties to i16
  br label %v118115_expression0_find_group_grouped_candidates
v118115_expression0_find_group_grouped_candidates:
  %v118115_expression0_find_group_grouped_candidate_bits = phi i16 [ %v118115_expression0_find_group_grouped_match_bits, %v118115_expression0_find_group_grouped_body ], [ %v118115_expression0_find_group_grouped_cleared_bits, %v118115_expression0_find_group_grouped_candidate_next ]
  %v118115_expression0_find_group_grouped_has_candidate = icmp ne i16 %v118115_expression0_find_group_grouped_candidate_bits, 0
  br i1 %v118115_expression0_find_group_grouped_has_candidate, label %v118115_expression0_find_group_grouped_candidate, label %v118115_expression0_find_group_grouped_decision
v118115_expression0_find_group_grouped_candidate:
  %v118115_expression0_find_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %v118115_expression0_find_group_grouped_candidate_bits, i1 false)
  %v118115_expression0_find_group_grouped_candidate_offset = zext i16 %v118115_expression0_find_group_grouped_candidate_offset16 to i64
  %v118115_expression0_find_group_grouped_candidate_unwrapped = add i64 %v118115_expression0_find_group_grouped_group_start, %v118115_expression0_find_group_grouped_candidate_offset
  %v118115_expression0_find_group_grouped_candidate_slot = and i64 %v118115_expression0_find_group_grouped_candidate_unwrapped, %v118115_expression0_find_group_grouped_mask
  %v118115_expression0_find_group_grouped_key_ptr = getelementptr [8 x i8], ptr %v118115_expression0_find_probe_keys, i64 %v118115_expression0_find_group_grouped_candidate_slot
  %v118115_expression0_find_group_grouped_key = load i32, ptr %v118115_expression0_find_group_grouped_key_ptr, align 4
  %v118115_expression0_find_group_grouped_candidate_equal = icmp eq i32 %v118115_expression0_find_group_grouped_key, %v118115_expression0_query
  br i1 %v118115_expression0_find_group_grouped_candidate_equal, label %v118115_expression0_find_group_grouped_match, label %v118115_expression0_find_group_grouped_candidate_next
v118115_expression0_find_group_grouped_candidate_next:
  %v118115_expression0_find_group_grouped_bits_minus_one = sub i16 %v118115_expression0_find_group_grouped_candidate_bits, 1
  %v118115_expression0_find_group_grouped_cleared_bits = and i16 %v118115_expression0_find_group_grouped_candidate_bits, %v118115_expression0_find_group_grouped_bits_minus_one
  br label %v118115_expression0_find_group_grouped_candidates
v118115_expression0_find_group_grouped_decision:
  %v118115_expression0_find_group_grouped_has_empty = icmp ne i16 %v118115_expression0_find_group_grouped_empty_bits, 0
  br i1 %v118115_expression0_find_group_grouped_has_empty, label %v118115_expression0_find_group_grouped_miss, label %v118115_expression0_find_group_grouped_next_group
v118115_expression0_find_group_grouped_match:
  br label %v118115_expression0_find_group_grouped_done
v118115_expression0_find_group_grouped_next_group:
  %v118115_expression0_find_group_grouped_next_probe = add i64 %v118115_expression0_find_group_grouped_probe, 16
  br label %v118115_expression0_find_group_grouped_group
v118115_expression0_find_group_grouped_miss:
  br label %v118115_expression0_find_group_grouped_done
v118115_expression0_find_group_grouped_done:
  %v118115_expression0_find_group_grouped_found = phi i1 [ true, %v118115_expression0_find_group_grouped_match ], [ false, %v118115_expression0_find_group_grouped_miss ]
  %v118115_expression0_find_group_grouped_slot = phi i64 [ %v118115_expression0_find_group_grouped_candidate_slot, %v118115_expression0_find_group_grouped_match ], [ 0, %v118115_expression0_find_group_grouped_miss ]
  br label %v118115_expression0_find_group_done
v118115_expression0_find_group_done:
  %v118115_expression0_find_group_found = phi i1 [ true, %v118115_expression0_find_group_match ], [ false, %v118115_expression0_find_group_vacant ], [ %v118115_expression0_find_group_grouped_found, %v118115_expression0_find_group_grouped_done ]
  %v118115_expression0_find_group_slot = phi i64 [ %v118115_expression0_find_group_start, %v118115_expression0_find_group_match ], [ 0, %v118115_expression0_find_group_vacant ], [ %v118115_expression0_find_group_grouped_slot, %v118115_expression0_find_group_grouped_done ]
  %v118115_expression0_find_slot = add i64 %v118115_expression0_find_group_slot, 0
  %v118115_expression0_find_exists = or i1 %v118115_expression0_find_group_found, false
  br i1 %v118115_expression0_find_exists, label %v118115_expression0_find_found, label %v118115_expression0_find_missing
v118115_expression0_find_missing:
  call void @llvm.trap()
  unreachable
v118115_expression0_find_found:
  %v118115_expression0_value_entry_offset = mul i64 %v118115_expression0_find_slot, 8
  %v118115_expression0_value_entries_field_offset = add i64 32, 4
  %v118115_expression0_value_field_offset = add i64 %v118115_expression0_value_entry_offset, %v118115_expression0_value_entries_field_offset
  %v118115_expression0_value_ptr = getelementptr i8, ptr %v118115_expression0_storage, i64 %v118115_expression0_value_field_offset
  %v118115_expression0 = load i32, ptr %v118115_expression0_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118115_expression0, i1 false)
  %v118115_expression_suffix = getelementptr i8, ptr @sollang_str_118116, i64 16
  call void @sollang_runtime_print(ptr %v118115_expression_suffix, i64 0, i1 true)
  %v118118 = load i32, ptr %slot118106, align 4
  %v118117 = add i32 %v118118, 1
  store i32 %v118117, ptr %slot118106, align 4
  br label %while118113_header
while118113_exit:
  ret void
}

define i32 @main() {
entry:
  %callref118139_arg0 = alloca %sollang.bounded_dictionary.t1212, align 8
  %slot118122 = alloca i32, align 4
  %v118124_owner = alloca %sollang.bounded_dictionary.t1212, align 8
  store %sollang.bounded_dictionary.t1212 zeroinitializer, ptr %v118124_owner, align 8
  %v118124_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118124_owner, i32 0, i32 1, i32 0
  %bd118124_0_key_operand = add i32 0, 1
  %bd118124_0_value_operand = add i32 0, 10
  %bd118124_0_hash_key = sext i32 %bd118124_0_key_operand to i64
  %bd118124_0_hash_high = lshr i64 %bd118124_0_hash_key, 32
  %bd118124_0_hash_fold = xor i64 %bd118124_0_hash_key, %bd118124_0_hash_high
  %bd118124_0_hash = mul i64 %bd118124_0_hash_fold, -7046029254386353131
  %bd118124_0_h2_shifted = lshr i64 %bd118124_0_hash, 57
  %bd118124_0_h2_raw = and i64 %bd118124_0_h2_shifted, 127
  %bd118124_0_h2_zero = icmp eq i64 %bd118124_0_h2_raw, 0
  %bd118124_0_h2_value = select i1 %bd118124_0_h2_zero, i64 1, i64 %bd118124_0_h2_raw
  %bd118124_0_h2 = trunc i64 %bd118124_0_h2_value to i8
  %bd118124_0_probe_keys = getelementptr i8, ptr %v118124_storage, i64 32
  %bd118124_0_group_mask = sub i64 16, 1
  %bd118124_0_group_start = and i64 %bd118124_0_hash, %bd118124_0_group_mask
  %bd118124_0_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bd118124_0_group_has_capacity, label %bd118124_0_group_first, label %bd118124_0_group_no_capacity
bd118124_0_group_no_capacity:
  br label %bd118124_0_group_done
bd118124_0_group_first:
  %bd118124_0_group_control_ptr = getelementptr i8, ptr %v118124_storage, i64 %bd118124_0_group_start
  %bd118124_0_group_control = load i8, ptr %bd118124_0_group_control_ptr, align 1
  %bd118124_0_group_empty = icmp eq i8 %bd118124_0_group_control, 0
  br i1 %bd118124_0_group_empty, label %bd118124_0_group_vacant, label %bd118124_0_group_occupied
bd118124_0_group_occupied:
  %bd118124_0_group_h2_match = icmp eq i8 %bd118124_0_group_control, %bd118124_0_h2
  br i1 %bd118124_0_group_h2_match, label %bd118124_0_group_compare, label %bd118124_0_group_fallback
bd118124_0_group_compare:
  %bd118124_0_group_key_ptr = getelementptr [8 x i8], ptr %bd118124_0_probe_keys, i64 %bd118124_0_group_start
  %bd118124_0_group_key = load i32, ptr %bd118124_0_group_key_ptr, align 4
  %bd118124_0_group_equal = icmp eq i32 %bd118124_0_group_key, %bd118124_0_key_operand
  br i1 %bd118124_0_group_equal, label %bd118124_0_group_match, label %bd118124_0_group_fallback
bd118124_0_group_match:
  br label %bd118124_0_group_done
bd118124_0_group_vacant:
  br label %bd118124_0_group_done
bd118124_0_group_fallback:
  %bd118124_0_group_grouped_mask = sub i64 16, 1
  %bd118124_0_group_grouped_start = and i64 %bd118124_0_hash, %bd118124_0_group_grouped_mask
  br label %bd118124_0_group_grouped_entry
bd118124_0_group_grouped_entry:
  br label %bd118124_0_group_grouped_group
bd118124_0_group_grouped_group:
  %bd118124_0_group_grouped_probe = phi i64 [ 0, %bd118124_0_group_grouped_entry ], [ %bd118124_0_group_grouped_next_probe, %bd118124_0_group_grouped_next_group ]
  %bd118124_0_group_grouped_first_deleted = phi i64 [ 16, %bd118124_0_group_grouped_entry ], [ %bd118124_0_group_grouped_next_deleted, %bd118124_0_group_grouped_next_group ]
  %bd118124_0_group_grouped_active = icmp ult i64 %bd118124_0_group_grouped_probe, 16
  br i1 %bd118124_0_group_grouped_active, label %bd118124_0_group_grouped_body, label %bd118124_0_group_grouped_miss
bd118124_0_group_grouped_body:
  %bd118124_0_group_grouped_unwrapped = add i64 %bd118124_0_group_grouped_start, %bd118124_0_group_grouped_probe
  %bd118124_0_group_grouped_group_start = and i64 %bd118124_0_group_grouped_unwrapped, %bd118124_0_group_grouped_mask
  %bd118124_0_group_grouped_control_ptr = getelementptr i8, ptr %v118124_storage, i64 %bd118124_0_group_grouped_group_start
  %bd118124_0_group_grouped_controls = load <16 x i8>, ptr %bd118124_0_group_grouped_control_ptr, align 1
  %bd118124_0_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bd118124_0_h2, i64 0
  %bd118124_0_group_grouped_h2_vector = shufflevector <16 x i8> %bd118124_0_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118124_0_group_grouped_matches = icmp eq <16 x i8> %bd118124_0_group_grouped_controls, %bd118124_0_group_grouped_h2_vector
  %bd118124_0_group_grouped_match_bits = bitcast <16 x i1> %bd118124_0_group_grouped_matches to i16
  %bd118124_0_group_grouped_empties = icmp eq <16 x i8> %bd118124_0_group_grouped_controls, zeroinitializer
  %bd118124_0_group_grouped_empty_bits = bitcast <16 x i1> %bd118124_0_group_grouped_empties to i16
  %bd118124_0_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bd118124_0_group_grouped_deleted_vector = shufflevector <16 x i8> %bd118124_0_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118124_0_group_grouped_deleted_matches = icmp eq <16 x i8> %bd118124_0_group_grouped_controls, %bd118124_0_group_grouped_deleted_vector
  %bd118124_0_group_grouped_deleted_bits = bitcast <16 x i1> %bd118124_0_group_grouped_deleted_matches to i16
  %bd118124_0_group_grouped_has_deleted = icmp ne i16 %bd118124_0_group_grouped_deleted_bits, 0
  %bd118124_0_group_grouped_no_previous_deleted = icmp eq i64 %bd118124_0_group_grouped_first_deleted, 16
  %bd118124_0_group_grouped_capture_deleted = and i1 %bd118124_0_group_grouped_has_deleted, %bd118124_0_group_grouped_no_previous_deleted
  %bd118124_0_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bd118124_0_group_grouped_deleted_bits, i1 false)
  %bd118124_0_group_grouped_deleted_offset = zext i16 %bd118124_0_group_grouped_deleted_offset16 to i64
  %bd118124_0_group_grouped_deleted_unwrapped = add i64 %bd118124_0_group_grouped_group_start, %bd118124_0_group_grouped_deleted_offset
  %bd118124_0_group_grouped_deleted_slot = and i64 %bd118124_0_group_grouped_deleted_unwrapped, %bd118124_0_group_grouped_mask
  %bd118124_0_group_grouped_captured_deleted = select i1 %bd118124_0_group_grouped_capture_deleted, i64 %bd118124_0_group_grouped_deleted_slot, i64 %bd118124_0_group_grouped_first_deleted
  br label %bd118124_0_group_grouped_candidates
bd118124_0_group_grouped_candidates:
  %bd118124_0_group_grouped_candidate_bits = phi i16 [ %bd118124_0_group_grouped_match_bits, %bd118124_0_group_grouped_body ], [ %bd118124_0_group_grouped_cleared_bits, %bd118124_0_group_grouped_candidate_next ]
  %bd118124_0_group_grouped_has_candidate = icmp ne i16 %bd118124_0_group_grouped_candidate_bits, 0
  br i1 %bd118124_0_group_grouped_has_candidate, label %bd118124_0_group_grouped_candidate, label %bd118124_0_group_grouped_decision
bd118124_0_group_grouped_candidate:
  %bd118124_0_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bd118124_0_group_grouped_candidate_bits, i1 false)
  %bd118124_0_group_grouped_candidate_offset = zext i16 %bd118124_0_group_grouped_candidate_offset16 to i64
  %bd118124_0_group_grouped_candidate_unwrapped = add i64 %bd118124_0_group_grouped_group_start, %bd118124_0_group_grouped_candidate_offset
  %bd118124_0_group_grouped_candidate_slot = and i64 %bd118124_0_group_grouped_candidate_unwrapped, %bd118124_0_group_grouped_mask
  %bd118124_0_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bd118124_0_probe_keys, i64 %bd118124_0_group_grouped_candidate_slot
  %bd118124_0_group_grouped_key = load i32, ptr %bd118124_0_group_grouped_key_ptr, align 4
  %bd118124_0_group_grouped_candidate_equal = icmp eq i32 %bd118124_0_group_grouped_key, %bd118124_0_key_operand
  br i1 %bd118124_0_group_grouped_candidate_equal, label %bd118124_0_group_grouped_match, label %bd118124_0_group_grouped_candidate_next
bd118124_0_group_grouped_candidate_next:
  %bd118124_0_group_grouped_bits_minus_one = sub i16 %bd118124_0_group_grouped_candidate_bits, 1
  %bd118124_0_group_grouped_cleared_bits = and i16 %bd118124_0_group_grouped_candidate_bits, %bd118124_0_group_grouped_bits_minus_one
  br label %bd118124_0_group_grouped_candidates
bd118124_0_group_grouped_decision:
  %bd118124_0_group_grouped_has_empty = icmp ne i16 %bd118124_0_group_grouped_empty_bits, 0
  br i1 %bd118124_0_group_grouped_has_empty, label %bd118124_0_group_grouped_empty, label %bd118124_0_group_grouped_next_group
bd118124_0_group_grouped_empty:
  %bd118124_0_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bd118124_0_group_grouped_empty_bits, i1 false)
  %bd118124_0_group_grouped_empty_offset = zext i16 %bd118124_0_group_grouped_empty_offset16 to i64
  %bd118124_0_group_grouped_empty_unwrapped = add i64 %bd118124_0_group_grouped_group_start, %bd118124_0_group_grouped_empty_offset
  %bd118124_0_group_grouped_empty_slot = and i64 %bd118124_0_group_grouped_empty_unwrapped, %bd118124_0_group_grouped_mask
  %bd118124_0_group_grouped_use_empty = icmp eq i64 %bd118124_0_group_grouped_captured_deleted, 16
  %bd118124_0_group_grouped_insertion_slot = select i1 %bd118124_0_group_grouped_use_empty, i64 %bd118124_0_group_grouped_empty_slot, i64 %bd118124_0_group_grouped_captured_deleted
  br label %bd118124_0_group_grouped_done
bd118124_0_group_grouped_match:
  br label %bd118124_0_group_grouped_done
bd118124_0_group_grouped_next_group:
  %bd118124_0_group_grouped_next_probe = add i64 %bd118124_0_group_grouped_probe, 16
  %bd118124_0_group_grouped_next_deleted = add i64 %bd118124_0_group_grouped_captured_deleted, 0
  br label %bd118124_0_group_grouped_group
bd118124_0_group_grouped_miss:
  %bd118124_0_group_grouped_no_deleted = icmp eq i64 %bd118124_0_group_grouped_first_deleted, 16
  %bd118124_0_group_grouped_miss_slot = select i1 %bd118124_0_group_grouped_no_deleted, i64 0, i64 %bd118124_0_group_grouped_first_deleted
  br label %bd118124_0_group_grouped_done
bd118124_0_group_grouped_done:
  %bd118124_0_group_grouped_found = phi i1 [ false, %bd118124_0_group_grouped_empty ], [ true, %bd118124_0_group_grouped_match ], [ false, %bd118124_0_group_grouped_miss ]
  %bd118124_0_group_grouped_slot = phi i64 [ %bd118124_0_group_grouped_insertion_slot, %bd118124_0_group_grouped_empty ], [ %bd118124_0_group_grouped_candidate_slot, %bd118124_0_group_grouped_match ], [ %bd118124_0_group_grouped_miss_slot, %bd118124_0_group_grouped_miss ]
  br label %bd118124_0_group_done
bd118124_0_group_done:
  %bd118124_0_group_found = phi i1 [ true, %bd118124_0_group_match ], [ false, %bd118124_0_group_vacant ], [ %bd118124_0_group_grouped_found, %bd118124_0_group_grouped_done ], [ false, %bd118124_0_group_no_capacity ]
  %bd118124_0_group_slot = phi i64 [ %bd118124_0_group_start, %bd118124_0_group_match ], [ %bd118124_0_group_start, %bd118124_0_group_vacant ], [ %bd118124_0_group_grouped_slot, %bd118124_0_group_grouped_done ], [ 0, %bd118124_0_group_no_capacity ]
  %bd118124_0_slot = add i64 %bd118124_0_group_slot, 0
  %bd118124_0_exists = or i1 %bd118124_0_group_found, false
  br label %bd118124_0_insert
bd118124_0_insert:
  %bd118124_0_key_entry_offset = mul i64 %bd118124_0_slot, 8
  %bd118124_0_key_entries_field_offset = add i64 32, 0
  %bd118124_0_key_field_offset = add i64 %bd118124_0_key_entry_offset, %bd118124_0_key_entries_field_offset
  %bd118124_0_key_ptr = getelementptr i8, ptr %v118124_storage, i64 %bd118124_0_key_field_offset
  store i32 %bd118124_0_key_operand, ptr %bd118124_0_key_ptr, align 4
  %bd118124_0_value_entry_offset = mul i64 %bd118124_0_slot, 8
  %bd118124_0_value_entries_field_offset = add i64 32, 4
  %bd118124_0_value_field_offset = add i64 %bd118124_0_value_entry_offset, %bd118124_0_value_entries_field_offset
  %bd118124_0_value_ptr = getelementptr i8, ptr %v118124_storage, i64 %bd118124_0_value_field_offset
  store i32 %bd118124_0_value_operand, ptr %bd118124_0_value_ptr, align 4
  %bd118124_0_control_control_ptr = getelementptr i8, ptr %v118124_storage, i64 %bd118124_0_slot
  store i8 %bd118124_0_h2, ptr %bd118124_0_control_control_ptr, align 1
  %bd118124_0_control_mirror_needed = icmp ult i64 %bd118124_0_slot, 16
  %bd118124_0_control_mirror_candidate = add i64 %bd118124_0_slot, 16
  %bd118124_0_control_mirror_slot = select i1 %bd118124_0_control_mirror_needed, i64 %bd118124_0_control_mirror_candidate, i64 %bd118124_0_slot
  %bd118124_0_control_mirror_ptr = getelementptr i8, ptr %v118124_storage, i64 %bd118124_0_control_mirror_slot
  store i8 %bd118124_0_h2, ptr %bd118124_0_control_mirror_ptr, align 1
  %v118124_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118124_owner, i32 0, i32 0
  store i64 1, ptr %v118124_length_ptr, align 8
  %v118124 = load %sollang.bounded_dictionary.t1212, ptr %v118124_owner, align 8
  store i32 0, ptr %slot118122, align 4
  br label %while118132_header
while118132_header:
  %while118132_v118130 = load i32, ptr %slot118122, align 4
  %while118132_v118129 = icmp slt i32 %while118132_v118130, 2
  br i1 %while118132_v118129, label %while118132_body, label %while118132_exit
while118132_body:
  %v118135_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118135, 0
  %v118135 = insertvalue %sollang.text %v118135_ptr, i64 18, 1
  %v118134_expression_literal0 = getelementptr i8, ptr @sollang_str_118135, i64 0
  call void @sollang_runtime_print(ptr %v118134_expression_literal0, i64 6, i1 false)
  %v118134_expression3_owner = alloca %sollang.bounded_dictionary.t1212, align 8
  store %sollang.bounded_dictionary.t1212 %v118124, ptr %v118134_expression3_owner, align 8
  %v118134_expression3_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118134_expression3_owner, i32 0, i32 1, i32 0
  %v118134_expression3_query = freeze i32 1
  %v118134_expression3_find_hash_key = sext i32 %v118134_expression3_query to i64
  %v118134_expression3_find_hash_high = lshr i64 %v118134_expression3_find_hash_key, 32
  %v118134_expression3_find_hash_fold = xor i64 %v118134_expression3_find_hash_key, %v118134_expression3_find_hash_high
  %v118134_expression3_find_hash = mul i64 %v118134_expression3_find_hash_fold, -7046029254386353131
  %v118134_expression3_find_h2_shifted = lshr i64 %v118134_expression3_find_hash, 57
  %v118134_expression3_find_h2_raw = and i64 %v118134_expression3_find_h2_shifted, 127
  %v118134_expression3_find_h2_zero = icmp eq i64 %v118134_expression3_find_h2_raw, 0
  %v118134_expression3_find_h2_value = select i1 %v118134_expression3_find_h2_zero, i64 1, i64 %v118134_expression3_find_h2_raw
  %v118134_expression3_find_h2 = trunc i64 %v118134_expression3_find_h2_value to i8
  %v118134_expression3_find_probe_keys = getelementptr i8, ptr %v118134_expression3_storage, i64 32
  %v118134_expression3_find_group_mask = sub i64 16, 1
  %v118134_expression3_find_group_start = and i64 %v118134_expression3_find_hash, %v118134_expression3_find_group_mask
  br label %v118134_expression3_find_group_first
v118134_expression3_find_group_first:
  %v118134_expression3_find_group_control_ptr = getelementptr i8, ptr %v118134_expression3_storage, i64 %v118134_expression3_find_group_start
  %v118134_expression3_find_group_control = load i8, ptr %v118134_expression3_find_group_control_ptr, align 1
  %v118134_expression3_find_group_empty = icmp eq i8 %v118134_expression3_find_group_control, 0
  br i1 %v118134_expression3_find_group_empty, label %v118134_expression3_find_group_vacant, label %v118134_expression3_find_group_occupied
v118134_expression3_find_group_occupied:
  %v118134_expression3_find_group_h2_match = icmp eq i8 %v118134_expression3_find_group_control, %v118134_expression3_find_h2
  br i1 %v118134_expression3_find_group_h2_match, label %v118134_expression3_find_group_compare, label %v118134_expression3_find_group_fallback
v118134_expression3_find_group_compare:
  %v118134_expression3_find_group_key_ptr = getelementptr [8 x i8], ptr %v118134_expression3_find_probe_keys, i64 %v118134_expression3_find_group_start
  %v118134_expression3_find_group_key = load i32, ptr %v118134_expression3_find_group_key_ptr, align 4
  %v118134_expression3_find_group_equal = icmp eq i32 %v118134_expression3_find_group_key, %v118134_expression3_query
  br i1 %v118134_expression3_find_group_equal, label %v118134_expression3_find_group_match, label %v118134_expression3_find_group_fallback
v118134_expression3_find_group_match:
  br label %v118134_expression3_find_group_done
v118134_expression3_find_group_vacant:
  br label %v118134_expression3_find_group_done
v118134_expression3_find_group_fallback:
  %v118134_expression3_find_group_grouped_mask = sub i64 16, 1
  %v118134_expression3_find_group_grouped_start = and i64 %v118134_expression3_find_hash, %v118134_expression3_find_group_grouped_mask
  br label %v118134_expression3_find_group_grouped_entry
v118134_expression3_find_group_grouped_entry:
  br label %v118134_expression3_find_group_grouped_group
v118134_expression3_find_group_grouped_group:
  %v118134_expression3_find_group_grouped_probe = phi i64 [ 0, %v118134_expression3_find_group_grouped_entry ], [ %v118134_expression3_find_group_grouped_next_probe, %v118134_expression3_find_group_grouped_next_group ]
  %v118134_expression3_find_group_grouped_active = icmp ult i64 %v118134_expression3_find_group_grouped_probe, 16
  br i1 %v118134_expression3_find_group_grouped_active, label %v118134_expression3_find_group_grouped_body, label %v118134_expression3_find_group_grouped_miss
v118134_expression3_find_group_grouped_body:
  %v118134_expression3_find_group_grouped_unwrapped = add i64 %v118134_expression3_find_group_grouped_start, %v118134_expression3_find_group_grouped_probe
  %v118134_expression3_find_group_grouped_group_start = and i64 %v118134_expression3_find_group_grouped_unwrapped, %v118134_expression3_find_group_grouped_mask
  %v118134_expression3_find_group_grouped_control_ptr = getelementptr i8, ptr %v118134_expression3_storage, i64 %v118134_expression3_find_group_grouped_group_start
  %v118134_expression3_find_group_grouped_controls = load <16 x i8>, ptr %v118134_expression3_find_group_grouped_control_ptr, align 1
  %v118134_expression3_find_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %v118134_expression3_find_h2, i64 0
  %v118134_expression3_find_group_grouped_h2_vector = shufflevector <16 x i8> %v118134_expression3_find_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %v118134_expression3_find_group_grouped_matches = icmp eq <16 x i8> %v118134_expression3_find_group_grouped_controls, %v118134_expression3_find_group_grouped_h2_vector
  %v118134_expression3_find_group_grouped_match_bits = bitcast <16 x i1> %v118134_expression3_find_group_grouped_matches to i16
  %v118134_expression3_find_group_grouped_empties = icmp eq <16 x i8> %v118134_expression3_find_group_grouped_controls, zeroinitializer
  %v118134_expression3_find_group_grouped_empty_bits = bitcast <16 x i1> %v118134_expression3_find_group_grouped_empties to i16
  br label %v118134_expression3_find_group_grouped_candidates
v118134_expression3_find_group_grouped_candidates:
  %v118134_expression3_find_group_grouped_candidate_bits = phi i16 [ %v118134_expression3_find_group_grouped_match_bits, %v118134_expression3_find_group_grouped_body ], [ %v118134_expression3_find_group_grouped_cleared_bits, %v118134_expression3_find_group_grouped_candidate_next ]
  %v118134_expression3_find_group_grouped_has_candidate = icmp ne i16 %v118134_expression3_find_group_grouped_candidate_bits, 0
  br i1 %v118134_expression3_find_group_grouped_has_candidate, label %v118134_expression3_find_group_grouped_candidate, label %v118134_expression3_find_group_grouped_decision
v118134_expression3_find_group_grouped_candidate:
  %v118134_expression3_find_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %v118134_expression3_find_group_grouped_candidate_bits, i1 false)
  %v118134_expression3_find_group_grouped_candidate_offset = zext i16 %v118134_expression3_find_group_grouped_candidate_offset16 to i64
  %v118134_expression3_find_group_grouped_candidate_unwrapped = add i64 %v118134_expression3_find_group_grouped_group_start, %v118134_expression3_find_group_grouped_candidate_offset
  %v118134_expression3_find_group_grouped_candidate_slot = and i64 %v118134_expression3_find_group_grouped_candidate_unwrapped, %v118134_expression3_find_group_grouped_mask
  %v118134_expression3_find_group_grouped_key_ptr = getelementptr [8 x i8], ptr %v118134_expression3_find_probe_keys, i64 %v118134_expression3_find_group_grouped_candidate_slot
  %v118134_expression3_find_group_grouped_key = load i32, ptr %v118134_expression3_find_group_grouped_key_ptr, align 4
  %v118134_expression3_find_group_grouped_candidate_equal = icmp eq i32 %v118134_expression3_find_group_grouped_key, %v118134_expression3_query
  br i1 %v118134_expression3_find_group_grouped_candidate_equal, label %v118134_expression3_find_group_grouped_match, label %v118134_expression3_find_group_grouped_candidate_next
v118134_expression3_find_group_grouped_candidate_next:
  %v118134_expression3_find_group_grouped_bits_minus_one = sub i16 %v118134_expression3_find_group_grouped_candidate_bits, 1
  %v118134_expression3_find_group_grouped_cleared_bits = and i16 %v118134_expression3_find_group_grouped_candidate_bits, %v118134_expression3_find_group_grouped_bits_minus_one
  br label %v118134_expression3_find_group_grouped_candidates
v118134_expression3_find_group_grouped_decision:
  %v118134_expression3_find_group_grouped_has_empty = icmp ne i16 %v118134_expression3_find_group_grouped_empty_bits, 0
  br i1 %v118134_expression3_find_group_grouped_has_empty, label %v118134_expression3_find_group_grouped_miss, label %v118134_expression3_find_group_grouped_next_group
v118134_expression3_find_group_grouped_match:
  br label %v118134_expression3_find_group_grouped_done
v118134_expression3_find_group_grouped_next_group:
  %v118134_expression3_find_group_grouped_next_probe = add i64 %v118134_expression3_find_group_grouped_probe, 16
  br label %v118134_expression3_find_group_grouped_group
v118134_expression3_find_group_grouped_miss:
  br label %v118134_expression3_find_group_grouped_done
v118134_expression3_find_group_grouped_done:
  %v118134_expression3_find_group_grouped_found = phi i1 [ true, %v118134_expression3_find_group_grouped_match ], [ false, %v118134_expression3_find_group_grouped_miss ]
  %v118134_expression3_find_group_grouped_slot = phi i64 [ %v118134_expression3_find_group_grouped_candidate_slot, %v118134_expression3_find_group_grouped_match ], [ 0, %v118134_expression3_find_group_grouped_miss ]
  br label %v118134_expression3_find_group_done
v118134_expression3_find_group_done:
  %v118134_expression3_find_group_found = phi i1 [ true, %v118134_expression3_find_group_match ], [ false, %v118134_expression3_find_group_vacant ], [ %v118134_expression3_find_group_grouped_found, %v118134_expression3_find_group_grouped_done ]
  %v118134_expression3_find_group_slot = phi i64 [ %v118134_expression3_find_group_start, %v118134_expression3_find_group_match ], [ 0, %v118134_expression3_find_group_vacant ], [ %v118134_expression3_find_group_grouped_slot, %v118134_expression3_find_group_grouped_done ]
  %v118134_expression3_find_slot = add i64 %v118134_expression3_find_group_slot, 0
  %v118134_expression3_find_exists = or i1 %v118134_expression3_find_group_found, false
  br i1 %v118134_expression3_find_exists, label %v118134_expression3_find_found, label %v118134_expression3_find_missing
v118134_expression3_find_missing:
  call void @llvm.trap()
  unreachable
v118134_expression3_find_found:
  %v118134_expression3_value_entry_offset = mul i64 %v118134_expression3_find_slot, 8
  %v118134_expression3_value_entries_field_offset = add i64 32, 4
  %v118134_expression3_value_field_offset = add i64 %v118134_expression3_value_entry_offset, %v118134_expression3_value_entries_field_offset
  %v118134_expression3_value_ptr = getelementptr i8, ptr %v118134_expression3_storage, i64 %v118134_expression3_value_field_offset
  %v118134_expression3 = load i32, ptr %v118134_expression3_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118134_expression3, i1 false)
  %v118134_expression_suffix = getelementptr i8, ptr @sollang_str_118135, i64 18
  call void @sollang_runtime_print(ptr %v118134_expression_suffix, i64 0, i1 true)
  %v118137 = load i32, ptr %slot118122, align 4
  %v118136 = add i32 %v118137, 1
  store i32 %v118136, ptr %slot118122, align 4
  br label %while118132_header
while118132_exit:
  %v118140 = freeze %sollang.bounded_dictionary.t1212 %v118124
  store %sollang.bounded_dictionary.t1212 %v118140, ptr %callref118139_arg0, align 8
  %callref118139_arg0_address = getelementptr i8, ptr %callref118139_arg0, i64 0
  call void @sollang_m144_s0(ptr %callref118139_arg0_address)
  call void @sollang_drop_t1212(%sollang.bounded_dictionary.t1212 %v118124)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
