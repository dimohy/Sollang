define void @sollang_m144_s0() {
entry:
  %v118115_owner = alloca %sollang.bounded_dictionary.t1247, align 8
  %bidx118125_owner = alloca %sollang.bounded_dictionary.t1247, align 8
  %bidx118129_owner = alloca %sollang.bounded_dictionary.t1247, align 8
  %slot118105 = alloca i32, align 4
  store i32 0, ptr %slot118105, align 4
  br label %while118113_header
while118113_header:
  %while118113_v118111 = load i32, ptr %slot118105, align 4
  %while118113_v118110 = icmp slt i32 %while118113_v118111, 2
  br i1 %while118113_v118110, label %while118113_body, label %while118113_exit
while118113_body:
  %v118118 = load i32, ptr %slot118105, align 4
  %v118122 = load i32, ptr %slot118105, align 4
  %v118117 = add i32 %v118118, 10
  %v118121 = add i32 %v118122, 20
  store %sollang.bounded_dictionary.t1247 zeroinitializer, ptr %v118115_owner, align 8
  %v118115_storage = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %v118115_owner, i32 0, i32 1, i32 0
  %bd118115_0_key_operand = add i32 0, 1
  %bd118115_0_hash_key = sext i32 %bd118115_0_key_operand to i64
  %bd118115_0_hash_high = lshr i64 %bd118115_0_hash_key, 32
  %bd118115_0_hash_fold = xor i64 %bd118115_0_hash_key, %bd118115_0_hash_high
  %bd118115_0_hash = mul i64 %bd118115_0_hash_fold, -7046029254386353131
  %bd118115_0_h2_shifted = lshr i64 %bd118115_0_hash, 57
  %bd118115_0_h2_raw = and i64 %bd118115_0_h2_shifted, 127
  %bd118115_0_h2_zero = icmp eq i64 %bd118115_0_h2_raw, 0
  %bd118115_0_h2_value = select i1 %bd118115_0_h2_zero, i64 1, i64 %bd118115_0_h2_raw
  %bd118115_0_h2 = trunc i64 %bd118115_0_h2_value to i8
  %bd118115_0_probe_keys = getelementptr i8, ptr %v118115_storage, i64 32
  %bd118115_0_group_mask = sub i64 16, 1
  %bd118115_0_group_start = and i64 %bd118115_0_hash, %bd118115_0_group_mask
  %bd118115_0_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bd118115_0_group_has_capacity, label %bd118115_0_group_first, label %bd118115_0_group_no_capacity
bd118115_0_group_no_capacity:
  br label %bd118115_0_group_done
bd118115_0_group_first:
  %bd118115_0_group_control_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_0_group_start
  %bd118115_0_group_control = load i8, ptr %bd118115_0_group_control_ptr, align 1
  %bd118115_0_group_empty = icmp eq i8 %bd118115_0_group_control, 0
  br i1 %bd118115_0_group_empty, label %bd118115_0_group_vacant, label %bd118115_0_group_occupied
bd118115_0_group_occupied:
  %bd118115_0_group_h2_match = icmp eq i8 %bd118115_0_group_control, %bd118115_0_h2
  br i1 %bd118115_0_group_h2_match, label %bd118115_0_group_compare, label %bd118115_0_group_fallback
bd118115_0_group_compare:
  %bd118115_0_group_key_ptr = getelementptr [8 x i8], ptr %bd118115_0_probe_keys, i64 %bd118115_0_group_start
  %bd118115_0_group_key = load i32, ptr %bd118115_0_group_key_ptr, align 4
  %bd118115_0_group_equal = icmp eq i32 %bd118115_0_group_key, %bd118115_0_key_operand
  br i1 %bd118115_0_group_equal, label %bd118115_0_group_match, label %bd118115_0_group_fallback
bd118115_0_group_match:
  br label %bd118115_0_group_done
bd118115_0_group_vacant:
  br label %bd118115_0_group_done
bd118115_0_group_fallback:
  %bd118115_0_group_grouped_mask = sub i64 16, 1
  %bd118115_0_group_grouped_start = and i64 %bd118115_0_hash, %bd118115_0_group_grouped_mask
  br label %bd118115_0_group_grouped_entry
bd118115_0_group_grouped_entry:
  br label %bd118115_0_group_grouped_group
bd118115_0_group_grouped_group:
  %bd118115_0_group_grouped_probe = phi i64 [ 0, %bd118115_0_group_grouped_entry ], [ %bd118115_0_group_grouped_next_probe, %bd118115_0_group_grouped_next_group ]
  %bd118115_0_group_grouped_first_deleted = phi i64 [ 16, %bd118115_0_group_grouped_entry ], [ %bd118115_0_group_grouped_next_deleted, %bd118115_0_group_grouped_next_group ]
  %bd118115_0_group_grouped_active = icmp ult i64 %bd118115_0_group_grouped_probe, 16
  br i1 %bd118115_0_group_grouped_active, label %bd118115_0_group_grouped_body, label %bd118115_0_group_grouped_miss
bd118115_0_group_grouped_body:
  %bd118115_0_group_grouped_unwrapped = add i64 %bd118115_0_group_grouped_start, %bd118115_0_group_grouped_probe
  %bd118115_0_group_grouped_group_start = and i64 %bd118115_0_group_grouped_unwrapped, %bd118115_0_group_grouped_mask
  %bd118115_0_group_grouped_control_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_0_group_grouped_group_start
  %bd118115_0_group_grouped_controls = load <16 x i8>, ptr %bd118115_0_group_grouped_control_ptr, align 1
  %bd118115_0_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bd118115_0_h2, i64 0
  %bd118115_0_group_grouped_h2_vector = shufflevector <16 x i8> %bd118115_0_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118115_0_group_grouped_matches = icmp eq <16 x i8> %bd118115_0_group_grouped_controls, %bd118115_0_group_grouped_h2_vector
  %bd118115_0_group_grouped_match_bits = bitcast <16 x i1> %bd118115_0_group_grouped_matches to i16
  %bd118115_0_group_grouped_empties = icmp eq <16 x i8> %bd118115_0_group_grouped_controls, zeroinitializer
  %bd118115_0_group_grouped_empty_bits = bitcast <16 x i1> %bd118115_0_group_grouped_empties to i16
  %bd118115_0_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bd118115_0_group_grouped_deleted_vector = shufflevector <16 x i8> %bd118115_0_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118115_0_group_grouped_deleted_matches = icmp eq <16 x i8> %bd118115_0_group_grouped_controls, %bd118115_0_group_grouped_deleted_vector
  %bd118115_0_group_grouped_deleted_bits = bitcast <16 x i1> %bd118115_0_group_grouped_deleted_matches to i16
  %bd118115_0_group_grouped_has_deleted = icmp ne i16 %bd118115_0_group_grouped_deleted_bits, 0
  %bd118115_0_group_grouped_no_previous_deleted = icmp eq i64 %bd118115_0_group_grouped_first_deleted, 16
  %bd118115_0_group_grouped_capture_deleted = and i1 %bd118115_0_group_grouped_has_deleted, %bd118115_0_group_grouped_no_previous_deleted
  %bd118115_0_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bd118115_0_group_grouped_deleted_bits, i1 false)
  %bd118115_0_group_grouped_deleted_offset = zext i16 %bd118115_0_group_grouped_deleted_offset16 to i64
  %bd118115_0_group_grouped_deleted_unwrapped = add i64 %bd118115_0_group_grouped_group_start, %bd118115_0_group_grouped_deleted_offset
  %bd118115_0_group_grouped_deleted_slot = and i64 %bd118115_0_group_grouped_deleted_unwrapped, %bd118115_0_group_grouped_mask
  %bd118115_0_group_grouped_captured_deleted = select i1 %bd118115_0_group_grouped_capture_deleted, i64 %bd118115_0_group_grouped_deleted_slot, i64 %bd118115_0_group_grouped_first_deleted
  br label %bd118115_0_group_grouped_candidates
bd118115_0_group_grouped_candidates:
  %bd118115_0_group_grouped_candidate_bits = phi i16 [ %bd118115_0_group_grouped_match_bits, %bd118115_0_group_grouped_body ], [ %bd118115_0_group_grouped_cleared_bits, %bd118115_0_group_grouped_candidate_next ]
  %bd118115_0_group_grouped_has_candidate = icmp ne i16 %bd118115_0_group_grouped_candidate_bits, 0
  br i1 %bd118115_0_group_grouped_has_candidate, label %bd118115_0_group_grouped_candidate, label %bd118115_0_group_grouped_decision
bd118115_0_group_grouped_candidate:
  %bd118115_0_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bd118115_0_group_grouped_candidate_bits, i1 false)
  %bd118115_0_group_grouped_candidate_offset = zext i16 %bd118115_0_group_grouped_candidate_offset16 to i64
  %bd118115_0_group_grouped_candidate_unwrapped = add i64 %bd118115_0_group_grouped_group_start, %bd118115_0_group_grouped_candidate_offset
  %bd118115_0_group_grouped_candidate_slot = and i64 %bd118115_0_group_grouped_candidate_unwrapped, %bd118115_0_group_grouped_mask
  %bd118115_0_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bd118115_0_probe_keys, i64 %bd118115_0_group_grouped_candidate_slot
  %bd118115_0_group_grouped_key = load i32, ptr %bd118115_0_group_grouped_key_ptr, align 4
  %bd118115_0_group_grouped_candidate_equal = icmp eq i32 %bd118115_0_group_grouped_key, %bd118115_0_key_operand
  br i1 %bd118115_0_group_grouped_candidate_equal, label %bd118115_0_group_grouped_match, label %bd118115_0_group_grouped_candidate_next
bd118115_0_group_grouped_candidate_next:
  %bd118115_0_group_grouped_bits_minus_one = sub i16 %bd118115_0_group_grouped_candidate_bits, 1
  %bd118115_0_group_grouped_cleared_bits = and i16 %bd118115_0_group_grouped_candidate_bits, %bd118115_0_group_grouped_bits_minus_one
  br label %bd118115_0_group_grouped_candidates
bd118115_0_group_grouped_decision:
  %bd118115_0_group_grouped_has_empty = icmp ne i16 %bd118115_0_group_grouped_empty_bits, 0
  br i1 %bd118115_0_group_grouped_has_empty, label %bd118115_0_group_grouped_empty, label %bd118115_0_group_grouped_next_group
bd118115_0_group_grouped_empty:
  %bd118115_0_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bd118115_0_group_grouped_empty_bits, i1 false)
  %bd118115_0_group_grouped_empty_offset = zext i16 %bd118115_0_group_grouped_empty_offset16 to i64
  %bd118115_0_group_grouped_empty_unwrapped = add i64 %bd118115_0_group_grouped_group_start, %bd118115_0_group_grouped_empty_offset
  %bd118115_0_group_grouped_empty_slot = and i64 %bd118115_0_group_grouped_empty_unwrapped, %bd118115_0_group_grouped_mask
  %bd118115_0_group_grouped_use_empty = icmp eq i64 %bd118115_0_group_grouped_captured_deleted, 16
  %bd118115_0_group_grouped_insertion_slot = select i1 %bd118115_0_group_grouped_use_empty, i64 %bd118115_0_group_grouped_empty_slot, i64 %bd118115_0_group_grouped_captured_deleted
  br label %bd118115_0_group_grouped_done
bd118115_0_group_grouped_match:
  br label %bd118115_0_group_grouped_done
bd118115_0_group_grouped_next_group:
  %bd118115_0_group_grouped_next_probe = add i64 %bd118115_0_group_grouped_probe, 16
  %bd118115_0_group_grouped_next_deleted = add i64 %bd118115_0_group_grouped_captured_deleted, 0
  br label %bd118115_0_group_grouped_group
bd118115_0_group_grouped_miss:
  %bd118115_0_group_grouped_no_deleted = icmp eq i64 %bd118115_0_group_grouped_first_deleted, 16
  %bd118115_0_group_grouped_miss_slot = select i1 %bd118115_0_group_grouped_no_deleted, i64 0, i64 %bd118115_0_group_grouped_first_deleted
  br label %bd118115_0_group_grouped_done
bd118115_0_group_grouped_done:
  %bd118115_0_group_grouped_found = phi i1 [ false, %bd118115_0_group_grouped_empty ], [ true, %bd118115_0_group_grouped_match ], [ false, %bd118115_0_group_grouped_miss ]
  %bd118115_0_group_grouped_slot = phi i64 [ %bd118115_0_group_grouped_insertion_slot, %bd118115_0_group_grouped_empty ], [ %bd118115_0_group_grouped_candidate_slot, %bd118115_0_group_grouped_match ], [ %bd118115_0_group_grouped_miss_slot, %bd118115_0_group_grouped_miss ]
  br label %bd118115_0_group_done
bd118115_0_group_done:
  %bd118115_0_group_found = phi i1 [ true, %bd118115_0_group_match ], [ false, %bd118115_0_group_vacant ], [ %bd118115_0_group_grouped_found, %bd118115_0_group_grouped_done ], [ false, %bd118115_0_group_no_capacity ]
  %bd118115_0_group_slot = phi i64 [ %bd118115_0_group_start, %bd118115_0_group_match ], [ %bd118115_0_group_start, %bd118115_0_group_vacant ], [ %bd118115_0_group_grouped_slot, %bd118115_0_group_grouped_done ], [ 0, %bd118115_0_group_no_capacity ]
  %bd118115_0_slot = add i64 %bd118115_0_group_slot, 0
  %bd118115_0_exists = or i1 %bd118115_0_group_found, false
  br label %bd118115_0_insert
bd118115_0_insert:
  %bd118115_0_key_entry_offset = mul i64 %bd118115_0_slot, 8
  %bd118115_0_key_entries_field_offset = add i64 32, 0
  %bd118115_0_key_field_offset = add i64 %bd118115_0_key_entry_offset, %bd118115_0_key_entries_field_offset
  %bd118115_0_key_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_0_key_field_offset
  store i32 %bd118115_0_key_operand, ptr %bd118115_0_key_ptr, align 4
  %bd118115_0_value_entry_offset = mul i64 %bd118115_0_slot, 8
  %bd118115_0_value_entries_field_offset = add i64 32, 4
  %bd118115_0_value_field_offset = add i64 %bd118115_0_value_entry_offset, %bd118115_0_value_entries_field_offset
  %bd118115_0_value_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_0_value_field_offset
  store i32 %v118117, ptr %bd118115_0_value_ptr, align 4
  %bd118115_0_control_control_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_0_slot
  store i8 %bd118115_0_h2, ptr %bd118115_0_control_control_ptr, align 1
  %bd118115_0_control_mirror_needed = icmp ult i64 %bd118115_0_slot, 16
  %bd118115_0_control_mirror_candidate = add i64 %bd118115_0_slot, 16
  %bd118115_0_control_mirror_slot = select i1 %bd118115_0_control_mirror_needed, i64 %bd118115_0_control_mirror_candidate, i64 %bd118115_0_slot
  %bd118115_0_control_mirror_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_0_control_mirror_slot
  store i8 %bd118115_0_h2, ptr %bd118115_0_control_mirror_ptr, align 1
  %bd118115_1_key_operand = add i32 0, 2
  %bd118115_1_hash_key = sext i32 %bd118115_1_key_operand to i64
  %bd118115_1_hash_high = lshr i64 %bd118115_1_hash_key, 32
  %bd118115_1_hash_fold = xor i64 %bd118115_1_hash_key, %bd118115_1_hash_high
  %bd118115_1_hash = mul i64 %bd118115_1_hash_fold, -7046029254386353131
  %bd118115_1_h2_shifted = lshr i64 %bd118115_1_hash, 57
  %bd118115_1_h2_raw = and i64 %bd118115_1_h2_shifted, 127
  %bd118115_1_h2_zero = icmp eq i64 %bd118115_1_h2_raw, 0
  %bd118115_1_h2_value = select i1 %bd118115_1_h2_zero, i64 1, i64 %bd118115_1_h2_raw
  %bd118115_1_h2 = trunc i64 %bd118115_1_h2_value to i8
  %bd118115_1_probe_keys = getelementptr i8, ptr %v118115_storage, i64 32
  %bd118115_1_group_mask = sub i64 16, 1
  %bd118115_1_group_start = and i64 %bd118115_1_hash, %bd118115_1_group_mask
  %bd118115_1_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bd118115_1_group_has_capacity, label %bd118115_1_group_first, label %bd118115_1_group_no_capacity
bd118115_1_group_no_capacity:
  br label %bd118115_1_group_done
bd118115_1_group_first:
  %bd118115_1_group_control_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_1_group_start
  %bd118115_1_group_control = load i8, ptr %bd118115_1_group_control_ptr, align 1
  %bd118115_1_group_empty = icmp eq i8 %bd118115_1_group_control, 0
  br i1 %bd118115_1_group_empty, label %bd118115_1_group_vacant, label %bd118115_1_group_occupied
bd118115_1_group_occupied:
  %bd118115_1_group_h2_match = icmp eq i8 %bd118115_1_group_control, %bd118115_1_h2
  br i1 %bd118115_1_group_h2_match, label %bd118115_1_group_compare, label %bd118115_1_group_fallback
bd118115_1_group_compare:
  %bd118115_1_group_key_ptr = getelementptr [8 x i8], ptr %bd118115_1_probe_keys, i64 %bd118115_1_group_start
  %bd118115_1_group_key = load i32, ptr %bd118115_1_group_key_ptr, align 4
  %bd118115_1_group_equal = icmp eq i32 %bd118115_1_group_key, %bd118115_1_key_operand
  br i1 %bd118115_1_group_equal, label %bd118115_1_group_match, label %bd118115_1_group_fallback
bd118115_1_group_match:
  br label %bd118115_1_group_done
bd118115_1_group_vacant:
  br label %bd118115_1_group_done
bd118115_1_group_fallback:
  %bd118115_1_group_grouped_mask = sub i64 16, 1
  %bd118115_1_group_grouped_start = and i64 %bd118115_1_hash, %bd118115_1_group_grouped_mask
  br label %bd118115_1_group_grouped_entry
bd118115_1_group_grouped_entry:
  br label %bd118115_1_group_grouped_group
bd118115_1_group_grouped_group:
  %bd118115_1_group_grouped_probe = phi i64 [ 0, %bd118115_1_group_grouped_entry ], [ %bd118115_1_group_grouped_next_probe, %bd118115_1_group_grouped_next_group ]
  %bd118115_1_group_grouped_first_deleted = phi i64 [ 16, %bd118115_1_group_grouped_entry ], [ %bd118115_1_group_grouped_next_deleted, %bd118115_1_group_grouped_next_group ]
  %bd118115_1_group_grouped_active = icmp ult i64 %bd118115_1_group_grouped_probe, 16
  br i1 %bd118115_1_group_grouped_active, label %bd118115_1_group_grouped_body, label %bd118115_1_group_grouped_miss
bd118115_1_group_grouped_body:
  %bd118115_1_group_grouped_unwrapped = add i64 %bd118115_1_group_grouped_start, %bd118115_1_group_grouped_probe
  %bd118115_1_group_grouped_group_start = and i64 %bd118115_1_group_grouped_unwrapped, %bd118115_1_group_grouped_mask
  %bd118115_1_group_grouped_control_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_1_group_grouped_group_start
  %bd118115_1_group_grouped_controls = load <16 x i8>, ptr %bd118115_1_group_grouped_control_ptr, align 1
  %bd118115_1_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bd118115_1_h2, i64 0
  %bd118115_1_group_grouped_h2_vector = shufflevector <16 x i8> %bd118115_1_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118115_1_group_grouped_matches = icmp eq <16 x i8> %bd118115_1_group_grouped_controls, %bd118115_1_group_grouped_h2_vector
  %bd118115_1_group_grouped_match_bits = bitcast <16 x i1> %bd118115_1_group_grouped_matches to i16
  %bd118115_1_group_grouped_empties = icmp eq <16 x i8> %bd118115_1_group_grouped_controls, zeroinitializer
  %bd118115_1_group_grouped_empty_bits = bitcast <16 x i1> %bd118115_1_group_grouped_empties to i16
  %bd118115_1_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bd118115_1_group_grouped_deleted_vector = shufflevector <16 x i8> %bd118115_1_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118115_1_group_grouped_deleted_matches = icmp eq <16 x i8> %bd118115_1_group_grouped_controls, %bd118115_1_group_grouped_deleted_vector
  %bd118115_1_group_grouped_deleted_bits = bitcast <16 x i1> %bd118115_1_group_grouped_deleted_matches to i16
  %bd118115_1_group_grouped_has_deleted = icmp ne i16 %bd118115_1_group_grouped_deleted_bits, 0
  %bd118115_1_group_grouped_no_previous_deleted = icmp eq i64 %bd118115_1_group_grouped_first_deleted, 16
  %bd118115_1_group_grouped_capture_deleted = and i1 %bd118115_1_group_grouped_has_deleted, %bd118115_1_group_grouped_no_previous_deleted
  %bd118115_1_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bd118115_1_group_grouped_deleted_bits, i1 false)
  %bd118115_1_group_grouped_deleted_offset = zext i16 %bd118115_1_group_grouped_deleted_offset16 to i64
  %bd118115_1_group_grouped_deleted_unwrapped = add i64 %bd118115_1_group_grouped_group_start, %bd118115_1_group_grouped_deleted_offset
  %bd118115_1_group_grouped_deleted_slot = and i64 %bd118115_1_group_grouped_deleted_unwrapped, %bd118115_1_group_grouped_mask
  %bd118115_1_group_grouped_captured_deleted = select i1 %bd118115_1_group_grouped_capture_deleted, i64 %bd118115_1_group_grouped_deleted_slot, i64 %bd118115_1_group_grouped_first_deleted
  br label %bd118115_1_group_grouped_candidates
bd118115_1_group_grouped_candidates:
  %bd118115_1_group_grouped_candidate_bits = phi i16 [ %bd118115_1_group_grouped_match_bits, %bd118115_1_group_grouped_body ], [ %bd118115_1_group_grouped_cleared_bits, %bd118115_1_group_grouped_candidate_next ]
  %bd118115_1_group_grouped_has_candidate = icmp ne i16 %bd118115_1_group_grouped_candidate_bits, 0
  br i1 %bd118115_1_group_grouped_has_candidate, label %bd118115_1_group_grouped_candidate, label %bd118115_1_group_grouped_decision
bd118115_1_group_grouped_candidate:
  %bd118115_1_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bd118115_1_group_grouped_candidate_bits, i1 false)
  %bd118115_1_group_grouped_candidate_offset = zext i16 %bd118115_1_group_grouped_candidate_offset16 to i64
  %bd118115_1_group_grouped_candidate_unwrapped = add i64 %bd118115_1_group_grouped_group_start, %bd118115_1_group_grouped_candidate_offset
  %bd118115_1_group_grouped_candidate_slot = and i64 %bd118115_1_group_grouped_candidate_unwrapped, %bd118115_1_group_grouped_mask
  %bd118115_1_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bd118115_1_probe_keys, i64 %bd118115_1_group_grouped_candidate_slot
  %bd118115_1_group_grouped_key = load i32, ptr %bd118115_1_group_grouped_key_ptr, align 4
  %bd118115_1_group_grouped_candidate_equal = icmp eq i32 %bd118115_1_group_grouped_key, %bd118115_1_key_operand
  br i1 %bd118115_1_group_grouped_candidate_equal, label %bd118115_1_group_grouped_match, label %bd118115_1_group_grouped_candidate_next
bd118115_1_group_grouped_candidate_next:
  %bd118115_1_group_grouped_bits_minus_one = sub i16 %bd118115_1_group_grouped_candidate_bits, 1
  %bd118115_1_group_grouped_cleared_bits = and i16 %bd118115_1_group_grouped_candidate_bits, %bd118115_1_group_grouped_bits_minus_one
  br label %bd118115_1_group_grouped_candidates
bd118115_1_group_grouped_decision:
  %bd118115_1_group_grouped_has_empty = icmp ne i16 %bd118115_1_group_grouped_empty_bits, 0
  br i1 %bd118115_1_group_grouped_has_empty, label %bd118115_1_group_grouped_empty, label %bd118115_1_group_grouped_next_group
bd118115_1_group_grouped_empty:
  %bd118115_1_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bd118115_1_group_grouped_empty_bits, i1 false)
  %bd118115_1_group_grouped_empty_offset = zext i16 %bd118115_1_group_grouped_empty_offset16 to i64
  %bd118115_1_group_grouped_empty_unwrapped = add i64 %bd118115_1_group_grouped_group_start, %bd118115_1_group_grouped_empty_offset
  %bd118115_1_group_grouped_empty_slot = and i64 %bd118115_1_group_grouped_empty_unwrapped, %bd118115_1_group_grouped_mask
  %bd118115_1_group_grouped_use_empty = icmp eq i64 %bd118115_1_group_grouped_captured_deleted, 16
  %bd118115_1_group_grouped_insertion_slot = select i1 %bd118115_1_group_grouped_use_empty, i64 %bd118115_1_group_grouped_empty_slot, i64 %bd118115_1_group_grouped_captured_deleted
  br label %bd118115_1_group_grouped_done
bd118115_1_group_grouped_match:
  br label %bd118115_1_group_grouped_done
bd118115_1_group_grouped_next_group:
  %bd118115_1_group_grouped_next_probe = add i64 %bd118115_1_group_grouped_probe, 16
  %bd118115_1_group_grouped_next_deleted = add i64 %bd118115_1_group_grouped_captured_deleted, 0
  br label %bd118115_1_group_grouped_group
bd118115_1_group_grouped_miss:
  %bd118115_1_group_grouped_no_deleted = icmp eq i64 %bd118115_1_group_grouped_first_deleted, 16
  %bd118115_1_group_grouped_miss_slot = select i1 %bd118115_1_group_grouped_no_deleted, i64 0, i64 %bd118115_1_group_grouped_first_deleted
  br label %bd118115_1_group_grouped_done
bd118115_1_group_grouped_done:
  %bd118115_1_group_grouped_found = phi i1 [ false, %bd118115_1_group_grouped_empty ], [ true, %bd118115_1_group_grouped_match ], [ false, %bd118115_1_group_grouped_miss ]
  %bd118115_1_group_grouped_slot = phi i64 [ %bd118115_1_group_grouped_insertion_slot, %bd118115_1_group_grouped_empty ], [ %bd118115_1_group_grouped_candidate_slot, %bd118115_1_group_grouped_match ], [ %bd118115_1_group_grouped_miss_slot, %bd118115_1_group_grouped_miss ]
  br label %bd118115_1_group_done
bd118115_1_group_done:
  %bd118115_1_group_found = phi i1 [ true, %bd118115_1_group_match ], [ false, %bd118115_1_group_vacant ], [ %bd118115_1_group_grouped_found, %bd118115_1_group_grouped_done ], [ false, %bd118115_1_group_no_capacity ]
  %bd118115_1_group_slot = phi i64 [ %bd118115_1_group_start, %bd118115_1_group_match ], [ %bd118115_1_group_start, %bd118115_1_group_vacant ], [ %bd118115_1_group_grouped_slot, %bd118115_1_group_grouped_done ], [ 0, %bd118115_1_group_no_capacity ]
  %bd118115_1_slot = add i64 %bd118115_1_group_slot, 0
  %bd118115_1_exists = or i1 %bd118115_1_group_found, false
  br label %bd118115_1_insert
bd118115_1_insert:
  %bd118115_1_key_entry_offset = mul i64 %bd118115_1_slot, 8
  %bd118115_1_key_entries_field_offset = add i64 32, 0
  %bd118115_1_key_field_offset = add i64 %bd118115_1_key_entry_offset, %bd118115_1_key_entries_field_offset
  %bd118115_1_key_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_1_key_field_offset
  store i32 %bd118115_1_key_operand, ptr %bd118115_1_key_ptr, align 4
  %bd118115_1_value_entry_offset = mul i64 %bd118115_1_slot, 8
  %bd118115_1_value_entries_field_offset = add i64 32, 4
  %bd118115_1_value_field_offset = add i64 %bd118115_1_value_entry_offset, %bd118115_1_value_entries_field_offset
  %bd118115_1_value_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_1_value_field_offset
  store i32 %v118121, ptr %bd118115_1_value_ptr, align 4
  %bd118115_1_control_control_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_1_slot
  store i8 %bd118115_1_h2, ptr %bd118115_1_control_control_ptr, align 1
  %bd118115_1_control_mirror_needed = icmp ult i64 %bd118115_1_slot, 16
  %bd118115_1_control_mirror_candidate = add i64 %bd118115_1_slot, 16
  %bd118115_1_control_mirror_slot = select i1 %bd118115_1_control_mirror_needed, i64 %bd118115_1_control_mirror_candidate, i64 %bd118115_1_slot
  %bd118115_1_control_mirror_ptr = getelementptr i8, ptr %v118115_storage, i64 %bd118115_1_control_mirror_slot
  store i8 %bd118115_1_h2, ptr %bd118115_1_control_mirror_ptr, align 1
  %v118115_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %v118115_owner, i32 0, i32 0
  store i64 2, ptr %v118115_length_ptr, align 8
  %v118115 = load %sollang.bounded_dictionary.t1247, ptr %v118115_owner, align 8
  %v118126 = freeze %sollang.bounded_dictionary.t1247 %v118115
  store %sollang.bounded_dictionary.t1247 %v118126, ptr %bidx118125_owner, align 8
  %bidx118125_storage = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %bidx118125_owner, i32 0, i32 1, i32 0
  %bidx118125_query = freeze i32 1
  %bidx118125_hash_key = sext i32 %bidx118125_query to i64
  %bidx118125_hash_high = lshr i64 %bidx118125_hash_key, 32
  %bidx118125_hash_fold = xor i64 %bidx118125_hash_key, %bidx118125_hash_high
  %bidx118125_hash = mul i64 %bidx118125_hash_fold, -7046029254386353131
  %bidx118125_h2_shifted = lshr i64 %bidx118125_hash, 57
  %bidx118125_h2_raw = and i64 %bidx118125_h2_shifted, 127
  %bidx118125_h2_zero = icmp eq i64 %bidx118125_h2_raw, 0
  %bidx118125_h2_value = select i1 %bidx118125_h2_zero, i64 1, i64 %bidx118125_h2_raw
  %bidx118125_h2 = trunc i64 %bidx118125_h2_value to i8
  %bidx118125_probe_keys = getelementptr i8, ptr %bidx118125_storage, i64 32
  %bidx118125_group_mask = sub i64 16, 1
  %bidx118125_group_start = and i64 %bidx118125_hash, %bidx118125_group_mask
  br label %bidx118125_group_first
bidx118125_group_first:
  %bidx118125_group_control_ptr = getelementptr i8, ptr %bidx118125_storage, i64 %bidx118125_group_start
  %bidx118125_group_control = load i8, ptr %bidx118125_group_control_ptr, align 1
  %bidx118125_group_empty = icmp eq i8 %bidx118125_group_control, 0
  br i1 %bidx118125_group_empty, label %bidx118125_group_vacant, label %bidx118125_group_occupied
bidx118125_group_occupied:
  %bidx118125_group_h2_match = icmp eq i8 %bidx118125_group_control, %bidx118125_h2
  br i1 %bidx118125_group_h2_match, label %bidx118125_group_compare, label %bidx118125_group_fallback
bidx118125_group_compare:
  %bidx118125_group_key_ptr = getelementptr [8 x i8], ptr %bidx118125_probe_keys, i64 %bidx118125_group_start
  %bidx118125_group_key = load i32, ptr %bidx118125_group_key_ptr, align 4
  %bidx118125_group_equal = icmp eq i32 %bidx118125_group_key, %bidx118125_query
  br i1 %bidx118125_group_equal, label %bidx118125_group_match, label %bidx118125_group_fallback
bidx118125_group_match:
  br label %bidx118125_group_done
bidx118125_group_vacant:
  br label %bidx118125_group_done
bidx118125_group_fallback:
  %bidx118125_group_grouped_mask = sub i64 16, 1
  %bidx118125_group_grouped_start = and i64 %bidx118125_hash, %bidx118125_group_grouped_mask
  br label %bidx118125_group_grouped_entry
bidx118125_group_grouped_entry:
  br label %bidx118125_group_grouped_group
bidx118125_group_grouped_group:
  %bidx118125_group_grouped_probe = phi i64 [ 0, %bidx118125_group_grouped_entry ], [ %bidx118125_group_grouped_next_probe, %bidx118125_group_grouped_next_group ]
  %bidx118125_group_grouped_active = icmp ult i64 %bidx118125_group_grouped_probe, 16
  br i1 %bidx118125_group_grouped_active, label %bidx118125_group_grouped_body, label %bidx118125_group_grouped_miss
bidx118125_group_grouped_body:
  %bidx118125_group_grouped_unwrapped = add i64 %bidx118125_group_grouped_start, %bidx118125_group_grouped_probe
  %bidx118125_group_grouped_group_start = and i64 %bidx118125_group_grouped_unwrapped, %bidx118125_group_grouped_mask
  %bidx118125_group_grouped_control_ptr = getelementptr i8, ptr %bidx118125_storage, i64 %bidx118125_group_grouped_group_start
  %bidx118125_group_grouped_controls = load <16 x i8>, ptr %bidx118125_group_grouped_control_ptr, align 1
  %bidx118125_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bidx118125_h2, i64 0
  %bidx118125_group_grouped_h2_vector = shufflevector <16 x i8> %bidx118125_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bidx118125_group_grouped_matches = icmp eq <16 x i8> %bidx118125_group_grouped_controls, %bidx118125_group_grouped_h2_vector
  %bidx118125_group_grouped_match_bits = bitcast <16 x i1> %bidx118125_group_grouped_matches to i16
  %bidx118125_group_grouped_empties = icmp eq <16 x i8> %bidx118125_group_grouped_controls, zeroinitializer
  %bidx118125_group_grouped_empty_bits = bitcast <16 x i1> %bidx118125_group_grouped_empties to i16
  br label %bidx118125_group_grouped_candidates
bidx118125_group_grouped_candidates:
  %bidx118125_group_grouped_candidate_bits = phi i16 [ %bidx118125_group_grouped_match_bits, %bidx118125_group_grouped_body ], [ %bidx118125_group_grouped_cleared_bits, %bidx118125_group_grouped_candidate_next ]
  %bidx118125_group_grouped_has_candidate = icmp ne i16 %bidx118125_group_grouped_candidate_bits, 0
  br i1 %bidx118125_group_grouped_has_candidate, label %bidx118125_group_grouped_candidate, label %bidx118125_group_grouped_decision
bidx118125_group_grouped_candidate:
  %bidx118125_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bidx118125_group_grouped_candidate_bits, i1 false)
  %bidx118125_group_grouped_candidate_offset = zext i16 %bidx118125_group_grouped_candidate_offset16 to i64
  %bidx118125_group_grouped_candidate_unwrapped = add i64 %bidx118125_group_grouped_group_start, %bidx118125_group_grouped_candidate_offset
  %bidx118125_group_grouped_candidate_slot = and i64 %bidx118125_group_grouped_candidate_unwrapped, %bidx118125_group_grouped_mask
  %bidx118125_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bidx118125_probe_keys, i64 %bidx118125_group_grouped_candidate_slot
  %bidx118125_group_grouped_key = load i32, ptr %bidx118125_group_grouped_key_ptr, align 4
  %bidx118125_group_grouped_candidate_equal = icmp eq i32 %bidx118125_group_grouped_key, %bidx118125_query
  br i1 %bidx118125_group_grouped_candidate_equal, label %bidx118125_group_grouped_match, label %bidx118125_group_grouped_candidate_next
bidx118125_group_grouped_candidate_next:
  %bidx118125_group_grouped_bits_minus_one = sub i16 %bidx118125_group_grouped_candidate_bits, 1
  %bidx118125_group_grouped_cleared_bits = and i16 %bidx118125_group_grouped_candidate_bits, %bidx118125_group_grouped_bits_minus_one
  br label %bidx118125_group_grouped_candidates
bidx118125_group_grouped_decision:
  %bidx118125_group_grouped_has_empty = icmp ne i16 %bidx118125_group_grouped_empty_bits, 0
  br i1 %bidx118125_group_grouped_has_empty, label %bidx118125_group_grouped_miss, label %bidx118125_group_grouped_next_group
bidx118125_group_grouped_match:
  br label %bidx118125_group_grouped_done
bidx118125_group_grouped_next_group:
  %bidx118125_group_grouped_next_probe = add i64 %bidx118125_group_grouped_probe, 16
  br label %bidx118125_group_grouped_group
bidx118125_group_grouped_miss:
  br label %bidx118125_group_grouped_done
bidx118125_group_grouped_done:
  %bidx118125_group_grouped_found = phi i1 [ true, %bidx118125_group_grouped_match ], [ false, %bidx118125_group_grouped_miss ]
  %bidx118125_group_grouped_slot = phi i64 [ %bidx118125_group_grouped_candidate_slot, %bidx118125_group_grouped_match ], [ 0, %bidx118125_group_grouped_miss ]
  br label %bidx118125_group_done
bidx118125_group_done:
  %bidx118125_group_found = phi i1 [ true, %bidx118125_group_match ], [ false, %bidx118125_group_vacant ], [ %bidx118125_group_grouped_found, %bidx118125_group_grouped_done ]
  %bidx118125_group_slot = phi i64 [ %bidx118125_group_start, %bidx118125_group_match ], [ 0, %bidx118125_group_vacant ], [ %bidx118125_group_grouped_slot, %bidx118125_group_grouped_done ]
  %bidx118125_slot = add i64 %bidx118125_group_slot, 0
  %bidx118125_exists = or i1 %bidx118125_group_found, false
  br i1 %bidx118125_exists, label %bidx118125_found, label %bidx118125_missing
bidx118125_missing:
  call void @llvm.trap()
  unreachable
bidx118125_found:
  %v118125_value_entry_offset = mul i64 %bidx118125_slot, 8
  %v118125_value_entries_field_offset = add i64 32, 4
  %v118125_value_field_offset = add i64 %v118125_value_entry_offset, %v118125_value_entries_field_offset
  %v118125_value_ptr = getelementptr i8, ptr %bidx118125_storage, i64 %v118125_value_field_offset
  %v118125 = load i32, ptr %v118125_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118125, i1 true)
  %v118130 = freeze %sollang.bounded_dictionary.t1247 %v118115
  store %sollang.bounded_dictionary.t1247 %v118130, ptr %bidx118129_owner, align 8
  %bidx118129_storage = getelementptr inbounds %sollang.bounded_dictionary.t1247, ptr %bidx118129_owner, i32 0, i32 1, i32 0
  %bidx118129_query = freeze i32 2
  %bidx118129_hash_key = sext i32 %bidx118129_query to i64
  %bidx118129_hash_high = lshr i64 %bidx118129_hash_key, 32
  %bidx118129_hash_fold = xor i64 %bidx118129_hash_key, %bidx118129_hash_high
  %bidx118129_hash = mul i64 %bidx118129_hash_fold, -7046029254386353131
  %bidx118129_h2_shifted = lshr i64 %bidx118129_hash, 57
  %bidx118129_h2_raw = and i64 %bidx118129_h2_shifted, 127
  %bidx118129_h2_zero = icmp eq i64 %bidx118129_h2_raw, 0
  %bidx118129_h2_value = select i1 %bidx118129_h2_zero, i64 1, i64 %bidx118129_h2_raw
  %bidx118129_h2 = trunc i64 %bidx118129_h2_value to i8
  %bidx118129_probe_keys = getelementptr i8, ptr %bidx118129_storage, i64 32
  %bidx118129_group_mask = sub i64 16, 1
  %bidx118129_group_start = and i64 %bidx118129_hash, %bidx118129_group_mask
  br label %bidx118129_group_first
bidx118129_group_first:
  %bidx118129_group_control_ptr = getelementptr i8, ptr %bidx118129_storage, i64 %bidx118129_group_start
  %bidx118129_group_control = load i8, ptr %bidx118129_group_control_ptr, align 1
  %bidx118129_group_empty = icmp eq i8 %bidx118129_group_control, 0
  br i1 %bidx118129_group_empty, label %bidx118129_group_vacant, label %bidx118129_group_occupied
bidx118129_group_occupied:
  %bidx118129_group_h2_match = icmp eq i8 %bidx118129_group_control, %bidx118129_h2
  br i1 %bidx118129_group_h2_match, label %bidx118129_group_compare, label %bidx118129_group_fallback
bidx118129_group_compare:
  %bidx118129_group_key_ptr = getelementptr [8 x i8], ptr %bidx118129_probe_keys, i64 %bidx118129_group_start
  %bidx118129_group_key = load i32, ptr %bidx118129_group_key_ptr, align 4
  %bidx118129_group_equal = icmp eq i32 %bidx118129_group_key, %bidx118129_query
  br i1 %bidx118129_group_equal, label %bidx118129_group_match, label %bidx118129_group_fallback
bidx118129_group_match:
  br label %bidx118129_group_done
bidx118129_group_vacant:
  br label %bidx118129_group_done
bidx118129_group_fallback:
  %bidx118129_group_grouped_mask = sub i64 16, 1
  %bidx118129_group_grouped_start = and i64 %bidx118129_hash, %bidx118129_group_grouped_mask
  br label %bidx118129_group_grouped_entry
bidx118129_group_grouped_entry:
  br label %bidx118129_group_grouped_group
bidx118129_group_grouped_group:
  %bidx118129_group_grouped_probe = phi i64 [ 0, %bidx118129_group_grouped_entry ], [ %bidx118129_group_grouped_next_probe, %bidx118129_group_grouped_next_group ]
  %bidx118129_group_grouped_active = icmp ult i64 %bidx118129_group_grouped_probe, 16
  br i1 %bidx118129_group_grouped_active, label %bidx118129_group_grouped_body, label %bidx118129_group_grouped_miss
bidx118129_group_grouped_body:
  %bidx118129_group_grouped_unwrapped = add i64 %bidx118129_group_grouped_start, %bidx118129_group_grouped_probe
  %bidx118129_group_grouped_group_start = and i64 %bidx118129_group_grouped_unwrapped, %bidx118129_group_grouped_mask
  %bidx118129_group_grouped_control_ptr = getelementptr i8, ptr %bidx118129_storage, i64 %bidx118129_group_grouped_group_start
  %bidx118129_group_grouped_controls = load <16 x i8>, ptr %bidx118129_group_grouped_control_ptr, align 1
  %bidx118129_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bidx118129_h2, i64 0
  %bidx118129_group_grouped_h2_vector = shufflevector <16 x i8> %bidx118129_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bidx118129_group_grouped_matches = icmp eq <16 x i8> %bidx118129_group_grouped_controls, %bidx118129_group_grouped_h2_vector
  %bidx118129_group_grouped_match_bits = bitcast <16 x i1> %bidx118129_group_grouped_matches to i16
  %bidx118129_group_grouped_empties = icmp eq <16 x i8> %bidx118129_group_grouped_controls, zeroinitializer
  %bidx118129_group_grouped_empty_bits = bitcast <16 x i1> %bidx118129_group_grouped_empties to i16
  br label %bidx118129_group_grouped_candidates
bidx118129_group_grouped_candidates:
  %bidx118129_group_grouped_candidate_bits = phi i16 [ %bidx118129_group_grouped_match_bits, %bidx118129_group_grouped_body ], [ %bidx118129_group_grouped_cleared_bits, %bidx118129_group_grouped_candidate_next ]
  %bidx118129_group_grouped_has_candidate = icmp ne i16 %bidx118129_group_grouped_candidate_bits, 0
  br i1 %bidx118129_group_grouped_has_candidate, label %bidx118129_group_grouped_candidate, label %bidx118129_group_grouped_decision
bidx118129_group_grouped_candidate:
  %bidx118129_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bidx118129_group_grouped_candidate_bits, i1 false)
  %bidx118129_group_grouped_candidate_offset = zext i16 %bidx118129_group_grouped_candidate_offset16 to i64
  %bidx118129_group_grouped_candidate_unwrapped = add i64 %bidx118129_group_grouped_group_start, %bidx118129_group_grouped_candidate_offset
  %bidx118129_group_grouped_candidate_slot = and i64 %bidx118129_group_grouped_candidate_unwrapped, %bidx118129_group_grouped_mask
  %bidx118129_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bidx118129_probe_keys, i64 %bidx118129_group_grouped_candidate_slot
  %bidx118129_group_grouped_key = load i32, ptr %bidx118129_group_grouped_key_ptr, align 4
  %bidx118129_group_grouped_candidate_equal = icmp eq i32 %bidx118129_group_grouped_key, %bidx118129_query
  br i1 %bidx118129_group_grouped_candidate_equal, label %bidx118129_group_grouped_match, label %bidx118129_group_grouped_candidate_next
bidx118129_group_grouped_candidate_next:
  %bidx118129_group_grouped_bits_minus_one = sub i16 %bidx118129_group_grouped_candidate_bits, 1
  %bidx118129_group_grouped_cleared_bits = and i16 %bidx118129_group_grouped_candidate_bits, %bidx118129_group_grouped_bits_minus_one
  br label %bidx118129_group_grouped_candidates
bidx118129_group_grouped_decision:
  %bidx118129_group_grouped_has_empty = icmp ne i16 %bidx118129_group_grouped_empty_bits, 0
  br i1 %bidx118129_group_grouped_has_empty, label %bidx118129_group_grouped_miss, label %bidx118129_group_grouped_next_group
bidx118129_group_grouped_match:
  br label %bidx118129_group_grouped_done
bidx118129_group_grouped_next_group:
  %bidx118129_group_grouped_next_probe = add i64 %bidx118129_group_grouped_probe, 16
  br label %bidx118129_group_grouped_group
bidx118129_group_grouped_miss:
  br label %bidx118129_group_grouped_done
bidx118129_group_grouped_done:
  %bidx118129_group_grouped_found = phi i1 [ true, %bidx118129_group_grouped_match ], [ false, %bidx118129_group_grouped_miss ]
  %bidx118129_group_grouped_slot = phi i64 [ %bidx118129_group_grouped_candidate_slot, %bidx118129_group_grouped_match ], [ 0, %bidx118129_group_grouped_miss ]
  br label %bidx118129_group_done
bidx118129_group_done:
  %bidx118129_group_found = phi i1 [ true, %bidx118129_group_match ], [ false, %bidx118129_group_vacant ], [ %bidx118129_group_grouped_found, %bidx118129_group_grouped_done ]
  %bidx118129_group_slot = phi i64 [ %bidx118129_group_start, %bidx118129_group_match ], [ 0, %bidx118129_group_vacant ], [ %bidx118129_group_grouped_slot, %bidx118129_group_grouped_done ]
  %bidx118129_slot = add i64 %bidx118129_group_slot, 0
  %bidx118129_exists = or i1 %bidx118129_group_found, false
  br i1 %bidx118129_exists, label %bidx118129_found, label %bidx118129_missing
bidx118129_missing:
  call void @llvm.trap()
  unreachable
bidx118129_found:
  %v118129_value_entry_offset = mul i64 %bidx118129_slot, 8
  %v118129_value_entries_field_offset = add i64 32, 4
  %v118129_value_field_offset = add i64 %v118129_value_entry_offset, %v118129_value_entries_field_offset
  %v118129_value_ptr = getelementptr i8, ptr %bidx118129_storage, i64 %v118129_value_field_offset
  %v118129 = load i32, ptr %v118129_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118129, i1 true)
  %v118133 = load i32, ptr %slot118105, align 4
  %v118132 = add i32 %v118133, 1
  store i32 %v118132, ptr %slot118105, align 4
  call void @sollang_drop_t1247(%sollang.bounded_dictionary.t1247 %v118115)
  br label %while118113_header
while118113_exit:
  ret void
}

define i32 @main() {
entry:
  call void @sollang_m144_s0()
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
