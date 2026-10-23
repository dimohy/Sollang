; ModuleID = 'W:\MyWorks\Sollang\artifacts\scratch\resume-20261006-owner-continuation22\scratch12720-source\1486-interpolation-capacity-receivers\emitted.ll'
source_filename = "W:\\MyWorks\\Sollang\\artifacts\\scratch\\resume-20261006-owner-continuation22\\scratch12720-source\\1486-interpolation-capacity-receivers\\emitted.ll"
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

%sollang.stream = type { ptr, ptr, ptr }
%sollang.array.i32 = type { ptr, i64, i64 }
%sollang.struct.m144_s0 = type { %sollang.array.i32 }
%sollang.bounded_dictionary.t1216 = type { i64, [160 x i8] }
%sollang.dict = type { ptr, i64, i64 }
%sollang.text = type { ptr, i64 }
%sollang.process_environment_result = type { ptr, i64, i64, i1 }
%sollang.process_spawn_result = type { i64, i64, i32 }
%sollang.process_result = type { i32, i32 }
%sollang.process_poll_result = type { i32, i32 }
%sollang.directory_node = type { ptr, i64, i8, [7 x i8] }
%sollang.path_absolute_result = type { ptr, i64, i32 }
%sollang.directory_result = type { ptr, i64, i64, i32 }
%sollang.path_query_result = type { ptr, i64, i8, i64, i64, i32 }
%sollang.file_handle_result = type { i64, i32 }
%sollang.file_count_result = type { i64, i32 }
%sollang.legacy_int_result = type { i64, i32 }
%sollang.enum.t469 = type { i32, [3 x i64] }
%sollang.source_text = type { ptr, i64, ptr, i64 }

@sollang_runtime_stdout_written = private global i32 0
@sollang_runtime_newline = private constant [1 x i8] c"\0A"
@sollang_runtime_stdout_buffer = private global [1048576 x i8] zeroinitializer
@sollang_runtime_stdout_count = private global i64 0
@sollang_runtime_error_newline = private constant [2 x i8] c"\0D\0A"
@sollang_runtime_bool_true = private constant [4 x i8] c"true"
@sollang_runtime_bool_false = private constant [5 x i8] c"false"
@sollang_process_error_spawn = private constant [5 x i8] c"spawn"
@sollang_process_error_wait = private constant [4 x i8] c"wait"
@sollang_process_error_signal = private constant [6 x i8] c"signal"
@sollang_process_error_capture = private constant [7 x i8] c"capture"
@sollang_bool_true_bytes = private constant [4 x i8] c"true"
@sollang_bool_false_bytes = private constant [5 x i8] c"false"
@sollang_file_error_io = private constant [2 x i8] c"io"
@sollang_file_error_range = private constant [5 x i8] c"range"
@sollang_file_error_truncated = private constant [9 x i8] c"truncated"
@sollang_file_error_invalid = private constant [7 x i8] c"invalid"
@sollang_directory_error_io = private constant [2 x i8] c"io"
@sollang_str_59720 = private unnamed_addr constant [10 x i8] c"ext binder"
@sollang_str_59728 = private unnamed_addr constant [10 x i8] c"res binder"
@sollang_str_59764 = private unnamed_addr constant [11 x i8] c"c e traffic"
@sollang_str_59768 = private unnamed_addr constant [12 x i8] c"e exp master"
@sollang_str_59805 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_59812 = private unnamed_addr constant [12 x i8] c"c hs traffic"
@sollang_str_59816 = private unnamed_addr constant [12 x i8] c"s hs traffic"
@sollang_str_59820 = private unnamed_addr constant [7 x i8] c"derived"
@sollang_str_59879 = private unnamed_addr constant [12 x i8] c"c ap traffic"
@sollang_str_59883 = private unnamed_addr constant [12 x i8] c"s ap traffic"
@sollang_str_59887 = private unnamed_addr constant [10 x i8] c"exp master"
@sollang_str_59914 = private unnamed_addr constant [10 x i8] c"res master"
@sollang_str_59924 = private unnamed_addr constant [8 x i8] c"finished"
@sollang_str_59953 = private unnamed_addr constant [11 x i8] c"traffic upd"
@sollang_str_68056 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_68066 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_69661 = private unnamed_addr constant [7 x i8] c"chunked"
@sollang_str_69743 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_69776 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_70211 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_70216 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_70415 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_70440 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_71225 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_71232 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_71253 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_71688 = private unnamed_addr constant [3 x i8] c"GET"
@sollang_str_71695 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_71702 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_72352 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_72360 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_72453 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_72456 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_72459 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_72462 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_72465 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_72504 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_72510 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_72667 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_72673 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_72680 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_72686 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_73198 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_73256 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_73435 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_73467 = private unnamed_addr constant [7 x i8] c"OPTIONS"
@sollang_str_73659 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_73919 = private unnamed_addr constant [4 x i8] c"Host"
@sollang_str_73934 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_73935 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_73942 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_73943 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_73946 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_74204 = private unnamed_addr constant [14 x i8] c"Content-Length"
@sollang_str_74207 = private unnamed_addr constant [17 x i8] c"Transfer-Encoding"
@sollang_str_74210 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_74213 = private unnamed_addr constant [7 x i8] c"Trailer"
@sollang_str_74251 = private unnamed_addr constant [8 x i8] c"HTTP/1.0"
@sollang_str_74257 = private unnamed_addr constant [8 x i8] c"HTTP/1.1"
@sollang_str_74387 = private unnamed_addr constant [2 x i8] c": "
@sollang_str_74393 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_74400 = private unnamed_addr constant [16 x i8] c"Content-Length: "
@sollang_str_74406 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_74545 = private unnamed_addr constant [7 x i8] c"CONNECT"
@sollang_str_74559 = private unnamed_addr constant [4 x i8] c"HEAD"
@sollang_str_74705 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_74971 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_74972 = private unnamed_addr constant [5 x i8] c"close"
@sollang_str_74979 = private unnamed_addr constant [10 x i8] c"Connection"
@sollang_str_74980 = private unnamed_addr constant [10 x i8] c"keep-alive"
@sollang_str_74983 = private unnamed_addr constant [2 x i8] c"\0D\0A"
@sollang_str_85469 = private unnamed_addr constant [9 x i8] c"client in"
@sollang_str_85473 = private unnamed_addr constant [9 x i8] c"server in"
@sollang_str_85481 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_85483 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_85490 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_85492 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_85499 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_85501 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_96360 = private unnamed_addr constant [10 x i8] c"quicv2 key"
@sollang_str_96362 = private unnamed_addr constant [8 x i8] c"quic key"
@sollang_str_96369 = private unnamed_addr constant [9 x i8] c"quicv2 iv"
@sollang_str_96371 = private unnamed_addr constant [7 x i8] c"quic iv"
@sollang_str_96378 = private unnamed_addr constant [9 x i8] c"quicv2 hp"
@sollang_str_96380 = private unnamed_addr constant [7 x i8] c"quic hp"
@sollang_str_102159 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_102170 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_102194 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_103655 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_103708 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_103761 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_106683 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_106694 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_106698 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_106972 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_106979 = private unnamed_addr constant [6 x i8] c"$value"
@sollang_str_107309 = private unnamed_addr constant [4 x i8] c"null"
@sollang_str_107348 = private unnamed_addr constant [4 x i8] c"true"
@sollang_str_107353 = private unnamed_addr constant [5 x i8] c"false"
@sollang_str_112680 = private unnamed_addr constant [0 x i8] zeroinitializer
@sollang_str_112708 = private unnamed_addr constant [0 x i8] zeroinitializer
@sollang_str_112712 = private unnamed_addr constant [0 x i8] zeroinitializer
@sollang_str_112716 = private unnamed_addr constant [0 x i8] zeroinitializer
@sollang_str_113458 = private unnamed_addr constant [1 x i8] c"0"
@sollang_str_113463 = private unnamed_addr constant [1 x i8] c"1"
@sollang_str_113468 = private unnamed_addr constant [1 x i8] c"2"
@sollang_str_113473 = private unnamed_addr constant [1 x i8] c"3"
@sollang_str_113478 = private unnamed_addr constant [1 x i8] c"4"
@sollang_str_113483 = private unnamed_addr constant [1 x i8] c"5"
@sollang_str_113488 = private unnamed_addr constant [1 x i8] c"6"
@sollang_str_113493 = private unnamed_addr constant [1 x i8] c"7"
@sollang_str_113498 = private unnamed_addr constant [1 x i8] c"8"
@sollang_str_113503 = private unnamed_addr constant [1 x i8] c"9"
@sollang_str_113508 = private unnamed_addr constant [1 x i8] c"a"
@sollang_str_113513 = private unnamed_addr constant [1 x i8] c"b"
@sollang_str_113518 = private unnamed_addr constant [1 x i8] c"c"
@sollang_str_113523 = private unnamed_addr constant [1 x i8] c"d"
@sollang_str_113528 = private unnamed_addr constant [1 x i8] c"e"
@sollang_str_113530 = private unnamed_addr constant [1 x i8] c"f"
@sollang_str_114498 = private unnamed_addr constant [1296 x i8] c"$((Int(self.bytes[0]) / 16) -> hexDigit)$((Int(self.bytes[0]) % 16) -> hexDigit)$((Int(self.bytes[1]) / 16) -> hexDigit)$((Int(self.bytes[1]) % 16) -> hexDigit)$((Int(self.bytes[2]) / 16) -> hexDigit)$((Int(self.bytes[2]) % 16) -> hexDigit)$((Int(self.bytes[3]) / 16) -> hexDigit)$((Int(self.bytes[3]) % 16) -> hexDigit)-$((Int(self.bytes[4]) / 16) -> hexDigit)$((Int(self.bytes[4]) % 16) -> hexDigit)$((Int(self.bytes[5]) / 16) -> hexDigit)$((Int(self.bytes[5]) % 16) -> hexDigit)-$((Int(self.bytes[6]) / 16) -> hexDigit)$((Int(self.bytes[6]) % 16) -> hexDigit)$((Int(self.bytes[7]) / 16) -> hexDigit)$((Int(self.bytes[7]) % 16) -> hexDigit)-$((Int(self.bytes[8]) / 16) -> hexDigit)$((Int(self.bytes[8]) % 16) -> hexDigit)$((Int(self.bytes[9]) / 16) -> hexDigit)$((Int(self.bytes[9]) % 16) -> hexDigit)-$((Int(self.bytes[10]) / 16) -> hexDigit)$((Int(self.bytes[10]) % 16) -> hexDigit)$((Int(self.bytes[11]) / 16) -> hexDigit)$((Int(self.bytes[11]) % 16) -> hexDigit)$((Int(self.bytes[12]) / 16) -> hexDigit)$((Int(self.bytes[12]) % 16) -> hexDigit)$((Int(self.bytes[13]) / 16) -> hexDigit)$((Int(self.bytes[13]) % 16) -> hexDigit)$((Int(self.bytes[14]) / 16) -> hexDigit)$((Int(self.bytes[14]) % 16) -> hexDigit)$((Int(self.bytes[15]) / 16) -> hexDigit)$((Int(self.bytes[15]) % 16) -> hexDigit)"
@sollang_str_114649 = private unnamed_addr constant [2 x i8] c"io"
@sollang_str_115039 = private unnamed_addr constant [2 x i8] c"io"
@sollang_str_115413 = private unnamed_addr constant [23 x i8] c"path is not valid UTF-8"
@sollang_str_115747 = private unnamed_addr constant [19 x i8] c"absolute child path"
@sollang_str_115971 = private unnamed_addr constant [18 x i8] c"path styles differ"
@sollang_str_115979 = private unnamed_addr constant [29 x i8] c"cannot join an absolute child"
@sollang_str_116020 = private unnamed_addr constant [18 x i8] c"path styles differ"
@sollang_str_116362 = private unnamed_addr constant [17 x i8] c"path contains NUL"
@sollang_str_116416 = private unnamed_addr constant [20 x i8] c"invalid drive prefix"
@sollang_str_116509 = private unnamed_addr constant [26 x i8] c"unsupported path namespace"
@sollang_str_116539 = private unnamed_addr constant [26 x i8] c"unsupported path namespace"
@sollang_str_116564 = private unnamed_addr constant [16 x i8] c"invalid UNC path"
@sollang_str_116871 = private unnamed_addr constant [17 x i8] c"path escapes root"
@sollang_str_116884 = private unnamed_addr constant [19 x i8] c"incomplete UNC path"
@sollang_str_116918 = private unnamed_addr constant [0 x i8] zeroinitializer
@sollang_str_116994 = private unnamed_addr constant [0 x i8] zeroinitializer
@sollang_str_117222 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_117263 = private unnamed_addr constant [4 x i8] c"wait"
@sollang_str_117311 = private unnamed_addr constant [6 x i8] c"signal"
@sollang_str_117332 = private unnamed_addr constant [4 x i8] c"kill"
@sollang_str_118107 = private unnamed_addr constant [38 x i8] c"projected=$(holder.values -> capacity)"
@sollang_str_118112 = private unnamed_addr constant [30 x i8] c"readonly=$(values -> capacity)"
@sollang_str_118125 = private unnamed_addr constant [30 x i8] c"$(a! -> len),$(a! -> capacity)"
@sollang_str_118133 = private unnamed_addr constant [21 x i8] c"$(a! -> len),$(a![1])"
@sollang_str_118136 = private unnamed_addr constant [30 x i8] c"$(b! -> len),$(b! -> capacity)"
@sollang_str_118144 = private unnamed_addr constant [21 x i8] c"$(b! -> len),$(b![1])"
@sollang_str_118155 = private unnamed_addr constant [30 x i8] c"$(a! -> len),$(a! -> capacity)"
@sollang_str_118163 = private unnamed_addr constant [21 x i8] c"$(a! -> len),$(a![1])"
@sollang_str_118166 = private unnamed_addr constant [30 x i8] c"$(b! -> len),$(b! -> capacity)"
@sollang_str_118174 = private unnamed_addr constant [21 x i8] c"$(b! -> len),$(b![1])"
@sollang_str_118190 = private unnamed_addr constant [30 x i8] c"$(a! -> len),$(a! -> capacity)"
@sollang_str_118198 = private unnamed_addr constant [21 x i8] c"$(a! -> len),$(a![1])"
@sollang_str_118201 = private unnamed_addr constant [30 x i8] c"$(b! -> len),$(b! -> capacity)"
@sollang_str_118209 = private unnamed_addr constant [21 x i8] c"$(b! -> len),$(b![1])"
@sollang_str_118226 = private unnamed_addr constant [30 x i8] c"$(a! -> len),$(a! -> capacity)"
@sollang_str_118234 = private unnamed_addr constant [21 x i8] c"$(a! -> len),$(a![1])"
@sollang_str_118237 = private unnamed_addr constant [30 x i8] c"$(b! -> len),$(b! -> capacity)"
@sollang_str_118245 = private unnamed_addr constant [21 x i8] c"$(b! -> len),$(b![1])"
@sollang_str_118252 = private unnamed_addr constant [33 x i8] c"$(repeated -> len),$(repeated[2])"
@sollang_str_118255 = private unnamed_addr constant [30 x i8] c"bounded=$(bounded -> capacity)"
@sollang_str_118258 = private unnamed_addr constant [51 x i8] c"bounded-dictionary=$(boundedDictionary -> capacity)"
@sollang_str_118263 = private unnamed_addr constant [58 x i8] c"dictionary=$((dictionary -> capacity) == ordinaryCapacity)"
@sollang_str_118276 = private unnamed_addr constant [27 x i8] c"arena=$(memory -> capacity)"
@sollang_str_118278 = private unnamed_addr constant [58 x i8] c"$(10 -> mark),$(a! -> capacity),$(20 -> mark),$(a! -> len)"
@sollang_process_null_windows = private unnamed_addr constant [4 x i8] c"NUL\00"
@sollang_binary_writer_handle = internal global i64 -1
@sollang_binary_writer_offset = internal global i64 0
@sollang_binary_reader_handle = internal global i64 -1
@sollang_binary_reader_offset = internal global i64 0
@sollang_legacy_int_writer_buffer = internal global [8192 x i64] zeroinitializer
@sollang_legacy_int_writer_buffer_count = internal global i64 0
@sollang_legacy_int_file_writer = internal global ptr null
@sollang_legacy_int_file_reader = internal global ptr null
@sollang_stage2_random_state = internal global i64 88172645463325252

declare ptr @GetStdHandle(i32)

declare i32 @GetConsoleMode(ptr, ptr)

declare i32 @WriteConsoleW(ptr, ptr, i32, ptr, ptr)

declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)

declare i32 @MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)

declare ptr @GetProcessHeap()

declare ptr @HeapAlloc(ptr, i32, i64)

declare i32 @HeapFree(ptr, i32, ptr)

define internal i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr %data, i32 %len) {
entry:
  %empty = icmp eq i32 %len, 0
  br i1 %empty, label %write_succeeded, label %classify

classify:                                         ; preds = %entry
  %mode = alloca i32, align 4
  %console_status = call i32 @GetConsoleMode(ptr %handle, ptr %mode)
  %is_console = icmp ne i32 %console_status, 0
  br i1 %is_console, label %console_prepare, label %redirected

redirected:                                       ; preds = %classify
  br label %redirected_write

redirected_write:                                 ; preds = %redirected_advance, %redirected
  %redirected_offset = phi i32 [ 0, %redirected ], [ %redirected_next, %redirected_advance ]
  %redirected_remaining = sub i32 %len, %redirected_offset
  %redirected_offset64 = zext i32 %redirected_offset to i64
  %redirected_data = getelementptr i8, ptr %data, i64 %redirected_offset64
  store i32 0, ptr @sollang_runtime_stdout_written, align 4
  %redirected_ok = call i32 @WriteFile(ptr %handle, ptr %redirected_data, i32 %redirected_remaining, ptr @sollang_runtime_stdout_written, ptr null)
  %redirected_count = load i32, ptr @sollang_runtime_stdout_written, align 4
  %redirected_succeeded = icmp ne i32 %redirected_ok, 0
  %redirected_progress = icmp ugt i32 %redirected_count, 0
  %redirected_bounded = icmp ule i32 %redirected_count, %redirected_remaining
  %redirected_valid0 = and i1 %redirected_succeeded, %redirected_progress
  %redirected_valid = and i1 %redirected_valid0, %redirected_bounded
  br i1 %redirected_valid, label %redirected_advance, label %write_failed

redirected_advance:                               ; preds = %redirected_write
  %redirected_next = add i32 %redirected_offset, %redirected_count
  %redirected_complete = icmp eq i32 %redirected_next, %len
  br i1 %redirected_complete, label %write_succeeded, label %redirected_write

console_prepare:                                  ; preds = %classify
  %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %len, ptr null, i32 0)
  %valid_utf8 = icmp sgt i32 %wide_chars, 0
  br i1 %valid_utf8, label %allocate, label %conversion_failed

allocate:                                         ; preds = %console_prepare
  %wide_bytes32 = shl i32 %wide_chars, 1
  %wide_bytes = zext i32 %wide_bytes32 to i64
  %heap = call ptr @GetProcessHeap()
  %wide = call ptr @HeapAlloc(ptr %heap, i32 0, i64 %wide_bytes)
  %wide_written = alloca i32, align 4
  %allocated = icmp ne ptr %wide, null
  br i1 %allocated, label %convert, label %conversion_failed

convert:                                          ; preds = %allocate
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %len, ptr %wide, i32 %wide_chars)
  %converted_all = icmp eq i32 %converted, %wide_chars
  br i1 %converted_all, label %console_write, label %conversion_free

console_write:                                    ; preds = %console_advance, %convert
  %console_offset = phi i32 [ 0, %convert ], [ %console_next, %console_advance ]
  %console_remaining = sub i32 %wide_chars, %console_offset
  %console_offset64 = zext i32 %console_offset to i64
  %console_data = getelementptr i16, ptr %wide, i64 %console_offset64
  store i32 0, ptr %wide_written, align 4
  %console_ok = call i32 @WriteConsoleW(ptr %handle, ptr %console_data, i32 %console_remaining, ptr %wide_written, ptr null)
  %console_count = load i32, ptr %wide_written, align 4
  %console_succeeded = icmp ne i32 %console_ok, 0
  %console_progress = icmp ugt i32 %console_count, 0
  %console_bounded = icmp ule i32 %console_count, %console_remaining
  %console_valid0 = and i1 %console_succeeded, %console_progress
  %console_valid = and i1 %console_valid0, %console_bounded
  br i1 %console_valid, label %console_advance, label %console_write_failed

console_advance:                                  ; preds = %console_write
  %console_next = add i32 %console_offset, %console_count
  %console_complete = icmp eq i32 %console_next, %wide_chars
  br i1 %console_complete, label %console_write_succeeded, label %console_write

console_write_succeeded:                          ; preds = %console_advance
  %freed = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %write_succeeded

console_write_failed:                             ; preds = %console_write
  %freed_after_write_failure = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %write_failed

write_succeeded:                                  ; preds = %console_write_succeeded, %redirected_advance, %entry
  store i32 %len, ptr @sollang_runtime_stdout_written, align 4
  ret i32 1

write_failed:                                     ; preds = %console_write_failed, %redirected_write
  store i32 0, ptr @sollang_runtime_stdout_written, align 4
  ret i32 0

conversion_free:                                  ; preds = %convert
  %freed_after_failure = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %conversion_failed

conversion_failed:                                ; preds = %conversion_free, %allocate, %console_prepare
  store i32 0, ptr @sollang_runtime_stdout_written, align 4
  ret i32 0
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #0

define internal void @sollang_runtime_flush_stdout() {
entry:
  %count = load i64, ptr @sollang_runtime_stdout_count, align 8
  %has_data = icmp ugt i64 %count, 0
  br i1 %has_data, label %write, label %done

write:                                            ; preds = %entry
  %handle = call ptr @GetStdHandle(i32 -11)
  %count32 = trunc i64 %count to i32
  %ok = call i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr @sollang_runtime_stdout_buffer, i32 %count32)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %clear, label %failure

clear:                                            ; preds = %write
  store i64 0, ptr @sollang_runtime_stdout_count, align 8
  br label %done

failure:                                          ; preds = %write
  call void @llvm.trap()
  unreachable

done:                                             ; preds = %clear, %entry
  ret void
}

define internal void @sollang_runtime_append_stdout(ptr %data, i64 %len) {
entry:
  %count = load i64, ptr @sollang_runtime_stdout_count, align 8
  %total = add i64 %count, %len
  %fits = icmp ule i64 %total, 1048576
  br i1 %fits, label %append, label %flush

flush:                                            ; preds = %entry
  call void @sollang_runtime_flush_stdout()
  %large = icmp ugt i64 %len, 1048576
  br i1 %large, label %direct, label %append_empty

direct:                                           ; preds = %flush
  %handle = call ptr @GetStdHandle(i32 -11)
  %len32 = trunc i64 %len to i32
  %ok = call i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr %data, i32 %len32)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %direct_done, label %direct_failure

direct_done:                                      ; preds = %direct
  ret void

direct_failure:                                   ; preds = %direct
  call void @llvm.trap()
  unreachable

append_empty:                                     ; preds = %flush
  call void @llvm.memcpy.p0.p0.i64(ptr @sollang_runtime_stdout_buffer, ptr %data, i64 %len, i1 false)
  store i64 %len, ptr @sollang_runtime_stdout_count, align 8
  ret void

append:                                           ; preds = %entry
  %slot = getelementptr i8, ptr @sollang_runtime_stdout_buffer, i64 %count
  call void @llvm.memcpy.p0.p0.i64(ptr %slot, ptr %data, i64 %len, i1 false)
  store i64 %total, ptr @sollang_runtime_stdout_count, align 8
  ret void
}

define internal void @sollang_runtime_print(ptr %data, i64 %len, i1 %newline) {
entry:
  call void @sollang_runtime_append_stdout(ptr %data, i64 %len)
  br i1 %newline, label %write_newline, label %done

write_newline:                                    ; preds = %entry
  call void @sollang_runtime_append_stdout(ptr @sollang_runtime_newline, i64 1)
  br label %done

done:                                             ; preds = %write_newline, %entry
  ret void
}

define internal void @sollang_runtime_eprint(ptr %data, i64 %len, i1 %newline) {
entry:
  %handle = call ptr @GetStdHandle(i32 -12)
  %len32 = trunc i64 %len to i32
  %ok = call i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr %data, i32 %len32)
  br i1 %newline, label %write_newline, label %done

write_newline:                                    ; preds = %entry
  %newline_ok = call i32 @sollang_runtime_write_stdout_bytes(ptr %handle, ptr @sollang_runtime_error_newline, i32 2)
  br label %done

done:                                             ; preds = %write_newline, %entry
  ret void
}

define internal void @sollang_runtime_eprintln(ptr %data, i64 %len) {
entry:
  call void @sollang_runtime_eprint(ptr %data, i64 %len, i1 true)
  ret void
}

define internal i64 @sollang_format_u64(ptr %dest, i64 %value) {
entry:
  br label %count

count:                                            ; preds = %count_more, %entry
  %count_n = phi i64 [ %value, %entry ], [ %count_q, %count_more ]
  %length = phi i64 [ 1, %entry ], [ %next_length, %count_more ]
  %count_q = udiv i64 %count_n, 10
  %count_done = icmp eq i64 %count_q, 0
  br i1 %count_done, label %write_entry, label %count_more

count_more:                                       ; preds = %count
  %next_length = add i64 %length, 1
  br label %count

write_entry:                                      ; preds = %count
  %last_index = sub i64 %length, 1
  br label %write

write:                                            ; preds = %write, %write_entry
  %write_n = phi i64 [ %value, %write_entry ], [ %write_q, %write ]
  %index = phi i64 [ %last_index, %write_entry ], [ %previous_index, %write ]
  %digit = urem i64 %write_n, 10
  %write_q = udiv i64 %write_n, 10
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  %slot = getelementptr i8, ptr %dest, i64 %index
  store i8 %ascii, ptr %slot, align 1
  %previous_index = sub i64 %index, 1
  %write_done = icmp eq i64 %write_q, 0
  br i1 %write_done, label %return, label %write

return:                                           ; preds = %write
  ret i64 %length
}

define internal i64 @sollang_format_i64(ptr %dest, i64 %value) {
entry:
  %negative = icmp slt i64 %value, 0
  br i1 %negative, label %negative_value, label %positive_value

negative_value:                                   ; preds = %entry
  store i8 45, ptr %dest, align 1
  %digits_dest = getelementptr i8, ptr %dest, i64 1
  %magnitude = sub i64 0, %value
  %negative_digits = call i64 @sollang_format_u64(ptr %digits_dest, i64 %magnitude)
  %negative_length = add i64 %negative_digits, 1
  ret i64 %negative_length

positive_value:                                   ; preds = %entry
  %positive_length = call i64 @sollang_format_u64(ptr %dest, i64 %value)
  ret i64 %positive_length
}

define internal void @sollang_runtime_print_i32(i32 %value, i1 %newline) {
entry:
  %buffer = alloca [12 x i8], align 1
  %end = getelementptr [12 x i8], ptr %buffer, i64 0, i64 12
  %wide = sext i32 %value to i64
  %negative = icmp slt i64 %wide, 0
  %negated = sub i64 0, %wide
  %magnitude = select i1 %negative, i64 %negated, i64 %wide
  br label %digits

digits:                                           ; preds = %digits, %entry
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done

digits_done:                                      ; preds = %digits
  br i1 %negative, label %write_sign, label %emit

write_sign:                                       ; preds = %digits_done
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit

emit:                                             ; preds = %write_sign, %digits_done
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_print(ptr %start, i64 %length, i1 %newline)
  ret void
}

define internal void @sollang_runtime_print_i64(i64 %value, i1 %signed, i1 %newline) {
entry:
  %buffer = alloca [21 x i8], align 1
  %end = getelementptr [21 x i8], ptr %buffer, i64 0, i64 21
  %negative_value = icmp slt i64 %value, 0
  %negative = and i1 %signed, %negative_value
  %negated = sub i64 0, %value
  %magnitude = select i1 %negative, i64 %negated, i64 %value
  br label %digits

digits:                                           ; preds = %digits, %entry
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done

digits_done:                                      ; preds = %digits
  br i1 %negative, label %write_sign, label %emit

write_sign:                                       ; preds = %digits_done
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit

emit:                                             ; preds = %write_sign, %digits_done
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_print(ptr %start, i64 %length, i1 %newline)
  ret void
}

define internal void @sollang_runtime_print_i1(i1 %value, i1 %newline) {
entry:
  %data = select i1 %value, ptr @sollang_runtime_bool_true, ptr @sollang_runtime_bool_false
  %length = select i1 %value, i64 4, i64 5
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 %newline)
  ret void
}

define internal void @sollang_runtime_eprint_i32(i32 %value, i1 %newline) {
entry:
  %buffer = alloca [12 x i8], align 1
  %end = getelementptr [12 x i8], ptr %buffer, i64 0, i64 12
  %wide = sext i32 %value to i64
  %negative = icmp slt i64 %wide, 0
  %negated = sub i64 0, %wide
  %magnitude = select i1 %negative, i64 %negated, i64 %wide
  br label %digits

digits:                                           ; preds = %digits, %entry
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done

digits_done:                                      ; preds = %digits
  br i1 %negative, label %write_sign, label %emit

write_sign:                                       ; preds = %digits_done
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit

emit:                                             ; preds = %write_sign, %digits_done
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_eprint(ptr %start, i64 %length, i1 %newline)
  ret void
}

define internal void @sollang_runtime_eprint_i64(i64 %value, i1 %signed, i1 %newline) {
entry:
  %buffer = alloca [21 x i8], align 1
  %end = getelementptr [21 x i8], ptr %buffer, i64 0, i64 21
  %negative_value = icmp slt i64 %value, 0
  %negative = and i1 %signed, %negative_value
  %negated = sub i64 0, %value
  %magnitude = select i1 %negative, i64 %negated, i64 %value
  br label %digits

digits:                                           ; preds = %digits, %entry
  %current = phi i64 [ %magnitude, %entry ], [ %quotient, %digits ]
  %cursor = phi ptr [ %end, %entry ], [ %digit_slot, %digits ]
  %digit = urem i64 %current, 10
  %quotient = udiv i64 %current, 10
  %digit_slot = getelementptr i8, ptr %cursor, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %digit_slot, align 1
  %more = icmp ne i64 %quotient, 0
  br i1 %more, label %digits, label %digits_done

digits_done:                                      ; preds = %digits
  br i1 %negative, label %write_sign, label %emit

write_sign:                                       ; preds = %digits_done
  %sign_slot = getelementptr i8, ptr %digit_slot, i64 -1
  store i8 45, ptr %sign_slot, align 1
  br label %emit

emit:                                             ; preds = %write_sign, %digits_done
  %start = phi ptr [ %digit_slot, %digits_done ], [ %sign_slot, %write_sign ]
  %end_address = ptrtoint ptr %end to i64
  %start_address = ptrtoint ptr %start to i64
  %length = sub i64 %end_address, %start_address
  call void @sollang_runtime_eprint(ptr %start, i64 %length, i1 %newline)
  ret void
}

define internal void @sollang_runtime_eprint_i1(i1 %value, i1 %newline) {
entry:
  %data = select i1 %value, ptr @sollang_runtime_bool_true, ptr @sollang_runtime_bool_false
  %length = select i1 %value, i64 4, i64 5
  call void @sollang_runtime_eprint(ptr %data, i64 %length, i1 %newline)
  ret void
}

declare dllimport ptr @CreateFileA(ptr, i32, i32, ptr, i32, i32, ptr)

declare dllimport ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)

declare dllimport i32 @DeleteFileW(ptr)

declare dllimport i32 @WaitForSingleObject(ptr, i32)

declare dllimport i32 @CloseHandle(ptr)

declare dllimport i32 @CreateDirectoryW(ptr, ptr)

declare dllimport i32 @GetFileAttributesW(ptr)

declare dllimport ptr @FindFirstFileW(ptr, ptr)

declare dllimport i32 @FindNextFileW(ptr, ptr)

declare dllimport i32 @FindClose(ptr)

declare dllimport void @SetLastError(i32)

declare dllimport i32 @GetLastError()

declare dllimport i32 @GetFinalPathNameByHandleW(ptr, ptr, i32, i32)

declare dllimport i32 @GetFullPathNameW(ptr, i32, ptr, ptr)

declare dllimport i32 @GetFileInformationByHandle(ptr, ptr)

declare dllimport i32 @WideCharToMultiByte(i32, i32, ptr, i32, ptr, i32, ptr, ptr)

declare dllimport ptr @GetCommandLineW()

declare dllimport ptr @CommandLineToArgvW(ptr, ptr)

declare dllimport ptr @LocalFree(ptr)

declare dllimport ptr @GetCurrentProcess()

declare dllimport i32 @DuplicateHandle(ptr, ptr, ptr, ptr, i32, i32, i32)

declare dllimport i32 @CreateProcessW(ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr)

declare dllimport ptr @GetEnvironmentStringsW()

declare dllimport i32 @FreeEnvironmentStringsW(ptr)

declare dllimport i32 @CompareStringOrdinal(ptr, i32, ptr, i32, i32)

declare dllimport i32 @GetProcessId(ptr)

declare dllimport i32 @GetExitCodeProcess(ptr, ptr)

declare dllimport i32 @TerminateProcess(ptr, i32)

define internal i1 @sollang_range_stream_next(ptr %context, ptr %output) {
entry:
  %done_address = getelementptr i8, ptr %context, i64 8
  %done = load i1, ptr %done_address, align 1
  br i1 %done, label %finished, label %active

active:                                           ; preds = %entry
  %current = load i32, ptr %context, align 4
  %end_address = getelementptr i8, ptr %context, i64 4
  %end = load i32, ptr %end_address, align 4
  %past_end = icmp sgt i32 %current, %end
  br i1 %past_end, label %mark_finished, label %yield

yield:                                            ; preds = %active
  store i32 %current, ptr %output, align 4
  %is_last = icmp eq i32 %current, %end
  br i1 %is_last, label %mark_finished_after_yield, label %advance

advance:                                          ; preds = %yield
  %next = add i32 %current, 1
  store i32 %next, ptr %context, align 4
  ret i1 true

mark_finished_after_yield:                        ; preds = %yield
  store i1 true, ptr %done_address, align 1
  ret i1 true

mark_finished:                                    ; preds = %active
  store i1 true, ptr %done_address, align 1
  ret i1 false

finished:                                         ; preds = %entry
  ret i1 false
}

define internal void @sollang_stream_heap_drop(ptr %context, i1 %destroy) {
entry:
  br i1 %destroy, label %release, label %done

release:                                          ; preds = %entry
  call void @free(ptr %context)
  br label %done

done:                                             ; preds = %release, %entry
  ret void
}

define internal %sollang.stream @sollang_range_stream_create({ i32, i32 } %range) {
entry:
  %context = call ptr @malloc(i64 12)
  %start = extractvalue { i32, i32 } %range, 0
  %end = extractvalue { i32, i32 } %range, 1
  store i32 %start, ptr %context, align 4
  %end_address = getelementptr i8, ptr %context, i64 4
  store i32 %end, ptr %end_address, align 4
  %done_address = getelementptr i8, ptr %context, i64 8
  store i1 false, ptr %done_address, align 1
  %with_context = insertvalue %sollang.stream poison, ptr %context, 0
  %with_next = insertvalue %sollang.stream %with_context, ptr @sollang_range_stream_next, 1
  %result = insertvalue %sollang.stream %with_next, ptr @sollang_stream_heap_drop, 2
  ret %sollang.stream %result
}

declare ptr @malloc(i64)

declare ptr @realloc(ptr, i64)

declare void @free(ptr)

define internal void @sollang_drop_t188(%sollang.array.i32 %value) {
entry:
  %data = extractvalue %sollang.array.i32 %value, 0
  call void @free(ptr %data)
  ret void
}

define internal void @sollang_drop_t1212(%sollang.struct.m144_s0 %value) {
entry:
  %field0 = extractvalue %sollang.struct.m144_s0 %value, 0
  call void @sollang_drop_t188(%sollang.array.i32 %field0)
  ret void
}

define internal void @sollang_drop_t1215(%sollang.array.i32 %value) {
entry:
  ret void
}

define internal void @sollang_drop_t1216(%sollang.bounded_dictionary.t1216 %value) {
entry:
  ret void
}

define internal void @sollang_drop_t1217(%sollang.dict %value) {
entry:
  %dict_storage = extractvalue %sollang.dict %value, 0
  call void @free(ptr %dict_storage)
  ret void
}

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #1

define ptr @sollang_raw_arena_create(i64 %bytes, i1 %size_valid) {
entry:
  br i1 %size_valid, label %allocate, label %fail

allocate:                                         ; preds = %entry
  %data = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %data, null
  br i1 %allocated, label %done, label %fail

done:                                             ; preds = %allocate
  ret ptr %data

fail:                                             ; preds = %allocate, %entry
  call void @llvm.trap()
  unreachable
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.cttz.i16(i16, i1 immarg) #2

declare dllimport void @ExitProcess(i32)

define void @sollang_m144_s2(ptr %arg) {
entry:
  %v118106_expression_literal0 = getelementptr i8, ptr @sollang_str_118107, i64 0
  call void @sollang_runtime_print(ptr %v118106_expression_literal0, i64 10, i1 false)
  %v118106_expression1_address = getelementptr inbounds %sollang.struct.m144_s0, ptr %arg, i32 0, i32 0
  %v118106_expression1 = load %sollang.array.i32, ptr %v118106_expression1_address, align 8
  %v118106_expression0_raw = extractvalue %sollang.array.i32 %v118106_expression1, 2
  %v118106_expression0 = trunc i64 %v118106_expression0_raw to i32
  %v118106_expression0_print = zext i32 %v118106_expression0 to i64
  call void @sollang_runtime_print_i64(i64 %v118106_expression0_print, i1 false, i1 false)
  %v118106_expression_suffix = getelementptr i8, ptr @sollang_str_118107, i64 38
  call void @sollang_runtime_print(ptr %v118106_expression_suffix, i64 0, i1 true)
  ret void
}

define void @sollang_m144_s3(ptr %arg) {
entry:
  %v118111_expression_literal0 = getelementptr i8, ptr @sollang_str_118112, i64 0
  call void @sollang_runtime_print(ptr %v118111_expression_literal0, i64 9, i1 false)
  %v118111_expression3_capacity_source = load %sollang.array.i32, ptr %arg, align 8
  %v118111_expression3_raw = extractvalue %sollang.array.i32 %v118111_expression3_capacity_source, 2
  %v118111_expression3 = trunc i64 %v118111_expression3_raw to i32
  %v118111_expression3_print = zext i32 %v118111_expression3 to i64
  call void @sollang_runtime_print_i64(i64 %v118111_expression3_print, i1 false, i1 false)
  %v118111_expression_suffix = getelementptr i8, ptr @sollang_str_118112, i64 30
  call void @sollang_runtime_print(ptr %v118111_expression_suffix, i64 0, i1 true)
  ret void
}

define i32 @sollang_m144_s4(i32 %arg) {
entry:
  call void @sollang_runtime_print_i32(i32 %arg, i1 true)
  ret i32 %arg
}

define void @sollang_m144_s5() {
entry:
  %slot118121 = alloca %sollang.array.i32, align 8
  %slot118122 = alloca %sollang.array.i32, align 8
  %v118123_data = inttoptr i64 0 to ptr
  %v118123_0 = insertvalue %sollang.array.i32 poison, ptr %v118123_data, 0
  %v118123_1 = insertvalue %sollang.array.i32 %v118123_0, i64 0, 1
  %v118123 = insertvalue %sollang.array.i32 %v118123_1, i64 0, 2
  store %sollang.array.i32 %v118123, ptr %slot118121, align 8
  %v118124_expression_literal0 = getelementptr i8, ptr @sollang_str_118125, i64 0
  call void @sollang_runtime_print(ptr %v118124_expression_literal0, i64 0, i1 false)
  %v118124_expression6_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118124_expression5_raw = extractvalue %sollang.array.i32 %v118124_expression6_mutable, 1
  %v118124_expression5 = trunc i64 %v118124_expression5_raw to i32
  %v118124_expression5_print = zext i32 %v118124_expression5 to i64
  call void @sollang_runtime_print_i64(i64 %v118124_expression5_print, i1 false, i1 false)
  %v118124_expression_literal1 = getelementptr i8, ptr @sollang_str_118125, i64 12
  call void @sollang_runtime_print(ptr %v118124_expression_literal1, i64 1, i1 false)
  %v118124_expression8_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118124_expression7_raw = extractvalue %sollang.array.i32 %v118124_expression8_mutable, 2
  %v118124_expression7 = trunc i64 %v118124_expression7_raw to i32
  %v118124_expression7_print = zext i32 %v118124_expression7 to i64
  call void @sollang_runtime_print_i64(i64 %v118124_expression7_print, i1 false, i1 false)
  %v118124_expression_suffix = getelementptr i8, ptr @sollang_str_118125, i64 30
  call void @sollang_runtime_print(ptr %v118124_expression_suffix, i64 0, i1 true)
  %v118127 = load %sollang.array.i32, ptr %slot118121, align 8
  %push118126_data = extractvalue %sollang.array.i32 %v118127, 0
  %push118126_length = extractvalue %sollang.array.i32 %v118127, 1
  %push118126_capacity = extractvalue %sollang.array.i32 %v118127, 2
  %push118126_full = icmp eq i64 %push118126_length, %push118126_capacity
  %push118126_empty = icmp eq i64 %push118126_capacity, 0
  %push118126_doubled = mul i64 %push118126_capacity, 2
  %push118126_grown_capacity = select i1 %push118126_empty, i64 4, i64 %push118126_doubled
  %push118126_append_capacity = select i1 %push118126_full, i64 %push118126_grown_capacity, i64 %push118126_capacity
  %push118126_append_bytes = mul i64 %push118126_append_capacity, 4
  br i1 %push118126_full, label %push118126_grow, label %push118126_keep

push118126_keep:                                  ; preds = %entry
  br label %push118126_ready

push118126_grow:                                  ; preds = %entry
  %push118126_grown_data = call ptr @malloc(i64 %push118126_append_bytes)
  %push118126_allocated = icmp ne ptr %push118126_grown_data, null
  br i1 %push118126_allocated, label %push118126_copy, label %push118126_allocation_failed

push118126_allocation_failed:                     ; preds = %push118126_grow
  call void @llvm.trap()
  unreachable

push118126_copy:                                  ; preds = %push118126_grow
  %push118126_copy_bytes = mul i64 %push118126_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118126_grown_data, ptr %push118126_data, i64 %push118126_copy_bytes, i1 false)
  call void @free(ptr %push118126_data)
  br label %push118126_ready

push118126_ready:                                 ; preds = %push118126_copy, %push118126_keep
  %push118126_append_data = phi ptr [ %push118126_data, %push118126_keep ], [ %push118126_grown_data, %push118126_copy ]
  %push118126_slot = getelementptr i32, ptr %push118126_append_data, i64 %push118126_length
  store i32 10, ptr %push118126_slot, align 4
  %push118126_new_length = add i64 %push118126_length, 1
  %push118126_array0 = insertvalue %sollang.array.i32 poison, ptr %push118126_append_data, 0
  %push118126_array1 = insertvalue %sollang.array.i32 %push118126_array0, i64 %push118126_new_length, 1
  %push118126_array2 = insertvalue %sollang.array.i32 %push118126_array1, i64 %push118126_append_capacity, 2
  store %sollang.array.i32 %push118126_array2, ptr %slot118121, align 8
  %v118130 = load %sollang.array.i32, ptr %slot118121, align 8
  %push118129_data = extractvalue %sollang.array.i32 %v118130, 0
  %push118129_length = extractvalue %sollang.array.i32 %v118130, 1
  %push118129_capacity = extractvalue %sollang.array.i32 %v118130, 2
  %push118129_full = icmp eq i64 %push118129_length, %push118129_capacity
  %push118129_empty = icmp eq i64 %push118129_capacity, 0
  %push118129_doubled = mul i64 %push118129_capacity, 2
  %push118129_grown_capacity = select i1 %push118129_empty, i64 4, i64 %push118129_doubled
  %push118129_append_capacity = select i1 %push118129_full, i64 %push118129_grown_capacity, i64 %push118129_capacity
  %push118129_append_bytes = mul i64 %push118129_append_capacity, 4
  br i1 %push118129_full, label %push118129_grow, label %push118129_keep

push118129_keep:                                  ; preds = %push118126_ready
  br label %push118129_ready

push118129_grow:                                  ; preds = %push118126_ready
  %push118129_grown_data = call ptr @malloc(i64 %push118129_append_bytes)
  %push118129_allocated = icmp ne ptr %push118129_grown_data, null
  br i1 %push118129_allocated, label %push118129_copy, label %push118129_allocation_failed

push118129_allocation_failed:                     ; preds = %push118129_grow
  call void @llvm.trap()
  unreachable

push118129_copy:                                  ; preds = %push118129_grow
  %push118129_copy_bytes = mul i64 %push118129_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118129_grown_data, ptr %push118129_data, i64 %push118129_copy_bytes, i1 false)
  call void @free(ptr %push118129_data)
  br label %push118129_ready

push118129_ready:                                 ; preds = %push118129_copy, %push118129_keep
  %push118129_append_data = phi ptr [ %push118129_data, %push118129_keep ], [ %push118129_grown_data, %push118129_copy ]
  %push118129_slot = getelementptr i32, ptr %push118129_append_data, i64 %push118129_length
  store i32 20, ptr %push118129_slot, align 4
  %push118129_new_length = add i64 %push118129_length, 1
  %push118129_array0 = insertvalue %sollang.array.i32 poison, ptr %push118129_append_data, 0
  %push118129_array1 = insertvalue %sollang.array.i32 %push118129_array0, i64 %push118129_new_length, 1
  %push118129_array2 = insertvalue %sollang.array.i32 %push118129_array1, i64 %push118129_append_capacity, 2
  store %sollang.array.i32 %push118129_array2, ptr %slot118121, align 8
  %v118132_expression_literal0 = getelementptr i8, ptr @sollang_str_118133, i64 0
  call void @sollang_runtime_print(ptr %v118132_expression_literal0, i64 0, i1 false)
  %v118132_expression10_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118132_expression9_raw = extractvalue %sollang.array.i32 %v118132_expression10_mutable, 1
  %v118132_expression9 = trunc i64 %v118132_expression9_raw to i32
  %v118132_expression9_print = zext i32 %v118132_expression9 to i64
  call void @sollang_runtime_print_i64(i64 %v118132_expression9_print, i1 false, i1 false)
  %v118132_expression_literal1 = getelementptr i8, ptr @sollang_str_118133, i64 12
  call void @sollang_runtime_print(ptr %v118132_expression_literal1, i64 1, i1 false)
  %v118132_expression12_mutable = load %sollang.array.i32, ptr %slot118121, align 8
  %v118132_expression11_data = extractvalue %sollang.array.i32 %v118132_expression12_mutable, 0
  %v118132_expression11_index = sext i32 1 to i64
  %v118132_expression11_length = extractvalue %sollang.array.i32 %v118132_expression12_mutable, 1
  %v118132_expression11_in_bounds = icmp ult i64 %v118132_expression11_index, %v118132_expression11_length
  br i1 %v118132_expression11_in_bounds, label %interpolation118132_array11_valid, label %interpolation118132_array11_invalid

interpolation118132_array11_invalid:              ; preds = %push118129_ready
  call void @llvm.trap()
  unreachable

interpolation118132_array11_valid:                ; preds = %push118129_ready
  %v118132_expression11_ptr = getelementptr i32, ptr %v118132_expression11_data, i64 %v118132_expression11_index
  %v118132_expression11 = load i32, ptr %v118132_expression11_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118132_expression11, i1 false)
  %v118132_expression_suffix = getelementptr i8, ptr @sollang_str_118133, i64 21
  call void @sollang_runtime_print(ptr %v118132_expression_suffix, i64 0, i1 true)
  %v118134_data = call ptr @malloc(i64 16)
  %v118134_0 = insertvalue %sollang.array.i32 poison, ptr %v118134_data, 0
  %v118134_1 = insertvalue %sollang.array.i32 %v118134_0, i64 0, 1
  %v118134 = insertvalue %sollang.array.i32 %v118134_1, i64 4, 2
  store %sollang.array.i32 %v118134, ptr %slot118122, align 8
  %v118135_expression_literal0 = getelementptr i8, ptr @sollang_str_118136, i64 0
  call void @sollang_runtime_print(ptr %v118135_expression_literal0, i64 0, i1 false)
  %v118135_expression15_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118135_expression14_raw = extractvalue %sollang.array.i32 %v118135_expression15_mutable, 1
  %v118135_expression14 = trunc i64 %v118135_expression14_raw to i32
  %v118135_expression14_print = zext i32 %v118135_expression14 to i64
  call void @sollang_runtime_print_i64(i64 %v118135_expression14_print, i1 false, i1 false)
  %v118135_expression_literal1 = getelementptr i8, ptr @sollang_str_118136, i64 12
  call void @sollang_runtime_print(ptr %v118135_expression_literal1, i64 1, i1 false)
  %v118135_expression17_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118135_expression16_raw = extractvalue %sollang.array.i32 %v118135_expression17_mutable, 2
  %v118135_expression16 = trunc i64 %v118135_expression16_raw to i32
  %v118135_expression16_print = zext i32 %v118135_expression16 to i64
  call void @sollang_runtime_print_i64(i64 %v118135_expression16_print, i1 false, i1 false)
  %v118135_expression_suffix = getelementptr i8, ptr @sollang_str_118136, i64 30
  call void @sollang_runtime_print(ptr %v118135_expression_suffix, i64 0, i1 true)
  %v118138 = load %sollang.array.i32, ptr %slot118122, align 8
  %push118137_data = extractvalue %sollang.array.i32 %v118138, 0
  %push118137_length = extractvalue %sollang.array.i32 %v118138, 1
  %push118137_capacity = extractvalue %sollang.array.i32 %v118138, 2
  %push118137_full = icmp eq i64 %push118137_length, %push118137_capacity
  %push118137_empty = icmp eq i64 %push118137_capacity, 0
  %push118137_doubled = mul i64 %push118137_capacity, 2
  %push118137_grown_capacity = select i1 %push118137_empty, i64 4, i64 %push118137_doubled
  %push118137_append_capacity = select i1 %push118137_full, i64 %push118137_grown_capacity, i64 %push118137_capacity
  %push118137_append_bytes = mul i64 %push118137_append_capacity, 4
  br i1 %push118137_full, label %push118137_grow, label %push118137_keep

push118137_keep:                                  ; preds = %interpolation118132_array11_valid
  br label %push118137_ready

push118137_grow:                                  ; preds = %interpolation118132_array11_valid
  %push118137_grown_data = call ptr @malloc(i64 %push118137_append_bytes)
  %push118137_allocated = icmp ne ptr %push118137_grown_data, null
  br i1 %push118137_allocated, label %push118137_copy, label %push118137_allocation_failed

push118137_allocation_failed:                     ; preds = %push118137_grow
  call void @llvm.trap()
  unreachable

push118137_copy:                                  ; preds = %push118137_grow
  %push118137_copy_bytes = mul i64 %push118137_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118137_grown_data, ptr %push118137_data, i64 %push118137_copy_bytes, i1 false)
  call void @free(ptr %push118137_data)
  br label %push118137_ready

push118137_ready:                                 ; preds = %push118137_copy, %push118137_keep
  %push118137_append_data = phi ptr [ %push118137_data, %push118137_keep ], [ %push118137_grown_data, %push118137_copy ]
  %push118137_slot = getelementptr i32, ptr %push118137_append_data, i64 %push118137_length
  store i32 10, ptr %push118137_slot, align 4
  %push118137_new_length = add i64 %push118137_length, 1
  %push118137_array0 = insertvalue %sollang.array.i32 poison, ptr %push118137_append_data, 0
  %push118137_array1 = insertvalue %sollang.array.i32 %push118137_array0, i64 %push118137_new_length, 1
  %push118137_array2 = insertvalue %sollang.array.i32 %push118137_array1, i64 %push118137_append_capacity, 2
  store %sollang.array.i32 %push118137_array2, ptr %slot118122, align 8
  %v118141 = load %sollang.array.i32, ptr %slot118122, align 8
  %push118140_data = extractvalue %sollang.array.i32 %v118141, 0
  %push118140_length = extractvalue %sollang.array.i32 %v118141, 1
  %push118140_capacity = extractvalue %sollang.array.i32 %v118141, 2
  %push118140_full = icmp eq i64 %push118140_length, %push118140_capacity
  %push118140_empty = icmp eq i64 %push118140_capacity, 0
  %push118140_doubled = mul i64 %push118140_capacity, 2
  %push118140_grown_capacity = select i1 %push118140_empty, i64 4, i64 %push118140_doubled
  %push118140_append_capacity = select i1 %push118140_full, i64 %push118140_grown_capacity, i64 %push118140_capacity
  %push118140_append_bytes = mul i64 %push118140_append_capacity, 4
  br i1 %push118140_full, label %push118140_grow, label %push118140_keep

push118140_keep:                                  ; preds = %push118137_ready
  br label %push118140_ready

push118140_grow:                                  ; preds = %push118137_ready
  %push118140_grown_data = call ptr @malloc(i64 %push118140_append_bytes)
  %push118140_allocated = icmp ne ptr %push118140_grown_data, null
  br i1 %push118140_allocated, label %push118140_copy, label %push118140_allocation_failed

push118140_allocation_failed:                     ; preds = %push118140_grow
  call void @llvm.trap()
  unreachable

push118140_copy:                                  ; preds = %push118140_grow
  %push118140_copy_bytes = mul i64 %push118140_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118140_grown_data, ptr %push118140_data, i64 %push118140_copy_bytes, i1 false)
  call void @free(ptr %push118140_data)
  br label %push118140_ready

push118140_ready:                                 ; preds = %push118140_copy, %push118140_keep
  %push118140_append_data = phi ptr [ %push118140_data, %push118140_keep ], [ %push118140_grown_data, %push118140_copy ]
  %push118140_slot = getelementptr i32, ptr %push118140_append_data, i64 %push118140_length
  store i32 20, ptr %push118140_slot, align 4
  %push118140_new_length = add i64 %push118140_length, 1
  %push118140_array0 = insertvalue %sollang.array.i32 poison, ptr %push118140_append_data, 0
  %push118140_array1 = insertvalue %sollang.array.i32 %push118140_array0, i64 %push118140_new_length, 1
  %push118140_array2 = insertvalue %sollang.array.i32 %push118140_array1, i64 %push118140_append_capacity, 2
  store %sollang.array.i32 %push118140_array2, ptr %slot118122, align 8
  %v118143_expression_literal0 = getelementptr i8, ptr @sollang_str_118144, i64 0
  call void @sollang_runtime_print(ptr %v118143_expression_literal0, i64 0, i1 false)
  %v118143_expression19_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118143_expression18_raw = extractvalue %sollang.array.i32 %v118143_expression19_mutable, 1
  %v118143_expression18 = trunc i64 %v118143_expression18_raw to i32
  %v118143_expression18_print = zext i32 %v118143_expression18 to i64
  call void @sollang_runtime_print_i64(i64 %v118143_expression18_print, i1 false, i1 false)
  %v118143_expression_literal1 = getelementptr i8, ptr @sollang_str_118144, i64 12
  call void @sollang_runtime_print(ptr %v118143_expression_literal1, i64 1, i1 false)
  %v118143_expression21_mutable = load %sollang.array.i32, ptr %slot118122, align 8
  %v118143_expression20_data = extractvalue %sollang.array.i32 %v118143_expression21_mutable, 0
  %v118143_expression20_index = sext i32 1 to i64
  %v118143_expression20_length = extractvalue %sollang.array.i32 %v118143_expression21_mutable, 1
  %v118143_expression20_in_bounds = icmp ult i64 %v118143_expression20_index, %v118143_expression20_length
  br i1 %v118143_expression20_in_bounds, label %interpolation118143_array20_valid, label %interpolation118143_array20_invalid

interpolation118143_array20_invalid:              ; preds = %push118140_ready
  call void @llvm.trap()
  unreachable

interpolation118143_array20_valid:                ; preds = %push118140_ready
  %v118143_expression20_ptr = getelementptr i32, ptr %v118143_expression20_data, i64 %v118143_expression20_index
  %v118143_expression20 = load i32, ptr %v118143_expression20_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118143_expression20, i1 false)
  %v118143_expression_suffix = getelementptr i8, ptr @sollang_str_118144, i64 21
  call void @sollang_runtime_print(ptr %v118143_expression_suffix, i64 0, i1 true)
  %drop118121_current = load %sollang.array.i32, ptr %slot118121, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %drop118121_current)
  %drop118122_current = load %sollang.array.i32, ptr %slot118122, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %drop118122_current)
  ret void
}

define void @sollang_m144_s8() {
entry:
  %slot118147 = alloca %sollang.array.i32, align 8
  %slot118148 = alloca %sollang.array.i32, align 8
  br i1 true, label %if118151_then, label %if118151_merge

if118151_then:                                    ; preds = %entry
  %v118153_data = inttoptr i64 0 to ptr
  %v118153_0 = insertvalue %sollang.array.i32 poison, ptr %v118153_data, 0
  %v118153_1 = insertvalue %sollang.array.i32 %v118153_0, i64 0, 1
  %v118153 = insertvalue %sollang.array.i32 %v118153_1, i64 0, 2
  store %sollang.array.i32 %v118153, ptr %slot118147, align 8
  %v118154_expression_literal0 = getelementptr i8, ptr @sollang_str_118155, i64 0
  call void @sollang_runtime_print(ptr %v118154_expression_literal0, i64 0, i1 false)
  %v118154_expression24_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118154_expression23_raw = extractvalue %sollang.array.i32 %v118154_expression24_mutable, 1
  %v118154_expression23 = trunc i64 %v118154_expression23_raw to i32
  %v118154_expression23_print = zext i32 %v118154_expression23 to i64
  call void @sollang_runtime_print_i64(i64 %v118154_expression23_print, i1 false, i1 false)
  %v118154_expression_literal1 = getelementptr i8, ptr @sollang_str_118155, i64 12
  call void @sollang_runtime_print(ptr %v118154_expression_literal1, i64 1, i1 false)
  %v118154_expression26_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118154_expression25_raw = extractvalue %sollang.array.i32 %v118154_expression26_mutable, 2
  %v118154_expression25 = trunc i64 %v118154_expression25_raw to i32
  %v118154_expression25_print = zext i32 %v118154_expression25 to i64
  call void @sollang_runtime_print_i64(i64 %v118154_expression25_print, i1 false, i1 false)
  %v118154_expression_suffix = getelementptr i8, ptr @sollang_str_118155, i64 30
  call void @sollang_runtime_print(ptr %v118154_expression_suffix, i64 0, i1 true)
  %v118157 = load %sollang.array.i32, ptr %slot118147, align 8
  %push118156_data = extractvalue %sollang.array.i32 %v118157, 0
  %push118156_length = extractvalue %sollang.array.i32 %v118157, 1
  %push118156_capacity = extractvalue %sollang.array.i32 %v118157, 2
  %push118156_full = icmp eq i64 %push118156_length, %push118156_capacity
  %push118156_empty = icmp eq i64 %push118156_capacity, 0
  %push118156_doubled = mul i64 %push118156_capacity, 2
  %push118156_grown_capacity = select i1 %push118156_empty, i64 4, i64 %push118156_doubled
  %push118156_append_capacity = select i1 %push118156_full, i64 %push118156_grown_capacity, i64 %push118156_capacity
  %push118156_append_bytes = mul i64 %push118156_append_capacity, 4
  br i1 %push118156_full, label %push118156_grow, label %push118156_keep

push118156_keep:                                  ; preds = %if118151_then
  br label %push118156_ready

push118156_grow:                                  ; preds = %if118151_then
  %push118156_grown_data = call ptr @malloc(i64 %push118156_append_bytes)
  %push118156_allocated = icmp ne ptr %push118156_grown_data, null
  br i1 %push118156_allocated, label %push118156_copy, label %push118156_allocation_failed

push118156_allocation_failed:                     ; preds = %push118156_grow
  call void @llvm.trap()
  unreachable

push118156_copy:                                  ; preds = %push118156_grow
  %push118156_copy_bytes = mul i64 %push118156_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118156_grown_data, ptr %push118156_data, i64 %push118156_copy_bytes, i1 false)
  call void @free(ptr %push118156_data)
  br label %push118156_ready

push118156_ready:                                 ; preds = %push118156_copy, %push118156_keep
  %push118156_append_data = phi ptr [ %push118156_data, %push118156_keep ], [ %push118156_grown_data, %push118156_copy ]
  %push118156_slot = getelementptr i32, ptr %push118156_append_data, i64 %push118156_length
  store i32 10, ptr %push118156_slot, align 4
  %push118156_new_length = add i64 %push118156_length, 1
  %push118156_array0 = insertvalue %sollang.array.i32 poison, ptr %push118156_append_data, 0
  %push118156_array1 = insertvalue %sollang.array.i32 %push118156_array0, i64 %push118156_new_length, 1
  %push118156_array2 = insertvalue %sollang.array.i32 %push118156_array1, i64 %push118156_append_capacity, 2
  store %sollang.array.i32 %push118156_array2, ptr %slot118147, align 8
  %v118160 = load %sollang.array.i32, ptr %slot118147, align 8
  %push118159_data = extractvalue %sollang.array.i32 %v118160, 0
  %push118159_length = extractvalue %sollang.array.i32 %v118160, 1
  %push118159_capacity = extractvalue %sollang.array.i32 %v118160, 2
  %push118159_full = icmp eq i64 %push118159_length, %push118159_capacity
  %push118159_empty = icmp eq i64 %push118159_capacity, 0
  %push118159_doubled = mul i64 %push118159_capacity, 2
  %push118159_grown_capacity = select i1 %push118159_empty, i64 4, i64 %push118159_doubled
  %push118159_append_capacity = select i1 %push118159_full, i64 %push118159_grown_capacity, i64 %push118159_capacity
  %push118159_append_bytes = mul i64 %push118159_append_capacity, 4
  br i1 %push118159_full, label %push118159_grow, label %push118159_keep

push118159_keep:                                  ; preds = %push118156_ready
  br label %push118159_ready

push118159_grow:                                  ; preds = %push118156_ready
  %push118159_grown_data = call ptr @malloc(i64 %push118159_append_bytes)
  %push118159_allocated = icmp ne ptr %push118159_grown_data, null
  br i1 %push118159_allocated, label %push118159_copy, label %push118159_allocation_failed

push118159_allocation_failed:                     ; preds = %push118159_grow
  call void @llvm.trap()
  unreachable

push118159_copy:                                  ; preds = %push118159_grow
  %push118159_copy_bytes = mul i64 %push118159_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118159_grown_data, ptr %push118159_data, i64 %push118159_copy_bytes, i1 false)
  call void @free(ptr %push118159_data)
  br label %push118159_ready

push118159_ready:                                 ; preds = %push118159_copy, %push118159_keep
  %push118159_append_data = phi ptr [ %push118159_data, %push118159_keep ], [ %push118159_grown_data, %push118159_copy ]
  %push118159_slot = getelementptr i32, ptr %push118159_append_data, i64 %push118159_length
  store i32 20, ptr %push118159_slot, align 4
  %push118159_new_length = add i64 %push118159_length, 1
  %push118159_array0 = insertvalue %sollang.array.i32 poison, ptr %push118159_append_data, 0
  %push118159_array1 = insertvalue %sollang.array.i32 %push118159_array0, i64 %push118159_new_length, 1
  %push118159_array2 = insertvalue %sollang.array.i32 %push118159_array1, i64 %push118159_append_capacity, 2
  store %sollang.array.i32 %push118159_array2, ptr %slot118147, align 8
  %v118162_expression_literal0 = getelementptr i8, ptr @sollang_str_118163, i64 0
  call void @sollang_runtime_print(ptr %v118162_expression_literal0, i64 0, i1 false)
  %v118162_expression28_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118162_expression27_raw = extractvalue %sollang.array.i32 %v118162_expression28_mutable, 1
  %v118162_expression27 = trunc i64 %v118162_expression27_raw to i32
  %v118162_expression27_print = zext i32 %v118162_expression27 to i64
  call void @sollang_runtime_print_i64(i64 %v118162_expression27_print, i1 false, i1 false)
  %v118162_expression_literal1 = getelementptr i8, ptr @sollang_str_118163, i64 12
  call void @sollang_runtime_print(ptr %v118162_expression_literal1, i64 1, i1 false)
  %v118162_expression30_mutable = load %sollang.array.i32, ptr %slot118147, align 8
  %v118162_expression29_data = extractvalue %sollang.array.i32 %v118162_expression30_mutable, 0
  %v118162_expression29_index = sext i32 1 to i64
  %v118162_expression29_length = extractvalue %sollang.array.i32 %v118162_expression30_mutable, 1
  %v118162_expression29_in_bounds = icmp ult i64 %v118162_expression29_index, %v118162_expression29_length
  br i1 %v118162_expression29_in_bounds, label %interpolation118162_array29_valid, label %interpolation118162_array29_invalid

interpolation118162_array29_invalid:              ; preds = %push118159_ready
  call void @llvm.trap()
  unreachable

interpolation118162_array29_valid:                ; preds = %push118159_ready
  %v118162_expression29_ptr = getelementptr i32, ptr %v118162_expression29_data, i64 %v118162_expression29_index
  %v118162_expression29 = load i32, ptr %v118162_expression29_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118162_expression29, i1 false)
  %v118162_expression_suffix = getelementptr i8, ptr @sollang_str_118163, i64 21
  call void @sollang_runtime_print(ptr %v118162_expression_suffix, i64 0, i1 true)
  %v118164_data = call ptr @malloc(i64 16)
  %v118164_0 = insertvalue %sollang.array.i32 poison, ptr %v118164_data, 0
  %v118164_1 = insertvalue %sollang.array.i32 %v118164_0, i64 0, 1
  %v118164 = insertvalue %sollang.array.i32 %v118164_1, i64 4, 2
  store %sollang.array.i32 %v118164, ptr %slot118148, align 8
  %v118165_expression_literal0 = getelementptr i8, ptr @sollang_str_118166, i64 0
  call void @sollang_runtime_print(ptr %v118165_expression_literal0, i64 0, i1 false)
  %v118165_expression33_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118165_expression32_raw = extractvalue %sollang.array.i32 %v118165_expression33_mutable, 1
  %v118165_expression32 = trunc i64 %v118165_expression32_raw to i32
  %v118165_expression32_print = zext i32 %v118165_expression32 to i64
  call void @sollang_runtime_print_i64(i64 %v118165_expression32_print, i1 false, i1 false)
  %v118165_expression_literal1 = getelementptr i8, ptr @sollang_str_118166, i64 12
  call void @sollang_runtime_print(ptr %v118165_expression_literal1, i64 1, i1 false)
  %v118165_expression35_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118165_expression34_raw = extractvalue %sollang.array.i32 %v118165_expression35_mutable, 2
  %v118165_expression34 = trunc i64 %v118165_expression34_raw to i32
  %v118165_expression34_print = zext i32 %v118165_expression34 to i64
  call void @sollang_runtime_print_i64(i64 %v118165_expression34_print, i1 false, i1 false)
  %v118165_expression_suffix = getelementptr i8, ptr @sollang_str_118166, i64 30
  call void @sollang_runtime_print(ptr %v118165_expression_suffix, i64 0, i1 true)
  %v118168 = load %sollang.array.i32, ptr %slot118148, align 8
  %push118167_data = extractvalue %sollang.array.i32 %v118168, 0
  %push118167_length = extractvalue %sollang.array.i32 %v118168, 1
  %push118167_capacity = extractvalue %sollang.array.i32 %v118168, 2
  %push118167_full = icmp eq i64 %push118167_length, %push118167_capacity
  %push118167_empty = icmp eq i64 %push118167_capacity, 0
  %push118167_doubled = mul i64 %push118167_capacity, 2
  %push118167_grown_capacity = select i1 %push118167_empty, i64 4, i64 %push118167_doubled
  %push118167_append_capacity = select i1 %push118167_full, i64 %push118167_grown_capacity, i64 %push118167_capacity
  %push118167_append_bytes = mul i64 %push118167_append_capacity, 4
  br i1 %push118167_full, label %push118167_grow, label %push118167_keep

push118167_keep:                                  ; preds = %interpolation118162_array29_valid
  br label %push118167_ready

push118167_grow:                                  ; preds = %interpolation118162_array29_valid
  %push118167_grown_data = call ptr @malloc(i64 %push118167_append_bytes)
  %push118167_allocated = icmp ne ptr %push118167_grown_data, null
  br i1 %push118167_allocated, label %push118167_copy, label %push118167_allocation_failed

push118167_allocation_failed:                     ; preds = %push118167_grow
  call void @llvm.trap()
  unreachable

push118167_copy:                                  ; preds = %push118167_grow
  %push118167_copy_bytes = mul i64 %push118167_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118167_grown_data, ptr %push118167_data, i64 %push118167_copy_bytes, i1 false)
  call void @free(ptr %push118167_data)
  br label %push118167_ready

push118167_ready:                                 ; preds = %push118167_copy, %push118167_keep
  %push118167_append_data = phi ptr [ %push118167_data, %push118167_keep ], [ %push118167_grown_data, %push118167_copy ]
  %push118167_slot = getelementptr i32, ptr %push118167_append_data, i64 %push118167_length
  store i32 10, ptr %push118167_slot, align 4
  %push118167_new_length = add i64 %push118167_length, 1
  %push118167_array0 = insertvalue %sollang.array.i32 poison, ptr %push118167_append_data, 0
  %push118167_array1 = insertvalue %sollang.array.i32 %push118167_array0, i64 %push118167_new_length, 1
  %push118167_array2 = insertvalue %sollang.array.i32 %push118167_array1, i64 %push118167_append_capacity, 2
  store %sollang.array.i32 %push118167_array2, ptr %slot118148, align 8
  %v118171 = load %sollang.array.i32, ptr %slot118148, align 8
  %push118170_data = extractvalue %sollang.array.i32 %v118171, 0
  %push118170_length = extractvalue %sollang.array.i32 %v118171, 1
  %push118170_capacity = extractvalue %sollang.array.i32 %v118171, 2
  %push118170_full = icmp eq i64 %push118170_length, %push118170_capacity
  %push118170_empty = icmp eq i64 %push118170_capacity, 0
  %push118170_doubled = mul i64 %push118170_capacity, 2
  %push118170_grown_capacity = select i1 %push118170_empty, i64 4, i64 %push118170_doubled
  %push118170_append_capacity = select i1 %push118170_full, i64 %push118170_grown_capacity, i64 %push118170_capacity
  %push118170_append_bytes = mul i64 %push118170_append_capacity, 4
  br i1 %push118170_full, label %push118170_grow, label %push118170_keep

push118170_keep:                                  ; preds = %push118167_ready
  br label %push118170_ready

push118170_grow:                                  ; preds = %push118167_ready
  %push118170_grown_data = call ptr @malloc(i64 %push118170_append_bytes)
  %push118170_allocated = icmp ne ptr %push118170_grown_data, null
  br i1 %push118170_allocated, label %push118170_copy, label %push118170_allocation_failed

push118170_allocation_failed:                     ; preds = %push118170_grow
  call void @llvm.trap()
  unreachable

push118170_copy:                                  ; preds = %push118170_grow
  %push118170_copy_bytes = mul i64 %push118170_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118170_grown_data, ptr %push118170_data, i64 %push118170_copy_bytes, i1 false)
  call void @free(ptr %push118170_data)
  br label %push118170_ready

push118170_ready:                                 ; preds = %push118170_copy, %push118170_keep
  %push118170_append_data = phi ptr [ %push118170_data, %push118170_keep ], [ %push118170_grown_data, %push118170_copy ]
  %push118170_slot = getelementptr i32, ptr %push118170_append_data, i64 %push118170_length
  store i32 20, ptr %push118170_slot, align 4
  %push118170_new_length = add i64 %push118170_length, 1
  %push118170_array0 = insertvalue %sollang.array.i32 poison, ptr %push118170_append_data, 0
  %push118170_array1 = insertvalue %sollang.array.i32 %push118170_array0, i64 %push118170_new_length, 1
  %push118170_array2 = insertvalue %sollang.array.i32 %push118170_array1, i64 %push118170_append_capacity, 2
  store %sollang.array.i32 %push118170_array2, ptr %slot118148, align 8
  %v118173_expression_literal0 = getelementptr i8, ptr @sollang_str_118174, i64 0
  call void @sollang_runtime_print(ptr %v118173_expression_literal0, i64 0, i1 false)
  %v118173_expression37_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118173_expression36_raw = extractvalue %sollang.array.i32 %v118173_expression37_mutable, 1
  %v118173_expression36 = trunc i64 %v118173_expression36_raw to i32
  %v118173_expression36_print = zext i32 %v118173_expression36 to i64
  call void @sollang_runtime_print_i64(i64 %v118173_expression36_print, i1 false, i1 false)
  %v118173_expression_literal1 = getelementptr i8, ptr @sollang_str_118174, i64 12
  call void @sollang_runtime_print(ptr %v118173_expression_literal1, i64 1, i1 false)
  %v118173_expression39_mutable = load %sollang.array.i32, ptr %slot118148, align 8
  %v118173_expression38_data = extractvalue %sollang.array.i32 %v118173_expression39_mutable, 0
  %v118173_expression38_index = sext i32 1 to i64
  %v118173_expression38_length = extractvalue %sollang.array.i32 %v118173_expression39_mutable, 1
  %v118173_expression38_in_bounds = icmp ult i64 %v118173_expression38_index, %v118173_expression38_length
  br i1 %v118173_expression38_in_bounds, label %interpolation118173_array38_valid, label %interpolation118173_array38_invalid

interpolation118173_array38_invalid:              ; preds = %push118170_ready
  call void @llvm.trap()
  unreachable

interpolation118173_array38_valid:                ; preds = %push118170_ready
  %v118173_expression38_ptr = getelementptr i32, ptr %v118173_expression38_data, i64 %v118173_expression38_index
  %v118173_expression38 = load i32, ptr %v118173_expression38_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118173_expression38, i1 false)
  %v118173_expression_suffix = getelementptr i8, ptr @sollang_str_118174, i64 21
  call void @sollang_runtime_print(ptr %v118173_expression_suffix, i64 0, i1 true)
  %cleanup1181511_b118148_current = load %sollang.array.i32, ptr %slot118148, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181511_b118148_current)
  %cleanup1181511_b118147_current = load %sollang.array.i32, ptr %slot118147, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181511_b118147_current)
  br label %if118151_merge

if118151_merge:                                   ; preds = %interpolation118173_array38_valid, %entry
  ret void
}

define void @sollang_m144_s11() {
entry:
  %slot118177 = alloca i32, align 4
  %slot118178 = alloca %sollang.array.i32, align 8
  %slot118179 = alloca %sollang.array.i32, align 8
  store i32 0, ptr %slot118177, align 4
  br label %while118186_header

while118186_header:                               ; preds = %interpolation118208_array56_valid, %entry
  %while118186_v118184 = load i32, ptr %slot118177, align 4
  %while118186_v118183 = icmp slt i32 %while118186_v118184, 1
  br i1 %while118186_v118183, label %while118186_body, label %while118186_exit

while118186_body:                                 ; preds = %while118186_header
  %v118188_data = inttoptr i64 0 to ptr
  %v118188_0 = insertvalue %sollang.array.i32 poison, ptr %v118188_data, 0
  %v118188_1 = insertvalue %sollang.array.i32 %v118188_0, i64 0, 1
  %v118188 = insertvalue %sollang.array.i32 %v118188_1, i64 0, 2
  store %sollang.array.i32 %v118188, ptr %slot118178, align 8
  %v118189_expression_literal0 = getelementptr i8, ptr @sollang_str_118190, i64 0
  call void @sollang_runtime_print(ptr %v118189_expression_literal0, i64 0, i1 false)
  %v118189_expression42_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118189_expression41_raw = extractvalue %sollang.array.i32 %v118189_expression42_mutable, 1
  %v118189_expression41 = trunc i64 %v118189_expression41_raw to i32
  %v118189_expression41_print = zext i32 %v118189_expression41 to i64
  call void @sollang_runtime_print_i64(i64 %v118189_expression41_print, i1 false, i1 false)
  %v118189_expression_literal1 = getelementptr i8, ptr @sollang_str_118190, i64 12
  call void @sollang_runtime_print(ptr %v118189_expression_literal1, i64 1, i1 false)
  %v118189_expression44_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118189_expression43_raw = extractvalue %sollang.array.i32 %v118189_expression44_mutable, 2
  %v118189_expression43 = trunc i64 %v118189_expression43_raw to i32
  %v118189_expression43_print = zext i32 %v118189_expression43 to i64
  call void @sollang_runtime_print_i64(i64 %v118189_expression43_print, i1 false, i1 false)
  %v118189_expression_suffix = getelementptr i8, ptr @sollang_str_118190, i64 30
  call void @sollang_runtime_print(ptr %v118189_expression_suffix, i64 0, i1 true)
  %v118192 = load %sollang.array.i32, ptr %slot118178, align 8
  %push118191_data = extractvalue %sollang.array.i32 %v118192, 0
  %push118191_length = extractvalue %sollang.array.i32 %v118192, 1
  %push118191_capacity = extractvalue %sollang.array.i32 %v118192, 2
  %push118191_full = icmp eq i64 %push118191_length, %push118191_capacity
  %push118191_empty = icmp eq i64 %push118191_capacity, 0
  %push118191_doubled = mul i64 %push118191_capacity, 2
  %push118191_grown_capacity = select i1 %push118191_empty, i64 4, i64 %push118191_doubled
  %push118191_append_capacity = select i1 %push118191_full, i64 %push118191_grown_capacity, i64 %push118191_capacity
  %push118191_append_bytes = mul i64 %push118191_append_capacity, 4
  br i1 %push118191_full, label %push118191_grow, label %push118191_keep

push118191_keep:                                  ; preds = %while118186_body
  br label %push118191_ready

push118191_grow:                                  ; preds = %while118186_body
  %push118191_grown_data = call ptr @malloc(i64 %push118191_append_bytes)
  %push118191_allocated = icmp ne ptr %push118191_grown_data, null
  br i1 %push118191_allocated, label %push118191_copy, label %push118191_allocation_failed

push118191_allocation_failed:                     ; preds = %push118191_grow
  call void @llvm.trap()
  unreachable

push118191_copy:                                  ; preds = %push118191_grow
  %push118191_copy_bytes = mul i64 %push118191_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118191_grown_data, ptr %push118191_data, i64 %push118191_copy_bytes, i1 false)
  call void @free(ptr %push118191_data)
  br label %push118191_ready

push118191_ready:                                 ; preds = %push118191_copy, %push118191_keep
  %push118191_append_data = phi ptr [ %push118191_data, %push118191_keep ], [ %push118191_grown_data, %push118191_copy ]
  %push118191_slot = getelementptr i32, ptr %push118191_append_data, i64 %push118191_length
  store i32 10, ptr %push118191_slot, align 4
  %push118191_new_length = add i64 %push118191_length, 1
  %push118191_array0 = insertvalue %sollang.array.i32 poison, ptr %push118191_append_data, 0
  %push118191_array1 = insertvalue %sollang.array.i32 %push118191_array0, i64 %push118191_new_length, 1
  %push118191_array2 = insertvalue %sollang.array.i32 %push118191_array1, i64 %push118191_append_capacity, 2
  store %sollang.array.i32 %push118191_array2, ptr %slot118178, align 8
  %v118195 = load %sollang.array.i32, ptr %slot118178, align 8
  %push118194_data = extractvalue %sollang.array.i32 %v118195, 0
  %push118194_length = extractvalue %sollang.array.i32 %v118195, 1
  %push118194_capacity = extractvalue %sollang.array.i32 %v118195, 2
  %push118194_full = icmp eq i64 %push118194_length, %push118194_capacity
  %push118194_empty = icmp eq i64 %push118194_capacity, 0
  %push118194_doubled = mul i64 %push118194_capacity, 2
  %push118194_grown_capacity = select i1 %push118194_empty, i64 4, i64 %push118194_doubled
  %push118194_append_capacity = select i1 %push118194_full, i64 %push118194_grown_capacity, i64 %push118194_capacity
  %push118194_append_bytes = mul i64 %push118194_append_capacity, 4
  br i1 %push118194_full, label %push118194_grow, label %push118194_keep

push118194_keep:                                  ; preds = %push118191_ready
  br label %push118194_ready

push118194_grow:                                  ; preds = %push118191_ready
  %push118194_grown_data = call ptr @malloc(i64 %push118194_append_bytes)
  %push118194_allocated = icmp ne ptr %push118194_grown_data, null
  br i1 %push118194_allocated, label %push118194_copy, label %push118194_allocation_failed

push118194_allocation_failed:                     ; preds = %push118194_grow
  call void @llvm.trap()
  unreachable

push118194_copy:                                  ; preds = %push118194_grow
  %push118194_copy_bytes = mul i64 %push118194_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118194_grown_data, ptr %push118194_data, i64 %push118194_copy_bytes, i1 false)
  call void @free(ptr %push118194_data)
  br label %push118194_ready

push118194_ready:                                 ; preds = %push118194_copy, %push118194_keep
  %push118194_append_data = phi ptr [ %push118194_data, %push118194_keep ], [ %push118194_grown_data, %push118194_copy ]
  %push118194_slot = getelementptr i32, ptr %push118194_append_data, i64 %push118194_length
  store i32 20, ptr %push118194_slot, align 4
  %push118194_new_length = add i64 %push118194_length, 1
  %push118194_array0 = insertvalue %sollang.array.i32 poison, ptr %push118194_append_data, 0
  %push118194_array1 = insertvalue %sollang.array.i32 %push118194_array0, i64 %push118194_new_length, 1
  %push118194_array2 = insertvalue %sollang.array.i32 %push118194_array1, i64 %push118194_append_capacity, 2
  store %sollang.array.i32 %push118194_array2, ptr %slot118178, align 8
  %v118197_expression_literal0 = getelementptr i8, ptr @sollang_str_118198, i64 0
  call void @sollang_runtime_print(ptr %v118197_expression_literal0, i64 0, i1 false)
  %v118197_expression46_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118197_expression45_raw = extractvalue %sollang.array.i32 %v118197_expression46_mutable, 1
  %v118197_expression45 = trunc i64 %v118197_expression45_raw to i32
  %v118197_expression45_print = zext i32 %v118197_expression45 to i64
  call void @sollang_runtime_print_i64(i64 %v118197_expression45_print, i1 false, i1 false)
  %v118197_expression_literal1 = getelementptr i8, ptr @sollang_str_118198, i64 12
  call void @sollang_runtime_print(ptr %v118197_expression_literal1, i64 1, i1 false)
  %v118197_expression48_mutable = load %sollang.array.i32, ptr %slot118178, align 8
  %v118197_expression47_data = extractvalue %sollang.array.i32 %v118197_expression48_mutable, 0
  %v118197_expression47_index = sext i32 1 to i64
  %v118197_expression47_length = extractvalue %sollang.array.i32 %v118197_expression48_mutable, 1
  %v118197_expression47_in_bounds = icmp ult i64 %v118197_expression47_index, %v118197_expression47_length
  br i1 %v118197_expression47_in_bounds, label %interpolation118197_array47_valid, label %interpolation118197_array47_invalid

interpolation118197_array47_invalid:              ; preds = %push118194_ready
  call void @llvm.trap()
  unreachable

interpolation118197_array47_valid:                ; preds = %push118194_ready
  %v118197_expression47_ptr = getelementptr i32, ptr %v118197_expression47_data, i64 %v118197_expression47_index
  %v118197_expression47 = load i32, ptr %v118197_expression47_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118197_expression47, i1 false)
  %v118197_expression_suffix = getelementptr i8, ptr @sollang_str_118198, i64 21
  call void @sollang_runtime_print(ptr %v118197_expression_suffix, i64 0, i1 true)
  %v118199_data = call ptr @malloc(i64 16)
  %v118199_0 = insertvalue %sollang.array.i32 poison, ptr %v118199_data, 0
  %v118199_1 = insertvalue %sollang.array.i32 %v118199_0, i64 0, 1
  %v118199 = insertvalue %sollang.array.i32 %v118199_1, i64 4, 2
  store %sollang.array.i32 %v118199, ptr %slot118179, align 8
  %v118200_expression_literal0 = getelementptr i8, ptr @sollang_str_118201, i64 0
  call void @sollang_runtime_print(ptr %v118200_expression_literal0, i64 0, i1 false)
  %v118200_expression51_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118200_expression50_raw = extractvalue %sollang.array.i32 %v118200_expression51_mutable, 1
  %v118200_expression50 = trunc i64 %v118200_expression50_raw to i32
  %v118200_expression50_print = zext i32 %v118200_expression50 to i64
  call void @sollang_runtime_print_i64(i64 %v118200_expression50_print, i1 false, i1 false)
  %v118200_expression_literal1 = getelementptr i8, ptr @sollang_str_118201, i64 12
  call void @sollang_runtime_print(ptr %v118200_expression_literal1, i64 1, i1 false)
  %v118200_expression53_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118200_expression52_raw = extractvalue %sollang.array.i32 %v118200_expression53_mutable, 2
  %v118200_expression52 = trunc i64 %v118200_expression52_raw to i32
  %v118200_expression52_print = zext i32 %v118200_expression52 to i64
  call void @sollang_runtime_print_i64(i64 %v118200_expression52_print, i1 false, i1 false)
  %v118200_expression_suffix = getelementptr i8, ptr @sollang_str_118201, i64 30
  call void @sollang_runtime_print(ptr %v118200_expression_suffix, i64 0, i1 true)
  %v118203 = load %sollang.array.i32, ptr %slot118179, align 8
  %push118202_data = extractvalue %sollang.array.i32 %v118203, 0
  %push118202_length = extractvalue %sollang.array.i32 %v118203, 1
  %push118202_capacity = extractvalue %sollang.array.i32 %v118203, 2
  %push118202_full = icmp eq i64 %push118202_length, %push118202_capacity
  %push118202_empty = icmp eq i64 %push118202_capacity, 0
  %push118202_doubled = mul i64 %push118202_capacity, 2
  %push118202_grown_capacity = select i1 %push118202_empty, i64 4, i64 %push118202_doubled
  %push118202_append_capacity = select i1 %push118202_full, i64 %push118202_grown_capacity, i64 %push118202_capacity
  %push118202_append_bytes = mul i64 %push118202_append_capacity, 4
  br i1 %push118202_full, label %push118202_grow, label %push118202_keep

push118202_keep:                                  ; preds = %interpolation118197_array47_valid
  br label %push118202_ready

push118202_grow:                                  ; preds = %interpolation118197_array47_valid
  %push118202_grown_data = call ptr @malloc(i64 %push118202_append_bytes)
  %push118202_allocated = icmp ne ptr %push118202_grown_data, null
  br i1 %push118202_allocated, label %push118202_copy, label %push118202_allocation_failed

push118202_allocation_failed:                     ; preds = %push118202_grow
  call void @llvm.trap()
  unreachable

push118202_copy:                                  ; preds = %push118202_grow
  %push118202_copy_bytes = mul i64 %push118202_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118202_grown_data, ptr %push118202_data, i64 %push118202_copy_bytes, i1 false)
  call void @free(ptr %push118202_data)
  br label %push118202_ready

push118202_ready:                                 ; preds = %push118202_copy, %push118202_keep
  %push118202_append_data = phi ptr [ %push118202_data, %push118202_keep ], [ %push118202_grown_data, %push118202_copy ]
  %push118202_slot = getelementptr i32, ptr %push118202_append_data, i64 %push118202_length
  store i32 10, ptr %push118202_slot, align 4
  %push118202_new_length = add i64 %push118202_length, 1
  %push118202_array0 = insertvalue %sollang.array.i32 poison, ptr %push118202_append_data, 0
  %push118202_array1 = insertvalue %sollang.array.i32 %push118202_array0, i64 %push118202_new_length, 1
  %push118202_array2 = insertvalue %sollang.array.i32 %push118202_array1, i64 %push118202_append_capacity, 2
  store %sollang.array.i32 %push118202_array2, ptr %slot118179, align 8
  %v118206 = load %sollang.array.i32, ptr %slot118179, align 8
  %push118205_data = extractvalue %sollang.array.i32 %v118206, 0
  %push118205_length = extractvalue %sollang.array.i32 %v118206, 1
  %push118205_capacity = extractvalue %sollang.array.i32 %v118206, 2
  %push118205_full = icmp eq i64 %push118205_length, %push118205_capacity
  %push118205_empty = icmp eq i64 %push118205_capacity, 0
  %push118205_doubled = mul i64 %push118205_capacity, 2
  %push118205_grown_capacity = select i1 %push118205_empty, i64 4, i64 %push118205_doubled
  %push118205_append_capacity = select i1 %push118205_full, i64 %push118205_grown_capacity, i64 %push118205_capacity
  %push118205_append_bytes = mul i64 %push118205_append_capacity, 4
  br i1 %push118205_full, label %push118205_grow, label %push118205_keep

push118205_keep:                                  ; preds = %push118202_ready
  br label %push118205_ready

push118205_grow:                                  ; preds = %push118202_ready
  %push118205_grown_data = call ptr @malloc(i64 %push118205_append_bytes)
  %push118205_allocated = icmp ne ptr %push118205_grown_data, null
  br i1 %push118205_allocated, label %push118205_copy, label %push118205_allocation_failed

push118205_allocation_failed:                     ; preds = %push118205_grow
  call void @llvm.trap()
  unreachable

push118205_copy:                                  ; preds = %push118205_grow
  %push118205_copy_bytes = mul i64 %push118205_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118205_grown_data, ptr %push118205_data, i64 %push118205_copy_bytes, i1 false)
  call void @free(ptr %push118205_data)
  br label %push118205_ready

push118205_ready:                                 ; preds = %push118205_copy, %push118205_keep
  %push118205_append_data = phi ptr [ %push118205_data, %push118205_keep ], [ %push118205_grown_data, %push118205_copy ]
  %push118205_slot = getelementptr i32, ptr %push118205_append_data, i64 %push118205_length
  store i32 20, ptr %push118205_slot, align 4
  %push118205_new_length = add i64 %push118205_length, 1
  %push118205_array0 = insertvalue %sollang.array.i32 poison, ptr %push118205_append_data, 0
  %push118205_array1 = insertvalue %sollang.array.i32 %push118205_array0, i64 %push118205_new_length, 1
  %push118205_array2 = insertvalue %sollang.array.i32 %push118205_array1, i64 %push118205_append_capacity, 2
  store %sollang.array.i32 %push118205_array2, ptr %slot118179, align 8
  %v118208_expression_literal0 = getelementptr i8, ptr @sollang_str_118209, i64 0
  call void @sollang_runtime_print(ptr %v118208_expression_literal0, i64 0, i1 false)
  %v118208_expression55_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118208_expression54_raw = extractvalue %sollang.array.i32 %v118208_expression55_mutable, 1
  %v118208_expression54 = trunc i64 %v118208_expression54_raw to i32
  %v118208_expression54_print = zext i32 %v118208_expression54 to i64
  call void @sollang_runtime_print_i64(i64 %v118208_expression54_print, i1 false, i1 false)
  %v118208_expression_literal1 = getelementptr i8, ptr @sollang_str_118209, i64 12
  call void @sollang_runtime_print(ptr %v118208_expression_literal1, i64 1, i1 false)
  %v118208_expression57_mutable = load %sollang.array.i32, ptr %slot118179, align 8
  %v118208_expression56_data = extractvalue %sollang.array.i32 %v118208_expression57_mutable, 0
  %v118208_expression56_index = sext i32 1 to i64
  %v118208_expression56_length = extractvalue %sollang.array.i32 %v118208_expression57_mutable, 1
  %v118208_expression56_in_bounds = icmp ult i64 %v118208_expression56_index, %v118208_expression56_length
  br i1 %v118208_expression56_in_bounds, label %interpolation118208_array56_valid, label %interpolation118208_array56_invalid

interpolation118208_array56_invalid:              ; preds = %push118205_ready
  call void @llvm.trap()
  unreachable

interpolation118208_array56_valid:                ; preds = %push118205_ready
  %v118208_expression56_ptr = getelementptr i32, ptr %v118208_expression56_data, i64 %v118208_expression56_index
  %v118208_expression56 = load i32, ptr %v118208_expression56_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118208_expression56, i1 false)
  %v118208_expression_suffix = getelementptr i8, ptr @sollang_str_118209, i64 21
  call void @sollang_runtime_print(ptr %v118208_expression_suffix, i64 0, i1 true)
  %v118211 = load i32, ptr %slot118177, align 4
  %v118210 = add i32 %v118211, 1
  store i32 %v118210, ptr %slot118177, align 4
  %cleanup1181863_b118179_current = load %sollang.array.i32, ptr %slot118179, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181863_b118179_current)
  %cleanup1181863_b118178_current = load %sollang.array.i32, ptr %slot118178, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1181863_b118178_current)
  br label %while118186_header

while118186_exit:                                 ; preds = %while118186_header
  ret void
}

define i32 @main() {
entry:
  %v118249_data = alloca [12 x i8], align 4
  %v118256_owner = alloca %sollang.bounded_dictionary.t1216, align 8
  %callref118266_arg0 = alloca %sollang.struct.m144_s0, align 8
  %callref118269_arg0 = alloca %sollang.array.i32, align 8
  %slot118214 = alloca %sollang.array.i32, align 8
  %slot118215 = alloca %sollang.array.i32, align 8
  %v118224_data = inttoptr i64 0 to ptr
  %v118224_0 = insertvalue %sollang.array.i32 poison, ptr %v118224_data, 0
  %v118224_1 = insertvalue %sollang.array.i32 %v118224_0, i64 0, 1
  %v118224 = insertvalue %sollang.array.i32 %v118224_1, i64 0, 2
  %v118235_data = call ptr @malloc(i64 16)
  %v118235_0 = insertvalue %sollang.array.i32 poison, ptr %v118235_data, 0
  %v118235_1 = insertvalue %sollang.array.i32 %v118235_0, i64 0, 1
  %v118235 = insertvalue %sollang.array.i32 %v118235_1, i64 4, 2
  store %sollang.array.i32 %v118224, ptr %slot118214, align 8
  %v118225_expression_literal0 = getelementptr i8, ptr @sollang_str_118226, i64 0
  call void @sollang_runtime_print(ptr %v118225_expression_literal0, i64 0, i1 false)
  %v118225_expression60_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118225_expression59_raw = extractvalue %sollang.array.i32 %v118225_expression60_mutable, 1
  %v118225_expression59 = trunc i64 %v118225_expression59_raw to i32
  %v118225_expression59_print = zext i32 %v118225_expression59 to i64
  call void @sollang_runtime_print_i64(i64 %v118225_expression59_print, i1 false, i1 false)
  %v118225_expression_literal1 = getelementptr i8, ptr @sollang_str_118226, i64 12
  call void @sollang_runtime_print(ptr %v118225_expression_literal1, i64 1, i1 false)
  %v118225_expression62_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118225_expression61_raw = extractvalue %sollang.array.i32 %v118225_expression62_mutable, 2
  %v118225_expression61 = trunc i64 %v118225_expression61_raw to i32
  %v118225_expression61_print = zext i32 %v118225_expression61 to i64
  call void @sollang_runtime_print_i64(i64 %v118225_expression61_print, i1 false, i1 false)
  %v118225_expression_suffix = getelementptr i8, ptr @sollang_str_118226, i64 30
  call void @sollang_runtime_print(ptr %v118225_expression_suffix, i64 0, i1 true)
  %v118228 = load %sollang.array.i32, ptr %slot118214, align 8
  %push118227_data = extractvalue %sollang.array.i32 %v118228, 0
  %push118227_length = extractvalue %sollang.array.i32 %v118228, 1
  %push118227_capacity = extractvalue %sollang.array.i32 %v118228, 2
  %push118227_full = icmp eq i64 %push118227_length, %push118227_capacity
  %push118227_empty = icmp eq i64 %push118227_capacity, 0
  %push118227_doubled = mul i64 %push118227_capacity, 2
  %push118227_grown_capacity = select i1 %push118227_empty, i64 4, i64 %push118227_doubled
  %push118227_append_capacity = select i1 %push118227_full, i64 %push118227_grown_capacity, i64 %push118227_capacity
  %push118227_append_bytes = mul i64 %push118227_append_capacity, 4
  br i1 %push118227_full, label %push118227_grow, label %push118227_keep

push118227_keep:                                  ; preds = %entry
  br label %push118227_ready

push118227_grow:                                  ; preds = %entry
  %push118227_grown_data = call ptr @malloc(i64 %push118227_append_bytes)
  %push118227_allocated = icmp ne ptr %push118227_grown_data, null
  br i1 %push118227_allocated, label %push118227_copy, label %push118227_allocation_failed

push118227_allocation_failed:                     ; preds = %push118227_grow
  call void @llvm.trap()
  unreachable

push118227_copy:                                  ; preds = %push118227_grow
  %push118227_copy_bytes = mul i64 %push118227_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118227_grown_data, ptr %push118227_data, i64 %push118227_copy_bytes, i1 false)
  call void @free(ptr %push118227_data)
  br label %push118227_ready

push118227_ready:                                 ; preds = %push118227_copy, %push118227_keep
  %push118227_append_data = phi ptr [ %push118227_data, %push118227_keep ], [ %push118227_grown_data, %push118227_copy ]
  %push118227_slot = getelementptr i32, ptr %push118227_append_data, i64 %push118227_length
  store i32 10, ptr %push118227_slot, align 4
  %push118227_new_length = add i64 %push118227_length, 1
  %push118227_array0 = insertvalue %sollang.array.i32 poison, ptr %push118227_append_data, 0
  %push118227_array1 = insertvalue %sollang.array.i32 %push118227_array0, i64 %push118227_new_length, 1
  %push118227_array2 = insertvalue %sollang.array.i32 %push118227_array1, i64 %push118227_append_capacity, 2
  store %sollang.array.i32 %push118227_array2, ptr %slot118214, align 8
  %v118231 = load %sollang.array.i32, ptr %slot118214, align 8
  %push118230_data = extractvalue %sollang.array.i32 %v118231, 0
  %push118230_length = extractvalue %sollang.array.i32 %v118231, 1
  %push118230_capacity = extractvalue %sollang.array.i32 %v118231, 2
  %push118230_full = icmp eq i64 %push118230_length, %push118230_capacity
  %push118230_empty = icmp eq i64 %push118230_capacity, 0
  %push118230_doubled = mul i64 %push118230_capacity, 2
  %push118230_grown_capacity = select i1 %push118230_empty, i64 4, i64 %push118230_doubled
  %push118230_append_capacity = select i1 %push118230_full, i64 %push118230_grown_capacity, i64 %push118230_capacity
  %push118230_append_bytes = mul i64 %push118230_append_capacity, 4
  br i1 %push118230_full, label %push118230_grow, label %push118230_keep

push118230_keep:                                  ; preds = %push118227_ready
  br label %push118230_ready

push118230_grow:                                  ; preds = %push118227_ready
  %push118230_grown_data = call ptr @malloc(i64 %push118230_append_bytes)
  %push118230_allocated = icmp ne ptr %push118230_grown_data, null
  br i1 %push118230_allocated, label %push118230_copy, label %push118230_allocation_failed

push118230_allocation_failed:                     ; preds = %push118230_grow
  call void @llvm.trap()
  unreachable

push118230_copy:                                  ; preds = %push118230_grow
  %push118230_copy_bytes = mul i64 %push118230_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118230_grown_data, ptr %push118230_data, i64 %push118230_copy_bytes, i1 false)
  call void @free(ptr %push118230_data)
  br label %push118230_ready

push118230_ready:                                 ; preds = %push118230_copy, %push118230_keep
  %push118230_append_data = phi ptr [ %push118230_data, %push118230_keep ], [ %push118230_grown_data, %push118230_copy ]
  %push118230_slot = getelementptr i32, ptr %push118230_append_data, i64 %push118230_length
  store i32 20, ptr %push118230_slot, align 4
  %push118230_new_length = add i64 %push118230_length, 1
  %push118230_array0 = insertvalue %sollang.array.i32 poison, ptr %push118230_append_data, 0
  %push118230_array1 = insertvalue %sollang.array.i32 %push118230_array0, i64 %push118230_new_length, 1
  %push118230_array2 = insertvalue %sollang.array.i32 %push118230_array1, i64 %push118230_append_capacity, 2
  store %sollang.array.i32 %push118230_array2, ptr %slot118214, align 8
  %v118233_expression_literal0 = getelementptr i8, ptr @sollang_str_118234, i64 0
  call void @sollang_runtime_print(ptr %v118233_expression_literal0, i64 0, i1 false)
  %v118233_expression64_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118233_expression63_raw = extractvalue %sollang.array.i32 %v118233_expression64_mutable, 1
  %v118233_expression63 = trunc i64 %v118233_expression63_raw to i32
  %v118233_expression63_print = zext i32 %v118233_expression63 to i64
  call void @sollang_runtime_print_i64(i64 %v118233_expression63_print, i1 false, i1 false)
  %v118233_expression_literal1 = getelementptr i8, ptr @sollang_str_118234, i64 12
  call void @sollang_runtime_print(ptr %v118233_expression_literal1, i64 1, i1 false)
  %v118233_expression66_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118233_expression65_data = extractvalue %sollang.array.i32 %v118233_expression66_mutable, 0
  %v118233_expression65_index = sext i32 1 to i64
  %v118233_expression65_length = extractvalue %sollang.array.i32 %v118233_expression66_mutable, 1
  %v118233_expression65_in_bounds = icmp ult i64 %v118233_expression65_index, %v118233_expression65_length
  br i1 %v118233_expression65_in_bounds, label %interpolation118233_array65_valid, label %interpolation118233_array65_invalid

interpolation118233_array65_invalid:              ; preds = %push118230_ready
  call void @llvm.trap()
  unreachable

interpolation118233_array65_valid:                ; preds = %push118230_ready
  %v118233_expression65_ptr = getelementptr i32, ptr %v118233_expression65_data, i64 %v118233_expression65_index
  %v118233_expression65 = load i32, ptr %v118233_expression65_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118233_expression65, i1 false)
  %v118233_expression_suffix = getelementptr i8, ptr @sollang_str_118234, i64 21
  call void @sollang_runtime_print(ptr %v118233_expression_suffix, i64 0, i1 true)
  store %sollang.array.i32 %v118235, ptr %slot118215, align 8
  %v118236_expression_literal0 = getelementptr i8, ptr @sollang_str_118237, i64 0
  call void @sollang_runtime_print(ptr %v118236_expression_literal0, i64 0, i1 false)
  %v118236_expression69_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118236_expression68_raw = extractvalue %sollang.array.i32 %v118236_expression69_mutable, 1
  %v118236_expression68 = trunc i64 %v118236_expression68_raw to i32
  %v118236_expression68_print = zext i32 %v118236_expression68 to i64
  call void @sollang_runtime_print_i64(i64 %v118236_expression68_print, i1 false, i1 false)
  %v118236_expression_literal1 = getelementptr i8, ptr @sollang_str_118237, i64 12
  call void @sollang_runtime_print(ptr %v118236_expression_literal1, i64 1, i1 false)
  %v118236_expression71_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118236_expression70_raw = extractvalue %sollang.array.i32 %v118236_expression71_mutable, 2
  %v118236_expression70 = trunc i64 %v118236_expression70_raw to i32
  %v118236_expression70_print = zext i32 %v118236_expression70 to i64
  call void @sollang_runtime_print_i64(i64 %v118236_expression70_print, i1 false, i1 false)
  %v118236_expression_suffix = getelementptr i8, ptr @sollang_str_118237, i64 30
  call void @sollang_runtime_print(ptr %v118236_expression_suffix, i64 0, i1 true)
  %v118239 = load %sollang.array.i32, ptr %slot118215, align 8
  %push118238_data = extractvalue %sollang.array.i32 %v118239, 0
  %push118238_length = extractvalue %sollang.array.i32 %v118239, 1
  %push118238_capacity = extractvalue %sollang.array.i32 %v118239, 2
  %push118238_full = icmp eq i64 %push118238_length, %push118238_capacity
  %push118238_empty = icmp eq i64 %push118238_capacity, 0
  %push118238_doubled = mul i64 %push118238_capacity, 2
  %push118238_grown_capacity = select i1 %push118238_empty, i64 4, i64 %push118238_doubled
  %push118238_append_capacity = select i1 %push118238_full, i64 %push118238_grown_capacity, i64 %push118238_capacity
  %push118238_append_bytes = mul i64 %push118238_append_capacity, 4
  br i1 %push118238_full, label %push118238_grow, label %push118238_keep

push118238_keep:                                  ; preds = %interpolation118233_array65_valid
  br label %push118238_ready

push118238_grow:                                  ; preds = %interpolation118233_array65_valid
  %push118238_grown_data = call ptr @malloc(i64 %push118238_append_bytes)
  %push118238_allocated = icmp ne ptr %push118238_grown_data, null
  br i1 %push118238_allocated, label %push118238_copy, label %push118238_allocation_failed

push118238_allocation_failed:                     ; preds = %push118238_grow
  call void @llvm.trap()
  unreachable

push118238_copy:                                  ; preds = %push118238_grow
  %push118238_copy_bytes = mul i64 %push118238_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118238_grown_data, ptr %push118238_data, i64 %push118238_copy_bytes, i1 false)
  call void @free(ptr %push118238_data)
  br label %push118238_ready

push118238_ready:                                 ; preds = %push118238_copy, %push118238_keep
  %push118238_append_data = phi ptr [ %push118238_data, %push118238_keep ], [ %push118238_grown_data, %push118238_copy ]
  %push118238_slot = getelementptr i32, ptr %push118238_append_data, i64 %push118238_length
  store i32 10, ptr %push118238_slot, align 4
  %push118238_new_length = add i64 %push118238_length, 1
  %push118238_array0 = insertvalue %sollang.array.i32 poison, ptr %push118238_append_data, 0
  %push118238_array1 = insertvalue %sollang.array.i32 %push118238_array0, i64 %push118238_new_length, 1
  %push118238_array2 = insertvalue %sollang.array.i32 %push118238_array1, i64 %push118238_append_capacity, 2
  store %sollang.array.i32 %push118238_array2, ptr %slot118215, align 8
  %v118242 = load %sollang.array.i32, ptr %slot118215, align 8
  %push118241_data = extractvalue %sollang.array.i32 %v118242, 0
  %push118241_length = extractvalue %sollang.array.i32 %v118242, 1
  %push118241_capacity = extractvalue %sollang.array.i32 %v118242, 2
  %push118241_full = icmp eq i64 %push118241_length, %push118241_capacity
  %push118241_empty = icmp eq i64 %push118241_capacity, 0
  %push118241_doubled = mul i64 %push118241_capacity, 2
  %push118241_grown_capacity = select i1 %push118241_empty, i64 4, i64 %push118241_doubled
  %push118241_append_capacity = select i1 %push118241_full, i64 %push118241_grown_capacity, i64 %push118241_capacity
  %push118241_append_bytes = mul i64 %push118241_append_capacity, 4
  br i1 %push118241_full, label %push118241_grow, label %push118241_keep

push118241_keep:                                  ; preds = %push118238_ready
  br label %push118241_ready

push118241_grow:                                  ; preds = %push118238_ready
  %push118241_grown_data = call ptr @malloc(i64 %push118241_append_bytes)
  %push118241_allocated = icmp ne ptr %push118241_grown_data, null
  br i1 %push118241_allocated, label %push118241_copy, label %push118241_allocation_failed

push118241_allocation_failed:                     ; preds = %push118241_grow
  call void @llvm.trap()
  unreachable

push118241_copy:                                  ; preds = %push118241_grow
  %push118241_copy_bytes = mul i64 %push118241_length, 4
  call void @llvm.memcpy.p0.p0.i64(ptr %push118241_grown_data, ptr %push118241_data, i64 %push118241_copy_bytes, i1 false)
  call void @free(ptr %push118241_data)
  br label %push118241_ready

push118241_ready:                                 ; preds = %push118241_copy, %push118241_keep
  %push118241_append_data = phi ptr [ %push118241_data, %push118241_keep ], [ %push118241_grown_data, %push118241_copy ]
  %push118241_slot = getelementptr i32, ptr %push118241_append_data, i64 %push118241_length
  store i32 20, ptr %push118241_slot, align 4
  %push118241_new_length = add i64 %push118241_length, 1
  %push118241_array0 = insertvalue %sollang.array.i32 poison, ptr %push118241_append_data, 0
  %push118241_array1 = insertvalue %sollang.array.i32 %push118241_array0, i64 %push118241_new_length, 1
  %push118241_array2 = insertvalue %sollang.array.i32 %push118241_array1, i64 %push118241_append_capacity, 2
  store %sollang.array.i32 %push118241_array2, ptr %slot118215, align 8
  %v118244_expression_literal0 = getelementptr i8, ptr @sollang_str_118245, i64 0
  call void @sollang_runtime_print(ptr %v118244_expression_literal0, i64 0, i1 false)
  %v118244_expression73_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118244_expression72_raw = extractvalue %sollang.array.i32 %v118244_expression73_mutable, 1
  %v118244_expression72 = trunc i64 %v118244_expression72_raw to i32
  %v118244_expression72_print = zext i32 %v118244_expression72 to i64
  call void @sollang_runtime_print_i64(i64 %v118244_expression72_print, i1 false, i1 false)
  %v118244_expression_literal1 = getelementptr i8, ptr @sollang_str_118245, i64 12
  call void @sollang_runtime_print(ptr %v118244_expression_literal1, i64 1, i1 false)
  %v118244_expression75_mutable = load %sollang.array.i32, ptr %slot118215, align 8
  %v118244_expression74_data = extractvalue %sollang.array.i32 %v118244_expression75_mutable, 0
  %v118244_expression74_index = sext i32 1 to i64
  %v118244_expression74_length = extractvalue %sollang.array.i32 %v118244_expression75_mutable, 1
  %v118244_expression74_in_bounds = icmp ult i64 %v118244_expression74_index, %v118244_expression74_length
  br i1 %v118244_expression74_in_bounds, label %interpolation118244_array74_valid, label %interpolation118244_array74_invalid

interpolation118244_array74_invalid:              ; preds = %push118241_ready
  call void @llvm.trap()
  unreachable

interpolation118244_array74_valid:                ; preds = %push118241_ready
  %v118244_expression74_ptr = getelementptr i32, ptr %v118244_expression74_data, i64 %v118244_expression74_index
  %v118244_expression74 = load i32, ptr %v118244_expression74_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118244_expression74, i1 false)
  %v118244_expression_suffix = getelementptr i8, ptr @sollang_str_118245, i64 21
  call void @sollang_runtime_print(ptr %v118244_expression_suffix, i64 0, i1 true)
  call void @sollang_m144_s5()
  call void @sollang_m144_s8()
  call void @sollang_m144_s11()
  %v118249_ptr0 = getelementptr i32, ptr %v118249_data, i64 0
  store i32 7, ptr %v118249_ptr0, align 4
  %v118249_ptr1 = getelementptr i32, ptr %v118249_data, i64 1
  store i32 7, ptr %v118249_ptr1, align 4
  %v118249_ptr2 = getelementptr i32, ptr %v118249_data, i64 2
  store i32 7, ptr %v118249_ptr2, align 4
  %v118249_0 = insertvalue { ptr, i64 } poison, ptr %v118249_data, 0
  %v118249 = insertvalue { ptr, i64 } %v118249_0, i64 3, 1
  %v118251_expression_literal0 = getelementptr i8, ptr @sollang_str_118252, i64 0
  call void @sollang_runtime_print(ptr %v118251_expression_literal0, i64 0, i1 false)
  %v118251_expression77_raw = add i64 0, 3
  %v118251_expression77 = trunc i64 %v118251_expression77_raw to i32
  %v118251_expression77_print = zext i32 %v118251_expression77 to i64
  call void @sollang_runtime_print_i64(i64 %v118251_expression77_print, i1 false, i1 false)
  %v118251_expression_literal1 = getelementptr i8, ptr @sollang_str_118252, i64 18
  call void @sollang_runtime_print(ptr %v118251_expression_literal1, i64 1, i1 false)
  %v118251_expression79_data = extractvalue { ptr, i64 } %v118249, 0
  %v118251_expression79_index = sext i32 2 to i64
  %v118251_expression79_length = extractvalue { ptr, i64 } %v118249, 1
  %v118251_expression79_in_bounds = icmp ult i64 %v118251_expression79_index, %v118251_expression79_length
  br i1 %v118251_expression79_in_bounds, label %interpolation118251_array79_valid, label %interpolation118251_array79_invalid

interpolation118251_array79_invalid:              ; preds = %interpolation118244_array74_valid
  call void @llvm.trap()
  unreachable

interpolation118251_array79_valid:                ; preds = %interpolation118244_array74_valid
  %v118251_expression79_ptr = getelementptr i32, ptr %v118251_expression79_data, i64 %v118251_expression79_index
  %v118251_expression79 = load i32, ptr %v118251_expression79_ptr, align 4
  call void @sollang_runtime_print_i32(i32 %v118251_expression79, i1 false)
  %v118251_expression_suffix = getelementptr i8, ptr @sollang_str_118252, i64 33
  call void @sollang_runtime_print(ptr %v118251_expression_suffix, i64 0, i1 true)
  %v118253_data = alloca [16 x i8], align 4
  %v118253_0 = insertvalue %sollang.array.i32 poison, ptr %v118253_data, 0
  %v118253_1 = insertvalue %sollang.array.i32 %v118253_0, i64 0, 1
  %v118253 = insertvalue %sollang.array.i32 %v118253_1, i64 4, 2
  %v118254_expression_literal0 = getelementptr i8, ptr @sollang_str_118255, i64 0
  call void @sollang_runtime_print(ptr %v118254_expression_literal0, i64 8, i1 false)
  %v118254_expression82_raw = extractvalue %sollang.array.i32 %v118253, 2
  %v118254_expression82 = trunc i64 %v118254_expression82_raw to i32
  %v118254_expression82_print = zext i32 %v118254_expression82 to i64
  call void @sollang_runtime_print_i64(i64 %v118254_expression82_print, i1 false, i1 false)
  %v118254_expression_suffix = getelementptr i8, ptr @sollang_str_118255, i64 30
  call void @sollang_runtime_print(ptr %v118254_expression_suffix, i64 0, i1 true)
  store %sollang.bounded_dictionary.t1216 zeroinitializer, ptr %v118256_owner, align 8
  %v118256 = load %sollang.bounded_dictionary.t1216, ptr %v118256_owner, align 8
  %v118257_expression_literal0 = getelementptr i8, ptr @sollang_str_118258, i64 0
  call void @sollang_runtime_print(ptr %v118257_expression_literal0, i64 19, i1 false)
  %v118257_expression84_raw = add i64 0, 4
  %v118257_expression84 = trunc i64 %v118257_expression84_raw to i32
  %v118257_expression84_print = zext i32 %v118257_expression84 to i64
  call void @sollang_runtime_print_i64(i64 %v118257_expression84_print, i1 false, i1 false)
  %v118257_expression_suffix = getelementptr i8, ptr @sollang_str_118258, i64 51
  call void @sollang_runtime_print(ptr %v118257_expression_suffix, i64 0, i1 true)
  %v118259_allocation_mirror = add i64 8, 23
  %v118259_allocation_offset = and i64 %v118259_allocation_mirror, -8
  %v118259_entry_bytes = mul i64 8, 8
  %v118259_allocation_bytes = add i64 %v118259_allocation_offset, %v118259_entry_bytes
  %v118259_storage = call ptr @malloc(i64 %v118259_allocation_bytes)
  %v118259_allocated = icmp ne ptr %v118259_storage, null
  br i1 %v118259_allocated, label %v118259_allocation_ready, label %v118259_allocation_failed

v118259_allocation_failed:                        ; preds = %interpolation118251_array79_valid
  call void @llvm.trap()
  unreachable

v118259_allocation_ready:                         ; preds = %interpolation118251_array79_valid
  %v118259_controls = getelementptr i8, ptr %v118259_storage, i64 0
  %v118259_control_bytes = add i64 8, 16
  call void @llvm.memset.p0.i64(ptr %v118259_controls, i8 0, i64 %v118259_control_bytes, i1 false)
  %v118259_0 = insertvalue %sollang.dict poison, ptr %v118259_storage, 0
  %v118259_1 = insertvalue %sollang.dict %v118259_0, i64 0, 1
  %v118259 = insertvalue %sollang.dict %v118259_1, i64 8, 2
  %v118261 = freeze %sollang.dict %v118259
  %v118260_raw = extractvalue %sollang.dict %v118261, 2
  %v118260_capacity_fits = icmp ule i64 %v118260_raw, 2147483647
  br i1 %v118260_capacity_fits, label %v118260_capacity_ok, label %v118260_capacity_fail

v118260_capacity_fail:                            ; preds = %v118259_allocation_ready
  call void @llvm.trap()
  unreachable

v118260_capacity_ok:                              ; preds = %v118259_allocation_ready
  %v118260 = trunc i64 %v118260_raw to i32
  %v118262_expression_literal0 = getelementptr i8, ptr @sollang_str_118263, i64 0
  call void @sollang_runtime_print(ptr %v118262_expression_literal0, i64 11, i1 false)
  %v118262_expression87_raw = extractvalue %sollang.dict %v118259, 2
  %v118262_expression87 = trunc i64 %v118262_expression87_raw to i32
  %v118262_expression86 = icmp eq i32 %v118262_expression87, %v118260
  call void @sollang_runtime_print_i1(i1 %v118262_expression86, i1 false)
  %v118262_expression_suffix = getelementptr i8, ptr @sollang_str_118263, i64 58
  call void @sollang_runtime_print(ptr %v118262_expression_suffix, i64 0, i1 true)
  %v118265_data = call ptr @malloc(i64 16)
  %v118265_0 = insertvalue %sollang.array.i32 poison, ptr %v118265_data, 0
  %v118265_1 = insertvalue %sollang.array.i32 %v118265_0, i64 0, 1
  %v118265 = insertvalue %sollang.array.i32 %v118265_1, i64 4, 2
  %v118264 = insertvalue %sollang.struct.m144_s0 poison, %sollang.array.i32 %v118265, 0
  %v118267 = freeze %sollang.struct.m144_s0 %v118264
  store %sollang.struct.m144_s0 %v118267, ptr %callref118266_arg0, align 8
  %callref118266_arg0_address = getelementptr i8, ptr %callref118266_arg0, i64 0
  call void @sollang_m144_s2(ptr %callref118266_arg0_address)
  %v118268_data = call ptr @malloc(i64 16)
  %v118268_0 = insertvalue %sollang.array.i32 poison, ptr %v118268_data, 0
  %v118268_1 = insertvalue %sollang.array.i32 %v118268_0, i64 0, 1
  %v118268 = insertvalue %sollang.array.i32 %v118268_1, i64 4, 2
  %v118270 = freeze %sollang.array.i32 %v118268
  store %sollang.array.i32 %v118270, ptr %callref118269_arg0, align 8
  %callref118269_arg0_address = getelementptr i8, ptr %callref118269_arg0, i64 0
  call void @sollang_m144_s3(ptr %callref118269_arg0_address)
  %v118271_capacity_i64 = add i64 0, 4
  %v118271_capacity_positive = icmp ugt i64 %v118271_capacity_i64, 0
  %v118271_allocation = select i1 %v118271_capacity_positive, i64 %v118271_capacity_i64, i64 1
  %v118271_capacity_valid = icmp sge i64 %v118271_capacity_i64, 0
  %v118271_data = call ptr @sollang_raw_arena_create(i64 %v118271_allocation, i1 %v118271_capacity_valid)
  %v118271_0 = insertvalue %sollang.array.i32 poison, ptr %v118271_data, 0
  %v118271_1 = insertvalue %sollang.array.i32 %v118271_0, i64 0, 1
  %v118271 = insertvalue %sollang.array.i32 %v118271_1, i64 %v118271_allocation, 2
  %v118274 = freeze %sollang.array.i32 %v118271
  %v118279 = extractvalue %sollang.array.i32 %v118274, 2
  call void @sollang_runtime_print_i64(i64 %v118279, i1 false, i1 true)
  %v118275_expression_literal0 = getelementptr i8, ptr @sollang_str_118276, i64 0
  call void @sollang_runtime_print(ptr %v118275_expression_literal0, i64 6, i1 false)
  %v118275_expression90 = extractvalue %sollang.array.i32 %v118271, 2
  call void @sollang_runtime_print_i64(i64 %v118275_expression90, i1 false, i1 false)
  %v118275_expression_suffix = getelementptr i8, ptr @sollang_str_118276, i64 27
  call void @sollang_runtime_print(ptr %v118275_expression_suffix, i64 0, i1 true)
  %v118277_expression_literal0 = getelementptr i8, ptr @sollang_str_118278, i64 0
  call void @sollang_runtime_print(ptr %v118277_expression_literal0, i64 0, i1 false)
  %v118277_expression92 = call i32 @sollang_m144_s4(i32 10)
  call void @sollang_runtime_print_i32(i32 %v118277_expression92, i1 false)
  %v118277_expression_literal1 = getelementptr i8, ptr @sollang_str_118278, i64 13
  call void @sollang_runtime_print(ptr %v118277_expression_literal1, i64 1, i1 false)
  %v118277_expression95_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118277_expression94_raw = extractvalue %sollang.array.i32 %v118277_expression95_mutable, 2
  %v118277_expression94 = trunc i64 %v118277_expression94_raw to i32
  %v118277_expression94_print = zext i32 %v118277_expression94 to i64
  call void @sollang_runtime_print_i64(i64 %v118277_expression94_print, i1 false, i1 false)
  %v118277_expression_literal2 = getelementptr i8, ptr @sollang_str_118278, i64 31
  call void @sollang_runtime_print(ptr %v118277_expression_literal2, i64 1, i1 false)
  %v118277_expression96 = call i32 @sollang_m144_s4(i32 20)
  call void @sollang_runtime_print_i32(i32 %v118277_expression96, i1 false)
  %v118277_expression_literal3 = getelementptr i8, ptr @sollang_str_118278, i64 45
  call void @sollang_runtime_print(ptr %v118277_expression_literal3, i64 1, i1 false)
  %v118277_expression99_mutable = load %sollang.array.i32, ptr %slot118214, align 8
  %v118277_expression98_raw = extractvalue %sollang.array.i32 %v118277_expression99_mutable, 1
  %v118277_expression98 = trunc i64 %v118277_expression98_raw to i32
  %v118277_expression98_print = zext i32 %v118277_expression98 to i64
  call void @sollang_runtime_print_i64(i64 %v118277_expression98_print, i1 false, i1 false)
  %v118277_expression_suffix = getelementptr i8, ptr @sollang_str_118278, i64 58
  call void @sollang_runtime_print(ptr %v118277_expression_suffix, i64 0, i1 true)
  call void @sollang_drop_t188(%sollang.array.i32 %v118268)
  call void @sollang_drop_t1212(%sollang.struct.m144_s0 %v118264)
  call void @sollang_drop_t1217(%sollang.dict %v118259)
  call void @sollang_drop_t1216(%sollang.bounded_dictionary.t1216 %v118256)
  call void @sollang_drop_t1215(%sollang.array.i32 %v118253)
  %cleanup1182136_b118215_current = load %sollang.array.i32, ptr %slot118215, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182136_b118215_current)
  %cleanup1182136_b118214_current = load %sollang.array.i32, ptr %slot118214, align 8
  call void @sollang_drop_t188(%sollang.array.i32 %cleanup1182136_b118214_current)
  call void @sollang_runtime_flush_stdout()
  ret i32 0
}

define internal ptr @sollang_process_copy_text(ptr %data, i64 %length) {
entry:
  %capacity = add i64 %length, 1
  %copy = call ptr @malloc(i64 %capacity)
  %allocated = icmp ne ptr %copy, null
  br i1 %allocated, label %loop, label %fail

loop:                                             ; preds = %body, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %body ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %terminate, label %body

body:                                             ; preds = %loop
  %source = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %source, align 1
  %destination = getelementptr i8, ptr %copy, i64 %index
  store i8 %byte, ptr %destination, align 1
  %next = add i64 %index, 1
  br label %loop

terminate:                                        ; preds = %loop
  %null_slot = getelementptr i8, ptr %copy, i64 %length
  store i8 0, ptr %null_slot, align 1
  ret ptr %copy

fail:                                             ; preds = %entry
  ret ptr null
}

define internal void @sollang_process_dispose_argv(ptr %argv, i64 %count) {
entry:
  br label %loop

loop:                                             ; preds = %body, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %body ]
  %done = icmp eq i64 %index, %count
  br i1 %done, label %finish, label %body

body:                                             ; preds = %loop
  %slot = getelementptr ptr, ptr %argv, i64 %index
  %value = load ptr, ptr %slot, align 8
  call void @free(ptr %value)
  %next = add i64 %index, 1
  br label %loop

finish:                                           ; preds = %loop
  call void @free(ptr %argv)
  ret void
}

define internal ptr @sollang_process_build_argv(ptr %records, i64 %count) {
entry:
  %slots = add i64 %count, 1
  %bytes = mul i64 %slots, 8
  %argv = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %argv, null
  br i1 %allocated, label %loop, label %fail

loop:                                             ; preds = %stored, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %stored ]
  %done = icmp eq i64 %index, %count
  br i1 %done, label %terminate, label %copy

copy:                                             ; preds = %loop
  %record = getelementptr %sollang.text, ptr %records, i64 %index
  %data_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  %data = load ptr, ptr %data_slot, align 8
  %length_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 1
  %length = load i64, ptr %length_slot, align 8
  %value = call ptr @sollang_process_copy_text(ptr %data, i64 %length)
  %copied = icmp ne ptr %value, null
  br i1 %copied, label %stored, label %cleanup

stored:                                           ; preds = %copy
  %slot = getelementptr ptr, ptr %argv, i64 %index
  store ptr %value, ptr %slot, align 8
  %next = add i64 %index, 1
  br label %loop

cleanup:                                          ; preds = %copy
  call void @sollang_process_dispose_argv(ptr %argv, i64 %index)
  ret ptr null

terminate:                                        ; preds = %loop
  %null_slot = getelementptr ptr, ptr %argv, i64 %count
  store ptr null, ptr %null_slot, align 8
  ret ptr %argv

fail:                                             ; preds = %entry
  ret ptr null
}

declare i64 @_get_osfhandle(i32)

define internal ptr @sollang_process_quote_windows_arg(ptr %source, i32 %chars) {
entry:
  %chars64 = zext i32 %chars to i64
  %double = mul i64 %chars64, 2
  %capacity = add i64 %double, 3
  %bytes = mul i64 %capacity, 2
  %output = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %output, null
  br i1 %allocated, label %initialize, label %fail

initialize:                                       ; preds = %entry
  store i16 34, ptr %output, align 2
  %index_slot = alloca i32, align 4
  %output_slot = alloca i64, align 8
  %slashes_slot = alloca i64, align 8
  store i32 0, ptr %index_slot, align 4
  store i64 1, ptr %output_slot, align 8
  store i64 0, ptr %slashes_slot, align 8
  br label %loop

loop:                                             ; preds = %write_character, %remember_slash, %initialize
  %index = load i32, ptr %index_slot, align 4
  %done = icmp eq i32 %index, %chars
  br i1 %done, label %finish_prepare, label %read

read:                                             ; preds = %loop
  %character_ptr = getelementptr i16, ptr %source, i32 %index
  %character = load i16, ptr %character_ptr, align 2
  %is_slash = icmp eq i16 %character, 92
  br i1 %is_slash, label %remember_slash, label %flush_prepare

remember_slash:                                   ; preds = %read
  %slashes = load i64, ptr %slashes_slot, align 8
  %more_slashes = add i64 %slashes, 1
  store i64 %more_slashes, ptr %slashes_slot, align 8
  %slash_next = add i32 %index, 1
  store i32 %slash_next, ptr %index_slot, align 4
  br label %loop

flush_prepare:                                    ; preds = %read
  %pending = load i64, ptr %slashes_slot, align 8
  %is_quote = icmp eq i16 %character, 34
  %doubled = mul i64 %pending, 2
  %escaped = add i64 %doubled, 1
  %flush_count = select i1 %is_quote, i64 %escaped, i64 %pending
  br label %flush_loop

flush_loop:                                       ; preds = %flush_body, %flush_prepare
  %flush_index = phi i64 [ 0, %flush_prepare ], [ %flush_next, %flush_body ]
  %flush_done = icmp eq i64 %flush_index, %flush_count
  br i1 %flush_done, label %write_character, label %flush_body

flush_body:                                       ; preds = %flush_loop
  %flush_output = load i64, ptr %output_slot, align 8
  %flush_ptr = getelementptr i16, ptr %output, i64 %flush_output
  store i16 92, ptr %flush_ptr, align 2
  %flush_output_next = add i64 %flush_output, 1
  store i64 %flush_output_next, ptr %output_slot, align 8
  %flush_next = add i64 %flush_index, 1
  br label %flush_loop

write_character:                                  ; preds = %flush_loop
  %output_index = load i64, ptr %output_slot, align 8
  %output_ptr = getelementptr i16, ptr %output, i64 %output_index
  store i16 %character, ptr %output_ptr, align 2
  %output_next = add i64 %output_index, 1
  store i64 %output_next, ptr %output_slot, align 8
  store i64 0, ptr %slashes_slot, align 8
  %index_next = add i32 %index, 1
  store i32 %index_next, ptr %index_slot, align 4
  br label %loop

finish_prepare:                                   ; preds = %loop
  %trailing = load i64, ptr %slashes_slot, align 8
  %finish_count = mul i64 %trailing, 2
  br label %finish_loop

finish_loop:                                      ; preds = %finish_body, %finish_prepare
  %finish_index = phi i64 [ 0, %finish_prepare ], [ %finish_next, %finish_body ]
  %finish_done = icmp eq i64 %finish_index, %finish_count
  br i1 %finish_done, label %close_quote, label %finish_body

finish_body:                                      ; preds = %finish_loop
  %finish_output = load i64, ptr %output_slot, align 8
  %finish_ptr = getelementptr i16, ptr %output, i64 %finish_output
  store i16 92, ptr %finish_ptr, align 2
  %finish_output_next = add i64 %finish_output, 1
  store i64 %finish_output_next, ptr %output_slot, align 8
  %finish_next = add i64 %finish_index, 1
  br label %finish_loop

close_quote:                                      ; preds = %finish_loop
  %close_index = load i64, ptr %output_slot, align 8
  %quote_ptr = getelementptr i16, ptr %output, i64 %close_index
  store i16 34, ptr %quote_ptr, align 2
  %null_index = add i64 %close_index, 1
  %null_ptr = getelementptr i16, ptr %output, i64 %null_index
  store i16 0, ptr %null_ptr, align 2
  ret ptr %output

fail:                                             ; preds = %entry
  ret ptr null
}

define internal ptr @sollang_process_build_windows_argv(ptr %records, i64 %count, ptr %program_slot) {
entry:
  store ptr null, ptr %program_slot, align 8
  %slots = add i64 %count, 1
  %argv_bytes = mul i64 %slots, 8
  %argv = call ptr @malloc(i64 %argv_bytes)
  %allocated = icmp ne ptr %argv, null
  br i1 %allocated, label %loop, label %fail

loop:                                             ; preds = %store, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %store ]
  %done = icmp eq i64 %index, %count
  br i1 %done, label %terminate, label %measure

measure:                                          ; preds = %loop
  %record = getelementptr %sollang.text, ptr %records, i64 %index
  %data_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  %data = load ptr, ptr %data_slot, align 8
  %length_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 1
  %length64 = load i64, ptr %length_slot, align 8
  %length_fits = icmp ule i64 %length64, 2147483647
  br i1 %length_fits, label %convert_size, label %cleanup

convert_size:                                     ; preds = %measure
  %length = trunc i64 %length64 to i32
  %chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr null, i32 0)
  %chars_valid = icmp sgt i32 %chars, 0
  %empty = icmp eq i32 %length, 0
  %valid = or i1 %chars_valid, %empty
  br i1 %valid, label %allocate_wide, label %cleanup

allocate_wide:                                    ; preds = %convert_size
  %chars_with_null = add i32 %chars, 1
  %chars_with_null64 = zext i32 %chars_with_null to i64
  %wide_bytes = mul i64 %chars_with_null64, 2
  %wide = call ptr @malloc(i64 %wide_bytes)
  %wide_ok = icmp ne ptr %wide, null
  br i1 %wide_ok, label %convert, label %cleanup

convert:                                          ; preds = %allocate_wide
  %written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr %wide, i32 %chars)
  %converted = icmp eq i32 %written, %chars
  br i1 %converted, label %terminate_wide, label %free_wide_error

terminate_wide:                                   ; preds = %convert
  %wide_end = getelementptr i16, ptr %wide, i32 %chars
  store i16 0, ptr %wide_end, align 2
  %quoted = call ptr @sollang_process_quote_windows_arg(ptr %wide, i32 %chars)
  %quoted_ok = icmp ne ptr %quoted, null
  br i1 %quoted_ok, label %preserve_program, label %free_wide_error

preserve_program:                                 ; preds = %terminate_wide
  %is_program = icmp eq i64 %index, 0
  br i1 %is_program, label %store_program, label %free_unquoted

store_program:                                    ; preds = %preserve_program
  store ptr %wide, ptr %program_slot, align 8
  br label %store

free_unquoted:                                    ; preds = %preserve_program
  call void @free(ptr %wide)
  br label %store

store:                                            ; preds = %free_unquoted, %store_program
  %slot = getelementptr ptr, ptr %argv, i64 %index
  store ptr %quoted, ptr %slot, align 8
  %next = add i64 %index, 1
  br label %loop

free_wide_error:                                  ; preds = %terminate_wide, %convert
  call void @free(ptr %wide)
  br label %cleanup

cleanup:                                          ; preds = %free_wide_error, %allocate_wide, %convert_size, %measure
  %failed_program = load ptr, ptr %program_slot, align 8
  call void @free(ptr %failed_program)
  store ptr null, ptr %program_slot, align 8
  call void @sollang_process_dispose_argv(ptr %argv, i64 %index)
  ret ptr null

terminate:                                        ; preds = %loop
  %null_slot = getelementptr ptr, ptr %argv, i64 %count
  store ptr null, ptr %null_slot, align 8
  ret ptr %argv

fail:                                             ; preds = %entry
  ret ptr null
}

define internal ptr @sollang_process_windows_text(ptr %data, i64 %length64) {
entry:
  %length_fits = icmp ule i64 %length64, 2147483647
  br i1 %length_fits, label %measure, label %fail

measure:                                          ; preds = %entry
  %length = trunc i64 %length64 to i32
  %chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr null, i32 0)
  %chars_valid = icmp sgt i32 %chars, 0
  %empty = icmp eq i32 %length, 0
  %valid = or i1 %chars_valid, %empty
  br i1 %valid, label %allocate, label %fail

allocate:                                         ; preds = %measure
  %with_null = add i32 %chars, 1
  %with_null64 = zext i32 %with_null to i64
  %bytes = mul i64 %with_null64, 2
  %wide = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %wide, null
  br i1 %allocated, label %convert, label %fail

convert:                                          ; preds = %allocate
  %written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr %wide, i32 %chars)
  %converted = icmp eq i32 %written, %chars
  br i1 %converted, label %terminate, label %free_fail

terminate:                                        ; preds = %convert
  %end = getelementptr i16, ptr %wide, i32 %chars
  store i16 0, ptr %end, align 2
  ret ptr %wide

free_fail:                                        ; preds = %convert
  call void @free(ptr %wide)
  br label %fail

fail:                                             ; preds = %free_fail, %allocate, %measure, %entry
  ret ptr null
}

define internal ptr @sollang_process_windows_path(ptr %data, i64 %length) {
entry:
  %present = icmp ugt i64 %length, 0
  br i1 %present, label %check, label %fail

check:                                            ; preds = %advance, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %convert, label %inspect

inspect:                                          ; preds = %check
  %byte_ptr = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %fail, label %advance

advance:                                          ; preds = %inspect
  %next = add i64 %index, 1
  br label %check

convert:                                          ; preds = %check
  %wide = call ptr @sollang_process_windows_text(ptr %data, i64 %length)
  ret ptr %wide

fail:                                             ; preds = %inspect, %entry
  ret ptr null
}

define internal ptr @sollang_process_join_windows_args(ptr %argv, i64 %count) {
entry:
  %index_slot = alloca i64, align 8
  %offset_slot = alloca i64, align 8
  store i64 0, ptr %index_slot, align 8
  store i64 0, ptr %offset_slot, align 8
  br label %measure_outer

measure_outer:                                    ; preds = %measure_argument_done, %entry
  %index = load i64, ptr %index_slot, align 8
  %outer_done = icmp eq i64 %index, %count
  br i1 %outer_done, label %allocate, label %measure_inner

measure_inner:                                    ; preds = %measure_more, %measure_outer
  %character_index = phi i64 [ 0, %measure_outer ], [ %character_next, %measure_more ]
  %argument_slot = getelementptr ptr, ptr %argv, i64 %index
  %argument = load ptr, ptr %argument_slot, align 8
  %character_ptr = getelementptr i16, ptr %argument, i64 %character_index
  %character = load i16, ptr %character_ptr, align 2
  %argument_done = icmp eq i16 %character, 0
  br i1 %argument_done, label %measure_argument_done, label %measure_more

measure_more:                                     ; preds = %measure_inner
  %character_next = add i64 %character_index, 1
  br label %measure_inner

measure_argument_done:                            ; preds = %measure_inner
  %offset = load i64, ptr %offset_slot, align 8
  %needs_space = icmp ne i64 %index, 0
  %space = zext i1 %needs_space to i64
  %with_argument = add i64 %offset, %character_index
  %next_offset = add i64 %with_argument, %space
  store i64 %next_offset, ptr %offset_slot, align 8
  %next_index = add i64 %index, 1
  store i64 %next_index, ptr %index_slot, align 8
  br label %measure_outer

allocate:                                         ; preds = %measure_outer
  %total = load i64, ptr %offset_slot, align 8
  %with_null = add i64 %total, 1
  %bytes = mul i64 %with_null, 2
  %command = call ptr @malloc(i64 %bytes)
  %allocated = icmp ne ptr %command, null
  br i1 %allocated, label %copy_setup, label %fail

copy_setup:                                       ; preds = %allocate
  store i64 0, ptr %index_slot, align 8
  store i64 0, ptr %offset_slot, align 8
  br label %copy_outer

copy_outer:                                       ; preds = %copy_argument_finish, %copy_setup
  %copy_index = load i64, ptr %index_slot, align 8
  %copy_done = icmp eq i64 %copy_index, %count
  br i1 %copy_done, label %terminate, label %copy_space

copy_space:                                       ; preds = %copy_outer
  %copy_offset = load i64, ptr %offset_slot, align 8
  %copy_needs_space = icmp ne i64 %copy_index, 0
  br i1 %copy_needs_space, label %store_space, label %copy_inner

store_space:                                      ; preds = %copy_space
  %space_ptr = getelementptr i16, ptr %command, i64 %copy_offset
  store i16 32, ptr %space_ptr, align 2
  %after_space = add i64 %copy_offset, 1
  store i64 %after_space, ptr %offset_slot, align 8
  br label %copy_inner

copy_inner:                                       ; preds = %copy_more, %store_space, %copy_space
  %copy_character_index = phi i64 [ 0, %copy_space ], [ 0, %store_space ], [ %copy_character_next, %copy_more ]
  %copy_argument_slot = getelementptr ptr, ptr %argv, i64 %copy_index
  %copy_argument = load ptr, ptr %copy_argument_slot, align 8
  %copy_character_ptr = getelementptr i16, ptr %copy_argument, i64 %copy_character_index
  %copy_character = load i16, ptr %copy_character_ptr, align 2
  %copy_argument_done = icmp eq i16 %copy_character, 0
  br i1 %copy_argument_done, label %copy_argument_finish, label %copy_more

copy_more:                                        ; preds = %copy_inner
  %current_offset = load i64, ptr %offset_slot, align 8
  %destination = getelementptr i16, ptr %command, i64 %current_offset
  store i16 %copy_character, ptr %destination, align 2
  %destination_next = add i64 %current_offset, 1
  store i64 %destination_next, ptr %offset_slot, align 8
  %copy_character_next = add i64 %copy_character_index, 1
  br label %copy_inner

copy_argument_finish:                             ; preds = %copy_inner
  %copy_index_next = add i64 %copy_index, 1
  store i64 %copy_index_next, ptr %index_slot, align 8
  br label %copy_outer

terminate:                                        ; preds = %copy_outer
  %final_offset = load i64, ptr %offset_slot, align 8
  %null_ptr = getelementptr i16, ptr %command, i64 %final_offset
  store i16 0, ptr %null_ptr, align 2
  ret ptr %command

fail:                                             ; preds = %allocate
  ret ptr null
}

define internal i64 @sollang_windows_wide_length(ptr %text) {
entry:
  br label %loop

loop:                                             ; preds = %more, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %more ]
  %at = getelementptr i16, ptr %text, i64 %index
  %character = load i16, ptr %at, align 2
  %done = icmp eq i16 %character, 0
  br i1 %done, label %result, label %more

more:                                             ; preds = %loop
  %next = add i64 %index, 1
  br label %loop

result:                                           ; preds = %loop
  ret i64 %index
}

define internal i64 @sollang_windows_environment_name_length(ptr %entry) {
entry_block:
  %first = load i16, ptr %entry, align 2
  %hidden = icmp eq i16 %first, 61
  %start = select i1 %hidden, i64 1, i64 0
  br label %loop

loop:                                             ; preds = %more, %entry_block
  %index = phi i64 [ %start, %entry_block ], [ %next, %more ]
  %at = getelementptr i16, ptr %entry, i64 %index
  %character = load i16, ptr %at, align 2
  %separator = icmp eq i16 %character, 61
  %end = icmp eq i16 %character, 0
  %done = or i1 %separator, %end
  br i1 %done, label %result, label %more

more:                                             ; preds = %loop
  %next = add i64 %index, 1
  br label %loop

result:                                           ; preds = %loop
  ret i64 %index
}

define internal i1 @sollang_windows_environment_text_valid(ptr %data, i64 %length, i1 %name) {
entry:
  br label %loop

loop:                                             ; preds = %more, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %more ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %valid, label %inspect

inspect:                                          ; preds = %loop
  %at = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %at, align 1
  %nul = icmp eq i8 %byte, 0
  %equal = icmp eq i8 %byte, 61
  %name_equal = and i1 %name, %equal
  %invalid = or i1 %nul, %name_equal
  br i1 %invalid, label %failure, label %more

more:                                             ; preds = %inspect
  %next = add i64 %index, 1
  br label %loop

valid:                                            ; preds = %loop
  ret i1 true

failure:                                          ; preds = %inspect
  ret i1 false
}

define internal i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %count, ptr %name, i64 %name_length) {
entry:
  %name_fits = icmp ule i64 %name_length, 2147483647
  br i1 %name_fits, label %loop, label %missing

loop:                                             ; preds = %different, %entry
  %remaining = phi i64 [ %count, %entry ], [ %index, %different ]
  %done = icmp eq i64 %remaining, 0
  br i1 %done, label %missing, label %inspect

inspect:                                          ; preds = %loop
  %index = sub i64 %remaining, 1
  %entry_slot = getelementptr ptr, ptr %entries, i64 %index
  %candidate = load ptr, ptr %entry_slot, align 8
  %length_slot = getelementptr i64, ptr %name_lengths, i64 %index
  %candidate_length64 = load i64, ptr %length_slot, align 8
  %candidate_fits = icmp ule i64 %candidate_length64, 2147483647
  br i1 %candidate_fits, label %compare, label %different

compare:                                          ; preds = %inspect
  %candidate_length = trunc i64 %candidate_length64 to i32
  %target_length = trunc i64 %name_length to i32
  %order = call i32 @CompareStringOrdinal(ptr %candidate, i32 %candidate_length, ptr %name, i32 %target_length, i32 1)
  %matches = icmp eq i32 %order, 2
  br i1 %matches, label %found, label %different

different:                                        ; preds = %compare, %inspect
  br label %loop

found:                                            ; preds = %compare
  ret i64 %index

missing:                                          ; preds = %loop, %entry
  ret i64 -1
}

define internal void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %count, ptr %parent) {
entry:
  %has_entries = icmp ne ptr %entries, null
  br i1 %has_entries, label %entry_loop, label %free_arrays

entry_loop:                                       ; preds = %entry_more, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %entry_more ]
  %entries_done = icmp eq i64 %index, %count
  br i1 %entries_done, label %free_arrays, label %entry_more

entry_more:                                       ; preds = %entry_loop
  %slot = getelementptr ptr, ptr %entries, i64 %index
  %value = load ptr, ptr %slot, align 8
  call void @free(ptr %value)
  %next = add i64 %index, 1
  br label %entry_loop

free_arrays:                                      ; preds = %entry_loop, %entry
  call void @free(ptr %entries)
  call void @free(ptr %name_lengths)
  call void @free(ptr %list)
  %has_parent = icmp ne ptr %parent, null
  br i1 %has_parent, label %free_parent, label %cleanup_done

free_parent:                                      ; preds = %free_arrays
  %parent_freed = call i32 @FreeEnvironmentStringsW(ptr %parent)
  br label %cleanup_done

cleanup_done:                                     ; preds = %free_parent, %free_arrays
  ret void
}

define internal %sollang.process_environment_result @sollang_windows_build_environment(ptr %changes, i64 %change_count, i1 %inherits) {
entry:
  %has_changes = icmp ne i64 %change_count, 0
  %cleared = xor i1 %inherits, true
  %custom = or i1 %has_changes, %cleared
  br i1 %custom, label %allocate_entries, label %fast

fast:                                             ; preds = %entry
  %fast0 = insertvalue %sollang.process_environment_result poison, ptr null, 0
  %fast1 = insertvalue %sollang.process_environment_result %fast0, i64 0, 1
  %fast2 = insertvalue %sollang.process_environment_result %fast1, i64 -1, 2
  %fast3 = insertvalue %sollang.process_environment_result %fast2, i1 true, 3
  ret %sollang.process_environment_result %fast3

allocate_entries:                                 ; preds = %entry
  %entry_slots0 = select i1 %has_changes, i64 %change_count, i64 1
  %entry_bytes = mul i64 %entry_slots0, 8
  %entries = call ptr @malloc(i64 %entry_bytes)
  %entries_ok = icmp ne ptr %entries, null
  br i1 %entries_ok, label %allocate_lengths, label %failure

allocate_lengths:                                 ; preds = %allocate_entries
  %name_lengths = call ptr @malloc(i64 %entry_bytes)
  %lengths_ok = icmp ne ptr %name_lengths, null
  br i1 %lengths_ok, label %initialize_entries, label %free_entries_failure

initialize_entries:                               ; preds = %init_more, %allocate_lengths
  %init_index = phi i64 [ 0, %allocate_lengths ], [ %init_next, %init_more ]
  %init_done = icmp eq i64 %init_index, %change_count
  br i1 %init_done, label %convert_changes, label %init_more

init_more:                                        ; preds = %initialize_entries
  %init_slot = getelementptr ptr, ptr %entries, i64 %init_index
  store ptr null, ptr %init_slot, align 8
  %init_next = add i64 %init_index, 1
  br label %initialize_entries

convert_changes:                                  ; preds = %store_set, %store_removed, %initialize_entries
  %change_index = phi i64 [ 0, %initialize_entries ], [ %change_next_removed, %store_removed ], [ %change_next_set, %store_set ]
  %changes_done = icmp eq i64 %change_index, %change_count
  br i1 %changes_done, label %parent_select, label %load_change

load_change:                                      ; preds = %convert_changes
  %change = getelementptr { %sollang.text, %sollang.text, i1 }, ptr %changes, i64 %change_index
  %name_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 0
  %name = load %sollang.text, ptr %name_slot, align 8
  %name_data = extractvalue %sollang.text %name, 0
  %name_length = extractvalue %sollang.text %name, 1
  %name_nonempty = icmp ne i64 %name_length, 0
  %name_valid0 = call i1 @sollang_windows_environment_text_valid(ptr %name_data, i64 %name_length, i1 true)
  %name_valid = and i1 %name_nonempty, %name_valid0
  %value_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 1
  %value = load %sollang.text, ptr %value_slot, align 8
  %value_data = extractvalue %sollang.text %value, 0
  %value_length = extractvalue %sollang.text %value, 1
  %value_valid = call i1 @sollang_windows_environment_text_valid(ptr %value_data, i64 %value_length, i1 false)
  %text_valid = and i1 %name_valid, %value_valid
  br i1 %text_valid, label %convert_name, label %build_failure

convert_name:                                     ; preds = %load_change
  %wide_name = call ptr @sollang_process_windows_text(ptr %name_data, i64 %name_length)
  %wide_name_ok = icmp ne ptr %wide_name, null
  br i1 %wide_name_ok, label %measure_name, label %build_failure

measure_name:                                     ; preds = %convert_name
  %wide_name_length = call i64 @sollang_windows_wide_length(ptr %wide_name)
  %name_length_store = getelementptr i64, ptr %name_lengths, i64 %change_index
  store i64 %wide_name_length, ptr %name_length_store, align 8
  %removed_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 2
  %removed = load i1, ptr %removed_slot, align 1
  br i1 %removed, label %store_removed, label %convert_value

store_removed:                                    ; preds = %measure_name
  %removed_entry_slot = getelementptr ptr, ptr %entries, i64 %change_index
  store ptr %wide_name, ptr %removed_entry_slot, align 8
  %change_next_removed = add i64 %change_index, 1
  br label %convert_changes

convert_value:                                    ; preds = %measure_name
  %wide_value = call ptr @sollang_process_windows_text(ptr %value_data, i64 %value_length)
  %wide_value_ok = icmp ne ptr %wide_value, null
  br i1 %wide_value_ok, label %allocate_entry, label %free_name_failure

allocate_entry:                                   ; preds = %convert_value
  %wide_value_length = call i64 @sollang_windows_wide_length(ptr %wide_value)
  %entry_without_end = add i64 %wide_name_length, %wide_value_length
  %entry_chars = add i64 %entry_without_end, 2
  %wide_entry_bytes = mul i64 %entry_chars, 2
  %wide_entry = call ptr @malloc(i64 %wide_entry_bytes)
  %wide_entry_ok = icmp ne ptr %wide_entry, null
  br i1 %wide_entry_ok, label %copy_entry, label %free_name_value_failure

copy_entry:                                       ; preds = %allocate_entry
  %wide_name_bytes = mul i64 %wide_name_length, 2
  call void @llvm.memcpy.p0.p0.i64(ptr %wide_entry, ptr %wide_name, i64 %wide_name_bytes, i1 false)
  %separator = getelementptr i16, ptr %wide_entry, i64 %wide_name_length
  store i16 61, ptr %separator, align 2
  %value_offset = add i64 %wide_name_length, 1
  %value_destination = getelementptr i16, ptr %wide_entry, i64 %value_offset
  %wide_value_bytes = mul i64 %wide_value_length, 2
  call void @llvm.memcpy.p0.p0.i64(ptr %value_destination, ptr %wide_value, i64 %wide_value_bytes, i1 false)
  %entry_end_offset = add i64 %value_offset, %wide_value_length
  %entry_end = getelementptr i16, ptr %wide_entry, i64 %entry_end_offset
  store i16 0, ptr %entry_end, align 2
  call void @free(ptr %wide_name)
  call void @free(ptr %wide_value)
  br label %store_set

store_set:                                        ; preds = %copy_entry
  %set_entry_slot = getelementptr ptr, ptr %entries, i64 %change_index
  store ptr %wide_entry, ptr %set_entry_slot, align 8
  %change_next_set = add i64 %change_index, 1
  br label %convert_changes

free_name_failure:                                ; preds = %convert_value
  call void @free(ptr %wide_name)
  br label %build_failure

free_name_value_failure:                          ; preds = %allocate_entry
  call void @free(ptr %wide_name)
  call void @free(ptr %wide_value)
  br label %build_failure

parent_select:                                    ; preds = %convert_changes
  br i1 %inherits, label %load_parent, label %allocate_list

load_parent:                                      ; preds = %parent_select
  %parent = call ptr @GetEnvironmentStringsW()
  %parent_ok = icmp ne ptr %parent, null
  br i1 %parent_ok, label %count_parent, label %build_failure

count_parent:                                     ; preds = %parent_more, %load_parent
  %parent_count = phi i64 [ 0, %load_parent ], [ %parent_count_next, %parent_more ]
  %parent_cursor = phi ptr [ %parent, %load_parent ], [ %parent_next, %parent_more ]
  %parent_first = load i16, ptr %parent_cursor, align 2
  %parent_done = icmp eq i16 %parent_first, 0
  br i1 %parent_done, label %allocate_list, label %parent_more

parent_more:                                      ; preds = %count_parent
  %parent_length = call i64 @sollang_windows_wide_length(ptr %parent_cursor)
  %parent_stride = add i64 %parent_length, 1
  %parent_next = getelementptr i16, ptr %parent_cursor, i64 %parent_stride
  %parent_count_next = add i64 %parent_count, 1
  br label %count_parent

allocate_list:                                    ; preds = %count_parent, %parent_select
  %selected_parent = phi ptr [ null, %parent_select ], [ %parent, %count_parent ]
  %selected_parent_count = phi i64 [ 0, %parent_select ], [ %parent_count, %count_parent ]
  %maximum_count = add i64 %selected_parent_count, %change_count
  %list_slots = add i64 %maximum_count, 1
  %list_bytes = mul i64 %list_slots, 8
  %list = call ptr @malloc(i64 %list_bytes)
  %list_ok = icmp ne ptr %list, null
  br i1 %list_ok, label %copy_parent, label %build_failure_with_parent

copy_parent:                                      ; preds = %copy_parent_continue, %allocate_list
  %copy_parent_index = phi i64 [ 0, %allocate_list ], [ %copy_parent_next, %copy_parent_continue ]
  %copy_parent_cursor = phi ptr [ %selected_parent, %allocate_list ], [ %copy_parent_cursor_next, %copy_parent_continue ]
  %kept_count = phi i64 [ 0, %allocate_list ], [ %kept_next, %copy_parent_continue ]
  %copy_parent_done = icmp eq i64 %copy_parent_index, %selected_parent_count
  br i1 %copy_parent_done, label %append_changes, label %copy_parent_inspect

copy_parent_inspect:                              ; preds = %copy_parent
  %parent_entry_length = call i64 @sollang_windows_wide_length(ptr %copy_parent_cursor)
  %parent_name_length = call i64 @sollang_windows_environment_name_length(ptr %copy_parent_cursor)
  %parent_change = call i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %change_count, ptr %copy_parent_cursor, i64 %parent_name_length)
  %parent_overridden = icmp sge i64 %parent_change, 0
  br i1 %parent_overridden, label %copy_parent_skip, label %copy_parent_keep

copy_parent_keep:                                 ; preds = %copy_parent_inspect
  %parent_destination = getelementptr ptr, ptr %list, i64 %kept_count
  store ptr %copy_parent_cursor, ptr %parent_destination, align 8
  %kept_after_copy = add i64 %kept_count, 1
  br label %copy_parent_continue

copy_parent_skip:                                 ; preds = %copy_parent_inspect
  br label %copy_parent_continue

copy_parent_continue:                             ; preds = %copy_parent_skip, %copy_parent_keep
  %kept_next = phi i64 [ %kept_after_copy, %copy_parent_keep ], [ %kept_count, %copy_parent_skip ]
  %copy_parent_stride = add i64 %parent_entry_length, 1
  %copy_parent_cursor_next = getelementptr i16, ptr %copy_parent_cursor, i64 %copy_parent_stride
  %copy_parent_next = add i64 %copy_parent_index, 1
  br label %copy_parent

append_changes:                                   ; preds = %append_continue, %copy_parent
  %append_index = phi i64 [ 0, %copy_parent ], [ %append_next, %append_continue ]
  %output_count = phi i64 [ %kept_count, %copy_parent ], [ %output_next, %append_continue ]
  %append_done = icmp eq i64 %append_index, %change_count
  br i1 %append_done, label %sort_outer, label %append_inspect

append_inspect:                                   ; preds = %append_changes
  %append_entry_slot = getelementptr ptr, ptr %entries, i64 %append_index
  %append_entry = load ptr, ptr %append_entry_slot, align 8
  %append_name_length_slot = getelementptr i64, ptr %name_lengths, i64 %append_index
  %append_name_length = load i64, ptr %append_name_length_slot, align 8
  %latest = call i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %change_count, ptr %append_entry, i64 %append_name_length)
  %is_latest = icmp eq i64 %latest, %append_index
  br i1 %is_latest, label %append_latest, label %append_skip

append_latest:                                    ; preds = %append_inspect
  %append_change = getelementptr { %sollang.text, %sollang.text, i1 }, ptr %changes, i64 %append_index
  %append_removed_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %append_change, i32 0, i32 2
  %append_removed = load i1, ptr %append_removed_slot, align 1
  br i1 %append_removed, label %append_skip, label %append_keep

append_keep:                                      ; preds = %append_latest
  %append_destination = getelementptr ptr, ptr %list, i64 %output_count
  store ptr %append_entry, ptr %append_destination, align 8
  %output_after_append = add i64 %output_count, 1
  br label %append_continue

append_skip:                                      ; preds = %append_latest, %append_inspect
  br label %append_continue

append_continue:                                  ; preds = %append_skip, %append_keep
  %output_next = phi i64 [ %output_after_append, %append_keep ], [ %output_count, %append_skip ]
  %append_next = add i64 %append_index, 1
  br label %append_changes

sort_outer:                                       ; preds = %sort_store, %append_changes
  %sort_index = phi i64 [ 1, %append_changes ], [ %sort_next, %sort_store ]
  %sort_done = icmp uge i64 %sort_index, %output_count
  br i1 %sort_done, label %measure_block, label %sort_load

sort_load:                                        ; preds = %sort_outer
  %sort_key_slot = getelementptr ptr, ptr %list, i64 %sort_index
  %sort_key = load ptr, ptr %sort_key_slot, align 8
  br label %sort_inner

sort_inner:                                       ; preds = %sort_shift, %sort_load
  %sort_position = phi i64 [ %sort_index, %sort_load ], [ %sort_previous, %sort_shift ]
  %at_start = icmp eq i64 %sort_position, 0
  br i1 %at_start, label %sort_store, label %sort_compare

sort_compare:                                     ; preds = %sort_inner
  %sort_previous = sub i64 %sort_position, 1
  %sort_previous_slot = getelementptr ptr, ptr %list, i64 %sort_previous
  %sort_previous_value = load ptr, ptr %sort_previous_slot, align 8
  %sort_order = call i32 @CompareStringOrdinal(ptr %sort_key, i32 -1, ptr %sort_previous_value, i32 -1, i32 1)
  %sort_before = icmp eq i32 %sort_order, 1
  br i1 %sort_before, label %sort_shift, label %sort_store

sort_shift:                                       ; preds = %sort_compare
  %sort_shift_destination = getelementptr ptr, ptr %list, i64 %sort_position
  store ptr %sort_previous_value, ptr %sort_shift_destination, align 8
  br label %sort_inner

sort_store:                                       ; preds = %sort_compare, %sort_inner
  %sort_destination = getelementptr ptr, ptr %list, i64 %sort_position
  store ptr %sort_key, ptr %sort_destination, align 8
  %sort_next = add i64 %sort_index, 1
  br label %sort_outer

measure_block:                                    ; preds = %measure_more, %sort_outer
  %measure_index = phi i64 [ 0, %sort_outer ], [ %measure_next, %measure_more ]
  %measure_chars = phi i64 [ 0, %sort_outer ], [ %measure_total, %measure_more ]
  %measure_done = icmp eq i64 %measure_index, %output_count
  br i1 %measure_done, label %allocate_block, label %measure_more

measure_more:                                     ; preds = %measure_block
  %measure_slot = getelementptr ptr, ptr %list, i64 %measure_index
  %measure_entry = load ptr, ptr %measure_slot, align 8
  %measure_length = call i64 @sollang_windows_wide_length(ptr %measure_entry)
  %measure_with_null = add i64 %measure_length, 1
  %measure_total = add i64 %measure_chars, %measure_with_null
  %measure_next = add i64 %measure_index, 1
  br label %measure_block

allocate_block:                                   ; preds = %measure_block
  %empty_block = icmp eq i64 %output_count, 0
  %nonempty_chars = add i64 %measure_chars, 1
  %block_chars = select i1 %empty_block, i64 2, i64 %nonempty_chars
  %block_bytes = mul i64 %block_chars, 2
  %block = call ptr @malloc(i64 %block_bytes)
  %block_ok = icmp ne ptr %block, null
  br i1 %block_ok, label %copy_block, label %build_failure_with_list

copy_block:                                       ; preds = %block_more, %allocate_block
  %block_index = phi i64 [ 0, %allocate_block ], [ %block_next, %block_more ]
  %block_offset = phi i64 [ 0, %allocate_block ], [ %block_offset_next, %block_more ]
  %block_done = icmp eq i64 %block_index, %output_count
  br i1 %block_done, label %terminate_block, label %block_more

block_more:                                       ; preds = %copy_block
  %block_entry_slot = getelementptr ptr, ptr %list, i64 %block_index
  %block_entry = load ptr, ptr %block_entry_slot, align 8
  %block_entry_length = call i64 @sollang_windows_wide_length(ptr %block_entry)
  %block_copy_chars = add i64 %block_entry_length, 1
  %block_copy_bytes = mul i64 %block_copy_chars, 2
  %block_destination = getelementptr i16, ptr %block, i64 %block_offset
  call void @llvm.memcpy.p0.p0.i64(ptr %block_destination, ptr %block_entry, i64 %block_copy_bytes, i1 false)
  %block_offset_next = add i64 %block_offset, %block_copy_chars
  %block_next = add i64 %block_index, 1
  br label %copy_block

terminate_block:                                  ; preds = %copy_block
  %final_null = getelementptr i16, ptr %block, i64 %block_offset
  store i16 0, ptr %final_null, align 2
  %empty_second = getelementptr i16, ptr %block, i64 1
  br i1 %empty_block, label %terminate_empty, label %finish

terminate_empty:                                  ; preds = %terminate_block
  store i16 0, ptr %empty_second, align 2
  br label %finish

finish:                                           ; preds = %terminate_empty, %terminate_block
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %change_count, ptr %selected_parent)
  %ok0 = insertvalue %sollang.process_environment_result poison, ptr %block, 0
  %ok1 = insertvalue %sollang.process_environment_result %ok0, i64 0, 1
  %ok2 = insertvalue %sollang.process_environment_result %ok1, i64 -1, 2
  %ok3 = insertvalue %sollang.process_environment_result %ok2, i1 true, 3
  ret %sollang.process_environment_result %ok3

build_failure_with_list:                          ; preds = %allocate_block
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %change_count, ptr %selected_parent)
  br label %failure

build_failure_with_parent:                        ; preds = %allocate_list
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr null, i64 %change_count, ptr %selected_parent)
  br label %failure

build_failure:                                    ; preds = %load_parent, %free_name_value_failure, %free_name_failure, %convert_name, %load_change
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr null, i64 %change_count, ptr null)
  br label %failure

free_entries_failure:                             ; preds = %allocate_lengths
  call void @free(ptr %entries)
  br label %failure

failure:                                          ; preds = %free_entries_failure, %build_failure, %build_failure_with_parent, %build_failure_with_list, %allocate_entries
  ret %sollang.process_environment_result zeroinitializer
}

define internal ptr @sollang_process_inherit_windows_handle(ptr %source) {
entry:
  %process = call ptr @GetCurrentProcess()
  %target_slot = alloca ptr, align 8
  %duplicated = call i32 @DuplicateHandle(ptr %process, ptr %source, ptr %process, ptr %target_slot, i32 0, i32 1, i32 2)
  %ok = icmp ne i32 %duplicated, 0
  br i1 %ok, label %success, label %fail

success:                                          ; preds = %entry
  %target = load ptr, ptr %target_slot, align 8
  ret ptr %target

fail:                                             ; preds = %entry
  ret ptr null
}

define internal i64 @sollang_process_spawn_windows(ptr %program, ptr %argv, i64 %count, ptr %working_directory, ptr %environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override) {
entry:
  %command = call ptr @sollang_process_join_windows_args(ptr %argv, i64 %count)
  %command_ok = icmp ne ptr %command, null
  br i1 %command_ok, label %handles, label %fail

handles:                                          ; preds = %entry
  %stdin_default_value = call i64 @_get_osfhandle(i32 0)
  %stdin_default = inttoptr i64 %stdin_default_value to ptr
  %has_stdin_override = icmp ne ptr %stdin_override, null
  %stdin_source = select i1 %has_stdin_override, ptr %stdin_override, ptr %stdin_default
  %stdout_default_value = call i64 @_get_osfhandle(i32 1)
  %stdout_default = inttoptr i64 %stdout_default_value to ptr
  %has_stdout_override = icmp ne ptr %stdout_override, null
  %stdout_source = select i1 %has_stdout_override, ptr %stdout_override, ptr %stdout_default
  %stderr_default_value = call i64 @_get_osfhandle(i32 2)
  %stderr_default = inttoptr i64 %stderr_default_value to ptr
  %has_stderr_override = icmp ne ptr %stderr_override, null
  %stderr_source = select i1 %has_stderr_override, ptr %stderr_override, ptr %stderr_default
  %stdin_handle = call ptr @sollang_process_inherit_windows_handle(ptr %stdin_source)
  %stdout_handle = call ptr @sollang_process_inherit_windows_handle(ptr %stdout_source)
  %stderr_handle = call ptr @sollang_process_inherit_windows_handle(ptr %stderr_source)
  %stdin_ok = icmp ne ptr %stdin_handle, null
  %stdout_ok = icmp ne ptr %stdout_handle, null
  %stderr_ok = icmp ne ptr %stderr_handle, null
  %io_ok0 = and i1 %stdin_ok, %stdout_ok
  %io_ok = and i1 %io_ok0, %stderr_ok
  br i1 %io_ok, label %create, label %close_handles_fail

create:                                           ; preds = %handles
  %startup = alloca [104 x i8], align 8
  %process_info = alloca [24 x i8], align 8
  call void @llvm.memset.p0.i64(ptr %startup, i8 0, i64 104, i1 false)
  call void @llvm.memset.p0.i64(ptr %process_info, i8 0, i64 24, i1 false)
  store i32 104, ptr %startup, align 4
  %flags_ptr = getelementptr i8, ptr %startup, i64 60
  store i32 256, ptr %flags_ptr, align 4
  %stdin_ptr = getelementptr i8, ptr %startup, i64 80
  store ptr %stdin_handle, ptr %stdin_ptr, align 8
  %stdout_ptr = getelementptr i8, ptr %startup, i64 88
  store ptr %stdout_handle, ptr %stdout_ptr, align 8
  %stderr_ptr = getelementptr i8, ptr %startup, i64 96
  store ptr %stderr_handle, ptr %stderr_ptr, align 8
  %has_environment = icmp ne ptr %environment, null
  %creation_flags = select i1 %has_environment, i32 1024, i32 0
  %created = call i32 @CreateProcessW(ptr %program, ptr %command, ptr null, ptr null, i32 1, i32 %creation_flags, ptr %environment, ptr %working_directory, ptr %startup, ptr %process_info)
  %created_ok = icmp ne i32 %created, 0
  br i1 %created_ok, label %spawned, label %close_handles_fail

spawned:                                          ; preds = %create
  %process_handle = load ptr, ptr %process_info, align 8
  %thread_ptr = getelementptr i8, ptr %process_info, i64 8
  %thread_handle = load ptr, ptr %thread_ptr, align 8
  %closed_thread = call i32 @CloseHandle(ptr %thread_handle)
  %closed_stdin = call i32 @CloseHandle(ptr %stdin_handle)
  %closed_stdout = call i32 @CloseHandle(ptr %stdout_handle)
  %closed_stderr = call i32 @CloseHandle(ptr %stderr_handle)
  call void @free(ptr %command)
  %token = ptrtoint ptr %process_handle to i64
  ret i64 %token

close_handles_fail:                               ; preds = %create, %handles
  br i1 %stdin_ok, label %close_stdin, label %close_stdout

close_stdin:                                      ; preds = %close_handles_fail
  %closed_stdin_fail = call i32 @CloseHandle(ptr %stdin_handle)
  br label %close_stdout

close_stdout:                                     ; preds = %close_stdin, %close_handles_fail
  br i1 %stdout_ok, label %close_stdout_present, label %close_stderr

close_stdout_present:                             ; preds = %close_stdout
  %closed_stdout_fail = call i32 @CloseHandle(ptr %stdout_handle)
  br label %close_stderr

close_stderr:                                     ; preds = %close_stdout_present, %close_stdout
  br i1 %stderr_ok, label %close_stderr_present, label %free_fail

close_stderr_present:                             ; preds = %close_stderr
  %closed_stderr_fail = call i32 @CloseHandle(ptr %stderr_handle)
  br label %free_fail

free_fail:                                        ; preds = %close_stderr_present, %close_stderr
  call void @free(ptr %command)
  br label %fail

fail:                                             ; preds = %free_fail, %entry
  ret i64 -1
}

define internal %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override) {
entry:
  %has_program = icmp ugt i64 %count, 0
  br i1 %has_program, label %build, label %error

build:                                            ; preds = %entry
  %program_slot = alloca ptr, align 8
  %argv = call ptr @sollang_process_build_windows_argv(ptr %records, i64 %count, ptr %program_slot)
  %built = icmp ne ptr %argv, null
  br i1 %built, label %spawn, label %error

spawn:                                            ; preds = %build
  %program = load ptr, ptr %program_slot, align 8
  br i1 %has_working_directory, label %working_directory_convert, label %spawn_ready

working_directory_convert:                        ; preds = %spawn
  %working_directory_wide = call ptr @sollang_process_windows_text(ptr %working_directory_data, i64 %working_directory_length)
  %working_directory_ok = icmp ne ptr %working_directory_wide, null
  br i1 %working_directory_ok, label %working_directory_ready, label %build_error

working_directory_ready:                          ; preds = %working_directory_convert
  br label %spawn_ready

spawn_ready:                                      ; preds = %working_directory_ready, %spawn
  %working_directory = phi ptr [ null, %spawn ], [ %working_directory_wide, %working_directory_ready ]
  %environment_result = call %sollang.process_environment_result @sollang_windows_build_environment(ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  %environment = extractvalue %sollang.process_environment_result %environment_result, 0
  %environment_ok = extractvalue %sollang.process_environment_result %environment_result, 3
  br i1 %environment_ok, label %environment_ready, label %environment_error

environment_ready:                                ; preds = %spawn_ready
  %raw = call i64 @sollang_process_spawn_windows(ptr %program, ptr %argv, i64 %count, ptr %working_directory, ptr %environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override)
  call void @free(ptr %environment)
  call void @free(ptr %working_directory)
  call void @free(ptr %program)
  call void @sollang_process_dispose_argv(ptr %argv, i64 %count)
  %spawned = icmp ne i64 %raw, -1
  br i1 %spawned, label %read_process_id, label %error

environment_error:                                ; preds = %spawn_ready
  call void @free(ptr %working_directory)
  call void @free(ptr %program)
  call void @sollang_process_dispose_argv(ptr %argv, i64 %count)
  br label %error

build_error:                                      ; preds = %working_directory_convert
  call void @free(ptr %program)
  call void @sollang_process_dispose_argv(ptr %argv, i64 %count)
  br label %error

read_process_id:                                  ; preds = %environment_ready
  %handle = inttoptr i64 %raw to ptr
  %process_id32 = call i32 @GetProcessId(ptr %handle)
  %process_id_ok = icmp ne i32 %process_id32, 0
  br i1 %process_id_ok, label %success, label %process_id_error

process_id_error:                                 ; preds = %read_process_id
  %terminated_id_error = call i32 @TerminateProcess(ptr %handle, i32 1)
  %reaped_id_error = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %closed_id_error = call i32 @CloseHandle(ptr %handle)
  br label %error

success:                                          ; preds = %read_process_id
  %process_id = zext i32 %process_id32 to i64
  %ok0 = insertvalue %sollang.process_spawn_result poison, i64 %raw, 0
  %ok1 = insertvalue %sollang.process_spawn_result %ok0, i64 %process_id, 1
  %ok2 = insertvalue %sollang.process_spawn_result %ok1, i32 0, 2
  ret %sollang.process_spawn_result %ok2

error:                                            ; preds = %process_id_error, %build_error, %environment_error, %environment_ready, %build, %entry
  %error0 = insertvalue %sollang.process_spawn_result poison, i64 0, 0
  %error1 = insertvalue %sollang.process_spawn_result %error0, i64 0, 1
  %error2 = insertvalue %sollang.process_spawn_result %error1, i32 1, 2
  ret %sollang.process_spawn_result %error2
}

define internal %sollang.process_spawn_result @sollang_spawn_process_with_stdout(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdout_override) {
entry:
  %result = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr null, ptr %stdout_override, ptr null)
  ret %sollang.process_spawn_result %result
}

define internal ptr @sollang_process_open_windows_stdio(i32 %mode, ptr %path, i64 %path_length, i1 %input) {
entry:
  %inherits = icmp eq i32 %mode, 0
  br i1 %inherits, label %inherit, label %select_file

select_file:                                      ; preds = %entry
  %is_file = icmp eq i32 %mode, 1
  br i1 %is_file, label %copy_path, label %select_null

select_null:                                      ; preds = %select_file
  %is_null = icmp eq i32 %mode, 2
  br i1 %is_null, label %open_null, label %failure

copy_path:                                        ; preds = %select_file
  %path_copy = call ptr @sollang_process_windows_path(ptr %path, i64 %path_length)
  %path_ok = icmp ne ptr %path_copy, null
  br i1 %path_ok, label %open, label %failure

open:                                             ; preds = %copy_path
  %access = select i1 %input, i32 -2147483648, i32 1073741824
  %creation = select i1 %input, i32 3, i32 2
  %handle = call ptr @CreateFileW(ptr %path_copy, i32 %access, i32 1, ptr null, i32 %creation, i32 128, ptr null)
  call void @free(ptr %path_copy)
  ret ptr %handle

open_null:                                        ; preds = %select_null
  %null_access = select i1 %input, i32 -2147483648, i32 1073741824
  %null_creation = select i1 %input, i32 3, i32 2
  %null_handle = call ptr @CreateFileA(ptr @sollang_process_null_windows, i32 %null_access, i32 3, ptr null, i32 %null_creation, i32 128, ptr null)
  ret ptr %null_handle

inherit:                                          ; preds = %entry
  ret ptr null

failure:                                          ; preds = %copy_path, %select_null
  ret ptr inttoptr (i64 -1 to ptr)
}

define internal void @sollang_process_close_windows_stdio(ptr %handle) {
entry:
  %value = ptrtoint ptr %handle to i64
  %present = icmp ne i64 %value, 0
  %valid = icmp ne i64 %value, -1
  %should_close = and i1 %present, %valid
  br i1 %should_close, label %close, label %done

close:                                            ; preds = %entry
  %closed = call i32 @CloseHandle(ptr %handle)
  br label %done

done:                                             ; preds = %close, %entry
  ret void
}

define internal %sollang.process_spawn_result @sollang_spawn_process_configured(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length) {
entry:
  %stdin_inherits = icmp eq i32 %stdin_mode, 0
  %stdout_inherits = icmp eq i32 %stdout_mode, 0
  %stderr_inherits = icmp eq i32 %stderr_mode, 0
  %output_inherits = and i1 %stdout_inherits, %stderr_inherits
  %all_inherit = and i1 %stdin_inherits, %output_inherits
  br i1 %all_inherit, label %inherit, label %open

inherit:                                          ; preds = %entry
  %inherited = call %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  ret %sollang.process_spawn_result %inherited

open:                                             ; preds = %entry
  %stdin_handle = call ptr @sollang_process_open_windows_stdio(i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i1 true)
  %stdout_handle = call ptr @sollang_process_open_windows_stdio(i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i1 false)
  %stderr_handle = call ptr @sollang_process_open_windows_stdio(i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length, i1 false)
  %stdin_value = ptrtoint ptr %stdin_handle to i64
  %stdout_value = ptrtoint ptr %stdout_handle to i64
  %stderr_value = ptrtoint ptr %stderr_handle to i64
  %stdin_ok = icmp ne i64 %stdin_value, -1
  %stdout_ok = icmp ne i64 %stdout_value, -1
  %stderr_ok = icmp ne i64 %stderr_value, -1
  %stdio_ok0 = and i1 %stdin_ok, %stdout_ok
  %stdio_ok = and i1 %stdio_ok0, %stderr_ok
  br i1 %stdio_ok, label %spawn, label %open_failure

spawn:                                            ; preds = %open
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdin_handle, ptr %stdout_handle, ptr %stderr_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdin_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdout_handle)
  call void @sollang_process_close_windows_stdio(ptr %stderr_handle)
  ret %sollang.process_spawn_result %spawned

open_failure:                                     ; preds = %open
  call void @sollang_process_close_windows_stdio(ptr %stdin_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdout_handle)
  call void @sollang_process_close_windows_stdio(ptr %stderr_handle)
  ret %sollang.process_spawn_result { i64 0, i64 0, i32 1 }
}

define internal %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment) {
entry:
  %result = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr null, ptr null, ptr null)
  ret %sollang.process_spawn_result %result
}

define internal %sollang.process_result @sollang_wait_process(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %wait, label %error

wait:                                             ; preds = %entry
  %handle = inttoptr i64 %token to ptr
  %waited = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %wait_ok = icmp eq i32 %waited, 0
  br i1 %wait_ok, label %read_exit, label %terminate_error

read_exit:                                        ; preds = %wait
  %exit_slot = alloca i32, align 4
  %read = call i32 @GetExitCodeProcess(ptr %handle, ptr %exit_slot)
  %read_ok = icmp ne i32 %read, 0
  br i1 %read_ok, label %success, label %terminate_error

success:                                          ; preds = %read_exit
  %exit_code = load i32, ptr %exit_slot, align 4
  %closed = call i32 @CloseHandle(ptr %handle)
  %ok0 = insertvalue %sollang.process_result poison, i32 %exit_code, 0
  %ok1 = insertvalue %sollang.process_result %ok0, i32 0, 1
  ret %sollang.process_result %ok1

terminate_error:                                  ; preds = %read_exit, %wait
  %terminated = call i32 @TerminateProcess(ptr %handle, i32 1)
  %reaped = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %closed_error = call i32 @CloseHandle(ptr %handle)
  br label %error

error:                                            ; preds = %terminate_error, %entry
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 2, 1
  ret %sollang.process_result %error1
}

define internal %sollang.process_poll_result @sollang_poll_process(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %poll, label %poll_error

poll:                                             ; preds = %entry
  %handle = inttoptr i64 %token to ptr
  %waited = call i32 @WaitForSingleObject(ptr %handle, i32 0)
  %exited = icmp eq i32 %waited, 0
  %running = icmp eq i32 %waited, 258
  br i1 %exited, label %read_exit, label %classify_pending

classify_pending:                                 ; preds = %poll
  br i1 %running, label %poll_running, label %poll_error

read_exit:                                        ; preds = %poll
  %exit_slot = alloca i32, align 4
  %read = call i32 @GetExitCodeProcess(ptr %handle, ptr %exit_slot)
  %read_ok = icmp ne i32 %read, 0
  br i1 %read_ok, label %close_exit, label %poll_error

close_exit:                                       ; preds = %read_exit
  %exit_code = load i32, ptr %exit_slot, align 4
  %closed = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %closed, 0
  br i1 %close_ok, label %poll_exited, label %poll_error

poll_exited:                                      ; preds = %close_exit
  %exited0 = insertvalue %sollang.process_poll_result poison, i32 %exit_code, 0
  %exited1 = insertvalue %sollang.process_poll_result %exited0, i32 1, 1
  ret %sollang.process_poll_result %exited1

poll_running:                                     ; preds = %classify_pending
  ret %sollang.process_poll_result zeroinitializer

poll_error:                                       ; preds = %close_exit, %read_exit, %classify_pending, %entry
  ret %sollang.process_poll_result { i32 0, i32 2 }
}

define internal i1 @sollang_kill_process(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %terminate, label %failure

terminate:                                        ; preds = %entry
  %handle = inttoptr i64 %token to ptr
  %terminated = call i32 @TerminateProcess(ptr %handle, i32 1)
  %succeeded = icmp ne i32 %terminated, 0
  ret i1 %succeeded

failure:                                          ; preds = %entry
  ret i1 false
}

define internal void @sollang_drop_process_child(i64 %token) {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %dispose, label %done

dispose:                                          ; preds = %entry
  %handle = inttoptr i64 %token to ptr
  %terminated = call i32 @TerminateProcess(ptr %handle, i32 1)
  %reaped = call i32 @WaitForSingleObject(ptr %handle, i32 -1)
  %closed = call i32 @CloseHandle(ptr %handle)
  br label %done

done:                                             ; preds = %dispose, %entry
  ret void
}

define internal %sollang.process_result @sollang_run_process(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment) {
entry:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %error = extractvalue %sollang.process_spawn_result %spawned, 2
  %ok = icmp eq i32 %error, 0
  br i1 %ok, label %wait, label %spawn_error

wait:                                             ; preds = %entry
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result

spawn_error:                                      ; preds = %entry
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 1, 1
  ret %sollang.process_result %error1
}

define internal %sollang.process_result @sollang_run_process_configured(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length) {
entry:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_configured(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %error = extractvalue %sollang.process_spawn_result %spawned, 2
  %ok = icmp eq i32 %error, 0
  br i1 %ok, label %wait, label %spawn_error

wait:                                             ; preds = %entry
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result

spawn_error:                                      ; preds = %entry
  ret %sollang.process_result { i32 0, i32 1 }
}

define internal %sollang.process_result @sollang_run_process_to_file(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %path, i64 %path_length) {
entry:
  %path_copy = call ptr @sollang_process_windows_path(ptr %path, i64 %path_length)
  %path_ok = icmp ne ptr %path_copy, null
  br i1 %path_ok, label %open, label %error

open:                                             ; preds = %entry
  %output = call ptr @CreateFileW(ptr %path_copy, i32 1073741824, i32 1, ptr null, i32 2, i32 128, ptr null)
  call void @free(ptr %path_copy)
  %output_handle_value = ptrtoint ptr %output to i64
  %opened = icmp ne i64 %output_handle_value, -1
  br i1 %opened, label %run, label %error

run:                                              ; preds = %open
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_with_stdout(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %output)
  %closed_output = call i32 @CloseHandle(ptr %output)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %spawn_error = extractvalue %sollang.process_spawn_result %spawned, 2
  %spawn_ok = icmp eq i32 %spawn_error, 0
  br i1 %spawn_ok, label %wait, label %error

wait:                                             ; preds = %run
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result

error:                                            ; preds = %run, %open, %entry
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 1, 1
  ret %sollang.process_result %error1
}

define internal void @sollang_directory_copy(ptr %destination, ptr %source, i64 %length) {
entry:
  br label %loop

loop:                                             ; preds = %body, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %body ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %finish, label %body

body:                                             ; preds = %loop
  %source_slot = getelementptr i8, ptr %source, i64 %index
  %byte = load i8, ptr %source_slot, align 1
  %destination_slot = getelementptr i8, ptr %destination, i64 %index
  store i8 %byte, ptr %destination_slot, align 1
  %next = add i64 %index, 1
  br label %loop

finish:                                           ; preds = %loop
  ret void
}

define internal i32 @sollang_directory_compare_nodes(ptr %left, ptr %right) {
entry:
  %left_len_slot = getelementptr %sollang.directory_node, ptr %left, i32 0, i32 1
  %left_len = load i64, ptr %left_len_slot, align 8
  %right_len_slot = getelementptr %sollang.directory_node, ptr %right, i32 0, i32 1
  %right_len = load i64, ptr %right_len_slot, align 8
  %left_name = getelementptr i8, ptr %left, i64 24
  %right_name = getelementptr i8, ptr %right, i64 24
  %left_shorter = icmp ult i64 %left_len, %right_len
  %minimum = select i1 %left_shorter, i64 %left_len, i64 %right_len
  br label %compare

compare:                                          ; preds = %equal_byte, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %equal_byte ]
  %within = icmp ult i64 %index, %minimum
  br i1 %within, label %compare_byte, label %compare_length

compare_byte:                                     ; preds = %compare
  %left_ptr = getelementptr i8, ptr %left_name, i64 %index
  %right_ptr = getelementptr i8, ptr %right_name, i64 %index
  %left_byte = load i8, ptr %left_ptr, align 1
  %right_byte = load i8, ptr %right_ptr, align 1
  %same = icmp eq i8 %left_byte, %right_byte
  br i1 %same, label %equal_byte, label %different_byte

equal_byte:                                       ; preds = %compare_byte
  %next = add i64 %index, 1
  br label %compare

different_byte:                                   ; preds = %compare_byte
  %less = icmp ult i8 %left_byte, %right_byte
  %byte_result = select i1 %less, i32 -1, i32 1
  ret i32 %byte_result

compare_length:                                   ; preds = %compare
  %same_length = icmp eq i64 %left_len, %right_len
  br i1 %same_length, label %equal, label %different_length

different_length:                                 ; preds = %compare_length
  %length_result = select i1 %left_shorter, i32 -1, i32 1
  ret i32 %length_result

equal:                                            ; preds = %compare_length
  ret i32 0
}

define internal ptr @sollang_directory_insert_sorted(ptr %head, ptr %node) {
entry:
  %empty = icmp eq ptr %head, null
  br i1 %empty, label %only, label %compare_head

only:                                             ; preds = %entry
  %only_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr null, ptr %only_next, align 8
  ret ptr %node

compare_head:                                     ; preds = %entry
  %head_order = call i32 @sollang_directory_compare_nodes(ptr %node, ptr %head)
  %before_head = icmp slt i32 %head_order, 0
  br i1 %before_head, label %prepend, label %scan_start

prepend:                                          ; preds = %compare_head
  %prepend_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr %head, ptr %prepend_next, align 8
  ret ptr %node

scan_start:                                       ; preds = %compare_head
  %head_next_slot = getelementptr %sollang.directory_node, ptr %head, i32 0, i32 0
  %head_next = load ptr, ptr %head_next_slot, align 8
  br label %scan

scan:                                             ; preds = %advance, %scan_start
  %previous = phi ptr [ %head, %scan_start ], [ %current, %advance ]
  %current = phi ptr [ %head_next, %scan_start ], [ %next, %advance ]
  %at_end = icmp eq ptr %current, null
  br i1 %at_end, label %append, label %compare_current

compare_current:                                  ; preds = %scan
  %order = call i32 @sollang_directory_compare_nodes(ptr %node, ptr %current)
  %before = icmp slt i32 %order, 0
  br i1 %before, label %insert, label %advance

advance:                                          ; preds = %compare_current
  %current_next_slot = getelementptr %sollang.directory_node, ptr %current, i32 0, i32 0
  %next = load ptr, ptr %current_next_slot, align 8
  br label %scan

insert:                                           ; preds = %compare_current
  %node_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr %current, ptr %node_next, align 8
  %previous_next = getelementptr %sollang.directory_node, ptr %previous, i32 0, i32 0
  store ptr %node, ptr %previous_next, align 8
  ret ptr %head

append:                                           ; preds = %scan
  %append_node_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr null, ptr %append_node_next, align 8
  %append_previous_next = getelementptr %sollang.directory_node, ptr %previous, i32 0, i32 0
  store ptr %node, ptr %append_previous_next, align 8
  ret ptr %head
}

define internal void @sollang_directory_free_nodes(ptr %head) {
entry:
  br label %loop

loop:                                             ; preds = %body, %entry
  %node = phi ptr [ %head, %entry ], [ %next, %body ]
  %done = icmp eq ptr %node, null
  br i1 %done, label %finish, label %body

body:                                             ; preds = %loop
  %next_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  %next = load ptr, ptr %next_slot, align 8
  call void @free(ptr %node)
  br label %loop

finish:                                           ; preds = %loop
  ret void
}

define internal ptr @sollang_directory_serialize(ptr %head, i64 %total) {
entry:
  %empty = icmp eq i64 %total, 0
  br i1 %empty, label %empty_result, label %allocate

empty_result:                                     ; preds = %entry
  ret ptr null

allocate:                                         ; preds = %entry
  %output = call ptr @malloc(i64 %total)
  %allocated = icmp ne ptr %output, null
  br i1 %allocated, label %loop, label %allocation_failed

allocation_failed:                                ; preds = %allocate
  call void @sollang_directory_free_nodes(ptr %head)
  ret ptr null

loop:                                             ; preds = %body, %allocate
  %node = phi ptr [ %head, %allocate ], [ %next_node, %body ]
  %offset = phi i64 [ 0, %allocate ], [ %next_offset, %body ]
  %done = icmp eq ptr %node, null
  br i1 %done, label %finish, label %body

body:                                             ; preds = %loop
  %next_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  %next_node = load ptr, ptr %next_slot, align 8
  %length_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 1
  %length = load i64, ptr %length_slot, align 8
  %kind_slot = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 2
  %kind = load i8, ptr %kind_slot, align 1
  %record = getelementptr i8, ptr %output, i64 %offset
  store i8 %kind, ptr %record, align 1
  %length32 = trunc i64 %length to i32
  %length0 = trunc i32 %length32 to i8
  %length_shift1 = lshr i32 %length32, 8
  %length1 = trunc i32 %length_shift1 to i8
  %length_shift2 = lshr i32 %length32, 16
  %length2 = trunc i32 %length_shift2 to i8
  %length_shift3 = lshr i32 %length32, 24
  %length3 = trunc i32 %length_shift3 to i8
  %length_ptr0 = getelementptr i8, ptr %record, i64 1
  %length_ptr1 = getelementptr i8, ptr %record, i64 2
  %length_ptr2 = getelementptr i8, ptr %record, i64 3
  %length_ptr3 = getelementptr i8, ptr %record, i64 4
  store i8 %length0, ptr %length_ptr0, align 1
  store i8 %length1, ptr %length_ptr1, align 1
  store i8 %length2, ptr %length_ptr2, align 1
  store i8 %length3, ptr %length_ptr3, align 1
  %destination = getelementptr i8, ptr %record, i64 5
  %source = getelementptr i8, ptr %node, i64 24
  call void @sollang_directory_copy(ptr %destination, ptr %source, i64 %length)
  %record_size = add i64 %length, 5
  %next_offset = add i64 %offset, %record_size
  call void @free(ptr %node)
  br label %loop

finish:                                           ; preds = %loop
  ret ptr %output
}

define internal %sollang.path_absolute_result @sollang_platform_absolute_path(ptr %path, i64 %len, i32 %style) {
entry:
  %native_style = icmp eq i32 %style, 1
  %nonempty = icmp ugt i64 %len, 0
  %bounded = icmp ult i64 %len, 2147483647
  %sized = and i1 %nonempty, %bounded
  %valid = and i1 %native_style, %sized
  br i1 %valid, label %scan, label %fail

scan:                                             ; preds = %scan_step, %entry
  %scan_index = phi i64 [ 0, %entry ], [ %scan_next, %scan_step ]
  %only_spaces = phi i1 [ true, %entry ], [ %remaining_spaces, %scan_step ]
  %byte_ptr = getelementptr i8, ptr %path, i64 %scan_index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %fail, label %scan_step

scan_step:                                        ; preds = %scan
  %space = icmp eq i8 %byte, 32
  %remaining_spaces = and i1 %only_spaces, %space
  %scan_next = add i64 %scan_index, 1
  %scan_done = icmp eq i64 %scan_next, %len
  br i1 %scan_done, label %validated, label %scan

validated:                                        ; preds = %scan_step
  br i1 %remaining_spaces, label %fail, label %measure

measure:                                          ; preds = %validated
  %len32 = trunc i64 %len to i32
  %input_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr null, i32 0)
  %input_valid = icmp sgt i32 %input_chars, 0
  br i1 %input_valid, label %allocate_input, label %fail

allocate_input:                                   ; preds = %measure
  %input_chars64 = zext i32 %input_chars to i64
  %input_capacity = add i64 %input_chars64, 1
  %input_bytes = mul i64 %input_capacity, 2
  %input = call ptr @malloc(i64 %input_bytes)
  %input_ok = icmp ne ptr %input, null
  br i1 %input_ok, label %convert_input, label %fail

convert_input:                                    ; preds = %allocate_input
  %input_written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr %input, i32 %input_chars)
  %converted = icmp eq i32 %input_written, %input_chars
  br i1 %converted, label %terminate_input, label %input_fail

terminate_input:                                  ; preds = %convert_input
  %input_end = getelementptr i16, ptr %input, i64 %input_chars64
  store i16 0, ptr %input_end, align 2
  %has_prefix = icmp uge i64 %len, 4
  br i1 %has_prefix, label %inspect_prefix, label %measure_absolute

inspect_prefix:                                   ; preds = %terminate_input
  %prefix0 = load i8, ptr %path, align 1
  %prefix1_ptr = getelementptr i8, ptr %path, i64 1
  %prefix2_ptr = getelementptr i8, ptr %path, i64 2
  %prefix3_ptr = getelementptr i8, ptr %path, i64 3
  %prefix1 = load i8, ptr %prefix1_ptr, align 1
  %prefix2 = load i8, ptr %prefix2_ptr, align 1
  %prefix3 = load i8, ptr %prefix3_ptr, align 1
  %slash0 = icmp eq i8 %prefix0, 92
  %slash1 = icmp eq i8 %prefix1, 92
  %question1 = icmp eq i8 %prefix1, 63
  %question2 = icmp eq i8 %prefix2, 63
  %slash3 = icmp eq i8 %prefix3, 92
  %extended_second = or i1 %slash1, %question1
  %extended_front = and i1 %slash0, %extended_second
  %extended_back = and i1 %question2, %slash3
  %extended = and i1 %extended_front, %extended_back
  br i1 %extended, label %preserve_extended, label %measure_absolute

preserve_extended:                                ; preds = %inspect_prefix
  %preserved = call ptr @malloc(i64 %len)
  %preserved_ok = icmp ne ptr %preserved, null
  br i1 %preserved_ok, label %copy_extended, label %input_fail

copy_extended:                                    ; preds = %preserve_extended
  call void @llvm.memcpy.p0.p0.i64(ptr %preserved, ptr %path, i64 %len, i1 false)
  call void @free(ptr %input)
  %extended_result0 = insertvalue %sollang.path_absolute_result poison, ptr %preserved, 0
  %extended_result1 = insertvalue %sollang.path_absolute_result %extended_result0, i64 %len, 1
  %extended_result2 = insertvalue %sollang.path_absolute_result %extended_result1, i32 1, 2
  ret %sollang.path_absolute_result %extended_result2

measure_absolute:                                 ; preds = %inspect_prefix, %terminate_input
  %needed = call i32 @GetFullPathNameW(ptr %input, i32 0, ptr null, ptr null)
  %has_size = icmp ugt i32 %needed, 0
  br i1 %has_size, label %allocate_absolute, label %input_fail

allocate_absolute:                                ; preds = %measure_absolute
  %needed64 = zext i32 %needed to i64
  %absolute_bytes = mul i64 %needed64, 2
  %absolute = call ptr @malloc(i64 %absolute_bytes)
  %absolute_ok = icmp ne ptr %absolute, null
  br i1 %absolute_ok, label %resolve, label %input_fail

resolve:                                          ; preds = %allocate_absolute
  %written = call i32 @GetFullPathNameW(ptr %input, i32 %needed, ptr %absolute, ptr null)
  %resolved_nonempty = icmp ugt i32 %written, 0
  %resolved_fits = icmp ult i32 %written, %needed
  %resolved = and i1 %resolved_nonempty, %resolved_fits
  call void @free(ptr %input)
  br i1 %resolved, label %measure_output, label %absolute_fail

measure_output:                                   ; preds = %resolve
  %utf8_size = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %absolute, i32 %written, ptr null, i32 0, ptr null, ptr null)
  %output_nonempty = icmp sgt i32 %utf8_size, 0
  br i1 %output_nonempty, label %allocate_output, label %absolute_fail

allocate_output:                                  ; preds = %measure_output
  %utf8_size64 = zext i32 %utf8_size to i64
  %output = call ptr @malloc(i64 %utf8_size64)
  %output_ok = icmp ne ptr %output, null
  br i1 %output_ok, label %convert_output, label %absolute_fail

convert_output:                                   ; preds = %allocate_output
  %output_written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %absolute, i32 %written, ptr %output, i32 %utf8_size, ptr null, ptr null)
  %output_complete = icmp eq i32 %output_written, %utf8_size
  call void @free(ptr %absolute)
  br i1 %output_complete, label %success, label %output_fail

success:                                          ; preds = %convert_output
  %result0 = insertvalue %sollang.path_absolute_result poison, ptr %output, 0
  %result1 = insertvalue %sollang.path_absolute_result %result0, i64 %utf8_size64, 1
  %result2 = insertvalue %sollang.path_absolute_result %result1, i32 1, 2
  ret %sollang.path_absolute_result %result2

output_fail:                                      ; preds = %convert_output
  call void @free(ptr %output)
  br label %fail

absolute_fail:                                    ; preds = %allocate_output, %measure_output, %resolve
  call void @free(ptr %absolute)
  br label %fail

input_fail:                                       ; preds = %allocate_absolute, %measure_absolute, %preserve_extended, %convert_input
  call void @free(ptr %input)
  br label %fail

fail:                                             ; preds = %input_fail, %absolute_fail, %output_fail, %allocate_input, %measure, %validated, %scan, %entry
  ret %sollang.path_absolute_result zeroinitializer
}

define internal i32 @sollang_platform_create_directory(ptr %path, i64 %len, i32 %style) {
entry:
  %style_ok = icmp eq i32 %style, 1
  %length_ok = icmp ule i64 %len, 32766
  %valid = and i1 %style_ok, %length_ok
  br i1 %valid, label %prepare, label %fail

prepare:                                          ; preds = %entry
  %capacity = add i64 %len, 1
  %buffer_size = mul i64 %capacity, 2
  %buffer = call ptr @malloc(i64 %buffer_size)
  %buffer_ok = icmp ne ptr %buffer, null
  br i1 %buffer_ok, label %convert, label %fail

convert:                                          ; preds = %prepare
  %capacity32 = trunc i64 %capacity to i32
  %converted = call i32 @sollang_windows_utf8_path(ptr %path, i64 %len, ptr %buffer, i32 %capacity32)
  %path_ok = icmp ne i32 %converted, 0
  br i1 %path_ok, label %create, label %fail_free

create:                                           ; preds = %convert
  %created = call i32 @CreateDirectoryW(ptr %buffer, ptr null)
  %created_ok = icmp ne i32 %created, 0
  br i1 %created_ok, label %success_free, label %inspect_existing

inspect_existing:                                 ; preds = %create
  %attributes = call i32 @GetFileAttributesW(ptr %buffer)
  %attributes_valid = icmp ne i32 %attributes, -1
  %directory_bits = and i32 %attributes, 16
  %is_directory = icmp ne i32 %directory_bits, 0
  %exists_as_directory = and i1 %attributes_valid, %is_directory
  br i1 %exists_as_directory, label %success_free, label %fail_free

success_free:                                     ; preds = %inspect_existing, %create
  call void @free(ptr %buffer)
  ret i32 1

fail_free:                                        ; preds = %inspect_existing, %convert
  call void @free(ptr %buffer)
  br label %fail

fail:                                             ; preds = %fail_free, %prepare, %entry
  ret i32 0
}

define internal %sollang.directory_result @sollang_platform_read_directory(ptr %path, i64 %len, i32 %style) {
entry:
  %style_ok = icmp eq i32 %style, 1
  %length_ok = icmp ule i64 %len, 32764
  %valid = and i1 %style_ok, %length_ok
  br i1 %valid, label %prepare, label %fail

prepare:                                          ; preds = %entry
  %buffer_size = add i64 %len, 3
  %pattern = call ptr @malloc(i64 %buffer_size)
  %pattern_ok = icmp ne ptr %pattern, null
  br i1 %pattern_ok, label %copy_path, label %fail

copy_path:                                        ; preds = %prepare
  call void @sollang_directory_copy(ptr %pattern, ptr %path, i64 %len)
  %has_path = icmp ugt i64 %len, 0
  br i1 %has_path, label %inspect_last, label %append_separator

inspect_last:                                     ; preds = %copy_path
  %last_index = sub i64 %len, 1
  %last_ptr = getelementptr i8, ptr %pattern, i64 %last_index
  %last = load i8, ptr %last_ptr, align 1
  %last_slash = icmp eq i8 %last, 47
  %last_backslash = icmp eq i8 %last, 92
  %has_separator = or i1 %last_slash, %last_backslash
  br i1 %has_separator, label %append_star, label %append_separator

append_separator:                                 ; preds = %inspect_last, %copy_path
  %separator_ptr = getelementptr i8, ptr %pattern, i64 %len
  store i8 92, ptr %separator_ptr, align 1
  %separator_star_index = add i64 %len, 1
  %separator_star_ptr = getelementptr i8, ptr %pattern, i64 %separator_star_index
  store i8 42, ptr %separator_star_ptr, align 1
  %separator_zero_index = add i64 %len, 2
  %separator_zero_ptr = getelementptr i8, ptr %pattern, i64 %separator_zero_index
  store i8 0, ptr %separator_zero_ptr, align 1
  br label %open

append_star:                                      ; preds = %inspect_last
  %star_ptr = getelementptr i8, ptr %pattern, i64 %len
  store i8 42, ptr %star_ptr, align 1
  %star_zero_index = add i64 %len, 1
  %star_zero_ptr = getelementptr i8, ptr %pattern, i64 %star_zero_index
  store i8 0, ptr %star_zero_ptr, align 1
  br label %open

open:                                             ; preds = %append_star, %append_separator
  %pattern_extra = phi i64 [ 2, %append_separator ], [ 1, %append_star ]
  %pattern_capacity = add i64 %len, 3
  %wide_bytes = mul i64 %pattern_capacity, 2
  %wide_pattern = call ptr @malloc(i64 %wide_bytes)
  %wide_ok = icmp ne ptr %wide_pattern, null
  br i1 %wide_ok, label %convert_pattern, label %pattern_fail

convert_pattern:                                  ; preds = %open
  %actual_pattern_length = add i64 %len, %pattern_extra
  %capacity32 = trunc i64 %pattern_capacity to i32
  %converted = call i32 @sollang_windows_utf8_path(ptr %pattern, i64 %actual_pattern_length, ptr %wide_pattern, i32 %capacity32)
  call void @free(ptr %pattern)
  %converted_ok = icmp ne i32 %converted, 0
  br i1 %converted_ok, label %open_wide, label %wide_fail

open_wide:                                        ; preds = %convert_pattern
  %find_data = alloca [592 x i8], align 8
  %utf8_name = alloca [1040 x i8], align 1
  %handle = call ptr @FindFirstFileW(ptr %wide_pattern, ptr %find_data)
  call void @free(ptr %wide_pattern)
  %invalid = icmp eq ptr %handle, inttoptr (i64 -1 to ptr)
  br i1 %invalid, label %fail, label %enumerate

pattern_fail:                                     ; preds = %open
  call void @free(ptr %pattern)
  br label %fail

wide_fail:                                        ; preds = %convert_pattern
  call void @free(ptr %wide_pattern)
  br label %fail

enumerate:                                        ; preds = %advance, %open_wide
  %head = phi ptr [ null, %open_wide ], [ %advanced_head, %advance ]
  %count = phi i64 [ 0, %open_wide ], [ %advanced_count, %advance ]
  %total = phi i64 [ 0, %open_wide ], [ %advanced_total, %advance ]
  %name = getelementptr i8, ptr %find_data, i64 44
  br label %name_length

name_length:                                      ; preds = %name_continue, %enumerate
  %name_index = phi i64 [ 0, %enumerate ], [ %name_next, %name_continue ]
  %name_slot = getelementptr i16, ptr %name, i64 %name_index
  %name_unit = load i16, ptr %name_slot, align 2
  %name_end = icmp eq i16 %name_unit, 0
  %name_limit = icmp eq i64 %name_index, 259
  %name_done = or i1 %name_end, %name_limit
  br i1 %name_done, label %inspect_name, label %name_continue

name_continue:                                    ; preds = %name_length
  %name_next = add i64 %name_index, 1
  br label %name_length

inspect_name:                                     ; preds = %name_length
  %first = load i16, ptr %name, align 2
  %second_ptr = getelementptr i16, ptr %name, i64 1
  %second = load i16, ptr %second_ptr, align 2
  %length_one = icmp eq i64 %name_index, 1
  %length_two = icmp eq i64 %name_index, 2
  %first_dot = icmp eq i16 %first, 46
  %second_dot = icmp eq i16 %second, 46
  %dot = and i1 %length_one, %first_dot
  %two_dots = and i1 %first_dot, %second_dot
  %dotdot = and i1 %length_two, %two_dots
  %special = or i1 %dot, %dotdot
  br i1 %special, label %skip, label %convert_name

convert_name:                                     ; preds = %inspect_name
  %name_index32 = trunc i64 %name_index to i32
  %utf8_length32 = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %name, i32 %name_index32, ptr %utf8_name, i32 1040, ptr null, ptr null)
  %name_valid = icmp sgt i32 %utf8_length32, 0
  br i1 %name_valid, label %allocate_node, label %conversion_failed

allocate_node:                                    ; preds = %convert_name
  %utf8_length = zext i32 %utf8_length32 to i64
  %node_size = add i64 %utf8_length, 24
  %node = call ptr @malloc(i64 %node_size)
  %node_ok = icmp ne ptr %node, null
  br i1 %node_ok, label %initialize_node, label %allocation_failed

initialize_node:                                  ; preds = %allocate_node
  %node_next = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 0
  store ptr null, ptr %node_next, align 8
  %node_length = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 1
  store i64 %utf8_length, ptr %node_length, align 8
  %attributes = load i32, ptr %find_data, align 4
  %reparse_bits = and i32 %attributes, 1024
  %is_reparse = icmp ne i32 %reparse_bits, 0
  %directory_bits = and i32 %attributes, 16
  %is_directory = icmp ne i32 %directory_bits, 0
  %ordinary_kind = select i1 %is_directory, i8 1, i8 0
  %kind = select i1 %is_reparse, i8 2, i8 %ordinary_kind
  %node_kind = getelementptr %sollang.directory_node, ptr %node, i32 0, i32 2
  store i8 %kind, ptr %node_kind, align 1
  %node_name = getelementptr i8, ptr %node, i64 24
  call void @sollang_directory_copy(ptr %node_name, ptr %utf8_name, i64 %utf8_length)
  %inserted_head = call ptr @sollang_directory_insert_sorted(ptr %head, ptr %node)
  %inserted_count = add i64 %count, 1
  %record_size = add i64 %utf8_length, 5
  %inserted_total = add i64 %total, %record_size
  br label %advance

skip:                                             ; preds = %inspect_name
  br label %advance

advance:                                          ; preds = %skip, %initialize_node
  %advanced_head = phi ptr [ %head, %skip ], [ %inserted_head, %initialize_node ]
  %advanced_count = phi i64 [ %count, %skip ], [ %inserted_count, %initialize_node ]
  %advanced_total = phi i64 [ %total, %skip ], [ %inserted_total, %initialize_node ]
  call void @SetLastError(i32 0)
  %has_next_status = call i32 @FindNextFileW(ptr %handle, ptr %find_data)
  %has_next = icmp ne i32 %has_next_status, 0
  br i1 %has_next, label %enumerate, label %finish_enumeration

finish_enumeration:                               ; preds = %advance
  %last_error = call i32 @GetLastError()
  %normal_end = icmp eq i32 %last_error, 18
  br i1 %normal_end, label %close_success, label %enumeration_failed

close_success:                                    ; preds = %finish_enumeration
  %closed = call i32 @FindClose(ptr %handle)
  %raw = call ptr @sollang_directory_serialize(ptr %advanced_head, i64 %advanced_total)
  %has_payload = icmp ugt i64 %advanced_total, 0
  %raw_missing = icmp eq ptr %raw, null
  %serialization_failed = and i1 %has_payload, %raw_missing
  br i1 %serialization_failed, label %fail, label %success

success:                                          ; preds = %close_success
  %success0 = insertvalue %sollang.directory_result poison, ptr %raw, 0
  %success1 = insertvalue %sollang.directory_result %success0, i64 %advanced_total, 1
  %success2 = insertvalue %sollang.directory_result %success1, i64 %advanced_count, 2
  %success3 = insertvalue %sollang.directory_result %success2, i32 1, 3
  ret %sollang.directory_result %success3

allocation_failed:                                ; preds = %allocate_node
  call void @sollang_directory_free_nodes(ptr %head)
  %allocation_closed = call i32 @FindClose(ptr %handle)
  br label %fail

conversion_failed:                                ; preds = %convert_name
  call void @sollang_directory_free_nodes(ptr %head)
  %conversion_closed = call i32 @FindClose(ptr %handle)
  br label %fail

enumeration_failed:                               ; preds = %finish_enumeration
  call void @sollang_directory_free_nodes(ptr %advanced_head)
  %failure_closed = call i32 @FindClose(ptr %handle)
  br label %fail

fail:                                             ; preds = %enumeration_failed, %conversion_failed, %allocation_failed, %close_success, %wide_fail, %pattern_fail, %open_wide, %prepare, %entry
  %failure0 = insertvalue %sollang.directory_result poison, ptr null, 0
  %failure1 = insertvalue %sollang.directory_result %failure0, i64 0, 1
  %failure2 = insertvalue %sollang.directory_result %failure1, i64 0, 2
  %failure3 = insertvalue %sollang.directory_result %failure2, i32 0, 3
  ret %sollang.directory_result %failure3
}

define internal %sollang.path_query_result @sollang_platform_query_path(ptr %path, i64 %len, i32 %style) {
entry:
  %style_ok = icmp eq i32 %style, 1
  %len32 = trunc i64 %len to i32
  %len_roundtrip = zext i32 %len32 to i64
  %length_ok = icmp eq i64 %len_roundtrip, %len
  %input_ok = and i1 %style_ok, %length_ok
  br i1 %input_ok, label %measure_input, label %fail

measure_input:                                    ; preds = %entry
  %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr null, i32 0)
  %wide_ok = icmp sgt i32 %wide_chars, 0
  br i1 %wide_ok, label %allocate_input, label %fail

allocate_input:                                   ; preds = %measure_input
  %wide_chars64 = zext i32 %wide_chars to i64
  %wide_with_zero = add i64 %wide_chars64, 1
  %wide_bytes = mul i64 %wide_with_zero, 2
  %wide_input = call ptr @malloc(i64 %wide_bytes)
  %wide_input_ok = icmp ne ptr %wide_input, null
  br i1 %wide_input_ok, label %convert_input, label %fail

convert_input:                                    ; preds = %allocate_input
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %path, i32 %len32, ptr %wide_input, i32 %wide_chars)
  %converted_ok = icmp eq i32 %converted, %wide_chars
  br i1 %converted_ok, label %terminate_input, label %input_fail

terminate_input:                                  ; preds = %convert_input
  %wide_zero = getelementptr i16, ptr %wide_input, i64 %wide_chars64
  store i16 0, ptr %wide_zero, align 2
  %handle = call ptr @CreateFileW(ptr %wide_input, i32 0, i32 7, ptr null, i32 3, i32 33554432, ptr null)
  call void @free(ptr %wide_input)
  %invalid_handle = inttoptr i64 -1 to ptr
  %handle_ok = icmp ne ptr %handle, %invalid_handle
  br i1 %handle_ok, label %measure_canonical, label %fail

measure_canonical:                                ; preds = %terminate_input
  %canonical_chars = call i32 @GetFinalPathNameByHandleW(ptr %handle, ptr null, i32 0, i32 0)
  %canonical_ok = icmp sgt i32 %canonical_chars, 0
  br i1 %canonical_ok, label %allocate_canonical, label %handle_fail

allocate_canonical:                               ; preds = %measure_canonical
  %canonical_capacity = add i32 %canonical_chars, 1
  %canonical_capacity64 = zext i32 %canonical_capacity to i64
  %canonical_wide_bytes = mul i64 %canonical_capacity64, 2
  %canonical_wide = call ptr @malloc(i64 %canonical_wide_bytes)
  %canonical_wide_ok = icmp ne ptr %canonical_wide, null
  br i1 %canonical_wide_ok, label %read_canonical, label %handle_fail

read_canonical:                                   ; preds = %allocate_canonical
  %canonical_written = call i32 @GetFinalPathNameByHandleW(ptr %handle, ptr %canonical_wide, i32 %canonical_capacity, i32 0)
  %canonical_written_positive = icmp sgt i32 %canonical_written, 0
  %canonical_written_fits = icmp ule i32 %canonical_written, %canonical_chars
  %canonical_written_ok = and i1 %canonical_written_positive, %canonical_written_fits
  br i1 %canonical_written_ok, label %metadata, label %canonical_wide_fail

metadata:                                         ; preds = %read_canonical
  %information = alloca [52 x i8], align 8
  %information_status = call i32 @GetFileInformationByHandle(ptr %handle, ptr %information)
  %information_ok = icmp ne i32 %information_status, 0
  br i1 %information_ok, label %measure_utf8, label %canonical_wide_fail

measure_utf8:                                     ; preds = %metadata
  %utf8_bytes = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %canonical_wide, i32 %canonical_written, ptr null, i32 0, ptr null, ptr null)
  %utf8_ok = icmp sgt i32 %utf8_bytes, 0
  br i1 %utf8_ok, label %allocate_utf8, label %canonical_wide_fail

allocate_utf8:                                    ; preds = %measure_utf8
  %utf8_bytes64 = zext i32 %utf8_bytes to i64
  %canonical_utf8 = call ptr @malloc(i64 %utf8_bytes64)
  %canonical_utf8_ok = icmp ne ptr %canonical_utf8, null
  br i1 %canonical_utf8_ok, label %convert_canonical, label %canonical_wide_fail

convert_canonical:                                ; preds = %allocate_utf8
  %utf8_written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %canonical_wide, i32 %canonical_written, ptr %canonical_utf8, i32 %utf8_bytes, ptr null, ptr null)
  %utf8_written_ok = icmp eq i32 %utf8_written, %utf8_bytes
  br i1 %utf8_written_ok, label %success, label %utf8_fail

success:                                          ; preds = %convert_canonical
  %attributes = load i32, ptr %information, align 4
  %directory_bits = and i32 %attributes, 16
  %is_directory = icmp ne i32 %directory_bits, 0
  %kind = select i1 %is_directory, i8 1, i8 0
  %size_high_ptr = getelementptr i8, ptr %information, i64 32
  %size_high32 = load i32, ptr %size_high_ptr, align 4
  %size_low_ptr = getelementptr i8, ptr %information, i64 36
  %size_low32 = load i32, ptr %size_low_ptr, align 4
  %size_high = zext i32 %size_high32 to i64
  %size_low = zext i32 %size_low32 to i64
  %size_shifted = shl i64 %size_high, 32
  %size = or i64 %size_shifted, %size_low
  %time_low_ptr = getelementptr i8, ptr %information, i64 20
  %time_low32 = load i32, ptr %time_low_ptr, align 4
  %time_high_ptr = getelementptr i8, ptr %information, i64 24
  %time_high32 = load i32, ptr %time_high_ptr, align 4
  %time_low = zext i32 %time_low32 to i64
  %time_high = zext i32 %time_high32 to i64
  %time_shifted = shl i64 %time_high, 32
  %file_time = or i64 %time_shifted, %time_low
  %unix_ticks = sub i64 %file_time, 116444736000000000
  %modified_nanos = mul i64 %unix_ticks, 100
  call void @free(ptr %canonical_wide)
  %closed = call i32 @CloseHandle(ptr %handle)
  %result0 = insertvalue %sollang.path_query_result poison, ptr %canonical_utf8, 0
  %result1 = insertvalue %sollang.path_query_result %result0, i64 %utf8_bytes64, 1
  %result2 = insertvalue %sollang.path_query_result %result1, i8 %kind, 2
  %result3 = insertvalue %sollang.path_query_result %result2, i64 %size, 3
  %result4 = insertvalue %sollang.path_query_result %result3, i64 %modified_nanos, 4
  %result5 = insertvalue %sollang.path_query_result %result4, i32 1, 5
  ret %sollang.path_query_result %result5

utf8_fail:                                        ; preds = %convert_canonical
  call void @free(ptr %canonical_utf8)
  br label %canonical_wide_fail

canonical_wide_fail:                              ; preds = %utf8_fail, %allocate_utf8, %measure_utf8, %metadata, %read_canonical
  call void @free(ptr %canonical_wide)
  br label %handle_fail

handle_fail:                                      ; preds = %canonical_wide_fail, %allocate_canonical, %measure_canonical
  %failed_closed = call i32 @CloseHandle(ptr %handle)
  br label %fail

input_fail:                                       ; preds = %convert_input
  call void @free(ptr %wide_input)
  br label %fail

fail:                                             ; preds = %input_fail, %handle_fail, %terminate_input, %allocate_input, %measure_input, %entry
  %failure_path0 = insertvalue %sollang.path_query_result poison, ptr null, 0
  %failure_path1 = insertvalue %sollang.path_query_result %failure_path0, i64 0, 1
  %failure_path2 = insertvalue %sollang.path_query_result %failure_path1, i8 3, 2
  %failure_path3 = insertvalue %sollang.path_query_result %failure_path2, i64 0, 3
  %failure_path4 = insertvalue %sollang.path_query_result %failure_path3, i64 0, 4
  %failure_path5 = insertvalue %sollang.path_query_result %failure_path4, i32 0, 5
  ret %sollang.path_query_result %failure_path5
}

define internal i32 @sollang_windows_utf8_path(ptr %data, i64 %length, ptr %wide, i32 %capacity) {
entry:
  %positive = icmp ugt i64 %length, 0
  %fits_i32 = icmp ule i64 %length, 2147483647
  %length_valid = and i1 %positive, %fits_i32
  br i1 %length_valid, label %check, label %failure

check:                                            ; preds = %advance, %entry
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %convert, label %inspect

inspect:                                          ; preds = %check
  %byte_ptr = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %failure, label %advance

advance:                                          ; preds = %inspect
  %next = add i64 %index, 1
  br label %check

convert:                                          ; preds = %check
  %length32 = trunc i64 %length to i32
  %room = sub i32 %capacity, 1
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length32, ptr %wide, i32 %room)
  %converted_ok = icmp sgt i32 %converted, 0
  br i1 %converted_ok, label %terminate, label %failure

terminate:                                        ; preds = %convert
  %zero = getelementptr i16, ptr %wide, i32 %converted
  store i16 0, ptr %zero, align 2
  ret i32 1

failure:                                          ; preds = %convert, %inspect, %entry
  ret i32 0
}

declare dllimport i32 @ReadFile(ptr, ptr, i32, ptr, ptr)

declare dllimport i32 @GetOverlappedResult(ptr, ptr, ptr, i32)

declare dllimport i32 @FlushFileBuffers(ptr)

declare dllimport i32 @MoveFileExW(ptr, ptr, i32)

define internal i32 @sollang_platform_create_exclusive_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %copy, label %failure

copy:                                             ; preds = %entry
  %valid = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %valid, 0
  br i1 %valid_path, label %create, label %failure

create:                                           ; preds = %copy
  %handle = call ptr @CreateFileW(ptr %buffer_ptr, i32 1073741824, i32 0, ptr null, i32 1, i32 128, ptr null)
  %handle_value = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_value, -1
  br i1 %invalid, label %classify, label %close

classify:                                         ; preds = %create
  %error = call i32 @GetLastError()
  %file_exists = icmp eq i32 %error, 80
  %already_exists = icmp eq i32 %error, 183
  %exists = or i1 %file_exists, %already_exists
  %status = select i1 %exists, i32 0, i32 -1
  ret i32 %status

close:                                            ; preds = %create
  %closed = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %closed, 0
  %close_status = select i1 %close_ok, i32 1, i32 -1
  ret i32 %close_status

failure:                                          ; preds = %copy, %entry
  ret i32 -1
}

define internal i32 @sollang_platform_remove_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %copy, label %failure

copy:                                             ; preds = %entry
  %valid = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %valid, 0
  br i1 %valid_path, label %remove, label %failure

remove:                                           ; preds = %copy
  %removed = call i32 @DeleteFileW(ptr %buffer_ptr)
  %success = icmp ne i32 %removed, 0
  br i1 %success, label %removed_file, label %classify

classify:                                         ; preds = %remove
  %error = call i32 @GetLastError()
  %file_missing = icmp eq i32 %error, 2
  %path_missing = icmp eq i32 %error, 3
  %missing = or i1 %file_missing, %path_missing
  %status = select i1 %missing, i32 0, i32 -1
  ret i32 %status

removed_file:                                     ; preds = %remove
  ret i32 1

failure:                                          ; preds = %copy, %entry
  ret i32 -1
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %convert, label %failure

convert:                                          ; preds = %entry
  %copied = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %copied, 0
  br i1 %valid_path, label %open, label %failure

open:                                             ; preds = %convert
  %handle = call ptr @CreateFileW(ptr %buffer_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 1073741952, ptr null)
  %handle_value = ptrtoint ptr %handle to i64
  %valid_handle = icmp ne i64 %handle_value, -1
  br i1 %valid_handle, label %success, label %failure

success:                                          ; preds = %open
  %result0 = insertvalue %sollang.file_handle_result poison, i64 %handle_value, 0
  %result1 = insertvalue %sollang.file_handle_result %result0, i32 1, 1
  ret %sollang.file_handle_result %result1

failure:                                          ; preds = %open, %convert, %entry
  %failure0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %failure1 = insertvalue %sollang.file_handle_result %failure0, i32 0, 1
  ret %sollang.file_handle_result %failure1
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %path, i64 %length) {
entry:
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %fits = icmp ule i64 %length, 259
  br i1 %fits, label %convert, label %failure

convert:                                          ; preds = %entry
  %copied = call i32 @sollang_windows_utf8_path(ptr %path, i64 %length, ptr %buffer_ptr, i32 260)
  %valid_path = icmp ne i32 %copied, 0
  br i1 %valid_path, label %open, label %failure

open:                                             ; preds = %convert
  %handle = call ptr @CreateFileW(ptr %buffer_ptr, i32 1073741824, i32 1, ptr null, i32 2, i32 1073741952, ptr null)
  %handle_value = ptrtoint ptr %handle to i64
  %valid_handle = icmp ne i64 %handle_value, -1
  br i1 %valid_handle, label %success, label %failure

success:                                          ; preds = %open
  %result0 = insertvalue %sollang.file_handle_result poison, i64 %handle_value, 0
  %result1 = insertvalue %sollang.file_handle_result %result0, i32 1, 1
  ret %sollang.file_handle_result %result1

failure:                                          ; preds = %open, %convert, %entry
  %failure0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %failure1 = insertvalue %sollang.file_handle_result %failure0, i32 0, 1
  ret %sollang.file_handle_result %failure1
}

define internal %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %handle_value, ptr %data, i64 %length, i64 %offset) {
entry:
  %valid_handle = icmp ne i64 %handle_value, -1
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %fits = icmp ule i64 %length, 4294967295
  %ready0 = and i1 %valid_handle, %valid_offset
  %ready = and i1 %ready0, %fits
  br i1 %ready, label %read, label %failure

read:                                             ; preds = %entry
  %handle = inttoptr i64 %handle_value to ptr
  %overlapped = alloca [32 x i8], align 8
  store [32 x i8] zeroinitializer, ptr %overlapped, align 8
  %offset_low_slot = getelementptr i8, ptr %overlapped, i64 16
  %offset_low = trunc i64 %offset to i32
  store i32 %offset_low, ptr %offset_low_slot, align 4
  %offset_high_slot = getelementptr i8, ptr %overlapped, i64 20
  %offset_shifted = lshr i64 %offset, 32
  %offset_high = trunc i64 %offset_shifted to i32
  store i32 %offset_high, ptr %offset_high_slot, align 4
  %count_slot = alloca i32, align 4
  store i32 0, ptr %count_slot, align 4
  %length32 = trunc i64 %length to i32
  %started = call i32 @ReadFile(ptr %handle, ptr %data, i32 %length32, ptr null, ptr %overlapped)
  %completed = call i32 @GetOverlappedResult(ptr %handle, ptr %overlapped, ptr %count_slot, i32 1)
  %ok = icmp ne i32 %completed, 0
  br i1 %ok, label %success, label %classify_failure

classify_failure:                                 ; preds = %read
  %error = call i32 @GetLastError()
  %eof = icmp eq i32 %error, 38
  br i1 %eof, label %success, label %failure

success:                                          ; preds = %classify_failure, %read
  %count32 = load i32, ptr %count_slot, align 4
  %count = zext i32 %count32 to i64
  %result0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %result1 = insertvalue %sollang.file_count_result %result0, i32 1, 1
  ret %sollang.file_count_result %result1

failure:                                          ; preds = %classify_failure, %entry
  %failure0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %failure1 = insertvalue %sollang.file_count_result %failure0, i32 0, 1
  ret %sollang.file_count_result %failure1
}

define internal %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %handle_value, ptr %data, i64 %length, i64 %offset) {
entry:
  %valid_handle = icmp ne i64 %handle_value, -1
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %fits = icmp ule i64 %length, 4294967295
  %ready0 = and i1 %valid_handle, %valid_offset
  %ready = and i1 %ready0, %fits
  br i1 %ready, label %write, label %failure

write:                                            ; preds = %entry
  %handle = inttoptr i64 %handle_value to ptr
  %overlapped = alloca [32 x i8], align 8
  store [32 x i8] zeroinitializer, ptr %overlapped, align 8
  %offset_low_slot = getelementptr i8, ptr %overlapped, i64 16
  %offset_low = trunc i64 %offset to i32
  store i32 %offset_low, ptr %offset_low_slot, align 4
  %offset_high_slot = getelementptr i8, ptr %overlapped, i64 20
  %offset_shifted = lshr i64 %offset, 32
  %offset_high = trunc i64 %offset_shifted to i32
  store i32 %offset_high, ptr %offset_high_slot, align 4
  %count_slot = alloca i32, align 4
  store i32 0, ptr %count_slot, align 4
  %length32 = trunc i64 %length to i32
  %started = call i32 @WriteFile(ptr %handle, ptr %data, i32 %length32, ptr null, ptr %overlapped)
  %completed = call i32 @GetOverlappedResult(ptr %handle, ptr %overlapped, ptr %count_slot, i32 1)
  %ok = icmp ne i32 %completed, 0
  br i1 %ok, label %success, label %failure

success:                                          ; preds = %write
  %count32 = load i32, ptr %count_slot, align 4
  %count = zext i32 %count32 to i64
  %result0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %result1 = insertvalue %sollang.file_count_result %result0, i32 1, 1
  ret %sollang.file_count_result %result1

failure:                                          ; preds = %write, %entry
  %failure0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %failure1 = insertvalue %sollang.file_count_result %failure0, i32 0, 1
  ret %sollang.file_count_result %failure1
}

define internal i32 @sollang_platform_sync_owned_file(i64 %handle_value) {
entry:
  %valid = icmp ne i64 %handle_value, -1
  br i1 %valid, label %sync, label %failure

sync:                                             ; preds = %entry
  %handle = inttoptr i64 %handle_value to ptr
  %result = call i32 @FlushFileBuffers(ptr %handle)
  ret i32 %result

failure:                                          ; preds = %entry
  ret i32 0
}

define internal void @sollang_platform_close_owned_file(i64 %handle_value) {
entry:
  %valid = icmp ne i64 %handle_value, -1
  br i1 %valid, label %close, label %done

close:                                            ; preds = %entry
  %handle = inttoptr i64 %handle_value to ptr
  %ignored = call i32 @CloseHandle(ptr %handle)
  br label %done

done:                                             ; preds = %close, %entry
  ret void
}

define internal i32 @sollang_platform_atomic_replace_file(ptr %temporary, i64 %temporary_length, ptr %destination, i64 %destination_length) {
entry:
  %temporary_buffer = alloca [260 x i16], align 2
  %temporary_ptr = getelementptr inbounds [260 x i16], ptr %temporary_buffer, i64 0, i64 0
  %temporary_fits = icmp ule i64 %temporary_length, 259
  br i1 %temporary_fits, label %convert_temporary, label %failure

convert_temporary:                                ; preds = %entry
  %temporary_copied = call i32 @sollang_windows_utf8_path(ptr %temporary, i64 %temporary_length, ptr %temporary_ptr, i32 260)
  %temporary_ok = icmp ne i32 %temporary_copied, 0
  br i1 %temporary_ok, label %destination_path, label %failure

destination_path:                                 ; preds = %convert_temporary
  %destination_buffer = alloca [260 x i16], align 2
  %destination_ptr = getelementptr inbounds [260 x i16], ptr %destination_buffer, i64 0, i64 0
  %destination_fits = icmp ule i64 %destination_length, 259
  br i1 %destination_fits, label %convert_destination, label %failure

convert_destination:                              ; preds = %destination_path
  %destination_copied = call i32 @sollang_windows_utf8_path(ptr %destination, i64 %destination_length, ptr %destination_ptr, i32 260)
  %destination_ok = icmp ne i32 %destination_copied, 0
  br i1 %destination_ok, label %replace, label %failure

replace:                                          ; preds = %convert_destination
  %result = call i32 @MoveFileExW(ptr %temporary_ptr, ptr %destination_ptr, i32 9)
  ret i32 %result

failure:                                          ; preds = %convert_destination, %destination_path, %convert_temporary, %entry
  ret i32 0
}

define internal void @sollang_binary_open_writer(ptr %path, i64 %length) {
entry:
  %old = load i64, ptr @sollang_binary_writer_handle, align 8
  call void @sollang_platform_close_owned_file(i64 %old)
  store i64 -1, ptr @sollang_binary_writer_handle, align 8
  %opened = call %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %path, i64 %length)
  %handle = extractvalue %sollang.file_handle_result %opened, 0
  %status = extractvalue %sollang.file_handle_result %opened, 1
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %ready, label %failure

ready:                                            ; preds = %entry
  store i64 %handle, ptr @sollang_binary_writer_handle, align 8
  store i64 0, ptr @sollang_binary_writer_offset, align 8
  ret void

failure:                                          ; preds = %entry
  call void @llvm.trap()
  unreachable
}

define internal void @sollang_binary_write(ptr %data, i64 %length) {
entry:
  %handle = load i64, ptr @sollang_binary_writer_handle, align 8
  %valid = icmp ne i64 %handle, -1
  br i1 %valid, label %write, label %failure

write:                                            ; preds = %entry
  %offset = load i64, ptr @sollang_binary_writer_offset, align 8
  %result = call %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %handle, ptr %data, i64 %length, i64 %offset)
  %count = extractvalue %sollang.file_count_result %result, 0
  %status = extractvalue %sollang.file_count_result %result, 1
  %called = icmp ne i32 %status, 0
  %full = icmp eq i64 %count, %length
  %ok = and i1 %called, %full
  br i1 %ok, label %advance, label %failure

advance:                                          ; preds = %write
  %next = add i64 %offset, %count
  store i64 %next, ptr @sollang_binary_writer_offset, align 8
  ret void

failure:                                          ; preds = %write, %entry
  call void @llvm.trap()
  unreachable
}

define internal void @sollang_binary_close_writer() {
entry:
  %handle = load i64, ptr @sollang_binary_writer_handle, align 8
  store i64 -1, ptr @sollang_binary_writer_handle, align 8
  store i64 0, ptr @sollang_binary_writer_offset, align 8
  %valid = icmp ne i64 %handle, -1
  br i1 %valid, label %sync, label %done

sync:                                             ; preds = %entry
  %status = call i32 @sollang_platform_sync_owned_file(i64 %handle)
  call void @sollang_platform_close_owned_file(i64 %handle)
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %done, label %failure

failure:                                          ; preds = %sync
  call void @llvm.trap()
  unreachable

done:                                             ; preds = %sync, %entry
  ret void
}

define internal void @sollang_binary_open_reader(ptr %path, i64 %length) {
entry:
  %old = load i64, ptr @sollang_binary_reader_handle, align 8
  call void @sollang_platform_close_owned_file(i64 %old)
  store i64 -1, ptr @sollang_binary_reader_handle, align 8
  %opened = call %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %path, i64 %length)
  %handle = extractvalue %sollang.file_handle_result %opened, 0
  %status = extractvalue %sollang.file_handle_result %opened, 1
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %ready, label %failure

ready:                                            ; preds = %entry
  store i64 %handle, ptr @sollang_binary_reader_handle, align 8
  store i64 0, ptr @sollang_binary_reader_offset, align 8
  ret void

failure:                                          ; preds = %entry
  call void @llvm.trap()
  unreachable
}

define internal %sollang.file_count_result @sollang_binary_read(ptr %data, i64 %length) {
entry:
  %handle = load i64, ptr @sollang_binary_reader_handle, align 8
  %offset = load i64, ptr @sollang_binary_reader_offset, align 8
  %valid = icmp ne i64 %handle, -1
  br i1 %valid, label %read, label %failure

read:                                             ; preds = %entry
  %result = call %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %handle, ptr %data, i64 %length, i64 %offset)
  %count = extractvalue %sollang.file_count_result %result, 0
  %next = add i64 %offset, %count
  store i64 %next, ptr @sollang_binary_reader_offset, align 8
  ret %sollang.file_count_result %result

failure:                                          ; preds = %entry
  %error0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %error1 = insertvalue %sollang.file_count_result %error0, i32 0, 1
  ret %sollang.file_count_result %error1
}

define internal void @sollang_binary_close_reader() {
entry:
  %handle = load i64, ptr @sollang_binary_reader_handle, align 8
  store i64 -1, ptr @sollang_binary_reader_handle, align 8
  store i64 0, ptr @sollang_binary_reader_offset, align 8
  call void @sollang_platform_close_owned_file(i64 %handle)
  ret void
}

define internal i32 @sollang_legacy_int_copy_text_to_c_path(ptr %data, i64 %len, ptr %out) {
entry:
  %too_long = icmp ugt i64 %len, 259
  br i1 %too_long, label %fail, label %copy

copy:                                             ; preds = %copy_body, %entry
  %i = phi i64 [ 0, %entry ], [ %next, %copy_body ]
  %done = icmp eq i64 %i, %len
  br i1 %done, label %nul, label %copy_body

copy_body:                                        ; preds = %copy
  %src = getelementptr i8, ptr %data, i64 %i
  %ch = load i8, ptr %src, align 1
  %dst = getelementptr i8, ptr %out, i64 %i
  store i8 %ch, ptr %dst, align 1
  %next = add i64 %i, 1
  br label %copy

nul:                                              ; preds = %copy
  %nul_ptr = getelementptr i8, ptr %out, i64 %len
  store i8 0, ptr %nul_ptr, align 1
  ret i32 1

fail:                                             ; preds = %entry
  ret i32 0
}

define internal i32 @sollang_legacy_int_open_write_i64_file(ptr %path, i64 %len) {
entry:
  store i64 0, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %ok = call i32 @sollang_legacy_int_platform_open_write_file(ptr %path, i64 %len)
  ret i32 %ok
}

define internal i32 @sollang_legacy_int_flush_i64_file() {
entry:
  %count = load i64, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %success, label %flush

flush:                                            ; preds = %entry
  %bytes = mul i64 %count, 8
  %ok = call i32 @sollang_legacy_int_platform_write_file_bytes(ptr @sollang_legacy_int_writer_buffer, i64 %bytes)
  %is_ok = icmp ne i32 %ok, 0
  br i1 %is_ok, label %reset, label %fail

reset:                                            ; preds = %flush
  store i64 0, ptr @sollang_legacy_int_writer_buffer_count, align 8
  br label %success

success:                                          ; preds = %reset, %entry
  ret i32 1

fail:                                             ; preds = %flush
  ret i32 0
}

define internal i32 @sollang_legacy_int_write_i64_file(i64 %value) {
entry:
  %count = load i64, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %slot = getelementptr inbounds [8192 x i64], ptr @sollang_legacy_int_writer_buffer, i64 0, i64 %count
  store i64 %value, ptr %slot, align 8
  %next = add i64 %count, 1
  store i64 %next, ptr @sollang_legacy_int_writer_buffer_count, align 8
  %full = icmp eq i64 %next, 8192
  br i1 %full, label %flush, label %success

flush:                                            ; preds = %entry
  %ok = call i32 @sollang_legacy_int_flush_i64_file()
  ret i32 %ok

success:                                          ; preds = %entry
  ret i32 1
}

define internal i32 @sollang_legacy_int_close_write_i64_file() {
entry:
  %flush_ok = call i32 @sollang_legacy_int_flush_i64_file()
  %flush_is_ok = icmp ne i32 %flush_ok, 0
  br i1 %flush_is_ok, label %close, label %fail

close:                                            ; preds = %entry
  %close_ok = call i32 @sollang_legacy_int_platform_close_write_file()
  ret i32 %close_ok

fail:                                             ; preds = %entry
  ret i32 0
}

define internal %sollang.legacy_int_result @sollang_legacy_int_closest_i64_file(i64 %target) {
entry:
  %count_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_i64_file_count()
  %count = extractvalue %sollang.legacy_int_result %count_result, 0
  %count_ok = extractvalue %sollang.legacy_int_result %count_result, 1
  %count_is_ok = icmp ne i32 %count_ok, 0
  %has_values = icmp sgt i64 %count, 0
  %can_search = and i1 %count_is_ok, %has_values
  br i1 %can_search, label %search, label %fail

search:                                           ; preds = %entry
  br label %loop

loop:                                             ; preds = %step, %search
  %low = phi i64 [ 0, %search ], [ %next_low, %step ]
  %high = phi i64 [ %count, %search ], [ %next_high, %step ]
  %active = icmp slt i64 %low, %high
  br i1 %active, label %probe, label %choose

probe:                                            ; preds = %loop
  %span = sub i64 %high, %low
  %half = sdiv i64 %span, 2
  %mid = add i64 %low, %half
  %mid_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %mid)
  %mid_value = extractvalue %sollang.legacy_int_result %mid_result, 0
  %mid_ok = extractvalue %sollang.legacy_int_result %mid_result, 1
  %mid_is_ok = icmp ne i32 %mid_ok, 0
  br i1 %mid_is_ok, label %compare_mid, label %fail

compare_mid:                                      ; preds = %probe
  %less = icmp slt i64 %mid_value, %target
  br i1 %less, label %move_low, label %move_high

move_low:                                         ; preds = %compare_mid
  %low_plus = add i64 %mid, 1
  br label %step

move_high:                                        ; preds = %compare_mid
  br label %step

step:                                             ; preds = %move_high, %move_low
  %next_low = phi i64 [ %low_plus, %move_low ], [ %low, %move_high ]
  %next_high = phi i64 [ %high, %move_low ], [ %mid, %move_high ]
  br label %loop

choose:                                           ; preds = %loop
  %at_start = icmp eq i64 %low, 0
  br i1 %at_start, label %read_low, label %check_end

check_end:                                        ; preds = %choose
  %at_end = icmp eq i64 %low, %count
  br i1 %at_end, label %read_prev_only, label %read_pair

read_low:                                         ; preds = %choose
  %first_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 0)
  ret %sollang.legacy_int_result %first_result

read_prev_only:                                   ; preds = %check_end
  %last_index = sub i64 %count, 1
  %last_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %last_index)
  ret %sollang.legacy_int_result %last_result

read_pair:                                        ; preds = %check_end
  %prev_index = sub i64 %low, 1
  %prev_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %prev_index)
  %next_result = call %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %low)
  %prev_ok = extractvalue %sollang.legacy_int_result %prev_result, 1
  %next_ok = extractvalue %sollang.legacy_int_result %next_result, 1
  %prev_is_ok = icmp ne i32 %prev_ok, 0
  %next_is_ok = icmp ne i32 %next_ok, 0
  %both_ok = and i1 %prev_is_ok, %next_is_ok
  br i1 %both_ok, label %compare_pair, label %fail

compare_pair:                                     ; preds = %read_pair
  %prev_value = extractvalue %sollang.legacy_int_result %prev_result, 0
  %next_value = extractvalue %sollang.legacy_int_result %next_result, 0
  %prev_diff = sub i64 %target, %prev_value
  %next_diff = sub i64 %next_value, %target
  %prefer_prev = icmp sle i64 %prev_diff, %next_diff
  br i1 %prefer_prev, label %return_prev, label %return_next

return_prev:                                      ; preds = %compare_pair
  ret %sollang.legacy_int_result %prev_result

return_next:                                      ; preds = %compare_pair
  ret %sollang.legacy_int_result %next_result

fail:                                             ; preds = %read_pair, %probe, %entry
  %fail0 = insertvalue %sollang.legacy_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.legacy_int_result %fail0, i32 0, 1
  ret %sollang.legacy_int_result %fail1
}

define internal void @sollang_legacy_int_require(i32 %status) {
entry:
  %ok = icmp ne i32 %status, 0
  br i1 %ok, label %done, label %failure

failure:                                          ; preds = %entry
  call void @ExitProcess(i32 1)
  unreachable

done:                                             ; preds = %entry
  ret void
}

define void @sollang_m133_s0(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  %ok = call i32 @sollang_legacy_int_open_write_i64_file(ptr %data, i64 %length)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}

define void @sollang_m133_s1(i32 %arg) {
entry:
  %wide = sext i32 %arg to i64
  %ok = call i32 @sollang_legacy_int_write_i64_file(i64 %wide)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}

define void @sollang_m133_s2() {
entry:
  %ok = call i32 @sollang_legacy_int_close_write_i64_file()
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}

define void @sollang_m133_s3(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  %ok = call i32 @sollang_legacy_int_platform_open_read_file(ptr %data, i64 %length)
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}

define void @sollang_m133_s5() {
entry:
  %ok = call i32 @sollang_legacy_int_platform_close_read_file()
  call void @sollang_legacy_int_require(i32 %ok)
  ret void
}

define i32 @sollang_m133_s4(i32 %arg) {
entry:
  %wide = sext i32 %arg to i64
  %result = call %sollang.legacy_int_result @sollang_legacy_int_closest_i64_file(i64 %wide)
  %status = extractvalue %sollang.legacy_int_result %result, 1
  call void @sollang_legacy_int_require(i32 %status)
  %value = extractvalue %sollang.legacy_int_result %result, 0
  %narrow = trunc i64 %value to i32
  ret i32 %narrow
}

declare dllimport i32 @SetFilePointerEx(ptr, i64, ptr, i32)

define internal i32 @sollang_legacy_int_platform_open_write_file(ptr %path, i64 %len) {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_legacy_int_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:                                             ; preds = %entry
  %handle = call ptr @CreateFileA(ptr %buf_ptr, i32 1073741824, i32 0, ptr null, i32 2, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:                                          ; preds = %open
  store ptr %handle, ptr @sollang_legacy_int_file_writer, align 8
  ret i32 1

fail:                                             ; preds = %open, %entry
  ret i32 0
}

define internal i32 @sollang_legacy_int_platform_write_file_bytes(ptr %data, i64 %len64) {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_writer, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %write, label %fail

write:                                            ; preds = %entry
  %written = alloca i32, align 4
  %len = trunc i64 %len64 to i32
  %ok = call i32 @WriteFile(ptr %handle, ptr %data, i32 %len, ptr %written, ptr null)
  %written32 = load i32, ptr %written, align 4
  %written64 = zext i32 %written32 to i64
  %write_ok = icmp ne i32 %ok, 0
  %full = icmp eq i64 %written64, %len64
  %all_ok = and i1 %write_ok, %full
  %result = zext i1 %all_ok to i32
  ret i32 %result

fail:                                             ; preds = %entry
  ret i32 0
}

define internal i32 @sollang_legacy_int_platform_close_write_file() {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_writer, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %close, label %fail

close:                                            ; preds = %entry
  %ok = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %ok, 0
  br i1 %close_ok, label %success, label %fail

success:                                          ; preds = %close
  store ptr null, ptr @sollang_legacy_int_file_writer, align 8
  ret i32 1

fail:                                             ; preds = %close, %entry
  ret i32 0
}

define internal i32 @sollang_legacy_int_platform_open_read_file(ptr %path, i64 %len) {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_legacy_int_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:                                             ; preds = %entry
  %handle = call ptr @CreateFileA(ptr %buf_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:                                          ; preds = %open
  store ptr %handle, ptr @sollang_legacy_int_file_reader, align 8
  ret i32 1

fail:                                             ; preds = %open, %entry
  ret i32 0
}

define internal %sollang.legacy_int_result @sollang_legacy_int_platform_i64_file_count() {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %size, label %fail

size:                                             ; preds = %entry
  %size_ptr = alloca i64, align 8
  %ok = call i32 @GetFileSizeEx(ptr %handle, ptr %size_ptr)
  %size_ok = icmp ne i32 %ok, 0
  br i1 %size_ok, label %check, label %fail

check:                                            ; preds = %size
  %bytes = load i64, ptr %size_ptr, align 8
  %rem = urem i64 %bytes, 8
  %aligned = icmp eq i64 %rem, 0
  br i1 %aligned, label %success, label %fail

success:                                          ; preds = %check
  %count = udiv i64 %bytes, 8
  %ok0 = insertvalue %sollang.legacy_int_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.legacy_int_result %ok0, i32 1, 1
  ret %sollang.legacy_int_result %ok1

fail:                                             ; preds = %check, %size, %entry
  %fail0 = insertvalue %sollang.legacy_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.legacy_int_result %fail0, i32 0, 1
  ret %sollang.legacy_int_result %fail1
}

define internal %sollang.legacy_int_result @sollang_legacy_int_platform_read_i64_at(i64 %index) {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %seek, label %fail

seek:                                             ; preds = %entry
  %offset = mul i64 %index, 8
  %seek_ok = call i32 @SetFilePointerEx(ptr %handle, i64 %offset, ptr null, i32 0)
  %seek_is_ok = icmp ne i32 %seek_ok, 0
  br i1 %seek_is_ok, label %read, label %fail

read:                                             ; preds = %seek
  %value_ptr = alloca i64, align 8
  %read_bytes = alloca i32, align 4
  %ok = call i32 @ReadFile(ptr %handle, ptr %value_ptr, i32 8, ptr %read_bytes, ptr null)
  %read_ok = icmp ne i32 %ok, 0
  %read_count = load i32, ptr %read_bytes, align 4
  %read_full = icmp eq i32 %read_count, 8
  %all_ok = and i1 %read_ok, %read_full
  br i1 %all_ok, label %success, label %fail

success:                                          ; preds = %read
  %value = load i64, ptr %value_ptr, align 8
  %ok0 = insertvalue %sollang.legacy_int_result poison, i64 %value, 0
  %ok1 = insertvalue %sollang.legacy_int_result %ok0, i32 1, 1
  ret %sollang.legacy_int_result %ok1

fail:                                             ; preds = %read, %seek, %entry
  %fail0 = insertvalue %sollang.legacy_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.legacy_int_result %fail0, i32 0, 1
  ret %sollang.legacy_int_result %fail1
}

define internal i32 @sollang_legacy_int_platform_close_read_file() {
entry:
  %handle = load ptr, ptr @sollang_legacy_int_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %close, label %fail

close:                                            ; preds = %entry
  %ok = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %ok, 0
  br i1 %close_ok, label %success, label %fail

success:                                          ; preds = %close
  store ptr null, ptr @sollang_legacy_int_file_reader, align 8
  ret i32 1

fail:                                             ; preds = %close, %entry
  ret i32 0
}

declare i32 @getchar()

declare dllimport i32 @GetFileSizeEx(ptr, ptr)

declare dllimport ptr @CreateFileMappingA(ptr, ptr, i32, i32, i32, ptr)

declare dllimport ptr @MapViewOfFile(ptr, i32, i32, i32, i64)

declare dllimport i32 @UnmapViewOfFile(ptr)

declare dllimport i64 @GetTickCount64()

declare dllimport void @GetSystemTimePreciseAsFileTime(ptr)

define void @sollang_m131_s0(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 false)
  ret void
}

define void @sollang_m131_s1(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 true)
  ret void
}

define i32 @sollang_m131_s2(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_print(ptr %data, i64 %length, i1 false)
  %value_slot = alloca i32, align 4
  %started_slot = alloca i1, align 1
  %negative_slot = alloca i1, align 1
  store i32 0, ptr %value_slot, align 4
  store i1 false, ptr %started_slot, align 1
  store i1 false, ptr %negative_slot, align 1
  br label %read

read:                                             ; preds = %mark_negative, %prefix, %append, %entry
  %character = call i32 @getchar()
  %eof = icmp eq i32 %character, -1
  br i1 %eof, label %done, label %classify

classify:                                         ; preds = %read
  %digit_low = icmp sge i32 %character, 48
  %digit_high = icmp sle i32 %character, 57
  %digit = and i1 %digit_low, %digit_high
  br i1 %digit, label %append, label %non_digit

append:                                           ; preds = %classify
  %previous = load i32, ptr %value_slot, align 4
  %scaled = mul i32 %previous, 10
  %digit_value = sub i32 %character, 48
  %updated = add i32 %scaled, %digit_value
  store i32 %updated, ptr %value_slot, align 4
  store i1 true, ptr %started_slot, align 1
  br label %read

non_digit:                                        ; preds = %classify
  %started = load i1, ptr %started_slot, align 1
  br i1 %started, label %done, label %prefix

prefix:                                           ; preds = %non_digit
  %minus = icmp eq i32 %character, 45
  br i1 %minus, label %mark_negative, label %read

mark_negative:                                    ; preds = %prefix
  store i1 true, ptr %negative_slot, align 1
  br label %read

done:                                             ; preds = %non_digit, %read
  %magnitude = load i32, ptr %value_slot, align 4
  %negative = load i1, ptr %negative_slot, align 1
  %negated = sub i32 0, %magnitude
  %result = select i1 %negative, i32 %negated, i32 %magnitude
  ret i32 %result
}

define void @sollang_m139_s0(i32 %arg) {
entry:
  %seed = sext i32 %arg to i64
  store i64 %seed, ptr @sollang_stage2_random_state, align 8
  ret void
}

define i32 @sollang_m139_s1(i32 %arg) {
entry:
  %valid = icmp sgt i32 %arg, 0
  br i1 %valid, label %next, label %failure

next:                                             ; preds = %entry
  %state = load i64, ptr @sollang_stage2_random_state, align 8
  %product = mul i64 %state, 6364136223846793005
  %updated = add i64 %product, 1442695040888963407
  store i64 %updated, ptr @sollang_stage2_random_state, align 8
  %bound = zext i32 %arg to i64
  %value = urem i64 %updated, %bound
  %result = trunc i64 %value to i32
  ret i32 %result

failure:                                          ; preds = %entry
  ret i32 0
}

define i64 @sollang_m130_s0() {
entry:
  %value = call i64 @GetTickCount64()
  ret i64 %value
}

define i64 @sollang_m130_s1() {
entry:
  %filetime = alloca [2 x i32], align 4
  call void @GetSystemTimePreciseAsFileTime(ptr %filetime)
  %low_ptr = getelementptr inbounds [2 x i32], ptr %filetime, i64 0, i64 0
  %high_ptr = getelementptr inbounds [2 x i32], ptr %filetime, i64 0, i64 1
  %low32 = load i32, ptr %low_ptr, align 4
  %high32 = load i32, ptr %high_ptr, align 4
  %low = zext i32 %low32 to i64
  %high = zext i32 %high32 to i64
  %shifted = shl i64 %high, 32
  %ticks = or i64 %shifted, %low
  %unix_ticks = sub i64 %ticks, 116444736000000000
  %millis = udiv i64 %unix_ticks, 10000
  ret i64 %millis
}

define i8 @sollang_m130_s2() {
  ret i8 0
}

define void @sollang_m131_s3(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_eprint(ptr %data, i64 %length, i1 false)
  ret void
}

define void @sollang_m131_s4(%sollang.text %arg) {
entry:
  %data = extractvalue %sollang.text %arg, 0
  %length = extractvalue %sollang.text %arg, 1
  call void @sollang_runtime_eprintln(ptr %data, i64 %length)
  ret void
}

define void @sollang_m131_s5() {
entry:
  call void @sollang_runtime_flush_stdout()
  ret void
}

declare dllimport i32 @BCryptGenRandom(ptr, ptr, i32, i32)

define internal i1 @sollang_secure_random_fill(ptr %buffer, i64 %length) {
entry:
  %empty = icmp eq i64 %length, 0
  br i1 %empty, label %success, label %fill

fill:                                             ; preds = %continue, %entry
  %offset = phi i64 [ 0, %entry ], [ %next_offset, %continue ]
  %remaining = sub i64 %length, %offset
  %large = icmp ugt i64 %remaining, 4294967295
  %chunk64 = select i1 %large, i64 4294967295, i64 %remaining
  %chunk = trunc i64 %chunk64 to i32
  %target = getelementptr i8, ptr %buffer, i64 %offset
  %status = call i32 @BCryptGenRandom(ptr null, ptr %target, i32 %chunk, i32 2)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %continue, label %failure

continue:                                         ; preds = %fill
  %next_offset = add i64 %offset, %chunk64
  %done = icmp eq i64 %next_offset, %length
  br i1 %done, label %success, label %fill

success:                                          ; preds = %continue, %entry
  ret i1 true

failure:                                          ; preds = %fill
  ret i1 false
}

define %sollang.enum.t469 @sollang_m139_s2(i64 %arg) {
entry:
  %empty = icmp eq i64 %arg, 0
  %allocation_size = select i1 %empty, i64 1, i64 %arg
  %buffer = call ptr @malloc(i64 %allocation_size)
  %filled = call i1 @sollang_secure_random_fill(ptr %buffer, i64 %arg)
  br i1 %filled, label %success, label %failure

success:                                          ; preds = %entry
  %success_slot = alloca %sollang.enum.t469, align 8
  store %sollang.enum.t469 zeroinitializer, ptr %success_slot, align 8
  %success_tag = getelementptr inbounds %sollang.enum.t469, ptr %success_slot, i32 0, i32 0
  store i32 0, ptr %success_tag, align 4
  %success_payload = getelementptr inbounds %sollang.enum.t469, ptr %success_slot, i32 0, i32 1
  %bytes0 = insertvalue %sollang.array.i32 poison, ptr %buffer, 0
  %bytes1 = insertvalue %sollang.array.i32 %bytes0, i64 %arg, 1
  %bytes = insertvalue %sollang.array.i32 %bytes1, i64 %arg, 2
  store %sollang.array.i32 %bytes, ptr %success_payload, align 8
  %success_result = load %sollang.enum.t469, ptr %success_slot, align 8
  ret %sollang.enum.t469 %success_result

failure:                                          ; preds = %entry
  call void @free(ptr %buffer)
  %failure_slot = alloca %sollang.enum.t469, align 8
  store %sollang.enum.t469 zeroinitializer, ptr %failure_slot, align 8
  %failure_tag = getelementptr inbounds %sollang.enum.t469, ptr %failure_slot, i32 0, i32 0
  store i32 1, ptr %failure_tag, align 4
  %failure_result = load %sollang.enum.t469, ptr %failure_slot, align 8
  ret %sollang.enum.t469 %failure_result
}

define %sollang.source_text @sollang_runtime_map_text(%sollang.text %path) {
entry:
  %path_data = extractvalue %sollang.text %path, 0
  %path_length = extractvalue %sollang.text %path, 1
  %buffer = alloca [260 x i16], align 2
  %buffer_ptr = getelementptr inbounds [260 x i16], ptr %buffer, i64 0, i64 0
  %path_ok = call i32 @sollang_windows_utf8_path(ptr %path_data, i64 %path_length, ptr %buffer_ptr, i32 260)
  %valid = icmp ne i32 %path_ok, 0
  br i1 %valid, label %open, label %failure

open:                                             ; preds = %entry
  %file = call ptr @CreateFileW(ptr %buffer_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 128, ptr null)
  %file_value = ptrtoint ptr %file to i64
  %opened = icmp ne i64 %file_value, -1
  br i1 %opened, label %size, label %failure

size:                                             ; preds = %open
  %size_slot = alloca i64, align 8
  %size_status = call i32 @GetFileSizeEx(ptr %file, ptr %size_slot)
  %size_ok = icmp ne i32 %size_status, 0
  br i1 %size_ok, label %size_known, label %close_failure

size_known:                                       ; preds = %size
  %length = load i64, ptr %size_slot, align 8
  %empty = icmp eq i64 %length, 0
  br i1 %empty, label %empty_success, label %mapping

empty_success:                                    ; preds = %size_known
  %empty_closed = call i32 @CloseHandle(ptr %file)
  ret %sollang.source_text zeroinitializer

mapping:                                          ; preds = %size_known
  %mapping_handle = call ptr @CreateFileMappingA(ptr %file, ptr null, i32 2, i32 0, i32 0, ptr null)
  %mapping_ok = icmp ne ptr %mapping_handle, null
  br i1 %mapping_ok, label %view, label %close_failure

view:                                             ; preds = %mapping
  %base = call ptr @MapViewOfFile(ptr %mapping_handle, i32 4, i32 0, i32 0, i64 %length)
  %base_ok = icmp ne ptr %base, null
  br i1 %base_ok, label %success, label %mapping_failure

success:                                          ; preds = %view
  %mapping_closed = call i32 @CloseHandle(ptr %mapping_handle)
  %file_closed = call i32 @CloseHandle(ptr %file)
  %result0 = insertvalue %sollang.source_text poison, ptr %base, 0
  %result1 = insertvalue %sollang.source_text %result0, i64 %length, 1
  %result2 = insertvalue %sollang.source_text %result1, ptr %base, 2
  %result3 = insertvalue %sollang.source_text %result2, i64 %length, 3
  ret %sollang.source_text %result3

mapping_failure:                                  ; preds = %view
  %failed_mapping_closed = call i32 @CloseHandle(ptr %mapping_handle)
  br label %close_failure

close_failure:                                    ; preds = %mapping_failure, %mapping, %size
  %failed_file_closed = call i32 @CloseHandle(ptr %file)
  br label %failure

failure:                                          ; preds = %close_failure, %open, %entry
  call void @llvm.trap()
  unreachable
}

define void @sollang_runtime_unmap_text(%sollang.source_text %source) {
entry:
  %base = extractvalue %sollang.source_text %source, 2
  %owned = icmp ne ptr %base, null
  br i1 %owned, label %release, label %done

release:                                          ; preds = %entry
  %length = extractvalue %sollang.source_text %source, 3
  %heap_owned = icmp eq i64 %length, -1
  br i1 %heap_owned, label %free_owned, label %unmap

free_owned:                                       ; preds = %release
  call void @free(ptr %base)
  br label %done

unmap:                                            ; preds = %release
  %ignored = call i32 @UnmapViewOfFile(ptr %base)
  br label %done

done:                                             ; preds = %unmap, %free_owned, %entry
  ret void
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #3

attributes #0 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nounwind willreturn memory(argmem: write) }
