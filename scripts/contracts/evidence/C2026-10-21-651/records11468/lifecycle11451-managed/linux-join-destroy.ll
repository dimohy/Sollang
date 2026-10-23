%sollang.event_stream = type { ptr, ptr, ptr }

define internal void @sollang_stream_join_0_drop(ptr %context, i1 %destroy) {
entry:
  %stream_join_runtime_address33 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 2
  %stream_join_runtime34 = load ptr, ptr %stream_join_runtime_address33, align 8
  call void @sollang_stream_join_runtime_cancel(ptr %stream_join_runtime34)
  %stream_join_input_address35 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 0
  %stream_join_input36 = load %sollang.event_stream, ptr %stream_join_input_address35, align 8
  %stream_context37 = extractvalue %sollang.event_stream %stream_join_input36, 0
  %stream_next38 = extractvalue %sollang.event_stream %stream_join_input36, 1
  %stream_drop39 = extractvalue %sollang.event_stream %stream_join_input36, 2
  %stream_has_drop40 = icmp ne ptr %stream_drop39, null
  br i1 %stream_has_drop40, label %bb_stream_drop11, label %bb_stream_drop_done12

bb_stream_drop11:
  call void %stream_drop39(ptr %stream_context37, i1 false)
  br label %bb_stream_drop_done12

bb_stream_drop_done12:
  %stream_join_input_address41 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 1
  %stream_join_input42 = load %sollang.event_stream, ptr %stream_join_input_address41, align 8
  %stream_context43 = extractvalue %sollang.event_stream %stream_join_input42, 0
  %stream_next44 = extractvalue %sollang.event_stream %stream_join_input42, 1
  %stream_drop45 = extractvalue %sollang.event_stream %stream_join_input42, 2
  %stream_has_drop46 = icmp ne ptr %stream_drop45, null
  br i1 %stream_has_drop46, label %bb_stream_drop13, label %bb_stream_drop_done14

bb_stream_drop13:
  call void %stream_drop45(ptr %stream_context43, i1 false)
  br label %bb_stream_drop_done14

bb_stream_drop_done14:
  br i1 %destroy, label %destroy_inputs, label %cancelled

cancelled:
  ret void

destroy_inputs:
  call void @sollang_stream_join_runtime_join_destroy(ptr %stream_join_runtime34)
  %stream_join_input_address47 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 0
  %stream_join_input48 = load %sollang.event_stream, ptr %stream_join_input_address47, align 8
  %stream_context49 = extractvalue %sollang.event_stream %stream_join_input48, 0
  %stream_next50 = extractvalue %sollang.event_stream %stream_join_input48, 1
  %stream_drop51 = extractvalue %sollang.event_stream %stream_join_input48, 2
  %stream_has_drop52 = icmp ne ptr %stream_drop51, null
  br i1 %stream_has_drop52, label %bb_stream_drop15, label %bb_stream_drop_done16

bb_stream_drop15:
  call void %stream_drop51(ptr %stream_context49, i1 true)
  br label %bb_stream_drop_done16

bb_stream_drop_done16:
  %stream_join_input_address53 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 1
  %stream_join_input54 = load %sollang.event_stream, ptr %stream_join_input_address53, align 8
  %stream_context55 = extractvalue %sollang.event_stream %stream_join_input54, 0
  %stream_next56 = extractvalue %sollang.event_stream %stream_join_input54, 1
  %stream_drop57 = extractvalue %sollang.event_stream %stream_join_input54, 2
  %stream_has_drop58 = icmp ne ptr %stream_drop57, null
  br i1 %stream_has_drop58, label %bb_stream_drop17, label %bb_stream_drop_done18

bb_stream_drop17:
  call void %stream_drop57(ptr %stream_context55, i1 true)
  br label %bb_stream_drop_done18

bb_stream_drop_done18:
  call void @sollang_free(ptr %context)
  ret void
}

@freed = internal global i32 0
@bad = internal global i32 0
@joined = internal global i32 0
@signals = internal global i32 0
@closed = internal global i32 0
define internal void @increment(ptr %counter) {
  %n = load i32, ptr %counter
  %next = add i32 %n, 1
  store i32 %next, ptr %counter
  ret void
}
define internal void @require(i1 %ok) {
  %failed = xor i1 %ok, true
  %n = zext i1 %failed to i32
  %old = load i32, ptr @bad
  %sum = add i32 %old, %n
  store i32 %sum, ptr @bad
  ret void
}
define internal void @sollang_free(ptr %allocation) {
  call void @increment(ptr @freed)
  ret void
}
define internal void @free(ptr %allocation) {
  call void @sollang_free(ptr %allocation)
  ret void
}
declare void @llvm.trap()

@ctx = internal global { %sollang.event_stream, %sollang.event_stream, ptr } {
  %sollang.event_stream { ptr inttoptr(i64 1 to ptr), ptr null, ptr @input_lifecycle },
  %sollang.event_stream { ptr inttoptr(i64 2 to ptr), ptr null, ptr @input_lifecycle },
  ptr null
}
@cancelled_inputs = internal global i32 0
@destroyed_inputs = internal global i32 0
define internal void @sollang_stream_join_runtime_cancel(ptr %runtime) { ret void }
define internal void @sollang_stream_join_runtime_join_destroy(ptr %runtime) {
  %destroyed = load i32, ptr @destroyed_inputs
  %still_live = icmp eq i32 %destroyed, 0
  call void @require(i1 %still_live)
  %cancelled = load i32, ptr @cancelled_inputs
  %all_cancelled = icmp eq i32 %cancelled, 2
  call void @require(i1 %all_cancelled)
  call void @increment(ptr @joined)
  ret void
}
define internal void @input_lifecycle(ptr %input, i1 %destroy) {
  br i1 %destroy, label %destroy_input, label %cancel_input
cancel_input:
  call void @increment(ptr @cancelled_inputs)
  ret void
destroy_input:
  %joins = load i32, ptr @joined
  %quiescent = icmp eq i32 %joins, 1
  call void @require(i1 %quiescent)
  call void @increment(ptr @destroyed_inputs)
  ret void
}
define i32 @main() {
  call void @sollang_stream_join_0_drop(ptr @ctx, i1 true)
  %frees = load i32, ptr @freed
  %free_ok = icmp eq i32 %frees, 1
  call void @require(i1 %free_ok)
  %joins = load i32, ptr @joined
  %join_ok = icmp eq i32 %joins, 1
  call void @require(i1 %join_ok)
  %drops = load i32, ptr @destroyed_inputs
  %drop_ok = icmp eq i32 %drops, 2
  call void @require(i1 %drop_ok)
  %bad = load i32, ptr @bad
  %ok = icmp eq i32 %bad, 0
  %exit = select i1 %ok, i32 0, i32 17
  ret i32 %exit
}
