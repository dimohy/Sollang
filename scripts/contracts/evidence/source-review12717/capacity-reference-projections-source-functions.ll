define ptr @sollang_m144_s4(ptr %arg) {
entry:
  %v118106 = load %sollang.array.i32, ptr %arg, align 8
  ret ptr %arg
}

define ptr @sollang_m144_s5(ptr %arg) {
entry:
  %v118110 = load %sollang.dict, ptr %arg, align 8
  ret ptr %arg
}

define i32 @main() {
entry:
  %slot118112 = alloca %sollang.array.i32, align 8
  %slot118113 = alloca %sollang.struct.m144_s0, align 8
  %slot118115 = alloca %sollang.dict, align 8
  %slot118116 = alloca %sollang.struct.m144_s2, align 8
  %v118118_data = call ptr @malloc(i64 16)
  %v118118_0 = insertvalue %sollang.array.i32 poison, ptr %v118118_data, 0
  %v118118_1 = insertvalue %sollang.array.i32 %v118118_0, i64 0, 1
  %v118118 = insertvalue %sollang.array.i32 %v118118_1, i64 4, 2
  %v118142_allocation_mirror = add i64 8, 23
  %v118142_allocation_offset = and i64 %v118142_allocation_mirror, -8
  %v118142_entry_bytes = mul i64 8, 8
  %v118142_allocation_bytes = add i64 %v118142_allocation_offset, %v118142_entry_bytes
  %v118142_storage = call ptr @malloc(i64 %v118142_allocation_bytes)
  %v118142_allocated = icmp ne ptr %v118142_storage, null
  br i1 %v118142_allocated, label %v118142_allocation_ready, label %v118142_allocation_failed
v118142_allocation_failed:
  call void @llvm.trap()
  unreachable
v118142_allocation_ready:
  %v118142_controls = getelementptr i8, ptr %v118142_storage, i64 0
  %v118142_entries_mirror = add i64 8, 23
  %v118142_entries_offset = and i64 %v118142_entries_mirror, -8
  %v118142_keys = getelementptr i8, ptr %v118142_storage, i64 %v118142_entries_offset
  %v118142_values = getelementptr i8, ptr %v118142_keys, i64 4
  %v118142_control_bytes = add i64 8, 16
  call void @llvm.memset.p0.i64(ptr %v118142_controls, i8 0, i64 %v118142_control_bytes, i1 false)
  %v118142_0 = insertvalue %sollang.dict poison, ptr %v118142_storage, 0
  %v118142_1 = insertvalue %sollang.dict %v118142_0, i64 0, 1
  %v118142 = insertvalue %sollang.dict %v118142_1, i64 8, 2
  store %sollang.array.i32 %v118118, ptr %slot118112, align 8
  %v118120 = load %sollang.array.i32, ptr %slot118112, align 8
  %push118119_data = extractvalue %sollang.array.i32 %v118120, 0
  %push118119_length = extractvalue %sollang.array.i32 %v118120, 1
  %push118119_capacity = extractvalue %sollang.array.i32 %v118120, 2
  %push118119_full = icmp eq i64 %push118119_length, %push118119_capacity
  %push118119_empty = icmp eq i64 %push118119_capacity, 0
  %push118119_doubled = mul i64 %push118119_capacity, 2
  %push118119_grown_capacity = select i1 %push118119_empty, i64 4, i64 %push118119_doubled
  %push118119_append_capacity = select i1 %push118119_full, i64 %push118119_grown_capacity, i64 %push118119_capacity
  %push118119_append_bytes = mul i64 %push118119_append_capacity, 4
  br i1 %push118119_full, label %push118119_grow, label %push118119_keep
push118119_keep:
  br label %push118119_ready
push118119_grow:
  %push118119_grown_data = call ptr @malloc(i64 %push118119_append_bytes)
  %push118119_allocated = icmp ne ptr %push118119_grown_data, null
  br i1 %push118119_allocated, label %push118119_copy, label %push118119_allocation_failed
push118119_allocation_failed:
  call void @llvm.trap()
  unreachable
push118119_copy:
  %push118119_copy_bytes = mul i64 %push118119_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118119_grown_data, ptr %push118119_data, i64 %push118119_copy_bytes, i1 false)
  call void @free(ptr %push118119_data)
  br label %push118119_ready
push118119_ready:
  %push118119_append_data = phi ptr [ %push118119_data, %push118119_keep ], [ %push118119_grown_data, %push118119_copy ]
  %push118119_slot = getelementptr i32, ptr %push118119_append_data, i64 %push118119_length
  store i32 10, ptr %push118119_slot, align 4
  %push118119_new_length = add i64 %push118119_length, 1
  %push118119_array0 = insertvalue %sollang.array.i32 poison, ptr %push118119_append_data, 0
  %push118119_array1 = insertvalue %sollang.array.i32 %push118119_array0, i64 %push118119_new_length, 1
  %push118119_array2 = insertvalue %sollang.array.i32 %push118119_array1, i64 %push118119_append_capacity, 2
  store %sollang.array.i32 %push118119_array2, ptr %slot118112, align 8
  %v118124 = load %sollang.array.i32, ptr %slot118112, align 8
  %callref118123_arg0_address = getelementptr i8, ptr %slot118112, i64 0
  %v118123 = call ptr @sollang_m144_s4(ptr %callref118123_arg0_address)
  %v118122 = insertvalue %sollang.struct.m144_s0 poison, ptr %v118123, 0
  store %sollang.struct.m144_s0 %v118122, ptr %slot118113, align 8
  %v118127 = load %sollang.array.i32, ptr %slot118112, align 8
  %callref118126_arg0_address = getelementptr i8, ptr %slot118112, i64 0
  %v118126 = call ptr @sollang_m144_s4(ptr %callref118126_arg0_address)
  %v118125 = insertvalue %sollang.struct.m144_s0 poison, ptr %v118126, 0
  store %sollang.struct.m144_s0 %v118125, ptr %slot118113, align 8
  %v118132 = load %sollang.struct.m144_s0, ptr %slot118113, align 8
  %v118134 = load %sollang.array.i32, ptr %slot118112, align 8
  %v118139 = load %sollang.struct.m144_s0, ptr %slot118113, align 8
  %v118141 = load %sollang.array.i32, ptr %slot118112, align 8
  %v118131 = extractvalue %sollang.struct.m144_s0 %v118132, 0
  %v118133_raw = extractvalue %sollang.array.i32 %v118134, 1
  %v118133 = trunc i64 %v118133_raw to i32
  %v118138 = extractvalue %sollang.struct.m144_s0 %v118139, 0
  %v118140_capacity_source = load %sollang.array.i32, ptr %slot118112, align 8
  %v118140_raw = extractvalue %sollang.array.i32 %v118140_capacity_source, 2
  %v118140_capacity_fits = icmp ule i64 %v118140_raw, 2147483647
  br i1 %v118140_capacity_fits, label %v118140_capacity_ok, label %v118140_capacity_fail
v118140_capacity_fail:
  call void @llvm.trap()
  unreachable
v118140_capacity_ok:
  %v118140 = trunc i64 %v118140_raw to i32
  %v118130_length_source = load %sollang.array.i32, ptr %v118131, align 8
  %v118130_raw = extractvalue %sollang.array.i32 %v118130_length_source, 1
  %v118130 = trunc i64 %v118130_raw to i32
  %v118137_capacity_source = load %sollang.array.i32, ptr %v118138, align 8
  %v118137_raw = extractvalue %sollang.array.i32 %v118137_capacity_source, 2
  %v118137_capacity_fits = icmp ule i64 %v118137_raw, 2147483647
  br i1 %v118137_capacity_fits, label %v118137_capacity_ok, label %v118137_capacity_fail
v118137_capacity_fail:
  call void @llvm.trap()
  unreachable
v118137_capacity_ok:
  %v118137 = trunc i64 %v118137_raw to i32
  %v118129 = icmp eq i32 %v118130, %v118133
  %v118136 = icmp eq i32 %v118137, %v118140
  call void @sollang_runtime_print_i1(i1 %v118129, i1 true)
  call void @sollang_runtime_print_i1(i1 %v118136, i1 true)
  store %sollang.dict %v118142, ptr %slot118115, align 8
  %v118144 = load %sollang.dict, ptr %slot118115, align 8
  %put118143_dictionary = load %sollang.dict, ptr %slot118115, align 8
  %put118143_old_storage = extractvalue %sollang.dict %put118143_dictionary, 0
  %put118143_old_length = extractvalue %sollang.dict %put118143_dictionary, 1
  %put118143_old_capacity = extractvalue %sollang.dict %put118143_dictionary, 2
  %put118143_key64 = sext i32 7 to i64
  %put118143_hash_high = lshr i64 %put118143_key64, 32
  %put118143_hash_fold = xor i64 %put118143_key64, %put118143_hash_high
  %put118143_hash = mul i64 %put118143_hash_fold, -7046029254386353131
  %put118143_h2_shifted = lshr i64 %put118143_hash, 57
  %put118143_h2_raw = and i64 %put118143_h2_shifted, 127
  %put118143_h2_zero = icmp eq i64 %put118143_h2_raw, 0
  %put118143_h2_value = select i1 %put118143_h2_zero, i64 1, i64 %put118143_h2_raw
  %put118143_h2 = trunc i64 %put118143_h2_value to i8
  %put118143_old_controls = getelementptr i8, ptr %put118143_old_storage, i64 0
  %put118143_old_entries_mirror = add i64 %put118143_old_capacity, 23
  %put118143_old_entries_offset = and i64 %put118143_old_entries_mirror, -8
  %put118143_old_keys = getelementptr i8, ptr %put118143_old_storage, i64 %put118143_old_entries_offset
  %put118143_old_values = getelementptr i8, ptr %put118143_old_keys, i64 4
  %put118143_probe_query = freeze i32 7
  %put118143_has_capacity = icmp ugt i64 %put118143_old_capacity, 0
  br i1 %put118143_has_capacity, label %put118143_lookup_start, label %put118143_grow
put118143_lookup_start:
  %put118143_probe_mask = sub i64 %put118143_old_capacity, 1
  %put118143_probe_start = and i64 %put118143_hash, %put118143_probe_mask
  br label %put118143_probe_entry
put118143_probe_entry:
  br label %put118143_probe_group
put118143_probe_group:
  %put118143_probe_probe = phi i64 [ 0, %put118143_probe_entry ], [ %put118143_probe_next_probe, %put118143_probe_next_group ]
  %put118143_probe_active = icmp ult i64 %put118143_probe_probe, %put118143_old_capacity
  br i1 %put118143_probe_active, label %put118143_probe_body, label %put118143_probe_miss
put118143_probe_body:
  %put118143_probe_unwrapped = add i64 %put118143_probe_start, %put118143_probe_probe
  %put118143_probe_group_start = and i64 %put118143_probe_unwrapped, %put118143_probe_mask
  %put118143_probe_control_ptr = getelementptr i8, ptr %put118143_old_controls, i64 %put118143_probe_group_start
  %put118143_probe_controls = load <16 x i8>, ptr %put118143_probe_control_ptr, align 1
  %put118143_probe_h2_seed = insertelement <16 x i8> poison, i8 %put118143_h2, i64 0
  %put118143_probe_h2_vector = shufflevector <16 x i8> %put118143_probe_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %put118143_probe_matches = icmp eq <16 x i8> %put118143_probe_controls, %put118143_probe_h2_vector
  %put118143_probe_match_bits = bitcast <16 x i1> %put118143_probe_matches to i16
  %put118143_probe_empties = icmp eq <16 x i8> %put118143_probe_controls, zeroinitializer
  %put118143_probe_empty_bits = bitcast <16 x i1> %put118143_probe_empties to i16
  br label %put118143_probe_candidates
put118143_probe_candidates:
  %put118143_probe_candidate_bits = phi i16 [ %put118143_probe_match_bits, %put118143_probe_body ], [ %put118143_probe_cleared_bits, %put118143_probe_candidate_next ]
  %put118143_probe_has_candidate = icmp ne i16 %put118143_probe_candidate_bits, 0
  br i1 %put118143_probe_has_candidate, label %put118143_probe_candidate, label %put118143_probe_decision
put118143_probe_candidate:
  %put118143_probe_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %put118143_probe_candidate_bits, i1 false)
  %put118143_probe_candidate_offset = zext i16 %put118143_probe_candidate_offset16 to i64
  %put118143_probe_candidate_unwrapped = add i64 %put118143_probe_group_start, %put118143_probe_candidate_offset
  %put118143_probe_candidate_slot = and i64 %put118143_probe_candidate_unwrapped, %put118143_probe_mask
  %put118143_probe_key_ptr = getelementptr [8 x i8], ptr %put118143_old_keys, i64 %put118143_probe_candidate_slot
  %put118143_probe_key = load i32, ptr %put118143_probe_key_ptr, align 4
  %put118143_probe_candidate_equal = icmp eq i32 %put118143_probe_key, %put118143_probe_query
  br i1 %put118143_probe_candidate_equal, label %put118143_probe_match, label %put118143_probe_candidate_next
put118143_probe_candidate_next:
  %put118143_probe_bits_minus_one = sub i16 %put118143_probe_candidate_bits, 1
  %put118143_probe_cleared_bits = and i16 %put118143_probe_candidate_bits, %put118143_probe_bits_minus_one
  br label %put118143_probe_candidates
put118143_probe_decision:
  %put118143_probe_has_empty = icmp ne i16 %put118143_probe_empty_bits, 0
  br i1 %put118143_probe_has_empty, label %put118143_probe_empty, label %put118143_probe_next_group
put118143_probe_empty:
  %put118143_probe_empty_offset16 = call i16 @llvm.cttz.i16(i16 %put118143_probe_empty_bits, i1 false)
  %put118143_probe_empty_offset = zext i16 %put118143_probe_empty_offset16 to i64
  %put118143_probe_empty_unwrapped = add i64 %put118143_probe_group_start, %put118143_probe_empty_offset
  %put118143_probe_empty_slot = and i64 %put118143_probe_empty_unwrapped, %put118143_probe_mask
  br label %put118143_probe_done
put118143_probe_match:
  br label %put118143_probe_done
put118143_probe_next_group:
  %put118143_probe_next_probe = add i64 %put118143_probe_probe, 16
  br label %put118143_probe_group
put118143_probe_miss:
  br label %put118143_probe_done
put118143_probe_done:
  %put118143_probe_found = phi i1 [ false, %put118143_probe_empty ], [ true, %put118143_probe_match ], [ false, %put118143_probe_miss ]
  %put118143_probe_slot = phi i64 [ %put118143_probe_empty_slot, %put118143_probe_empty ], [ %put118143_probe_candidate_slot, %put118143_probe_match ], [ 0, %put118143_probe_miss ]
  %put118143_lookup_slot = add i64 %put118143_probe_slot, 0
  br i1 %put118143_probe_found, label %put118143_update_in_place, label %put118143_new_key
put118143_update_in_place:
  %put118143_update_in_place_ptr = getelementptr [8 x i8], ptr %put118143_old_values, i64 %put118143_lookup_slot
  store i32 77, ptr %put118143_update_in_place_ptr, align 4
  br label %put118143_complete
put118143_new_key:
  %put118143_new_key_slot = add i64 %put118143_lookup_slot, 0
  %put118143_candidate_length = add i64 %put118143_old_length, 1
  %put118143_candidate_scaled = mul i64 %put118143_candidate_length, 8
  %put118143_load_limit = mul i64 %put118143_old_capacity, 7
  %put118143_fits = icmp ule i64 %put118143_candidate_scaled, %put118143_load_limit
  br i1 %put118143_fits, label %put118143_insert_in_place, label %put118143_grow
put118143_insert_in_place:
  %put118143_insert_in_place_key_ptr = getelementptr [8 x i8], ptr %put118143_old_keys, i64 %put118143_new_key_slot
  store i32 7, ptr %put118143_insert_in_place_key_ptr, align 4
  %put118143_insert_in_place_value_ptr = getelementptr [8 x i8], ptr %put118143_old_values, i64 %put118143_new_key_slot
  store i32 77, ptr %put118143_insert_in_place_value_ptr, align 4
  %put118143_insert_in_place_control_ptr = getelementptr i8, ptr %put118143_old_controls, i64 %put118143_new_key_slot
  %put118143_insert_control_control_ptr = getelementptr i8, ptr %put118143_old_controls, i64 %put118143_new_key_slot
  store i8 %put118143_h2, ptr %put118143_insert_control_control_ptr, align 1
  %put118143_insert_control_mirror_needed = icmp ult i64 %put118143_new_key_slot, 16
  %put118143_insert_control_mirror_candidate = add i64 %put118143_new_key_slot, %put118143_old_capacity
  %put118143_insert_control_mirror_slot = select i1 %put118143_insert_control_mirror_needed, i64 %put118143_insert_control_mirror_candidate, i64 %put118143_new_key_slot
  %put118143_insert_control_mirror_ptr = getelementptr i8, ptr %put118143_old_controls, i64 %put118143_insert_control_mirror_slot
  store i8 %put118143_h2, ptr %put118143_insert_control_mirror_ptr, align 1
  %put118143_in_place_result = insertvalue %sollang.dict %put118143_dictionary, i64 %put118143_candidate_length, 1
  store %sollang.dict %put118143_in_place_result, ptr %slot118115, align 8
  br label %put118143_complete
put118143_grow:
  %put118143_capacity_double = mul i64 %put118143_old_capacity, 2
  %put118143_capacity_small = icmp ult i64 %put118143_old_capacity, 4
  %put118143_capacity = select i1 %put118143_capacity_small, i64 4, i64 %put118143_capacity_double
  %put118143_allocation_mirror = add i64 %put118143_capacity, 23
  %put118143_allocation_offset = and i64 %put118143_allocation_mirror, -8
  %put118143_entry_bytes = mul i64 %put118143_capacity, 8
  %put118143_allocation_bytes = add i64 %put118143_allocation_offset, %put118143_entry_bytes
  %put118143_storage = call ptr @malloc(i64 %put118143_allocation_bytes)
  %put118143_allocated = icmp ne ptr %put118143_storage, null
  br i1 %put118143_allocated, label %put118143_allocation_ready, label %put118143_allocation_failed
put118143_allocation_failed:
  call void @llvm.trap()
  unreachable
put118143_allocation_ready:
  %put118143_controls = getelementptr i8, ptr %put118143_storage, i64 0
  %put118143_entries_mirror = add i64 %put118143_capacity, 23
  %put118143_entries_offset = and i64 %put118143_entries_mirror, -8
  %put118143_keys = getelementptr i8, ptr %put118143_storage, i64 %put118143_entries_offset
  %put118143_values = getelementptr i8, ptr %put118143_keys, i64 4
  %put118143_control_bytes = add i64 %put118143_capacity, 16
  call void @llvm.memset.p0.i64(ptr %put118143_controls, i8 0, i64 %put118143_control_bytes, i1 false)
  br label %put118143_rehash_start
put118143_rehash_loop:
  %put118143_rehash_index = phi i64 [ 0, %put118143_rehash_start ], [ %put118143_rehash_next, %put118143_rehash_advance ]
  %put118143_rehash_active = icmp ult i64 %put118143_rehash_index, %put118143_old_capacity
  br i1 %put118143_rehash_active, label %put118143_rehash_check, label %put118143_rehash_done
put118143_rehash_check:
  %put118143_old_control_ptr = getelementptr i8, ptr %put118143_old_controls, i64 0
  %put118143_old_control_slot = getelementptr i8, ptr %put118143_old_control_ptr, i64 %put118143_rehash_index
  %put118143_old_control = load i8, ptr %put118143_old_control_slot, align 1
  %put118143_rehash_occupied = icmp sgt i8 %put118143_old_control, 0
  br i1 %put118143_rehash_occupied, label %put118143_rehash_copy, label %put118143_rehash_advance
put118143_rehash_copy:
  %put118143_rehash_key_ptr = getelementptr [8 x i8], ptr %put118143_old_keys, i64 %put118143_rehash_index
  %put118143_rehash_key = load i32, ptr %put118143_rehash_key_ptr, align 4
  %put118143_rehash_value_ptr = getelementptr [8 x i8], ptr %put118143_old_values, i64 %put118143_rehash_index
  %put118143_rehash_value = load i32, ptr %put118143_rehash_value_ptr, align 4
  %put118143_rehash_key64 = sext i32 %put118143_rehash_key to i64
  %put118143_rehash_hash_high = lshr i64 %put118143_rehash_key64, 32
  %put118143_rehash_hash_fold = xor i64 %put118143_rehash_key64, %put118143_rehash_hash_high
  %put118143_rehash_hash = mul i64 %put118143_rehash_hash_fold, -7046029254386353131
  %put118143_rehash_h2_shifted = lshr i64 %put118143_rehash_hash, 57
  %put118143_rehash_h2_raw = and i64 %put118143_rehash_h2_shifted, 127
  %put118143_rehash_h2_zero = icmp eq i64 %put118143_rehash_h2_raw, 0
  %put118143_rehash_h2_value = select i1 %put118143_rehash_h2_zero, i64 1, i64 %put118143_rehash_h2_raw
  %put118143_rehash_h2 = trunc i64 %put118143_rehash_h2_value to i8
  %put118143_rehash_probe_mask = sub i64 %put118143_capacity, 1
  %put118143_rehash_probe_start = and i64 %put118143_rehash_hash, %put118143_rehash_probe_mask
  br label %put118143_rehash_probe_entry
put118143_rehash_probe_entry:
  br label %put118143_rehash_probe_group
put118143_rehash_probe_group:
  %put118143_rehash_probe_probe = phi i64 [ 0, %put118143_rehash_probe_entry ], [ %put118143_rehash_probe_next_probe, %put118143_rehash_probe_next_group ]
  %put118143_rehash_probe_active = icmp ult i64 %put118143_rehash_probe_probe, %put118143_capacity
  br i1 %put118143_rehash_probe_active, label %put118143_rehash_probe_body, label %put118143_rehash_probe_miss
put118143_rehash_probe_body:
  %put118143_rehash_probe_unwrapped = add i64 %put118143_rehash_probe_start, %put118143_rehash_probe_probe
  %put118143_rehash_probe_group_start = and i64 %put118143_rehash_probe_unwrapped, %put118143_rehash_probe_mask
  %put118143_rehash_probe_control_ptr = getelementptr i8, ptr %put118143_controls, i64 %put118143_rehash_probe_group_start
  %put118143_rehash_probe_controls = load <16 x i8>, ptr %put118143_rehash_probe_control_ptr, align 1
  %put118143_rehash_probe_h2_seed = insertelement <16 x i8> poison, i8 %put118143_rehash_h2, i64 0
  %put118143_rehash_probe_h2_vector = shufflevector <16 x i8> %put118143_rehash_probe_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %put118143_rehash_probe_matches = icmp eq <16 x i8> %put118143_rehash_probe_controls, %put118143_rehash_probe_h2_vector
  %put118143_rehash_probe_match_bits = bitcast <16 x i1> %put118143_rehash_probe_matches to i16
  %put118143_rehash_probe_empties = icmp eq <16 x i8> %put118143_rehash_probe_controls, zeroinitializer
  %put118143_rehash_probe_empty_bits = bitcast <16 x i1> %put118143_rehash_probe_empties to i16
  br label %put118143_rehash_probe_candidates
put118143_rehash_probe_candidates:
  %put118143_rehash_probe_candidate_bits = phi i16 [ %put118143_rehash_probe_match_bits, %put118143_rehash_probe_body ], [ %put118143_rehash_probe_cleared_bits, %put118143_rehash_probe_candidate_next ]
  %put118143_rehash_probe_has_candidate = icmp ne i16 %put118143_rehash_probe_candidate_bits, 0
  br i1 %put118143_rehash_probe_has_candidate, label %put118143_rehash_probe_candidate, label %put118143_rehash_probe_decision
put118143_rehash_probe_candidate:
  %put118143_rehash_probe_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %put118143_rehash_probe_candidate_bits, i1 false)
  %put118143_rehash_probe_candidate_offset = zext i16 %put118143_rehash_probe_candidate_offset16 to i64
  %put118143_rehash_probe_candidate_unwrapped = add i64 %put118143_rehash_probe_group_start, %put118143_rehash_probe_candidate_offset
  %put118143_rehash_probe_candidate_slot = and i64 %put118143_rehash_probe_candidate_unwrapped, %put118143_rehash_probe_mask
  %put118143_rehash_probe_key_ptr = getelementptr [8 x i8], ptr %put118143_keys, i64 %put118143_rehash_probe_candidate_slot
  %put118143_rehash_probe_key = load i32, ptr %put118143_rehash_probe_key_ptr, align 4
  %put118143_rehash_probe_candidate_equal = icmp eq i32 %put118143_rehash_probe_key, %put118143_rehash_key
  br i1 %put118143_rehash_probe_candidate_equal, label %put118143_rehash_probe_match, label %put118143_rehash_probe_candidate_next
put118143_rehash_probe_candidate_next:
  %put118143_rehash_probe_bits_minus_one = sub i16 %put118143_rehash_probe_candidate_bits, 1
  %put118143_rehash_probe_cleared_bits = and i16 %put118143_rehash_probe_candidate_bits, %put118143_rehash_probe_bits_minus_one
  br label %put118143_rehash_probe_candidates
put118143_rehash_probe_decision:
  %put118143_rehash_probe_has_empty = icmp ne i16 %put118143_rehash_probe_empty_bits, 0
  br i1 %put118143_rehash_probe_has_empty, label %put118143_rehash_probe_empty, label %put118143_rehash_probe_next_group
put118143_rehash_probe_empty:
  %put118143_rehash_probe_empty_offset16 = call i16 @llvm.cttz.i16(i16 %put118143_rehash_probe_empty_bits, i1 false)
  %put118143_rehash_probe_empty_offset = zext i16 %put118143_rehash_probe_empty_offset16 to i64
  %put118143_rehash_probe_empty_unwrapped = add i64 %put118143_rehash_probe_group_start, %put118143_rehash_probe_empty_offset
  %put118143_rehash_probe_empty_slot = and i64 %put118143_rehash_probe_empty_unwrapped, %put118143_rehash_probe_mask
  br label %put118143_rehash_probe_done
put118143_rehash_probe_match:
  br label %put118143_rehash_probe_done
put118143_rehash_probe_next_group:
  %put118143_rehash_probe_next_probe = add i64 %put118143_rehash_probe_probe, 16
  br label %put118143_rehash_probe_group
put118143_rehash_probe_miss:
  br label %put118143_rehash_probe_done
put118143_rehash_probe_done:
  %put118143_rehash_probe_found = phi i1 [ false, %put118143_rehash_probe_empty ], [ true, %put118143_rehash_probe_match ], [ false, %put118143_rehash_probe_miss ]
  %put118143_rehash_probe_slot = phi i64 [ %put118143_rehash_probe_empty_slot, %put118143_rehash_probe_empty ], [ %put118143_rehash_probe_candidate_slot, %put118143_rehash_probe_match ], [ 0, %put118143_rehash_probe_miss ]
  %put118143_rehash_slot = add i64 %put118143_rehash_probe_slot, 0
  br label %put118143_rehash_store
put118143_rehash_store:
  %put118143_rehash_new_key_ptr = getelementptr [8 x i8], ptr %put118143_keys, i64 %put118143_rehash_slot
  store i32 %put118143_rehash_key, ptr %put118143_rehash_new_key_ptr, align 4
  %put118143_rehash_new_value_ptr = getelementptr [8 x i8], ptr %put118143_values, i64 %put118143_rehash_slot
  store i32 %put118143_rehash_value, ptr %put118143_rehash_new_value_ptr, align 4
  %put118143_rehash_store_control_control_ptr = getelementptr i8, ptr %put118143_controls, i64 %put118143_rehash_slot
  store i8 %put118143_rehash_h2, ptr %put118143_rehash_store_control_control_ptr, align 1
  %put118143_rehash_store_control_mirror_needed = icmp ult i64 %put118143_rehash_slot, 16
  %put118143_rehash_store_control_mirror_candidate = add i64 %put118143_rehash_slot, %put118143_capacity
  %put118143_rehash_store_control_mirror_slot = select i1 %put118143_rehash_store_control_mirror_needed, i64 %put118143_rehash_store_control_mirror_candidate, i64 %put118143_rehash_slot
  %put118143_rehash_store_control_mirror_ptr = getelementptr i8, ptr %put118143_controls, i64 %put118143_rehash_store_control_mirror_slot
  store i8 %put118143_rehash_h2, ptr %put118143_rehash_store_control_mirror_ptr, align 1
  br label %put118143_rehash_advance
put118143_rehash_advance:
  %put118143_rehash_next = add i64 %put118143_rehash_index, 1
  br label %put118143_rehash_loop
put118143_rehash_start:
  br label %put118143_rehash_loop
put118143_rehash_done:
  call void @free(ptr %put118143_old_storage)
  %put118143_grown_probe_mask = sub i64 %put118143_capacity, 1
  %put118143_grown_probe_start = and i64 %put118143_hash, %put118143_grown_probe_mask
  br label %put118143_grown_probe_entry
put118143_grown_probe_entry:
  br label %put118143_grown_probe_group
put118143_grown_probe_group:
  %put118143_grown_probe_probe = phi i64 [ 0, %put118143_grown_probe_entry ], [ %put118143_grown_probe_next_probe, %put118143_grown_probe_next_group ]
  %put118143_grown_probe_active = icmp ult i64 %put118143_grown_probe_probe, %put118143_capacity
  br i1 %put118143_grown_probe_active, label %put118143_grown_probe_body, label %put118143_grown_probe_miss
put118143_grown_probe_body:
  %put118143_grown_probe_unwrapped = add i64 %put118143_grown_probe_start, %put118143_grown_probe_probe
  %put118143_grown_probe_group_start = and i64 %put118143_grown_probe_unwrapped, %put118143_grown_probe_mask
  %put118143_grown_probe_control_ptr = getelementptr i8, ptr %put118143_controls, i64 %put118143_grown_probe_group_start
  %put118143_grown_probe_controls = load <16 x i8>, ptr %put118143_grown_probe_control_ptr, align 1
  %put118143_grown_probe_h2_seed = insertelement <16 x i8> poison, i8 %put118143_h2, i64 0
  %put118143_grown_probe_h2_vector = shufflevector <16 x i8> %put118143_grown_probe_h2_seed, <16 x i8> poison, <16 x i32> zeroinitializer
  %put118143_grown_probe_matches = icmp eq <16 x i8> %put118143_grown_probe_controls, %put118143_grown_probe_h2_vector
  %put118143_grown_probe_match_bits = bitcast <16 x i1> %put118143_grown_probe_matches to i16
  %put118143_grown_probe_empties = icmp eq <16 x i8> %put118143_grown_probe_controls, zeroinitializer
  %put118143_grown_probe_empty_bits = bitcast <16 x i1> %put118143_grown_probe_empties to i16
  br label %put118143_grown_probe_candidates
put118143_grown_probe_candidates:
  %put118143_grown_probe_candidate_bits = phi i16 [ %put118143_grown_probe_match_bits, %put118143_grown_probe_body ], [ %put118143_grown_probe_cleared_bits, %put118143_grown_probe_candidate_next ]
  %put118143_grown_probe_has_candidate = icmp ne i16 %put118143_grown_probe_candidate_bits, 0
  br i1 %put118143_grown_probe_has_candidate, label %put118143_grown_probe_candidate, label %put118143_grown_probe_decision
put118143_grown_probe_candidate:
  %put118143_grown_probe_candidate_offset16 = call i16 @llvm.cttz.i16(i16 %put118143_grown_probe_candidate_bits, i1 false)
  %put118143_grown_probe_candidate_offset = zext i16 %put118143_grown_probe_candidate_offset16 to i64
  %put118143_grown_probe_candidate_unwrapped = add i64 %put118143_grown_probe_group_start, %put118143_grown_probe_candidate_offset
  %put118143_grown_probe_candidate_slot = and i64 %put118143_grown_probe_candidate_unwrapped, %put118143_grown_probe_mask
  %put118143_grown_probe_key_ptr = getelementptr [8 x i8], ptr %put118143_keys, i64 %put118143_grown_probe_candidate_slot
  %put118143_grown_probe_key = load i32, ptr %put118143_grown_probe_key_ptr, align 4
  %put118143_grown_probe_candidate_equal = icmp eq i32 %put118143_grown_probe_key, %put118143_probe_query
  br i1 %put118143_grown_probe_candidate_equal, label %put118143_grown_probe_match, label %put118143_grown_probe_candidate_next
put118143_grown_probe_candidate_next:
  %put118143_grown_probe_bits_minus_one = sub i16 %put118143_grown_probe_candidate_bits, 1
  %put118143_grown_probe_cleared_bits = and i16 %put118143_grown_probe_candidate_bits, %put118143_grown_probe_bits_minus_one
  br label %put118143_grown_probe_candidates
put118143_grown_probe_decision:
  %put118143_grown_probe_has_empty = icmp ne i16 %put118143_grown_probe_empty_bits, 0
  br i1 %put118143_grown_probe_has_empty, label %put118143_grown_probe_empty, label %put118143_grown_probe_next_group
put118143_grown_probe_empty:
  %put118143_grown_probe_empty_offset16 = call i16 @llvm.cttz.i16(i16 %put118143_grown_probe_empty_bits, i1 false)
  %put118143_grown_probe_empty_offset = zext i16 %put118143_grown_probe_empty_offset16 to i64
  %put118143_grown_probe_empty_unwrapped = add i64 %put118143_grown_probe_group_start, %put118143_grown_probe_empty_offset
  %put118143_grown_probe_empty_slot = and i64 %put118143_grown_probe_empty_unwrapped, %put118143_grown_probe_mask
  br label %put118143_grown_probe_done
put118143_grown_probe_match:
  br label %put118143_grown_probe_done
put118143_grown_probe_next_group:
  %put118143_grown_probe_next_probe = add i64 %put118143_grown_probe_probe, 16
  br label %put118143_grown_probe_group
put118143_grown_probe_miss:
  br label %put118143_grown_probe_done
put118143_grown_probe_done:
  %put118143_grown_probe_found = phi i1 [ false, %put118143_grown_probe_empty ], [ true, %put118143_grown_probe_match ], [ false, %put118143_grown_probe_miss ]
  %put118143_grown_probe_slot = phi i64 [ %put118143_grown_probe_empty_slot, %put118143_grown_probe_empty ], [ %put118143_grown_probe_candidate_slot, %put118143_grown_probe_match ], [ 0, %put118143_grown_probe_miss ]
  %put118143_slot = add i64 %put118143_grown_probe_slot, 0
  br label %put118143_insert
put118143_insert:
  %put118143_insert_key_ptr = getelementptr [8 x i8], ptr %put118143_keys, i64 %put118143_slot
  store i32 7, ptr %put118143_insert_key_ptr, align 4
  %put118143_insert_value_ptr = getelementptr [8 x i8], ptr %put118143_values, i64 %put118143_slot
  store i32 77, ptr %put118143_insert_value_ptr, align 4
  %put118143_store_control_control_ptr = getelementptr i8, ptr %put118143_controls, i64 %put118143_slot
  store i8 %put118143_h2, ptr %put118143_store_control_control_ptr, align 1
  %put118143_store_control_mirror_needed = icmp ult i64 %put118143_slot, 16
  %put118143_store_control_mirror_candidate = add i64 %put118143_slot, %put118143_capacity
  %put118143_store_control_mirror_slot = select i1 %put118143_store_control_mirror_needed, i64 %put118143_store_control_mirror_candidate, i64 %put118143_slot
  %put118143_store_control_mirror_ptr = getelementptr i8, ptr %put118143_controls, i64 %put118143_store_control_mirror_slot
  store i8 %put118143_h2, ptr %put118143_store_control_mirror_ptr, align 1
  %put118143_new_length = add i64 %put118143_old_length, 1
  %put118143_result3_0 = insertvalue %sollang.dict poison, ptr %put118143_storage, 0
  %put118143_result3_1 = insertvalue %sollang.dict %put118143_result3_0, i64 %put118143_new_length, 1
  %put118143_result3 = insertvalue %sollang.dict %put118143_result3_1, i64 %put118143_capacity, 2
  store %sollang.dict %put118143_result3, ptr %slot118115, align 8
  br label %put118143_complete
put118143_complete:
  %v118149 = load %sollang.dict, ptr %slot118115, align 8
  %callref118148_arg0_address = getelementptr i8, ptr %slot118115, i64 0
  %v118148 = call ptr @sollang_m144_s5(ptr %callref118148_arg0_address)
  %v118147 = insertvalue %sollang.struct.m144_s2 poison, ptr %v118148, 0
  store %sollang.struct.m144_s2 %v118147, ptr %slot118116, align 8
  %v118152 = load %sollang.dict, ptr %slot118115, align 8
  %callref118151_arg0_address = getelementptr i8, ptr %slot118115, i64 0
  %v118151 = call ptr @sollang_m144_s5(ptr %callref118151_arg0_address)
  %v118150 = insertvalue %sollang.struct.m144_s2 poison, ptr %v118151, 0
  store %sollang.struct.m144_s2 %v118150, ptr %slot118116, align 8
  %v118157 = load %sollang.struct.m144_s2, ptr %slot118116, align 8
  %v118159 = load %sollang.dict, ptr %slot118115, align 8
  %v118164 = load %sollang.struct.m144_s2, ptr %slot118116, align 8
  %v118166 = load %sollang.dict, ptr %slot118115, align 8
  %v118156 = extractvalue %sollang.struct.m144_s2 %v118157, 0
  %v118158_length_source = load %sollang.dict, ptr %slot118115, align 8
  %v118158_raw = extractvalue %sollang.dict %v118158_length_source, 1
  %v118158 = trunc i64 %v118158_raw to i32
  %v118163 = extractvalue %sollang.struct.m144_s2 %v118164, 0
  %v118165_capacity_source = load %sollang.dict, ptr %slot118115, align 8
  %v118165_raw = extractvalue %sollang.dict %v118165_capacity_source, 2
  %v118165_capacity_fits = icmp ule i64 %v118165_raw, 2147483647
  br i1 %v118165_capacity_fits, label %v118165_capacity_ok, label %v118165_capacity_fail
v118165_capacity_fail:
  call void @llvm.trap()
  unreachable
v118165_capacity_ok:
  %v118165 = trunc i64 %v118165_raw to i32
  %v118155_length_source = load %sollang.dict, ptr %v118156, align 8
  %v118155_raw = extractvalue %sollang.dict %v118155_length_source, 1
  %v118155 = trunc i64 %v118155_raw to i32
  %v118162_capacity_source = load %sollang.dict, ptr %v118163, align 8
  %v118162_raw = extractvalue %sollang.dict %v118162_capacity_source, 2
  %v118162_capacity_fits = icmp ule i64 %v118162_raw, 2147483647
  br i1 %v118162_capacity_fits, label %v118162_capacity_ok, label %v118162_capacity_fail
v118162_capacity_fail:
  call void @llvm.trap()
  unreachable
v118162_capacity_ok:
  %v118162 = trunc i64 %v118162_raw to i32
  %v118154 = icmp eq i32 %v118155, %v118158
  %v118161 = icmp eq i32 %v118162, %v118165
  call void @sollang_runtime_print_i1(i1 %v118154, i1 true)
  call void @sollang_runtime_print_i1(i1 %v118161, i1 true)
  %cleanup1181116_b118116_current = load %sollang.struct.m144_s2, ptr %slot118116, align 8
  call void @sollang_drop_t1216(%sollang.struct.m144_s2 %cleanup1181116_b118116_current)
  %cleanup1181116_b118115_current = load %sollang.dict, ptr %slot118115, align 8
  call void @sollang_drop_t1212(%sollang.dict %cleanup1181116_b118115_current)
  %cleanup1181116_b118113_current = load %sollang.struct.m144_s0, ptr %slot118113, align 8
  call void @sollang_drop_t1215(%sollang.struct.m144_s0 %cleanup1181116_b118113_current)
  %cleanup1181116_b118112_current = load %sollang.array.i32, ptr %slot118112, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181116_b118112_current)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
