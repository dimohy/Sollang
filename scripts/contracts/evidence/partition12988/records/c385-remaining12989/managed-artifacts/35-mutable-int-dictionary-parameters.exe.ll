; sollang cpu contract cpu1-d-r1-a3fe-f0
target triple = "x86_64-pc-windows-msvc"

%sollang.text = type { ptr, i64 }
%sollang.source_text = type { ptr, i64, ptr, i64 }
%sollang.int_slice = type { ptr, i64 }
%sollang.mutable_container = type { ptr, ptr, ptr }
%sollang.dynamic_int_array = type { ptr, i64, i64 }
%sollang.int_dictionary = type { ptr, i64, i64 }
%sollang.read_int_result = type { i64, i32 }
%sollang.file_int_result = type { i64, i32 }
%sollang.file_count_result = type { i64, i32 }
%sollang.file_handle_result = type { i64, i32 }
%sollang.socket_result = type { i64, i32, i32 }
%sollang.mapped_bytes = type { ptr, i64, ptr, i64, i1 }
%sollang.environment_result = type { ptr, i64, i1, i1 }
%sollang.process_result = type { i32, i32 }
%sollang.process_poll_result = type { i32, i32 }
%sollang.process_spawn_result = type { i64, i64, i32 }
%sollang.process_capture_result = type { i32, ptr, i64, i64, i1, ptr, i64, i64, i1, i32 }
%sollang.process_environment_result = type { ptr, i64, i64, i1 }
%sollang.task = type { ptr, ptr }
%sollang.stream = type { ptr, ptr, ptr }
%sollang.event_stream = type { ptr, ptr, ptr }
%sollang.dyn = type { ptr, ptr }
%sollang.task_control = type { ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, i64, ptr, ptr, i32, i32, i64, i64, i32, ptr, i64, i64, i32, i32, ptr, ptr }%sollang.struct.27 = type { i64 }
%sollang.struct.29 = type { i64 }
%sollang.struct.30 = type { i64 }
%sollang.struct.31 = type { i64 }
%sollang.struct.32 = type { %sollang.dynamic_int_array, %sollang.text, i1, %sollang.dynamic_int_array, i1, %sollang.enum.1582, %sollang.enum.1583, %sollang.enum.1583 }
%sollang.struct.33 = type { %sollang.text, %sollang.text }
%sollang.struct.34 = type { %sollang.dynamic_int_array, %sollang.enum.35 }
%sollang.struct.43 = type { i32, i32 }
%sollang.struct.44 = type { i32, i32, i32, i32, %sollang.enum.45 }
%sollang.struct.1024 = type { %sollang.enum.1448 }
%sollang.struct.1025 = type {  }
%sollang.struct.1026 = type { i32, i1 }
%sollang.struct.1027 = type { i32, i32 }
%sollang.struct.1028 = type { %sollang.enum.1454, i64 }
%sollang.struct.1029 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1030 = type { %sollang.struct.1029 }
%sollang.struct.1031 = type { i32, i32, i32 }
%sollang.struct.1032 = type { %sollang.struct.1029, %sollang.enum.1452, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, i32, i32, i32, i32, %sollang.dynamic_int_array, i1, %sollang.struct.1031, i32, %sollang.struct.1184, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, i32, i32, %sollang.dynamic_int_array, i32, i1, %sollang.struct.1028 }
%sollang.struct.1033 = type { i32, i32, i32, i32, i32, i32, i32, i32 }
%sollang.struct.1034 = type { %sollang.struct.1033, %sollang.enum.1453, i32, i32, i32, i32, i32, i32, %sollang.struct.1184, %sollang.dynamic_int_array }
%sollang.struct.1035 = type { i32 }
%sollang.struct.1036 = type { %sollang.text, %sollang.text, i32, i64, i32, i32 }
%sollang.struct.1037 = type { i64, %sollang.enum.2151, %sollang.enum.1455, %sollang.enum.1456, %sollang.enum.2151, i64, %sollang.enum.2152 }
%sollang.struct.1038 = type { i64, i64, i64, i1 }
%sollang.struct.1039 = type { i64, i64, i64 }
%sollang.struct.1040 = type { i64 }
%sollang.struct.1041 = type { %sollang.struct.1040, %sollang.enum.1459 }
%sollang.struct.1042 = type { %sollang.enum.1486, i64 }
%sollang.struct.1043 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1044 = type { %sollang.struct.1043 }
%sollang.struct.1045 = type { i32, i32, i32, i32, i32, i32, i1 }
%sollang.struct.1046 = type { i32, i32, i32, i32, i32, i32, %sollang.enum.1485, %sollang.struct.1102, %sollang.struct.1060, %sollang.struct.1079, i32, i1, i32, i32, i32, %sollang.dynamic_int_array, i1, %sollang.struct.1042 }
%sollang.struct.1047 = type { i32, i32 }
%sollang.struct.1048 = type { i32, i32 }
%sollang.struct.1049 = type { i32, i32 }
%sollang.struct.1050 = type { i1, i64 }
%sollang.struct.1051 = type { %sollang.enum.1463, i64 }
%sollang.struct.1052 = type { i32, i32, i32 }
%sollang.struct.1053 = type { %sollang.struct.1071, i32, i32, i32, i32 }
%sollang.struct.1054 = type { %sollang.dynamic_int_array, %sollang.struct.1098 }
%sollang.struct.1055 = type { %sollang.struct.1071, %sollang.struct.1106, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32, %sollang.enum.1460, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.1460 }
%sollang.struct.1056 = type { %sollang.dynamic_int_array }
%sollang.struct.1057 = type { i32, %sollang.struct.1098 }
%sollang.struct.1058 = type { %sollang.enum.1476, i64 }
%sollang.struct.1059 = type { i32, i32, i32, i32, i32, i32 }
%sollang.struct.1060 = type { %sollang.struct.1089, %sollang.struct.1082, %sollang.struct.1110, i32, i32, i32 }
%sollang.struct.1061 = type { %sollang.enum.1464, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.1487, i32, i32 }
%sollang.struct.1062 = type { i32, i32, i32, i32, i32, %sollang.enum.1487, i32, i32 }
%sollang.struct.1063 = type { %sollang.struct.1089, i32, i32, %sollang.enum.1467, i32, i32, i32, i32, %sollang.enum.1466, %sollang.enum.1466 }
%sollang.struct.1064 = type { %sollang.struct.1060, %sollang.struct.1063, %sollang.enum.1469, i32, %sollang.dynamic_int_array, i32, i32, %sollang.dynamic_int_array }
%sollang.struct.1065 = type { %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, i32 }
%sollang.struct.1066 = type { %sollang.struct.1065, %sollang.struct.1084, %sollang.enum.1471, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1067 = type { %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1068 = type { %sollang.struct.1067, %sollang.struct.1112, %sollang.enum.1473, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1069 = type { i32, i32, %sollang.enum.1466, %sollang.enum.1466 }
%sollang.struct.1070 = type { i32, i32, %sollang.struct.1098 }
%sollang.struct.1071 = type { %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.struct.1098 }
%sollang.struct.1072 = type { i32, %sollang.struct.1098 }
%sollang.struct.1073 = type { %sollang.struct.1069, %sollang.struct.1098 }
%sollang.struct.1074 = type { %sollang.enum.1486, i64 }
%sollang.struct.1075 = type { i32, i32, i32 }
%sollang.struct.1076 = type { %sollang.struct.1064, %sollang.struct.1092 }
%sollang.struct.1077 = type { %sollang.struct.1066, %sollang.struct.1092 }
%sollang.struct.1078 = type { %sollang.struct.1068, %sollang.struct.1092 }
%sollang.struct.1079 = type { %sollang.struct.1060, %sollang.struct.1075, i32, %sollang.dynamic_int_array, %sollang.enum.1477 }
%sollang.struct.1080 = type { %sollang.enum.1484, i64 }
%sollang.struct.1081 = type { i32, i32, i32 }
%sollang.struct.1082 = type { %sollang.struct.1089, i32, i32 }
%sollang.struct.1083 = type { %sollang.dynamic_int_array, i32, %sollang.struct.1098 }
%sollang.struct.1084 = type { %sollang.struct.1089, i32, i32, i32, %sollang.enum.1480, i32, i32, i32, %sollang.dynamic_int_array, %sollang.enum.1481 }
%sollang.struct.1085 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1086 = type { i32, %sollang.struct.1098 }
%sollang.struct.1087 = type { %sollang.enum.1493, i64 }
%sollang.struct.1088 = type { i32, i32 }
%sollang.struct.1089 = type { %sollang.struct.1096, i32 }
%sollang.struct.1090 = type { %sollang.struct.1097, %sollang.struct.1098 }
%sollang.struct.1091 = type { %sollang.enum.1488, i32 }
%sollang.struct.1092 = type { %sollang.struct.1096, i32, i32, i32, %sollang.enum.1490, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.struct.1091, %sollang.dynamic_int_array, i32, i32, i32, %sollang.enum.1491, i32, i32, i32, i32, i32, i32, %sollang.enum.1491 }
%sollang.struct.1093 = type { i32, %sollang.struct.1098 }
%sollang.struct.1094 = type { %sollang.enum.1496, i64 }
%sollang.struct.1095 = type { i32, i32 }
%sollang.struct.1096 = type { i32, i32 }
%sollang.struct.1097 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1098 = type { i32, i32 }
%sollang.struct.1099 = type { i32, %sollang.struct.1098 }
%sollang.struct.1100 = type { i32, i32 }
%sollang.struct.1101 = type { i32 }
%sollang.struct.1102 = type { i64, i32, i32 }
%sollang.struct.1103 = type { i32, i32 }
%sollang.struct.1104 = type { %sollang.enum.1498, i64 }
%sollang.struct.1105 = type { i32 }
%sollang.struct.1106 = type { i32 }
%sollang.struct.1107 = type { i32, %sollang.enum.1497, i32 }
%sollang.struct.1108 = type { %sollang.enum.1500, i64 }
%sollang.struct.1109 = type { i32, i32, i32, i32 }
%sollang.struct.1110 = type { %sollang.struct.1089, i32, i32, i32 }
%sollang.struct.1111 = type { %sollang.dynamic_int_array, %sollang.struct.1098 }
%sollang.struct.1112 = type { %sollang.struct.1089, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.dynamic_int_array }
%sollang.struct.1113 = type { %sollang.dynamic_int_array }
%sollang.struct.1114 = type { %sollang.enum.1502, i64 }
%sollang.struct.1115 = type { i32, i32 }
%sollang.struct.1116 = type { %sollang.struct.1115 }
%sollang.struct.1117 = type { i32, i32 }
%sollang.struct.1118 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.1124 }
%sollang.struct.1119 = type { %sollang.struct.1116, i32, i32, i32, i32, i32, i32, %sollang.enum.1501, i32, i32, i32, i32, i32, i32, i32, i1, i32, i32, i32, i32, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.struct.1129, %sollang.struct.1129, %sollang.struct.1129, i32, i32, i32, i32, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i1, %sollang.struct.1114, i1, i1 }
%sollang.struct.1120 = type { %sollang.struct.1119 }
%sollang.struct.1121 = type { i32, i32, i32 }
%sollang.struct.1122 = type { i32, i32, i32, i32 }
%sollang.struct.1123 = type { i32, i32 }
%sollang.struct.1124 = type { i32, i32 }
%sollang.struct.1125 = type { i32, i32 }
%sollang.struct.1126 = type { i32, i32, i32 }
%sollang.struct.1127 = type { i32, i32, i32 }
%sollang.struct.1128 = type { i32, i32 }
%sollang.struct.1129 = type { %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32 }
%sollang.struct.1130 = type { %sollang.struct.1129, %sollang.struct.1129 }
%sollang.struct.1131 = type { %sollang.struct.1123, i32, %sollang.dynamic_int_array }
%sollang.struct.1132 = type { i32, %sollang.dynamic_int_array }
%sollang.struct.1133 = type { i32 }
%sollang.struct.1134 = type { i32 }
%sollang.struct.1135 = type { i1, i32 }
%sollang.struct.1136 = type { i1, i32 }
%sollang.struct.1137 = type { i1, i32 }
%sollang.struct.1138 = type { %sollang.enum.1504, i64 }
%sollang.struct.1139 = type { %sollang.dynamic_int_array, %sollang.struct.1149, i1, %sollang.struct.1145, %sollang.struct.1145, %sollang.struct.1145, i1, i1, i1, i32, i32, i32 }
%sollang.struct.1140 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1141 = type { i1 }
%sollang.struct.1142 = type { %sollang.struct.1140, %sollang.struct.1141 }
%sollang.struct.1143 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.1186 }
%sollang.struct.1144 = type { i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.1503, i64, i32, i32, i32, i32, i32, i1, i64, i1, %sollang.struct.1186, i32, i32, i32, i32, i1, %sollang.dynamic_int_array, %sollang.struct.1149, i1, %sollang.struct.1145, %sollang.struct.1145, %sollang.struct.1145, i1, i1, i1, i32, i32, i32, %sollang.dynamic_int_array, i1, %sollang.struct.1138 }
%sollang.struct.1145 = type { %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32 }
%sollang.struct.1146 = type { %sollang.struct.1145, i32 }
%sollang.struct.1147 = type { i32 }
%sollang.struct.1148 = type { i32, i32, i32 }
%sollang.struct.1149 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1150 = type { %sollang.struct.1149, i32 }
%sollang.struct.1151 = type { i32, i32 }
%sollang.struct.1152 = type { %sollang.struct.1145, %sollang.struct.1145, %sollang.struct.1145, i1, i1, i1, i32, i32, i32, i32 }
%sollang.struct.1153 = type { i32, i32, i32 }
%sollang.struct.1154 = type { %sollang.dynamic_int_array, %sollang.struct.1145, %sollang.struct.1145, %sollang.struct.1145, i1, i1, i1, i32, i32, i32 }
%sollang.struct.1155 = type { %sollang.dynamic_int_array }
%sollang.struct.1156 = type { %sollang.int_slice }
%sollang.struct.1157 = type { %sollang.dynamic_int_array, %sollang.int_slice }
%sollang.struct.1158 = type { %sollang.struct.1155, %sollang.int_slice }
%sollang.struct.1159 = type { %sollang.int_slice }
%sollang.struct.1160 = type { %sollang.enum.1510 }
%sollang.struct.1161 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1162 = type { %sollang.struct.1164, %sollang.struct.1164 }
%sollang.struct.1163 = type { i8 }
%sollang.struct.1164 = type { %sollang.int_slice, %sollang.int_slice, i32, i64 }
%sollang.struct.1165 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1166 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1167 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1168 = type { %sollang.enum.1512, i64 }
%sollang.struct.1169 = type { i32, i32 }
%sollang.struct.1170 = type { i32, i32 }
%sollang.struct.1171 = type { %sollang.enum.1513, %sollang.enum.1514 }
%sollang.struct.1172 = type { %sollang.struct.1171, i32, i32, i64, i8, i8, i32 }
%sollang.struct.1173 = type { %sollang.struct.1171, i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.1174 = type { i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.1175 = type { %sollang.enum.1516, i64 }
%sollang.struct.1176 = type { %sollang.enum.1515, i64 }
%sollang.struct.1177 = type { %sollang.enum.1515, i32, i32 }
%sollang.struct.1178 = type { %sollang.enum.1517, i64 }
%sollang.struct.1179 = type { i32, i32 }
%sollang.struct.1180 = type { i32, i32 }
%sollang.struct.1181 = type { i1 }
%sollang.struct.1182 = type { %sollang.struct.1181, i32, i32, i64 }
%sollang.struct.1183 = type { i32, i32, i64, i32, i64 }
%sollang.struct.1184 = type { %sollang.enum.1518, i32 }
%sollang.struct.1185 = type { i64 }
%sollang.struct.1186 = type { i64, i64, i64, i64, i64, i64, i64, %sollang.int_slice, i32 }
%sollang.struct.1187 = type { %sollang.enum.1519, i64 }
%sollang.struct.1188 = type { i32, %sollang.enum.1521 }
%sollang.struct.1189 = type { i32, i32 }
%sollang.struct.1190 = type { %sollang.dynamic_int_array, i32, %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1191 = type { %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1192 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1193 = type { i1 }
%sollang.struct.1194 = type { %sollang.struct.1191, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1195 = type { %sollang.struct.1191, %sollang.dynamic_int_array, %sollang.enum.1522 }
%sollang.struct.1196 = type { %sollang.struct.1192, %sollang.dynamic_int_array, i32 }
%sollang.struct.1197 = type { %sollang.struct.1192, %sollang.dynamic_int_array, %sollang.enum.1522 }
%sollang.struct.1198 = type { %sollang.dynamic_int_array, i32, i32, i32, i1 }
%sollang.struct.1199 = type { %sollang.struct.1198, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1200 = type { %sollang.struct.1198, %sollang.dynamic_int_array, %sollang.enum.1522 }
%sollang.struct.1201 = type { %sollang.struct.1198, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1202 = type { %sollang.struct.1198, %sollang.dynamic_int_array, %sollang.enum.1522 }
%sollang.struct.1203 = type { %sollang.struct.29, i64 }
%sollang.struct.1204 = type { %sollang.struct.30, i64 }
%sollang.struct.1205 = type { %sollang.struct.1203, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1206 = type { %sollang.struct.1203, %sollang.dynamic_int_array, %sollang.enum.1580 }
%sollang.struct.1207 = type { %sollang.struct.1204, %sollang.dynamic_int_array, i32 }
%sollang.struct.1208 = type { %sollang.struct.1204, %sollang.dynamic_int_array, %sollang.enum.1580 }
%sollang.struct.1209 = type { %sollang.struct.1362, i64 }
%sollang.struct.1210 = type { %sollang.struct.1355, %sollang.struct.1373 }
%sollang.struct.1211 = type { %sollang.struct.1209, %sollang.dynamic_int_array, i64, i1 }
%sollang.struct.1212 = type { %sollang.struct.1209, %sollang.dynamic_int_array, %sollang.struct.1373 }
%sollang.struct.1213 = type { %sollang.struct.1209, %sollang.dynamic_int_array, i64 }
%sollang.struct.1214 = type { %sollang.struct.1209, %sollang.dynamic_int_array, %sollang.struct.1373 }
%sollang.struct.1215 = type { %sollang.text, %sollang.text }
%sollang.struct.1216 = type { %sollang.text }
%sollang.struct.1217 = type { %sollang.enum.1523, %sollang.text }
%sollang.struct.1218 = type { %sollang.enum.1523 }
%sollang.struct.1219 = type { i8, i8, i8, i8 }
%sollang.struct.1220 = type { %sollang.struct.1219, i16 }
%sollang.struct.1221 = type { i16, i16, i16, i16, i16, i16, i16, i16 }
%sollang.struct.1222 = type { %sollang.struct.1221, i16, i32, i32 }
%sollang.struct.1223 = type { %sollang.enum.1542, i64 }
%sollang.struct.1224 = type { %sollang.enum.1527, i32 }
%sollang.struct.1225 = type { %sollang.enum.1526, i64, i64 }
%sollang.struct.1226 = type { %sollang.enum.1534, i64 }
%sollang.struct.1227 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1228 = type { i64, i64 }
%sollang.struct.1229 = type { %sollang.struct.1228, %sollang.struct.1228 }
%sollang.struct.1230 = type { %sollang.struct.1227 }
%sollang.struct.1231 = type { %sollang.source_text, %sollang.struct.1228, %sollang.struct.1228, %sollang.enum.1528, %sollang.dynamic_int_array, i64 }
%sollang.struct.1232 = type { %sollang.source_text, %sollang.enum.1528, i32, %sollang.struct.1228, %sollang.dynamic_int_array, i64 }
%sollang.struct.1233 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1234 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1235 = type { %sollang.struct.1234 }
%sollang.struct.1236 = type { %sollang.struct.1235, %sollang.text }
%sollang.struct.1237 = type { %sollang.enum.1529, %sollang.struct.1234 }
%sollang.struct.1238 = type { i64, i64, i1 }
%sollang.struct.1239 = type { %sollang.struct.1234, %sollang.enum.1530, %sollang.enum.1531, i64, i64, i64, i64, %sollang.dynamic_int_array, i1, i64, i32 }
%sollang.struct.1240 = type { i1, i64, i1, i1 }
%sollang.struct.1241 = type { %sollang.enum.1525, %sollang.struct.1230, %sollang.struct.1235, i32, i32 }
%sollang.struct.1242 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32 }
%sollang.struct.1243 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32, %sollang.enum.1537, %sollang.enum.1536 }
%sollang.struct.1244 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32, %sollang.enum.1537, %sollang.enum.1536, %sollang.dynamic_int_array, %sollang.struct.1232, i64 }
%sollang.struct.1245 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32, %sollang.dynamic_int_array, i64, %sollang.dynamic_int_array, i64, %sollang.struct.1239, i1, i1, i1 }
%sollang.struct.1246 = type { i32, i32, i32, i32 }
%sollang.struct.1247 = type { %sollang.struct.1246 }
%sollang.struct.1248 = type { %sollang.struct.1246, %sollang.dynamic_int_array, %sollang.text, i32, i32, i1, i1, i1, i64, %sollang.enum.1536, %sollang.enum.1537 }
%sollang.struct.1249 = type { %sollang.dynamic_int_array, i64, %sollang.enum.1536, %sollang.enum.1537 }
%sollang.struct.1250 = type { i32, i32, i32, i32 }
%sollang.struct.1251 = type { %sollang.struct.1250 }
%sollang.struct.1252 = type { %sollang.struct.1250, %sollang.dynamic_int_array, i32, i32, i1, i1, i1, i64, %sollang.enum.1539 }
%sollang.struct.1253 = type { %sollang.dynamic_int_array, i64, %sollang.enum.1539, %sollang.enum.1538 }
%sollang.struct.1254 = type { %sollang.struct.1352, %sollang.struct.1227 }
%sollang.struct.1255 = type { %sollang.struct.1354, %sollang.struct.1230, i32 }
%sollang.struct.1256 = type { %sollang.struct.1355, %sollang.struct.1230, i32, %sollang.dynamic_int_array, i64 }
%sollang.struct.1257 = type { %sollang.struct.1355, %sollang.struct.1230, i32, %sollang.dynamic_int_array, %sollang.struct.1231, i64, %sollang.dynamic_int_array, i64, i1 }
%sollang.struct.1258 = type { %sollang.struct.1355, %sollang.struct.1230, i32, %sollang.dynamic_int_array, %sollang.struct.1231, i64, %sollang.dynamic_int_array, i64, %sollang.struct.1239 }
%sollang.struct.1259 = type { %sollang.enum.1543, i64 }
%sollang.struct.1260 = type { %sollang.int_slice }
%sollang.struct.1261 = type { %sollang.struct.1356, %sollang.enum.1525, i1, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64 }
%sollang.struct.1262 = type { i64, i64, i64, i64 }
%sollang.struct.1263 = type { i64, i64, i32, i32, i32, i64, %sollang.struct.1262 }
%sollang.struct.1264 = type { %sollang.struct.1260, %sollang.enum.1525, %sollang.struct.1263, i1 }
%sollang.struct.1265 = type { %sollang.dynamic_int_array, %sollang.enum.1525, %sollang.enum.1525, i1, i32, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.struct.1275, %sollang.struct.1275, i64, i64, i1, %sollang.int_slice, %sollang.dynamic_int_array, %sollang.int_slice, %sollang.dynamic_int_array, i1, i1, %sollang.dynamic_int_array, %sollang.struct.1328, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64, i32, i64, i1, i1, %sollang.struct.1321, %sollang.struct.1303, %sollang.struct.1304, %sollang.struct.1332, %sollang.struct.1334, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.1266 = type { %sollang.struct.1331, i1, i1, i64 }
%sollang.struct.1267 = type { %sollang.struct.1330, i1, i1, i64, i1, i64 }
%sollang.struct.1268 = type { i64, %sollang.struct.1266, %sollang.struct.1267 }
%sollang.struct.1269 = type { i64, %sollang.struct.1266 }
%sollang.struct.1270 = type { i64, %sollang.struct.1267 }
%sollang.struct.1271 = type { i64, i64 }
%sollang.struct.1272 = type { i64, i8 }
%sollang.struct.1273 = type { i64, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
%sollang.struct.1274 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1275 = type { i1, i32, %sollang.int_slice, %sollang.struct.1345 }
%sollang.struct.1276 = type { i64, i1, %sollang.enum.1544 }
%sollang.struct.1277 = type { i64, i1, %sollang.dynamic_int_array }
%sollang.struct.1278 = type { i1, i1, i1, %sollang.struct.1332, %sollang.struct.1333 }
%sollang.struct.1279 = type { i64, i8 }
%sollang.struct.1280 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1281 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1282 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1283 = type { i64, %sollang.dynamic_int_array }
%sollang.struct.1284 = type { %sollang.enum.1543, i64 }
%sollang.struct.1285 = type { i64, %sollang.dynamic_int_array }
%sollang.struct.1286 = type { i64, i64, i1, %sollang.dynamic_int_array }
%sollang.struct.1287 = type { i64, i64, i64 }
%sollang.struct.1288 = type { i64, i64 }
%sollang.struct.1289 = type { %sollang.dynamic_int_array }
%sollang.struct.1290 = type { i64, i64 }
%sollang.struct.1291 = type { i1, i64 }
%sollang.struct.1292 = type { i64, i64 }
%sollang.struct.1293 = type { i1, i64 }
%sollang.struct.1294 = type { i1, i64, i64, %sollang.dynamic_int_array }
%sollang.struct.1295 = type { i64, i64, %sollang.dynamic_int_array, %sollang.int_slice }
%sollang.struct.1296 = type { i64, i64 }
%sollang.struct.1297 = type { i64, i64, i64, %sollang.dynamic_int_array }
%sollang.struct.1298 = type { %sollang.enum.1544, i64 }
%sollang.struct.1299 = type { i32, i64, i64, %sollang.dynamic_int_array, i64 }
%sollang.struct.1300 = type { i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64, %sollang.dynamic_int_array }
%sollang.struct.1301 = type { %sollang.dynamic_int_array, i64, %sollang.dynamic_int_array }
%sollang.struct.1302 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1303 = type { i1, i64, i64, i64, i64 }
%sollang.struct.1304 = type { i64, i64, i64, i64, i1 }
%sollang.struct.1305 = type { %sollang.int_slice }
%sollang.struct.1306 = type { %sollang.struct.1260, %sollang.int_slice, %sollang.struct.1305 }
%sollang.struct.1307 = type { %sollang.struct.1305, %sollang.int_slice, %sollang.struct.1220, i64, %sollang.dynamic_int_array, %sollang.int_slice }
%sollang.struct.1308 = type { %sollang.struct.1265, %sollang.struct.1268, %sollang.struct.1305 }
%sollang.struct.1309 = type { %sollang.dynamic_int_array }
%sollang.struct.1310 = type { %sollang.struct.1305, %sollang.struct.1268 }
%sollang.struct.1311 = type { i32, i64, %sollang.dynamic_int_array, i64 }
%sollang.struct.1312 = type { i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64, i64 }
%sollang.struct.1313 = type { i32, i64, %sollang.dynamic_int_array, i64 }
%sollang.struct.1314 = type { i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64, i64 }
%sollang.struct.1315 = type { i1, i64, %sollang.dynamic_int_array }
%sollang.struct.1316 = type { i8, i64, %sollang.dynamic_int_array }
%sollang.struct.1317 = type { %sollang.struct.1326, %sollang.struct.1325 }
%sollang.struct.1318 = type { i32, i64 }
%sollang.struct.1319 = type { i64, i64, i64, i1, i1 }
%sollang.struct.1320 = type { %sollang.struct.1303, %sollang.struct.1304, i64, i64, i64, i64 }
%sollang.struct.1321 = type { %sollang.dynamic_int_array }
%sollang.struct.1322 = type { %sollang.int_slice }
%sollang.struct.1323 = type { %sollang.int_slice }
%sollang.struct.1324 = type { %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1325 = type { %sollang.struct.1155 }
%sollang.struct.1326 = type { %sollang.struct.1158, %sollang.int_slice }
%sollang.struct.1327 = type { %sollang.struct.1330, i64 }
%sollang.struct.1328 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1329 = type { i64, i64, %sollang.enum.1545, %sollang.enum.1546 }
%sollang.struct.1330 = type { i64, i64, i64, i1, i64 }
%sollang.struct.1331 = type { i64, i64, i1, i64 }
%sollang.struct.1332 = type { i64, i64, i64, i64, i64 }
%sollang.struct.1333 = type { i64, i64 }
%sollang.struct.1334 = type { i1, i64, i64, i1, i1, i64, i64, i64, i64, i64, i64, i32, %sollang.dynamic_int_array, i32, i32, i32, i32, %sollang.dynamic_int_array, i32, i32, i32 }
%sollang.struct.1335 = type { %sollang.dynamic_int_array }
%sollang.struct.1336 = type { i16, %sollang.dynamic_int_array }
%sollang.struct.1337 = type { %sollang.enum.1547, %sollang.struct.1344, %sollang.int_slice }
%sollang.struct.1338 = type { i8, %sollang.dynamic_int_array, i64 }
%sollang.struct.1339 = type { i16, %sollang.dynamic_int_array, i64 }
%sollang.struct.1340 = type { %sollang.int_slice, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.int_slice, %sollang.dynamic_int_array }
%sollang.struct.1341 = type { %sollang.int_slice, %sollang.dynamic_int_array, %sollang.int_slice }
%sollang.struct.1342 = type { %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1343 = type { %sollang.enum.1548, %sollang.struct.1344 }
%sollang.struct.1344 = type { %sollang.dynamic_int_array }
%sollang.struct.1345 = type { %sollang.struct.1317 }
%sollang.struct.1346 = type { i64, %sollang.dynamic_int_array, i64 }
%sollang.struct.1347 = type { i64 }
%sollang.struct.1348 = type { i64, i64 }
%sollang.struct.1349 = type { i32, %sollang.dynamic_int_array }
%sollang.struct.1350 = type { %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1351 = type { i8, i64, i64, i64 }
%sollang.struct.1352 = type { %sollang.enum.1525, i32, i1 }
%sollang.struct.1353 = type { %sollang.enum.1525, i1 }
%sollang.struct.1354 = type { i64 }
%sollang.struct.1355 = type { i64 }
%sollang.struct.1356 = type { i64 }
%sollang.struct.1357 = type { ptr, i64, i64 }
%sollang.struct.1358 = type { %sollang.dynamic_int_array }
%sollang.struct.1359 = type { i64, %sollang.enum.1552, %sollang.enum.1551 }
%sollang.struct.1360 = type { i64, i1, i1, i1 }
%sollang.struct.1361 = type { i64, i64, i64 }
%sollang.struct.1362 = type { i64 }
%sollang.struct.1363 = type { i64, %sollang.enum.1553, %sollang.dynamic_int_array, i64, i64, %sollang.enum.1554, %sollang.enum.2176, %sollang.enum.2177, %sollang.enum.2151 }
%sollang.struct.1364 = type { %sollang.struct.1362, %sollang.struct.1355, %sollang.struct.1373 }
%sollang.struct.1365 = type { %sollang.struct.1362, %sollang.struct.1355 }
%sollang.struct.1366 = type { %sollang.struct.1362, %sollang.struct.1373 }
%sollang.struct.1367 = type { %sollang.struct.1362, %sollang.struct.1363 }
%sollang.struct.1368 = type { %sollang.struct.1362, %sollang.struct.1363, %sollang.struct.1373 }
%sollang.struct.1369 = type { %sollang.struct.1363, %sollang.struct.1373 }
%sollang.struct.1370 = type { i64, %sollang.dynamic_int_array }
%sollang.struct.1371 = type { %sollang.enum.1525, %sollang.dynamic_int_array, i1 }
%sollang.struct.1372 = type { %sollang.enum.1525, i64, i1 }
%sollang.struct.1373 = type { %sollang.enum.1557, i32 }
%sollang.struct.1374 = type { %sollang.enum.1559, i64 }
%sollang.struct.1375 = type { i32, i32, i32 }
%sollang.struct.1376 = type { %sollang.enum.1558, i64, i64 }
%sollang.struct.1377 = type { %sollang.enum.1558, i64, i1 }
%sollang.struct.1378 = type { %sollang.source_text, i64, i64, i32, i1, %sollang.struct.1375, %sollang.struct.1377 }
%sollang.struct.1379 = type { %sollang.enum.1561, i64, i32 }
%sollang.struct.1380 = type { i32, i32, i32, i32 }
%sollang.struct.1381 = type { i32, i32, i32, i32 }
%sollang.struct.1382 = type { %sollang.enum.1560, i32 }
%sollang.struct.1383 = type { i32, i32, i32, i1 }
%sollang.struct.1384 = type { %sollang.source_text, i64, i64, i32, i32, i1, %sollang.struct.1382, %sollang.struct.1380 }
%sollang.struct.1385 = type { %sollang.struct.1381, i32, i32, i32, i32 }
%sollang.struct.1386 = type { i64, i64, i64, i32, i1, i1 }
%sollang.struct.1387 = type { i32, i32, i32 }
%sollang.struct.1388 = type { %sollang.enum.1562, i64, i64 }
%sollang.struct.1389 = type { %sollang.source_text, i64, i32, i32 }
%sollang.struct.1390 = type { %sollang.enum.1565, i64 }
%sollang.struct.1391 = type { i32, i32, i32, i32 }
%sollang.struct.1392 = type { %sollang.enum.1563, i64, i64, i64, i64, i32, i32 }
%sollang.struct.1393 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1394 = type { %sollang.enum.1564, i64, i64, i1, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1395 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1396 = type { %sollang.source_text, i64, i64, i8, i32, %sollang.struct.1391, %sollang.dynamic_int_array }
%sollang.struct.1397 = type { %sollang.dynamic_int_array, i32, i32, i32, i8, %sollang.dynamic_int_array }
%sollang.struct.1398 = type { i64, i64, i32 }
%sollang.struct.1399 = type { i32, i32, i32, i32 }
%sollang.struct.1400 = type { %sollang.enum.1566, i64, i64, i64 }
%sollang.struct.1401 = type { i64, i64 }
%sollang.struct.1402 = type { %sollang.source_text, i64, i64, i32, i32, i1, i1, i32, i32 }
%sollang.struct.1403 = type { %sollang.enum.1567, i64, i64, i64, i1, %sollang.enum.1568, i64 }
%sollang.struct.1404 = type { i8, i64 }
%sollang.struct.1405 = type { i32 }
%sollang.struct.1406 = type { i64, i64 }
%sollang.struct.1407 = type { i64 }
%sollang.struct.1408 = type { i64, i64, i64 }
%sollang.struct.1409 = type { i8 }
%sollang.struct.1410 = type { i8 }
%sollang.struct.1411 = type { i64, i64 }
%sollang.struct.1412 = type { i64 }
%sollang.struct.1413 = type { %sollang.struct.1406 }
%sollang.struct.1414 = type { %sollang.struct.1407 }
%sollang.struct.1415 = type { i64 }
%sollang.struct.1416 = type { %sollang.struct.27, %sollang.enum.1569, %sollang.struct.27 }
%sollang.struct.1417 = type { %sollang.dynamic_int_array, %sollang.struct.27, i64, %sollang.enum.1570 }
%sollang.struct.1418 = type { %sollang.struct.1417, %sollang.struct.1406, %sollang.struct.1406, i64 }
%sollang.struct.1419 = type { %sollang.enum.1571 }
%sollang.struct.1420 = type { %sollang.enum.1575, i64 }
%sollang.struct.1421 = type { i64, i64, i1 }
%sollang.struct.1422 = type { %sollang.struct.1421, %sollang.enum.1572, %sollang.enum.1573, %sollang.struct.1421 }
%sollang.struct.1423 = type { %sollang.source_text, %sollang.struct.1421, %sollang.enum.1574, %sollang.struct.1421, %sollang.struct.1421, %sollang.struct.1421 }
%sollang.struct.1424 = type { i1, i1, i1, i1, i1 }
%sollang.struct.1425 = type { %sollang.enum.1576, i64 }
%sollang.struct.1426 = type { i32, i32 }
%sollang.struct.1427 = type { %sollang.enum.1577 }
%sollang.struct.1428 = type { %sollang.enum.1579, i64 }
%sollang.struct.1429 = type { %sollang.int_slice }
%sollang.struct.1430 = type { i8 }
%sollang.struct.1431 = type { %sollang.struct.1410, %sollang.struct.1163 }
%sollang.struct.1432 = type { %sollang.struct.29, %sollang.dynamic_int_array, i64, i1 }
%sollang.struct.1433 = type { %sollang.struct.29, %sollang.dynamic_int_array, %sollang.enum.1580 }
%sollang.struct.1434 = type { %sollang.struct.30, %sollang.dynamic_int_array, i64 }
%sollang.struct.1435 = type { %sollang.struct.30, %sollang.dynamic_int_array, %sollang.enum.1580 }
%sollang.struct.1436 = type { %sollang.enum.1581, i32 }
%sollang.struct.1437 = type { i32, %sollang.enum.46 }
%sollang.struct.1438 = type { %sollang.dynamic_int_array, i8, i64, i64 }
%sollang.struct.1439 = type { %sollang.struct.34, %sollang.enum.38, i64, i64 }
%sollang.struct.1440 = type { %sollang.text, %sollang.text, i1 }
%sollang.struct.1441 = type { i64, i64 }
%sollang.struct.1442 = type { %sollang.struct.1443, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i1, i1 }
%sollang.struct.1443 = type { i32 }
%sollang.struct.1444 = type { i32 }
%sollang.struct.1445 = type { i64 }
%sollang.struct.1446 = type { i64, %sollang.struct.1445, i32, i32 }
%sollang.struct.1447 = type { i32, i32 }
%sollang.enum.35 = type { i32, [0 x i64] }
%sollang.enum.38 = type { i32, [0 x i64] }
%sollang.enum.45 = type { i32, [0 x i64] }
%sollang.enum.46 = type { i32, [0 x i64] }
%sollang.enum.1448 = type { i32, [0 x i64] }
%sollang.enum.1449 = type { i32, [0 x i64] }
%sollang.enum.1450 = type { i32, [0 x i64] }
%sollang.enum.1451 = type { i32, [0 x i64] }
%sollang.enum.1452 = type { i32, [0 x i64] }
%sollang.enum.1453 = type { i32, [0 x i64] }
%sollang.enum.1454 = type { i32, [0 x i64] }
%sollang.enum.1455 = type { i32, [0 x i64] }
%sollang.enum.1456 = type { i32, [0 x i64] }
%sollang.enum.1457 = type { i32, [0 x i64] }
%sollang.enum.1458 = type { i32, [0 x i64] }
%sollang.enum.1459 = type { i32, [0 x i64] }
%sollang.enum.1460 = type { i32, [0 x i64] }
%sollang.enum.1461 = type { i32, [1 x i64] }
%sollang.enum.1462 = type { i32, [1 x i64] }
%sollang.enum.1463 = type { i32, [0 x i64] }
%sollang.enum.1464 = type { i32, [0 x i64] }
%sollang.enum.1465 = type { i32, [5 x i64] }
%sollang.enum.1466 = type { i32, [4 x i64] }
%sollang.enum.1467 = type { i32, [0 x i64] }
%sollang.enum.1468 = type { i32, [1 x i64] }
%sollang.enum.1469 = type { i32, [0 x i64] }
%sollang.enum.1470 = type { i32, [1 x i64] }
%sollang.enum.1471 = type { i32, [0 x i64] }
%sollang.enum.1472 = type { i32, [1 x i64] }
%sollang.enum.1473 = type { i32, [0 x i64] }
%sollang.enum.1474 = type { i32, [1 x i64] }
%sollang.enum.1475 = type { i32, [1 x i64] }
%sollang.enum.1476 = type { i32, [0 x i64] }
%sollang.enum.1477 = type { i32, [66 x i64] }
%sollang.enum.1478 = type { i32, [1 x i64] }
%sollang.enum.1479 = type { i32, [1 x i64] }
%sollang.enum.1480 = type { i32, [0 x i64] }
%sollang.enum.1481 = type { i32, [4 x i64] }
%sollang.enum.1482 = type { i32, [1 x i64] }
%sollang.enum.1483 = type { i32, [1 x i64] }
%sollang.enum.1484 = type { i32, [0 x i64] }
%sollang.enum.1485 = type { i32, [0 x i64] }
%sollang.enum.1486 = type { i32, [0 x i64] }
%sollang.enum.1487 = type { i32, [0 x i64] }
%sollang.enum.1488 = type { i32, [0 x i64] }
%sollang.enum.1489 = type { i32, [1 x i64] }
%sollang.enum.1490 = type { i32, [0 x i64] }
%sollang.enum.1491 = type { i32, [4 x i64] }
%sollang.enum.1492 = type { i32, [1 x i64] }
%sollang.enum.1493 = type { i32, [0 x i64] }
%sollang.enum.1494 = type { i32, [1 x i64] }
%sollang.enum.1495 = type { i32, [1 x i64] }
%sollang.enum.1496 = type { i32, [0 x i64] }
%sollang.enum.1497 = type { i32, [0 x i64] }
%sollang.enum.1498 = type { i32, [0 x i64] }
%sollang.enum.1499 = type { i32, [1 x i64] }
%sollang.enum.1500 = type { i32, [0 x i64] }
%sollang.enum.1501 = type { i32, [0 x i64] }
%sollang.enum.1502 = type { i32, [0 x i64] }
%sollang.enum.1503 = type { i32, [0 x i64] }
%sollang.enum.1504 = type { i32, [0 x i64] }
%sollang.enum.1505 = type { i32, [0 x i64] }
%sollang.enum.1506 = type { i32, [0 x i64] }
%sollang.enum.1507 = type { i32, [0 x i64] }
%sollang.enum.1508 = type { i32, [0 x i64] }
%sollang.enum.1509 = type { i32, [3 x i64] }
%sollang.enum.1510 = type { i32, [0 x i64] }
%sollang.enum.1511 = type { i32, [0 x i64] }
%sollang.enum.1512 = type { i32, [0 x i64] }
%sollang.enum.1513 = type { i32, [0 x i64] }
%sollang.enum.1514 = type { i32, [0 x i64] }
%sollang.enum.1515 = type { i32, [0 x i64] }
%sollang.enum.1516 = type { i32, [0 x i64] }
%sollang.enum.1517 = type { i32, [0 x i64] }
%sollang.enum.1518 = type { i32, [0 x i64] }
%sollang.enum.1519 = type { i32, [0 x i64] }
%sollang.enum.1520 = type { i32, [3 x i64] }
%sollang.enum.1521 = type { i32, [0 x i64] }
%sollang.enum.1522 = type { i32, [2 x i64] }
%sollang.enum.1523 = type { i32, [0 x i64] }
%sollang.enum.1524 = type { i32, [2 x i64] }
%sollang.enum.1525 = type { i32, [4 x i64] }
%sollang.enum.1526 = type { i32, [0 x i64] }
%sollang.enum.1527 = type { i32, [0 x i64] }
%sollang.enum.1528 = type { i32, [0 x i64] }
%sollang.enum.1529 = type { i32, [1 x i64] }
%sollang.enum.1530 = type { i32, [0 x i64] }
%sollang.enum.1531 = type { i32, [0 x i64] }
%sollang.enum.1532 = type { i32, [2 x i64] }
%sollang.enum.1533 = type { i32, [7 x i64] }
%sollang.enum.1534 = type { i32, [0 x i64] }
%sollang.enum.1535 = type { i32, [2 x i64] }
%sollang.enum.1536 = type { i32, [0 x i64] }
%sollang.enum.1537 = type { i32, [0 x i64] }
%sollang.enum.1538 = type { i32, [0 x i64] }
%sollang.enum.1539 = type { i32, [0 x i64] }
%sollang.enum.1540 = type { i32, [2 x i64] }
%sollang.enum.1541 = type { i32, [8 x i64] }
%sollang.enum.1542 = type { i32, [0 x i64] }
%sollang.enum.1543 = type { i32, [0 x i64] }
%sollang.enum.1544 = type { i32, [7 x i64] }
%sollang.enum.1545 = type { i32, [0 x i64] }
%sollang.enum.1546 = type { i32, [0 x i64] }
%sollang.enum.1547 = type { i32, [0 x i64] }
%sollang.enum.1548 = type { i32, [0 x i64] }
%sollang.enum.1549 = type { i32, [0 x i64] }
%sollang.enum.1550 = type { i32, [0 x i64] }
%sollang.enum.1551 = type { i32, [0 x i64] }
%sollang.enum.1552 = type { i32, [1 x i64] }
%sollang.enum.1553 = type { i32, [0 x i64] }
%sollang.enum.1554 = type { i32, [0 x i64] }
%sollang.enum.1555 = type { i32, [16 x i64] }
%sollang.enum.1556 = type { i32, [16 x i64] }
%sollang.enum.1557 = type { i32, [0 x i64] }
%sollang.enum.1558 = type { i32, [0 x i64] }
%sollang.enum.1559 = type { i32, [0 x i64] }
%sollang.enum.1560 = type { i32, [0 x i64] }
%sollang.enum.1561 = type { i32, [0 x i64] }
%sollang.enum.1562 = type { i32, [0 x i64] }
%sollang.enum.1563 = type { i32, [0 x i64] }
%sollang.enum.1564 = type { i32, [0 x i64] }
%sollang.enum.1565 = type { i32, [0 x i64] }
%sollang.enum.1566 = type { i32, [0 x i64] }
%sollang.enum.1567 = type { i32, [0 x i64] }
%sollang.enum.1568 = type { i32, [0 x i64] }
%sollang.enum.1569 = type { i32, [0 x i64] }
%sollang.enum.1570 = type { i32, [0 x i64] }
%sollang.enum.1571 = type { i32, [0 x i64] }
%sollang.enum.1572 = type { i32, [3 x i64] }
%sollang.enum.1573 = type { i32, [1 x i64] }
%sollang.enum.1574 = type { i32, [12 x i64] }
%sollang.enum.1575 = type { i32, [0 x i64] }
%sollang.enum.1576 = type { i32, [0 x i64] }
%sollang.enum.1577 = type { i32, [0 x i64] }
%sollang.enum.1578 = type { i32, [0 x i64] }
%sollang.enum.1579 = type { i32, [0 x i64] }
%sollang.enum.1580 = type { i32, [2 x i64] }
%sollang.enum.1581 = type { i32, [0 x i64] }
%sollang.enum.1582 = type { i32, [2 x i64] }
%sollang.enum.1583 = type { i32, [2 x i64] }
%sollang.enum.1584 = type { i32, [1 x i64] }
%sollang.enum.2151 = type { i32, [1 x i64] }
%sollang.enum.2152 = type { i32, [7 x i64] }
%sollang.enum.2176 = type { i32, [1 x i64] }
%sollang.enum.2177 = type { i32, [2 x i64] }
%sollang.enum.2186 = type { i32, [2 x i64] }
%sollang.enum.2189 = type { i32, [1 x i64] }
%sollang.enum.2190 = type { i32, [1 x i64] }
%sollang.enum.2191 = type { i32, [3 x i64] }
%sollang.enum.2192 = type { i32, [44 x i64] }
%sollang.enum.2193 = type { i32, [2 x i64] }
%sollang.enum.2194 = type { i32, [13 x i64] }
%sollang.enum.2195 = type { i32, [2 x i64] }
%sollang.enum.2197 = type { i32, [1 x i64] }
%sollang.enum.2200 = type { i32, [3 x i64] }
%sollang.enum.2201 = type { i32, [3 x i64] }
%sollang.enum.2202 = type { i32, [4 x i64] }
%sollang.enum.2203 = type { i32, [105 x i64] }
%sollang.enum.2204 = type { i32, [2 x i64] }
%sollang.enum.2205 = type { i32, [3 x i64] }
%sollang.enum.2206 = type { i32, [9 x i64] }
%sollang.enum.2207 = type { i32, [26 x i64] }
%sollang.enum.2208 = type { i32, [81 x i64] }
%sollang.enum.2209 = type { i32, [2 x i64] }
%sollang.enum.2212 = type { i32, [26 x i64] }
%sollang.enum.2213 = type { i32, [4 x i64] }
%sollang.enum.2214 = type { i32, [2 x i64] }
%sollang.enum.2215 = type { i32, [2 x i64] }
%sollang.enum.2216 = type { i32, [2 x i64] }
%sollang.enum.2217 = type { i32, [50 x i64] }
%sollang.enum.2218 = type { i32, [2 x i64] }
%sollang.enum.2219 = type { i32, [3 x i64] }
%sollang.enum.2220 = type { i32, [2 x i64] }
%sollang.enum.2221 = type { i32, [2 x i64] }
%sollang.enum.2223 = type { i32, [2 x i64] }
%sollang.enum.2224 = type { i32, [2 x i64] }
%sollang.enum.2226 = type { i32, [9 x i64] }
%sollang.enum.2227 = type { i32, [24 x i64] }
%sollang.enum.2228 = type { i32, [2 x i64] }
%sollang.enum.2229 = type { i32, [12 x i64] }
%sollang.enum.2230 = type { i32, [11 x i64] }
%sollang.enum.2231 = type { i32, [2 x i64] }
%sollang.enum.2232 = type { i32, [32 x i64] }
%sollang.enum.2233 = type { i32, [34 x i64] }
%sollang.enum.2234 = type { i32, [2 x i64] }
%sollang.enum.2235 = type { i32, [9 x i64] }
%sollang.enum.2236 = type { i32, [31 x i64] }
%sollang.enum.2237 = type { i32, [2 x i64] }
%sollang.enum.2238 = type { i32, [15 x i64] }
%sollang.enum.2239 = type { i32, [34 x i64] }
%sollang.enum.2240 = type { i32, [2 x i64] }
%sollang.enum.2241 = type { i32, [2 x i64] }
%sollang.enum.2242 = type { i32, [6 x i64] }
%sollang.enum.2243 = type { i32, [2 x i64] }
%sollang.enum.2244 = type { i32, [2 x i64] }
%sollang.enum.2245 = type { i32, [2 x i64] }
%sollang.enum.2247 = type { i32, [14 x i64] }
%sollang.enum.2248 = type { i32, [9 x i64] }
%sollang.enum.2249 = type { i32, [5 x i64] }
%sollang.enum.2250 = type { i32, [5 x i64] }
%sollang.enum.2251 = type { i32, [4 x i64] }
%sollang.enum.2252 = type { i32, [2 x i64] }
%sollang.enum.2254 = type { i32, [2 x i64] }
%sollang.enum.2255 = type { i32, [2 x i64] }
%sollang.enum.2256 = type { i32, [81 x i64] }
%sollang.enum.2257 = type { i32, [3 x i64] }
%sollang.enum.2258 = type { i32, [2 x i64] }
%sollang.enum.2259 = type { i32, [3 x i64] }
%sollang.enum.2260 = type { i32, [5 x i64] }
%sollang.enum.2261 = type { i32, [2 x i64] }
%sollang.enum.2262 = type { i32, [14 x i64] }
%sollang.enum.2263 = type { i32, [2 x i64] }
%sollang.enum.2264 = type { i32, [32 x i64] }
%sollang.enum.2265 = type { i32, [4 x i64] }
%sollang.enum.2266 = type { i32, [2 x i64] }
%sollang.enum.2268 = type { i32, [5 x i64] }
%sollang.enum.2269 = type { i32, [2 x i64] }
%sollang.enum.2270 = type { i32, [2 x i64] }
%sollang.enum.2271 = type { i32, [5 x i64] }
%sollang.enum.2272 = type { i32, [2 x i64] }
%sollang.enum.2273 = type { i32, [2 x i64] }
%sollang.enum.2274 = type { i32, [32 x i64] }
%sollang.enum.2275 = type { i32, [2 x i64] }
%sollang.enum.2276 = type { i32, [4 x i64] }
%sollang.enum.2278 = type { i32, [2 x i64] }
%sollang.enum.2279 = type { i32, [2 x i64] }
%sollang.enum.2280 = type { i32, [4 x i64] }
%sollang.enum.2281 = type { i32, [2 x i64] }
%sollang.enum.2282 = type { i32, [2 x i64] }
%sollang.enum.2283 = type { i32, [2 x i64] }
%sollang.enum.2284 = type { i32, [2 x i64] }
%sollang.enum.2285 = type { i32, [2 x i64] }
%sollang.enum.2286 = type { i32, [2 x i64] }
%sollang.enum.2287 = type { i32, [3 x i64] }
%sollang.enum.2288 = type { i32, [2 x i64] }
%sollang.enum.2290 = type { i32, [3 x i64] }
%sollang.enum.2291 = type { i32, [4 x i64] }
%sollang.enum.2292 = type { i32, [9 x i64] }
%sollang.enum.2293 = type { i32, [2 x i64] }
%sollang.enum.2294 = type { i32, [32 x i64] }
%sollang.enum.2295 = type { i32, [3 x i64] }
%sollang.enum.2297 = type { i32, [5 x i64] }
%sollang.enum.2298 = type { i32, [2 x i64] }
%sollang.enum.2299 = type { i32, [2 x i64] }
%sollang.enum.2300 = type { i32, [4 x i64] }
%sollang.enum.2301 = type { i32, [4 x i64] }
%sollang.enum.2302 = type { i32, [72 x i64] }
%sollang.enum.2303 = type { i32, [2 x i64] }
%sollang.enum.2304 = type { i32, [2 x i64] }
%sollang.enum.2305 = type { i32, [3 x i64] }
%sollang.enum.2306 = type { i32, [2 x i64] }
%sollang.enum.2307 = type { i32, [13 x i64] }
%sollang.enum.2308 = type { i32, [26 x i64] }
%sollang.enum.2309 = type { i32, [5 x i64] }
%sollang.enum.2310 = type { i32, [2 x i64] }
%sollang.enum.2313 = type { i32, [2 x i64] }
%sollang.enum.2314 = type { i32, [72 x i64] }
%sollang.enum.2315 = type { i32, [3 x i64] }
%sollang.enum.2316 = type { i32, [13 x i64] }
%sollang.enum.2317 = type { i32, [70 x i64] }
%sollang.enum.2318 = type { i32, [2 x i64] }
%sollang.enum.2319 = type { i32, [3 x i64] }
%sollang.enum.2320 = type { i32, [40 x i64] }
%sollang.enum.2324 = type { i32, [10 x i64] }
%sollang.enum.2325 = type { i32, [11 x i64] }
%sollang.enum.2326 = type { i32, [2 x i64] }
%sollang.enum.2327 = type { i32, [1 x i64] }
%sollang.enum.2328 = type { i32, [5 x i64] }
%sollang.enum.2329 = type { i32, [3 x i64] }
%sollang.enum.2330 = type { i32, [3 x i64] }
%sollang.enum.2331 = type { i32, [10 x i64] }
%sollang.enum.2332 = type { i32, [33 x i64] }
%sollang.enum.2333 = type { i32, [35 x i64] }
%sollang.enum.2334 = type { i32, [1 x i64] }
%sollang.enum.2336 = type { i32, [8 x i64] }
%sollang.enum.2337 = type { i32, [2 x i64] }
%sollang.enum.2338 = type { i32, [2 x i64] }
%sollang.enum.2339 = type { i32, [1 x i64] }
%sollang.enum.2340 = type { i32, [2 x i64] }
%sollang.enum.2343 = type { i32, [3 x i64] }
%sollang.enum.2345 = type { i32, [2 x i64] }
%sollang.enum.2346 = type { i32, [2 x i64] }
%sollang.enum.2347 = type { i32, [2 x i64] }
%sollang.enum.2348 = type { i32, [5 x i64] }
%sollang.enum.2349 = type { i32, [11 x i64] }
%sollang.enum.2350 = type { i32, [9 x i64] }
%sollang.enum.2352 = type { i32, [3 x i64] }
%sollang.enum.2353 = type { i32, [2 x i64] }
%sollang.enum.2354 = type { i32, [2 x i64] }
%sollang.enum.2355 = type { i32, [2 x i64] }
%sollang.enum.2356 = type { i32, [2 x i64] }
%sollang.enum.2357 = type { i32, [2 x i64] }
%sollang.enum.2358 = type { i32, [2 x i64] }
%sollang.enum.2359 = type { i32, [2 x i64] }
%sollang.enum.2360 = type { i32, [2 x i64] }
%sollang.enum.2361 = type { i32, [3 x i64] }
%sollang.enum.2362 = type { i32, [3 x i64] }
%sollang.enum.2363 = type { i32, [4 x i64] }
%sollang.enum.2364 = type { i32, [2 x i64] }
%sollang.enum.2365 = type { i32, [4 x i64] }
%sollang.enum.2366 = type { i32, [4 x i64] }
%sollang.enum.2367 = type { i32, [2 x i64] }
%sollang.enum.2368 = type { i32, [8 x i64] }
%sollang.enum.2369 = type { i32, [2 x i64] }
%sollang.enum.2370 = type { i32, [4 x i64] }
%sollang.enum.2371 = type { i32, [3 x i64] }
%sollang.enum.2372 = type { i32, [2 x i64] }
%sollang.enum.2373 = type { i32, [2 x i64] }
%sollang.enum.2374 = type { i32, [5 x i64] }
%sollang.enum.2375 = type { i32, [10 x i64] }
%sollang.enum.2376 = type { i32, [10 x i64] }
%sollang.enum.2377 = type { i32, [11 x i64] }
%sollang.enum.2378 = type { i32, [11 x i64] }
%sollang.enum.2379 = type { i32, [7 x i64] }
%sollang.enum.2380 = type { i32, [8 x i64] }
%sollang.enum.2381 = type { i32, [7 x i64] }
%sollang.enum.2382 = type { i32, [8 x i64] }
%sollang.enum.2383 = type { i32, [2 x i64] }
%sollang.enum.2384 = type { i32, [7 x i64] }
%sollang.enum.2385 = type { i32, [7 x i64] }
%sollang.enum.2386 = type { i32, [3 x i64] }
%sollang.enum.2387 = type { i32, [3 x i64] }
%sollang.enum.2388 = type { i32, [2 x i64] }
%sollang.enum.2389 = type { i32, [2 x i64] }
%sollang.enum.2391 = type { i32, [2 x i64] }
%sollang.enum.2392 = type { i32, [4 x i64] }
%sollang.enum.2393 = type { i32, [3 x i64] }
%sollang.enum.2394 = type { i32, [3 x i64] }
%sollang.enum.2395 = type { i32, [13 x i64] }
%sollang.enum.2396 = type { i32, [12 x i64] }
%sollang.enum.2397 = type { i32, [4 x i64] }
%sollang.enum.2398 = type { i32, [2 x i64] }
%sollang.enum.2399 = type { i32, [2 x i64] }
%sollang.enum.2401 = type { i32, [2 x i64] }
%sollang.enum.2402 = type { i32, [5 x i64] }
%sollang.enum.2403 = type { i32, [3 x i64] }
%sollang.enum.2404 = type { i32, [15 x i64] }
%sollang.enum.2405 = type { i32, [3 x i64] }
%sollang.enum.2406 = type { i32, [2 x i64] }
%sollang.enum.2407 = type { i32, [3 x i64] }
%sollang.enum.2412 = type { i32, [2 x i64] }
%sollang.enum.2413 = type { i32, [3 x i64] }
%sollang.enum.2414 = type { i32, [3 x i64] }
%sollang.enum.2415 = type { i32, [15 x i64] }
%sollang.enum.2416 = type { i32, [25 x i64] }
%sollang.enum.2417 = type { i32, [7 x i64] }
%sollang.enum.2418 = type { i32, [5 x i64] }
%sollang.enum.2419 = type { i32, [9 x i64] }
%sollang.enum.2420 = type { i32, [31 x i64] }
%sollang.enum.2421 = type { i32, [3 x i64] }
%sollang.enum.2422 = type { i32, [8 x i64] }
%sollang.enum.2423 = type { i32, [2 x i64] }
%sollang.enum.2424 = type { i32, [12 x i64] }
%sollang.enum.2425 = type { i32, [6 x i64] }
%sollang.enum.2426 = type { i32, [2 x i64] }
%sollang.enum.2427 = type { i32, [9 x i64] }
%sollang.enum.2428 = type { i32, [6 x i64] }
%sollang.enum.2429 = type { i32, [3 x i64] }
%sollang.enum.2430 = type { i32, [26 x i64] }
%sollang.enum.2431 = type { i32, [4 x i64] }
%sollang.enum.2432 = type { i32, [5 x i64] }
%sollang.enum.2433 = type { i32, [8 x i64] }
%sollang.enum.2434 = type { i32, [40 x i64] }
%sollang.enum.2435 = type { i32, [9 x i64] }
%sollang.enum.2436 = type { i32, [3 x i64] }
%sollang.enum.2440 = type { i32, [2 x i64] }
%sollang.enum.2441 = type { i32, [2 x i64] }
%sollang.enum.2442 = type { i32, [9 x i64] }
%sollang.enum.2443 = type { i32, [21 x i64] }
%sollang.enum.2444 = type { i32, [2 x i64] }
%sollang.enum.2445 = type { i32, [2 x i64] }
%sollang.enum.2446 = type { i32, [4 x i64] }
%sollang.enum.2447 = type { i32, [3 x i64] }
%sollang.enum.2448 = type { i32, [9 x i64] }
%sollang.enum.2449 = type { i32, [2 x i64] }
%sollang.enum.2450 = type { i32, [5 x i64] }
%sollang.enum.2451 = type { i32, [2 x i64] }
%sollang.enum.2452 = type { i32, [14 x i64] }
%sollang.enum.2454 = type { i32, [11 x i64] }
%sollang.enum.2455 = type { i32, [16 x i64] }
%sollang.enum.2456 = type { i32, [7 x i64] }
%sollang.enum.2459 = type { i32, [7 x i64] }
%sollang.enum.2460 = type { i32, [4 x i64] }
%sollang.enum.2461 = type { i32, [6 x i64] }
%sollang.enum.2462 = type { i32, [7 x i64] }
%sollang.enum.2463 = type { i32, [6 x i64] }
%sollang.enum.2464 = type { i32, [5 x i64] }
%sollang.enum.2465 = type { i32, [2 x i64] }
%sollang.enum.2466 = type { i32, [4 x i64] }
%sollang.enum.2467 = type { i32, [10 x i64] }
%sollang.enum.2468 = type { i32, [131 x i64] }
%sollang.enum.2469 = type { i32, [2 x i64] }
%sollang.enum.2470 = type { i32, [16 x i64] }
%sollang.enum.2471 = type { i32, [7 x i64] }
%sollang.enum.2472 = type { i32, [10 x i64] }
%sollang.enum.2473 = type { i32, [5 x i64] }
%sollang.enum.2475 = type { i32, [2 x i64] }
%sollang.enum.2476 = type { i32, [17 x i64] }
%sollang.enum.2478 = type { i32, [10 x i64] }
%sollang.enum.2479 = type { i32, [5 x i64] }
%sollang.enum.2480 = type { i32, [3 x i64] }
%sollang.enum.2481 = type { i32, [8 x i64] }
%sollang.enum.2482 = type { i32, [2 x i64] }
%sollang.enum.2483 = type { i32, [4 x i64] }
%sollang.enum.2484 = type { i32, [2 x i64] }
%sollang.enum.2485 = type { i32, [9 x i64] }
%sollang.enum.2486 = type { i32, [3 x i64] }
%sollang.enum.2487 = type { i32, [7 x i64] }
%sollang.enum.2488 = type { i32, [11 x i64] }
%sollang.enum.2489 = type { i32, [7 x i64] }
%sollang.enum.2493 = type { i32, [6 x i64] }
%sollang.enum.2495 = type { i32, [11 x i64] }
%sollang.enum.2496 = type { i32, [2 x i64] }
%sollang.enum.2497 = type { i32, [18 x i64] }
%sollang.enum.2498 = type { i32, [149 x i64] }
%sollang.enum.2500 = type { i32, [3 x i64] }
%sollang.enum.2501 = type { i32, [2 x i64] }
%sollang.enum.2502 = type { i32, [2 x i64] }
%sollang.enum.2504 = type { i32, [12 x i64] }
%sollang.enum.2505 = type { i32, [9 x i64] }
%sollang.enum.2506 = type { i32, [5 x i64] }
%sollang.enum.2507 = type { i32, [5 x i64] }
%sollang.enum.2508 = type { i32, [6 x i64] }
%sollang.enum.2509 = type { i32, [6 x i64] }
%sollang.enum.2510 = type { i32, [2 x i64] }
%sollang.enum.2511 = type { i32, [14 x i64] }
%sollang.enum.2512 = type { i32, [6 x i64] }
%sollang.enum.2513 = type { i32, [6 x i64] }
%sollang.enum.2514 = type { i32, [4 x i64] }
%sollang.enum.2515 = type { i32, [5 x i64] }
%sollang.enum.2516 = type { i32, [4 x i64] }
%sollang.enum.2517 = type { i32, [21 x i64] }
%sollang.enum.2518 = type { i32, [4 x i64] }
%sollang.enum.2519 = type { i32, [5 x i64] }
%sollang.enum.2520 = type { i32, [2 x i64] }
%sollang.enum.2522 = type { i32, [3 x i64] }
%sollang.enum.2523 = type { i32, [4 x i64] }
%sollang.enum.2524 = type { i32, [2 x i64] }
%sollang.enum.2525 = type { i32, [6 x i64] }
%sollang.enum.2526 = type { i32, [5 x i64] }
%sollang.enum.2527 = type { i32, [5 x i64] }
%sollang.enum.2530 = type { i32, [16 x i64] }
%sollang.enum.2531 = type { i32, [7 x i64] }
%sollang.enum.2532 = type { i32, [6 x i64] }
%sollang.enum.2533 = type { i32, [4 x i64] }
%sollang.enum.2534 = type { i32, [5 x i64] }
%sollang.enum.2535 = type { i32, [2 x i64] }
%sollang.enum.2536 = type { i32, [2 x i64] }
%sollang.enum.2537 = type { i32, [4 x i64] }
%sollang.enum.2539 = type { i32, [9 x i64] }
%sollang.enum.2540 = type { i32, [4 x i64] }
%sollang.enum.2541 = type { i32, [3 x i64] }
%sollang.enum.2542 = type { i32, [17 x i64] }
%sollang.enum.2543 = type { i32, [2 x i64] }
%sollang.enum.2544 = type { i32, [3 x i64] }
%sollang.enum.2545 = type { i32, [12 x i64] }
%sollang.enum.2546 = type { i32, [3 x i64] }
%sollang.enum.2547 = type { i32, [4 x i64] }
%sollang.enum.2548 = type { i32, [12 x i64] }
%sollang.enum.2549 = type { i32, [4 x i64] }
%sollang.enum.2550 = type { i32, [3 x i64] }
%sollang.enum.2551 = type { i32, [3 x i64] }
%sollang.enum.2552 = type { i32, [4 x i64] }
%sollang.enum.2553 = type { i32, [2 x i64] }
%sollang.enum.2554 = type { i32, [3 x i64] }
%sollang.enum.2556 = type { i32, [6 x i64] }
%sollang.enum.2557 = type { i32, [3 x i64] }
%sollang.enum.2558 = type { i32, [2 x i64] }
%sollang.enum.2559 = type { i32, [2 x i64] }
%sollang.enum.2560 = type { i32, [2 x i64] }
%sollang.enum.2561 = type { i32, [3 x i64] }
%sollang.enum.2562 = type { i32, [2 x i64] }
%sollang.enum.2563 = type { i32, [2 x i64] }
%sollang.enum.2564 = type { i32, [12 x i64] }
%sollang.enum.2565 = type { i32, [6 x i64] }
%sollang.enum.2566 = type { i32, [3 x i64] }
%sollang.enum.2567 = type { i32, [2 x i64] }
%sollang.enum.2568 = type { i32, [8 x i64] }
%sollang.enum.2570 = type { i32, [2 x i64] }
%sollang.enum.2571 = type { i32, [4 x i64] }
%sollang.enum.2574 = type { i32, [4 x i64] }
%sollang.enum.2575 = type { i32, [4 x i64] }
%sollang.enum.2576 = type { i32, [7 x i64] }
%sollang.enum.2577 = type { i32, [4 x i64] }
%sollang.enum.2579 = type { i32, [9 x i64] }
%sollang.enum.2580 = type { i32, [2 x i64] }
%sollang.enum.2581 = type { i32, [4 x i64] }
%sollang.enum.2582 = type { i32, [1 x i64] }
%sollang.enum.2583 = type { i32, [1 x i64] }
%sollang.enum.2584 = type { i32, [2 x i64] }
%sollang.enum.2585 = type { i32, [2 x i64] }
%sollang.enum.2586 = type { i32, [2 x i64] }
%sollang.enum.2587 = type { i32, [6 x i64] }
%sollang.enum.2588 = type { i32, [1 x i64] }
%sollang.enum.2589 = type { i32, [1 x i64] }
%sollang.enum.2590 = type { i32, [1 x i64] }
%sollang.enum.2591 = type { i32, [1 x i64] }
%sollang.enum.2592 = type { i32, [11 x i64] }
%sollang.enum.2593 = type { i32, [29 x i64] }
%sollang.enum.2594 = type { i32, [12 x i64] }
%sollang.enum.2595 = type { i32, [2 x i64] }
%sollang.enum.2596 = type { i32, [3 x i64] }
%sollang.enum.2597 = type { i32, [2 x i64] }
%sollang.enum.2599 = type { i32, [2 x i64] }
%sollang.enum.2600 = type { i32, [3 x i64] }
%sollang.enum.2601 = type { i32, [2 x i64] }
%sollang.enum.2602 = type { i32, [1 x i64] }
%sollang.enum.2603 = type { i32, [1 x i64] }
%sollang.enum.2606 = type { i32, [2 x i64] }
%sollang.enum.2607 = type { i32, [2 x i64] }
%sollang.enum.2608 = type { i32, [2 x i64] }
%sollang.enum.2611 = type { i32, [2 x i64] }
%sollang.enum.2612 = type { i32, [7 x i64] }
%sollang.enum.2613 = type { i32, [4 x i64] }
%sollang.enum.2614 = type { i32, [2 x i64] }
%sollang.enum.2615 = type { i32, [2 x i64] }
%sollang.enum.2617 = type { i32, [3 x i64] }
%sollang.enum.2620 = type { i32, [6 x i64] }
%sollang.enum.2621 = type { i32, [2 x i64] }
%sollang.enum.2622 = type { i32, [3 x i64] }
%sollang.enum.2623 = type { i32, [8 x i64] }
%sollang.enum.2624 = type { i32, [2 x i64] }
%sollang.enum.2625 = type { i32, [3 x i64] }
%sollang.enum.2626 = type { i32, [1 x i64] }
%sollang.enum.2627 = type { i32, [2 x i64] }
%sollang.enum.2628 = type { i32, [2 x i64] }
%sollang.enum.2630 = type { i32, [2 x i64] }
%sollang.enum.2631 = type { i32, [4 x i64] }
%sollang.enum.2632 = type { i32, [3 x i64] }
%sollang.enum.2633 = type { i32, [18 x i64] }
%sollang.enum.2634 = type { i32, [3 x i64] }
%sollang.enum.2635 = type { i32, [16 x i64] }
%sollang.enum.2636 = type { i32, [2 x i64] }
%sollang.enum.2637 = type { i32, [2 x i64] }
%sollang.enum.2638 = type { i32, [2 x i64] }
%sollang.enum.2639 = type { i32, [2 x i64] }
%sollang.enum.2641 = type { i32, [1 x i64] }
%sollang.enum.2642 = type { i32, [2 x i64] }
%sollang.enum.2643 = type { i32, [5 x i64] }
%sollang.enum.2644 = type { i32, [2 x i64] }
%sollang.enum.2645 = type { i32, [3 x i64] }
%sollang.enum.2648 = type { i32, [2 x i64] }
%sollang.enum.2649 = type { i32, [9 x i64] }
%sollang.enum.2650 = type { i32, [7 x i64] }

@sollang_file_writer = internal global ptr null
@sollang_file_reader = internal global ptr null
@sollang_argument_count_value = internal global i64 0
@sollang_argument_records = internal global ptr null
@sollang_environment_allocations = internal global ptr null
@sollang_environment_empty = internal constant [1 x i8] zeroinitializer, align 1
@sollang_stdout_buffer = internal global [1048576 x i8] zeroinitializer, align 16
@sollang_stdout_buffer_count = internal global i64 0
@sollang_stdout_line_buffered = internal global i1 false
@_fltused = global i32 0
@sollang_random_state = internal global i64 88172645463393265
@sollang_writer_buffer = internal global [8192 x i64] zeroinitializer, align 8
@sollang_writer_buffer_count = internal global i64 0

declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @GetConsoleMode(ptr, ptr)
declare dllimport i32 @WriteConsoleW(ptr, ptr, i32, ptr, ptr)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare dllimport i32 @ReadFile(ptr, ptr, i32, ptr, ptr)
declare dllimport i32 @GetOverlappedResult(ptr, ptr, ptr, i32)
declare dllimport ptr @CreateFileA(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport i32 @CloseHandle(ptr)
declare dllimport ptr @GetCurrentProcess()
declare dllimport i32 @DuplicateHandle(ptr, ptr, ptr, ptr, i32, i32, i32)
declare dllimport i32 @SetFilePointerEx(ptr, i64, ptr, i32)
declare dllimport i32 @GetFileSizeEx(ptr, ptr)
declare dllimport i32 @SetEndOfFile(ptr)
declare dllimport ptr @CreateFileMappingA(ptr, ptr, i32, i32, i32, ptr)
declare dllimport ptr @MapViewOfFile(ptr, i32, i32, i32, i64)
declare dllimport i32 @UnmapViewOfFile(ptr)
declare dllimport i32 @FlushViewOfFile(ptr, i64)
declare dllimport i32 @FlushFileBuffers(ptr)
declare dllimport i32 @MoveFileExA(ptr, ptr, i32)
declare dllimport i32 @MoveFileExW(ptr, ptr, i32)
declare dllimport i32 @DeleteFileA(ptr)
declare dllimport i32 @DeleteFileW(ptr)
declare dllimport ptr @GetProcessHeap()
declare dllimport ptr @HeapAlloc(ptr, i32, i64)
declare dllimport i32 @HeapFree(ptr, i32, ptr)
declare dllimport i64 @GetTickCount64()
declare dllimport void @GetSystemTimePreciseAsFileTime(ptr)
declare dllimport void @Sleep(i32)
declare dllimport ptr @GetCommandLineW()
declare dllimport ptr @CommandLineToArgvW(ptr, ptr)
declare dllimport i32 @WideCharToMultiByte(i32, i32, ptr, i32, ptr, i32, ptr, ptr)
declare dllimport ptr @LocalFree(ptr)
declare dllimport i32 @MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)
declare dllimport i32 @GetEnvironmentVariableW(ptr, ptr, i32)
declare dllimport i32 @GetLastError()
declare dllimport void @SetLastError(i32)
define internal i32 @sollang_windows_utf8_path(ptr %data, i64 %length, ptr %wide, i32 %capacity) #0 {
entry:
  %positive = icmp ugt i64 %length, 0
  %fits_i32 = icmp ule i64 %length, 2147483647
  %length_valid = and i1 %positive, %fits_i32
  br i1 %length_valid, label %check, label %failure
check:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %convert, label %inspect
inspect:
  %byte_ptr = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %failure, label %advance
advance:
  %next = add i64 %index, 1
  br label %check
convert:
  %length32 = trunc i64 %length to i32
  %room = sub i32 %capacity, 1
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length32, ptr %wide, i32 %room)
  %converted_ok = icmp sgt i32 %converted, 0
  br i1 %converted_ok, label %terminate, label %failure
terminate:
  %zero = getelementptr i16, ptr %wide, i32 %converted
  store i16 0, ptr %zero, align 2
  ret i32 1
failure:
  ret i32 0
}

declare void @llvm.trap()
declare i64 @llvm.ctpop.i64(i64)
declare i16 @llvm.cttz.i16(i16, i1 immarg)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg)
declare void @llvm.memcpy.p0.p0.i64(ptr nocapture writeonly, ptr nocapture readonly, i64, i1 immarg)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)

@.slg.str.module.x.0 = private unnamed_addr constant [26 x i8] c".addScores:bb_alloc_fail19", align 1
@.slg.str.module.x.1 = private unnamed_addr constant [26 x i8] c".addScores:bb_alloc_fail70", align 1
@.slg.str.module.x.2 = private unnamed_addr constant [43 x i8] c".replaceFirst:bb_dict_assign_missing_fail12", align 1
define internal void @sollang_fn_addScores(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.mutable_container %it) #0 {
entry:
  %trap_written84 = alloca i32, align 4
  %trap_written303 = alloca i32, align 4
  %param_mut_ptr_addr0 = extractvalue %sollang.mutable_container %it, 0
  %param_mut_len_addr1 = extractvalue %sollang.mutable_container %it, 1
  %param_mut_capacity_addr2 = extractvalue %sollang.mutable_container %it, 2
  %mutable_ptr3 = load ptr, ptr %param_mut_ptr_addr0, align 8
  %mutable_len4 = load i64, ptr %param_mut_len_addr1, align 8
  %mutable_capacity5 = load i64, ptr %param_mut_capacity_addr2, align 8
  %hash_key6 = sext i32 3 to i64
  %hash_high8 = lshr i64 %hash_key6, 32
  %hash_fold7 = xor i64 %hash_key6, %hash_high8
  %hash9 = mul i64 %hash_fold7, -7046029254386353131
  %dict_h2_shifted10 = lshr i64 %hash9, 57
  %dict_h2_raw11 = and i64 %dict_h2_shifted10, 127
  %dict_h2_zero12 = icmp eq i64 %dict_h2_raw11, 0
  %dict_h213 = select i1 %dict_h2_zero12, i64 1, i64 %dict_h2_raw11
  %dict_h2_byte14 = trunc i64 %dict_h213 to i8
  %dict_capacity_mask15 = sub i64 %mutable_capacity5, 1
  %dict_start_slot16 = and i64 %hash9, %dict_capacity_mask15
  br label %bb_dict_group_find0

bb_dict_group_find0:
  %dict_group_probe18 = phi i64 [ 0, %entry ], [ %dict_group_next_probe17, %bb_dict_group_next8 ]
  %dict_group_active19 = icmp ult i64 %dict_group_probe18, %mutable_capacity5
  br i1 %dict_group_active19, label %bb_dict_group_body1, label %bb_dict_group_miss9

bb_dict_group_body1:
  %dict_group_unwrapped20 = add i64 %dict_start_slot16, %dict_group_probe18
  %dict_group_start21 = and i64 %dict_group_unwrapped20, %dict_capacity_mask15
  %dict_group_pointer22 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_group_start21
  %dict_group_controls23 = load <16 x i8>, ptr %dict_group_pointer22, align 1
  %dict_group_h2_seed24 = insertelement <16 x i8> poison, i8 %dict_h2_byte14, i64 0
  %dict_group_h2_vector25 = shufflevector <16 x i8> %dict_group_h2_seed24, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector26 = icmp eq <16 x i8> %dict_group_controls23, %dict_group_h2_vector25
  %dict_group_match_bits27 = bitcast <16 x i1> %dict_group_matches_vector26 to i16
  %dict_group_empty_vector28 = icmp eq <16 x i8> %dict_group_controls23, zeroinitializer
  %dict_group_empty_bits29 = bitcast <16 x i1> %dict_group_empty_vector28 to i16
  br label %bb_dict_group_candidates2

bb_dict_group_candidates2:
  %dict_group_candidate_bits30 = phi i16 [ %dict_group_match_bits27, %bb_dict_group_body1 ], [ %dict_group_cleared_bits31, %bb_dict_group_candidate_next4 ]
  %dict_group_has_candidate32 = icmp ne i16 %dict_group_candidate_bits30, 0
  br i1 %dict_group_has_candidate32, label %bb_dict_group_candidate_body3, label %bb_dict_group_decision5

bb_dict_group_candidate_body3:
  %dict_group_candidate_offset1633 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits30, i1 false)
  %dict_group_candidate_offset34 = zext i16 %dict_group_candidate_offset1633 to i64
  %dict_group_candidate_unwrapped35 = add i64 %dict_group_start21, %dict_group_candidate_offset34
  %dict_group_candidate_slot36 = and i64 %dict_group_candidate_unwrapped35, %dict_capacity_mask15
  %dict_entries_offset_mirror37 = add i64 %mutable_capacity5, 23
  %dict_entries_offset38 = and i64 %dict_entries_offset_mirror37, -8
  %dict_entries39 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset38
  %dict_key_offset40 = mul i64 %dict_group_candidate_slot36, 2
  %dict_key_slot41 = getelementptr i32, ptr %dict_entries39, i64 %dict_key_offset40
  %dict_key42 = load i32, ptr %dict_key_slot41, align 4
  %dict_group_key_match43 = icmp eq i32 %dict_key42, 3
  br i1 %dict_group_key_match43, label %bb_dict_group_match7, label %bb_dict_group_candidate_next4

bb_dict_group_candidate_next4:
  %dict_group_bits_minus_one44 = sub i16 %dict_group_candidate_bits30, 1
  %dict_group_cleared_bits31 = and i16 %dict_group_candidate_bits30, %dict_group_bits_minus_one44
  br label %bb_dict_group_candidates2

bb_dict_group_decision5:
  %dict_group_has_empty45 = icmp ne i16 %dict_group_empty_bits29, 0
  br i1 %dict_group_has_empty45, label %bb_dict_group_empty6, label %bb_dict_group_next8

bb_dict_group_empty6:
  %dict_group_empty_offset1646 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits29, i1 false)
  %dict_group_empty_offset47 = zext i16 %dict_group_empty_offset1646 to i64
  %dict_group_empty_unwrapped48 = add i64 %dict_group_start21, %dict_group_empty_offset47
  %dict_group_empty_slot49 = and i64 %dict_group_empty_unwrapped48, %dict_capacity_mask15
  br label %bb_dict_group_done10

bb_dict_group_match7:
  br label %bb_dict_group_done10

bb_dict_group_next8:
  %dict_group_next_probe17 = add i64 %dict_group_probe18, 16
  br label %bb_dict_group_find0

bb_dict_group_miss9:
  br label %bb_dict_group_done10

bb_dict_group_done10:
  %dict_find_found50 = phi i1 [ false, %bb_dict_group_empty6 ], [ true, %bb_dict_group_match7 ], [ false, %bb_dict_group_miss9 ]
  %dict_find_found_slot51 = phi i64 [ %dict_group_empty_slot49, %bb_dict_group_empty6 ], [ %dict_group_candidate_slot36, %bb_dict_group_match7 ], [ 0, %bb_dict_group_miss9 ]
  br i1 %dict_find_found50, label %bb_dict_put_update11, label %bb_dict_put_insert12

bb_dict_put_update11:
  %dict_entries_offset_mirror52 = add i64 %mutable_capacity5, 23
  %dict_entries_offset53 = and i64 %dict_entries_offset_mirror52, -8
  %dict_entries54 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset53
  %dict_offset55 = mul i64 %dict_find_found_slot51, 2
  %dict_key_slot56 = getelementptr i32, ptr %dict_entries54, i64 %dict_offset55
  %dict_value_offset57 = add i64 %dict_offset55, 1
  %dict_value_slot58 = getelementptr i32, ptr %dict_entries54, i64 %dict_value_offset57
  store i32 3, ptr %dict_key_slot56, align 4
  store i32 300, ptr %dict_value_slot58, align 4
  br label %bb_dict_put_done15

bb_dict_put_insert12:
  %dict_next_len59 = add i64 %mutable_len4, 1
  %dict_load_numerator60 = mul i64 %dict_next_len59, 8
  %dict_load_denominator61 = mul i64 %mutable_capacity5, 7
  %dict_should_grow62 = icmp ugt i64 %dict_load_numerator60, %dict_load_denominator61
  br i1 %dict_should_grow62, label %bb_dict_put_insert_grow14, label %bb_dict_put_insert_current13

bb_dict_put_insert_current13:
  %dict_entries_offset_mirror63 = add i64 %mutable_capacity5, 23
  %dict_entries_offset64 = and i64 %dict_entries_offset_mirror63, -8
  %dict_entries65 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset64
  %dict_offset66 = mul i64 %dict_find_found_slot51, 2
  %dict_key_slot67 = getelementptr i32, ptr %dict_entries65, i64 %dict_offset66
  %dict_value_offset68 = add i64 %dict_offset66, 1
  %dict_value_slot69 = getelementptr i32, ptr %dict_entries65, i64 %dict_value_offset68
  store i32 3, ptr %dict_key_slot67, align 4
  store i32 300, ptr %dict_value_slot69, align 4
  %dict_control_slot70 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_find_found_slot51
  store i8 %dict_h2_byte14, ptr %dict_control_slot70, align 1
  %dict_control_mirrored71 = icmp ult i64 %dict_find_found_slot51, 16
  br i1 %dict_control_mirrored71, label %bb_dict_control_mirror16, label %bb_dict_control_done17

bb_dict_control_mirror16:
  %dict_control_mirror_index72 = add i64 %mutable_capacity5, %dict_find_found_slot51
  %dict_control_mirror_slot73 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_control_mirror_index72
  store i8 %dict_h2_byte14, ptr %dict_control_mirror_slot73, align 1
  br label %bb_dict_control_done17

bb_dict_control_done17:
  br label %bb_dict_put_done15

bb_dict_put_insert_grow14:
  %dict_has_capacity74 = icmp eq i64 %mutable_capacity5, 0
  %dict_doubled_capacity75 = mul i64 %mutable_capacity5, 2
  %dict_new_capacity76 = select i1 %dict_has_capacity74, i64 4, i64 %dict_doubled_capacity75
  %dict_entries_offset_mirror77 = add i64 %dict_new_capacity76, 23
  %dict_entries_offset78 = and i64 %dict_entries_offset_mirror77, -8
  %dict_entries_bytes79 = mul i64 %dict_new_capacity76, 8
  %dict_bytes80 = add i64 %dict_entries_offset78, %dict_entries_bytes79
  %heap81 = call ptr @sollang_alloc(i64 %dict_bytes80)
  %heap_ok82 = icmp ne ptr %heap81, null
  br i1 %heap_ok82, label %bb_alloc_ok18, label %bb_alloc_fail19

bb_alloc_fail19:
  %trap_stderr83 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr83, ptr @.slg.str.module.x.0, i32 26, ptr %trap_written84, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok18:
  %dict_control_bytes85 = add i64 %dict_new_capacity76, 16
  call void @llvm.memset.p0.i64(ptr %heap81, i8 0, i64 %dict_control_bytes85, i1 false)
  br label %bb_dict_rehash20

bb_dict_rehash20:
  %dict_rehash_i87 = phi i64 [ 0, %bb_alloc_ok18 ], [ %dict_rehash_next_i86, %bb_dict_rehash_next23 ]
  %dict_rehash_active88 = icmp ult i64 %dict_rehash_i87, %mutable_capacity5
  br i1 %dict_rehash_active88, label %bb_dict_rehash_body21, label %bb_dict_rehash_done24

bb_dict_rehash_body21:
  %dict_control_slot89 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_rehash_i87
  %dict_control90 = load i8, ptr %dict_control_slot89, align 1
  %dict_rehash_full91 = icmp ne i8 %dict_control90, 0
  br i1 %dict_rehash_full91, label %bb_dict_rehash_move22, label %bb_dict_rehash_next23

bb_dict_rehash_move22:
  %dict_entries_offset_mirror92 = add i64 %mutable_capacity5, 23
  %dict_entries_offset93 = and i64 %dict_entries_offset_mirror92, -8
  %dict_entries94 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset93
  %dict_key_offset95 = mul i64 %dict_rehash_i87, 2
  %dict_key_slot96 = getelementptr i32, ptr %dict_entries94, i64 %dict_key_offset95
  %dict_key97 = load i32, ptr %dict_key_slot96, align 4
  %dict_entries_offset_mirror98 = add i64 %mutable_capacity5, 23
  %dict_entries_offset99 = and i64 %dict_entries_offset_mirror98, -8
  %dict_entries100 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset99
  %dict_value_base101 = mul i64 %dict_rehash_i87, 2
  %dict_value_offset102 = add i64 %dict_value_base101, 1
  %dict_value_slot103 = getelementptr i32, ptr %dict_entries100, i64 %dict_value_offset102
  %dict_value104 = load i32, ptr %dict_value_slot103, align 4
  %hash_key105 = sext i32 %dict_key97 to i64
  %hash_high107 = lshr i64 %hash_key105, 32
  %hash_fold106 = xor i64 %hash_key105, %hash_high107
  %hash108 = mul i64 %hash_fold106, -7046029254386353131
  %dict_h2_shifted109 = lshr i64 %hash108, 57
  %dict_h2_raw110 = and i64 %dict_h2_shifted109, 127
  %dict_h2_zero111 = icmp eq i64 %dict_h2_raw110, 0
  %dict_h2112 = select i1 %dict_h2_zero111, i64 1, i64 %dict_h2_raw110
  %dict_h2_byte113 = trunc i64 %dict_h2112 to i8
  %dict_capacity_mask114 = sub i64 %dict_new_capacity76, 1
  %dict_start_slot115 = and i64 %hash108, %dict_capacity_mask114
  br label %bb_dict_group_find25

bb_dict_group_find25:
  %dict_group_probe117 = phi i64 [ 0, %bb_dict_rehash_move22 ], [ %dict_group_next_probe116, %bb_dict_group_next33 ]
  %dict_group_active118 = icmp ult i64 %dict_group_probe117, %dict_new_capacity76
  br i1 %dict_group_active118, label %bb_dict_group_body26, label %bb_dict_group_miss34

bb_dict_group_body26:
  %dict_group_unwrapped119 = add i64 %dict_start_slot115, %dict_group_probe117
  %dict_group_start120 = and i64 %dict_group_unwrapped119, %dict_capacity_mask114
  %dict_group_pointer121 = getelementptr i8, ptr %heap81, i64 %dict_group_start120
  %dict_group_controls122 = load <16 x i8>, ptr %dict_group_pointer121, align 1
  %dict_group_h2_seed123 = insertelement <16 x i8> poison, i8 %dict_h2_byte113, i64 0
  %dict_group_h2_vector124 = shufflevector <16 x i8> %dict_group_h2_seed123, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector125 = icmp eq <16 x i8> %dict_group_controls122, %dict_group_h2_vector124
  %dict_group_match_bits126 = bitcast <16 x i1> %dict_group_matches_vector125 to i16
  %dict_group_empty_vector127 = icmp eq <16 x i8> %dict_group_controls122, zeroinitializer
  %dict_group_empty_bits128 = bitcast <16 x i1> %dict_group_empty_vector127 to i16
  br label %bb_dict_group_candidates27

bb_dict_group_candidates27:
  %dict_group_candidate_bits129 = phi i16 [ %dict_group_match_bits126, %bb_dict_group_body26 ], [ %dict_group_cleared_bits130, %bb_dict_group_candidate_next29 ]
  %dict_group_has_candidate131 = icmp ne i16 %dict_group_candidate_bits129, 0
  br i1 %dict_group_has_candidate131, label %bb_dict_group_candidate_body28, label %bb_dict_group_decision30

bb_dict_group_candidate_body28:
  %dict_group_candidate_offset16132 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits129, i1 false)
  %dict_group_candidate_offset133 = zext i16 %dict_group_candidate_offset16132 to i64
  %dict_group_candidate_unwrapped134 = add i64 %dict_group_start120, %dict_group_candidate_offset133
  %dict_group_candidate_slot135 = and i64 %dict_group_candidate_unwrapped134, %dict_capacity_mask114
  %dict_entries_offset_mirror136 = add i64 %dict_new_capacity76, 23
  %dict_entries_offset137 = and i64 %dict_entries_offset_mirror136, -8
  %dict_entries138 = getelementptr i8, ptr %heap81, i64 %dict_entries_offset137
  %dict_key_offset139 = mul i64 %dict_group_candidate_slot135, 2
  %dict_key_slot140 = getelementptr i32, ptr %dict_entries138, i64 %dict_key_offset139
  %dict_key141 = load i32, ptr %dict_key_slot140, align 4
  %dict_group_key_match142 = icmp eq i32 %dict_key141, %dict_key97
  br i1 %dict_group_key_match142, label %bb_dict_group_match32, label %bb_dict_group_candidate_next29

bb_dict_group_candidate_next29:
  %dict_group_bits_minus_one143 = sub i16 %dict_group_candidate_bits129, 1
  %dict_group_cleared_bits130 = and i16 %dict_group_candidate_bits129, %dict_group_bits_minus_one143
  br label %bb_dict_group_candidates27

bb_dict_group_decision30:
  %dict_group_has_empty144 = icmp ne i16 %dict_group_empty_bits128, 0
  br i1 %dict_group_has_empty144, label %bb_dict_group_empty31, label %bb_dict_group_next33

bb_dict_group_empty31:
  %dict_group_empty_offset16145 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits128, i1 false)
  %dict_group_empty_offset146 = zext i16 %dict_group_empty_offset16145 to i64
  %dict_group_empty_unwrapped147 = add i64 %dict_group_start120, %dict_group_empty_offset146
  %dict_group_empty_slot148 = and i64 %dict_group_empty_unwrapped147, %dict_capacity_mask114
  br label %bb_dict_group_done35

bb_dict_group_match32:
  br label %bb_dict_group_done35

bb_dict_group_next33:
  %dict_group_next_probe116 = add i64 %dict_group_probe117, 16
  br label %bb_dict_group_find25

bb_dict_group_miss34:
  br label %bb_dict_group_done35

bb_dict_group_done35:
  %dict_find_found149 = phi i1 [ false, %bb_dict_group_empty31 ], [ true, %bb_dict_group_match32 ], [ false, %bb_dict_group_miss34 ]
  %dict_find_found_slot150 = phi i64 [ %dict_group_empty_slot148, %bb_dict_group_empty31 ], [ %dict_group_candidate_slot135, %bb_dict_group_match32 ], [ 0, %bb_dict_group_miss34 ]
  %dict_entries_offset_mirror151 = add i64 %dict_new_capacity76, 23
  %dict_entries_offset152 = and i64 %dict_entries_offset_mirror151, -8
  %dict_entries153 = getelementptr i8, ptr %heap81, i64 %dict_entries_offset152
  %dict_offset154 = mul i64 %dict_find_found_slot150, 2
  %dict_key_slot155 = getelementptr i32, ptr %dict_entries153, i64 %dict_offset154
  %dict_value_offset156 = add i64 %dict_offset154, 1
  %dict_value_slot157 = getelementptr i32, ptr %dict_entries153, i64 %dict_value_offset156
  store i32 %dict_key97, ptr %dict_key_slot155, align 4
  store i32 %dict_value104, ptr %dict_value_slot157, align 4
  %dict_control_slot158 = getelementptr i8, ptr %heap81, i64 %dict_find_found_slot150
  store i8 %dict_h2_byte113, ptr %dict_control_slot158, align 1
  %dict_control_mirrored159 = icmp ult i64 %dict_find_found_slot150, 16
  br i1 %dict_control_mirrored159, label %bb_dict_control_mirror36, label %bb_dict_control_done37

bb_dict_control_mirror36:
  %dict_control_mirror_index160 = add i64 %dict_new_capacity76, %dict_find_found_slot150
  %dict_control_mirror_slot161 = getelementptr i8, ptr %heap81, i64 %dict_control_mirror_index160
  store i8 %dict_h2_byte113, ptr %dict_control_mirror_slot161, align 1
  br label %bb_dict_control_done37

bb_dict_control_done37:
  br label %bb_dict_rehash_next23

bb_dict_rehash_next23:
  %dict_rehash_next_i86 = add i64 %dict_rehash_i87, 1
  br label %bb_dict_rehash20

bb_dict_rehash_done24:
  call void @sollang_free(ptr %mutable_ptr3)
  %hash_key162 = sext i32 3 to i64
  %hash_high164 = lshr i64 %hash_key162, 32
  %hash_fold163 = xor i64 %hash_key162, %hash_high164
  %hash165 = mul i64 %hash_fold163, -7046029254386353131
  %dict_h2_shifted166 = lshr i64 %hash165, 57
  %dict_h2_raw167 = and i64 %dict_h2_shifted166, 127
  %dict_h2_zero168 = icmp eq i64 %dict_h2_raw167, 0
  %dict_h2169 = select i1 %dict_h2_zero168, i64 1, i64 %dict_h2_raw167
  %dict_h2_byte170 = trunc i64 %dict_h2169 to i8
  %dict_capacity_mask171 = sub i64 %dict_new_capacity76, 1
  %dict_start_slot172 = and i64 %hash165, %dict_capacity_mask171
  br label %bb_dict_group_find38

bb_dict_group_find38:
  %dict_group_probe174 = phi i64 [ 0, %bb_dict_rehash_done24 ], [ %dict_group_next_probe173, %bb_dict_group_next46 ]
  %dict_group_active175 = icmp ult i64 %dict_group_probe174, %dict_new_capacity76
  br i1 %dict_group_active175, label %bb_dict_group_body39, label %bb_dict_group_miss47

bb_dict_group_body39:
  %dict_group_unwrapped176 = add i64 %dict_start_slot172, %dict_group_probe174
  %dict_group_start177 = and i64 %dict_group_unwrapped176, %dict_capacity_mask171
  %dict_group_pointer178 = getelementptr i8, ptr %heap81, i64 %dict_group_start177
  %dict_group_controls179 = load <16 x i8>, ptr %dict_group_pointer178, align 1
  %dict_group_h2_seed180 = insertelement <16 x i8> poison, i8 %dict_h2_byte170, i64 0
  %dict_group_h2_vector181 = shufflevector <16 x i8> %dict_group_h2_seed180, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector182 = icmp eq <16 x i8> %dict_group_controls179, %dict_group_h2_vector181
  %dict_group_match_bits183 = bitcast <16 x i1> %dict_group_matches_vector182 to i16
  %dict_group_empty_vector184 = icmp eq <16 x i8> %dict_group_controls179, zeroinitializer
  %dict_group_empty_bits185 = bitcast <16 x i1> %dict_group_empty_vector184 to i16
  br label %bb_dict_group_candidates40

bb_dict_group_candidates40:
  %dict_group_candidate_bits186 = phi i16 [ %dict_group_match_bits183, %bb_dict_group_body39 ], [ %dict_group_cleared_bits187, %bb_dict_group_candidate_next42 ]
  %dict_group_has_candidate188 = icmp ne i16 %dict_group_candidate_bits186, 0
  br i1 %dict_group_has_candidate188, label %bb_dict_group_candidate_body41, label %bb_dict_group_decision43

bb_dict_group_candidate_body41:
  %dict_group_candidate_offset16189 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits186, i1 false)
  %dict_group_candidate_offset190 = zext i16 %dict_group_candidate_offset16189 to i64
  %dict_group_candidate_unwrapped191 = add i64 %dict_group_start177, %dict_group_candidate_offset190
  %dict_group_candidate_slot192 = and i64 %dict_group_candidate_unwrapped191, %dict_capacity_mask171
  %dict_entries_offset_mirror193 = add i64 %dict_new_capacity76, 23
  %dict_entries_offset194 = and i64 %dict_entries_offset_mirror193, -8
  %dict_entries195 = getelementptr i8, ptr %heap81, i64 %dict_entries_offset194
  %dict_key_offset196 = mul i64 %dict_group_candidate_slot192, 2
  %dict_key_slot197 = getelementptr i32, ptr %dict_entries195, i64 %dict_key_offset196
  %dict_key198 = load i32, ptr %dict_key_slot197, align 4
  %dict_group_key_match199 = icmp eq i32 %dict_key198, 3
  br i1 %dict_group_key_match199, label %bb_dict_group_match45, label %bb_dict_group_candidate_next42

bb_dict_group_candidate_next42:
  %dict_group_bits_minus_one200 = sub i16 %dict_group_candidate_bits186, 1
  %dict_group_cleared_bits187 = and i16 %dict_group_candidate_bits186, %dict_group_bits_minus_one200
  br label %bb_dict_group_candidates40

bb_dict_group_decision43:
  %dict_group_has_empty201 = icmp ne i16 %dict_group_empty_bits185, 0
  br i1 %dict_group_has_empty201, label %bb_dict_group_empty44, label %bb_dict_group_next46

bb_dict_group_empty44:
  %dict_group_empty_offset16202 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits185, i1 false)
  %dict_group_empty_offset203 = zext i16 %dict_group_empty_offset16202 to i64
  %dict_group_empty_unwrapped204 = add i64 %dict_group_start177, %dict_group_empty_offset203
  %dict_group_empty_slot205 = and i64 %dict_group_empty_unwrapped204, %dict_capacity_mask171
  br label %bb_dict_group_done48

bb_dict_group_match45:
  br label %bb_dict_group_done48

bb_dict_group_next46:
  %dict_group_next_probe173 = add i64 %dict_group_probe174, 16
  br label %bb_dict_group_find38

bb_dict_group_miss47:
  br label %bb_dict_group_done48

bb_dict_group_done48:
  %dict_find_found206 = phi i1 [ false, %bb_dict_group_empty44 ], [ true, %bb_dict_group_match45 ], [ false, %bb_dict_group_miss47 ]
  %dict_find_found_slot207 = phi i64 [ %dict_group_empty_slot205, %bb_dict_group_empty44 ], [ %dict_group_candidate_slot192, %bb_dict_group_match45 ], [ 0, %bb_dict_group_miss47 ]
  %dict_entries_offset_mirror208 = add i64 %dict_new_capacity76, 23
  %dict_entries_offset209 = and i64 %dict_entries_offset_mirror208, -8
  %dict_entries210 = getelementptr i8, ptr %heap81, i64 %dict_entries_offset209
  %dict_offset211 = mul i64 %dict_find_found_slot207, 2
  %dict_key_slot212 = getelementptr i32, ptr %dict_entries210, i64 %dict_offset211
  %dict_value_offset213 = add i64 %dict_offset211, 1
  %dict_value_slot214 = getelementptr i32, ptr %dict_entries210, i64 %dict_value_offset213
  store i32 3, ptr %dict_key_slot212, align 4
  store i32 300, ptr %dict_value_slot214, align 4
  %dict_control_slot215 = getelementptr i8, ptr %heap81, i64 %dict_find_found_slot207
  store i8 %dict_h2_byte170, ptr %dict_control_slot215, align 1
  %dict_control_mirrored216 = icmp ult i64 %dict_find_found_slot207, 16
  br i1 %dict_control_mirrored216, label %bb_dict_control_mirror49, label %bb_dict_control_done50

bb_dict_control_mirror49:
  %dict_control_mirror_index217 = add i64 %dict_new_capacity76, %dict_find_found_slot207
  %dict_control_mirror_slot218 = getelementptr i8, ptr %heap81, i64 %dict_control_mirror_index217
  store i8 %dict_h2_byte170, ptr %dict_control_mirror_slot218, align 1
  br label %bb_dict_control_done50

bb_dict_control_done50:
  br label %bb_dict_put_done15

bb_dict_put_done15:
  %dict_ptr219 = phi ptr [ %mutable_ptr3, %bb_dict_put_update11 ], [ %mutable_ptr3, %bb_dict_control_done17 ], [ %heap81, %bb_dict_control_done50 ]
  %dict_len220 = phi i64 [ %mutable_len4, %bb_dict_put_update11 ], [ %dict_next_len59, %bb_dict_control_done17 ], [ %dict_next_len59, %bb_dict_control_done50 ]
  %dict_capacity221 = phi i64 [ %mutable_capacity5, %bb_dict_put_update11 ], [ %mutable_capacity5, %bb_dict_control_done17 ], [ %dict_new_capacity76, %bb_dict_control_done50 ]
  store ptr %dict_ptr219, ptr %param_mut_ptr_addr0, align 8
  store i64 %dict_len220, ptr %param_mut_len_addr1, align 8
  store i64 %dict_capacity221, ptr %param_mut_capacity_addr2, align 8
  %mutable_ptr222 = load ptr, ptr %param_mut_ptr_addr0, align 8
  %mutable_len223 = load i64, ptr %param_mut_len_addr1, align 8
  %mutable_capacity224 = load i64, ptr %param_mut_capacity_addr2, align 8
  %hash_key225 = sext i32 4 to i64
  %hash_high227 = lshr i64 %hash_key225, 32
  %hash_fold226 = xor i64 %hash_key225, %hash_high227
  %hash228 = mul i64 %hash_fold226, -7046029254386353131
  %dict_h2_shifted229 = lshr i64 %hash228, 57
  %dict_h2_raw230 = and i64 %dict_h2_shifted229, 127
  %dict_h2_zero231 = icmp eq i64 %dict_h2_raw230, 0
  %dict_h2232 = select i1 %dict_h2_zero231, i64 1, i64 %dict_h2_raw230
  %dict_h2_byte233 = trunc i64 %dict_h2232 to i8
  %dict_capacity_mask234 = sub i64 %mutable_capacity224, 1
  %dict_start_slot235 = and i64 %hash228, %dict_capacity_mask234
  br label %bb_dict_group_find51

bb_dict_group_find51:
  %dict_group_probe237 = phi i64 [ 0, %bb_dict_put_done15 ], [ %dict_group_next_probe236, %bb_dict_group_next59 ]
  %dict_group_active238 = icmp ult i64 %dict_group_probe237, %mutable_capacity224
  br i1 %dict_group_active238, label %bb_dict_group_body52, label %bb_dict_group_miss60

bb_dict_group_body52:
  %dict_group_unwrapped239 = add i64 %dict_start_slot235, %dict_group_probe237
  %dict_group_start240 = and i64 %dict_group_unwrapped239, %dict_capacity_mask234
  %dict_group_pointer241 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_group_start240
  %dict_group_controls242 = load <16 x i8>, ptr %dict_group_pointer241, align 1
  %dict_group_h2_seed243 = insertelement <16 x i8> poison, i8 %dict_h2_byte233, i64 0
  %dict_group_h2_vector244 = shufflevector <16 x i8> %dict_group_h2_seed243, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector245 = icmp eq <16 x i8> %dict_group_controls242, %dict_group_h2_vector244
  %dict_group_match_bits246 = bitcast <16 x i1> %dict_group_matches_vector245 to i16
  %dict_group_empty_vector247 = icmp eq <16 x i8> %dict_group_controls242, zeroinitializer
  %dict_group_empty_bits248 = bitcast <16 x i1> %dict_group_empty_vector247 to i16
  br label %bb_dict_group_candidates53

bb_dict_group_candidates53:
  %dict_group_candidate_bits249 = phi i16 [ %dict_group_match_bits246, %bb_dict_group_body52 ], [ %dict_group_cleared_bits250, %bb_dict_group_candidate_next55 ]
  %dict_group_has_candidate251 = icmp ne i16 %dict_group_candidate_bits249, 0
  br i1 %dict_group_has_candidate251, label %bb_dict_group_candidate_body54, label %bb_dict_group_decision56

bb_dict_group_candidate_body54:
  %dict_group_candidate_offset16252 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits249, i1 false)
  %dict_group_candidate_offset253 = zext i16 %dict_group_candidate_offset16252 to i64
  %dict_group_candidate_unwrapped254 = add i64 %dict_group_start240, %dict_group_candidate_offset253
  %dict_group_candidate_slot255 = and i64 %dict_group_candidate_unwrapped254, %dict_capacity_mask234
  %dict_entries_offset_mirror256 = add i64 %mutable_capacity224, 23
  %dict_entries_offset257 = and i64 %dict_entries_offset_mirror256, -8
  %dict_entries258 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_entries_offset257
  %dict_key_offset259 = mul i64 %dict_group_candidate_slot255, 2
  %dict_key_slot260 = getelementptr i32, ptr %dict_entries258, i64 %dict_key_offset259
  %dict_key261 = load i32, ptr %dict_key_slot260, align 4
  %dict_group_key_match262 = icmp eq i32 %dict_key261, 4
  br i1 %dict_group_key_match262, label %bb_dict_group_match58, label %bb_dict_group_candidate_next55

bb_dict_group_candidate_next55:
  %dict_group_bits_minus_one263 = sub i16 %dict_group_candidate_bits249, 1
  %dict_group_cleared_bits250 = and i16 %dict_group_candidate_bits249, %dict_group_bits_minus_one263
  br label %bb_dict_group_candidates53

bb_dict_group_decision56:
  %dict_group_has_empty264 = icmp ne i16 %dict_group_empty_bits248, 0
  br i1 %dict_group_has_empty264, label %bb_dict_group_empty57, label %bb_dict_group_next59

bb_dict_group_empty57:
  %dict_group_empty_offset16265 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits248, i1 false)
  %dict_group_empty_offset266 = zext i16 %dict_group_empty_offset16265 to i64
  %dict_group_empty_unwrapped267 = add i64 %dict_group_start240, %dict_group_empty_offset266
  %dict_group_empty_slot268 = and i64 %dict_group_empty_unwrapped267, %dict_capacity_mask234
  br label %bb_dict_group_done61

bb_dict_group_match58:
  br label %bb_dict_group_done61

bb_dict_group_next59:
  %dict_group_next_probe236 = add i64 %dict_group_probe237, 16
  br label %bb_dict_group_find51

bb_dict_group_miss60:
  br label %bb_dict_group_done61

bb_dict_group_done61:
  %dict_find_found269 = phi i1 [ false, %bb_dict_group_empty57 ], [ true, %bb_dict_group_match58 ], [ false, %bb_dict_group_miss60 ]
  %dict_find_found_slot270 = phi i64 [ %dict_group_empty_slot268, %bb_dict_group_empty57 ], [ %dict_group_candidate_slot255, %bb_dict_group_match58 ], [ 0, %bb_dict_group_miss60 ]
  br i1 %dict_find_found269, label %bb_dict_put_update62, label %bb_dict_put_insert63

bb_dict_put_update62:
  %dict_entries_offset_mirror271 = add i64 %mutable_capacity224, 23
  %dict_entries_offset272 = and i64 %dict_entries_offset_mirror271, -8
  %dict_entries273 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_entries_offset272
  %dict_offset274 = mul i64 %dict_find_found_slot270, 2
  %dict_key_slot275 = getelementptr i32, ptr %dict_entries273, i64 %dict_offset274
  %dict_value_offset276 = add i64 %dict_offset274, 1
  %dict_value_slot277 = getelementptr i32, ptr %dict_entries273, i64 %dict_value_offset276
  store i32 4, ptr %dict_key_slot275, align 4
  store i32 400, ptr %dict_value_slot277, align 4
  br label %bb_dict_put_done66

bb_dict_put_insert63:
  %dict_next_len278 = add i64 %mutable_len223, 1
  %dict_load_numerator279 = mul i64 %dict_next_len278, 8
  %dict_load_denominator280 = mul i64 %mutable_capacity224, 7
  %dict_should_grow281 = icmp ugt i64 %dict_load_numerator279, %dict_load_denominator280
  br i1 %dict_should_grow281, label %bb_dict_put_insert_grow65, label %bb_dict_put_insert_current64

bb_dict_put_insert_current64:
  %dict_entries_offset_mirror282 = add i64 %mutable_capacity224, 23
  %dict_entries_offset283 = and i64 %dict_entries_offset_mirror282, -8
  %dict_entries284 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_entries_offset283
  %dict_offset285 = mul i64 %dict_find_found_slot270, 2
  %dict_key_slot286 = getelementptr i32, ptr %dict_entries284, i64 %dict_offset285
  %dict_value_offset287 = add i64 %dict_offset285, 1
  %dict_value_slot288 = getelementptr i32, ptr %dict_entries284, i64 %dict_value_offset287
  store i32 4, ptr %dict_key_slot286, align 4
  store i32 400, ptr %dict_value_slot288, align 4
  %dict_control_slot289 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_find_found_slot270
  store i8 %dict_h2_byte233, ptr %dict_control_slot289, align 1
  %dict_control_mirrored290 = icmp ult i64 %dict_find_found_slot270, 16
  br i1 %dict_control_mirrored290, label %bb_dict_control_mirror67, label %bb_dict_control_done68

bb_dict_control_mirror67:
  %dict_control_mirror_index291 = add i64 %mutable_capacity224, %dict_find_found_slot270
  %dict_control_mirror_slot292 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_control_mirror_index291
  store i8 %dict_h2_byte233, ptr %dict_control_mirror_slot292, align 1
  br label %bb_dict_control_done68

bb_dict_control_done68:
  br label %bb_dict_put_done66

bb_dict_put_insert_grow65:
  %dict_has_capacity293 = icmp eq i64 %mutable_capacity224, 0
  %dict_doubled_capacity294 = mul i64 %mutable_capacity224, 2
  %dict_new_capacity295 = select i1 %dict_has_capacity293, i64 4, i64 %dict_doubled_capacity294
  %dict_entries_offset_mirror296 = add i64 %dict_new_capacity295, 23
  %dict_entries_offset297 = and i64 %dict_entries_offset_mirror296, -8
  %dict_entries_bytes298 = mul i64 %dict_new_capacity295, 8
  %dict_bytes299 = add i64 %dict_entries_offset297, %dict_entries_bytes298
  %heap300 = call ptr @sollang_alloc(i64 %dict_bytes299)
  %heap_ok301 = icmp ne ptr %heap300, null
  br i1 %heap_ok301, label %bb_alloc_ok69, label %bb_alloc_fail70

bb_alloc_fail70:
  %trap_stderr302 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr302, ptr @.slg.str.module.x.1, i32 26, ptr %trap_written303, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok69:
  %dict_control_bytes304 = add i64 %dict_new_capacity295, 16
  call void @llvm.memset.p0.i64(ptr %heap300, i8 0, i64 %dict_control_bytes304, i1 false)
  br label %bb_dict_rehash71

bb_dict_rehash71:
  %dict_rehash_i306 = phi i64 [ 0, %bb_alloc_ok69 ], [ %dict_rehash_next_i305, %bb_dict_rehash_next74 ]
  %dict_rehash_active307 = icmp ult i64 %dict_rehash_i306, %mutable_capacity224
  br i1 %dict_rehash_active307, label %bb_dict_rehash_body72, label %bb_dict_rehash_done75

bb_dict_rehash_body72:
  %dict_control_slot308 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_rehash_i306
  %dict_control309 = load i8, ptr %dict_control_slot308, align 1
  %dict_rehash_full310 = icmp ne i8 %dict_control309, 0
  br i1 %dict_rehash_full310, label %bb_dict_rehash_move73, label %bb_dict_rehash_next74

bb_dict_rehash_move73:
  %dict_entries_offset_mirror311 = add i64 %mutable_capacity224, 23
  %dict_entries_offset312 = and i64 %dict_entries_offset_mirror311, -8
  %dict_entries313 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_entries_offset312
  %dict_key_offset314 = mul i64 %dict_rehash_i306, 2
  %dict_key_slot315 = getelementptr i32, ptr %dict_entries313, i64 %dict_key_offset314
  %dict_key316 = load i32, ptr %dict_key_slot315, align 4
  %dict_entries_offset_mirror317 = add i64 %mutable_capacity224, 23
  %dict_entries_offset318 = and i64 %dict_entries_offset_mirror317, -8
  %dict_entries319 = getelementptr i8, ptr %mutable_ptr222, i64 %dict_entries_offset318
  %dict_value_base320 = mul i64 %dict_rehash_i306, 2
  %dict_value_offset321 = add i64 %dict_value_base320, 1
  %dict_value_slot322 = getelementptr i32, ptr %dict_entries319, i64 %dict_value_offset321
  %dict_value323 = load i32, ptr %dict_value_slot322, align 4
  %hash_key324 = sext i32 %dict_key316 to i64
  %hash_high326 = lshr i64 %hash_key324, 32
  %hash_fold325 = xor i64 %hash_key324, %hash_high326
  %hash327 = mul i64 %hash_fold325, -7046029254386353131
  %dict_h2_shifted328 = lshr i64 %hash327, 57
  %dict_h2_raw329 = and i64 %dict_h2_shifted328, 127
  %dict_h2_zero330 = icmp eq i64 %dict_h2_raw329, 0
  %dict_h2331 = select i1 %dict_h2_zero330, i64 1, i64 %dict_h2_raw329
  %dict_h2_byte332 = trunc i64 %dict_h2331 to i8
  %dict_capacity_mask333 = sub i64 %dict_new_capacity295, 1
  %dict_start_slot334 = and i64 %hash327, %dict_capacity_mask333
  br label %bb_dict_group_find76

bb_dict_group_find76:
  %dict_group_probe336 = phi i64 [ 0, %bb_dict_rehash_move73 ], [ %dict_group_next_probe335, %bb_dict_group_next84 ]
  %dict_group_active337 = icmp ult i64 %dict_group_probe336, %dict_new_capacity295
  br i1 %dict_group_active337, label %bb_dict_group_body77, label %bb_dict_group_miss85

bb_dict_group_body77:
  %dict_group_unwrapped338 = add i64 %dict_start_slot334, %dict_group_probe336
  %dict_group_start339 = and i64 %dict_group_unwrapped338, %dict_capacity_mask333
  %dict_group_pointer340 = getelementptr i8, ptr %heap300, i64 %dict_group_start339
  %dict_group_controls341 = load <16 x i8>, ptr %dict_group_pointer340, align 1
  %dict_group_h2_seed342 = insertelement <16 x i8> poison, i8 %dict_h2_byte332, i64 0
  %dict_group_h2_vector343 = shufflevector <16 x i8> %dict_group_h2_seed342, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector344 = icmp eq <16 x i8> %dict_group_controls341, %dict_group_h2_vector343
  %dict_group_match_bits345 = bitcast <16 x i1> %dict_group_matches_vector344 to i16
  %dict_group_empty_vector346 = icmp eq <16 x i8> %dict_group_controls341, zeroinitializer
  %dict_group_empty_bits347 = bitcast <16 x i1> %dict_group_empty_vector346 to i16
  br label %bb_dict_group_candidates78

bb_dict_group_candidates78:
  %dict_group_candidate_bits348 = phi i16 [ %dict_group_match_bits345, %bb_dict_group_body77 ], [ %dict_group_cleared_bits349, %bb_dict_group_candidate_next80 ]
  %dict_group_has_candidate350 = icmp ne i16 %dict_group_candidate_bits348, 0
  br i1 %dict_group_has_candidate350, label %bb_dict_group_candidate_body79, label %bb_dict_group_decision81

bb_dict_group_candidate_body79:
  %dict_group_candidate_offset16351 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits348, i1 false)
  %dict_group_candidate_offset352 = zext i16 %dict_group_candidate_offset16351 to i64
  %dict_group_candidate_unwrapped353 = add i64 %dict_group_start339, %dict_group_candidate_offset352
  %dict_group_candidate_slot354 = and i64 %dict_group_candidate_unwrapped353, %dict_capacity_mask333
  %dict_entries_offset_mirror355 = add i64 %dict_new_capacity295, 23
  %dict_entries_offset356 = and i64 %dict_entries_offset_mirror355, -8
  %dict_entries357 = getelementptr i8, ptr %heap300, i64 %dict_entries_offset356
  %dict_key_offset358 = mul i64 %dict_group_candidate_slot354, 2
  %dict_key_slot359 = getelementptr i32, ptr %dict_entries357, i64 %dict_key_offset358
  %dict_key360 = load i32, ptr %dict_key_slot359, align 4
  %dict_group_key_match361 = icmp eq i32 %dict_key360, %dict_key316
  br i1 %dict_group_key_match361, label %bb_dict_group_match83, label %bb_dict_group_candidate_next80

bb_dict_group_candidate_next80:
  %dict_group_bits_minus_one362 = sub i16 %dict_group_candidate_bits348, 1
  %dict_group_cleared_bits349 = and i16 %dict_group_candidate_bits348, %dict_group_bits_minus_one362
  br label %bb_dict_group_candidates78

bb_dict_group_decision81:
  %dict_group_has_empty363 = icmp ne i16 %dict_group_empty_bits347, 0
  br i1 %dict_group_has_empty363, label %bb_dict_group_empty82, label %bb_dict_group_next84

bb_dict_group_empty82:
  %dict_group_empty_offset16364 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits347, i1 false)
  %dict_group_empty_offset365 = zext i16 %dict_group_empty_offset16364 to i64
  %dict_group_empty_unwrapped366 = add i64 %dict_group_start339, %dict_group_empty_offset365
  %dict_group_empty_slot367 = and i64 %dict_group_empty_unwrapped366, %dict_capacity_mask333
  br label %bb_dict_group_done86

bb_dict_group_match83:
  br label %bb_dict_group_done86

bb_dict_group_next84:
  %dict_group_next_probe335 = add i64 %dict_group_probe336, 16
  br label %bb_dict_group_find76

bb_dict_group_miss85:
  br label %bb_dict_group_done86

bb_dict_group_done86:
  %dict_find_found368 = phi i1 [ false, %bb_dict_group_empty82 ], [ true, %bb_dict_group_match83 ], [ false, %bb_dict_group_miss85 ]
  %dict_find_found_slot369 = phi i64 [ %dict_group_empty_slot367, %bb_dict_group_empty82 ], [ %dict_group_candidate_slot354, %bb_dict_group_match83 ], [ 0, %bb_dict_group_miss85 ]
  %dict_entries_offset_mirror370 = add i64 %dict_new_capacity295, 23
  %dict_entries_offset371 = and i64 %dict_entries_offset_mirror370, -8
  %dict_entries372 = getelementptr i8, ptr %heap300, i64 %dict_entries_offset371
  %dict_offset373 = mul i64 %dict_find_found_slot369, 2
  %dict_key_slot374 = getelementptr i32, ptr %dict_entries372, i64 %dict_offset373
  %dict_value_offset375 = add i64 %dict_offset373, 1
  %dict_value_slot376 = getelementptr i32, ptr %dict_entries372, i64 %dict_value_offset375
  store i32 %dict_key316, ptr %dict_key_slot374, align 4
  store i32 %dict_value323, ptr %dict_value_slot376, align 4
  %dict_control_slot377 = getelementptr i8, ptr %heap300, i64 %dict_find_found_slot369
  store i8 %dict_h2_byte332, ptr %dict_control_slot377, align 1
  %dict_control_mirrored378 = icmp ult i64 %dict_find_found_slot369, 16
  br i1 %dict_control_mirrored378, label %bb_dict_control_mirror87, label %bb_dict_control_done88

bb_dict_control_mirror87:
  %dict_control_mirror_index379 = add i64 %dict_new_capacity295, %dict_find_found_slot369
  %dict_control_mirror_slot380 = getelementptr i8, ptr %heap300, i64 %dict_control_mirror_index379
  store i8 %dict_h2_byte332, ptr %dict_control_mirror_slot380, align 1
  br label %bb_dict_control_done88

bb_dict_control_done88:
  br label %bb_dict_rehash_next74

bb_dict_rehash_next74:
  %dict_rehash_next_i305 = add i64 %dict_rehash_i306, 1
  br label %bb_dict_rehash71

bb_dict_rehash_done75:
  call void @sollang_free(ptr %mutable_ptr222)
  %hash_key381 = sext i32 4 to i64
  %hash_high383 = lshr i64 %hash_key381, 32
  %hash_fold382 = xor i64 %hash_key381, %hash_high383
  %hash384 = mul i64 %hash_fold382, -7046029254386353131
  %dict_h2_shifted385 = lshr i64 %hash384, 57
  %dict_h2_raw386 = and i64 %dict_h2_shifted385, 127
  %dict_h2_zero387 = icmp eq i64 %dict_h2_raw386, 0
  %dict_h2388 = select i1 %dict_h2_zero387, i64 1, i64 %dict_h2_raw386
  %dict_h2_byte389 = trunc i64 %dict_h2388 to i8
  %dict_capacity_mask390 = sub i64 %dict_new_capacity295, 1
  %dict_start_slot391 = and i64 %hash384, %dict_capacity_mask390
  br label %bb_dict_group_find89

bb_dict_group_find89:
  %dict_group_probe393 = phi i64 [ 0, %bb_dict_rehash_done75 ], [ %dict_group_next_probe392, %bb_dict_group_next97 ]
  %dict_group_active394 = icmp ult i64 %dict_group_probe393, %dict_new_capacity295
  br i1 %dict_group_active394, label %bb_dict_group_body90, label %bb_dict_group_miss98

bb_dict_group_body90:
  %dict_group_unwrapped395 = add i64 %dict_start_slot391, %dict_group_probe393
  %dict_group_start396 = and i64 %dict_group_unwrapped395, %dict_capacity_mask390
  %dict_group_pointer397 = getelementptr i8, ptr %heap300, i64 %dict_group_start396
  %dict_group_controls398 = load <16 x i8>, ptr %dict_group_pointer397, align 1
  %dict_group_h2_seed399 = insertelement <16 x i8> poison, i8 %dict_h2_byte389, i64 0
  %dict_group_h2_vector400 = shufflevector <16 x i8> %dict_group_h2_seed399, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector401 = icmp eq <16 x i8> %dict_group_controls398, %dict_group_h2_vector400
  %dict_group_match_bits402 = bitcast <16 x i1> %dict_group_matches_vector401 to i16
  %dict_group_empty_vector403 = icmp eq <16 x i8> %dict_group_controls398, zeroinitializer
  %dict_group_empty_bits404 = bitcast <16 x i1> %dict_group_empty_vector403 to i16
  br label %bb_dict_group_candidates91

bb_dict_group_candidates91:
  %dict_group_candidate_bits405 = phi i16 [ %dict_group_match_bits402, %bb_dict_group_body90 ], [ %dict_group_cleared_bits406, %bb_dict_group_candidate_next93 ]
  %dict_group_has_candidate407 = icmp ne i16 %dict_group_candidate_bits405, 0
  br i1 %dict_group_has_candidate407, label %bb_dict_group_candidate_body92, label %bb_dict_group_decision94

bb_dict_group_candidate_body92:
  %dict_group_candidate_offset16408 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits405, i1 false)
  %dict_group_candidate_offset409 = zext i16 %dict_group_candidate_offset16408 to i64
  %dict_group_candidate_unwrapped410 = add i64 %dict_group_start396, %dict_group_candidate_offset409
  %dict_group_candidate_slot411 = and i64 %dict_group_candidate_unwrapped410, %dict_capacity_mask390
  %dict_entries_offset_mirror412 = add i64 %dict_new_capacity295, 23
  %dict_entries_offset413 = and i64 %dict_entries_offset_mirror412, -8
  %dict_entries414 = getelementptr i8, ptr %heap300, i64 %dict_entries_offset413
  %dict_key_offset415 = mul i64 %dict_group_candidate_slot411, 2
  %dict_key_slot416 = getelementptr i32, ptr %dict_entries414, i64 %dict_key_offset415
  %dict_key417 = load i32, ptr %dict_key_slot416, align 4
  %dict_group_key_match418 = icmp eq i32 %dict_key417, 4
  br i1 %dict_group_key_match418, label %bb_dict_group_match96, label %bb_dict_group_candidate_next93

bb_dict_group_candidate_next93:
  %dict_group_bits_minus_one419 = sub i16 %dict_group_candidate_bits405, 1
  %dict_group_cleared_bits406 = and i16 %dict_group_candidate_bits405, %dict_group_bits_minus_one419
  br label %bb_dict_group_candidates91

bb_dict_group_decision94:
  %dict_group_has_empty420 = icmp ne i16 %dict_group_empty_bits404, 0
  br i1 %dict_group_has_empty420, label %bb_dict_group_empty95, label %bb_dict_group_next97

bb_dict_group_empty95:
  %dict_group_empty_offset16421 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits404, i1 false)
  %dict_group_empty_offset422 = zext i16 %dict_group_empty_offset16421 to i64
  %dict_group_empty_unwrapped423 = add i64 %dict_group_start396, %dict_group_empty_offset422
  %dict_group_empty_slot424 = and i64 %dict_group_empty_unwrapped423, %dict_capacity_mask390
  br label %bb_dict_group_done99

bb_dict_group_match96:
  br label %bb_dict_group_done99

bb_dict_group_next97:
  %dict_group_next_probe392 = add i64 %dict_group_probe393, 16
  br label %bb_dict_group_find89

bb_dict_group_miss98:
  br label %bb_dict_group_done99

bb_dict_group_done99:
  %dict_find_found425 = phi i1 [ false, %bb_dict_group_empty95 ], [ true, %bb_dict_group_match96 ], [ false, %bb_dict_group_miss98 ]
  %dict_find_found_slot426 = phi i64 [ %dict_group_empty_slot424, %bb_dict_group_empty95 ], [ %dict_group_candidate_slot411, %bb_dict_group_match96 ], [ 0, %bb_dict_group_miss98 ]
  %dict_entries_offset_mirror427 = add i64 %dict_new_capacity295, 23
  %dict_entries_offset428 = and i64 %dict_entries_offset_mirror427, -8
  %dict_entries429 = getelementptr i8, ptr %heap300, i64 %dict_entries_offset428
  %dict_offset430 = mul i64 %dict_find_found_slot426, 2
  %dict_key_slot431 = getelementptr i32, ptr %dict_entries429, i64 %dict_offset430
  %dict_value_offset432 = add i64 %dict_offset430, 1
  %dict_value_slot433 = getelementptr i32, ptr %dict_entries429, i64 %dict_value_offset432
  store i32 4, ptr %dict_key_slot431, align 4
  store i32 400, ptr %dict_value_slot433, align 4
  %dict_control_slot434 = getelementptr i8, ptr %heap300, i64 %dict_find_found_slot426
  store i8 %dict_h2_byte389, ptr %dict_control_slot434, align 1
  %dict_control_mirrored435 = icmp ult i64 %dict_find_found_slot426, 16
  br i1 %dict_control_mirrored435, label %bb_dict_control_mirror100, label %bb_dict_control_done101

bb_dict_control_mirror100:
  %dict_control_mirror_index436 = add i64 %dict_new_capacity295, %dict_find_found_slot426
  %dict_control_mirror_slot437 = getelementptr i8, ptr %heap300, i64 %dict_control_mirror_index436
  store i8 %dict_h2_byte389, ptr %dict_control_mirror_slot437, align 1
  br label %bb_dict_control_done101

bb_dict_control_done101:
  br label %bb_dict_put_done66

bb_dict_put_done66:
  %dict_ptr438 = phi ptr [ %mutable_ptr222, %bb_dict_put_update62 ], [ %mutable_ptr222, %bb_dict_control_done68 ], [ %heap300, %bb_dict_control_done101 ]
  %dict_len439 = phi i64 [ %mutable_len223, %bb_dict_put_update62 ], [ %dict_next_len278, %bb_dict_control_done68 ], [ %dict_next_len278, %bb_dict_control_done101 ]
  %dict_capacity440 = phi i64 [ %mutable_capacity224, %bb_dict_put_update62 ], [ %mutable_capacity224, %bb_dict_control_done68 ], [ %dict_new_capacity295, %bb_dict_control_done101 ]
  store ptr %dict_ptr438, ptr %param_mut_ptr_addr0, align 8
  store i64 %dict_len439, ptr %param_mut_len_addr1, align 8
  store i64 %dict_capacity440, ptr %param_mut_capacity_addr2, align 8
  ret void
}

define internal void @sollang_fn_replaceFirst(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.mutable_container %it) #0 {
entry:
  %trap_written53 = alloca i32, align 4
  %param_mut_ptr_addr0 = extractvalue %sollang.mutable_container %it, 0
  %param_mut_len_addr1 = extractvalue %sollang.mutable_container %it, 1
  %param_mut_capacity_addr2 = extractvalue %sollang.mutable_container %it, 2
  %mutable_ptr3 = load ptr, ptr %param_mut_ptr_addr0, align 8
  %mutable_len4 = load i64, ptr %param_mut_len_addr1, align 8
  %mutable_capacity5 = load i64, ptr %param_mut_capacity_addr2, align 8
  %hash_key6 = sext i32 1 to i64
  %hash_high8 = lshr i64 %hash_key6, 32
  %hash_fold7 = xor i64 %hash_key6, %hash_high8
  %hash9 = mul i64 %hash_fold7, -7046029254386353131
  %dict_h2_shifted10 = lshr i64 %hash9, 57
  %dict_h2_raw11 = and i64 %dict_h2_shifted10, 127
  %dict_h2_zero12 = icmp eq i64 %dict_h2_raw11, 0
  %dict_h213 = select i1 %dict_h2_zero12, i64 1, i64 %dict_h2_raw11
  %dict_h2_byte14 = trunc i64 %dict_h213 to i8
  %dict_capacity_mask15 = sub i64 %mutable_capacity5, 1
  %dict_start_slot16 = and i64 %hash9, %dict_capacity_mask15
  br label %bb_dict_group_find0

bb_dict_group_find0:
  %dict_group_probe18 = phi i64 [ 0, %entry ], [ %dict_group_next_probe17, %bb_dict_group_next8 ]
  %dict_group_active19 = icmp ult i64 %dict_group_probe18, %mutable_capacity5
  br i1 %dict_group_active19, label %bb_dict_group_body1, label %bb_dict_group_miss9

bb_dict_group_body1:
  %dict_group_unwrapped20 = add i64 %dict_start_slot16, %dict_group_probe18
  %dict_group_start21 = and i64 %dict_group_unwrapped20, %dict_capacity_mask15
  %dict_group_pointer22 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_group_start21
  %dict_group_controls23 = load <16 x i8>, ptr %dict_group_pointer22, align 1
  %dict_group_h2_seed24 = insertelement <16 x i8> poison, i8 %dict_h2_byte14, i64 0
  %dict_group_h2_vector25 = shufflevector <16 x i8> %dict_group_h2_seed24, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector26 = icmp eq <16 x i8> %dict_group_controls23, %dict_group_h2_vector25
  %dict_group_match_bits27 = bitcast <16 x i1> %dict_group_matches_vector26 to i16
  %dict_group_empty_vector28 = icmp eq <16 x i8> %dict_group_controls23, zeroinitializer
  %dict_group_empty_bits29 = bitcast <16 x i1> %dict_group_empty_vector28 to i16
  br label %bb_dict_group_candidates2

bb_dict_group_candidates2:
  %dict_group_candidate_bits30 = phi i16 [ %dict_group_match_bits27, %bb_dict_group_body1 ], [ %dict_group_cleared_bits31, %bb_dict_group_candidate_next4 ]
  %dict_group_has_candidate32 = icmp ne i16 %dict_group_candidate_bits30, 0
  br i1 %dict_group_has_candidate32, label %bb_dict_group_candidate_body3, label %bb_dict_group_decision5

bb_dict_group_candidate_body3:
  %dict_group_candidate_offset1633 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits30, i1 false)
  %dict_group_candidate_offset34 = zext i16 %dict_group_candidate_offset1633 to i64
  %dict_group_candidate_unwrapped35 = add i64 %dict_group_start21, %dict_group_candidate_offset34
  %dict_group_candidate_slot36 = and i64 %dict_group_candidate_unwrapped35, %dict_capacity_mask15
  %dict_entries_offset_mirror37 = add i64 %mutable_capacity5, 23
  %dict_entries_offset38 = and i64 %dict_entries_offset_mirror37, -8
  %dict_entries39 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset38
  %dict_key_offset40 = mul i64 %dict_group_candidate_slot36, 2
  %dict_key_slot41 = getelementptr i32, ptr %dict_entries39, i64 %dict_key_offset40
  %dict_key42 = load i32, ptr %dict_key_slot41, align 4
  %dict_group_key_match43 = icmp eq i32 %dict_key42, 1
  br i1 %dict_group_key_match43, label %bb_dict_group_match7, label %bb_dict_group_candidate_next4

bb_dict_group_candidate_next4:
  %dict_group_bits_minus_one44 = sub i16 %dict_group_candidate_bits30, 1
  %dict_group_cleared_bits31 = and i16 %dict_group_candidate_bits30, %dict_group_bits_minus_one44
  br label %bb_dict_group_candidates2

bb_dict_group_decision5:
  %dict_group_has_empty45 = icmp ne i16 %dict_group_empty_bits29, 0
  br i1 %dict_group_has_empty45, label %bb_dict_group_empty6, label %bb_dict_group_next8

bb_dict_group_empty6:
  %dict_group_empty_offset1646 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits29, i1 false)
  %dict_group_empty_offset47 = zext i16 %dict_group_empty_offset1646 to i64
  %dict_group_empty_unwrapped48 = add i64 %dict_group_start21, %dict_group_empty_offset47
  %dict_group_empty_slot49 = and i64 %dict_group_empty_unwrapped48, %dict_capacity_mask15
  br label %bb_dict_group_done10

bb_dict_group_match7:
  br label %bb_dict_group_done10

bb_dict_group_next8:
  %dict_group_next_probe17 = add i64 %dict_group_probe18, 16
  br label %bb_dict_group_find0

bb_dict_group_miss9:
  br label %bb_dict_group_done10

bb_dict_group_done10:
  %dict_find_found50 = phi i1 [ false, %bb_dict_group_empty6 ], [ true, %bb_dict_group_match7 ], [ false, %bb_dict_group_miss9 ]
  %dict_find_found_slot51 = phi i64 [ %dict_group_empty_slot49, %bb_dict_group_empty6 ], [ %dict_group_candidate_slot36, %bb_dict_group_match7 ], [ 0, %bb_dict_group_miss9 ]
  br i1 %dict_find_found50, label %bb_dict_assign_missing_ok11, label %bb_dict_assign_missing_fail12

bb_dict_assign_missing_fail12:
  %trap_stderr52 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr52, ptr @.slg.str.module.x.2, i32 43, ptr %trap_written53, ptr null)
  call void @llvm.trap()
  unreachable

bb_dict_assign_missing_ok11:
  %dict_entries_offset_mirror54 = add i64 %mutable_capacity5, 23
  %dict_entries_offset55 = and i64 %dict_entries_offset_mirror54, -8
  %dict_entries56 = getelementptr i8, ptr %mutable_ptr3, i64 %dict_entries_offset55
  %dict_offset57 = mul i64 %dict_find_found_slot51, 2
  %dict_key_slot58 = getelementptr i32, ptr %dict_entries56, i64 %dict_offset57
  %dict_value_offset59 = add i64 %dict_offset57, 1
  %dict_value_slot60 = getelementptr i32, ptr %dict_entries56, i64 %dict_value_offset59
  store i32 1, ptr %dict_key_slot58, align 4
  store i32 150, ptr %dict_value_slot60, align 4
  ret void
}

@.slg.str.suffix.0 = private unnamed_addr constant [20 x i8] c"main:bb_alloc_fail19", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [20 x i8] c"main:bb_alloc_fail70", align 1
@.slg.str.suffix.2 = private unnamed_addr constant [8 x i8] c"count = ", align 1
@.slg.str.suffix.3 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.4 = private unnamed_addr constant [8 x i8] c"first = ", align 1
@.slg.str.suffix.5 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.6 = private unnamed_addr constant [8 x i8] c"third = ", align 1
@.slg.str.suffix.7 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.8 = private unnamed_addr constant [9 x i8] c"fourth = ", align 1
@.slg.str.suffix.9 = private unnamed_addr constant [1 x i8] c"\0A", align 1
define dso_local void @__chkstk() naked nounwind {
entry:
  call void asm sideeffect inteldialect "push rcx\0Apush rax\0Alea rcx, [rsp + 24]\0Acmp rax, 4096\0Ajb .Lsollang_chkstk_tail\0A.Lsollang_chkstk_loop:\0Asub rcx, 4096\0Atest byte ptr [rcx], 0\0Asub rax, 4096\0Acmp rax, 4096\0Ajae .Lsollang_chkstk_loop\0A.Lsollang_chkstk_tail:\0Asub rcx, rax\0Atest byte ptr [rcx], 0\0Apop rax\0Apop rcx\0Aret", "~{memory},~{flags}"()
  unreachable
}

define internal i32 @sollang_write_stream_chunk(ptr %handle, ptr %data, i32 %len, ptr %written, i1 %is_console) #0 {
entry:
  %empty = icmp eq i32 %len, 0
  br i1 %empty, label %success_empty, label %classify

success_empty:
  store i32 0, ptr %written, align 4
  ret i32 1

classify:
  br i1 %is_console, label %console_prepare, label %redirected

redirected:
  br label %redirected_write

redirected_write:
  %redirected_offset = phi i32 [ 0, %redirected ], [ %redirected_next, %redirected_advance ]
  %redirected_remaining = sub i32 %len, %redirected_offset
  %redirected_offset64 = zext i32 %redirected_offset to i64
  %redirected_data = getelementptr i8, ptr %data, i64 %redirected_offset64
  store i32 0, ptr %written, align 4
  %redirected_ok = call i32 @WriteFile(ptr %handle, ptr %redirected_data, i32 %redirected_remaining, ptr %written, ptr null)
  %redirected_count = load i32, ptr %written, align 4
  %redirected_succeeded = icmp ne i32 %redirected_ok, 0
  %redirected_progress = icmp ugt i32 %redirected_count, 0
  %redirected_bounded = icmp ule i32 %redirected_count, %redirected_remaining
  %redirected_valid0 = and i1 %redirected_succeeded, %redirected_progress
  %redirected_valid = and i1 %redirected_valid0, %redirected_bounded
  br i1 %redirected_valid, label %redirected_advance, label %write_failed

redirected_advance:
  %redirected_next = add i32 %redirected_offset, %redirected_count
  %redirected_complete = icmp eq i32 %redirected_next, %len
  br i1 %redirected_complete, label %write_succeeded, label %redirected_write

console_prepare:
  %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %len, ptr null, i32 0)
  %valid_utf8 = icmp sgt i32 %wide_chars, 0
  br i1 %valid_utf8, label %allocate, label %conversion_failed

allocate:
  %wide_bytes32 = shl i32 %wide_chars, 1
  %wide_bytes = zext i32 %wide_bytes32 to i64
  %heap = call ptr @GetProcessHeap()
  %wide = call ptr @HeapAlloc(ptr %heap, i32 0, i64 %wide_bytes)
  %wide_written = alloca i32, align 4
  %allocated = icmp ne ptr %wide, null
  br i1 %allocated, label %convert, label %conversion_failed

convert:
  %converted = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %len, ptr %wide, i32 %wide_chars)
  %converted_all = icmp eq i32 %converted, %wide_chars
  br i1 %converted_all, label %console_write, label %conversion_free

console_write:
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

console_advance:
  %console_next = add i32 %console_offset, %console_count
  %console_complete = icmp eq i32 %console_next, %wide_chars
  br i1 %console_complete, label %console_write_succeeded, label %console_write

console_write_succeeded:
  %freed = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %write_succeeded

console_write_failed:
  %freed_after_write_failure = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %write_failed

write_succeeded:
  store i32 %len, ptr %written, align 4
  ret i32 1

write_failed:
  store i32 0, ptr %written, align 4
  ret i32 0

conversion_free:
  %freed_after_failure = call i32 @HeapFree(ptr %heap, i32 0, ptr %wide)
  br label %conversion_failed

conversion_failed:
  store i32 0, ptr %written, align 4
  ret i32 0
}

define internal i32 @sollang_write_stream(ptr %handle, ptr %data, i64 %len64, ptr %written, i1 %is_console) #0 {
entry:
  %empty = icmp eq i64 %len64, 0
  br i1 %empty, label %success_empty, label %prepare

success_empty:
  store i32 0, ptr %written, align 4
  ret i32 1

prepare:
  %offset = phi i64 [ 0, %entry ], [ %next, %advance ]
  %remaining = sub i64 %len64, %offset
  %current = getelementptr i8, ptr %data, i64 %offset
  %more = icmp ugt i64 %remaining, 1048576
  %proposed = select i1 %more, i64 1048576, i64 %remaining
  %split_console = and i1 %more, %is_console
  br i1 %split_console, label %trim_boundary, label %write

trim_boundary:
  %boundary = phi i64 [ 1048576, %prepare ], [ %previous, %trim_next ]
  %boundary_ptr = getelementptr i8, ptr %current, i64 %boundary
  %boundary_byte = load i8, ptr %boundary_ptr, align 1
  %prefix = and i8 %boundary_byte, -64
  %continuation = icmp eq i8 %prefix, -128
  br i1 %continuation, label %trim_next, label %write

trim_next:
  %can_trim = icmp ugt i64 %boundary, 1048573
  %previous = sub i64 %boundary, 1
  br i1 %can_trim, label %trim_boundary, label %failure

write:
  %chunk64 = phi i64 [ %proposed, %prepare ], [ %boundary, %trim_boundary ]
  %chunk32 = trunc i64 %chunk64 to i32
  %ok = call i32 @sollang_write_stream_chunk(ptr %handle, ptr %current, i32 %chunk32, ptr %written, i1 %is_console)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %advance, label %failure

advance:
  %next = add i64 %offset, %chunk64
  %complete = icmp eq i64 %next, %len64
  br i1 %complete, label %success, label %prepare

success:
  ret i32 1

failure:
  store i32 0, ptr %written, align 4
  ret i32 0
}

define internal i32 @sollang_write_stdout_bytes(ptr %stdout, ptr %data, i32 %len, ptr %written) #0 {
entry:
  %is_console = load i1, ptr @sollang_stdout_line_buffered, align 1
  %ok = call i32 @sollang_write_stream_chunk(ptr %stdout, ptr %data, i32 %len, ptr %written, i1 %is_console)
  ret i32 %ok
}

define internal i32 @sollang_flush_stdout(ptr %stdout, ptr %written) #0 {
entry:
  %count64 = load i64, ptr @sollang_stdout_buffer_count, align 8
  %has_data = icmp ne i64 %count64, 0
  br i1 %has_data, label %write, label %empty

write:
  %count = trunc i64 %count64 to i32
  %buffer = getelementptr inbounds [1048576 x i8], ptr @sollang_stdout_buffer, i64 0, i64 0
  %ok = call i32 @sollang_write_stdout_bytes(ptr %stdout, ptr %buffer, i32 %count, ptr %written)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %clear, label %failure

clear:
  store i64 0, ptr @sollang_stdout_buffer_count, align 8
  ret i32 %ok

failure:
  call void @llvm.trap()
  unreachable

empty:
  store i32 0, ptr %written, align 4
  ret i32 1
}

define internal i32 @sollang_write(ptr %stdout, ptr %data, i64 %len64, ptr %written) #0 {
entry:
  br label %write_prepare

write_prepare:
  %oversized = icmp ugt i64 %len64, 1048576
  br i1 %oversized, label %write_direct_prepare, label %buffer_prepare

write_direct_prepare:
  %flushed_direct = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %direct_console = load i1, ptr @sollang_stdout_line_buffered, align 1
  %direct_ok = call i32 @sollang_write_stream(ptr %stdout, ptr %data, i64 %len64, ptr %written, i1 %direct_console)
  %direct_succeeded = icmp ne i32 %direct_ok, 0
  br i1 %direct_succeeded, label %write_direct_done, label %write_direct_failure

write_direct_done:
  ret i32 1

write_direct_failure:
  call void @llvm.trap()
  unreachable

buffer_prepare:
  %count = load i64, ptr @sollang_stdout_buffer_count, align 8
  %combined = add i64 %count, %len64
  %needs_flush = icmp ugt i64 %combined, 1048576
  br i1 %needs_flush, label %flush, label %append

flush:
  %flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  br label %append

append:
  %offset = phi i64 [ %count, %buffer_prepare ], [ 0, %flush ]
  %destination = getelementptr inbounds [1048576 x i8], ptr @sollang_stdout_buffer, i64 0, i64 %offset
  %copied = call ptr @memcpy(ptr %destination, ptr %data, i64 %len64)
  %next_count = add i64 %offset, %len64
  store i64 %next_count, ptr @sollang_stdout_buffer_count, align 8
  %written32 = trunc i64 %len64 to i32
  store i32 %written32, ptr %written, align 4
  %single_byte = icmp eq i64 %len64, 1
  br i1 %single_byte, label %inspect_newline, label %done

inspect_newline:
  %byte = load i8, ptr %data, align 1
  %newline = icmp eq i8 %byte, 10
  %line_buffered = load i1, ptr @sollang_stdout_line_buffered, align 1
  %flush_newline = and i1 %newline, %line_buffered
  br i1 %flush_newline, label %flush_line, label %done

flush_line:
  %line_ok = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  ret i32 %line_ok

done:
  ret i32 1
}

define internal i32 @sollang_read_stdin(ptr %stdin, ptr %data, i64 %len64, ptr %read) #0 {
entry:
  %exceeds_dword = icmp ugt i64 %len64, 4294967295
  %bounded_len = select i1 %exceeds_dword, i64 4294967295, i64 %len64
  %len = trunc i64 %bounded_len to i32
  %ok = call i32 @ReadFile(ptr %stdin, ptr %data, i32 %len, ptr %read, ptr null)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %success, label %inspect_error

inspect_error:
  %error = call i32 @GetLastError()
  %broken_pipe = icmp eq i32 %error, 109
  br i1 %broken_pipe, label %eof, label %failure

eof:
  store i32 0, ptr %read, align 4
  ret i32 1

success:
  ret i32 1

failure:
  ret i32 0
}

define internal i32 @sollang_platform_create_exclusive_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i16], align 2
  %buf_ptr = getelementptr inbounds [260 x i16], ptr %buf, i64 0, i64 0
  %fits = icmp ule i64 %len, 259
  br i1 %fits, label %convert, label %fail
convert:
  %copy_ok = call i32 @sollang_windows_utf8_path(ptr %path, i64 %len, ptr %buf_ptr, i32 260)
  %copied = icmp ne i32 %copy_ok, 0
  br i1 %copied, label %create, label %fail

create:
  %handle = call ptr @CreateFileW(ptr %buf_ptr, i32 1073741824, i32 0, ptr null, i32 1, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %create_failed, label %close

close:
  %closed = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %closed, 0
  %status = select i1 %close_ok, i32 1, i32 -1
  ret i32 %status

create_failed:
  %error = call i32 @GetLastError()
  %file_exists = icmp eq i32 %error, 80
  %already_exists = icmp eq i32 %error, 183
  %exists = or i1 %file_exists, %already_exists
  %status_failed = select i1 %exists, i32 0, i32 -1
  ret i32 %status_failed

fail:
  ret i32 -1
}

define internal i32 @sollang_platform_remove_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i16], align 2
  %buf_ptr = getelementptr inbounds [260 x i16], ptr %buf, i64 0, i64 0
  %fits = icmp ule i64 %len, 259
  br i1 %fits, label %convert, label %fail
convert:
  %copy_ok = call i32 @sollang_windows_utf8_path(ptr %path, i64 %len, ptr %buf_ptr, i32 260)
  %copied = icmp ne i32 %copy_ok, 0
  br i1 %copied, label %remove, label %fail

remove:
  %removed = call i32 @DeleteFileW(ptr %buf_ptr)
  %success = icmp ne i32 %removed, 0
  br i1 %success, label %removed_file, label %remove_failed

removed_file:
  ret i32 1

remove_failed:
  %error = call i32 @GetLastError()
  %file_missing = icmp eq i32 %error, 2
  %path_missing = icmp eq i32 %error, 3
  %missing = or i1 %file_missing, %path_missing
  %status = select i1 %missing, i32 0, i32 -1
  ret i32 %status

fail:
  ret i32 -1
}

define internal i32 @sollang_platform_atomic_replace_file(ptr %temporary, i64 %temporary_len, ptr %destination, i64 %destination_len) #0 {
entry:
  %temporary_buf = alloca [260 x i16], align 2
  %temporary_ptr = getelementptr inbounds [260 x i16], ptr %temporary_buf, i64 0, i64 0
  %temporary_fits = icmp ule i64 %temporary_len, 259
  br i1 %temporary_fits, label %convert_temporary, label %fail
convert_temporary:
  %temporary_ok = call i32 @sollang_windows_utf8_path(ptr %temporary, i64 %temporary_len, ptr %temporary_ptr, i32 260)
  %temporary_valid = icmp ne i32 %temporary_ok, 0
  br i1 %temporary_valid, label %copy_destination, label %fail

copy_destination:
  %destination_buf = alloca [260 x i16], align 2
  %destination_ptr = getelementptr inbounds [260 x i16], ptr %destination_buf, i64 0, i64 0
  %destination_fits = icmp ule i64 %destination_len, 259
  br i1 %destination_fits, label %convert_destination, label %fail
convert_destination:
  %destination_ok = call i32 @sollang_windows_utf8_path(ptr %destination, i64 %destination_len, ptr %destination_ptr, i32 260)
  %destination_valid = icmp ne i32 %destination_ok, 0
  br i1 %destination_valid, label %replace, label %fail

replace:
  %result = call i32 @MoveFileExW(ptr %temporary_ptr, ptr %destination_ptr, i32 9)
  ret i32 %result

fail:
  ret i32 0
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i16], align 2
  %buf_ptr = getelementptr inbounds [260 x i16], ptr %buf, i64 0, i64 0
  %fits = icmp ule i64 %len, 259
  br i1 %fits, label %convert, label %fail
convert:
  %copy_ok = call i32 @sollang_windows_utf8_path(ptr %path, i64 %len, ptr %buf_ptr, i32 260)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:
  %handle = call ptr @CreateFileW(ptr %buf_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 1073741952, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:
  %ok0 = insertvalue %sollang.file_handle_result poison, i64 %handle_int, 0
  %ok1 = insertvalue %sollang.file_handle_result %ok0, i32 1, 1
  ret %sollang.file_handle_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %fail1 = insertvalue %sollang.file_handle_result %fail0, i32 0, 1
  ret %sollang.file_handle_result %fail1
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i16], align 2
  %buf_ptr = getelementptr inbounds [260 x i16], ptr %buf, i64 0, i64 0
  %fits = icmp ule i64 %len, 259
  br i1 %fits, label %convert, label %fail
convert:
  %copy_ok = call i32 @sollang_windows_utf8_path(ptr %path, i64 %len, ptr %buf_ptr, i32 260)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:
  %handle = call ptr @CreateFileW(ptr %buf_ptr, i32 1073741824, i32 1, ptr null, i32 2, i32 1073741952, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:
  %ok0 = insertvalue %sollang.file_handle_result poison, i64 %handle_int, 0
  %ok1 = insertvalue %sollang.file_handle_result %ok0, i32 1, 1
  ret %sollang.file_handle_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %fail1 = insertvalue %sollang.file_handle_result %fail0, i32 0, 1
  ret %sollang.file_handle_result %fail1
}

define internal i64 @sollang_platform_duplicate_owned_file(i64 %source_value) #0 {
entry:
  %source = inttoptr i64 %source_value to ptr
  %process = call ptr @GetCurrentProcess()
  %target_slot = alloca ptr, align 8
  %ok = call i32 @DuplicateHandle(ptr %process, ptr %source, ptr %process, ptr %target_slot, i32 0, i32 0, i32 2)
  %succeeded = icmp ne i32 %ok, 0
  br i1 %succeeded, label %success, label %fail

success:
  %target = load ptr, ptr %target_slot, align 8
  %target_value = ptrtoint ptr %target to i64
  ret i64 %target_value

fail:
  ret i64 -1
}

define internal %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %handle_value, ptr %data, i64 %len64, i64 %offset) #0 {
entry:
  %valid_handle = icmp ne i64 %handle_value, -1
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %fits = icmp ule i64 %len64, 4294967295
  %ready0 = and i1 %valid_handle, %valid_offset
  %ready = and i1 %ready0, %fits
  br i1 %ready, label %read, label %fail

read:
  %handle = inttoptr i64 %handle_value to ptr
  %overlapped = alloca [32 x i8], align 8
  call void @llvm.memset.p0.i64(ptr %overlapped, i8 0, i64 32, i1 false)
  %offset_low_slot = getelementptr i8, ptr %overlapped, i64 16
  %offset_low = trunc i64 %offset to i32
  store i32 %offset_low, ptr %offset_low_slot, align 4
  %offset_high_slot = getelementptr i8, ptr %overlapped, i64 20
  %offset_shifted = lshr i64 %offset, 32
  %offset_high = trunc i64 %offset_shifted to i32
  store i32 %offset_high, ptr %offset_high_slot, align 4
  %count_slot = alloca i32, align 4
  store i32 0, ptr %count_slot, align 4
  %len = trunc i64 %len64 to i32
  %started = call i32 @ReadFile(ptr %handle, ptr %data, i32 %len, ptr null, ptr %overlapped)
  %completed = call i32 @GetOverlappedResult(ptr %handle, ptr %overlapped, ptr %count_slot, i32 1)
  %ok = icmp ne i32 %completed, 0
  br i1 %ok, label %success, label %classify_failure

classify_failure:
  %error = call i32 @GetLastError()
  %eof = icmp eq i32 %error, 38
  br i1 %eof, label %success, label %fail

success:
  %count32 = load i32, ptr %count_slot, align 4
  %count = zext i32 %count32 to i64
  %ok0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.file_count_result %ok0, i32 1, 1
  ret %sollang.file_count_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1
  ret %sollang.file_count_result %fail1
}

define internal %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %handle_value, ptr %data, i64 %len64, i64 %offset) #0 {
entry:
  %valid_handle = icmp ne i64 %handle_value, -1
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %fits = icmp ule i64 %len64, 4294967295
  %ready0 = and i1 %valid_handle, %valid_offset
  %ready = and i1 %ready0, %fits
  br i1 %ready, label %write, label %fail

write:
  %handle = inttoptr i64 %handle_value to ptr
  %overlapped = alloca [32 x i8], align 8
  call void @llvm.memset.p0.i64(ptr %overlapped, i8 0, i64 32, i1 false)
  %offset_low_slot = getelementptr i8, ptr %overlapped, i64 16
  %offset_low = trunc i64 %offset to i32
  store i32 %offset_low, ptr %offset_low_slot, align 4
  %offset_high_slot = getelementptr i8, ptr %overlapped, i64 20
  %offset_shifted = lshr i64 %offset, 32
  %offset_high = trunc i64 %offset_shifted to i32
  store i32 %offset_high, ptr %offset_high_slot, align 4
  %count_slot = alloca i32, align 4
  store i32 0, ptr %count_slot, align 4
  %len = trunc i64 %len64 to i32
  %started = call i32 @WriteFile(ptr %handle, ptr %data, i32 %len, ptr null, ptr %overlapped)
  %completed = call i32 @GetOverlappedResult(ptr %handle, ptr %overlapped, ptr %count_slot, i32 1)
  %ok = icmp ne i32 %completed, 0
  br i1 %ok, label %success, label %fail

success:
  %count32 = load i32, ptr %count_slot, align 4
  %count = zext i32 %count32 to i64
  %ok0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.file_count_result %ok0, i32 1, 1
  ret %sollang.file_count_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1
  ret %sollang.file_count_result %fail1
}

define internal i32 @sollang_platform_sync_owned_file(i64 %handle_value) #0 {
entry:
  %valid = icmp ne i64 %handle_value, -1
  br i1 %valid, label %sync, label %fail

sync:
  %handle = inttoptr i64 %handle_value to ptr
  %ok = call i32 @FlushFileBuffers(ptr %handle)
  ret i32 %ok

fail:
  ret i32 0
}

define internal void @sollang_platform_close_owned_file(i64 %handle_value) #0 {
entry:
  %valid = icmp ne i64 %handle_value, -1
  br i1 %valid, label %close, label %done

close:
  %handle = inttoptr i64 %handle_value to ptr
  %ignored = call i32 @CloseHandle(ptr %handle)
  br label %done

done:
  ret void
}

define internal i32 @sollang_platform_open_write_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:
  %handle = call ptr @CreateFileA(ptr %buf_ptr, i32 1073741824, i32 0, ptr null, i32 2, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:
  store ptr %handle, ptr @sollang_file_writer, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_platform_write_file_bytes(ptr %data, i64 %len64) #0 {
entry:
  %handle = load ptr, ptr @sollang_file_writer, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %write, label %fail

write:
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

fail:
  ret i32 0
}

define internal i32 @sollang_platform_close_write_file() #0 {
entry:
  %handle = load ptr, ptr @sollang_file_writer, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %close, label %fail

close:
  %ok = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %ok, 0
  br i1 %close_ok, label %success, label %fail

success:
  store ptr null, ptr @sollang_file_writer, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_platform_open_read_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open, label %fail

open:
  %handle = call ptr @CreateFileA(ptr %buf_ptr, i32 -2147483648, i32 1, ptr null, i32 3, i32 128, ptr null)
  %handle_int = ptrtoint ptr %handle to i64
  %invalid = icmp eq i64 %handle_int, -1
  br i1 %invalid, label %fail, label %success

success:
  store ptr %handle, ptr @sollang_file_reader, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal %sollang.file_count_result @sollang_platform_i64_file_count() #0 {
entry:
  %handle = load ptr, ptr @sollang_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %size, label %fail

size:
  %size_ptr = alloca i64, align 8
  %ok = call i32 @GetFileSizeEx(ptr %handle, ptr %size_ptr)
  %size_ok = icmp ne i32 %ok, 0
  br i1 %size_ok, label %check, label %fail

check:
  %bytes = load i64, ptr %size_ptr, align 8
  %rem = urem i64 %bytes, 8
  %aligned = icmp eq i64 %rem, 0
  br i1 %aligned, label %success, label %fail

success:
  %count = udiv i64 %bytes, 8
  %ok0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.file_count_result %ok0, i32 1, 1
  ret %sollang.file_count_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1
  ret %sollang.file_count_result %fail1
}

define internal %sollang.file_int_result @sollang_platform_read_i64_at(i64 %index) #0 {
entry:
  %handle = load ptr, ptr @sollang_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %seek, label %fail

seek:
  %offset = mul i64 %index, 8
  %seek_ok = call i32 @SetFilePointerEx(ptr %handle, i64 %offset, ptr null, i32 0)
  %seek_is_ok = icmp ne i32 %seek_ok, 0
  br i1 %seek_is_ok, label %read, label %fail

read:
  %value_ptr = alloca i64, align 8
  %read_bytes = alloca i32, align 4
  %ok = call i32 @ReadFile(ptr %handle, ptr %value_ptr, i32 8, ptr %read_bytes, ptr null)
  %read_ok = icmp ne i32 %ok, 0
  %read_count = load i32, ptr %read_bytes, align 4
  %read_full = icmp eq i32 %read_count, 8
  %all_ok = and i1 %read_ok, %read_full
  br i1 %all_ok, label %success, label %fail

success:
  %value = load i64, ptr %value_ptr, align 8
  %ok0 = insertvalue %sollang.file_int_result poison, i64 %value, 0
  %ok1 = insertvalue %sollang.file_int_result %ok0, i32 1, 1
  ret %sollang.file_int_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_int_result %fail0, i32 0, 1
  ret %sollang.file_int_result %fail1
}

define internal %sollang.file_count_result @sollang_platform_read_file_bytes(ptr %data, i64 %len64) #0 {
entry:
  %handle = load ptr, ptr @sollang_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  %fits = icmp ule i64 %len64, 4294967295
  %ready = and i1 %has_handle, %fits
  br i1 %ready, label %read, label %fail

read:
  %len = trunc i64 %len64 to i32
  %count_ptr = alloca i32, align 4
  %result = call i32 @ReadFile(ptr %handle, ptr %data, i32 %len, ptr %count_ptr, ptr null)
  %ok = icmp ne i32 %result, 0
  br i1 %ok, label %success, label %fail

success:
  %count32 = load i32, ptr %count_ptr, align 4
  %count = zext i32 %count32 to i64
  %ok0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.file_count_result %ok0, i32 1, 1
  ret %sollang.file_count_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1
  ret %sollang.file_count_result %fail1
}

define internal i32 @sollang_platform_close_read_file() #0 {
entry:
  %handle = load ptr, ptr @sollang_file_reader, align 8
  %has_handle = icmp ne ptr %handle, null
  br i1 %has_handle, label %close, label %fail

close:
  %ok = call i32 @CloseHandle(ptr %handle)
  %close_ok = icmp ne i32 %ok, 0
  br i1 %close_ok, label %success, label %fail

success:
  store ptr null, ptr @sollang_file_reader, align 8
  ret i32 1

fail:
  ret i32 0
}

define internal %sollang.mapped_bytes @sollang_map_file(ptr %path, i64 %path_len, i64 %offset, i64 %requested_len, i64 %requested_size, i1 %writable) #0 {
entry:
  %buf = alloca [260 x i16], align 2
  %buf_ptr = getelementptr inbounds [260 x i16], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_windows_utf8_path(ptr %path, i64 %path_len, ptr %buf_ptr, i32 260)
  %path_ok = icmp ne i32 %copy_ok, 0
  br i1 %path_ok, label %open, label %fail

open:
  %access = select i1 %writable, i32 -1073741824, i32 -2147483648
  %creation = select i1 %writable, i32 4, i32 3
  %file = call ptr @CreateFileW(ptr %buf_ptr, i32 %access, i32 1, ptr null, i32 %creation, i32 128, ptr null)
  %file_int = ptrtoint ptr %file to i64
  %file_ok = icmp ne i64 %file_int, -1
  br i1 %file_ok, label %resize_check, label %fail

resize_check:
  %has_requested_size = icmp ne i64 %requested_size, 0
  %resize = and i1 %writable, %has_requested_size
  br i1 %resize, label %resize_file, label %read_size

resize_file:
  %seek_ok = call i32 @SetFilePointerEx(ptr %file, i64 %requested_size, ptr null, i32 0)
  %seek_valid = icmp ne i32 %seek_ok, 0
  br i1 %seek_valid, label %resize_end, label %close_fail

resize_end:
  %end_ok = call i32 @SetEndOfFile(ptr %file)
  %resize_valid = icmp ne i32 %end_ok, 0
  br i1 %resize_valid, label %read_size, label %close_fail

read_size:
  %size_slot = alloca i64, align 8
  %size_ok = call i32 @GetFileSizeEx(ptr %file, ptr %size_slot)
  %size_valid = icmp ne i32 %size_ok, 0
  br i1 %size_valid, label %bounds, label %close_fail

bounds:
  %file_size = load i64, ptr %size_slot, align 8
  %offset_ok = icmp ule i64 %offset, %file_size
  %remaining = sub i64 %file_size, %offset
  %whole = icmp eq i64 %requested_len, 0
  %view_len = select i1 %whole, i64 %remaining, i64 %requested_len
  %len_nonzero = icmp ne i64 %view_len, 0
  %len_ok = icmp ule i64 %view_len, %remaining
  %bounds1 = and i1 %offset_ok, %len_nonzero
  %bounds_ok = and i1 %bounds1, %len_ok
  br i1 %bounds_ok, label %mapping, label %close_fail

mapping:
  %protect = select i1 %writable, i32 4, i32 2
  %mapping_handle = call ptr @CreateFileMappingA(ptr %file, ptr null, i32 %protect, i32 0, i32 0, ptr null)
  %mapping_ok = icmp ne ptr %mapping_handle, null
  br i1 %mapping_ok, label %view, label %close_fail

view:
  %aligned = and i64 %offset, -65536
  %delta = sub i64 %offset, %aligned
  %mapped_len = add i64 %delta, %view_len
  %high64 = lshr i64 %aligned, 32
  %high = trunc i64 %high64 to i32
  %low = trunc i64 %aligned to i32
  %desired = select i1 %writable, i32 2, i32 4
  %base = call ptr @MapViewOfFile(ptr %mapping_handle, i32 %desired, i32 %high, i32 %low, i64 %mapped_len)
  %base_ok = icmp ne ptr %base, null
  br i1 %base_ok, label %success, label %mapping_close_fail

success:
  %data = getelementptr i8, ptr %base, i64 %delta
  %ignored_mapping = call i32 @CloseHandle(ptr %mapping_handle)
  %ignored_file = call i32 @CloseHandle(ptr %file)
  %r0 = insertvalue %sollang.mapped_bytes poison, ptr %data, 0
  %r1 = insertvalue %sollang.mapped_bytes %r0, i64 %view_len, 1
  %r2 = insertvalue %sollang.mapped_bytes %r1, ptr %base, 2
  %r3 = insertvalue %sollang.mapped_bytes %r2, i64 %mapped_len, 3
  %r4 = insertvalue %sollang.mapped_bytes %r3, i1 %writable, 4
  ret %sollang.mapped_bytes %r4

mapping_close_fail:
  %ignored_mapping_fail = call i32 @CloseHandle(ptr %mapping_handle)
  br label %close_fail

close_fail:
  %ignored_close = call i32 @CloseHandle(ptr %file)
  br label %fail

fail:
  %f0 = insertvalue %sollang.mapped_bytes zeroinitializer, i1 %writable, 4
  ret %sollang.mapped_bytes %f0
}

define internal i32 @sollang_mapped_flush(ptr %base, i64 %mapped_len) #0 {
entry:
  %ok = call i32 @FlushViewOfFile(ptr %base, i64 %mapped_len)
  ret i32 %ok
}

define internal void @sollang_mapped_unmap(ptr %base, i64 %mapped_len) #0 {
entry:
  %ignored = call i32 @UnmapViewOfFile(ptr %base)
  ret void
}

define internal i64 @sollang_now_millis() #0 {
entry:
  %millis = call i64 @GetTickCount64()
  ret i64 %millis
}

define internal i64 @sollang_utc_now_millis() #0 {
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

define internal void @sollang_wait_millis(i64 %requested) #0 {
entry:
  %positive = icmp sgt i64 %requested, 0
  br i1 %positive, label %clamp, label %done

clamp:
  %too_large = icmp ugt i64 %requested, 4294967294
  %bounded = select i1 %too_large, i64 4294967294, i64 %requested
  %millis = trunc i64 %bounded to i32
  call void @Sleep(i32 %millis)
  br label %done

done:
  ret void
}

define internal ptr @sollang_alloc(i64 %bytes) #0 {
entry:
  %heap = call ptr @GetProcessHeap()
  %ptr = call ptr @HeapAlloc(ptr %heap, i32 0, i64 %bytes)
  ret ptr %ptr
}

define internal void @sollang_free(ptr %ptr) #0 {
entry:
  %is_null = icmp eq ptr %ptr, null
  br i1 %is_null, label %done, label %free

free:
  %heap = call ptr @GetProcessHeap()
  %ignored = call i32 @HeapFree(ptr %heap, i32 0, ptr %ptr)
  br label %done

done:
  ret void
}

define dso_local ptr @memset(ptr %dest, i32 %value, i64 %count) #0 {
entry:
  %byte = trunc i32 %value to i8
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %next, %body ]
  %active = icmp ult i64 %i, %count
  br i1 %active, label %body, label %done

body:
  %slot = getelementptr i8, ptr %dest, i64 %i
  store i8 %byte, ptr %slot, align 1
  %next = add i64 %i, 1
  br label %loop

done:
  ret ptr %dest
}

define dso_local ptr @memcpy(ptr %dest, ptr %source, i64 %count) #0 {
entry:
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %next, %body ]
  %active = icmp ult i64 %i, %count
  br i1 %active, label %body, label %done

body:
  %src_slot = getelementptr i8, ptr %source, i64 %i
  %dst_slot = getelementptr i8, ptr %dest, i64 %i
  %byte = load i8, ptr %src_slot, align 1
  store i8 %byte, ptr %dst_slot, align 1
  %next = add i64 %i, 1
  br label %loop

done:
  ret ptr %dest
}

define dso_local ptr @memmove(ptr %dest, ptr %source, i64 %count) #0 {
entry:
  %same = icmp eq ptr %dest, %source
  %empty = icmp eq i64 %count, 0
  %done_early = or i1 %same, %empty
  br i1 %done_early, label %done, label %choose_direction

choose_direction:
  %forward = icmp ult ptr %dest, %source
  br i1 %forward, label %forward_loop, label %backward_loop

forward_loop:
  %forward_i = phi i64 [ 0, %choose_direction ], [ %forward_next, %forward_body ]
  %forward_active = icmp ult i64 %forward_i, %count
  br i1 %forward_active, label %forward_body, label %done

forward_body:
  %forward_src = getelementptr i8, ptr %source, i64 %forward_i
  %forward_dst = getelementptr i8, ptr %dest, i64 %forward_i
  %forward_byte = load i8, ptr %forward_src, align 1
  store i8 %forward_byte, ptr %forward_dst, align 1
  %forward_next = add i64 %forward_i, 1
  br label %forward_loop

backward_loop:
  %backward_i = phi i64 [ %count, %choose_direction ], [ %backward_next, %backward_body ]
  %backward_active = icmp ugt i64 %backward_i, 0
  br i1 %backward_active, label %backward_body, label %done

backward_body:
  %backward_next = sub i64 %backward_i, 1
  %backward_src = getelementptr i8, ptr %source, i64 %backward_next
  %backward_dst = getelementptr i8, ptr %dest, i64 %backward_next
  %backward_byte = load i8, ptr %backward_src, align 1
  store i8 %backward_byte, ptr %backward_dst, align 1
  br label %backward_loop

done:
  ret ptr %dest
}

define internal i64 @sollang_format_u64(ptr %dest, i64 %value) #0 {
entry:
  br label %count

count:
  %count_n = phi i64 [ %value, %entry ], [ %count_q, %count_more ]
  %length = phi i64 [ 1, %entry ], [ %next_length, %count_more ]
  %count_q = udiv i64 %count_n, 10
  %count_done = icmp eq i64 %count_q, 0
  br i1 %count_done, label %write_entry, label %count_more

count_more:
  %next_length = add i64 %length, 1
  br label %count

write_entry:
  %last_index = sub i64 %length, 1
  br label %write

write:
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

return:
  ret i64 %length
}

define internal i64 @sollang_format_i64(ptr %dest, i64 %value) #0 {
entry:
  %negative = icmp slt i64 %value, 0
  br i1 %negative, label %negative_value, label %positive_value

negative_value:
  store i8 45, ptr %dest, align 1
  %digits_dest = getelementptr i8, ptr %dest, i64 1
  %magnitude = sub i64 0, %value
  %negative_digits = call i64 @sollang_format_u64(ptr %digits_dest, i64 %magnitude)
  %negative_length = add i64 %negative_digits, 1
  ret i64 %negative_length

positive_value:
  %positive_length = call i64 @sollang_format_u64(ptr %dest, i64 %value)
  ret i64 %positive_length
}

define internal i32 @sollang_write_u64(ptr %stdout, i64 %value, ptr %written) #0 {
entry:
  %buf = alloca [20 x i8], align 1
  %end = getelementptr inbounds [20 x i8], ptr %buf, i64 0, i64 20
  br label %digits

digits:
  %n = phi i64 [ %value, %entry ], [ %q, %digits ]
  %p = phi ptr [ %end, %entry ], [ %next, %digits ]
  %digit = urem i64 %n, 10
  %q = udiv i64 %n, 10
  %next = getelementptr i8, ptr %p, i64 -1
  %digit8 = trunc i64 %digit to i8
  %ascii = add i8 %digit8, 48
  store i8 %ascii, ptr %next, align 1
  %done = icmp eq i64 %q, 0
  br i1 %done, label %write, label %digits

write:
  %start_int = ptrtoint ptr %next to i64
  %end_int = ptrtoint ptr %end to i64
  %len = sub i64 %end_int, %start_int
  %ok = call i32 @sollang_write(ptr %stdout, ptr %next, i64 %len, ptr %written)
  ret i32 %ok
}

define internal i32 @sollang_write_i64(ptr %stdout, i64 %value, ptr %written) #0 {
entry:
  %negative = icmp slt i64 %value, 0
  br i1 %negative, label %write_sign, label %write_digits

write_sign:
  %sign = alloca i8, align 1
  store i8 45, ptr %sign, align 1
  %sign_ok = call i32 @sollang_write(ptr %stdout, ptr %sign, i64 1, ptr %written)
  %magnitude = sub i64 0, %value
  %digits_ok_negative = call i32 @sollang_write_u64(ptr %stdout, i64 %magnitude, ptr %written)
  %negative_ok = and i32 %sign_ok, %digits_ok_negative
  ret i32 %negative_ok

write_digits:
  %digits_ok = call i32 @sollang_write_u64(ptr %stdout, i64 %value, ptr %written)
  ret i32 %digits_ok
}

define internal %sollang.read_int_result @sollang_read_i64(ptr %stdin, ptr %read) #0 {
entry:
  %buf = alloca [64 x i8], align 1
  %ok = call i32 @sollang_read_stdin(ptr %stdin, ptr %buf, i64 64, ptr %read)
  %read_ok = icmp ne i32 %ok, 0
  br i1 %read_ok, label %prepare, label %fail

prepare:
  %read32 = load i32, ptr %read, align 4
  %len = zext i32 %read32 to i64
  br label %skip

skip:
  %skip_idx = phi i64 [ 0, %prepare ], [ %skip_next, %skip_ws ]
  %skip_has = icmp ult i64 %skip_idx, %len
  br i1 %skip_has, label %skip_char, label %fail

skip_char:
  %skip_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %skip_idx
  %skip_ch = load i8, ptr %skip_ptr, align 1
  %skip_sp = icmp eq i8 %skip_ch, 32
  %skip_tab = icmp eq i8 %skip_ch, 9
  %skip_cr = icmp eq i8 %skip_ch, 13
  %skip_lf = icmp eq i8 %skip_ch, 10
  %skip_sp_tab = or i1 %skip_sp, %skip_tab
  %skip_cr_lf = or i1 %skip_cr, %skip_lf
  %skip_is_ws = or i1 %skip_sp_tab, %skip_cr_lf
  br i1 %skip_is_ws, label %skip_ws, label %digit_entry

skip_ws:
  %skip_next = add i64 %skip_idx, 1
  br label %skip

digit_entry:
  %first_ge = icmp uge i8 %skip_ch, 48
  %first_le = icmp ule i8 %skip_ch, 57
  %first_digit = and i1 %first_ge, %first_le
  br i1 %first_digit, label %digits, label %fail

digits:
  %digit_idx = phi i64 [ %skip_idx, %digit_entry ], [ %digit_next, %digit_continue ]
  %value = phi i64 [ 0, %digit_entry ], [ %value_next, %digit_continue ]
  %digit_has = icmp ult i64 %digit_idx, %len
  br i1 %digit_has, label %digit_char, label %success

digit_char:
  %digit_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %digit_idx
  %digit_ch = load i8, ptr %digit_ptr, align 1
  %digit_ge = icmp uge i8 %digit_ch, 48
  %digit_le = icmp ule i8 %digit_ch, 57
  %is_digit = and i1 %digit_ge, %digit_le
  br i1 %is_digit, label %digit_continue, label %trail_entry

digit_continue:
  %digit64 = zext i8 %digit_ch to i64
  %digit_value = sub i64 %digit64, 48
  %value_x10 = mul i64 %value, 10
  %value_next = add i64 %value_x10, %digit_value
  %digit_next = add i64 %digit_idx, 1
  br label %digits

trail_entry:
  br label %trail

trail:
  %trail_idx = phi i64 [ %digit_idx, %trail_entry ], [ %trail_next, %trail_ws ]
  %trail_has = icmp ult i64 %trail_idx, %len
  br i1 %trail_has, label %trail_char, label %success

trail_char:
  %trail_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %trail_idx
  %trail_ch = load i8, ptr %trail_ptr, align 1
  %trail_sp = icmp eq i8 %trail_ch, 32
  %trail_tab = icmp eq i8 %trail_ch, 9
  %trail_cr = icmp eq i8 %trail_ch, 13
  %trail_lf = icmp eq i8 %trail_ch, 10
  %trail_sp_tab = or i1 %trail_sp, %trail_tab
  %trail_cr_lf = or i1 %trail_cr, %trail_lf
  %trail_is_ws = or i1 %trail_sp_tab, %trail_cr_lf
  br i1 %trail_is_ws, label %trail_ws, label %fail

trail_ws:
  %trail_next = add i64 %trail_idx, 1
  br label %trail

success:
  %success_value = phi i64 [ %value, %digits ], [ %value, %trail ]
  %success0 = insertvalue %sollang.read_int_result poison, i64 %success_value, 0
  %success1 = insertvalue %sollang.read_int_result %success0, i32 1, 1
  ret %sollang.read_int_result %success1

fail:
  %fail0 = insertvalue %sollang.read_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.read_int_result %fail0, i32 0, 1
  ret %sollang.read_int_result %fail1
}

define internal i32 @sollang_copy_text_to_c_path(ptr %data, i64 %len, ptr %out) #0 {
entry:
  %too_long = icmp ugt i64 %len, 259
  br i1 %too_long, label %fail, label %copy

copy:
  %i = phi i64 [ 0, %entry ], [ %next, %copy_body ]
  %done = icmp eq i64 %i, %len
  br i1 %done, label %nul, label %copy_body

copy_body:
  %src = getelementptr i8, ptr %data, i64 %i
  %ch = load i8, ptr %src, align 1
  %dst = getelementptr i8, ptr %out, i64 %i
  store i8 %ch, ptr %dst, align 1
  %next = add i64 %i, 1
  br label %copy

nul:
  %nul_ptr = getelementptr i8, ptr %out, i64 %len
  store i8 0, ptr %nul_ptr, align 1
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_file_path_has_no_nul(ptr %data, i64 %len) #0 {
entry:
  br label %check

check:
  %i = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %i, %len
  br i1 %done, label %valid, label %read

read:
  %src = getelementptr i8, ptr %data, i64 %i
  %ch = load i8, ptr %src, align 1
  %is_nul = icmp eq i8 %ch, 0
  br i1 %is_nul, label %invalid, label %advance

advance:
  %next = add i64 %i, 1
  br label %check

valid:
  ret i32 1

invalid:
  ret i32 0
}

define internal i32 @sollang_seed_random(i64 %seed) #0 {
entry:
  store i64 %seed, ptr @sollang_random_state, align 8
  ret i32 1
}

define internal %sollang.file_int_result @sollang_random_below(i64 %max) #0 {
entry:
  %valid = icmp sgt i64 %max, 0
  br i1 %valid, label %next, label %fail

next:
  %state = load i64, ptr @sollang_random_state, align 8
  %mul = mul i64 %state, 6364136223846793005
  %new_state = add i64 %mul, 1442695040888963407
  store i64 %new_state, ptr @sollang_random_state, align 8
  %value = urem i64 %new_state, %max
  %ok0 = insertvalue %sollang.file_int_result poison, i64 %value, 0
  %ok1 = insertvalue %sollang.file_int_result %ok0, i32 1, 1
  ret %sollang.file_int_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_int_result %fail0, i32 0, 1
  ret %sollang.file_int_result %fail1
}

define internal i32 @sollang_open_write_i64_file(ptr %path, i64 %len) #0 {
entry:
  store i64 0, ptr @sollang_writer_buffer_count, align 8
  %ok = call i32 @sollang_platform_open_write_file(ptr %path, i64 %len)
  ret i32 %ok
}

define internal i32 @sollang_flush_i64_file() #0 {
entry:
  %count = load i64, ptr @sollang_writer_buffer_count, align 8
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %success, label %flush

flush:
  %bytes = mul i64 %count, 8
  %ok = call i32 @sollang_platform_write_file_bytes(ptr @sollang_writer_buffer, i64 %bytes)
  %is_ok = icmp ne i32 %ok, 0
  br i1 %is_ok, label %reset, label %fail

reset:
  store i64 0, ptr @sollang_writer_buffer_count, align 8
  br label %success

success:
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_write_i64_file(i64 %value) #0 {
entry:
  %count = load i64, ptr @sollang_writer_buffer_count, align 8
  %slot = getelementptr inbounds [8192 x i64], ptr @sollang_writer_buffer, i64 0, i64 %count
  store i64 %value, ptr %slot, align 8
  %next = add i64 %count, 1
  store i64 %next, ptr @sollang_writer_buffer_count, align 8
  %full = icmp eq i64 %next, 8192
  br i1 %full, label %flush, label %success

flush:
  %ok = call i32 @sollang_flush_i64_file()
  ret i32 %ok

success:
  ret i32 1
}

define internal i32 @sollang_close_write_i64_file() #0 {
entry:
  %flush_ok = call i32 @sollang_flush_i64_file()
  %flush_is_ok = icmp ne i32 %flush_ok, 0
  br i1 %flush_is_ok, label %close, label %fail

close:
  %close_ok = call i32 @sollang_platform_close_write_file()
  ret i32 %close_ok

fail:
  ret i32 0
}

define internal %sollang.file_int_result @sollang_closest_i64_file(i64 %target) #0 {
entry:
  %count_result = call %sollang.file_count_result @sollang_platform_i64_file_count()
  %count = extractvalue %sollang.file_count_result %count_result, 0
  %count_ok = extractvalue %sollang.file_count_result %count_result, 1
  %count_is_ok = icmp ne i32 %count_ok, 0
  %has_values = icmp sgt i64 %count, 0
  %can_search = and i1 %count_is_ok, %has_values
  br i1 %can_search, label %search, label %fail

search:
  br label %loop

loop:
  %low = phi i64 [ 0, %search ], [ %next_low, %step ]
  %high = phi i64 [ %count, %search ], [ %next_high, %step ]
  %active = icmp slt i64 %low, %high
  br i1 %active, label %probe, label %choose

probe:
  %span = sub i64 %high, %low
  %half = sdiv i64 %span, 2
  %mid = add i64 %low, %half
  %mid_result = call %sollang.file_int_result @sollang_platform_read_i64_at(i64 %mid)
  %mid_value = extractvalue %sollang.file_int_result %mid_result, 0
  %mid_ok = extractvalue %sollang.file_int_result %mid_result, 1
  %mid_is_ok = icmp ne i32 %mid_ok, 0
  br i1 %mid_is_ok, label %compare_mid, label %fail

compare_mid:
  %less = icmp slt i64 %mid_value, %target
  br i1 %less, label %move_low, label %move_high

move_low:
  %low_plus = add i64 %mid, 1
  br label %step

move_high:
  br label %step

step:
  %next_low = phi i64 [ %low_plus, %move_low ], [ %low, %move_high ]
  %next_high = phi i64 [ %high, %move_low ], [ %mid, %move_high ]
  br label %loop

choose:
  %at_start = icmp eq i64 %low, 0
  br i1 %at_start, label %read_low, label %check_end

check_end:
  %at_end = icmp eq i64 %low, %count
  br i1 %at_end, label %read_prev_only, label %read_pair

read_low:
  %first_result = call %sollang.file_int_result @sollang_platform_read_i64_at(i64 0)
  ret %sollang.file_int_result %first_result

read_prev_only:
  %last_index = sub i64 %count, 1
  %last_result = call %sollang.file_int_result @sollang_platform_read_i64_at(i64 %last_index)
  ret %sollang.file_int_result %last_result

read_pair:
  %prev_index = sub i64 %low, 1
  %prev_result = call %sollang.file_int_result @sollang_platform_read_i64_at(i64 %prev_index)
  %next_result = call %sollang.file_int_result @sollang_platform_read_i64_at(i64 %low)
  %prev_ok = extractvalue %sollang.file_int_result %prev_result, 1
  %next_ok = extractvalue %sollang.file_int_result %next_result, 1
  %prev_is_ok = icmp ne i32 %prev_ok, 0
  %next_is_ok = icmp ne i32 %next_ok, 0
  %both_ok = and i1 %prev_is_ok, %next_is_ok
  br i1 %both_ok, label %compare_pair, label %fail

compare_pair:
  %prev_value = extractvalue %sollang.file_int_result %prev_result, 0
  %next_value = extractvalue %sollang.file_int_result %next_result, 0
  %prev_diff = sub i64 %target, %prev_value
  %next_diff = sub i64 %next_value, %target
  %prefer_prev = icmp sle i64 %prev_diff, %next_diff
  br i1 %prefer_prev, label %return_prev, label %return_next

return_prev:
  ret %sollang.file_int_result %prev_result

return_next:
  ret %sollang.file_int_result %next_result

fail:
  %fail0 = insertvalue %sollang.file_int_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_int_result %fail0, i32 0, 1
  ret %sollang.file_int_result %fail1
}
define internal i64 @sollang_utf8_decode(ptr %data, i64 %len, i64 %index) #0 {
entry:
  %has_first = icmp ult i64 %index, %len
  br i1 %has_first, label %first, label %invalid

first:
  %p0 = getelementptr i8, ptr %data, i64 %index
  %b0raw = load i8, ptr %p0, align 1
  %b0 = zext i8 %b0raw to i32
  %ascii = icmp ult i32 %b0, 128
  br i1 %ascii, label %ascii_result, label %classify

ascii_result:
  %ascii_wide = zext i32 %b0 to i64
  %ascii_packed = or i64 %ascii_wide, 4294967296
  ret i64 %ascii_packed

classify:
  %is2lo = icmp uge i32 %b0, 194
  %is2hi = icmp ule i32 %b0, 223
  %is2 = and i1 %is2lo, %is2hi
  %is3lo = icmp uge i32 %b0, 224
  %is3hi = icmp ule i32 %b0, 239
  %is3 = and i1 %is3lo, %is3hi
  %is4lo = icmp uge i32 %b0, 240
  %is4hi = icmp ule i32 %b0, 244
  %is4 = and i1 %is4lo, %is4hi
  br i1 %is2, label %decode2, label %check3

check3:
  br i1 %is3, label %decode3, label %check4

check4:
  br i1 %is4, label %decode4, label %invalid

decode2:
  %end2 = add i64 %index, 1
  %has2 = icmp ult i64 %end2, %len
  br i1 %has2, label %load2, label %invalid

load2:
  %p1_2 = getelementptr i8, ptr %data, i64 %end2
  %b1_2raw = load i8, ptr %p1_2, align 1
  %b1_2 = zext i8 %b1_2raw to i32
  %c1_2lo = icmp uge i32 %b1_2, 128
  %c1_2hi = icmp ule i32 %b1_2, 191
  %c1_2 = and i1 %c1_2lo, %c1_2hi
  br i1 %c1_2, label %result2, label %invalid

result2:
  %h2 = and i32 %b0, 31
  %h2s = shl i32 %h2, 6
  %l2 = and i32 %b1_2, 63
  %cp2 = or i32 %h2s, %l2
  %cp2wide = zext i32 %cp2 to i64
  %packed2 = or i64 %cp2wide, 8589934592
  ret i64 %packed2

decode3:
  %end3 = add i64 %index, 2
  %has3 = icmp ult i64 %end3, %len
  br i1 %has3, label %load3, label %invalid

load3:
  %i1_3 = add i64 %index, 1
  %p1_3 = getelementptr i8, ptr %data, i64 %i1_3
  %p2_3 = getelementptr i8, ptr %data, i64 %end3
  %b1_3raw = load i8, ptr %p1_3, align 1
  %b2_3raw = load i8, ptr %p2_3, align 1
  %b1_3 = zext i8 %b1_3raw to i32
  %b2_3 = zext i8 %b2_3raw to i32
  %c1_3lo = icmp uge i32 %b1_3, 128
  %c1_3hi = icmp ule i32 %b1_3, 191
  %c1_3 = and i1 %c1_3lo, %c1_3hi
  %c2_3lo = icmp uge i32 %b2_3, 128
  %c2_3hi = icmp ule i32 %b2_3, 191
  %c2_3 = and i1 %c2_3lo, %c2_3hi
  %cont3 = and i1 %c1_3, %c2_3
  br i1 %cont3, label %value3, label %invalid

value3:
  %h3 = and i32 %b0, 15
  %h3s = shl i32 %h3, 12
  %m3 = and i32 %b1_3, 63
  %m3s = shl i32 %m3, 6
  %hm3 = or i32 %h3s, %m3s
  %l3 = and i32 %b2_3, 63
  %cp3 = or i32 %hm3, %l3
  %min3 = icmp uge i32 %cp3, 2048
  %below_surrogate = icmp ult i32 %cp3, 55296
  %above_surrogate = icmp ugt i32 %cp3, 57343
  %not_surrogate = or i1 %below_surrogate, %above_surrogate
  %valid3 = and i1 %min3, %not_surrogate
  br i1 %valid3, label %result3, label %invalid

result3:
  %cp3wide = zext i32 %cp3 to i64
  %packed3 = or i64 %cp3wide, 12884901888
  ret i64 %packed3

decode4:
  %end4 = add i64 %index, 3
  %has4 = icmp ult i64 %end4, %len
  br i1 %has4, label %load4, label %invalid

load4:
  %i1_4 = add i64 %index, 1
  %i2_4 = add i64 %index, 2
  %p1_4 = getelementptr i8, ptr %data, i64 %i1_4
  %p2_4 = getelementptr i8, ptr %data, i64 %i2_4
  %p3_4 = getelementptr i8, ptr %data, i64 %end4
  %b1_4raw = load i8, ptr %p1_4, align 1
  %b2_4raw = load i8, ptr %p2_4, align 1
  %b3_4raw = load i8, ptr %p3_4, align 1
  %b1_4 = zext i8 %b1_4raw to i32
  %b2_4 = zext i8 %b2_4raw to i32
  %b3_4 = zext i8 %b3_4raw to i32
  %c1_4lo = icmp uge i32 %b1_4, 128
  %c1_4hi = icmp ule i32 %b1_4, 191
  %c1_4 = and i1 %c1_4lo, %c1_4hi
  %c2_4lo = icmp uge i32 %b2_4, 128
  %c2_4hi = icmp ule i32 %b2_4, 191
  %c2_4 = and i1 %c2_4lo, %c2_4hi
  %c3_4lo = icmp uge i32 %b3_4, 128
  %c3_4hi = icmp ule i32 %b3_4, 191
  %c3_4 = and i1 %c3_4lo, %c3_4hi
  %cont12_4 = and i1 %c1_4, %c2_4
  %cont4 = and i1 %cont12_4, %c3_4
  br i1 %cont4, label %value4, label %invalid

value4:
  %h4 = and i32 %b0, 7
  %h4s = shl i32 %h4, 18
  %m1_4 = and i32 %b1_4, 63
  %m1_4s = shl i32 %m1_4, 12
  %m2_4 = and i32 %b2_4, 63
  %m2_4s = shl i32 %m2_4, 6
  %hm1_4 = or i32 %h4s, %m1_4s
  %hm2_4 = or i32 %hm1_4, %m2_4s
  %l4 = and i32 %b3_4, 63
  %cp4 = or i32 %hm2_4, %l4
  %min4 = icmp uge i32 %cp4, 65536
  %max4 = icmp ule i32 %cp4, 1114111
  %valid4 = and i1 %min4, %max4
  br i1 %valid4, label %result4, label %invalid

result4:
  %cp4wide = zext i32 %cp4 to i64
  %packed4 = or i64 %cp4wide, 17179869184
  ret i64 %packed4

invalid:
  ret i64 -1
}

define dso_local i32 @sollang_start() local_unnamed_addr {
entry:
  %stack_slot0 = alloca [24 x i8], align 8
  %written = alloca i32, align 4
  %read = alloca i32, align 4
  %ok_state = alloca i1, align 1
  %trap_written83 = alloca i32, align 4
  %trap_written302 = alloca i32, align 4
  store i1 true, ptr %ok_state, align 1
  %stdin = call ptr @GetStdHandle(i32 -10)
  %stdout = call ptr @GetStdHandle(i32 -11)
  %stdout_mode = alloca i32, align 4
  %stdout_is_console_status = call i32 @GetConsoleMode(ptr %stdout, ptr %stdout_mode)
  %stdout_is_console = icmp ne i32 %stdout_is_console_status, 0
  store i1 %stdout_is_console, ptr @sollang_stdout_line_buffered, align 1
  call void @llvm.lifetime.start.p0(i64 24, ptr %stack_slot0)
  %mutable_len_addr0 = getelementptr i8, ptr %stack_slot0, i64 8
  %mutable_capacity_addr1 = getelementptr i8, ptr %stack_slot0, i64 16
  store ptr null, ptr %stack_slot0, align 8
  store i64 0, ptr %mutable_len_addr0, align 8
  store i64 0, ptr %mutable_capacity_addr1, align 8
  %mutable_ptr2 = load ptr, ptr %stack_slot0, align 8
  %mutable_len3 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity4 = load i64, ptr %mutable_capacity_addr1, align 8
  %hash_key5 = sext i32 1 to i64
  %hash_high7 = lshr i64 %hash_key5, 32
  %hash_fold6 = xor i64 %hash_key5, %hash_high7
  %hash8 = mul i64 %hash_fold6, -7046029254386353131
  %dict_h2_shifted9 = lshr i64 %hash8, 57
  %dict_h2_raw10 = and i64 %dict_h2_shifted9, 127
  %dict_h2_zero11 = icmp eq i64 %dict_h2_raw10, 0
  %dict_h212 = select i1 %dict_h2_zero11, i64 1, i64 %dict_h2_raw10
  %dict_h2_byte13 = trunc i64 %dict_h212 to i8
  %dict_capacity_mask14 = sub i64 %mutable_capacity4, 1
  %dict_start_slot15 = and i64 %hash8, %dict_capacity_mask14
  br label %bb_dict_group_find0

bb_dict_group_find0:
  %dict_group_probe17 = phi i64 [ 0, %entry ], [ %dict_group_next_probe16, %bb_dict_group_next8 ]
  %dict_group_active18 = icmp ult i64 %dict_group_probe17, %mutable_capacity4
  br i1 %dict_group_active18, label %bb_dict_group_body1, label %bb_dict_group_miss9

bb_dict_group_body1:
  %dict_group_unwrapped19 = add i64 %dict_start_slot15, %dict_group_probe17
  %dict_group_start20 = and i64 %dict_group_unwrapped19, %dict_capacity_mask14
  %dict_group_pointer21 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_group_start20
  %dict_group_controls22 = load <16 x i8>, ptr %dict_group_pointer21, align 1
  %dict_group_h2_seed23 = insertelement <16 x i8> poison, i8 %dict_h2_byte13, i64 0
  %dict_group_h2_vector24 = shufflevector <16 x i8> %dict_group_h2_seed23, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector25 = icmp eq <16 x i8> %dict_group_controls22, %dict_group_h2_vector24
  %dict_group_match_bits26 = bitcast <16 x i1> %dict_group_matches_vector25 to i16
  %dict_group_empty_vector27 = icmp eq <16 x i8> %dict_group_controls22, zeroinitializer
  %dict_group_empty_bits28 = bitcast <16 x i1> %dict_group_empty_vector27 to i16
  br label %bb_dict_group_candidates2

bb_dict_group_candidates2:
  %dict_group_candidate_bits29 = phi i16 [ %dict_group_match_bits26, %bb_dict_group_body1 ], [ %dict_group_cleared_bits30, %bb_dict_group_candidate_next4 ]
  %dict_group_has_candidate31 = icmp ne i16 %dict_group_candidate_bits29, 0
  br i1 %dict_group_has_candidate31, label %bb_dict_group_candidate_body3, label %bb_dict_group_decision5

bb_dict_group_candidate_body3:
  %dict_group_candidate_offset1632 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits29, i1 false)
  %dict_group_candidate_offset33 = zext i16 %dict_group_candidate_offset1632 to i64
  %dict_group_candidate_unwrapped34 = add i64 %dict_group_start20, %dict_group_candidate_offset33
  %dict_group_candidate_slot35 = and i64 %dict_group_candidate_unwrapped34, %dict_capacity_mask14
  %dict_entries_offset_mirror36 = add i64 %mutable_capacity4, 23
  %dict_entries_offset37 = and i64 %dict_entries_offset_mirror36, -8
  %dict_entries38 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_entries_offset37
  %dict_key_offset39 = mul i64 %dict_group_candidate_slot35, 2
  %dict_key_slot40 = getelementptr i32, ptr %dict_entries38, i64 %dict_key_offset39
  %dict_key41 = load i32, ptr %dict_key_slot40, align 4
  %dict_group_key_match42 = icmp eq i32 %dict_key41, 1
  br i1 %dict_group_key_match42, label %bb_dict_group_match7, label %bb_dict_group_candidate_next4

bb_dict_group_candidate_next4:
  %dict_group_bits_minus_one43 = sub i16 %dict_group_candidate_bits29, 1
  %dict_group_cleared_bits30 = and i16 %dict_group_candidate_bits29, %dict_group_bits_minus_one43
  br label %bb_dict_group_candidates2

bb_dict_group_decision5:
  %dict_group_has_empty44 = icmp ne i16 %dict_group_empty_bits28, 0
  br i1 %dict_group_has_empty44, label %bb_dict_group_empty6, label %bb_dict_group_next8

bb_dict_group_empty6:
  %dict_group_empty_offset1645 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits28, i1 false)
  %dict_group_empty_offset46 = zext i16 %dict_group_empty_offset1645 to i64
  %dict_group_empty_unwrapped47 = add i64 %dict_group_start20, %dict_group_empty_offset46
  %dict_group_empty_slot48 = and i64 %dict_group_empty_unwrapped47, %dict_capacity_mask14
  br label %bb_dict_group_done10

bb_dict_group_match7:
  br label %bb_dict_group_done10

bb_dict_group_next8:
  %dict_group_next_probe16 = add i64 %dict_group_probe17, 16
  br label %bb_dict_group_find0

bb_dict_group_miss9:
  br label %bb_dict_group_done10

bb_dict_group_done10:
  %dict_find_found49 = phi i1 [ false, %bb_dict_group_empty6 ], [ true, %bb_dict_group_match7 ], [ false, %bb_dict_group_miss9 ]
  %dict_find_found_slot50 = phi i64 [ %dict_group_empty_slot48, %bb_dict_group_empty6 ], [ %dict_group_candidate_slot35, %bb_dict_group_match7 ], [ 0, %bb_dict_group_miss9 ]
  br i1 %dict_find_found49, label %bb_dict_put_update11, label %bb_dict_put_insert12

bb_dict_put_update11:
  %dict_entries_offset_mirror51 = add i64 %mutable_capacity4, 23
  %dict_entries_offset52 = and i64 %dict_entries_offset_mirror51, -8
  %dict_entries53 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_entries_offset52
  %dict_offset54 = mul i64 %dict_find_found_slot50, 2
  %dict_key_slot55 = getelementptr i32, ptr %dict_entries53, i64 %dict_offset54
  %dict_value_offset56 = add i64 %dict_offset54, 1
  %dict_value_slot57 = getelementptr i32, ptr %dict_entries53, i64 %dict_value_offset56
  store i32 1, ptr %dict_key_slot55, align 4
  store i32 100, ptr %dict_value_slot57, align 4
  br label %bb_dict_put_done15

bb_dict_put_insert12:
  %dict_next_len58 = add i64 %mutable_len3, 1
  %dict_load_numerator59 = mul i64 %dict_next_len58, 8
  %dict_load_denominator60 = mul i64 %mutable_capacity4, 7
  %dict_should_grow61 = icmp ugt i64 %dict_load_numerator59, %dict_load_denominator60
  br i1 %dict_should_grow61, label %bb_dict_put_insert_grow14, label %bb_dict_put_insert_current13

bb_dict_put_insert_current13:
  %dict_entries_offset_mirror62 = add i64 %mutable_capacity4, 23
  %dict_entries_offset63 = and i64 %dict_entries_offset_mirror62, -8
  %dict_entries64 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_entries_offset63
  %dict_offset65 = mul i64 %dict_find_found_slot50, 2
  %dict_key_slot66 = getelementptr i32, ptr %dict_entries64, i64 %dict_offset65
  %dict_value_offset67 = add i64 %dict_offset65, 1
  %dict_value_slot68 = getelementptr i32, ptr %dict_entries64, i64 %dict_value_offset67
  store i32 1, ptr %dict_key_slot66, align 4
  store i32 100, ptr %dict_value_slot68, align 4
  %dict_control_slot69 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_find_found_slot50
  store i8 %dict_h2_byte13, ptr %dict_control_slot69, align 1
  %dict_control_mirrored70 = icmp ult i64 %dict_find_found_slot50, 16
  br i1 %dict_control_mirrored70, label %bb_dict_control_mirror16, label %bb_dict_control_done17

bb_dict_control_mirror16:
  %dict_control_mirror_index71 = add i64 %mutable_capacity4, %dict_find_found_slot50
  %dict_control_mirror_slot72 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_control_mirror_index71
  store i8 %dict_h2_byte13, ptr %dict_control_mirror_slot72, align 1
  br label %bb_dict_control_done17

bb_dict_control_done17:
  br label %bb_dict_put_done15

bb_dict_put_insert_grow14:
  %dict_has_capacity73 = icmp eq i64 %mutable_capacity4, 0
  %dict_doubled_capacity74 = mul i64 %mutable_capacity4, 2
  %dict_new_capacity75 = select i1 %dict_has_capacity73, i64 4, i64 %dict_doubled_capacity74
  %dict_entries_offset_mirror76 = add i64 %dict_new_capacity75, 23
  %dict_entries_offset77 = and i64 %dict_entries_offset_mirror76, -8
  %dict_entries_bytes78 = mul i64 %dict_new_capacity75, 8
  %dict_bytes79 = add i64 %dict_entries_offset77, %dict_entries_bytes78
  %heap80 = call ptr @sollang_alloc(i64 %dict_bytes79)
  %heap_ok81 = icmp ne ptr %heap80, null
  br i1 %heap_ok81, label %bb_alloc_ok18, label %bb_alloc_fail19

bb_alloc_fail19:
  %trap_stderr82 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr82, ptr @.slg.str.suffix.0, i32 20, ptr %trap_written83, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok18:
  %dict_control_bytes84 = add i64 %dict_new_capacity75, 16
  call void @llvm.memset.p0.i64(ptr %heap80, i8 0, i64 %dict_control_bytes84, i1 false)
  br label %bb_dict_rehash20

bb_dict_rehash20:
  %dict_rehash_i86 = phi i64 [ 0, %bb_alloc_ok18 ], [ %dict_rehash_next_i85, %bb_dict_rehash_next23 ]
  %dict_rehash_active87 = icmp ult i64 %dict_rehash_i86, %mutable_capacity4
  br i1 %dict_rehash_active87, label %bb_dict_rehash_body21, label %bb_dict_rehash_done24

bb_dict_rehash_body21:
  %dict_control_slot88 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_rehash_i86
  %dict_control89 = load i8, ptr %dict_control_slot88, align 1
  %dict_rehash_full90 = icmp ne i8 %dict_control89, 0
  br i1 %dict_rehash_full90, label %bb_dict_rehash_move22, label %bb_dict_rehash_next23

bb_dict_rehash_move22:
  %dict_entries_offset_mirror91 = add i64 %mutable_capacity4, 23
  %dict_entries_offset92 = and i64 %dict_entries_offset_mirror91, -8
  %dict_entries93 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_entries_offset92
  %dict_key_offset94 = mul i64 %dict_rehash_i86, 2
  %dict_key_slot95 = getelementptr i32, ptr %dict_entries93, i64 %dict_key_offset94
  %dict_key96 = load i32, ptr %dict_key_slot95, align 4
  %dict_entries_offset_mirror97 = add i64 %mutable_capacity4, 23
  %dict_entries_offset98 = and i64 %dict_entries_offset_mirror97, -8
  %dict_entries99 = getelementptr i8, ptr %mutable_ptr2, i64 %dict_entries_offset98
  %dict_value_base100 = mul i64 %dict_rehash_i86, 2
  %dict_value_offset101 = add i64 %dict_value_base100, 1
  %dict_value_slot102 = getelementptr i32, ptr %dict_entries99, i64 %dict_value_offset101
  %dict_value103 = load i32, ptr %dict_value_slot102, align 4
  %hash_key104 = sext i32 %dict_key96 to i64
  %hash_high106 = lshr i64 %hash_key104, 32
  %hash_fold105 = xor i64 %hash_key104, %hash_high106
  %hash107 = mul i64 %hash_fold105, -7046029254386353131
  %dict_h2_shifted108 = lshr i64 %hash107, 57
  %dict_h2_raw109 = and i64 %dict_h2_shifted108, 127
  %dict_h2_zero110 = icmp eq i64 %dict_h2_raw109, 0
  %dict_h2111 = select i1 %dict_h2_zero110, i64 1, i64 %dict_h2_raw109
  %dict_h2_byte112 = trunc i64 %dict_h2111 to i8
  %dict_capacity_mask113 = sub i64 %dict_new_capacity75, 1
  %dict_start_slot114 = and i64 %hash107, %dict_capacity_mask113
  br label %bb_dict_group_find25

bb_dict_group_find25:
  %dict_group_probe116 = phi i64 [ 0, %bb_dict_rehash_move22 ], [ %dict_group_next_probe115, %bb_dict_group_next33 ]
  %dict_group_active117 = icmp ult i64 %dict_group_probe116, %dict_new_capacity75
  br i1 %dict_group_active117, label %bb_dict_group_body26, label %bb_dict_group_miss34

bb_dict_group_body26:
  %dict_group_unwrapped118 = add i64 %dict_start_slot114, %dict_group_probe116
  %dict_group_start119 = and i64 %dict_group_unwrapped118, %dict_capacity_mask113
  %dict_group_pointer120 = getelementptr i8, ptr %heap80, i64 %dict_group_start119
  %dict_group_controls121 = load <16 x i8>, ptr %dict_group_pointer120, align 1
  %dict_group_h2_seed122 = insertelement <16 x i8> poison, i8 %dict_h2_byte112, i64 0
  %dict_group_h2_vector123 = shufflevector <16 x i8> %dict_group_h2_seed122, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector124 = icmp eq <16 x i8> %dict_group_controls121, %dict_group_h2_vector123
  %dict_group_match_bits125 = bitcast <16 x i1> %dict_group_matches_vector124 to i16
  %dict_group_empty_vector126 = icmp eq <16 x i8> %dict_group_controls121, zeroinitializer
  %dict_group_empty_bits127 = bitcast <16 x i1> %dict_group_empty_vector126 to i16
  br label %bb_dict_group_candidates27

bb_dict_group_candidates27:
  %dict_group_candidate_bits128 = phi i16 [ %dict_group_match_bits125, %bb_dict_group_body26 ], [ %dict_group_cleared_bits129, %bb_dict_group_candidate_next29 ]
  %dict_group_has_candidate130 = icmp ne i16 %dict_group_candidate_bits128, 0
  br i1 %dict_group_has_candidate130, label %bb_dict_group_candidate_body28, label %bb_dict_group_decision30

bb_dict_group_candidate_body28:
  %dict_group_candidate_offset16131 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits128, i1 false)
  %dict_group_candidate_offset132 = zext i16 %dict_group_candidate_offset16131 to i64
  %dict_group_candidate_unwrapped133 = add i64 %dict_group_start119, %dict_group_candidate_offset132
  %dict_group_candidate_slot134 = and i64 %dict_group_candidate_unwrapped133, %dict_capacity_mask113
  %dict_entries_offset_mirror135 = add i64 %dict_new_capacity75, 23
  %dict_entries_offset136 = and i64 %dict_entries_offset_mirror135, -8
  %dict_entries137 = getelementptr i8, ptr %heap80, i64 %dict_entries_offset136
  %dict_key_offset138 = mul i64 %dict_group_candidate_slot134, 2
  %dict_key_slot139 = getelementptr i32, ptr %dict_entries137, i64 %dict_key_offset138
  %dict_key140 = load i32, ptr %dict_key_slot139, align 4
  %dict_group_key_match141 = icmp eq i32 %dict_key140, %dict_key96
  br i1 %dict_group_key_match141, label %bb_dict_group_match32, label %bb_dict_group_candidate_next29

bb_dict_group_candidate_next29:
  %dict_group_bits_minus_one142 = sub i16 %dict_group_candidate_bits128, 1
  %dict_group_cleared_bits129 = and i16 %dict_group_candidate_bits128, %dict_group_bits_minus_one142
  br label %bb_dict_group_candidates27

bb_dict_group_decision30:
  %dict_group_has_empty143 = icmp ne i16 %dict_group_empty_bits127, 0
  br i1 %dict_group_has_empty143, label %bb_dict_group_empty31, label %bb_dict_group_next33

bb_dict_group_empty31:
  %dict_group_empty_offset16144 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits127, i1 false)
  %dict_group_empty_offset145 = zext i16 %dict_group_empty_offset16144 to i64
  %dict_group_empty_unwrapped146 = add i64 %dict_group_start119, %dict_group_empty_offset145
  %dict_group_empty_slot147 = and i64 %dict_group_empty_unwrapped146, %dict_capacity_mask113
  br label %bb_dict_group_done35

bb_dict_group_match32:
  br label %bb_dict_group_done35

bb_dict_group_next33:
  %dict_group_next_probe115 = add i64 %dict_group_probe116, 16
  br label %bb_dict_group_find25

bb_dict_group_miss34:
  br label %bb_dict_group_done35

bb_dict_group_done35:
  %dict_find_found148 = phi i1 [ false, %bb_dict_group_empty31 ], [ true, %bb_dict_group_match32 ], [ false, %bb_dict_group_miss34 ]
  %dict_find_found_slot149 = phi i64 [ %dict_group_empty_slot147, %bb_dict_group_empty31 ], [ %dict_group_candidate_slot134, %bb_dict_group_match32 ], [ 0, %bb_dict_group_miss34 ]
  %dict_entries_offset_mirror150 = add i64 %dict_new_capacity75, 23
  %dict_entries_offset151 = and i64 %dict_entries_offset_mirror150, -8
  %dict_entries152 = getelementptr i8, ptr %heap80, i64 %dict_entries_offset151
  %dict_offset153 = mul i64 %dict_find_found_slot149, 2
  %dict_key_slot154 = getelementptr i32, ptr %dict_entries152, i64 %dict_offset153
  %dict_value_offset155 = add i64 %dict_offset153, 1
  %dict_value_slot156 = getelementptr i32, ptr %dict_entries152, i64 %dict_value_offset155
  store i32 %dict_key96, ptr %dict_key_slot154, align 4
  store i32 %dict_value103, ptr %dict_value_slot156, align 4
  %dict_control_slot157 = getelementptr i8, ptr %heap80, i64 %dict_find_found_slot149
  store i8 %dict_h2_byte112, ptr %dict_control_slot157, align 1
  %dict_control_mirrored158 = icmp ult i64 %dict_find_found_slot149, 16
  br i1 %dict_control_mirrored158, label %bb_dict_control_mirror36, label %bb_dict_control_done37

bb_dict_control_mirror36:
  %dict_control_mirror_index159 = add i64 %dict_new_capacity75, %dict_find_found_slot149
  %dict_control_mirror_slot160 = getelementptr i8, ptr %heap80, i64 %dict_control_mirror_index159
  store i8 %dict_h2_byte112, ptr %dict_control_mirror_slot160, align 1
  br label %bb_dict_control_done37

bb_dict_control_done37:
  br label %bb_dict_rehash_next23

bb_dict_rehash_next23:
  %dict_rehash_next_i85 = add i64 %dict_rehash_i86, 1
  br label %bb_dict_rehash20

bb_dict_rehash_done24:
  call void @sollang_free(ptr %mutable_ptr2)
  %hash_key161 = sext i32 1 to i64
  %hash_high163 = lshr i64 %hash_key161, 32
  %hash_fold162 = xor i64 %hash_key161, %hash_high163
  %hash164 = mul i64 %hash_fold162, -7046029254386353131
  %dict_h2_shifted165 = lshr i64 %hash164, 57
  %dict_h2_raw166 = and i64 %dict_h2_shifted165, 127
  %dict_h2_zero167 = icmp eq i64 %dict_h2_raw166, 0
  %dict_h2168 = select i1 %dict_h2_zero167, i64 1, i64 %dict_h2_raw166
  %dict_h2_byte169 = trunc i64 %dict_h2168 to i8
  %dict_capacity_mask170 = sub i64 %dict_new_capacity75, 1
  %dict_start_slot171 = and i64 %hash164, %dict_capacity_mask170
  br label %bb_dict_group_find38

bb_dict_group_find38:
  %dict_group_probe173 = phi i64 [ 0, %bb_dict_rehash_done24 ], [ %dict_group_next_probe172, %bb_dict_group_next46 ]
  %dict_group_active174 = icmp ult i64 %dict_group_probe173, %dict_new_capacity75
  br i1 %dict_group_active174, label %bb_dict_group_body39, label %bb_dict_group_miss47

bb_dict_group_body39:
  %dict_group_unwrapped175 = add i64 %dict_start_slot171, %dict_group_probe173
  %dict_group_start176 = and i64 %dict_group_unwrapped175, %dict_capacity_mask170
  %dict_group_pointer177 = getelementptr i8, ptr %heap80, i64 %dict_group_start176
  %dict_group_controls178 = load <16 x i8>, ptr %dict_group_pointer177, align 1
  %dict_group_h2_seed179 = insertelement <16 x i8> poison, i8 %dict_h2_byte169, i64 0
  %dict_group_h2_vector180 = shufflevector <16 x i8> %dict_group_h2_seed179, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector181 = icmp eq <16 x i8> %dict_group_controls178, %dict_group_h2_vector180
  %dict_group_match_bits182 = bitcast <16 x i1> %dict_group_matches_vector181 to i16
  %dict_group_empty_vector183 = icmp eq <16 x i8> %dict_group_controls178, zeroinitializer
  %dict_group_empty_bits184 = bitcast <16 x i1> %dict_group_empty_vector183 to i16
  br label %bb_dict_group_candidates40

bb_dict_group_candidates40:
  %dict_group_candidate_bits185 = phi i16 [ %dict_group_match_bits182, %bb_dict_group_body39 ], [ %dict_group_cleared_bits186, %bb_dict_group_candidate_next42 ]
  %dict_group_has_candidate187 = icmp ne i16 %dict_group_candidate_bits185, 0
  br i1 %dict_group_has_candidate187, label %bb_dict_group_candidate_body41, label %bb_dict_group_decision43

bb_dict_group_candidate_body41:
  %dict_group_candidate_offset16188 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits185, i1 false)
  %dict_group_candidate_offset189 = zext i16 %dict_group_candidate_offset16188 to i64
  %dict_group_candidate_unwrapped190 = add i64 %dict_group_start176, %dict_group_candidate_offset189
  %dict_group_candidate_slot191 = and i64 %dict_group_candidate_unwrapped190, %dict_capacity_mask170
  %dict_entries_offset_mirror192 = add i64 %dict_new_capacity75, 23
  %dict_entries_offset193 = and i64 %dict_entries_offset_mirror192, -8
  %dict_entries194 = getelementptr i8, ptr %heap80, i64 %dict_entries_offset193
  %dict_key_offset195 = mul i64 %dict_group_candidate_slot191, 2
  %dict_key_slot196 = getelementptr i32, ptr %dict_entries194, i64 %dict_key_offset195
  %dict_key197 = load i32, ptr %dict_key_slot196, align 4
  %dict_group_key_match198 = icmp eq i32 %dict_key197, 1
  br i1 %dict_group_key_match198, label %bb_dict_group_match45, label %bb_dict_group_candidate_next42

bb_dict_group_candidate_next42:
  %dict_group_bits_minus_one199 = sub i16 %dict_group_candidate_bits185, 1
  %dict_group_cleared_bits186 = and i16 %dict_group_candidate_bits185, %dict_group_bits_minus_one199
  br label %bb_dict_group_candidates40

bb_dict_group_decision43:
  %dict_group_has_empty200 = icmp ne i16 %dict_group_empty_bits184, 0
  br i1 %dict_group_has_empty200, label %bb_dict_group_empty44, label %bb_dict_group_next46

bb_dict_group_empty44:
  %dict_group_empty_offset16201 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits184, i1 false)
  %dict_group_empty_offset202 = zext i16 %dict_group_empty_offset16201 to i64
  %dict_group_empty_unwrapped203 = add i64 %dict_group_start176, %dict_group_empty_offset202
  %dict_group_empty_slot204 = and i64 %dict_group_empty_unwrapped203, %dict_capacity_mask170
  br label %bb_dict_group_done48

bb_dict_group_match45:
  br label %bb_dict_group_done48

bb_dict_group_next46:
  %dict_group_next_probe172 = add i64 %dict_group_probe173, 16
  br label %bb_dict_group_find38

bb_dict_group_miss47:
  br label %bb_dict_group_done48

bb_dict_group_done48:
  %dict_find_found205 = phi i1 [ false, %bb_dict_group_empty44 ], [ true, %bb_dict_group_match45 ], [ false, %bb_dict_group_miss47 ]
  %dict_find_found_slot206 = phi i64 [ %dict_group_empty_slot204, %bb_dict_group_empty44 ], [ %dict_group_candidate_slot191, %bb_dict_group_match45 ], [ 0, %bb_dict_group_miss47 ]
  %dict_entries_offset_mirror207 = add i64 %dict_new_capacity75, 23
  %dict_entries_offset208 = and i64 %dict_entries_offset_mirror207, -8
  %dict_entries209 = getelementptr i8, ptr %heap80, i64 %dict_entries_offset208
  %dict_offset210 = mul i64 %dict_find_found_slot206, 2
  %dict_key_slot211 = getelementptr i32, ptr %dict_entries209, i64 %dict_offset210
  %dict_value_offset212 = add i64 %dict_offset210, 1
  %dict_value_slot213 = getelementptr i32, ptr %dict_entries209, i64 %dict_value_offset212
  store i32 1, ptr %dict_key_slot211, align 4
  store i32 100, ptr %dict_value_slot213, align 4
  %dict_control_slot214 = getelementptr i8, ptr %heap80, i64 %dict_find_found_slot206
  store i8 %dict_h2_byte169, ptr %dict_control_slot214, align 1
  %dict_control_mirrored215 = icmp ult i64 %dict_find_found_slot206, 16
  br i1 %dict_control_mirrored215, label %bb_dict_control_mirror49, label %bb_dict_control_done50

bb_dict_control_mirror49:
  %dict_control_mirror_index216 = add i64 %dict_new_capacity75, %dict_find_found_slot206
  %dict_control_mirror_slot217 = getelementptr i8, ptr %heap80, i64 %dict_control_mirror_index216
  store i8 %dict_h2_byte169, ptr %dict_control_mirror_slot217, align 1
  br label %bb_dict_control_done50

bb_dict_control_done50:
  br label %bb_dict_put_done15

bb_dict_put_done15:
  %dict_ptr218 = phi ptr [ %mutable_ptr2, %bb_dict_put_update11 ], [ %mutable_ptr2, %bb_dict_control_done17 ], [ %heap80, %bb_dict_control_done50 ]
  %dict_len219 = phi i64 [ %mutable_len3, %bb_dict_put_update11 ], [ %dict_next_len58, %bb_dict_control_done17 ], [ %dict_next_len58, %bb_dict_control_done50 ]
  %dict_capacity220 = phi i64 [ %mutable_capacity4, %bb_dict_put_update11 ], [ %mutable_capacity4, %bb_dict_control_done17 ], [ %dict_new_capacity75, %bb_dict_control_done50 ]
  store ptr %dict_ptr218, ptr %stack_slot0, align 8
  store i64 %dict_len219, ptr %mutable_len_addr0, align 8
  store i64 %dict_capacity220, ptr %mutable_capacity_addr1, align 8
  %mutable_ptr221 = load ptr, ptr %stack_slot0, align 8
  %mutable_len222 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity223 = load i64, ptr %mutable_capacity_addr1, align 8
  %hash_key224 = sext i32 2 to i64
  %hash_high226 = lshr i64 %hash_key224, 32
  %hash_fold225 = xor i64 %hash_key224, %hash_high226
  %hash227 = mul i64 %hash_fold225, -7046029254386353131
  %dict_h2_shifted228 = lshr i64 %hash227, 57
  %dict_h2_raw229 = and i64 %dict_h2_shifted228, 127
  %dict_h2_zero230 = icmp eq i64 %dict_h2_raw229, 0
  %dict_h2231 = select i1 %dict_h2_zero230, i64 1, i64 %dict_h2_raw229
  %dict_h2_byte232 = trunc i64 %dict_h2231 to i8
  %dict_capacity_mask233 = sub i64 %mutable_capacity223, 1
  %dict_start_slot234 = and i64 %hash227, %dict_capacity_mask233
  br label %bb_dict_group_find51

bb_dict_group_find51:
  %dict_group_probe236 = phi i64 [ 0, %bb_dict_put_done15 ], [ %dict_group_next_probe235, %bb_dict_group_next59 ]
  %dict_group_active237 = icmp ult i64 %dict_group_probe236, %mutable_capacity223
  br i1 %dict_group_active237, label %bb_dict_group_body52, label %bb_dict_group_miss60

bb_dict_group_body52:
  %dict_group_unwrapped238 = add i64 %dict_start_slot234, %dict_group_probe236
  %dict_group_start239 = and i64 %dict_group_unwrapped238, %dict_capacity_mask233
  %dict_group_pointer240 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_group_start239
  %dict_group_controls241 = load <16 x i8>, ptr %dict_group_pointer240, align 1
  %dict_group_h2_seed242 = insertelement <16 x i8> poison, i8 %dict_h2_byte232, i64 0
  %dict_group_h2_vector243 = shufflevector <16 x i8> %dict_group_h2_seed242, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector244 = icmp eq <16 x i8> %dict_group_controls241, %dict_group_h2_vector243
  %dict_group_match_bits245 = bitcast <16 x i1> %dict_group_matches_vector244 to i16
  %dict_group_empty_vector246 = icmp eq <16 x i8> %dict_group_controls241, zeroinitializer
  %dict_group_empty_bits247 = bitcast <16 x i1> %dict_group_empty_vector246 to i16
  br label %bb_dict_group_candidates53

bb_dict_group_candidates53:
  %dict_group_candidate_bits248 = phi i16 [ %dict_group_match_bits245, %bb_dict_group_body52 ], [ %dict_group_cleared_bits249, %bb_dict_group_candidate_next55 ]
  %dict_group_has_candidate250 = icmp ne i16 %dict_group_candidate_bits248, 0
  br i1 %dict_group_has_candidate250, label %bb_dict_group_candidate_body54, label %bb_dict_group_decision56

bb_dict_group_candidate_body54:
  %dict_group_candidate_offset16251 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits248, i1 false)
  %dict_group_candidate_offset252 = zext i16 %dict_group_candidate_offset16251 to i64
  %dict_group_candidate_unwrapped253 = add i64 %dict_group_start239, %dict_group_candidate_offset252
  %dict_group_candidate_slot254 = and i64 %dict_group_candidate_unwrapped253, %dict_capacity_mask233
  %dict_entries_offset_mirror255 = add i64 %mutable_capacity223, 23
  %dict_entries_offset256 = and i64 %dict_entries_offset_mirror255, -8
  %dict_entries257 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_entries_offset256
  %dict_key_offset258 = mul i64 %dict_group_candidate_slot254, 2
  %dict_key_slot259 = getelementptr i32, ptr %dict_entries257, i64 %dict_key_offset258
  %dict_key260 = load i32, ptr %dict_key_slot259, align 4
  %dict_group_key_match261 = icmp eq i32 %dict_key260, 2
  br i1 %dict_group_key_match261, label %bb_dict_group_match58, label %bb_dict_group_candidate_next55

bb_dict_group_candidate_next55:
  %dict_group_bits_minus_one262 = sub i16 %dict_group_candidate_bits248, 1
  %dict_group_cleared_bits249 = and i16 %dict_group_candidate_bits248, %dict_group_bits_minus_one262
  br label %bb_dict_group_candidates53

bb_dict_group_decision56:
  %dict_group_has_empty263 = icmp ne i16 %dict_group_empty_bits247, 0
  br i1 %dict_group_has_empty263, label %bb_dict_group_empty57, label %bb_dict_group_next59

bb_dict_group_empty57:
  %dict_group_empty_offset16264 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits247, i1 false)
  %dict_group_empty_offset265 = zext i16 %dict_group_empty_offset16264 to i64
  %dict_group_empty_unwrapped266 = add i64 %dict_group_start239, %dict_group_empty_offset265
  %dict_group_empty_slot267 = and i64 %dict_group_empty_unwrapped266, %dict_capacity_mask233
  br label %bb_dict_group_done61

bb_dict_group_match58:
  br label %bb_dict_group_done61

bb_dict_group_next59:
  %dict_group_next_probe235 = add i64 %dict_group_probe236, 16
  br label %bb_dict_group_find51

bb_dict_group_miss60:
  br label %bb_dict_group_done61

bb_dict_group_done61:
  %dict_find_found268 = phi i1 [ false, %bb_dict_group_empty57 ], [ true, %bb_dict_group_match58 ], [ false, %bb_dict_group_miss60 ]
  %dict_find_found_slot269 = phi i64 [ %dict_group_empty_slot267, %bb_dict_group_empty57 ], [ %dict_group_candidate_slot254, %bb_dict_group_match58 ], [ 0, %bb_dict_group_miss60 ]
  br i1 %dict_find_found268, label %bb_dict_put_update62, label %bb_dict_put_insert63

bb_dict_put_update62:
  %dict_entries_offset_mirror270 = add i64 %mutable_capacity223, 23
  %dict_entries_offset271 = and i64 %dict_entries_offset_mirror270, -8
  %dict_entries272 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_entries_offset271
  %dict_offset273 = mul i64 %dict_find_found_slot269, 2
  %dict_key_slot274 = getelementptr i32, ptr %dict_entries272, i64 %dict_offset273
  %dict_value_offset275 = add i64 %dict_offset273, 1
  %dict_value_slot276 = getelementptr i32, ptr %dict_entries272, i64 %dict_value_offset275
  store i32 2, ptr %dict_key_slot274, align 4
  store i32 200, ptr %dict_value_slot276, align 4
  br label %bb_dict_put_done66

bb_dict_put_insert63:
  %dict_next_len277 = add i64 %mutable_len222, 1
  %dict_load_numerator278 = mul i64 %dict_next_len277, 8
  %dict_load_denominator279 = mul i64 %mutable_capacity223, 7
  %dict_should_grow280 = icmp ugt i64 %dict_load_numerator278, %dict_load_denominator279
  br i1 %dict_should_grow280, label %bb_dict_put_insert_grow65, label %bb_dict_put_insert_current64

bb_dict_put_insert_current64:
  %dict_entries_offset_mirror281 = add i64 %mutable_capacity223, 23
  %dict_entries_offset282 = and i64 %dict_entries_offset_mirror281, -8
  %dict_entries283 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_entries_offset282
  %dict_offset284 = mul i64 %dict_find_found_slot269, 2
  %dict_key_slot285 = getelementptr i32, ptr %dict_entries283, i64 %dict_offset284
  %dict_value_offset286 = add i64 %dict_offset284, 1
  %dict_value_slot287 = getelementptr i32, ptr %dict_entries283, i64 %dict_value_offset286
  store i32 2, ptr %dict_key_slot285, align 4
  store i32 200, ptr %dict_value_slot287, align 4
  %dict_control_slot288 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_find_found_slot269
  store i8 %dict_h2_byte232, ptr %dict_control_slot288, align 1
  %dict_control_mirrored289 = icmp ult i64 %dict_find_found_slot269, 16
  br i1 %dict_control_mirrored289, label %bb_dict_control_mirror67, label %bb_dict_control_done68

bb_dict_control_mirror67:
  %dict_control_mirror_index290 = add i64 %mutable_capacity223, %dict_find_found_slot269
  %dict_control_mirror_slot291 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_control_mirror_index290
  store i8 %dict_h2_byte232, ptr %dict_control_mirror_slot291, align 1
  br label %bb_dict_control_done68

bb_dict_control_done68:
  br label %bb_dict_put_done66

bb_dict_put_insert_grow65:
  %dict_has_capacity292 = icmp eq i64 %mutable_capacity223, 0
  %dict_doubled_capacity293 = mul i64 %mutable_capacity223, 2
  %dict_new_capacity294 = select i1 %dict_has_capacity292, i64 4, i64 %dict_doubled_capacity293
  %dict_entries_offset_mirror295 = add i64 %dict_new_capacity294, 23
  %dict_entries_offset296 = and i64 %dict_entries_offset_mirror295, -8
  %dict_entries_bytes297 = mul i64 %dict_new_capacity294, 8
  %dict_bytes298 = add i64 %dict_entries_offset296, %dict_entries_bytes297
  %heap299 = call ptr @sollang_alloc(i64 %dict_bytes298)
  %heap_ok300 = icmp ne ptr %heap299, null
  br i1 %heap_ok300, label %bb_alloc_ok69, label %bb_alloc_fail70

bb_alloc_fail70:
  %trap_stderr301 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr301, ptr @.slg.str.suffix.1, i32 20, ptr %trap_written302, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok69:
  %dict_control_bytes303 = add i64 %dict_new_capacity294, 16
  call void @llvm.memset.p0.i64(ptr %heap299, i8 0, i64 %dict_control_bytes303, i1 false)
  br label %bb_dict_rehash71

bb_dict_rehash71:
  %dict_rehash_i305 = phi i64 [ 0, %bb_alloc_ok69 ], [ %dict_rehash_next_i304, %bb_dict_rehash_next74 ]
  %dict_rehash_active306 = icmp ult i64 %dict_rehash_i305, %mutable_capacity223
  br i1 %dict_rehash_active306, label %bb_dict_rehash_body72, label %bb_dict_rehash_done75

bb_dict_rehash_body72:
  %dict_control_slot307 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_rehash_i305
  %dict_control308 = load i8, ptr %dict_control_slot307, align 1
  %dict_rehash_full309 = icmp ne i8 %dict_control308, 0
  br i1 %dict_rehash_full309, label %bb_dict_rehash_move73, label %bb_dict_rehash_next74

bb_dict_rehash_move73:
  %dict_entries_offset_mirror310 = add i64 %mutable_capacity223, 23
  %dict_entries_offset311 = and i64 %dict_entries_offset_mirror310, -8
  %dict_entries312 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_entries_offset311
  %dict_key_offset313 = mul i64 %dict_rehash_i305, 2
  %dict_key_slot314 = getelementptr i32, ptr %dict_entries312, i64 %dict_key_offset313
  %dict_key315 = load i32, ptr %dict_key_slot314, align 4
  %dict_entries_offset_mirror316 = add i64 %mutable_capacity223, 23
  %dict_entries_offset317 = and i64 %dict_entries_offset_mirror316, -8
  %dict_entries318 = getelementptr i8, ptr %mutable_ptr221, i64 %dict_entries_offset317
  %dict_value_base319 = mul i64 %dict_rehash_i305, 2
  %dict_value_offset320 = add i64 %dict_value_base319, 1
  %dict_value_slot321 = getelementptr i32, ptr %dict_entries318, i64 %dict_value_offset320
  %dict_value322 = load i32, ptr %dict_value_slot321, align 4
  %hash_key323 = sext i32 %dict_key315 to i64
  %hash_high325 = lshr i64 %hash_key323, 32
  %hash_fold324 = xor i64 %hash_key323, %hash_high325
  %hash326 = mul i64 %hash_fold324, -7046029254386353131
  %dict_h2_shifted327 = lshr i64 %hash326, 57
  %dict_h2_raw328 = and i64 %dict_h2_shifted327, 127
  %dict_h2_zero329 = icmp eq i64 %dict_h2_raw328, 0
  %dict_h2330 = select i1 %dict_h2_zero329, i64 1, i64 %dict_h2_raw328
  %dict_h2_byte331 = trunc i64 %dict_h2330 to i8
  %dict_capacity_mask332 = sub i64 %dict_new_capacity294, 1
  %dict_start_slot333 = and i64 %hash326, %dict_capacity_mask332
  br label %bb_dict_group_find76

bb_dict_group_find76:
  %dict_group_probe335 = phi i64 [ 0, %bb_dict_rehash_move73 ], [ %dict_group_next_probe334, %bb_dict_group_next84 ]
  %dict_group_active336 = icmp ult i64 %dict_group_probe335, %dict_new_capacity294
  br i1 %dict_group_active336, label %bb_dict_group_body77, label %bb_dict_group_miss85

bb_dict_group_body77:
  %dict_group_unwrapped337 = add i64 %dict_start_slot333, %dict_group_probe335
  %dict_group_start338 = and i64 %dict_group_unwrapped337, %dict_capacity_mask332
  %dict_group_pointer339 = getelementptr i8, ptr %heap299, i64 %dict_group_start338
  %dict_group_controls340 = load <16 x i8>, ptr %dict_group_pointer339, align 1
  %dict_group_h2_seed341 = insertelement <16 x i8> poison, i8 %dict_h2_byte331, i64 0
  %dict_group_h2_vector342 = shufflevector <16 x i8> %dict_group_h2_seed341, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector343 = icmp eq <16 x i8> %dict_group_controls340, %dict_group_h2_vector342
  %dict_group_match_bits344 = bitcast <16 x i1> %dict_group_matches_vector343 to i16
  %dict_group_empty_vector345 = icmp eq <16 x i8> %dict_group_controls340, zeroinitializer
  %dict_group_empty_bits346 = bitcast <16 x i1> %dict_group_empty_vector345 to i16
  br label %bb_dict_group_candidates78

bb_dict_group_candidates78:
  %dict_group_candidate_bits347 = phi i16 [ %dict_group_match_bits344, %bb_dict_group_body77 ], [ %dict_group_cleared_bits348, %bb_dict_group_candidate_next80 ]
  %dict_group_has_candidate349 = icmp ne i16 %dict_group_candidate_bits347, 0
  br i1 %dict_group_has_candidate349, label %bb_dict_group_candidate_body79, label %bb_dict_group_decision81

bb_dict_group_candidate_body79:
  %dict_group_candidate_offset16350 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits347, i1 false)
  %dict_group_candidate_offset351 = zext i16 %dict_group_candidate_offset16350 to i64
  %dict_group_candidate_unwrapped352 = add i64 %dict_group_start338, %dict_group_candidate_offset351
  %dict_group_candidate_slot353 = and i64 %dict_group_candidate_unwrapped352, %dict_capacity_mask332
  %dict_entries_offset_mirror354 = add i64 %dict_new_capacity294, 23
  %dict_entries_offset355 = and i64 %dict_entries_offset_mirror354, -8
  %dict_entries356 = getelementptr i8, ptr %heap299, i64 %dict_entries_offset355
  %dict_key_offset357 = mul i64 %dict_group_candidate_slot353, 2
  %dict_key_slot358 = getelementptr i32, ptr %dict_entries356, i64 %dict_key_offset357
  %dict_key359 = load i32, ptr %dict_key_slot358, align 4
  %dict_group_key_match360 = icmp eq i32 %dict_key359, %dict_key315
  br i1 %dict_group_key_match360, label %bb_dict_group_match83, label %bb_dict_group_candidate_next80

bb_dict_group_candidate_next80:
  %dict_group_bits_minus_one361 = sub i16 %dict_group_candidate_bits347, 1
  %dict_group_cleared_bits348 = and i16 %dict_group_candidate_bits347, %dict_group_bits_minus_one361
  br label %bb_dict_group_candidates78

bb_dict_group_decision81:
  %dict_group_has_empty362 = icmp ne i16 %dict_group_empty_bits346, 0
  br i1 %dict_group_has_empty362, label %bb_dict_group_empty82, label %bb_dict_group_next84

bb_dict_group_empty82:
  %dict_group_empty_offset16363 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits346, i1 false)
  %dict_group_empty_offset364 = zext i16 %dict_group_empty_offset16363 to i64
  %dict_group_empty_unwrapped365 = add i64 %dict_group_start338, %dict_group_empty_offset364
  %dict_group_empty_slot366 = and i64 %dict_group_empty_unwrapped365, %dict_capacity_mask332
  br label %bb_dict_group_done86

bb_dict_group_match83:
  br label %bb_dict_group_done86

bb_dict_group_next84:
  %dict_group_next_probe334 = add i64 %dict_group_probe335, 16
  br label %bb_dict_group_find76

bb_dict_group_miss85:
  br label %bb_dict_group_done86

bb_dict_group_done86:
  %dict_find_found367 = phi i1 [ false, %bb_dict_group_empty82 ], [ true, %bb_dict_group_match83 ], [ false, %bb_dict_group_miss85 ]
  %dict_find_found_slot368 = phi i64 [ %dict_group_empty_slot366, %bb_dict_group_empty82 ], [ %dict_group_candidate_slot353, %bb_dict_group_match83 ], [ 0, %bb_dict_group_miss85 ]
  %dict_entries_offset_mirror369 = add i64 %dict_new_capacity294, 23
  %dict_entries_offset370 = and i64 %dict_entries_offset_mirror369, -8
  %dict_entries371 = getelementptr i8, ptr %heap299, i64 %dict_entries_offset370
  %dict_offset372 = mul i64 %dict_find_found_slot368, 2
  %dict_key_slot373 = getelementptr i32, ptr %dict_entries371, i64 %dict_offset372
  %dict_value_offset374 = add i64 %dict_offset372, 1
  %dict_value_slot375 = getelementptr i32, ptr %dict_entries371, i64 %dict_value_offset374
  store i32 %dict_key315, ptr %dict_key_slot373, align 4
  store i32 %dict_value322, ptr %dict_value_slot375, align 4
  %dict_control_slot376 = getelementptr i8, ptr %heap299, i64 %dict_find_found_slot368
  store i8 %dict_h2_byte331, ptr %dict_control_slot376, align 1
  %dict_control_mirrored377 = icmp ult i64 %dict_find_found_slot368, 16
  br i1 %dict_control_mirrored377, label %bb_dict_control_mirror87, label %bb_dict_control_done88

bb_dict_control_mirror87:
  %dict_control_mirror_index378 = add i64 %dict_new_capacity294, %dict_find_found_slot368
  %dict_control_mirror_slot379 = getelementptr i8, ptr %heap299, i64 %dict_control_mirror_index378
  store i8 %dict_h2_byte331, ptr %dict_control_mirror_slot379, align 1
  br label %bb_dict_control_done88

bb_dict_control_done88:
  br label %bb_dict_rehash_next74

bb_dict_rehash_next74:
  %dict_rehash_next_i304 = add i64 %dict_rehash_i305, 1
  br label %bb_dict_rehash71

bb_dict_rehash_done75:
  call void @sollang_free(ptr %mutable_ptr221)
  %hash_key380 = sext i32 2 to i64
  %hash_high382 = lshr i64 %hash_key380, 32
  %hash_fold381 = xor i64 %hash_key380, %hash_high382
  %hash383 = mul i64 %hash_fold381, -7046029254386353131
  %dict_h2_shifted384 = lshr i64 %hash383, 57
  %dict_h2_raw385 = and i64 %dict_h2_shifted384, 127
  %dict_h2_zero386 = icmp eq i64 %dict_h2_raw385, 0
  %dict_h2387 = select i1 %dict_h2_zero386, i64 1, i64 %dict_h2_raw385
  %dict_h2_byte388 = trunc i64 %dict_h2387 to i8
  %dict_capacity_mask389 = sub i64 %dict_new_capacity294, 1
  %dict_start_slot390 = and i64 %hash383, %dict_capacity_mask389
  br label %bb_dict_group_find89

bb_dict_group_find89:
  %dict_group_probe392 = phi i64 [ 0, %bb_dict_rehash_done75 ], [ %dict_group_next_probe391, %bb_dict_group_next97 ]
  %dict_group_active393 = icmp ult i64 %dict_group_probe392, %dict_new_capacity294
  br i1 %dict_group_active393, label %bb_dict_group_body90, label %bb_dict_group_miss98

bb_dict_group_body90:
  %dict_group_unwrapped394 = add i64 %dict_start_slot390, %dict_group_probe392
  %dict_group_start395 = and i64 %dict_group_unwrapped394, %dict_capacity_mask389
  %dict_group_pointer396 = getelementptr i8, ptr %heap299, i64 %dict_group_start395
  %dict_group_controls397 = load <16 x i8>, ptr %dict_group_pointer396, align 1
  %dict_group_h2_seed398 = insertelement <16 x i8> poison, i8 %dict_h2_byte388, i64 0
  %dict_group_h2_vector399 = shufflevector <16 x i8> %dict_group_h2_seed398, <16 x i8> poison, <16 x i32> zeroinitializer
  %dict_group_matches_vector400 = icmp eq <16 x i8> %dict_group_controls397, %dict_group_h2_vector399
  %dict_group_match_bits401 = bitcast <16 x i1> %dict_group_matches_vector400 to i16
  %dict_group_empty_vector402 = icmp eq <16 x i8> %dict_group_controls397, zeroinitializer
  %dict_group_empty_bits403 = bitcast <16 x i1> %dict_group_empty_vector402 to i16
  br label %bb_dict_group_candidates91

bb_dict_group_candidates91:
  %dict_group_candidate_bits404 = phi i16 [ %dict_group_match_bits401, %bb_dict_group_body90 ], [ %dict_group_cleared_bits405, %bb_dict_group_candidate_next93 ]
  %dict_group_has_candidate406 = icmp ne i16 %dict_group_candidate_bits404, 0
  br i1 %dict_group_has_candidate406, label %bb_dict_group_candidate_body92, label %bb_dict_group_decision94

bb_dict_group_candidate_body92:
  %dict_group_candidate_offset16407 = call i16 @llvm.cttz.i16(i16 %dict_group_candidate_bits404, i1 false)
  %dict_group_candidate_offset408 = zext i16 %dict_group_candidate_offset16407 to i64
  %dict_group_candidate_unwrapped409 = add i64 %dict_group_start395, %dict_group_candidate_offset408
  %dict_group_candidate_slot410 = and i64 %dict_group_candidate_unwrapped409, %dict_capacity_mask389
  %dict_entries_offset_mirror411 = add i64 %dict_new_capacity294, 23
  %dict_entries_offset412 = and i64 %dict_entries_offset_mirror411, -8
  %dict_entries413 = getelementptr i8, ptr %heap299, i64 %dict_entries_offset412
  %dict_key_offset414 = mul i64 %dict_group_candidate_slot410, 2
  %dict_key_slot415 = getelementptr i32, ptr %dict_entries413, i64 %dict_key_offset414
  %dict_key416 = load i32, ptr %dict_key_slot415, align 4
  %dict_group_key_match417 = icmp eq i32 %dict_key416, 2
  br i1 %dict_group_key_match417, label %bb_dict_group_match96, label %bb_dict_group_candidate_next93

bb_dict_group_candidate_next93:
  %dict_group_bits_minus_one418 = sub i16 %dict_group_candidate_bits404, 1
  %dict_group_cleared_bits405 = and i16 %dict_group_candidate_bits404, %dict_group_bits_minus_one418
  br label %bb_dict_group_candidates91

bb_dict_group_decision94:
  %dict_group_has_empty419 = icmp ne i16 %dict_group_empty_bits403, 0
  br i1 %dict_group_has_empty419, label %bb_dict_group_empty95, label %bb_dict_group_next97

bb_dict_group_empty95:
  %dict_group_empty_offset16420 = call i16 @llvm.cttz.i16(i16 %dict_group_empty_bits403, i1 false)
  %dict_group_empty_offset421 = zext i16 %dict_group_empty_offset16420 to i64
  %dict_group_empty_unwrapped422 = add i64 %dict_group_start395, %dict_group_empty_offset421
  %dict_group_empty_slot423 = and i64 %dict_group_empty_unwrapped422, %dict_capacity_mask389
  br label %bb_dict_group_done99

bb_dict_group_match96:
  br label %bb_dict_group_done99

bb_dict_group_next97:
  %dict_group_next_probe391 = add i64 %dict_group_probe392, 16
  br label %bb_dict_group_find89

bb_dict_group_miss98:
  br label %bb_dict_group_done99

bb_dict_group_done99:
  %dict_find_found424 = phi i1 [ false, %bb_dict_group_empty95 ], [ true, %bb_dict_group_match96 ], [ false, %bb_dict_group_miss98 ]
  %dict_find_found_slot425 = phi i64 [ %dict_group_empty_slot423, %bb_dict_group_empty95 ], [ %dict_group_candidate_slot410, %bb_dict_group_match96 ], [ 0, %bb_dict_group_miss98 ]
  %dict_entries_offset_mirror426 = add i64 %dict_new_capacity294, 23
  %dict_entries_offset427 = and i64 %dict_entries_offset_mirror426, -8
  %dict_entries428 = getelementptr i8, ptr %heap299, i64 %dict_entries_offset427
  %dict_offset429 = mul i64 %dict_find_found_slot425, 2
  %dict_key_slot430 = getelementptr i32, ptr %dict_entries428, i64 %dict_offset429
  %dict_value_offset431 = add i64 %dict_offset429, 1
  %dict_value_slot432 = getelementptr i32, ptr %dict_entries428, i64 %dict_value_offset431
  store i32 2, ptr %dict_key_slot430, align 4
  store i32 200, ptr %dict_value_slot432, align 4
  %dict_control_slot433 = getelementptr i8, ptr %heap299, i64 %dict_find_found_slot425
  store i8 %dict_h2_byte388, ptr %dict_control_slot433, align 1
  %dict_control_mirrored434 = icmp ult i64 %dict_find_found_slot425, 16
  br i1 %dict_control_mirrored434, label %bb_dict_control_mirror100, label %bb_dict_control_done101

bb_dict_control_mirror100:
  %dict_control_mirror_index435 = add i64 %dict_new_capacity294, %dict_find_found_slot425
  %dict_control_mirror_slot436 = getelementptr i8, ptr %heap299, i64 %dict_control_mirror_index435
  store i8 %dict_h2_byte388, ptr %dict_control_mirror_slot436, align 1
  br label %bb_dict_control_done101

bb_dict_control_done101:
  br label %bb_dict_put_done66

bb_dict_put_done66:
  %dict_ptr437 = phi ptr [ %mutable_ptr221, %bb_dict_put_update62 ], [ %mutable_ptr221, %bb_dict_control_done68 ], [ %heap299, %bb_dict_control_done101 ]
  %dict_len438 = phi i64 [ %mutable_len222, %bb_dict_put_update62 ], [ %dict_next_len277, %bb_dict_control_done68 ], [ %dict_next_len277, %bb_dict_control_done101 ]
  %dict_capacity439 = phi i64 [ %mutable_capacity223, %bb_dict_put_update62 ], [ %mutable_capacity223, %bb_dict_control_done68 ], [ %dict_new_capacity294, %bb_dict_control_done101 ]
  store ptr %dict_ptr437, ptr %stack_slot0, align 8
  store i64 %dict_len438, ptr %mutable_len_addr0, align 8
  store i64 %dict_capacity439, ptr %mutable_capacity_addr1, align 8
  %mutable_ptr440 = load ptr, ptr %stack_slot0, align 8
  %mutable_len441 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity442 = load i64, ptr %mutable_capacity_addr1, align 8
  %mutable_ptr443 = load ptr, ptr %stack_slot0, align 8
  %mutable_len444 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity445 = load i64, ptr %mutable_capacity_addr1, align 8
  %mutable_arg446 = insertvalue %sollang.mutable_container poison, ptr %stack_slot0, 0
  %mutable_arg447 = insertvalue %sollang.mutable_container %mutable_arg446, ptr %mutable_len_addr0, 1
  %mutable_arg448 = insertvalue %sollang.mutable_container %mutable_arg447, ptr %mutable_capacity_addr1, 2
  call void @sollang_fn_addScores(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.mutable_container %mutable_arg448)
  %mutable_ptr449 = load ptr, ptr %stack_slot0, align 8
  %mutable_len450 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity451 = load i64, ptr %mutable_capacity_addr1, align 8
  %mutable_arg452 = insertvalue %sollang.mutable_container poison, ptr %stack_slot0, 0
  %mutable_arg453 = insertvalue %sollang.mutable_container %mutable_arg452, ptr %mutable_len_addr0, 1
  %mutable_arg454 = insertvalue %sollang.mutable_container %mutable_arg453, ptr %mutable_capacity_addr1, 2
  call void @sollang_fn_replaceFirst(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.mutable_container %mutable_arg454)
  %mutable_ptr455 = load ptr, ptr %stack_slot0, align 8
  %mutable_len456 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity457 = load i64, ptr %mutable_capacity_addr1, align 8
  %dict_len_value458 = trunc i64 %mutable_len456 to i32
  %mutable_ptr459 = load ptr, ptr %stack_slot0, align 8
  %mutable_len460 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity461 = load i64, ptr %mutable_capacity_addr1, align 8
  %index_size462 = sext i32 1 to i64
  %hash_key463 = sext i32 1 to i64
  %hash_high465 = lshr i64 %hash_key463, 32
  %hash_fold464 = xor i64 %hash_key463, %hash_high465
  %hash466 = mul i64 %hash_fold464, -7046029254386353131
  %dict_h2_shifted467 = lshr i64 %hash466, 57
  %dict_h2_raw468 = and i64 %dict_h2_shifted467, 127
  %dict_h2_zero469 = icmp eq i64 %dict_h2_raw468, 0
  %dict_h2470 = select i1 %dict_h2_zero469, i64 1, i64 %dict_h2_raw468
  %dict_h2_byte471 = trunc i64 %dict_h2470 to i8
  %dict_capacity_mask472 = sub i64 %mutable_capacity461, 1
  %dict_start_slot473 = and i64 %hash466, %dict_capacity_mask472
  br label %bb_dict_lookup102

bb_dict_lookup102:
  %dict_lookup_probe475 = phi i64 [ 0, %bb_dict_put_done66 ], [ %dict_lookup_next_probe474, %bb_dict_lookup_next107 ]
  %dict_lookup_active476 = icmp ult i64 %dict_lookup_probe475, %mutable_capacity461
  br i1 %dict_lookup_active476, label %bb_dict_lookup_body103, label %bb_dict_lookup_miss108

bb_dict_lookup_body103:
  %dict_lookup_unwrapped477 = add i64 %dict_start_slot473, %dict_lookup_probe475
  %dict_lookup_slot478 = and i64 %dict_lookup_unwrapped477, %dict_capacity_mask472
  %dict_control_slot479 = getelementptr i8, ptr %mutable_ptr459, i64 %dict_lookup_slot478
  %dict_control480 = load i8, ptr %dict_control_slot479, align 1
  %dict_lookup_is_empty481 = icmp eq i8 %dict_control480, 0
  br i1 %dict_lookup_is_empty481, label %bb_dict_lookup_miss108, label %bb_dict_lookup_full104

bb_dict_lookup_full104:
  %dict_lookup_h2_match482 = icmp eq i8 %dict_control480, %dict_h2_byte471
  br i1 %dict_lookup_h2_match482, label %bb_dict_lookup_compare105, label %bb_dict_lookup_next107

bb_dict_lookup_compare105:
  %dict_entries_offset_mirror483 = add i64 %mutable_capacity461, 23
  %dict_entries_offset484 = and i64 %dict_entries_offset_mirror483, -8
  %dict_entries485 = getelementptr i8, ptr %mutable_ptr459, i64 %dict_entries_offset484
  %dict_key_offset486 = mul i64 %dict_lookup_slot478, 2
  %dict_key_slot487 = getelementptr i32, ptr %dict_entries485, i64 %dict_key_offset486
  %dict_key488 = load i32, ptr %dict_key_slot487, align 4
  %dict_lookup_key_match489 = icmp eq i32 %dict_key488, 1
  br i1 %dict_lookup_key_match489, label %bb_dict_lookup_match106, label %bb_dict_lookup_next107

bb_dict_lookup_match106:
  %dict_entries_offset_mirror490 = add i64 %mutable_capacity461, 23
  %dict_entries_offset491 = and i64 %dict_entries_offset_mirror490, -8
  %dict_entries492 = getelementptr i8, ptr %mutable_ptr459, i64 %dict_entries_offset491
  %dict_value_base493 = mul i64 %dict_lookup_slot478, 2
  %dict_value_offset494 = add i64 %dict_value_base493, 1
  %dict_value_slot495 = getelementptr i32, ptr %dict_entries492, i64 %dict_value_offset494
  %dict_value496 = load i32, ptr %dict_value_slot495, align 4
  br label %bb_dict_lookup_done109

bb_dict_lookup_next107:
  %dict_lookup_next_probe474 = add i64 %dict_lookup_probe475, 1
  br label %bb_dict_lookup102

bb_dict_lookup_miss108:
  call void @llvm.trap()
  unreachable

bb_dict_lookup_done109:
  %mutable_ptr497 = load ptr, ptr %stack_slot0, align 8
  %mutable_len498 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity499 = load i64, ptr %mutable_capacity_addr1, align 8
  %index_size500 = sext i32 3 to i64
  %hash_key501 = sext i32 3 to i64
  %hash_high503 = lshr i64 %hash_key501, 32
  %hash_fold502 = xor i64 %hash_key501, %hash_high503
  %hash504 = mul i64 %hash_fold502, -7046029254386353131
  %dict_h2_shifted505 = lshr i64 %hash504, 57
  %dict_h2_raw506 = and i64 %dict_h2_shifted505, 127
  %dict_h2_zero507 = icmp eq i64 %dict_h2_raw506, 0
  %dict_h2508 = select i1 %dict_h2_zero507, i64 1, i64 %dict_h2_raw506
  %dict_h2_byte509 = trunc i64 %dict_h2508 to i8
  %dict_capacity_mask510 = sub i64 %mutable_capacity499, 1
  %dict_start_slot511 = and i64 %hash504, %dict_capacity_mask510
  br label %bb_dict_lookup110

bb_dict_lookup110:
  %dict_lookup_probe513 = phi i64 [ 0, %bb_dict_lookup_done109 ], [ %dict_lookup_next_probe512, %bb_dict_lookup_next115 ]
  %dict_lookup_active514 = icmp ult i64 %dict_lookup_probe513, %mutable_capacity499
  br i1 %dict_lookup_active514, label %bb_dict_lookup_body111, label %bb_dict_lookup_miss116

bb_dict_lookup_body111:
  %dict_lookup_unwrapped515 = add i64 %dict_start_slot511, %dict_lookup_probe513
  %dict_lookup_slot516 = and i64 %dict_lookup_unwrapped515, %dict_capacity_mask510
  %dict_control_slot517 = getelementptr i8, ptr %mutable_ptr497, i64 %dict_lookup_slot516
  %dict_control518 = load i8, ptr %dict_control_slot517, align 1
  %dict_lookup_is_empty519 = icmp eq i8 %dict_control518, 0
  br i1 %dict_lookup_is_empty519, label %bb_dict_lookup_miss116, label %bb_dict_lookup_full112

bb_dict_lookup_full112:
  %dict_lookup_h2_match520 = icmp eq i8 %dict_control518, %dict_h2_byte509
  br i1 %dict_lookup_h2_match520, label %bb_dict_lookup_compare113, label %bb_dict_lookup_next115

bb_dict_lookup_compare113:
  %dict_entries_offset_mirror521 = add i64 %mutable_capacity499, 23
  %dict_entries_offset522 = and i64 %dict_entries_offset_mirror521, -8
  %dict_entries523 = getelementptr i8, ptr %mutable_ptr497, i64 %dict_entries_offset522
  %dict_key_offset524 = mul i64 %dict_lookup_slot516, 2
  %dict_key_slot525 = getelementptr i32, ptr %dict_entries523, i64 %dict_key_offset524
  %dict_key526 = load i32, ptr %dict_key_slot525, align 4
  %dict_lookup_key_match527 = icmp eq i32 %dict_key526, 3
  br i1 %dict_lookup_key_match527, label %bb_dict_lookup_match114, label %bb_dict_lookup_next115

bb_dict_lookup_match114:
  %dict_entries_offset_mirror528 = add i64 %mutable_capacity499, 23
  %dict_entries_offset529 = and i64 %dict_entries_offset_mirror528, -8
  %dict_entries530 = getelementptr i8, ptr %mutable_ptr497, i64 %dict_entries_offset529
  %dict_value_base531 = mul i64 %dict_lookup_slot516, 2
  %dict_value_offset532 = add i64 %dict_value_base531, 1
  %dict_value_slot533 = getelementptr i32, ptr %dict_entries530, i64 %dict_value_offset532
  %dict_value534 = load i32, ptr %dict_value_slot533, align 4
  br label %bb_dict_lookup_done117

bb_dict_lookup_next115:
  %dict_lookup_next_probe512 = add i64 %dict_lookup_probe513, 1
  br label %bb_dict_lookup110

bb_dict_lookup_miss116:
  call void @llvm.trap()
  unreachable

bb_dict_lookup_done117:
  %mutable_ptr535 = load ptr, ptr %stack_slot0, align 8
  %mutable_len536 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity537 = load i64, ptr %mutable_capacity_addr1, align 8
  %index_size538 = sext i32 4 to i64
  %hash_key539 = sext i32 4 to i64
  %hash_high541 = lshr i64 %hash_key539, 32
  %hash_fold540 = xor i64 %hash_key539, %hash_high541
  %hash542 = mul i64 %hash_fold540, -7046029254386353131
  %dict_h2_shifted543 = lshr i64 %hash542, 57
  %dict_h2_raw544 = and i64 %dict_h2_shifted543, 127
  %dict_h2_zero545 = icmp eq i64 %dict_h2_raw544, 0
  %dict_h2546 = select i1 %dict_h2_zero545, i64 1, i64 %dict_h2_raw544
  %dict_h2_byte547 = trunc i64 %dict_h2546 to i8
  %dict_capacity_mask548 = sub i64 %mutable_capacity537, 1
  %dict_start_slot549 = and i64 %hash542, %dict_capacity_mask548
  br label %bb_dict_lookup118

bb_dict_lookup118:
  %dict_lookup_probe551 = phi i64 [ 0, %bb_dict_lookup_done117 ], [ %dict_lookup_next_probe550, %bb_dict_lookup_next123 ]
  %dict_lookup_active552 = icmp ult i64 %dict_lookup_probe551, %mutable_capacity537
  br i1 %dict_lookup_active552, label %bb_dict_lookup_body119, label %bb_dict_lookup_miss124

bb_dict_lookup_body119:
  %dict_lookup_unwrapped553 = add i64 %dict_start_slot549, %dict_lookup_probe551
  %dict_lookup_slot554 = and i64 %dict_lookup_unwrapped553, %dict_capacity_mask548
  %dict_control_slot555 = getelementptr i8, ptr %mutable_ptr535, i64 %dict_lookup_slot554
  %dict_control556 = load i8, ptr %dict_control_slot555, align 1
  %dict_lookup_is_empty557 = icmp eq i8 %dict_control556, 0
  br i1 %dict_lookup_is_empty557, label %bb_dict_lookup_miss124, label %bb_dict_lookup_full120

bb_dict_lookup_full120:
  %dict_lookup_h2_match558 = icmp eq i8 %dict_control556, %dict_h2_byte547
  br i1 %dict_lookup_h2_match558, label %bb_dict_lookup_compare121, label %bb_dict_lookup_next123

bb_dict_lookup_compare121:
  %dict_entries_offset_mirror559 = add i64 %mutable_capacity537, 23
  %dict_entries_offset560 = and i64 %dict_entries_offset_mirror559, -8
  %dict_entries561 = getelementptr i8, ptr %mutable_ptr535, i64 %dict_entries_offset560
  %dict_key_offset562 = mul i64 %dict_lookup_slot554, 2
  %dict_key_slot563 = getelementptr i32, ptr %dict_entries561, i64 %dict_key_offset562
  %dict_key564 = load i32, ptr %dict_key_slot563, align 4
  %dict_lookup_key_match565 = icmp eq i32 %dict_key564, 4
  br i1 %dict_lookup_key_match565, label %bb_dict_lookup_match122, label %bb_dict_lookup_next123

bb_dict_lookup_match122:
  %dict_entries_offset_mirror566 = add i64 %mutable_capacity537, 23
  %dict_entries_offset567 = and i64 %dict_entries_offset_mirror566, -8
  %dict_entries568 = getelementptr i8, ptr %mutable_ptr535, i64 %dict_entries_offset567
  %dict_value_base569 = mul i64 %dict_lookup_slot554, 2
  %dict_value_offset570 = add i64 %dict_value_base569, 1
  %dict_value_slot571 = getelementptr i32, ptr %dict_entries568, i64 %dict_value_offset570
  %dict_value572 = load i32, ptr %dict_value_slot571, align 4
  br label %bb_dict_lookup_done125

bb_dict_lookup_next123:
  %dict_lookup_next_probe550 = add i64 %dict_lookup_probe551, 1
  br label %bb_dict_lookup118

bb_dict_lookup_miss124:
  call void @llvm.trap()
  unreachable

bb_dict_lookup_done125:
  %write573 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.2, i64 8, ptr %written)
  %is_ok574 = icmp ne i32 %write573, 0
  %previous_ok575 = load i1, ptr %ok_state, align 1
  %ok576 = and i1 %previous_ok575, %is_ok574
  store i1 %ok576, ptr %ok_state, align 1
  %print_integer577 = sext i32 %dict_len_value458 to i64
  %write578 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer577, ptr %written)
  %is_ok579 = icmp ne i32 %write578, 0
  %previous_ok580 = load i1, ptr %ok_state, align 1
  %ok581 = and i1 %previous_ok580, %is_ok579
  store i1 %ok581, ptr %ok_state, align 1
  %write582 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.3, i64 1, ptr %written)
  %is_ok583 = icmp ne i32 %write582, 0
  %previous_ok584 = load i1, ptr %ok_state, align 1
  %ok585 = and i1 %previous_ok584, %is_ok583
  store i1 %ok585, ptr %ok_state, align 1
  %write586 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.4, i64 8, ptr %written)
  %is_ok587 = icmp ne i32 %write586, 0
  %previous_ok588 = load i1, ptr %ok_state, align 1
  %ok589 = and i1 %previous_ok588, %is_ok587
  store i1 %ok589, ptr %ok_state, align 1
  %print_integer590 = sext i32 %dict_value496 to i64
  %write591 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer590, ptr %written)
  %is_ok592 = icmp ne i32 %write591, 0
  %previous_ok593 = load i1, ptr %ok_state, align 1
  %ok594 = and i1 %previous_ok593, %is_ok592
  store i1 %ok594, ptr %ok_state, align 1
  %write595 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.5, i64 1, ptr %written)
  %is_ok596 = icmp ne i32 %write595, 0
  %previous_ok597 = load i1, ptr %ok_state, align 1
  %ok598 = and i1 %previous_ok597, %is_ok596
  store i1 %ok598, ptr %ok_state, align 1
  %write599 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.6, i64 8, ptr %written)
  %is_ok600 = icmp ne i32 %write599, 0
  %previous_ok601 = load i1, ptr %ok_state, align 1
  %ok602 = and i1 %previous_ok601, %is_ok600
  store i1 %ok602, ptr %ok_state, align 1
  %print_integer603 = sext i32 %dict_value534 to i64
  %write604 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer603, ptr %written)
  %is_ok605 = icmp ne i32 %write604, 0
  %previous_ok606 = load i1, ptr %ok_state, align 1
  %ok607 = and i1 %previous_ok606, %is_ok605
  store i1 %ok607, ptr %ok_state, align 1
  %write608 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.7, i64 1, ptr %written)
  %is_ok609 = icmp ne i32 %write608, 0
  %previous_ok610 = load i1, ptr %ok_state, align 1
  %ok611 = and i1 %previous_ok610, %is_ok609
  store i1 %ok611, ptr %ok_state, align 1
  %write612 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.8, i64 9, ptr %written)
  %is_ok613 = icmp ne i32 %write612, 0
  %previous_ok614 = load i1, ptr %ok_state, align 1
  %ok615 = and i1 %previous_ok614, %is_ok613
  store i1 %ok615, ptr %ok_state, align 1
  %print_integer616 = sext i32 %dict_value572 to i64
  %write617 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer616, ptr %written)
  %is_ok618 = icmp ne i32 %write617, 0
  %previous_ok619 = load i1, ptr %ok_state, align 1
  %ok620 = and i1 %previous_ok619, %is_ok618
  store i1 %ok620, ptr %ok_state, align 1
  %write621 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.9, i64 1, ptr %written)
  %is_ok622 = icmp ne i32 %write621, 0
  %previous_ok623 = load i1, ptr %ok_state, align 1
  %ok624 = and i1 %previous_ok623, %is_ok622
  store i1 %ok624, ptr %ok_state, align 1
  %mutable_ptr625 = load ptr, ptr %stack_slot0, align 8
  %mutable_len626 = load i64, ptr %mutable_len_addr0, align 8
  %mutable_capacity627 = load i64, ptr %mutable_capacity_addr1, align 8
  call void @sollang_free(ptr %mutable_ptr625)
  call void @llvm.lifetime.end.p0(i64 24, ptr %stack_slot0)
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %final_ok628 = load i1, ptr %ok_state, align 1
  %exit629 = select i1 %final_ok628, i32 0, i32 1
  ret i32 %exit629
}

attributes #0 = { nounwind }
