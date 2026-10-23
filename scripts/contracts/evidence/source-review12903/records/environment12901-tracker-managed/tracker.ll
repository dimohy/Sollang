@sollang_environment_allocations = global ptr null, align 8
declare ptr @probe_alloc(i64)
declare void @probe_free(ptr)
define internal i1 @sollang_track_environment_allocation(ptr %allocation) {
entry:
  %node = call ptr @probe_alloc(i64 16)
  %ok = icmp ne ptr %node, null
  br i1 %ok, label %store, label %fail

store:
  store ptr %allocation, ptr %node, align 8
  %next_slot = getelementptr i8, ptr %node, i64 8
  %initial_head = load atomic ptr, ptr @sollang_environment_allocations acquire, align 8
  br label %publish

publish:
  %head = phi ptr [ %initial_head, %store ], [ %observed_head, %publish ]
  store ptr %head, ptr %next_slot, align 8
  %exchange = cmpxchg ptr @sollang_environment_allocations, ptr %head, ptr %node acq_rel acquire, align 8
  %observed_head = extractvalue { ptr, i1 } %exchange, 0
  %published = extractvalue { ptr, i1 } %exchange, 1
  br i1 %published, label %done, label %publish

done:
  ret i1 true

fail:
  ret i1 false
}

define internal void @sollang_dispose_environment() {
entry:
  %head = load ptr, ptr @sollang_environment_allocations, align 8
  br label %loop

loop:
  %node = phi ptr [ %head, %entry ], [ %next, %free_node ]
  %done = icmp eq ptr %node, null
  br i1 %done, label %finish, label %free_node

free_node:
  %allocation = load ptr, ptr %node, align 8
  %next_slot = getelementptr i8, ptr %node, i64 8
  %next = load ptr, ptr %next_slot, align 8
  call void @probe_free(ptr %allocation)
  call void @probe_free(ptr %node)
  br label %loop

finish:
  ret void
}
define i8 @observe_track(ptr %allocation) {
  %ok = call i1 @sollang_track_environment_allocation(ptr %allocation)
  %byte = zext i1 %ok to i8
  ret i8 %byte
}
define ptr @observe_head() {
  %head = load ptr, ptr @sollang_environment_allocations, align 8
  ret ptr %head
}
define void @observe_dispose() {
  call void @sollang_dispose_environment()
  ret void
}
