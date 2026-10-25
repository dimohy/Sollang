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
define internal void @sollang_m144_s0_async_cancel(ptr %control) {
entry:
  %async_cancel_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_cancel_context = load ptr, ptr %async_cancel_context_slot, align 8
  %async_context = freeze ptr %async_cancel_context
  %async_cancel_status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %async_cancel_status = load i32, ptr %async_cancel_status_slot, align 4
  %async_cancel_completed = icmp eq i32 %async_cancel_status, 2
  br i1 %async_cancel_completed, label %async_cancel_result, label %async_cancel_pending
async_cancel_result:
  br label %async_cancel_cleanup
async_cancel_pending:
  %async_cancel_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_cancel_state = load i32, ptr %async_cancel_state_slot, align 4
  switch i32 %async_cancel_state, label %async_cancel_invalid [ i32 0, label %async_cancel_initial i32 1, label %async_cancel_state1 ]
async_cancel_initial:
  br label %async_cancel_cleanup
async_cancel_invalid:
  call void @llvm.trap()
  unreachable
async_cancel_state1:
  %async_cancel_spill_slot1 = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_spill_frame1 = load ptr, ptr %async_cancel_spill_slot1, align 8
  br label %async_cancel_cleanup
async_cancel_cleanup:
  %async_cancel_frame_slot = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_frame = load ptr, ptr %async_cancel_frame_slot, align 8
  call void @free(ptr %async_cancel_frame)
  call void @free(ptr %async_cancel_context)
  ret void
}
define %sollang.task @sollang_m144_s0() {
entry:
  %async_context = call ptr @malloc(i64 32)
  %async_context_allocated = icmp ne ptr %async_context, null
  br i1 %async_context_allocated, label %async_initialize, label %async_allocation_failed
async_allocation_failed:
  call void @llvm.trap()
  unreachable
async_initialize:
  %async_initial_frame_slot = getelementptr i8, ptr %async_context, i64 8
  store ptr null, ptr %async_initial_frame_slot, align 8
  %async_handle = call ptr @sollang_task_start(ptr @sollang_m144_s0_async_worker, ptr @free, ptr @sollang_m144_s0_async_cancel, ptr %async_context)
  %async_started = icmp ne ptr %async_handle, null
  br i1 %async_started, label %async_ready, label %async_start_failed
async_start_failed:
  call void @free(ptr %async_context)
  call void @llvm.trap()
  unreachable
async_ready:
  %async_task_handle = insertvalue %sollang.task poison, ptr %async_handle, 0
  %async_task = insertvalue %sollang.task %async_task_handle, ptr %async_context, 1
  ret %sollang.task %async_task
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
define internal void @sollang_m144_s4_async_cancel(ptr %control) {
entry:
  %async_cancel_context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %async_cancel_context = load ptr, ptr %async_cancel_context_slot, align 8
  %async_context = freeze ptr %async_cancel_context
  %async_cancel_status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %async_cancel_status = load i32, ptr %async_cancel_status_slot, align 4
  %async_cancel_completed = icmp eq i32 %async_cancel_status, 2
  br i1 %async_cancel_completed, label %async_cancel_result, label %async_cancel_pending
async_cancel_result:
  br label %async_cancel_cleanup
async_cancel_pending:
  %async_cancel_state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_cancel_state = load i32, ptr %async_cancel_state_slot, align 4
  switch i32 %async_cancel_state, label %async_cancel_invalid [ i32 0, label %async_cancel_initial i32 1, label %async_cancel_state1 ]
async_cancel_initial:
  br label %async_cancel_cleanup
async_cancel_invalid:
  call void @llvm.trap()
  unreachable
async_cancel_state1:
  %async_cancel_spill_slot1 = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_spill_frame1 = load ptr, ptr %async_cancel_spill_slot1, align 8
  br label %async_cancel_cleanup
async_cancel_cleanup:
  %async_cancel_frame_slot = getelementptr i8, ptr %async_cancel_context, i64 8
  %async_cancel_frame = load ptr, ptr %async_cancel_frame_slot, align 8
  call void @free(ptr %async_cancel_frame)
  call void @free(ptr %async_cancel_context)
  ret void
}
define %sollang.task @sollang_m144_s4() {
entry:
  %async_context = call ptr @malloc(i64 32)
  %async_context_allocated = icmp ne ptr %async_context, null
  br i1 %async_context_allocated, label %async_initialize, label %async_allocation_failed
async_allocation_failed:
  call void @llvm.trap()
  unreachable
async_initialize:
  %async_initial_frame_slot = getelementptr i8, ptr %async_context, i64 8
  store ptr null, ptr %async_initial_frame_slot, align 8
  %async_handle = call ptr @sollang_task_start(ptr @sollang_m144_s4_async_worker, ptr @free, ptr @sollang_m144_s4_async_cancel, ptr %async_context)
  %async_started = icmp ne ptr %async_handle, null
  br i1 %async_started, label %async_ready, label %async_start_failed
async_start_failed:
  call void @free(ptr %async_context)
  call void @llvm.trap()
  unreachable
async_ready:
  %async_task_handle = insertvalue %sollang.task poison, ptr %async_handle, 0
  %async_task = insertvalue %sollang.task %async_task_handle, ptr %async_context, 1
  ret %sollang.task %async_task
}
define i32 @main() {
entry:
  %v118132 = call %sollang.task @sollang_m144_s0()
  %v118134_task_handle = extractvalue %sollang.task %v118132, 0
  %v118134_task_context = extractvalue %sollang.task %v118132, 1
  %v118134_task_joined = call i1 @sollang_task_join(ptr %v118134_task_handle)
  br i1 %v118134_task_joined, label %await118134_joined, label %await118134_failed
await118134_failed:
  call void @llvm.trap()
  unreachable
await118134_joined:
  %v118134_completion_slot = getelementptr %sollang.task_control, ptr %v118134_task_handle, i32 0, i32 22
  %v118134_completion = load ptr, ptr %v118134_completion_slot, align 8
  %v118134_needs_completion = icmp ne ptr %v118134_completion, null
  br i1 %v118134_needs_completion, label %task_result_v118134_complete, label %task_result_v118134_ready
task_result_v118134_complete:
  call void %v118134_completion(ptr %v118134_task_handle)
  store ptr null, ptr %v118134_completion_slot, align 8
  br label %task_result_v118134_ready
task_result_v118134_ready:
  %v118134 = load i32, ptr %v118134_task_context, align 4
  %v118134_task_released = call i1 @sollang_task_release(ptr %v118134_task_handle)
  br i1 %v118134_task_released, label %await118134_released, label %await118134_release_failed
await118134_release_failed:
  call void @llvm.trap()
  unreachable
await118134_released:
  call void @sollang_runtime_print_i32(i32 %v118134, i1 true)
  %v118135 = call %sollang.task @sollang_m144_s4()
  %v118137_task_handle = extractvalue %sollang.task %v118135, 0
  %v118137_task_context = extractvalue %sollang.task %v118135, 1
  %v118137_task_joined = call i1 @sollang_task_join(ptr %v118137_task_handle)
  br i1 %v118137_task_joined, label %await118137_joined, label %await118137_failed
await118137_failed:
  call void @llvm.trap()
  unreachable
await118137_joined:
  %v118137_completion_slot = getelementptr %sollang.task_control, ptr %v118137_task_handle, i32 0, i32 22
  %v118137_completion = load ptr, ptr %v118137_completion_slot, align 8
  %v118137_needs_completion = icmp ne ptr %v118137_completion, null
  br i1 %v118137_needs_completion, label %task_result_v118137_complete, label %task_result_v118137_ready
task_result_v118137_complete:
  call void %v118137_completion(ptr %v118137_task_handle)
  store ptr null, ptr %v118137_completion_slot, align 8
  br label %task_result_v118137_ready
task_result_v118137_ready:
  %v118137 = load i32, ptr %v118137_task_context, align 4
  %v118137_task_released = call i1 @sollang_task_release(ptr %v118137_task_handle)
  br i1 %v118137_task_released, label %await118137_released, label %await118137_release_failed
await118137_release_failed:
  call void @llvm.trap()
  unreachable
await118137_released:
  call void @sollang_runtime_print_i32(i32 %v118137, i1 true)
  call void @sollang_async_shutdown()
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
