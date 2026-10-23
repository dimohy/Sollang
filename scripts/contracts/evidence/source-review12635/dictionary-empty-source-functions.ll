define i32 @main() {
entry:
  %v118114_owner = alloca %sollang.bounded_dictionary.t1212, align 8
  %slot118104 = alloca i32, align 4
  %slot118105 = alloca %sollang.bounded_dictionary.t1212, align 8
  store i32 0, ptr %slot118104, align 4
  br label %while118112_header
while118112_header:
  %while118112_v118110 = load i32, ptr %slot118104, align 4
  %while118112_v118109 = icmp slt i32 %while118112_v118110, 2
  br i1 %while118112_v118109, label %while118112_body, label %while118112_exit
while118112_body:
  store %sollang.bounded_dictionary.t1212 zeroinitializer, ptr %v118114_owner, align 8
  %v118114_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118114_owner, i32 0, i32 1, i32 0
  %v118114 = load %sollang.bounded_dictionary.t1212, ptr %v118114_owner, align 8
  store %sollang.bounded_dictionary.t1212 %v118114, ptr %slot118105, align 8
  %v118116 = load %sollang.bounded_dictionary.t1212, ptr %slot118105, align 8
  %v118119 = load i32, ptr %slot118104, align 4
  %v118118 = add i32 %v118119, 10
  %bput118115_owner = getelementptr i8, ptr %slot118105, i64 0
  %bput118115_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bput118115_owner, i32 0, i32 1, i32 0
  %bput118115_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bput118115_owner, i32 0, i32 0
  %bput118115_old_length = load i64, ptr %bput118115_length_ptr, align 8
  %bput118115_query = freeze i32 1
  %bput118115_new_value = freeze i32 %v118118
  %bput118115_hash_key = sext i32 %bput118115_query to i64
  %bput118115_hash_high = lshr i64 %bput118115_hash_key, 32
  %bput118115_hash_fold = xor i64 %bput118115_hash_key, %bput118115_hash_high
  %bput118115_hash = mul i64 %bput118115_hash_fold, -7046029254386353131
  %bput118115_h2_shifted = lshr i64 %bput118115_hash, 57
  %bput118115_h2_raw = and i64 %bput118115_h2_shifted, 127
  %bput118115_h2_zero = icmp eq i64 %bput118115_h2_raw, 0
  %bput118115_h2_value = select i1 %bput118115_h2_zero, i64 1, i64 %bput118115_h2_raw
  %bput118115_h2 = trunc i64 %bput118115_h2_value to i8
  %bput118115_probe_keys = getelementptr i8, ptr %bput118115_storage, i64 32
  %bput118115_group_mask = sub i64 16, 1
  %bput118115_group_start = and i64 %bput118115_hash, %bput118115_group_mask
  %bput118115_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bput118115_group_has_capacity, label %bput118115_group_first, label %bput118115_group_no_capacity
bput118115_group_no_capacity:
  br label %bput118115_group_done
bput118115_group_first:
  %bput118115_group_control_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_group_start
  %bput118115_group_control = load i8, ptr %bput118115_group_control_ptr, align 1
  %bput118115_group_empty = icmp eq i8 %bput118115_group_control, 0
  br i1 %bput118115_group_empty, label %bput118115_group_vacant, label %bput118115_group_occupied
bput118115_group_occupied:
  %bput118115_group_h2_match = icmp eq i8 %bput118115_group_control, %bput118115_h2
  br i1 %bput118115_group_h2_match, label %bput118115_group_compare, label %bput118115_group_fallback
bput118115_group_compare:
  %bput118115_group_key_ptr = getelementptr [8 x i8], ptr %bput118115_probe_keys, i64 %bput118115_group_start
  %bput118115_group_key = load i32, ptr %bput118115_group_key_ptr, align 4
  %bput118115_group_equal = icmp eq i32 %bput118115_group_key, %bput118115_query
  br i1 %bput118115_group_equal, label %bput118115_group_match, label %bput118115_group_fallback
bput118115_group_match:
  br label %bput118115_group_done
bput118115_group_vacant:
  br label %bput118115_group_done
bput118115_group_fallback:
  %bput118115_group_grouped_mask = sub i64 16, 1
  %bput118115_group_grouped_start = and i64 %bput118115_hash, %bput118115_group_grouped_mask
  br label %bput118115_group_grouped_entry
bput118115_group_grouped_entry:
  br label %bput118115_group_grouped_group
bput118115_group_grouped_group:
  %bput118115_group_grouped_probe = phi i64 [ 0, %bput118115_group_grouped_entry ], [ %bput118115_group_grouped_next_probe, %bput118115_group_grouped_next_group ]
  %bput118115_group_grouped_first_deleted = phi i64 [ 16, %bput118115_group_grouped_entry ], [ %bput118115_group_grouped_next_deleted, %bput118115_group_grouped_next_group ]
  %bput118115_group_grouped_active = icmp ult i64 %bput118115_group_grouped_probe, 16
  br i1 %bput118115_group_grouped_active, label %bput118115_group_grouped_body, label %bput118115_group_grouped_miss
bput118115_group_grouped_body:
  %bput118115_group_grouped_unwrapped = add i64 %bput118115_group_grouped_start, %bput118115_group_grouped_probe
  %bput118115_group_grouped_group_start = and i64 %bput118115_group_grouped_unwrapped, %bput118115_group_grouped_mask
  %bput118115_group_grouped_control_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_group_grouped_group_start
  %bput118115_group_grouped_controls = load <16 x i8>, ptr %bput118115_group_grouped_control_ptr, align 1
  %bput118115_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bput118115_h2, i64 0
  %bput118115_group_grouped_h2_vector = shufflevector <16 x i8> %bput118115_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bput118115_group_grouped_matches = icmp eq <16 x i8> %bput118115_group_grouped_controls, %bput118115_group_grouped_h2_vector
  %bput118115_group_grouped_match_bits = bitcast <16 x i1> %bput118115_group_grouped_matches to i16
  %bput118115_group_grouped_empties = icmp eq <16 x i8> %bput118115_group_grouped_controls, zeroinitializer
  %bput118115_group_grouped_empty_bits = bitcast <16 x i1> %bput118115_group_grouped_empties to i16
  %bput118115_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bput118115_group_grouped_deleted_vector = shufflevector <16 x i8> %bput118115_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bput118115_group_grouped_deleted_matches = icmp eq <16 x i8> %bput118115_group_grouped_controls, %bput118115_group_grouped_deleted_vector
  %bput118115_group_grouped_deleted_bits = bitcast <16 x i1> %bput118115_group_grouped_deleted_matches to i16
  %bput118115_group_grouped_has_deleted = icmp ne i16 %bput118115_group_grouped_deleted_bits, 0
  %bput118115_group_grouped_no_previous_deleted = icmp eq i64 %bput118115_group_grouped_first_deleted, 16
  %bput118115_group_grouped_capture_deleted = and i1 %bput118115_group_grouped_has_deleted, %bput118115_group_grouped_no_previous_deleted
  %bput118115_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bput118115_group_grouped_deleted_bits, i1 false)
  %bput118115_group_grouped_deleted_offset = zext i16 %bput118115_group_grouped_deleted_offset16 to i64
  %bput118115_group_grouped_deleted_unwrapped = add i64 %bput118115_group_grouped_group_start, %bput118115_group_grouped_deleted_offset
  %bput118115_group_grouped_deleted_slot = and i64 %bput118115_group_grouped_deleted_unwrapped, %bput118115_group_grouped_mask
  %bput118115_group_grouped_captured_deleted = select i1 %bput118115_group_grouped_capture_deleted, i64 %bput118115_group_grouped_deleted_slot, i64 %bput118115_group_grouped_first_deleted
  br label %bput118115_group_grouped_candidates
bput118115_group_grouped_candidates:
  %bput118115_group_grouped_candidate_bits = phi i16 [ %bput118115_group_grouped_match_bits, %bput118115_group_grouped_body ], [ %bput118115_group_grouped_cleared_bits, %bput118115_group_grouped_candidate_next ]
  %bput118115_group_grouped_has_candidate = icmp ne i16 %bput118115_group_grouped_candidate_bits, 0
  br i1 %bput118115_group_grouped_has_candidate, label %bput118115_group_grouped_candidate, label %bput118115_group_grouped_decision
bput118115_group_grouped_candidate:
  %bput118115_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bput118115_group_grouped_candidate_bits, i1 false)
  %bput118115_group_grouped_candidate_offset = zext i16 %bput118115_group_grouped_candidate_offset16 to i64
  %bput118115_group_grouped_candidate_unwrapped = add i64 %bput118115_group_grouped_group_start, %bput118115_group_grouped_candidate_offset
  %bput118115_group_grouped_candidate_slot = and i64 %bput118115_group_grouped_candidate_unwrapped, %bput118115_group_grouped_mask
  %bput118115_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bput118115_probe_keys, i64 %bput118115_group_grouped_candidate_slot
  %bput118115_group_grouped_key = load i32, ptr %bput118115_group_grouped_key_ptr, align 4
  %bput118115_group_grouped_candidate_equal = icmp eq i32 %bput118115_group_grouped_key, %bput118115_query
  br i1 %bput118115_group_grouped_candidate_equal, label %bput118115_group_grouped_match, label %bput118115_group_grouped_candidate_next
bput118115_group_grouped_candidate_next:
  %bput118115_group_grouped_bits_minus_one = sub i16 %bput118115_group_grouped_candidate_bits, 1
  %bput118115_group_grouped_cleared_bits = and i16 %bput118115_group_grouped_candidate_bits, %bput118115_group_grouped_bits_minus_one
  br label %bput118115_group_grouped_candidates
bput118115_group_grouped_decision:
  %bput118115_group_grouped_has_empty = icmp ne i16 %bput118115_group_grouped_empty_bits, 0
  br i1 %bput118115_group_grouped_has_empty, label %bput118115_group_grouped_empty, label %bput118115_group_grouped_next_group
bput118115_group_grouped_empty:
  %bput118115_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bput118115_group_grouped_empty_bits, i1 false)
  %bput118115_group_grouped_empty_offset = zext i16 %bput118115_group_grouped_empty_offset16 to i64
  %bput118115_group_grouped_empty_unwrapped = add i64 %bput118115_group_grouped_group_start, %bput118115_group_grouped_empty_offset
  %bput118115_group_grouped_empty_slot = and i64 %bput118115_group_grouped_empty_unwrapped, %bput118115_group_grouped_mask
  %bput118115_group_grouped_use_empty = icmp eq i64 %bput118115_group_grouped_captured_deleted, 16
  %bput118115_group_grouped_insertion_slot = select i1 %bput118115_group_grouped_use_empty, i64 %bput118115_group_grouped_empty_slot, i64 %bput118115_group_grouped_captured_deleted
  br label %bput118115_group_grouped_done
bput118115_group_grouped_match:
  br label %bput118115_group_grouped_done
bput118115_group_grouped_next_group:
  %bput118115_group_grouped_next_probe = add i64 %bput118115_group_grouped_probe, 16
  %bput118115_group_grouped_next_deleted = add i64 %bput118115_group_grouped_captured_deleted, 0
  br label %bput118115_group_grouped_group
bput118115_group_grouped_miss:
  %bput118115_group_grouped_no_deleted = icmp eq i64 %bput118115_group_grouped_first_deleted, 16
  %bput118115_group_grouped_miss_slot = select i1 %bput118115_group_grouped_no_deleted, i64 0, i64 %bput118115_group_grouped_first_deleted
  br label %bput118115_group_grouped_done
bput118115_group_grouped_done:
  %bput118115_group_grouped_found = phi i1 [ false, %bput118115_group_grouped_empty ], [ true, %bput118115_group_grouped_match ], [ false, %bput118115_group_grouped_miss ]
  %bput118115_group_grouped_slot = phi i64 [ %bput118115_group_grouped_insertion_slot, %bput118115_group_grouped_empty ], [ %bput118115_group_grouped_candidate_slot, %bput118115_group_grouped_match ], [ %bput118115_group_grouped_miss_slot, %bput118115_group_grouped_miss ]
  br label %bput118115_group_done
bput118115_group_done:
  %bput118115_group_found = phi i1 [ true, %bput118115_group_match ], [ false, %bput118115_group_vacant ], [ %bput118115_group_grouped_found, %bput118115_group_grouped_done ], [ false, %bput118115_group_no_capacity ]
  %bput118115_group_slot = phi i64 [ %bput118115_group_start, %bput118115_group_match ], [ %bput118115_group_start, %bput118115_group_vacant ], [ %bput118115_group_grouped_slot, %bput118115_group_grouped_done ], [ 0, %bput118115_group_no_capacity ]
  %bput118115_slot = add i64 %bput118115_group_slot, 0
  %bput118115_exists = or i1 %bput118115_group_found, false
  br i1 %bput118115_exists, label %bput118115_update, label %bput118115_insert_check
bput118115_insert_check:
  %bput118115_insert_slot = add i64 %bput118115_slot, 0
  %bput118115_new_length = add i64 %bput118115_old_length, 1
  %bput118115_fits = icmp ule i64 %bput118115_new_length, 2
  br i1 %bput118115_fits, label %bput118115_insert, label %bput118115_full
bput118115_full:
  call void @llvm.trap()
  unreachable
bput118115_update:
  %bput118115_update_value_entry_offset = mul i64 %bput118115_slot, 8
  %bput118115_update_value_entries_field_offset = add i64 32, 4
  %bput118115_update_value_field_offset = add i64 %bput118115_update_value_entry_offset, %bput118115_update_value_entries_field_offset
  %bput118115_update_value_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_update_value_field_offset
  store i32 %bput118115_new_value, ptr %bput118115_update_value_ptr, align 4
  br label %bput118115_complete
bput118115_insert:
  %bput118115_insert_key_entry_offset = mul i64 %bput118115_insert_slot, 8
  %bput118115_insert_key_entries_field_offset = add i64 32, 0
  %bput118115_insert_key_field_offset = add i64 %bput118115_insert_key_entry_offset, %bput118115_insert_key_entries_field_offset
  %bput118115_insert_key_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_insert_key_field_offset
  store i32 %bput118115_query, ptr %bput118115_insert_key_ptr, align 4
  %bput118115_insert_value_entry_offset = mul i64 %bput118115_insert_slot, 8
  %bput118115_insert_value_entries_field_offset = add i64 32, 4
  %bput118115_insert_value_field_offset = add i64 %bput118115_insert_value_entry_offset, %bput118115_insert_value_entries_field_offset
  %bput118115_insert_value_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_insert_value_field_offset
  store i32 %bput118115_new_value, ptr %bput118115_insert_value_ptr, align 4
  %bput118115_insert_control_control_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_insert_slot
  store i8 %bput118115_h2, ptr %bput118115_insert_control_control_ptr, align 1
  %bput118115_insert_control_mirror_needed = icmp ult i64 %bput118115_insert_slot, 16
  %bput118115_insert_control_mirror_candidate = add i64 %bput118115_insert_slot, 16
  %bput118115_insert_control_mirror_slot = select i1 %bput118115_insert_control_mirror_needed, i64 %bput118115_insert_control_mirror_candidate, i64 %bput118115_insert_slot
  %bput118115_insert_control_mirror_ptr = getelementptr i8, ptr %bput118115_storage, i64 %bput118115_insert_control_mirror_slot
  store i8 %bput118115_h2, ptr %bput118115_insert_control_mirror_ptr, align 1
  store i64 %bput118115_new_length, ptr %bput118115_length_ptr, align 8
  br label %bput118115_complete
bput118115_complete:
  %v118123 = load %sollang.bounded_dictionary.t1212, ptr %slot118105, align 8
  %bidx118122_owner = getelementptr i8, ptr %slot118105, i64 0
  %bidx118122_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bidx118122_owner, i32 0, i32 1, i32 0
  %bidx118122_query = freeze i32 1
  %bidx118122_hash_key = sext i32 %bidx118122_query to i64
  %bidx118122_hash_high = lshr i64 %bidx118122_hash_key, 32
  %bidx118122_hash_fold = xor i64 %bidx118122_hash_key, %bidx118122_hash_high
  %bidx118122_hash = mul i64 %bidx118122_hash_fold, -7046029254386353131
  %bidx118122_h2_shifted = lshr i64 %bidx118122_hash, 57
  %bidx118122_h2_raw = and i64 %bidx118122_h2_shifted, 127
  %bidx118122_h2_zero = icmp eq i64 %bidx118122_h2_raw, 0
  %bidx118122_h2_value = select i1 %bidx118122_h2_zero, i64 1, i64 %bidx118122_h2_raw
  %bidx118122_h2 = trunc i64 %bidx118122_h2_value to i8
  %bidx118122_probe_keys = getelementptr i8, ptr %bidx118122_storage, i64 32
  %bidx118122_group_mask = sub i64 16, 1
  %bidx118122_group_start = and i64 %bidx118122_hash, %bidx118122_group_mask
  br label %bidx118122_group_first
bidx118122_group_first:
  %bidx118122_group_control_ptr = getelementptr i8, ptr %bidx118122_storage, i64 %bidx118122_group_start
  %bidx118122_group_control = load i8, ptr %bidx118122_group_control_ptr, align 1
  %bidx118122_group_empty = icmp eq i8 %bidx118122_group_control, 0
  br i1 %bidx118122_group_empty, label %bidx118122_group_vacant, label %bidx118122_group_occupied
bidx118122_group_occupied:
  %bidx118122_group_h2_match = icmp eq i8 %bidx118122_group_control, %bidx118122_h2
  br i1 %bidx118122_group_h2_match, label %bidx118122_group_compare, label %bidx118122_group_fallback
bidx118122_group_compare:
  %bidx118122_group_key_ptr = getelementptr [8 x i8], ptr %bidx118122_probe_keys, i64 %bidx118122_group_start
  %bidx118122_group_key = load i32, ptr %bidx118122_group_key_ptr, align 4
  %bidx118122_group_equal = icmp eq i32 %bidx118122_group_key, %bidx118122_query
  br i1 %bidx118122_group_equal, label %bidx118122_group_match, label %bidx118122_group_fallback
bidx118122_group_match:
  br label %bidx118122_group_done
bidx118122_group_vacant:
  br label %bidx118122_group_done
bidx118122_group_fallback:
  %bidx118122_group_grouped_mask = sub i64 16, 1
  %bidx118122_group_grouped_start = and i64 %bidx118122_hash, %bidx118122_group_grouped_mask
  br label %bidx118122_group_grouped_entry
bidx118122_group_grouped_entry:
  br label %bidx118122_group_grouped_group
bidx118122_group_grouped_group:
  %bidx118122_group_grouped_probe = phi i64 [ 0, %bidx118122_group_grouped_entry ], [ %bidx118122_group_grouped_next_probe, %bidx118122_group_grouped_next_group ]
  %bidx118122_group_grouped_active = icmp ult i64 %bidx118122_group_grouped_probe, 16
  br i1 %bidx118122_group_grouped_active, label %bidx118122_group_grouped_body, label %bidx118122_group_grouped_miss
bidx118122_group_grouped_body:
  %bidx118122_group_grouped_unwrapped = add i64 %bidx118122_group_grouped_start, %bidx118122_group_grouped_probe
  %bidx118122_group_grouped_group_start = and i64 %bidx118122_group_grouped_unwrapped, %bidx118122_group_grouped_mask
  %bidx118122_group_grouped_control_ptr = getelementptr i8, ptr %bidx118122_storage, i64 %bidx118122_group_grouped_group_start
  %bidx118122_group_grouped_controls = load <16 x i8>, ptr %bidx118122_group_grouped_control_ptr, align 1
  %bidx118122_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bidx118122_h2, i64 0
  %bidx118122_group_grouped_h2_vector = shufflevector <16 x i8> %bidx118122_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bidx118122_group_grouped_matches = icmp eq <16 x i8> %bidx118122_group_grouped_controls, %bidx118122_group_grouped_h2_vector
  %bidx118122_group_grouped_match_bits = bitcast <16 x i1> %bidx118122_group_grouped_matches to i16
  %bidx118122_group_grouped_empties = icmp eq <16 x i8> %bidx118122_group_grouped_controls, zeroinitializer
  %bidx118122_group_grouped_empty_bits = bitcast <16 x i1> %bidx118122_group_grouped_empties to i16
  br label %bidx118122_group_grouped_candidates
bidx118122_group_grouped_candidates:
  %bidx118122_group_grouped_candidate_bits = phi i16 [ %bidx118122_group_grouped_match_bits, %bidx118122_group_grouped_body ], [ %bidx118122_group_grouped_cleared_bits, %bidx118122_group_grouped_candidate_next ]
  %bidx118122_group_grouped_has_candidate = icmp ne i16 %bidx118122_group_grouped_candidate_bits, 0
  br i1 %bidx118122_group_grouped_has_candidate, label %bidx118122_group_grouped_candidate, label %bidx118122_group_grouped_decision
bidx118122_group_grouped_candidate:
  %bidx118122_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bidx118122_group_grouped_candidate_bits, i1 false)
  %bidx118122_group_grouped_candidate_offset = zext i16 %bidx118122_group_grouped_candidate_offset16 to i64
  %bidx118122_group_grouped_candidate_unwrapped = add i64 %bidx118122_group_grouped_group_start, %bidx118122_group_grouped_candidate_offset
  %bidx118122_group_grouped_candidate_slot = and i64 %bidx118122_group_grouped_candidate_unwrapped, %bidx118122_group_grouped_mask
  %bidx118122_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bidx118122_probe_keys, i64 %bidx118122_group_grouped_candidate_slot
  %bidx118122_group_grouped_key = load i32, ptr %bidx118122_group_grouped_key_ptr, align 4
  %bidx118122_group_grouped_candidate_equal = icmp eq i32 %bidx118122_group_grouped_key, %bidx118122_query
  br i1 %bidx118122_group_grouped_candidate_equal, label %bidx118122_group_grouped_match, label %bidx118122_group_grouped_candidate_next
bidx118122_group_grouped_candidate_next:
  %bidx118122_group_grouped_bits_minus_one = sub i16 %bidx118122_group_grouped_candidate_bits, 1
  %bidx118122_group_grouped_cleared_bits = and i16 %bidx118122_group_grouped_candidate_bits, %bidx118122_group_grouped_bits_minus_one
  br label %bidx118122_group_grouped_candidates
bidx118122_group_grouped_decision:
  %bidx118122_group_grouped_has_empty = icmp ne i16 %bidx118122_group_grouped_empty_bits, 0
  br i1 %bidx118122_group_grouped_has_empty, label %bidx118122_group_grouped_miss, label %bidx118122_group_grouped_next_group
bidx118122_group_grouped_match:
  br label %bidx118122_group_grouped_done
bidx118122_group_grouped_next_group:
  %bidx118122_group_grouped_next_probe = add i64 %bidx118122_group_grouped_probe, 16
  br label %bidx118122_group_grouped_group
bidx118122_group_grouped_miss:
  br label %bidx118122_group_grouped_done
bidx118122_group_grouped_done:
  %bidx118122_group_grouped_found = phi i1 [ true, %bidx118122_group_grouped_match ], [ false, %bidx118122_group_grouped_miss ]
  %bidx118122_group_grouped_slot = phi i64 [ %bidx118122_group_grouped_candidate_slot, %bidx118122_group_grouped_match ], [ 0, %bidx118122_group_grouped_miss ]
  br label %bidx118122_group_done
bidx118122_group_done:
  %bidx118122_group_found = phi i1 [ true, %bidx118122_group_match ], [ false, %bidx118122_group_vacant ], [ %bidx118122_group_grouped_found, %bidx118122_group_grouped_done ]
  %bidx118122_group_slot = phi i64 [ %bidx118122_group_start, %bidx118122_group_match ], [ 0, %bidx118122_group_vacant ], [ %bidx118122_group_grouped_slot, %bidx118122_group_grouped_done ]
  %bidx118122_slot = add i64 %bidx118122_group_slot, 0
  %bidx118122_exists = or i1 %bidx118122_group_found, false
  br i1 %bidx118122_exists, label %bidx118122_found, label %bidx118122_missing
bidx118122_missing:
  call void @llvm.trap()
  unreachable
bidx118122_found:
  %v118122_value_entry_offset = mul i64 %bidx118122_slot, 8
  %v118122_value_entries_field_offset = add i64 32, 4
  %v118122_value_field_offset = add i64 %v118122_value_entry_offset, %v118122_value_entries_field_offset
  %v118122_value_ptr = getelementptr i8, ptr %bidx118122_storage, i64 %v118122_value_field_offset
  %v118122 = load i32, ptr %v118122_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118122, i1 true)
  %v118126 = load i32, ptr %slot118104, align 4
  %v118125 = add i32 %v118126, 1
  store i32 %v118125, ptr %slot118104, align 4
  %cleanup1181123_b118105_current = load %sollang.bounded_dictionary.t1212, ptr %slot118105, align 8
  call void @sollang_drop_t1212(%sollang.bounded_dictionary.t1212 %cleanup1181123_b118105_current)
  br label %while118112_header
while118112_exit:
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
