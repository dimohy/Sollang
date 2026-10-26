declare void @ignored()
define void @first() { ret void }
define void @second() { ret void }
define i32 @third() {
entry:
  ret i32 3
}
