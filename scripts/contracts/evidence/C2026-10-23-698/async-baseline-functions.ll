define i1 @sollang_m144_s0_async_worker(ptr %control) {
entry:
  %async_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_context = load ptr, ptr %async_context_slot, align 8
  %async_frame_slot = getelementptr i8, ptr %async_context, i64 8
  %slot118105 = alloca i32, align 4
  %each118108_index_slot = getelementptr i8, ptr %async_context, i64 16
  %each118108_limit_slot = getelementptr i8, ptr %async_context, i64 24
  %async_resume_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state = load i32, ptr %async_resume_state_slot, align 4
  switch i32 %async_resume_state, label %async_state_invalid [ i32 0, label %async_state_start i32 1, label %async_resume1 ]
async_state_invalid:
  call void @llvm.trap()
  unreachable
async_state_start:
  store i32 0, ptr %slot118105, align 4
  %each_role_m144_s10_at118110_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118110 = trunc i64 %each_role_m144_s10_at118110_cursor to i32
  %each_role_m144_s10_at118111_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118111 = trunc i64 %each_role_m144_s10_at118111_cursor to i32
  %each_role_m144_s10_at118109_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118109 = trunc i64 %each_role_m144_s10_at118109_cursor to i32
  %v118109_start = insertvalue { i32, i32 } poison, i32 1, 0
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
  %each_role_m144_s10_at118112_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118112 = trunc i64 %each_role_m144_s10_at118112_cursor to i32
  %async_frame1_store = call ptr @malloc(i64 4)
  %async_frame1_allocated = icmp ne ptr %async_frame1_store, null
  br i1 %async_frame1_allocated, label %async_frame1_ready, label %async_frame1_failed
async_frame1_failed:
  call void @llvm.trap()
  unreachable
async_frame1_ready:
  store ptr %async_frame1_store, ptr %async_frame_slot, align 8
  %async_frame1_118105_store_address = getelementptr i8, ptr %async_frame1_store, i64 0
  %async_frame1_118105_stored = load i32, ptr %slot118105, align 4
  store i32 %async_frame1_118105_stored, ptr %async_frame1_118105_store_address, align 4
  store i32 1, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume1:
  %async_frame1_load = load ptr, ptr %async_frame_slot, align 8
  %async_frame1_118105_load_address = getelementptr i8, ptr %async_frame1_load, i64 0
  %async_frame1_118105_loaded = load i32, ptr %async_frame1_118105_load_address, align 4
  store i32 %async_frame1_118105_loaded, ptr %slot118105, align 4
  call void @free(ptr %async_frame1_load)
  store ptr null, ptr %async_frame_slot, align 8
  %each_role_m144_s10_at118114_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118114 = trunc i64 %each_role_m144_s10_at118114_cursor to i32
  %v118114 = load i32, ptr %slot118105, align 4
  %each_role_m144_s10_at118115_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118115 = trunc i64 %each_role_m144_s10_at118115_cursor to i32
  %v118115 = freeze i32 %each_role_m144_s10_at118115
  %each_role_m144_s10_at118113_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118113 = trunc i64 %each_role_m144_s10_at118113_cursor to i32
  %v118113 = add i32 %v118114, %v118115
  %each_role_m144_s10_at118106_cursor = load i64, ptr %each118108_index_slot, align 8
  %each_role_m144_s10_at118106 = trunc i64 %each_role_m144_s10_at118106_cursor to i32
  store i32 %v118113, ptr %slot118105, align 4
  br label %each118108_continue
each118108_continue:
  %each118108_current = load i64, ptr %each118108_index_slot, align 8
  %each118108_next = add i64 %each118108_current, 1
  store i64 %each118108_next, ptr %each118108_index_slot, align 8
  br label %each118108_header
each118108_exit:
  %v118116 = load i32, ptr %slot118105, align 4
  %async_completed_result = freeze i32 %v118116
  store i32 %async_completed_result, ptr %async_context, align 4
  ret i1 true
}

define i1 @sollang_m144_s4_async_worker(ptr %control) {
entry:
  %async_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_context = load ptr, ptr %async_context_slot, align 8
  %async_frame_slot = getelementptr i8, ptr %async_context, i64 8
  %slot118119 = alloca i32, align 4
  %each118122_index_slot = getelementptr i8, ptr %async_context, i64 16
  %each118122_limit_slot = getelementptr i8, ptr %async_context, i64 24
  %async_resume_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state = load i32, ptr %async_resume_state_slot, align 4
  switch i32 %async_resume_state, label %async_state_invalid [ i32 0, label %async_state_start i32 1, label %async_resume1 ]
async_state_invalid:
  call void @llvm.trap()
  unreachable
async_state_start:
  store i32 0, ptr %slot118119, align 4
  %each_role_m144_s11_at118123_cursor = load i64, ptr %each118122_index_slot, align 8
  %each_role_m144_s11_at118123 = trunc i64 %each_role_m144_s11_at118123_cursor to i32
  %each118122_count = freeze i32 2
  %each118122_limit = sext i32 %each118122_count to i64
  store i64 1, ptr %each118122_index_slot, align 8
  store i64 %each118122_limit, ptr %each118122_limit_slot, align 8
  br label %each118122_header
each118122_header:
  %each118122_index = load i64, ptr %each118122_index_slot, align 8
  %each118122_bound = load i64, ptr %each118122_limit_slot, align 8
  %each118122_done = icmp sgt i64 %each118122_index, %each118122_bound
  br i1 %each118122_done, label %each118122_exit, label %each118122_body
each118122_body:
  %each118122_item = trunc i64 %each118122_index to i32
  %each_role_m144_s11_at118124_cursor = load i64, ptr %each118122_index_slot, align 8
  %each_role_m144_s11_at118124 = trunc i64 %each_role_m144_s11_at118124_cursor to i32
  %async_frame1_store = call ptr @malloc(i64 4)
  %async_frame1_allocated = icmp ne ptr %async_frame1_store, null
  br i1 %async_frame1_allocated, label %async_frame1_ready, label %async_frame1_failed
async_frame1_failed:
  call void @llvm.trap()
  unreachable
async_frame1_ready:
  store ptr %async_frame1_store, ptr %async_frame_slot, align 8
  %async_frame1_118119_store_address = getelementptr i8, ptr %async_frame1_store, i64 0
  %async_frame1_118119_stored = load i32, ptr %slot118119, align 4
  store i32 %async_frame1_118119_stored, ptr %async_frame1_118119_store_address, align 4
  store i32 1, ptr %async_resume_state_slot, align 4
  ret i1 false
async_resume1:
  %async_frame1_load = load ptr, ptr %async_frame_slot, align 8
  %async_frame1_118119_load_address = getelementptr i8, ptr %async_frame1_load, i64 0
  %async_frame1_118119_loaded = load i32, ptr %async_frame1_118119_load_address, align 4
  store i32 %async_frame1_118119_loaded, ptr %slot118119, align 4
  call void @free(ptr %async_frame1_load)
  store ptr null, ptr %async_frame_slot, align 8
  %each_role_m144_s11_at118126_cursor = load i64, ptr %each118122_index_slot, align 8
  %each_role_m144_s11_at118126 = trunc i64 %each_role_m144_s11_at118126_cursor to i32
  %v118126 = load i32, ptr %slot118119, align 4
  %each_role_m144_s11_at118127_cursor = load i64, ptr %each118122_index_slot, align 8
  %each_role_m144_s11_at118127 = trunc i64 %each_role_m144_s11_at118127_cursor to i32
  %v118127 = freeze i32 %each_role_m144_s11_at118127
  %each_role_m144_s11_at118125_cursor = load i64, ptr %each118122_index_slot, align 8
  %each_role_m144_s11_at118125 = trunc i64 %each_role_m144_s11_at118125_cursor to i32
  %v118125 = add i32 %v118126, %v118127
  %each_role_m144_s11_at118120_cursor = load i64, ptr %each118122_index_slot, align 8
  %each_role_m144_s11_at118120 = trunc i64 %each_role_m144_s11_at118120_cursor to i32
  store i32 %v118125, ptr %slot118119, align 4
  br label %each118122_continue
each118122_continue:
  %each118122_current = load i64, ptr %each118122_index_slot, align 8
  %each118122_next = add i64 %each118122_current, 1
  store i64 %each118122_next, ptr %each118122_index_slot, align 8
  br label %each118122_header
each118122_exit:
  %v118128 = load i32, ptr %slot118119, align 4
  %async_completed_result = freeze i32 %v118128
  store i32 %async_completed_result, ptr %async_context, align 4
  ret i1 true
}
