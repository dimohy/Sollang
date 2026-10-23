define void @sollang_m144_s0(%sollang.bounded_dictionary.t1212 %arg) {
entry:
  %bidx118116_owner = alloca %sollang.bounded_dictionary.t1212, align 8
  %slot118106 = alloca i32, align 4
  store i32 0, ptr %slot118106, align 4
  br label %while118113_header
while118113_header:
  %while118113_v118111 = load i32, ptr %slot118106, align 4
  %while118113_v118110 = icmp slt i32 %while118113_v118111, 2
  br i1 %while118113_v118110, label %while118113_body, label %while118113_exit
while118113_body:
  store %sollang.bounded_dictionary.t1212 %arg, ptr %bidx118116_owner, align 8
  %bidx118116_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bidx118116_owner, i32 0, i32 1, i32 0
  %bidx118116_query = freeze i32 1
  %bidx118116_hash_key = sext i32 %bidx118116_query to i64
  %bidx118116_hash_high = lshr i64 %bidx118116_hash_key, 32
  %bidx118116_hash_fold = xor i64 %bidx118116_hash_key, %bidx118116_hash_high
  %bidx118116_hash = mul i64 %bidx118116_hash_fold, -7046029254386353131
  %bidx118116_h2_shifted = lshr i64 %bidx118116_hash, 57
  %bidx118116_h2_raw = and i64 %bidx118116_h2_shifted, 127
  %bidx118116_h2_zero = icmp eq i64 %bidx118116_h2_raw, 0
  %bidx118116_h2_value = select i1 %bidx118116_h2_zero, i64 1, i64 %bidx118116_h2_raw
  %bidx118116_h2 = trunc i64 %bidx118116_h2_value to i8
  %bidx118116_probe_keys = getelementptr i8, ptr %bidx118116_storage, i64 32
  %bidx118116_group_mask = sub i64 16, 1
  %bidx118116_group_start = and i64 %bidx118116_hash, %bidx118116_group_mask
  br label %bidx118116_group_first
bidx118116_group_first:
  %bidx118116_group_control_ptr = getelementptr i8, ptr %bidx118116_storage, i64 %bidx118116_group_start
  %bidx118116_group_control = load i8, ptr %bidx118116_group_control_ptr, align 1
  %bidx118116_group_empty = icmp eq i8 %bidx118116_group_control, 0
  br i1 %bidx118116_group_empty, label %bidx118116_group_vacant, label %bidx118116_group_occupied
bidx118116_group_occupied:
  %bidx118116_group_h2_match = icmp eq i8 %bidx118116_group_control, %bidx118116_h2
  br i1 %bidx118116_group_h2_match, label %bidx118116_group_compare, label %bidx118116_group_fallback
bidx118116_group_compare:
  %bidx118116_group_key_ptr = getelementptr [8 x i8], ptr %bidx118116_probe_keys, i64 %bidx118116_group_start
  %bidx118116_group_key = load i32, ptr %bidx118116_group_key_ptr, align 4
  %bidx118116_group_equal = icmp eq i32 %bidx118116_group_key, %bidx118116_query
  br i1 %bidx118116_group_equal, label %bidx118116_group_match, label %bidx118116_group_fallback
bidx118116_group_match:
  br label %bidx118116_group_done
bidx118116_group_vacant:
  br label %bidx118116_group_done
bidx118116_group_fallback:
  %bidx118116_group_grouped_mask = sub i64 16, 1
  %bidx118116_group_grouped_start = and i64 %bidx118116_hash, %bidx118116_group_grouped_mask
  br label %bidx118116_group_grouped_entry
bidx118116_group_grouped_entry:
  br label %bidx118116_group_grouped_group
bidx118116_group_grouped_group:
  %bidx118116_group_grouped_probe = phi i64 [ 0, %bidx118116_group_grouped_entry ], [ %bidx118116_group_grouped_next_probe, %bidx118116_group_grouped_next_group ]
  %bidx118116_group_grouped_active = icmp ult i64 %bidx118116_group_grouped_probe, 16
  br i1 %bidx118116_group_grouped_active, label %bidx118116_group_grouped_body, label %bidx118116_group_grouped_miss
bidx118116_group_grouped_body:
  %bidx118116_group_grouped_unwrapped = add i64 %bidx118116_group_grouped_start, %bidx118116_group_grouped_probe
  %bidx118116_group_grouped_group_start = and i64 %bidx118116_group_grouped_unwrapped, %bidx118116_group_grouped_mask
  %bidx118116_group_grouped_control_ptr = getelementptr i8, ptr %bidx118116_storage, i64 %bidx118116_group_grouped_group_start
  %bidx118116_group_grouped_controls = load <16 x i8>, ptr %bidx118116_group_grouped_control_ptr, align 1
  %bidx118116_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bidx118116_h2, i64 0
  %bidx118116_group_grouped_h2_vector = shufflevector <16 x i8> %bidx118116_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bidx118116_group_grouped_matches = icmp eq <16 x i8> %bidx118116_group_grouped_controls, %bidx118116_group_grouped_h2_vector
  %bidx118116_group_grouped_match_bits = bitcast <16 x i1> %bidx118116_group_grouped_matches to i16
  %bidx118116_group_grouped_empties = icmp eq <16 x i8> %bidx118116_group_grouped_controls, zeroinitializer
  %bidx118116_group_grouped_empty_bits = bitcast <16 x i1> %bidx118116_group_grouped_empties to i16
  br label %bidx118116_group_grouped_candidates
bidx118116_group_grouped_candidates:
  %bidx118116_group_grouped_candidate_bits = phi i16 [ %bidx118116_group_grouped_match_bits, %bidx118116_group_grouped_body ], [ %bidx118116_group_grouped_cleared_bits, %bidx118116_group_grouped_candidate_next ]
  %bidx118116_group_grouped_has_candidate = icmp ne i16 %bidx118116_group_grouped_candidate_bits, 0
  br i1 %bidx118116_group_grouped_has_candidate, label %bidx118116_group_grouped_candidate, label %bidx118116_group_grouped_decision
bidx118116_group_grouped_candidate:
  %bidx118116_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bidx118116_group_grouped_candidate_bits, i1 false)
  %bidx118116_group_grouped_candidate_offset = zext i16 %bidx118116_group_grouped_candidate_offset16 to i64
  %bidx118116_group_grouped_candidate_unwrapped = add i64 %bidx118116_group_grouped_group_start, %bidx118116_group_grouped_candidate_offset
  %bidx118116_group_grouped_candidate_slot = and i64 %bidx118116_group_grouped_candidate_unwrapped, %bidx118116_group_grouped_mask
  %bidx118116_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bidx118116_probe_keys, i64 %bidx118116_group_grouped_candidate_slot
  %bidx118116_group_grouped_key = load i32, ptr %bidx118116_group_grouped_key_ptr, align 4
  %bidx118116_group_grouped_candidate_equal = icmp eq i32 %bidx118116_group_grouped_key, %bidx118116_query
  br i1 %bidx118116_group_grouped_candidate_equal, label %bidx118116_group_grouped_match, label %bidx118116_group_grouped_candidate_next
bidx118116_group_grouped_candidate_next:
  %bidx118116_group_grouped_bits_minus_one = sub i16 %bidx118116_group_grouped_candidate_bits, 1
  %bidx118116_group_grouped_cleared_bits = and i16 %bidx118116_group_grouped_candidate_bits, %bidx118116_group_grouped_bits_minus_one
  br label %bidx118116_group_grouped_candidates
bidx118116_group_grouped_decision:
  %bidx118116_group_grouped_has_empty = icmp ne i16 %bidx118116_group_grouped_empty_bits, 0
  br i1 %bidx118116_group_grouped_has_empty, label %bidx118116_group_grouped_miss, label %bidx118116_group_grouped_next_group
bidx118116_group_grouped_match:
  br label %bidx118116_group_grouped_done
bidx118116_group_grouped_next_group:
  %bidx118116_group_grouped_next_probe = add i64 %bidx118116_group_grouped_probe, 16
  br label %bidx118116_group_grouped_group
bidx118116_group_grouped_miss:
  br label %bidx118116_group_grouped_done
bidx118116_group_grouped_done:
  %bidx118116_group_grouped_found = phi i1 [ true, %bidx118116_group_grouped_match ], [ false, %bidx118116_group_grouped_miss ]
  %bidx118116_group_grouped_slot = phi i64 [ %bidx118116_group_grouped_candidate_slot, %bidx118116_group_grouped_match ], [ 0, %bidx118116_group_grouped_miss ]
  br label %bidx118116_group_done
bidx118116_group_done:
  %bidx118116_group_found = phi i1 [ true, %bidx118116_group_match ], [ false, %bidx118116_group_vacant ], [ %bidx118116_group_grouped_found, %bidx118116_group_grouped_done ]
  %bidx118116_group_slot = phi i64 [ %bidx118116_group_start, %bidx118116_group_match ], [ 0, %bidx118116_group_vacant ], [ %bidx118116_group_grouped_slot, %bidx118116_group_grouped_done ]
  %bidx118116_slot = add i64 %bidx118116_group_slot, 0
  %bidx118116_exists = or i1 %bidx118116_group_found, false
  br i1 %bidx118116_exists, label %bidx118116_found, label %bidx118116_missing
bidx118116_missing:
  call void @llvm.trap()
  unreachable
bidx118116_found:
  %v118116_value_entry_offset = mul i64 %bidx118116_slot, 8
  %v118116_value_entries_field_offset = add i64 32, 4
  %v118116_value_field_offset = add i64 %v118116_value_entry_offset, %v118116_value_entries_field_offset
  %v118116_value_ptr = getelementptr i8, ptr %bidx118116_storage, i64 %v118116_value_field_offset
  %v118116 = load i32, ptr %v118116_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118116, i1 true)
  %v118120 = load i32, ptr %slot118106, align 4
  %v118119 = add i32 %v118120, 1
  store i32 %v118119, ptr %slot118106, align 4
  br label %while118113_header
while118113_exit:
  ret void
}

define void @sollang_m144_s3(ptr %arg) {
entry:
  %slot118125 = alloca i32, align 4
  store i32 0, ptr %slot118125, align 4
  br label %while118132_header
while118132_header:
  %while118132_v118130 = load i32, ptr %slot118125, align 4
  %while118132_v118129 = icmp slt i32 %while118132_v118130, 2
  br i1 %while118132_v118129, label %while118132_body, label %while118132_exit
while118132_body:
  %v118136 = load %sollang.bounded_dictionary.t1212, ptr %arg, align 8
  %bidx118135_owner = freeze ptr %arg
  %bidx118135_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bidx118135_owner, i32 0, i32 1, i32 0
  %bidx118135_query = freeze i32 1
  %bidx118135_hash_key = sext i32 %bidx118135_query to i64
  %bidx118135_hash_high = lshr i64 %bidx118135_hash_key, 32
  %bidx118135_hash_fold = xor i64 %bidx118135_hash_key, %bidx118135_hash_high
  %bidx118135_hash = mul i64 %bidx118135_hash_fold, -7046029254386353131
  %bidx118135_h2_shifted = lshr i64 %bidx118135_hash, 57
  %bidx118135_h2_raw = and i64 %bidx118135_h2_shifted, 127
  %bidx118135_h2_zero = icmp eq i64 %bidx118135_h2_raw, 0
  %bidx118135_h2_value = select i1 %bidx118135_h2_zero, i64 1, i64 %bidx118135_h2_raw
  %bidx118135_h2 = trunc i64 %bidx118135_h2_value to i8
  %bidx118135_probe_keys = getelementptr i8, ptr %bidx118135_storage, i64 32
  %bidx118135_group_mask = sub i64 16, 1
  %bidx118135_group_start = and i64 %bidx118135_hash, %bidx118135_group_mask
  br label %bidx118135_group_first
bidx118135_group_first:
  %bidx118135_group_control_ptr = getelementptr i8, ptr %bidx118135_storage, i64 %bidx118135_group_start
  %bidx118135_group_control = load i8, ptr %bidx118135_group_control_ptr, align 1
  %bidx118135_group_empty = icmp eq i8 %bidx118135_group_control, 0
  br i1 %bidx118135_group_empty, label %bidx118135_group_vacant, label %bidx118135_group_occupied
bidx118135_group_occupied:
  %bidx118135_group_h2_match = icmp eq i8 %bidx118135_group_control, %bidx118135_h2
  br i1 %bidx118135_group_h2_match, label %bidx118135_group_compare, label %bidx118135_group_fallback
bidx118135_group_compare:
  %bidx118135_group_key_ptr = getelementptr [8 x i8], ptr %bidx118135_probe_keys, i64 %bidx118135_group_start
  %bidx118135_group_key = load i32, ptr %bidx118135_group_key_ptr, align 4
  %bidx118135_group_equal = icmp eq i32 %bidx118135_group_key, %bidx118135_query
  br i1 %bidx118135_group_equal, label %bidx118135_group_match, label %bidx118135_group_fallback
bidx118135_group_match:
  br label %bidx118135_group_done
bidx118135_group_vacant:
  br label %bidx118135_group_done
bidx118135_group_fallback:
  %bidx118135_group_grouped_mask = sub i64 16, 1
  %bidx118135_group_grouped_start = and i64 %bidx118135_hash, %bidx118135_group_grouped_mask
  br label %bidx118135_group_grouped_entry
bidx118135_group_grouped_entry:
  br label %bidx118135_group_grouped_group
bidx118135_group_grouped_group:
  %bidx118135_group_grouped_probe = phi i64 [ 0, %bidx118135_group_grouped_entry ], [ %bidx118135_group_grouped_next_probe, %bidx118135_group_grouped_next_group ]
  %bidx118135_group_grouped_active = icmp ult i64 %bidx118135_group_grouped_probe, 16
  br i1 %bidx118135_group_grouped_active, label %bidx118135_group_grouped_body, label %bidx118135_group_grouped_miss
bidx118135_group_grouped_body:
  %bidx118135_group_grouped_unwrapped = add i64 %bidx118135_group_grouped_start, %bidx118135_group_grouped_probe
  %bidx118135_group_grouped_group_start = and i64 %bidx118135_group_grouped_unwrapped, %bidx118135_group_grouped_mask
  %bidx118135_group_grouped_control_ptr = getelementptr i8, ptr %bidx118135_storage, i64 %bidx118135_group_grouped_group_start
  %bidx118135_group_grouped_controls = load <16 x i8>, ptr %bidx118135_group_grouped_control_ptr, align 1
  %bidx118135_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bidx118135_h2, i64 0
  %bidx118135_group_grouped_h2_vector = shufflevector <16 x i8> %bidx118135_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bidx118135_group_grouped_matches = icmp eq <16 x i8> %bidx118135_group_grouped_controls, %bidx118135_group_grouped_h2_vector
  %bidx118135_group_grouped_match_bits = bitcast <16 x i1> %bidx118135_group_grouped_matches to i16
  %bidx118135_group_grouped_empties = icmp eq <16 x i8> %bidx118135_group_grouped_controls, zeroinitializer
  %bidx118135_group_grouped_empty_bits = bitcast <16 x i1> %bidx118135_group_grouped_empties to i16
  br label %bidx118135_group_grouped_candidates
bidx118135_group_grouped_candidates:
  %bidx118135_group_grouped_candidate_bits = phi i16 [ %bidx118135_group_grouped_match_bits, %bidx118135_group_grouped_body ], [ %bidx118135_group_grouped_cleared_bits, %bidx118135_group_grouped_candidate_next ]
  %bidx118135_group_grouped_has_candidate = icmp ne i16 %bidx118135_group_grouped_candidate_bits, 0
  br i1 %bidx118135_group_grouped_has_candidate, label %bidx118135_group_grouped_candidate, label %bidx118135_group_grouped_decision
bidx118135_group_grouped_candidate:
  %bidx118135_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bidx118135_group_grouped_candidate_bits, i1 false)
  %bidx118135_group_grouped_candidate_offset = zext i16 %bidx118135_group_grouped_candidate_offset16 to i64
  %bidx118135_group_grouped_candidate_unwrapped = add i64 %bidx118135_group_grouped_group_start, %bidx118135_group_grouped_candidate_offset
  %bidx118135_group_grouped_candidate_slot = and i64 %bidx118135_group_grouped_candidate_unwrapped, %bidx118135_group_grouped_mask
  %bidx118135_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bidx118135_probe_keys, i64 %bidx118135_group_grouped_candidate_slot
  %bidx118135_group_grouped_key = load i32, ptr %bidx118135_group_grouped_key_ptr, align 4
  %bidx118135_group_grouped_candidate_equal = icmp eq i32 %bidx118135_group_grouped_key, %bidx118135_query
  br i1 %bidx118135_group_grouped_candidate_equal, label %bidx118135_group_grouped_match, label %bidx118135_group_grouped_candidate_next
bidx118135_group_grouped_candidate_next:
  %bidx118135_group_grouped_bits_minus_one = sub i16 %bidx118135_group_grouped_candidate_bits, 1
  %bidx118135_group_grouped_cleared_bits = and i16 %bidx118135_group_grouped_candidate_bits, %bidx118135_group_grouped_bits_minus_one
  br label %bidx118135_group_grouped_candidates
bidx118135_group_grouped_decision:
  %bidx118135_group_grouped_has_empty = icmp ne i16 %bidx118135_group_grouped_empty_bits, 0
  br i1 %bidx118135_group_grouped_has_empty, label %bidx118135_group_grouped_miss, label %bidx118135_group_grouped_next_group
bidx118135_group_grouped_match:
  br label %bidx118135_group_grouped_done
bidx118135_group_grouped_next_group:
  %bidx118135_group_grouped_next_probe = add i64 %bidx118135_group_grouped_probe, 16
  br label %bidx118135_group_grouped_group
bidx118135_group_grouped_miss:
  br label %bidx118135_group_grouped_done
bidx118135_group_grouped_done:
  %bidx118135_group_grouped_found = phi i1 [ true, %bidx118135_group_grouped_match ], [ false, %bidx118135_group_grouped_miss ]
  %bidx118135_group_grouped_slot = phi i64 [ %bidx118135_group_grouped_candidate_slot, %bidx118135_group_grouped_match ], [ 0, %bidx118135_group_grouped_miss ]
  br label %bidx118135_group_done
bidx118135_group_done:
  %bidx118135_group_found = phi i1 [ true, %bidx118135_group_match ], [ false, %bidx118135_group_vacant ], [ %bidx118135_group_grouped_found, %bidx118135_group_grouped_done ]
  %bidx118135_group_slot = phi i64 [ %bidx118135_group_start, %bidx118135_group_match ], [ 0, %bidx118135_group_vacant ], [ %bidx118135_group_grouped_slot, %bidx118135_group_grouped_done ]
  %bidx118135_slot = add i64 %bidx118135_group_slot, 0
  %bidx118135_exists = or i1 %bidx118135_group_found, false
  br i1 %bidx118135_exists, label %bidx118135_found, label %bidx118135_missing
bidx118135_missing:
  call void @llvm.trap()
  unreachable
bidx118135_found:
  %v118135_value_entry_offset = mul i64 %bidx118135_slot, 8
  %v118135_value_entries_field_offset = add i64 32, 4
  %v118135_value_field_offset = add i64 %v118135_value_entry_offset, %v118135_value_entries_field_offset
  %v118135_value_ptr = getelementptr i8, ptr %bidx118135_storage, i64 %v118135_value_field_offset
  %v118135 = load i32, ptr %v118135_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118135, i1 true)
  %v118139 = load i32, ptr %slot118125, align 4
  %v118138 = add i32 %v118139, 1
  store i32 %v118138, ptr %slot118125, align 4
  br label %while118132_header
while118132_exit:
  ret void
}

define i32 @main() {
entry:
  %v118146_owner = alloca %sollang.bounded_dictionary.t1212, align 8
  %v118153_owner = alloca %sollang.bounded_dictionary.t1212, align 8
  %callref118151_arg0 = alloca %sollang.bounded_dictionary.t1212, align 8
  %slot118143 = alloca %sollang.bounded_dictionary.t1212, align 8
  %slot118144 = alloca i32, align 4
  store %sollang.bounded_dictionary.t1212 zeroinitializer, ptr %v118146_owner, align 8
  %v118146_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118146_owner, i32 0, i32 1, i32 0
  %bd118146_0_key_operand = add i32 0, 1
  %bd118146_0_value_operand = add i32 0, 10
  %bd118146_0_hash_key = sext i32 %bd118146_0_key_operand to i64
  %bd118146_0_hash_high = lshr i64 %bd118146_0_hash_key, 32
  %bd118146_0_hash_fold = xor i64 %bd118146_0_hash_key, %bd118146_0_hash_high
  %bd118146_0_hash = mul i64 %bd118146_0_hash_fold, -7046029254386353131
  %bd118146_0_h2_shifted = lshr i64 %bd118146_0_hash, 57
  %bd118146_0_h2_raw = and i64 %bd118146_0_h2_shifted, 127
  %bd118146_0_h2_zero = icmp eq i64 %bd118146_0_h2_raw, 0
  %bd118146_0_h2_value = select i1 %bd118146_0_h2_zero, i64 1, i64 %bd118146_0_h2_raw
  %bd118146_0_h2 = trunc i64 %bd118146_0_h2_value to i8
  %bd118146_0_probe_keys = getelementptr i8, ptr %v118146_storage, i64 32
  %bd118146_0_group_mask = sub i64 16, 1
  %bd118146_0_group_start = and i64 %bd118146_0_hash, %bd118146_0_group_mask
  %bd118146_0_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bd118146_0_group_has_capacity, label %bd118146_0_group_first, label %bd118146_0_group_no_capacity
bd118146_0_group_no_capacity:
  br label %bd118146_0_group_done
bd118146_0_group_first:
  %bd118146_0_group_control_ptr = getelementptr i8, ptr %v118146_storage, i64 %bd118146_0_group_start
  %bd118146_0_group_control = load i8, ptr %bd118146_0_group_control_ptr, align 1
  %bd118146_0_group_empty = icmp eq i8 %bd118146_0_group_control, 0
  br i1 %bd118146_0_group_empty, label %bd118146_0_group_vacant, label %bd118146_0_group_occupied
bd118146_0_group_occupied:
  %bd118146_0_group_h2_match = icmp eq i8 %bd118146_0_group_control, %bd118146_0_h2
  br i1 %bd118146_0_group_h2_match, label %bd118146_0_group_compare, label %bd118146_0_group_fallback
bd118146_0_group_compare:
  %bd118146_0_group_key_ptr = getelementptr [8 x i8], ptr %bd118146_0_probe_keys, i64 %bd118146_0_group_start
  %bd118146_0_group_key = load i32, ptr %bd118146_0_group_key_ptr, align 4
  %bd118146_0_group_equal = icmp eq i32 %bd118146_0_group_key, %bd118146_0_key_operand
  br i1 %bd118146_0_group_equal, label %bd118146_0_group_match, label %bd118146_0_group_fallback
bd118146_0_group_match:
  br label %bd118146_0_group_done
bd118146_0_group_vacant:
  br label %bd118146_0_group_done
bd118146_0_group_fallback:
  %bd118146_0_group_grouped_mask = sub i64 16, 1
  %bd118146_0_group_grouped_start = and i64 %bd118146_0_hash, %bd118146_0_group_grouped_mask
  br label %bd118146_0_group_grouped_entry
bd118146_0_group_grouped_entry:
  br label %bd118146_0_group_grouped_group
bd118146_0_group_grouped_group:
  %bd118146_0_group_grouped_probe = phi i64 [ 0, %bd118146_0_group_grouped_entry ], [ %bd118146_0_group_grouped_next_probe, %bd118146_0_group_grouped_next_group ]
  %bd118146_0_group_grouped_first_deleted = phi i64 [ 16, %bd118146_0_group_grouped_entry ], [ %bd118146_0_group_grouped_next_deleted, %bd118146_0_group_grouped_next_group ]
  %bd118146_0_group_grouped_active = icmp ult i64 %bd118146_0_group_grouped_probe, 16
  br i1 %bd118146_0_group_grouped_active, label %bd118146_0_group_grouped_body, label %bd118146_0_group_grouped_miss
bd118146_0_group_grouped_body:
  %bd118146_0_group_grouped_unwrapped = add i64 %bd118146_0_group_grouped_start, %bd118146_0_group_grouped_probe
  %bd118146_0_group_grouped_group_start = and i64 %bd118146_0_group_grouped_unwrapped, %bd118146_0_group_grouped_mask
  %bd118146_0_group_grouped_control_ptr = getelementptr i8, ptr %v118146_storage, i64 %bd118146_0_group_grouped_group_start
  %bd118146_0_group_grouped_controls = load <16 x i8>, ptr %bd118146_0_group_grouped_control_ptr, align 1
  %bd118146_0_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bd118146_0_h2, i64 0
  %bd118146_0_group_grouped_h2_vector = shufflevector <16 x i8> %bd118146_0_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118146_0_group_grouped_matches = icmp eq <16 x i8> %bd118146_0_group_grouped_controls, %bd118146_0_group_grouped_h2_vector
  %bd118146_0_group_grouped_match_bits = bitcast <16 x i1> %bd118146_0_group_grouped_matches to i16
  %bd118146_0_group_grouped_empties = icmp eq <16 x i8> %bd118146_0_group_grouped_controls, zeroinitializer
  %bd118146_0_group_grouped_empty_bits = bitcast <16 x i1> %bd118146_0_group_grouped_empties to i16
  %bd118146_0_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bd118146_0_group_grouped_deleted_vector = shufflevector <16 x i8> %bd118146_0_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118146_0_group_grouped_deleted_matches = icmp eq <16 x i8> %bd118146_0_group_grouped_controls, %bd118146_0_group_grouped_deleted_vector
  %bd118146_0_group_grouped_deleted_bits = bitcast <16 x i1> %bd118146_0_group_grouped_deleted_matches to i16
  %bd118146_0_group_grouped_has_deleted = icmp ne i16 %bd118146_0_group_grouped_deleted_bits, 0
  %bd118146_0_group_grouped_no_previous_deleted = icmp eq i64 %bd118146_0_group_grouped_first_deleted, 16
  %bd118146_0_group_grouped_capture_deleted = and i1 %bd118146_0_group_grouped_has_deleted, %bd118146_0_group_grouped_no_previous_deleted
  %bd118146_0_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bd118146_0_group_grouped_deleted_bits, i1 false)
  %bd118146_0_group_grouped_deleted_offset = zext i16 %bd118146_0_group_grouped_deleted_offset16 to i64
  %bd118146_0_group_grouped_deleted_unwrapped = add i64 %bd118146_0_group_grouped_group_start, %bd118146_0_group_grouped_deleted_offset
  %bd118146_0_group_grouped_deleted_slot = and i64 %bd118146_0_group_grouped_deleted_unwrapped, %bd118146_0_group_grouped_mask
  %bd118146_0_group_grouped_captured_deleted = select i1 %bd118146_0_group_grouped_capture_deleted, i64 %bd118146_0_group_grouped_deleted_slot, i64 %bd118146_0_group_grouped_first_deleted
  br label %bd118146_0_group_grouped_candidates
bd118146_0_group_grouped_candidates:
  %bd118146_0_group_grouped_candidate_bits = phi i16 [ %bd118146_0_group_grouped_match_bits, %bd118146_0_group_grouped_body ], [ %bd118146_0_group_grouped_cleared_bits, %bd118146_0_group_grouped_candidate_next ]
  %bd118146_0_group_grouped_has_candidate = icmp ne i16 %bd118146_0_group_grouped_candidate_bits, 0
  br i1 %bd118146_0_group_grouped_has_candidate, label %bd118146_0_group_grouped_candidate, label %bd118146_0_group_grouped_decision
bd118146_0_group_grouped_candidate:
  %bd118146_0_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bd118146_0_group_grouped_candidate_bits, i1 false)
  %bd118146_0_group_grouped_candidate_offset = zext i16 %bd118146_0_group_grouped_candidate_offset16 to i64
  %bd118146_0_group_grouped_candidate_unwrapped = add i64 %bd118146_0_group_grouped_group_start, %bd118146_0_group_grouped_candidate_offset
  %bd118146_0_group_grouped_candidate_slot = and i64 %bd118146_0_group_grouped_candidate_unwrapped, %bd118146_0_group_grouped_mask
  %bd118146_0_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bd118146_0_probe_keys, i64 %bd118146_0_group_grouped_candidate_slot
  %bd118146_0_group_grouped_key = load i32, ptr %bd118146_0_group_grouped_key_ptr, align 4
  %bd118146_0_group_grouped_candidate_equal = icmp eq i32 %bd118146_0_group_grouped_key, %bd118146_0_key_operand
  br i1 %bd118146_0_group_grouped_candidate_equal, label %bd118146_0_group_grouped_match, label %bd118146_0_group_grouped_candidate_next
bd118146_0_group_grouped_candidate_next:
  %bd118146_0_group_grouped_bits_minus_one = sub i16 %bd118146_0_group_grouped_candidate_bits, 1
  %bd118146_0_group_grouped_cleared_bits = and i16 %bd118146_0_group_grouped_candidate_bits, %bd118146_0_group_grouped_bits_minus_one
  br label %bd118146_0_group_grouped_candidates
bd118146_0_group_grouped_decision:
  %bd118146_0_group_grouped_has_empty = icmp ne i16 %bd118146_0_group_grouped_empty_bits, 0
  br i1 %bd118146_0_group_grouped_has_empty, label %bd118146_0_group_grouped_empty, label %bd118146_0_group_grouped_next_group
bd118146_0_group_grouped_empty:
  %bd118146_0_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bd118146_0_group_grouped_empty_bits, i1 false)
  %bd118146_0_group_grouped_empty_offset = zext i16 %bd118146_0_group_grouped_empty_offset16 to i64
  %bd118146_0_group_grouped_empty_unwrapped = add i64 %bd118146_0_group_grouped_group_start, %bd118146_0_group_grouped_empty_offset
  %bd118146_0_group_grouped_empty_slot = and i64 %bd118146_0_group_grouped_empty_unwrapped, %bd118146_0_group_grouped_mask
  %bd118146_0_group_grouped_use_empty = icmp eq i64 %bd118146_0_group_grouped_captured_deleted, 16
  %bd118146_0_group_grouped_insertion_slot = select i1 %bd118146_0_group_grouped_use_empty, i64 %bd118146_0_group_grouped_empty_slot, i64 %bd118146_0_group_grouped_captured_deleted
  br label %bd118146_0_group_grouped_done
bd118146_0_group_grouped_match:
  br label %bd118146_0_group_grouped_done
bd118146_0_group_grouped_next_group:
  %bd118146_0_group_grouped_next_probe = add i64 %bd118146_0_group_grouped_probe, 16
  %bd118146_0_group_grouped_next_deleted = add i64 %bd118146_0_group_grouped_captured_deleted, 0
  br label %bd118146_0_group_grouped_group
bd118146_0_group_grouped_miss:
  %bd118146_0_group_grouped_no_deleted = icmp eq i64 %bd118146_0_group_grouped_first_deleted, 16
  %bd118146_0_group_grouped_miss_slot = select i1 %bd118146_0_group_grouped_no_deleted, i64 0, i64 %bd118146_0_group_grouped_first_deleted
  br label %bd118146_0_group_grouped_done
bd118146_0_group_grouped_done:
  %bd118146_0_group_grouped_found = phi i1 [ false, %bd118146_0_group_grouped_empty ], [ true, %bd118146_0_group_grouped_match ], [ false, %bd118146_0_group_grouped_miss ]
  %bd118146_0_group_grouped_slot = phi i64 [ %bd118146_0_group_grouped_insertion_slot, %bd118146_0_group_grouped_empty ], [ %bd118146_0_group_grouped_candidate_slot, %bd118146_0_group_grouped_match ], [ %bd118146_0_group_grouped_miss_slot, %bd118146_0_group_grouped_miss ]
  br label %bd118146_0_group_done
bd118146_0_group_done:
  %bd118146_0_group_found = phi i1 [ true, %bd118146_0_group_match ], [ false, %bd118146_0_group_vacant ], [ %bd118146_0_group_grouped_found, %bd118146_0_group_grouped_done ], [ false, %bd118146_0_group_no_capacity ]
  %bd118146_0_group_slot = phi i64 [ %bd118146_0_group_start, %bd118146_0_group_match ], [ %bd118146_0_group_start, %bd118146_0_group_vacant ], [ %bd118146_0_group_grouped_slot, %bd118146_0_group_grouped_done ], [ 0, %bd118146_0_group_no_capacity ]
  %bd118146_0_slot = add i64 %bd118146_0_group_slot, 0
  %bd118146_0_exists = or i1 %bd118146_0_group_found, false
  br label %bd118146_0_insert
bd118146_0_insert:
  %bd118146_0_key_entry_offset = mul i64 %bd118146_0_slot, 8
  %bd118146_0_key_entries_field_offset = add i64 32, 0
  %bd118146_0_key_field_offset = add i64 %bd118146_0_key_entry_offset, %bd118146_0_key_entries_field_offset
  %bd118146_0_key_ptr = getelementptr i8, ptr %v118146_storage, i64 %bd118146_0_key_field_offset
  store i32 %bd118146_0_key_operand, ptr %bd118146_0_key_ptr, align 4
  %bd118146_0_value_entry_offset = mul i64 %bd118146_0_slot, 8
  %bd118146_0_value_entries_field_offset = add i64 32, 4
  %bd118146_0_value_field_offset = add i64 %bd118146_0_value_entry_offset, %bd118146_0_value_entries_field_offset
  %bd118146_0_value_ptr = getelementptr i8, ptr %v118146_storage, i64 %bd118146_0_value_field_offset
  store i32 %bd118146_0_value_operand, ptr %bd118146_0_value_ptr, align 4
  %bd118146_0_control_control_ptr = getelementptr i8, ptr %v118146_storage, i64 %bd118146_0_slot
  store i8 %bd118146_0_h2, ptr %bd118146_0_control_control_ptr, align 1
  %bd118146_0_control_mirror_needed = icmp ult i64 %bd118146_0_slot, 16
  %bd118146_0_control_mirror_candidate = add i64 %bd118146_0_slot, 16
  %bd118146_0_control_mirror_slot = select i1 %bd118146_0_control_mirror_needed, i64 %bd118146_0_control_mirror_candidate, i64 %bd118146_0_slot
  %bd118146_0_control_mirror_ptr = getelementptr i8, ptr %v118146_storage, i64 %bd118146_0_control_mirror_slot
  store i8 %bd118146_0_h2, ptr %bd118146_0_control_mirror_ptr, align 1
  %v118146_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118146_owner, i32 0, i32 0
  store i64 1, ptr %v118146_length_ptr, align 8
  %v118146 = load %sollang.bounded_dictionary.t1212, ptr %v118146_owner, align 8
  store %sollang.bounded_dictionary.t1212 zeroinitializer, ptr %v118153_owner, align 8
  %v118153_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118153_owner, i32 0, i32 1, i32 0
  %bd118153_0_key_operand = add i32 0, 1
  %bd118153_0_value_operand = add i32 0, 20
  %bd118153_0_hash_key = sext i32 %bd118153_0_key_operand to i64
  %bd118153_0_hash_high = lshr i64 %bd118153_0_hash_key, 32
  %bd118153_0_hash_fold = xor i64 %bd118153_0_hash_key, %bd118153_0_hash_high
  %bd118153_0_hash = mul i64 %bd118153_0_hash_fold, -7046029254386353131
  %bd118153_0_h2_shifted = lshr i64 %bd118153_0_hash, 57
  %bd118153_0_h2_raw = and i64 %bd118153_0_h2_shifted, 127
  %bd118153_0_h2_zero = icmp eq i64 %bd118153_0_h2_raw, 0
  %bd118153_0_h2_value = select i1 %bd118153_0_h2_zero, i64 1, i64 %bd118153_0_h2_raw
  %bd118153_0_h2 = trunc i64 %bd118153_0_h2_value to i8
  %bd118153_0_probe_keys = getelementptr i8, ptr %v118153_storage, i64 32
  %bd118153_0_group_mask = sub i64 16, 1
  %bd118153_0_group_start = and i64 %bd118153_0_hash, %bd118153_0_group_mask
  %bd118153_0_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bd118153_0_group_has_capacity, label %bd118153_0_group_first, label %bd118153_0_group_no_capacity
bd118153_0_group_no_capacity:
  br label %bd118153_0_group_done
bd118153_0_group_first:
  %bd118153_0_group_control_ptr = getelementptr i8, ptr %v118153_storage, i64 %bd118153_0_group_start
  %bd118153_0_group_control = load i8, ptr %bd118153_0_group_control_ptr, align 1
  %bd118153_0_group_empty = icmp eq i8 %bd118153_0_group_control, 0
  br i1 %bd118153_0_group_empty, label %bd118153_0_group_vacant, label %bd118153_0_group_occupied
bd118153_0_group_occupied:
  %bd118153_0_group_h2_match = icmp eq i8 %bd118153_0_group_control, %bd118153_0_h2
  br i1 %bd118153_0_group_h2_match, label %bd118153_0_group_compare, label %bd118153_0_group_fallback
bd118153_0_group_compare:
  %bd118153_0_group_key_ptr = getelementptr [8 x i8], ptr %bd118153_0_probe_keys, i64 %bd118153_0_group_start
  %bd118153_0_group_key = load i32, ptr %bd118153_0_group_key_ptr, align 4
  %bd118153_0_group_equal = icmp eq i32 %bd118153_0_group_key, %bd118153_0_key_operand
  br i1 %bd118153_0_group_equal, label %bd118153_0_group_match, label %bd118153_0_group_fallback
bd118153_0_group_match:
  br label %bd118153_0_group_done
bd118153_0_group_vacant:
  br label %bd118153_0_group_done
bd118153_0_group_fallback:
  %bd118153_0_group_grouped_mask = sub i64 16, 1
  %bd118153_0_group_grouped_start = and i64 %bd118153_0_hash, %bd118153_0_group_grouped_mask
  br label %bd118153_0_group_grouped_entry
bd118153_0_group_grouped_entry:
  br label %bd118153_0_group_grouped_group
bd118153_0_group_grouped_group:
  %bd118153_0_group_grouped_probe = phi i64 [ 0, %bd118153_0_group_grouped_entry ], [ %bd118153_0_group_grouped_next_probe, %bd118153_0_group_grouped_next_group ]
  %bd118153_0_group_grouped_first_deleted = phi i64 [ 16, %bd118153_0_group_grouped_entry ], [ %bd118153_0_group_grouped_next_deleted, %bd118153_0_group_grouped_next_group ]
  %bd118153_0_group_grouped_active = icmp ult i64 %bd118153_0_group_grouped_probe, 16
  br i1 %bd118153_0_group_grouped_active, label %bd118153_0_group_grouped_body, label %bd118153_0_group_grouped_miss
bd118153_0_group_grouped_body:
  %bd118153_0_group_grouped_unwrapped = add i64 %bd118153_0_group_grouped_start, %bd118153_0_group_grouped_probe
  %bd118153_0_group_grouped_group_start = and i64 %bd118153_0_group_grouped_unwrapped, %bd118153_0_group_grouped_mask
  %bd118153_0_group_grouped_control_ptr = getelementptr i8, ptr %v118153_storage, i64 %bd118153_0_group_grouped_group_start
  %bd118153_0_group_grouped_controls = load <16 x i8>, ptr %bd118153_0_group_grouped_control_ptr, align 1
  %bd118153_0_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bd118153_0_h2, i64 0
  %bd118153_0_group_grouped_h2_vector = shufflevector <16 x i8> %bd118153_0_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118153_0_group_grouped_matches = icmp eq <16 x i8> %bd118153_0_group_grouped_controls, %bd118153_0_group_grouped_h2_vector
  %bd118153_0_group_grouped_match_bits = bitcast <16 x i1> %bd118153_0_group_grouped_matches to i16
  %bd118153_0_group_grouped_empties = icmp eq <16 x i8> %bd118153_0_group_grouped_controls, zeroinitializer
  %bd118153_0_group_grouped_empty_bits = bitcast <16 x i1> %bd118153_0_group_grouped_empties to i16
  %bd118153_0_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bd118153_0_group_grouped_deleted_vector = shufflevector <16 x i8> %bd118153_0_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bd118153_0_group_grouped_deleted_matches = icmp eq <16 x i8> %bd118153_0_group_grouped_controls, %bd118153_0_group_grouped_deleted_vector
  %bd118153_0_group_grouped_deleted_bits = bitcast <16 x i1> %bd118153_0_group_grouped_deleted_matches to i16
  %bd118153_0_group_grouped_has_deleted = icmp ne i16 %bd118153_0_group_grouped_deleted_bits, 0
  %bd118153_0_group_grouped_no_previous_deleted = icmp eq i64 %bd118153_0_group_grouped_first_deleted, 16
  %bd118153_0_group_grouped_capture_deleted = and i1 %bd118153_0_group_grouped_has_deleted, %bd118153_0_group_grouped_no_previous_deleted
  %bd118153_0_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bd118153_0_group_grouped_deleted_bits, i1 false)
  %bd118153_0_group_grouped_deleted_offset = zext i16 %bd118153_0_group_grouped_deleted_offset16 to i64
  %bd118153_0_group_grouped_deleted_unwrapped = add i64 %bd118153_0_group_grouped_group_start, %bd118153_0_group_grouped_deleted_offset
  %bd118153_0_group_grouped_deleted_slot = and i64 %bd118153_0_group_grouped_deleted_unwrapped, %bd118153_0_group_grouped_mask
  %bd118153_0_group_grouped_captured_deleted = select i1 %bd118153_0_group_grouped_capture_deleted, i64 %bd118153_0_group_grouped_deleted_slot, i64 %bd118153_0_group_grouped_first_deleted
  br label %bd118153_0_group_grouped_candidates
bd118153_0_group_grouped_candidates:
  %bd118153_0_group_grouped_candidate_bits = phi i16 [ %bd118153_0_group_grouped_match_bits, %bd118153_0_group_grouped_body ], [ %bd118153_0_group_grouped_cleared_bits, %bd118153_0_group_grouped_candidate_next ]
  %bd118153_0_group_grouped_has_candidate = icmp ne i16 %bd118153_0_group_grouped_candidate_bits, 0
  br i1 %bd118153_0_group_grouped_has_candidate, label %bd118153_0_group_grouped_candidate, label %bd118153_0_group_grouped_decision
bd118153_0_group_grouped_candidate:
  %bd118153_0_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bd118153_0_group_grouped_candidate_bits, i1 false)
  %bd118153_0_group_grouped_candidate_offset = zext i16 %bd118153_0_group_grouped_candidate_offset16 to i64
  %bd118153_0_group_grouped_candidate_unwrapped = add i64 %bd118153_0_group_grouped_group_start, %bd118153_0_group_grouped_candidate_offset
  %bd118153_0_group_grouped_candidate_slot = and i64 %bd118153_0_group_grouped_candidate_unwrapped, %bd118153_0_group_grouped_mask
  %bd118153_0_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bd118153_0_probe_keys, i64 %bd118153_0_group_grouped_candidate_slot
  %bd118153_0_group_grouped_key = load i32, ptr %bd118153_0_group_grouped_key_ptr, align 4
  %bd118153_0_group_grouped_candidate_equal = icmp eq i32 %bd118153_0_group_grouped_key, %bd118153_0_key_operand
  br i1 %bd118153_0_group_grouped_candidate_equal, label %bd118153_0_group_grouped_match, label %bd118153_0_group_grouped_candidate_next
bd118153_0_group_grouped_candidate_next:
  %bd118153_0_group_grouped_bits_minus_one = sub i16 %bd118153_0_group_grouped_candidate_bits, 1
  %bd118153_0_group_grouped_cleared_bits = and i16 %bd118153_0_group_grouped_candidate_bits, %bd118153_0_group_grouped_bits_minus_one
  br label %bd118153_0_group_grouped_candidates
bd118153_0_group_grouped_decision:
  %bd118153_0_group_grouped_has_empty = icmp ne i16 %bd118153_0_group_grouped_empty_bits, 0
  br i1 %bd118153_0_group_grouped_has_empty, label %bd118153_0_group_grouped_empty, label %bd118153_0_group_grouped_next_group
bd118153_0_group_grouped_empty:
  %bd118153_0_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bd118153_0_group_grouped_empty_bits, i1 false)
  %bd118153_0_group_grouped_empty_offset = zext i16 %bd118153_0_group_grouped_empty_offset16 to i64
  %bd118153_0_group_grouped_empty_unwrapped = add i64 %bd118153_0_group_grouped_group_start, %bd118153_0_group_grouped_empty_offset
  %bd118153_0_group_grouped_empty_slot = and i64 %bd118153_0_group_grouped_empty_unwrapped, %bd118153_0_group_grouped_mask
  %bd118153_0_group_grouped_use_empty = icmp eq i64 %bd118153_0_group_grouped_captured_deleted, 16
  %bd118153_0_group_grouped_insertion_slot = select i1 %bd118153_0_group_grouped_use_empty, i64 %bd118153_0_group_grouped_empty_slot, i64 %bd118153_0_group_grouped_captured_deleted
  br label %bd118153_0_group_grouped_done
bd118153_0_group_grouped_match:
  br label %bd118153_0_group_grouped_done
bd118153_0_group_grouped_next_group:
  %bd118153_0_group_grouped_next_probe = add i64 %bd118153_0_group_grouped_probe, 16
  %bd118153_0_group_grouped_next_deleted = add i64 %bd118153_0_group_grouped_captured_deleted, 0
  br label %bd118153_0_group_grouped_group
bd118153_0_group_grouped_miss:
  %bd118153_0_group_grouped_no_deleted = icmp eq i64 %bd118153_0_group_grouped_first_deleted, 16
  %bd118153_0_group_grouped_miss_slot = select i1 %bd118153_0_group_grouped_no_deleted, i64 0, i64 %bd118153_0_group_grouped_first_deleted
  br label %bd118153_0_group_grouped_done
bd118153_0_group_grouped_done:
  %bd118153_0_group_grouped_found = phi i1 [ false, %bd118153_0_group_grouped_empty ], [ true, %bd118153_0_group_grouped_match ], [ false, %bd118153_0_group_grouped_miss ]
  %bd118153_0_group_grouped_slot = phi i64 [ %bd118153_0_group_grouped_insertion_slot, %bd118153_0_group_grouped_empty ], [ %bd118153_0_group_grouped_candidate_slot, %bd118153_0_group_grouped_match ], [ %bd118153_0_group_grouped_miss_slot, %bd118153_0_group_grouped_miss ]
  br label %bd118153_0_group_done
bd118153_0_group_done:
  %bd118153_0_group_found = phi i1 [ true, %bd118153_0_group_match ], [ false, %bd118153_0_group_vacant ], [ %bd118153_0_group_grouped_found, %bd118153_0_group_grouped_done ], [ false, %bd118153_0_group_no_capacity ]
  %bd118153_0_group_slot = phi i64 [ %bd118153_0_group_start, %bd118153_0_group_match ], [ %bd118153_0_group_start, %bd118153_0_group_vacant ], [ %bd118153_0_group_grouped_slot, %bd118153_0_group_grouped_done ], [ 0, %bd118153_0_group_no_capacity ]
  %bd118153_0_slot = add i64 %bd118153_0_group_slot, 0
  %bd118153_0_exists = or i1 %bd118153_0_group_found, false
  br label %bd118153_0_insert
bd118153_0_insert:
  %bd118153_0_key_entry_offset = mul i64 %bd118153_0_slot, 8
  %bd118153_0_key_entries_field_offset = add i64 32, 0
  %bd118153_0_key_field_offset = add i64 %bd118153_0_key_entry_offset, %bd118153_0_key_entries_field_offset
  %bd118153_0_key_ptr = getelementptr i8, ptr %v118153_storage, i64 %bd118153_0_key_field_offset
  store i32 %bd118153_0_key_operand, ptr %bd118153_0_key_ptr, align 4
  %bd118153_0_value_entry_offset = mul i64 %bd118153_0_slot, 8
  %bd118153_0_value_entries_field_offset = add i64 32, 4
  %bd118153_0_value_field_offset = add i64 %bd118153_0_value_entry_offset, %bd118153_0_value_entries_field_offset
  %bd118153_0_value_ptr = getelementptr i8, ptr %v118153_storage, i64 %bd118153_0_value_field_offset
  store i32 %bd118153_0_value_operand, ptr %bd118153_0_value_ptr, align 4
  %bd118153_0_control_control_ptr = getelementptr i8, ptr %v118153_storage, i64 %bd118153_0_slot
  store i8 %bd118153_0_h2, ptr %bd118153_0_control_control_ptr, align 1
  %bd118153_0_control_mirror_needed = icmp ult i64 %bd118153_0_slot, 16
  %bd118153_0_control_mirror_candidate = add i64 %bd118153_0_slot, 16
  %bd118153_0_control_mirror_slot = select i1 %bd118153_0_control_mirror_needed, i64 %bd118153_0_control_mirror_candidate, i64 %bd118153_0_slot
  %bd118153_0_control_mirror_ptr = getelementptr i8, ptr %v118153_storage, i64 %bd118153_0_control_mirror_slot
  store i8 %bd118153_0_h2, ptr %bd118153_0_control_mirror_ptr, align 1
  %v118153_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %v118153_owner, i32 0, i32 0
  store i64 1, ptr %v118153_length_ptr, align 8
  %v118153 = load %sollang.bounded_dictionary.t1212, ptr %v118153_owner, align 8
  %v118150 = freeze %sollang.bounded_dictionary.t1212 %v118146
  %v118152 = freeze %sollang.bounded_dictionary.t1212 %v118146
  call void @sollang_m144_s0(%sollang.bounded_dictionary.t1212 %v118150)
  store %sollang.bounded_dictionary.t1212 %v118152, ptr %callref118151_arg0, align 8
  %callref118151_arg0_address = getelementptr i8, ptr %callref118151_arg0, i64 0
  call void @sollang_m144_s3(ptr %callref118151_arg0_address)
  store %sollang.bounded_dictionary.t1212 %v118153, ptr %slot118143, align 8
  store i32 0, ptr %slot118144, align 4
  br label %while118161_header
while118161_header:
  %while118161_v118159 = load i32, ptr %slot118144, align 4
  %while118161_v118158 = icmp slt i32 %while118161_v118159, 2
  br i1 %while118161_v118158, label %while118161_body, label %while118161_exit
while118161_body:
  %v118164 = load %sollang.bounded_dictionary.t1212, ptr %slot118143, align 8
  %v118168 = load i32, ptr %slot118144, align 4
  %v118166 = add i32 20, %v118168
  %bput118163_owner = getelementptr i8, ptr %slot118143, i64 0
  %bput118163_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bput118163_owner, i32 0, i32 1, i32 0
  %bput118163_length_ptr = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bput118163_owner, i32 0, i32 0
  %bput118163_old_length = load i64, ptr %bput118163_length_ptr, align 8
  %bput118163_query = freeze i32 1
  %bput118163_new_value = freeze i32 %v118166
  %bput118163_hash_key = sext i32 %bput118163_query to i64
  %bput118163_hash_high = lshr i64 %bput118163_hash_key, 32
  %bput118163_hash_fold = xor i64 %bput118163_hash_key, %bput118163_hash_high
  %bput118163_hash = mul i64 %bput118163_hash_fold, -7046029254386353131
  %bput118163_h2_shifted = lshr i64 %bput118163_hash, 57
  %bput118163_h2_raw = and i64 %bput118163_h2_shifted, 127
  %bput118163_h2_zero = icmp eq i64 %bput118163_h2_raw, 0
  %bput118163_h2_value = select i1 %bput118163_h2_zero, i64 1, i64 %bput118163_h2_raw
  %bput118163_h2 = trunc i64 %bput118163_h2_value to i8
  %bput118163_probe_keys = getelementptr i8, ptr %bput118163_storage, i64 32
  %bput118163_group_mask = sub i64 16, 1
  %bput118163_group_start = and i64 %bput118163_hash, %bput118163_group_mask
  %bput118163_group_has_capacity = icmp ugt i64 16, 0
  br i1 %bput118163_group_has_capacity, label %bput118163_group_first, label %bput118163_group_no_capacity
bput118163_group_no_capacity:
  br label %bput118163_group_done
bput118163_group_first:
  %bput118163_group_control_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_group_start
  %bput118163_group_control = load i8, ptr %bput118163_group_control_ptr, align 1
  %bput118163_group_empty = icmp eq i8 %bput118163_group_control, 0
  br i1 %bput118163_group_empty, label %bput118163_group_vacant, label %bput118163_group_occupied
bput118163_group_occupied:
  %bput118163_group_h2_match = icmp eq i8 %bput118163_group_control, %bput118163_h2
  br i1 %bput118163_group_h2_match, label %bput118163_group_compare, label %bput118163_group_fallback
bput118163_group_compare:
  %bput118163_group_key_ptr = getelementptr [8 x i8], ptr %bput118163_probe_keys, i64 %bput118163_group_start
  %bput118163_group_key = load i32, ptr %bput118163_group_key_ptr, align 4
  %bput118163_group_equal = icmp eq i32 %bput118163_group_key, %bput118163_query
  br i1 %bput118163_group_equal, label %bput118163_group_match, label %bput118163_group_fallback
bput118163_group_match:
  br label %bput118163_group_done
bput118163_group_vacant:
  br label %bput118163_group_done
bput118163_group_fallback:
  %bput118163_group_grouped_mask = sub i64 16, 1
  %bput118163_group_grouped_start = and i64 %bput118163_hash, %bput118163_group_grouped_mask
  br label %bput118163_group_grouped_entry
bput118163_group_grouped_entry:
  br label %bput118163_group_grouped_group
bput118163_group_grouped_group:
  %bput118163_group_grouped_probe = phi i64 [ 0, %bput118163_group_grouped_entry ], [ %bput118163_group_grouped_next_probe, %bput118163_group_grouped_next_group ]
  %bput118163_group_grouped_first_deleted = phi i64 [ 16, %bput118163_group_grouped_entry ], [ %bput118163_group_grouped_next_deleted, %bput118163_group_grouped_next_group ]
  %bput118163_group_grouped_active = icmp ult i64 %bput118163_group_grouped_probe, 16
  br i1 %bput118163_group_grouped_active, label %bput118163_group_grouped_body, label %bput118163_group_grouped_miss
bput118163_group_grouped_body:
  %bput118163_group_grouped_unwrapped = add i64 %bput118163_group_grouped_start, %bput118163_group_grouped_probe
  %bput118163_group_grouped_group_start = and i64 %bput118163_group_grouped_unwrapped, %bput118163_group_grouped_mask
  %bput118163_group_grouped_control_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_group_grouped_group_start
  %bput118163_group_grouped_controls = load <16 x i8>, ptr %bput118163_group_grouped_control_ptr, align 1
  %bput118163_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bput118163_h2, i64 0
  %bput118163_group_grouped_h2_vector = shufflevector <16 x i8> %bput118163_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bput118163_group_grouped_matches = icmp eq <16 x i8> %bput118163_group_grouped_controls, %bput118163_group_grouped_h2_vector
  %bput118163_group_grouped_match_bits = bitcast <16 x i1> %bput118163_group_grouped_matches to i16
  %bput118163_group_grouped_empties = icmp eq <16 x i8> %bput118163_group_grouped_controls, zeroinitializer
  %bput118163_group_grouped_empty_bits = bitcast <16 x i1> %bput118163_group_grouped_empties to i16
  %bput118163_group_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %bput118163_group_grouped_deleted_vector = shufflevector <16 x i8> %bput118163_group_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bput118163_group_grouped_deleted_matches = icmp eq <16 x i8> %bput118163_group_grouped_controls, %bput118163_group_grouped_deleted_vector
  %bput118163_group_grouped_deleted_bits = bitcast <16 x i1> %bput118163_group_grouped_deleted_matches to i16
  %bput118163_group_grouped_has_deleted = icmp ne i16 %bput118163_group_grouped_deleted_bits, 0
  %bput118163_group_grouped_no_previous_deleted = icmp eq i64 %bput118163_group_grouped_first_deleted, 16
  %bput118163_group_grouped_capture_deleted = and i1 %bput118163_group_grouped_has_deleted, %bput118163_group_grouped_no_previous_deleted
  %bput118163_group_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %bput118163_group_grouped_deleted_bits, i1 false)
  %bput118163_group_grouped_deleted_offset = zext i16 %bput118163_group_grouped_deleted_offset16 to i64
  %bput118163_group_grouped_deleted_unwrapped = add i64 %bput118163_group_grouped_group_start, %bput118163_group_grouped_deleted_offset
  %bput118163_group_grouped_deleted_slot = and i64 %bput118163_group_grouped_deleted_unwrapped, %bput118163_group_grouped_mask
  %bput118163_group_grouped_captured_deleted = select i1 %bput118163_group_grouped_capture_deleted, i64 %bput118163_group_grouped_deleted_slot, i64 %bput118163_group_grouped_first_deleted
  br label %bput118163_group_grouped_candidates
bput118163_group_grouped_candidates:
  %bput118163_group_grouped_candidate_bits = phi i16 [ %bput118163_group_grouped_match_bits, %bput118163_group_grouped_body ], [ %bput118163_group_grouped_cleared_bits, %bput118163_group_grouped_candidate_next ]
  %bput118163_group_grouped_has_candidate = icmp ne i16 %bput118163_group_grouped_candidate_bits, 0
  br i1 %bput118163_group_grouped_has_candidate, label %bput118163_group_grouped_candidate, label %bput118163_group_grouped_decision
bput118163_group_grouped_candidate:
  %bput118163_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bput118163_group_grouped_candidate_bits, i1 false)
  %bput118163_group_grouped_candidate_offset = zext i16 %bput118163_group_grouped_candidate_offset16 to i64
  %bput118163_group_grouped_candidate_unwrapped = add i64 %bput118163_group_grouped_group_start, %bput118163_group_grouped_candidate_offset
  %bput118163_group_grouped_candidate_slot = and i64 %bput118163_group_grouped_candidate_unwrapped, %bput118163_group_grouped_mask
  %bput118163_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bput118163_probe_keys, i64 %bput118163_group_grouped_candidate_slot
  %bput118163_group_grouped_key = load i32, ptr %bput118163_group_grouped_key_ptr, align 4
  %bput118163_group_grouped_candidate_equal = icmp eq i32 %bput118163_group_grouped_key, %bput118163_query
  br i1 %bput118163_group_grouped_candidate_equal, label %bput118163_group_grouped_match, label %bput118163_group_grouped_candidate_next
bput118163_group_grouped_candidate_next:
  %bput118163_group_grouped_bits_minus_one = sub i16 %bput118163_group_grouped_candidate_bits, 1
  %bput118163_group_grouped_cleared_bits = and i16 %bput118163_group_grouped_candidate_bits, %bput118163_group_grouped_bits_minus_one
  br label %bput118163_group_grouped_candidates
bput118163_group_grouped_decision:
  %bput118163_group_grouped_has_empty = icmp ne i16 %bput118163_group_grouped_empty_bits, 0
  br i1 %bput118163_group_grouped_has_empty, label %bput118163_group_grouped_empty, label %bput118163_group_grouped_next_group
bput118163_group_grouped_empty:
  %bput118163_group_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %bput118163_group_grouped_empty_bits, i1 false)
  %bput118163_group_grouped_empty_offset = zext i16 %bput118163_group_grouped_empty_offset16 to i64
  %bput118163_group_grouped_empty_unwrapped = add i64 %bput118163_group_grouped_group_start, %bput118163_group_grouped_empty_offset
  %bput118163_group_grouped_empty_slot = and i64 %bput118163_group_grouped_empty_unwrapped, %bput118163_group_grouped_mask
  %bput118163_group_grouped_use_empty = icmp eq i64 %bput118163_group_grouped_captured_deleted, 16
  %bput118163_group_grouped_insertion_slot = select i1 %bput118163_group_grouped_use_empty, i64 %bput118163_group_grouped_empty_slot, i64 %bput118163_group_grouped_captured_deleted
  br label %bput118163_group_grouped_done
bput118163_group_grouped_match:
  br label %bput118163_group_grouped_done
bput118163_group_grouped_next_group:
  %bput118163_group_grouped_next_probe = add i64 %bput118163_group_grouped_probe, 16
  %bput118163_group_grouped_next_deleted = add i64 %bput118163_group_grouped_captured_deleted, 0
  br label %bput118163_group_grouped_group
bput118163_group_grouped_miss:
  %bput118163_group_grouped_no_deleted = icmp eq i64 %bput118163_group_grouped_first_deleted, 16
  %bput118163_group_grouped_miss_slot = select i1 %bput118163_group_grouped_no_deleted, i64 0, i64 %bput118163_group_grouped_first_deleted
  br label %bput118163_group_grouped_done
bput118163_group_grouped_done:
  %bput118163_group_grouped_found = phi i1 [ false, %bput118163_group_grouped_empty ], [ true, %bput118163_group_grouped_match ], [ false, %bput118163_group_grouped_miss ]
  %bput118163_group_grouped_slot = phi i64 [ %bput118163_group_grouped_insertion_slot, %bput118163_group_grouped_empty ], [ %bput118163_group_grouped_candidate_slot, %bput118163_group_grouped_match ], [ %bput118163_group_grouped_miss_slot, %bput118163_group_grouped_miss ]
  br label %bput118163_group_done
bput118163_group_done:
  %bput118163_group_found = phi i1 [ true, %bput118163_group_match ], [ false, %bput118163_group_vacant ], [ %bput118163_group_grouped_found, %bput118163_group_grouped_done ], [ false, %bput118163_group_no_capacity ]
  %bput118163_group_slot = phi i64 [ %bput118163_group_start, %bput118163_group_match ], [ %bput118163_group_start, %bput118163_group_vacant ], [ %bput118163_group_grouped_slot, %bput118163_group_grouped_done ], [ 0, %bput118163_group_no_capacity ]
  %bput118163_slot = add i64 %bput118163_group_slot, 0
  %bput118163_exists = or i1 %bput118163_group_found, false
  br i1 %bput118163_exists, label %bput118163_update, label %bput118163_insert_check
bput118163_insert_check:
  %bput118163_insert_slot = add i64 %bput118163_slot, 0
  %bput118163_new_length = add i64 %bput118163_old_length, 1
  %bput118163_fits = icmp ule i64 %bput118163_new_length, 2
  br i1 %bput118163_fits, label %bput118163_insert, label %bput118163_full
bput118163_full:
  call void @llvm.trap()
  unreachable
bput118163_update:
  %bput118163_update_value_entry_offset = mul i64 %bput118163_slot, 8
  %bput118163_update_value_entries_field_offset = add i64 32, 4
  %bput118163_update_value_field_offset = add i64 %bput118163_update_value_entry_offset, %bput118163_update_value_entries_field_offset
  %bput118163_update_value_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_update_value_field_offset
  store i32 %bput118163_new_value, ptr %bput118163_update_value_ptr, align 4
  br label %bput118163_complete
bput118163_insert:
  %bput118163_insert_key_entry_offset = mul i64 %bput118163_insert_slot, 8
  %bput118163_insert_key_entries_field_offset = add i64 32, 0
  %bput118163_insert_key_field_offset = add i64 %bput118163_insert_key_entry_offset, %bput118163_insert_key_entries_field_offset
  %bput118163_insert_key_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_insert_key_field_offset
  store i32 %bput118163_query, ptr %bput118163_insert_key_ptr, align 4
  %bput118163_insert_value_entry_offset = mul i64 %bput118163_insert_slot, 8
  %bput118163_insert_value_entries_field_offset = add i64 32, 4
  %bput118163_insert_value_field_offset = add i64 %bput118163_insert_value_entry_offset, %bput118163_insert_value_entries_field_offset
  %bput118163_insert_value_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_insert_value_field_offset
  store i32 %bput118163_new_value, ptr %bput118163_insert_value_ptr, align 4
  %bput118163_insert_control_control_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_insert_slot
  store i8 %bput118163_h2, ptr %bput118163_insert_control_control_ptr, align 1
  %bput118163_insert_control_mirror_needed = icmp ult i64 %bput118163_insert_slot, 16
  %bput118163_insert_control_mirror_candidate = add i64 %bput118163_insert_slot, 16
  %bput118163_insert_control_mirror_slot = select i1 %bput118163_insert_control_mirror_needed, i64 %bput118163_insert_control_mirror_candidate, i64 %bput118163_insert_slot
  %bput118163_insert_control_mirror_ptr = getelementptr i8, ptr %bput118163_storage, i64 %bput118163_insert_control_mirror_slot
  store i8 %bput118163_h2, ptr %bput118163_insert_control_mirror_ptr, align 1
  store i64 %bput118163_new_length, ptr %bput118163_length_ptr, align 8
  br label %bput118163_complete
bput118163_complete:
  %v118171 = load %sollang.bounded_dictionary.t1212, ptr %slot118143, align 8
  %bidx118170_owner = getelementptr i8, ptr %slot118143, i64 0
  %bidx118170_storage = getelementptr inbounds %sollang.bounded_dictionary.t1212, ptr %bidx118170_owner, i32 0, i32 1, i32 0
  %bidx118170_query = freeze i32 1
  %bidx118170_hash_key = sext i32 %bidx118170_query to i64
  %bidx118170_hash_high = lshr i64 %bidx118170_hash_key, 32
  %bidx118170_hash_fold = xor i64 %bidx118170_hash_key, %bidx118170_hash_high
  %bidx118170_hash = mul i64 %bidx118170_hash_fold, -7046029254386353131
  %bidx118170_h2_shifted = lshr i64 %bidx118170_hash, 57
  %bidx118170_h2_raw = and i64 %bidx118170_h2_shifted, 127
  %bidx118170_h2_zero = icmp eq i64 %bidx118170_h2_raw, 0
  %bidx118170_h2_value = select i1 %bidx118170_h2_zero, i64 1, i64 %bidx118170_h2_raw
  %bidx118170_h2 = trunc i64 %bidx118170_h2_value to i8
  %bidx118170_probe_keys = getelementptr i8, ptr %bidx118170_storage, i64 32
  %bidx118170_group_mask = sub i64 16, 1
  %bidx118170_group_start = and i64 %bidx118170_hash, %bidx118170_group_mask
  br label %bidx118170_group_first
bidx118170_group_first:
  %bidx118170_group_control_ptr = getelementptr i8, ptr %bidx118170_storage, i64 %bidx118170_group_start
  %bidx118170_group_control = load i8, ptr %bidx118170_group_control_ptr, align 1
  %bidx118170_group_empty = icmp eq i8 %bidx118170_group_control, 0
  br i1 %bidx118170_group_empty, label %bidx118170_group_vacant, label %bidx118170_group_occupied
bidx118170_group_occupied:
  %bidx118170_group_h2_match = icmp eq i8 %bidx118170_group_control, %bidx118170_h2
  br i1 %bidx118170_group_h2_match, label %bidx118170_group_compare, label %bidx118170_group_fallback
bidx118170_group_compare:
  %bidx118170_group_key_ptr = getelementptr [8 x i8], ptr %bidx118170_probe_keys, i64 %bidx118170_group_start
  %bidx118170_group_key = load i32, ptr %bidx118170_group_key_ptr, align 4
  %bidx118170_group_equal = icmp eq i32 %bidx118170_group_key, %bidx118170_query
  br i1 %bidx118170_group_equal, label %bidx118170_group_match, label %bidx118170_group_fallback
bidx118170_group_match:
  br label %bidx118170_group_done
bidx118170_group_vacant:
  br label %bidx118170_group_done
bidx118170_group_fallback:
  %bidx118170_group_grouped_mask = sub i64 16, 1
  %bidx118170_group_grouped_start = and i64 %bidx118170_hash, %bidx118170_group_grouped_mask
  br label %bidx118170_group_grouped_entry
bidx118170_group_grouped_entry:
  br label %bidx118170_group_grouped_group
bidx118170_group_grouped_group:
  %bidx118170_group_grouped_probe = phi i64 [ 0, %bidx118170_group_grouped_entry ], [ %bidx118170_group_grouped_next_probe, %bidx118170_group_grouped_next_group ]
  %bidx118170_group_grouped_active = icmp ult i64 %bidx118170_group_grouped_probe, 16
  br i1 %bidx118170_group_grouped_active, label %bidx118170_group_grouped_body, label %bidx118170_group_grouped_miss
bidx118170_group_grouped_body:
  %bidx118170_group_grouped_unwrapped = add i64 %bidx118170_group_grouped_start, %bidx118170_group_grouped_probe
  %bidx118170_group_grouped_group_start = and i64 %bidx118170_group_grouped_unwrapped, %bidx118170_group_grouped_mask
  %bidx118170_group_grouped_control_ptr = getelementptr i8, ptr %bidx118170_storage, i64 %bidx118170_group_grouped_group_start
  %bidx118170_group_grouped_controls = load <16 x i8>, ptr %bidx118170_group_grouped_control_ptr, align 1
  %bidx118170_group_grouped_h2_seed = insertelement <16 x i8> poison, i8 %bidx118170_h2, i64 0
  %bidx118170_group_grouped_h2_vector = shufflevector <16 x i8> %bidx118170_group_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %bidx118170_group_grouped_matches = icmp eq <16 x i8> %bidx118170_group_grouped_controls, %bidx118170_group_grouped_h2_vector
  %bidx118170_group_grouped_match_bits = bitcast <16 x i1> %bidx118170_group_grouped_matches to i16
  %bidx118170_group_grouped_empties = icmp eq <16 x i8> %bidx118170_group_grouped_controls, zeroinitializer
  %bidx118170_group_grouped_empty_bits = bitcast <16 x i1> %bidx118170_group_grouped_empties to i16
  br label %bidx118170_group_grouped_candidates
bidx118170_group_grouped_candidates:
  %bidx118170_group_grouped_candidate_bits = phi i16 [ %bidx118170_group_grouped_match_bits, %bidx118170_group_grouped_body ], [ %bidx118170_group_grouped_cleared_bits, %bidx118170_group_grouped_candidate_next ]
  %bidx118170_group_grouped_has_candidate = icmp ne i16 %bidx118170_group_grouped_candidate_bits, 0
  br i1 %bidx118170_group_grouped_has_candidate, label %bidx118170_group_grouped_candidate, label %bidx118170_group_grouped_decision
bidx118170_group_grouped_candidate:
  %bidx118170_group_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %bidx118170_group_grouped_candidate_bits, i1 false)
  %bidx118170_group_grouped_candidate_offset = zext i16 %bidx118170_group_grouped_candidate_offset16 to i64
  %bidx118170_group_grouped_candidate_unwrapped = add i64 %bidx118170_group_grouped_group_start, %bidx118170_group_grouped_candidate_offset
  %bidx118170_group_grouped_candidate_slot = and i64 %bidx118170_group_grouped_candidate_unwrapped, %bidx118170_group_grouped_mask
  %bidx118170_group_grouped_key_ptr = getelementptr [8 x i8], ptr %bidx118170_probe_keys, i64 %bidx118170_group_grouped_candidate_slot
  %bidx118170_group_grouped_key = load i32, ptr %bidx118170_group_grouped_key_ptr, align 4
  %bidx118170_group_grouped_candidate_equal = icmp eq i32 %bidx118170_group_grouped_key, %bidx118170_query
  br i1 %bidx118170_group_grouped_candidate_equal, label %bidx118170_group_grouped_match, label %bidx118170_group_grouped_candidate_next
bidx118170_group_grouped_candidate_next:
  %bidx118170_group_grouped_bits_minus_one = sub i16 %bidx118170_group_grouped_candidate_bits, 1
  %bidx118170_group_grouped_cleared_bits = and i16 %bidx118170_group_grouped_candidate_bits, %bidx118170_group_grouped_bits_minus_one
  br label %bidx118170_group_grouped_candidates
bidx118170_group_grouped_decision:
  %bidx118170_group_grouped_has_empty = icmp ne i16 %bidx118170_group_grouped_empty_bits, 0
  br i1 %bidx118170_group_grouped_has_empty, label %bidx118170_group_grouped_miss, label %bidx118170_group_grouped_next_group
bidx118170_group_grouped_match:
  br label %bidx118170_group_grouped_done
bidx118170_group_grouped_next_group:
  %bidx118170_group_grouped_next_probe = add i64 %bidx118170_group_grouped_probe, 16
  br label %bidx118170_group_grouped_group
bidx118170_group_grouped_miss:
  br label %bidx118170_group_grouped_done
bidx118170_group_grouped_done:
  %bidx118170_group_grouped_found = phi i1 [ true, %bidx118170_group_grouped_match ], [ false, %bidx118170_group_grouped_miss ]
  %bidx118170_group_grouped_slot = phi i64 [ %bidx118170_group_grouped_candidate_slot, %bidx118170_group_grouped_match ], [ 0, %bidx118170_group_grouped_miss ]
  br label %bidx118170_group_done
bidx118170_group_done:
  %bidx118170_group_found = phi i1 [ true, %bidx118170_group_match ], [ false, %bidx118170_group_vacant ], [ %bidx118170_group_grouped_found, %bidx118170_group_grouped_done ]
  %bidx118170_group_slot = phi i64 [ %bidx118170_group_start, %bidx118170_group_match ], [ 0, %bidx118170_group_vacant ], [ %bidx118170_group_grouped_slot, %bidx118170_group_grouped_done ]
  %bidx118170_slot = add i64 %bidx118170_group_slot, 0
  %bidx118170_exists = or i1 %bidx118170_group_found, false
  br i1 %bidx118170_exists, label %bidx118170_found, label %bidx118170_missing
bidx118170_missing:
  call void @llvm.trap()
  unreachable
bidx118170_found:
  %v118170_value_entry_offset = mul i64 %bidx118170_slot, 8
  %v118170_value_entries_field_offset = add i64 32, 4
  %v118170_value_field_offset = add i64 %v118170_value_entry_offset, %v118170_value_entries_field_offset
  %v118170_value_ptr = getelementptr i8, ptr %bidx118170_storage, i64 %v118170_value_field_offset
  %v118170 = load i32, ptr %v118170_value_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118170, i1 true)
  %v118174 = load i32, ptr %slot118144, align 4
  %v118173 = add i32 %v118174, 1
  store i32 %v118173, ptr %slot118144, align 4
  br label %while118161_header
while118161_exit:
  %cleanup1181416_b118143_current = load %sollang.bounded_dictionary.t1212, ptr %slot118143, align 8
  call void @sollang_drop_t1212(%sollang.bounded_dictionary.t1212 %cleanup1181416_b118143_current)
  call void @sollang_drop_t1212(%sollang.bounded_dictionary.t1212 %v118146)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
