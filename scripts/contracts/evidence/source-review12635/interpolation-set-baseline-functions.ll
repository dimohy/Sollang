define i32 @main() {
entry:
  %each118111_index_slot = alloca i64, align 8
  %each118111_limit_slot = alloca i64, align 8
  %slot118104 = alloca %sollang.dict, align 8
  %v118106_requested = add i64 0, 2
  %v118106_nonnegative = icmp sge i64 %v118106_requested, 0
  br i1 %v118106_nonnegative, label %collection118106_capacity_ok, label %collection118106_capacity_fail
collection118106_capacity_fail:
  call void @llvm.trap()
  unreachable
collection118106_capacity_ok:
  %v118106_scaled = mul i64 %v118106_requested, 8
  %v118106_rounded_entries = add i64 %v118106_scaled, 6
  %v118106_required = udiv i64 %v118106_rounded_entries, 7
  %v118106_below_minimum = icmp ult i64 %v118106_required, 16
  %v118106_minimum = select i1 %v118106_below_minimum, i64 16, i64 %v118106_required
  %v118106_minus_one = sub i64 %v118106_minimum, 1
  %v118106_shift1 = lshr i64 %v118106_minus_one, 1
  %v118106_round1 = or i64 %v118106_minus_one, %v118106_shift1
  %v118106_shift2 = lshr i64 %v118106_round1, 2
  %v118106_round2 = or i64 %v118106_round1, %v118106_shift2
  %v118106_shift4 = lshr i64 %v118106_round2, 4
  %v118106_round4 = or i64 %v118106_round2, %v118106_shift4
  %v118106_shift8 = lshr i64 %v118106_round4, 8
  %v118106_round8 = or i64 %v118106_round4, %v118106_shift8
  %v118106_shift16 = lshr i64 %v118106_round8, 16
  %v118106_round16 = or i64 %v118106_round8, %v118106_shift16
  %v118106_shift32 = lshr i64 %v118106_round16, 32
  %v118106_round32 = or i64 %v118106_round16, %v118106_shift32
  %v118106_capacity = add i64 %v118106_round32, 1
  %v118106_allocation_mirror = add i64 %v118106_capacity, 23
  %v118106_allocation_offset = and i64 %v118106_allocation_mirror, -8
  %v118106_entry_bytes = mul i64 %v118106_capacity, 4
  %v118106_allocation_bytes = add i64 %v118106_allocation_offset, %v118106_entry_bytes
  %v118106_storage = call ptr @malloc(i64 %v118106_allocation_bytes)
  %v118106_allocated = icmp ne ptr %v118106_storage, null
  br i1 %v118106_allocated, label %v118106_allocation_ready, label %v118106_allocation_failed
v118106_allocation_failed:
  call void @llvm.trap()
  unreachable
v118106_allocation_ready:
  %v118106_controls = getelementptr i8, ptr %v118106_storage, i64 0
  %v118106_entries_mirror = add i64 %v118106_capacity, 23
  %v118106_entries_offset = and i64 %v118106_entries_mirror, -8
  %v118106_keys = getelementptr i8, ptr %v118106_storage, i64 %v118106_entries_offset
  %v118106_values = getelementptr i8, ptr %v118106_keys, i64 4
  %v118106_control_bytes = add i64 %v118106_capacity, 16
  call void @llvm.memset.p0.i64(ptr %v118106_controls, i8 0, i64 %v118106_control_bytes, i1 false)
  %v118106_0 = insertvalue %sollang.dict poison, ptr %v118106_storage, 0
  %v118106_1 = insertvalue %sollang.dict %v118106_0, i64 0, 1
  %v118106 = insertvalue %sollang.dict %v118106_1, i64 %v118106_capacity, 2
  store %sollang.dict %v118106, ptr %slot118104, align 8
  %v118109 = load %sollang.dict, ptr %slot118104, align 8
  %set118108_source = load %sollang.dict, ptr %slot118104, align 8
  %set118108_storage = extractvalue %sollang.dict %set118108_source, 0
  %set118108_length = extractvalue %sollang.dict %set118108_source, 1
  %set118108_capacity = extractvalue %sollang.dict %set118108_source, 2
  %set118108_controls = getelementptr i8, ptr %set118108_storage, i64 0
  %set118108_entries_mirror = add i64 %set118108_capacity, 23
  %set118108_entries_offset = and i64 %set118108_entries_mirror, -8
  %set118108_keys = getelementptr i8, ptr %set118108_storage, i64 %set118108_entries_offset
  %set118108_values = getelementptr i8, ptr %set118108_keys, i64 4
  %set118108_query_addr = alloca i32, align 4
  store i32 1, ptr %set118108_query_addr, align 4
  %set118108_query = load i32, ptr %set118108_query_addr, align 4
  %set118108_query_key64 = sext i32 %set118108_query to i64
  %set118108_query_hash_high = lshr i64 %set118108_query_key64, 32
  %set118108_query_hash_fold = xor i64 %set118108_query_key64, %set118108_query_hash_high
  %set118108_query_hash = mul i64 %set118108_query_hash_fold, -7046029254386353131
  %set118108_h2_shifted = lshr i64 %set118108_query_hash, 57
  %set118108_h2_raw = and i64 %set118108_h2_shifted, 127
  %set118108_h2_zero = icmp eq i64 %set118108_h2_raw, 0
  %set118108_h2_value = select i1 %set118108_h2_zero, i64 1, i64 %set118108_h2_raw
  %set118108_h2 = trunc i64 %set118108_h2_value to i8
  %set118108_find_mask = sub i64 %set118108_capacity, 1
  %set118108_find_start = and i64 %set118108_query_hash, %set118108_find_mask
  %set118108_find_has_capacity = icmp ugt i64 %set118108_capacity, 0
  br i1 %set118108_find_has_capacity, label %set118108_find_first, label %set118108_find_no_capacity
set118108_find_no_capacity:
  br label %set118108_find_done
set118108_find_first:
  %set118108_find_control_ptr = getelementptr i8, ptr %set118108_controls, i64 %set118108_find_start
  %set118108_find_control = load i8, ptr %set118108_find_control_ptr, align 1
  %set118108_find_empty = icmp eq i8 %set118108_find_control, 0
  br i1 %set118108_find_empty, label %set118108_find_vacant, label %set118108_find_occupied
set118108_find_occupied:
  %set118108_find_h2_match = icmp eq i8 %set118108_find_control, %set118108_h2
  br i1 %set118108_find_h2_match, label %set118108_find_compare, label %set118108_find_fallback
set118108_find_compare:
  %set118108_find_key_ptr = getelementptr [4 x i8], ptr %set118108_keys, i64 %set118108_find_start
  %set118108_find_key = load i32, ptr %set118108_find_key_ptr, align 4
  %set118108_find_equal = icmp eq i32 %set118108_find_key, %set118108_query
  br i1 %set118108_find_equal, label %set118108_find_match, label %set118108_find_fallback
set118108_find_match:
  br label %set118108_find_done
set118108_find_vacant:
  br label %set118108_find_done
set118108_find_fallback:
  %set118108_find_grouped_mask = sub i64 %set118108_capacity, 1
  %set118108_find_grouped_start = and i64 %set118108_query_hash, %set118108_find_grouped_mask
  br label %set118108_find_grouped_entry
set118108_find_grouped_entry:
  br label %set118108_find_grouped_group
set118108_find_grouped_group:
  %set118108_find_grouped_probe = phi i64 [ 0, %set118108_find_grouped_entry ], [ %set118108_find_grouped_next_probe, %set118108_find_grouped_next_group ]
  %set118108_find_grouped_first_deleted = phi i64 [ %set118108_capacity, %set118108_find_grouped_entry ], [ %set118108_find_grouped_next_deleted, %set118108_find_grouped_next_group ]
  %set118108_find_grouped_active = icmp ult i64 %set118108_find_grouped_probe, %set118108_capacity
  br i1 %set118108_find_grouped_active, label %set118108_find_grouped_body, label %set118108_find_grouped_miss
set118108_find_grouped_body:
  %set118108_find_grouped_unwrapped = add i64 %set118108_find_grouped_start, %set118108_find_grouped_probe
  %set118108_find_grouped_group_start = and i64 %set118108_find_grouped_unwrapped, %set118108_find_grouped_mask
  %set118108_find_grouped_control_ptr = getelementptr i8, ptr %set118108_controls, i64 %set118108_find_grouped_group_start
  %set118108_find_grouped_controls = load <16 x i8>, ptr %set118108_find_grouped_control_ptr, align 1
  %set118108_find_grouped_h2_seed = insertelement <16 x i8> poison, i8 %set118108_h2, i64 0
  %set118108_find_grouped_h2_vector = shufflevector <16 x i8> %set118108_find_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %set118108_find_grouped_matches = icmp eq <16 x i8> %set118108_find_grouped_controls, %set118108_find_grouped_h2_vector
  %set118108_find_grouped_match_bits = bitcast <16 x i1> %set118108_find_grouped_matches to i16
  %set118108_find_grouped_empties = icmp eq <16 x i8> %set118108_find_grouped_controls, zeroinitializer
  %set118108_find_grouped_empty_bits = bitcast <16 x i1> %set118108_find_grouped_empties to i16
  %set118108_find_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %set118108_find_grouped_deleted_vector = shufflevector <16 x i8> %set118108_find_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %set118108_find_grouped_deleted_matches = icmp eq <16 x i8> %set118108_find_grouped_controls, %set118108_find_grouped_deleted_vector
  %set118108_find_grouped_deleted_bits = bitcast <16 x i1> %set118108_find_grouped_deleted_matches to i16
  %set118108_find_grouped_has_deleted = icmp ne i16 %set118108_find_grouped_deleted_bits, 0
  %set118108_find_grouped_no_previous_deleted = icmp eq i64 %set118108_find_grouped_first_deleted, %set118108_capacity
  %set118108_find_grouped_capture_deleted = and i1 %set118108_find_grouped_has_deleted, %set118108_find_grouped_no_previous_deleted
  %set118108_find_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_find_grouped_deleted_bits, i1 false)
  %set118108_find_grouped_deleted_offset = zext i16 %set118108_find_grouped_deleted_offset16 to i64
  %set118108_find_grouped_deleted_unwrapped = add i64 %set118108_find_grouped_group_start, %set118108_find_grouped_deleted_offset
  %set118108_find_grouped_deleted_slot = and i64 %set118108_find_grouped_deleted_unwrapped, %set118108_find_grouped_mask
  %set118108_find_grouped_captured_deleted = select i1 %set118108_find_grouped_capture_deleted, i64 %set118108_find_grouped_deleted_slot, i64 %set118108_find_grouped_first_deleted
  br label %set118108_find_grouped_candidates
set118108_find_grouped_candidates:
  %set118108_find_grouped_candidate_bits = phi i16 [ %set118108_find_grouped_match_bits, %set118108_find_grouped_body ], [ %set118108_find_grouped_cleared_bits, %set118108_find_grouped_candidate_next ]
  %set118108_find_grouped_has_candidate = icmp ne i16 %set118108_find_grouped_candidate_bits, 0
  br i1 %set118108_find_grouped_has_candidate, label %set118108_find_grouped_candidate, label %set118108_find_grouped_decision
set118108_find_grouped_candidate:
  %set118108_find_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_find_grouped_candidate_bits, i1 false)
  %set118108_find_grouped_candidate_offset = zext i16 %set118108_find_grouped_candidate_offset16 to i64
  %set118108_find_grouped_candidate_unwrapped = add i64 %set118108_find_grouped_group_start, %set118108_find_grouped_candidate_offset
  %set118108_find_grouped_candidate_slot = and i64 %set118108_find_grouped_candidate_unwrapped, %set118108_find_grouped_mask
  %set118108_find_grouped_key_ptr = getelementptr [4 x i8], ptr %set118108_keys, i64 %set118108_find_grouped_candidate_slot
  %set118108_find_grouped_key = load i32, ptr %set118108_find_grouped_key_ptr, align 4
  %set118108_find_grouped_candidate_equal = icmp eq i32 %set118108_find_grouped_key, %set118108_query
  br i1 %set118108_find_grouped_candidate_equal, label %set118108_find_grouped_match, label %set118108_find_grouped_candidate_next
set118108_find_grouped_candidate_next:
  %set118108_find_grouped_bits_minus_one = sub i16 %set118108_find_grouped_candidate_bits, 1
  %set118108_find_grouped_cleared_bits = and i16 %set118108_find_grouped_candidate_bits, %set118108_find_grouped_bits_minus_one
  br label %set118108_find_grouped_candidates
set118108_find_grouped_decision:
  %set118108_find_grouped_has_empty = icmp ne i16 %set118108_find_grouped_empty_bits, 0
  br i1 %set118108_find_grouped_has_empty, label %set118108_find_grouped_empty, label %set118108_find_grouped_next_group
set118108_find_grouped_empty:
  %set118108_find_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_find_grouped_empty_bits, i1 false)
  %set118108_find_grouped_empty_offset = zext i16 %set118108_find_grouped_empty_offset16 to i64
  %set118108_find_grouped_empty_unwrapped = add i64 %set118108_find_grouped_group_start, %set118108_find_grouped_empty_offset
  %set118108_find_grouped_empty_slot = and i64 %set118108_find_grouped_empty_unwrapped, %set118108_find_grouped_mask
  %set118108_find_grouped_use_empty = icmp eq i64 %set118108_find_grouped_captured_deleted, %set118108_capacity
  %set118108_find_grouped_insertion_slot = select i1 %set118108_find_grouped_use_empty, i64 %set118108_find_grouped_empty_slot, i64 %set118108_find_grouped_captured_deleted
  br label %set118108_find_grouped_done
set118108_find_grouped_match:
  br label %set118108_find_grouped_done
set118108_find_grouped_next_group:
  %set118108_find_grouped_next_probe = add i64 %set118108_find_grouped_probe, 16
  %set118108_find_grouped_next_deleted = add i64 %set118108_find_grouped_captured_deleted, 0
  br label %set118108_find_grouped_group
set118108_find_grouped_miss:
  %set118108_find_grouped_no_deleted = icmp eq i64 %set118108_find_grouped_first_deleted, %set118108_capacity
  %set118108_find_grouped_miss_slot = select i1 %set118108_find_grouped_no_deleted, i64 0, i64 %set118108_find_grouped_first_deleted
  br label %set118108_find_grouped_done
set118108_find_grouped_done:
  %set118108_find_grouped_found = phi i1 [ false, %set118108_find_grouped_empty ], [ true, %set118108_find_grouped_match ], [ false, %set118108_find_grouped_miss ]
  %set118108_find_grouped_slot = phi i64 [ %set118108_find_grouped_insertion_slot, %set118108_find_grouped_empty ], [ %set118108_find_grouped_candidate_slot, %set118108_find_grouped_match ], [ %set118108_find_grouped_miss_slot, %set118108_find_grouped_miss ]
  br label %set118108_find_done
set118108_find_done:
  %set118108_find_found = phi i1 [ true, %set118108_find_match ], [ false, %set118108_find_vacant ], [ %set118108_find_grouped_found, %set118108_find_grouped_done ], [ false, %set118108_find_no_capacity ]
  %set118108_find_slot = phi i64 [ %set118108_find_start, %set118108_find_match ], [ %set118108_find_start, %set118108_find_vacant ], [ %set118108_find_grouped_slot, %set118108_find_grouped_done ], [ 0, %set118108_find_no_capacity ]
  %set118108_slot = add i64 %set118108_find_slot, 0
  br i1 %set118108_find_found, label %set118108_found, label %set118108_missing
set118108_missing:
  %set118108_insert_slot = add i64 %set118108_find_slot, 0
  %set118108_next_length = add i64 %set118108_length, 1
  %set118108_scaled_length = mul i64 %set118108_next_length, 8
  %set118108_load_limit = mul i64 %set118108_capacity, 7
  %set118108_fits = icmp ule i64 %set118108_scaled_length, %set118108_load_limit
  br i1 %set118108_fits, label %set118108_insert_current, label %set118108_grow
set118108_insert_current:
  %set118108_insert_key_ptr = getelementptr i32, ptr %set118108_keys, i64 %set118108_insert_slot
  store i32 %set118108_query, ptr %set118108_insert_key_ptr, align 4
  %set118108_insert_control_ptr = getelementptr i8, ptr %set118108_controls, i64 %set118108_insert_slot
  %set118108_insert_control_control_ptr = getelementptr i8, ptr %set118108_controls, i64 %set118108_insert_slot
  store i8 %set118108_h2, ptr %set118108_insert_control_control_ptr, align 1
  %set118108_insert_control_mirror_needed = icmp ult i64 %set118108_insert_slot, 16
  %set118108_insert_control_mirror_candidate = add i64 %set118108_insert_slot, %set118108_capacity
  %set118108_insert_control_mirror_slot = select i1 %set118108_insert_control_mirror_needed, i64 %set118108_insert_control_mirror_candidate, i64 %set118108_insert_slot
  %set118108_insert_control_mirror_ptr = getelementptr i8, ptr %set118108_controls, i64 %set118108_insert_control_mirror_slot
  store i8 %set118108_h2, ptr %set118108_insert_control_mirror_ptr, align 1
  %set118108_current_result = insertvalue %sollang.dict %set118108_source, i64 %set118108_next_length, 1
  store %sollang.dict %set118108_current_result, ptr %slot118104, align 8
  br label %set118108_inserted
set118108_grow:
  %set118108_grown_capacity = mul i64 %set118108_capacity, 2
  br label %set118108_grow_rehash_entry
set118108_grow_rehash_entry:
  %set118108_grow_rehash_allocation_mirror = add i64 %set118108_grown_capacity, 23
  %set118108_grow_rehash_allocation_offset = and i64 %set118108_grow_rehash_allocation_mirror, -8
  %set118108_grow_rehash_entry_bytes = mul i64 %set118108_grown_capacity, 4
  %set118108_grow_rehash_allocation_bytes = add i64 %set118108_grow_rehash_allocation_offset, %set118108_grow_rehash_entry_bytes
  %set118108_grow_rehash_storage = call ptr @malloc(i64 %set118108_grow_rehash_allocation_bytes)
  %set118108_grow_rehash_allocated = icmp ne ptr %set118108_grow_rehash_storage, null
  br i1 %set118108_grow_rehash_allocated, label %set118108_grow_rehash_allocation_ready, label %set118108_grow_rehash_allocation_failed
set118108_grow_rehash_allocation_failed:
  call void @llvm.trap()
  unreachable
set118108_grow_rehash_allocation_ready:
  %set118108_grow_rehash_controls = getelementptr i8, ptr %set118108_grow_rehash_storage, i64 0
  %set118108_grow_rehash_entries_mirror = add i64 %set118108_grown_capacity, 23
  %set118108_grow_rehash_entries_offset = and i64 %set118108_grow_rehash_entries_mirror, -8
  %set118108_grow_rehash_keys = getelementptr i8, ptr %set118108_grow_rehash_storage, i64 %set118108_grow_rehash_entries_offset
  %set118108_grow_rehash_values = getelementptr i8, ptr %set118108_grow_rehash_keys, i64 4
  %set118108_grow_rehash_control_bytes = add i64 %set118108_grown_capacity, 16
  call void @llvm.memset.p0.i64(ptr %set118108_grow_rehash_controls, i8 0, i64 %set118108_grow_rehash_control_bytes, i1 false)
  br label %set118108_grow_rehash_loop
set118108_grow_rehash_loop:
  %set118108_grow_rehash_index = phi i64 [ 0, %set118108_grow_rehash_allocation_ready ], [ %set118108_grow_rehash_next_index, %set118108_grow_rehash_advance ]
  %set118108_grow_rehash_active = icmp ult i64 %set118108_grow_rehash_index, %set118108_capacity
  br i1 %set118108_grow_rehash_active, label %set118108_grow_rehash_check, label %set118108_grow_rehash_done
set118108_grow_rehash_check:
  %set118108_grow_rehash_old_control_ptr = getelementptr i8, ptr %set118108_controls, i64 %set118108_grow_rehash_index
  %set118108_grow_rehash_old_control = load i8, ptr %set118108_grow_rehash_old_control_ptr, align 1
  %set118108_grow_rehash_occupied = icmp sgt i8 %set118108_grow_rehash_old_control, 0
  br i1 %set118108_grow_rehash_occupied, label %set118108_grow_rehash_move, label %set118108_grow_rehash_advance
set118108_grow_rehash_move:
  %set118108_grow_rehash_old_key_ptr = getelementptr i32, ptr %set118108_keys, i64 %set118108_grow_rehash_index
  %set118108_grow_rehash_key = load i32, ptr %set118108_grow_rehash_old_key_ptr, align 4
  %set118108_grow_rehash_key64 = sext i32 %set118108_grow_rehash_key to i64
  %set118108_grow_rehash_hash_high = lshr i64 %set118108_grow_rehash_key64, 32
  %set118108_grow_rehash_hash_fold = xor i64 %set118108_grow_rehash_key64, %set118108_grow_rehash_hash_high
  %set118108_grow_rehash_hash = mul i64 %set118108_grow_rehash_hash_fold, -7046029254386353131
  %set118108_grow_rehash_h2_shifted = lshr i64 %set118108_grow_rehash_hash, 57
  %set118108_grow_rehash_h2_raw = and i64 %set118108_grow_rehash_h2_shifted, 127
  %set118108_grow_rehash_h2_zero = icmp eq i64 %set118108_grow_rehash_h2_raw, 0
  %set118108_grow_rehash_h2_value = select i1 %set118108_grow_rehash_h2_zero, i64 1, i64 %set118108_grow_rehash_h2_raw
  %set118108_grow_rehash_h2 = trunc i64 %set118108_grow_rehash_h2_value to i8
  %set118108_grow_rehash_find_mask = sub i64 %set118108_grown_capacity, 1
  %set118108_grow_rehash_find_start = and i64 %set118108_grow_rehash_hash, %set118108_grow_rehash_find_mask
  %set118108_grow_rehash_find_has_capacity = icmp ugt i64 %set118108_grown_capacity, 0
  br i1 %set118108_grow_rehash_find_has_capacity, label %set118108_grow_rehash_find_first, label %set118108_grow_rehash_find_no_capacity
set118108_grow_rehash_find_no_capacity:
  br label %set118108_grow_rehash_find_done
set118108_grow_rehash_find_first:
  %set118108_grow_rehash_find_control_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grow_rehash_find_start
  %set118108_grow_rehash_find_control = load i8, ptr %set118108_grow_rehash_find_control_ptr, align 1
  %set118108_grow_rehash_find_empty = icmp eq i8 %set118108_grow_rehash_find_control, 0
  br i1 %set118108_grow_rehash_find_empty, label %set118108_grow_rehash_find_vacant, label %set118108_grow_rehash_find_occupied
set118108_grow_rehash_find_occupied:
  %set118108_grow_rehash_find_h2_match = icmp eq i8 %set118108_grow_rehash_find_control, %set118108_grow_rehash_h2
  br i1 %set118108_grow_rehash_find_h2_match, label %set118108_grow_rehash_find_compare, label %set118108_grow_rehash_find_fallback
set118108_grow_rehash_find_compare:
  %set118108_grow_rehash_find_key_ptr = getelementptr [4 x i8], ptr %set118108_grow_rehash_keys, i64 %set118108_grow_rehash_find_start
  %set118108_grow_rehash_find_key = load i32, ptr %set118108_grow_rehash_find_key_ptr, align 4
  %set118108_grow_rehash_find_equal = icmp eq i32 %set118108_grow_rehash_find_key, %set118108_grow_rehash_key
  br i1 %set118108_grow_rehash_find_equal, label %set118108_grow_rehash_find_match, label %set118108_grow_rehash_find_fallback
set118108_grow_rehash_find_match:
  br label %set118108_grow_rehash_find_done
set118108_grow_rehash_find_vacant:
  br label %set118108_grow_rehash_find_done
set118108_grow_rehash_find_fallback:
  %set118108_grow_rehash_find_grouped_mask = sub i64 %set118108_grown_capacity, 1
  %set118108_grow_rehash_find_grouped_start = and i64 %set118108_grow_rehash_hash, %set118108_grow_rehash_find_grouped_mask
  br label %set118108_grow_rehash_find_grouped_entry
set118108_grow_rehash_find_grouped_entry:
  br label %set118108_grow_rehash_find_grouped_group
set118108_grow_rehash_find_grouped_group:
  %set118108_grow_rehash_find_grouped_probe = phi i64 [ 0, %set118108_grow_rehash_find_grouped_entry ], [ %set118108_grow_rehash_find_grouped_next_probe, %set118108_grow_rehash_find_grouped_next_group ]
  %set118108_grow_rehash_find_grouped_first_deleted = phi i64 [ %set118108_grown_capacity, %set118108_grow_rehash_find_grouped_entry ], [ %set118108_grow_rehash_find_grouped_next_deleted, %set118108_grow_rehash_find_grouped_next_group ]
  %set118108_grow_rehash_find_grouped_active = icmp ult i64 %set118108_grow_rehash_find_grouped_probe, %set118108_grown_capacity
  br i1 %set118108_grow_rehash_find_grouped_active, label %set118108_grow_rehash_find_grouped_body, label %set118108_grow_rehash_find_grouped_miss
set118108_grow_rehash_find_grouped_body:
  %set118108_grow_rehash_find_grouped_unwrapped = add i64 %set118108_grow_rehash_find_grouped_start, %set118108_grow_rehash_find_grouped_probe
  %set118108_grow_rehash_find_grouped_group_start = and i64 %set118108_grow_rehash_find_grouped_unwrapped, %set118108_grow_rehash_find_grouped_mask
  %set118108_grow_rehash_find_grouped_control_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grow_rehash_find_grouped_group_start
  %set118108_grow_rehash_find_grouped_controls = load <16 x i8>, ptr %set118108_grow_rehash_find_grouped_control_ptr, align 1
  %set118108_grow_rehash_find_grouped_h2_seed = insertelement <16 x i8> poison, i8 %set118108_grow_rehash_h2, i64 0
  %set118108_grow_rehash_find_grouped_h2_vector = shufflevector <16 x i8> %set118108_grow_rehash_find_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %set118108_grow_rehash_find_grouped_matches = icmp eq <16 x i8> %set118108_grow_rehash_find_grouped_controls, %set118108_grow_rehash_find_grouped_h2_vector
  %set118108_grow_rehash_find_grouped_match_bits = bitcast <16 x i1> %set118108_grow_rehash_find_grouped_matches to i16
  %set118108_grow_rehash_find_grouped_empties = icmp eq <16 x i8> %set118108_grow_rehash_find_grouped_controls, zeroinitializer
  %set118108_grow_rehash_find_grouped_empty_bits = bitcast <16 x i1> %set118108_grow_rehash_find_grouped_empties to i16
  %set118108_grow_rehash_find_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %set118108_grow_rehash_find_grouped_deleted_vector = shufflevector <16 x i8> %set118108_grow_rehash_find_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %set118108_grow_rehash_find_grouped_deleted_matches = icmp eq <16 x i8> %set118108_grow_rehash_find_grouped_controls, %set118108_grow_rehash_find_grouped_deleted_vector
  %set118108_grow_rehash_find_grouped_deleted_bits = bitcast <16 x i1> %set118108_grow_rehash_find_grouped_deleted_matches to i16
  %set118108_grow_rehash_find_grouped_has_deleted = icmp ne i16 %set118108_grow_rehash_find_grouped_deleted_bits, 0
  %set118108_grow_rehash_find_grouped_no_previous_deleted = icmp eq i64 %set118108_grow_rehash_find_grouped_first_deleted, %set118108_grown_capacity
  %set118108_grow_rehash_find_grouped_capture_deleted = and i1 %set118108_grow_rehash_find_grouped_has_deleted, %set118108_grow_rehash_find_grouped_no_previous_deleted
  %set118108_grow_rehash_find_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_grow_rehash_find_grouped_deleted_bits, i1 false)
  %set118108_grow_rehash_find_grouped_deleted_offset = zext i16 %set118108_grow_rehash_find_grouped_deleted_offset16 to i64
  %set118108_grow_rehash_find_grouped_deleted_unwrapped = add i64 %set118108_grow_rehash_find_grouped_group_start, %set118108_grow_rehash_find_grouped_deleted_offset
  %set118108_grow_rehash_find_grouped_deleted_slot = and i64 %set118108_grow_rehash_find_grouped_deleted_unwrapped, %set118108_grow_rehash_find_grouped_mask
  %set118108_grow_rehash_find_grouped_captured_deleted = select i1 %set118108_grow_rehash_find_grouped_capture_deleted, i64 %set118108_grow_rehash_find_grouped_deleted_slot, i64 %set118108_grow_rehash_find_grouped_first_deleted
  br label %set118108_grow_rehash_find_grouped_candidates
set118108_grow_rehash_find_grouped_candidates:
  %set118108_grow_rehash_find_grouped_candidate_bits = phi i16 [ %set118108_grow_rehash_find_grouped_match_bits, %set118108_grow_rehash_find_grouped_body ], [ %set118108_grow_rehash_find_grouped_cleared_bits, %set118108_grow_rehash_find_grouped_candidate_next ]
  %set118108_grow_rehash_find_grouped_has_candidate = icmp ne i16 %set118108_grow_rehash_find_grouped_candidate_bits, 0
  br i1 %set118108_grow_rehash_find_grouped_has_candidate, label %set118108_grow_rehash_find_grouped_candidate, label %set118108_grow_rehash_find_grouped_decision
set118108_grow_rehash_find_grouped_candidate:
  %set118108_grow_rehash_find_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_grow_rehash_find_grouped_candidate_bits, i1 false)
  %set118108_grow_rehash_find_grouped_candidate_offset = zext i16 %set118108_grow_rehash_find_grouped_candidate_offset16 to i64
  %set118108_grow_rehash_find_grouped_candidate_unwrapped = add i64 %set118108_grow_rehash_find_grouped_group_start, %set118108_grow_rehash_find_grouped_candidate_offset
  %set118108_grow_rehash_find_grouped_candidate_slot = and i64 %set118108_grow_rehash_find_grouped_candidate_unwrapped, %set118108_grow_rehash_find_grouped_mask
  %set118108_grow_rehash_find_grouped_key_ptr = getelementptr [4 x i8], ptr %set118108_grow_rehash_keys, i64 %set118108_grow_rehash_find_grouped_candidate_slot
  %set118108_grow_rehash_find_grouped_key = load i32, ptr %set118108_grow_rehash_find_grouped_key_ptr, align 4
  %set118108_grow_rehash_find_grouped_candidate_equal = icmp eq i32 %set118108_grow_rehash_find_grouped_key, %set118108_grow_rehash_key
  br i1 %set118108_grow_rehash_find_grouped_candidate_equal, label %set118108_grow_rehash_find_grouped_match, label %set118108_grow_rehash_find_grouped_candidate_next
set118108_grow_rehash_find_grouped_candidate_next:
  %set118108_grow_rehash_find_grouped_bits_minus_one = sub i16 %set118108_grow_rehash_find_grouped_candidate_bits, 1
  %set118108_grow_rehash_find_grouped_cleared_bits = and i16 %set118108_grow_rehash_find_grouped_candidate_bits, %set118108_grow_rehash_find_grouped_bits_minus_one
  br label %set118108_grow_rehash_find_grouped_candidates
set118108_grow_rehash_find_grouped_decision:
  %set118108_grow_rehash_find_grouped_has_empty = icmp ne i16 %set118108_grow_rehash_find_grouped_empty_bits, 0
  br i1 %set118108_grow_rehash_find_grouped_has_empty, label %set118108_grow_rehash_find_grouped_empty, label %set118108_grow_rehash_find_grouped_next_group
set118108_grow_rehash_find_grouped_empty:
  %set118108_grow_rehash_find_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_grow_rehash_find_grouped_empty_bits, i1 false)
  %set118108_grow_rehash_find_grouped_empty_offset = zext i16 %set118108_grow_rehash_find_grouped_empty_offset16 to i64
  %set118108_grow_rehash_find_grouped_empty_unwrapped = add i64 %set118108_grow_rehash_find_grouped_group_start, %set118108_grow_rehash_find_grouped_empty_offset
  %set118108_grow_rehash_find_grouped_empty_slot = and i64 %set118108_grow_rehash_find_grouped_empty_unwrapped, %set118108_grow_rehash_find_grouped_mask
  %set118108_grow_rehash_find_grouped_use_empty = icmp eq i64 %set118108_grow_rehash_find_grouped_captured_deleted, %set118108_grown_capacity
  %set118108_grow_rehash_find_grouped_insertion_slot = select i1 %set118108_grow_rehash_find_grouped_use_empty, i64 %set118108_grow_rehash_find_grouped_empty_slot, i64 %set118108_grow_rehash_find_grouped_captured_deleted
  br label %set118108_grow_rehash_find_grouped_done
set118108_grow_rehash_find_grouped_match:
  br label %set118108_grow_rehash_find_grouped_done
set118108_grow_rehash_find_grouped_next_group:
  %set118108_grow_rehash_find_grouped_next_probe = add i64 %set118108_grow_rehash_find_grouped_probe, 16
  %set118108_grow_rehash_find_grouped_next_deleted = add i64 %set118108_grow_rehash_find_grouped_captured_deleted, 0
  br label %set118108_grow_rehash_find_grouped_group
set118108_grow_rehash_find_grouped_miss:
  %set118108_grow_rehash_find_grouped_no_deleted = icmp eq i64 %set118108_grow_rehash_find_grouped_first_deleted, %set118108_grown_capacity
  %set118108_grow_rehash_find_grouped_miss_slot = select i1 %set118108_grow_rehash_find_grouped_no_deleted, i64 0, i64 %set118108_grow_rehash_find_grouped_first_deleted
  br label %set118108_grow_rehash_find_grouped_done
set118108_grow_rehash_find_grouped_done:
  %set118108_grow_rehash_find_grouped_found = phi i1 [ false, %set118108_grow_rehash_find_grouped_empty ], [ true, %set118108_grow_rehash_find_grouped_match ], [ false, %set118108_grow_rehash_find_grouped_miss ]
  %set118108_grow_rehash_find_grouped_slot = phi i64 [ %set118108_grow_rehash_find_grouped_insertion_slot, %set118108_grow_rehash_find_grouped_empty ], [ %set118108_grow_rehash_find_grouped_candidate_slot, %set118108_grow_rehash_find_grouped_match ], [ %set118108_grow_rehash_find_grouped_miss_slot, %set118108_grow_rehash_find_grouped_miss ]
  br label %set118108_grow_rehash_find_done
set118108_grow_rehash_find_done:
  %set118108_grow_rehash_find_found = phi i1 [ true, %set118108_grow_rehash_find_match ], [ false, %set118108_grow_rehash_find_vacant ], [ %set118108_grow_rehash_find_grouped_found, %set118108_grow_rehash_find_grouped_done ], [ false, %set118108_grow_rehash_find_no_capacity ]
  %set118108_grow_rehash_find_slot = phi i64 [ %set118108_grow_rehash_find_start, %set118108_grow_rehash_find_match ], [ %set118108_grow_rehash_find_start, %set118108_grow_rehash_find_vacant ], [ %set118108_grow_rehash_find_grouped_slot, %set118108_grow_rehash_find_grouped_done ], [ 0, %set118108_grow_rehash_find_no_capacity ]
  %set118108_grow_rehash_slot = add i64 %set118108_grow_rehash_find_slot, 0
  %set118108_grow_rehash_new_key_ptr = getelementptr i32, ptr %set118108_grow_rehash_keys, i64 %set118108_grow_rehash_slot
  store i32 %set118108_grow_rehash_key, ptr %set118108_grow_rehash_new_key_ptr, align 4
  %set118108_grow_rehash_store_control_control_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grow_rehash_slot
  store i8 %set118108_grow_rehash_h2, ptr %set118108_grow_rehash_store_control_control_ptr, align 1
  %set118108_grow_rehash_store_control_mirror_needed = icmp ult i64 %set118108_grow_rehash_slot, 16
  %set118108_grow_rehash_store_control_mirror_candidate = add i64 %set118108_grow_rehash_slot, %set118108_grown_capacity
  %set118108_grow_rehash_store_control_mirror_slot = select i1 %set118108_grow_rehash_store_control_mirror_needed, i64 %set118108_grow_rehash_store_control_mirror_candidate, i64 %set118108_grow_rehash_slot
  %set118108_grow_rehash_store_control_mirror_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grow_rehash_store_control_mirror_slot
  store i8 %set118108_grow_rehash_h2, ptr %set118108_grow_rehash_store_control_mirror_ptr, align 1
  br label %set118108_grow_rehash_advance
set118108_grow_rehash_advance:
  %set118108_grow_rehash_next_index = add i64 %set118108_grow_rehash_index, 1
  br label %set118108_grow_rehash_loop
set118108_grow_rehash_done:
  call void @free(ptr %set118108_controls)
  %set118108_grow_rehash_result_0 = insertvalue %sollang.dict poison, ptr %set118108_grow_rehash_storage, 0
  %set118108_grow_rehash_result_1 = insertvalue %sollang.dict %set118108_grow_rehash_result_0, i64 %set118108_length, 1
  %set118108_grow_rehash_result = insertvalue %sollang.dict %set118108_grow_rehash_result_1, i64 %set118108_grown_capacity, 2
  %set118108_grown_probe_mask = sub i64 %set118108_grown_capacity, 1
  %set118108_grown_probe_start = and i64 %set118108_query_hash, %set118108_grown_probe_mask
  %set118108_grown_probe_has_capacity = icmp ugt i64 %set118108_grown_capacity, 0
  br i1 %set118108_grown_probe_has_capacity, label %set118108_grown_probe_first, label %set118108_grown_probe_no_capacity
set118108_grown_probe_no_capacity:
  br label %set118108_grown_probe_done
set118108_grown_probe_first:
  %set118108_grown_probe_control_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grown_probe_start
  %set118108_grown_probe_control = load i8, ptr %set118108_grown_probe_control_ptr, align 1
  %set118108_grown_probe_empty = icmp eq i8 %set118108_grown_probe_control, 0
  br i1 %set118108_grown_probe_empty, label %set118108_grown_probe_vacant, label %set118108_grown_probe_occupied
set118108_grown_probe_occupied:
  %set118108_grown_probe_h2_match = icmp eq i8 %set118108_grown_probe_control, %set118108_h2
  br i1 %set118108_grown_probe_h2_match, label %set118108_grown_probe_compare, label %set118108_grown_probe_fallback
set118108_grown_probe_compare:
  %set118108_grown_probe_key_ptr = getelementptr [4 x i8], ptr %set118108_grow_rehash_keys, i64 %set118108_grown_probe_start
  %set118108_grown_probe_key = load i32, ptr %set118108_grown_probe_key_ptr, align 4
  %set118108_grown_probe_equal = icmp eq i32 %set118108_grown_probe_key, %set118108_query
  br i1 %set118108_grown_probe_equal, label %set118108_grown_probe_match, label %set118108_grown_probe_fallback
set118108_grown_probe_match:
  br label %set118108_grown_probe_done
set118108_grown_probe_vacant:
  br label %set118108_grown_probe_done
set118108_grown_probe_fallback:
  %set118108_grown_probe_grouped_mask = sub i64 %set118108_grown_capacity, 1
  %set118108_grown_probe_grouped_start = and i64 %set118108_query_hash, %set118108_grown_probe_grouped_mask
  br label %set118108_grown_probe_grouped_entry
set118108_grown_probe_grouped_entry:
  br label %set118108_grown_probe_grouped_group
set118108_grown_probe_grouped_group:
  %set118108_grown_probe_grouped_probe = phi i64 [ 0, %set118108_grown_probe_grouped_entry ], [ %set118108_grown_probe_grouped_next_probe, %set118108_grown_probe_grouped_next_group ]
  %set118108_grown_probe_grouped_first_deleted = phi i64 [ %set118108_grown_capacity, %set118108_grown_probe_grouped_entry ], [ %set118108_grown_probe_grouped_next_deleted, %set118108_grown_probe_grouped_next_group ]
  %set118108_grown_probe_grouped_active = icmp ult i64 %set118108_grown_probe_grouped_probe, %set118108_grown_capacity
  br i1 %set118108_grown_probe_grouped_active, label %set118108_grown_probe_grouped_body, label %set118108_grown_probe_grouped_miss
set118108_grown_probe_grouped_body:
  %set118108_grown_probe_grouped_unwrapped = add i64 %set118108_grown_probe_grouped_start, %set118108_grown_probe_grouped_probe
  %set118108_grown_probe_grouped_group_start = and i64 %set118108_grown_probe_grouped_unwrapped, %set118108_grown_probe_grouped_mask
  %set118108_grown_probe_grouped_control_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grown_probe_grouped_group_start
  %set118108_grown_probe_grouped_controls = load <16 x i8>, ptr %set118108_grown_probe_grouped_control_ptr, align 1
  %set118108_grown_probe_grouped_h2_seed = insertelement <16 x i8> poison, i8 %set118108_h2, i64 0
  %set118108_grown_probe_grouped_h2_vector = shufflevector <16 x i8> %set118108_grown_probe_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %set118108_grown_probe_grouped_matches = icmp eq <16 x i8> %set118108_grown_probe_grouped_controls, %set118108_grown_probe_grouped_h2_vector
  %set118108_grown_probe_grouped_match_bits = bitcast <16 x i1> %set118108_grown_probe_grouped_matches to i16
  %set118108_grown_probe_grouped_empties = icmp eq <16 x i8> %set118108_grown_probe_grouped_controls, zeroinitializer
  %set118108_grown_probe_grouped_empty_bits = bitcast <16 x i1> %set118108_grown_probe_grouped_empties to i16
  %set118108_grown_probe_grouped_deleted_seed = insertelement <16 x i8> poison, i8 -1, i64 0
  %set118108_grown_probe_grouped_deleted_vector = shufflevector <16 x i8> %set118108_grown_probe_grouped_deleted_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %set118108_grown_probe_grouped_deleted_matches = icmp eq <16 x i8> %set118108_grown_probe_grouped_controls, %set118108_grown_probe_grouped_deleted_vector
  %set118108_grown_probe_grouped_deleted_bits = bitcast <16 x i1> %set118108_grown_probe_grouped_deleted_matches to i16
  %set118108_grown_probe_grouped_has_deleted = icmp ne i16 %set118108_grown_probe_grouped_deleted_bits, 0
  %set118108_grown_probe_grouped_no_previous_deleted = icmp eq i64 %set118108_grown_probe_grouped_first_deleted, %set118108_grown_capacity
  %set118108_grown_probe_grouped_capture_deleted = and i1 %set118108_grown_probe_grouped_has_deleted, %set118108_grown_probe_grouped_no_previous_deleted
  %set118108_grown_probe_grouped_deleted_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_grown_probe_grouped_deleted_bits, i1 false)
  %set118108_grown_probe_grouped_deleted_offset = zext i16 %set118108_grown_probe_grouped_deleted_offset16 to i64
  %set118108_grown_probe_grouped_deleted_unwrapped = add i64 %set118108_grown_probe_grouped_group_start, %set118108_grown_probe_grouped_deleted_offset
  %set118108_grown_probe_grouped_deleted_slot = and i64 %set118108_grown_probe_grouped_deleted_unwrapped, %set118108_grown_probe_grouped_mask
  %set118108_grown_probe_grouped_captured_deleted = select i1 %set118108_grown_probe_grouped_capture_deleted, i64 %set118108_grown_probe_grouped_deleted_slot, i64 %set118108_grown_probe_grouped_first_deleted
  br label %set118108_grown_probe_grouped_candidates
set118108_grown_probe_grouped_candidates:
  %set118108_grown_probe_grouped_candidate_bits = phi i16 [ %set118108_grown_probe_grouped_match_bits, %set118108_grown_probe_grouped_body ], [ %set118108_grown_probe_grouped_cleared_bits, %set118108_grown_probe_grouped_candidate_next ]
  %set118108_grown_probe_grouped_has_candidate = icmp ne i16 %set118108_grown_probe_grouped_candidate_bits, 0
  br i1 %set118108_grown_probe_grouped_has_candidate, label %set118108_grown_probe_grouped_candidate, label %set118108_grown_probe_grouped_decision
set118108_grown_probe_grouped_candidate:
  %set118108_grown_probe_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_grown_probe_grouped_candidate_bits, i1 false)
  %set118108_grown_probe_grouped_candidate_offset = zext i16 %set118108_grown_probe_grouped_candidate_offset16 to i64
  %set118108_grown_probe_grouped_candidate_unwrapped = add i64 %set118108_grown_probe_grouped_group_start, %set118108_grown_probe_grouped_candidate_offset
  %set118108_grown_probe_grouped_candidate_slot = and i64 %set118108_grown_probe_grouped_candidate_unwrapped, %set118108_grown_probe_grouped_mask
  %set118108_grown_probe_grouped_key_ptr = getelementptr [4 x i8], ptr %set118108_grow_rehash_keys, i64 %set118108_grown_probe_grouped_candidate_slot
  %set118108_grown_probe_grouped_key = load i32, ptr %set118108_grown_probe_grouped_key_ptr, align 4
  %set118108_grown_probe_grouped_candidate_equal = icmp eq i32 %set118108_grown_probe_grouped_key, %set118108_query
  br i1 %set118108_grown_probe_grouped_candidate_equal, label %set118108_grown_probe_grouped_match, label %set118108_grown_probe_grouped_candidate_next
set118108_grown_probe_grouped_candidate_next:
  %set118108_grown_probe_grouped_bits_minus_one = sub i16 %set118108_grown_probe_grouped_candidate_bits, 1
  %set118108_grown_probe_grouped_cleared_bits = and i16 %set118108_grown_probe_grouped_candidate_bits, %set118108_grown_probe_grouped_bits_minus_one
  br label %set118108_grown_probe_grouped_candidates
set118108_grown_probe_grouped_decision:
  %set118108_grown_probe_grouped_has_empty = icmp ne i16 %set118108_grown_probe_grouped_empty_bits, 0
  br i1 %set118108_grown_probe_grouped_has_empty, label %set118108_grown_probe_grouped_empty, label %set118108_grown_probe_grouped_next_group
set118108_grown_probe_grouped_empty:
  %set118108_grown_probe_grouped_empty_offset16 = call i16 @llvm.cttz.i16(i16 %set118108_grown_probe_grouped_empty_bits, i1 false)
  %set118108_grown_probe_grouped_empty_offset = zext i16 %set118108_grown_probe_grouped_empty_offset16 to i64
  %set118108_grown_probe_grouped_empty_unwrapped = add i64 %set118108_grown_probe_grouped_group_start, %set118108_grown_probe_grouped_empty_offset
  %set118108_grown_probe_grouped_empty_slot = and i64 %set118108_grown_probe_grouped_empty_unwrapped, %set118108_grown_probe_grouped_mask
  %set118108_grown_probe_grouped_use_empty = icmp eq i64 %set118108_grown_probe_grouped_captured_deleted, %set118108_grown_capacity
  %set118108_grown_probe_grouped_insertion_slot = select i1 %set118108_grown_probe_grouped_use_empty, i64 %set118108_grown_probe_grouped_empty_slot, i64 %set118108_grown_probe_grouped_captured_deleted
  br label %set118108_grown_probe_grouped_done
set118108_grown_probe_grouped_match:
  br label %set118108_grown_probe_grouped_done
set118108_grown_probe_grouped_next_group:
  %set118108_grown_probe_grouped_next_probe = add i64 %set118108_grown_probe_grouped_probe, 16
  %set118108_grown_probe_grouped_next_deleted = add i64 %set118108_grown_probe_grouped_captured_deleted, 0
  br label %set118108_grown_probe_grouped_group
set118108_grown_probe_grouped_miss:
  %set118108_grown_probe_grouped_no_deleted = icmp eq i64 %set118108_grown_probe_grouped_first_deleted, %set118108_grown_capacity
  %set118108_grown_probe_grouped_miss_slot = select i1 %set118108_grown_probe_grouped_no_deleted, i64 0, i64 %set118108_grown_probe_grouped_first_deleted
  br label %set118108_grown_probe_grouped_done
set118108_grown_probe_grouped_done:
  %set118108_grown_probe_grouped_found = phi i1 [ false, %set118108_grown_probe_grouped_empty ], [ true, %set118108_grown_probe_grouped_match ], [ false, %set118108_grown_probe_grouped_miss ]
  %set118108_grown_probe_grouped_slot = phi i64 [ %set118108_grown_probe_grouped_insertion_slot, %set118108_grown_probe_grouped_empty ], [ %set118108_grown_probe_grouped_candidate_slot, %set118108_grown_probe_grouped_match ], [ %set118108_grown_probe_grouped_miss_slot, %set118108_grown_probe_grouped_miss ]
  br label %set118108_grown_probe_done
set118108_grown_probe_done:
  %set118108_grown_probe_found = phi i1 [ true, %set118108_grown_probe_match ], [ false, %set118108_grown_probe_vacant ], [ %set118108_grown_probe_grouped_found, %set118108_grown_probe_grouped_done ], [ false, %set118108_grown_probe_no_capacity ]
  %set118108_grown_probe_slot = phi i64 [ %set118108_grown_probe_start, %set118108_grown_probe_match ], [ %set118108_grown_probe_start, %set118108_grown_probe_vacant ], [ %set118108_grown_probe_grouped_slot, %set118108_grown_probe_grouped_done ], [ 0, %set118108_grown_probe_no_capacity ]
  %set118108_grown_slot = add i64 %set118108_grown_probe_slot, 0
  %set118108_grown_key_ptr = getelementptr i32, ptr %set118108_grow_rehash_keys, i64 %set118108_grown_slot
  store i32 %set118108_query, ptr %set118108_grown_key_ptr, align 4
  %set118108_grown_store_control_control_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grown_slot
  store i8 %set118108_h2, ptr %set118108_grown_store_control_control_ptr, align 1
  %set118108_grown_store_control_mirror_needed = icmp ult i64 %set118108_grown_slot, 16
  %set118108_grown_store_control_mirror_candidate = add i64 %set118108_grown_slot, %set118108_grown_capacity
  %set118108_grown_store_control_mirror_slot = select i1 %set118108_grown_store_control_mirror_needed, i64 %set118108_grown_store_control_mirror_candidate, i64 %set118108_grown_slot
  %set118108_grown_store_control_mirror_ptr = getelementptr i8, ptr %set118108_grow_rehash_controls, i64 %set118108_grown_store_control_mirror_slot
  store i8 %set118108_h2, ptr %set118108_grown_store_control_mirror_ptr, align 1
  %set118108_grown_result = insertvalue %sollang.dict %set118108_grow_rehash_result, i64 %set118108_next_length, 1
  store %sollang.dict %set118108_grown_result, ptr %slot118104, align 8
  br label %set118108_inserted
set118108_found:
  br label %set118108_duplicate
set118108_inserted:
  br label %set118108_complete
set118108_duplicate:
  br label %set118108_complete
set118108_complete:
  %v118108 = phi i1 [ true, %set118108_inserted ], [ false, %set118108_duplicate ]
  %v118112_start = insertvalue { i32, i32 } poison, i32 0, 0
  %v118112 = insertvalue { i32, i32 } %v118112_start, i32 2, 1
  %each118111_range = freeze { i32, i32 } %v118112
  %each118111_first = extractvalue { i32, i32 } %each118111_range, 0
  %each118111_last = extractvalue { i32, i32 } %each118111_range, 1
  %each118111_start = sext i32 %each118111_first to i64
  %each118111_limit = sext i32 %each118111_last to i64
  store i64 %each118111_start, ptr %each118111_index_slot, align 8
  store i64 %each118111_limit, ptr %each118111_limit_slot, align 8
  br label %each118111_header
each118111_header:
  %each118111_index = load i64, ptr %each118111_index_slot, align 8
  %each118111_bound = load i64, ptr %each118111_limit_slot, align 8
  %each118111_done = icmp sgt i64 %each118111_index, %each118111_bound
  br i1 %each118111_done, label %each118111_exit, label %each118111_body
each118111_body:
  %each118111_item = trunc i64 %each118111_index to i32
  %each_role_m144_s3 = freeze i32 %each118111_item
  %v118116_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118116, 0
  %v118116 = insertvalue %sollang.text %v118116_ptr, i64 33, 1
  %v118115_expression_literal0 = getelementptr i8, ptr @sollang_str_118116, i64 0
  call void @sollang_runtime_print(ptr %v118115_expression_literal0, i64 4, i1 false)
  %v118115_expression1_mutable = load %sollang.dict, ptr %slot118104, align 8
  %iset118115_0_source = load %sollang.dict, ptr %slot118104, align 8
  %iset118115_0_storage = extractvalue %sollang.dict %iset118115_0_source, 0
  %iset118115_0_capacity = extractvalue %sollang.dict %iset118115_0_source, 2
  %iset118115_0_controls = getelementptr i8, ptr %iset118115_0_storage, i64 0
  %iset118115_0_entries_mirror = add i64 %iset118115_0_capacity, 23
  %iset118115_0_entries_offset = and i64 %iset118115_0_entries_mirror, -8
  %iset118115_0_keys = getelementptr i8, ptr %iset118115_0_storage, i64 %iset118115_0_entries_offset
  %iset118115_0_values = getelementptr i8, ptr %iset118115_0_keys, i64 4
  %iset118115_0_query_addr = alloca i32, align 4
  store i32 %each_role_m144_s3, ptr %iset118115_0_query_addr, align 4
  %iset118115_0_query = load i32, ptr %iset118115_0_query_addr, align 4
  %iset118115_0_query_key64 = sext i32 %iset118115_0_query to i64
  %iset118115_0_query_hash_high = lshr i64 %iset118115_0_query_key64, 32
  %iset118115_0_query_hash_fold = xor i64 %iset118115_0_query_key64, %iset118115_0_query_hash_high
  %iset118115_0_query_hash = mul i64 %iset118115_0_query_hash_fold, -7046029254386353131
  %iset118115_0_h2_shifted = lshr i64 %iset118115_0_query_hash, 57
  %iset118115_0_h2_raw = and i64 %iset118115_0_h2_shifted, 127
  %iset118115_0_h2_zero = icmp eq i64 %iset118115_0_h2_raw, 0
  %iset118115_0_h2_value = select i1 %iset118115_0_h2_zero, i64 1, i64 %iset118115_0_h2_raw
  %iset118115_0_h2 = trunc i64 %iset118115_0_h2_value to i8
  %iset118115_0_find_mask = sub i64 %iset118115_0_capacity, 1
  %iset118115_0_find_start = and i64 %iset118115_0_query_hash, %iset118115_0_find_mask
  br label %iset118115_0_find_first
iset118115_0_find_first:
  %iset118115_0_find_control_ptr = getelementptr i8, ptr %iset118115_0_controls, i64 %iset118115_0_find_start
  %iset118115_0_find_control = load i8, ptr %iset118115_0_find_control_ptr, align 1
  %iset118115_0_find_empty = icmp eq i8 %iset118115_0_find_control, 0
  br i1 %iset118115_0_find_empty, label %iset118115_0_find_vacant, label %iset118115_0_find_occupied
iset118115_0_find_occupied:
  %iset118115_0_find_h2_match = icmp eq i8 %iset118115_0_find_control, %iset118115_0_h2
  br i1 %iset118115_0_find_h2_match, label %iset118115_0_find_compare, label %iset118115_0_find_fallback
iset118115_0_find_compare:
  %iset118115_0_find_key_ptr = getelementptr [4 x i8], ptr %iset118115_0_keys, i64 %iset118115_0_find_start
  %iset118115_0_find_key = load i32, ptr %iset118115_0_find_key_ptr, align 4
  %iset118115_0_find_equal = icmp eq i32 %iset118115_0_find_key, %iset118115_0_query
  br i1 %iset118115_0_find_equal, label %iset118115_0_find_match, label %iset118115_0_find_fallback
iset118115_0_find_match:
  br label %iset118115_0_find_done
iset118115_0_find_vacant:
  br label %iset118115_0_find_done
iset118115_0_find_fallback:
  %iset118115_0_find_grouped_mask = sub i64 %iset118115_0_capacity, 1
  %iset118115_0_find_grouped_start = and i64 %iset118115_0_query_hash, %iset118115_0_find_grouped_mask
  br label %iset118115_0_find_grouped_entry
iset118115_0_find_grouped_entry:
  br label %iset118115_0_find_grouped_group
iset118115_0_find_grouped_group:
  %iset118115_0_find_grouped_probe = phi i64 [ 0, %iset118115_0_find_grouped_entry ], [ %iset118115_0_find_grouped_next_probe, %iset118115_0_find_grouped_next_group ]
  %iset118115_0_find_grouped_active = icmp ult i64 %iset118115_0_find_grouped_probe, %iset118115_0_capacity
  br i1 %iset118115_0_find_grouped_active, label %iset118115_0_find_grouped_body, label %iset118115_0_find_grouped_miss
iset118115_0_find_grouped_body:
  %iset118115_0_find_grouped_unwrapped = add i64 %iset118115_0_find_grouped_start, %iset118115_0_find_grouped_probe
  %iset118115_0_find_grouped_group_start = and i64 %iset118115_0_find_grouped_unwrapped, %iset118115_0_find_grouped_mask
  %iset118115_0_find_grouped_control_ptr = getelementptr i8, ptr %iset118115_0_controls, i64 %iset118115_0_find_grouped_group_start
  %iset118115_0_find_grouped_controls = load <16 x i8>, ptr %iset118115_0_find_grouped_control_ptr, align 1
  %iset118115_0_find_grouped_h2_seed = insertelement <16 x i8> poison, i8 %iset118115_0_h2, i64 0
  %iset118115_0_find_grouped_h2_vector = shufflevector <16 x i8> %iset118115_0_find_grouped_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %iset118115_0_find_grouped_matches = icmp eq <16 x i8> %iset118115_0_find_grouped_controls, %iset118115_0_find_grouped_h2_vector
  %iset118115_0_find_grouped_match_bits = bitcast <16 x i1> %iset118115_0_find_grouped_matches to i16
  %iset118115_0_find_grouped_empties = icmp eq <16 x i8> %iset118115_0_find_grouped_controls, zeroinitializer
  %iset118115_0_find_grouped_empty_bits = bitcast <16 x i1> %iset118115_0_find_grouped_empties to i16
  br label %iset118115_0_find_grouped_candidates
iset118115_0_find_grouped_candidates:
  %iset118115_0_find_grouped_candidate_bits = phi i16 [ %iset118115_0_find_grouped_match_bits, %iset118115_0_find_grouped_body ], [ %iset118115_0_find_grouped_cleared_bits, %iset118115_0_find_grouped_candidate_next ]
  %iset118115_0_find_grouped_has_candidate = icmp ne i16 %iset118115_0_find_grouped_candidate_bits, 0
  br i1 %iset118115_0_find_grouped_has_candidate, label %iset118115_0_find_grouped_candidate, label %iset118115_0_find_grouped_decision
iset118115_0_find_grouped_candidate:
  %iset118115_0_find_grouped_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %iset118115_0_find_grouped_candidate_bits, i1 false)
  %iset118115_0_find_grouped_candidate_offset = zext i16 %iset118115_0_find_grouped_candidate_offset16 to i64
  %iset118115_0_find_grouped_candidate_unwrapped = add i64 %iset118115_0_find_grouped_group_start, %iset118115_0_find_grouped_candidate_offset
  %iset118115_0_find_grouped_candidate_slot = and i64 %iset118115_0_find_grouped_candidate_unwrapped, %iset118115_0_find_grouped_mask
  %iset118115_0_find_grouped_key_ptr = getelementptr [4 x i8], ptr %iset118115_0_keys, i64 %iset118115_0_find_grouped_candidate_slot
  %iset118115_0_find_grouped_key = load i32, ptr %iset118115_0_find_grouped_key_ptr, align 4
  %iset118115_0_find_grouped_candidate_equal = icmp eq i32 %iset118115_0_find_grouped_key, %iset118115_0_query
  br i1 %iset118115_0_find_grouped_candidate_equal, label %iset118115_0_find_grouped_match, label %iset118115_0_find_grouped_candidate_next
iset118115_0_find_grouped_candidate_next:
  %iset118115_0_find_grouped_bits_minus_one = sub i16 %iset118115_0_find_grouped_candidate_bits, 1
  %iset118115_0_find_grouped_cleared_bits = and i16 %iset118115_0_find_grouped_candidate_bits, %iset118115_0_find_grouped_bits_minus_one
  br label %iset118115_0_find_grouped_candidates
iset118115_0_find_grouped_decision:
  %iset118115_0_find_grouped_has_empty = icmp ne i16 %iset118115_0_find_grouped_empty_bits, 0
  br i1 %iset118115_0_find_grouped_has_empty, label %iset118115_0_find_grouped_miss, label %iset118115_0_find_grouped_next_group
iset118115_0_find_grouped_match:
  br label %iset118115_0_find_grouped_done
iset118115_0_find_grouped_next_group:
  %iset118115_0_find_grouped_next_probe = add i64 %iset118115_0_find_grouped_probe, 16
  br label %iset118115_0_find_grouped_group
iset118115_0_find_grouped_miss:
  br label %iset118115_0_find_grouped_done
iset118115_0_find_grouped_done:
  %iset118115_0_find_grouped_found = phi i1 [ true, %iset118115_0_find_grouped_match ], [ false, %iset118115_0_find_grouped_miss ]
  %iset118115_0_find_grouped_slot = phi i64 [ %iset118115_0_find_grouped_candidate_slot, %iset118115_0_find_grouped_match ], [ 0, %iset118115_0_find_grouped_miss ]
  br label %iset118115_0_find_done
iset118115_0_find_done:
  %iset118115_0_find_found = phi i1 [ true, %iset118115_0_find_match ], [ false, %iset118115_0_find_vacant ], [ %iset118115_0_find_grouped_found, %iset118115_0_find_grouped_done ]
  %iset118115_0_find_slot = phi i64 [ %iset118115_0_find_start, %iset118115_0_find_match ], [ 0, %iset118115_0_find_vacant ], [ %iset118115_0_find_grouped_slot, %iset118115_0_find_grouped_done ]
  %iset118115_0_slot = add i64 %iset118115_0_find_slot, 0
  br i1 %iset118115_0_find_found, label %iset118115_0_found, label %iset118115_0_missing
iset118115_0_missing:
  br label %iset118115_0_not_found
iset118115_0_found:
  br label %iset118115_0_present
iset118115_0_present:
  br label %iset118115_0_complete
iset118115_0_not_found:
  br label %iset118115_0_complete
iset118115_0_complete:
  %v118115_expression0 = phi i1 [ true, %iset118115_0_present ], [ false, %iset118115_0_not_found ]
  call void @sollang_runtime_print_i1(i1 %v118115_expression0, i1 false)
  %v118115_expression_suffix = getelementptr i8, ptr @sollang_str_118116, i64 33
  call void @sollang_runtime_print(ptr %v118115_expression_suffix, i64 0, i1 true)
  br label %each118111_continue
each118111_continue:
  %each118111_current = load i64, ptr %each118111_index_slot, align 8
  %each118111_next = add i64 %each118111_current, 1
  store i64 %each118111_next, ptr %each118111_index_slot, align 8
  br label %each118111_header
each118111_exit:
  %cleanup1181036_b118104_current = load %sollang.dict, ptr %slot118104, align 8
  call void @sollang_drop_t1212(%sollang.dict %cleanup1181036_b118104_current)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
