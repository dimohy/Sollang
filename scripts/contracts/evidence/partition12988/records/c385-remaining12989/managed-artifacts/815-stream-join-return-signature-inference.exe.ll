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
%sollang.struct.2651 = type { i32, i32 }
%sollang.struct.2709 = type { %sollang.stream, %sollang.stream }
%sollang.struct.2710 = type { %sollang.stream, %sollang.stream }
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
declare dllimport i32 @SetConsoleMode(ptr, i32)
declare dllimport i32 @ReadConsoleInputW(ptr, ptr, i32, ptr)
declare dllimport i32 @CancelSynchronousIo(ptr)
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
declare dllimport i32 @WaitForSingleObject(ptr, i32)
declare dllimport i32 @GetEnvironmentVariableW(ptr, ptr, i32)
declare dllimport i32 @GetLastError()
declare dllimport void @SetLastError(i32)
declare dllimport ptr @CreateThread(ptr, i64, ptr, ptr, i32, ptr)
declare dllimport ptr @CreateEventA(ptr, i32, i32, ptr)
declare dllimport i32 @SetEvent(ptr)
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

define internal void @sollang_drop_2709(%sollang.struct.2709 %value) #0 {
entry:
  %drop_field0 = extractvalue %sollang.struct.2709 %value, 0
  %stream_context1 = extractvalue %sollang.stream %drop_field0, 0
  %stream_next2 = extractvalue %sollang.stream %drop_field0, 1
  %stream_drop3 = extractvalue %sollang.stream %drop_field0, 2
  %stream_has_drop4 = icmp ne ptr %stream_drop3, null
  br i1 %stream_has_drop4, label %bb_stream_drop0, label %bb_stream_drop_done1

bb_stream_drop0:
  call void %stream_drop3(ptr %stream_context1, i1 true)
  br label %bb_stream_drop_done1

bb_stream_drop_done1:
  %drop_field5 = extractvalue %sollang.struct.2709 %value, 1
  %stream_context6 = extractvalue %sollang.stream %drop_field5, 0
  %stream_next7 = extractvalue %sollang.stream %drop_field5, 1
  %stream_drop8 = extractvalue %sollang.stream %drop_field5, 2
  %stream_has_drop9 = icmp ne ptr %stream_drop8, null
  br i1 %stream_has_drop9, label %bb_stream_drop2, label %bb_stream_drop_done3

bb_stream_drop2:
  call void %stream_drop8(ptr %stream_context6, i1 true)
  br label %bb_stream_drop_done3

bb_stream_drop_done3:
  ret void
}

define internal void @sollang_drop_2710(%sollang.struct.2710 %value) #0 {
entry:
  %drop_field10 = extractvalue %sollang.struct.2710 %value, 0
  %stream_context11 = extractvalue %sollang.stream %drop_field10, 0
  %stream_next12 = extractvalue %sollang.stream %drop_field10, 1
  %stream_drop13 = extractvalue %sollang.stream %drop_field10, 2
  %stream_has_drop14 = icmp ne ptr %stream_drop13, null
  br i1 %stream_has_drop14, label %bb_stream_drop4, label %bb_stream_drop_done5

bb_stream_drop4:
  call void %stream_drop13(ptr %stream_context11, i1 true)
  br label %bb_stream_drop_done5

bb_stream_drop_done5:
  %drop_field15 = extractvalue %sollang.struct.2710 %value, 1
  %stream_context16 = extractvalue %sollang.stream %drop_field15, 0
  %stream_next17 = extractvalue %sollang.stream %drop_field15, 1
  %stream_drop18 = extractvalue %sollang.stream %drop_field15, 2
  %stream_has_drop19 = icmp ne ptr %stream_drop18, null
  br i1 %stream_has_drop19, label %bb_stream_drop6, label %bb_stream_drop_done7

bb_stream_drop6:
  call void %stream_drop18(ptr %stream_context16, i1 true)
  br label %bb_stream_drop_done7

bb_stream_drop_done7:
  ret void
}

define internal i1 @sollang_stream_join_0_next(ptr %context, ptr %output) #0 {
entry:
  %stream_join_input_address20 = getelementptr { %sollang.stream, %sollang.stream }, ptr %context, i32 0, i32 0
  %stream_join_input21 = load %sollang.stream, ptr %stream_join_input_address20, align 8
  %stream_context22 = extractvalue %sollang.stream %stream_join_input21, 0
  %stream_next23 = extractvalue %sollang.stream %stream_join_input21, 1
  %stream_drop24 = extractvalue %sollang.stream %stream_join_input21, 2
  %zip_runtime_output25 = getelementptr %sollang.struct.2651, ptr %output, i32 0, i32 0
  %zip_runtime_has_value26 = call i1 %stream_next23(ptr %stream_context22, ptr %zip_runtime_output25)
  br i1 %zip_runtime_has_value26, label %bb_zip_runtime_pull10, label %bb_zip_runtime_done8

bb_zip_runtime_pull10:
  %stream_join_input_address27 = getelementptr { %sollang.stream, %sollang.stream }, ptr %context, i32 0, i32 1
  %stream_join_input28 = load %sollang.stream, ptr %stream_join_input_address27, align 8
  %stream_context29 = extractvalue %sollang.stream %stream_join_input28, 0
  %stream_next30 = extractvalue %sollang.stream %stream_join_input28, 1
  %stream_drop31 = extractvalue %sollang.stream %stream_join_input28, 2
  %zip_runtime_output32 = getelementptr %sollang.struct.2651, ptr %output, i32 0, i32 1
  %zip_runtime_has_value33 = call i1 %stream_next30(ptr %stream_context29, ptr %zip_runtime_output32)
  br i1 %zip_runtime_has_value33, label %bb_zip_runtime_emit11, label %bb_zip_runtime_partial9

bb_zip_runtime_emit11:
  ret i1 true

bb_zip_runtime_partial9:
  br label %bb_zip_runtime_done8

bb_zip_runtime_done8:
  ret i1 false
}

define internal void @sollang_stream_join_0_drop(ptr %context, i1 %destroy) #0 {
entry:
  br i1 %destroy, label %destroy_inputs, label %cancelled

cancelled:
  ret void

destroy_inputs:
  %stream_join_input_address34 = getelementptr { %sollang.stream, %sollang.stream }, ptr %context, i32 0, i32 0
  %stream_join_input35 = load %sollang.stream, ptr %stream_join_input_address34, align 8
  %stream_context36 = extractvalue %sollang.stream %stream_join_input35, 0
  %stream_next37 = extractvalue %sollang.stream %stream_join_input35, 1
  %stream_drop38 = extractvalue %sollang.stream %stream_join_input35, 2
  %stream_has_drop39 = icmp ne ptr %stream_drop38, null
  br i1 %stream_has_drop39, label %bb_stream_drop12, label %bb_stream_drop_done13

bb_stream_drop12:
  call void %stream_drop38(ptr %stream_context36, i1 true)
  br label %bb_stream_drop_done13

bb_stream_drop_done13:
  %stream_join_input_address40 = getelementptr { %sollang.stream, %sollang.stream }, ptr %context, i32 0, i32 1
  %stream_join_input41 = load %sollang.stream, ptr %stream_join_input_address40, align 8
  %stream_context42 = extractvalue %sollang.stream %stream_join_input41, 0
  %stream_next43 = extractvalue %sollang.stream %stream_join_input41, 1
  %stream_drop44 = extractvalue %sollang.stream %stream_join_input41, 2
  %stream_has_drop45 = icmp ne ptr %stream_drop44, null
  br i1 %stream_has_drop45, label %bb_stream_drop14, label %bb_stream_drop_done15

bb_stream_drop14:
  call void %stream_drop44(ptr %stream_context42, i1 true)
  br label %bb_stream_drop_done15

bb_stream_drop_done15:
  call void @sollang_free(ptr %context)
  ret void
}

define internal i1 @sollang_stream_join_1_next(ptr %context, ptr %output) #0 {
entry:
  %concat_runtime_cursor_address46 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %context, i32 0, i32 2
  %concat_runtime_cursor47 = load i32, ptr %concat_runtime_cursor_address46, align 4
  switch i32 %concat_runtime_cursor47, label %bb_concat_runtime_done16 [
    i32 0, label %bb_concat_runtime_input_017
    i32 1, label %bb_concat_runtime_input_118
  ]

bb_concat_runtime_input_017:
  %stream_join_input_address48 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %context, i32 0, i32 0
  %stream_join_input49 = load %sollang.stream, ptr %stream_join_input_address48, align 8
  %stream_context50 = extractvalue %sollang.stream %stream_join_input49, 0
  %stream_next51 = extractvalue %sollang.stream %stream_join_input49, 1
  %stream_drop52 = extractvalue %sollang.stream %stream_join_input49, 2
  %concat_runtime_has_value53 = call i1 %stream_next51(ptr %stream_context50, ptr %output)
  br i1 %concat_runtime_has_value53, label %bb_concat_runtime_emit19, label %bb_concat_runtime_exhausted20

bb_concat_runtime_emit19:
  ret i1 true

bb_concat_runtime_exhausted20:
  store i32 1, ptr %concat_runtime_cursor_address46, align 4
  br label %bb_concat_runtime_input_118

bb_concat_runtime_input_118:
  %stream_join_input_address54 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %context, i32 0, i32 1
  %stream_join_input55 = load %sollang.stream, ptr %stream_join_input_address54, align 8
  %stream_context56 = extractvalue %sollang.stream %stream_join_input55, 0
  %stream_next57 = extractvalue %sollang.stream %stream_join_input55, 1
  %stream_drop58 = extractvalue %sollang.stream %stream_join_input55, 2
  %concat_runtime_has_value59 = call i1 %stream_next57(ptr %stream_context56, ptr %output)
  br i1 %concat_runtime_has_value59, label %bb_concat_runtime_emit21, label %bb_concat_runtime_exhausted22

bb_concat_runtime_emit21:
  ret i1 true

bb_concat_runtime_exhausted22:
  store i32 2, ptr %concat_runtime_cursor_address46, align 4
  br label %bb_concat_runtime_done16

bb_concat_runtime_done16:
  ret i1 false
}

define internal void @sollang_stream_join_1_drop(ptr %context, i1 %destroy) #0 {
entry:
  br i1 %destroy, label %destroy_inputs, label %cancelled

cancelled:
  ret void

destroy_inputs:
  %stream_join_input_address60 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %context, i32 0, i32 0
  %stream_join_input61 = load %sollang.stream, ptr %stream_join_input_address60, align 8
  %stream_context62 = extractvalue %sollang.stream %stream_join_input61, 0
  %stream_next63 = extractvalue %sollang.stream %stream_join_input61, 1
  %stream_drop64 = extractvalue %sollang.stream %stream_join_input61, 2
  %stream_has_drop65 = icmp ne ptr %stream_drop64, null
  br i1 %stream_has_drop65, label %bb_stream_drop23, label %bb_stream_drop_done24

bb_stream_drop23:
  call void %stream_drop64(ptr %stream_context62, i1 true)
  br label %bb_stream_drop_done24

bb_stream_drop_done24:
  %stream_join_input_address66 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %context, i32 0, i32 1
  %stream_join_input67 = load %sollang.stream, ptr %stream_join_input_address66, align 8
  %stream_context68 = extractvalue %sollang.stream %stream_join_input67, 0
  %stream_next69 = extractvalue %sollang.stream %stream_join_input67, 1
  %stream_drop70 = extractvalue %sollang.stream %stream_join_input67, 2
  %stream_has_drop71 = icmp ne ptr %stream_drop70, null
  br i1 %stream_has_drop71, label %bb_stream_drop25, label %bb_stream_drop_done26

bb_stream_drop25:
  call void %stream_drop70(ptr %stream_context68, i1 true)
  br label %bb_stream_drop_done26

bb_stream_drop_done26:
  call void @sollang_free(ptr %context)
  ret void
}

define internal i1 @sollang_stream_join_2_next(ptr %context, ptr %output) #0 {
entry:
  %merge_runtime_scan_slot72 = alloca i32, align 4
  %merge_runtime_checked_slot73 = alloca i32, align 4
  %merge_runtime_cursor_address74 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 2
  %merge_runtime_cursor75 = load i32, ptr %merge_runtime_cursor_address74, align 4
  store i32 %merge_runtime_cursor75, ptr %merge_runtime_scan_slot72, align 4
  store i32 0, ptr %merge_runtime_checked_slot73, align 4
  br label %bb_merge_runtime_loop27

bb_merge_runtime_loop27:
  %merge_runtime_checked76 = load i32, ptr %merge_runtime_checked_slot73, align 4
  %merge_runtime_exhausted77 = icmp eq i32 %merge_runtime_checked76, 2
  br i1 %merge_runtime_exhausted77, label %bb_merge_runtime_done28, label %bb_merge_runtime_dispatch31

bb_merge_runtime_dispatch31:
  %merge_runtime_scan78 = load i32, ptr %merge_runtime_scan_slot72, align 4
  switch i32 %merge_runtime_scan78, label %bb_merge_runtime_done28 [
    i32 0, label %bb_merge_runtime_input_029
    i32 1, label %bb_merge_runtime_input_130
  ]

bb_merge_runtime_input_029:
  %merge_runtime_active_address79 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 3, i32 0
  %merge_runtime_active80 = load i1, ptr %merge_runtime_active_address79, align 1
  br i1 %merge_runtime_active80, label %bb_merge_runtime_pull32, label %bb_merge_runtime_advance33

bb_merge_runtime_pull32:
  %stream_join_input_address81 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 0
  %stream_join_input82 = load %sollang.stream, ptr %stream_join_input_address81, align 8
  %stream_context83 = extractvalue %sollang.stream %stream_join_input82, 0
  %stream_next84 = extractvalue %sollang.stream %stream_join_input82, 1
  %stream_drop85 = extractvalue %sollang.stream %stream_join_input82, 2
  %merge_runtime_has_value86 = call i1 %stream_next84(ptr %stream_context83, ptr %output)
  br i1 %merge_runtime_has_value86, label %bb_merge_runtime_emit34, label %bb_merge_runtime_mark_exhausted35

bb_merge_runtime_emit34:
  store i32 1, ptr %merge_runtime_cursor_address74, align 4
  ret i1 true

bb_merge_runtime_mark_exhausted35:
  store i1 false, ptr %merge_runtime_active_address79, align 1
  br label %bb_merge_runtime_advance33

bb_merge_runtime_advance33:
  store i32 1, ptr %merge_runtime_scan_slot72, align 4
  %merge_runtime_previous_checked87 = load i32, ptr %merge_runtime_checked_slot73, align 4
  %merge_runtime_next_checked88 = add i32 %merge_runtime_previous_checked87, 1
  store i32 %merge_runtime_next_checked88, ptr %merge_runtime_checked_slot73, align 4
  br label %bb_merge_runtime_loop27

bb_merge_runtime_input_130:
  %merge_runtime_active_address89 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 3, i32 1
  %merge_runtime_active90 = load i1, ptr %merge_runtime_active_address89, align 1
  br i1 %merge_runtime_active90, label %bb_merge_runtime_pull36, label %bb_merge_runtime_advance37

bb_merge_runtime_pull36:
  %stream_join_input_address91 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 1
  %stream_join_input92 = load %sollang.stream, ptr %stream_join_input_address91, align 8
  %stream_context93 = extractvalue %sollang.stream %stream_join_input92, 0
  %stream_next94 = extractvalue %sollang.stream %stream_join_input92, 1
  %stream_drop95 = extractvalue %sollang.stream %stream_join_input92, 2
  %merge_runtime_has_value96 = call i1 %stream_next94(ptr %stream_context93, ptr %output)
  br i1 %merge_runtime_has_value96, label %bb_merge_runtime_emit38, label %bb_merge_runtime_mark_exhausted39

bb_merge_runtime_emit38:
  store i32 0, ptr %merge_runtime_cursor_address74, align 4
  ret i1 true

bb_merge_runtime_mark_exhausted39:
  store i1 false, ptr %merge_runtime_active_address89, align 1
  br label %bb_merge_runtime_advance37

bb_merge_runtime_advance37:
  store i32 0, ptr %merge_runtime_scan_slot72, align 4
  %merge_runtime_previous_checked97 = load i32, ptr %merge_runtime_checked_slot73, align 4
  %merge_runtime_next_checked98 = add i32 %merge_runtime_previous_checked97, 1
  store i32 %merge_runtime_next_checked98, ptr %merge_runtime_checked_slot73, align 4
  br label %bb_merge_runtime_loop27

bb_merge_runtime_done28:
  ret i1 false
}

define internal void @sollang_stream_join_2_drop(ptr %context, i1 %destroy) #0 {
entry:
  br i1 %destroy, label %destroy_inputs, label %cancelled

cancelled:
  ret void

destroy_inputs:
  %stream_join_input_address99 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 0
  %stream_join_input100 = load %sollang.stream, ptr %stream_join_input_address99, align 8
  %stream_context101 = extractvalue %sollang.stream %stream_join_input100, 0
  %stream_next102 = extractvalue %sollang.stream %stream_join_input100, 1
  %stream_drop103 = extractvalue %sollang.stream %stream_join_input100, 2
  %stream_has_drop104 = icmp ne ptr %stream_drop103, null
  br i1 %stream_has_drop104, label %bb_stream_drop40, label %bb_stream_drop_done41

bb_stream_drop40:
  call void %stream_drop103(ptr %stream_context101, i1 true)
  br label %bb_stream_drop_done41

bb_stream_drop_done41:
  %stream_join_input_address105 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %context, i32 0, i32 1
  %stream_join_input106 = load %sollang.stream, ptr %stream_join_input_address105, align 8
  %stream_context107 = extractvalue %sollang.stream %stream_join_input106, 0
  %stream_next108 = extractvalue %sollang.stream %stream_join_input106, 1
  %stream_drop109 = extractvalue %sollang.stream %stream_join_input106, 2
  %stream_has_drop110 = icmp ne ptr %stream_drop109, null
  br i1 %stream_has_drop110, label %bb_stream_drop42, label %bb_stream_drop_done43

bb_stream_drop42:
  call void %stream_drop109(ptr %stream_context107, i1 true)
  br label %bb_stream_drop_done43

bb_stream_drop_done43:
  call void @sollang_free(ptr %context)
  ret void
}

define internal i1 @sollang_stream_join_3_next(ptr %context, ptr %output) #0 {
entry:
  %latest_runtime_cursor_address111 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 2
  %latest_runtime_initialized_address112 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 3
  %latest_runtime_initialized113 = load i1, ptr %latest_runtime_initialized_address112, align 1
  br i1 %latest_runtime_initialized113, label %bb_latest_runtime_scan_entry45, label %bb_latest_runtime_initial44

bb_latest_runtime_initial44:
  %stream_join_input_address114 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 0
  %stream_join_input115 = load %sollang.stream, ptr %stream_join_input_address114, align 8
  %stream_context116 = extractvalue %sollang.stream %stream_join_input115, 0
  %stream_next117 = extractvalue %sollang.stream %stream_join_input115, 1
  %stream_drop118 = extractvalue %sollang.stream %stream_join_input115, 2
  %latest_runtime_cache_address119 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 5
  %latest_runtime_has_initial120 = call i1 %stream_next117(ptr %stream_context116, ptr %latest_runtime_cache_address119)
  br i1 %latest_runtime_has_initial120, label %bb_latest_runtime_initial_next47, label %bb_latest_runtime_done46

bb_latest_runtime_initial_next47:
  %stream_join_input_address121 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 1
  %stream_join_input122 = load %sollang.stream, ptr %stream_join_input_address121, align 8
  %stream_context123 = extractvalue %sollang.stream %stream_join_input122, 0
  %stream_next124 = extractvalue %sollang.stream %stream_join_input122, 1
  %stream_drop125 = extractvalue %sollang.stream %stream_join_input122, 2
  %latest_runtime_cache_address126 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 6
  %latest_runtime_has_initial127 = call i1 %stream_next124(ptr %stream_context123, ptr %latest_runtime_cache_address126)
  br i1 %latest_runtime_has_initial127, label %bb_latest_runtime_initial_next48, label %bb_latest_runtime_done46

bb_latest_runtime_initial_next48:
  store i1 true, ptr %latest_runtime_initialized_address112, align 1
  store i32 0, ptr %latest_runtime_cursor_address111, align 4
  %latest_runtime_cache_address128 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 5
  %latest_runtime_value129 = load i32, ptr %latest_runtime_cache_address128, align 4
  %latest_runtime_product130 = insertvalue %sollang.struct.2651 poison, i32 %latest_runtime_value129, 0
  %latest_runtime_cache_address131 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 6
  %latest_runtime_value132 = load i32, ptr %latest_runtime_cache_address131, align 4
  %latest_runtime_product133 = insertvalue %sollang.struct.2651 %latest_runtime_product130, i32 %latest_runtime_value132, 1
  store %sollang.struct.2651 %latest_runtime_product133, ptr %output, align 4
  ret i1 true

bb_latest_runtime_scan_entry45:
  %latest_runtime_scan_slot134 = alloca i32, align 4
  %latest_runtime_checked_slot135 = alloca i32, align 4
  %latest_runtime_cursor136 = load i32, ptr %latest_runtime_cursor_address111, align 4
  store i32 %latest_runtime_cursor136, ptr %latest_runtime_scan_slot134, align 4
  store i32 0, ptr %latest_runtime_checked_slot135, align 4
  br label %bb_latest_runtime_loop49

bb_latest_runtime_loop49:
  %latest_runtime_checked137 = load i32, ptr %latest_runtime_checked_slot135, align 4
  %latest_runtime_exhausted138 = icmp eq i32 %latest_runtime_checked137, 2
  br i1 %latest_runtime_exhausted138, label %bb_latest_runtime_done46, label %bb_latest_runtime_dispatch52

bb_latest_runtime_dispatch52:
  %latest_runtime_scan139 = load i32, ptr %latest_runtime_scan_slot134, align 4
  switch i32 %latest_runtime_scan139, label %bb_latest_runtime_done46 [
    i32 0, label %bb_latest_runtime_input_050
    i32 1, label %bb_latest_runtime_input_151
  ]

bb_latest_runtime_input_050:
  %latest_runtime_active_address140 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 4, i32 0
  %latest_runtime_active141 = load i1, ptr %latest_runtime_active_address140, align 1
  br i1 %latest_runtime_active141, label %bb_latest_runtime_pull53, label %bb_latest_runtime_advance54

bb_latest_runtime_pull53:
  %stream_join_input_address142 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 0
  %stream_join_input143 = load %sollang.stream, ptr %stream_join_input_address142, align 8
  %stream_context144 = extractvalue %sollang.stream %stream_join_input143, 0
  %stream_next145 = extractvalue %sollang.stream %stream_join_input143, 1
  %stream_drop146 = extractvalue %sollang.stream %stream_join_input143, 2
  %latest_runtime_cache_address147 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 5
  %latest_runtime_has_value148 = call i1 %stream_next145(ptr %stream_context144, ptr %latest_runtime_cache_address147)
  br i1 %latest_runtime_has_value148, label %bb_latest_runtime_emit55, label %bb_latest_runtime_mark_exhausted56

bb_latest_runtime_emit55:
  store i32 1, ptr %latest_runtime_cursor_address111, align 4
  %latest_runtime_cache_address149 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 5
  %latest_runtime_value150 = load i32, ptr %latest_runtime_cache_address149, align 4
  %latest_runtime_product151 = insertvalue %sollang.struct.2651 poison, i32 %latest_runtime_value150, 0
  %latest_runtime_cache_address152 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 6
  %latest_runtime_value153 = load i32, ptr %latest_runtime_cache_address152, align 4
  %latest_runtime_product154 = insertvalue %sollang.struct.2651 %latest_runtime_product151, i32 %latest_runtime_value153, 1
  store %sollang.struct.2651 %latest_runtime_product154, ptr %output, align 4
  ret i1 true

bb_latest_runtime_mark_exhausted56:
  store i1 false, ptr %latest_runtime_active_address140, align 1
  br label %bb_latest_runtime_advance54

bb_latest_runtime_advance54:
  store i32 1, ptr %latest_runtime_scan_slot134, align 4
  %latest_runtime_previous_checked155 = load i32, ptr %latest_runtime_checked_slot135, align 4
  %latest_runtime_next_checked156 = add i32 %latest_runtime_previous_checked155, 1
  store i32 %latest_runtime_next_checked156, ptr %latest_runtime_checked_slot135, align 4
  br label %bb_latest_runtime_loop49

bb_latest_runtime_input_151:
  %latest_runtime_active_address157 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 4, i32 1
  %latest_runtime_active158 = load i1, ptr %latest_runtime_active_address157, align 1
  br i1 %latest_runtime_active158, label %bb_latest_runtime_pull57, label %bb_latest_runtime_advance58

bb_latest_runtime_pull57:
  %stream_join_input_address159 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 1
  %stream_join_input160 = load %sollang.stream, ptr %stream_join_input_address159, align 8
  %stream_context161 = extractvalue %sollang.stream %stream_join_input160, 0
  %stream_next162 = extractvalue %sollang.stream %stream_join_input160, 1
  %stream_drop163 = extractvalue %sollang.stream %stream_join_input160, 2
  %latest_runtime_cache_address164 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 6
  %latest_runtime_has_value165 = call i1 %stream_next162(ptr %stream_context161, ptr %latest_runtime_cache_address164)
  br i1 %latest_runtime_has_value165, label %bb_latest_runtime_emit59, label %bb_latest_runtime_mark_exhausted60

bb_latest_runtime_emit59:
  store i32 0, ptr %latest_runtime_cursor_address111, align 4
  %latest_runtime_cache_address166 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 5
  %latest_runtime_value167 = load i32, ptr %latest_runtime_cache_address166, align 4
  %latest_runtime_product168 = insertvalue %sollang.struct.2651 poison, i32 %latest_runtime_value167, 0
  %latest_runtime_cache_address169 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 6
  %latest_runtime_value170 = load i32, ptr %latest_runtime_cache_address169, align 4
  %latest_runtime_product171 = insertvalue %sollang.struct.2651 %latest_runtime_product168, i32 %latest_runtime_value170, 1
  store %sollang.struct.2651 %latest_runtime_product171, ptr %output, align 4
  ret i1 true

bb_latest_runtime_mark_exhausted60:
  store i1 false, ptr %latest_runtime_active_address157, align 1
  br label %bb_latest_runtime_advance58

bb_latest_runtime_advance58:
  store i32 0, ptr %latest_runtime_scan_slot134, align 4
  %latest_runtime_previous_checked172 = load i32, ptr %latest_runtime_checked_slot135, align 4
  %latest_runtime_next_checked173 = add i32 %latest_runtime_previous_checked172, 1
  store i32 %latest_runtime_next_checked173, ptr %latest_runtime_checked_slot135, align 4
  br label %bb_latest_runtime_loop49

bb_latest_runtime_done46:
  ret i1 false
}

define internal void @sollang_stream_join_3_drop(ptr %context, i1 %destroy) #0 {
entry:
  br i1 %destroy, label %destroy_inputs, label %cancelled

cancelled:
  ret void

destroy_inputs:
  %stream_join_input_address174 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 0
  %stream_join_input175 = load %sollang.stream, ptr %stream_join_input_address174, align 8
  %stream_context176 = extractvalue %sollang.stream %stream_join_input175, 0
  %stream_next177 = extractvalue %sollang.stream %stream_join_input175, 1
  %stream_drop178 = extractvalue %sollang.stream %stream_join_input175, 2
  %stream_has_drop179 = icmp ne ptr %stream_drop178, null
  br i1 %stream_has_drop179, label %bb_stream_drop61, label %bb_stream_drop_done62

bb_stream_drop61:
  call void %stream_drop178(ptr %stream_context176, i1 true)
  br label %bb_stream_drop_done62

bb_stream_drop_done62:
  %stream_join_input_address180 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %context, i32 0, i32 1
  %stream_join_input181 = load %sollang.stream, ptr %stream_join_input_address180, align 8
  %stream_context182 = extractvalue %sollang.stream %stream_join_input181, 0
  %stream_next183 = extractvalue %sollang.stream %stream_join_input181, 1
  %stream_drop184 = extractvalue %sollang.stream %stream_join_input181, 2
  %stream_has_drop185 = icmp ne ptr %stream_drop184, null
  br i1 %stream_has_drop185, label %bb_stream_drop63, label %bb_stream_drop_done64

bb_stream_drop63:
  call void %stream_drop184(ptr %stream_context182, i1 true)
  br label %bb_stream_drop_done64

bb_stream_drop_done64:
  call void @sollang_free(ptr %context)
  ret void
}

@.slg.str.module.x.0 = private unnamed_addr constant [44 x i8] c".makeValues:bb_range_stream_allocation_fail1", align 1
@.slg.str.module.x.1 = private unnamed_addr constant [45 x i8] c".zipValues:bb_stream_join_context_alloc_fail1", align 1
@.slg.str.module.x.2 = private unnamed_addr constant [48 x i8] c".concatValues:bb_stream_join_context_alloc_fail1", align 1
@.slg.str.module.x.3 = private unnamed_addr constant [47 x i8] c".mergeValues:bb_stream_join_context_alloc_fail1", align 1
@.slg.str.module.x.4 = private unnamed_addr constant [48 x i8] c".latestValues:bb_stream_join_context_alloc_fail1", align 1
define internal %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %it) #0 {
entry:
  %trap_written3 = alloca i32, align 4
  %range_stream_context0 = call ptr @sollang_alloc(i64 12)
  %range_stream_allocated1 = icmp ne ptr %range_stream_context0, null
  br i1 %range_stream_allocated1, label %bb_range_stream_allocation_ok0, label %bb_range_stream_allocation_fail1

bb_range_stream_allocation_fail1:
  %trap_stderr2 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr2, ptr @.slg.str.module.x.0, i32 44, ptr %trap_written3, ptr null)
  call void @llvm.trap()
  unreachable

bb_range_stream_allocation_ok0:
  %range_stream_start4 = extractvalue %sollang.struct.43 %it, 0
  %range_stream_end5 = extractvalue %sollang.struct.43 %it, 1
  store i32 %range_stream_start4, ptr %range_stream_context0, align 4
  %range_stream_end_address6 = getelementptr i8, ptr %range_stream_context0, i64 4
  store i32 %range_stream_end5, ptr %range_stream_end_address6, align 4
  %range_stream_done_address7 = getelementptr i8, ptr %range_stream_context0, i64 8
  store i1 false, ptr %range_stream_done_address7, align 1
  %stream_with_context8 = insertvalue %sollang.stream poison, ptr %range_stream_context0, 0
  %stream_with_next9 = insertvalue %sollang.stream %stream_with_context8, ptr @sollang_range_stream_next, 1
  %stream_with_drop10 = insertvalue %sollang.stream %stream_with_next9, ptr @sollang_stream_heap_drop, 2
  ret %sollang.stream %stream_with_drop10
}

define internal %sollang.stream @sollang_fn_zipValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %it, %sollang.stream %arg_0) #0 {
entry:
  %trap_written19 = alloca i32, align 4
  %stream_context0 = extractvalue %sollang.stream %it, 0
  %stream_next1 = extractvalue %sollang.stream %it, 1
  %stream_drop2 = extractvalue %sollang.stream %it, 2
  %stream_context3 = extractvalue %sollang.stream %arg_0, 0
  %stream_next4 = extractvalue %sollang.stream %arg_0, 1
  %stream_drop5 = extractvalue %sollang.stream %arg_0, 2
  %stream_with_context6 = insertvalue %sollang.stream poison, ptr %stream_context0, 0
  %stream_with_next7 = insertvalue %sollang.stream %stream_with_context6, ptr %stream_next1, 1
  %stream_with_drop8 = insertvalue %sollang.stream %stream_with_next7, ptr %stream_drop2, 2
  %product_init9 = insertvalue %sollang.struct.2709 poison, %sollang.stream %stream_with_drop8, 0
  %stream_with_context10 = insertvalue %sollang.stream poison, ptr %stream_context3, 0
  %stream_with_next11 = insertvalue %sollang.stream %stream_with_context10, ptr %stream_next4, 1
  %stream_with_drop12 = insertvalue %sollang.stream %stream_with_next11, ptr %stream_drop5, 2
  %product_init13 = insertvalue %sollang.struct.2709 %product_init9, %sollang.stream %stream_with_drop12, 1
  %stream_join_context_size_pointer14 = getelementptr { %sollang.stream, %sollang.stream }, ptr null, i32 1
  %stream_join_context_size15 = ptrtoint ptr %stream_join_context_size_pointer14 to i64
  %stream_join_context16 = call ptr @sollang_alloc(i64 %stream_join_context_size15)
  %stream_join_context_allocated17 = icmp ne ptr %stream_join_context16, null
  br i1 %stream_join_context_allocated17, label %bb_stream_join_context_alloc_ok0, label %bb_stream_join_context_alloc_fail1

bb_stream_join_context_alloc_fail1:
  %trap_stderr18 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr18, ptr @.slg.str.module.x.1, i32 45, ptr %trap_written19, ptr null)
  call void @llvm.trap()
  unreachable

bb_stream_join_context_alloc_ok0:
  %stream_join_source20 = extractvalue %sollang.struct.2709 %product_init13, 0
  %stream_join_context_input21 = getelementptr { %sollang.stream, %sollang.stream }, ptr %stream_join_context16, i32 0, i32 0
  store %sollang.stream %stream_join_source20, ptr %stream_join_context_input21, align 8
  %stream_join_source22 = extractvalue %sollang.struct.2709 %product_init13, 1
  %stream_join_context_input23 = getelementptr { %sollang.stream, %sollang.stream }, ptr %stream_join_context16, i32 0, i32 1
  store %sollang.stream %stream_join_source22, ptr %stream_join_context_input23, align 8
  %stream_with_context24 = insertvalue %sollang.stream poison, ptr %stream_join_context16, 0
  %stream_with_next25 = insertvalue %sollang.stream %stream_with_context24, ptr @sollang_stream_join_0_next, 1
  %stream_with_drop26 = insertvalue %sollang.stream %stream_with_next25, ptr @sollang_stream_join_0_drop, 2
  ret %sollang.stream %stream_with_drop26
}

define internal %sollang.stream @sollang_fn_concatValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %it, %sollang.stream %arg_0) #0 {
entry:
  %trap_written19 = alloca i32, align 4
  %stream_context0 = extractvalue %sollang.stream %it, 0
  %stream_next1 = extractvalue %sollang.stream %it, 1
  %stream_drop2 = extractvalue %sollang.stream %it, 2
  %stream_context3 = extractvalue %sollang.stream %arg_0, 0
  %stream_next4 = extractvalue %sollang.stream %arg_0, 1
  %stream_drop5 = extractvalue %sollang.stream %arg_0, 2
  %stream_with_context6 = insertvalue %sollang.stream poison, ptr %stream_context0, 0
  %stream_with_next7 = insertvalue %sollang.stream %stream_with_context6, ptr %stream_next1, 1
  %stream_with_drop8 = insertvalue %sollang.stream %stream_with_next7, ptr %stream_drop2, 2
  %product_init9 = insertvalue %sollang.struct.2710 poison, %sollang.stream %stream_with_drop8, 0
  %stream_with_context10 = insertvalue %sollang.stream poison, ptr %stream_context3, 0
  %stream_with_next11 = insertvalue %sollang.stream %stream_with_context10, ptr %stream_next4, 1
  %stream_with_drop12 = insertvalue %sollang.stream %stream_with_next11, ptr %stream_drop5, 2
  %product_init13 = insertvalue %sollang.struct.2710 %product_init9, %sollang.stream %stream_with_drop12, 1
  %stream_join_context_size_pointer14 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr null, i32 1
  %stream_join_context_size15 = ptrtoint ptr %stream_join_context_size_pointer14 to i64
  %stream_join_context16 = call ptr @sollang_alloc(i64 %stream_join_context_size15)
  %stream_join_context_allocated17 = icmp ne ptr %stream_join_context16, null
  br i1 %stream_join_context_allocated17, label %bb_stream_join_context_alloc_ok0, label %bb_stream_join_context_alloc_fail1

bb_stream_join_context_alloc_fail1:
  %trap_stderr18 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr18, ptr @.slg.str.module.x.2, i32 48, ptr %trap_written19, ptr null)
  call void @llvm.trap()
  unreachable

bb_stream_join_context_alloc_ok0:
  %stream_join_source20 = extractvalue %sollang.struct.2710 %product_init13, 0
  %stream_join_context_input21 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %stream_join_context16, i32 0, i32 0
  store %sollang.stream %stream_join_source20, ptr %stream_join_context_input21, align 8
  %stream_join_source22 = extractvalue %sollang.struct.2710 %product_init13, 1
  %stream_join_context_input23 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %stream_join_context16, i32 0, i32 1
  store %sollang.stream %stream_join_source22, ptr %stream_join_context_input23, align 8
  %concat_context_cursor24 = getelementptr { %sollang.stream, %sollang.stream, i32 }, ptr %stream_join_context16, i32 0, i32 2
  store i32 0, ptr %concat_context_cursor24, align 4
  %stream_with_context25 = insertvalue %sollang.stream poison, ptr %stream_join_context16, 0
  %stream_with_next26 = insertvalue %sollang.stream %stream_with_context25, ptr @sollang_stream_join_1_next, 1
  %stream_with_drop27 = insertvalue %sollang.stream %stream_with_next26, ptr @sollang_stream_join_1_drop, 2
  ret %sollang.stream %stream_with_drop27
}

define internal %sollang.event_stream @sollang_fn_mergeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %it, %sollang.stream %arg_0) #0 {
entry:
  %trap_written19 = alloca i32, align 4
  %stream_context0 = extractvalue %sollang.stream %it, 0
  %stream_next1 = extractvalue %sollang.stream %it, 1
  %stream_drop2 = extractvalue %sollang.stream %it, 2
  %stream_context3 = extractvalue %sollang.stream %arg_0, 0
  %stream_next4 = extractvalue %sollang.stream %arg_0, 1
  %stream_drop5 = extractvalue %sollang.stream %arg_0, 2
  %stream_with_context6 = insertvalue %sollang.stream poison, ptr %stream_context0, 0
  %stream_with_next7 = insertvalue %sollang.stream %stream_with_context6, ptr %stream_next1, 1
  %stream_with_drop8 = insertvalue %sollang.stream %stream_with_next7, ptr %stream_drop2, 2
  %product_init9 = insertvalue %sollang.struct.2710 poison, %sollang.stream %stream_with_drop8, 0
  %stream_with_context10 = insertvalue %sollang.stream poison, ptr %stream_context3, 0
  %stream_with_next11 = insertvalue %sollang.stream %stream_with_context10, ptr %stream_next4, 1
  %stream_with_drop12 = insertvalue %sollang.stream %stream_with_next11, ptr %stream_drop5, 2
  %product_init13 = insertvalue %sollang.struct.2710 %product_init9, %sollang.stream %stream_with_drop12, 1
  %stream_join_context_size_pointer14 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr null, i32 1
  %stream_join_context_size15 = ptrtoint ptr %stream_join_context_size_pointer14 to i64
  %stream_join_context16 = call ptr @sollang_alloc(i64 %stream_join_context_size15)
  %stream_join_context_allocated17 = icmp ne ptr %stream_join_context16, null
  br i1 %stream_join_context_allocated17, label %bb_stream_join_context_alloc_ok0, label %bb_stream_join_context_alloc_fail1

bb_stream_join_context_alloc_fail1:
  %trap_stderr18 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr18, ptr @.slg.str.module.x.3, i32 47, ptr %trap_written19, ptr null)
  call void @llvm.trap()
  unreachable

bb_stream_join_context_alloc_ok0:
  %stream_join_source20 = extractvalue %sollang.struct.2710 %product_init13, 0
  %stream_join_context_input21 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %stream_join_context16, i32 0, i32 0
  store %sollang.stream %stream_join_source20, ptr %stream_join_context_input21, align 8
  %stream_join_source22 = extractvalue %sollang.struct.2710 %product_init13, 1
  %stream_join_context_input23 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %stream_join_context16, i32 0, i32 1
  store %sollang.stream %stream_join_source22, ptr %stream_join_context_input23, align 8
  %concat_context_cursor24 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %stream_join_context16, i32 0, i32 2
  store i32 0, ptr %concat_context_cursor24, align 4
  %stream_join_context_active25 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %stream_join_context16, i32 0, i32 3, i32 0
  store i1 true, ptr %stream_join_context_active25, align 1
  %stream_join_context_active26 = getelementptr { %sollang.stream, %sollang.stream, i32, [2 x i1] }, ptr %stream_join_context16, i32 0, i32 3, i32 1
  store i1 true, ptr %stream_join_context_active26, align 1
  %stream_with_context27 = insertvalue %sollang.event_stream poison, ptr %stream_join_context16, 0
  %stream_with_next28 = insertvalue %sollang.event_stream %stream_with_context27, ptr @sollang_stream_join_2_next, 1
  %stream_with_drop29 = insertvalue %sollang.event_stream %stream_with_next28, ptr @sollang_stream_join_2_drop, 2
  ret %sollang.event_stream %stream_with_drop29
}

define internal %sollang.event_stream @sollang_fn_latestValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %it, %sollang.stream %arg_0) #0 {
entry:
  %trap_written19 = alloca i32, align 4
  %stream_context0 = extractvalue %sollang.stream %it, 0
  %stream_next1 = extractvalue %sollang.stream %it, 1
  %stream_drop2 = extractvalue %sollang.stream %it, 2
  %stream_context3 = extractvalue %sollang.stream %arg_0, 0
  %stream_next4 = extractvalue %sollang.stream %arg_0, 1
  %stream_drop5 = extractvalue %sollang.stream %arg_0, 2
  %stream_with_context6 = insertvalue %sollang.stream poison, ptr %stream_context0, 0
  %stream_with_next7 = insertvalue %sollang.stream %stream_with_context6, ptr %stream_next1, 1
  %stream_with_drop8 = insertvalue %sollang.stream %stream_with_next7, ptr %stream_drop2, 2
  %product_init9 = insertvalue %sollang.struct.2709 poison, %sollang.stream %stream_with_drop8, 0
  %stream_with_context10 = insertvalue %sollang.stream poison, ptr %stream_context3, 0
  %stream_with_next11 = insertvalue %sollang.stream %stream_with_context10, ptr %stream_next4, 1
  %stream_with_drop12 = insertvalue %sollang.stream %stream_with_next11, ptr %stream_drop5, 2
  %product_init13 = insertvalue %sollang.struct.2709 %product_init9, %sollang.stream %stream_with_drop12, 1
  %stream_join_context_size_pointer14 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr null, i32 1
  %stream_join_context_size15 = ptrtoint ptr %stream_join_context_size_pointer14 to i64
  %stream_join_context16 = call ptr @sollang_alloc(i64 %stream_join_context_size15)
  %stream_join_context_allocated17 = icmp ne ptr %stream_join_context16, null
  br i1 %stream_join_context_allocated17, label %bb_stream_join_context_alloc_ok0, label %bb_stream_join_context_alloc_fail1

bb_stream_join_context_alloc_fail1:
  %trap_stderr18 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr18, ptr @.slg.str.module.x.4, i32 48, ptr %trap_written19, ptr null)
  call void @llvm.trap()
  unreachable

bb_stream_join_context_alloc_ok0:
  %stream_join_source20 = extractvalue %sollang.struct.2709 %product_init13, 0
  %stream_join_context_input21 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %stream_join_context16, i32 0, i32 0
  store %sollang.stream %stream_join_source20, ptr %stream_join_context_input21, align 8
  %stream_join_source22 = extractvalue %sollang.struct.2709 %product_init13, 1
  %stream_join_context_input23 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %stream_join_context16, i32 0, i32 1
  store %sollang.stream %stream_join_source22, ptr %stream_join_context_input23, align 8
  %concat_context_cursor24 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %stream_join_context16, i32 0, i32 2
  store i32 0, ptr %concat_context_cursor24, align 4
  %latest_context_initialized25 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %stream_join_context16, i32 0, i32 3
  store i1 false, ptr %latest_context_initialized25, align 1
  %stream_join_context_active26 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %stream_join_context16, i32 0, i32 4, i32 0
  store i1 true, ptr %stream_join_context_active26, align 1
  %stream_join_context_active27 = getelementptr { %sollang.stream, %sollang.stream, i32, i1, [2 x i1], i32, i32 }, ptr %stream_join_context16, i32 0, i32 4, i32 1
  store i1 true, ptr %stream_join_context_active27, align 1
  %stream_with_context28 = insertvalue %sollang.event_stream poison, ptr %stream_join_context16, 0
  %stream_with_next29 = insertvalue %sollang.event_stream %stream_with_context28, ptr @sollang_stream_join_3_next, 1
  %stream_with_drop30 = insertvalue %sollang.event_stream %stream_with_next29, ptr @sollang_stream_join_3_drop, 2
  ret %sollang.event_stream %stream_with_drop30
}

@.slg.str.suffix.0 = private unnamed_addr constant [1 x i8] c":", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.2 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.3 = private unnamed_addr constant [1 x i8] c"m", align 1
@.slg.str.suffix.4 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.5 = private unnamed_addr constant [1 x i8] c"l", align 1
@.slg.str.suffix.6 = private unnamed_addr constant [1 x i8] c":", align 1
@.slg.str.suffix.7 = private unnamed_addr constant [1 x i8] c"\0A", align 1
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

define internal i32 @sollang_mouse_event_worker(ptr %context) #0 {
entry:
  %input = load ptr, ptr %context, align 8
  %record = alloca [20 x i8], align 4
  %read = alloca i32, align 4
  br label %wait

wait:
  %cancel_address = getelementptr i8, ptr %context, i64 32
  %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
  %active = icmp eq i32 %cancelled, 0
  br i1 %active, label %read_input, label %done

read_input:
  %ok = call i32 @ReadConsoleInputW(ptr %input, ptr %record, i32 1, ptr %read)
  %read_ok = icmp ne i32 %ok, 0
  br i1 %read_ok, label %inspect, label %closed

inspect:
  %event_type = load i16, ptr %record, align 2
  %is_mouse = icmp eq i16 %event_type, 2
  br i1 %is_mouse, label %mouse, label %wait

mouse:
  %x_slot = getelementptr i8, ptr %record, i64 4
  %x16 = load i16, ptr %x_slot, align 2
  %x = sext i16 %x16 to i32
  %y_slot = getelementptr i8, ptr %record, i64 6
  %y16 = load i16, ptr %y_slot, align 2
  %y = sext i16 %y16 to i32
  %buttons_address = getelementptr i8, ptr %record, i64 8
  %buttons = load i32, ptr %buttons_address, align 4
  %flags_address = getelementptr i8, ptr %record, i64 16
  %flags = load i32, ptr %flags_address, align 4
  %wheel_bits = and i32 %flags, 12
  %is_wheel = icmp ne i32 %wheel_bits, 0
  br i1 %is_wheel, label %wheel, label %non_wheel

wheel:
  %wheel_delta = ashr i32 %buttons, 16
  br label %enqueue

non_wheel:
  %previous_address = getelementptr i8, ptr %context, i64 64
  %previous = load i32, ptr %previous_address, align 4
  %changed = xor i32 %previous, %buttons
  store i32 %buttons, ptr %previous_address, align 4
  %has_change = icmp ne i32 %changed, 0
  br i1 %has_change, label %button_change, label %move

button_change:
  %changed0 = and i32 %changed, 1
  %is0 = icmp ne i32 %changed0, 0
  %changed1 = and i32 %changed, 4
  %is1 = icmp ne i32 %changed1, 0
  %changed2 = and i32 %changed, 2
  %is2 = icmp ne i32 %changed2, 0
  %button12 = select i1 %is2, i32 2, i32 3
  %button1 = select i1 %is1, i32 1, i32 %button12
  %button_index = select i1 %is0, i32 0, i32 %button1
  %pressed_bits = and i32 %buttons, %changed
  %pressed = icmp ne i32 %pressed_bits, 0
  %button_kind = select i1 %pressed, i32 1, i32 2
  br label %enqueue

move:
  br label %enqueue

enqueue:
  %delta = phi i32 [ %wheel_delta, %wheel ], [ 0, %button_change ], [ 0, %move ]
  %button = phi i32 [ -1, %wheel ], [ %button_index, %button_change ], [ -1, %move ]
  %kind = phi i32 [ 3, %wheel ], [ %button_kind, %button_change ], [ 0, %move ]
  br label %queue_lock

queue_lock:
  %lock_address = getelementptr i8, ptr %context, i64 68
  %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
  %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
  br i1 %lock_acquired, label %queue_state, label %queue_lock

queue_state:
  %capacity_address = getelementptr i8, ptr %context, i64 12
  %capacity = load i32, ptr %capacity_address, align 4
  %head_address = getelementptr i8, ptr %context, i64 20
  %head = load i32, ptr %head_address, align 4
  %tail_address = getelementptr i8, ptr %context, i64 24
  %tail = load i32, ptr %tail_address, align 4
  %count_address = getelementptr i8, ptr %context, i64 28
  %count = load i32, ptr %count_address, align 4
  %full = icmp uge i32 %count, %capacity
  br i1 %full, label %overflow, label %write

overflow:
  %policy_address = getelementptr i8, ptr %context, i64 16
  %policy = load i32, ptr %policy_address, align 4
  %drop_newest = icmp eq i32 %policy, 0
  br i1 %drop_newest, label %unlock_drop, label %not_drop_newest

not_drop_newest:
  %coalesce = icmp eq i32 %policy, 2
  %is_move = icmp eq i32 %kind, 0
  %coalesce_move = and i1 %coalesce, %is_move
  br i1 %coalesce_move, label %replace_move_check, label %drop_oldest

replace_move_check:
  %last_tail_unwrapped = add i32 %tail, %capacity
  %last_tail = sub i32 %last_tail_unwrapped, 1
  %last_index = urem i32 %last_tail, %capacity
  %last_index64 = zext i32 %last_index to i64
  %last_offset = mul i64 %last_index64, 20
  %buffer_address0 = getelementptr i8, ptr %context, i64 56
  %buffer0 = load ptr, ptr %buffer_address0, align 8
  %last_record = getelementptr i8, ptr %buffer0, i64 %last_offset
  %last_kind_address = getelementptr i8, ptr %last_record, i64 16
  %last_kind = load i32, ptr %last_kind_address, align 4
  %last_is_move = icmp eq i32 %last_kind, 0
  br i1 %last_is_move, label %replace_move, label %unlock_drop

replace_move:
  store i32 %x, ptr %last_record, align 4
  %last_y = getelementptr i8, ptr %last_record, i64 4
  store i32 %y, ptr %last_y, align 4
  br label %signal

drop_oldest:
  %next_head_unwrapped = add i32 %head, 1
  %next_head = urem i32 %next_head_unwrapped, %capacity
  store i32 %next_head, ptr %head_address, align 4
  %reduced_count = sub i32 %count, 1
  store i32 %reduced_count, ptr %count_address, align 4
  br label %write

write:
  %index64 = zext i32 %tail to i64
  %offset = mul i64 %index64, 20
  %buffer_address = getelementptr i8, ptr %context, i64 56
  %buffer = load ptr, ptr %buffer_address, align 8
  %slot = getelementptr i8, ptr %buffer, i64 %offset
  store i32 %x, ptr %slot, align 4
  %slot_y = getelementptr i8, ptr %slot, i64 4
  store i32 %y, ptr %slot_y, align 4
  %slot_delta = getelementptr i8, ptr %slot, i64 8
  store i32 %delta, ptr %slot_delta, align 4
  %slot_button = getelementptr i8, ptr %slot, i64 12
  store i32 %button, ptr %slot_button, align 4
  %slot_kind = getelementptr i8, ptr %slot, i64 16
  store i32 %kind, ptr %slot_kind, align 4
  %next_tail_unwrapped = add i32 %tail, 1
  %next_tail = urem i32 %next_tail_unwrapped, %capacity
  store i32 %next_tail, ptr %tail_address, align 4
  %current_count = load i32, ptr %count_address, align 4
  %next_count = add i32 %current_count, 1
  store i32 %next_count, ptr %count_address, align 4
  br label %signal

unlock_drop:
  store atomic i32 0, ptr %lock_address release, align 4
  br label %wait

signal:
  store atomic i32 0, ptr %lock_address release, align 4
  %event_address = getelementptr i8, ptr %context, i64 48
  %event = load ptr, ptr %event_address, align 8
  %signalled = call i32 @SetEvent(ptr %event)
  br label %wait

closed:
  store atomic i32 1, ptr %cancel_address release, align 4
  %closed_event_address = getelementptr i8, ptr %context, i64 48
  %closed_event = load ptr, ptr %closed_event_address, align 8
  %closed_signalled = call i32 @SetEvent(ptr %closed_event)
  br label %done

done:
  ret i32 0
}

define internal ptr @sollang_mouse_event_stream_create(i32 %requested_capacity, i32 %overflow) #0 {
entry:
  %capacity_low = icmp slt i32 %requested_capacity, 2
  %capacity_high = icmp sgt i32 %requested_capacity, 65536
  %capacity_invalid = or i1 %capacity_low, %capacity_high
  %overflow_invalid = icmp ugt i32 %overflow, 2
  %invalid = or i1 %capacity_invalid, %overflow_invalid
  br i1 %invalid, label %fail, label %input_handle

input_handle:
  %input = call ptr @GetStdHandle(i32 -10)
  %valid = icmp ne ptr %input, inttoptr (i64 -1 to ptr)
  br i1 %valid, label %mode, label %fail

mode:
  %original_address = alloca i32, align 4
  %got_mode = call i32 @GetConsoleMode(ptr %input, ptr %original_address)
  %mode_ok = icmp ne i32 %got_mode, 0
  br i1 %mode_ok, label %allocate_context, label %fail

allocate_context:
  %context = call ptr @sollang_alloc(i64 80)
  %allocated = icmp ne ptr %context, null
  br i1 %allocated, label %allocate_buffer, label %fail

allocate_buffer:
  %capacity64 = zext i32 %requested_capacity to i64
  %buffer_bytes = mul i64 %capacity64, 20
  %buffer = call ptr @sollang_alloc(i64 %buffer_bytes)
  %buffer_allocated = icmp ne ptr %buffer, null
  br i1 %buffer_allocated, label %create_event, label %free_context

create_event:
  %event = call ptr @CreateEventA(ptr null, i32 0, i32 0, ptr null)
  %event_ok = icmp ne ptr %event, null
  br i1 %event_ok, label %initialize, label %free_buffer

initialize:
  %original = load i32, ptr %original_address, align 4
  %with_mouse = or i32 %original, 144
  %interactive = and i32 %with_mouse, -65
  %enabled = call i32 @SetConsoleMode(ptr %input, i32 %interactive)
  %enabled_ok = icmp ne i32 %enabled, 0
  br i1 %enabled_ok, label %initialize_context, label %close_event

initialize_context:
  store ptr %input, ptr %context, align 8
  %mode_slot = getelementptr i8, ptr %context, i64 8
  store i32 %original, ptr %mode_slot, align 4
  %capacity_slot = getelementptr i8, ptr %context, i64 12
  store i32 %requested_capacity, ptr %capacity_slot, align 4
  %overflow_slot = getelementptr i8, ptr %context, i64 16
  store i32 %overflow, ptr %overflow_slot, align 4
  %head_slot = getelementptr i8, ptr %context, i64 20
  store i32 0, ptr %head_slot, align 4
  %tail_slot = getelementptr i8, ptr %context, i64 24
  store i32 0, ptr %tail_slot, align 4
  %count_slot = getelementptr i8, ptr %context, i64 28
  store i32 0, ptr %count_slot, align 4
  %cancel_slot = getelementptr i8, ptr %context, i64 32
  store atomic i32 0, ptr %cancel_slot release, align 4
  %event_slot = getelementptr i8, ptr %context, i64 48
  store ptr %event, ptr %event_slot, align 8
  %buffer_slot = getelementptr i8, ptr %context, i64 56
  store ptr %buffer, ptr %buffer_slot, align 8
  %buttons_slot = getelementptr i8, ptr %context, i64 64
  store i32 0, ptr %buttons_slot, align 4
  %lock_slot = getelementptr i8, ptr %context, i64 68
  store atomic i32 0, ptr %lock_slot release, align 4
  %thread = call ptr @CreateThread(ptr null, i64 0, ptr @sollang_mouse_event_worker, ptr %context, i32 0, ptr null)
  %thread_ok = icmp ne ptr %thread, null
  br i1 %thread_ok, label %ready, label %restore

ready:
  %thread_slot = getelementptr i8, ptr %context, i64 40
  store ptr %thread, ptr %thread_slot, align 8
  ret ptr %context

restore:
  %restored_after_thread = call i32 @SetConsoleMode(ptr %input, i32 %original)
  br label %close_event

close_event:
  %event_closed = call i32 @CloseHandle(ptr %event)
  br label %free_buffer

free_buffer:
  call void @sollang_free(ptr %buffer)
  br label %free_context

free_context:
  call void @sollang_free(ptr %context)
  br label %fail

fail:
  ret ptr null
}

define internal i1 @sollang_mouse_event_next_raw(ptr %context, ptr %x, ptr %y, ptr %delta, ptr %button, ptr %kind) #0 {
entry:
  br label %queue_lock

queue_lock:
  %lock_address = getelementptr i8, ptr %context, i64 68
  %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
  %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
  br i1 %lock_acquired, label %poll, label %queue_lock

poll:
  %count_address = getelementptr i8, ptr %context, i64 28
  %count = load i32, ptr %count_address, align 4
  %available = icmp ugt i32 %count, 0
  br i1 %available, label %read, label %unlock_empty

unlock_empty:
  store atomic i32 0, ptr %lock_address release, align 4
  br label %empty

empty:
  %cancel_address = getelementptr i8, ptr %context, i64 32
  %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
  %active = icmp eq i32 %cancelled, 0
  br i1 %active, label %wait, label %closed

wait:
  %event_address = getelementptr i8, ptr %context, i64 48
  %event = load ptr, ptr %event_address, align 8
  %waited = call i32 @WaitForSingleObject(ptr %event, i32 -1)
  br label %queue_lock

read:
  %capacity_address = getelementptr i8, ptr %context, i64 12
  %capacity = load i32, ptr %capacity_address, align 4
  %head_address = getelementptr i8, ptr %context, i64 20
  %head = load i32, ptr %head_address, align 4
  %index64 = zext i32 %head to i64
  %offset = mul i64 %index64, 20
  %buffer_address = getelementptr i8, ptr %context, i64 56
  %buffer = load ptr, ptr %buffer_address, align 8
  %slot = getelementptr i8, ptr %buffer, i64 %offset
  %x_value = load i32, ptr %slot, align 4
  store i32 %x_value, ptr %x, align 4
  %slot_y = getelementptr i8, ptr %slot, i64 4
  %y_value = load i32, ptr %slot_y, align 4
  store i32 %y_value, ptr %y, align 4
  %slot_delta = getelementptr i8, ptr %slot, i64 8
  %delta_value = load i32, ptr %slot_delta, align 4
  store i32 %delta_value, ptr %delta, align 4
  %slot_button = getelementptr i8, ptr %slot, i64 12
  %button_value = load i32, ptr %slot_button, align 4
  store i32 %button_value, ptr %button, align 4
  %slot_kind = getelementptr i8, ptr %slot, i64 16
  %kind_value = load i32, ptr %slot_kind, align 4
  store i32 %kind_value, ptr %kind, align 4
  %next_head_unwrapped = add i32 %head, 1
  %next_head = urem i32 %next_head_unwrapped, %capacity
  store i32 %next_head, ptr %head_address, align 4
  %next_count = sub i32 %count, 1
  store i32 %next_count, ptr %count_address, align 4
  store atomic i32 0, ptr %lock_address release, align 4
  ret i1 true

closed:
  ret i1 false
}

define internal void @sollang_mouse_event_stream_drop(ptr %context, i1 %destroy) #0 {
entry:
  %cancel_address = getelementptr i8, ptr %context, i64 32
  store atomic i32 1, ptr %cancel_address release, align 4
  %thread_address = getelementptr i8, ptr %context, i64 40
  %thread = load ptr, ptr %thread_address, align 8
  %cancelled = call i32 @CancelSynchronousIo(ptr %thread)
  %event_address = getelementptr i8, ptr %context, i64 48
  %event = load ptr, ptr %event_address, align 8
  %signalled = call i32 @SetEvent(ptr %event)
  br i1 %destroy, label %join_worker, label %cancelled_only

cancelled_only:
  ret void

join_worker:
  %cancel_pending = call i32 @CancelSynchronousIo(ptr %thread)
  %joined = call i32 @WaitForSingleObject(ptr %thread, i32 1)
  switch i32 %joined, label %join_failed [
    i32 0, label %cleanup
    i32 258, label %join_worker
  ]

join_failed:
  call void @llvm.trap()
  unreachable

cleanup:
  %thread_closed = call i32 @CloseHandle(ptr %thread)
  %event_closed = call i32 @CloseHandle(ptr %event)
  %input = load ptr, ptr %context, align 8
  %mode_slot = getelementptr i8, ptr %context, i64 8
  %original = load i32, ptr %mode_slot, align 4
  %restored = call i32 @SetConsoleMode(ptr %input, i32 %original)
  %buffer_address = getelementptr i8, ptr %context, i64 56
  %buffer = load ptr, ptr %buffer_address, align 8
  call void @sollang_free(ptr %buffer)
  call void @sollang_free(ptr %context)
  ret void
}

define internal i1 @sollang_mouse_event_stream_next(ptr %context, ptr %output) #0 {
entry:
  %x = alloca i32, align 4
  %y = alloca i32, align 4
  %delta = alloca i32, align 4
  %button = alloca i32, align 4
  %kind = alloca i32, align 4
  %available = call i1 @sollang_mouse_event_next_raw(ptr %context, ptr %x, ptr %y, ptr %delta, ptr %button, ptr %kind)
  br i1 %available, label %write, label %done

write:
  %x_value = load i32, ptr %x, align 4
  %y_value = load i32, ptr %y, align 4
  %delta_value = load i32, ptr %delta, align 4
  %button_value = load i32, ptr %button, align 4
  %kind_value = load i32, ptr %kind, align 4
  %x_address = getelementptr %sollang.struct.44, ptr %output, i32 0, i32 0
  store i32 %x_value, ptr %x_address, align 4
  %y_address = getelementptr %sollang.struct.44, ptr %output, i32 0, i32 1
  store i32 %y_value, ptr %y_address, align 4
  %delta_address = getelementptr %sollang.struct.44, ptr %output, i32 0, i32 2
  store i32 %delta_value, ptr %delta_address, align 4
  %button_address = getelementptr %sollang.struct.44, ptr %output, i32 0, i32 3
  store i32 %button_value, ptr %button_address, align 4
  %kind0 = insertvalue %sollang.enum.45 poison, i32 %kind_value, 0
  %kind1 = insertvalue %sollang.enum.45 %kind0, [0 x i64] zeroinitializer, 1
  %kind_address = getelementptr %sollang.struct.44, ptr %output, i32 0, i32 4
  store %sollang.enum.45 %kind1, ptr %kind_address, align 8
  ret i1 true

done:
  ret i1 false
}

define internal i1 @sollang_range_stream_next(ptr %context, ptr %output) #0 {
entry:
  %done_address = getelementptr i8, ptr %context, i64 8
  %done = load i1, ptr %done_address, align 1
  br i1 %done, label %finished, label %active

active:
  %current = load i32, ptr %context, align 4
  %end_address = getelementptr i8, ptr %context, i64 4
  %end = load i32, ptr %end_address, align 4
  %past_end = icmp sgt i32 %current, %end
  br i1 %past_end, label %mark_finished, label %yield

yield:
  store i32 %current, ptr %output, align 4
  %is_last = icmp eq i32 %current, %end
  br i1 %is_last, label %mark_finished_after_yield, label %advance

advance:
  %next = add i32 %current, 1
  store i32 %next, ptr %context, align 4
  ret i1 true

mark_finished_after_yield:
  store i1 true, ptr %done_address, align 1
  ret i1 true

mark_finished:
  store i1 true, ptr %done_address, align 1
  ret i1 false

finished:
  ret i1 false
}

define internal void @sollang_stream_heap_drop(ptr %context, i1 %destroy) #0 {
entry:
  br i1 %destroy, label %release, label %done
release:
  call void @sollang_free(ptr %context)
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
  %written = alloca i32, align 4
  %read = alloca i32, align 4
  %ok_state = alloca i1, align 1
  %stream_cancelled22 = alloca i1, align 1
  %stream_element_address23 = alloca %sollang.struct.2651, align 4
  %stream_cancelled70 = alloca i1, align 1
  %stream_element_address71 = alloca i32, align 4
  %stream_cancelled107 = alloca i1, align 1
  %stream_element_address108 = alloca i32, align 4
  %stream_cancelled148 = alloca i1, align 1
  %stream_element_address149 = alloca %sollang.struct.2651, align 4
  store i1 true, ptr %ok_state, align 1
  %stdin = call ptr @GetStdHandle(i32 -10)
  %stdout = call ptr @GetStdHandle(i32 -11)
  %stdout_mode = alloca i32, align 4
  %stdout_is_console_status = call i32 @GetConsoleMode(ptr %stdout, ptr %stdout_mode)
  %stdout_is_console = icmp ne i32 %stdout_is_console_status, 0
  store i1 %stdout_is_console, ptr @sollang_stdout_line_buffered, align 1
  %range0 = insertvalue %sollang.struct.43 poison, i32 1, 0
  %range1 = insertvalue %sollang.struct.43 %range0, i32 2, 1
  %struct_call2 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range1)
  %stream_context3 = extractvalue %sollang.stream %struct_call2, 0
  %stream_next4 = extractvalue %sollang.stream %struct_call2, 1
  %stream_drop5 = extractvalue %sollang.stream %struct_call2, 2
  %range6 = insertvalue %sollang.struct.43 poison, i32 10, 0
  %range7 = insertvalue %sollang.struct.43 %range6, i32 11, 1
  %struct_call8 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range7)
  %stream_context9 = extractvalue %sollang.stream %struct_call8, 0
  %stream_next10 = extractvalue %sollang.stream %struct_call8, 1
  %stream_drop11 = extractvalue %sollang.stream %struct_call8, 2
  %stream_with_context13 = insertvalue %sollang.stream poison, ptr %stream_context3, 0
  %stream_with_next14 = insertvalue %sollang.stream %stream_with_context13, ptr %stream_next4, 1
  %stream_with_drop15 = insertvalue %sollang.stream %stream_with_next14, ptr %stream_drop5, 2
  %stream_with_context16 = insertvalue %sollang.stream poison, ptr %stream_context9, 0
  %stream_with_next17 = insertvalue %sollang.stream %stream_with_context16, ptr %stream_next10, 1
  %stream_with_drop18 = insertvalue %sollang.stream %stream_with_next17, ptr %stream_drop11, 2
  %struct_call12 = call %sollang.stream @sollang_fn_zipValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %stream_with_drop15, %sollang.stream %stream_with_drop18)
  %stream_context19 = extractvalue %sollang.stream %struct_call12, 0
  %stream_next20 = extractvalue %sollang.stream %struct_call12, 1
  %stream_drop21 = extractvalue %sollang.stream %struct_call12, 2
  store i1 false, ptr %stream_cancelled22, align 1
  br label %bb_stream_next0

bb_stream_next0:
  %stream_has_value24 = call i1 %stream_next20(ptr %stream_context19, ptr %stream_element_address23)
  br i1 %stream_has_value24, label %bb_stream_value1, label %bb_stream_done3

bb_stream_value1:
  %stream_element25 = load %sollang.struct.2651, ptr %stream_element_address23, align 4
  %field26 = extractvalue %sollang.struct.2651 %stream_element25, 0
  %print_integer27 = sext i32 %field26 to i64
  %write28 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer27, ptr %written)
  %is_ok29 = icmp ne i32 %write28, 0
  %previous_ok30 = load i1, ptr %ok_state, align 1
  %ok31 = and i1 %previous_ok30, %is_ok29
  store i1 %ok31, ptr %ok_state, align 1
  %write32 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.0, i64 1, ptr %written)
  %is_ok33 = icmp ne i32 %write32, 0
  %previous_ok34 = load i1, ptr %ok_state, align 1
  %ok35 = and i1 %previous_ok34, %is_ok33
  store i1 %ok35, ptr %ok_state, align 1
  %field36 = extractvalue %sollang.struct.2651 %stream_element25, 1
  %print_integer37 = sext i32 %field36 to i64
  %write38 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer37, ptr %written)
  %is_ok39 = icmp ne i32 %write38, 0
  %previous_ok40 = load i1, ptr %ok_state, align 1
  %ok41 = and i1 %previous_ok40, %is_ok39
  store i1 %ok41, ptr %ok_state, align 1
  %write42 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.1, i64 1, ptr %written)
  %is_ok43 = icmp ne i32 %write42, 0
  %previous_ok44 = load i1, ptr %ok_state, align 1
  %ok45 = and i1 %previous_ok44, %is_ok43
  store i1 %ok45, ptr %ok_state, align 1
  br label %bb_stream_continue2

bb_stream_continue2:
  %stream_cancelled46 = load i1, ptr %stream_cancelled22, align 1
  br i1 %stream_cancelled46, label %bb_stream_done3, label %bb_stream_next0

bb_stream_done3:
  %stream_has_drop47 = icmp ne ptr %stream_drop21, null
  br i1 %stream_has_drop47, label %bb_stream_drop4, label %bb_stream_drop_done5

bb_stream_drop4:
  call void %stream_drop21(ptr %stream_context19, i1 true)
  br label %bb_stream_drop_done5

bb_stream_drop_done5:
  %range48 = insertvalue %sollang.struct.43 poison, i32 3, 0
  %range49 = insertvalue %sollang.struct.43 %range48, i32 4, 1
  %struct_call50 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range49)
  %stream_context51 = extractvalue %sollang.stream %struct_call50, 0
  %stream_next52 = extractvalue %sollang.stream %struct_call50, 1
  %stream_drop53 = extractvalue %sollang.stream %struct_call50, 2
  %range54 = insertvalue %sollang.struct.43 poison, i32 5, 0
  %range55 = insertvalue %sollang.struct.43 %range54, i32 6, 1
  %struct_call56 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range55)
  %stream_context57 = extractvalue %sollang.stream %struct_call56, 0
  %stream_next58 = extractvalue %sollang.stream %struct_call56, 1
  %stream_drop59 = extractvalue %sollang.stream %struct_call56, 2
  %stream_with_context61 = insertvalue %sollang.stream poison, ptr %stream_context51, 0
  %stream_with_next62 = insertvalue %sollang.stream %stream_with_context61, ptr %stream_next52, 1
  %stream_with_drop63 = insertvalue %sollang.stream %stream_with_next62, ptr %stream_drop53, 2
  %stream_with_context64 = insertvalue %sollang.stream poison, ptr %stream_context57, 0
  %stream_with_next65 = insertvalue %sollang.stream %stream_with_context64, ptr %stream_next58, 1
  %stream_with_drop66 = insertvalue %sollang.stream %stream_with_next65, ptr %stream_drop59, 2
  %struct_call60 = call %sollang.stream @sollang_fn_concatValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %stream_with_drop63, %sollang.stream %stream_with_drop66)
  %stream_context67 = extractvalue %sollang.stream %struct_call60, 0
  %stream_next68 = extractvalue %sollang.stream %struct_call60, 1
  %stream_drop69 = extractvalue %sollang.stream %struct_call60, 2
  store i1 false, ptr %stream_cancelled70, align 1
  br label %bb_stream_next6

bb_stream_next6:
  %stream_has_value72 = call i1 %stream_next68(ptr %stream_context67, ptr %stream_element_address71)
  br i1 %stream_has_value72, label %bb_stream_value7, label %bb_stream_done9

bb_stream_value7:
  %stream_element73 = load i32, ptr %stream_element_address71, align 4
  %print_integer74 = sext i32 %stream_element73 to i64
  %write75 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer74, ptr %written)
  %is_ok76 = icmp ne i32 %write75, 0
  %previous_ok77 = load i1, ptr %ok_state, align 1
  %ok78 = and i1 %previous_ok77, %is_ok76
  store i1 %ok78, ptr %ok_state, align 1
  %write79 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.2, i64 1, ptr %written)
  %is_ok80 = icmp ne i32 %write79, 0
  %previous_ok81 = load i1, ptr %ok_state, align 1
  %ok82 = and i1 %previous_ok81, %is_ok80
  store i1 %ok82, ptr %ok_state, align 1
  br label %bb_stream_continue8

bb_stream_continue8:
  %stream_cancelled83 = load i1, ptr %stream_cancelled70, align 1
  br i1 %stream_cancelled83, label %bb_stream_done9, label %bb_stream_next6

bb_stream_done9:
  %stream_has_drop84 = icmp ne ptr %stream_drop69, null
  br i1 %stream_has_drop84, label %bb_stream_drop10, label %bb_stream_drop_done11

bb_stream_drop10:
  call void %stream_drop69(ptr %stream_context67, i1 true)
  br label %bb_stream_drop_done11

bb_stream_drop_done11:
  %range85 = insertvalue %sollang.struct.43 poison, i32 7, 0
  %range86 = insertvalue %sollang.struct.43 %range85, i32 8, 1
  %struct_call87 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range86)
  %stream_context88 = extractvalue %sollang.stream %struct_call87, 0
  %stream_next89 = extractvalue %sollang.stream %struct_call87, 1
  %stream_drop90 = extractvalue %sollang.stream %struct_call87, 2
  %range91 = insertvalue %sollang.struct.43 poison, i32 9, 0
  %range92 = insertvalue %sollang.struct.43 %range91, i32 10, 1
  %struct_call93 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range92)
  %stream_context94 = extractvalue %sollang.stream %struct_call93, 0
  %stream_next95 = extractvalue %sollang.stream %struct_call93, 1
  %stream_drop96 = extractvalue %sollang.stream %struct_call93, 2
  %stream_with_context98 = insertvalue %sollang.stream poison, ptr %stream_context88, 0
  %stream_with_next99 = insertvalue %sollang.stream %stream_with_context98, ptr %stream_next89, 1
  %stream_with_drop100 = insertvalue %sollang.stream %stream_with_next99, ptr %stream_drop90, 2
  %stream_with_context101 = insertvalue %sollang.stream poison, ptr %stream_context94, 0
  %stream_with_next102 = insertvalue %sollang.stream %stream_with_context101, ptr %stream_next95, 1
  %stream_with_drop103 = insertvalue %sollang.stream %stream_with_next102, ptr %stream_drop96, 2
  %struct_call97 = call %sollang.event_stream @sollang_fn_mergeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %stream_with_drop100, %sollang.stream %stream_with_drop103)
  %stream_context104 = extractvalue %sollang.event_stream %struct_call97, 0
  %stream_next105 = extractvalue %sollang.event_stream %struct_call97, 1
  %stream_drop106 = extractvalue %sollang.event_stream %struct_call97, 2
  store i1 false, ptr %stream_cancelled107, align 1
  br label %bb_stream_next12

bb_stream_next12:
  %stream_has_value109 = call i1 %stream_next105(ptr %stream_context104, ptr %stream_element_address108)
  br i1 %stream_has_value109, label %bb_stream_value13, label %bb_stream_done15

bb_stream_value13:
  %stream_element110 = load i32, ptr %stream_element_address108, align 4
  %write111 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.3, i64 1, ptr %written)
  %is_ok112 = icmp ne i32 %write111, 0
  %previous_ok113 = load i1, ptr %ok_state, align 1
  %ok114 = and i1 %previous_ok113, %is_ok112
  store i1 %ok114, ptr %ok_state, align 1
  %print_integer115 = sext i32 %stream_element110 to i64
  %write116 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer115, ptr %written)
  %is_ok117 = icmp ne i32 %write116, 0
  %previous_ok118 = load i1, ptr %ok_state, align 1
  %ok119 = and i1 %previous_ok118, %is_ok117
  store i1 %ok119, ptr %ok_state, align 1
  %write120 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.4, i64 1, ptr %written)
  %is_ok121 = icmp ne i32 %write120, 0
  %previous_ok122 = load i1, ptr %ok_state, align 1
  %ok123 = and i1 %previous_ok122, %is_ok121
  store i1 %ok123, ptr %ok_state, align 1
  br label %bb_stream_continue14

bb_stream_continue14:
  %stream_cancelled124 = load i1, ptr %stream_cancelled107, align 1
  br i1 %stream_cancelled124, label %bb_stream_done15, label %bb_stream_next12

bb_stream_done15:
  %stream_has_drop125 = icmp ne ptr %stream_drop106, null
  br i1 %stream_has_drop125, label %bb_stream_drop16, label %bb_stream_drop_done17

bb_stream_drop16:
  call void %stream_drop106(ptr %stream_context104, i1 true)
  br label %bb_stream_drop_done17

bb_stream_drop_done17:
  %range126 = insertvalue %sollang.struct.43 poison, i32 11, 0
  %range127 = insertvalue %sollang.struct.43 %range126, i32 12, 1
  %struct_call128 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range127)
  %stream_context129 = extractvalue %sollang.stream %struct_call128, 0
  %stream_next130 = extractvalue %sollang.stream %struct_call128, 1
  %stream_drop131 = extractvalue %sollang.stream %struct_call128, 2
  %range132 = insertvalue %sollang.struct.43 poison, i32 13, 0
  %range133 = insertvalue %sollang.struct.43 %range132, i32 14, 1
  %struct_call134 = call %sollang.stream @sollang_fn_makeValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.struct.43 %range133)
  %stream_context135 = extractvalue %sollang.stream %struct_call134, 0
  %stream_next136 = extractvalue %sollang.stream %struct_call134, 1
  %stream_drop137 = extractvalue %sollang.stream %struct_call134, 2
  %stream_with_context139 = insertvalue %sollang.stream poison, ptr %stream_context129, 0
  %stream_with_next140 = insertvalue %sollang.stream %stream_with_context139, ptr %stream_next130, 1
  %stream_with_drop141 = insertvalue %sollang.stream %stream_with_next140, ptr %stream_drop131, 2
  %stream_with_context142 = insertvalue %sollang.stream poison, ptr %stream_context135, 0
  %stream_with_next143 = insertvalue %sollang.stream %stream_with_context142, ptr %stream_next136, 1
  %stream_with_drop144 = insertvalue %sollang.stream %stream_with_next143, ptr %stream_drop137, 2
  %struct_call138 = call %sollang.event_stream @sollang_fn_latestValues(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.stream %stream_with_drop141, %sollang.stream %stream_with_drop144)
  %stream_context145 = extractvalue %sollang.event_stream %struct_call138, 0
  %stream_next146 = extractvalue %sollang.event_stream %struct_call138, 1
  %stream_drop147 = extractvalue %sollang.event_stream %struct_call138, 2
  store i1 false, ptr %stream_cancelled148, align 1
  br label %bb_stream_next18

bb_stream_next18:
  %stream_has_value150 = call i1 %stream_next146(ptr %stream_context145, ptr %stream_element_address149)
  br i1 %stream_has_value150, label %bb_stream_value19, label %bb_stream_done21

bb_stream_value19:
  %stream_element151 = load %sollang.struct.2651, ptr %stream_element_address149, align 4
  %write152 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.5, i64 1, ptr %written)
  %is_ok153 = icmp ne i32 %write152, 0
  %previous_ok154 = load i1, ptr %ok_state, align 1
  %ok155 = and i1 %previous_ok154, %is_ok153
  store i1 %ok155, ptr %ok_state, align 1
  %field156 = extractvalue %sollang.struct.2651 %stream_element151, 0
  %print_integer157 = sext i32 %field156 to i64
  %write158 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer157, ptr %written)
  %is_ok159 = icmp ne i32 %write158, 0
  %previous_ok160 = load i1, ptr %ok_state, align 1
  %ok161 = and i1 %previous_ok160, %is_ok159
  store i1 %ok161, ptr %ok_state, align 1
  %write162 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.6, i64 1, ptr %written)
  %is_ok163 = icmp ne i32 %write162, 0
  %previous_ok164 = load i1, ptr %ok_state, align 1
  %ok165 = and i1 %previous_ok164, %is_ok163
  store i1 %ok165, ptr %ok_state, align 1
  %field166 = extractvalue %sollang.struct.2651 %stream_element151, 1
  %print_integer167 = sext i32 %field166 to i64
  %write168 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer167, ptr %written)
  %is_ok169 = icmp ne i32 %write168, 0
  %previous_ok170 = load i1, ptr %ok_state, align 1
  %ok171 = and i1 %previous_ok170, %is_ok169
  store i1 %ok171, ptr %ok_state, align 1
  %write172 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.7, i64 1, ptr %written)
  %is_ok173 = icmp ne i32 %write172, 0
  %previous_ok174 = load i1, ptr %ok_state, align 1
  %ok175 = and i1 %previous_ok174, %is_ok173
  store i1 %ok175, ptr %ok_state, align 1
  br label %bb_stream_continue20

bb_stream_continue20:
  %stream_cancelled176 = load i1, ptr %stream_cancelled148, align 1
  br i1 %stream_cancelled176, label %bb_stream_done21, label %bb_stream_next18

bb_stream_done21:
  %stream_has_drop177 = icmp ne ptr %stream_drop147, null
  br i1 %stream_has_drop177, label %bb_stream_drop22, label %bb_stream_drop_done23

bb_stream_drop22:
  call void %stream_drop147(ptr %stream_context145, i1 true)
  br label %bb_stream_drop_done23

bb_stream_drop_done23:
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %final_ok178 = load i1, ptr %ok_state, align 1
  %exit179 = select i1 %final_ok178, i32 0, i32 1
  ret i32 %exit179
}

attributes #0 = { nounwind }
