; Durable negative control for C2026-09-02-233. A terminating block must not
; retain later instructions without a new labeled basic block.
define i32 @main() {
entry:
  br label %terminated

terminated:
  unreachable

later:
  %late = add i32 1, 2
}
