define ptr @sollang_m144_s2(ptr %arg) {
entry:
  %v118106 = load %sollang.struct.m144_s0, ptr %arg, align 4
  ret ptr %arg
}

define i32 @sollang_m144_s3(ptr %arg) {
entry:
  %v118111_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118111, 0
  %v118111 = insertvalue %sollang.text %v118111_ptr, i64 10, 1
  %v118113 = load %sollang.struct.m144_s0, ptr %arg, align 4
  call void @sollang_runtime_print(ptr @sollang_str_118111, i64 10, i1 true)
  %v118112_address = getelementptr inbounds %sollang.struct.m144_s0, ptr %arg, i32 0, i32 0
  %v118112 = load i32, ptr %v118112_address, align 4
  ret i32 %v118112
}

define i32 @sollang_m144_s4(ptr %arg) {
entry:
  %v118118_ptr = insertvalue %sollang.text poison, ptr @sollang_str_118118, 0
  %v118118 = insertvalue %sollang.text %v118118_ptr, i64 15, 1
  %v118120 = load %sollang.struct.m144_s0, ptr %arg, align 4
  call void @sollang_runtime_print(ptr @sollang_str_118118, i64 15, i1 true)
  %v118119_address = getelementptr inbounds %sollang.struct.m144_s0, ptr %arg, i32 0, i32 0
  %v118119 = load i32, ptr %v118119_address, align 4
  ret i32 %v118119
}

define i32 @main() {
entry:
  %callref118126_arg0 = alloca %sollang.struct.m144_s0, align 4
  %callref118129_arg0 = alloca %sollang.struct.m144_s0, align 4
  %v118123 = insertvalue %sollang.struct.m144_s0 poison, i32 7, 0
  %v118127 = freeze %sollang.struct.m144_s0 %v118123
  %v118130 = freeze %sollang.struct.m144_s0 %v118123
  store %sollang.struct.m144_s0 %v118127, ptr %callref118126_arg0, align 4
  %callref118126_arg0_address = getelementptr i8, ptr %callref118126_arg0, i64 0
  %v118126 = call ptr @sollang_m144_s2(ptr %callref118126_arg0_address)
  %v118131 = call i32 @sollang_m144_s3(ptr %v118126)
  call void @sollang_runtime_print_i32(i32 %v118131, i1 true)
  store %sollang.struct.m144_s0 %v118130, ptr %callref118129_arg0, align 4
  %callref118129_arg0_address = getelementptr i8, ptr %callref118129_arg0, i64 0
  %v118129 = call ptr @sollang_m144_s2(ptr %callref118129_arg0_address)
  %v118132 = call i32 @sollang_m144_s4(ptr %v118129)
  call void @sollang_runtime_print_i32(i32 %v118132, i1 true)
  call void @sollang_drop_t1212(%sollang.struct.m144_s0 %v118123)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}
