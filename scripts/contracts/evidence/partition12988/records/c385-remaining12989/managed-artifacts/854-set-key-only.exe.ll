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

@.slg.str.module.x.0 = private unnamed_addr constant [23 x i8] c".makeSet:bb_alloc_fail1", align 1
@.slg.str.module.x.1 = private unnamed_addr constant [24 x i8] c".makeSet:bb_alloc_fail29", align 1
@.slg.str.module.x.2 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail104", align 1
@.slg.str.module.x.3 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail179", align 1
@.slg.str.module.x.4 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail254", align 1
@.slg.str.module.x.5 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail329", align 1
@.slg.str.module.x.6 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail404", align 1
@.slg.str.module.x.7 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail479", align 1
@.slg.str.module.x.8 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail554", align 1
@.slg.str.module.x.9 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail629", align 1
@.slg.str.module.x.10 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail704", align 1
@.slg.str.module.x.11 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail779", align 1
@.slg.str.module.x.12 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail854", align 1
@.slg.str.module.x.13 = private unnamed_addr constant [25 x i8] c".makeSet:bb_alloc_fail929", align 1
@.slg.str.module.x.14 = private unnamed_addr constant [26 x i8] c".makeSet:bb_alloc_fail1004", align 1
@.slg.str.module.x.15 = private unnamed_addr constant [26 x i8] c".makeSet:bb_alloc_fail1079", align 1
@.slg.str.module.x.16 = private unnamed_addr constant [26 x i8] c".makeSet:bb_alloc_fail1154", align 1
@.slg.str.module.x.17 = private unnamed_addr constant [10 x i8] c"first=true", align 1
@.slg.str.module.x.18 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.module.x.19 = private unnamed_addr constant [11 x i8] c"first=false", align 1
@.slg.str.module.x.20 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.module.x.21 = private unnamed_addr constant [14 x i8] c"duplicate=true", align 1
@.slg.str.module.x.22 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.module.x.23 = private unnamed_addr constant [15 x i8] c"duplicate=false", align 1
@.slg.str.module.x.24 = private unnamed_addr constant [1 x i8] c"\0A", align 1
define internal %sollang.int_dictionary @sollang_fn_makeSet(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state) #0 {
entry:
  %trap_written7 = alloca i32, align 4
  %mutable_ptr_addr9 = alloca ptr, align 8
  %mutable_len_addr10 = alloca i64, align 8
  %mutable_capacity_addr11 = alloca i64, align 8
  %trap_written125 = alloca i32, align 4
  %trap_written452 = alloca i32, align 4
  %trap_written779 = alloca i32, align 4
  %trap_written1106 = alloca i32, align 4
  %trap_written1433 = alloca i32, align 4
  %trap_written1760 = alloca i32, align 4
  %trap_written2087 = alloca i32, align 4
  %trap_written2414 = alloca i32, align 4
  %trap_written2741 = alloca i32, align 4
  %trap_written3068 = alloca i32, align 4
  %trap_written3395 = alloca i32, align 4
  %trap_written3722 = alloca i32, align 4
  %trap_written4049 = alloca i32, align 4
  %trap_written4376 = alloca i32, align 4
  %trap_written4703 = alloca i32, align 4
  %trap_written5030 = alloca i32, align 4
  %generic_dict_entries_offset_mirror0 = add i64 16, 23
  %generic_dict_entries_offset1 = and i64 %generic_dict_entries_offset_mirror0, -8
  %generic_dict_entries_bytes2 = mul i64 16, 4
  %generic_dict_bytes3 = add i64 %generic_dict_entries_offset1, %generic_dict_entries_bytes2
  %heap4 = call ptr @sollang_alloc(i64 %generic_dict_bytes3)
  %heap_ok5 = icmp ne ptr %heap4, null
  br i1 %heap_ok5, label %bb_alloc_ok0, label %bb_alloc_fail1

bb_alloc_fail1:
  %trap_stderr6 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr6, ptr @.slg.str.module.x.0, i32 23, ptr %trap_written7, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok0:
  %generic_dict_control_bytes8 = add i64 16, 16
  call void @llvm.memset.p0.i64(ptr %heap4, i8 0, i64 %generic_dict_control_bytes8, i1 false)
  store ptr %heap4, ptr %mutable_ptr_addr9, align 8
  store i64 0, ptr %mutable_len_addr10, align 8
  store i64 16, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr12 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len13 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity14 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key15 = sext i32 10 to i64
  %hash_high17 = lshr i64 %hash_key15, 32
  %hash_fold16 = xor i64 %hash_key15, %hash_high17
  %hash18 = mul i64 %hash_fold16, -7046029254386353131
  %dict_h2_shifted19 = lshr i64 %hash18, 57
  %dict_h2_raw20 = and i64 %dict_h2_shifted19, 127
  %dict_h2_zero21 = icmp eq i64 %dict_h2_raw20, 0
  %dict_h222 = select i1 %dict_h2_zero21, i64 1, i64 %dict_h2_raw20
  %dict_h2_byte23 = trunc i64 %dict_h222 to i8
  %dict_capacity_mask24 = sub i64 %mutable_capacity14, 1
  %dict_start_slot25 = and i64 %hash18, %dict_capacity_mask24
  %generic_dict_insert_has_capacity26 = icmp ugt i64 %mutable_capacity14, 0
  br i1 %generic_dict_insert_has_capacity26, label %bb_generic_dict_insert_first8, label %bb_generic_dict_insert_no_capacity9

bb_generic_dict_insert_no_capacity9:
  br label %bb_generic_dict_insert_first_done7

bb_generic_dict_insert_first8:
  %generic_dict_control_slot27 = getelementptr i8, ptr %mutable_ptr12, i64 %dict_start_slot25
  %generic_dict_control28 = load i8, ptr %generic_dict_control_slot27, align 1
  %generic_dict_insert_first_empty29 = icmp eq i8 %generic_dict_control28, 0
  br i1 %generic_dict_insert_first_empty29, label %bb_generic_dict_insert_first_vacant6, label %bb_generic_dict_insert_first_occupied2

bb_generic_dict_insert_first_occupied2:
  %generic_dict_insert_first_h230 = icmp eq i8 %generic_dict_control28, %dict_h2_byte23
  br i1 %generic_dict_insert_first_h230, label %bb_generic_dict_insert_first_compare3, label %bb_generic_dict_insert_first_fallback5

bb_generic_dict_insert_first_compare3:
  %generic_dict_insert_first_key_entries_offset_mirror31 = add i64 %mutable_capacity14, 23
  %generic_dict_insert_first_key_entries_offset32 = and i64 %generic_dict_insert_first_key_entries_offset_mirror31, -8
  %generic_dict_insert_first_key_entries33 = getelementptr i8, ptr %mutable_ptr12, i64 %generic_dict_insert_first_key_entries_offset32
  %generic_dict_insert_first_key_entry_offset34 = mul i64 %dict_start_slot25, 4
  %generic_dict_insert_first_key_slot35 = getelementptr i8, ptr %generic_dict_insert_first_key_entries33, i64 %generic_dict_insert_first_key_entry_offset34
  %generic_dict_insert_first_key36 = load i32, ptr %generic_dict_insert_first_key_slot35, align 4
  %generic_dict_key_equal37 = icmp eq i32 %generic_dict_insert_first_key36, 10
  br i1 %generic_dict_key_equal37, label %bb_generic_dict_insert_first_match4, label %bb_generic_dict_insert_first_fallback5

bb_generic_dict_insert_first_match4:
  br label %bb_generic_dict_insert_first_done7

bb_generic_dict_insert_first_vacant6:
  br label %bb_generic_dict_insert_first_done7

bb_generic_dict_insert_first_fallback5:
  %hash_key38 = sext i32 10 to i64
  %hash_high40 = lshr i64 %hash_key38, 32
  %hash_fold39 = xor i64 %hash_key38, %hash_high40
  %hash41 = mul i64 %hash_fold39, -7046029254386353131
  %dict_h2_shifted42 = lshr i64 %hash41, 57
  %dict_h2_raw43 = and i64 %dict_h2_shifted42, 127
  %dict_h2_zero44 = icmp eq i64 %dict_h2_raw43, 0
  %dict_h245 = select i1 %dict_h2_zero44, i64 1, i64 %dict_h2_raw43
  %dict_h2_byte46 = trunc i64 %dict_h245 to i8
  %dict_capacity_mask47 = sub i64 %mutable_capacity14, 1
  %dict_start_slot48 = and i64 %hash41, %dict_capacity_mask47
  br label %bb_generic_dict_group_find10

bb_generic_dict_group_find10:
  %generic_dict_group_probe51 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback5 ], [ %generic_dict_group_next_probe49, %bb_generic_dict_group_next18 ]
  %generic_dict_group_deleted52 = phi i64 [ %mutable_capacity14, %bb_generic_dict_insert_first_fallback5 ], [ %generic_dict_group_next_deleted50, %bb_generic_dict_group_next18 ]
  %generic_dict_group_active53 = icmp ult i64 %generic_dict_group_probe51, %mutable_capacity14
  br i1 %generic_dict_group_active53, label %bb_generic_dict_group_body11, label %bb_generic_dict_group_miss19

bb_generic_dict_group_body11:
  %generic_dict_group_unwrapped54 = add i64 %dict_start_slot48, %generic_dict_group_probe51
  %generic_dict_group_start55 = and i64 %generic_dict_group_unwrapped54, %dict_capacity_mask47
  %generic_dict_group_pointer56 = getelementptr i8, ptr %mutable_ptr12, i64 %generic_dict_group_start55
  %generic_dict_group_controls57 = load <16 x i8>, ptr %generic_dict_group_pointer56, align 1
  %generic_dict_group_h2_seed58 = insertelement <16 x i8> poison, i8 %dict_h2_byte46, i64 0
  %generic_dict_group_h2_vector59 = shufflevector <16 x i8> %generic_dict_group_h2_seed58, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector60 = icmp eq <16 x i8> %generic_dict_group_controls57, %generic_dict_group_h2_vector59
  %generic_dict_group_match_bits61 = bitcast <16 x i1> %generic_dict_group_matches_vector60 to i16
  %generic_dict_group_empty_vector62 = icmp eq <16 x i8> %generic_dict_group_controls57, zeroinitializer
  %generic_dict_group_empty_bits63 = bitcast <16 x i1> %generic_dict_group_empty_vector62 to i16
  %generic_dict_group_deleted_seed64 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector65 = shufflevector <16 x i8> %generic_dict_group_deleted_seed64, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches66 = icmp eq <16 x i8> %generic_dict_group_controls57, %generic_dict_group_deleted_vector65
  %generic_dict_group_deleted_bits67 = bitcast <16 x i1> %generic_dict_group_deleted_matches66 to i16
  %generic_dict_group_has_deleted68 = icmp ne i16 %generic_dict_group_deleted_bits67, 0
  %generic_dict_group_no_previous_deleted69 = icmp eq i64 %generic_dict_group_deleted52, %mutable_capacity14
  %generic_dict_group_capture_deleted70 = and i1 %generic_dict_group_has_deleted68, %generic_dict_group_no_previous_deleted69
  %generic_dict_group_deleted_offset1671 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits67, i1 false)
  %generic_dict_group_deleted_offset72 = zext i16 %generic_dict_group_deleted_offset1671 to i64
  %generic_dict_group_deleted_unwrapped73 = add i64 %generic_dict_group_start55, %generic_dict_group_deleted_offset72
  %generic_dict_group_deleted_slot74 = and i64 %generic_dict_group_deleted_unwrapped73, %dict_capacity_mask47
  %generic_dict_group_captured_deleted75 = select i1 %generic_dict_group_capture_deleted70, i64 %generic_dict_group_deleted_slot74, i64 %generic_dict_group_deleted52
  br label %bb_generic_dict_candidate_loop12

bb_generic_dict_candidate_loop12:
  %generic_dict_candidate_bits76 = phi i16 [ %generic_dict_group_match_bits61, %bb_generic_dict_group_body11 ], [ %generic_dict_candidate_cleared_bits77, %bb_generic_dict_candidate_next14 ]
  %generic_dict_has_candidate78 = icmp ne i16 %generic_dict_candidate_bits76, 0
  br i1 %generic_dict_has_candidate78, label %bb_generic_dict_candidate_body13, label %bb_generic_dict_group_decision15

bb_generic_dict_candidate_body13:
  %generic_dict_candidate_offset1679 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits76, i1 false)
  %generic_dict_candidate_offset80 = zext i16 %generic_dict_candidate_offset1679 to i64
  %generic_dict_candidate_unwrapped81 = add i64 %generic_dict_group_start55, %generic_dict_candidate_offset80
  %generic_dict_candidate_slot82 = and i64 %generic_dict_candidate_unwrapped81, %dict_capacity_mask47
  %generic_dict_key_entries_offset_mirror83 = add i64 %mutable_capacity14, 23
  %generic_dict_key_entries_offset84 = and i64 %generic_dict_key_entries_offset_mirror83, -8
  %generic_dict_key_entries85 = getelementptr i8, ptr %mutable_ptr12, i64 %generic_dict_key_entries_offset84
  %generic_dict_key_entry_offset86 = mul i64 %generic_dict_candidate_slot82, 4
  %generic_dict_key_slot87 = getelementptr i8, ptr %generic_dict_key_entries85, i64 %generic_dict_key_entry_offset86
  %generic_dict_key88 = load i32, ptr %generic_dict_key_slot87, align 4
  %generic_dict_key_equal89 = icmp eq i32 %generic_dict_key88, 10
  br i1 %generic_dict_key_equal89, label %bb_generic_dict_group_match17, label %bb_generic_dict_candidate_next14

bb_generic_dict_candidate_next14:
  %generic_dict_candidate_bits_minus_one90 = sub i16 %generic_dict_candidate_bits76, 1
  %generic_dict_candidate_cleared_bits77 = and i16 %generic_dict_candidate_bits76, %generic_dict_candidate_bits_minus_one90
  br label %bb_generic_dict_candidate_loop12

bb_generic_dict_group_decision15:
  %generic_dict_group_has_empty91 = icmp ne i16 %generic_dict_group_empty_bits63, 0
  br i1 %generic_dict_group_has_empty91, label %bb_generic_dict_group_empty16, label %bb_generic_dict_group_next18

bb_generic_dict_group_empty16:
  %generic_dict_group_empty_offset1692 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits63, i1 false)
  %generic_dict_group_empty_offset93 = zext i16 %generic_dict_group_empty_offset1692 to i64
  %generic_dict_group_empty_unwrapped94 = add i64 %generic_dict_group_start55, %generic_dict_group_empty_offset93
  %generic_dict_group_empty_slot95 = and i64 %generic_dict_group_empty_unwrapped94, %dict_capacity_mask47
  %generic_dict_group_use_empty96 = icmp eq i64 %generic_dict_group_captured_deleted75, %mutable_capacity14
  %generic_dict_group_insertion_slot97 = select i1 %generic_dict_group_use_empty96, i64 %generic_dict_group_empty_slot95, i64 %generic_dict_group_captured_deleted75
  br label %bb_generic_dict_group_done20

bb_generic_dict_group_match17:
  br label %bb_generic_dict_group_done20

bb_generic_dict_group_next18:
  %generic_dict_group_next_probe49 = add i64 %generic_dict_group_probe51, 16
  %generic_dict_group_next_deleted50 = add i64 %generic_dict_group_captured_deleted75, 0
  br label %bb_generic_dict_group_find10

bb_generic_dict_group_miss19:
  %generic_dict_group_miss_no_deleted98 = icmp eq i64 %generic_dict_group_deleted52, %mutable_capacity14
  %generic_dict_group_miss_slot99 = select i1 %generic_dict_group_miss_no_deleted98, i64 0, i64 %generic_dict_group_deleted52
  br label %bb_generic_dict_group_done20

bb_generic_dict_group_done20:
  %generic_dict_find_found100 = phi i1 [ false, %bb_generic_dict_group_empty16 ], [ true, %bb_generic_dict_group_match17 ], [ false, %bb_generic_dict_group_miss19 ]
  %generic_dict_find_slot_result101 = phi i64 [ %generic_dict_group_insertion_slot97, %bb_generic_dict_group_empty16 ], [ %generic_dict_candidate_slot82, %bb_generic_dict_group_match17 ], [ %generic_dict_group_miss_slot99, %bb_generic_dict_group_miss19 ]
  br label %bb_generic_dict_insert_first_done7

bb_generic_dict_insert_first_done7:
  %generic_dict_insert_first_found102 = phi i1 [ true, %bb_generic_dict_insert_first_match4 ], [ false, %bb_generic_dict_insert_first_vacant6 ], [ %generic_dict_find_found100, %bb_generic_dict_group_done20 ], [ false, %bb_generic_dict_insert_no_capacity9 ]
  %generic_dict_insert_first_slot_result103 = phi i64 [ %dict_start_slot25, %bb_generic_dict_insert_first_match4 ], [ %dict_start_slot25, %bb_generic_dict_insert_first_vacant6 ], [ %generic_dict_find_slot_result101, %bb_generic_dict_group_done20 ], [ 0, %bb_generic_dict_insert_no_capacity9 ]
  br i1 %generic_dict_insert_first_found102, label %bb_set_insert_duplicate21, label %bb_set_insert_new22

bb_set_insert_duplicate21:
  br label %bb_set_insert_done25

bb_set_insert_new22:
  %set_insert_length104 = add i64 %mutable_len13, 1
  %set_insert_load_num105 = mul i64 %set_insert_length104, 8
  %set_insert_load_den106 = mul i64 %mutable_capacity14, 7
  %set_insert_should_grow107 = icmp ugt i64 %set_insert_load_num105, %set_insert_load_den106
  br i1 %set_insert_should_grow107, label %bb_set_insert_grow24, label %bb_set_insert_current23

bb_set_insert_current23:
  %set_key_entries_offset_mirror108 = add i64 %mutable_capacity14, 23
  %set_key_entries_offset109 = and i64 %set_key_entries_offset_mirror108, -8
  %set_key_entries110 = getelementptr i8, ptr %mutable_ptr12, i64 %set_key_entries_offset109
  %set_key_entry_offset111 = mul i64 %generic_dict_insert_first_slot_result103, 4
  %set_key_slot112 = getelementptr i8, ptr %set_key_entries110, i64 %set_key_entry_offset111
  store i32 10, ptr %set_key_slot112, align 4
  %generic_dict_control_slot113 = getelementptr i8, ptr %mutable_ptr12, i64 %generic_dict_insert_first_slot_result103
  store i8 %dict_h2_byte23, ptr %generic_dict_control_slot113, align 1
  %generic_dict_control_mirrored114 = icmp ult i64 %generic_dict_insert_first_slot_result103, 16
  br i1 %generic_dict_control_mirrored114, label %bb_generic_dict_control_mirror26, label %bb_generic_dict_control_done27

bb_generic_dict_control_mirror26:
  %generic_dict_control_mirror_index115 = add i64 %mutable_capacity14, %generic_dict_insert_first_slot_result103
  %generic_dict_control_mirror_slot116 = getelementptr i8, ptr %mutable_ptr12, i64 %generic_dict_control_mirror_index115
  store i8 %dict_h2_byte23, ptr %generic_dict_control_mirror_slot116, align 1
  br label %bb_generic_dict_control_done27

bb_generic_dict_control_done27:
  br label %bb_set_insert_done25

bb_set_insert_grow24:
  %set_grown_capacity117 = mul i64 %mutable_capacity14, 2
  %generic_dict_entries_offset_mirror118 = add i64 %set_grown_capacity117, 23
  %generic_dict_entries_offset119 = and i64 %generic_dict_entries_offset_mirror118, -8
  %generic_dict_entries_bytes120 = mul i64 %set_grown_capacity117, 4
  %generic_dict_bytes121 = add i64 %generic_dict_entries_offset119, %generic_dict_entries_bytes120
  %heap122 = call ptr @sollang_alloc(i64 %generic_dict_bytes121)
  %heap_ok123 = icmp ne ptr %heap122, null
  br i1 %heap_ok123, label %bb_alloc_ok28, label %bb_alloc_fail29

bb_alloc_fail29:
  %trap_stderr124 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr124, ptr @.slg.str.module.x.1, i32 24, ptr %trap_written125, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok28:
  %generic_dict_control_bytes126 = add i64 %set_grown_capacity117, 16
  call void @llvm.memset.p0.i64(ptr %heap122, i8 0, i64 %generic_dict_control_bytes126, i1 false)
  br label %bb_set_rehash30

bb_set_rehash30:
  %set_rehash_index128 = phi i64 [ 0, %bb_alloc_ok28 ], [ %set_rehash_next_index127, %bb_set_rehash_next33 ]
  %set_rehash_active129 = icmp ult i64 %set_rehash_index128, %mutable_capacity14
  br i1 %set_rehash_active129, label %bb_set_rehash_body31, label %bb_set_rehash_done34

bb_set_rehash_body31:
  %generic_dict_control_slot130 = getelementptr i8, ptr %mutable_ptr12, i64 %set_rehash_index128
  %generic_dict_control131 = load i8, ptr %generic_dict_control_slot130, align 1
  %set_rehash_occupied132 = icmp sgt i8 %generic_dict_control131, 0
  br i1 %set_rehash_occupied132, label %bb_set_rehash_move32, label %bb_set_rehash_next33

bb_set_rehash_move32:
  %set_rehash_key_entries_offset_mirror133 = add i64 %mutable_capacity14, 23
  %set_rehash_key_entries_offset134 = and i64 %set_rehash_key_entries_offset_mirror133, -8
  %set_rehash_key_entries135 = getelementptr i8, ptr %mutable_ptr12, i64 %set_rehash_key_entries_offset134
  %set_rehash_key_entry_offset136 = mul i64 %set_rehash_index128, 4
  %set_rehash_key_slot137 = getelementptr i8, ptr %set_rehash_key_entries135, i64 %set_rehash_key_entry_offset136
  %set_rehash_key138 = load i32, ptr %set_rehash_key_slot137, align 4
  %hash_key139 = sext i32 %set_rehash_key138 to i64
  %hash_high141 = lshr i64 %hash_key139, 32
  %hash_fold140 = xor i64 %hash_key139, %hash_high141
  %hash142 = mul i64 %hash_fold140, -7046029254386353131
  %dict_h2_shifted143 = lshr i64 %hash142, 57
  %dict_h2_raw144 = and i64 %dict_h2_shifted143, 127
  %dict_h2_zero145 = icmp eq i64 %dict_h2_raw144, 0
  %dict_h2146 = select i1 %dict_h2_zero145, i64 1, i64 %dict_h2_raw144
  %dict_h2_byte147 = trunc i64 %dict_h2146 to i8
  %dict_capacity_mask148 = sub i64 %set_grown_capacity117, 1
  %dict_start_slot149 = and i64 %hash142, %dict_capacity_mask148
  %generic_dict_insert_has_capacity150 = icmp ugt i64 %set_grown_capacity117, 0
  br i1 %generic_dict_insert_has_capacity150, label %bb_generic_dict_insert_first41, label %bb_generic_dict_insert_no_capacity42

bb_generic_dict_insert_no_capacity42:
  br label %bb_generic_dict_insert_first_done40

bb_generic_dict_insert_first41:
  %generic_dict_control_slot151 = getelementptr i8, ptr %heap122, i64 %dict_start_slot149
  %generic_dict_control152 = load i8, ptr %generic_dict_control_slot151, align 1
  %generic_dict_insert_first_empty153 = icmp eq i8 %generic_dict_control152, 0
  br i1 %generic_dict_insert_first_empty153, label %bb_generic_dict_insert_first_vacant39, label %bb_generic_dict_insert_first_occupied35

bb_generic_dict_insert_first_occupied35:
  %generic_dict_insert_first_h2154 = icmp eq i8 %generic_dict_control152, %dict_h2_byte147
  br i1 %generic_dict_insert_first_h2154, label %bb_generic_dict_insert_first_compare36, label %bb_generic_dict_insert_first_fallback38

bb_generic_dict_insert_first_compare36:
  %generic_dict_insert_first_key_entries_offset_mirror155 = add i64 %set_grown_capacity117, 23
  %generic_dict_insert_first_key_entries_offset156 = and i64 %generic_dict_insert_first_key_entries_offset_mirror155, -8
  %generic_dict_insert_first_key_entries157 = getelementptr i8, ptr %heap122, i64 %generic_dict_insert_first_key_entries_offset156
  %generic_dict_insert_first_key_entry_offset158 = mul i64 %dict_start_slot149, 4
  %generic_dict_insert_first_key_slot159 = getelementptr i8, ptr %generic_dict_insert_first_key_entries157, i64 %generic_dict_insert_first_key_entry_offset158
  %generic_dict_insert_first_key160 = load i32, ptr %generic_dict_insert_first_key_slot159, align 4
  %generic_dict_key_equal161 = icmp eq i32 %generic_dict_insert_first_key160, %set_rehash_key138
  br i1 %generic_dict_key_equal161, label %bb_generic_dict_insert_first_match37, label %bb_generic_dict_insert_first_fallback38

bb_generic_dict_insert_first_match37:
  br label %bb_generic_dict_insert_first_done40

bb_generic_dict_insert_first_vacant39:
  br label %bb_generic_dict_insert_first_done40

bb_generic_dict_insert_first_fallback38:
  %hash_key162 = sext i32 %set_rehash_key138 to i64
  %hash_high164 = lshr i64 %hash_key162, 32
  %hash_fold163 = xor i64 %hash_key162, %hash_high164
  %hash165 = mul i64 %hash_fold163, -7046029254386353131
  %dict_h2_shifted166 = lshr i64 %hash165, 57
  %dict_h2_raw167 = and i64 %dict_h2_shifted166, 127
  %dict_h2_zero168 = icmp eq i64 %dict_h2_raw167, 0
  %dict_h2169 = select i1 %dict_h2_zero168, i64 1, i64 %dict_h2_raw167
  %dict_h2_byte170 = trunc i64 %dict_h2169 to i8
  %dict_capacity_mask171 = sub i64 %set_grown_capacity117, 1
  %dict_start_slot172 = and i64 %hash165, %dict_capacity_mask171
  br label %bb_generic_dict_group_find43

bb_generic_dict_group_find43:
  %generic_dict_group_probe175 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback38 ], [ %generic_dict_group_next_probe173, %bb_generic_dict_group_next51 ]
  %generic_dict_group_deleted176 = phi i64 [ %set_grown_capacity117, %bb_generic_dict_insert_first_fallback38 ], [ %generic_dict_group_next_deleted174, %bb_generic_dict_group_next51 ]
  %generic_dict_group_active177 = icmp ult i64 %generic_dict_group_probe175, %set_grown_capacity117
  br i1 %generic_dict_group_active177, label %bb_generic_dict_group_body44, label %bb_generic_dict_group_miss52

bb_generic_dict_group_body44:
  %generic_dict_group_unwrapped178 = add i64 %dict_start_slot172, %generic_dict_group_probe175
  %generic_dict_group_start179 = and i64 %generic_dict_group_unwrapped178, %dict_capacity_mask171
  %generic_dict_group_pointer180 = getelementptr i8, ptr %heap122, i64 %generic_dict_group_start179
  %generic_dict_group_controls181 = load <16 x i8>, ptr %generic_dict_group_pointer180, align 1
  %generic_dict_group_h2_seed182 = insertelement <16 x i8> poison, i8 %dict_h2_byte170, i64 0
  %generic_dict_group_h2_vector183 = shufflevector <16 x i8> %generic_dict_group_h2_seed182, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector184 = icmp eq <16 x i8> %generic_dict_group_controls181, %generic_dict_group_h2_vector183
  %generic_dict_group_match_bits185 = bitcast <16 x i1> %generic_dict_group_matches_vector184 to i16
  %generic_dict_group_empty_vector186 = icmp eq <16 x i8> %generic_dict_group_controls181, zeroinitializer
  %generic_dict_group_empty_bits187 = bitcast <16 x i1> %generic_dict_group_empty_vector186 to i16
  %generic_dict_group_deleted_seed188 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector189 = shufflevector <16 x i8> %generic_dict_group_deleted_seed188, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches190 = icmp eq <16 x i8> %generic_dict_group_controls181, %generic_dict_group_deleted_vector189
  %generic_dict_group_deleted_bits191 = bitcast <16 x i1> %generic_dict_group_deleted_matches190 to i16
  %generic_dict_group_has_deleted192 = icmp ne i16 %generic_dict_group_deleted_bits191, 0
  %generic_dict_group_no_previous_deleted193 = icmp eq i64 %generic_dict_group_deleted176, %set_grown_capacity117
  %generic_dict_group_capture_deleted194 = and i1 %generic_dict_group_has_deleted192, %generic_dict_group_no_previous_deleted193
  %generic_dict_group_deleted_offset16195 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits191, i1 false)
  %generic_dict_group_deleted_offset196 = zext i16 %generic_dict_group_deleted_offset16195 to i64
  %generic_dict_group_deleted_unwrapped197 = add i64 %generic_dict_group_start179, %generic_dict_group_deleted_offset196
  %generic_dict_group_deleted_slot198 = and i64 %generic_dict_group_deleted_unwrapped197, %dict_capacity_mask171
  %generic_dict_group_captured_deleted199 = select i1 %generic_dict_group_capture_deleted194, i64 %generic_dict_group_deleted_slot198, i64 %generic_dict_group_deleted176
  br label %bb_generic_dict_candidate_loop45

bb_generic_dict_candidate_loop45:
  %generic_dict_candidate_bits200 = phi i16 [ %generic_dict_group_match_bits185, %bb_generic_dict_group_body44 ], [ %generic_dict_candidate_cleared_bits201, %bb_generic_dict_candidate_next47 ]
  %generic_dict_has_candidate202 = icmp ne i16 %generic_dict_candidate_bits200, 0
  br i1 %generic_dict_has_candidate202, label %bb_generic_dict_candidate_body46, label %bb_generic_dict_group_decision48

bb_generic_dict_candidate_body46:
  %generic_dict_candidate_offset16203 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits200, i1 false)
  %generic_dict_candidate_offset204 = zext i16 %generic_dict_candidate_offset16203 to i64
  %generic_dict_candidate_unwrapped205 = add i64 %generic_dict_group_start179, %generic_dict_candidate_offset204
  %generic_dict_candidate_slot206 = and i64 %generic_dict_candidate_unwrapped205, %dict_capacity_mask171
  %generic_dict_key_entries_offset_mirror207 = add i64 %set_grown_capacity117, 23
  %generic_dict_key_entries_offset208 = and i64 %generic_dict_key_entries_offset_mirror207, -8
  %generic_dict_key_entries209 = getelementptr i8, ptr %heap122, i64 %generic_dict_key_entries_offset208
  %generic_dict_key_entry_offset210 = mul i64 %generic_dict_candidate_slot206, 4
  %generic_dict_key_slot211 = getelementptr i8, ptr %generic_dict_key_entries209, i64 %generic_dict_key_entry_offset210
  %generic_dict_key212 = load i32, ptr %generic_dict_key_slot211, align 4
  %generic_dict_key_equal213 = icmp eq i32 %generic_dict_key212, %set_rehash_key138
  br i1 %generic_dict_key_equal213, label %bb_generic_dict_group_match50, label %bb_generic_dict_candidate_next47

bb_generic_dict_candidate_next47:
  %generic_dict_candidate_bits_minus_one214 = sub i16 %generic_dict_candidate_bits200, 1
  %generic_dict_candidate_cleared_bits201 = and i16 %generic_dict_candidate_bits200, %generic_dict_candidate_bits_minus_one214
  br label %bb_generic_dict_candidate_loop45

bb_generic_dict_group_decision48:
  %generic_dict_group_has_empty215 = icmp ne i16 %generic_dict_group_empty_bits187, 0
  br i1 %generic_dict_group_has_empty215, label %bb_generic_dict_group_empty49, label %bb_generic_dict_group_next51

bb_generic_dict_group_empty49:
  %generic_dict_group_empty_offset16216 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits187, i1 false)
  %generic_dict_group_empty_offset217 = zext i16 %generic_dict_group_empty_offset16216 to i64
  %generic_dict_group_empty_unwrapped218 = add i64 %generic_dict_group_start179, %generic_dict_group_empty_offset217
  %generic_dict_group_empty_slot219 = and i64 %generic_dict_group_empty_unwrapped218, %dict_capacity_mask171
  %generic_dict_group_use_empty220 = icmp eq i64 %generic_dict_group_captured_deleted199, %set_grown_capacity117
  %generic_dict_group_insertion_slot221 = select i1 %generic_dict_group_use_empty220, i64 %generic_dict_group_empty_slot219, i64 %generic_dict_group_captured_deleted199
  br label %bb_generic_dict_group_done53

bb_generic_dict_group_match50:
  br label %bb_generic_dict_group_done53

bb_generic_dict_group_next51:
  %generic_dict_group_next_probe173 = add i64 %generic_dict_group_probe175, 16
  %generic_dict_group_next_deleted174 = add i64 %generic_dict_group_captured_deleted199, 0
  br label %bb_generic_dict_group_find43

bb_generic_dict_group_miss52:
  %generic_dict_group_miss_no_deleted222 = icmp eq i64 %generic_dict_group_deleted176, %set_grown_capacity117
  %generic_dict_group_miss_slot223 = select i1 %generic_dict_group_miss_no_deleted222, i64 0, i64 %generic_dict_group_deleted176
  br label %bb_generic_dict_group_done53

bb_generic_dict_group_done53:
  %generic_dict_find_found224 = phi i1 [ false, %bb_generic_dict_group_empty49 ], [ true, %bb_generic_dict_group_match50 ], [ false, %bb_generic_dict_group_miss52 ]
  %generic_dict_find_slot_result225 = phi i64 [ %generic_dict_group_insertion_slot221, %bb_generic_dict_group_empty49 ], [ %generic_dict_candidate_slot206, %bb_generic_dict_group_match50 ], [ %generic_dict_group_miss_slot223, %bb_generic_dict_group_miss52 ]
  br label %bb_generic_dict_insert_first_done40

bb_generic_dict_insert_first_done40:
  %generic_dict_insert_first_found226 = phi i1 [ true, %bb_generic_dict_insert_first_match37 ], [ false, %bb_generic_dict_insert_first_vacant39 ], [ %generic_dict_find_found224, %bb_generic_dict_group_done53 ], [ false, %bb_generic_dict_insert_no_capacity42 ]
  %generic_dict_insert_first_slot_result227 = phi i64 [ %dict_start_slot149, %bb_generic_dict_insert_first_match37 ], [ %dict_start_slot149, %bb_generic_dict_insert_first_vacant39 ], [ %generic_dict_find_slot_result225, %bb_generic_dict_group_done53 ], [ 0, %bb_generic_dict_insert_no_capacity42 ]
  %set_key_entries_offset_mirror228 = add i64 %set_grown_capacity117, 23
  %set_key_entries_offset229 = and i64 %set_key_entries_offset_mirror228, -8
  %set_key_entries230 = getelementptr i8, ptr %heap122, i64 %set_key_entries_offset229
  %set_key_entry_offset231 = mul i64 %generic_dict_insert_first_slot_result227, 4
  %set_key_slot232 = getelementptr i8, ptr %set_key_entries230, i64 %set_key_entry_offset231
  store i32 %set_rehash_key138, ptr %set_key_slot232, align 4
  %generic_dict_control_slot233 = getelementptr i8, ptr %heap122, i64 %generic_dict_insert_first_slot_result227
  store i8 %dict_h2_byte147, ptr %generic_dict_control_slot233, align 1
  %generic_dict_control_mirrored234 = icmp ult i64 %generic_dict_insert_first_slot_result227, 16
  br i1 %generic_dict_control_mirrored234, label %bb_generic_dict_control_mirror54, label %bb_generic_dict_control_done55

bb_generic_dict_control_mirror54:
  %generic_dict_control_mirror_index235 = add i64 %set_grown_capacity117, %generic_dict_insert_first_slot_result227
  %generic_dict_control_mirror_slot236 = getelementptr i8, ptr %heap122, i64 %generic_dict_control_mirror_index235
  store i8 %dict_h2_byte147, ptr %generic_dict_control_mirror_slot236, align 1
  br label %bb_generic_dict_control_done55

bb_generic_dict_control_done55:
  br label %bb_set_rehash_next33

bb_set_rehash_next33:
  %set_rehash_next_index127 = add i64 %set_rehash_index128, 1
  br label %bb_set_rehash30

bb_set_rehash_done34:
  call void @sollang_free(ptr %mutable_ptr12)
  %hash_key237 = sext i32 10 to i64
  %hash_high239 = lshr i64 %hash_key237, 32
  %hash_fold238 = xor i64 %hash_key237, %hash_high239
  %hash240 = mul i64 %hash_fold238, -7046029254386353131
  %dict_h2_shifted241 = lshr i64 %hash240, 57
  %dict_h2_raw242 = and i64 %dict_h2_shifted241, 127
  %dict_h2_zero243 = icmp eq i64 %dict_h2_raw242, 0
  %dict_h2244 = select i1 %dict_h2_zero243, i64 1, i64 %dict_h2_raw242
  %dict_h2_byte245 = trunc i64 %dict_h2244 to i8
  %dict_capacity_mask246 = sub i64 %set_grown_capacity117, 1
  %dict_start_slot247 = and i64 %hash240, %dict_capacity_mask246
  %generic_dict_insert_has_capacity248 = icmp ugt i64 %set_grown_capacity117, 0
  br i1 %generic_dict_insert_has_capacity248, label %bb_generic_dict_insert_first62, label %bb_generic_dict_insert_no_capacity63

bb_generic_dict_insert_no_capacity63:
  br label %bb_generic_dict_insert_first_done61

bb_generic_dict_insert_first62:
  %generic_dict_control_slot249 = getelementptr i8, ptr %heap122, i64 %dict_start_slot247
  %generic_dict_control250 = load i8, ptr %generic_dict_control_slot249, align 1
  %generic_dict_insert_first_empty251 = icmp eq i8 %generic_dict_control250, 0
  br i1 %generic_dict_insert_first_empty251, label %bb_generic_dict_insert_first_vacant60, label %bb_generic_dict_insert_first_occupied56

bb_generic_dict_insert_first_occupied56:
  %generic_dict_insert_first_h2252 = icmp eq i8 %generic_dict_control250, %dict_h2_byte245
  br i1 %generic_dict_insert_first_h2252, label %bb_generic_dict_insert_first_compare57, label %bb_generic_dict_insert_first_fallback59

bb_generic_dict_insert_first_compare57:
  %generic_dict_insert_first_key_entries_offset_mirror253 = add i64 %set_grown_capacity117, 23
  %generic_dict_insert_first_key_entries_offset254 = and i64 %generic_dict_insert_first_key_entries_offset_mirror253, -8
  %generic_dict_insert_first_key_entries255 = getelementptr i8, ptr %heap122, i64 %generic_dict_insert_first_key_entries_offset254
  %generic_dict_insert_first_key_entry_offset256 = mul i64 %dict_start_slot247, 4
  %generic_dict_insert_first_key_slot257 = getelementptr i8, ptr %generic_dict_insert_first_key_entries255, i64 %generic_dict_insert_first_key_entry_offset256
  %generic_dict_insert_first_key258 = load i32, ptr %generic_dict_insert_first_key_slot257, align 4
  %generic_dict_key_equal259 = icmp eq i32 %generic_dict_insert_first_key258, 10
  br i1 %generic_dict_key_equal259, label %bb_generic_dict_insert_first_match58, label %bb_generic_dict_insert_first_fallback59

bb_generic_dict_insert_first_match58:
  br label %bb_generic_dict_insert_first_done61

bb_generic_dict_insert_first_vacant60:
  br label %bb_generic_dict_insert_first_done61

bb_generic_dict_insert_first_fallback59:
  %hash_key260 = sext i32 10 to i64
  %hash_high262 = lshr i64 %hash_key260, 32
  %hash_fold261 = xor i64 %hash_key260, %hash_high262
  %hash263 = mul i64 %hash_fold261, -7046029254386353131
  %dict_h2_shifted264 = lshr i64 %hash263, 57
  %dict_h2_raw265 = and i64 %dict_h2_shifted264, 127
  %dict_h2_zero266 = icmp eq i64 %dict_h2_raw265, 0
  %dict_h2267 = select i1 %dict_h2_zero266, i64 1, i64 %dict_h2_raw265
  %dict_h2_byte268 = trunc i64 %dict_h2267 to i8
  %dict_capacity_mask269 = sub i64 %set_grown_capacity117, 1
  %dict_start_slot270 = and i64 %hash263, %dict_capacity_mask269
  br label %bb_generic_dict_group_find64

bb_generic_dict_group_find64:
  %generic_dict_group_probe273 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback59 ], [ %generic_dict_group_next_probe271, %bb_generic_dict_group_next72 ]
  %generic_dict_group_deleted274 = phi i64 [ %set_grown_capacity117, %bb_generic_dict_insert_first_fallback59 ], [ %generic_dict_group_next_deleted272, %bb_generic_dict_group_next72 ]
  %generic_dict_group_active275 = icmp ult i64 %generic_dict_group_probe273, %set_grown_capacity117
  br i1 %generic_dict_group_active275, label %bb_generic_dict_group_body65, label %bb_generic_dict_group_miss73

bb_generic_dict_group_body65:
  %generic_dict_group_unwrapped276 = add i64 %dict_start_slot270, %generic_dict_group_probe273
  %generic_dict_group_start277 = and i64 %generic_dict_group_unwrapped276, %dict_capacity_mask269
  %generic_dict_group_pointer278 = getelementptr i8, ptr %heap122, i64 %generic_dict_group_start277
  %generic_dict_group_controls279 = load <16 x i8>, ptr %generic_dict_group_pointer278, align 1
  %generic_dict_group_h2_seed280 = insertelement <16 x i8> poison, i8 %dict_h2_byte268, i64 0
  %generic_dict_group_h2_vector281 = shufflevector <16 x i8> %generic_dict_group_h2_seed280, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector282 = icmp eq <16 x i8> %generic_dict_group_controls279, %generic_dict_group_h2_vector281
  %generic_dict_group_match_bits283 = bitcast <16 x i1> %generic_dict_group_matches_vector282 to i16
  %generic_dict_group_empty_vector284 = icmp eq <16 x i8> %generic_dict_group_controls279, zeroinitializer
  %generic_dict_group_empty_bits285 = bitcast <16 x i1> %generic_dict_group_empty_vector284 to i16
  %generic_dict_group_deleted_seed286 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector287 = shufflevector <16 x i8> %generic_dict_group_deleted_seed286, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches288 = icmp eq <16 x i8> %generic_dict_group_controls279, %generic_dict_group_deleted_vector287
  %generic_dict_group_deleted_bits289 = bitcast <16 x i1> %generic_dict_group_deleted_matches288 to i16
  %generic_dict_group_has_deleted290 = icmp ne i16 %generic_dict_group_deleted_bits289, 0
  %generic_dict_group_no_previous_deleted291 = icmp eq i64 %generic_dict_group_deleted274, %set_grown_capacity117
  %generic_dict_group_capture_deleted292 = and i1 %generic_dict_group_has_deleted290, %generic_dict_group_no_previous_deleted291
  %generic_dict_group_deleted_offset16293 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits289, i1 false)
  %generic_dict_group_deleted_offset294 = zext i16 %generic_dict_group_deleted_offset16293 to i64
  %generic_dict_group_deleted_unwrapped295 = add i64 %generic_dict_group_start277, %generic_dict_group_deleted_offset294
  %generic_dict_group_deleted_slot296 = and i64 %generic_dict_group_deleted_unwrapped295, %dict_capacity_mask269
  %generic_dict_group_captured_deleted297 = select i1 %generic_dict_group_capture_deleted292, i64 %generic_dict_group_deleted_slot296, i64 %generic_dict_group_deleted274
  br label %bb_generic_dict_candidate_loop66

bb_generic_dict_candidate_loop66:
  %generic_dict_candidate_bits298 = phi i16 [ %generic_dict_group_match_bits283, %bb_generic_dict_group_body65 ], [ %generic_dict_candidate_cleared_bits299, %bb_generic_dict_candidate_next68 ]
  %generic_dict_has_candidate300 = icmp ne i16 %generic_dict_candidate_bits298, 0
  br i1 %generic_dict_has_candidate300, label %bb_generic_dict_candidate_body67, label %bb_generic_dict_group_decision69

bb_generic_dict_candidate_body67:
  %generic_dict_candidate_offset16301 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits298, i1 false)
  %generic_dict_candidate_offset302 = zext i16 %generic_dict_candidate_offset16301 to i64
  %generic_dict_candidate_unwrapped303 = add i64 %generic_dict_group_start277, %generic_dict_candidate_offset302
  %generic_dict_candidate_slot304 = and i64 %generic_dict_candidate_unwrapped303, %dict_capacity_mask269
  %generic_dict_key_entries_offset_mirror305 = add i64 %set_grown_capacity117, 23
  %generic_dict_key_entries_offset306 = and i64 %generic_dict_key_entries_offset_mirror305, -8
  %generic_dict_key_entries307 = getelementptr i8, ptr %heap122, i64 %generic_dict_key_entries_offset306
  %generic_dict_key_entry_offset308 = mul i64 %generic_dict_candidate_slot304, 4
  %generic_dict_key_slot309 = getelementptr i8, ptr %generic_dict_key_entries307, i64 %generic_dict_key_entry_offset308
  %generic_dict_key310 = load i32, ptr %generic_dict_key_slot309, align 4
  %generic_dict_key_equal311 = icmp eq i32 %generic_dict_key310, 10
  br i1 %generic_dict_key_equal311, label %bb_generic_dict_group_match71, label %bb_generic_dict_candidate_next68

bb_generic_dict_candidate_next68:
  %generic_dict_candidate_bits_minus_one312 = sub i16 %generic_dict_candidate_bits298, 1
  %generic_dict_candidate_cleared_bits299 = and i16 %generic_dict_candidate_bits298, %generic_dict_candidate_bits_minus_one312
  br label %bb_generic_dict_candidate_loop66

bb_generic_dict_group_decision69:
  %generic_dict_group_has_empty313 = icmp ne i16 %generic_dict_group_empty_bits285, 0
  br i1 %generic_dict_group_has_empty313, label %bb_generic_dict_group_empty70, label %bb_generic_dict_group_next72

bb_generic_dict_group_empty70:
  %generic_dict_group_empty_offset16314 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits285, i1 false)
  %generic_dict_group_empty_offset315 = zext i16 %generic_dict_group_empty_offset16314 to i64
  %generic_dict_group_empty_unwrapped316 = add i64 %generic_dict_group_start277, %generic_dict_group_empty_offset315
  %generic_dict_group_empty_slot317 = and i64 %generic_dict_group_empty_unwrapped316, %dict_capacity_mask269
  %generic_dict_group_use_empty318 = icmp eq i64 %generic_dict_group_captured_deleted297, %set_grown_capacity117
  %generic_dict_group_insertion_slot319 = select i1 %generic_dict_group_use_empty318, i64 %generic_dict_group_empty_slot317, i64 %generic_dict_group_captured_deleted297
  br label %bb_generic_dict_group_done74

bb_generic_dict_group_match71:
  br label %bb_generic_dict_group_done74

bb_generic_dict_group_next72:
  %generic_dict_group_next_probe271 = add i64 %generic_dict_group_probe273, 16
  %generic_dict_group_next_deleted272 = add i64 %generic_dict_group_captured_deleted297, 0
  br label %bb_generic_dict_group_find64

bb_generic_dict_group_miss73:
  %generic_dict_group_miss_no_deleted320 = icmp eq i64 %generic_dict_group_deleted274, %set_grown_capacity117
  %generic_dict_group_miss_slot321 = select i1 %generic_dict_group_miss_no_deleted320, i64 0, i64 %generic_dict_group_deleted274
  br label %bb_generic_dict_group_done74

bb_generic_dict_group_done74:
  %generic_dict_find_found322 = phi i1 [ false, %bb_generic_dict_group_empty70 ], [ true, %bb_generic_dict_group_match71 ], [ false, %bb_generic_dict_group_miss73 ]
  %generic_dict_find_slot_result323 = phi i64 [ %generic_dict_group_insertion_slot319, %bb_generic_dict_group_empty70 ], [ %generic_dict_candidate_slot304, %bb_generic_dict_group_match71 ], [ %generic_dict_group_miss_slot321, %bb_generic_dict_group_miss73 ]
  br label %bb_generic_dict_insert_first_done61

bb_generic_dict_insert_first_done61:
  %generic_dict_insert_first_found324 = phi i1 [ true, %bb_generic_dict_insert_first_match58 ], [ false, %bb_generic_dict_insert_first_vacant60 ], [ %generic_dict_find_found322, %bb_generic_dict_group_done74 ], [ false, %bb_generic_dict_insert_no_capacity63 ]
  %generic_dict_insert_first_slot_result325 = phi i64 [ %dict_start_slot247, %bb_generic_dict_insert_first_match58 ], [ %dict_start_slot247, %bb_generic_dict_insert_first_vacant60 ], [ %generic_dict_find_slot_result323, %bb_generic_dict_group_done74 ], [ 0, %bb_generic_dict_insert_no_capacity63 ]
  %set_key_entries_offset_mirror326 = add i64 %set_grown_capacity117, 23
  %set_key_entries_offset327 = and i64 %set_key_entries_offset_mirror326, -8
  %set_key_entries328 = getelementptr i8, ptr %heap122, i64 %set_key_entries_offset327
  %set_key_entry_offset329 = mul i64 %generic_dict_insert_first_slot_result325, 4
  %set_key_slot330 = getelementptr i8, ptr %set_key_entries328, i64 %set_key_entry_offset329
  store i32 10, ptr %set_key_slot330, align 4
  %generic_dict_control_slot331 = getelementptr i8, ptr %heap122, i64 %generic_dict_insert_first_slot_result325
  store i8 %dict_h2_byte245, ptr %generic_dict_control_slot331, align 1
  %generic_dict_control_mirrored332 = icmp ult i64 %generic_dict_insert_first_slot_result325, 16
  br i1 %generic_dict_control_mirrored332, label %bb_generic_dict_control_mirror75, label %bb_generic_dict_control_done76

bb_generic_dict_control_mirror75:
  %generic_dict_control_mirror_index333 = add i64 %set_grown_capacity117, %generic_dict_insert_first_slot_result325
  %generic_dict_control_mirror_slot334 = getelementptr i8, ptr %heap122, i64 %generic_dict_control_mirror_index333
  store i8 %dict_h2_byte245, ptr %generic_dict_control_mirror_slot334, align 1
  br label %bb_generic_dict_control_done76

bb_generic_dict_control_done76:
  br label %bb_set_insert_done25

bb_set_insert_done25:
  %set_pointer335 = phi ptr [ %mutable_ptr12, %bb_set_insert_duplicate21 ], [ %mutable_ptr12, %bb_generic_dict_control_done27 ], [ %heap122, %bb_generic_dict_control_done76 ]
  %set_length336 = phi i64 [ %mutable_len13, %bb_set_insert_duplicate21 ], [ %set_insert_length104, %bb_generic_dict_control_done27 ], [ %set_insert_length104, %bb_generic_dict_control_done76 ]
  %set_capacity337 = phi i64 [ %mutable_capacity14, %bb_set_insert_duplicate21 ], [ %mutable_capacity14, %bb_generic_dict_control_done27 ], [ %set_grown_capacity117, %bb_generic_dict_control_done76 ]
  %set_inserted338 = phi i1 [ false, %bb_set_insert_duplicate21 ], [ true, %bb_generic_dict_control_done27 ], [ true, %bb_generic_dict_control_done76 ]
  store ptr %set_pointer335, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length336, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity337, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr339 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len340 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity341 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key342 = sext i32 20 to i64
  %hash_high344 = lshr i64 %hash_key342, 32
  %hash_fold343 = xor i64 %hash_key342, %hash_high344
  %hash345 = mul i64 %hash_fold343, -7046029254386353131
  %dict_h2_shifted346 = lshr i64 %hash345, 57
  %dict_h2_raw347 = and i64 %dict_h2_shifted346, 127
  %dict_h2_zero348 = icmp eq i64 %dict_h2_raw347, 0
  %dict_h2349 = select i1 %dict_h2_zero348, i64 1, i64 %dict_h2_raw347
  %dict_h2_byte350 = trunc i64 %dict_h2349 to i8
  %dict_capacity_mask351 = sub i64 %mutable_capacity341, 1
  %dict_start_slot352 = and i64 %hash345, %dict_capacity_mask351
  %generic_dict_insert_has_capacity353 = icmp ugt i64 %mutable_capacity341, 0
  br i1 %generic_dict_insert_has_capacity353, label %bb_generic_dict_insert_first83, label %bb_generic_dict_insert_no_capacity84

bb_generic_dict_insert_no_capacity84:
  br label %bb_generic_dict_insert_first_done82

bb_generic_dict_insert_first83:
  %generic_dict_control_slot354 = getelementptr i8, ptr %mutable_ptr339, i64 %dict_start_slot352
  %generic_dict_control355 = load i8, ptr %generic_dict_control_slot354, align 1
  %generic_dict_insert_first_empty356 = icmp eq i8 %generic_dict_control355, 0
  br i1 %generic_dict_insert_first_empty356, label %bb_generic_dict_insert_first_vacant81, label %bb_generic_dict_insert_first_occupied77

bb_generic_dict_insert_first_occupied77:
  %generic_dict_insert_first_h2357 = icmp eq i8 %generic_dict_control355, %dict_h2_byte350
  br i1 %generic_dict_insert_first_h2357, label %bb_generic_dict_insert_first_compare78, label %bb_generic_dict_insert_first_fallback80

bb_generic_dict_insert_first_compare78:
  %generic_dict_insert_first_key_entries_offset_mirror358 = add i64 %mutable_capacity341, 23
  %generic_dict_insert_first_key_entries_offset359 = and i64 %generic_dict_insert_first_key_entries_offset_mirror358, -8
  %generic_dict_insert_first_key_entries360 = getelementptr i8, ptr %mutable_ptr339, i64 %generic_dict_insert_first_key_entries_offset359
  %generic_dict_insert_first_key_entry_offset361 = mul i64 %dict_start_slot352, 4
  %generic_dict_insert_first_key_slot362 = getelementptr i8, ptr %generic_dict_insert_first_key_entries360, i64 %generic_dict_insert_first_key_entry_offset361
  %generic_dict_insert_first_key363 = load i32, ptr %generic_dict_insert_first_key_slot362, align 4
  %generic_dict_key_equal364 = icmp eq i32 %generic_dict_insert_first_key363, 20
  br i1 %generic_dict_key_equal364, label %bb_generic_dict_insert_first_match79, label %bb_generic_dict_insert_first_fallback80

bb_generic_dict_insert_first_match79:
  br label %bb_generic_dict_insert_first_done82

bb_generic_dict_insert_first_vacant81:
  br label %bb_generic_dict_insert_first_done82

bb_generic_dict_insert_first_fallback80:
  %hash_key365 = sext i32 20 to i64
  %hash_high367 = lshr i64 %hash_key365, 32
  %hash_fold366 = xor i64 %hash_key365, %hash_high367
  %hash368 = mul i64 %hash_fold366, -7046029254386353131
  %dict_h2_shifted369 = lshr i64 %hash368, 57
  %dict_h2_raw370 = and i64 %dict_h2_shifted369, 127
  %dict_h2_zero371 = icmp eq i64 %dict_h2_raw370, 0
  %dict_h2372 = select i1 %dict_h2_zero371, i64 1, i64 %dict_h2_raw370
  %dict_h2_byte373 = trunc i64 %dict_h2372 to i8
  %dict_capacity_mask374 = sub i64 %mutable_capacity341, 1
  %dict_start_slot375 = and i64 %hash368, %dict_capacity_mask374
  br label %bb_generic_dict_group_find85

bb_generic_dict_group_find85:
  %generic_dict_group_probe378 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback80 ], [ %generic_dict_group_next_probe376, %bb_generic_dict_group_next93 ]
  %generic_dict_group_deleted379 = phi i64 [ %mutable_capacity341, %bb_generic_dict_insert_first_fallback80 ], [ %generic_dict_group_next_deleted377, %bb_generic_dict_group_next93 ]
  %generic_dict_group_active380 = icmp ult i64 %generic_dict_group_probe378, %mutable_capacity341
  br i1 %generic_dict_group_active380, label %bb_generic_dict_group_body86, label %bb_generic_dict_group_miss94

bb_generic_dict_group_body86:
  %generic_dict_group_unwrapped381 = add i64 %dict_start_slot375, %generic_dict_group_probe378
  %generic_dict_group_start382 = and i64 %generic_dict_group_unwrapped381, %dict_capacity_mask374
  %generic_dict_group_pointer383 = getelementptr i8, ptr %mutable_ptr339, i64 %generic_dict_group_start382
  %generic_dict_group_controls384 = load <16 x i8>, ptr %generic_dict_group_pointer383, align 1
  %generic_dict_group_h2_seed385 = insertelement <16 x i8> poison, i8 %dict_h2_byte373, i64 0
  %generic_dict_group_h2_vector386 = shufflevector <16 x i8> %generic_dict_group_h2_seed385, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector387 = icmp eq <16 x i8> %generic_dict_group_controls384, %generic_dict_group_h2_vector386
  %generic_dict_group_match_bits388 = bitcast <16 x i1> %generic_dict_group_matches_vector387 to i16
  %generic_dict_group_empty_vector389 = icmp eq <16 x i8> %generic_dict_group_controls384, zeroinitializer
  %generic_dict_group_empty_bits390 = bitcast <16 x i1> %generic_dict_group_empty_vector389 to i16
  %generic_dict_group_deleted_seed391 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector392 = shufflevector <16 x i8> %generic_dict_group_deleted_seed391, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches393 = icmp eq <16 x i8> %generic_dict_group_controls384, %generic_dict_group_deleted_vector392
  %generic_dict_group_deleted_bits394 = bitcast <16 x i1> %generic_dict_group_deleted_matches393 to i16
  %generic_dict_group_has_deleted395 = icmp ne i16 %generic_dict_group_deleted_bits394, 0
  %generic_dict_group_no_previous_deleted396 = icmp eq i64 %generic_dict_group_deleted379, %mutable_capacity341
  %generic_dict_group_capture_deleted397 = and i1 %generic_dict_group_has_deleted395, %generic_dict_group_no_previous_deleted396
  %generic_dict_group_deleted_offset16398 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits394, i1 false)
  %generic_dict_group_deleted_offset399 = zext i16 %generic_dict_group_deleted_offset16398 to i64
  %generic_dict_group_deleted_unwrapped400 = add i64 %generic_dict_group_start382, %generic_dict_group_deleted_offset399
  %generic_dict_group_deleted_slot401 = and i64 %generic_dict_group_deleted_unwrapped400, %dict_capacity_mask374
  %generic_dict_group_captured_deleted402 = select i1 %generic_dict_group_capture_deleted397, i64 %generic_dict_group_deleted_slot401, i64 %generic_dict_group_deleted379
  br label %bb_generic_dict_candidate_loop87

bb_generic_dict_candidate_loop87:
  %generic_dict_candidate_bits403 = phi i16 [ %generic_dict_group_match_bits388, %bb_generic_dict_group_body86 ], [ %generic_dict_candidate_cleared_bits404, %bb_generic_dict_candidate_next89 ]
  %generic_dict_has_candidate405 = icmp ne i16 %generic_dict_candidate_bits403, 0
  br i1 %generic_dict_has_candidate405, label %bb_generic_dict_candidate_body88, label %bb_generic_dict_group_decision90

bb_generic_dict_candidate_body88:
  %generic_dict_candidate_offset16406 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits403, i1 false)
  %generic_dict_candidate_offset407 = zext i16 %generic_dict_candidate_offset16406 to i64
  %generic_dict_candidate_unwrapped408 = add i64 %generic_dict_group_start382, %generic_dict_candidate_offset407
  %generic_dict_candidate_slot409 = and i64 %generic_dict_candidate_unwrapped408, %dict_capacity_mask374
  %generic_dict_key_entries_offset_mirror410 = add i64 %mutable_capacity341, 23
  %generic_dict_key_entries_offset411 = and i64 %generic_dict_key_entries_offset_mirror410, -8
  %generic_dict_key_entries412 = getelementptr i8, ptr %mutable_ptr339, i64 %generic_dict_key_entries_offset411
  %generic_dict_key_entry_offset413 = mul i64 %generic_dict_candidate_slot409, 4
  %generic_dict_key_slot414 = getelementptr i8, ptr %generic_dict_key_entries412, i64 %generic_dict_key_entry_offset413
  %generic_dict_key415 = load i32, ptr %generic_dict_key_slot414, align 4
  %generic_dict_key_equal416 = icmp eq i32 %generic_dict_key415, 20
  br i1 %generic_dict_key_equal416, label %bb_generic_dict_group_match92, label %bb_generic_dict_candidate_next89

bb_generic_dict_candidate_next89:
  %generic_dict_candidate_bits_minus_one417 = sub i16 %generic_dict_candidate_bits403, 1
  %generic_dict_candidate_cleared_bits404 = and i16 %generic_dict_candidate_bits403, %generic_dict_candidate_bits_minus_one417
  br label %bb_generic_dict_candidate_loop87

bb_generic_dict_group_decision90:
  %generic_dict_group_has_empty418 = icmp ne i16 %generic_dict_group_empty_bits390, 0
  br i1 %generic_dict_group_has_empty418, label %bb_generic_dict_group_empty91, label %bb_generic_dict_group_next93

bb_generic_dict_group_empty91:
  %generic_dict_group_empty_offset16419 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits390, i1 false)
  %generic_dict_group_empty_offset420 = zext i16 %generic_dict_group_empty_offset16419 to i64
  %generic_dict_group_empty_unwrapped421 = add i64 %generic_dict_group_start382, %generic_dict_group_empty_offset420
  %generic_dict_group_empty_slot422 = and i64 %generic_dict_group_empty_unwrapped421, %dict_capacity_mask374
  %generic_dict_group_use_empty423 = icmp eq i64 %generic_dict_group_captured_deleted402, %mutable_capacity341
  %generic_dict_group_insertion_slot424 = select i1 %generic_dict_group_use_empty423, i64 %generic_dict_group_empty_slot422, i64 %generic_dict_group_captured_deleted402
  br label %bb_generic_dict_group_done95

bb_generic_dict_group_match92:
  br label %bb_generic_dict_group_done95

bb_generic_dict_group_next93:
  %generic_dict_group_next_probe376 = add i64 %generic_dict_group_probe378, 16
  %generic_dict_group_next_deleted377 = add i64 %generic_dict_group_captured_deleted402, 0
  br label %bb_generic_dict_group_find85

bb_generic_dict_group_miss94:
  %generic_dict_group_miss_no_deleted425 = icmp eq i64 %generic_dict_group_deleted379, %mutable_capacity341
  %generic_dict_group_miss_slot426 = select i1 %generic_dict_group_miss_no_deleted425, i64 0, i64 %generic_dict_group_deleted379
  br label %bb_generic_dict_group_done95

bb_generic_dict_group_done95:
  %generic_dict_find_found427 = phi i1 [ false, %bb_generic_dict_group_empty91 ], [ true, %bb_generic_dict_group_match92 ], [ false, %bb_generic_dict_group_miss94 ]
  %generic_dict_find_slot_result428 = phi i64 [ %generic_dict_group_insertion_slot424, %bb_generic_dict_group_empty91 ], [ %generic_dict_candidate_slot409, %bb_generic_dict_group_match92 ], [ %generic_dict_group_miss_slot426, %bb_generic_dict_group_miss94 ]
  br label %bb_generic_dict_insert_first_done82

bb_generic_dict_insert_first_done82:
  %generic_dict_insert_first_found429 = phi i1 [ true, %bb_generic_dict_insert_first_match79 ], [ false, %bb_generic_dict_insert_first_vacant81 ], [ %generic_dict_find_found427, %bb_generic_dict_group_done95 ], [ false, %bb_generic_dict_insert_no_capacity84 ]
  %generic_dict_insert_first_slot_result430 = phi i64 [ %dict_start_slot352, %bb_generic_dict_insert_first_match79 ], [ %dict_start_slot352, %bb_generic_dict_insert_first_vacant81 ], [ %generic_dict_find_slot_result428, %bb_generic_dict_group_done95 ], [ 0, %bb_generic_dict_insert_no_capacity84 ]
  br i1 %generic_dict_insert_first_found429, label %bb_set_insert_duplicate96, label %bb_set_insert_new97

bb_set_insert_duplicate96:
  br label %bb_set_insert_done100

bb_set_insert_new97:
  %set_insert_length431 = add i64 %mutable_len340, 1
  %set_insert_load_num432 = mul i64 %set_insert_length431, 8
  %set_insert_load_den433 = mul i64 %mutable_capacity341, 7
  %set_insert_should_grow434 = icmp ugt i64 %set_insert_load_num432, %set_insert_load_den433
  br i1 %set_insert_should_grow434, label %bb_set_insert_grow99, label %bb_set_insert_current98

bb_set_insert_current98:
  %set_key_entries_offset_mirror435 = add i64 %mutable_capacity341, 23
  %set_key_entries_offset436 = and i64 %set_key_entries_offset_mirror435, -8
  %set_key_entries437 = getelementptr i8, ptr %mutable_ptr339, i64 %set_key_entries_offset436
  %set_key_entry_offset438 = mul i64 %generic_dict_insert_first_slot_result430, 4
  %set_key_slot439 = getelementptr i8, ptr %set_key_entries437, i64 %set_key_entry_offset438
  store i32 20, ptr %set_key_slot439, align 4
  %generic_dict_control_slot440 = getelementptr i8, ptr %mutable_ptr339, i64 %generic_dict_insert_first_slot_result430
  store i8 %dict_h2_byte350, ptr %generic_dict_control_slot440, align 1
  %generic_dict_control_mirrored441 = icmp ult i64 %generic_dict_insert_first_slot_result430, 16
  br i1 %generic_dict_control_mirrored441, label %bb_generic_dict_control_mirror101, label %bb_generic_dict_control_done102

bb_generic_dict_control_mirror101:
  %generic_dict_control_mirror_index442 = add i64 %mutable_capacity341, %generic_dict_insert_first_slot_result430
  %generic_dict_control_mirror_slot443 = getelementptr i8, ptr %mutable_ptr339, i64 %generic_dict_control_mirror_index442
  store i8 %dict_h2_byte350, ptr %generic_dict_control_mirror_slot443, align 1
  br label %bb_generic_dict_control_done102

bb_generic_dict_control_done102:
  br label %bb_set_insert_done100

bb_set_insert_grow99:
  %set_grown_capacity444 = mul i64 %mutable_capacity341, 2
  %generic_dict_entries_offset_mirror445 = add i64 %set_grown_capacity444, 23
  %generic_dict_entries_offset446 = and i64 %generic_dict_entries_offset_mirror445, -8
  %generic_dict_entries_bytes447 = mul i64 %set_grown_capacity444, 4
  %generic_dict_bytes448 = add i64 %generic_dict_entries_offset446, %generic_dict_entries_bytes447
  %heap449 = call ptr @sollang_alloc(i64 %generic_dict_bytes448)
  %heap_ok450 = icmp ne ptr %heap449, null
  br i1 %heap_ok450, label %bb_alloc_ok103, label %bb_alloc_fail104

bb_alloc_fail104:
  %trap_stderr451 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr451, ptr @.slg.str.module.x.2, i32 25, ptr %trap_written452, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok103:
  %generic_dict_control_bytes453 = add i64 %set_grown_capacity444, 16
  call void @llvm.memset.p0.i64(ptr %heap449, i8 0, i64 %generic_dict_control_bytes453, i1 false)
  br label %bb_set_rehash105

bb_set_rehash105:
  %set_rehash_index455 = phi i64 [ 0, %bb_alloc_ok103 ], [ %set_rehash_next_index454, %bb_set_rehash_next108 ]
  %set_rehash_active456 = icmp ult i64 %set_rehash_index455, %mutable_capacity341
  br i1 %set_rehash_active456, label %bb_set_rehash_body106, label %bb_set_rehash_done109

bb_set_rehash_body106:
  %generic_dict_control_slot457 = getelementptr i8, ptr %mutable_ptr339, i64 %set_rehash_index455
  %generic_dict_control458 = load i8, ptr %generic_dict_control_slot457, align 1
  %set_rehash_occupied459 = icmp sgt i8 %generic_dict_control458, 0
  br i1 %set_rehash_occupied459, label %bb_set_rehash_move107, label %bb_set_rehash_next108

bb_set_rehash_move107:
  %set_rehash_key_entries_offset_mirror460 = add i64 %mutable_capacity341, 23
  %set_rehash_key_entries_offset461 = and i64 %set_rehash_key_entries_offset_mirror460, -8
  %set_rehash_key_entries462 = getelementptr i8, ptr %mutable_ptr339, i64 %set_rehash_key_entries_offset461
  %set_rehash_key_entry_offset463 = mul i64 %set_rehash_index455, 4
  %set_rehash_key_slot464 = getelementptr i8, ptr %set_rehash_key_entries462, i64 %set_rehash_key_entry_offset463
  %set_rehash_key465 = load i32, ptr %set_rehash_key_slot464, align 4
  %hash_key466 = sext i32 %set_rehash_key465 to i64
  %hash_high468 = lshr i64 %hash_key466, 32
  %hash_fold467 = xor i64 %hash_key466, %hash_high468
  %hash469 = mul i64 %hash_fold467, -7046029254386353131
  %dict_h2_shifted470 = lshr i64 %hash469, 57
  %dict_h2_raw471 = and i64 %dict_h2_shifted470, 127
  %dict_h2_zero472 = icmp eq i64 %dict_h2_raw471, 0
  %dict_h2473 = select i1 %dict_h2_zero472, i64 1, i64 %dict_h2_raw471
  %dict_h2_byte474 = trunc i64 %dict_h2473 to i8
  %dict_capacity_mask475 = sub i64 %set_grown_capacity444, 1
  %dict_start_slot476 = and i64 %hash469, %dict_capacity_mask475
  %generic_dict_insert_has_capacity477 = icmp ugt i64 %set_grown_capacity444, 0
  br i1 %generic_dict_insert_has_capacity477, label %bb_generic_dict_insert_first116, label %bb_generic_dict_insert_no_capacity117

bb_generic_dict_insert_no_capacity117:
  br label %bb_generic_dict_insert_first_done115

bb_generic_dict_insert_first116:
  %generic_dict_control_slot478 = getelementptr i8, ptr %heap449, i64 %dict_start_slot476
  %generic_dict_control479 = load i8, ptr %generic_dict_control_slot478, align 1
  %generic_dict_insert_first_empty480 = icmp eq i8 %generic_dict_control479, 0
  br i1 %generic_dict_insert_first_empty480, label %bb_generic_dict_insert_first_vacant114, label %bb_generic_dict_insert_first_occupied110

bb_generic_dict_insert_first_occupied110:
  %generic_dict_insert_first_h2481 = icmp eq i8 %generic_dict_control479, %dict_h2_byte474
  br i1 %generic_dict_insert_first_h2481, label %bb_generic_dict_insert_first_compare111, label %bb_generic_dict_insert_first_fallback113

bb_generic_dict_insert_first_compare111:
  %generic_dict_insert_first_key_entries_offset_mirror482 = add i64 %set_grown_capacity444, 23
  %generic_dict_insert_first_key_entries_offset483 = and i64 %generic_dict_insert_first_key_entries_offset_mirror482, -8
  %generic_dict_insert_first_key_entries484 = getelementptr i8, ptr %heap449, i64 %generic_dict_insert_first_key_entries_offset483
  %generic_dict_insert_first_key_entry_offset485 = mul i64 %dict_start_slot476, 4
  %generic_dict_insert_first_key_slot486 = getelementptr i8, ptr %generic_dict_insert_first_key_entries484, i64 %generic_dict_insert_first_key_entry_offset485
  %generic_dict_insert_first_key487 = load i32, ptr %generic_dict_insert_first_key_slot486, align 4
  %generic_dict_key_equal488 = icmp eq i32 %generic_dict_insert_first_key487, %set_rehash_key465
  br i1 %generic_dict_key_equal488, label %bb_generic_dict_insert_first_match112, label %bb_generic_dict_insert_first_fallback113

bb_generic_dict_insert_first_match112:
  br label %bb_generic_dict_insert_first_done115

bb_generic_dict_insert_first_vacant114:
  br label %bb_generic_dict_insert_first_done115

bb_generic_dict_insert_first_fallback113:
  %hash_key489 = sext i32 %set_rehash_key465 to i64
  %hash_high491 = lshr i64 %hash_key489, 32
  %hash_fold490 = xor i64 %hash_key489, %hash_high491
  %hash492 = mul i64 %hash_fold490, -7046029254386353131
  %dict_h2_shifted493 = lshr i64 %hash492, 57
  %dict_h2_raw494 = and i64 %dict_h2_shifted493, 127
  %dict_h2_zero495 = icmp eq i64 %dict_h2_raw494, 0
  %dict_h2496 = select i1 %dict_h2_zero495, i64 1, i64 %dict_h2_raw494
  %dict_h2_byte497 = trunc i64 %dict_h2496 to i8
  %dict_capacity_mask498 = sub i64 %set_grown_capacity444, 1
  %dict_start_slot499 = and i64 %hash492, %dict_capacity_mask498
  br label %bb_generic_dict_group_find118

bb_generic_dict_group_find118:
  %generic_dict_group_probe502 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback113 ], [ %generic_dict_group_next_probe500, %bb_generic_dict_group_next126 ]
  %generic_dict_group_deleted503 = phi i64 [ %set_grown_capacity444, %bb_generic_dict_insert_first_fallback113 ], [ %generic_dict_group_next_deleted501, %bb_generic_dict_group_next126 ]
  %generic_dict_group_active504 = icmp ult i64 %generic_dict_group_probe502, %set_grown_capacity444
  br i1 %generic_dict_group_active504, label %bb_generic_dict_group_body119, label %bb_generic_dict_group_miss127

bb_generic_dict_group_body119:
  %generic_dict_group_unwrapped505 = add i64 %dict_start_slot499, %generic_dict_group_probe502
  %generic_dict_group_start506 = and i64 %generic_dict_group_unwrapped505, %dict_capacity_mask498
  %generic_dict_group_pointer507 = getelementptr i8, ptr %heap449, i64 %generic_dict_group_start506
  %generic_dict_group_controls508 = load <16 x i8>, ptr %generic_dict_group_pointer507, align 1
  %generic_dict_group_h2_seed509 = insertelement <16 x i8> poison, i8 %dict_h2_byte497, i64 0
  %generic_dict_group_h2_vector510 = shufflevector <16 x i8> %generic_dict_group_h2_seed509, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector511 = icmp eq <16 x i8> %generic_dict_group_controls508, %generic_dict_group_h2_vector510
  %generic_dict_group_match_bits512 = bitcast <16 x i1> %generic_dict_group_matches_vector511 to i16
  %generic_dict_group_empty_vector513 = icmp eq <16 x i8> %generic_dict_group_controls508, zeroinitializer
  %generic_dict_group_empty_bits514 = bitcast <16 x i1> %generic_dict_group_empty_vector513 to i16
  %generic_dict_group_deleted_seed515 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector516 = shufflevector <16 x i8> %generic_dict_group_deleted_seed515, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches517 = icmp eq <16 x i8> %generic_dict_group_controls508, %generic_dict_group_deleted_vector516
  %generic_dict_group_deleted_bits518 = bitcast <16 x i1> %generic_dict_group_deleted_matches517 to i16
  %generic_dict_group_has_deleted519 = icmp ne i16 %generic_dict_group_deleted_bits518, 0
  %generic_dict_group_no_previous_deleted520 = icmp eq i64 %generic_dict_group_deleted503, %set_grown_capacity444
  %generic_dict_group_capture_deleted521 = and i1 %generic_dict_group_has_deleted519, %generic_dict_group_no_previous_deleted520
  %generic_dict_group_deleted_offset16522 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits518, i1 false)
  %generic_dict_group_deleted_offset523 = zext i16 %generic_dict_group_deleted_offset16522 to i64
  %generic_dict_group_deleted_unwrapped524 = add i64 %generic_dict_group_start506, %generic_dict_group_deleted_offset523
  %generic_dict_group_deleted_slot525 = and i64 %generic_dict_group_deleted_unwrapped524, %dict_capacity_mask498
  %generic_dict_group_captured_deleted526 = select i1 %generic_dict_group_capture_deleted521, i64 %generic_dict_group_deleted_slot525, i64 %generic_dict_group_deleted503
  br label %bb_generic_dict_candidate_loop120

bb_generic_dict_candidate_loop120:
  %generic_dict_candidate_bits527 = phi i16 [ %generic_dict_group_match_bits512, %bb_generic_dict_group_body119 ], [ %generic_dict_candidate_cleared_bits528, %bb_generic_dict_candidate_next122 ]
  %generic_dict_has_candidate529 = icmp ne i16 %generic_dict_candidate_bits527, 0
  br i1 %generic_dict_has_candidate529, label %bb_generic_dict_candidate_body121, label %bb_generic_dict_group_decision123

bb_generic_dict_candidate_body121:
  %generic_dict_candidate_offset16530 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits527, i1 false)
  %generic_dict_candidate_offset531 = zext i16 %generic_dict_candidate_offset16530 to i64
  %generic_dict_candidate_unwrapped532 = add i64 %generic_dict_group_start506, %generic_dict_candidate_offset531
  %generic_dict_candidate_slot533 = and i64 %generic_dict_candidate_unwrapped532, %dict_capacity_mask498
  %generic_dict_key_entries_offset_mirror534 = add i64 %set_grown_capacity444, 23
  %generic_dict_key_entries_offset535 = and i64 %generic_dict_key_entries_offset_mirror534, -8
  %generic_dict_key_entries536 = getelementptr i8, ptr %heap449, i64 %generic_dict_key_entries_offset535
  %generic_dict_key_entry_offset537 = mul i64 %generic_dict_candidate_slot533, 4
  %generic_dict_key_slot538 = getelementptr i8, ptr %generic_dict_key_entries536, i64 %generic_dict_key_entry_offset537
  %generic_dict_key539 = load i32, ptr %generic_dict_key_slot538, align 4
  %generic_dict_key_equal540 = icmp eq i32 %generic_dict_key539, %set_rehash_key465
  br i1 %generic_dict_key_equal540, label %bb_generic_dict_group_match125, label %bb_generic_dict_candidate_next122

bb_generic_dict_candidate_next122:
  %generic_dict_candidate_bits_minus_one541 = sub i16 %generic_dict_candidate_bits527, 1
  %generic_dict_candidate_cleared_bits528 = and i16 %generic_dict_candidate_bits527, %generic_dict_candidate_bits_minus_one541
  br label %bb_generic_dict_candidate_loop120

bb_generic_dict_group_decision123:
  %generic_dict_group_has_empty542 = icmp ne i16 %generic_dict_group_empty_bits514, 0
  br i1 %generic_dict_group_has_empty542, label %bb_generic_dict_group_empty124, label %bb_generic_dict_group_next126

bb_generic_dict_group_empty124:
  %generic_dict_group_empty_offset16543 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits514, i1 false)
  %generic_dict_group_empty_offset544 = zext i16 %generic_dict_group_empty_offset16543 to i64
  %generic_dict_group_empty_unwrapped545 = add i64 %generic_dict_group_start506, %generic_dict_group_empty_offset544
  %generic_dict_group_empty_slot546 = and i64 %generic_dict_group_empty_unwrapped545, %dict_capacity_mask498
  %generic_dict_group_use_empty547 = icmp eq i64 %generic_dict_group_captured_deleted526, %set_grown_capacity444
  %generic_dict_group_insertion_slot548 = select i1 %generic_dict_group_use_empty547, i64 %generic_dict_group_empty_slot546, i64 %generic_dict_group_captured_deleted526
  br label %bb_generic_dict_group_done128

bb_generic_dict_group_match125:
  br label %bb_generic_dict_group_done128

bb_generic_dict_group_next126:
  %generic_dict_group_next_probe500 = add i64 %generic_dict_group_probe502, 16
  %generic_dict_group_next_deleted501 = add i64 %generic_dict_group_captured_deleted526, 0
  br label %bb_generic_dict_group_find118

bb_generic_dict_group_miss127:
  %generic_dict_group_miss_no_deleted549 = icmp eq i64 %generic_dict_group_deleted503, %set_grown_capacity444
  %generic_dict_group_miss_slot550 = select i1 %generic_dict_group_miss_no_deleted549, i64 0, i64 %generic_dict_group_deleted503
  br label %bb_generic_dict_group_done128

bb_generic_dict_group_done128:
  %generic_dict_find_found551 = phi i1 [ false, %bb_generic_dict_group_empty124 ], [ true, %bb_generic_dict_group_match125 ], [ false, %bb_generic_dict_group_miss127 ]
  %generic_dict_find_slot_result552 = phi i64 [ %generic_dict_group_insertion_slot548, %bb_generic_dict_group_empty124 ], [ %generic_dict_candidate_slot533, %bb_generic_dict_group_match125 ], [ %generic_dict_group_miss_slot550, %bb_generic_dict_group_miss127 ]
  br label %bb_generic_dict_insert_first_done115

bb_generic_dict_insert_first_done115:
  %generic_dict_insert_first_found553 = phi i1 [ true, %bb_generic_dict_insert_first_match112 ], [ false, %bb_generic_dict_insert_first_vacant114 ], [ %generic_dict_find_found551, %bb_generic_dict_group_done128 ], [ false, %bb_generic_dict_insert_no_capacity117 ]
  %generic_dict_insert_first_slot_result554 = phi i64 [ %dict_start_slot476, %bb_generic_dict_insert_first_match112 ], [ %dict_start_slot476, %bb_generic_dict_insert_first_vacant114 ], [ %generic_dict_find_slot_result552, %bb_generic_dict_group_done128 ], [ 0, %bb_generic_dict_insert_no_capacity117 ]
  %set_key_entries_offset_mirror555 = add i64 %set_grown_capacity444, 23
  %set_key_entries_offset556 = and i64 %set_key_entries_offset_mirror555, -8
  %set_key_entries557 = getelementptr i8, ptr %heap449, i64 %set_key_entries_offset556
  %set_key_entry_offset558 = mul i64 %generic_dict_insert_first_slot_result554, 4
  %set_key_slot559 = getelementptr i8, ptr %set_key_entries557, i64 %set_key_entry_offset558
  store i32 %set_rehash_key465, ptr %set_key_slot559, align 4
  %generic_dict_control_slot560 = getelementptr i8, ptr %heap449, i64 %generic_dict_insert_first_slot_result554
  store i8 %dict_h2_byte474, ptr %generic_dict_control_slot560, align 1
  %generic_dict_control_mirrored561 = icmp ult i64 %generic_dict_insert_first_slot_result554, 16
  br i1 %generic_dict_control_mirrored561, label %bb_generic_dict_control_mirror129, label %bb_generic_dict_control_done130

bb_generic_dict_control_mirror129:
  %generic_dict_control_mirror_index562 = add i64 %set_grown_capacity444, %generic_dict_insert_first_slot_result554
  %generic_dict_control_mirror_slot563 = getelementptr i8, ptr %heap449, i64 %generic_dict_control_mirror_index562
  store i8 %dict_h2_byte474, ptr %generic_dict_control_mirror_slot563, align 1
  br label %bb_generic_dict_control_done130

bb_generic_dict_control_done130:
  br label %bb_set_rehash_next108

bb_set_rehash_next108:
  %set_rehash_next_index454 = add i64 %set_rehash_index455, 1
  br label %bb_set_rehash105

bb_set_rehash_done109:
  call void @sollang_free(ptr %mutable_ptr339)
  %hash_key564 = sext i32 20 to i64
  %hash_high566 = lshr i64 %hash_key564, 32
  %hash_fold565 = xor i64 %hash_key564, %hash_high566
  %hash567 = mul i64 %hash_fold565, -7046029254386353131
  %dict_h2_shifted568 = lshr i64 %hash567, 57
  %dict_h2_raw569 = and i64 %dict_h2_shifted568, 127
  %dict_h2_zero570 = icmp eq i64 %dict_h2_raw569, 0
  %dict_h2571 = select i1 %dict_h2_zero570, i64 1, i64 %dict_h2_raw569
  %dict_h2_byte572 = trunc i64 %dict_h2571 to i8
  %dict_capacity_mask573 = sub i64 %set_grown_capacity444, 1
  %dict_start_slot574 = and i64 %hash567, %dict_capacity_mask573
  %generic_dict_insert_has_capacity575 = icmp ugt i64 %set_grown_capacity444, 0
  br i1 %generic_dict_insert_has_capacity575, label %bb_generic_dict_insert_first137, label %bb_generic_dict_insert_no_capacity138

bb_generic_dict_insert_no_capacity138:
  br label %bb_generic_dict_insert_first_done136

bb_generic_dict_insert_first137:
  %generic_dict_control_slot576 = getelementptr i8, ptr %heap449, i64 %dict_start_slot574
  %generic_dict_control577 = load i8, ptr %generic_dict_control_slot576, align 1
  %generic_dict_insert_first_empty578 = icmp eq i8 %generic_dict_control577, 0
  br i1 %generic_dict_insert_first_empty578, label %bb_generic_dict_insert_first_vacant135, label %bb_generic_dict_insert_first_occupied131

bb_generic_dict_insert_first_occupied131:
  %generic_dict_insert_first_h2579 = icmp eq i8 %generic_dict_control577, %dict_h2_byte572
  br i1 %generic_dict_insert_first_h2579, label %bb_generic_dict_insert_first_compare132, label %bb_generic_dict_insert_first_fallback134

bb_generic_dict_insert_first_compare132:
  %generic_dict_insert_first_key_entries_offset_mirror580 = add i64 %set_grown_capacity444, 23
  %generic_dict_insert_first_key_entries_offset581 = and i64 %generic_dict_insert_first_key_entries_offset_mirror580, -8
  %generic_dict_insert_first_key_entries582 = getelementptr i8, ptr %heap449, i64 %generic_dict_insert_first_key_entries_offset581
  %generic_dict_insert_first_key_entry_offset583 = mul i64 %dict_start_slot574, 4
  %generic_dict_insert_first_key_slot584 = getelementptr i8, ptr %generic_dict_insert_first_key_entries582, i64 %generic_dict_insert_first_key_entry_offset583
  %generic_dict_insert_first_key585 = load i32, ptr %generic_dict_insert_first_key_slot584, align 4
  %generic_dict_key_equal586 = icmp eq i32 %generic_dict_insert_first_key585, 20
  br i1 %generic_dict_key_equal586, label %bb_generic_dict_insert_first_match133, label %bb_generic_dict_insert_first_fallback134

bb_generic_dict_insert_first_match133:
  br label %bb_generic_dict_insert_first_done136

bb_generic_dict_insert_first_vacant135:
  br label %bb_generic_dict_insert_first_done136

bb_generic_dict_insert_first_fallback134:
  %hash_key587 = sext i32 20 to i64
  %hash_high589 = lshr i64 %hash_key587, 32
  %hash_fold588 = xor i64 %hash_key587, %hash_high589
  %hash590 = mul i64 %hash_fold588, -7046029254386353131
  %dict_h2_shifted591 = lshr i64 %hash590, 57
  %dict_h2_raw592 = and i64 %dict_h2_shifted591, 127
  %dict_h2_zero593 = icmp eq i64 %dict_h2_raw592, 0
  %dict_h2594 = select i1 %dict_h2_zero593, i64 1, i64 %dict_h2_raw592
  %dict_h2_byte595 = trunc i64 %dict_h2594 to i8
  %dict_capacity_mask596 = sub i64 %set_grown_capacity444, 1
  %dict_start_slot597 = and i64 %hash590, %dict_capacity_mask596
  br label %bb_generic_dict_group_find139

bb_generic_dict_group_find139:
  %generic_dict_group_probe600 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback134 ], [ %generic_dict_group_next_probe598, %bb_generic_dict_group_next147 ]
  %generic_dict_group_deleted601 = phi i64 [ %set_grown_capacity444, %bb_generic_dict_insert_first_fallback134 ], [ %generic_dict_group_next_deleted599, %bb_generic_dict_group_next147 ]
  %generic_dict_group_active602 = icmp ult i64 %generic_dict_group_probe600, %set_grown_capacity444
  br i1 %generic_dict_group_active602, label %bb_generic_dict_group_body140, label %bb_generic_dict_group_miss148

bb_generic_dict_group_body140:
  %generic_dict_group_unwrapped603 = add i64 %dict_start_slot597, %generic_dict_group_probe600
  %generic_dict_group_start604 = and i64 %generic_dict_group_unwrapped603, %dict_capacity_mask596
  %generic_dict_group_pointer605 = getelementptr i8, ptr %heap449, i64 %generic_dict_group_start604
  %generic_dict_group_controls606 = load <16 x i8>, ptr %generic_dict_group_pointer605, align 1
  %generic_dict_group_h2_seed607 = insertelement <16 x i8> poison, i8 %dict_h2_byte595, i64 0
  %generic_dict_group_h2_vector608 = shufflevector <16 x i8> %generic_dict_group_h2_seed607, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector609 = icmp eq <16 x i8> %generic_dict_group_controls606, %generic_dict_group_h2_vector608
  %generic_dict_group_match_bits610 = bitcast <16 x i1> %generic_dict_group_matches_vector609 to i16
  %generic_dict_group_empty_vector611 = icmp eq <16 x i8> %generic_dict_group_controls606, zeroinitializer
  %generic_dict_group_empty_bits612 = bitcast <16 x i1> %generic_dict_group_empty_vector611 to i16
  %generic_dict_group_deleted_seed613 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector614 = shufflevector <16 x i8> %generic_dict_group_deleted_seed613, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches615 = icmp eq <16 x i8> %generic_dict_group_controls606, %generic_dict_group_deleted_vector614
  %generic_dict_group_deleted_bits616 = bitcast <16 x i1> %generic_dict_group_deleted_matches615 to i16
  %generic_dict_group_has_deleted617 = icmp ne i16 %generic_dict_group_deleted_bits616, 0
  %generic_dict_group_no_previous_deleted618 = icmp eq i64 %generic_dict_group_deleted601, %set_grown_capacity444
  %generic_dict_group_capture_deleted619 = and i1 %generic_dict_group_has_deleted617, %generic_dict_group_no_previous_deleted618
  %generic_dict_group_deleted_offset16620 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits616, i1 false)
  %generic_dict_group_deleted_offset621 = zext i16 %generic_dict_group_deleted_offset16620 to i64
  %generic_dict_group_deleted_unwrapped622 = add i64 %generic_dict_group_start604, %generic_dict_group_deleted_offset621
  %generic_dict_group_deleted_slot623 = and i64 %generic_dict_group_deleted_unwrapped622, %dict_capacity_mask596
  %generic_dict_group_captured_deleted624 = select i1 %generic_dict_group_capture_deleted619, i64 %generic_dict_group_deleted_slot623, i64 %generic_dict_group_deleted601
  br label %bb_generic_dict_candidate_loop141

bb_generic_dict_candidate_loop141:
  %generic_dict_candidate_bits625 = phi i16 [ %generic_dict_group_match_bits610, %bb_generic_dict_group_body140 ], [ %generic_dict_candidate_cleared_bits626, %bb_generic_dict_candidate_next143 ]
  %generic_dict_has_candidate627 = icmp ne i16 %generic_dict_candidate_bits625, 0
  br i1 %generic_dict_has_candidate627, label %bb_generic_dict_candidate_body142, label %bb_generic_dict_group_decision144

bb_generic_dict_candidate_body142:
  %generic_dict_candidate_offset16628 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits625, i1 false)
  %generic_dict_candidate_offset629 = zext i16 %generic_dict_candidate_offset16628 to i64
  %generic_dict_candidate_unwrapped630 = add i64 %generic_dict_group_start604, %generic_dict_candidate_offset629
  %generic_dict_candidate_slot631 = and i64 %generic_dict_candidate_unwrapped630, %dict_capacity_mask596
  %generic_dict_key_entries_offset_mirror632 = add i64 %set_grown_capacity444, 23
  %generic_dict_key_entries_offset633 = and i64 %generic_dict_key_entries_offset_mirror632, -8
  %generic_dict_key_entries634 = getelementptr i8, ptr %heap449, i64 %generic_dict_key_entries_offset633
  %generic_dict_key_entry_offset635 = mul i64 %generic_dict_candidate_slot631, 4
  %generic_dict_key_slot636 = getelementptr i8, ptr %generic_dict_key_entries634, i64 %generic_dict_key_entry_offset635
  %generic_dict_key637 = load i32, ptr %generic_dict_key_slot636, align 4
  %generic_dict_key_equal638 = icmp eq i32 %generic_dict_key637, 20
  br i1 %generic_dict_key_equal638, label %bb_generic_dict_group_match146, label %bb_generic_dict_candidate_next143

bb_generic_dict_candidate_next143:
  %generic_dict_candidate_bits_minus_one639 = sub i16 %generic_dict_candidate_bits625, 1
  %generic_dict_candidate_cleared_bits626 = and i16 %generic_dict_candidate_bits625, %generic_dict_candidate_bits_minus_one639
  br label %bb_generic_dict_candidate_loop141

bb_generic_dict_group_decision144:
  %generic_dict_group_has_empty640 = icmp ne i16 %generic_dict_group_empty_bits612, 0
  br i1 %generic_dict_group_has_empty640, label %bb_generic_dict_group_empty145, label %bb_generic_dict_group_next147

bb_generic_dict_group_empty145:
  %generic_dict_group_empty_offset16641 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits612, i1 false)
  %generic_dict_group_empty_offset642 = zext i16 %generic_dict_group_empty_offset16641 to i64
  %generic_dict_group_empty_unwrapped643 = add i64 %generic_dict_group_start604, %generic_dict_group_empty_offset642
  %generic_dict_group_empty_slot644 = and i64 %generic_dict_group_empty_unwrapped643, %dict_capacity_mask596
  %generic_dict_group_use_empty645 = icmp eq i64 %generic_dict_group_captured_deleted624, %set_grown_capacity444
  %generic_dict_group_insertion_slot646 = select i1 %generic_dict_group_use_empty645, i64 %generic_dict_group_empty_slot644, i64 %generic_dict_group_captured_deleted624
  br label %bb_generic_dict_group_done149

bb_generic_dict_group_match146:
  br label %bb_generic_dict_group_done149

bb_generic_dict_group_next147:
  %generic_dict_group_next_probe598 = add i64 %generic_dict_group_probe600, 16
  %generic_dict_group_next_deleted599 = add i64 %generic_dict_group_captured_deleted624, 0
  br label %bb_generic_dict_group_find139

bb_generic_dict_group_miss148:
  %generic_dict_group_miss_no_deleted647 = icmp eq i64 %generic_dict_group_deleted601, %set_grown_capacity444
  %generic_dict_group_miss_slot648 = select i1 %generic_dict_group_miss_no_deleted647, i64 0, i64 %generic_dict_group_deleted601
  br label %bb_generic_dict_group_done149

bb_generic_dict_group_done149:
  %generic_dict_find_found649 = phi i1 [ false, %bb_generic_dict_group_empty145 ], [ true, %bb_generic_dict_group_match146 ], [ false, %bb_generic_dict_group_miss148 ]
  %generic_dict_find_slot_result650 = phi i64 [ %generic_dict_group_insertion_slot646, %bb_generic_dict_group_empty145 ], [ %generic_dict_candidate_slot631, %bb_generic_dict_group_match146 ], [ %generic_dict_group_miss_slot648, %bb_generic_dict_group_miss148 ]
  br label %bb_generic_dict_insert_first_done136

bb_generic_dict_insert_first_done136:
  %generic_dict_insert_first_found651 = phi i1 [ true, %bb_generic_dict_insert_first_match133 ], [ false, %bb_generic_dict_insert_first_vacant135 ], [ %generic_dict_find_found649, %bb_generic_dict_group_done149 ], [ false, %bb_generic_dict_insert_no_capacity138 ]
  %generic_dict_insert_first_slot_result652 = phi i64 [ %dict_start_slot574, %bb_generic_dict_insert_first_match133 ], [ %dict_start_slot574, %bb_generic_dict_insert_first_vacant135 ], [ %generic_dict_find_slot_result650, %bb_generic_dict_group_done149 ], [ 0, %bb_generic_dict_insert_no_capacity138 ]
  %set_key_entries_offset_mirror653 = add i64 %set_grown_capacity444, 23
  %set_key_entries_offset654 = and i64 %set_key_entries_offset_mirror653, -8
  %set_key_entries655 = getelementptr i8, ptr %heap449, i64 %set_key_entries_offset654
  %set_key_entry_offset656 = mul i64 %generic_dict_insert_first_slot_result652, 4
  %set_key_slot657 = getelementptr i8, ptr %set_key_entries655, i64 %set_key_entry_offset656
  store i32 20, ptr %set_key_slot657, align 4
  %generic_dict_control_slot658 = getelementptr i8, ptr %heap449, i64 %generic_dict_insert_first_slot_result652
  store i8 %dict_h2_byte572, ptr %generic_dict_control_slot658, align 1
  %generic_dict_control_mirrored659 = icmp ult i64 %generic_dict_insert_first_slot_result652, 16
  br i1 %generic_dict_control_mirrored659, label %bb_generic_dict_control_mirror150, label %bb_generic_dict_control_done151

bb_generic_dict_control_mirror150:
  %generic_dict_control_mirror_index660 = add i64 %set_grown_capacity444, %generic_dict_insert_first_slot_result652
  %generic_dict_control_mirror_slot661 = getelementptr i8, ptr %heap449, i64 %generic_dict_control_mirror_index660
  store i8 %dict_h2_byte572, ptr %generic_dict_control_mirror_slot661, align 1
  br label %bb_generic_dict_control_done151

bb_generic_dict_control_done151:
  br label %bb_set_insert_done100

bb_set_insert_done100:
  %set_pointer662 = phi ptr [ %mutable_ptr339, %bb_set_insert_duplicate96 ], [ %mutable_ptr339, %bb_generic_dict_control_done102 ], [ %heap449, %bb_generic_dict_control_done151 ]
  %set_length663 = phi i64 [ %mutable_len340, %bb_set_insert_duplicate96 ], [ %set_insert_length431, %bb_generic_dict_control_done102 ], [ %set_insert_length431, %bb_generic_dict_control_done151 ]
  %set_capacity664 = phi i64 [ %mutable_capacity341, %bb_set_insert_duplicate96 ], [ %mutable_capacity341, %bb_generic_dict_control_done102 ], [ %set_grown_capacity444, %bb_generic_dict_control_done151 ]
  %set_inserted665 = phi i1 [ false, %bb_set_insert_duplicate96 ], [ true, %bb_generic_dict_control_done102 ], [ true, %bb_generic_dict_control_done151 ]
  store ptr %set_pointer662, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length663, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity664, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr666 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len667 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity668 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key669 = sext i32 10 to i64
  %hash_high671 = lshr i64 %hash_key669, 32
  %hash_fold670 = xor i64 %hash_key669, %hash_high671
  %hash672 = mul i64 %hash_fold670, -7046029254386353131
  %dict_h2_shifted673 = lshr i64 %hash672, 57
  %dict_h2_raw674 = and i64 %dict_h2_shifted673, 127
  %dict_h2_zero675 = icmp eq i64 %dict_h2_raw674, 0
  %dict_h2676 = select i1 %dict_h2_zero675, i64 1, i64 %dict_h2_raw674
  %dict_h2_byte677 = trunc i64 %dict_h2676 to i8
  %dict_capacity_mask678 = sub i64 %mutable_capacity668, 1
  %dict_start_slot679 = and i64 %hash672, %dict_capacity_mask678
  %generic_dict_insert_has_capacity680 = icmp ugt i64 %mutable_capacity668, 0
  br i1 %generic_dict_insert_has_capacity680, label %bb_generic_dict_insert_first158, label %bb_generic_dict_insert_no_capacity159

bb_generic_dict_insert_no_capacity159:
  br label %bb_generic_dict_insert_first_done157

bb_generic_dict_insert_first158:
  %generic_dict_control_slot681 = getelementptr i8, ptr %mutable_ptr666, i64 %dict_start_slot679
  %generic_dict_control682 = load i8, ptr %generic_dict_control_slot681, align 1
  %generic_dict_insert_first_empty683 = icmp eq i8 %generic_dict_control682, 0
  br i1 %generic_dict_insert_first_empty683, label %bb_generic_dict_insert_first_vacant156, label %bb_generic_dict_insert_first_occupied152

bb_generic_dict_insert_first_occupied152:
  %generic_dict_insert_first_h2684 = icmp eq i8 %generic_dict_control682, %dict_h2_byte677
  br i1 %generic_dict_insert_first_h2684, label %bb_generic_dict_insert_first_compare153, label %bb_generic_dict_insert_first_fallback155

bb_generic_dict_insert_first_compare153:
  %generic_dict_insert_first_key_entries_offset_mirror685 = add i64 %mutable_capacity668, 23
  %generic_dict_insert_first_key_entries_offset686 = and i64 %generic_dict_insert_first_key_entries_offset_mirror685, -8
  %generic_dict_insert_first_key_entries687 = getelementptr i8, ptr %mutable_ptr666, i64 %generic_dict_insert_first_key_entries_offset686
  %generic_dict_insert_first_key_entry_offset688 = mul i64 %dict_start_slot679, 4
  %generic_dict_insert_first_key_slot689 = getelementptr i8, ptr %generic_dict_insert_first_key_entries687, i64 %generic_dict_insert_first_key_entry_offset688
  %generic_dict_insert_first_key690 = load i32, ptr %generic_dict_insert_first_key_slot689, align 4
  %generic_dict_key_equal691 = icmp eq i32 %generic_dict_insert_first_key690, 10
  br i1 %generic_dict_key_equal691, label %bb_generic_dict_insert_first_match154, label %bb_generic_dict_insert_first_fallback155

bb_generic_dict_insert_first_match154:
  br label %bb_generic_dict_insert_first_done157

bb_generic_dict_insert_first_vacant156:
  br label %bb_generic_dict_insert_first_done157

bb_generic_dict_insert_first_fallback155:
  %hash_key692 = sext i32 10 to i64
  %hash_high694 = lshr i64 %hash_key692, 32
  %hash_fold693 = xor i64 %hash_key692, %hash_high694
  %hash695 = mul i64 %hash_fold693, -7046029254386353131
  %dict_h2_shifted696 = lshr i64 %hash695, 57
  %dict_h2_raw697 = and i64 %dict_h2_shifted696, 127
  %dict_h2_zero698 = icmp eq i64 %dict_h2_raw697, 0
  %dict_h2699 = select i1 %dict_h2_zero698, i64 1, i64 %dict_h2_raw697
  %dict_h2_byte700 = trunc i64 %dict_h2699 to i8
  %dict_capacity_mask701 = sub i64 %mutable_capacity668, 1
  %dict_start_slot702 = and i64 %hash695, %dict_capacity_mask701
  br label %bb_generic_dict_group_find160

bb_generic_dict_group_find160:
  %generic_dict_group_probe705 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback155 ], [ %generic_dict_group_next_probe703, %bb_generic_dict_group_next168 ]
  %generic_dict_group_deleted706 = phi i64 [ %mutable_capacity668, %bb_generic_dict_insert_first_fallback155 ], [ %generic_dict_group_next_deleted704, %bb_generic_dict_group_next168 ]
  %generic_dict_group_active707 = icmp ult i64 %generic_dict_group_probe705, %mutable_capacity668
  br i1 %generic_dict_group_active707, label %bb_generic_dict_group_body161, label %bb_generic_dict_group_miss169

bb_generic_dict_group_body161:
  %generic_dict_group_unwrapped708 = add i64 %dict_start_slot702, %generic_dict_group_probe705
  %generic_dict_group_start709 = and i64 %generic_dict_group_unwrapped708, %dict_capacity_mask701
  %generic_dict_group_pointer710 = getelementptr i8, ptr %mutable_ptr666, i64 %generic_dict_group_start709
  %generic_dict_group_controls711 = load <16 x i8>, ptr %generic_dict_group_pointer710, align 1
  %generic_dict_group_h2_seed712 = insertelement <16 x i8> poison, i8 %dict_h2_byte700, i64 0
  %generic_dict_group_h2_vector713 = shufflevector <16 x i8> %generic_dict_group_h2_seed712, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector714 = icmp eq <16 x i8> %generic_dict_group_controls711, %generic_dict_group_h2_vector713
  %generic_dict_group_match_bits715 = bitcast <16 x i1> %generic_dict_group_matches_vector714 to i16
  %generic_dict_group_empty_vector716 = icmp eq <16 x i8> %generic_dict_group_controls711, zeroinitializer
  %generic_dict_group_empty_bits717 = bitcast <16 x i1> %generic_dict_group_empty_vector716 to i16
  %generic_dict_group_deleted_seed718 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector719 = shufflevector <16 x i8> %generic_dict_group_deleted_seed718, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches720 = icmp eq <16 x i8> %generic_dict_group_controls711, %generic_dict_group_deleted_vector719
  %generic_dict_group_deleted_bits721 = bitcast <16 x i1> %generic_dict_group_deleted_matches720 to i16
  %generic_dict_group_has_deleted722 = icmp ne i16 %generic_dict_group_deleted_bits721, 0
  %generic_dict_group_no_previous_deleted723 = icmp eq i64 %generic_dict_group_deleted706, %mutable_capacity668
  %generic_dict_group_capture_deleted724 = and i1 %generic_dict_group_has_deleted722, %generic_dict_group_no_previous_deleted723
  %generic_dict_group_deleted_offset16725 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits721, i1 false)
  %generic_dict_group_deleted_offset726 = zext i16 %generic_dict_group_deleted_offset16725 to i64
  %generic_dict_group_deleted_unwrapped727 = add i64 %generic_dict_group_start709, %generic_dict_group_deleted_offset726
  %generic_dict_group_deleted_slot728 = and i64 %generic_dict_group_deleted_unwrapped727, %dict_capacity_mask701
  %generic_dict_group_captured_deleted729 = select i1 %generic_dict_group_capture_deleted724, i64 %generic_dict_group_deleted_slot728, i64 %generic_dict_group_deleted706
  br label %bb_generic_dict_candidate_loop162

bb_generic_dict_candidate_loop162:
  %generic_dict_candidate_bits730 = phi i16 [ %generic_dict_group_match_bits715, %bb_generic_dict_group_body161 ], [ %generic_dict_candidate_cleared_bits731, %bb_generic_dict_candidate_next164 ]
  %generic_dict_has_candidate732 = icmp ne i16 %generic_dict_candidate_bits730, 0
  br i1 %generic_dict_has_candidate732, label %bb_generic_dict_candidate_body163, label %bb_generic_dict_group_decision165

bb_generic_dict_candidate_body163:
  %generic_dict_candidate_offset16733 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits730, i1 false)
  %generic_dict_candidate_offset734 = zext i16 %generic_dict_candidate_offset16733 to i64
  %generic_dict_candidate_unwrapped735 = add i64 %generic_dict_group_start709, %generic_dict_candidate_offset734
  %generic_dict_candidate_slot736 = and i64 %generic_dict_candidate_unwrapped735, %dict_capacity_mask701
  %generic_dict_key_entries_offset_mirror737 = add i64 %mutable_capacity668, 23
  %generic_dict_key_entries_offset738 = and i64 %generic_dict_key_entries_offset_mirror737, -8
  %generic_dict_key_entries739 = getelementptr i8, ptr %mutable_ptr666, i64 %generic_dict_key_entries_offset738
  %generic_dict_key_entry_offset740 = mul i64 %generic_dict_candidate_slot736, 4
  %generic_dict_key_slot741 = getelementptr i8, ptr %generic_dict_key_entries739, i64 %generic_dict_key_entry_offset740
  %generic_dict_key742 = load i32, ptr %generic_dict_key_slot741, align 4
  %generic_dict_key_equal743 = icmp eq i32 %generic_dict_key742, 10
  br i1 %generic_dict_key_equal743, label %bb_generic_dict_group_match167, label %bb_generic_dict_candidate_next164

bb_generic_dict_candidate_next164:
  %generic_dict_candidate_bits_minus_one744 = sub i16 %generic_dict_candidate_bits730, 1
  %generic_dict_candidate_cleared_bits731 = and i16 %generic_dict_candidate_bits730, %generic_dict_candidate_bits_minus_one744
  br label %bb_generic_dict_candidate_loop162

bb_generic_dict_group_decision165:
  %generic_dict_group_has_empty745 = icmp ne i16 %generic_dict_group_empty_bits717, 0
  br i1 %generic_dict_group_has_empty745, label %bb_generic_dict_group_empty166, label %bb_generic_dict_group_next168

bb_generic_dict_group_empty166:
  %generic_dict_group_empty_offset16746 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits717, i1 false)
  %generic_dict_group_empty_offset747 = zext i16 %generic_dict_group_empty_offset16746 to i64
  %generic_dict_group_empty_unwrapped748 = add i64 %generic_dict_group_start709, %generic_dict_group_empty_offset747
  %generic_dict_group_empty_slot749 = and i64 %generic_dict_group_empty_unwrapped748, %dict_capacity_mask701
  %generic_dict_group_use_empty750 = icmp eq i64 %generic_dict_group_captured_deleted729, %mutable_capacity668
  %generic_dict_group_insertion_slot751 = select i1 %generic_dict_group_use_empty750, i64 %generic_dict_group_empty_slot749, i64 %generic_dict_group_captured_deleted729
  br label %bb_generic_dict_group_done170

bb_generic_dict_group_match167:
  br label %bb_generic_dict_group_done170

bb_generic_dict_group_next168:
  %generic_dict_group_next_probe703 = add i64 %generic_dict_group_probe705, 16
  %generic_dict_group_next_deleted704 = add i64 %generic_dict_group_captured_deleted729, 0
  br label %bb_generic_dict_group_find160

bb_generic_dict_group_miss169:
  %generic_dict_group_miss_no_deleted752 = icmp eq i64 %generic_dict_group_deleted706, %mutable_capacity668
  %generic_dict_group_miss_slot753 = select i1 %generic_dict_group_miss_no_deleted752, i64 0, i64 %generic_dict_group_deleted706
  br label %bb_generic_dict_group_done170

bb_generic_dict_group_done170:
  %generic_dict_find_found754 = phi i1 [ false, %bb_generic_dict_group_empty166 ], [ true, %bb_generic_dict_group_match167 ], [ false, %bb_generic_dict_group_miss169 ]
  %generic_dict_find_slot_result755 = phi i64 [ %generic_dict_group_insertion_slot751, %bb_generic_dict_group_empty166 ], [ %generic_dict_candidate_slot736, %bb_generic_dict_group_match167 ], [ %generic_dict_group_miss_slot753, %bb_generic_dict_group_miss169 ]
  br label %bb_generic_dict_insert_first_done157

bb_generic_dict_insert_first_done157:
  %generic_dict_insert_first_found756 = phi i1 [ true, %bb_generic_dict_insert_first_match154 ], [ false, %bb_generic_dict_insert_first_vacant156 ], [ %generic_dict_find_found754, %bb_generic_dict_group_done170 ], [ false, %bb_generic_dict_insert_no_capacity159 ]
  %generic_dict_insert_first_slot_result757 = phi i64 [ %dict_start_slot679, %bb_generic_dict_insert_first_match154 ], [ %dict_start_slot679, %bb_generic_dict_insert_first_vacant156 ], [ %generic_dict_find_slot_result755, %bb_generic_dict_group_done170 ], [ 0, %bb_generic_dict_insert_no_capacity159 ]
  br i1 %generic_dict_insert_first_found756, label %bb_set_insert_duplicate171, label %bb_set_insert_new172

bb_set_insert_duplicate171:
  br label %bb_set_insert_done175

bb_set_insert_new172:
  %set_insert_length758 = add i64 %mutable_len667, 1
  %set_insert_load_num759 = mul i64 %set_insert_length758, 8
  %set_insert_load_den760 = mul i64 %mutable_capacity668, 7
  %set_insert_should_grow761 = icmp ugt i64 %set_insert_load_num759, %set_insert_load_den760
  br i1 %set_insert_should_grow761, label %bb_set_insert_grow174, label %bb_set_insert_current173

bb_set_insert_current173:
  %set_key_entries_offset_mirror762 = add i64 %mutable_capacity668, 23
  %set_key_entries_offset763 = and i64 %set_key_entries_offset_mirror762, -8
  %set_key_entries764 = getelementptr i8, ptr %mutable_ptr666, i64 %set_key_entries_offset763
  %set_key_entry_offset765 = mul i64 %generic_dict_insert_first_slot_result757, 4
  %set_key_slot766 = getelementptr i8, ptr %set_key_entries764, i64 %set_key_entry_offset765
  store i32 10, ptr %set_key_slot766, align 4
  %generic_dict_control_slot767 = getelementptr i8, ptr %mutable_ptr666, i64 %generic_dict_insert_first_slot_result757
  store i8 %dict_h2_byte677, ptr %generic_dict_control_slot767, align 1
  %generic_dict_control_mirrored768 = icmp ult i64 %generic_dict_insert_first_slot_result757, 16
  br i1 %generic_dict_control_mirrored768, label %bb_generic_dict_control_mirror176, label %bb_generic_dict_control_done177

bb_generic_dict_control_mirror176:
  %generic_dict_control_mirror_index769 = add i64 %mutable_capacity668, %generic_dict_insert_first_slot_result757
  %generic_dict_control_mirror_slot770 = getelementptr i8, ptr %mutable_ptr666, i64 %generic_dict_control_mirror_index769
  store i8 %dict_h2_byte677, ptr %generic_dict_control_mirror_slot770, align 1
  br label %bb_generic_dict_control_done177

bb_generic_dict_control_done177:
  br label %bb_set_insert_done175

bb_set_insert_grow174:
  %set_grown_capacity771 = mul i64 %mutable_capacity668, 2
  %generic_dict_entries_offset_mirror772 = add i64 %set_grown_capacity771, 23
  %generic_dict_entries_offset773 = and i64 %generic_dict_entries_offset_mirror772, -8
  %generic_dict_entries_bytes774 = mul i64 %set_grown_capacity771, 4
  %generic_dict_bytes775 = add i64 %generic_dict_entries_offset773, %generic_dict_entries_bytes774
  %heap776 = call ptr @sollang_alloc(i64 %generic_dict_bytes775)
  %heap_ok777 = icmp ne ptr %heap776, null
  br i1 %heap_ok777, label %bb_alloc_ok178, label %bb_alloc_fail179

bb_alloc_fail179:
  %trap_stderr778 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr778, ptr @.slg.str.module.x.3, i32 25, ptr %trap_written779, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok178:
  %generic_dict_control_bytes780 = add i64 %set_grown_capacity771, 16
  call void @llvm.memset.p0.i64(ptr %heap776, i8 0, i64 %generic_dict_control_bytes780, i1 false)
  br label %bb_set_rehash180

bb_set_rehash180:
  %set_rehash_index782 = phi i64 [ 0, %bb_alloc_ok178 ], [ %set_rehash_next_index781, %bb_set_rehash_next183 ]
  %set_rehash_active783 = icmp ult i64 %set_rehash_index782, %mutable_capacity668
  br i1 %set_rehash_active783, label %bb_set_rehash_body181, label %bb_set_rehash_done184

bb_set_rehash_body181:
  %generic_dict_control_slot784 = getelementptr i8, ptr %mutable_ptr666, i64 %set_rehash_index782
  %generic_dict_control785 = load i8, ptr %generic_dict_control_slot784, align 1
  %set_rehash_occupied786 = icmp sgt i8 %generic_dict_control785, 0
  br i1 %set_rehash_occupied786, label %bb_set_rehash_move182, label %bb_set_rehash_next183

bb_set_rehash_move182:
  %set_rehash_key_entries_offset_mirror787 = add i64 %mutable_capacity668, 23
  %set_rehash_key_entries_offset788 = and i64 %set_rehash_key_entries_offset_mirror787, -8
  %set_rehash_key_entries789 = getelementptr i8, ptr %mutable_ptr666, i64 %set_rehash_key_entries_offset788
  %set_rehash_key_entry_offset790 = mul i64 %set_rehash_index782, 4
  %set_rehash_key_slot791 = getelementptr i8, ptr %set_rehash_key_entries789, i64 %set_rehash_key_entry_offset790
  %set_rehash_key792 = load i32, ptr %set_rehash_key_slot791, align 4
  %hash_key793 = sext i32 %set_rehash_key792 to i64
  %hash_high795 = lshr i64 %hash_key793, 32
  %hash_fold794 = xor i64 %hash_key793, %hash_high795
  %hash796 = mul i64 %hash_fold794, -7046029254386353131
  %dict_h2_shifted797 = lshr i64 %hash796, 57
  %dict_h2_raw798 = and i64 %dict_h2_shifted797, 127
  %dict_h2_zero799 = icmp eq i64 %dict_h2_raw798, 0
  %dict_h2800 = select i1 %dict_h2_zero799, i64 1, i64 %dict_h2_raw798
  %dict_h2_byte801 = trunc i64 %dict_h2800 to i8
  %dict_capacity_mask802 = sub i64 %set_grown_capacity771, 1
  %dict_start_slot803 = and i64 %hash796, %dict_capacity_mask802
  %generic_dict_insert_has_capacity804 = icmp ugt i64 %set_grown_capacity771, 0
  br i1 %generic_dict_insert_has_capacity804, label %bb_generic_dict_insert_first191, label %bb_generic_dict_insert_no_capacity192

bb_generic_dict_insert_no_capacity192:
  br label %bb_generic_dict_insert_first_done190

bb_generic_dict_insert_first191:
  %generic_dict_control_slot805 = getelementptr i8, ptr %heap776, i64 %dict_start_slot803
  %generic_dict_control806 = load i8, ptr %generic_dict_control_slot805, align 1
  %generic_dict_insert_first_empty807 = icmp eq i8 %generic_dict_control806, 0
  br i1 %generic_dict_insert_first_empty807, label %bb_generic_dict_insert_first_vacant189, label %bb_generic_dict_insert_first_occupied185

bb_generic_dict_insert_first_occupied185:
  %generic_dict_insert_first_h2808 = icmp eq i8 %generic_dict_control806, %dict_h2_byte801
  br i1 %generic_dict_insert_first_h2808, label %bb_generic_dict_insert_first_compare186, label %bb_generic_dict_insert_first_fallback188

bb_generic_dict_insert_first_compare186:
  %generic_dict_insert_first_key_entries_offset_mirror809 = add i64 %set_grown_capacity771, 23
  %generic_dict_insert_first_key_entries_offset810 = and i64 %generic_dict_insert_first_key_entries_offset_mirror809, -8
  %generic_dict_insert_first_key_entries811 = getelementptr i8, ptr %heap776, i64 %generic_dict_insert_first_key_entries_offset810
  %generic_dict_insert_first_key_entry_offset812 = mul i64 %dict_start_slot803, 4
  %generic_dict_insert_first_key_slot813 = getelementptr i8, ptr %generic_dict_insert_first_key_entries811, i64 %generic_dict_insert_first_key_entry_offset812
  %generic_dict_insert_first_key814 = load i32, ptr %generic_dict_insert_first_key_slot813, align 4
  %generic_dict_key_equal815 = icmp eq i32 %generic_dict_insert_first_key814, %set_rehash_key792
  br i1 %generic_dict_key_equal815, label %bb_generic_dict_insert_first_match187, label %bb_generic_dict_insert_first_fallback188

bb_generic_dict_insert_first_match187:
  br label %bb_generic_dict_insert_first_done190

bb_generic_dict_insert_first_vacant189:
  br label %bb_generic_dict_insert_first_done190

bb_generic_dict_insert_first_fallback188:
  %hash_key816 = sext i32 %set_rehash_key792 to i64
  %hash_high818 = lshr i64 %hash_key816, 32
  %hash_fold817 = xor i64 %hash_key816, %hash_high818
  %hash819 = mul i64 %hash_fold817, -7046029254386353131
  %dict_h2_shifted820 = lshr i64 %hash819, 57
  %dict_h2_raw821 = and i64 %dict_h2_shifted820, 127
  %dict_h2_zero822 = icmp eq i64 %dict_h2_raw821, 0
  %dict_h2823 = select i1 %dict_h2_zero822, i64 1, i64 %dict_h2_raw821
  %dict_h2_byte824 = trunc i64 %dict_h2823 to i8
  %dict_capacity_mask825 = sub i64 %set_grown_capacity771, 1
  %dict_start_slot826 = and i64 %hash819, %dict_capacity_mask825
  br label %bb_generic_dict_group_find193

bb_generic_dict_group_find193:
  %generic_dict_group_probe829 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback188 ], [ %generic_dict_group_next_probe827, %bb_generic_dict_group_next201 ]
  %generic_dict_group_deleted830 = phi i64 [ %set_grown_capacity771, %bb_generic_dict_insert_first_fallback188 ], [ %generic_dict_group_next_deleted828, %bb_generic_dict_group_next201 ]
  %generic_dict_group_active831 = icmp ult i64 %generic_dict_group_probe829, %set_grown_capacity771
  br i1 %generic_dict_group_active831, label %bb_generic_dict_group_body194, label %bb_generic_dict_group_miss202

bb_generic_dict_group_body194:
  %generic_dict_group_unwrapped832 = add i64 %dict_start_slot826, %generic_dict_group_probe829
  %generic_dict_group_start833 = and i64 %generic_dict_group_unwrapped832, %dict_capacity_mask825
  %generic_dict_group_pointer834 = getelementptr i8, ptr %heap776, i64 %generic_dict_group_start833
  %generic_dict_group_controls835 = load <16 x i8>, ptr %generic_dict_group_pointer834, align 1
  %generic_dict_group_h2_seed836 = insertelement <16 x i8> poison, i8 %dict_h2_byte824, i64 0
  %generic_dict_group_h2_vector837 = shufflevector <16 x i8> %generic_dict_group_h2_seed836, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector838 = icmp eq <16 x i8> %generic_dict_group_controls835, %generic_dict_group_h2_vector837
  %generic_dict_group_match_bits839 = bitcast <16 x i1> %generic_dict_group_matches_vector838 to i16
  %generic_dict_group_empty_vector840 = icmp eq <16 x i8> %generic_dict_group_controls835, zeroinitializer
  %generic_dict_group_empty_bits841 = bitcast <16 x i1> %generic_dict_group_empty_vector840 to i16
  %generic_dict_group_deleted_seed842 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector843 = shufflevector <16 x i8> %generic_dict_group_deleted_seed842, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches844 = icmp eq <16 x i8> %generic_dict_group_controls835, %generic_dict_group_deleted_vector843
  %generic_dict_group_deleted_bits845 = bitcast <16 x i1> %generic_dict_group_deleted_matches844 to i16
  %generic_dict_group_has_deleted846 = icmp ne i16 %generic_dict_group_deleted_bits845, 0
  %generic_dict_group_no_previous_deleted847 = icmp eq i64 %generic_dict_group_deleted830, %set_grown_capacity771
  %generic_dict_group_capture_deleted848 = and i1 %generic_dict_group_has_deleted846, %generic_dict_group_no_previous_deleted847
  %generic_dict_group_deleted_offset16849 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits845, i1 false)
  %generic_dict_group_deleted_offset850 = zext i16 %generic_dict_group_deleted_offset16849 to i64
  %generic_dict_group_deleted_unwrapped851 = add i64 %generic_dict_group_start833, %generic_dict_group_deleted_offset850
  %generic_dict_group_deleted_slot852 = and i64 %generic_dict_group_deleted_unwrapped851, %dict_capacity_mask825
  %generic_dict_group_captured_deleted853 = select i1 %generic_dict_group_capture_deleted848, i64 %generic_dict_group_deleted_slot852, i64 %generic_dict_group_deleted830
  br label %bb_generic_dict_candidate_loop195

bb_generic_dict_candidate_loop195:
  %generic_dict_candidate_bits854 = phi i16 [ %generic_dict_group_match_bits839, %bb_generic_dict_group_body194 ], [ %generic_dict_candidate_cleared_bits855, %bb_generic_dict_candidate_next197 ]
  %generic_dict_has_candidate856 = icmp ne i16 %generic_dict_candidate_bits854, 0
  br i1 %generic_dict_has_candidate856, label %bb_generic_dict_candidate_body196, label %bb_generic_dict_group_decision198

bb_generic_dict_candidate_body196:
  %generic_dict_candidate_offset16857 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits854, i1 false)
  %generic_dict_candidate_offset858 = zext i16 %generic_dict_candidate_offset16857 to i64
  %generic_dict_candidate_unwrapped859 = add i64 %generic_dict_group_start833, %generic_dict_candidate_offset858
  %generic_dict_candidate_slot860 = and i64 %generic_dict_candidate_unwrapped859, %dict_capacity_mask825
  %generic_dict_key_entries_offset_mirror861 = add i64 %set_grown_capacity771, 23
  %generic_dict_key_entries_offset862 = and i64 %generic_dict_key_entries_offset_mirror861, -8
  %generic_dict_key_entries863 = getelementptr i8, ptr %heap776, i64 %generic_dict_key_entries_offset862
  %generic_dict_key_entry_offset864 = mul i64 %generic_dict_candidate_slot860, 4
  %generic_dict_key_slot865 = getelementptr i8, ptr %generic_dict_key_entries863, i64 %generic_dict_key_entry_offset864
  %generic_dict_key866 = load i32, ptr %generic_dict_key_slot865, align 4
  %generic_dict_key_equal867 = icmp eq i32 %generic_dict_key866, %set_rehash_key792
  br i1 %generic_dict_key_equal867, label %bb_generic_dict_group_match200, label %bb_generic_dict_candidate_next197

bb_generic_dict_candidate_next197:
  %generic_dict_candidate_bits_minus_one868 = sub i16 %generic_dict_candidate_bits854, 1
  %generic_dict_candidate_cleared_bits855 = and i16 %generic_dict_candidate_bits854, %generic_dict_candidate_bits_minus_one868
  br label %bb_generic_dict_candidate_loop195

bb_generic_dict_group_decision198:
  %generic_dict_group_has_empty869 = icmp ne i16 %generic_dict_group_empty_bits841, 0
  br i1 %generic_dict_group_has_empty869, label %bb_generic_dict_group_empty199, label %bb_generic_dict_group_next201

bb_generic_dict_group_empty199:
  %generic_dict_group_empty_offset16870 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits841, i1 false)
  %generic_dict_group_empty_offset871 = zext i16 %generic_dict_group_empty_offset16870 to i64
  %generic_dict_group_empty_unwrapped872 = add i64 %generic_dict_group_start833, %generic_dict_group_empty_offset871
  %generic_dict_group_empty_slot873 = and i64 %generic_dict_group_empty_unwrapped872, %dict_capacity_mask825
  %generic_dict_group_use_empty874 = icmp eq i64 %generic_dict_group_captured_deleted853, %set_grown_capacity771
  %generic_dict_group_insertion_slot875 = select i1 %generic_dict_group_use_empty874, i64 %generic_dict_group_empty_slot873, i64 %generic_dict_group_captured_deleted853
  br label %bb_generic_dict_group_done203

bb_generic_dict_group_match200:
  br label %bb_generic_dict_group_done203

bb_generic_dict_group_next201:
  %generic_dict_group_next_probe827 = add i64 %generic_dict_group_probe829, 16
  %generic_dict_group_next_deleted828 = add i64 %generic_dict_group_captured_deleted853, 0
  br label %bb_generic_dict_group_find193

bb_generic_dict_group_miss202:
  %generic_dict_group_miss_no_deleted876 = icmp eq i64 %generic_dict_group_deleted830, %set_grown_capacity771
  %generic_dict_group_miss_slot877 = select i1 %generic_dict_group_miss_no_deleted876, i64 0, i64 %generic_dict_group_deleted830
  br label %bb_generic_dict_group_done203

bb_generic_dict_group_done203:
  %generic_dict_find_found878 = phi i1 [ false, %bb_generic_dict_group_empty199 ], [ true, %bb_generic_dict_group_match200 ], [ false, %bb_generic_dict_group_miss202 ]
  %generic_dict_find_slot_result879 = phi i64 [ %generic_dict_group_insertion_slot875, %bb_generic_dict_group_empty199 ], [ %generic_dict_candidate_slot860, %bb_generic_dict_group_match200 ], [ %generic_dict_group_miss_slot877, %bb_generic_dict_group_miss202 ]
  br label %bb_generic_dict_insert_first_done190

bb_generic_dict_insert_first_done190:
  %generic_dict_insert_first_found880 = phi i1 [ true, %bb_generic_dict_insert_first_match187 ], [ false, %bb_generic_dict_insert_first_vacant189 ], [ %generic_dict_find_found878, %bb_generic_dict_group_done203 ], [ false, %bb_generic_dict_insert_no_capacity192 ]
  %generic_dict_insert_first_slot_result881 = phi i64 [ %dict_start_slot803, %bb_generic_dict_insert_first_match187 ], [ %dict_start_slot803, %bb_generic_dict_insert_first_vacant189 ], [ %generic_dict_find_slot_result879, %bb_generic_dict_group_done203 ], [ 0, %bb_generic_dict_insert_no_capacity192 ]
  %set_key_entries_offset_mirror882 = add i64 %set_grown_capacity771, 23
  %set_key_entries_offset883 = and i64 %set_key_entries_offset_mirror882, -8
  %set_key_entries884 = getelementptr i8, ptr %heap776, i64 %set_key_entries_offset883
  %set_key_entry_offset885 = mul i64 %generic_dict_insert_first_slot_result881, 4
  %set_key_slot886 = getelementptr i8, ptr %set_key_entries884, i64 %set_key_entry_offset885
  store i32 %set_rehash_key792, ptr %set_key_slot886, align 4
  %generic_dict_control_slot887 = getelementptr i8, ptr %heap776, i64 %generic_dict_insert_first_slot_result881
  store i8 %dict_h2_byte801, ptr %generic_dict_control_slot887, align 1
  %generic_dict_control_mirrored888 = icmp ult i64 %generic_dict_insert_first_slot_result881, 16
  br i1 %generic_dict_control_mirrored888, label %bb_generic_dict_control_mirror204, label %bb_generic_dict_control_done205

bb_generic_dict_control_mirror204:
  %generic_dict_control_mirror_index889 = add i64 %set_grown_capacity771, %generic_dict_insert_first_slot_result881
  %generic_dict_control_mirror_slot890 = getelementptr i8, ptr %heap776, i64 %generic_dict_control_mirror_index889
  store i8 %dict_h2_byte801, ptr %generic_dict_control_mirror_slot890, align 1
  br label %bb_generic_dict_control_done205

bb_generic_dict_control_done205:
  br label %bb_set_rehash_next183

bb_set_rehash_next183:
  %set_rehash_next_index781 = add i64 %set_rehash_index782, 1
  br label %bb_set_rehash180

bb_set_rehash_done184:
  call void @sollang_free(ptr %mutable_ptr666)
  %hash_key891 = sext i32 10 to i64
  %hash_high893 = lshr i64 %hash_key891, 32
  %hash_fold892 = xor i64 %hash_key891, %hash_high893
  %hash894 = mul i64 %hash_fold892, -7046029254386353131
  %dict_h2_shifted895 = lshr i64 %hash894, 57
  %dict_h2_raw896 = and i64 %dict_h2_shifted895, 127
  %dict_h2_zero897 = icmp eq i64 %dict_h2_raw896, 0
  %dict_h2898 = select i1 %dict_h2_zero897, i64 1, i64 %dict_h2_raw896
  %dict_h2_byte899 = trunc i64 %dict_h2898 to i8
  %dict_capacity_mask900 = sub i64 %set_grown_capacity771, 1
  %dict_start_slot901 = and i64 %hash894, %dict_capacity_mask900
  %generic_dict_insert_has_capacity902 = icmp ugt i64 %set_grown_capacity771, 0
  br i1 %generic_dict_insert_has_capacity902, label %bb_generic_dict_insert_first212, label %bb_generic_dict_insert_no_capacity213

bb_generic_dict_insert_no_capacity213:
  br label %bb_generic_dict_insert_first_done211

bb_generic_dict_insert_first212:
  %generic_dict_control_slot903 = getelementptr i8, ptr %heap776, i64 %dict_start_slot901
  %generic_dict_control904 = load i8, ptr %generic_dict_control_slot903, align 1
  %generic_dict_insert_first_empty905 = icmp eq i8 %generic_dict_control904, 0
  br i1 %generic_dict_insert_first_empty905, label %bb_generic_dict_insert_first_vacant210, label %bb_generic_dict_insert_first_occupied206

bb_generic_dict_insert_first_occupied206:
  %generic_dict_insert_first_h2906 = icmp eq i8 %generic_dict_control904, %dict_h2_byte899
  br i1 %generic_dict_insert_first_h2906, label %bb_generic_dict_insert_first_compare207, label %bb_generic_dict_insert_first_fallback209

bb_generic_dict_insert_first_compare207:
  %generic_dict_insert_first_key_entries_offset_mirror907 = add i64 %set_grown_capacity771, 23
  %generic_dict_insert_first_key_entries_offset908 = and i64 %generic_dict_insert_first_key_entries_offset_mirror907, -8
  %generic_dict_insert_first_key_entries909 = getelementptr i8, ptr %heap776, i64 %generic_dict_insert_first_key_entries_offset908
  %generic_dict_insert_first_key_entry_offset910 = mul i64 %dict_start_slot901, 4
  %generic_dict_insert_first_key_slot911 = getelementptr i8, ptr %generic_dict_insert_first_key_entries909, i64 %generic_dict_insert_first_key_entry_offset910
  %generic_dict_insert_first_key912 = load i32, ptr %generic_dict_insert_first_key_slot911, align 4
  %generic_dict_key_equal913 = icmp eq i32 %generic_dict_insert_first_key912, 10
  br i1 %generic_dict_key_equal913, label %bb_generic_dict_insert_first_match208, label %bb_generic_dict_insert_first_fallback209

bb_generic_dict_insert_first_match208:
  br label %bb_generic_dict_insert_first_done211

bb_generic_dict_insert_first_vacant210:
  br label %bb_generic_dict_insert_first_done211

bb_generic_dict_insert_first_fallback209:
  %hash_key914 = sext i32 10 to i64
  %hash_high916 = lshr i64 %hash_key914, 32
  %hash_fold915 = xor i64 %hash_key914, %hash_high916
  %hash917 = mul i64 %hash_fold915, -7046029254386353131
  %dict_h2_shifted918 = lshr i64 %hash917, 57
  %dict_h2_raw919 = and i64 %dict_h2_shifted918, 127
  %dict_h2_zero920 = icmp eq i64 %dict_h2_raw919, 0
  %dict_h2921 = select i1 %dict_h2_zero920, i64 1, i64 %dict_h2_raw919
  %dict_h2_byte922 = trunc i64 %dict_h2921 to i8
  %dict_capacity_mask923 = sub i64 %set_grown_capacity771, 1
  %dict_start_slot924 = and i64 %hash917, %dict_capacity_mask923
  br label %bb_generic_dict_group_find214

bb_generic_dict_group_find214:
  %generic_dict_group_probe927 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback209 ], [ %generic_dict_group_next_probe925, %bb_generic_dict_group_next222 ]
  %generic_dict_group_deleted928 = phi i64 [ %set_grown_capacity771, %bb_generic_dict_insert_first_fallback209 ], [ %generic_dict_group_next_deleted926, %bb_generic_dict_group_next222 ]
  %generic_dict_group_active929 = icmp ult i64 %generic_dict_group_probe927, %set_grown_capacity771
  br i1 %generic_dict_group_active929, label %bb_generic_dict_group_body215, label %bb_generic_dict_group_miss223

bb_generic_dict_group_body215:
  %generic_dict_group_unwrapped930 = add i64 %dict_start_slot924, %generic_dict_group_probe927
  %generic_dict_group_start931 = and i64 %generic_dict_group_unwrapped930, %dict_capacity_mask923
  %generic_dict_group_pointer932 = getelementptr i8, ptr %heap776, i64 %generic_dict_group_start931
  %generic_dict_group_controls933 = load <16 x i8>, ptr %generic_dict_group_pointer932, align 1
  %generic_dict_group_h2_seed934 = insertelement <16 x i8> poison, i8 %dict_h2_byte922, i64 0
  %generic_dict_group_h2_vector935 = shufflevector <16 x i8> %generic_dict_group_h2_seed934, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector936 = icmp eq <16 x i8> %generic_dict_group_controls933, %generic_dict_group_h2_vector935
  %generic_dict_group_match_bits937 = bitcast <16 x i1> %generic_dict_group_matches_vector936 to i16
  %generic_dict_group_empty_vector938 = icmp eq <16 x i8> %generic_dict_group_controls933, zeroinitializer
  %generic_dict_group_empty_bits939 = bitcast <16 x i1> %generic_dict_group_empty_vector938 to i16
  %generic_dict_group_deleted_seed940 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector941 = shufflevector <16 x i8> %generic_dict_group_deleted_seed940, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches942 = icmp eq <16 x i8> %generic_dict_group_controls933, %generic_dict_group_deleted_vector941
  %generic_dict_group_deleted_bits943 = bitcast <16 x i1> %generic_dict_group_deleted_matches942 to i16
  %generic_dict_group_has_deleted944 = icmp ne i16 %generic_dict_group_deleted_bits943, 0
  %generic_dict_group_no_previous_deleted945 = icmp eq i64 %generic_dict_group_deleted928, %set_grown_capacity771
  %generic_dict_group_capture_deleted946 = and i1 %generic_dict_group_has_deleted944, %generic_dict_group_no_previous_deleted945
  %generic_dict_group_deleted_offset16947 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits943, i1 false)
  %generic_dict_group_deleted_offset948 = zext i16 %generic_dict_group_deleted_offset16947 to i64
  %generic_dict_group_deleted_unwrapped949 = add i64 %generic_dict_group_start931, %generic_dict_group_deleted_offset948
  %generic_dict_group_deleted_slot950 = and i64 %generic_dict_group_deleted_unwrapped949, %dict_capacity_mask923
  %generic_dict_group_captured_deleted951 = select i1 %generic_dict_group_capture_deleted946, i64 %generic_dict_group_deleted_slot950, i64 %generic_dict_group_deleted928
  br label %bb_generic_dict_candidate_loop216

bb_generic_dict_candidate_loop216:
  %generic_dict_candidate_bits952 = phi i16 [ %generic_dict_group_match_bits937, %bb_generic_dict_group_body215 ], [ %generic_dict_candidate_cleared_bits953, %bb_generic_dict_candidate_next218 ]
  %generic_dict_has_candidate954 = icmp ne i16 %generic_dict_candidate_bits952, 0
  br i1 %generic_dict_has_candidate954, label %bb_generic_dict_candidate_body217, label %bb_generic_dict_group_decision219

bb_generic_dict_candidate_body217:
  %generic_dict_candidate_offset16955 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits952, i1 false)
  %generic_dict_candidate_offset956 = zext i16 %generic_dict_candidate_offset16955 to i64
  %generic_dict_candidate_unwrapped957 = add i64 %generic_dict_group_start931, %generic_dict_candidate_offset956
  %generic_dict_candidate_slot958 = and i64 %generic_dict_candidate_unwrapped957, %dict_capacity_mask923
  %generic_dict_key_entries_offset_mirror959 = add i64 %set_grown_capacity771, 23
  %generic_dict_key_entries_offset960 = and i64 %generic_dict_key_entries_offset_mirror959, -8
  %generic_dict_key_entries961 = getelementptr i8, ptr %heap776, i64 %generic_dict_key_entries_offset960
  %generic_dict_key_entry_offset962 = mul i64 %generic_dict_candidate_slot958, 4
  %generic_dict_key_slot963 = getelementptr i8, ptr %generic_dict_key_entries961, i64 %generic_dict_key_entry_offset962
  %generic_dict_key964 = load i32, ptr %generic_dict_key_slot963, align 4
  %generic_dict_key_equal965 = icmp eq i32 %generic_dict_key964, 10
  br i1 %generic_dict_key_equal965, label %bb_generic_dict_group_match221, label %bb_generic_dict_candidate_next218

bb_generic_dict_candidate_next218:
  %generic_dict_candidate_bits_minus_one966 = sub i16 %generic_dict_candidate_bits952, 1
  %generic_dict_candidate_cleared_bits953 = and i16 %generic_dict_candidate_bits952, %generic_dict_candidate_bits_minus_one966
  br label %bb_generic_dict_candidate_loop216

bb_generic_dict_group_decision219:
  %generic_dict_group_has_empty967 = icmp ne i16 %generic_dict_group_empty_bits939, 0
  br i1 %generic_dict_group_has_empty967, label %bb_generic_dict_group_empty220, label %bb_generic_dict_group_next222

bb_generic_dict_group_empty220:
  %generic_dict_group_empty_offset16968 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits939, i1 false)
  %generic_dict_group_empty_offset969 = zext i16 %generic_dict_group_empty_offset16968 to i64
  %generic_dict_group_empty_unwrapped970 = add i64 %generic_dict_group_start931, %generic_dict_group_empty_offset969
  %generic_dict_group_empty_slot971 = and i64 %generic_dict_group_empty_unwrapped970, %dict_capacity_mask923
  %generic_dict_group_use_empty972 = icmp eq i64 %generic_dict_group_captured_deleted951, %set_grown_capacity771
  %generic_dict_group_insertion_slot973 = select i1 %generic_dict_group_use_empty972, i64 %generic_dict_group_empty_slot971, i64 %generic_dict_group_captured_deleted951
  br label %bb_generic_dict_group_done224

bb_generic_dict_group_match221:
  br label %bb_generic_dict_group_done224

bb_generic_dict_group_next222:
  %generic_dict_group_next_probe925 = add i64 %generic_dict_group_probe927, 16
  %generic_dict_group_next_deleted926 = add i64 %generic_dict_group_captured_deleted951, 0
  br label %bb_generic_dict_group_find214

bb_generic_dict_group_miss223:
  %generic_dict_group_miss_no_deleted974 = icmp eq i64 %generic_dict_group_deleted928, %set_grown_capacity771
  %generic_dict_group_miss_slot975 = select i1 %generic_dict_group_miss_no_deleted974, i64 0, i64 %generic_dict_group_deleted928
  br label %bb_generic_dict_group_done224

bb_generic_dict_group_done224:
  %generic_dict_find_found976 = phi i1 [ false, %bb_generic_dict_group_empty220 ], [ true, %bb_generic_dict_group_match221 ], [ false, %bb_generic_dict_group_miss223 ]
  %generic_dict_find_slot_result977 = phi i64 [ %generic_dict_group_insertion_slot973, %bb_generic_dict_group_empty220 ], [ %generic_dict_candidate_slot958, %bb_generic_dict_group_match221 ], [ %generic_dict_group_miss_slot975, %bb_generic_dict_group_miss223 ]
  br label %bb_generic_dict_insert_first_done211

bb_generic_dict_insert_first_done211:
  %generic_dict_insert_first_found978 = phi i1 [ true, %bb_generic_dict_insert_first_match208 ], [ false, %bb_generic_dict_insert_first_vacant210 ], [ %generic_dict_find_found976, %bb_generic_dict_group_done224 ], [ false, %bb_generic_dict_insert_no_capacity213 ]
  %generic_dict_insert_first_slot_result979 = phi i64 [ %dict_start_slot901, %bb_generic_dict_insert_first_match208 ], [ %dict_start_slot901, %bb_generic_dict_insert_first_vacant210 ], [ %generic_dict_find_slot_result977, %bb_generic_dict_group_done224 ], [ 0, %bb_generic_dict_insert_no_capacity213 ]
  %set_key_entries_offset_mirror980 = add i64 %set_grown_capacity771, 23
  %set_key_entries_offset981 = and i64 %set_key_entries_offset_mirror980, -8
  %set_key_entries982 = getelementptr i8, ptr %heap776, i64 %set_key_entries_offset981
  %set_key_entry_offset983 = mul i64 %generic_dict_insert_first_slot_result979, 4
  %set_key_slot984 = getelementptr i8, ptr %set_key_entries982, i64 %set_key_entry_offset983
  store i32 10, ptr %set_key_slot984, align 4
  %generic_dict_control_slot985 = getelementptr i8, ptr %heap776, i64 %generic_dict_insert_first_slot_result979
  store i8 %dict_h2_byte899, ptr %generic_dict_control_slot985, align 1
  %generic_dict_control_mirrored986 = icmp ult i64 %generic_dict_insert_first_slot_result979, 16
  br i1 %generic_dict_control_mirrored986, label %bb_generic_dict_control_mirror225, label %bb_generic_dict_control_done226

bb_generic_dict_control_mirror225:
  %generic_dict_control_mirror_index987 = add i64 %set_grown_capacity771, %generic_dict_insert_first_slot_result979
  %generic_dict_control_mirror_slot988 = getelementptr i8, ptr %heap776, i64 %generic_dict_control_mirror_index987
  store i8 %dict_h2_byte899, ptr %generic_dict_control_mirror_slot988, align 1
  br label %bb_generic_dict_control_done226

bb_generic_dict_control_done226:
  br label %bb_set_insert_done175

bb_set_insert_done175:
  %set_pointer989 = phi ptr [ %mutable_ptr666, %bb_set_insert_duplicate171 ], [ %mutable_ptr666, %bb_generic_dict_control_done177 ], [ %heap776, %bb_generic_dict_control_done226 ]
  %set_length990 = phi i64 [ %mutable_len667, %bb_set_insert_duplicate171 ], [ %set_insert_length758, %bb_generic_dict_control_done177 ], [ %set_insert_length758, %bb_generic_dict_control_done226 ]
  %set_capacity991 = phi i64 [ %mutable_capacity668, %bb_set_insert_duplicate171 ], [ %mutable_capacity668, %bb_generic_dict_control_done177 ], [ %set_grown_capacity771, %bb_generic_dict_control_done226 ]
  %set_inserted992 = phi i1 [ false, %bb_set_insert_duplicate171 ], [ true, %bb_generic_dict_control_done177 ], [ true, %bb_generic_dict_control_done226 ]
  store ptr %set_pointer989, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length990, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity991, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr993 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len994 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity995 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key996 = sext i32 30 to i64
  %hash_high998 = lshr i64 %hash_key996, 32
  %hash_fold997 = xor i64 %hash_key996, %hash_high998
  %hash999 = mul i64 %hash_fold997, -7046029254386353131
  %dict_h2_shifted1000 = lshr i64 %hash999, 57
  %dict_h2_raw1001 = and i64 %dict_h2_shifted1000, 127
  %dict_h2_zero1002 = icmp eq i64 %dict_h2_raw1001, 0
  %dict_h21003 = select i1 %dict_h2_zero1002, i64 1, i64 %dict_h2_raw1001
  %dict_h2_byte1004 = trunc i64 %dict_h21003 to i8
  %dict_capacity_mask1005 = sub i64 %mutable_capacity995, 1
  %dict_start_slot1006 = and i64 %hash999, %dict_capacity_mask1005
  %generic_dict_insert_has_capacity1007 = icmp ugt i64 %mutable_capacity995, 0
  br i1 %generic_dict_insert_has_capacity1007, label %bb_generic_dict_insert_first233, label %bb_generic_dict_insert_no_capacity234

bb_generic_dict_insert_no_capacity234:
  br label %bb_generic_dict_insert_first_done232

bb_generic_dict_insert_first233:
  %generic_dict_control_slot1008 = getelementptr i8, ptr %mutable_ptr993, i64 %dict_start_slot1006
  %generic_dict_control1009 = load i8, ptr %generic_dict_control_slot1008, align 1
  %generic_dict_insert_first_empty1010 = icmp eq i8 %generic_dict_control1009, 0
  br i1 %generic_dict_insert_first_empty1010, label %bb_generic_dict_insert_first_vacant231, label %bb_generic_dict_insert_first_occupied227

bb_generic_dict_insert_first_occupied227:
  %generic_dict_insert_first_h21011 = icmp eq i8 %generic_dict_control1009, %dict_h2_byte1004
  br i1 %generic_dict_insert_first_h21011, label %bb_generic_dict_insert_first_compare228, label %bb_generic_dict_insert_first_fallback230

bb_generic_dict_insert_first_compare228:
  %generic_dict_insert_first_key_entries_offset_mirror1012 = add i64 %mutable_capacity995, 23
  %generic_dict_insert_first_key_entries_offset1013 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1012, -8
  %generic_dict_insert_first_key_entries1014 = getelementptr i8, ptr %mutable_ptr993, i64 %generic_dict_insert_first_key_entries_offset1013
  %generic_dict_insert_first_key_entry_offset1015 = mul i64 %dict_start_slot1006, 4
  %generic_dict_insert_first_key_slot1016 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1014, i64 %generic_dict_insert_first_key_entry_offset1015
  %generic_dict_insert_first_key1017 = load i32, ptr %generic_dict_insert_first_key_slot1016, align 4
  %generic_dict_key_equal1018 = icmp eq i32 %generic_dict_insert_first_key1017, 30
  br i1 %generic_dict_key_equal1018, label %bb_generic_dict_insert_first_match229, label %bb_generic_dict_insert_first_fallback230

bb_generic_dict_insert_first_match229:
  br label %bb_generic_dict_insert_first_done232

bb_generic_dict_insert_first_vacant231:
  br label %bb_generic_dict_insert_first_done232

bb_generic_dict_insert_first_fallback230:
  %hash_key1019 = sext i32 30 to i64
  %hash_high1021 = lshr i64 %hash_key1019, 32
  %hash_fold1020 = xor i64 %hash_key1019, %hash_high1021
  %hash1022 = mul i64 %hash_fold1020, -7046029254386353131
  %dict_h2_shifted1023 = lshr i64 %hash1022, 57
  %dict_h2_raw1024 = and i64 %dict_h2_shifted1023, 127
  %dict_h2_zero1025 = icmp eq i64 %dict_h2_raw1024, 0
  %dict_h21026 = select i1 %dict_h2_zero1025, i64 1, i64 %dict_h2_raw1024
  %dict_h2_byte1027 = trunc i64 %dict_h21026 to i8
  %dict_capacity_mask1028 = sub i64 %mutable_capacity995, 1
  %dict_start_slot1029 = and i64 %hash1022, %dict_capacity_mask1028
  br label %bb_generic_dict_group_find235

bb_generic_dict_group_find235:
  %generic_dict_group_probe1032 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback230 ], [ %generic_dict_group_next_probe1030, %bb_generic_dict_group_next243 ]
  %generic_dict_group_deleted1033 = phi i64 [ %mutable_capacity995, %bb_generic_dict_insert_first_fallback230 ], [ %generic_dict_group_next_deleted1031, %bb_generic_dict_group_next243 ]
  %generic_dict_group_active1034 = icmp ult i64 %generic_dict_group_probe1032, %mutable_capacity995
  br i1 %generic_dict_group_active1034, label %bb_generic_dict_group_body236, label %bb_generic_dict_group_miss244

bb_generic_dict_group_body236:
  %generic_dict_group_unwrapped1035 = add i64 %dict_start_slot1029, %generic_dict_group_probe1032
  %generic_dict_group_start1036 = and i64 %generic_dict_group_unwrapped1035, %dict_capacity_mask1028
  %generic_dict_group_pointer1037 = getelementptr i8, ptr %mutable_ptr993, i64 %generic_dict_group_start1036
  %generic_dict_group_controls1038 = load <16 x i8>, ptr %generic_dict_group_pointer1037, align 1
  %generic_dict_group_h2_seed1039 = insertelement <16 x i8> poison, i8 %dict_h2_byte1027, i64 0
  %generic_dict_group_h2_vector1040 = shufflevector <16 x i8> %generic_dict_group_h2_seed1039, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1041 = icmp eq <16 x i8> %generic_dict_group_controls1038, %generic_dict_group_h2_vector1040
  %generic_dict_group_match_bits1042 = bitcast <16 x i1> %generic_dict_group_matches_vector1041 to i16
  %generic_dict_group_empty_vector1043 = icmp eq <16 x i8> %generic_dict_group_controls1038, zeroinitializer
  %generic_dict_group_empty_bits1044 = bitcast <16 x i1> %generic_dict_group_empty_vector1043 to i16
  %generic_dict_group_deleted_seed1045 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1046 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1045, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1047 = icmp eq <16 x i8> %generic_dict_group_controls1038, %generic_dict_group_deleted_vector1046
  %generic_dict_group_deleted_bits1048 = bitcast <16 x i1> %generic_dict_group_deleted_matches1047 to i16
  %generic_dict_group_has_deleted1049 = icmp ne i16 %generic_dict_group_deleted_bits1048, 0
  %generic_dict_group_no_previous_deleted1050 = icmp eq i64 %generic_dict_group_deleted1033, %mutable_capacity995
  %generic_dict_group_capture_deleted1051 = and i1 %generic_dict_group_has_deleted1049, %generic_dict_group_no_previous_deleted1050
  %generic_dict_group_deleted_offset161052 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1048, i1 false)
  %generic_dict_group_deleted_offset1053 = zext i16 %generic_dict_group_deleted_offset161052 to i64
  %generic_dict_group_deleted_unwrapped1054 = add i64 %generic_dict_group_start1036, %generic_dict_group_deleted_offset1053
  %generic_dict_group_deleted_slot1055 = and i64 %generic_dict_group_deleted_unwrapped1054, %dict_capacity_mask1028
  %generic_dict_group_captured_deleted1056 = select i1 %generic_dict_group_capture_deleted1051, i64 %generic_dict_group_deleted_slot1055, i64 %generic_dict_group_deleted1033
  br label %bb_generic_dict_candidate_loop237

bb_generic_dict_candidate_loop237:
  %generic_dict_candidate_bits1057 = phi i16 [ %generic_dict_group_match_bits1042, %bb_generic_dict_group_body236 ], [ %generic_dict_candidate_cleared_bits1058, %bb_generic_dict_candidate_next239 ]
  %generic_dict_has_candidate1059 = icmp ne i16 %generic_dict_candidate_bits1057, 0
  br i1 %generic_dict_has_candidate1059, label %bb_generic_dict_candidate_body238, label %bb_generic_dict_group_decision240

bb_generic_dict_candidate_body238:
  %generic_dict_candidate_offset161060 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1057, i1 false)
  %generic_dict_candidate_offset1061 = zext i16 %generic_dict_candidate_offset161060 to i64
  %generic_dict_candidate_unwrapped1062 = add i64 %generic_dict_group_start1036, %generic_dict_candidate_offset1061
  %generic_dict_candidate_slot1063 = and i64 %generic_dict_candidate_unwrapped1062, %dict_capacity_mask1028
  %generic_dict_key_entries_offset_mirror1064 = add i64 %mutable_capacity995, 23
  %generic_dict_key_entries_offset1065 = and i64 %generic_dict_key_entries_offset_mirror1064, -8
  %generic_dict_key_entries1066 = getelementptr i8, ptr %mutable_ptr993, i64 %generic_dict_key_entries_offset1065
  %generic_dict_key_entry_offset1067 = mul i64 %generic_dict_candidate_slot1063, 4
  %generic_dict_key_slot1068 = getelementptr i8, ptr %generic_dict_key_entries1066, i64 %generic_dict_key_entry_offset1067
  %generic_dict_key1069 = load i32, ptr %generic_dict_key_slot1068, align 4
  %generic_dict_key_equal1070 = icmp eq i32 %generic_dict_key1069, 30
  br i1 %generic_dict_key_equal1070, label %bb_generic_dict_group_match242, label %bb_generic_dict_candidate_next239

bb_generic_dict_candidate_next239:
  %generic_dict_candidate_bits_minus_one1071 = sub i16 %generic_dict_candidate_bits1057, 1
  %generic_dict_candidate_cleared_bits1058 = and i16 %generic_dict_candidate_bits1057, %generic_dict_candidate_bits_minus_one1071
  br label %bb_generic_dict_candidate_loop237

bb_generic_dict_group_decision240:
  %generic_dict_group_has_empty1072 = icmp ne i16 %generic_dict_group_empty_bits1044, 0
  br i1 %generic_dict_group_has_empty1072, label %bb_generic_dict_group_empty241, label %bb_generic_dict_group_next243

bb_generic_dict_group_empty241:
  %generic_dict_group_empty_offset161073 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1044, i1 false)
  %generic_dict_group_empty_offset1074 = zext i16 %generic_dict_group_empty_offset161073 to i64
  %generic_dict_group_empty_unwrapped1075 = add i64 %generic_dict_group_start1036, %generic_dict_group_empty_offset1074
  %generic_dict_group_empty_slot1076 = and i64 %generic_dict_group_empty_unwrapped1075, %dict_capacity_mask1028
  %generic_dict_group_use_empty1077 = icmp eq i64 %generic_dict_group_captured_deleted1056, %mutable_capacity995
  %generic_dict_group_insertion_slot1078 = select i1 %generic_dict_group_use_empty1077, i64 %generic_dict_group_empty_slot1076, i64 %generic_dict_group_captured_deleted1056
  br label %bb_generic_dict_group_done245

bb_generic_dict_group_match242:
  br label %bb_generic_dict_group_done245

bb_generic_dict_group_next243:
  %generic_dict_group_next_probe1030 = add i64 %generic_dict_group_probe1032, 16
  %generic_dict_group_next_deleted1031 = add i64 %generic_dict_group_captured_deleted1056, 0
  br label %bb_generic_dict_group_find235

bb_generic_dict_group_miss244:
  %generic_dict_group_miss_no_deleted1079 = icmp eq i64 %generic_dict_group_deleted1033, %mutable_capacity995
  %generic_dict_group_miss_slot1080 = select i1 %generic_dict_group_miss_no_deleted1079, i64 0, i64 %generic_dict_group_deleted1033
  br label %bb_generic_dict_group_done245

bb_generic_dict_group_done245:
  %generic_dict_find_found1081 = phi i1 [ false, %bb_generic_dict_group_empty241 ], [ true, %bb_generic_dict_group_match242 ], [ false, %bb_generic_dict_group_miss244 ]
  %generic_dict_find_slot_result1082 = phi i64 [ %generic_dict_group_insertion_slot1078, %bb_generic_dict_group_empty241 ], [ %generic_dict_candidate_slot1063, %bb_generic_dict_group_match242 ], [ %generic_dict_group_miss_slot1080, %bb_generic_dict_group_miss244 ]
  br label %bb_generic_dict_insert_first_done232

bb_generic_dict_insert_first_done232:
  %generic_dict_insert_first_found1083 = phi i1 [ true, %bb_generic_dict_insert_first_match229 ], [ false, %bb_generic_dict_insert_first_vacant231 ], [ %generic_dict_find_found1081, %bb_generic_dict_group_done245 ], [ false, %bb_generic_dict_insert_no_capacity234 ]
  %generic_dict_insert_first_slot_result1084 = phi i64 [ %dict_start_slot1006, %bb_generic_dict_insert_first_match229 ], [ %dict_start_slot1006, %bb_generic_dict_insert_first_vacant231 ], [ %generic_dict_find_slot_result1082, %bb_generic_dict_group_done245 ], [ 0, %bb_generic_dict_insert_no_capacity234 ]
  br i1 %generic_dict_insert_first_found1083, label %bb_set_insert_duplicate246, label %bb_set_insert_new247

bb_set_insert_duplicate246:
  br label %bb_set_insert_done250

bb_set_insert_new247:
  %set_insert_length1085 = add i64 %mutable_len994, 1
  %set_insert_load_num1086 = mul i64 %set_insert_length1085, 8
  %set_insert_load_den1087 = mul i64 %mutable_capacity995, 7
  %set_insert_should_grow1088 = icmp ugt i64 %set_insert_load_num1086, %set_insert_load_den1087
  br i1 %set_insert_should_grow1088, label %bb_set_insert_grow249, label %bb_set_insert_current248

bb_set_insert_current248:
  %set_key_entries_offset_mirror1089 = add i64 %mutable_capacity995, 23
  %set_key_entries_offset1090 = and i64 %set_key_entries_offset_mirror1089, -8
  %set_key_entries1091 = getelementptr i8, ptr %mutable_ptr993, i64 %set_key_entries_offset1090
  %set_key_entry_offset1092 = mul i64 %generic_dict_insert_first_slot_result1084, 4
  %set_key_slot1093 = getelementptr i8, ptr %set_key_entries1091, i64 %set_key_entry_offset1092
  store i32 30, ptr %set_key_slot1093, align 4
  %generic_dict_control_slot1094 = getelementptr i8, ptr %mutable_ptr993, i64 %generic_dict_insert_first_slot_result1084
  store i8 %dict_h2_byte1004, ptr %generic_dict_control_slot1094, align 1
  %generic_dict_control_mirrored1095 = icmp ult i64 %generic_dict_insert_first_slot_result1084, 16
  br i1 %generic_dict_control_mirrored1095, label %bb_generic_dict_control_mirror251, label %bb_generic_dict_control_done252

bb_generic_dict_control_mirror251:
  %generic_dict_control_mirror_index1096 = add i64 %mutable_capacity995, %generic_dict_insert_first_slot_result1084
  %generic_dict_control_mirror_slot1097 = getelementptr i8, ptr %mutable_ptr993, i64 %generic_dict_control_mirror_index1096
  store i8 %dict_h2_byte1004, ptr %generic_dict_control_mirror_slot1097, align 1
  br label %bb_generic_dict_control_done252

bb_generic_dict_control_done252:
  br label %bb_set_insert_done250

bb_set_insert_grow249:
  %set_grown_capacity1098 = mul i64 %mutable_capacity995, 2
  %generic_dict_entries_offset_mirror1099 = add i64 %set_grown_capacity1098, 23
  %generic_dict_entries_offset1100 = and i64 %generic_dict_entries_offset_mirror1099, -8
  %generic_dict_entries_bytes1101 = mul i64 %set_grown_capacity1098, 4
  %generic_dict_bytes1102 = add i64 %generic_dict_entries_offset1100, %generic_dict_entries_bytes1101
  %heap1103 = call ptr @sollang_alloc(i64 %generic_dict_bytes1102)
  %heap_ok1104 = icmp ne ptr %heap1103, null
  br i1 %heap_ok1104, label %bb_alloc_ok253, label %bb_alloc_fail254

bb_alloc_fail254:
  %trap_stderr1105 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr1105, ptr @.slg.str.module.x.4, i32 25, ptr %trap_written1106, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok253:
  %generic_dict_control_bytes1107 = add i64 %set_grown_capacity1098, 16
  call void @llvm.memset.p0.i64(ptr %heap1103, i8 0, i64 %generic_dict_control_bytes1107, i1 false)
  br label %bb_set_rehash255

bb_set_rehash255:
  %set_rehash_index1109 = phi i64 [ 0, %bb_alloc_ok253 ], [ %set_rehash_next_index1108, %bb_set_rehash_next258 ]
  %set_rehash_active1110 = icmp ult i64 %set_rehash_index1109, %mutable_capacity995
  br i1 %set_rehash_active1110, label %bb_set_rehash_body256, label %bb_set_rehash_done259

bb_set_rehash_body256:
  %generic_dict_control_slot1111 = getelementptr i8, ptr %mutable_ptr993, i64 %set_rehash_index1109
  %generic_dict_control1112 = load i8, ptr %generic_dict_control_slot1111, align 1
  %set_rehash_occupied1113 = icmp sgt i8 %generic_dict_control1112, 0
  br i1 %set_rehash_occupied1113, label %bb_set_rehash_move257, label %bb_set_rehash_next258

bb_set_rehash_move257:
  %set_rehash_key_entries_offset_mirror1114 = add i64 %mutable_capacity995, 23
  %set_rehash_key_entries_offset1115 = and i64 %set_rehash_key_entries_offset_mirror1114, -8
  %set_rehash_key_entries1116 = getelementptr i8, ptr %mutable_ptr993, i64 %set_rehash_key_entries_offset1115
  %set_rehash_key_entry_offset1117 = mul i64 %set_rehash_index1109, 4
  %set_rehash_key_slot1118 = getelementptr i8, ptr %set_rehash_key_entries1116, i64 %set_rehash_key_entry_offset1117
  %set_rehash_key1119 = load i32, ptr %set_rehash_key_slot1118, align 4
  %hash_key1120 = sext i32 %set_rehash_key1119 to i64
  %hash_high1122 = lshr i64 %hash_key1120, 32
  %hash_fold1121 = xor i64 %hash_key1120, %hash_high1122
  %hash1123 = mul i64 %hash_fold1121, -7046029254386353131
  %dict_h2_shifted1124 = lshr i64 %hash1123, 57
  %dict_h2_raw1125 = and i64 %dict_h2_shifted1124, 127
  %dict_h2_zero1126 = icmp eq i64 %dict_h2_raw1125, 0
  %dict_h21127 = select i1 %dict_h2_zero1126, i64 1, i64 %dict_h2_raw1125
  %dict_h2_byte1128 = trunc i64 %dict_h21127 to i8
  %dict_capacity_mask1129 = sub i64 %set_grown_capacity1098, 1
  %dict_start_slot1130 = and i64 %hash1123, %dict_capacity_mask1129
  %generic_dict_insert_has_capacity1131 = icmp ugt i64 %set_grown_capacity1098, 0
  br i1 %generic_dict_insert_has_capacity1131, label %bb_generic_dict_insert_first266, label %bb_generic_dict_insert_no_capacity267

bb_generic_dict_insert_no_capacity267:
  br label %bb_generic_dict_insert_first_done265

bb_generic_dict_insert_first266:
  %generic_dict_control_slot1132 = getelementptr i8, ptr %heap1103, i64 %dict_start_slot1130
  %generic_dict_control1133 = load i8, ptr %generic_dict_control_slot1132, align 1
  %generic_dict_insert_first_empty1134 = icmp eq i8 %generic_dict_control1133, 0
  br i1 %generic_dict_insert_first_empty1134, label %bb_generic_dict_insert_first_vacant264, label %bb_generic_dict_insert_first_occupied260

bb_generic_dict_insert_first_occupied260:
  %generic_dict_insert_first_h21135 = icmp eq i8 %generic_dict_control1133, %dict_h2_byte1128
  br i1 %generic_dict_insert_first_h21135, label %bb_generic_dict_insert_first_compare261, label %bb_generic_dict_insert_first_fallback263

bb_generic_dict_insert_first_compare261:
  %generic_dict_insert_first_key_entries_offset_mirror1136 = add i64 %set_grown_capacity1098, 23
  %generic_dict_insert_first_key_entries_offset1137 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1136, -8
  %generic_dict_insert_first_key_entries1138 = getelementptr i8, ptr %heap1103, i64 %generic_dict_insert_first_key_entries_offset1137
  %generic_dict_insert_first_key_entry_offset1139 = mul i64 %dict_start_slot1130, 4
  %generic_dict_insert_first_key_slot1140 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1138, i64 %generic_dict_insert_first_key_entry_offset1139
  %generic_dict_insert_first_key1141 = load i32, ptr %generic_dict_insert_first_key_slot1140, align 4
  %generic_dict_key_equal1142 = icmp eq i32 %generic_dict_insert_first_key1141, %set_rehash_key1119
  br i1 %generic_dict_key_equal1142, label %bb_generic_dict_insert_first_match262, label %bb_generic_dict_insert_first_fallback263

bb_generic_dict_insert_first_match262:
  br label %bb_generic_dict_insert_first_done265

bb_generic_dict_insert_first_vacant264:
  br label %bb_generic_dict_insert_first_done265

bb_generic_dict_insert_first_fallback263:
  %hash_key1143 = sext i32 %set_rehash_key1119 to i64
  %hash_high1145 = lshr i64 %hash_key1143, 32
  %hash_fold1144 = xor i64 %hash_key1143, %hash_high1145
  %hash1146 = mul i64 %hash_fold1144, -7046029254386353131
  %dict_h2_shifted1147 = lshr i64 %hash1146, 57
  %dict_h2_raw1148 = and i64 %dict_h2_shifted1147, 127
  %dict_h2_zero1149 = icmp eq i64 %dict_h2_raw1148, 0
  %dict_h21150 = select i1 %dict_h2_zero1149, i64 1, i64 %dict_h2_raw1148
  %dict_h2_byte1151 = trunc i64 %dict_h21150 to i8
  %dict_capacity_mask1152 = sub i64 %set_grown_capacity1098, 1
  %dict_start_slot1153 = and i64 %hash1146, %dict_capacity_mask1152
  br label %bb_generic_dict_group_find268

bb_generic_dict_group_find268:
  %generic_dict_group_probe1156 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback263 ], [ %generic_dict_group_next_probe1154, %bb_generic_dict_group_next276 ]
  %generic_dict_group_deleted1157 = phi i64 [ %set_grown_capacity1098, %bb_generic_dict_insert_first_fallback263 ], [ %generic_dict_group_next_deleted1155, %bb_generic_dict_group_next276 ]
  %generic_dict_group_active1158 = icmp ult i64 %generic_dict_group_probe1156, %set_grown_capacity1098
  br i1 %generic_dict_group_active1158, label %bb_generic_dict_group_body269, label %bb_generic_dict_group_miss277

bb_generic_dict_group_body269:
  %generic_dict_group_unwrapped1159 = add i64 %dict_start_slot1153, %generic_dict_group_probe1156
  %generic_dict_group_start1160 = and i64 %generic_dict_group_unwrapped1159, %dict_capacity_mask1152
  %generic_dict_group_pointer1161 = getelementptr i8, ptr %heap1103, i64 %generic_dict_group_start1160
  %generic_dict_group_controls1162 = load <16 x i8>, ptr %generic_dict_group_pointer1161, align 1
  %generic_dict_group_h2_seed1163 = insertelement <16 x i8> poison, i8 %dict_h2_byte1151, i64 0
  %generic_dict_group_h2_vector1164 = shufflevector <16 x i8> %generic_dict_group_h2_seed1163, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1165 = icmp eq <16 x i8> %generic_dict_group_controls1162, %generic_dict_group_h2_vector1164
  %generic_dict_group_match_bits1166 = bitcast <16 x i1> %generic_dict_group_matches_vector1165 to i16
  %generic_dict_group_empty_vector1167 = icmp eq <16 x i8> %generic_dict_group_controls1162, zeroinitializer
  %generic_dict_group_empty_bits1168 = bitcast <16 x i1> %generic_dict_group_empty_vector1167 to i16
  %generic_dict_group_deleted_seed1169 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1170 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1169, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1171 = icmp eq <16 x i8> %generic_dict_group_controls1162, %generic_dict_group_deleted_vector1170
  %generic_dict_group_deleted_bits1172 = bitcast <16 x i1> %generic_dict_group_deleted_matches1171 to i16
  %generic_dict_group_has_deleted1173 = icmp ne i16 %generic_dict_group_deleted_bits1172, 0
  %generic_dict_group_no_previous_deleted1174 = icmp eq i64 %generic_dict_group_deleted1157, %set_grown_capacity1098
  %generic_dict_group_capture_deleted1175 = and i1 %generic_dict_group_has_deleted1173, %generic_dict_group_no_previous_deleted1174
  %generic_dict_group_deleted_offset161176 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1172, i1 false)
  %generic_dict_group_deleted_offset1177 = zext i16 %generic_dict_group_deleted_offset161176 to i64
  %generic_dict_group_deleted_unwrapped1178 = add i64 %generic_dict_group_start1160, %generic_dict_group_deleted_offset1177
  %generic_dict_group_deleted_slot1179 = and i64 %generic_dict_group_deleted_unwrapped1178, %dict_capacity_mask1152
  %generic_dict_group_captured_deleted1180 = select i1 %generic_dict_group_capture_deleted1175, i64 %generic_dict_group_deleted_slot1179, i64 %generic_dict_group_deleted1157
  br label %bb_generic_dict_candidate_loop270

bb_generic_dict_candidate_loop270:
  %generic_dict_candidate_bits1181 = phi i16 [ %generic_dict_group_match_bits1166, %bb_generic_dict_group_body269 ], [ %generic_dict_candidate_cleared_bits1182, %bb_generic_dict_candidate_next272 ]
  %generic_dict_has_candidate1183 = icmp ne i16 %generic_dict_candidate_bits1181, 0
  br i1 %generic_dict_has_candidate1183, label %bb_generic_dict_candidate_body271, label %bb_generic_dict_group_decision273

bb_generic_dict_candidate_body271:
  %generic_dict_candidate_offset161184 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1181, i1 false)
  %generic_dict_candidate_offset1185 = zext i16 %generic_dict_candidate_offset161184 to i64
  %generic_dict_candidate_unwrapped1186 = add i64 %generic_dict_group_start1160, %generic_dict_candidate_offset1185
  %generic_dict_candidate_slot1187 = and i64 %generic_dict_candidate_unwrapped1186, %dict_capacity_mask1152
  %generic_dict_key_entries_offset_mirror1188 = add i64 %set_grown_capacity1098, 23
  %generic_dict_key_entries_offset1189 = and i64 %generic_dict_key_entries_offset_mirror1188, -8
  %generic_dict_key_entries1190 = getelementptr i8, ptr %heap1103, i64 %generic_dict_key_entries_offset1189
  %generic_dict_key_entry_offset1191 = mul i64 %generic_dict_candidate_slot1187, 4
  %generic_dict_key_slot1192 = getelementptr i8, ptr %generic_dict_key_entries1190, i64 %generic_dict_key_entry_offset1191
  %generic_dict_key1193 = load i32, ptr %generic_dict_key_slot1192, align 4
  %generic_dict_key_equal1194 = icmp eq i32 %generic_dict_key1193, %set_rehash_key1119
  br i1 %generic_dict_key_equal1194, label %bb_generic_dict_group_match275, label %bb_generic_dict_candidate_next272

bb_generic_dict_candidate_next272:
  %generic_dict_candidate_bits_minus_one1195 = sub i16 %generic_dict_candidate_bits1181, 1
  %generic_dict_candidate_cleared_bits1182 = and i16 %generic_dict_candidate_bits1181, %generic_dict_candidate_bits_minus_one1195
  br label %bb_generic_dict_candidate_loop270

bb_generic_dict_group_decision273:
  %generic_dict_group_has_empty1196 = icmp ne i16 %generic_dict_group_empty_bits1168, 0
  br i1 %generic_dict_group_has_empty1196, label %bb_generic_dict_group_empty274, label %bb_generic_dict_group_next276

bb_generic_dict_group_empty274:
  %generic_dict_group_empty_offset161197 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1168, i1 false)
  %generic_dict_group_empty_offset1198 = zext i16 %generic_dict_group_empty_offset161197 to i64
  %generic_dict_group_empty_unwrapped1199 = add i64 %generic_dict_group_start1160, %generic_dict_group_empty_offset1198
  %generic_dict_group_empty_slot1200 = and i64 %generic_dict_group_empty_unwrapped1199, %dict_capacity_mask1152
  %generic_dict_group_use_empty1201 = icmp eq i64 %generic_dict_group_captured_deleted1180, %set_grown_capacity1098
  %generic_dict_group_insertion_slot1202 = select i1 %generic_dict_group_use_empty1201, i64 %generic_dict_group_empty_slot1200, i64 %generic_dict_group_captured_deleted1180
  br label %bb_generic_dict_group_done278

bb_generic_dict_group_match275:
  br label %bb_generic_dict_group_done278

bb_generic_dict_group_next276:
  %generic_dict_group_next_probe1154 = add i64 %generic_dict_group_probe1156, 16
  %generic_dict_group_next_deleted1155 = add i64 %generic_dict_group_captured_deleted1180, 0
  br label %bb_generic_dict_group_find268

bb_generic_dict_group_miss277:
  %generic_dict_group_miss_no_deleted1203 = icmp eq i64 %generic_dict_group_deleted1157, %set_grown_capacity1098
  %generic_dict_group_miss_slot1204 = select i1 %generic_dict_group_miss_no_deleted1203, i64 0, i64 %generic_dict_group_deleted1157
  br label %bb_generic_dict_group_done278

bb_generic_dict_group_done278:
  %generic_dict_find_found1205 = phi i1 [ false, %bb_generic_dict_group_empty274 ], [ true, %bb_generic_dict_group_match275 ], [ false, %bb_generic_dict_group_miss277 ]
  %generic_dict_find_slot_result1206 = phi i64 [ %generic_dict_group_insertion_slot1202, %bb_generic_dict_group_empty274 ], [ %generic_dict_candidate_slot1187, %bb_generic_dict_group_match275 ], [ %generic_dict_group_miss_slot1204, %bb_generic_dict_group_miss277 ]
  br label %bb_generic_dict_insert_first_done265

bb_generic_dict_insert_first_done265:
  %generic_dict_insert_first_found1207 = phi i1 [ true, %bb_generic_dict_insert_first_match262 ], [ false, %bb_generic_dict_insert_first_vacant264 ], [ %generic_dict_find_found1205, %bb_generic_dict_group_done278 ], [ false, %bb_generic_dict_insert_no_capacity267 ]
  %generic_dict_insert_first_slot_result1208 = phi i64 [ %dict_start_slot1130, %bb_generic_dict_insert_first_match262 ], [ %dict_start_slot1130, %bb_generic_dict_insert_first_vacant264 ], [ %generic_dict_find_slot_result1206, %bb_generic_dict_group_done278 ], [ 0, %bb_generic_dict_insert_no_capacity267 ]
  %set_key_entries_offset_mirror1209 = add i64 %set_grown_capacity1098, 23
  %set_key_entries_offset1210 = and i64 %set_key_entries_offset_mirror1209, -8
  %set_key_entries1211 = getelementptr i8, ptr %heap1103, i64 %set_key_entries_offset1210
  %set_key_entry_offset1212 = mul i64 %generic_dict_insert_first_slot_result1208, 4
  %set_key_slot1213 = getelementptr i8, ptr %set_key_entries1211, i64 %set_key_entry_offset1212
  store i32 %set_rehash_key1119, ptr %set_key_slot1213, align 4
  %generic_dict_control_slot1214 = getelementptr i8, ptr %heap1103, i64 %generic_dict_insert_first_slot_result1208
  store i8 %dict_h2_byte1128, ptr %generic_dict_control_slot1214, align 1
  %generic_dict_control_mirrored1215 = icmp ult i64 %generic_dict_insert_first_slot_result1208, 16
  br i1 %generic_dict_control_mirrored1215, label %bb_generic_dict_control_mirror279, label %bb_generic_dict_control_done280

bb_generic_dict_control_mirror279:
  %generic_dict_control_mirror_index1216 = add i64 %set_grown_capacity1098, %generic_dict_insert_first_slot_result1208
  %generic_dict_control_mirror_slot1217 = getelementptr i8, ptr %heap1103, i64 %generic_dict_control_mirror_index1216
  store i8 %dict_h2_byte1128, ptr %generic_dict_control_mirror_slot1217, align 1
  br label %bb_generic_dict_control_done280

bb_generic_dict_control_done280:
  br label %bb_set_rehash_next258

bb_set_rehash_next258:
  %set_rehash_next_index1108 = add i64 %set_rehash_index1109, 1
  br label %bb_set_rehash255

bb_set_rehash_done259:
  call void @sollang_free(ptr %mutable_ptr993)
  %hash_key1218 = sext i32 30 to i64
  %hash_high1220 = lshr i64 %hash_key1218, 32
  %hash_fold1219 = xor i64 %hash_key1218, %hash_high1220
  %hash1221 = mul i64 %hash_fold1219, -7046029254386353131
  %dict_h2_shifted1222 = lshr i64 %hash1221, 57
  %dict_h2_raw1223 = and i64 %dict_h2_shifted1222, 127
  %dict_h2_zero1224 = icmp eq i64 %dict_h2_raw1223, 0
  %dict_h21225 = select i1 %dict_h2_zero1224, i64 1, i64 %dict_h2_raw1223
  %dict_h2_byte1226 = trunc i64 %dict_h21225 to i8
  %dict_capacity_mask1227 = sub i64 %set_grown_capacity1098, 1
  %dict_start_slot1228 = and i64 %hash1221, %dict_capacity_mask1227
  %generic_dict_insert_has_capacity1229 = icmp ugt i64 %set_grown_capacity1098, 0
  br i1 %generic_dict_insert_has_capacity1229, label %bb_generic_dict_insert_first287, label %bb_generic_dict_insert_no_capacity288

bb_generic_dict_insert_no_capacity288:
  br label %bb_generic_dict_insert_first_done286

bb_generic_dict_insert_first287:
  %generic_dict_control_slot1230 = getelementptr i8, ptr %heap1103, i64 %dict_start_slot1228
  %generic_dict_control1231 = load i8, ptr %generic_dict_control_slot1230, align 1
  %generic_dict_insert_first_empty1232 = icmp eq i8 %generic_dict_control1231, 0
  br i1 %generic_dict_insert_first_empty1232, label %bb_generic_dict_insert_first_vacant285, label %bb_generic_dict_insert_first_occupied281

bb_generic_dict_insert_first_occupied281:
  %generic_dict_insert_first_h21233 = icmp eq i8 %generic_dict_control1231, %dict_h2_byte1226
  br i1 %generic_dict_insert_first_h21233, label %bb_generic_dict_insert_first_compare282, label %bb_generic_dict_insert_first_fallback284

bb_generic_dict_insert_first_compare282:
  %generic_dict_insert_first_key_entries_offset_mirror1234 = add i64 %set_grown_capacity1098, 23
  %generic_dict_insert_first_key_entries_offset1235 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1234, -8
  %generic_dict_insert_first_key_entries1236 = getelementptr i8, ptr %heap1103, i64 %generic_dict_insert_first_key_entries_offset1235
  %generic_dict_insert_first_key_entry_offset1237 = mul i64 %dict_start_slot1228, 4
  %generic_dict_insert_first_key_slot1238 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1236, i64 %generic_dict_insert_first_key_entry_offset1237
  %generic_dict_insert_first_key1239 = load i32, ptr %generic_dict_insert_first_key_slot1238, align 4
  %generic_dict_key_equal1240 = icmp eq i32 %generic_dict_insert_first_key1239, 30
  br i1 %generic_dict_key_equal1240, label %bb_generic_dict_insert_first_match283, label %bb_generic_dict_insert_first_fallback284

bb_generic_dict_insert_first_match283:
  br label %bb_generic_dict_insert_first_done286

bb_generic_dict_insert_first_vacant285:
  br label %bb_generic_dict_insert_first_done286

bb_generic_dict_insert_first_fallback284:
  %hash_key1241 = sext i32 30 to i64
  %hash_high1243 = lshr i64 %hash_key1241, 32
  %hash_fold1242 = xor i64 %hash_key1241, %hash_high1243
  %hash1244 = mul i64 %hash_fold1242, -7046029254386353131
  %dict_h2_shifted1245 = lshr i64 %hash1244, 57
  %dict_h2_raw1246 = and i64 %dict_h2_shifted1245, 127
  %dict_h2_zero1247 = icmp eq i64 %dict_h2_raw1246, 0
  %dict_h21248 = select i1 %dict_h2_zero1247, i64 1, i64 %dict_h2_raw1246
  %dict_h2_byte1249 = trunc i64 %dict_h21248 to i8
  %dict_capacity_mask1250 = sub i64 %set_grown_capacity1098, 1
  %dict_start_slot1251 = and i64 %hash1244, %dict_capacity_mask1250
  br label %bb_generic_dict_group_find289

bb_generic_dict_group_find289:
  %generic_dict_group_probe1254 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback284 ], [ %generic_dict_group_next_probe1252, %bb_generic_dict_group_next297 ]
  %generic_dict_group_deleted1255 = phi i64 [ %set_grown_capacity1098, %bb_generic_dict_insert_first_fallback284 ], [ %generic_dict_group_next_deleted1253, %bb_generic_dict_group_next297 ]
  %generic_dict_group_active1256 = icmp ult i64 %generic_dict_group_probe1254, %set_grown_capacity1098
  br i1 %generic_dict_group_active1256, label %bb_generic_dict_group_body290, label %bb_generic_dict_group_miss298

bb_generic_dict_group_body290:
  %generic_dict_group_unwrapped1257 = add i64 %dict_start_slot1251, %generic_dict_group_probe1254
  %generic_dict_group_start1258 = and i64 %generic_dict_group_unwrapped1257, %dict_capacity_mask1250
  %generic_dict_group_pointer1259 = getelementptr i8, ptr %heap1103, i64 %generic_dict_group_start1258
  %generic_dict_group_controls1260 = load <16 x i8>, ptr %generic_dict_group_pointer1259, align 1
  %generic_dict_group_h2_seed1261 = insertelement <16 x i8> poison, i8 %dict_h2_byte1249, i64 0
  %generic_dict_group_h2_vector1262 = shufflevector <16 x i8> %generic_dict_group_h2_seed1261, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1263 = icmp eq <16 x i8> %generic_dict_group_controls1260, %generic_dict_group_h2_vector1262
  %generic_dict_group_match_bits1264 = bitcast <16 x i1> %generic_dict_group_matches_vector1263 to i16
  %generic_dict_group_empty_vector1265 = icmp eq <16 x i8> %generic_dict_group_controls1260, zeroinitializer
  %generic_dict_group_empty_bits1266 = bitcast <16 x i1> %generic_dict_group_empty_vector1265 to i16
  %generic_dict_group_deleted_seed1267 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1268 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1267, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1269 = icmp eq <16 x i8> %generic_dict_group_controls1260, %generic_dict_group_deleted_vector1268
  %generic_dict_group_deleted_bits1270 = bitcast <16 x i1> %generic_dict_group_deleted_matches1269 to i16
  %generic_dict_group_has_deleted1271 = icmp ne i16 %generic_dict_group_deleted_bits1270, 0
  %generic_dict_group_no_previous_deleted1272 = icmp eq i64 %generic_dict_group_deleted1255, %set_grown_capacity1098
  %generic_dict_group_capture_deleted1273 = and i1 %generic_dict_group_has_deleted1271, %generic_dict_group_no_previous_deleted1272
  %generic_dict_group_deleted_offset161274 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1270, i1 false)
  %generic_dict_group_deleted_offset1275 = zext i16 %generic_dict_group_deleted_offset161274 to i64
  %generic_dict_group_deleted_unwrapped1276 = add i64 %generic_dict_group_start1258, %generic_dict_group_deleted_offset1275
  %generic_dict_group_deleted_slot1277 = and i64 %generic_dict_group_deleted_unwrapped1276, %dict_capacity_mask1250
  %generic_dict_group_captured_deleted1278 = select i1 %generic_dict_group_capture_deleted1273, i64 %generic_dict_group_deleted_slot1277, i64 %generic_dict_group_deleted1255
  br label %bb_generic_dict_candidate_loop291

bb_generic_dict_candidate_loop291:
  %generic_dict_candidate_bits1279 = phi i16 [ %generic_dict_group_match_bits1264, %bb_generic_dict_group_body290 ], [ %generic_dict_candidate_cleared_bits1280, %bb_generic_dict_candidate_next293 ]
  %generic_dict_has_candidate1281 = icmp ne i16 %generic_dict_candidate_bits1279, 0
  br i1 %generic_dict_has_candidate1281, label %bb_generic_dict_candidate_body292, label %bb_generic_dict_group_decision294

bb_generic_dict_candidate_body292:
  %generic_dict_candidate_offset161282 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1279, i1 false)
  %generic_dict_candidate_offset1283 = zext i16 %generic_dict_candidate_offset161282 to i64
  %generic_dict_candidate_unwrapped1284 = add i64 %generic_dict_group_start1258, %generic_dict_candidate_offset1283
  %generic_dict_candidate_slot1285 = and i64 %generic_dict_candidate_unwrapped1284, %dict_capacity_mask1250
  %generic_dict_key_entries_offset_mirror1286 = add i64 %set_grown_capacity1098, 23
  %generic_dict_key_entries_offset1287 = and i64 %generic_dict_key_entries_offset_mirror1286, -8
  %generic_dict_key_entries1288 = getelementptr i8, ptr %heap1103, i64 %generic_dict_key_entries_offset1287
  %generic_dict_key_entry_offset1289 = mul i64 %generic_dict_candidate_slot1285, 4
  %generic_dict_key_slot1290 = getelementptr i8, ptr %generic_dict_key_entries1288, i64 %generic_dict_key_entry_offset1289
  %generic_dict_key1291 = load i32, ptr %generic_dict_key_slot1290, align 4
  %generic_dict_key_equal1292 = icmp eq i32 %generic_dict_key1291, 30
  br i1 %generic_dict_key_equal1292, label %bb_generic_dict_group_match296, label %bb_generic_dict_candidate_next293

bb_generic_dict_candidate_next293:
  %generic_dict_candidate_bits_minus_one1293 = sub i16 %generic_dict_candidate_bits1279, 1
  %generic_dict_candidate_cleared_bits1280 = and i16 %generic_dict_candidate_bits1279, %generic_dict_candidate_bits_minus_one1293
  br label %bb_generic_dict_candidate_loop291

bb_generic_dict_group_decision294:
  %generic_dict_group_has_empty1294 = icmp ne i16 %generic_dict_group_empty_bits1266, 0
  br i1 %generic_dict_group_has_empty1294, label %bb_generic_dict_group_empty295, label %bb_generic_dict_group_next297

bb_generic_dict_group_empty295:
  %generic_dict_group_empty_offset161295 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1266, i1 false)
  %generic_dict_group_empty_offset1296 = zext i16 %generic_dict_group_empty_offset161295 to i64
  %generic_dict_group_empty_unwrapped1297 = add i64 %generic_dict_group_start1258, %generic_dict_group_empty_offset1296
  %generic_dict_group_empty_slot1298 = and i64 %generic_dict_group_empty_unwrapped1297, %dict_capacity_mask1250
  %generic_dict_group_use_empty1299 = icmp eq i64 %generic_dict_group_captured_deleted1278, %set_grown_capacity1098
  %generic_dict_group_insertion_slot1300 = select i1 %generic_dict_group_use_empty1299, i64 %generic_dict_group_empty_slot1298, i64 %generic_dict_group_captured_deleted1278
  br label %bb_generic_dict_group_done299

bb_generic_dict_group_match296:
  br label %bb_generic_dict_group_done299

bb_generic_dict_group_next297:
  %generic_dict_group_next_probe1252 = add i64 %generic_dict_group_probe1254, 16
  %generic_dict_group_next_deleted1253 = add i64 %generic_dict_group_captured_deleted1278, 0
  br label %bb_generic_dict_group_find289

bb_generic_dict_group_miss298:
  %generic_dict_group_miss_no_deleted1301 = icmp eq i64 %generic_dict_group_deleted1255, %set_grown_capacity1098
  %generic_dict_group_miss_slot1302 = select i1 %generic_dict_group_miss_no_deleted1301, i64 0, i64 %generic_dict_group_deleted1255
  br label %bb_generic_dict_group_done299

bb_generic_dict_group_done299:
  %generic_dict_find_found1303 = phi i1 [ false, %bb_generic_dict_group_empty295 ], [ true, %bb_generic_dict_group_match296 ], [ false, %bb_generic_dict_group_miss298 ]
  %generic_dict_find_slot_result1304 = phi i64 [ %generic_dict_group_insertion_slot1300, %bb_generic_dict_group_empty295 ], [ %generic_dict_candidate_slot1285, %bb_generic_dict_group_match296 ], [ %generic_dict_group_miss_slot1302, %bb_generic_dict_group_miss298 ]
  br label %bb_generic_dict_insert_first_done286

bb_generic_dict_insert_first_done286:
  %generic_dict_insert_first_found1305 = phi i1 [ true, %bb_generic_dict_insert_first_match283 ], [ false, %bb_generic_dict_insert_first_vacant285 ], [ %generic_dict_find_found1303, %bb_generic_dict_group_done299 ], [ false, %bb_generic_dict_insert_no_capacity288 ]
  %generic_dict_insert_first_slot_result1306 = phi i64 [ %dict_start_slot1228, %bb_generic_dict_insert_first_match283 ], [ %dict_start_slot1228, %bb_generic_dict_insert_first_vacant285 ], [ %generic_dict_find_slot_result1304, %bb_generic_dict_group_done299 ], [ 0, %bb_generic_dict_insert_no_capacity288 ]
  %set_key_entries_offset_mirror1307 = add i64 %set_grown_capacity1098, 23
  %set_key_entries_offset1308 = and i64 %set_key_entries_offset_mirror1307, -8
  %set_key_entries1309 = getelementptr i8, ptr %heap1103, i64 %set_key_entries_offset1308
  %set_key_entry_offset1310 = mul i64 %generic_dict_insert_first_slot_result1306, 4
  %set_key_slot1311 = getelementptr i8, ptr %set_key_entries1309, i64 %set_key_entry_offset1310
  store i32 30, ptr %set_key_slot1311, align 4
  %generic_dict_control_slot1312 = getelementptr i8, ptr %heap1103, i64 %generic_dict_insert_first_slot_result1306
  store i8 %dict_h2_byte1226, ptr %generic_dict_control_slot1312, align 1
  %generic_dict_control_mirrored1313 = icmp ult i64 %generic_dict_insert_first_slot_result1306, 16
  br i1 %generic_dict_control_mirrored1313, label %bb_generic_dict_control_mirror300, label %bb_generic_dict_control_done301

bb_generic_dict_control_mirror300:
  %generic_dict_control_mirror_index1314 = add i64 %set_grown_capacity1098, %generic_dict_insert_first_slot_result1306
  %generic_dict_control_mirror_slot1315 = getelementptr i8, ptr %heap1103, i64 %generic_dict_control_mirror_index1314
  store i8 %dict_h2_byte1226, ptr %generic_dict_control_mirror_slot1315, align 1
  br label %bb_generic_dict_control_done301

bb_generic_dict_control_done301:
  br label %bb_set_insert_done250

bb_set_insert_done250:
  %set_pointer1316 = phi ptr [ %mutable_ptr993, %bb_set_insert_duplicate246 ], [ %mutable_ptr993, %bb_generic_dict_control_done252 ], [ %heap1103, %bb_generic_dict_control_done301 ]
  %set_length1317 = phi i64 [ %mutable_len994, %bb_set_insert_duplicate246 ], [ %set_insert_length1085, %bb_generic_dict_control_done252 ], [ %set_insert_length1085, %bb_generic_dict_control_done301 ]
  %set_capacity1318 = phi i64 [ %mutable_capacity995, %bb_set_insert_duplicate246 ], [ %mutable_capacity995, %bb_generic_dict_control_done252 ], [ %set_grown_capacity1098, %bb_generic_dict_control_done301 ]
  %set_inserted1319 = phi i1 [ false, %bb_set_insert_duplicate246 ], [ true, %bb_generic_dict_control_done252 ], [ true, %bb_generic_dict_control_done301 ]
  store ptr %set_pointer1316, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length1317, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity1318, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr1320 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len1321 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity1322 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key1323 = sext i32 4 to i64
  %hash_high1325 = lshr i64 %hash_key1323, 32
  %hash_fold1324 = xor i64 %hash_key1323, %hash_high1325
  %hash1326 = mul i64 %hash_fold1324, -7046029254386353131
  %dict_h2_shifted1327 = lshr i64 %hash1326, 57
  %dict_h2_raw1328 = and i64 %dict_h2_shifted1327, 127
  %dict_h2_zero1329 = icmp eq i64 %dict_h2_raw1328, 0
  %dict_h21330 = select i1 %dict_h2_zero1329, i64 1, i64 %dict_h2_raw1328
  %dict_h2_byte1331 = trunc i64 %dict_h21330 to i8
  %dict_capacity_mask1332 = sub i64 %mutable_capacity1322, 1
  %dict_start_slot1333 = and i64 %hash1326, %dict_capacity_mask1332
  %generic_dict_insert_has_capacity1334 = icmp ugt i64 %mutable_capacity1322, 0
  br i1 %generic_dict_insert_has_capacity1334, label %bb_generic_dict_insert_first308, label %bb_generic_dict_insert_no_capacity309

bb_generic_dict_insert_no_capacity309:
  br label %bb_generic_dict_insert_first_done307

bb_generic_dict_insert_first308:
  %generic_dict_control_slot1335 = getelementptr i8, ptr %mutable_ptr1320, i64 %dict_start_slot1333
  %generic_dict_control1336 = load i8, ptr %generic_dict_control_slot1335, align 1
  %generic_dict_insert_first_empty1337 = icmp eq i8 %generic_dict_control1336, 0
  br i1 %generic_dict_insert_first_empty1337, label %bb_generic_dict_insert_first_vacant306, label %bb_generic_dict_insert_first_occupied302

bb_generic_dict_insert_first_occupied302:
  %generic_dict_insert_first_h21338 = icmp eq i8 %generic_dict_control1336, %dict_h2_byte1331
  br i1 %generic_dict_insert_first_h21338, label %bb_generic_dict_insert_first_compare303, label %bb_generic_dict_insert_first_fallback305

bb_generic_dict_insert_first_compare303:
  %generic_dict_insert_first_key_entries_offset_mirror1339 = add i64 %mutable_capacity1322, 23
  %generic_dict_insert_first_key_entries_offset1340 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1339, -8
  %generic_dict_insert_first_key_entries1341 = getelementptr i8, ptr %mutable_ptr1320, i64 %generic_dict_insert_first_key_entries_offset1340
  %generic_dict_insert_first_key_entry_offset1342 = mul i64 %dict_start_slot1333, 4
  %generic_dict_insert_first_key_slot1343 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1341, i64 %generic_dict_insert_first_key_entry_offset1342
  %generic_dict_insert_first_key1344 = load i32, ptr %generic_dict_insert_first_key_slot1343, align 4
  %generic_dict_key_equal1345 = icmp eq i32 %generic_dict_insert_first_key1344, 4
  br i1 %generic_dict_key_equal1345, label %bb_generic_dict_insert_first_match304, label %bb_generic_dict_insert_first_fallback305

bb_generic_dict_insert_first_match304:
  br label %bb_generic_dict_insert_first_done307

bb_generic_dict_insert_first_vacant306:
  br label %bb_generic_dict_insert_first_done307

bb_generic_dict_insert_first_fallback305:
  %hash_key1346 = sext i32 4 to i64
  %hash_high1348 = lshr i64 %hash_key1346, 32
  %hash_fold1347 = xor i64 %hash_key1346, %hash_high1348
  %hash1349 = mul i64 %hash_fold1347, -7046029254386353131
  %dict_h2_shifted1350 = lshr i64 %hash1349, 57
  %dict_h2_raw1351 = and i64 %dict_h2_shifted1350, 127
  %dict_h2_zero1352 = icmp eq i64 %dict_h2_raw1351, 0
  %dict_h21353 = select i1 %dict_h2_zero1352, i64 1, i64 %dict_h2_raw1351
  %dict_h2_byte1354 = trunc i64 %dict_h21353 to i8
  %dict_capacity_mask1355 = sub i64 %mutable_capacity1322, 1
  %dict_start_slot1356 = and i64 %hash1349, %dict_capacity_mask1355
  br label %bb_generic_dict_group_find310

bb_generic_dict_group_find310:
  %generic_dict_group_probe1359 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback305 ], [ %generic_dict_group_next_probe1357, %bb_generic_dict_group_next318 ]
  %generic_dict_group_deleted1360 = phi i64 [ %mutable_capacity1322, %bb_generic_dict_insert_first_fallback305 ], [ %generic_dict_group_next_deleted1358, %bb_generic_dict_group_next318 ]
  %generic_dict_group_active1361 = icmp ult i64 %generic_dict_group_probe1359, %mutable_capacity1322
  br i1 %generic_dict_group_active1361, label %bb_generic_dict_group_body311, label %bb_generic_dict_group_miss319

bb_generic_dict_group_body311:
  %generic_dict_group_unwrapped1362 = add i64 %dict_start_slot1356, %generic_dict_group_probe1359
  %generic_dict_group_start1363 = and i64 %generic_dict_group_unwrapped1362, %dict_capacity_mask1355
  %generic_dict_group_pointer1364 = getelementptr i8, ptr %mutable_ptr1320, i64 %generic_dict_group_start1363
  %generic_dict_group_controls1365 = load <16 x i8>, ptr %generic_dict_group_pointer1364, align 1
  %generic_dict_group_h2_seed1366 = insertelement <16 x i8> poison, i8 %dict_h2_byte1354, i64 0
  %generic_dict_group_h2_vector1367 = shufflevector <16 x i8> %generic_dict_group_h2_seed1366, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1368 = icmp eq <16 x i8> %generic_dict_group_controls1365, %generic_dict_group_h2_vector1367
  %generic_dict_group_match_bits1369 = bitcast <16 x i1> %generic_dict_group_matches_vector1368 to i16
  %generic_dict_group_empty_vector1370 = icmp eq <16 x i8> %generic_dict_group_controls1365, zeroinitializer
  %generic_dict_group_empty_bits1371 = bitcast <16 x i1> %generic_dict_group_empty_vector1370 to i16
  %generic_dict_group_deleted_seed1372 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1373 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1372, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1374 = icmp eq <16 x i8> %generic_dict_group_controls1365, %generic_dict_group_deleted_vector1373
  %generic_dict_group_deleted_bits1375 = bitcast <16 x i1> %generic_dict_group_deleted_matches1374 to i16
  %generic_dict_group_has_deleted1376 = icmp ne i16 %generic_dict_group_deleted_bits1375, 0
  %generic_dict_group_no_previous_deleted1377 = icmp eq i64 %generic_dict_group_deleted1360, %mutable_capacity1322
  %generic_dict_group_capture_deleted1378 = and i1 %generic_dict_group_has_deleted1376, %generic_dict_group_no_previous_deleted1377
  %generic_dict_group_deleted_offset161379 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1375, i1 false)
  %generic_dict_group_deleted_offset1380 = zext i16 %generic_dict_group_deleted_offset161379 to i64
  %generic_dict_group_deleted_unwrapped1381 = add i64 %generic_dict_group_start1363, %generic_dict_group_deleted_offset1380
  %generic_dict_group_deleted_slot1382 = and i64 %generic_dict_group_deleted_unwrapped1381, %dict_capacity_mask1355
  %generic_dict_group_captured_deleted1383 = select i1 %generic_dict_group_capture_deleted1378, i64 %generic_dict_group_deleted_slot1382, i64 %generic_dict_group_deleted1360
  br label %bb_generic_dict_candidate_loop312

bb_generic_dict_candidate_loop312:
  %generic_dict_candidate_bits1384 = phi i16 [ %generic_dict_group_match_bits1369, %bb_generic_dict_group_body311 ], [ %generic_dict_candidate_cleared_bits1385, %bb_generic_dict_candidate_next314 ]
  %generic_dict_has_candidate1386 = icmp ne i16 %generic_dict_candidate_bits1384, 0
  br i1 %generic_dict_has_candidate1386, label %bb_generic_dict_candidate_body313, label %bb_generic_dict_group_decision315

bb_generic_dict_candidate_body313:
  %generic_dict_candidate_offset161387 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1384, i1 false)
  %generic_dict_candidate_offset1388 = zext i16 %generic_dict_candidate_offset161387 to i64
  %generic_dict_candidate_unwrapped1389 = add i64 %generic_dict_group_start1363, %generic_dict_candidate_offset1388
  %generic_dict_candidate_slot1390 = and i64 %generic_dict_candidate_unwrapped1389, %dict_capacity_mask1355
  %generic_dict_key_entries_offset_mirror1391 = add i64 %mutable_capacity1322, 23
  %generic_dict_key_entries_offset1392 = and i64 %generic_dict_key_entries_offset_mirror1391, -8
  %generic_dict_key_entries1393 = getelementptr i8, ptr %mutable_ptr1320, i64 %generic_dict_key_entries_offset1392
  %generic_dict_key_entry_offset1394 = mul i64 %generic_dict_candidate_slot1390, 4
  %generic_dict_key_slot1395 = getelementptr i8, ptr %generic_dict_key_entries1393, i64 %generic_dict_key_entry_offset1394
  %generic_dict_key1396 = load i32, ptr %generic_dict_key_slot1395, align 4
  %generic_dict_key_equal1397 = icmp eq i32 %generic_dict_key1396, 4
  br i1 %generic_dict_key_equal1397, label %bb_generic_dict_group_match317, label %bb_generic_dict_candidate_next314

bb_generic_dict_candidate_next314:
  %generic_dict_candidate_bits_minus_one1398 = sub i16 %generic_dict_candidate_bits1384, 1
  %generic_dict_candidate_cleared_bits1385 = and i16 %generic_dict_candidate_bits1384, %generic_dict_candidate_bits_minus_one1398
  br label %bb_generic_dict_candidate_loop312

bb_generic_dict_group_decision315:
  %generic_dict_group_has_empty1399 = icmp ne i16 %generic_dict_group_empty_bits1371, 0
  br i1 %generic_dict_group_has_empty1399, label %bb_generic_dict_group_empty316, label %bb_generic_dict_group_next318

bb_generic_dict_group_empty316:
  %generic_dict_group_empty_offset161400 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1371, i1 false)
  %generic_dict_group_empty_offset1401 = zext i16 %generic_dict_group_empty_offset161400 to i64
  %generic_dict_group_empty_unwrapped1402 = add i64 %generic_dict_group_start1363, %generic_dict_group_empty_offset1401
  %generic_dict_group_empty_slot1403 = and i64 %generic_dict_group_empty_unwrapped1402, %dict_capacity_mask1355
  %generic_dict_group_use_empty1404 = icmp eq i64 %generic_dict_group_captured_deleted1383, %mutable_capacity1322
  %generic_dict_group_insertion_slot1405 = select i1 %generic_dict_group_use_empty1404, i64 %generic_dict_group_empty_slot1403, i64 %generic_dict_group_captured_deleted1383
  br label %bb_generic_dict_group_done320

bb_generic_dict_group_match317:
  br label %bb_generic_dict_group_done320

bb_generic_dict_group_next318:
  %generic_dict_group_next_probe1357 = add i64 %generic_dict_group_probe1359, 16
  %generic_dict_group_next_deleted1358 = add i64 %generic_dict_group_captured_deleted1383, 0
  br label %bb_generic_dict_group_find310

bb_generic_dict_group_miss319:
  %generic_dict_group_miss_no_deleted1406 = icmp eq i64 %generic_dict_group_deleted1360, %mutable_capacity1322
  %generic_dict_group_miss_slot1407 = select i1 %generic_dict_group_miss_no_deleted1406, i64 0, i64 %generic_dict_group_deleted1360
  br label %bb_generic_dict_group_done320

bb_generic_dict_group_done320:
  %generic_dict_find_found1408 = phi i1 [ false, %bb_generic_dict_group_empty316 ], [ true, %bb_generic_dict_group_match317 ], [ false, %bb_generic_dict_group_miss319 ]
  %generic_dict_find_slot_result1409 = phi i64 [ %generic_dict_group_insertion_slot1405, %bb_generic_dict_group_empty316 ], [ %generic_dict_candidate_slot1390, %bb_generic_dict_group_match317 ], [ %generic_dict_group_miss_slot1407, %bb_generic_dict_group_miss319 ]
  br label %bb_generic_dict_insert_first_done307

bb_generic_dict_insert_first_done307:
  %generic_dict_insert_first_found1410 = phi i1 [ true, %bb_generic_dict_insert_first_match304 ], [ false, %bb_generic_dict_insert_first_vacant306 ], [ %generic_dict_find_found1408, %bb_generic_dict_group_done320 ], [ false, %bb_generic_dict_insert_no_capacity309 ]
  %generic_dict_insert_first_slot_result1411 = phi i64 [ %dict_start_slot1333, %bb_generic_dict_insert_first_match304 ], [ %dict_start_slot1333, %bb_generic_dict_insert_first_vacant306 ], [ %generic_dict_find_slot_result1409, %bb_generic_dict_group_done320 ], [ 0, %bb_generic_dict_insert_no_capacity309 ]
  br i1 %generic_dict_insert_first_found1410, label %bb_set_insert_duplicate321, label %bb_set_insert_new322

bb_set_insert_duplicate321:
  br label %bb_set_insert_done325

bb_set_insert_new322:
  %set_insert_length1412 = add i64 %mutable_len1321, 1
  %set_insert_load_num1413 = mul i64 %set_insert_length1412, 8
  %set_insert_load_den1414 = mul i64 %mutable_capacity1322, 7
  %set_insert_should_grow1415 = icmp ugt i64 %set_insert_load_num1413, %set_insert_load_den1414
  br i1 %set_insert_should_grow1415, label %bb_set_insert_grow324, label %bb_set_insert_current323

bb_set_insert_current323:
  %set_key_entries_offset_mirror1416 = add i64 %mutable_capacity1322, 23
  %set_key_entries_offset1417 = and i64 %set_key_entries_offset_mirror1416, -8
  %set_key_entries1418 = getelementptr i8, ptr %mutable_ptr1320, i64 %set_key_entries_offset1417
  %set_key_entry_offset1419 = mul i64 %generic_dict_insert_first_slot_result1411, 4
  %set_key_slot1420 = getelementptr i8, ptr %set_key_entries1418, i64 %set_key_entry_offset1419
  store i32 4, ptr %set_key_slot1420, align 4
  %generic_dict_control_slot1421 = getelementptr i8, ptr %mutable_ptr1320, i64 %generic_dict_insert_first_slot_result1411
  store i8 %dict_h2_byte1331, ptr %generic_dict_control_slot1421, align 1
  %generic_dict_control_mirrored1422 = icmp ult i64 %generic_dict_insert_first_slot_result1411, 16
  br i1 %generic_dict_control_mirrored1422, label %bb_generic_dict_control_mirror326, label %bb_generic_dict_control_done327

bb_generic_dict_control_mirror326:
  %generic_dict_control_mirror_index1423 = add i64 %mutable_capacity1322, %generic_dict_insert_first_slot_result1411
  %generic_dict_control_mirror_slot1424 = getelementptr i8, ptr %mutable_ptr1320, i64 %generic_dict_control_mirror_index1423
  store i8 %dict_h2_byte1331, ptr %generic_dict_control_mirror_slot1424, align 1
  br label %bb_generic_dict_control_done327

bb_generic_dict_control_done327:
  br label %bb_set_insert_done325

bb_set_insert_grow324:
  %set_grown_capacity1425 = mul i64 %mutable_capacity1322, 2
  %generic_dict_entries_offset_mirror1426 = add i64 %set_grown_capacity1425, 23
  %generic_dict_entries_offset1427 = and i64 %generic_dict_entries_offset_mirror1426, -8
  %generic_dict_entries_bytes1428 = mul i64 %set_grown_capacity1425, 4
  %generic_dict_bytes1429 = add i64 %generic_dict_entries_offset1427, %generic_dict_entries_bytes1428
  %heap1430 = call ptr @sollang_alloc(i64 %generic_dict_bytes1429)
  %heap_ok1431 = icmp ne ptr %heap1430, null
  br i1 %heap_ok1431, label %bb_alloc_ok328, label %bb_alloc_fail329

bb_alloc_fail329:
  %trap_stderr1432 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr1432, ptr @.slg.str.module.x.5, i32 25, ptr %trap_written1433, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok328:
  %generic_dict_control_bytes1434 = add i64 %set_grown_capacity1425, 16
  call void @llvm.memset.p0.i64(ptr %heap1430, i8 0, i64 %generic_dict_control_bytes1434, i1 false)
  br label %bb_set_rehash330

bb_set_rehash330:
  %set_rehash_index1436 = phi i64 [ 0, %bb_alloc_ok328 ], [ %set_rehash_next_index1435, %bb_set_rehash_next333 ]
  %set_rehash_active1437 = icmp ult i64 %set_rehash_index1436, %mutable_capacity1322
  br i1 %set_rehash_active1437, label %bb_set_rehash_body331, label %bb_set_rehash_done334

bb_set_rehash_body331:
  %generic_dict_control_slot1438 = getelementptr i8, ptr %mutable_ptr1320, i64 %set_rehash_index1436
  %generic_dict_control1439 = load i8, ptr %generic_dict_control_slot1438, align 1
  %set_rehash_occupied1440 = icmp sgt i8 %generic_dict_control1439, 0
  br i1 %set_rehash_occupied1440, label %bb_set_rehash_move332, label %bb_set_rehash_next333

bb_set_rehash_move332:
  %set_rehash_key_entries_offset_mirror1441 = add i64 %mutable_capacity1322, 23
  %set_rehash_key_entries_offset1442 = and i64 %set_rehash_key_entries_offset_mirror1441, -8
  %set_rehash_key_entries1443 = getelementptr i8, ptr %mutable_ptr1320, i64 %set_rehash_key_entries_offset1442
  %set_rehash_key_entry_offset1444 = mul i64 %set_rehash_index1436, 4
  %set_rehash_key_slot1445 = getelementptr i8, ptr %set_rehash_key_entries1443, i64 %set_rehash_key_entry_offset1444
  %set_rehash_key1446 = load i32, ptr %set_rehash_key_slot1445, align 4
  %hash_key1447 = sext i32 %set_rehash_key1446 to i64
  %hash_high1449 = lshr i64 %hash_key1447, 32
  %hash_fold1448 = xor i64 %hash_key1447, %hash_high1449
  %hash1450 = mul i64 %hash_fold1448, -7046029254386353131
  %dict_h2_shifted1451 = lshr i64 %hash1450, 57
  %dict_h2_raw1452 = and i64 %dict_h2_shifted1451, 127
  %dict_h2_zero1453 = icmp eq i64 %dict_h2_raw1452, 0
  %dict_h21454 = select i1 %dict_h2_zero1453, i64 1, i64 %dict_h2_raw1452
  %dict_h2_byte1455 = trunc i64 %dict_h21454 to i8
  %dict_capacity_mask1456 = sub i64 %set_grown_capacity1425, 1
  %dict_start_slot1457 = and i64 %hash1450, %dict_capacity_mask1456
  %generic_dict_insert_has_capacity1458 = icmp ugt i64 %set_grown_capacity1425, 0
  br i1 %generic_dict_insert_has_capacity1458, label %bb_generic_dict_insert_first341, label %bb_generic_dict_insert_no_capacity342

bb_generic_dict_insert_no_capacity342:
  br label %bb_generic_dict_insert_first_done340

bb_generic_dict_insert_first341:
  %generic_dict_control_slot1459 = getelementptr i8, ptr %heap1430, i64 %dict_start_slot1457
  %generic_dict_control1460 = load i8, ptr %generic_dict_control_slot1459, align 1
  %generic_dict_insert_first_empty1461 = icmp eq i8 %generic_dict_control1460, 0
  br i1 %generic_dict_insert_first_empty1461, label %bb_generic_dict_insert_first_vacant339, label %bb_generic_dict_insert_first_occupied335

bb_generic_dict_insert_first_occupied335:
  %generic_dict_insert_first_h21462 = icmp eq i8 %generic_dict_control1460, %dict_h2_byte1455
  br i1 %generic_dict_insert_first_h21462, label %bb_generic_dict_insert_first_compare336, label %bb_generic_dict_insert_first_fallback338

bb_generic_dict_insert_first_compare336:
  %generic_dict_insert_first_key_entries_offset_mirror1463 = add i64 %set_grown_capacity1425, 23
  %generic_dict_insert_first_key_entries_offset1464 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1463, -8
  %generic_dict_insert_first_key_entries1465 = getelementptr i8, ptr %heap1430, i64 %generic_dict_insert_first_key_entries_offset1464
  %generic_dict_insert_first_key_entry_offset1466 = mul i64 %dict_start_slot1457, 4
  %generic_dict_insert_first_key_slot1467 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1465, i64 %generic_dict_insert_first_key_entry_offset1466
  %generic_dict_insert_first_key1468 = load i32, ptr %generic_dict_insert_first_key_slot1467, align 4
  %generic_dict_key_equal1469 = icmp eq i32 %generic_dict_insert_first_key1468, %set_rehash_key1446
  br i1 %generic_dict_key_equal1469, label %bb_generic_dict_insert_first_match337, label %bb_generic_dict_insert_first_fallback338

bb_generic_dict_insert_first_match337:
  br label %bb_generic_dict_insert_first_done340

bb_generic_dict_insert_first_vacant339:
  br label %bb_generic_dict_insert_first_done340

bb_generic_dict_insert_first_fallback338:
  %hash_key1470 = sext i32 %set_rehash_key1446 to i64
  %hash_high1472 = lshr i64 %hash_key1470, 32
  %hash_fold1471 = xor i64 %hash_key1470, %hash_high1472
  %hash1473 = mul i64 %hash_fold1471, -7046029254386353131
  %dict_h2_shifted1474 = lshr i64 %hash1473, 57
  %dict_h2_raw1475 = and i64 %dict_h2_shifted1474, 127
  %dict_h2_zero1476 = icmp eq i64 %dict_h2_raw1475, 0
  %dict_h21477 = select i1 %dict_h2_zero1476, i64 1, i64 %dict_h2_raw1475
  %dict_h2_byte1478 = trunc i64 %dict_h21477 to i8
  %dict_capacity_mask1479 = sub i64 %set_grown_capacity1425, 1
  %dict_start_slot1480 = and i64 %hash1473, %dict_capacity_mask1479
  br label %bb_generic_dict_group_find343

bb_generic_dict_group_find343:
  %generic_dict_group_probe1483 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback338 ], [ %generic_dict_group_next_probe1481, %bb_generic_dict_group_next351 ]
  %generic_dict_group_deleted1484 = phi i64 [ %set_grown_capacity1425, %bb_generic_dict_insert_first_fallback338 ], [ %generic_dict_group_next_deleted1482, %bb_generic_dict_group_next351 ]
  %generic_dict_group_active1485 = icmp ult i64 %generic_dict_group_probe1483, %set_grown_capacity1425
  br i1 %generic_dict_group_active1485, label %bb_generic_dict_group_body344, label %bb_generic_dict_group_miss352

bb_generic_dict_group_body344:
  %generic_dict_group_unwrapped1486 = add i64 %dict_start_slot1480, %generic_dict_group_probe1483
  %generic_dict_group_start1487 = and i64 %generic_dict_group_unwrapped1486, %dict_capacity_mask1479
  %generic_dict_group_pointer1488 = getelementptr i8, ptr %heap1430, i64 %generic_dict_group_start1487
  %generic_dict_group_controls1489 = load <16 x i8>, ptr %generic_dict_group_pointer1488, align 1
  %generic_dict_group_h2_seed1490 = insertelement <16 x i8> poison, i8 %dict_h2_byte1478, i64 0
  %generic_dict_group_h2_vector1491 = shufflevector <16 x i8> %generic_dict_group_h2_seed1490, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1492 = icmp eq <16 x i8> %generic_dict_group_controls1489, %generic_dict_group_h2_vector1491
  %generic_dict_group_match_bits1493 = bitcast <16 x i1> %generic_dict_group_matches_vector1492 to i16
  %generic_dict_group_empty_vector1494 = icmp eq <16 x i8> %generic_dict_group_controls1489, zeroinitializer
  %generic_dict_group_empty_bits1495 = bitcast <16 x i1> %generic_dict_group_empty_vector1494 to i16
  %generic_dict_group_deleted_seed1496 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1497 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1496, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1498 = icmp eq <16 x i8> %generic_dict_group_controls1489, %generic_dict_group_deleted_vector1497
  %generic_dict_group_deleted_bits1499 = bitcast <16 x i1> %generic_dict_group_deleted_matches1498 to i16
  %generic_dict_group_has_deleted1500 = icmp ne i16 %generic_dict_group_deleted_bits1499, 0
  %generic_dict_group_no_previous_deleted1501 = icmp eq i64 %generic_dict_group_deleted1484, %set_grown_capacity1425
  %generic_dict_group_capture_deleted1502 = and i1 %generic_dict_group_has_deleted1500, %generic_dict_group_no_previous_deleted1501
  %generic_dict_group_deleted_offset161503 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1499, i1 false)
  %generic_dict_group_deleted_offset1504 = zext i16 %generic_dict_group_deleted_offset161503 to i64
  %generic_dict_group_deleted_unwrapped1505 = add i64 %generic_dict_group_start1487, %generic_dict_group_deleted_offset1504
  %generic_dict_group_deleted_slot1506 = and i64 %generic_dict_group_deleted_unwrapped1505, %dict_capacity_mask1479
  %generic_dict_group_captured_deleted1507 = select i1 %generic_dict_group_capture_deleted1502, i64 %generic_dict_group_deleted_slot1506, i64 %generic_dict_group_deleted1484
  br label %bb_generic_dict_candidate_loop345

bb_generic_dict_candidate_loop345:
  %generic_dict_candidate_bits1508 = phi i16 [ %generic_dict_group_match_bits1493, %bb_generic_dict_group_body344 ], [ %generic_dict_candidate_cleared_bits1509, %bb_generic_dict_candidate_next347 ]
  %generic_dict_has_candidate1510 = icmp ne i16 %generic_dict_candidate_bits1508, 0
  br i1 %generic_dict_has_candidate1510, label %bb_generic_dict_candidate_body346, label %bb_generic_dict_group_decision348

bb_generic_dict_candidate_body346:
  %generic_dict_candidate_offset161511 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1508, i1 false)
  %generic_dict_candidate_offset1512 = zext i16 %generic_dict_candidate_offset161511 to i64
  %generic_dict_candidate_unwrapped1513 = add i64 %generic_dict_group_start1487, %generic_dict_candidate_offset1512
  %generic_dict_candidate_slot1514 = and i64 %generic_dict_candidate_unwrapped1513, %dict_capacity_mask1479
  %generic_dict_key_entries_offset_mirror1515 = add i64 %set_grown_capacity1425, 23
  %generic_dict_key_entries_offset1516 = and i64 %generic_dict_key_entries_offset_mirror1515, -8
  %generic_dict_key_entries1517 = getelementptr i8, ptr %heap1430, i64 %generic_dict_key_entries_offset1516
  %generic_dict_key_entry_offset1518 = mul i64 %generic_dict_candidate_slot1514, 4
  %generic_dict_key_slot1519 = getelementptr i8, ptr %generic_dict_key_entries1517, i64 %generic_dict_key_entry_offset1518
  %generic_dict_key1520 = load i32, ptr %generic_dict_key_slot1519, align 4
  %generic_dict_key_equal1521 = icmp eq i32 %generic_dict_key1520, %set_rehash_key1446
  br i1 %generic_dict_key_equal1521, label %bb_generic_dict_group_match350, label %bb_generic_dict_candidate_next347

bb_generic_dict_candidate_next347:
  %generic_dict_candidate_bits_minus_one1522 = sub i16 %generic_dict_candidate_bits1508, 1
  %generic_dict_candidate_cleared_bits1509 = and i16 %generic_dict_candidate_bits1508, %generic_dict_candidate_bits_minus_one1522
  br label %bb_generic_dict_candidate_loop345

bb_generic_dict_group_decision348:
  %generic_dict_group_has_empty1523 = icmp ne i16 %generic_dict_group_empty_bits1495, 0
  br i1 %generic_dict_group_has_empty1523, label %bb_generic_dict_group_empty349, label %bb_generic_dict_group_next351

bb_generic_dict_group_empty349:
  %generic_dict_group_empty_offset161524 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1495, i1 false)
  %generic_dict_group_empty_offset1525 = zext i16 %generic_dict_group_empty_offset161524 to i64
  %generic_dict_group_empty_unwrapped1526 = add i64 %generic_dict_group_start1487, %generic_dict_group_empty_offset1525
  %generic_dict_group_empty_slot1527 = and i64 %generic_dict_group_empty_unwrapped1526, %dict_capacity_mask1479
  %generic_dict_group_use_empty1528 = icmp eq i64 %generic_dict_group_captured_deleted1507, %set_grown_capacity1425
  %generic_dict_group_insertion_slot1529 = select i1 %generic_dict_group_use_empty1528, i64 %generic_dict_group_empty_slot1527, i64 %generic_dict_group_captured_deleted1507
  br label %bb_generic_dict_group_done353

bb_generic_dict_group_match350:
  br label %bb_generic_dict_group_done353

bb_generic_dict_group_next351:
  %generic_dict_group_next_probe1481 = add i64 %generic_dict_group_probe1483, 16
  %generic_dict_group_next_deleted1482 = add i64 %generic_dict_group_captured_deleted1507, 0
  br label %bb_generic_dict_group_find343

bb_generic_dict_group_miss352:
  %generic_dict_group_miss_no_deleted1530 = icmp eq i64 %generic_dict_group_deleted1484, %set_grown_capacity1425
  %generic_dict_group_miss_slot1531 = select i1 %generic_dict_group_miss_no_deleted1530, i64 0, i64 %generic_dict_group_deleted1484
  br label %bb_generic_dict_group_done353

bb_generic_dict_group_done353:
  %generic_dict_find_found1532 = phi i1 [ false, %bb_generic_dict_group_empty349 ], [ true, %bb_generic_dict_group_match350 ], [ false, %bb_generic_dict_group_miss352 ]
  %generic_dict_find_slot_result1533 = phi i64 [ %generic_dict_group_insertion_slot1529, %bb_generic_dict_group_empty349 ], [ %generic_dict_candidate_slot1514, %bb_generic_dict_group_match350 ], [ %generic_dict_group_miss_slot1531, %bb_generic_dict_group_miss352 ]
  br label %bb_generic_dict_insert_first_done340

bb_generic_dict_insert_first_done340:
  %generic_dict_insert_first_found1534 = phi i1 [ true, %bb_generic_dict_insert_first_match337 ], [ false, %bb_generic_dict_insert_first_vacant339 ], [ %generic_dict_find_found1532, %bb_generic_dict_group_done353 ], [ false, %bb_generic_dict_insert_no_capacity342 ]
  %generic_dict_insert_first_slot_result1535 = phi i64 [ %dict_start_slot1457, %bb_generic_dict_insert_first_match337 ], [ %dict_start_slot1457, %bb_generic_dict_insert_first_vacant339 ], [ %generic_dict_find_slot_result1533, %bb_generic_dict_group_done353 ], [ 0, %bb_generic_dict_insert_no_capacity342 ]
  %set_key_entries_offset_mirror1536 = add i64 %set_grown_capacity1425, 23
  %set_key_entries_offset1537 = and i64 %set_key_entries_offset_mirror1536, -8
  %set_key_entries1538 = getelementptr i8, ptr %heap1430, i64 %set_key_entries_offset1537
  %set_key_entry_offset1539 = mul i64 %generic_dict_insert_first_slot_result1535, 4
  %set_key_slot1540 = getelementptr i8, ptr %set_key_entries1538, i64 %set_key_entry_offset1539
  store i32 %set_rehash_key1446, ptr %set_key_slot1540, align 4
  %generic_dict_control_slot1541 = getelementptr i8, ptr %heap1430, i64 %generic_dict_insert_first_slot_result1535
  store i8 %dict_h2_byte1455, ptr %generic_dict_control_slot1541, align 1
  %generic_dict_control_mirrored1542 = icmp ult i64 %generic_dict_insert_first_slot_result1535, 16
  br i1 %generic_dict_control_mirrored1542, label %bb_generic_dict_control_mirror354, label %bb_generic_dict_control_done355

bb_generic_dict_control_mirror354:
  %generic_dict_control_mirror_index1543 = add i64 %set_grown_capacity1425, %generic_dict_insert_first_slot_result1535
  %generic_dict_control_mirror_slot1544 = getelementptr i8, ptr %heap1430, i64 %generic_dict_control_mirror_index1543
  store i8 %dict_h2_byte1455, ptr %generic_dict_control_mirror_slot1544, align 1
  br label %bb_generic_dict_control_done355

bb_generic_dict_control_done355:
  br label %bb_set_rehash_next333

bb_set_rehash_next333:
  %set_rehash_next_index1435 = add i64 %set_rehash_index1436, 1
  br label %bb_set_rehash330

bb_set_rehash_done334:
  call void @sollang_free(ptr %mutable_ptr1320)
  %hash_key1545 = sext i32 4 to i64
  %hash_high1547 = lshr i64 %hash_key1545, 32
  %hash_fold1546 = xor i64 %hash_key1545, %hash_high1547
  %hash1548 = mul i64 %hash_fold1546, -7046029254386353131
  %dict_h2_shifted1549 = lshr i64 %hash1548, 57
  %dict_h2_raw1550 = and i64 %dict_h2_shifted1549, 127
  %dict_h2_zero1551 = icmp eq i64 %dict_h2_raw1550, 0
  %dict_h21552 = select i1 %dict_h2_zero1551, i64 1, i64 %dict_h2_raw1550
  %dict_h2_byte1553 = trunc i64 %dict_h21552 to i8
  %dict_capacity_mask1554 = sub i64 %set_grown_capacity1425, 1
  %dict_start_slot1555 = and i64 %hash1548, %dict_capacity_mask1554
  %generic_dict_insert_has_capacity1556 = icmp ugt i64 %set_grown_capacity1425, 0
  br i1 %generic_dict_insert_has_capacity1556, label %bb_generic_dict_insert_first362, label %bb_generic_dict_insert_no_capacity363

bb_generic_dict_insert_no_capacity363:
  br label %bb_generic_dict_insert_first_done361

bb_generic_dict_insert_first362:
  %generic_dict_control_slot1557 = getelementptr i8, ptr %heap1430, i64 %dict_start_slot1555
  %generic_dict_control1558 = load i8, ptr %generic_dict_control_slot1557, align 1
  %generic_dict_insert_first_empty1559 = icmp eq i8 %generic_dict_control1558, 0
  br i1 %generic_dict_insert_first_empty1559, label %bb_generic_dict_insert_first_vacant360, label %bb_generic_dict_insert_first_occupied356

bb_generic_dict_insert_first_occupied356:
  %generic_dict_insert_first_h21560 = icmp eq i8 %generic_dict_control1558, %dict_h2_byte1553
  br i1 %generic_dict_insert_first_h21560, label %bb_generic_dict_insert_first_compare357, label %bb_generic_dict_insert_first_fallback359

bb_generic_dict_insert_first_compare357:
  %generic_dict_insert_first_key_entries_offset_mirror1561 = add i64 %set_grown_capacity1425, 23
  %generic_dict_insert_first_key_entries_offset1562 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1561, -8
  %generic_dict_insert_first_key_entries1563 = getelementptr i8, ptr %heap1430, i64 %generic_dict_insert_first_key_entries_offset1562
  %generic_dict_insert_first_key_entry_offset1564 = mul i64 %dict_start_slot1555, 4
  %generic_dict_insert_first_key_slot1565 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1563, i64 %generic_dict_insert_first_key_entry_offset1564
  %generic_dict_insert_first_key1566 = load i32, ptr %generic_dict_insert_first_key_slot1565, align 4
  %generic_dict_key_equal1567 = icmp eq i32 %generic_dict_insert_first_key1566, 4
  br i1 %generic_dict_key_equal1567, label %bb_generic_dict_insert_first_match358, label %bb_generic_dict_insert_first_fallback359

bb_generic_dict_insert_first_match358:
  br label %bb_generic_dict_insert_first_done361

bb_generic_dict_insert_first_vacant360:
  br label %bb_generic_dict_insert_first_done361

bb_generic_dict_insert_first_fallback359:
  %hash_key1568 = sext i32 4 to i64
  %hash_high1570 = lshr i64 %hash_key1568, 32
  %hash_fold1569 = xor i64 %hash_key1568, %hash_high1570
  %hash1571 = mul i64 %hash_fold1569, -7046029254386353131
  %dict_h2_shifted1572 = lshr i64 %hash1571, 57
  %dict_h2_raw1573 = and i64 %dict_h2_shifted1572, 127
  %dict_h2_zero1574 = icmp eq i64 %dict_h2_raw1573, 0
  %dict_h21575 = select i1 %dict_h2_zero1574, i64 1, i64 %dict_h2_raw1573
  %dict_h2_byte1576 = trunc i64 %dict_h21575 to i8
  %dict_capacity_mask1577 = sub i64 %set_grown_capacity1425, 1
  %dict_start_slot1578 = and i64 %hash1571, %dict_capacity_mask1577
  br label %bb_generic_dict_group_find364

bb_generic_dict_group_find364:
  %generic_dict_group_probe1581 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback359 ], [ %generic_dict_group_next_probe1579, %bb_generic_dict_group_next372 ]
  %generic_dict_group_deleted1582 = phi i64 [ %set_grown_capacity1425, %bb_generic_dict_insert_first_fallback359 ], [ %generic_dict_group_next_deleted1580, %bb_generic_dict_group_next372 ]
  %generic_dict_group_active1583 = icmp ult i64 %generic_dict_group_probe1581, %set_grown_capacity1425
  br i1 %generic_dict_group_active1583, label %bb_generic_dict_group_body365, label %bb_generic_dict_group_miss373

bb_generic_dict_group_body365:
  %generic_dict_group_unwrapped1584 = add i64 %dict_start_slot1578, %generic_dict_group_probe1581
  %generic_dict_group_start1585 = and i64 %generic_dict_group_unwrapped1584, %dict_capacity_mask1577
  %generic_dict_group_pointer1586 = getelementptr i8, ptr %heap1430, i64 %generic_dict_group_start1585
  %generic_dict_group_controls1587 = load <16 x i8>, ptr %generic_dict_group_pointer1586, align 1
  %generic_dict_group_h2_seed1588 = insertelement <16 x i8> poison, i8 %dict_h2_byte1576, i64 0
  %generic_dict_group_h2_vector1589 = shufflevector <16 x i8> %generic_dict_group_h2_seed1588, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1590 = icmp eq <16 x i8> %generic_dict_group_controls1587, %generic_dict_group_h2_vector1589
  %generic_dict_group_match_bits1591 = bitcast <16 x i1> %generic_dict_group_matches_vector1590 to i16
  %generic_dict_group_empty_vector1592 = icmp eq <16 x i8> %generic_dict_group_controls1587, zeroinitializer
  %generic_dict_group_empty_bits1593 = bitcast <16 x i1> %generic_dict_group_empty_vector1592 to i16
  %generic_dict_group_deleted_seed1594 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1595 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1594, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1596 = icmp eq <16 x i8> %generic_dict_group_controls1587, %generic_dict_group_deleted_vector1595
  %generic_dict_group_deleted_bits1597 = bitcast <16 x i1> %generic_dict_group_deleted_matches1596 to i16
  %generic_dict_group_has_deleted1598 = icmp ne i16 %generic_dict_group_deleted_bits1597, 0
  %generic_dict_group_no_previous_deleted1599 = icmp eq i64 %generic_dict_group_deleted1582, %set_grown_capacity1425
  %generic_dict_group_capture_deleted1600 = and i1 %generic_dict_group_has_deleted1598, %generic_dict_group_no_previous_deleted1599
  %generic_dict_group_deleted_offset161601 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1597, i1 false)
  %generic_dict_group_deleted_offset1602 = zext i16 %generic_dict_group_deleted_offset161601 to i64
  %generic_dict_group_deleted_unwrapped1603 = add i64 %generic_dict_group_start1585, %generic_dict_group_deleted_offset1602
  %generic_dict_group_deleted_slot1604 = and i64 %generic_dict_group_deleted_unwrapped1603, %dict_capacity_mask1577
  %generic_dict_group_captured_deleted1605 = select i1 %generic_dict_group_capture_deleted1600, i64 %generic_dict_group_deleted_slot1604, i64 %generic_dict_group_deleted1582
  br label %bb_generic_dict_candidate_loop366

bb_generic_dict_candidate_loop366:
  %generic_dict_candidate_bits1606 = phi i16 [ %generic_dict_group_match_bits1591, %bb_generic_dict_group_body365 ], [ %generic_dict_candidate_cleared_bits1607, %bb_generic_dict_candidate_next368 ]
  %generic_dict_has_candidate1608 = icmp ne i16 %generic_dict_candidate_bits1606, 0
  br i1 %generic_dict_has_candidate1608, label %bb_generic_dict_candidate_body367, label %bb_generic_dict_group_decision369

bb_generic_dict_candidate_body367:
  %generic_dict_candidate_offset161609 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1606, i1 false)
  %generic_dict_candidate_offset1610 = zext i16 %generic_dict_candidate_offset161609 to i64
  %generic_dict_candidate_unwrapped1611 = add i64 %generic_dict_group_start1585, %generic_dict_candidate_offset1610
  %generic_dict_candidate_slot1612 = and i64 %generic_dict_candidate_unwrapped1611, %dict_capacity_mask1577
  %generic_dict_key_entries_offset_mirror1613 = add i64 %set_grown_capacity1425, 23
  %generic_dict_key_entries_offset1614 = and i64 %generic_dict_key_entries_offset_mirror1613, -8
  %generic_dict_key_entries1615 = getelementptr i8, ptr %heap1430, i64 %generic_dict_key_entries_offset1614
  %generic_dict_key_entry_offset1616 = mul i64 %generic_dict_candidate_slot1612, 4
  %generic_dict_key_slot1617 = getelementptr i8, ptr %generic_dict_key_entries1615, i64 %generic_dict_key_entry_offset1616
  %generic_dict_key1618 = load i32, ptr %generic_dict_key_slot1617, align 4
  %generic_dict_key_equal1619 = icmp eq i32 %generic_dict_key1618, 4
  br i1 %generic_dict_key_equal1619, label %bb_generic_dict_group_match371, label %bb_generic_dict_candidate_next368

bb_generic_dict_candidate_next368:
  %generic_dict_candidate_bits_minus_one1620 = sub i16 %generic_dict_candidate_bits1606, 1
  %generic_dict_candidate_cleared_bits1607 = and i16 %generic_dict_candidate_bits1606, %generic_dict_candidate_bits_minus_one1620
  br label %bb_generic_dict_candidate_loop366

bb_generic_dict_group_decision369:
  %generic_dict_group_has_empty1621 = icmp ne i16 %generic_dict_group_empty_bits1593, 0
  br i1 %generic_dict_group_has_empty1621, label %bb_generic_dict_group_empty370, label %bb_generic_dict_group_next372

bb_generic_dict_group_empty370:
  %generic_dict_group_empty_offset161622 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1593, i1 false)
  %generic_dict_group_empty_offset1623 = zext i16 %generic_dict_group_empty_offset161622 to i64
  %generic_dict_group_empty_unwrapped1624 = add i64 %generic_dict_group_start1585, %generic_dict_group_empty_offset1623
  %generic_dict_group_empty_slot1625 = and i64 %generic_dict_group_empty_unwrapped1624, %dict_capacity_mask1577
  %generic_dict_group_use_empty1626 = icmp eq i64 %generic_dict_group_captured_deleted1605, %set_grown_capacity1425
  %generic_dict_group_insertion_slot1627 = select i1 %generic_dict_group_use_empty1626, i64 %generic_dict_group_empty_slot1625, i64 %generic_dict_group_captured_deleted1605
  br label %bb_generic_dict_group_done374

bb_generic_dict_group_match371:
  br label %bb_generic_dict_group_done374

bb_generic_dict_group_next372:
  %generic_dict_group_next_probe1579 = add i64 %generic_dict_group_probe1581, 16
  %generic_dict_group_next_deleted1580 = add i64 %generic_dict_group_captured_deleted1605, 0
  br label %bb_generic_dict_group_find364

bb_generic_dict_group_miss373:
  %generic_dict_group_miss_no_deleted1628 = icmp eq i64 %generic_dict_group_deleted1582, %set_grown_capacity1425
  %generic_dict_group_miss_slot1629 = select i1 %generic_dict_group_miss_no_deleted1628, i64 0, i64 %generic_dict_group_deleted1582
  br label %bb_generic_dict_group_done374

bb_generic_dict_group_done374:
  %generic_dict_find_found1630 = phi i1 [ false, %bb_generic_dict_group_empty370 ], [ true, %bb_generic_dict_group_match371 ], [ false, %bb_generic_dict_group_miss373 ]
  %generic_dict_find_slot_result1631 = phi i64 [ %generic_dict_group_insertion_slot1627, %bb_generic_dict_group_empty370 ], [ %generic_dict_candidate_slot1612, %bb_generic_dict_group_match371 ], [ %generic_dict_group_miss_slot1629, %bb_generic_dict_group_miss373 ]
  br label %bb_generic_dict_insert_first_done361

bb_generic_dict_insert_first_done361:
  %generic_dict_insert_first_found1632 = phi i1 [ true, %bb_generic_dict_insert_first_match358 ], [ false, %bb_generic_dict_insert_first_vacant360 ], [ %generic_dict_find_found1630, %bb_generic_dict_group_done374 ], [ false, %bb_generic_dict_insert_no_capacity363 ]
  %generic_dict_insert_first_slot_result1633 = phi i64 [ %dict_start_slot1555, %bb_generic_dict_insert_first_match358 ], [ %dict_start_slot1555, %bb_generic_dict_insert_first_vacant360 ], [ %generic_dict_find_slot_result1631, %bb_generic_dict_group_done374 ], [ 0, %bb_generic_dict_insert_no_capacity363 ]
  %set_key_entries_offset_mirror1634 = add i64 %set_grown_capacity1425, 23
  %set_key_entries_offset1635 = and i64 %set_key_entries_offset_mirror1634, -8
  %set_key_entries1636 = getelementptr i8, ptr %heap1430, i64 %set_key_entries_offset1635
  %set_key_entry_offset1637 = mul i64 %generic_dict_insert_first_slot_result1633, 4
  %set_key_slot1638 = getelementptr i8, ptr %set_key_entries1636, i64 %set_key_entry_offset1637
  store i32 4, ptr %set_key_slot1638, align 4
  %generic_dict_control_slot1639 = getelementptr i8, ptr %heap1430, i64 %generic_dict_insert_first_slot_result1633
  store i8 %dict_h2_byte1553, ptr %generic_dict_control_slot1639, align 1
  %generic_dict_control_mirrored1640 = icmp ult i64 %generic_dict_insert_first_slot_result1633, 16
  br i1 %generic_dict_control_mirrored1640, label %bb_generic_dict_control_mirror375, label %bb_generic_dict_control_done376

bb_generic_dict_control_mirror375:
  %generic_dict_control_mirror_index1641 = add i64 %set_grown_capacity1425, %generic_dict_insert_first_slot_result1633
  %generic_dict_control_mirror_slot1642 = getelementptr i8, ptr %heap1430, i64 %generic_dict_control_mirror_index1641
  store i8 %dict_h2_byte1553, ptr %generic_dict_control_mirror_slot1642, align 1
  br label %bb_generic_dict_control_done376

bb_generic_dict_control_done376:
  br label %bb_set_insert_done325

bb_set_insert_done325:
  %set_pointer1643 = phi ptr [ %mutable_ptr1320, %bb_set_insert_duplicate321 ], [ %mutable_ptr1320, %bb_generic_dict_control_done327 ], [ %heap1430, %bb_generic_dict_control_done376 ]
  %set_length1644 = phi i64 [ %mutable_len1321, %bb_set_insert_duplicate321 ], [ %set_insert_length1412, %bb_generic_dict_control_done327 ], [ %set_insert_length1412, %bb_generic_dict_control_done376 ]
  %set_capacity1645 = phi i64 [ %mutable_capacity1322, %bb_set_insert_duplicate321 ], [ %mutable_capacity1322, %bb_generic_dict_control_done327 ], [ %set_grown_capacity1425, %bb_generic_dict_control_done376 ]
  %set_inserted1646 = phi i1 [ false, %bb_set_insert_duplicate321 ], [ true, %bb_generic_dict_control_done327 ], [ true, %bb_generic_dict_control_done376 ]
  store ptr %set_pointer1643, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length1644, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity1645, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr1647 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len1648 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity1649 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key1650 = sext i32 5 to i64
  %hash_high1652 = lshr i64 %hash_key1650, 32
  %hash_fold1651 = xor i64 %hash_key1650, %hash_high1652
  %hash1653 = mul i64 %hash_fold1651, -7046029254386353131
  %dict_h2_shifted1654 = lshr i64 %hash1653, 57
  %dict_h2_raw1655 = and i64 %dict_h2_shifted1654, 127
  %dict_h2_zero1656 = icmp eq i64 %dict_h2_raw1655, 0
  %dict_h21657 = select i1 %dict_h2_zero1656, i64 1, i64 %dict_h2_raw1655
  %dict_h2_byte1658 = trunc i64 %dict_h21657 to i8
  %dict_capacity_mask1659 = sub i64 %mutable_capacity1649, 1
  %dict_start_slot1660 = and i64 %hash1653, %dict_capacity_mask1659
  %generic_dict_insert_has_capacity1661 = icmp ugt i64 %mutable_capacity1649, 0
  br i1 %generic_dict_insert_has_capacity1661, label %bb_generic_dict_insert_first383, label %bb_generic_dict_insert_no_capacity384

bb_generic_dict_insert_no_capacity384:
  br label %bb_generic_dict_insert_first_done382

bb_generic_dict_insert_first383:
  %generic_dict_control_slot1662 = getelementptr i8, ptr %mutable_ptr1647, i64 %dict_start_slot1660
  %generic_dict_control1663 = load i8, ptr %generic_dict_control_slot1662, align 1
  %generic_dict_insert_first_empty1664 = icmp eq i8 %generic_dict_control1663, 0
  br i1 %generic_dict_insert_first_empty1664, label %bb_generic_dict_insert_first_vacant381, label %bb_generic_dict_insert_first_occupied377

bb_generic_dict_insert_first_occupied377:
  %generic_dict_insert_first_h21665 = icmp eq i8 %generic_dict_control1663, %dict_h2_byte1658
  br i1 %generic_dict_insert_first_h21665, label %bb_generic_dict_insert_first_compare378, label %bb_generic_dict_insert_first_fallback380

bb_generic_dict_insert_first_compare378:
  %generic_dict_insert_first_key_entries_offset_mirror1666 = add i64 %mutable_capacity1649, 23
  %generic_dict_insert_first_key_entries_offset1667 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1666, -8
  %generic_dict_insert_first_key_entries1668 = getelementptr i8, ptr %mutable_ptr1647, i64 %generic_dict_insert_first_key_entries_offset1667
  %generic_dict_insert_first_key_entry_offset1669 = mul i64 %dict_start_slot1660, 4
  %generic_dict_insert_first_key_slot1670 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1668, i64 %generic_dict_insert_first_key_entry_offset1669
  %generic_dict_insert_first_key1671 = load i32, ptr %generic_dict_insert_first_key_slot1670, align 4
  %generic_dict_key_equal1672 = icmp eq i32 %generic_dict_insert_first_key1671, 5
  br i1 %generic_dict_key_equal1672, label %bb_generic_dict_insert_first_match379, label %bb_generic_dict_insert_first_fallback380

bb_generic_dict_insert_first_match379:
  br label %bb_generic_dict_insert_first_done382

bb_generic_dict_insert_first_vacant381:
  br label %bb_generic_dict_insert_first_done382

bb_generic_dict_insert_first_fallback380:
  %hash_key1673 = sext i32 5 to i64
  %hash_high1675 = lshr i64 %hash_key1673, 32
  %hash_fold1674 = xor i64 %hash_key1673, %hash_high1675
  %hash1676 = mul i64 %hash_fold1674, -7046029254386353131
  %dict_h2_shifted1677 = lshr i64 %hash1676, 57
  %dict_h2_raw1678 = and i64 %dict_h2_shifted1677, 127
  %dict_h2_zero1679 = icmp eq i64 %dict_h2_raw1678, 0
  %dict_h21680 = select i1 %dict_h2_zero1679, i64 1, i64 %dict_h2_raw1678
  %dict_h2_byte1681 = trunc i64 %dict_h21680 to i8
  %dict_capacity_mask1682 = sub i64 %mutable_capacity1649, 1
  %dict_start_slot1683 = and i64 %hash1676, %dict_capacity_mask1682
  br label %bb_generic_dict_group_find385

bb_generic_dict_group_find385:
  %generic_dict_group_probe1686 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback380 ], [ %generic_dict_group_next_probe1684, %bb_generic_dict_group_next393 ]
  %generic_dict_group_deleted1687 = phi i64 [ %mutable_capacity1649, %bb_generic_dict_insert_first_fallback380 ], [ %generic_dict_group_next_deleted1685, %bb_generic_dict_group_next393 ]
  %generic_dict_group_active1688 = icmp ult i64 %generic_dict_group_probe1686, %mutable_capacity1649
  br i1 %generic_dict_group_active1688, label %bb_generic_dict_group_body386, label %bb_generic_dict_group_miss394

bb_generic_dict_group_body386:
  %generic_dict_group_unwrapped1689 = add i64 %dict_start_slot1683, %generic_dict_group_probe1686
  %generic_dict_group_start1690 = and i64 %generic_dict_group_unwrapped1689, %dict_capacity_mask1682
  %generic_dict_group_pointer1691 = getelementptr i8, ptr %mutable_ptr1647, i64 %generic_dict_group_start1690
  %generic_dict_group_controls1692 = load <16 x i8>, ptr %generic_dict_group_pointer1691, align 1
  %generic_dict_group_h2_seed1693 = insertelement <16 x i8> poison, i8 %dict_h2_byte1681, i64 0
  %generic_dict_group_h2_vector1694 = shufflevector <16 x i8> %generic_dict_group_h2_seed1693, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1695 = icmp eq <16 x i8> %generic_dict_group_controls1692, %generic_dict_group_h2_vector1694
  %generic_dict_group_match_bits1696 = bitcast <16 x i1> %generic_dict_group_matches_vector1695 to i16
  %generic_dict_group_empty_vector1697 = icmp eq <16 x i8> %generic_dict_group_controls1692, zeroinitializer
  %generic_dict_group_empty_bits1698 = bitcast <16 x i1> %generic_dict_group_empty_vector1697 to i16
  %generic_dict_group_deleted_seed1699 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1700 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1699, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1701 = icmp eq <16 x i8> %generic_dict_group_controls1692, %generic_dict_group_deleted_vector1700
  %generic_dict_group_deleted_bits1702 = bitcast <16 x i1> %generic_dict_group_deleted_matches1701 to i16
  %generic_dict_group_has_deleted1703 = icmp ne i16 %generic_dict_group_deleted_bits1702, 0
  %generic_dict_group_no_previous_deleted1704 = icmp eq i64 %generic_dict_group_deleted1687, %mutable_capacity1649
  %generic_dict_group_capture_deleted1705 = and i1 %generic_dict_group_has_deleted1703, %generic_dict_group_no_previous_deleted1704
  %generic_dict_group_deleted_offset161706 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1702, i1 false)
  %generic_dict_group_deleted_offset1707 = zext i16 %generic_dict_group_deleted_offset161706 to i64
  %generic_dict_group_deleted_unwrapped1708 = add i64 %generic_dict_group_start1690, %generic_dict_group_deleted_offset1707
  %generic_dict_group_deleted_slot1709 = and i64 %generic_dict_group_deleted_unwrapped1708, %dict_capacity_mask1682
  %generic_dict_group_captured_deleted1710 = select i1 %generic_dict_group_capture_deleted1705, i64 %generic_dict_group_deleted_slot1709, i64 %generic_dict_group_deleted1687
  br label %bb_generic_dict_candidate_loop387

bb_generic_dict_candidate_loop387:
  %generic_dict_candidate_bits1711 = phi i16 [ %generic_dict_group_match_bits1696, %bb_generic_dict_group_body386 ], [ %generic_dict_candidate_cleared_bits1712, %bb_generic_dict_candidate_next389 ]
  %generic_dict_has_candidate1713 = icmp ne i16 %generic_dict_candidate_bits1711, 0
  br i1 %generic_dict_has_candidate1713, label %bb_generic_dict_candidate_body388, label %bb_generic_dict_group_decision390

bb_generic_dict_candidate_body388:
  %generic_dict_candidate_offset161714 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1711, i1 false)
  %generic_dict_candidate_offset1715 = zext i16 %generic_dict_candidate_offset161714 to i64
  %generic_dict_candidate_unwrapped1716 = add i64 %generic_dict_group_start1690, %generic_dict_candidate_offset1715
  %generic_dict_candidate_slot1717 = and i64 %generic_dict_candidate_unwrapped1716, %dict_capacity_mask1682
  %generic_dict_key_entries_offset_mirror1718 = add i64 %mutable_capacity1649, 23
  %generic_dict_key_entries_offset1719 = and i64 %generic_dict_key_entries_offset_mirror1718, -8
  %generic_dict_key_entries1720 = getelementptr i8, ptr %mutable_ptr1647, i64 %generic_dict_key_entries_offset1719
  %generic_dict_key_entry_offset1721 = mul i64 %generic_dict_candidate_slot1717, 4
  %generic_dict_key_slot1722 = getelementptr i8, ptr %generic_dict_key_entries1720, i64 %generic_dict_key_entry_offset1721
  %generic_dict_key1723 = load i32, ptr %generic_dict_key_slot1722, align 4
  %generic_dict_key_equal1724 = icmp eq i32 %generic_dict_key1723, 5
  br i1 %generic_dict_key_equal1724, label %bb_generic_dict_group_match392, label %bb_generic_dict_candidate_next389

bb_generic_dict_candidate_next389:
  %generic_dict_candidate_bits_minus_one1725 = sub i16 %generic_dict_candidate_bits1711, 1
  %generic_dict_candidate_cleared_bits1712 = and i16 %generic_dict_candidate_bits1711, %generic_dict_candidate_bits_minus_one1725
  br label %bb_generic_dict_candidate_loop387

bb_generic_dict_group_decision390:
  %generic_dict_group_has_empty1726 = icmp ne i16 %generic_dict_group_empty_bits1698, 0
  br i1 %generic_dict_group_has_empty1726, label %bb_generic_dict_group_empty391, label %bb_generic_dict_group_next393

bb_generic_dict_group_empty391:
  %generic_dict_group_empty_offset161727 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1698, i1 false)
  %generic_dict_group_empty_offset1728 = zext i16 %generic_dict_group_empty_offset161727 to i64
  %generic_dict_group_empty_unwrapped1729 = add i64 %generic_dict_group_start1690, %generic_dict_group_empty_offset1728
  %generic_dict_group_empty_slot1730 = and i64 %generic_dict_group_empty_unwrapped1729, %dict_capacity_mask1682
  %generic_dict_group_use_empty1731 = icmp eq i64 %generic_dict_group_captured_deleted1710, %mutable_capacity1649
  %generic_dict_group_insertion_slot1732 = select i1 %generic_dict_group_use_empty1731, i64 %generic_dict_group_empty_slot1730, i64 %generic_dict_group_captured_deleted1710
  br label %bb_generic_dict_group_done395

bb_generic_dict_group_match392:
  br label %bb_generic_dict_group_done395

bb_generic_dict_group_next393:
  %generic_dict_group_next_probe1684 = add i64 %generic_dict_group_probe1686, 16
  %generic_dict_group_next_deleted1685 = add i64 %generic_dict_group_captured_deleted1710, 0
  br label %bb_generic_dict_group_find385

bb_generic_dict_group_miss394:
  %generic_dict_group_miss_no_deleted1733 = icmp eq i64 %generic_dict_group_deleted1687, %mutable_capacity1649
  %generic_dict_group_miss_slot1734 = select i1 %generic_dict_group_miss_no_deleted1733, i64 0, i64 %generic_dict_group_deleted1687
  br label %bb_generic_dict_group_done395

bb_generic_dict_group_done395:
  %generic_dict_find_found1735 = phi i1 [ false, %bb_generic_dict_group_empty391 ], [ true, %bb_generic_dict_group_match392 ], [ false, %bb_generic_dict_group_miss394 ]
  %generic_dict_find_slot_result1736 = phi i64 [ %generic_dict_group_insertion_slot1732, %bb_generic_dict_group_empty391 ], [ %generic_dict_candidate_slot1717, %bb_generic_dict_group_match392 ], [ %generic_dict_group_miss_slot1734, %bb_generic_dict_group_miss394 ]
  br label %bb_generic_dict_insert_first_done382

bb_generic_dict_insert_first_done382:
  %generic_dict_insert_first_found1737 = phi i1 [ true, %bb_generic_dict_insert_first_match379 ], [ false, %bb_generic_dict_insert_first_vacant381 ], [ %generic_dict_find_found1735, %bb_generic_dict_group_done395 ], [ false, %bb_generic_dict_insert_no_capacity384 ]
  %generic_dict_insert_first_slot_result1738 = phi i64 [ %dict_start_slot1660, %bb_generic_dict_insert_first_match379 ], [ %dict_start_slot1660, %bb_generic_dict_insert_first_vacant381 ], [ %generic_dict_find_slot_result1736, %bb_generic_dict_group_done395 ], [ 0, %bb_generic_dict_insert_no_capacity384 ]
  br i1 %generic_dict_insert_first_found1737, label %bb_set_insert_duplicate396, label %bb_set_insert_new397

bb_set_insert_duplicate396:
  br label %bb_set_insert_done400

bb_set_insert_new397:
  %set_insert_length1739 = add i64 %mutable_len1648, 1
  %set_insert_load_num1740 = mul i64 %set_insert_length1739, 8
  %set_insert_load_den1741 = mul i64 %mutable_capacity1649, 7
  %set_insert_should_grow1742 = icmp ugt i64 %set_insert_load_num1740, %set_insert_load_den1741
  br i1 %set_insert_should_grow1742, label %bb_set_insert_grow399, label %bb_set_insert_current398

bb_set_insert_current398:
  %set_key_entries_offset_mirror1743 = add i64 %mutable_capacity1649, 23
  %set_key_entries_offset1744 = and i64 %set_key_entries_offset_mirror1743, -8
  %set_key_entries1745 = getelementptr i8, ptr %mutable_ptr1647, i64 %set_key_entries_offset1744
  %set_key_entry_offset1746 = mul i64 %generic_dict_insert_first_slot_result1738, 4
  %set_key_slot1747 = getelementptr i8, ptr %set_key_entries1745, i64 %set_key_entry_offset1746
  store i32 5, ptr %set_key_slot1747, align 4
  %generic_dict_control_slot1748 = getelementptr i8, ptr %mutable_ptr1647, i64 %generic_dict_insert_first_slot_result1738
  store i8 %dict_h2_byte1658, ptr %generic_dict_control_slot1748, align 1
  %generic_dict_control_mirrored1749 = icmp ult i64 %generic_dict_insert_first_slot_result1738, 16
  br i1 %generic_dict_control_mirrored1749, label %bb_generic_dict_control_mirror401, label %bb_generic_dict_control_done402

bb_generic_dict_control_mirror401:
  %generic_dict_control_mirror_index1750 = add i64 %mutable_capacity1649, %generic_dict_insert_first_slot_result1738
  %generic_dict_control_mirror_slot1751 = getelementptr i8, ptr %mutable_ptr1647, i64 %generic_dict_control_mirror_index1750
  store i8 %dict_h2_byte1658, ptr %generic_dict_control_mirror_slot1751, align 1
  br label %bb_generic_dict_control_done402

bb_generic_dict_control_done402:
  br label %bb_set_insert_done400

bb_set_insert_grow399:
  %set_grown_capacity1752 = mul i64 %mutable_capacity1649, 2
  %generic_dict_entries_offset_mirror1753 = add i64 %set_grown_capacity1752, 23
  %generic_dict_entries_offset1754 = and i64 %generic_dict_entries_offset_mirror1753, -8
  %generic_dict_entries_bytes1755 = mul i64 %set_grown_capacity1752, 4
  %generic_dict_bytes1756 = add i64 %generic_dict_entries_offset1754, %generic_dict_entries_bytes1755
  %heap1757 = call ptr @sollang_alloc(i64 %generic_dict_bytes1756)
  %heap_ok1758 = icmp ne ptr %heap1757, null
  br i1 %heap_ok1758, label %bb_alloc_ok403, label %bb_alloc_fail404

bb_alloc_fail404:
  %trap_stderr1759 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr1759, ptr @.slg.str.module.x.6, i32 25, ptr %trap_written1760, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok403:
  %generic_dict_control_bytes1761 = add i64 %set_grown_capacity1752, 16
  call void @llvm.memset.p0.i64(ptr %heap1757, i8 0, i64 %generic_dict_control_bytes1761, i1 false)
  br label %bb_set_rehash405

bb_set_rehash405:
  %set_rehash_index1763 = phi i64 [ 0, %bb_alloc_ok403 ], [ %set_rehash_next_index1762, %bb_set_rehash_next408 ]
  %set_rehash_active1764 = icmp ult i64 %set_rehash_index1763, %mutable_capacity1649
  br i1 %set_rehash_active1764, label %bb_set_rehash_body406, label %bb_set_rehash_done409

bb_set_rehash_body406:
  %generic_dict_control_slot1765 = getelementptr i8, ptr %mutable_ptr1647, i64 %set_rehash_index1763
  %generic_dict_control1766 = load i8, ptr %generic_dict_control_slot1765, align 1
  %set_rehash_occupied1767 = icmp sgt i8 %generic_dict_control1766, 0
  br i1 %set_rehash_occupied1767, label %bb_set_rehash_move407, label %bb_set_rehash_next408

bb_set_rehash_move407:
  %set_rehash_key_entries_offset_mirror1768 = add i64 %mutable_capacity1649, 23
  %set_rehash_key_entries_offset1769 = and i64 %set_rehash_key_entries_offset_mirror1768, -8
  %set_rehash_key_entries1770 = getelementptr i8, ptr %mutable_ptr1647, i64 %set_rehash_key_entries_offset1769
  %set_rehash_key_entry_offset1771 = mul i64 %set_rehash_index1763, 4
  %set_rehash_key_slot1772 = getelementptr i8, ptr %set_rehash_key_entries1770, i64 %set_rehash_key_entry_offset1771
  %set_rehash_key1773 = load i32, ptr %set_rehash_key_slot1772, align 4
  %hash_key1774 = sext i32 %set_rehash_key1773 to i64
  %hash_high1776 = lshr i64 %hash_key1774, 32
  %hash_fold1775 = xor i64 %hash_key1774, %hash_high1776
  %hash1777 = mul i64 %hash_fold1775, -7046029254386353131
  %dict_h2_shifted1778 = lshr i64 %hash1777, 57
  %dict_h2_raw1779 = and i64 %dict_h2_shifted1778, 127
  %dict_h2_zero1780 = icmp eq i64 %dict_h2_raw1779, 0
  %dict_h21781 = select i1 %dict_h2_zero1780, i64 1, i64 %dict_h2_raw1779
  %dict_h2_byte1782 = trunc i64 %dict_h21781 to i8
  %dict_capacity_mask1783 = sub i64 %set_grown_capacity1752, 1
  %dict_start_slot1784 = and i64 %hash1777, %dict_capacity_mask1783
  %generic_dict_insert_has_capacity1785 = icmp ugt i64 %set_grown_capacity1752, 0
  br i1 %generic_dict_insert_has_capacity1785, label %bb_generic_dict_insert_first416, label %bb_generic_dict_insert_no_capacity417

bb_generic_dict_insert_no_capacity417:
  br label %bb_generic_dict_insert_first_done415

bb_generic_dict_insert_first416:
  %generic_dict_control_slot1786 = getelementptr i8, ptr %heap1757, i64 %dict_start_slot1784
  %generic_dict_control1787 = load i8, ptr %generic_dict_control_slot1786, align 1
  %generic_dict_insert_first_empty1788 = icmp eq i8 %generic_dict_control1787, 0
  br i1 %generic_dict_insert_first_empty1788, label %bb_generic_dict_insert_first_vacant414, label %bb_generic_dict_insert_first_occupied410

bb_generic_dict_insert_first_occupied410:
  %generic_dict_insert_first_h21789 = icmp eq i8 %generic_dict_control1787, %dict_h2_byte1782
  br i1 %generic_dict_insert_first_h21789, label %bb_generic_dict_insert_first_compare411, label %bb_generic_dict_insert_first_fallback413

bb_generic_dict_insert_first_compare411:
  %generic_dict_insert_first_key_entries_offset_mirror1790 = add i64 %set_grown_capacity1752, 23
  %generic_dict_insert_first_key_entries_offset1791 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1790, -8
  %generic_dict_insert_first_key_entries1792 = getelementptr i8, ptr %heap1757, i64 %generic_dict_insert_first_key_entries_offset1791
  %generic_dict_insert_first_key_entry_offset1793 = mul i64 %dict_start_slot1784, 4
  %generic_dict_insert_first_key_slot1794 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1792, i64 %generic_dict_insert_first_key_entry_offset1793
  %generic_dict_insert_first_key1795 = load i32, ptr %generic_dict_insert_first_key_slot1794, align 4
  %generic_dict_key_equal1796 = icmp eq i32 %generic_dict_insert_first_key1795, %set_rehash_key1773
  br i1 %generic_dict_key_equal1796, label %bb_generic_dict_insert_first_match412, label %bb_generic_dict_insert_first_fallback413

bb_generic_dict_insert_first_match412:
  br label %bb_generic_dict_insert_first_done415

bb_generic_dict_insert_first_vacant414:
  br label %bb_generic_dict_insert_first_done415

bb_generic_dict_insert_first_fallback413:
  %hash_key1797 = sext i32 %set_rehash_key1773 to i64
  %hash_high1799 = lshr i64 %hash_key1797, 32
  %hash_fold1798 = xor i64 %hash_key1797, %hash_high1799
  %hash1800 = mul i64 %hash_fold1798, -7046029254386353131
  %dict_h2_shifted1801 = lshr i64 %hash1800, 57
  %dict_h2_raw1802 = and i64 %dict_h2_shifted1801, 127
  %dict_h2_zero1803 = icmp eq i64 %dict_h2_raw1802, 0
  %dict_h21804 = select i1 %dict_h2_zero1803, i64 1, i64 %dict_h2_raw1802
  %dict_h2_byte1805 = trunc i64 %dict_h21804 to i8
  %dict_capacity_mask1806 = sub i64 %set_grown_capacity1752, 1
  %dict_start_slot1807 = and i64 %hash1800, %dict_capacity_mask1806
  br label %bb_generic_dict_group_find418

bb_generic_dict_group_find418:
  %generic_dict_group_probe1810 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback413 ], [ %generic_dict_group_next_probe1808, %bb_generic_dict_group_next426 ]
  %generic_dict_group_deleted1811 = phi i64 [ %set_grown_capacity1752, %bb_generic_dict_insert_first_fallback413 ], [ %generic_dict_group_next_deleted1809, %bb_generic_dict_group_next426 ]
  %generic_dict_group_active1812 = icmp ult i64 %generic_dict_group_probe1810, %set_grown_capacity1752
  br i1 %generic_dict_group_active1812, label %bb_generic_dict_group_body419, label %bb_generic_dict_group_miss427

bb_generic_dict_group_body419:
  %generic_dict_group_unwrapped1813 = add i64 %dict_start_slot1807, %generic_dict_group_probe1810
  %generic_dict_group_start1814 = and i64 %generic_dict_group_unwrapped1813, %dict_capacity_mask1806
  %generic_dict_group_pointer1815 = getelementptr i8, ptr %heap1757, i64 %generic_dict_group_start1814
  %generic_dict_group_controls1816 = load <16 x i8>, ptr %generic_dict_group_pointer1815, align 1
  %generic_dict_group_h2_seed1817 = insertelement <16 x i8> poison, i8 %dict_h2_byte1805, i64 0
  %generic_dict_group_h2_vector1818 = shufflevector <16 x i8> %generic_dict_group_h2_seed1817, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1819 = icmp eq <16 x i8> %generic_dict_group_controls1816, %generic_dict_group_h2_vector1818
  %generic_dict_group_match_bits1820 = bitcast <16 x i1> %generic_dict_group_matches_vector1819 to i16
  %generic_dict_group_empty_vector1821 = icmp eq <16 x i8> %generic_dict_group_controls1816, zeroinitializer
  %generic_dict_group_empty_bits1822 = bitcast <16 x i1> %generic_dict_group_empty_vector1821 to i16
  %generic_dict_group_deleted_seed1823 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1824 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1823, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1825 = icmp eq <16 x i8> %generic_dict_group_controls1816, %generic_dict_group_deleted_vector1824
  %generic_dict_group_deleted_bits1826 = bitcast <16 x i1> %generic_dict_group_deleted_matches1825 to i16
  %generic_dict_group_has_deleted1827 = icmp ne i16 %generic_dict_group_deleted_bits1826, 0
  %generic_dict_group_no_previous_deleted1828 = icmp eq i64 %generic_dict_group_deleted1811, %set_grown_capacity1752
  %generic_dict_group_capture_deleted1829 = and i1 %generic_dict_group_has_deleted1827, %generic_dict_group_no_previous_deleted1828
  %generic_dict_group_deleted_offset161830 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1826, i1 false)
  %generic_dict_group_deleted_offset1831 = zext i16 %generic_dict_group_deleted_offset161830 to i64
  %generic_dict_group_deleted_unwrapped1832 = add i64 %generic_dict_group_start1814, %generic_dict_group_deleted_offset1831
  %generic_dict_group_deleted_slot1833 = and i64 %generic_dict_group_deleted_unwrapped1832, %dict_capacity_mask1806
  %generic_dict_group_captured_deleted1834 = select i1 %generic_dict_group_capture_deleted1829, i64 %generic_dict_group_deleted_slot1833, i64 %generic_dict_group_deleted1811
  br label %bb_generic_dict_candidate_loop420

bb_generic_dict_candidate_loop420:
  %generic_dict_candidate_bits1835 = phi i16 [ %generic_dict_group_match_bits1820, %bb_generic_dict_group_body419 ], [ %generic_dict_candidate_cleared_bits1836, %bb_generic_dict_candidate_next422 ]
  %generic_dict_has_candidate1837 = icmp ne i16 %generic_dict_candidate_bits1835, 0
  br i1 %generic_dict_has_candidate1837, label %bb_generic_dict_candidate_body421, label %bb_generic_dict_group_decision423

bb_generic_dict_candidate_body421:
  %generic_dict_candidate_offset161838 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1835, i1 false)
  %generic_dict_candidate_offset1839 = zext i16 %generic_dict_candidate_offset161838 to i64
  %generic_dict_candidate_unwrapped1840 = add i64 %generic_dict_group_start1814, %generic_dict_candidate_offset1839
  %generic_dict_candidate_slot1841 = and i64 %generic_dict_candidate_unwrapped1840, %dict_capacity_mask1806
  %generic_dict_key_entries_offset_mirror1842 = add i64 %set_grown_capacity1752, 23
  %generic_dict_key_entries_offset1843 = and i64 %generic_dict_key_entries_offset_mirror1842, -8
  %generic_dict_key_entries1844 = getelementptr i8, ptr %heap1757, i64 %generic_dict_key_entries_offset1843
  %generic_dict_key_entry_offset1845 = mul i64 %generic_dict_candidate_slot1841, 4
  %generic_dict_key_slot1846 = getelementptr i8, ptr %generic_dict_key_entries1844, i64 %generic_dict_key_entry_offset1845
  %generic_dict_key1847 = load i32, ptr %generic_dict_key_slot1846, align 4
  %generic_dict_key_equal1848 = icmp eq i32 %generic_dict_key1847, %set_rehash_key1773
  br i1 %generic_dict_key_equal1848, label %bb_generic_dict_group_match425, label %bb_generic_dict_candidate_next422

bb_generic_dict_candidate_next422:
  %generic_dict_candidate_bits_minus_one1849 = sub i16 %generic_dict_candidate_bits1835, 1
  %generic_dict_candidate_cleared_bits1836 = and i16 %generic_dict_candidate_bits1835, %generic_dict_candidate_bits_minus_one1849
  br label %bb_generic_dict_candidate_loop420

bb_generic_dict_group_decision423:
  %generic_dict_group_has_empty1850 = icmp ne i16 %generic_dict_group_empty_bits1822, 0
  br i1 %generic_dict_group_has_empty1850, label %bb_generic_dict_group_empty424, label %bb_generic_dict_group_next426

bb_generic_dict_group_empty424:
  %generic_dict_group_empty_offset161851 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1822, i1 false)
  %generic_dict_group_empty_offset1852 = zext i16 %generic_dict_group_empty_offset161851 to i64
  %generic_dict_group_empty_unwrapped1853 = add i64 %generic_dict_group_start1814, %generic_dict_group_empty_offset1852
  %generic_dict_group_empty_slot1854 = and i64 %generic_dict_group_empty_unwrapped1853, %dict_capacity_mask1806
  %generic_dict_group_use_empty1855 = icmp eq i64 %generic_dict_group_captured_deleted1834, %set_grown_capacity1752
  %generic_dict_group_insertion_slot1856 = select i1 %generic_dict_group_use_empty1855, i64 %generic_dict_group_empty_slot1854, i64 %generic_dict_group_captured_deleted1834
  br label %bb_generic_dict_group_done428

bb_generic_dict_group_match425:
  br label %bb_generic_dict_group_done428

bb_generic_dict_group_next426:
  %generic_dict_group_next_probe1808 = add i64 %generic_dict_group_probe1810, 16
  %generic_dict_group_next_deleted1809 = add i64 %generic_dict_group_captured_deleted1834, 0
  br label %bb_generic_dict_group_find418

bb_generic_dict_group_miss427:
  %generic_dict_group_miss_no_deleted1857 = icmp eq i64 %generic_dict_group_deleted1811, %set_grown_capacity1752
  %generic_dict_group_miss_slot1858 = select i1 %generic_dict_group_miss_no_deleted1857, i64 0, i64 %generic_dict_group_deleted1811
  br label %bb_generic_dict_group_done428

bb_generic_dict_group_done428:
  %generic_dict_find_found1859 = phi i1 [ false, %bb_generic_dict_group_empty424 ], [ true, %bb_generic_dict_group_match425 ], [ false, %bb_generic_dict_group_miss427 ]
  %generic_dict_find_slot_result1860 = phi i64 [ %generic_dict_group_insertion_slot1856, %bb_generic_dict_group_empty424 ], [ %generic_dict_candidate_slot1841, %bb_generic_dict_group_match425 ], [ %generic_dict_group_miss_slot1858, %bb_generic_dict_group_miss427 ]
  br label %bb_generic_dict_insert_first_done415

bb_generic_dict_insert_first_done415:
  %generic_dict_insert_first_found1861 = phi i1 [ true, %bb_generic_dict_insert_first_match412 ], [ false, %bb_generic_dict_insert_first_vacant414 ], [ %generic_dict_find_found1859, %bb_generic_dict_group_done428 ], [ false, %bb_generic_dict_insert_no_capacity417 ]
  %generic_dict_insert_first_slot_result1862 = phi i64 [ %dict_start_slot1784, %bb_generic_dict_insert_first_match412 ], [ %dict_start_slot1784, %bb_generic_dict_insert_first_vacant414 ], [ %generic_dict_find_slot_result1860, %bb_generic_dict_group_done428 ], [ 0, %bb_generic_dict_insert_no_capacity417 ]
  %set_key_entries_offset_mirror1863 = add i64 %set_grown_capacity1752, 23
  %set_key_entries_offset1864 = and i64 %set_key_entries_offset_mirror1863, -8
  %set_key_entries1865 = getelementptr i8, ptr %heap1757, i64 %set_key_entries_offset1864
  %set_key_entry_offset1866 = mul i64 %generic_dict_insert_first_slot_result1862, 4
  %set_key_slot1867 = getelementptr i8, ptr %set_key_entries1865, i64 %set_key_entry_offset1866
  store i32 %set_rehash_key1773, ptr %set_key_slot1867, align 4
  %generic_dict_control_slot1868 = getelementptr i8, ptr %heap1757, i64 %generic_dict_insert_first_slot_result1862
  store i8 %dict_h2_byte1782, ptr %generic_dict_control_slot1868, align 1
  %generic_dict_control_mirrored1869 = icmp ult i64 %generic_dict_insert_first_slot_result1862, 16
  br i1 %generic_dict_control_mirrored1869, label %bb_generic_dict_control_mirror429, label %bb_generic_dict_control_done430

bb_generic_dict_control_mirror429:
  %generic_dict_control_mirror_index1870 = add i64 %set_grown_capacity1752, %generic_dict_insert_first_slot_result1862
  %generic_dict_control_mirror_slot1871 = getelementptr i8, ptr %heap1757, i64 %generic_dict_control_mirror_index1870
  store i8 %dict_h2_byte1782, ptr %generic_dict_control_mirror_slot1871, align 1
  br label %bb_generic_dict_control_done430

bb_generic_dict_control_done430:
  br label %bb_set_rehash_next408

bb_set_rehash_next408:
  %set_rehash_next_index1762 = add i64 %set_rehash_index1763, 1
  br label %bb_set_rehash405

bb_set_rehash_done409:
  call void @sollang_free(ptr %mutable_ptr1647)
  %hash_key1872 = sext i32 5 to i64
  %hash_high1874 = lshr i64 %hash_key1872, 32
  %hash_fold1873 = xor i64 %hash_key1872, %hash_high1874
  %hash1875 = mul i64 %hash_fold1873, -7046029254386353131
  %dict_h2_shifted1876 = lshr i64 %hash1875, 57
  %dict_h2_raw1877 = and i64 %dict_h2_shifted1876, 127
  %dict_h2_zero1878 = icmp eq i64 %dict_h2_raw1877, 0
  %dict_h21879 = select i1 %dict_h2_zero1878, i64 1, i64 %dict_h2_raw1877
  %dict_h2_byte1880 = trunc i64 %dict_h21879 to i8
  %dict_capacity_mask1881 = sub i64 %set_grown_capacity1752, 1
  %dict_start_slot1882 = and i64 %hash1875, %dict_capacity_mask1881
  %generic_dict_insert_has_capacity1883 = icmp ugt i64 %set_grown_capacity1752, 0
  br i1 %generic_dict_insert_has_capacity1883, label %bb_generic_dict_insert_first437, label %bb_generic_dict_insert_no_capacity438

bb_generic_dict_insert_no_capacity438:
  br label %bb_generic_dict_insert_first_done436

bb_generic_dict_insert_first437:
  %generic_dict_control_slot1884 = getelementptr i8, ptr %heap1757, i64 %dict_start_slot1882
  %generic_dict_control1885 = load i8, ptr %generic_dict_control_slot1884, align 1
  %generic_dict_insert_first_empty1886 = icmp eq i8 %generic_dict_control1885, 0
  br i1 %generic_dict_insert_first_empty1886, label %bb_generic_dict_insert_first_vacant435, label %bb_generic_dict_insert_first_occupied431

bb_generic_dict_insert_first_occupied431:
  %generic_dict_insert_first_h21887 = icmp eq i8 %generic_dict_control1885, %dict_h2_byte1880
  br i1 %generic_dict_insert_first_h21887, label %bb_generic_dict_insert_first_compare432, label %bb_generic_dict_insert_first_fallback434

bb_generic_dict_insert_first_compare432:
  %generic_dict_insert_first_key_entries_offset_mirror1888 = add i64 %set_grown_capacity1752, 23
  %generic_dict_insert_first_key_entries_offset1889 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1888, -8
  %generic_dict_insert_first_key_entries1890 = getelementptr i8, ptr %heap1757, i64 %generic_dict_insert_first_key_entries_offset1889
  %generic_dict_insert_first_key_entry_offset1891 = mul i64 %dict_start_slot1882, 4
  %generic_dict_insert_first_key_slot1892 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1890, i64 %generic_dict_insert_first_key_entry_offset1891
  %generic_dict_insert_first_key1893 = load i32, ptr %generic_dict_insert_first_key_slot1892, align 4
  %generic_dict_key_equal1894 = icmp eq i32 %generic_dict_insert_first_key1893, 5
  br i1 %generic_dict_key_equal1894, label %bb_generic_dict_insert_first_match433, label %bb_generic_dict_insert_first_fallback434

bb_generic_dict_insert_first_match433:
  br label %bb_generic_dict_insert_first_done436

bb_generic_dict_insert_first_vacant435:
  br label %bb_generic_dict_insert_first_done436

bb_generic_dict_insert_first_fallback434:
  %hash_key1895 = sext i32 5 to i64
  %hash_high1897 = lshr i64 %hash_key1895, 32
  %hash_fold1896 = xor i64 %hash_key1895, %hash_high1897
  %hash1898 = mul i64 %hash_fold1896, -7046029254386353131
  %dict_h2_shifted1899 = lshr i64 %hash1898, 57
  %dict_h2_raw1900 = and i64 %dict_h2_shifted1899, 127
  %dict_h2_zero1901 = icmp eq i64 %dict_h2_raw1900, 0
  %dict_h21902 = select i1 %dict_h2_zero1901, i64 1, i64 %dict_h2_raw1900
  %dict_h2_byte1903 = trunc i64 %dict_h21902 to i8
  %dict_capacity_mask1904 = sub i64 %set_grown_capacity1752, 1
  %dict_start_slot1905 = and i64 %hash1898, %dict_capacity_mask1904
  br label %bb_generic_dict_group_find439

bb_generic_dict_group_find439:
  %generic_dict_group_probe1908 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback434 ], [ %generic_dict_group_next_probe1906, %bb_generic_dict_group_next447 ]
  %generic_dict_group_deleted1909 = phi i64 [ %set_grown_capacity1752, %bb_generic_dict_insert_first_fallback434 ], [ %generic_dict_group_next_deleted1907, %bb_generic_dict_group_next447 ]
  %generic_dict_group_active1910 = icmp ult i64 %generic_dict_group_probe1908, %set_grown_capacity1752
  br i1 %generic_dict_group_active1910, label %bb_generic_dict_group_body440, label %bb_generic_dict_group_miss448

bb_generic_dict_group_body440:
  %generic_dict_group_unwrapped1911 = add i64 %dict_start_slot1905, %generic_dict_group_probe1908
  %generic_dict_group_start1912 = and i64 %generic_dict_group_unwrapped1911, %dict_capacity_mask1904
  %generic_dict_group_pointer1913 = getelementptr i8, ptr %heap1757, i64 %generic_dict_group_start1912
  %generic_dict_group_controls1914 = load <16 x i8>, ptr %generic_dict_group_pointer1913, align 1
  %generic_dict_group_h2_seed1915 = insertelement <16 x i8> poison, i8 %dict_h2_byte1903, i64 0
  %generic_dict_group_h2_vector1916 = shufflevector <16 x i8> %generic_dict_group_h2_seed1915, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector1917 = icmp eq <16 x i8> %generic_dict_group_controls1914, %generic_dict_group_h2_vector1916
  %generic_dict_group_match_bits1918 = bitcast <16 x i1> %generic_dict_group_matches_vector1917 to i16
  %generic_dict_group_empty_vector1919 = icmp eq <16 x i8> %generic_dict_group_controls1914, zeroinitializer
  %generic_dict_group_empty_bits1920 = bitcast <16 x i1> %generic_dict_group_empty_vector1919 to i16
  %generic_dict_group_deleted_seed1921 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector1922 = shufflevector <16 x i8> %generic_dict_group_deleted_seed1921, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches1923 = icmp eq <16 x i8> %generic_dict_group_controls1914, %generic_dict_group_deleted_vector1922
  %generic_dict_group_deleted_bits1924 = bitcast <16 x i1> %generic_dict_group_deleted_matches1923 to i16
  %generic_dict_group_has_deleted1925 = icmp ne i16 %generic_dict_group_deleted_bits1924, 0
  %generic_dict_group_no_previous_deleted1926 = icmp eq i64 %generic_dict_group_deleted1909, %set_grown_capacity1752
  %generic_dict_group_capture_deleted1927 = and i1 %generic_dict_group_has_deleted1925, %generic_dict_group_no_previous_deleted1926
  %generic_dict_group_deleted_offset161928 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits1924, i1 false)
  %generic_dict_group_deleted_offset1929 = zext i16 %generic_dict_group_deleted_offset161928 to i64
  %generic_dict_group_deleted_unwrapped1930 = add i64 %generic_dict_group_start1912, %generic_dict_group_deleted_offset1929
  %generic_dict_group_deleted_slot1931 = and i64 %generic_dict_group_deleted_unwrapped1930, %dict_capacity_mask1904
  %generic_dict_group_captured_deleted1932 = select i1 %generic_dict_group_capture_deleted1927, i64 %generic_dict_group_deleted_slot1931, i64 %generic_dict_group_deleted1909
  br label %bb_generic_dict_candidate_loop441

bb_generic_dict_candidate_loop441:
  %generic_dict_candidate_bits1933 = phi i16 [ %generic_dict_group_match_bits1918, %bb_generic_dict_group_body440 ], [ %generic_dict_candidate_cleared_bits1934, %bb_generic_dict_candidate_next443 ]
  %generic_dict_has_candidate1935 = icmp ne i16 %generic_dict_candidate_bits1933, 0
  br i1 %generic_dict_has_candidate1935, label %bb_generic_dict_candidate_body442, label %bb_generic_dict_group_decision444

bb_generic_dict_candidate_body442:
  %generic_dict_candidate_offset161936 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits1933, i1 false)
  %generic_dict_candidate_offset1937 = zext i16 %generic_dict_candidate_offset161936 to i64
  %generic_dict_candidate_unwrapped1938 = add i64 %generic_dict_group_start1912, %generic_dict_candidate_offset1937
  %generic_dict_candidate_slot1939 = and i64 %generic_dict_candidate_unwrapped1938, %dict_capacity_mask1904
  %generic_dict_key_entries_offset_mirror1940 = add i64 %set_grown_capacity1752, 23
  %generic_dict_key_entries_offset1941 = and i64 %generic_dict_key_entries_offset_mirror1940, -8
  %generic_dict_key_entries1942 = getelementptr i8, ptr %heap1757, i64 %generic_dict_key_entries_offset1941
  %generic_dict_key_entry_offset1943 = mul i64 %generic_dict_candidate_slot1939, 4
  %generic_dict_key_slot1944 = getelementptr i8, ptr %generic_dict_key_entries1942, i64 %generic_dict_key_entry_offset1943
  %generic_dict_key1945 = load i32, ptr %generic_dict_key_slot1944, align 4
  %generic_dict_key_equal1946 = icmp eq i32 %generic_dict_key1945, 5
  br i1 %generic_dict_key_equal1946, label %bb_generic_dict_group_match446, label %bb_generic_dict_candidate_next443

bb_generic_dict_candidate_next443:
  %generic_dict_candidate_bits_minus_one1947 = sub i16 %generic_dict_candidate_bits1933, 1
  %generic_dict_candidate_cleared_bits1934 = and i16 %generic_dict_candidate_bits1933, %generic_dict_candidate_bits_minus_one1947
  br label %bb_generic_dict_candidate_loop441

bb_generic_dict_group_decision444:
  %generic_dict_group_has_empty1948 = icmp ne i16 %generic_dict_group_empty_bits1920, 0
  br i1 %generic_dict_group_has_empty1948, label %bb_generic_dict_group_empty445, label %bb_generic_dict_group_next447

bb_generic_dict_group_empty445:
  %generic_dict_group_empty_offset161949 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits1920, i1 false)
  %generic_dict_group_empty_offset1950 = zext i16 %generic_dict_group_empty_offset161949 to i64
  %generic_dict_group_empty_unwrapped1951 = add i64 %generic_dict_group_start1912, %generic_dict_group_empty_offset1950
  %generic_dict_group_empty_slot1952 = and i64 %generic_dict_group_empty_unwrapped1951, %dict_capacity_mask1904
  %generic_dict_group_use_empty1953 = icmp eq i64 %generic_dict_group_captured_deleted1932, %set_grown_capacity1752
  %generic_dict_group_insertion_slot1954 = select i1 %generic_dict_group_use_empty1953, i64 %generic_dict_group_empty_slot1952, i64 %generic_dict_group_captured_deleted1932
  br label %bb_generic_dict_group_done449

bb_generic_dict_group_match446:
  br label %bb_generic_dict_group_done449

bb_generic_dict_group_next447:
  %generic_dict_group_next_probe1906 = add i64 %generic_dict_group_probe1908, 16
  %generic_dict_group_next_deleted1907 = add i64 %generic_dict_group_captured_deleted1932, 0
  br label %bb_generic_dict_group_find439

bb_generic_dict_group_miss448:
  %generic_dict_group_miss_no_deleted1955 = icmp eq i64 %generic_dict_group_deleted1909, %set_grown_capacity1752
  %generic_dict_group_miss_slot1956 = select i1 %generic_dict_group_miss_no_deleted1955, i64 0, i64 %generic_dict_group_deleted1909
  br label %bb_generic_dict_group_done449

bb_generic_dict_group_done449:
  %generic_dict_find_found1957 = phi i1 [ false, %bb_generic_dict_group_empty445 ], [ true, %bb_generic_dict_group_match446 ], [ false, %bb_generic_dict_group_miss448 ]
  %generic_dict_find_slot_result1958 = phi i64 [ %generic_dict_group_insertion_slot1954, %bb_generic_dict_group_empty445 ], [ %generic_dict_candidate_slot1939, %bb_generic_dict_group_match446 ], [ %generic_dict_group_miss_slot1956, %bb_generic_dict_group_miss448 ]
  br label %bb_generic_dict_insert_first_done436

bb_generic_dict_insert_first_done436:
  %generic_dict_insert_first_found1959 = phi i1 [ true, %bb_generic_dict_insert_first_match433 ], [ false, %bb_generic_dict_insert_first_vacant435 ], [ %generic_dict_find_found1957, %bb_generic_dict_group_done449 ], [ false, %bb_generic_dict_insert_no_capacity438 ]
  %generic_dict_insert_first_slot_result1960 = phi i64 [ %dict_start_slot1882, %bb_generic_dict_insert_first_match433 ], [ %dict_start_slot1882, %bb_generic_dict_insert_first_vacant435 ], [ %generic_dict_find_slot_result1958, %bb_generic_dict_group_done449 ], [ 0, %bb_generic_dict_insert_no_capacity438 ]
  %set_key_entries_offset_mirror1961 = add i64 %set_grown_capacity1752, 23
  %set_key_entries_offset1962 = and i64 %set_key_entries_offset_mirror1961, -8
  %set_key_entries1963 = getelementptr i8, ptr %heap1757, i64 %set_key_entries_offset1962
  %set_key_entry_offset1964 = mul i64 %generic_dict_insert_first_slot_result1960, 4
  %set_key_slot1965 = getelementptr i8, ptr %set_key_entries1963, i64 %set_key_entry_offset1964
  store i32 5, ptr %set_key_slot1965, align 4
  %generic_dict_control_slot1966 = getelementptr i8, ptr %heap1757, i64 %generic_dict_insert_first_slot_result1960
  store i8 %dict_h2_byte1880, ptr %generic_dict_control_slot1966, align 1
  %generic_dict_control_mirrored1967 = icmp ult i64 %generic_dict_insert_first_slot_result1960, 16
  br i1 %generic_dict_control_mirrored1967, label %bb_generic_dict_control_mirror450, label %bb_generic_dict_control_done451

bb_generic_dict_control_mirror450:
  %generic_dict_control_mirror_index1968 = add i64 %set_grown_capacity1752, %generic_dict_insert_first_slot_result1960
  %generic_dict_control_mirror_slot1969 = getelementptr i8, ptr %heap1757, i64 %generic_dict_control_mirror_index1968
  store i8 %dict_h2_byte1880, ptr %generic_dict_control_mirror_slot1969, align 1
  br label %bb_generic_dict_control_done451

bb_generic_dict_control_done451:
  br label %bb_set_insert_done400

bb_set_insert_done400:
  %set_pointer1970 = phi ptr [ %mutable_ptr1647, %bb_set_insert_duplicate396 ], [ %mutable_ptr1647, %bb_generic_dict_control_done402 ], [ %heap1757, %bb_generic_dict_control_done451 ]
  %set_length1971 = phi i64 [ %mutable_len1648, %bb_set_insert_duplicate396 ], [ %set_insert_length1739, %bb_generic_dict_control_done402 ], [ %set_insert_length1739, %bb_generic_dict_control_done451 ]
  %set_capacity1972 = phi i64 [ %mutable_capacity1649, %bb_set_insert_duplicate396 ], [ %mutable_capacity1649, %bb_generic_dict_control_done402 ], [ %set_grown_capacity1752, %bb_generic_dict_control_done451 ]
  %set_inserted1973 = phi i1 [ false, %bb_set_insert_duplicate396 ], [ true, %bb_generic_dict_control_done402 ], [ true, %bb_generic_dict_control_done451 ]
  store ptr %set_pointer1970, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length1971, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity1972, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr1974 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len1975 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity1976 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key1977 = sext i32 6 to i64
  %hash_high1979 = lshr i64 %hash_key1977, 32
  %hash_fold1978 = xor i64 %hash_key1977, %hash_high1979
  %hash1980 = mul i64 %hash_fold1978, -7046029254386353131
  %dict_h2_shifted1981 = lshr i64 %hash1980, 57
  %dict_h2_raw1982 = and i64 %dict_h2_shifted1981, 127
  %dict_h2_zero1983 = icmp eq i64 %dict_h2_raw1982, 0
  %dict_h21984 = select i1 %dict_h2_zero1983, i64 1, i64 %dict_h2_raw1982
  %dict_h2_byte1985 = trunc i64 %dict_h21984 to i8
  %dict_capacity_mask1986 = sub i64 %mutable_capacity1976, 1
  %dict_start_slot1987 = and i64 %hash1980, %dict_capacity_mask1986
  %generic_dict_insert_has_capacity1988 = icmp ugt i64 %mutable_capacity1976, 0
  br i1 %generic_dict_insert_has_capacity1988, label %bb_generic_dict_insert_first458, label %bb_generic_dict_insert_no_capacity459

bb_generic_dict_insert_no_capacity459:
  br label %bb_generic_dict_insert_first_done457

bb_generic_dict_insert_first458:
  %generic_dict_control_slot1989 = getelementptr i8, ptr %mutable_ptr1974, i64 %dict_start_slot1987
  %generic_dict_control1990 = load i8, ptr %generic_dict_control_slot1989, align 1
  %generic_dict_insert_first_empty1991 = icmp eq i8 %generic_dict_control1990, 0
  br i1 %generic_dict_insert_first_empty1991, label %bb_generic_dict_insert_first_vacant456, label %bb_generic_dict_insert_first_occupied452

bb_generic_dict_insert_first_occupied452:
  %generic_dict_insert_first_h21992 = icmp eq i8 %generic_dict_control1990, %dict_h2_byte1985
  br i1 %generic_dict_insert_first_h21992, label %bb_generic_dict_insert_first_compare453, label %bb_generic_dict_insert_first_fallback455

bb_generic_dict_insert_first_compare453:
  %generic_dict_insert_first_key_entries_offset_mirror1993 = add i64 %mutable_capacity1976, 23
  %generic_dict_insert_first_key_entries_offset1994 = and i64 %generic_dict_insert_first_key_entries_offset_mirror1993, -8
  %generic_dict_insert_first_key_entries1995 = getelementptr i8, ptr %mutable_ptr1974, i64 %generic_dict_insert_first_key_entries_offset1994
  %generic_dict_insert_first_key_entry_offset1996 = mul i64 %dict_start_slot1987, 4
  %generic_dict_insert_first_key_slot1997 = getelementptr i8, ptr %generic_dict_insert_first_key_entries1995, i64 %generic_dict_insert_first_key_entry_offset1996
  %generic_dict_insert_first_key1998 = load i32, ptr %generic_dict_insert_first_key_slot1997, align 4
  %generic_dict_key_equal1999 = icmp eq i32 %generic_dict_insert_first_key1998, 6
  br i1 %generic_dict_key_equal1999, label %bb_generic_dict_insert_first_match454, label %bb_generic_dict_insert_first_fallback455

bb_generic_dict_insert_first_match454:
  br label %bb_generic_dict_insert_first_done457

bb_generic_dict_insert_first_vacant456:
  br label %bb_generic_dict_insert_first_done457

bb_generic_dict_insert_first_fallback455:
  %hash_key2000 = sext i32 6 to i64
  %hash_high2002 = lshr i64 %hash_key2000, 32
  %hash_fold2001 = xor i64 %hash_key2000, %hash_high2002
  %hash2003 = mul i64 %hash_fold2001, -7046029254386353131
  %dict_h2_shifted2004 = lshr i64 %hash2003, 57
  %dict_h2_raw2005 = and i64 %dict_h2_shifted2004, 127
  %dict_h2_zero2006 = icmp eq i64 %dict_h2_raw2005, 0
  %dict_h22007 = select i1 %dict_h2_zero2006, i64 1, i64 %dict_h2_raw2005
  %dict_h2_byte2008 = trunc i64 %dict_h22007 to i8
  %dict_capacity_mask2009 = sub i64 %mutable_capacity1976, 1
  %dict_start_slot2010 = and i64 %hash2003, %dict_capacity_mask2009
  br label %bb_generic_dict_group_find460

bb_generic_dict_group_find460:
  %generic_dict_group_probe2013 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback455 ], [ %generic_dict_group_next_probe2011, %bb_generic_dict_group_next468 ]
  %generic_dict_group_deleted2014 = phi i64 [ %mutable_capacity1976, %bb_generic_dict_insert_first_fallback455 ], [ %generic_dict_group_next_deleted2012, %bb_generic_dict_group_next468 ]
  %generic_dict_group_active2015 = icmp ult i64 %generic_dict_group_probe2013, %mutable_capacity1976
  br i1 %generic_dict_group_active2015, label %bb_generic_dict_group_body461, label %bb_generic_dict_group_miss469

bb_generic_dict_group_body461:
  %generic_dict_group_unwrapped2016 = add i64 %dict_start_slot2010, %generic_dict_group_probe2013
  %generic_dict_group_start2017 = and i64 %generic_dict_group_unwrapped2016, %dict_capacity_mask2009
  %generic_dict_group_pointer2018 = getelementptr i8, ptr %mutable_ptr1974, i64 %generic_dict_group_start2017
  %generic_dict_group_controls2019 = load <16 x i8>, ptr %generic_dict_group_pointer2018, align 1
  %generic_dict_group_h2_seed2020 = insertelement <16 x i8> poison, i8 %dict_h2_byte2008, i64 0
  %generic_dict_group_h2_vector2021 = shufflevector <16 x i8> %generic_dict_group_h2_seed2020, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2022 = icmp eq <16 x i8> %generic_dict_group_controls2019, %generic_dict_group_h2_vector2021
  %generic_dict_group_match_bits2023 = bitcast <16 x i1> %generic_dict_group_matches_vector2022 to i16
  %generic_dict_group_empty_vector2024 = icmp eq <16 x i8> %generic_dict_group_controls2019, zeroinitializer
  %generic_dict_group_empty_bits2025 = bitcast <16 x i1> %generic_dict_group_empty_vector2024 to i16
  %generic_dict_group_deleted_seed2026 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2027 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2026, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2028 = icmp eq <16 x i8> %generic_dict_group_controls2019, %generic_dict_group_deleted_vector2027
  %generic_dict_group_deleted_bits2029 = bitcast <16 x i1> %generic_dict_group_deleted_matches2028 to i16
  %generic_dict_group_has_deleted2030 = icmp ne i16 %generic_dict_group_deleted_bits2029, 0
  %generic_dict_group_no_previous_deleted2031 = icmp eq i64 %generic_dict_group_deleted2014, %mutable_capacity1976
  %generic_dict_group_capture_deleted2032 = and i1 %generic_dict_group_has_deleted2030, %generic_dict_group_no_previous_deleted2031
  %generic_dict_group_deleted_offset162033 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2029, i1 false)
  %generic_dict_group_deleted_offset2034 = zext i16 %generic_dict_group_deleted_offset162033 to i64
  %generic_dict_group_deleted_unwrapped2035 = add i64 %generic_dict_group_start2017, %generic_dict_group_deleted_offset2034
  %generic_dict_group_deleted_slot2036 = and i64 %generic_dict_group_deleted_unwrapped2035, %dict_capacity_mask2009
  %generic_dict_group_captured_deleted2037 = select i1 %generic_dict_group_capture_deleted2032, i64 %generic_dict_group_deleted_slot2036, i64 %generic_dict_group_deleted2014
  br label %bb_generic_dict_candidate_loop462

bb_generic_dict_candidate_loop462:
  %generic_dict_candidate_bits2038 = phi i16 [ %generic_dict_group_match_bits2023, %bb_generic_dict_group_body461 ], [ %generic_dict_candidate_cleared_bits2039, %bb_generic_dict_candidate_next464 ]
  %generic_dict_has_candidate2040 = icmp ne i16 %generic_dict_candidate_bits2038, 0
  br i1 %generic_dict_has_candidate2040, label %bb_generic_dict_candidate_body463, label %bb_generic_dict_group_decision465

bb_generic_dict_candidate_body463:
  %generic_dict_candidate_offset162041 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2038, i1 false)
  %generic_dict_candidate_offset2042 = zext i16 %generic_dict_candidate_offset162041 to i64
  %generic_dict_candidate_unwrapped2043 = add i64 %generic_dict_group_start2017, %generic_dict_candidate_offset2042
  %generic_dict_candidate_slot2044 = and i64 %generic_dict_candidate_unwrapped2043, %dict_capacity_mask2009
  %generic_dict_key_entries_offset_mirror2045 = add i64 %mutable_capacity1976, 23
  %generic_dict_key_entries_offset2046 = and i64 %generic_dict_key_entries_offset_mirror2045, -8
  %generic_dict_key_entries2047 = getelementptr i8, ptr %mutable_ptr1974, i64 %generic_dict_key_entries_offset2046
  %generic_dict_key_entry_offset2048 = mul i64 %generic_dict_candidate_slot2044, 4
  %generic_dict_key_slot2049 = getelementptr i8, ptr %generic_dict_key_entries2047, i64 %generic_dict_key_entry_offset2048
  %generic_dict_key2050 = load i32, ptr %generic_dict_key_slot2049, align 4
  %generic_dict_key_equal2051 = icmp eq i32 %generic_dict_key2050, 6
  br i1 %generic_dict_key_equal2051, label %bb_generic_dict_group_match467, label %bb_generic_dict_candidate_next464

bb_generic_dict_candidate_next464:
  %generic_dict_candidate_bits_minus_one2052 = sub i16 %generic_dict_candidate_bits2038, 1
  %generic_dict_candidate_cleared_bits2039 = and i16 %generic_dict_candidate_bits2038, %generic_dict_candidate_bits_minus_one2052
  br label %bb_generic_dict_candidate_loop462

bb_generic_dict_group_decision465:
  %generic_dict_group_has_empty2053 = icmp ne i16 %generic_dict_group_empty_bits2025, 0
  br i1 %generic_dict_group_has_empty2053, label %bb_generic_dict_group_empty466, label %bb_generic_dict_group_next468

bb_generic_dict_group_empty466:
  %generic_dict_group_empty_offset162054 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2025, i1 false)
  %generic_dict_group_empty_offset2055 = zext i16 %generic_dict_group_empty_offset162054 to i64
  %generic_dict_group_empty_unwrapped2056 = add i64 %generic_dict_group_start2017, %generic_dict_group_empty_offset2055
  %generic_dict_group_empty_slot2057 = and i64 %generic_dict_group_empty_unwrapped2056, %dict_capacity_mask2009
  %generic_dict_group_use_empty2058 = icmp eq i64 %generic_dict_group_captured_deleted2037, %mutable_capacity1976
  %generic_dict_group_insertion_slot2059 = select i1 %generic_dict_group_use_empty2058, i64 %generic_dict_group_empty_slot2057, i64 %generic_dict_group_captured_deleted2037
  br label %bb_generic_dict_group_done470

bb_generic_dict_group_match467:
  br label %bb_generic_dict_group_done470

bb_generic_dict_group_next468:
  %generic_dict_group_next_probe2011 = add i64 %generic_dict_group_probe2013, 16
  %generic_dict_group_next_deleted2012 = add i64 %generic_dict_group_captured_deleted2037, 0
  br label %bb_generic_dict_group_find460

bb_generic_dict_group_miss469:
  %generic_dict_group_miss_no_deleted2060 = icmp eq i64 %generic_dict_group_deleted2014, %mutable_capacity1976
  %generic_dict_group_miss_slot2061 = select i1 %generic_dict_group_miss_no_deleted2060, i64 0, i64 %generic_dict_group_deleted2014
  br label %bb_generic_dict_group_done470

bb_generic_dict_group_done470:
  %generic_dict_find_found2062 = phi i1 [ false, %bb_generic_dict_group_empty466 ], [ true, %bb_generic_dict_group_match467 ], [ false, %bb_generic_dict_group_miss469 ]
  %generic_dict_find_slot_result2063 = phi i64 [ %generic_dict_group_insertion_slot2059, %bb_generic_dict_group_empty466 ], [ %generic_dict_candidate_slot2044, %bb_generic_dict_group_match467 ], [ %generic_dict_group_miss_slot2061, %bb_generic_dict_group_miss469 ]
  br label %bb_generic_dict_insert_first_done457

bb_generic_dict_insert_first_done457:
  %generic_dict_insert_first_found2064 = phi i1 [ true, %bb_generic_dict_insert_first_match454 ], [ false, %bb_generic_dict_insert_first_vacant456 ], [ %generic_dict_find_found2062, %bb_generic_dict_group_done470 ], [ false, %bb_generic_dict_insert_no_capacity459 ]
  %generic_dict_insert_first_slot_result2065 = phi i64 [ %dict_start_slot1987, %bb_generic_dict_insert_first_match454 ], [ %dict_start_slot1987, %bb_generic_dict_insert_first_vacant456 ], [ %generic_dict_find_slot_result2063, %bb_generic_dict_group_done470 ], [ 0, %bb_generic_dict_insert_no_capacity459 ]
  br i1 %generic_dict_insert_first_found2064, label %bb_set_insert_duplicate471, label %bb_set_insert_new472

bb_set_insert_duplicate471:
  br label %bb_set_insert_done475

bb_set_insert_new472:
  %set_insert_length2066 = add i64 %mutable_len1975, 1
  %set_insert_load_num2067 = mul i64 %set_insert_length2066, 8
  %set_insert_load_den2068 = mul i64 %mutable_capacity1976, 7
  %set_insert_should_grow2069 = icmp ugt i64 %set_insert_load_num2067, %set_insert_load_den2068
  br i1 %set_insert_should_grow2069, label %bb_set_insert_grow474, label %bb_set_insert_current473

bb_set_insert_current473:
  %set_key_entries_offset_mirror2070 = add i64 %mutable_capacity1976, 23
  %set_key_entries_offset2071 = and i64 %set_key_entries_offset_mirror2070, -8
  %set_key_entries2072 = getelementptr i8, ptr %mutable_ptr1974, i64 %set_key_entries_offset2071
  %set_key_entry_offset2073 = mul i64 %generic_dict_insert_first_slot_result2065, 4
  %set_key_slot2074 = getelementptr i8, ptr %set_key_entries2072, i64 %set_key_entry_offset2073
  store i32 6, ptr %set_key_slot2074, align 4
  %generic_dict_control_slot2075 = getelementptr i8, ptr %mutable_ptr1974, i64 %generic_dict_insert_first_slot_result2065
  store i8 %dict_h2_byte1985, ptr %generic_dict_control_slot2075, align 1
  %generic_dict_control_mirrored2076 = icmp ult i64 %generic_dict_insert_first_slot_result2065, 16
  br i1 %generic_dict_control_mirrored2076, label %bb_generic_dict_control_mirror476, label %bb_generic_dict_control_done477

bb_generic_dict_control_mirror476:
  %generic_dict_control_mirror_index2077 = add i64 %mutable_capacity1976, %generic_dict_insert_first_slot_result2065
  %generic_dict_control_mirror_slot2078 = getelementptr i8, ptr %mutable_ptr1974, i64 %generic_dict_control_mirror_index2077
  store i8 %dict_h2_byte1985, ptr %generic_dict_control_mirror_slot2078, align 1
  br label %bb_generic_dict_control_done477

bb_generic_dict_control_done477:
  br label %bb_set_insert_done475

bb_set_insert_grow474:
  %set_grown_capacity2079 = mul i64 %mutable_capacity1976, 2
  %generic_dict_entries_offset_mirror2080 = add i64 %set_grown_capacity2079, 23
  %generic_dict_entries_offset2081 = and i64 %generic_dict_entries_offset_mirror2080, -8
  %generic_dict_entries_bytes2082 = mul i64 %set_grown_capacity2079, 4
  %generic_dict_bytes2083 = add i64 %generic_dict_entries_offset2081, %generic_dict_entries_bytes2082
  %heap2084 = call ptr @sollang_alloc(i64 %generic_dict_bytes2083)
  %heap_ok2085 = icmp ne ptr %heap2084, null
  br i1 %heap_ok2085, label %bb_alloc_ok478, label %bb_alloc_fail479

bb_alloc_fail479:
  %trap_stderr2086 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr2086, ptr @.slg.str.module.x.7, i32 25, ptr %trap_written2087, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok478:
  %generic_dict_control_bytes2088 = add i64 %set_grown_capacity2079, 16
  call void @llvm.memset.p0.i64(ptr %heap2084, i8 0, i64 %generic_dict_control_bytes2088, i1 false)
  br label %bb_set_rehash480

bb_set_rehash480:
  %set_rehash_index2090 = phi i64 [ 0, %bb_alloc_ok478 ], [ %set_rehash_next_index2089, %bb_set_rehash_next483 ]
  %set_rehash_active2091 = icmp ult i64 %set_rehash_index2090, %mutable_capacity1976
  br i1 %set_rehash_active2091, label %bb_set_rehash_body481, label %bb_set_rehash_done484

bb_set_rehash_body481:
  %generic_dict_control_slot2092 = getelementptr i8, ptr %mutable_ptr1974, i64 %set_rehash_index2090
  %generic_dict_control2093 = load i8, ptr %generic_dict_control_slot2092, align 1
  %set_rehash_occupied2094 = icmp sgt i8 %generic_dict_control2093, 0
  br i1 %set_rehash_occupied2094, label %bb_set_rehash_move482, label %bb_set_rehash_next483

bb_set_rehash_move482:
  %set_rehash_key_entries_offset_mirror2095 = add i64 %mutable_capacity1976, 23
  %set_rehash_key_entries_offset2096 = and i64 %set_rehash_key_entries_offset_mirror2095, -8
  %set_rehash_key_entries2097 = getelementptr i8, ptr %mutable_ptr1974, i64 %set_rehash_key_entries_offset2096
  %set_rehash_key_entry_offset2098 = mul i64 %set_rehash_index2090, 4
  %set_rehash_key_slot2099 = getelementptr i8, ptr %set_rehash_key_entries2097, i64 %set_rehash_key_entry_offset2098
  %set_rehash_key2100 = load i32, ptr %set_rehash_key_slot2099, align 4
  %hash_key2101 = sext i32 %set_rehash_key2100 to i64
  %hash_high2103 = lshr i64 %hash_key2101, 32
  %hash_fold2102 = xor i64 %hash_key2101, %hash_high2103
  %hash2104 = mul i64 %hash_fold2102, -7046029254386353131
  %dict_h2_shifted2105 = lshr i64 %hash2104, 57
  %dict_h2_raw2106 = and i64 %dict_h2_shifted2105, 127
  %dict_h2_zero2107 = icmp eq i64 %dict_h2_raw2106, 0
  %dict_h22108 = select i1 %dict_h2_zero2107, i64 1, i64 %dict_h2_raw2106
  %dict_h2_byte2109 = trunc i64 %dict_h22108 to i8
  %dict_capacity_mask2110 = sub i64 %set_grown_capacity2079, 1
  %dict_start_slot2111 = and i64 %hash2104, %dict_capacity_mask2110
  %generic_dict_insert_has_capacity2112 = icmp ugt i64 %set_grown_capacity2079, 0
  br i1 %generic_dict_insert_has_capacity2112, label %bb_generic_dict_insert_first491, label %bb_generic_dict_insert_no_capacity492

bb_generic_dict_insert_no_capacity492:
  br label %bb_generic_dict_insert_first_done490

bb_generic_dict_insert_first491:
  %generic_dict_control_slot2113 = getelementptr i8, ptr %heap2084, i64 %dict_start_slot2111
  %generic_dict_control2114 = load i8, ptr %generic_dict_control_slot2113, align 1
  %generic_dict_insert_first_empty2115 = icmp eq i8 %generic_dict_control2114, 0
  br i1 %generic_dict_insert_first_empty2115, label %bb_generic_dict_insert_first_vacant489, label %bb_generic_dict_insert_first_occupied485

bb_generic_dict_insert_first_occupied485:
  %generic_dict_insert_first_h22116 = icmp eq i8 %generic_dict_control2114, %dict_h2_byte2109
  br i1 %generic_dict_insert_first_h22116, label %bb_generic_dict_insert_first_compare486, label %bb_generic_dict_insert_first_fallback488

bb_generic_dict_insert_first_compare486:
  %generic_dict_insert_first_key_entries_offset_mirror2117 = add i64 %set_grown_capacity2079, 23
  %generic_dict_insert_first_key_entries_offset2118 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2117, -8
  %generic_dict_insert_first_key_entries2119 = getelementptr i8, ptr %heap2084, i64 %generic_dict_insert_first_key_entries_offset2118
  %generic_dict_insert_first_key_entry_offset2120 = mul i64 %dict_start_slot2111, 4
  %generic_dict_insert_first_key_slot2121 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2119, i64 %generic_dict_insert_first_key_entry_offset2120
  %generic_dict_insert_first_key2122 = load i32, ptr %generic_dict_insert_first_key_slot2121, align 4
  %generic_dict_key_equal2123 = icmp eq i32 %generic_dict_insert_first_key2122, %set_rehash_key2100
  br i1 %generic_dict_key_equal2123, label %bb_generic_dict_insert_first_match487, label %bb_generic_dict_insert_first_fallback488

bb_generic_dict_insert_first_match487:
  br label %bb_generic_dict_insert_first_done490

bb_generic_dict_insert_first_vacant489:
  br label %bb_generic_dict_insert_first_done490

bb_generic_dict_insert_first_fallback488:
  %hash_key2124 = sext i32 %set_rehash_key2100 to i64
  %hash_high2126 = lshr i64 %hash_key2124, 32
  %hash_fold2125 = xor i64 %hash_key2124, %hash_high2126
  %hash2127 = mul i64 %hash_fold2125, -7046029254386353131
  %dict_h2_shifted2128 = lshr i64 %hash2127, 57
  %dict_h2_raw2129 = and i64 %dict_h2_shifted2128, 127
  %dict_h2_zero2130 = icmp eq i64 %dict_h2_raw2129, 0
  %dict_h22131 = select i1 %dict_h2_zero2130, i64 1, i64 %dict_h2_raw2129
  %dict_h2_byte2132 = trunc i64 %dict_h22131 to i8
  %dict_capacity_mask2133 = sub i64 %set_grown_capacity2079, 1
  %dict_start_slot2134 = and i64 %hash2127, %dict_capacity_mask2133
  br label %bb_generic_dict_group_find493

bb_generic_dict_group_find493:
  %generic_dict_group_probe2137 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback488 ], [ %generic_dict_group_next_probe2135, %bb_generic_dict_group_next501 ]
  %generic_dict_group_deleted2138 = phi i64 [ %set_grown_capacity2079, %bb_generic_dict_insert_first_fallback488 ], [ %generic_dict_group_next_deleted2136, %bb_generic_dict_group_next501 ]
  %generic_dict_group_active2139 = icmp ult i64 %generic_dict_group_probe2137, %set_grown_capacity2079
  br i1 %generic_dict_group_active2139, label %bb_generic_dict_group_body494, label %bb_generic_dict_group_miss502

bb_generic_dict_group_body494:
  %generic_dict_group_unwrapped2140 = add i64 %dict_start_slot2134, %generic_dict_group_probe2137
  %generic_dict_group_start2141 = and i64 %generic_dict_group_unwrapped2140, %dict_capacity_mask2133
  %generic_dict_group_pointer2142 = getelementptr i8, ptr %heap2084, i64 %generic_dict_group_start2141
  %generic_dict_group_controls2143 = load <16 x i8>, ptr %generic_dict_group_pointer2142, align 1
  %generic_dict_group_h2_seed2144 = insertelement <16 x i8> poison, i8 %dict_h2_byte2132, i64 0
  %generic_dict_group_h2_vector2145 = shufflevector <16 x i8> %generic_dict_group_h2_seed2144, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2146 = icmp eq <16 x i8> %generic_dict_group_controls2143, %generic_dict_group_h2_vector2145
  %generic_dict_group_match_bits2147 = bitcast <16 x i1> %generic_dict_group_matches_vector2146 to i16
  %generic_dict_group_empty_vector2148 = icmp eq <16 x i8> %generic_dict_group_controls2143, zeroinitializer
  %generic_dict_group_empty_bits2149 = bitcast <16 x i1> %generic_dict_group_empty_vector2148 to i16
  %generic_dict_group_deleted_seed2150 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2151 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2150, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2152 = icmp eq <16 x i8> %generic_dict_group_controls2143, %generic_dict_group_deleted_vector2151
  %generic_dict_group_deleted_bits2153 = bitcast <16 x i1> %generic_dict_group_deleted_matches2152 to i16
  %generic_dict_group_has_deleted2154 = icmp ne i16 %generic_dict_group_deleted_bits2153, 0
  %generic_dict_group_no_previous_deleted2155 = icmp eq i64 %generic_dict_group_deleted2138, %set_grown_capacity2079
  %generic_dict_group_capture_deleted2156 = and i1 %generic_dict_group_has_deleted2154, %generic_dict_group_no_previous_deleted2155
  %generic_dict_group_deleted_offset162157 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2153, i1 false)
  %generic_dict_group_deleted_offset2158 = zext i16 %generic_dict_group_deleted_offset162157 to i64
  %generic_dict_group_deleted_unwrapped2159 = add i64 %generic_dict_group_start2141, %generic_dict_group_deleted_offset2158
  %generic_dict_group_deleted_slot2160 = and i64 %generic_dict_group_deleted_unwrapped2159, %dict_capacity_mask2133
  %generic_dict_group_captured_deleted2161 = select i1 %generic_dict_group_capture_deleted2156, i64 %generic_dict_group_deleted_slot2160, i64 %generic_dict_group_deleted2138
  br label %bb_generic_dict_candidate_loop495

bb_generic_dict_candidate_loop495:
  %generic_dict_candidate_bits2162 = phi i16 [ %generic_dict_group_match_bits2147, %bb_generic_dict_group_body494 ], [ %generic_dict_candidate_cleared_bits2163, %bb_generic_dict_candidate_next497 ]
  %generic_dict_has_candidate2164 = icmp ne i16 %generic_dict_candidate_bits2162, 0
  br i1 %generic_dict_has_candidate2164, label %bb_generic_dict_candidate_body496, label %bb_generic_dict_group_decision498

bb_generic_dict_candidate_body496:
  %generic_dict_candidate_offset162165 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2162, i1 false)
  %generic_dict_candidate_offset2166 = zext i16 %generic_dict_candidate_offset162165 to i64
  %generic_dict_candidate_unwrapped2167 = add i64 %generic_dict_group_start2141, %generic_dict_candidate_offset2166
  %generic_dict_candidate_slot2168 = and i64 %generic_dict_candidate_unwrapped2167, %dict_capacity_mask2133
  %generic_dict_key_entries_offset_mirror2169 = add i64 %set_grown_capacity2079, 23
  %generic_dict_key_entries_offset2170 = and i64 %generic_dict_key_entries_offset_mirror2169, -8
  %generic_dict_key_entries2171 = getelementptr i8, ptr %heap2084, i64 %generic_dict_key_entries_offset2170
  %generic_dict_key_entry_offset2172 = mul i64 %generic_dict_candidate_slot2168, 4
  %generic_dict_key_slot2173 = getelementptr i8, ptr %generic_dict_key_entries2171, i64 %generic_dict_key_entry_offset2172
  %generic_dict_key2174 = load i32, ptr %generic_dict_key_slot2173, align 4
  %generic_dict_key_equal2175 = icmp eq i32 %generic_dict_key2174, %set_rehash_key2100
  br i1 %generic_dict_key_equal2175, label %bb_generic_dict_group_match500, label %bb_generic_dict_candidate_next497

bb_generic_dict_candidate_next497:
  %generic_dict_candidate_bits_minus_one2176 = sub i16 %generic_dict_candidate_bits2162, 1
  %generic_dict_candidate_cleared_bits2163 = and i16 %generic_dict_candidate_bits2162, %generic_dict_candidate_bits_minus_one2176
  br label %bb_generic_dict_candidate_loop495

bb_generic_dict_group_decision498:
  %generic_dict_group_has_empty2177 = icmp ne i16 %generic_dict_group_empty_bits2149, 0
  br i1 %generic_dict_group_has_empty2177, label %bb_generic_dict_group_empty499, label %bb_generic_dict_group_next501

bb_generic_dict_group_empty499:
  %generic_dict_group_empty_offset162178 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2149, i1 false)
  %generic_dict_group_empty_offset2179 = zext i16 %generic_dict_group_empty_offset162178 to i64
  %generic_dict_group_empty_unwrapped2180 = add i64 %generic_dict_group_start2141, %generic_dict_group_empty_offset2179
  %generic_dict_group_empty_slot2181 = and i64 %generic_dict_group_empty_unwrapped2180, %dict_capacity_mask2133
  %generic_dict_group_use_empty2182 = icmp eq i64 %generic_dict_group_captured_deleted2161, %set_grown_capacity2079
  %generic_dict_group_insertion_slot2183 = select i1 %generic_dict_group_use_empty2182, i64 %generic_dict_group_empty_slot2181, i64 %generic_dict_group_captured_deleted2161
  br label %bb_generic_dict_group_done503

bb_generic_dict_group_match500:
  br label %bb_generic_dict_group_done503

bb_generic_dict_group_next501:
  %generic_dict_group_next_probe2135 = add i64 %generic_dict_group_probe2137, 16
  %generic_dict_group_next_deleted2136 = add i64 %generic_dict_group_captured_deleted2161, 0
  br label %bb_generic_dict_group_find493

bb_generic_dict_group_miss502:
  %generic_dict_group_miss_no_deleted2184 = icmp eq i64 %generic_dict_group_deleted2138, %set_grown_capacity2079
  %generic_dict_group_miss_slot2185 = select i1 %generic_dict_group_miss_no_deleted2184, i64 0, i64 %generic_dict_group_deleted2138
  br label %bb_generic_dict_group_done503

bb_generic_dict_group_done503:
  %generic_dict_find_found2186 = phi i1 [ false, %bb_generic_dict_group_empty499 ], [ true, %bb_generic_dict_group_match500 ], [ false, %bb_generic_dict_group_miss502 ]
  %generic_dict_find_slot_result2187 = phi i64 [ %generic_dict_group_insertion_slot2183, %bb_generic_dict_group_empty499 ], [ %generic_dict_candidate_slot2168, %bb_generic_dict_group_match500 ], [ %generic_dict_group_miss_slot2185, %bb_generic_dict_group_miss502 ]
  br label %bb_generic_dict_insert_first_done490

bb_generic_dict_insert_first_done490:
  %generic_dict_insert_first_found2188 = phi i1 [ true, %bb_generic_dict_insert_first_match487 ], [ false, %bb_generic_dict_insert_first_vacant489 ], [ %generic_dict_find_found2186, %bb_generic_dict_group_done503 ], [ false, %bb_generic_dict_insert_no_capacity492 ]
  %generic_dict_insert_first_slot_result2189 = phi i64 [ %dict_start_slot2111, %bb_generic_dict_insert_first_match487 ], [ %dict_start_slot2111, %bb_generic_dict_insert_first_vacant489 ], [ %generic_dict_find_slot_result2187, %bb_generic_dict_group_done503 ], [ 0, %bb_generic_dict_insert_no_capacity492 ]
  %set_key_entries_offset_mirror2190 = add i64 %set_grown_capacity2079, 23
  %set_key_entries_offset2191 = and i64 %set_key_entries_offset_mirror2190, -8
  %set_key_entries2192 = getelementptr i8, ptr %heap2084, i64 %set_key_entries_offset2191
  %set_key_entry_offset2193 = mul i64 %generic_dict_insert_first_slot_result2189, 4
  %set_key_slot2194 = getelementptr i8, ptr %set_key_entries2192, i64 %set_key_entry_offset2193
  store i32 %set_rehash_key2100, ptr %set_key_slot2194, align 4
  %generic_dict_control_slot2195 = getelementptr i8, ptr %heap2084, i64 %generic_dict_insert_first_slot_result2189
  store i8 %dict_h2_byte2109, ptr %generic_dict_control_slot2195, align 1
  %generic_dict_control_mirrored2196 = icmp ult i64 %generic_dict_insert_first_slot_result2189, 16
  br i1 %generic_dict_control_mirrored2196, label %bb_generic_dict_control_mirror504, label %bb_generic_dict_control_done505

bb_generic_dict_control_mirror504:
  %generic_dict_control_mirror_index2197 = add i64 %set_grown_capacity2079, %generic_dict_insert_first_slot_result2189
  %generic_dict_control_mirror_slot2198 = getelementptr i8, ptr %heap2084, i64 %generic_dict_control_mirror_index2197
  store i8 %dict_h2_byte2109, ptr %generic_dict_control_mirror_slot2198, align 1
  br label %bb_generic_dict_control_done505

bb_generic_dict_control_done505:
  br label %bb_set_rehash_next483

bb_set_rehash_next483:
  %set_rehash_next_index2089 = add i64 %set_rehash_index2090, 1
  br label %bb_set_rehash480

bb_set_rehash_done484:
  call void @sollang_free(ptr %mutable_ptr1974)
  %hash_key2199 = sext i32 6 to i64
  %hash_high2201 = lshr i64 %hash_key2199, 32
  %hash_fold2200 = xor i64 %hash_key2199, %hash_high2201
  %hash2202 = mul i64 %hash_fold2200, -7046029254386353131
  %dict_h2_shifted2203 = lshr i64 %hash2202, 57
  %dict_h2_raw2204 = and i64 %dict_h2_shifted2203, 127
  %dict_h2_zero2205 = icmp eq i64 %dict_h2_raw2204, 0
  %dict_h22206 = select i1 %dict_h2_zero2205, i64 1, i64 %dict_h2_raw2204
  %dict_h2_byte2207 = trunc i64 %dict_h22206 to i8
  %dict_capacity_mask2208 = sub i64 %set_grown_capacity2079, 1
  %dict_start_slot2209 = and i64 %hash2202, %dict_capacity_mask2208
  %generic_dict_insert_has_capacity2210 = icmp ugt i64 %set_grown_capacity2079, 0
  br i1 %generic_dict_insert_has_capacity2210, label %bb_generic_dict_insert_first512, label %bb_generic_dict_insert_no_capacity513

bb_generic_dict_insert_no_capacity513:
  br label %bb_generic_dict_insert_first_done511

bb_generic_dict_insert_first512:
  %generic_dict_control_slot2211 = getelementptr i8, ptr %heap2084, i64 %dict_start_slot2209
  %generic_dict_control2212 = load i8, ptr %generic_dict_control_slot2211, align 1
  %generic_dict_insert_first_empty2213 = icmp eq i8 %generic_dict_control2212, 0
  br i1 %generic_dict_insert_first_empty2213, label %bb_generic_dict_insert_first_vacant510, label %bb_generic_dict_insert_first_occupied506

bb_generic_dict_insert_first_occupied506:
  %generic_dict_insert_first_h22214 = icmp eq i8 %generic_dict_control2212, %dict_h2_byte2207
  br i1 %generic_dict_insert_first_h22214, label %bb_generic_dict_insert_first_compare507, label %bb_generic_dict_insert_first_fallback509

bb_generic_dict_insert_first_compare507:
  %generic_dict_insert_first_key_entries_offset_mirror2215 = add i64 %set_grown_capacity2079, 23
  %generic_dict_insert_first_key_entries_offset2216 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2215, -8
  %generic_dict_insert_first_key_entries2217 = getelementptr i8, ptr %heap2084, i64 %generic_dict_insert_first_key_entries_offset2216
  %generic_dict_insert_first_key_entry_offset2218 = mul i64 %dict_start_slot2209, 4
  %generic_dict_insert_first_key_slot2219 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2217, i64 %generic_dict_insert_first_key_entry_offset2218
  %generic_dict_insert_first_key2220 = load i32, ptr %generic_dict_insert_first_key_slot2219, align 4
  %generic_dict_key_equal2221 = icmp eq i32 %generic_dict_insert_first_key2220, 6
  br i1 %generic_dict_key_equal2221, label %bb_generic_dict_insert_first_match508, label %bb_generic_dict_insert_first_fallback509

bb_generic_dict_insert_first_match508:
  br label %bb_generic_dict_insert_first_done511

bb_generic_dict_insert_first_vacant510:
  br label %bb_generic_dict_insert_first_done511

bb_generic_dict_insert_first_fallback509:
  %hash_key2222 = sext i32 6 to i64
  %hash_high2224 = lshr i64 %hash_key2222, 32
  %hash_fold2223 = xor i64 %hash_key2222, %hash_high2224
  %hash2225 = mul i64 %hash_fold2223, -7046029254386353131
  %dict_h2_shifted2226 = lshr i64 %hash2225, 57
  %dict_h2_raw2227 = and i64 %dict_h2_shifted2226, 127
  %dict_h2_zero2228 = icmp eq i64 %dict_h2_raw2227, 0
  %dict_h22229 = select i1 %dict_h2_zero2228, i64 1, i64 %dict_h2_raw2227
  %dict_h2_byte2230 = trunc i64 %dict_h22229 to i8
  %dict_capacity_mask2231 = sub i64 %set_grown_capacity2079, 1
  %dict_start_slot2232 = and i64 %hash2225, %dict_capacity_mask2231
  br label %bb_generic_dict_group_find514

bb_generic_dict_group_find514:
  %generic_dict_group_probe2235 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback509 ], [ %generic_dict_group_next_probe2233, %bb_generic_dict_group_next522 ]
  %generic_dict_group_deleted2236 = phi i64 [ %set_grown_capacity2079, %bb_generic_dict_insert_first_fallback509 ], [ %generic_dict_group_next_deleted2234, %bb_generic_dict_group_next522 ]
  %generic_dict_group_active2237 = icmp ult i64 %generic_dict_group_probe2235, %set_grown_capacity2079
  br i1 %generic_dict_group_active2237, label %bb_generic_dict_group_body515, label %bb_generic_dict_group_miss523

bb_generic_dict_group_body515:
  %generic_dict_group_unwrapped2238 = add i64 %dict_start_slot2232, %generic_dict_group_probe2235
  %generic_dict_group_start2239 = and i64 %generic_dict_group_unwrapped2238, %dict_capacity_mask2231
  %generic_dict_group_pointer2240 = getelementptr i8, ptr %heap2084, i64 %generic_dict_group_start2239
  %generic_dict_group_controls2241 = load <16 x i8>, ptr %generic_dict_group_pointer2240, align 1
  %generic_dict_group_h2_seed2242 = insertelement <16 x i8> poison, i8 %dict_h2_byte2230, i64 0
  %generic_dict_group_h2_vector2243 = shufflevector <16 x i8> %generic_dict_group_h2_seed2242, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2244 = icmp eq <16 x i8> %generic_dict_group_controls2241, %generic_dict_group_h2_vector2243
  %generic_dict_group_match_bits2245 = bitcast <16 x i1> %generic_dict_group_matches_vector2244 to i16
  %generic_dict_group_empty_vector2246 = icmp eq <16 x i8> %generic_dict_group_controls2241, zeroinitializer
  %generic_dict_group_empty_bits2247 = bitcast <16 x i1> %generic_dict_group_empty_vector2246 to i16
  %generic_dict_group_deleted_seed2248 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2249 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2248, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2250 = icmp eq <16 x i8> %generic_dict_group_controls2241, %generic_dict_group_deleted_vector2249
  %generic_dict_group_deleted_bits2251 = bitcast <16 x i1> %generic_dict_group_deleted_matches2250 to i16
  %generic_dict_group_has_deleted2252 = icmp ne i16 %generic_dict_group_deleted_bits2251, 0
  %generic_dict_group_no_previous_deleted2253 = icmp eq i64 %generic_dict_group_deleted2236, %set_grown_capacity2079
  %generic_dict_group_capture_deleted2254 = and i1 %generic_dict_group_has_deleted2252, %generic_dict_group_no_previous_deleted2253
  %generic_dict_group_deleted_offset162255 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2251, i1 false)
  %generic_dict_group_deleted_offset2256 = zext i16 %generic_dict_group_deleted_offset162255 to i64
  %generic_dict_group_deleted_unwrapped2257 = add i64 %generic_dict_group_start2239, %generic_dict_group_deleted_offset2256
  %generic_dict_group_deleted_slot2258 = and i64 %generic_dict_group_deleted_unwrapped2257, %dict_capacity_mask2231
  %generic_dict_group_captured_deleted2259 = select i1 %generic_dict_group_capture_deleted2254, i64 %generic_dict_group_deleted_slot2258, i64 %generic_dict_group_deleted2236
  br label %bb_generic_dict_candidate_loop516

bb_generic_dict_candidate_loop516:
  %generic_dict_candidate_bits2260 = phi i16 [ %generic_dict_group_match_bits2245, %bb_generic_dict_group_body515 ], [ %generic_dict_candidate_cleared_bits2261, %bb_generic_dict_candidate_next518 ]
  %generic_dict_has_candidate2262 = icmp ne i16 %generic_dict_candidate_bits2260, 0
  br i1 %generic_dict_has_candidate2262, label %bb_generic_dict_candidate_body517, label %bb_generic_dict_group_decision519

bb_generic_dict_candidate_body517:
  %generic_dict_candidate_offset162263 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2260, i1 false)
  %generic_dict_candidate_offset2264 = zext i16 %generic_dict_candidate_offset162263 to i64
  %generic_dict_candidate_unwrapped2265 = add i64 %generic_dict_group_start2239, %generic_dict_candidate_offset2264
  %generic_dict_candidate_slot2266 = and i64 %generic_dict_candidate_unwrapped2265, %dict_capacity_mask2231
  %generic_dict_key_entries_offset_mirror2267 = add i64 %set_grown_capacity2079, 23
  %generic_dict_key_entries_offset2268 = and i64 %generic_dict_key_entries_offset_mirror2267, -8
  %generic_dict_key_entries2269 = getelementptr i8, ptr %heap2084, i64 %generic_dict_key_entries_offset2268
  %generic_dict_key_entry_offset2270 = mul i64 %generic_dict_candidate_slot2266, 4
  %generic_dict_key_slot2271 = getelementptr i8, ptr %generic_dict_key_entries2269, i64 %generic_dict_key_entry_offset2270
  %generic_dict_key2272 = load i32, ptr %generic_dict_key_slot2271, align 4
  %generic_dict_key_equal2273 = icmp eq i32 %generic_dict_key2272, 6
  br i1 %generic_dict_key_equal2273, label %bb_generic_dict_group_match521, label %bb_generic_dict_candidate_next518

bb_generic_dict_candidate_next518:
  %generic_dict_candidate_bits_minus_one2274 = sub i16 %generic_dict_candidate_bits2260, 1
  %generic_dict_candidate_cleared_bits2261 = and i16 %generic_dict_candidate_bits2260, %generic_dict_candidate_bits_minus_one2274
  br label %bb_generic_dict_candidate_loop516

bb_generic_dict_group_decision519:
  %generic_dict_group_has_empty2275 = icmp ne i16 %generic_dict_group_empty_bits2247, 0
  br i1 %generic_dict_group_has_empty2275, label %bb_generic_dict_group_empty520, label %bb_generic_dict_group_next522

bb_generic_dict_group_empty520:
  %generic_dict_group_empty_offset162276 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2247, i1 false)
  %generic_dict_group_empty_offset2277 = zext i16 %generic_dict_group_empty_offset162276 to i64
  %generic_dict_group_empty_unwrapped2278 = add i64 %generic_dict_group_start2239, %generic_dict_group_empty_offset2277
  %generic_dict_group_empty_slot2279 = and i64 %generic_dict_group_empty_unwrapped2278, %dict_capacity_mask2231
  %generic_dict_group_use_empty2280 = icmp eq i64 %generic_dict_group_captured_deleted2259, %set_grown_capacity2079
  %generic_dict_group_insertion_slot2281 = select i1 %generic_dict_group_use_empty2280, i64 %generic_dict_group_empty_slot2279, i64 %generic_dict_group_captured_deleted2259
  br label %bb_generic_dict_group_done524

bb_generic_dict_group_match521:
  br label %bb_generic_dict_group_done524

bb_generic_dict_group_next522:
  %generic_dict_group_next_probe2233 = add i64 %generic_dict_group_probe2235, 16
  %generic_dict_group_next_deleted2234 = add i64 %generic_dict_group_captured_deleted2259, 0
  br label %bb_generic_dict_group_find514

bb_generic_dict_group_miss523:
  %generic_dict_group_miss_no_deleted2282 = icmp eq i64 %generic_dict_group_deleted2236, %set_grown_capacity2079
  %generic_dict_group_miss_slot2283 = select i1 %generic_dict_group_miss_no_deleted2282, i64 0, i64 %generic_dict_group_deleted2236
  br label %bb_generic_dict_group_done524

bb_generic_dict_group_done524:
  %generic_dict_find_found2284 = phi i1 [ false, %bb_generic_dict_group_empty520 ], [ true, %bb_generic_dict_group_match521 ], [ false, %bb_generic_dict_group_miss523 ]
  %generic_dict_find_slot_result2285 = phi i64 [ %generic_dict_group_insertion_slot2281, %bb_generic_dict_group_empty520 ], [ %generic_dict_candidate_slot2266, %bb_generic_dict_group_match521 ], [ %generic_dict_group_miss_slot2283, %bb_generic_dict_group_miss523 ]
  br label %bb_generic_dict_insert_first_done511

bb_generic_dict_insert_first_done511:
  %generic_dict_insert_first_found2286 = phi i1 [ true, %bb_generic_dict_insert_first_match508 ], [ false, %bb_generic_dict_insert_first_vacant510 ], [ %generic_dict_find_found2284, %bb_generic_dict_group_done524 ], [ false, %bb_generic_dict_insert_no_capacity513 ]
  %generic_dict_insert_first_slot_result2287 = phi i64 [ %dict_start_slot2209, %bb_generic_dict_insert_first_match508 ], [ %dict_start_slot2209, %bb_generic_dict_insert_first_vacant510 ], [ %generic_dict_find_slot_result2285, %bb_generic_dict_group_done524 ], [ 0, %bb_generic_dict_insert_no_capacity513 ]
  %set_key_entries_offset_mirror2288 = add i64 %set_grown_capacity2079, 23
  %set_key_entries_offset2289 = and i64 %set_key_entries_offset_mirror2288, -8
  %set_key_entries2290 = getelementptr i8, ptr %heap2084, i64 %set_key_entries_offset2289
  %set_key_entry_offset2291 = mul i64 %generic_dict_insert_first_slot_result2287, 4
  %set_key_slot2292 = getelementptr i8, ptr %set_key_entries2290, i64 %set_key_entry_offset2291
  store i32 6, ptr %set_key_slot2292, align 4
  %generic_dict_control_slot2293 = getelementptr i8, ptr %heap2084, i64 %generic_dict_insert_first_slot_result2287
  store i8 %dict_h2_byte2207, ptr %generic_dict_control_slot2293, align 1
  %generic_dict_control_mirrored2294 = icmp ult i64 %generic_dict_insert_first_slot_result2287, 16
  br i1 %generic_dict_control_mirrored2294, label %bb_generic_dict_control_mirror525, label %bb_generic_dict_control_done526

bb_generic_dict_control_mirror525:
  %generic_dict_control_mirror_index2295 = add i64 %set_grown_capacity2079, %generic_dict_insert_first_slot_result2287
  %generic_dict_control_mirror_slot2296 = getelementptr i8, ptr %heap2084, i64 %generic_dict_control_mirror_index2295
  store i8 %dict_h2_byte2207, ptr %generic_dict_control_mirror_slot2296, align 1
  br label %bb_generic_dict_control_done526

bb_generic_dict_control_done526:
  br label %bb_set_insert_done475

bb_set_insert_done475:
  %set_pointer2297 = phi ptr [ %mutable_ptr1974, %bb_set_insert_duplicate471 ], [ %mutable_ptr1974, %bb_generic_dict_control_done477 ], [ %heap2084, %bb_generic_dict_control_done526 ]
  %set_length2298 = phi i64 [ %mutable_len1975, %bb_set_insert_duplicate471 ], [ %set_insert_length2066, %bb_generic_dict_control_done477 ], [ %set_insert_length2066, %bb_generic_dict_control_done526 ]
  %set_capacity2299 = phi i64 [ %mutable_capacity1976, %bb_set_insert_duplicate471 ], [ %mutable_capacity1976, %bb_generic_dict_control_done477 ], [ %set_grown_capacity2079, %bb_generic_dict_control_done526 ]
  %set_inserted2300 = phi i1 [ false, %bb_set_insert_duplicate471 ], [ true, %bb_generic_dict_control_done477 ], [ true, %bb_generic_dict_control_done526 ]
  store ptr %set_pointer2297, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length2298, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity2299, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr2301 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len2302 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity2303 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key2304 = sext i32 7 to i64
  %hash_high2306 = lshr i64 %hash_key2304, 32
  %hash_fold2305 = xor i64 %hash_key2304, %hash_high2306
  %hash2307 = mul i64 %hash_fold2305, -7046029254386353131
  %dict_h2_shifted2308 = lshr i64 %hash2307, 57
  %dict_h2_raw2309 = and i64 %dict_h2_shifted2308, 127
  %dict_h2_zero2310 = icmp eq i64 %dict_h2_raw2309, 0
  %dict_h22311 = select i1 %dict_h2_zero2310, i64 1, i64 %dict_h2_raw2309
  %dict_h2_byte2312 = trunc i64 %dict_h22311 to i8
  %dict_capacity_mask2313 = sub i64 %mutable_capacity2303, 1
  %dict_start_slot2314 = and i64 %hash2307, %dict_capacity_mask2313
  %generic_dict_insert_has_capacity2315 = icmp ugt i64 %mutable_capacity2303, 0
  br i1 %generic_dict_insert_has_capacity2315, label %bb_generic_dict_insert_first533, label %bb_generic_dict_insert_no_capacity534

bb_generic_dict_insert_no_capacity534:
  br label %bb_generic_dict_insert_first_done532

bb_generic_dict_insert_first533:
  %generic_dict_control_slot2316 = getelementptr i8, ptr %mutable_ptr2301, i64 %dict_start_slot2314
  %generic_dict_control2317 = load i8, ptr %generic_dict_control_slot2316, align 1
  %generic_dict_insert_first_empty2318 = icmp eq i8 %generic_dict_control2317, 0
  br i1 %generic_dict_insert_first_empty2318, label %bb_generic_dict_insert_first_vacant531, label %bb_generic_dict_insert_first_occupied527

bb_generic_dict_insert_first_occupied527:
  %generic_dict_insert_first_h22319 = icmp eq i8 %generic_dict_control2317, %dict_h2_byte2312
  br i1 %generic_dict_insert_first_h22319, label %bb_generic_dict_insert_first_compare528, label %bb_generic_dict_insert_first_fallback530

bb_generic_dict_insert_first_compare528:
  %generic_dict_insert_first_key_entries_offset_mirror2320 = add i64 %mutable_capacity2303, 23
  %generic_dict_insert_first_key_entries_offset2321 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2320, -8
  %generic_dict_insert_first_key_entries2322 = getelementptr i8, ptr %mutable_ptr2301, i64 %generic_dict_insert_first_key_entries_offset2321
  %generic_dict_insert_first_key_entry_offset2323 = mul i64 %dict_start_slot2314, 4
  %generic_dict_insert_first_key_slot2324 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2322, i64 %generic_dict_insert_first_key_entry_offset2323
  %generic_dict_insert_first_key2325 = load i32, ptr %generic_dict_insert_first_key_slot2324, align 4
  %generic_dict_key_equal2326 = icmp eq i32 %generic_dict_insert_first_key2325, 7
  br i1 %generic_dict_key_equal2326, label %bb_generic_dict_insert_first_match529, label %bb_generic_dict_insert_first_fallback530

bb_generic_dict_insert_first_match529:
  br label %bb_generic_dict_insert_first_done532

bb_generic_dict_insert_first_vacant531:
  br label %bb_generic_dict_insert_first_done532

bb_generic_dict_insert_first_fallback530:
  %hash_key2327 = sext i32 7 to i64
  %hash_high2329 = lshr i64 %hash_key2327, 32
  %hash_fold2328 = xor i64 %hash_key2327, %hash_high2329
  %hash2330 = mul i64 %hash_fold2328, -7046029254386353131
  %dict_h2_shifted2331 = lshr i64 %hash2330, 57
  %dict_h2_raw2332 = and i64 %dict_h2_shifted2331, 127
  %dict_h2_zero2333 = icmp eq i64 %dict_h2_raw2332, 0
  %dict_h22334 = select i1 %dict_h2_zero2333, i64 1, i64 %dict_h2_raw2332
  %dict_h2_byte2335 = trunc i64 %dict_h22334 to i8
  %dict_capacity_mask2336 = sub i64 %mutable_capacity2303, 1
  %dict_start_slot2337 = and i64 %hash2330, %dict_capacity_mask2336
  br label %bb_generic_dict_group_find535

bb_generic_dict_group_find535:
  %generic_dict_group_probe2340 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback530 ], [ %generic_dict_group_next_probe2338, %bb_generic_dict_group_next543 ]
  %generic_dict_group_deleted2341 = phi i64 [ %mutable_capacity2303, %bb_generic_dict_insert_first_fallback530 ], [ %generic_dict_group_next_deleted2339, %bb_generic_dict_group_next543 ]
  %generic_dict_group_active2342 = icmp ult i64 %generic_dict_group_probe2340, %mutable_capacity2303
  br i1 %generic_dict_group_active2342, label %bb_generic_dict_group_body536, label %bb_generic_dict_group_miss544

bb_generic_dict_group_body536:
  %generic_dict_group_unwrapped2343 = add i64 %dict_start_slot2337, %generic_dict_group_probe2340
  %generic_dict_group_start2344 = and i64 %generic_dict_group_unwrapped2343, %dict_capacity_mask2336
  %generic_dict_group_pointer2345 = getelementptr i8, ptr %mutable_ptr2301, i64 %generic_dict_group_start2344
  %generic_dict_group_controls2346 = load <16 x i8>, ptr %generic_dict_group_pointer2345, align 1
  %generic_dict_group_h2_seed2347 = insertelement <16 x i8> poison, i8 %dict_h2_byte2335, i64 0
  %generic_dict_group_h2_vector2348 = shufflevector <16 x i8> %generic_dict_group_h2_seed2347, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2349 = icmp eq <16 x i8> %generic_dict_group_controls2346, %generic_dict_group_h2_vector2348
  %generic_dict_group_match_bits2350 = bitcast <16 x i1> %generic_dict_group_matches_vector2349 to i16
  %generic_dict_group_empty_vector2351 = icmp eq <16 x i8> %generic_dict_group_controls2346, zeroinitializer
  %generic_dict_group_empty_bits2352 = bitcast <16 x i1> %generic_dict_group_empty_vector2351 to i16
  %generic_dict_group_deleted_seed2353 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2354 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2353, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2355 = icmp eq <16 x i8> %generic_dict_group_controls2346, %generic_dict_group_deleted_vector2354
  %generic_dict_group_deleted_bits2356 = bitcast <16 x i1> %generic_dict_group_deleted_matches2355 to i16
  %generic_dict_group_has_deleted2357 = icmp ne i16 %generic_dict_group_deleted_bits2356, 0
  %generic_dict_group_no_previous_deleted2358 = icmp eq i64 %generic_dict_group_deleted2341, %mutable_capacity2303
  %generic_dict_group_capture_deleted2359 = and i1 %generic_dict_group_has_deleted2357, %generic_dict_group_no_previous_deleted2358
  %generic_dict_group_deleted_offset162360 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2356, i1 false)
  %generic_dict_group_deleted_offset2361 = zext i16 %generic_dict_group_deleted_offset162360 to i64
  %generic_dict_group_deleted_unwrapped2362 = add i64 %generic_dict_group_start2344, %generic_dict_group_deleted_offset2361
  %generic_dict_group_deleted_slot2363 = and i64 %generic_dict_group_deleted_unwrapped2362, %dict_capacity_mask2336
  %generic_dict_group_captured_deleted2364 = select i1 %generic_dict_group_capture_deleted2359, i64 %generic_dict_group_deleted_slot2363, i64 %generic_dict_group_deleted2341
  br label %bb_generic_dict_candidate_loop537

bb_generic_dict_candidate_loop537:
  %generic_dict_candidate_bits2365 = phi i16 [ %generic_dict_group_match_bits2350, %bb_generic_dict_group_body536 ], [ %generic_dict_candidate_cleared_bits2366, %bb_generic_dict_candidate_next539 ]
  %generic_dict_has_candidate2367 = icmp ne i16 %generic_dict_candidate_bits2365, 0
  br i1 %generic_dict_has_candidate2367, label %bb_generic_dict_candidate_body538, label %bb_generic_dict_group_decision540

bb_generic_dict_candidate_body538:
  %generic_dict_candidate_offset162368 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2365, i1 false)
  %generic_dict_candidate_offset2369 = zext i16 %generic_dict_candidate_offset162368 to i64
  %generic_dict_candidate_unwrapped2370 = add i64 %generic_dict_group_start2344, %generic_dict_candidate_offset2369
  %generic_dict_candidate_slot2371 = and i64 %generic_dict_candidate_unwrapped2370, %dict_capacity_mask2336
  %generic_dict_key_entries_offset_mirror2372 = add i64 %mutable_capacity2303, 23
  %generic_dict_key_entries_offset2373 = and i64 %generic_dict_key_entries_offset_mirror2372, -8
  %generic_dict_key_entries2374 = getelementptr i8, ptr %mutable_ptr2301, i64 %generic_dict_key_entries_offset2373
  %generic_dict_key_entry_offset2375 = mul i64 %generic_dict_candidate_slot2371, 4
  %generic_dict_key_slot2376 = getelementptr i8, ptr %generic_dict_key_entries2374, i64 %generic_dict_key_entry_offset2375
  %generic_dict_key2377 = load i32, ptr %generic_dict_key_slot2376, align 4
  %generic_dict_key_equal2378 = icmp eq i32 %generic_dict_key2377, 7
  br i1 %generic_dict_key_equal2378, label %bb_generic_dict_group_match542, label %bb_generic_dict_candidate_next539

bb_generic_dict_candidate_next539:
  %generic_dict_candidate_bits_minus_one2379 = sub i16 %generic_dict_candidate_bits2365, 1
  %generic_dict_candidate_cleared_bits2366 = and i16 %generic_dict_candidate_bits2365, %generic_dict_candidate_bits_minus_one2379
  br label %bb_generic_dict_candidate_loop537

bb_generic_dict_group_decision540:
  %generic_dict_group_has_empty2380 = icmp ne i16 %generic_dict_group_empty_bits2352, 0
  br i1 %generic_dict_group_has_empty2380, label %bb_generic_dict_group_empty541, label %bb_generic_dict_group_next543

bb_generic_dict_group_empty541:
  %generic_dict_group_empty_offset162381 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2352, i1 false)
  %generic_dict_group_empty_offset2382 = zext i16 %generic_dict_group_empty_offset162381 to i64
  %generic_dict_group_empty_unwrapped2383 = add i64 %generic_dict_group_start2344, %generic_dict_group_empty_offset2382
  %generic_dict_group_empty_slot2384 = and i64 %generic_dict_group_empty_unwrapped2383, %dict_capacity_mask2336
  %generic_dict_group_use_empty2385 = icmp eq i64 %generic_dict_group_captured_deleted2364, %mutable_capacity2303
  %generic_dict_group_insertion_slot2386 = select i1 %generic_dict_group_use_empty2385, i64 %generic_dict_group_empty_slot2384, i64 %generic_dict_group_captured_deleted2364
  br label %bb_generic_dict_group_done545

bb_generic_dict_group_match542:
  br label %bb_generic_dict_group_done545

bb_generic_dict_group_next543:
  %generic_dict_group_next_probe2338 = add i64 %generic_dict_group_probe2340, 16
  %generic_dict_group_next_deleted2339 = add i64 %generic_dict_group_captured_deleted2364, 0
  br label %bb_generic_dict_group_find535

bb_generic_dict_group_miss544:
  %generic_dict_group_miss_no_deleted2387 = icmp eq i64 %generic_dict_group_deleted2341, %mutable_capacity2303
  %generic_dict_group_miss_slot2388 = select i1 %generic_dict_group_miss_no_deleted2387, i64 0, i64 %generic_dict_group_deleted2341
  br label %bb_generic_dict_group_done545

bb_generic_dict_group_done545:
  %generic_dict_find_found2389 = phi i1 [ false, %bb_generic_dict_group_empty541 ], [ true, %bb_generic_dict_group_match542 ], [ false, %bb_generic_dict_group_miss544 ]
  %generic_dict_find_slot_result2390 = phi i64 [ %generic_dict_group_insertion_slot2386, %bb_generic_dict_group_empty541 ], [ %generic_dict_candidate_slot2371, %bb_generic_dict_group_match542 ], [ %generic_dict_group_miss_slot2388, %bb_generic_dict_group_miss544 ]
  br label %bb_generic_dict_insert_first_done532

bb_generic_dict_insert_first_done532:
  %generic_dict_insert_first_found2391 = phi i1 [ true, %bb_generic_dict_insert_first_match529 ], [ false, %bb_generic_dict_insert_first_vacant531 ], [ %generic_dict_find_found2389, %bb_generic_dict_group_done545 ], [ false, %bb_generic_dict_insert_no_capacity534 ]
  %generic_dict_insert_first_slot_result2392 = phi i64 [ %dict_start_slot2314, %bb_generic_dict_insert_first_match529 ], [ %dict_start_slot2314, %bb_generic_dict_insert_first_vacant531 ], [ %generic_dict_find_slot_result2390, %bb_generic_dict_group_done545 ], [ 0, %bb_generic_dict_insert_no_capacity534 ]
  br i1 %generic_dict_insert_first_found2391, label %bb_set_insert_duplicate546, label %bb_set_insert_new547

bb_set_insert_duplicate546:
  br label %bb_set_insert_done550

bb_set_insert_new547:
  %set_insert_length2393 = add i64 %mutable_len2302, 1
  %set_insert_load_num2394 = mul i64 %set_insert_length2393, 8
  %set_insert_load_den2395 = mul i64 %mutable_capacity2303, 7
  %set_insert_should_grow2396 = icmp ugt i64 %set_insert_load_num2394, %set_insert_load_den2395
  br i1 %set_insert_should_grow2396, label %bb_set_insert_grow549, label %bb_set_insert_current548

bb_set_insert_current548:
  %set_key_entries_offset_mirror2397 = add i64 %mutable_capacity2303, 23
  %set_key_entries_offset2398 = and i64 %set_key_entries_offset_mirror2397, -8
  %set_key_entries2399 = getelementptr i8, ptr %mutable_ptr2301, i64 %set_key_entries_offset2398
  %set_key_entry_offset2400 = mul i64 %generic_dict_insert_first_slot_result2392, 4
  %set_key_slot2401 = getelementptr i8, ptr %set_key_entries2399, i64 %set_key_entry_offset2400
  store i32 7, ptr %set_key_slot2401, align 4
  %generic_dict_control_slot2402 = getelementptr i8, ptr %mutable_ptr2301, i64 %generic_dict_insert_first_slot_result2392
  store i8 %dict_h2_byte2312, ptr %generic_dict_control_slot2402, align 1
  %generic_dict_control_mirrored2403 = icmp ult i64 %generic_dict_insert_first_slot_result2392, 16
  br i1 %generic_dict_control_mirrored2403, label %bb_generic_dict_control_mirror551, label %bb_generic_dict_control_done552

bb_generic_dict_control_mirror551:
  %generic_dict_control_mirror_index2404 = add i64 %mutable_capacity2303, %generic_dict_insert_first_slot_result2392
  %generic_dict_control_mirror_slot2405 = getelementptr i8, ptr %mutable_ptr2301, i64 %generic_dict_control_mirror_index2404
  store i8 %dict_h2_byte2312, ptr %generic_dict_control_mirror_slot2405, align 1
  br label %bb_generic_dict_control_done552

bb_generic_dict_control_done552:
  br label %bb_set_insert_done550

bb_set_insert_grow549:
  %set_grown_capacity2406 = mul i64 %mutable_capacity2303, 2
  %generic_dict_entries_offset_mirror2407 = add i64 %set_grown_capacity2406, 23
  %generic_dict_entries_offset2408 = and i64 %generic_dict_entries_offset_mirror2407, -8
  %generic_dict_entries_bytes2409 = mul i64 %set_grown_capacity2406, 4
  %generic_dict_bytes2410 = add i64 %generic_dict_entries_offset2408, %generic_dict_entries_bytes2409
  %heap2411 = call ptr @sollang_alloc(i64 %generic_dict_bytes2410)
  %heap_ok2412 = icmp ne ptr %heap2411, null
  br i1 %heap_ok2412, label %bb_alloc_ok553, label %bb_alloc_fail554

bb_alloc_fail554:
  %trap_stderr2413 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr2413, ptr @.slg.str.module.x.8, i32 25, ptr %trap_written2414, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok553:
  %generic_dict_control_bytes2415 = add i64 %set_grown_capacity2406, 16
  call void @llvm.memset.p0.i64(ptr %heap2411, i8 0, i64 %generic_dict_control_bytes2415, i1 false)
  br label %bb_set_rehash555

bb_set_rehash555:
  %set_rehash_index2417 = phi i64 [ 0, %bb_alloc_ok553 ], [ %set_rehash_next_index2416, %bb_set_rehash_next558 ]
  %set_rehash_active2418 = icmp ult i64 %set_rehash_index2417, %mutable_capacity2303
  br i1 %set_rehash_active2418, label %bb_set_rehash_body556, label %bb_set_rehash_done559

bb_set_rehash_body556:
  %generic_dict_control_slot2419 = getelementptr i8, ptr %mutable_ptr2301, i64 %set_rehash_index2417
  %generic_dict_control2420 = load i8, ptr %generic_dict_control_slot2419, align 1
  %set_rehash_occupied2421 = icmp sgt i8 %generic_dict_control2420, 0
  br i1 %set_rehash_occupied2421, label %bb_set_rehash_move557, label %bb_set_rehash_next558

bb_set_rehash_move557:
  %set_rehash_key_entries_offset_mirror2422 = add i64 %mutable_capacity2303, 23
  %set_rehash_key_entries_offset2423 = and i64 %set_rehash_key_entries_offset_mirror2422, -8
  %set_rehash_key_entries2424 = getelementptr i8, ptr %mutable_ptr2301, i64 %set_rehash_key_entries_offset2423
  %set_rehash_key_entry_offset2425 = mul i64 %set_rehash_index2417, 4
  %set_rehash_key_slot2426 = getelementptr i8, ptr %set_rehash_key_entries2424, i64 %set_rehash_key_entry_offset2425
  %set_rehash_key2427 = load i32, ptr %set_rehash_key_slot2426, align 4
  %hash_key2428 = sext i32 %set_rehash_key2427 to i64
  %hash_high2430 = lshr i64 %hash_key2428, 32
  %hash_fold2429 = xor i64 %hash_key2428, %hash_high2430
  %hash2431 = mul i64 %hash_fold2429, -7046029254386353131
  %dict_h2_shifted2432 = lshr i64 %hash2431, 57
  %dict_h2_raw2433 = and i64 %dict_h2_shifted2432, 127
  %dict_h2_zero2434 = icmp eq i64 %dict_h2_raw2433, 0
  %dict_h22435 = select i1 %dict_h2_zero2434, i64 1, i64 %dict_h2_raw2433
  %dict_h2_byte2436 = trunc i64 %dict_h22435 to i8
  %dict_capacity_mask2437 = sub i64 %set_grown_capacity2406, 1
  %dict_start_slot2438 = and i64 %hash2431, %dict_capacity_mask2437
  %generic_dict_insert_has_capacity2439 = icmp ugt i64 %set_grown_capacity2406, 0
  br i1 %generic_dict_insert_has_capacity2439, label %bb_generic_dict_insert_first566, label %bb_generic_dict_insert_no_capacity567

bb_generic_dict_insert_no_capacity567:
  br label %bb_generic_dict_insert_first_done565

bb_generic_dict_insert_first566:
  %generic_dict_control_slot2440 = getelementptr i8, ptr %heap2411, i64 %dict_start_slot2438
  %generic_dict_control2441 = load i8, ptr %generic_dict_control_slot2440, align 1
  %generic_dict_insert_first_empty2442 = icmp eq i8 %generic_dict_control2441, 0
  br i1 %generic_dict_insert_first_empty2442, label %bb_generic_dict_insert_first_vacant564, label %bb_generic_dict_insert_first_occupied560

bb_generic_dict_insert_first_occupied560:
  %generic_dict_insert_first_h22443 = icmp eq i8 %generic_dict_control2441, %dict_h2_byte2436
  br i1 %generic_dict_insert_first_h22443, label %bb_generic_dict_insert_first_compare561, label %bb_generic_dict_insert_first_fallback563

bb_generic_dict_insert_first_compare561:
  %generic_dict_insert_first_key_entries_offset_mirror2444 = add i64 %set_grown_capacity2406, 23
  %generic_dict_insert_first_key_entries_offset2445 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2444, -8
  %generic_dict_insert_first_key_entries2446 = getelementptr i8, ptr %heap2411, i64 %generic_dict_insert_first_key_entries_offset2445
  %generic_dict_insert_first_key_entry_offset2447 = mul i64 %dict_start_slot2438, 4
  %generic_dict_insert_first_key_slot2448 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2446, i64 %generic_dict_insert_first_key_entry_offset2447
  %generic_dict_insert_first_key2449 = load i32, ptr %generic_dict_insert_first_key_slot2448, align 4
  %generic_dict_key_equal2450 = icmp eq i32 %generic_dict_insert_first_key2449, %set_rehash_key2427
  br i1 %generic_dict_key_equal2450, label %bb_generic_dict_insert_first_match562, label %bb_generic_dict_insert_first_fallback563

bb_generic_dict_insert_first_match562:
  br label %bb_generic_dict_insert_first_done565

bb_generic_dict_insert_first_vacant564:
  br label %bb_generic_dict_insert_first_done565

bb_generic_dict_insert_first_fallback563:
  %hash_key2451 = sext i32 %set_rehash_key2427 to i64
  %hash_high2453 = lshr i64 %hash_key2451, 32
  %hash_fold2452 = xor i64 %hash_key2451, %hash_high2453
  %hash2454 = mul i64 %hash_fold2452, -7046029254386353131
  %dict_h2_shifted2455 = lshr i64 %hash2454, 57
  %dict_h2_raw2456 = and i64 %dict_h2_shifted2455, 127
  %dict_h2_zero2457 = icmp eq i64 %dict_h2_raw2456, 0
  %dict_h22458 = select i1 %dict_h2_zero2457, i64 1, i64 %dict_h2_raw2456
  %dict_h2_byte2459 = trunc i64 %dict_h22458 to i8
  %dict_capacity_mask2460 = sub i64 %set_grown_capacity2406, 1
  %dict_start_slot2461 = and i64 %hash2454, %dict_capacity_mask2460
  br label %bb_generic_dict_group_find568

bb_generic_dict_group_find568:
  %generic_dict_group_probe2464 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback563 ], [ %generic_dict_group_next_probe2462, %bb_generic_dict_group_next576 ]
  %generic_dict_group_deleted2465 = phi i64 [ %set_grown_capacity2406, %bb_generic_dict_insert_first_fallback563 ], [ %generic_dict_group_next_deleted2463, %bb_generic_dict_group_next576 ]
  %generic_dict_group_active2466 = icmp ult i64 %generic_dict_group_probe2464, %set_grown_capacity2406
  br i1 %generic_dict_group_active2466, label %bb_generic_dict_group_body569, label %bb_generic_dict_group_miss577

bb_generic_dict_group_body569:
  %generic_dict_group_unwrapped2467 = add i64 %dict_start_slot2461, %generic_dict_group_probe2464
  %generic_dict_group_start2468 = and i64 %generic_dict_group_unwrapped2467, %dict_capacity_mask2460
  %generic_dict_group_pointer2469 = getelementptr i8, ptr %heap2411, i64 %generic_dict_group_start2468
  %generic_dict_group_controls2470 = load <16 x i8>, ptr %generic_dict_group_pointer2469, align 1
  %generic_dict_group_h2_seed2471 = insertelement <16 x i8> poison, i8 %dict_h2_byte2459, i64 0
  %generic_dict_group_h2_vector2472 = shufflevector <16 x i8> %generic_dict_group_h2_seed2471, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2473 = icmp eq <16 x i8> %generic_dict_group_controls2470, %generic_dict_group_h2_vector2472
  %generic_dict_group_match_bits2474 = bitcast <16 x i1> %generic_dict_group_matches_vector2473 to i16
  %generic_dict_group_empty_vector2475 = icmp eq <16 x i8> %generic_dict_group_controls2470, zeroinitializer
  %generic_dict_group_empty_bits2476 = bitcast <16 x i1> %generic_dict_group_empty_vector2475 to i16
  %generic_dict_group_deleted_seed2477 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2478 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2477, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2479 = icmp eq <16 x i8> %generic_dict_group_controls2470, %generic_dict_group_deleted_vector2478
  %generic_dict_group_deleted_bits2480 = bitcast <16 x i1> %generic_dict_group_deleted_matches2479 to i16
  %generic_dict_group_has_deleted2481 = icmp ne i16 %generic_dict_group_deleted_bits2480, 0
  %generic_dict_group_no_previous_deleted2482 = icmp eq i64 %generic_dict_group_deleted2465, %set_grown_capacity2406
  %generic_dict_group_capture_deleted2483 = and i1 %generic_dict_group_has_deleted2481, %generic_dict_group_no_previous_deleted2482
  %generic_dict_group_deleted_offset162484 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2480, i1 false)
  %generic_dict_group_deleted_offset2485 = zext i16 %generic_dict_group_deleted_offset162484 to i64
  %generic_dict_group_deleted_unwrapped2486 = add i64 %generic_dict_group_start2468, %generic_dict_group_deleted_offset2485
  %generic_dict_group_deleted_slot2487 = and i64 %generic_dict_group_deleted_unwrapped2486, %dict_capacity_mask2460
  %generic_dict_group_captured_deleted2488 = select i1 %generic_dict_group_capture_deleted2483, i64 %generic_dict_group_deleted_slot2487, i64 %generic_dict_group_deleted2465
  br label %bb_generic_dict_candidate_loop570

bb_generic_dict_candidate_loop570:
  %generic_dict_candidate_bits2489 = phi i16 [ %generic_dict_group_match_bits2474, %bb_generic_dict_group_body569 ], [ %generic_dict_candidate_cleared_bits2490, %bb_generic_dict_candidate_next572 ]
  %generic_dict_has_candidate2491 = icmp ne i16 %generic_dict_candidate_bits2489, 0
  br i1 %generic_dict_has_candidate2491, label %bb_generic_dict_candidate_body571, label %bb_generic_dict_group_decision573

bb_generic_dict_candidate_body571:
  %generic_dict_candidate_offset162492 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2489, i1 false)
  %generic_dict_candidate_offset2493 = zext i16 %generic_dict_candidate_offset162492 to i64
  %generic_dict_candidate_unwrapped2494 = add i64 %generic_dict_group_start2468, %generic_dict_candidate_offset2493
  %generic_dict_candidate_slot2495 = and i64 %generic_dict_candidate_unwrapped2494, %dict_capacity_mask2460
  %generic_dict_key_entries_offset_mirror2496 = add i64 %set_grown_capacity2406, 23
  %generic_dict_key_entries_offset2497 = and i64 %generic_dict_key_entries_offset_mirror2496, -8
  %generic_dict_key_entries2498 = getelementptr i8, ptr %heap2411, i64 %generic_dict_key_entries_offset2497
  %generic_dict_key_entry_offset2499 = mul i64 %generic_dict_candidate_slot2495, 4
  %generic_dict_key_slot2500 = getelementptr i8, ptr %generic_dict_key_entries2498, i64 %generic_dict_key_entry_offset2499
  %generic_dict_key2501 = load i32, ptr %generic_dict_key_slot2500, align 4
  %generic_dict_key_equal2502 = icmp eq i32 %generic_dict_key2501, %set_rehash_key2427
  br i1 %generic_dict_key_equal2502, label %bb_generic_dict_group_match575, label %bb_generic_dict_candidate_next572

bb_generic_dict_candidate_next572:
  %generic_dict_candidate_bits_minus_one2503 = sub i16 %generic_dict_candidate_bits2489, 1
  %generic_dict_candidate_cleared_bits2490 = and i16 %generic_dict_candidate_bits2489, %generic_dict_candidate_bits_minus_one2503
  br label %bb_generic_dict_candidate_loop570

bb_generic_dict_group_decision573:
  %generic_dict_group_has_empty2504 = icmp ne i16 %generic_dict_group_empty_bits2476, 0
  br i1 %generic_dict_group_has_empty2504, label %bb_generic_dict_group_empty574, label %bb_generic_dict_group_next576

bb_generic_dict_group_empty574:
  %generic_dict_group_empty_offset162505 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2476, i1 false)
  %generic_dict_group_empty_offset2506 = zext i16 %generic_dict_group_empty_offset162505 to i64
  %generic_dict_group_empty_unwrapped2507 = add i64 %generic_dict_group_start2468, %generic_dict_group_empty_offset2506
  %generic_dict_group_empty_slot2508 = and i64 %generic_dict_group_empty_unwrapped2507, %dict_capacity_mask2460
  %generic_dict_group_use_empty2509 = icmp eq i64 %generic_dict_group_captured_deleted2488, %set_grown_capacity2406
  %generic_dict_group_insertion_slot2510 = select i1 %generic_dict_group_use_empty2509, i64 %generic_dict_group_empty_slot2508, i64 %generic_dict_group_captured_deleted2488
  br label %bb_generic_dict_group_done578

bb_generic_dict_group_match575:
  br label %bb_generic_dict_group_done578

bb_generic_dict_group_next576:
  %generic_dict_group_next_probe2462 = add i64 %generic_dict_group_probe2464, 16
  %generic_dict_group_next_deleted2463 = add i64 %generic_dict_group_captured_deleted2488, 0
  br label %bb_generic_dict_group_find568

bb_generic_dict_group_miss577:
  %generic_dict_group_miss_no_deleted2511 = icmp eq i64 %generic_dict_group_deleted2465, %set_grown_capacity2406
  %generic_dict_group_miss_slot2512 = select i1 %generic_dict_group_miss_no_deleted2511, i64 0, i64 %generic_dict_group_deleted2465
  br label %bb_generic_dict_group_done578

bb_generic_dict_group_done578:
  %generic_dict_find_found2513 = phi i1 [ false, %bb_generic_dict_group_empty574 ], [ true, %bb_generic_dict_group_match575 ], [ false, %bb_generic_dict_group_miss577 ]
  %generic_dict_find_slot_result2514 = phi i64 [ %generic_dict_group_insertion_slot2510, %bb_generic_dict_group_empty574 ], [ %generic_dict_candidate_slot2495, %bb_generic_dict_group_match575 ], [ %generic_dict_group_miss_slot2512, %bb_generic_dict_group_miss577 ]
  br label %bb_generic_dict_insert_first_done565

bb_generic_dict_insert_first_done565:
  %generic_dict_insert_first_found2515 = phi i1 [ true, %bb_generic_dict_insert_first_match562 ], [ false, %bb_generic_dict_insert_first_vacant564 ], [ %generic_dict_find_found2513, %bb_generic_dict_group_done578 ], [ false, %bb_generic_dict_insert_no_capacity567 ]
  %generic_dict_insert_first_slot_result2516 = phi i64 [ %dict_start_slot2438, %bb_generic_dict_insert_first_match562 ], [ %dict_start_slot2438, %bb_generic_dict_insert_first_vacant564 ], [ %generic_dict_find_slot_result2514, %bb_generic_dict_group_done578 ], [ 0, %bb_generic_dict_insert_no_capacity567 ]
  %set_key_entries_offset_mirror2517 = add i64 %set_grown_capacity2406, 23
  %set_key_entries_offset2518 = and i64 %set_key_entries_offset_mirror2517, -8
  %set_key_entries2519 = getelementptr i8, ptr %heap2411, i64 %set_key_entries_offset2518
  %set_key_entry_offset2520 = mul i64 %generic_dict_insert_first_slot_result2516, 4
  %set_key_slot2521 = getelementptr i8, ptr %set_key_entries2519, i64 %set_key_entry_offset2520
  store i32 %set_rehash_key2427, ptr %set_key_slot2521, align 4
  %generic_dict_control_slot2522 = getelementptr i8, ptr %heap2411, i64 %generic_dict_insert_first_slot_result2516
  store i8 %dict_h2_byte2436, ptr %generic_dict_control_slot2522, align 1
  %generic_dict_control_mirrored2523 = icmp ult i64 %generic_dict_insert_first_slot_result2516, 16
  br i1 %generic_dict_control_mirrored2523, label %bb_generic_dict_control_mirror579, label %bb_generic_dict_control_done580

bb_generic_dict_control_mirror579:
  %generic_dict_control_mirror_index2524 = add i64 %set_grown_capacity2406, %generic_dict_insert_first_slot_result2516
  %generic_dict_control_mirror_slot2525 = getelementptr i8, ptr %heap2411, i64 %generic_dict_control_mirror_index2524
  store i8 %dict_h2_byte2436, ptr %generic_dict_control_mirror_slot2525, align 1
  br label %bb_generic_dict_control_done580

bb_generic_dict_control_done580:
  br label %bb_set_rehash_next558

bb_set_rehash_next558:
  %set_rehash_next_index2416 = add i64 %set_rehash_index2417, 1
  br label %bb_set_rehash555

bb_set_rehash_done559:
  call void @sollang_free(ptr %mutable_ptr2301)
  %hash_key2526 = sext i32 7 to i64
  %hash_high2528 = lshr i64 %hash_key2526, 32
  %hash_fold2527 = xor i64 %hash_key2526, %hash_high2528
  %hash2529 = mul i64 %hash_fold2527, -7046029254386353131
  %dict_h2_shifted2530 = lshr i64 %hash2529, 57
  %dict_h2_raw2531 = and i64 %dict_h2_shifted2530, 127
  %dict_h2_zero2532 = icmp eq i64 %dict_h2_raw2531, 0
  %dict_h22533 = select i1 %dict_h2_zero2532, i64 1, i64 %dict_h2_raw2531
  %dict_h2_byte2534 = trunc i64 %dict_h22533 to i8
  %dict_capacity_mask2535 = sub i64 %set_grown_capacity2406, 1
  %dict_start_slot2536 = and i64 %hash2529, %dict_capacity_mask2535
  %generic_dict_insert_has_capacity2537 = icmp ugt i64 %set_grown_capacity2406, 0
  br i1 %generic_dict_insert_has_capacity2537, label %bb_generic_dict_insert_first587, label %bb_generic_dict_insert_no_capacity588

bb_generic_dict_insert_no_capacity588:
  br label %bb_generic_dict_insert_first_done586

bb_generic_dict_insert_first587:
  %generic_dict_control_slot2538 = getelementptr i8, ptr %heap2411, i64 %dict_start_slot2536
  %generic_dict_control2539 = load i8, ptr %generic_dict_control_slot2538, align 1
  %generic_dict_insert_first_empty2540 = icmp eq i8 %generic_dict_control2539, 0
  br i1 %generic_dict_insert_first_empty2540, label %bb_generic_dict_insert_first_vacant585, label %bb_generic_dict_insert_first_occupied581

bb_generic_dict_insert_first_occupied581:
  %generic_dict_insert_first_h22541 = icmp eq i8 %generic_dict_control2539, %dict_h2_byte2534
  br i1 %generic_dict_insert_first_h22541, label %bb_generic_dict_insert_first_compare582, label %bb_generic_dict_insert_first_fallback584

bb_generic_dict_insert_first_compare582:
  %generic_dict_insert_first_key_entries_offset_mirror2542 = add i64 %set_grown_capacity2406, 23
  %generic_dict_insert_first_key_entries_offset2543 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2542, -8
  %generic_dict_insert_first_key_entries2544 = getelementptr i8, ptr %heap2411, i64 %generic_dict_insert_first_key_entries_offset2543
  %generic_dict_insert_first_key_entry_offset2545 = mul i64 %dict_start_slot2536, 4
  %generic_dict_insert_first_key_slot2546 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2544, i64 %generic_dict_insert_first_key_entry_offset2545
  %generic_dict_insert_first_key2547 = load i32, ptr %generic_dict_insert_first_key_slot2546, align 4
  %generic_dict_key_equal2548 = icmp eq i32 %generic_dict_insert_first_key2547, 7
  br i1 %generic_dict_key_equal2548, label %bb_generic_dict_insert_first_match583, label %bb_generic_dict_insert_first_fallback584

bb_generic_dict_insert_first_match583:
  br label %bb_generic_dict_insert_first_done586

bb_generic_dict_insert_first_vacant585:
  br label %bb_generic_dict_insert_first_done586

bb_generic_dict_insert_first_fallback584:
  %hash_key2549 = sext i32 7 to i64
  %hash_high2551 = lshr i64 %hash_key2549, 32
  %hash_fold2550 = xor i64 %hash_key2549, %hash_high2551
  %hash2552 = mul i64 %hash_fold2550, -7046029254386353131
  %dict_h2_shifted2553 = lshr i64 %hash2552, 57
  %dict_h2_raw2554 = and i64 %dict_h2_shifted2553, 127
  %dict_h2_zero2555 = icmp eq i64 %dict_h2_raw2554, 0
  %dict_h22556 = select i1 %dict_h2_zero2555, i64 1, i64 %dict_h2_raw2554
  %dict_h2_byte2557 = trunc i64 %dict_h22556 to i8
  %dict_capacity_mask2558 = sub i64 %set_grown_capacity2406, 1
  %dict_start_slot2559 = and i64 %hash2552, %dict_capacity_mask2558
  br label %bb_generic_dict_group_find589

bb_generic_dict_group_find589:
  %generic_dict_group_probe2562 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback584 ], [ %generic_dict_group_next_probe2560, %bb_generic_dict_group_next597 ]
  %generic_dict_group_deleted2563 = phi i64 [ %set_grown_capacity2406, %bb_generic_dict_insert_first_fallback584 ], [ %generic_dict_group_next_deleted2561, %bb_generic_dict_group_next597 ]
  %generic_dict_group_active2564 = icmp ult i64 %generic_dict_group_probe2562, %set_grown_capacity2406
  br i1 %generic_dict_group_active2564, label %bb_generic_dict_group_body590, label %bb_generic_dict_group_miss598

bb_generic_dict_group_body590:
  %generic_dict_group_unwrapped2565 = add i64 %dict_start_slot2559, %generic_dict_group_probe2562
  %generic_dict_group_start2566 = and i64 %generic_dict_group_unwrapped2565, %dict_capacity_mask2558
  %generic_dict_group_pointer2567 = getelementptr i8, ptr %heap2411, i64 %generic_dict_group_start2566
  %generic_dict_group_controls2568 = load <16 x i8>, ptr %generic_dict_group_pointer2567, align 1
  %generic_dict_group_h2_seed2569 = insertelement <16 x i8> poison, i8 %dict_h2_byte2557, i64 0
  %generic_dict_group_h2_vector2570 = shufflevector <16 x i8> %generic_dict_group_h2_seed2569, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2571 = icmp eq <16 x i8> %generic_dict_group_controls2568, %generic_dict_group_h2_vector2570
  %generic_dict_group_match_bits2572 = bitcast <16 x i1> %generic_dict_group_matches_vector2571 to i16
  %generic_dict_group_empty_vector2573 = icmp eq <16 x i8> %generic_dict_group_controls2568, zeroinitializer
  %generic_dict_group_empty_bits2574 = bitcast <16 x i1> %generic_dict_group_empty_vector2573 to i16
  %generic_dict_group_deleted_seed2575 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2576 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2575, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2577 = icmp eq <16 x i8> %generic_dict_group_controls2568, %generic_dict_group_deleted_vector2576
  %generic_dict_group_deleted_bits2578 = bitcast <16 x i1> %generic_dict_group_deleted_matches2577 to i16
  %generic_dict_group_has_deleted2579 = icmp ne i16 %generic_dict_group_deleted_bits2578, 0
  %generic_dict_group_no_previous_deleted2580 = icmp eq i64 %generic_dict_group_deleted2563, %set_grown_capacity2406
  %generic_dict_group_capture_deleted2581 = and i1 %generic_dict_group_has_deleted2579, %generic_dict_group_no_previous_deleted2580
  %generic_dict_group_deleted_offset162582 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2578, i1 false)
  %generic_dict_group_deleted_offset2583 = zext i16 %generic_dict_group_deleted_offset162582 to i64
  %generic_dict_group_deleted_unwrapped2584 = add i64 %generic_dict_group_start2566, %generic_dict_group_deleted_offset2583
  %generic_dict_group_deleted_slot2585 = and i64 %generic_dict_group_deleted_unwrapped2584, %dict_capacity_mask2558
  %generic_dict_group_captured_deleted2586 = select i1 %generic_dict_group_capture_deleted2581, i64 %generic_dict_group_deleted_slot2585, i64 %generic_dict_group_deleted2563
  br label %bb_generic_dict_candidate_loop591

bb_generic_dict_candidate_loop591:
  %generic_dict_candidate_bits2587 = phi i16 [ %generic_dict_group_match_bits2572, %bb_generic_dict_group_body590 ], [ %generic_dict_candidate_cleared_bits2588, %bb_generic_dict_candidate_next593 ]
  %generic_dict_has_candidate2589 = icmp ne i16 %generic_dict_candidate_bits2587, 0
  br i1 %generic_dict_has_candidate2589, label %bb_generic_dict_candidate_body592, label %bb_generic_dict_group_decision594

bb_generic_dict_candidate_body592:
  %generic_dict_candidate_offset162590 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2587, i1 false)
  %generic_dict_candidate_offset2591 = zext i16 %generic_dict_candidate_offset162590 to i64
  %generic_dict_candidate_unwrapped2592 = add i64 %generic_dict_group_start2566, %generic_dict_candidate_offset2591
  %generic_dict_candidate_slot2593 = and i64 %generic_dict_candidate_unwrapped2592, %dict_capacity_mask2558
  %generic_dict_key_entries_offset_mirror2594 = add i64 %set_grown_capacity2406, 23
  %generic_dict_key_entries_offset2595 = and i64 %generic_dict_key_entries_offset_mirror2594, -8
  %generic_dict_key_entries2596 = getelementptr i8, ptr %heap2411, i64 %generic_dict_key_entries_offset2595
  %generic_dict_key_entry_offset2597 = mul i64 %generic_dict_candidate_slot2593, 4
  %generic_dict_key_slot2598 = getelementptr i8, ptr %generic_dict_key_entries2596, i64 %generic_dict_key_entry_offset2597
  %generic_dict_key2599 = load i32, ptr %generic_dict_key_slot2598, align 4
  %generic_dict_key_equal2600 = icmp eq i32 %generic_dict_key2599, 7
  br i1 %generic_dict_key_equal2600, label %bb_generic_dict_group_match596, label %bb_generic_dict_candidate_next593

bb_generic_dict_candidate_next593:
  %generic_dict_candidate_bits_minus_one2601 = sub i16 %generic_dict_candidate_bits2587, 1
  %generic_dict_candidate_cleared_bits2588 = and i16 %generic_dict_candidate_bits2587, %generic_dict_candidate_bits_minus_one2601
  br label %bb_generic_dict_candidate_loop591

bb_generic_dict_group_decision594:
  %generic_dict_group_has_empty2602 = icmp ne i16 %generic_dict_group_empty_bits2574, 0
  br i1 %generic_dict_group_has_empty2602, label %bb_generic_dict_group_empty595, label %bb_generic_dict_group_next597

bb_generic_dict_group_empty595:
  %generic_dict_group_empty_offset162603 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2574, i1 false)
  %generic_dict_group_empty_offset2604 = zext i16 %generic_dict_group_empty_offset162603 to i64
  %generic_dict_group_empty_unwrapped2605 = add i64 %generic_dict_group_start2566, %generic_dict_group_empty_offset2604
  %generic_dict_group_empty_slot2606 = and i64 %generic_dict_group_empty_unwrapped2605, %dict_capacity_mask2558
  %generic_dict_group_use_empty2607 = icmp eq i64 %generic_dict_group_captured_deleted2586, %set_grown_capacity2406
  %generic_dict_group_insertion_slot2608 = select i1 %generic_dict_group_use_empty2607, i64 %generic_dict_group_empty_slot2606, i64 %generic_dict_group_captured_deleted2586
  br label %bb_generic_dict_group_done599

bb_generic_dict_group_match596:
  br label %bb_generic_dict_group_done599

bb_generic_dict_group_next597:
  %generic_dict_group_next_probe2560 = add i64 %generic_dict_group_probe2562, 16
  %generic_dict_group_next_deleted2561 = add i64 %generic_dict_group_captured_deleted2586, 0
  br label %bb_generic_dict_group_find589

bb_generic_dict_group_miss598:
  %generic_dict_group_miss_no_deleted2609 = icmp eq i64 %generic_dict_group_deleted2563, %set_grown_capacity2406
  %generic_dict_group_miss_slot2610 = select i1 %generic_dict_group_miss_no_deleted2609, i64 0, i64 %generic_dict_group_deleted2563
  br label %bb_generic_dict_group_done599

bb_generic_dict_group_done599:
  %generic_dict_find_found2611 = phi i1 [ false, %bb_generic_dict_group_empty595 ], [ true, %bb_generic_dict_group_match596 ], [ false, %bb_generic_dict_group_miss598 ]
  %generic_dict_find_slot_result2612 = phi i64 [ %generic_dict_group_insertion_slot2608, %bb_generic_dict_group_empty595 ], [ %generic_dict_candidate_slot2593, %bb_generic_dict_group_match596 ], [ %generic_dict_group_miss_slot2610, %bb_generic_dict_group_miss598 ]
  br label %bb_generic_dict_insert_first_done586

bb_generic_dict_insert_first_done586:
  %generic_dict_insert_first_found2613 = phi i1 [ true, %bb_generic_dict_insert_first_match583 ], [ false, %bb_generic_dict_insert_first_vacant585 ], [ %generic_dict_find_found2611, %bb_generic_dict_group_done599 ], [ false, %bb_generic_dict_insert_no_capacity588 ]
  %generic_dict_insert_first_slot_result2614 = phi i64 [ %dict_start_slot2536, %bb_generic_dict_insert_first_match583 ], [ %dict_start_slot2536, %bb_generic_dict_insert_first_vacant585 ], [ %generic_dict_find_slot_result2612, %bb_generic_dict_group_done599 ], [ 0, %bb_generic_dict_insert_no_capacity588 ]
  %set_key_entries_offset_mirror2615 = add i64 %set_grown_capacity2406, 23
  %set_key_entries_offset2616 = and i64 %set_key_entries_offset_mirror2615, -8
  %set_key_entries2617 = getelementptr i8, ptr %heap2411, i64 %set_key_entries_offset2616
  %set_key_entry_offset2618 = mul i64 %generic_dict_insert_first_slot_result2614, 4
  %set_key_slot2619 = getelementptr i8, ptr %set_key_entries2617, i64 %set_key_entry_offset2618
  store i32 7, ptr %set_key_slot2619, align 4
  %generic_dict_control_slot2620 = getelementptr i8, ptr %heap2411, i64 %generic_dict_insert_first_slot_result2614
  store i8 %dict_h2_byte2534, ptr %generic_dict_control_slot2620, align 1
  %generic_dict_control_mirrored2621 = icmp ult i64 %generic_dict_insert_first_slot_result2614, 16
  br i1 %generic_dict_control_mirrored2621, label %bb_generic_dict_control_mirror600, label %bb_generic_dict_control_done601

bb_generic_dict_control_mirror600:
  %generic_dict_control_mirror_index2622 = add i64 %set_grown_capacity2406, %generic_dict_insert_first_slot_result2614
  %generic_dict_control_mirror_slot2623 = getelementptr i8, ptr %heap2411, i64 %generic_dict_control_mirror_index2622
  store i8 %dict_h2_byte2534, ptr %generic_dict_control_mirror_slot2623, align 1
  br label %bb_generic_dict_control_done601

bb_generic_dict_control_done601:
  br label %bb_set_insert_done550

bb_set_insert_done550:
  %set_pointer2624 = phi ptr [ %mutable_ptr2301, %bb_set_insert_duplicate546 ], [ %mutable_ptr2301, %bb_generic_dict_control_done552 ], [ %heap2411, %bb_generic_dict_control_done601 ]
  %set_length2625 = phi i64 [ %mutable_len2302, %bb_set_insert_duplicate546 ], [ %set_insert_length2393, %bb_generic_dict_control_done552 ], [ %set_insert_length2393, %bb_generic_dict_control_done601 ]
  %set_capacity2626 = phi i64 [ %mutable_capacity2303, %bb_set_insert_duplicate546 ], [ %mutable_capacity2303, %bb_generic_dict_control_done552 ], [ %set_grown_capacity2406, %bb_generic_dict_control_done601 ]
  %set_inserted2627 = phi i1 [ false, %bb_set_insert_duplicate546 ], [ true, %bb_generic_dict_control_done552 ], [ true, %bb_generic_dict_control_done601 ]
  store ptr %set_pointer2624, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length2625, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity2626, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr2628 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len2629 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity2630 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key2631 = sext i32 8 to i64
  %hash_high2633 = lshr i64 %hash_key2631, 32
  %hash_fold2632 = xor i64 %hash_key2631, %hash_high2633
  %hash2634 = mul i64 %hash_fold2632, -7046029254386353131
  %dict_h2_shifted2635 = lshr i64 %hash2634, 57
  %dict_h2_raw2636 = and i64 %dict_h2_shifted2635, 127
  %dict_h2_zero2637 = icmp eq i64 %dict_h2_raw2636, 0
  %dict_h22638 = select i1 %dict_h2_zero2637, i64 1, i64 %dict_h2_raw2636
  %dict_h2_byte2639 = trunc i64 %dict_h22638 to i8
  %dict_capacity_mask2640 = sub i64 %mutable_capacity2630, 1
  %dict_start_slot2641 = and i64 %hash2634, %dict_capacity_mask2640
  %generic_dict_insert_has_capacity2642 = icmp ugt i64 %mutable_capacity2630, 0
  br i1 %generic_dict_insert_has_capacity2642, label %bb_generic_dict_insert_first608, label %bb_generic_dict_insert_no_capacity609

bb_generic_dict_insert_no_capacity609:
  br label %bb_generic_dict_insert_first_done607

bb_generic_dict_insert_first608:
  %generic_dict_control_slot2643 = getelementptr i8, ptr %mutable_ptr2628, i64 %dict_start_slot2641
  %generic_dict_control2644 = load i8, ptr %generic_dict_control_slot2643, align 1
  %generic_dict_insert_first_empty2645 = icmp eq i8 %generic_dict_control2644, 0
  br i1 %generic_dict_insert_first_empty2645, label %bb_generic_dict_insert_first_vacant606, label %bb_generic_dict_insert_first_occupied602

bb_generic_dict_insert_first_occupied602:
  %generic_dict_insert_first_h22646 = icmp eq i8 %generic_dict_control2644, %dict_h2_byte2639
  br i1 %generic_dict_insert_first_h22646, label %bb_generic_dict_insert_first_compare603, label %bb_generic_dict_insert_first_fallback605

bb_generic_dict_insert_first_compare603:
  %generic_dict_insert_first_key_entries_offset_mirror2647 = add i64 %mutable_capacity2630, 23
  %generic_dict_insert_first_key_entries_offset2648 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2647, -8
  %generic_dict_insert_first_key_entries2649 = getelementptr i8, ptr %mutable_ptr2628, i64 %generic_dict_insert_first_key_entries_offset2648
  %generic_dict_insert_first_key_entry_offset2650 = mul i64 %dict_start_slot2641, 4
  %generic_dict_insert_first_key_slot2651 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2649, i64 %generic_dict_insert_first_key_entry_offset2650
  %generic_dict_insert_first_key2652 = load i32, ptr %generic_dict_insert_first_key_slot2651, align 4
  %generic_dict_key_equal2653 = icmp eq i32 %generic_dict_insert_first_key2652, 8
  br i1 %generic_dict_key_equal2653, label %bb_generic_dict_insert_first_match604, label %bb_generic_dict_insert_first_fallback605

bb_generic_dict_insert_first_match604:
  br label %bb_generic_dict_insert_first_done607

bb_generic_dict_insert_first_vacant606:
  br label %bb_generic_dict_insert_first_done607

bb_generic_dict_insert_first_fallback605:
  %hash_key2654 = sext i32 8 to i64
  %hash_high2656 = lshr i64 %hash_key2654, 32
  %hash_fold2655 = xor i64 %hash_key2654, %hash_high2656
  %hash2657 = mul i64 %hash_fold2655, -7046029254386353131
  %dict_h2_shifted2658 = lshr i64 %hash2657, 57
  %dict_h2_raw2659 = and i64 %dict_h2_shifted2658, 127
  %dict_h2_zero2660 = icmp eq i64 %dict_h2_raw2659, 0
  %dict_h22661 = select i1 %dict_h2_zero2660, i64 1, i64 %dict_h2_raw2659
  %dict_h2_byte2662 = trunc i64 %dict_h22661 to i8
  %dict_capacity_mask2663 = sub i64 %mutable_capacity2630, 1
  %dict_start_slot2664 = and i64 %hash2657, %dict_capacity_mask2663
  br label %bb_generic_dict_group_find610

bb_generic_dict_group_find610:
  %generic_dict_group_probe2667 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback605 ], [ %generic_dict_group_next_probe2665, %bb_generic_dict_group_next618 ]
  %generic_dict_group_deleted2668 = phi i64 [ %mutable_capacity2630, %bb_generic_dict_insert_first_fallback605 ], [ %generic_dict_group_next_deleted2666, %bb_generic_dict_group_next618 ]
  %generic_dict_group_active2669 = icmp ult i64 %generic_dict_group_probe2667, %mutable_capacity2630
  br i1 %generic_dict_group_active2669, label %bb_generic_dict_group_body611, label %bb_generic_dict_group_miss619

bb_generic_dict_group_body611:
  %generic_dict_group_unwrapped2670 = add i64 %dict_start_slot2664, %generic_dict_group_probe2667
  %generic_dict_group_start2671 = and i64 %generic_dict_group_unwrapped2670, %dict_capacity_mask2663
  %generic_dict_group_pointer2672 = getelementptr i8, ptr %mutable_ptr2628, i64 %generic_dict_group_start2671
  %generic_dict_group_controls2673 = load <16 x i8>, ptr %generic_dict_group_pointer2672, align 1
  %generic_dict_group_h2_seed2674 = insertelement <16 x i8> poison, i8 %dict_h2_byte2662, i64 0
  %generic_dict_group_h2_vector2675 = shufflevector <16 x i8> %generic_dict_group_h2_seed2674, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2676 = icmp eq <16 x i8> %generic_dict_group_controls2673, %generic_dict_group_h2_vector2675
  %generic_dict_group_match_bits2677 = bitcast <16 x i1> %generic_dict_group_matches_vector2676 to i16
  %generic_dict_group_empty_vector2678 = icmp eq <16 x i8> %generic_dict_group_controls2673, zeroinitializer
  %generic_dict_group_empty_bits2679 = bitcast <16 x i1> %generic_dict_group_empty_vector2678 to i16
  %generic_dict_group_deleted_seed2680 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2681 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2680, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2682 = icmp eq <16 x i8> %generic_dict_group_controls2673, %generic_dict_group_deleted_vector2681
  %generic_dict_group_deleted_bits2683 = bitcast <16 x i1> %generic_dict_group_deleted_matches2682 to i16
  %generic_dict_group_has_deleted2684 = icmp ne i16 %generic_dict_group_deleted_bits2683, 0
  %generic_dict_group_no_previous_deleted2685 = icmp eq i64 %generic_dict_group_deleted2668, %mutable_capacity2630
  %generic_dict_group_capture_deleted2686 = and i1 %generic_dict_group_has_deleted2684, %generic_dict_group_no_previous_deleted2685
  %generic_dict_group_deleted_offset162687 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2683, i1 false)
  %generic_dict_group_deleted_offset2688 = zext i16 %generic_dict_group_deleted_offset162687 to i64
  %generic_dict_group_deleted_unwrapped2689 = add i64 %generic_dict_group_start2671, %generic_dict_group_deleted_offset2688
  %generic_dict_group_deleted_slot2690 = and i64 %generic_dict_group_deleted_unwrapped2689, %dict_capacity_mask2663
  %generic_dict_group_captured_deleted2691 = select i1 %generic_dict_group_capture_deleted2686, i64 %generic_dict_group_deleted_slot2690, i64 %generic_dict_group_deleted2668
  br label %bb_generic_dict_candidate_loop612

bb_generic_dict_candidate_loop612:
  %generic_dict_candidate_bits2692 = phi i16 [ %generic_dict_group_match_bits2677, %bb_generic_dict_group_body611 ], [ %generic_dict_candidate_cleared_bits2693, %bb_generic_dict_candidate_next614 ]
  %generic_dict_has_candidate2694 = icmp ne i16 %generic_dict_candidate_bits2692, 0
  br i1 %generic_dict_has_candidate2694, label %bb_generic_dict_candidate_body613, label %bb_generic_dict_group_decision615

bb_generic_dict_candidate_body613:
  %generic_dict_candidate_offset162695 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2692, i1 false)
  %generic_dict_candidate_offset2696 = zext i16 %generic_dict_candidate_offset162695 to i64
  %generic_dict_candidate_unwrapped2697 = add i64 %generic_dict_group_start2671, %generic_dict_candidate_offset2696
  %generic_dict_candidate_slot2698 = and i64 %generic_dict_candidate_unwrapped2697, %dict_capacity_mask2663
  %generic_dict_key_entries_offset_mirror2699 = add i64 %mutable_capacity2630, 23
  %generic_dict_key_entries_offset2700 = and i64 %generic_dict_key_entries_offset_mirror2699, -8
  %generic_dict_key_entries2701 = getelementptr i8, ptr %mutable_ptr2628, i64 %generic_dict_key_entries_offset2700
  %generic_dict_key_entry_offset2702 = mul i64 %generic_dict_candidate_slot2698, 4
  %generic_dict_key_slot2703 = getelementptr i8, ptr %generic_dict_key_entries2701, i64 %generic_dict_key_entry_offset2702
  %generic_dict_key2704 = load i32, ptr %generic_dict_key_slot2703, align 4
  %generic_dict_key_equal2705 = icmp eq i32 %generic_dict_key2704, 8
  br i1 %generic_dict_key_equal2705, label %bb_generic_dict_group_match617, label %bb_generic_dict_candidate_next614

bb_generic_dict_candidate_next614:
  %generic_dict_candidate_bits_minus_one2706 = sub i16 %generic_dict_candidate_bits2692, 1
  %generic_dict_candidate_cleared_bits2693 = and i16 %generic_dict_candidate_bits2692, %generic_dict_candidate_bits_minus_one2706
  br label %bb_generic_dict_candidate_loop612

bb_generic_dict_group_decision615:
  %generic_dict_group_has_empty2707 = icmp ne i16 %generic_dict_group_empty_bits2679, 0
  br i1 %generic_dict_group_has_empty2707, label %bb_generic_dict_group_empty616, label %bb_generic_dict_group_next618

bb_generic_dict_group_empty616:
  %generic_dict_group_empty_offset162708 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2679, i1 false)
  %generic_dict_group_empty_offset2709 = zext i16 %generic_dict_group_empty_offset162708 to i64
  %generic_dict_group_empty_unwrapped2710 = add i64 %generic_dict_group_start2671, %generic_dict_group_empty_offset2709
  %generic_dict_group_empty_slot2711 = and i64 %generic_dict_group_empty_unwrapped2710, %dict_capacity_mask2663
  %generic_dict_group_use_empty2712 = icmp eq i64 %generic_dict_group_captured_deleted2691, %mutable_capacity2630
  %generic_dict_group_insertion_slot2713 = select i1 %generic_dict_group_use_empty2712, i64 %generic_dict_group_empty_slot2711, i64 %generic_dict_group_captured_deleted2691
  br label %bb_generic_dict_group_done620

bb_generic_dict_group_match617:
  br label %bb_generic_dict_group_done620

bb_generic_dict_group_next618:
  %generic_dict_group_next_probe2665 = add i64 %generic_dict_group_probe2667, 16
  %generic_dict_group_next_deleted2666 = add i64 %generic_dict_group_captured_deleted2691, 0
  br label %bb_generic_dict_group_find610

bb_generic_dict_group_miss619:
  %generic_dict_group_miss_no_deleted2714 = icmp eq i64 %generic_dict_group_deleted2668, %mutable_capacity2630
  %generic_dict_group_miss_slot2715 = select i1 %generic_dict_group_miss_no_deleted2714, i64 0, i64 %generic_dict_group_deleted2668
  br label %bb_generic_dict_group_done620

bb_generic_dict_group_done620:
  %generic_dict_find_found2716 = phi i1 [ false, %bb_generic_dict_group_empty616 ], [ true, %bb_generic_dict_group_match617 ], [ false, %bb_generic_dict_group_miss619 ]
  %generic_dict_find_slot_result2717 = phi i64 [ %generic_dict_group_insertion_slot2713, %bb_generic_dict_group_empty616 ], [ %generic_dict_candidate_slot2698, %bb_generic_dict_group_match617 ], [ %generic_dict_group_miss_slot2715, %bb_generic_dict_group_miss619 ]
  br label %bb_generic_dict_insert_first_done607

bb_generic_dict_insert_first_done607:
  %generic_dict_insert_first_found2718 = phi i1 [ true, %bb_generic_dict_insert_first_match604 ], [ false, %bb_generic_dict_insert_first_vacant606 ], [ %generic_dict_find_found2716, %bb_generic_dict_group_done620 ], [ false, %bb_generic_dict_insert_no_capacity609 ]
  %generic_dict_insert_first_slot_result2719 = phi i64 [ %dict_start_slot2641, %bb_generic_dict_insert_first_match604 ], [ %dict_start_slot2641, %bb_generic_dict_insert_first_vacant606 ], [ %generic_dict_find_slot_result2717, %bb_generic_dict_group_done620 ], [ 0, %bb_generic_dict_insert_no_capacity609 ]
  br i1 %generic_dict_insert_first_found2718, label %bb_set_insert_duplicate621, label %bb_set_insert_new622

bb_set_insert_duplicate621:
  br label %bb_set_insert_done625

bb_set_insert_new622:
  %set_insert_length2720 = add i64 %mutable_len2629, 1
  %set_insert_load_num2721 = mul i64 %set_insert_length2720, 8
  %set_insert_load_den2722 = mul i64 %mutable_capacity2630, 7
  %set_insert_should_grow2723 = icmp ugt i64 %set_insert_load_num2721, %set_insert_load_den2722
  br i1 %set_insert_should_grow2723, label %bb_set_insert_grow624, label %bb_set_insert_current623

bb_set_insert_current623:
  %set_key_entries_offset_mirror2724 = add i64 %mutable_capacity2630, 23
  %set_key_entries_offset2725 = and i64 %set_key_entries_offset_mirror2724, -8
  %set_key_entries2726 = getelementptr i8, ptr %mutable_ptr2628, i64 %set_key_entries_offset2725
  %set_key_entry_offset2727 = mul i64 %generic_dict_insert_first_slot_result2719, 4
  %set_key_slot2728 = getelementptr i8, ptr %set_key_entries2726, i64 %set_key_entry_offset2727
  store i32 8, ptr %set_key_slot2728, align 4
  %generic_dict_control_slot2729 = getelementptr i8, ptr %mutable_ptr2628, i64 %generic_dict_insert_first_slot_result2719
  store i8 %dict_h2_byte2639, ptr %generic_dict_control_slot2729, align 1
  %generic_dict_control_mirrored2730 = icmp ult i64 %generic_dict_insert_first_slot_result2719, 16
  br i1 %generic_dict_control_mirrored2730, label %bb_generic_dict_control_mirror626, label %bb_generic_dict_control_done627

bb_generic_dict_control_mirror626:
  %generic_dict_control_mirror_index2731 = add i64 %mutable_capacity2630, %generic_dict_insert_first_slot_result2719
  %generic_dict_control_mirror_slot2732 = getelementptr i8, ptr %mutable_ptr2628, i64 %generic_dict_control_mirror_index2731
  store i8 %dict_h2_byte2639, ptr %generic_dict_control_mirror_slot2732, align 1
  br label %bb_generic_dict_control_done627

bb_generic_dict_control_done627:
  br label %bb_set_insert_done625

bb_set_insert_grow624:
  %set_grown_capacity2733 = mul i64 %mutable_capacity2630, 2
  %generic_dict_entries_offset_mirror2734 = add i64 %set_grown_capacity2733, 23
  %generic_dict_entries_offset2735 = and i64 %generic_dict_entries_offset_mirror2734, -8
  %generic_dict_entries_bytes2736 = mul i64 %set_grown_capacity2733, 4
  %generic_dict_bytes2737 = add i64 %generic_dict_entries_offset2735, %generic_dict_entries_bytes2736
  %heap2738 = call ptr @sollang_alloc(i64 %generic_dict_bytes2737)
  %heap_ok2739 = icmp ne ptr %heap2738, null
  br i1 %heap_ok2739, label %bb_alloc_ok628, label %bb_alloc_fail629

bb_alloc_fail629:
  %trap_stderr2740 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr2740, ptr @.slg.str.module.x.9, i32 25, ptr %trap_written2741, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok628:
  %generic_dict_control_bytes2742 = add i64 %set_grown_capacity2733, 16
  call void @llvm.memset.p0.i64(ptr %heap2738, i8 0, i64 %generic_dict_control_bytes2742, i1 false)
  br label %bb_set_rehash630

bb_set_rehash630:
  %set_rehash_index2744 = phi i64 [ 0, %bb_alloc_ok628 ], [ %set_rehash_next_index2743, %bb_set_rehash_next633 ]
  %set_rehash_active2745 = icmp ult i64 %set_rehash_index2744, %mutable_capacity2630
  br i1 %set_rehash_active2745, label %bb_set_rehash_body631, label %bb_set_rehash_done634

bb_set_rehash_body631:
  %generic_dict_control_slot2746 = getelementptr i8, ptr %mutable_ptr2628, i64 %set_rehash_index2744
  %generic_dict_control2747 = load i8, ptr %generic_dict_control_slot2746, align 1
  %set_rehash_occupied2748 = icmp sgt i8 %generic_dict_control2747, 0
  br i1 %set_rehash_occupied2748, label %bb_set_rehash_move632, label %bb_set_rehash_next633

bb_set_rehash_move632:
  %set_rehash_key_entries_offset_mirror2749 = add i64 %mutable_capacity2630, 23
  %set_rehash_key_entries_offset2750 = and i64 %set_rehash_key_entries_offset_mirror2749, -8
  %set_rehash_key_entries2751 = getelementptr i8, ptr %mutable_ptr2628, i64 %set_rehash_key_entries_offset2750
  %set_rehash_key_entry_offset2752 = mul i64 %set_rehash_index2744, 4
  %set_rehash_key_slot2753 = getelementptr i8, ptr %set_rehash_key_entries2751, i64 %set_rehash_key_entry_offset2752
  %set_rehash_key2754 = load i32, ptr %set_rehash_key_slot2753, align 4
  %hash_key2755 = sext i32 %set_rehash_key2754 to i64
  %hash_high2757 = lshr i64 %hash_key2755, 32
  %hash_fold2756 = xor i64 %hash_key2755, %hash_high2757
  %hash2758 = mul i64 %hash_fold2756, -7046029254386353131
  %dict_h2_shifted2759 = lshr i64 %hash2758, 57
  %dict_h2_raw2760 = and i64 %dict_h2_shifted2759, 127
  %dict_h2_zero2761 = icmp eq i64 %dict_h2_raw2760, 0
  %dict_h22762 = select i1 %dict_h2_zero2761, i64 1, i64 %dict_h2_raw2760
  %dict_h2_byte2763 = trunc i64 %dict_h22762 to i8
  %dict_capacity_mask2764 = sub i64 %set_grown_capacity2733, 1
  %dict_start_slot2765 = and i64 %hash2758, %dict_capacity_mask2764
  %generic_dict_insert_has_capacity2766 = icmp ugt i64 %set_grown_capacity2733, 0
  br i1 %generic_dict_insert_has_capacity2766, label %bb_generic_dict_insert_first641, label %bb_generic_dict_insert_no_capacity642

bb_generic_dict_insert_no_capacity642:
  br label %bb_generic_dict_insert_first_done640

bb_generic_dict_insert_first641:
  %generic_dict_control_slot2767 = getelementptr i8, ptr %heap2738, i64 %dict_start_slot2765
  %generic_dict_control2768 = load i8, ptr %generic_dict_control_slot2767, align 1
  %generic_dict_insert_first_empty2769 = icmp eq i8 %generic_dict_control2768, 0
  br i1 %generic_dict_insert_first_empty2769, label %bb_generic_dict_insert_first_vacant639, label %bb_generic_dict_insert_first_occupied635

bb_generic_dict_insert_first_occupied635:
  %generic_dict_insert_first_h22770 = icmp eq i8 %generic_dict_control2768, %dict_h2_byte2763
  br i1 %generic_dict_insert_first_h22770, label %bb_generic_dict_insert_first_compare636, label %bb_generic_dict_insert_first_fallback638

bb_generic_dict_insert_first_compare636:
  %generic_dict_insert_first_key_entries_offset_mirror2771 = add i64 %set_grown_capacity2733, 23
  %generic_dict_insert_first_key_entries_offset2772 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2771, -8
  %generic_dict_insert_first_key_entries2773 = getelementptr i8, ptr %heap2738, i64 %generic_dict_insert_first_key_entries_offset2772
  %generic_dict_insert_first_key_entry_offset2774 = mul i64 %dict_start_slot2765, 4
  %generic_dict_insert_first_key_slot2775 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2773, i64 %generic_dict_insert_first_key_entry_offset2774
  %generic_dict_insert_first_key2776 = load i32, ptr %generic_dict_insert_first_key_slot2775, align 4
  %generic_dict_key_equal2777 = icmp eq i32 %generic_dict_insert_first_key2776, %set_rehash_key2754
  br i1 %generic_dict_key_equal2777, label %bb_generic_dict_insert_first_match637, label %bb_generic_dict_insert_first_fallback638

bb_generic_dict_insert_first_match637:
  br label %bb_generic_dict_insert_first_done640

bb_generic_dict_insert_first_vacant639:
  br label %bb_generic_dict_insert_first_done640

bb_generic_dict_insert_first_fallback638:
  %hash_key2778 = sext i32 %set_rehash_key2754 to i64
  %hash_high2780 = lshr i64 %hash_key2778, 32
  %hash_fold2779 = xor i64 %hash_key2778, %hash_high2780
  %hash2781 = mul i64 %hash_fold2779, -7046029254386353131
  %dict_h2_shifted2782 = lshr i64 %hash2781, 57
  %dict_h2_raw2783 = and i64 %dict_h2_shifted2782, 127
  %dict_h2_zero2784 = icmp eq i64 %dict_h2_raw2783, 0
  %dict_h22785 = select i1 %dict_h2_zero2784, i64 1, i64 %dict_h2_raw2783
  %dict_h2_byte2786 = trunc i64 %dict_h22785 to i8
  %dict_capacity_mask2787 = sub i64 %set_grown_capacity2733, 1
  %dict_start_slot2788 = and i64 %hash2781, %dict_capacity_mask2787
  br label %bb_generic_dict_group_find643

bb_generic_dict_group_find643:
  %generic_dict_group_probe2791 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback638 ], [ %generic_dict_group_next_probe2789, %bb_generic_dict_group_next651 ]
  %generic_dict_group_deleted2792 = phi i64 [ %set_grown_capacity2733, %bb_generic_dict_insert_first_fallback638 ], [ %generic_dict_group_next_deleted2790, %bb_generic_dict_group_next651 ]
  %generic_dict_group_active2793 = icmp ult i64 %generic_dict_group_probe2791, %set_grown_capacity2733
  br i1 %generic_dict_group_active2793, label %bb_generic_dict_group_body644, label %bb_generic_dict_group_miss652

bb_generic_dict_group_body644:
  %generic_dict_group_unwrapped2794 = add i64 %dict_start_slot2788, %generic_dict_group_probe2791
  %generic_dict_group_start2795 = and i64 %generic_dict_group_unwrapped2794, %dict_capacity_mask2787
  %generic_dict_group_pointer2796 = getelementptr i8, ptr %heap2738, i64 %generic_dict_group_start2795
  %generic_dict_group_controls2797 = load <16 x i8>, ptr %generic_dict_group_pointer2796, align 1
  %generic_dict_group_h2_seed2798 = insertelement <16 x i8> poison, i8 %dict_h2_byte2786, i64 0
  %generic_dict_group_h2_vector2799 = shufflevector <16 x i8> %generic_dict_group_h2_seed2798, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2800 = icmp eq <16 x i8> %generic_dict_group_controls2797, %generic_dict_group_h2_vector2799
  %generic_dict_group_match_bits2801 = bitcast <16 x i1> %generic_dict_group_matches_vector2800 to i16
  %generic_dict_group_empty_vector2802 = icmp eq <16 x i8> %generic_dict_group_controls2797, zeroinitializer
  %generic_dict_group_empty_bits2803 = bitcast <16 x i1> %generic_dict_group_empty_vector2802 to i16
  %generic_dict_group_deleted_seed2804 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2805 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2804, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2806 = icmp eq <16 x i8> %generic_dict_group_controls2797, %generic_dict_group_deleted_vector2805
  %generic_dict_group_deleted_bits2807 = bitcast <16 x i1> %generic_dict_group_deleted_matches2806 to i16
  %generic_dict_group_has_deleted2808 = icmp ne i16 %generic_dict_group_deleted_bits2807, 0
  %generic_dict_group_no_previous_deleted2809 = icmp eq i64 %generic_dict_group_deleted2792, %set_grown_capacity2733
  %generic_dict_group_capture_deleted2810 = and i1 %generic_dict_group_has_deleted2808, %generic_dict_group_no_previous_deleted2809
  %generic_dict_group_deleted_offset162811 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2807, i1 false)
  %generic_dict_group_deleted_offset2812 = zext i16 %generic_dict_group_deleted_offset162811 to i64
  %generic_dict_group_deleted_unwrapped2813 = add i64 %generic_dict_group_start2795, %generic_dict_group_deleted_offset2812
  %generic_dict_group_deleted_slot2814 = and i64 %generic_dict_group_deleted_unwrapped2813, %dict_capacity_mask2787
  %generic_dict_group_captured_deleted2815 = select i1 %generic_dict_group_capture_deleted2810, i64 %generic_dict_group_deleted_slot2814, i64 %generic_dict_group_deleted2792
  br label %bb_generic_dict_candidate_loop645

bb_generic_dict_candidate_loop645:
  %generic_dict_candidate_bits2816 = phi i16 [ %generic_dict_group_match_bits2801, %bb_generic_dict_group_body644 ], [ %generic_dict_candidate_cleared_bits2817, %bb_generic_dict_candidate_next647 ]
  %generic_dict_has_candidate2818 = icmp ne i16 %generic_dict_candidate_bits2816, 0
  br i1 %generic_dict_has_candidate2818, label %bb_generic_dict_candidate_body646, label %bb_generic_dict_group_decision648

bb_generic_dict_candidate_body646:
  %generic_dict_candidate_offset162819 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2816, i1 false)
  %generic_dict_candidate_offset2820 = zext i16 %generic_dict_candidate_offset162819 to i64
  %generic_dict_candidate_unwrapped2821 = add i64 %generic_dict_group_start2795, %generic_dict_candidate_offset2820
  %generic_dict_candidate_slot2822 = and i64 %generic_dict_candidate_unwrapped2821, %dict_capacity_mask2787
  %generic_dict_key_entries_offset_mirror2823 = add i64 %set_grown_capacity2733, 23
  %generic_dict_key_entries_offset2824 = and i64 %generic_dict_key_entries_offset_mirror2823, -8
  %generic_dict_key_entries2825 = getelementptr i8, ptr %heap2738, i64 %generic_dict_key_entries_offset2824
  %generic_dict_key_entry_offset2826 = mul i64 %generic_dict_candidate_slot2822, 4
  %generic_dict_key_slot2827 = getelementptr i8, ptr %generic_dict_key_entries2825, i64 %generic_dict_key_entry_offset2826
  %generic_dict_key2828 = load i32, ptr %generic_dict_key_slot2827, align 4
  %generic_dict_key_equal2829 = icmp eq i32 %generic_dict_key2828, %set_rehash_key2754
  br i1 %generic_dict_key_equal2829, label %bb_generic_dict_group_match650, label %bb_generic_dict_candidate_next647

bb_generic_dict_candidate_next647:
  %generic_dict_candidate_bits_minus_one2830 = sub i16 %generic_dict_candidate_bits2816, 1
  %generic_dict_candidate_cleared_bits2817 = and i16 %generic_dict_candidate_bits2816, %generic_dict_candidate_bits_minus_one2830
  br label %bb_generic_dict_candidate_loop645

bb_generic_dict_group_decision648:
  %generic_dict_group_has_empty2831 = icmp ne i16 %generic_dict_group_empty_bits2803, 0
  br i1 %generic_dict_group_has_empty2831, label %bb_generic_dict_group_empty649, label %bb_generic_dict_group_next651

bb_generic_dict_group_empty649:
  %generic_dict_group_empty_offset162832 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2803, i1 false)
  %generic_dict_group_empty_offset2833 = zext i16 %generic_dict_group_empty_offset162832 to i64
  %generic_dict_group_empty_unwrapped2834 = add i64 %generic_dict_group_start2795, %generic_dict_group_empty_offset2833
  %generic_dict_group_empty_slot2835 = and i64 %generic_dict_group_empty_unwrapped2834, %dict_capacity_mask2787
  %generic_dict_group_use_empty2836 = icmp eq i64 %generic_dict_group_captured_deleted2815, %set_grown_capacity2733
  %generic_dict_group_insertion_slot2837 = select i1 %generic_dict_group_use_empty2836, i64 %generic_dict_group_empty_slot2835, i64 %generic_dict_group_captured_deleted2815
  br label %bb_generic_dict_group_done653

bb_generic_dict_group_match650:
  br label %bb_generic_dict_group_done653

bb_generic_dict_group_next651:
  %generic_dict_group_next_probe2789 = add i64 %generic_dict_group_probe2791, 16
  %generic_dict_group_next_deleted2790 = add i64 %generic_dict_group_captured_deleted2815, 0
  br label %bb_generic_dict_group_find643

bb_generic_dict_group_miss652:
  %generic_dict_group_miss_no_deleted2838 = icmp eq i64 %generic_dict_group_deleted2792, %set_grown_capacity2733
  %generic_dict_group_miss_slot2839 = select i1 %generic_dict_group_miss_no_deleted2838, i64 0, i64 %generic_dict_group_deleted2792
  br label %bb_generic_dict_group_done653

bb_generic_dict_group_done653:
  %generic_dict_find_found2840 = phi i1 [ false, %bb_generic_dict_group_empty649 ], [ true, %bb_generic_dict_group_match650 ], [ false, %bb_generic_dict_group_miss652 ]
  %generic_dict_find_slot_result2841 = phi i64 [ %generic_dict_group_insertion_slot2837, %bb_generic_dict_group_empty649 ], [ %generic_dict_candidate_slot2822, %bb_generic_dict_group_match650 ], [ %generic_dict_group_miss_slot2839, %bb_generic_dict_group_miss652 ]
  br label %bb_generic_dict_insert_first_done640

bb_generic_dict_insert_first_done640:
  %generic_dict_insert_first_found2842 = phi i1 [ true, %bb_generic_dict_insert_first_match637 ], [ false, %bb_generic_dict_insert_first_vacant639 ], [ %generic_dict_find_found2840, %bb_generic_dict_group_done653 ], [ false, %bb_generic_dict_insert_no_capacity642 ]
  %generic_dict_insert_first_slot_result2843 = phi i64 [ %dict_start_slot2765, %bb_generic_dict_insert_first_match637 ], [ %dict_start_slot2765, %bb_generic_dict_insert_first_vacant639 ], [ %generic_dict_find_slot_result2841, %bb_generic_dict_group_done653 ], [ 0, %bb_generic_dict_insert_no_capacity642 ]
  %set_key_entries_offset_mirror2844 = add i64 %set_grown_capacity2733, 23
  %set_key_entries_offset2845 = and i64 %set_key_entries_offset_mirror2844, -8
  %set_key_entries2846 = getelementptr i8, ptr %heap2738, i64 %set_key_entries_offset2845
  %set_key_entry_offset2847 = mul i64 %generic_dict_insert_first_slot_result2843, 4
  %set_key_slot2848 = getelementptr i8, ptr %set_key_entries2846, i64 %set_key_entry_offset2847
  store i32 %set_rehash_key2754, ptr %set_key_slot2848, align 4
  %generic_dict_control_slot2849 = getelementptr i8, ptr %heap2738, i64 %generic_dict_insert_first_slot_result2843
  store i8 %dict_h2_byte2763, ptr %generic_dict_control_slot2849, align 1
  %generic_dict_control_mirrored2850 = icmp ult i64 %generic_dict_insert_first_slot_result2843, 16
  br i1 %generic_dict_control_mirrored2850, label %bb_generic_dict_control_mirror654, label %bb_generic_dict_control_done655

bb_generic_dict_control_mirror654:
  %generic_dict_control_mirror_index2851 = add i64 %set_grown_capacity2733, %generic_dict_insert_first_slot_result2843
  %generic_dict_control_mirror_slot2852 = getelementptr i8, ptr %heap2738, i64 %generic_dict_control_mirror_index2851
  store i8 %dict_h2_byte2763, ptr %generic_dict_control_mirror_slot2852, align 1
  br label %bb_generic_dict_control_done655

bb_generic_dict_control_done655:
  br label %bb_set_rehash_next633

bb_set_rehash_next633:
  %set_rehash_next_index2743 = add i64 %set_rehash_index2744, 1
  br label %bb_set_rehash630

bb_set_rehash_done634:
  call void @sollang_free(ptr %mutable_ptr2628)
  %hash_key2853 = sext i32 8 to i64
  %hash_high2855 = lshr i64 %hash_key2853, 32
  %hash_fold2854 = xor i64 %hash_key2853, %hash_high2855
  %hash2856 = mul i64 %hash_fold2854, -7046029254386353131
  %dict_h2_shifted2857 = lshr i64 %hash2856, 57
  %dict_h2_raw2858 = and i64 %dict_h2_shifted2857, 127
  %dict_h2_zero2859 = icmp eq i64 %dict_h2_raw2858, 0
  %dict_h22860 = select i1 %dict_h2_zero2859, i64 1, i64 %dict_h2_raw2858
  %dict_h2_byte2861 = trunc i64 %dict_h22860 to i8
  %dict_capacity_mask2862 = sub i64 %set_grown_capacity2733, 1
  %dict_start_slot2863 = and i64 %hash2856, %dict_capacity_mask2862
  %generic_dict_insert_has_capacity2864 = icmp ugt i64 %set_grown_capacity2733, 0
  br i1 %generic_dict_insert_has_capacity2864, label %bb_generic_dict_insert_first662, label %bb_generic_dict_insert_no_capacity663

bb_generic_dict_insert_no_capacity663:
  br label %bb_generic_dict_insert_first_done661

bb_generic_dict_insert_first662:
  %generic_dict_control_slot2865 = getelementptr i8, ptr %heap2738, i64 %dict_start_slot2863
  %generic_dict_control2866 = load i8, ptr %generic_dict_control_slot2865, align 1
  %generic_dict_insert_first_empty2867 = icmp eq i8 %generic_dict_control2866, 0
  br i1 %generic_dict_insert_first_empty2867, label %bb_generic_dict_insert_first_vacant660, label %bb_generic_dict_insert_first_occupied656

bb_generic_dict_insert_first_occupied656:
  %generic_dict_insert_first_h22868 = icmp eq i8 %generic_dict_control2866, %dict_h2_byte2861
  br i1 %generic_dict_insert_first_h22868, label %bb_generic_dict_insert_first_compare657, label %bb_generic_dict_insert_first_fallback659

bb_generic_dict_insert_first_compare657:
  %generic_dict_insert_first_key_entries_offset_mirror2869 = add i64 %set_grown_capacity2733, 23
  %generic_dict_insert_first_key_entries_offset2870 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2869, -8
  %generic_dict_insert_first_key_entries2871 = getelementptr i8, ptr %heap2738, i64 %generic_dict_insert_first_key_entries_offset2870
  %generic_dict_insert_first_key_entry_offset2872 = mul i64 %dict_start_slot2863, 4
  %generic_dict_insert_first_key_slot2873 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2871, i64 %generic_dict_insert_first_key_entry_offset2872
  %generic_dict_insert_first_key2874 = load i32, ptr %generic_dict_insert_first_key_slot2873, align 4
  %generic_dict_key_equal2875 = icmp eq i32 %generic_dict_insert_first_key2874, 8
  br i1 %generic_dict_key_equal2875, label %bb_generic_dict_insert_first_match658, label %bb_generic_dict_insert_first_fallback659

bb_generic_dict_insert_first_match658:
  br label %bb_generic_dict_insert_first_done661

bb_generic_dict_insert_first_vacant660:
  br label %bb_generic_dict_insert_first_done661

bb_generic_dict_insert_first_fallback659:
  %hash_key2876 = sext i32 8 to i64
  %hash_high2878 = lshr i64 %hash_key2876, 32
  %hash_fold2877 = xor i64 %hash_key2876, %hash_high2878
  %hash2879 = mul i64 %hash_fold2877, -7046029254386353131
  %dict_h2_shifted2880 = lshr i64 %hash2879, 57
  %dict_h2_raw2881 = and i64 %dict_h2_shifted2880, 127
  %dict_h2_zero2882 = icmp eq i64 %dict_h2_raw2881, 0
  %dict_h22883 = select i1 %dict_h2_zero2882, i64 1, i64 %dict_h2_raw2881
  %dict_h2_byte2884 = trunc i64 %dict_h22883 to i8
  %dict_capacity_mask2885 = sub i64 %set_grown_capacity2733, 1
  %dict_start_slot2886 = and i64 %hash2879, %dict_capacity_mask2885
  br label %bb_generic_dict_group_find664

bb_generic_dict_group_find664:
  %generic_dict_group_probe2889 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback659 ], [ %generic_dict_group_next_probe2887, %bb_generic_dict_group_next672 ]
  %generic_dict_group_deleted2890 = phi i64 [ %set_grown_capacity2733, %bb_generic_dict_insert_first_fallback659 ], [ %generic_dict_group_next_deleted2888, %bb_generic_dict_group_next672 ]
  %generic_dict_group_active2891 = icmp ult i64 %generic_dict_group_probe2889, %set_grown_capacity2733
  br i1 %generic_dict_group_active2891, label %bb_generic_dict_group_body665, label %bb_generic_dict_group_miss673

bb_generic_dict_group_body665:
  %generic_dict_group_unwrapped2892 = add i64 %dict_start_slot2886, %generic_dict_group_probe2889
  %generic_dict_group_start2893 = and i64 %generic_dict_group_unwrapped2892, %dict_capacity_mask2885
  %generic_dict_group_pointer2894 = getelementptr i8, ptr %heap2738, i64 %generic_dict_group_start2893
  %generic_dict_group_controls2895 = load <16 x i8>, ptr %generic_dict_group_pointer2894, align 1
  %generic_dict_group_h2_seed2896 = insertelement <16 x i8> poison, i8 %dict_h2_byte2884, i64 0
  %generic_dict_group_h2_vector2897 = shufflevector <16 x i8> %generic_dict_group_h2_seed2896, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector2898 = icmp eq <16 x i8> %generic_dict_group_controls2895, %generic_dict_group_h2_vector2897
  %generic_dict_group_match_bits2899 = bitcast <16 x i1> %generic_dict_group_matches_vector2898 to i16
  %generic_dict_group_empty_vector2900 = icmp eq <16 x i8> %generic_dict_group_controls2895, zeroinitializer
  %generic_dict_group_empty_bits2901 = bitcast <16 x i1> %generic_dict_group_empty_vector2900 to i16
  %generic_dict_group_deleted_seed2902 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector2903 = shufflevector <16 x i8> %generic_dict_group_deleted_seed2902, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches2904 = icmp eq <16 x i8> %generic_dict_group_controls2895, %generic_dict_group_deleted_vector2903
  %generic_dict_group_deleted_bits2905 = bitcast <16 x i1> %generic_dict_group_deleted_matches2904 to i16
  %generic_dict_group_has_deleted2906 = icmp ne i16 %generic_dict_group_deleted_bits2905, 0
  %generic_dict_group_no_previous_deleted2907 = icmp eq i64 %generic_dict_group_deleted2890, %set_grown_capacity2733
  %generic_dict_group_capture_deleted2908 = and i1 %generic_dict_group_has_deleted2906, %generic_dict_group_no_previous_deleted2907
  %generic_dict_group_deleted_offset162909 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits2905, i1 false)
  %generic_dict_group_deleted_offset2910 = zext i16 %generic_dict_group_deleted_offset162909 to i64
  %generic_dict_group_deleted_unwrapped2911 = add i64 %generic_dict_group_start2893, %generic_dict_group_deleted_offset2910
  %generic_dict_group_deleted_slot2912 = and i64 %generic_dict_group_deleted_unwrapped2911, %dict_capacity_mask2885
  %generic_dict_group_captured_deleted2913 = select i1 %generic_dict_group_capture_deleted2908, i64 %generic_dict_group_deleted_slot2912, i64 %generic_dict_group_deleted2890
  br label %bb_generic_dict_candidate_loop666

bb_generic_dict_candidate_loop666:
  %generic_dict_candidate_bits2914 = phi i16 [ %generic_dict_group_match_bits2899, %bb_generic_dict_group_body665 ], [ %generic_dict_candidate_cleared_bits2915, %bb_generic_dict_candidate_next668 ]
  %generic_dict_has_candidate2916 = icmp ne i16 %generic_dict_candidate_bits2914, 0
  br i1 %generic_dict_has_candidate2916, label %bb_generic_dict_candidate_body667, label %bb_generic_dict_group_decision669

bb_generic_dict_candidate_body667:
  %generic_dict_candidate_offset162917 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits2914, i1 false)
  %generic_dict_candidate_offset2918 = zext i16 %generic_dict_candidate_offset162917 to i64
  %generic_dict_candidate_unwrapped2919 = add i64 %generic_dict_group_start2893, %generic_dict_candidate_offset2918
  %generic_dict_candidate_slot2920 = and i64 %generic_dict_candidate_unwrapped2919, %dict_capacity_mask2885
  %generic_dict_key_entries_offset_mirror2921 = add i64 %set_grown_capacity2733, 23
  %generic_dict_key_entries_offset2922 = and i64 %generic_dict_key_entries_offset_mirror2921, -8
  %generic_dict_key_entries2923 = getelementptr i8, ptr %heap2738, i64 %generic_dict_key_entries_offset2922
  %generic_dict_key_entry_offset2924 = mul i64 %generic_dict_candidate_slot2920, 4
  %generic_dict_key_slot2925 = getelementptr i8, ptr %generic_dict_key_entries2923, i64 %generic_dict_key_entry_offset2924
  %generic_dict_key2926 = load i32, ptr %generic_dict_key_slot2925, align 4
  %generic_dict_key_equal2927 = icmp eq i32 %generic_dict_key2926, 8
  br i1 %generic_dict_key_equal2927, label %bb_generic_dict_group_match671, label %bb_generic_dict_candidate_next668

bb_generic_dict_candidate_next668:
  %generic_dict_candidate_bits_minus_one2928 = sub i16 %generic_dict_candidate_bits2914, 1
  %generic_dict_candidate_cleared_bits2915 = and i16 %generic_dict_candidate_bits2914, %generic_dict_candidate_bits_minus_one2928
  br label %bb_generic_dict_candidate_loop666

bb_generic_dict_group_decision669:
  %generic_dict_group_has_empty2929 = icmp ne i16 %generic_dict_group_empty_bits2901, 0
  br i1 %generic_dict_group_has_empty2929, label %bb_generic_dict_group_empty670, label %bb_generic_dict_group_next672

bb_generic_dict_group_empty670:
  %generic_dict_group_empty_offset162930 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits2901, i1 false)
  %generic_dict_group_empty_offset2931 = zext i16 %generic_dict_group_empty_offset162930 to i64
  %generic_dict_group_empty_unwrapped2932 = add i64 %generic_dict_group_start2893, %generic_dict_group_empty_offset2931
  %generic_dict_group_empty_slot2933 = and i64 %generic_dict_group_empty_unwrapped2932, %dict_capacity_mask2885
  %generic_dict_group_use_empty2934 = icmp eq i64 %generic_dict_group_captured_deleted2913, %set_grown_capacity2733
  %generic_dict_group_insertion_slot2935 = select i1 %generic_dict_group_use_empty2934, i64 %generic_dict_group_empty_slot2933, i64 %generic_dict_group_captured_deleted2913
  br label %bb_generic_dict_group_done674

bb_generic_dict_group_match671:
  br label %bb_generic_dict_group_done674

bb_generic_dict_group_next672:
  %generic_dict_group_next_probe2887 = add i64 %generic_dict_group_probe2889, 16
  %generic_dict_group_next_deleted2888 = add i64 %generic_dict_group_captured_deleted2913, 0
  br label %bb_generic_dict_group_find664

bb_generic_dict_group_miss673:
  %generic_dict_group_miss_no_deleted2936 = icmp eq i64 %generic_dict_group_deleted2890, %set_grown_capacity2733
  %generic_dict_group_miss_slot2937 = select i1 %generic_dict_group_miss_no_deleted2936, i64 0, i64 %generic_dict_group_deleted2890
  br label %bb_generic_dict_group_done674

bb_generic_dict_group_done674:
  %generic_dict_find_found2938 = phi i1 [ false, %bb_generic_dict_group_empty670 ], [ true, %bb_generic_dict_group_match671 ], [ false, %bb_generic_dict_group_miss673 ]
  %generic_dict_find_slot_result2939 = phi i64 [ %generic_dict_group_insertion_slot2935, %bb_generic_dict_group_empty670 ], [ %generic_dict_candidate_slot2920, %bb_generic_dict_group_match671 ], [ %generic_dict_group_miss_slot2937, %bb_generic_dict_group_miss673 ]
  br label %bb_generic_dict_insert_first_done661

bb_generic_dict_insert_first_done661:
  %generic_dict_insert_first_found2940 = phi i1 [ true, %bb_generic_dict_insert_first_match658 ], [ false, %bb_generic_dict_insert_first_vacant660 ], [ %generic_dict_find_found2938, %bb_generic_dict_group_done674 ], [ false, %bb_generic_dict_insert_no_capacity663 ]
  %generic_dict_insert_first_slot_result2941 = phi i64 [ %dict_start_slot2863, %bb_generic_dict_insert_first_match658 ], [ %dict_start_slot2863, %bb_generic_dict_insert_first_vacant660 ], [ %generic_dict_find_slot_result2939, %bb_generic_dict_group_done674 ], [ 0, %bb_generic_dict_insert_no_capacity663 ]
  %set_key_entries_offset_mirror2942 = add i64 %set_grown_capacity2733, 23
  %set_key_entries_offset2943 = and i64 %set_key_entries_offset_mirror2942, -8
  %set_key_entries2944 = getelementptr i8, ptr %heap2738, i64 %set_key_entries_offset2943
  %set_key_entry_offset2945 = mul i64 %generic_dict_insert_first_slot_result2941, 4
  %set_key_slot2946 = getelementptr i8, ptr %set_key_entries2944, i64 %set_key_entry_offset2945
  store i32 8, ptr %set_key_slot2946, align 4
  %generic_dict_control_slot2947 = getelementptr i8, ptr %heap2738, i64 %generic_dict_insert_first_slot_result2941
  store i8 %dict_h2_byte2861, ptr %generic_dict_control_slot2947, align 1
  %generic_dict_control_mirrored2948 = icmp ult i64 %generic_dict_insert_first_slot_result2941, 16
  br i1 %generic_dict_control_mirrored2948, label %bb_generic_dict_control_mirror675, label %bb_generic_dict_control_done676

bb_generic_dict_control_mirror675:
  %generic_dict_control_mirror_index2949 = add i64 %set_grown_capacity2733, %generic_dict_insert_first_slot_result2941
  %generic_dict_control_mirror_slot2950 = getelementptr i8, ptr %heap2738, i64 %generic_dict_control_mirror_index2949
  store i8 %dict_h2_byte2861, ptr %generic_dict_control_mirror_slot2950, align 1
  br label %bb_generic_dict_control_done676

bb_generic_dict_control_done676:
  br label %bb_set_insert_done625

bb_set_insert_done625:
  %set_pointer2951 = phi ptr [ %mutable_ptr2628, %bb_set_insert_duplicate621 ], [ %mutable_ptr2628, %bb_generic_dict_control_done627 ], [ %heap2738, %bb_generic_dict_control_done676 ]
  %set_length2952 = phi i64 [ %mutable_len2629, %bb_set_insert_duplicate621 ], [ %set_insert_length2720, %bb_generic_dict_control_done627 ], [ %set_insert_length2720, %bb_generic_dict_control_done676 ]
  %set_capacity2953 = phi i64 [ %mutable_capacity2630, %bb_set_insert_duplicate621 ], [ %mutable_capacity2630, %bb_generic_dict_control_done627 ], [ %set_grown_capacity2733, %bb_generic_dict_control_done676 ]
  %set_inserted2954 = phi i1 [ false, %bb_set_insert_duplicate621 ], [ true, %bb_generic_dict_control_done627 ], [ true, %bb_generic_dict_control_done676 ]
  store ptr %set_pointer2951, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length2952, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity2953, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr2955 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len2956 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity2957 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key2958 = sext i32 9 to i64
  %hash_high2960 = lshr i64 %hash_key2958, 32
  %hash_fold2959 = xor i64 %hash_key2958, %hash_high2960
  %hash2961 = mul i64 %hash_fold2959, -7046029254386353131
  %dict_h2_shifted2962 = lshr i64 %hash2961, 57
  %dict_h2_raw2963 = and i64 %dict_h2_shifted2962, 127
  %dict_h2_zero2964 = icmp eq i64 %dict_h2_raw2963, 0
  %dict_h22965 = select i1 %dict_h2_zero2964, i64 1, i64 %dict_h2_raw2963
  %dict_h2_byte2966 = trunc i64 %dict_h22965 to i8
  %dict_capacity_mask2967 = sub i64 %mutable_capacity2957, 1
  %dict_start_slot2968 = and i64 %hash2961, %dict_capacity_mask2967
  %generic_dict_insert_has_capacity2969 = icmp ugt i64 %mutable_capacity2957, 0
  br i1 %generic_dict_insert_has_capacity2969, label %bb_generic_dict_insert_first683, label %bb_generic_dict_insert_no_capacity684

bb_generic_dict_insert_no_capacity684:
  br label %bb_generic_dict_insert_first_done682

bb_generic_dict_insert_first683:
  %generic_dict_control_slot2970 = getelementptr i8, ptr %mutable_ptr2955, i64 %dict_start_slot2968
  %generic_dict_control2971 = load i8, ptr %generic_dict_control_slot2970, align 1
  %generic_dict_insert_first_empty2972 = icmp eq i8 %generic_dict_control2971, 0
  br i1 %generic_dict_insert_first_empty2972, label %bb_generic_dict_insert_first_vacant681, label %bb_generic_dict_insert_first_occupied677

bb_generic_dict_insert_first_occupied677:
  %generic_dict_insert_first_h22973 = icmp eq i8 %generic_dict_control2971, %dict_h2_byte2966
  br i1 %generic_dict_insert_first_h22973, label %bb_generic_dict_insert_first_compare678, label %bb_generic_dict_insert_first_fallback680

bb_generic_dict_insert_first_compare678:
  %generic_dict_insert_first_key_entries_offset_mirror2974 = add i64 %mutable_capacity2957, 23
  %generic_dict_insert_first_key_entries_offset2975 = and i64 %generic_dict_insert_first_key_entries_offset_mirror2974, -8
  %generic_dict_insert_first_key_entries2976 = getelementptr i8, ptr %mutable_ptr2955, i64 %generic_dict_insert_first_key_entries_offset2975
  %generic_dict_insert_first_key_entry_offset2977 = mul i64 %dict_start_slot2968, 4
  %generic_dict_insert_first_key_slot2978 = getelementptr i8, ptr %generic_dict_insert_first_key_entries2976, i64 %generic_dict_insert_first_key_entry_offset2977
  %generic_dict_insert_first_key2979 = load i32, ptr %generic_dict_insert_first_key_slot2978, align 4
  %generic_dict_key_equal2980 = icmp eq i32 %generic_dict_insert_first_key2979, 9
  br i1 %generic_dict_key_equal2980, label %bb_generic_dict_insert_first_match679, label %bb_generic_dict_insert_first_fallback680

bb_generic_dict_insert_first_match679:
  br label %bb_generic_dict_insert_first_done682

bb_generic_dict_insert_first_vacant681:
  br label %bb_generic_dict_insert_first_done682

bb_generic_dict_insert_first_fallback680:
  %hash_key2981 = sext i32 9 to i64
  %hash_high2983 = lshr i64 %hash_key2981, 32
  %hash_fold2982 = xor i64 %hash_key2981, %hash_high2983
  %hash2984 = mul i64 %hash_fold2982, -7046029254386353131
  %dict_h2_shifted2985 = lshr i64 %hash2984, 57
  %dict_h2_raw2986 = and i64 %dict_h2_shifted2985, 127
  %dict_h2_zero2987 = icmp eq i64 %dict_h2_raw2986, 0
  %dict_h22988 = select i1 %dict_h2_zero2987, i64 1, i64 %dict_h2_raw2986
  %dict_h2_byte2989 = trunc i64 %dict_h22988 to i8
  %dict_capacity_mask2990 = sub i64 %mutable_capacity2957, 1
  %dict_start_slot2991 = and i64 %hash2984, %dict_capacity_mask2990
  br label %bb_generic_dict_group_find685

bb_generic_dict_group_find685:
  %generic_dict_group_probe2994 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback680 ], [ %generic_dict_group_next_probe2992, %bb_generic_dict_group_next693 ]
  %generic_dict_group_deleted2995 = phi i64 [ %mutable_capacity2957, %bb_generic_dict_insert_first_fallback680 ], [ %generic_dict_group_next_deleted2993, %bb_generic_dict_group_next693 ]
  %generic_dict_group_active2996 = icmp ult i64 %generic_dict_group_probe2994, %mutable_capacity2957
  br i1 %generic_dict_group_active2996, label %bb_generic_dict_group_body686, label %bb_generic_dict_group_miss694

bb_generic_dict_group_body686:
  %generic_dict_group_unwrapped2997 = add i64 %dict_start_slot2991, %generic_dict_group_probe2994
  %generic_dict_group_start2998 = and i64 %generic_dict_group_unwrapped2997, %dict_capacity_mask2990
  %generic_dict_group_pointer2999 = getelementptr i8, ptr %mutable_ptr2955, i64 %generic_dict_group_start2998
  %generic_dict_group_controls3000 = load <16 x i8>, ptr %generic_dict_group_pointer2999, align 1
  %generic_dict_group_h2_seed3001 = insertelement <16 x i8> poison, i8 %dict_h2_byte2989, i64 0
  %generic_dict_group_h2_vector3002 = shufflevector <16 x i8> %generic_dict_group_h2_seed3001, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3003 = icmp eq <16 x i8> %generic_dict_group_controls3000, %generic_dict_group_h2_vector3002
  %generic_dict_group_match_bits3004 = bitcast <16 x i1> %generic_dict_group_matches_vector3003 to i16
  %generic_dict_group_empty_vector3005 = icmp eq <16 x i8> %generic_dict_group_controls3000, zeroinitializer
  %generic_dict_group_empty_bits3006 = bitcast <16 x i1> %generic_dict_group_empty_vector3005 to i16
  %generic_dict_group_deleted_seed3007 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3008 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3007, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3009 = icmp eq <16 x i8> %generic_dict_group_controls3000, %generic_dict_group_deleted_vector3008
  %generic_dict_group_deleted_bits3010 = bitcast <16 x i1> %generic_dict_group_deleted_matches3009 to i16
  %generic_dict_group_has_deleted3011 = icmp ne i16 %generic_dict_group_deleted_bits3010, 0
  %generic_dict_group_no_previous_deleted3012 = icmp eq i64 %generic_dict_group_deleted2995, %mutable_capacity2957
  %generic_dict_group_capture_deleted3013 = and i1 %generic_dict_group_has_deleted3011, %generic_dict_group_no_previous_deleted3012
  %generic_dict_group_deleted_offset163014 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3010, i1 false)
  %generic_dict_group_deleted_offset3015 = zext i16 %generic_dict_group_deleted_offset163014 to i64
  %generic_dict_group_deleted_unwrapped3016 = add i64 %generic_dict_group_start2998, %generic_dict_group_deleted_offset3015
  %generic_dict_group_deleted_slot3017 = and i64 %generic_dict_group_deleted_unwrapped3016, %dict_capacity_mask2990
  %generic_dict_group_captured_deleted3018 = select i1 %generic_dict_group_capture_deleted3013, i64 %generic_dict_group_deleted_slot3017, i64 %generic_dict_group_deleted2995
  br label %bb_generic_dict_candidate_loop687

bb_generic_dict_candidate_loop687:
  %generic_dict_candidate_bits3019 = phi i16 [ %generic_dict_group_match_bits3004, %bb_generic_dict_group_body686 ], [ %generic_dict_candidate_cleared_bits3020, %bb_generic_dict_candidate_next689 ]
  %generic_dict_has_candidate3021 = icmp ne i16 %generic_dict_candidate_bits3019, 0
  br i1 %generic_dict_has_candidate3021, label %bb_generic_dict_candidate_body688, label %bb_generic_dict_group_decision690

bb_generic_dict_candidate_body688:
  %generic_dict_candidate_offset163022 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3019, i1 false)
  %generic_dict_candidate_offset3023 = zext i16 %generic_dict_candidate_offset163022 to i64
  %generic_dict_candidate_unwrapped3024 = add i64 %generic_dict_group_start2998, %generic_dict_candidate_offset3023
  %generic_dict_candidate_slot3025 = and i64 %generic_dict_candidate_unwrapped3024, %dict_capacity_mask2990
  %generic_dict_key_entries_offset_mirror3026 = add i64 %mutable_capacity2957, 23
  %generic_dict_key_entries_offset3027 = and i64 %generic_dict_key_entries_offset_mirror3026, -8
  %generic_dict_key_entries3028 = getelementptr i8, ptr %mutable_ptr2955, i64 %generic_dict_key_entries_offset3027
  %generic_dict_key_entry_offset3029 = mul i64 %generic_dict_candidate_slot3025, 4
  %generic_dict_key_slot3030 = getelementptr i8, ptr %generic_dict_key_entries3028, i64 %generic_dict_key_entry_offset3029
  %generic_dict_key3031 = load i32, ptr %generic_dict_key_slot3030, align 4
  %generic_dict_key_equal3032 = icmp eq i32 %generic_dict_key3031, 9
  br i1 %generic_dict_key_equal3032, label %bb_generic_dict_group_match692, label %bb_generic_dict_candidate_next689

bb_generic_dict_candidate_next689:
  %generic_dict_candidate_bits_minus_one3033 = sub i16 %generic_dict_candidate_bits3019, 1
  %generic_dict_candidate_cleared_bits3020 = and i16 %generic_dict_candidate_bits3019, %generic_dict_candidate_bits_minus_one3033
  br label %bb_generic_dict_candidate_loop687

bb_generic_dict_group_decision690:
  %generic_dict_group_has_empty3034 = icmp ne i16 %generic_dict_group_empty_bits3006, 0
  br i1 %generic_dict_group_has_empty3034, label %bb_generic_dict_group_empty691, label %bb_generic_dict_group_next693

bb_generic_dict_group_empty691:
  %generic_dict_group_empty_offset163035 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3006, i1 false)
  %generic_dict_group_empty_offset3036 = zext i16 %generic_dict_group_empty_offset163035 to i64
  %generic_dict_group_empty_unwrapped3037 = add i64 %generic_dict_group_start2998, %generic_dict_group_empty_offset3036
  %generic_dict_group_empty_slot3038 = and i64 %generic_dict_group_empty_unwrapped3037, %dict_capacity_mask2990
  %generic_dict_group_use_empty3039 = icmp eq i64 %generic_dict_group_captured_deleted3018, %mutable_capacity2957
  %generic_dict_group_insertion_slot3040 = select i1 %generic_dict_group_use_empty3039, i64 %generic_dict_group_empty_slot3038, i64 %generic_dict_group_captured_deleted3018
  br label %bb_generic_dict_group_done695

bb_generic_dict_group_match692:
  br label %bb_generic_dict_group_done695

bb_generic_dict_group_next693:
  %generic_dict_group_next_probe2992 = add i64 %generic_dict_group_probe2994, 16
  %generic_dict_group_next_deleted2993 = add i64 %generic_dict_group_captured_deleted3018, 0
  br label %bb_generic_dict_group_find685

bb_generic_dict_group_miss694:
  %generic_dict_group_miss_no_deleted3041 = icmp eq i64 %generic_dict_group_deleted2995, %mutable_capacity2957
  %generic_dict_group_miss_slot3042 = select i1 %generic_dict_group_miss_no_deleted3041, i64 0, i64 %generic_dict_group_deleted2995
  br label %bb_generic_dict_group_done695

bb_generic_dict_group_done695:
  %generic_dict_find_found3043 = phi i1 [ false, %bb_generic_dict_group_empty691 ], [ true, %bb_generic_dict_group_match692 ], [ false, %bb_generic_dict_group_miss694 ]
  %generic_dict_find_slot_result3044 = phi i64 [ %generic_dict_group_insertion_slot3040, %bb_generic_dict_group_empty691 ], [ %generic_dict_candidate_slot3025, %bb_generic_dict_group_match692 ], [ %generic_dict_group_miss_slot3042, %bb_generic_dict_group_miss694 ]
  br label %bb_generic_dict_insert_first_done682

bb_generic_dict_insert_first_done682:
  %generic_dict_insert_first_found3045 = phi i1 [ true, %bb_generic_dict_insert_first_match679 ], [ false, %bb_generic_dict_insert_first_vacant681 ], [ %generic_dict_find_found3043, %bb_generic_dict_group_done695 ], [ false, %bb_generic_dict_insert_no_capacity684 ]
  %generic_dict_insert_first_slot_result3046 = phi i64 [ %dict_start_slot2968, %bb_generic_dict_insert_first_match679 ], [ %dict_start_slot2968, %bb_generic_dict_insert_first_vacant681 ], [ %generic_dict_find_slot_result3044, %bb_generic_dict_group_done695 ], [ 0, %bb_generic_dict_insert_no_capacity684 ]
  br i1 %generic_dict_insert_first_found3045, label %bb_set_insert_duplicate696, label %bb_set_insert_new697

bb_set_insert_duplicate696:
  br label %bb_set_insert_done700

bb_set_insert_new697:
  %set_insert_length3047 = add i64 %mutable_len2956, 1
  %set_insert_load_num3048 = mul i64 %set_insert_length3047, 8
  %set_insert_load_den3049 = mul i64 %mutable_capacity2957, 7
  %set_insert_should_grow3050 = icmp ugt i64 %set_insert_load_num3048, %set_insert_load_den3049
  br i1 %set_insert_should_grow3050, label %bb_set_insert_grow699, label %bb_set_insert_current698

bb_set_insert_current698:
  %set_key_entries_offset_mirror3051 = add i64 %mutable_capacity2957, 23
  %set_key_entries_offset3052 = and i64 %set_key_entries_offset_mirror3051, -8
  %set_key_entries3053 = getelementptr i8, ptr %mutable_ptr2955, i64 %set_key_entries_offset3052
  %set_key_entry_offset3054 = mul i64 %generic_dict_insert_first_slot_result3046, 4
  %set_key_slot3055 = getelementptr i8, ptr %set_key_entries3053, i64 %set_key_entry_offset3054
  store i32 9, ptr %set_key_slot3055, align 4
  %generic_dict_control_slot3056 = getelementptr i8, ptr %mutable_ptr2955, i64 %generic_dict_insert_first_slot_result3046
  store i8 %dict_h2_byte2966, ptr %generic_dict_control_slot3056, align 1
  %generic_dict_control_mirrored3057 = icmp ult i64 %generic_dict_insert_first_slot_result3046, 16
  br i1 %generic_dict_control_mirrored3057, label %bb_generic_dict_control_mirror701, label %bb_generic_dict_control_done702

bb_generic_dict_control_mirror701:
  %generic_dict_control_mirror_index3058 = add i64 %mutable_capacity2957, %generic_dict_insert_first_slot_result3046
  %generic_dict_control_mirror_slot3059 = getelementptr i8, ptr %mutable_ptr2955, i64 %generic_dict_control_mirror_index3058
  store i8 %dict_h2_byte2966, ptr %generic_dict_control_mirror_slot3059, align 1
  br label %bb_generic_dict_control_done702

bb_generic_dict_control_done702:
  br label %bb_set_insert_done700

bb_set_insert_grow699:
  %set_grown_capacity3060 = mul i64 %mutable_capacity2957, 2
  %generic_dict_entries_offset_mirror3061 = add i64 %set_grown_capacity3060, 23
  %generic_dict_entries_offset3062 = and i64 %generic_dict_entries_offset_mirror3061, -8
  %generic_dict_entries_bytes3063 = mul i64 %set_grown_capacity3060, 4
  %generic_dict_bytes3064 = add i64 %generic_dict_entries_offset3062, %generic_dict_entries_bytes3063
  %heap3065 = call ptr @sollang_alloc(i64 %generic_dict_bytes3064)
  %heap_ok3066 = icmp ne ptr %heap3065, null
  br i1 %heap_ok3066, label %bb_alloc_ok703, label %bb_alloc_fail704

bb_alloc_fail704:
  %trap_stderr3067 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr3067, ptr @.slg.str.module.x.10, i32 25, ptr %trap_written3068, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok703:
  %generic_dict_control_bytes3069 = add i64 %set_grown_capacity3060, 16
  call void @llvm.memset.p0.i64(ptr %heap3065, i8 0, i64 %generic_dict_control_bytes3069, i1 false)
  br label %bb_set_rehash705

bb_set_rehash705:
  %set_rehash_index3071 = phi i64 [ 0, %bb_alloc_ok703 ], [ %set_rehash_next_index3070, %bb_set_rehash_next708 ]
  %set_rehash_active3072 = icmp ult i64 %set_rehash_index3071, %mutable_capacity2957
  br i1 %set_rehash_active3072, label %bb_set_rehash_body706, label %bb_set_rehash_done709

bb_set_rehash_body706:
  %generic_dict_control_slot3073 = getelementptr i8, ptr %mutable_ptr2955, i64 %set_rehash_index3071
  %generic_dict_control3074 = load i8, ptr %generic_dict_control_slot3073, align 1
  %set_rehash_occupied3075 = icmp sgt i8 %generic_dict_control3074, 0
  br i1 %set_rehash_occupied3075, label %bb_set_rehash_move707, label %bb_set_rehash_next708

bb_set_rehash_move707:
  %set_rehash_key_entries_offset_mirror3076 = add i64 %mutable_capacity2957, 23
  %set_rehash_key_entries_offset3077 = and i64 %set_rehash_key_entries_offset_mirror3076, -8
  %set_rehash_key_entries3078 = getelementptr i8, ptr %mutable_ptr2955, i64 %set_rehash_key_entries_offset3077
  %set_rehash_key_entry_offset3079 = mul i64 %set_rehash_index3071, 4
  %set_rehash_key_slot3080 = getelementptr i8, ptr %set_rehash_key_entries3078, i64 %set_rehash_key_entry_offset3079
  %set_rehash_key3081 = load i32, ptr %set_rehash_key_slot3080, align 4
  %hash_key3082 = sext i32 %set_rehash_key3081 to i64
  %hash_high3084 = lshr i64 %hash_key3082, 32
  %hash_fold3083 = xor i64 %hash_key3082, %hash_high3084
  %hash3085 = mul i64 %hash_fold3083, -7046029254386353131
  %dict_h2_shifted3086 = lshr i64 %hash3085, 57
  %dict_h2_raw3087 = and i64 %dict_h2_shifted3086, 127
  %dict_h2_zero3088 = icmp eq i64 %dict_h2_raw3087, 0
  %dict_h23089 = select i1 %dict_h2_zero3088, i64 1, i64 %dict_h2_raw3087
  %dict_h2_byte3090 = trunc i64 %dict_h23089 to i8
  %dict_capacity_mask3091 = sub i64 %set_grown_capacity3060, 1
  %dict_start_slot3092 = and i64 %hash3085, %dict_capacity_mask3091
  %generic_dict_insert_has_capacity3093 = icmp ugt i64 %set_grown_capacity3060, 0
  br i1 %generic_dict_insert_has_capacity3093, label %bb_generic_dict_insert_first716, label %bb_generic_dict_insert_no_capacity717

bb_generic_dict_insert_no_capacity717:
  br label %bb_generic_dict_insert_first_done715

bb_generic_dict_insert_first716:
  %generic_dict_control_slot3094 = getelementptr i8, ptr %heap3065, i64 %dict_start_slot3092
  %generic_dict_control3095 = load i8, ptr %generic_dict_control_slot3094, align 1
  %generic_dict_insert_first_empty3096 = icmp eq i8 %generic_dict_control3095, 0
  br i1 %generic_dict_insert_first_empty3096, label %bb_generic_dict_insert_first_vacant714, label %bb_generic_dict_insert_first_occupied710

bb_generic_dict_insert_first_occupied710:
  %generic_dict_insert_first_h23097 = icmp eq i8 %generic_dict_control3095, %dict_h2_byte3090
  br i1 %generic_dict_insert_first_h23097, label %bb_generic_dict_insert_first_compare711, label %bb_generic_dict_insert_first_fallback713

bb_generic_dict_insert_first_compare711:
  %generic_dict_insert_first_key_entries_offset_mirror3098 = add i64 %set_grown_capacity3060, 23
  %generic_dict_insert_first_key_entries_offset3099 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3098, -8
  %generic_dict_insert_first_key_entries3100 = getelementptr i8, ptr %heap3065, i64 %generic_dict_insert_first_key_entries_offset3099
  %generic_dict_insert_first_key_entry_offset3101 = mul i64 %dict_start_slot3092, 4
  %generic_dict_insert_first_key_slot3102 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3100, i64 %generic_dict_insert_first_key_entry_offset3101
  %generic_dict_insert_first_key3103 = load i32, ptr %generic_dict_insert_first_key_slot3102, align 4
  %generic_dict_key_equal3104 = icmp eq i32 %generic_dict_insert_first_key3103, %set_rehash_key3081
  br i1 %generic_dict_key_equal3104, label %bb_generic_dict_insert_first_match712, label %bb_generic_dict_insert_first_fallback713

bb_generic_dict_insert_first_match712:
  br label %bb_generic_dict_insert_first_done715

bb_generic_dict_insert_first_vacant714:
  br label %bb_generic_dict_insert_first_done715

bb_generic_dict_insert_first_fallback713:
  %hash_key3105 = sext i32 %set_rehash_key3081 to i64
  %hash_high3107 = lshr i64 %hash_key3105, 32
  %hash_fold3106 = xor i64 %hash_key3105, %hash_high3107
  %hash3108 = mul i64 %hash_fold3106, -7046029254386353131
  %dict_h2_shifted3109 = lshr i64 %hash3108, 57
  %dict_h2_raw3110 = and i64 %dict_h2_shifted3109, 127
  %dict_h2_zero3111 = icmp eq i64 %dict_h2_raw3110, 0
  %dict_h23112 = select i1 %dict_h2_zero3111, i64 1, i64 %dict_h2_raw3110
  %dict_h2_byte3113 = trunc i64 %dict_h23112 to i8
  %dict_capacity_mask3114 = sub i64 %set_grown_capacity3060, 1
  %dict_start_slot3115 = and i64 %hash3108, %dict_capacity_mask3114
  br label %bb_generic_dict_group_find718

bb_generic_dict_group_find718:
  %generic_dict_group_probe3118 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback713 ], [ %generic_dict_group_next_probe3116, %bb_generic_dict_group_next726 ]
  %generic_dict_group_deleted3119 = phi i64 [ %set_grown_capacity3060, %bb_generic_dict_insert_first_fallback713 ], [ %generic_dict_group_next_deleted3117, %bb_generic_dict_group_next726 ]
  %generic_dict_group_active3120 = icmp ult i64 %generic_dict_group_probe3118, %set_grown_capacity3060
  br i1 %generic_dict_group_active3120, label %bb_generic_dict_group_body719, label %bb_generic_dict_group_miss727

bb_generic_dict_group_body719:
  %generic_dict_group_unwrapped3121 = add i64 %dict_start_slot3115, %generic_dict_group_probe3118
  %generic_dict_group_start3122 = and i64 %generic_dict_group_unwrapped3121, %dict_capacity_mask3114
  %generic_dict_group_pointer3123 = getelementptr i8, ptr %heap3065, i64 %generic_dict_group_start3122
  %generic_dict_group_controls3124 = load <16 x i8>, ptr %generic_dict_group_pointer3123, align 1
  %generic_dict_group_h2_seed3125 = insertelement <16 x i8> poison, i8 %dict_h2_byte3113, i64 0
  %generic_dict_group_h2_vector3126 = shufflevector <16 x i8> %generic_dict_group_h2_seed3125, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3127 = icmp eq <16 x i8> %generic_dict_group_controls3124, %generic_dict_group_h2_vector3126
  %generic_dict_group_match_bits3128 = bitcast <16 x i1> %generic_dict_group_matches_vector3127 to i16
  %generic_dict_group_empty_vector3129 = icmp eq <16 x i8> %generic_dict_group_controls3124, zeroinitializer
  %generic_dict_group_empty_bits3130 = bitcast <16 x i1> %generic_dict_group_empty_vector3129 to i16
  %generic_dict_group_deleted_seed3131 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3132 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3131, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3133 = icmp eq <16 x i8> %generic_dict_group_controls3124, %generic_dict_group_deleted_vector3132
  %generic_dict_group_deleted_bits3134 = bitcast <16 x i1> %generic_dict_group_deleted_matches3133 to i16
  %generic_dict_group_has_deleted3135 = icmp ne i16 %generic_dict_group_deleted_bits3134, 0
  %generic_dict_group_no_previous_deleted3136 = icmp eq i64 %generic_dict_group_deleted3119, %set_grown_capacity3060
  %generic_dict_group_capture_deleted3137 = and i1 %generic_dict_group_has_deleted3135, %generic_dict_group_no_previous_deleted3136
  %generic_dict_group_deleted_offset163138 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3134, i1 false)
  %generic_dict_group_deleted_offset3139 = zext i16 %generic_dict_group_deleted_offset163138 to i64
  %generic_dict_group_deleted_unwrapped3140 = add i64 %generic_dict_group_start3122, %generic_dict_group_deleted_offset3139
  %generic_dict_group_deleted_slot3141 = and i64 %generic_dict_group_deleted_unwrapped3140, %dict_capacity_mask3114
  %generic_dict_group_captured_deleted3142 = select i1 %generic_dict_group_capture_deleted3137, i64 %generic_dict_group_deleted_slot3141, i64 %generic_dict_group_deleted3119
  br label %bb_generic_dict_candidate_loop720

bb_generic_dict_candidate_loop720:
  %generic_dict_candidate_bits3143 = phi i16 [ %generic_dict_group_match_bits3128, %bb_generic_dict_group_body719 ], [ %generic_dict_candidate_cleared_bits3144, %bb_generic_dict_candidate_next722 ]
  %generic_dict_has_candidate3145 = icmp ne i16 %generic_dict_candidate_bits3143, 0
  br i1 %generic_dict_has_candidate3145, label %bb_generic_dict_candidate_body721, label %bb_generic_dict_group_decision723

bb_generic_dict_candidate_body721:
  %generic_dict_candidate_offset163146 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3143, i1 false)
  %generic_dict_candidate_offset3147 = zext i16 %generic_dict_candidate_offset163146 to i64
  %generic_dict_candidate_unwrapped3148 = add i64 %generic_dict_group_start3122, %generic_dict_candidate_offset3147
  %generic_dict_candidate_slot3149 = and i64 %generic_dict_candidate_unwrapped3148, %dict_capacity_mask3114
  %generic_dict_key_entries_offset_mirror3150 = add i64 %set_grown_capacity3060, 23
  %generic_dict_key_entries_offset3151 = and i64 %generic_dict_key_entries_offset_mirror3150, -8
  %generic_dict_key_entries3152 = getelementptr i8, ptr %heap3065, i64 %generic_dict_key_entries_offset3151
  %generic_dict_key_entry_offset3153 = mul i64 %generic_dict_candidate_slot3149, 4
  %generic_dict_key_slot3154 = getelementptr i8, ptr %generic_dict_key_entries3152, i64 %generic_dict_key_entry_offset3153
  %generic_dict_key3155 = load i32, ptr %generic_dict_key_slot3154, align 4
  %generic_dict_key_equal3156 = icmp eq i32 %generic_dict_key3155, %set_rehash_key3081
  br i1 %generic_dict_key_equal3156, label %bb_generic_dict_group_match725, label %bb_generic_dict_candidate_next722

bb_generic_dict_candidate_next722:
  %generic_dict_candidate_bits_minus_one3157 = sub i16 %generic_dict_candidate_bits3143, 1
  %generic_dict_candidate_cleared_bits3144 = and i16 %generic_dict_candidate_bits3143, %generic_dict_candidate_bits_minus_one3157
  br label %bb_generic_dict_candidate_loop720

bb_generic_dict_group_decision723:
  %generic_dict_group_has_empty3158 = icmp ne i16 %generic_dict_group_empty_bits3130, 0
  br i1 %generic_dict_group_has_empty3158, label %bb_generic_dict_group_empty724, label %bb_generic_dict_group_next726

bb_generic_dict_group_empty724:
  %generic_dict_group_empty_offset163159 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3130, i1 false)
  %generic_dict_group_empty_offset3160 = zext i16 %generic_dict_group_empty_offset163159 to i64
  %generic_dict_group_empty_unwrapped3161 = add i64 %generic_dict_group_start3122, %generic_dict_group_empty_offset3160
  %generic_dict_group_empty_slot3162 = and i64 %generic_dict_group_empty_unwrapped3161, %dict_capacity_mask3114
  %generic_dict_group_use_empty3163 = icmp eq i64 %generic_dict_group_captured_deleted3142, %set_grown_capacity3060
  %generic_dict_group_insertion_slot3164 = select i1 %generic_dict_group_use_empty3163, i64 %generic_dict_group_empty_slot3162, i64 %generic_dict_group_captured_deleted3142
  br label %bb_generic_dict_group_done728

bb_generic_dict_group_match725:
  br label %bb_generic_dict_group_done728

bb_generic_dict_group_next726:
  %generic_dict_group_next_probe3116 = add i64 %generic_dict_group_probe3118, 16
  %generic_dict_group_next_deleted3117 = add i64 %generic_dict_group_captured_deleted3142, 0
  br label %bb_generic_dict_group_find718

bb_generic_dict_group_miss727:
  %generic_dict_group_miss_no_deleted3165 = icmp eq i64 %generic_dict_group_deleted3119, %set_grown_capacity3060
  %generic_dict_group_miss_slot3166 = select i1 %generic_dict_group_miss_no_deleted3165, i64 0, i64 %generic_dict_group_deleted3119
  br label %bb_generic_dict_group_done728

bb_generic_dict_group_done728:
  %generic_dict_find_found3167 = phi i1 [ false, %bb_generic_dict_group_empty724 ], [ true, %bb_generic_dict_group_match725 ], [ false, %bb_generic_dict_group_miss727 ]
  %generic_dict_find_slot_result3168 = phi i64 [ %generic_dict_group_insertion_slot3164, %bb_generic_dict_group_empty724 ], [ %generic_dict_candidate_slot3149, %bb_generic_dict_group_match725 ], [ %generic_dict_group_miss_slot3166, %bb_generic_dict_group_miss727 ]
  br label %bb_generic_dict_insert_first_done715

bb_generic_dict_insert_first_done715:
  %generic_dict_insert_first_found3169 = phi i1 [ true, %bb_generic_dict_insert_first_match712 ], [ false, %bb_generic_dict_insert_first_vacant714 ], [ %generic_dict_find_found3167, %bb_generic_dict_group_done728 ], [ false, %bb_generic_dict_insert_no_capacity717 ]
  %generic_dict_insert_first_slot_result3170 = phi i64 [ %dict_start_slot3092, %bb_generic_dict_insert_first_match712 ], [ %dict_start_slot3092, %bb_generic_dict_insert_first_vacant714 ], [ %generic_dict_find_slot_result3168, %bb_generic_dict_group_done728 ], [ 0, %bb_generic_dict_insert_no_capacity717 ]
  %set_key_entries_offset_mirror3171 = add i64 %set_grown_capacity3060, 23
  %set_key_entries_offset3172 = and i64 %set_key_entries_offset_mirror3171, -8
  %set_key_entries3173 = getelementptr i8, ptr %heap3065, i64 %set_key_entries_offset3172
  %set_key_entry_offset3174 = mul i64 %generic_dict_insert_first_slot_result3170, 4
  %set_key_slot3175 = getelementptr i8, ptr %set_key_entries3173, i64 %set_key_entry_offset3174
  store i32 %set_rehash_key3081, ptr %set_key_slot3175, align 4
  %generic_dict_control_slot3176 = getelementptr i8, ptr %heap3065, i64 %generic_dict_insert_first_slot_result3170
  store i8 %dict_h2_byte3090, ptr %generic_dict_control_slot3176, align 1
  %generic_dict_control_mirrored3177 = icmp ult i64 %generic_dict_insert_first_slot_result3170, 16
  br i1 %generic_dict_control_mirrored3177, label %bb_generic_dict_control_mirror729, label %bb_generic_dict_control_done730

bb_generic_dict_control_mirror729:
  %generic_dict_control_mirror_index3178 = add i64 %set_grown_capacity3060, %generic_dict_insert_first_slot_result3170
  %generic_dict_control_mirror_slot3179 = getelementptr i8, ptr %heap3065, i64 %generic_dict_control_mirror_index3178
  store i8 %dict_h2_byte3090, ptr %generic_dict_control_mirror_slot3179, align 1
  br label %bb_generic_dict_control_done730

bb_generic_dict_control_done730:
  br label %bb_set_rehash_next708

bb_set_rehash_next708:
  %set_rehash_next_index3070 = add i64 %set_rehash_index3071, 1
  br label %bb_set_rehash705

bb_set_rehash_done709:
  call void @sollang_free(ptr %mutable_ptr2955)
  %hash_key3180 = sext i32 9 to i64
  %hash_high3182 = lshr i64 %hash_key3180, 32
  %hash_fold3181 = xor i64 %hash_key3180, %hash_high3182
  %hash3183 = mul i64 %hash_fold3181, -7046029254386353131
  %dict_h2_shifted3184 = lshr i64 %hash3183, 57
  %dict_h2_raw3185 = and i64 %dict_h2_shifted3184, 127
  %dict_h2_zero3186 = icmp eq i64 %dict_h2_raw3185, 0
  %dict_h23187 = select i1 %dict_h2_zero3186, i64 1, i64 %dict_h2_raw3185
  %dict_h2_byte3188 = trunc i64 %dict_h23187 to i8
  %dict_capacity_mask3189 = sub i64 %set_grown_capacity3060, 1
  %dict_start_slot3190 = and i64 %hash3183, %dict_capacity_mask3189
  %generic_dict_insert_has_capacity3191 = icmp ugt i64 %set_grown_capacity3060, 0
  br i1 %generic_dict_insert_has_capacity3191, label %bb_generic_dict_insert_first737, label %bb_generic_dict_insert_no_capacity738

bb_generic_dict_insert_no_capacity738:
  br label %bb_generic_dict_insert_first_done736

bb_generic_dict_insert_first737:
  %generic_dict_control_slot3192 = getelementptr i8, ptr %heap3065, i64 %dict_start_slot3190
  %generic_dict_control3193 = load i8, ptr %generic_dict_control_slot3192, align 1
  %generic_dict_insert_first_empty3194 = icmp eq i8 %generic_dict_control3193, 0
  br i1 %generic_dict_insert_first_empty3194, label %bb_generic_dict_insert_first_vacant735, label %bb_generic_dict_insert_first_occupied731

bb_generic_dict_insert_first_occupied731:
  %generic_dict_insert_first_h23195 = icmp eq i8 %generic_dict_control3193, %dict_h2_byte3188
  br i1 %generic_dict_insert_first_h23195, label %bb_generic_dict_insert_first_compare732, label %bb_generic_dict_insert_first_fallback734

bb_generic_dict_insert_first_compare732:
  %generic_dict_insert_first_key_entries_offset_mirror3196 = add i64 %set_grown_capacity3060, 23
  %generic_dict_insert_first_key_entries_offset3197 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3196, -8
  %generic_dict_insert_first_key_entries3198 = getelementptr i8, ptr %heap3065, i64 %generic_dict_insert_first_key_entries_offset3197
  %generic_dict_insert_first_key_entry_offset3199 = mul i64 %dict_start_slot3190, 4
  %generic_dict_insert_first_key_slot3200 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3198, i64 %generic_dict_insert_first_key_entry_offset3199
  %generic_dict_insert_first_key3201 = load i32, ptr %generic_dict_insert_first_key_slot3200, align 4
  %generic_dict_key_equal3202 = icmp eq i32 %generic_dict_insert_first_key3201, 9
  br i1 %generic_dict_key_equal3202, label %bb_generic_dict_insert_first_match733, label %bb_generic_dict_insert_first_fallback734

bb_generic_dict_insert_first_match733:
  br label %bb_generic_dict_insert_first_done736

bb_generic_dict_insert_first_vacant735:
  br label %bb_generic_dict_insert_first_done736

bb_generic_dict_insert_first_fallback734:
  %hash_key3203 = sext i32 9 to i64
  %hash_high3205 = lshr i64 %hash_key3203, 32
  %hash_fold3204 = xor i64 %hash_key3203, %hash_high3205
  %hash3206 = mul i64 %hash_fold3204, -7046029254386353131
  %dict_h2_shifted3207 = lshr i64 %hash3206, 57
  %dict_h2_raw3208 = and i64 %dict_h2_shifted3207, 127
  %dict_h2_zero3209 = icmp eq i64 %dict_h2_raw3208, 0
  %dict_h23210 = select i1 %dict_h2_zero3209, i64 1, i64 %dict_h2_raw3208
  %dict_h2_byte3211 = trunc i64 %dict_h23210 to i8
  %dict_capacity_mask3212 = sub i64 %set_grown_capacity3060, 1
  %dict_start_slot3213 = and i64 %hash3206, %dict_capacity_mask3212
  br label %bb_generic_dict_group_find739

bb_generic_dict_group_find739:
  %generic_dict_group_probe3216 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback734 ], [ %generic_dict_group_next_probe3214, %bb_generic_dict_group_next747 ]
  %generic_dict_group_deleted3217 = phi i64 [ %set_grown_capacity3060, %bb_generic_dict_insert_first_fallback734 ], [ %generic_dict_group_next_deleted3215, %bb_generic_dict_group_next747 ]
  %generic_dict_group_active3218 = icmp ult i64 %generic_dict_group_probe3216, %set_grown_capacity3060
  br i1 %generic_dict_group_active3218, label %bb_generic_dict_group_body740, label %bb_generic_dict_group_miss748

bb_generic_dict_group_body740:
  %generic_dict_group_unwrapped3219 = add i64 %dict_start_slot3213, %generic_dict_group_probe3216
  %generic_dict_group_start3220 = and i64 %generic_dict_group_unwrapped3219, %dict_capacity_mask3212
  %generic_dict_group_pointer3221 = getelementptr i8, ptr %heap3065, i64 %generic_dict_group_start3220
  %generic_dict_group_controls3222 = load <16 x i8>, ptr %generic_dict_group_pointer3221, align 1
  %generic_dict_group_h2_seed3223 = insertelement <16 x i8> poison, i8 %dict_h2_byte3211, i64 0
  %generic_dict_group_h2_vector3224 = shufflevector <16 x i8> %generic_dict_group_h2_seed3223, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3225 = icmp eq <16 x i8> %generic_dict_group_controls3222, %generic_dict_group_h2_vector3224
  %generic_dict_group_match_bits3226 = bitcast <16 x i1> %generic_dict_group_matches_vector3225 to i16
  %generic_dict_group_empty_vector3227 = icmp eq <16 x i8> %generic_dict_group_controls3222, zeroinitializer
  %generic_dict_group_empty_bits3228 = bitcast <16 x i1> %generic_dict_group_empty_vector3227 to i16
  %generic_dict_group_deleted_seed3229 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3230 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3229, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3231 = icmp eq <16 x i8> %generic_dict_group_controls3222, %generic_dict_group_deleted_vector3230
  %generic_dict_group_deleted_bits3232 = bitcast <16 x i1> %generic_dict_group_deleted_matches3231 to i16
  %generic_dict_group_has_deleted3233 = icmp ne i16 %generic_dict_group_deleted_bits3232, 0
  %generic_dict_group_no_previous_deleted3234 = icmp eq i64 %generic_dict_group_deleted3217, %set_grown_capacity3060
  %generic_dict_group_capture_deleted3235 = and i1 %generic_dict_group_has_deleted3233, %generic_dict_group_no_previous_deleted3234
  %generic_dict_group_deleted_offset163236 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3232, i1 false)
  %generic_dict_group_deleted_offset3237 = zext i16 %generic_dict_group_deleted_offset163236 to i64
  %generic_dict_group_deleted_unwrapped3238 = add i64 %generic_dict_group_start3220, %generic_dict_group_deleted_offset3237
  %generic_dict_group_deleted_slot3239 = and i64 %generic_dict_group_deleted_unwrapped3238, %dict_capacity_mask3212
  %generic_dict_group_captured_deleted3240 = select i1 %generic_dict_group_capture_deleted3235, i64 %generic_dict_group_deleted_slot3239, i64 %generic_dict_group_deleted3217
  br label %bb_generic_dict_candidate_loop741

bb_generic_dict_candidate_loop741:
  %generic_dict_candidate_bits3241 = phi i16 [ %generic_dict_group_match_bits3226, %bb_generic_dict_group_body740 ], [ %generic_dict_candidate_cleared_bits3242, %bb_generic_dict_candidate_next743 ]
  %generic_dict_has_candidate3243 = icmp ne i16 %generic_dict_candidate_bits3241, 0
  br i1 %generic_dict_has_candidate3243, label %bb_generic_dict_candidate_body742, label %bb_generic_dict_group_decision744

bb_generic_dict_candidate_body742:
  %generic_dict_candidate_offset163244 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3241, i1 false)
  %generic_dict_candidate_offset3245 = zext i16 %generic_dict_candidate_offset163244 to i64
  %generic_dict_candidate_unwrapped3246 = add i64 %generic_dict_group_start3220, %generic_dict_candidate_offset3245
  %generic_dict_candidate_slot3247 = and i64 %generic_dict_candidate_unwrapped3246, %dict_capacity_mask3212
  %generic_dict_key_entries_offset_mirror3248 = add i64 %set_grown_capacity3060, 23
  %generic_dict_key_entries_offset3249 = and i64 %generic_dict_key_entries_offset_mirror3248, -8
  %generic_dict_key_entries3250 = getelementptr i8, ptr %heap3065, i64 %generic_dict_key_entries_offset3249
  %generic_dict_key_entry_offset3251 = mul i64 %generic_dict_candidate_slot3247, 4
  %generic_dict_key_slot3252 = getelementptr i8, ptr %generic_dict_key_entries3250, i64 %generic_dict_key_entry_offset3251
  %generic_dict_key3253 = load i32, ptr %generic_dict_key_slot3252, align 4
  %generic_dict_key_equal3254 = icmp eq i32 %generic_dict_key3253, 9
  br i1 %generic_dict_key_equal3254, label %bb_generic_dict_group_match746, label %bb_generic_dict_candidate_next743

bb_generic_dict_candidate_next743:
  %generic_dict_candidate_bits_minus_one3255 = sub i16 %generic_dict_candidate_bits3241, 1
  %generic_dict_candidate_cleared_bits3242 = and i16 %generic_dict_candidate_bits3241, %generic_dict_candidate_bits_minus_one3255
  br label %bb_generic_dict_candidate_loop741

bb_generic_dict_group_decision744:
  %generic_dict_group_has_empty3256 = icmp ne i16 %generic_dict_group_empty_bits3228, 0
  br i1 %generic_dict_group_has_empty3256, label %bb_generic_dict_group_empty745, label %bb_generic_dict_group_next747

bb_generic_dict_group_empty745:
  %generic_dict_group_empty_offset163257 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3228, i1 false)
  %generic_dict_group_empty_offset3258 = zext i16 %generic_dict_group_empty_offset163257 to i64
  %generic_dict_group_empty_unwrapped3259 = add i64 %generic_dict_group_start3220, %generic_dict_group_empty_offset3258
  %generic_dict_group_empty_slot3260 = and i64 %generic_dict_group_empty_unwrapped3259, %dict_capacity_mask3212
  %generic_dict_group_use_empty3261 = icmp eq i64 %generic_dict_group_captured_deleted3240, %set_grown_capacity3060
  %generic_dict_group_insertion_slot3262 = select i1 %generic_dict_group_use_empty3261, i64 %generic_dict_group_empty_slot3260, i64 %generic_dict_group_captured_deleted3240
  br label %bb_generic_dict_group_done749

bb_generic_dict_group_match746:
  br label %bb_generic_dict_group_done749

bb_generic_dict_group_next747:
  %generic_dict_group_next_probe3214 = add i64 %generic_dict_group_probe3216, 16
  %generic_dict_group_next_deleted3215 = add i64 %generic_dict_group_captured_deleted3240, 0
  br label %bb_generic_dict_group_find739

bb_generic_dict_group_miss748:
  %generic_dict_group_miss_no_deleted3263 = icmp eq i64 %generic_dict_group_deleted3217, %set_grown_capacity3060
  %generic_dict_group_miss_slot3264 = select i1 %generic_dict_group_miss_no_deleted3263, i64 0, i64 %generic_dict_group_deleted3217
  br label %bb_generic_dict_group_done749

bb_generic_dict_group_done749:
  %generic_dict_find_found3265 = phi i1 [ false, %bb_generic_dict_group_empty745 ], [ true, %bb_generic_dict_group_match746 ], [ false, %bb_generic_dict_group_miss748 ]
  %generic_dict_find_slot_result3266 = phi i64 [ %generic_dict_group_insertion_slot3262, %bb_generic_dict_group_empty745 ], [ %generic_dict_candidate_slot3247, %bb_generic_dict_group_match746 ], [ %generic_dict_group_miss_slot3264, %bb_generic_dict_group_miss748 ]
  br label %bb_generic_dict_insert_first_done736

bb_generic_dict_insert_first_done736:
  %generic_dict_insert_first_found3267 = phi i1 [ true, %bb_generic_dict_insert_first_match733 ], [ false, %bb_generic_dict_insert_first_vacant735 ], [ %generic_dict_find_found3265, %bb_generic_dict_group_done749 ], [ false, %bb_generic_dict_insert_no_capacity738 ]
  %generic_dict_insert_first_slot_result3268 = phi i64 [ %dict_start_slot3190, %bb_generic_dict_insert_first_match733 ], [ %dict_start_slot3190, %bb_generic_dict_insert_first_vacant735 ], [ %generic_dict_find_slot_result3266, %bb_generic_dict_group_done749 ], [ 0, %bb_generic_dict_insert_no_capacity738 ]
  %set_key_entries_offset_mirror3269 = add i64 %set_grown_capacity3060, 23
  %set_key_entries_offset3270 = and i64 %set_key_entries_offset_mirror3269, -8
  %set_key_entries3271 = getelementptr i8, ptr %heap3065, i64 %set_key_entries_offset3270
  %set_key_entry_offset3272 = mul i64 %generic_dict_insert_first_slot_result3268, 4
  %set_key_slot3273 = getelementptr i8, ptr %set_key_entries3271, i64 %set_key_entry_offset3272
  store i32 9, ptr %set_key_slot3273, align 4
  %generic_dict_control_slot3274 = getelementptr i8, ptr %heap3065, i64 %generic_dict_insert_first_slot_result3268
  store i8 %dict_h2_byte3188, ptr %generic_dict_control_slot3274, align 1
  %generic_dict_control_mirrored3275 = icmp ult i64 %generic_dict_insert_first_slot_result3268, 16
  br i1 %generic_dict_control_mirrored3275, label %bb_generic_dict_control_mirror750, label %bb_generic_dict_control_done751

bb_generic_dict_control_mirror750:
  %generic_dict_control_mirror_index3276 = add i64 %set_grown_capacity3060, %generic_dict_insert_first_slot_result3268
  %generic_dict_control_mirror_slot3277 = getelementptr i8, ptr %heap3065, i64 %generic_dict_control_mirror_index3276
  store i8 %dict_h2_byte3188, ptr %generic_dict_control_mirror_slot3277, align 1
  br label %bb_generic_dict_control_done751

bb_generic_dict_control_done751:
  br label %bb_set_insert_done700

bb_set_insert_done700:
  %set_pointer3278 = phi ptr [ %mutable_ptr2955, %bb_set_insert_duplicate696 ], [ %mutable_ptr2955, %bb_generic_dict_control_done702 ], [ %heap3065, %bb_generic_dict_control_done751 ]
  %set_length3279 = phi i64 [ %mutable_len2956, %bb_set_insert_duplicate696 ], [ %set_insert_length3047, %bb_generic_dict_control_done702 ], [ %set_insert_length3047, %bb_generic_dict_control_done751 ]
  %set_capacity3280 = phi i64 [ %mutable_capacity2957, %bb_set_insert_duplicate696 ], [ %mutable_capacity2957, %bb_generic_dict_control_done702 ], [ %set_grown_capacity3060, %bb_generic_dict_control_done751 ]
  %set_inserted3281 = phi i1 [ false, %bb_set_insert_duplicate696 ], [ true, %bb_generic_dict_control_done702 ], [ true, %bb_generic_dict_control_done751 ]
  store ptr %set_pointer3278, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length3279, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity3280, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr3282 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len3283 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity3284 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key3285 = sext i32 11 to i64
  %hash_high3287 = lshr i64 %hash_key3285, 32
  %hash_fold3286 = xor i64 %hash_key3285, %hash_high3287
  %hash3288 = mul i64 %hash_fold3286, -7046029254386353131
  %dict_h2_shifted3289 = lshr i64 %hash3288, 57
  %dict_h2_raw3290 = and i64 %dict_h2_shifted3289, 127
  %dict_h2_zero3291 = icmp eq i64 %dict_h2_raw3290, 0
  %dict_h23292 = select i1 %dict_h2_zero3291, i64 1, i64 %dict_h2_raw3290
  %dict_h2_byte3293 = trunc i64 %dict_h23292 to i8
  %dict_capacity_mask3294 = sub i64 %mutable_capacity3284, 1
  %dict_start_slot3295 = and i64 %hash3288, %dict_capacity_mask3294
  %generic_dict_insert_has_capacity3296 = icmp ugt i64 %mutable_capacity3284, 0
  br i1 %generic_dict_insert_has_capacity3296, label %bb_generic_dict_insert_first758, label %bb_generic_dict_insert_no_capacity759

bb_generic_dict_insert_no_capacity759:
  br label %bb_generic_dict_insert_first_done757

bb_generic_dict_insert_first758:
  %generic_dict_control_slot3297 = getelementptr i8, ptr %mutable_ptr3282, i64 %dict_start_slot3295
  %generic_dict_control3298 = load i8, ptr %generic_dict_control_slot3297, align 1
  %generic_dict_insert_first_empty3299 = icmp eq i8 %generic_dict_control3298, 0
  br i1 %generic_dict_insert_first_empty3299, label %bb_generic_dict_insert_first_vacant756, label %bb_generic_dict_insert_first_occupied752

bb_generic_dict_insert_first_occupied752:
  %generic_dict_insert_first_h23300 = icmp eq i8 %generic_dict_control3298, %dict_h2_byte3293
  br i1 %generic_dict_insert_first_h23300, label %bb_generic_dict_insert_first_compare753, label %bb_generic_dict_insert_first_fallback755

bb_generic_dict_insert_first_compare753:
  %generic_dict_insert_first_key_entries_offset_mirror3301 = add i64 %mutable_capacity3284, 23
  %generic_dict_insert_first_key_entries_offset3302 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3301, -8
  %generic_dict_insert_first_key_entries3303 = getelementptr i8, ptr %mutable_ptr3282, i64 %generic_dict_insert_first_key_entries_offset3302
  %generic_dict_insert_first_key_entry_offset3304 = mul i64 %dict_start_slot3295, 4
  %generic_dict_insert_first_key_slot3305 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3303, i64 %generic_dict_insert_first_key_entry_offset3304
  %generic_dict_insert_first_key3306 = load i32, ptr %generic_dict_insert_first_key_slot3305, align 4
  %generic_dict_key_equal3307 = icmp eq i32 %generic_dict_insert_first_key3306, 11
  br i1 %generic_dict_key_equal3307, label %bb_generic_dict_insert_first_match754, label %bb_generic_dict_insert_first_fallback755

bb_generic_dict_insert_first_match754:
  br label %bb_generic_dict_insert_first_done757

bb_generic_dict_insert_first_vacant756:
  br label %bb_generic_dict_insert_first_done757

bb_generic_dict_insert_first_fallback755:
  %hash_key3308 = sext i32 11 to i64
  %hash_high3310 = lshr i64 %hash_key3308, 32
  %hash_fold3309 = xor i64 %hash_key3308, %hash_high3310
  %hash3311 = mul i64 %hash_fold3309, -7046029254386353131
  %dict_h2_shifted3312 = lshr i64 %hash3311, 57
  %dict_h2_raw3313 = and i64 %dict_h2_shifted3312, 127
  %dict_h2_zero3314 = icmp eq i64 %dict_h2_raw3313, 0
  %dict_h23315 = select i1 %dict_h2_zero3314, i64 1, i64 %dict_h2_raw3313
  %dict_h2_byte3316 = trunc i64 %dict_h23315 to i8
  %dict_capacity_mask3317 = sub i64 %mutable_capacity3284, 1
  %dict_start_slot3318 = and i64 %hash3311, %dict_capacity_mask3317
  br label %bb_generic_dict_group_find760

bb_generic_dict_group_find760:
  %generic_dict_group_probe3321 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback755 ], [ %generic_dict_group_next_probe3319, %bb_generic_dict_group_next768 ]
  %generic_dict_group_deleted3322 = phi i64 [ %mutable_capacity3284, %bb_generic_dict_insert_first_fallback755 ], [ %generic_dict_group_next_deleted3320, %bb_generic_dict_group_next768 ]
  %generic_dict_group_active3323 = icmp ult i64 %generic_dict_group_probe3321, %mutable_capacity3284
  br i1 %generic_dict_group_active3323, label %bb_generic_dict_group_body761, label %bb_generic_dict_group_miss769

bb_generic_dict_group_body761:
  %generic_dict_group_unwrapped3324 = add i64 %dict_start_slot3318, %generic_dict_group_probe3321
  %generic_dict_group_start3325 = and i64 %generic_dict_group_unwrapped3324, %dict_capacity_mask3317
  %generic_dict_group_pointer3326 = getelementptr i8, ptr %mutable_ptr3282, i64 %generic_dict_group_start3325
  %generic_dict_group_controls3327 = load <16 x i8>, ptr %generic_dict_group_pointer3326, align 1
  %generic_dict_group_h2_seed3328 = insertelement <16 x i8> poison, i8 %dict_h2_byte3316, i64 0
  %generic_dict_group_h2_vector3329 = shufflevector <16 x i8> %generic_dict_group_h2_seed3328, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3330 = icmp eq <16 x i8> %generic_dict_group_controls3327, %generic_dict_group_h2_vector3329
  %generic_dict_group_match_bits3331 = bitcast <16 x i1> %generic_dict_group_matches_vector3330 to i16
  %generic_dict_group_empty_vector3332 = icmp eq <16 x i8> %generic_dict_group_controls3327, zeroinitializer
  %generic_dict_group_empty_bits3333 = bitcast <16 x i1> %generic_dict_group_empty_vector3332 to i16
  %generic_dict_group_deleted_seed3334 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3335 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3334, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3336 = icmp eq <16 x i8> %generic_dict_group_controls3327, %generic_dict_group_deleted_vector3335
  %generic_dict_group_deleted_bits3337 = bitcast <16 x i1> %generic_dict_group_deleted_matches3336 to i16
  %generic_dict_group_has_deleted3338 = icmp ne i16 %generic_dict_group_deleted_bits3337, 0
  %generic_dict_group_no_previous_deleted3339 = icmp eq i64 %generic_dict_group_deleted3322, %mutable_capacity3284
  %generic_dict_group_capture_deleted3340 = and i1 %generic_dict_group_has_deleted3338, %generic_dict_group_no_previous_deleted3339
  %generic_dict_group_deleted_offset163341 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3337, i1 false)
  %generic_dict_group_deleted_offset3342 = zext i16 %generic_dict_group_deleted_offset163341 to i64
  %generic_dict_group_deleted_unwrapped3343 = add i64 %generic_dict_group_start3325, %generic_dict_group_deleted_offset3342
  %generic_dict_group_deleted_slot3344 = and i64 %generic_dict_group_deleted_unwrapped3343, %dict_capacity_mask3317
  %generic_dict_group_captured_deleted3345 = select i1 %generic_dict_group_capture_deleted3340, i64 %generic_dict_group_deleted_slot3344, i64 %generic_dict_group_deleted3322
  br label %bb_generic_dict_candidate_loop762

bb_generic_dict_candidate_loop762:
  %generic_dict_candidate_bits3346 = phi i16 [ %generic_dict_group_match_bits3331, %bb_generic_dict_group_body761 ], [ %generic_dict_candidate_cleared_bits3347, %bb_generic_dict_candidate_next764 ]
  %generic_dict_has_candidate3348 = icmp ne i16 %generic_dict_candidate_bits3346, 0
  br i1 %generic_dict_has_candidate3348, label %bb_generic_dict_candidate_body763, label %bb_generic_dict_group_decision765

bb_generic_dict_candidate_body763:
  %generic_dict_candidate_offset163349 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3346, i1 false)
  %generic_dict_candidate_offset3350 = zext i16 %generic_dict_candidate_offset163349 to i64
  %generic_dict_candidate_unwrapped3351 = add i64 %generic_dict_group_start3325, %generic_dict_candidate_offset3350
  %generic_dict_candidate_slot3352 = and i64 %generic_dict_candidate_unwrapped3351, %dict_capacity_mask3317
  %generic_dict_key_entries_offset_mirror3353 = add i64 %mutable_capacity3284, 23
  %generic_dict_key_entries_offset3354 = and i64 %generic_dict_key_entries_offset_mirror3353, -8
  %generic_dict_key_entries3355 = getelementptr i8, ptr %mutable_ptr3282, i64 %generic_dict_key_entries_offset3354
  %generic_dict_key_entry_offset3356 = mul i64 %generic_dict_candidate_slot3352, 4
  %generic_dict_key_slot3357 = getelementptr i8, ptr %generic_dict_key_entries3355, i64 %generic_dict_key_entry_offset3356
  %generic_dict_key3358 = load i32, ptr %generic_dict_key_slot3357, align 4
  %generic_dict_key_equal3359 = icmp eq i32 %generic_dict_key3358, 11
  br i1 %generic_dict_key_equal3359, label %bb_generic_dict_group_match767, label %bb_generic_dict_candidate_next764

bb_generic_dict_candidate_next764:
  %generic_dict_candidate_bits_minus_one3360 = sub i16 %generic_dict_candidate_bits3346, 1
  %generic_dict_candidate_cleared_bits3347 = and i16 %generic_dict_candidate_bits3346, %generic_dict_candidate_bits_minus_one3360
  br label %bb_generic_dict_candidate_loop762

bb_generic_dict_group_decision765:
  %generic_dict_group_has_empty3361 = icmp ne i16 %generic_dict_group_empty_bits3333, 0
  br i1 %generic_dict_group_has_empty3361, label %bb_generic_dict_group_empty766, label %bb_generic_dict_group_next768

bb_generic_dict_group_empty766:
  %generic_dict_group_empty_offset163362 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3333, i1 false)
  %generic_dict_group_empty_offset3363 = zext i16 %generic_dict_group_empty_offset163362 to i64
  %generic_dict_group_empty_unwrapped3364 = add i64 %generic_dict_group_start3325, %generic_dict_group_empty_offset3363
  %generic_dict_group_empty_slot3365 = and i64 %generic_dict_group_empty_unwrapped3364, %dict_capacity_mask3317
  %generic_dict_group_use_empty3366 = icmp eq i64 %generic_dict_group_captured_deleted3345, %mutable_capacity3284
  %generic_dict_group_insertion_slot3367 = select i1 %generic_dict_group_use_empty3366, i64 %generic_dict_group_empty_slot3365, i64 %generic_dict_group_captured_deleted3345
  br label %bb_generic_dict_group_done770

bb_generic_dict_group_match767:
  br label %bb_generic_dict_group_done770

bb_generic_dict_group_next768:
  %generic_dict_group_next_probe3319 = add i64 %generic_dict_group_probe3321, 16
  %generic_dict_group_next_deleted3320 = add i64 %generic_dict_group_captured_deleted3345, 0
  br label %bb_generic_dict_group_find760

bb_generic_dict_group_miss769:
  %generic_dict_group_miss_no_deleted3368 = icmp eq i64 %generic_dict_group_deleted3322, %mutable_capacity3284
  %generic_dict_group_miss_slot3369 = select i1 %generic_dict_group_miss_no_deleted3368, i64 0, i64 %generic_dict_group_deleted3322
  br label %bb_generic_dict_group_done770

bb_generic_dict_group_done770:
  %generic_dict_find_found3370 = phi i1 [ false, %bb_generic_dict_group_empty766 ], [ true, %bb_generic_dict_group_match767 ], [ false, %bb_generic_dict_group_miss769 ]
  %generic_dict_find_slot_result3371 = phi i64 [ %generic_dict_group_insertion_slot3367, %bb_generic_dict_group_empty766 ], [ %generic_dict_candidate_slot3352, %bb_generic_dict_group_match767 ], [ %generic_dict_group_miss_slot3369, %bb_generic_dict_group_miss769 ]
  br label %bb_generic_dict_insert_first_done757

bb_generic_dict_insert_first_done757:
  %generic_dict_insert_first_found3372 = phi i1 [ true, %bb_generic_dict_insert_first_match754 ], [ false, %bb_generic_dict_insert_first_vacant756 ], [ %generic_dict_find_found3370, %bb_generic_dict_group_done770 ], [ false, %bb_generic_dict_insert_no_capacity759 ]
  %generic_dict_insert_first_slot_result3373 = phi i64 [ %dict_start_slot3295, %bb_generic_dict_insert_first_match754 ], [ %dict_start_slot3295, %bb_generic_dict_insert_first_vacant756 ], [ %generic_dict_find_slot_result3371, %bb_generic_dict_group_done770 ], [ 0, %bb_generic_dict_insert_no_capacity759 ]
  br i1 %generic_dict_insert_first_found3372, label %bb_set_insert_duplicate771, label %bb_set_insert_new772

bb_set_insert_duplicate771:
  br label %bb_set_insert_done775

bb_set_insert_new772:
  %set_insert_length3374 = add i64 %mutable_len3283, 1
  %set_insert_load_num3375 = mul i64 %set_insert_length3374, 8
  %set_insert_load_den3376 = mul i64 %mutable_capacity3284, 7
  %set_insert_should_grow3377 = icmp ugt i64 %set_insert_load_num3375, %set_insert_load_den3376
  br i1 %set_insert_should_grow3377, label %bb_set_insert_grow774, label %bb_set_insert_current773

bb_set_insert_current773:
  %set_key_entries_offset_mirror3378 = add i64 %mutable_capacity3284, 23
  %set_key_entries_offset3379 = and i64 %set_key_entries_offset_mirror3378, -8
  %set_key_entries3380 = getelementptr i8, ptr %mutable_ptr3282, i64 %set_key_entries_offset3379
  %set_key_entry_offset3381 = mul i64 %generic_dict_insert_first_slot_result3373, 4
  %set_key_slot3382 = getelementptr i8, ptr %set_key_entries3380, i64 %set_key_entry_offset3381
  store i32 11, ptr %set_key_slot3382, align 4
  %generic_dict_control_slot3383 = getelementptr i8, ptr %mutable_ptr3282, i64 %generic_dict_insert_first_slot_result3373
  store i8 %dict_h2_byte3293, ptr %generic_dict_control_slot3383, align 1
  %generic_dict_control_mirrored3384 = icmp ult i64 %generic_dict_insert_first_slot_result3373, 16
  br i1 %generic_dict_control_mirrored3384, label %bb_generic_dict_control_mirror776, label %bb_generic_dict_control_done777

bb_generic_dict_control_mirror776:
  %generic_dict_control_mirror_index3385 = add i64 %mutable_capacity3284, %generic_dict_insert_first_slot_result3373
  %generic_dict_control_mirror_slot3386 = getelementptr i8, ptr %mutable_ptr3282, i64 %generic_dict_control_mirror_index3385
  store i8 %dict_h2_byte3293, ptr %generic_dict_control_mirror_slot3386, align 1
  br label %bb_generic_dict_control_done777

bb_generic_dict_control_done777:
  br label %bb_set_insert_done775

bb_set_insert_grow774:
  %set_grown_capacity3387 = mul i64 %mutable_capacity3284, 2
  %generic_dict_entries_offset_mirror3388 = add i64 %set_grown_capacity3387, 23
  %generic_dict_entries_offset3389 = and i64 %generic_dict_entries_offset_mirror3388, -8
  %generic_dict_entries_bytes3390 = mul i64 %set_grown_capacity3387, 4
  %generic_dict_bytes3391 = add i64 %generic_dict_entries_offset3389, %generic_dict_entries_bytes3390
  %heap3392 = call ptr @sollang_alloc(i64 %generic_dict_bytes3391)
  %heap_ok3393 = icmp ne ptr %heap3392, null
  br i1 %heap_ok3393, label %bb_alloc_ok778, label %bb_alloc_fail779

bb_alloc_fail779:
  %trap_stderr3394 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr3394, ptr @.slg.str.module.x.11, i32 25, ptr %trap_written3395, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok778:
  %generic_dict_control_bytes3396 = add i64 %set_grown_capacity3387, 16
  call void @llvm.memset.p0.i64(ptr %heap3392, i8 0, i64 %generic_dict_control_bytes3396, i1 false)
  br label %bb_set_rehash780

bb_set_rehash780:
  %set_rehash_index3398 = phi i64 [ 0, %bb_alloc_ok778 ], [ %set_rehash_next_index3397, %bb_set_rehash_next783 ]
  %set_rehash_active3399 = icmp ult i64 %set_rehash_index3398, %mutable_capacity3284
  br i1 %set_rehash_active3399, label %bb_set_rehash_body781, label %bb_set_rehash_done784

bb_set_rehash_body781:
  %generic_dict_control_slot3400 = getelementptr i8, ptr %mutable_ptr3282, i64 %set_rehash_index3398
  %generic_dict_control3401 = load i8, ptr %generic_dict_control_slot3400, align 1
  %set_rehash_occupied3402 = icmp sgt i8 %generic_dict_control3401, 0
  br i1 %set_rehash_occupied3402, label %bb_set_rehash_move782, label %bb_set_rehash_next783

bb_set_rehash_move782:
  %set_rehash_key_entries_offset_mirror3403 = add i64 %mutable_capacity3284, 23
  %set_rehash_key_entries_offset3404 = and i64 %set_rehash_key_entries_offset_mirror3403, -8
  %set_rehash_key_entries3405 = getelementptr i8, ptr %mutable_ptr3282, i64 %set_rehash_key_entries_offset3404
  %set_rehash_key_entry_offset3406 = mul i64 %set_rehash_index3398, 4
  %set_rehash_key_slot3407 = getelementptr i8, ptr %set_rehash_key_entries3405, i64 %set_rehash_key_entry_offset3406
  %set_rehash_key3408 = load i32, ptr %set_rehash_key_slot3407, align 4
  %hash_key3409 = sext i32 %set_rehash_key3408 to i64
  %hash_high3411 = lshr i64 %hash_key3409, 32
  %hash_fold3410 = xor i64 %hash_key3409, %hash_high3411
  %hash3412 = mul i64 %hash_fold3410, -7046029254386353131
  %dict_h2_shifted3413 = lshr i64 %hash3412, 57
  %dict_h2_raw3414 = and i64 %dict_h2_shifted3413, 127
  %dict_h2_zero3415 = icmp eq i64 %dict_h2_raw3414, 0
  %dict_h23416 = select i1 %dict_h2_zero3415, i64 1, i64 %dict_h2_raw3414
  %dict_h2_byte3417 = trunc i64 %dict_h23416 to i8
  %dict_capacity_mask3418 = sub i64 %set_grown_capacity3387, 1
  %dict_start_slot3419 = and i64 %hash3412, %dict_capacity_mask3418
  %generic_dict_insert_has_capacity3420 = icmp ugt i64 %set_grown_capacity3387, 0
  br i1 %generic_dict_insert_has_capacity3420, label %bb_generic_dict_insert_first791, label %bb_generic_dict_insert_no_capacity792

bb_generic_dict_insert_no_capacity792:
  br label %bb_generic_dict_insert_first_done790

bb_generic_dict_insert_first791:
  %generic_dict_control_slot3421 = getelementptr i8, ptr %heap3392, i64 %dict_start_slot3419
  %generic_dict_control3422 = load i8, ptr %generic_dict_control_slot3421, align 1
  %generic_dict_insert_first_empty3423 = icmp eq i8 %generic_dict_control3422, 0
  br i1 %generic_dict_insert_first_empty3423, label %bb_generic_dict_insert_first_vacant789, label %bb_generic_dict_insert_first_occupied785

bb_generic_dict_insert_first_occupied785:
  %generic_dict_insert_first_h23424 = icmp eq i8 %generic_dict_control3422, %dict_h2_byte3417
  br i1 %generic_dict_insert_first_h23424, label %bb_generic_dict_insert_first_compare786, label %bb_generic_dict_insert_first_fallback788

bb_generic_dict_insert_first_compare786:
  %generic_dict_insert_first_key_entries_offset_mirror3425 = add i64 %set_grown_capacity3387, 23
  %generic_dict_insert_first_key_entries_offset3426 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3425, -8
  %generic_dict_insert_first_key_entries3427 = getelementptr i8, ptr %heap3392, i64 %generic_dict_insert_first_key_entries_offset3426
  %generic_dict_insert_first_key_entry_offset3428 = mul i64 %dict_start_slot3419, 4
  %generic_dict_insert_first_key_slot3429 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3427, i64 %generic_dict_insert_first_key_entry_offset3428
  %generic_dict_insert_first_key3430 = load i32, ptr %generic_dict_insert_first_key_slot3429, align 4
  %generic_dict_key_equal3431 = icmp eq i32 %generic_dict_insert_first_key3430, %set_rehash_key3408
  br i1 %generic_dict_key_equal3431, label %bb_generic_dict_insert_first_match787, label %bb_generic_dict_insert_first_fallback788

bb_generic_dict_insert_first_match787:
  br label %bb_generic_dict_insert_first_done790

bb_generic_dict_insert_first_vacant789:
  br label %bb_generic_dict_insert_first_done790

bb_generic_dict_insert_first_fallback788:
  %hash_key3432 = sext i32 %set_rehash_key3408 to i64
  %hash_high3434 = lshr i64 %hash_key3432, 32
  %hash_fold3433 = xor i64 %hash_key3432, %hash_high3434
  %hash3435 = mul i64 %hash_fold3433, -7046029254386353131
  %dict_h2_shifted3436 = lshr i64 %hash3435, 57
  %dict_h2_raw3437 = and i64 %dict_h2_shifted3436, 127
  %dict_h2_zero3438 = icmp eq i64 %dict_h2_raw3437, 0
  %dict_h23439 = select i1 %dict_h2_zero3438, i64 1, i64 %dict_h2_raw3437
  %dict_h2_byte3440 = trunc i64 %dict_h23439 to i8
  %dict_capacity_mask3441 = sub i64 %set_grown_capacity3387, 1
  %dict_start_slot3442 = and i64 %hash3435, %dict_capacity_mask3441
  br label %bb_generic_dict_group_find793

bb_generic_dict_group_find793:
  %generic_dict_group_probe3445 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback788 ], [ %generic_dict_group_next_probe3443, %bb_generic_dict_group_next801 ]
  %generic_dict_group_deleted3446 = phi i64 [ %set_grown_capacity3387, %bb_generic_dict_insert_first_fallback788 ], [ %generic_dict_group_next_deleted3444, %bb_generic_dict_group_next801 ]
  %generic_dict_group_active3447 = icmp ult i64 %generic_dict_group_probe3445, %set_grown_capacity3387
  br i1 %generic_dict_group_active3447, label %bb_generic_dict_group_body794, label %bb_generic_dict_group_miss802

bb_generic_dict_group_body794:
  %generic_dict_group_unwrapped3448 = add i64 %dict_start_slot3442, %generic_dict_group_probe3445
  %generic_dict_group_start3449 = and i64 %generic_dict_group_unwrapped3448, %dict_capacity_mask3441
  %generic_dict_group_pointer3450 = getelementptr i8, ptr %heap3392, i64 %generic_dict_group_start3449
  %generic_dict_group_controls3451 = load <16 x i8>, ptr %generic_dict_group_pointer3450, align 1
  %generic_dict_group_h2_seed3452 = insertelement <16 x i8> poison, i8 %dict_h2_byte3440, i64 0
  %generic_dict_group_h2_vector3453 = shufflevector <16 x i8> %generic_dict_group_h2_seed3452, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3454 = icmp eq <16 x i8> %generic_dict_group_controls3451, %generic_dict_group_h2_vector3453
  %generic_dict_group_match_bits3455 = bitcast <16 x i1> %generic_dict_group_matches_vector3454 to i16
  %generic_dict_group_empty_vector3456 = icmp eq <16 x i8> %generic_dict_group_controls3451, zeroinitializer
  %generic_dict_group_empty_bits3457 = bitcast <16 x i1> %generic_dict_group_empty_vector3456 to i16
  %generic_dict_group_deleted_seed3458 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3459 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3458, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3460 = icmp eq <16 x i8> %generic_dict_group_controls3451, %generic_dict_group_deleted_vector3459
  %generic_dict_group_deleted_bits3461 = bitcast <16 x i1> %generic_dict_group_deleted_matches3460 to i16
  %generic_dict_group_has_deleted3462 = icmp ne i16 %generic_dict_group_deleted_bits3461, 0
  %generic_dict_group_no_previous_deleted3463 = icmp eq i64 %generic_dict_group_deleted3446, %set_grown_capacity3387
  %generic_dict_group_capture_deleted3464 = and i1 %generic_dict_group_has_deleted3462, %generic_dict_group_no_previous_deleted3463
  %generic_dict_group_deleted_offset163465 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3461, i1 false)
  %generic_dict_group_deleted_offset3466 = zext i16 %generic_dict_group_deleted_offset163465 to i64
  %generic_dict_group_deleted_unwrapped3467 = add i64 %generic_dict_group_start3449, %generic_dict_group_deleted_offset3466
  %generic_dict_group_deleted_slot3468 = and i64 %generic_dict_group_deleted_unwrapped3467, %dict_capacity_mask3441
  %generic_dict_group_captured_deleted3469 = select i1 %generic_dict_group_capture_deleted3464, i64 %generic_dict_group_deleted_slot3468, i64 %generic_dict_group_deleted3446
  br label %bb_generic_dict_candidate_loop795

bb_generic_dict_candidate_loop795:
  %generic_dict_candidate_bits3470 = phi i16 [ %generic_dict_group_match_bits3455, %bb_generic_dict_group_body794 ], [ %generic_dict_candidate_cleared_bits3471, %bb_generic_dict_candidate_next797 ]
  %generic_dict_has_candidate3472 = icmp ne i16 %generic_dict_candidate_bits3470, 0
  br i1 %generic_dict_has_candidate3472, label %bb_generic_dict_candidate_body796, label %bb_generic_dict_group_decision798

bb_generic_dict_candidate_body796:
  %generic_dict_candidate_offset163473 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3470, i1 false)
  %generic_dict_candidate_offset3474 = zext i16 %generic_dict_candidate_offset163473 to i64
  %generic_dict_candidate_unwrapped3475 = add i64 %generic_dict_group_start3449, %generic_dict_candidate_offset3474
  %generic_dict_candidate_slot3476 = and i64 %generic_dict_candidate_unwrapped3475, %dict_capacity_mask3441
  %generic_dict_key_entries_offset_mirror3477 = add i64 %set_grown_capacity3387, 23
  %generic_dict_key_entries_offset3478 = and i64 %generic_dict_key_entries_offset_mirror3477, -8
  %generic_dict_key_entries3479 = getelementptr i8, ptr %heap3392, i64 %generic_dict_key_entries_offset3478
  %generic_dict_key_entry_offset3480 = mul i64 %generic_dict_candidate_slot3476, 4
  %generic_dict_key_slot3481 = getelementptr i8, ptr %generic_dict_key_entries3479, i64 %generic_dict_key_entry_offset3480
  %generic_dict_key3482 = load i32, ptr %generic_dict_key_slot3481, align 4
  %generic_dict_key_equal3483 = icmp eq i32 %generic_dict_key3482, %set_rehash_key3408
  br i1 %generic_dict_key_equal3483, label %bb_generic_dict_group_match800, label %bb_generic_dict_candidate_next797

bb_generic_dict_candidate_next797:
  %generic_dict_candidate_bits_minus_one3484 = sub i16 %generic_dict_candidate_bits3470, 1
  %generic_dict_candidate_cleared_bits3471 = and i16 %generic_dict_candidate_bits3470, %generic_dict_candidate_bits_minus_one3484
  br label %bb_generic_dict_candidate_loop795

bb_generic_dict_group_decision798:
  %generic_dict_group_has_empty3485 = icmp ne i16 %generic_dict_group_empty_bits3457, 0
  br i1 %generic_dict_group_has_empty3485, label %bb_generic_dict_group_empty799, label %bb_generic_dict_group_next801

bb_generic_dict_group_empty799:
  %generic_dict_group_empty_offset163486 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3457, i1 false)
  %generic_dict_group_empty_offset3487 = zext i16 %generic_dict_group_empty_offset163486 to i64
  %generic_dict_group_empty_unwrapped3488 = add i64 %generic_dict_group_start3449, %generic_dict_group_empty_offset3487
  %generic_dict_group_empty_slot3489 = and i64 %generic_dict_group_empty_unwrapped3488, %dict_capacity_mask3441
  %generic_dict_group_use_empty3490 = icmp eq i64 %generic_dict_group_captured_deleted3469, %set_grown_capacity3387
  %generic_dict_group_insertion_slot3491 = select i1 %generic_dict_group_use_empty3490, i64 %generic_dict_group_empty_slot3489, i64 %generic_dict_group_captured_deleted3469
  br label %bb_generic_dict_group_done803

bb_generic_dict_group_match800:
  br label %bb_generic_dict_group_done803

bb_generic_dict_group_next801:
  %generic_dict_group_next_probe3443 = add i64 %generic_dict_group_probe3445, 16
  %generic_dict_group_next_deleted3444 = add i64 %generic_dict_group_captured_deleted3469, 0
  br label %bb_generic_dict_group_find793

bb_generic_dict_group_miss802:
  %generic_dict_group_miss_no_deleted3492 = icmp eq i64 %generic_dict_group_deleted3446, %set_grown_capacity3387
  %generic_dict_group_miss_slot3493 = select i1 %generic_dict_group_miss_no_deleted3492, i64 0, i64 %generic_dict_group_deleted3446
  br label %bb_generic_dict_group_done803

bb_generic_dict_group_done803:
  %generic_dict_find_found3494 = phi i1 [ false, %bb_generic_dict_group_empty799 ], [ true, %bb_generic_dict_group_match800 ], [ false, %bb_generic_dict_group_miss802 ]
  %generic_dict_find_slot_result3495 = phi i64 [ %generic_dict_group_insertion_slot3491, %bb_generic_dict_group_empty799 ], [ %generic_dict_candidate_slot3476, %bb_generic_dict_group_match800 ], [ %generic_dict_group_miss_slot3493, %bb_generic_dict_group_miss802 ]
  br label %bb_generic_dict_insert_first_done790

bb_generic_dict_insert_first_done790:
  %generic_dict_insert_first_found3496 = phi i1 [ true, %bb_generic_dict_insert_first_match787 ], [ false, %bb_generic_dict_insert_first_vacant789 ], [ %generic_dict_find_found3494, %bb_generic_dict_group_done803 ], [ false, %bb_generic_dict_insert_no_capacity792 ]
  %generic_dict_insert_first_slot_result3497 = phi i64 [ %dict_start_slot3419, %bb_generic_dict_insert_first_match787 ], [ %dict_start_slot3419, %bb_generic_dict_insert_first_vacant789 ], [ %generic_dict_find_slot_result3495, %bb_generic_dict_group_done803 ], [ 0, %bb_generic_dict_insert_no_capacity792 ]
  %set_key_entries_offset_mirror3498 = add i64 %set_grown_capacity3387, 23
  %set_key_entries_offset3499 = and i64 %set_key_entries_offset_mirror3498, -8
  %set_key_entries3500 = getelementptr i8, ptr %heap3392, i64 %set_key_entries_offset3499
  %set_key_entry_offset3501 = mul i64 %generic_dict_insert_first_slot_result3497, 4
  %set_key_slot3502 = getelementptr i8, ptr %set_key_entries3500, i64 %set_key_entry_offset3501
  store i32 %set_rehash_key3408, ptr %set_key_slot3502, align 4
  %generic_dict_control_slot3503 = getelementptr i8, ptr %heap3392, i64 %generic_dict_insert_first_slot_result3497
  store i8 %dict_h2_byte3417, ptr %generic_dict_control_slot3503, align 1
  %generic_dict_control_mirrored3504 = icmp ult i64 %generic_dict_insert_first_slot_result3497, 16
  br i1 %generic_dict_control_mirrored3504, label %bb_generic_dict_control_mirror804, label %bb_generic_dict_control_done805

bb_generic_dict_control_mirror804:
  %generic_dict_control_mirror_index3505 = add i64 %set_grown_capacity3387, %generic_dict_insert_first_slot_result3497
  %generic_dict_control_mirror_slot3506 = getelementptr i8, ptr %heap3392, i64 %generic_dict_control_mirror_index3505
  store i8 %dict_h2_byte3417, ptr %generic_dict_control_mirror_slot3506, align 1
  br label %bb_generic_dict_control_done805

bb_generic_dict_control_done805:
  br label %bb_set_rehash_next783

bb_set_rehash_next783:
  %set_rehash_next_index3397 = add i64 %set_rehash_index3398, 1
  br label %bb_set_rehash780

bb_set_rehash_done784:
  call void @sollang_free(ptr %mutable_ptr3282)
  %hash_key3507 = sext i32 11 to i64
  %hash_high3509 = lshr i64 %hash_key3507, 32
  %hash_fold3508 = xor i64 %hash_key3507, %hash_high3509
  %hash3510 = mul i64 %hash_fold3508, -7046029254386353131
  %dict_h2_shifted3511 = lshr i64 %hash3510, 57
  %dict_h2_raw3512 = and i64 %dict_h2_shifted3511, 127
  %dict_h2_zero3513 = icmp eq i64 %dict_h2_raw3512, 0
  %dict_h23514 = select i1 %dict_h2_zero3513, i64 1, i64 %dict_h2_raw3512
  %dict_h2_byte3515 = trunc i64 %dict_h23514 to i8
  %dict_capacity_mask3516 = sub i64 %set_grown_capacity3387, 1
  %dict_start_slot3517 = and i64 %hash3510, %dict_capacity_mask3516
  %generic_dict_insert_has_capacity3518 = icmp ugt i64 %set_grown_capacity3387, 0
  br i1 %generic_dict_insert_has_capacity3518, label %bb_generic_dict_insert_first812, label %bb_generic_dict_insert_no_capacity813

bb_generic_dict_insert_no_capacity813:
  br label %bb_generic_dict_insert_first_done811

bb_generic_dict_insert_first812:
  %generic_dict_control_slot3519 = getelementptr i8, ptr %heap3392, i64 %dict_start_slot3517
  %generic_dict_control3520 = load i8, ptr %generic_dict_control_slot3519, align 1
  %generic_dict_insert_first_empty3521 = icmp eq i8 %generic_dict_control3520, 0
  br i1 %generic_dict_insert_first_empty3521, label %bb_generic_dict_insert_first_vacant810, label %bb_generic_dict_insert_first_occupied806

bb_generic_dict_insert_first_occupied806:
  %generic_dict_insert_first_h23522 = icmp eq i8 %generic_dict_control3520, %dict_h2_byte3515
  br i1 %generic_dict_insert_first_h23522, label %bb_generic_dict_insert_first_compare807, label %bb_generic_dict_insert_first_fallback809

bb_generic_dict_insert_first_compare807:
  %generic_dict_insert_first_key_entries_offset_mirror3523 = add i64 %set_grown_capacity3387, 23
  %generic_dict_insert_first_key_entries_offset3524 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3523, -8
  %generic_dict_insert_first_key_entries3525 = getelementptr i8, ptr %heap3392, i64 %generic_dict_insert_first_key_entries_offset3524
  %generic_dict_insert_first_key_entry_offset3526 = mul i64 %dict_start_slot3517, 4
  %generic_dict_insert_first_key_slot3527 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3525, i64 %generic_dict_insert_first_key_entry_offset3526
  %generic_dict_insert_first_key3528 = load i32, ptr %generic_dict_insert_first_key_slot3527, align 4
  %generic_dict_key_equal3529 = icmp eq i32 %generic_dict_insert_first_key3528, 11
  br i1 %generic_dict_key_equal3529, label %bb_generic_dict_insert_first_match808, label %bb_generic_dict_insert_first_fallback809

bb_generic_dict_insert_first_match808:
  br label %bb_generic_dict_insert_first_done811

bb_generic_dict_insert_first_vacant810:
  br label %bb_generic_dict_insert_first_done811

bb_generic_dict_insert_first_fallback809:
  %hash_key3530 = sext i32 11 to i64
  %hash_high3532 = lshr i64 %hash_key3530, 32
  %hash_fold3531 = xor i64 %hash_key3530, %hash_high3532
  %hash3533 = mul i64 %hash_fold3531, -7046029254386353131
  %dict_h2_shifted3534 = lshr i64 %hash3533, 57
  %dict_h2_raw3535 = and i64 %dict_h2_shifted3534, 127
  %dict_h2_zero3536 = icmp eq i64 %dict_h2_raw3535, 0
  %dict_h23537 = select i1 %dict_h2_zero3536, i64 1, i64 %dict_h2_raw3535
  %dict_h2_byte3538 = trunc i64 %dict_h23537 to i8
  %dict_capacity_mask3539 = sub i64 %set_grown_capacity3387, 1
  %dict_start_slot3540 = and i64 %hash3533, %dict_capacity_mask3539
  br label %bb_generic_dict_group_find814

bb_generic_dict_group_find814:
  %generic_dict_group_probe3543 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback809 ], [ %generic_dict_group_next_probe3541, %bb_generic_dict_group_next822 ]
  %generic_dict_group_deleted3544 = phi i64 [ %set_grown_capacity3387, %bb_generic_dict_insert_first_fallback809 ], [ %generic_dict_group_next_deleted3542, %bb_generic_dict_group_next822 ]
  %generic_dict_group_active3545 = icmp ult i64 %generic_dict_group_probe3543, %set_grown_capacity3387
  br i1 %generic_dict_group_active3545, label %bb_generic_dict_group_body815, label %bb_generic_dict_group_miss823

bb_generic_dict_group_body815:
  %generic_dict_group_unwrapped3546 = add i64 %dict_start_slot3540, %generic_dict_group_probe3543
  %generic_dict_group_start3547 = and i64 %generic_dict_group_unwrapped3546, %dict_capacity_mask3539
  %generic_dict_group_pointer3548 = getelementptr i8, ptr %heap3392, i64 %generic_dict_group_start3547
  %generic_dict_group_controls3549 = load <16 x i8>, ptr %generic_dict_group_pointer3548, align 1
  %generic_dict_group_h2_seed3550 = insertelement <16 x i8> poison, i8 %dict_h2_byte3538, i64 0
  %generic_dict_group_h2_vector3551 = shufflevector <16 x i8> %generic_dict_group_h2_seed3550, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3552 = icmp eq <16 x i8> %generic_dict_group_controls3549, %generic_dict_group_h2_vector3551
  %generic_dict_group_match_bits3553 = bitcast <16 x i1> %generic_dict_group_matches_vector3552 to i16
  %generic_dict_group_empty_vector3554 = icmp eq <16 x i8> %generic_dict_group_controls3549, zeroinitializer
  %generic_dict_group_empty_bits3555 = bitcast <16 x i1> %generic_dict_group_empty_vector3554 to i16
  %generic_dict_group_deleted_seed3556 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3557 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3556, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3558 = icmp eq <16 x i8> %generic_dict_group_controls3549, %generic_dict_group_deleted_vector3557
  %generic_dict_group_deleted_bits3559 = bitcast <16 x i1> %generic_dict_group_deleted_matches3558 to i16
  %generic_dict_group_has_deleted3560 = icmp ne i16 %generic_dict_group_deleted_bits3559, 0
  %generic_dict_group_no_previous_deleted3561 = icmp eq i64 %generic_dict_group_deleted3544, %set_grown_capacity3387
  %generic_dict_group_capture_deleted3562 = and i1 %generic_dict_group_has_deleted3560, %generic_dict_group_no_previous_deleted3561
  %generic_dict_group_deleted_offset163563 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3559, i1 false)
  %generic_dict_group_deleted_offset3564 = zext i16 %generic_dict_group_deleted_offset163563 to i64
  %generic_dict_group_deleted_unwrapped3565 = add i64 %generic_dict_group_start3547, %generic_dict_group_deleted_offset3564
  %generic_dict_group_deleted_slot3566 = and i64 %generic_dict_group_deleted_unwrapped3565, %dict_capacity_mask3539
  %generic_dict_group_captured_deleted3567 = select i1 %generic_dict_group_capture_deleted3562, i64 %generic_dict_group_deleted_slot3566, i64 %generic_dict_group_deleted3544
  br label %bb_generic_dict_candidate_loop816

bb_generic_dict_candidate_loop816:
  %generic_dict_candidate_bits3568 = phi i16 [ %generic_dict_group_match_bits3553, %bb_generic_dict_group_body815 ], [ %generic_dict_candidate_cleared_bits3569, %bb_generic_dict_candidate_next818 ]
  %generic_dict_has_candidate3570 = icmp ne i16 %generic_dict_candidate_bits3568, 0
  br i1 %generic_dict_has_candidate3570, label %bb_generic_dict_candidate_body817, label %bb_generic_dict_group_decision819

bb_generic_dict_candidate_body817:
  %generic_dict_candidate_offset163571 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3568, i1 false)
  %generic_dict_candidate_offset3572 = zext i16 %generic_dict_candidate_offset163571 to i64
  %generic_dict_candidate_unwrapped3573 = add i64 %generic_dict_group_start3547, %generic_dict_candidate_offset3572
  %generic_dict_candidate_slot3574 = and i64 %generic_dict_candidate_unwrapped3573, %dict_capacity_mask3539
  %generic_dict_key_entries_offset_mirror3575 = add i64 %set_grown_capacity3387, 23
  %generic_dict_key_entries_offset3576 = and i64 %generic_dict_key_entries_offset_mirror3575, -8
  %generic_dict_key_entries3577 = getelementptr i8, ptr %heap3392, i64 %generic_dict_key_entries_offset3576
  %generic_dict_key_entry_offset3578 = mul i64 %generic_dict_candidate_slot3574, 4
  %generic_dict_key_slot3579 = getelementptr i8, ptr %generic_dict_key_entries3577, i64 %generic_dict_key_entry_offset3578
  %generic_dict_key3580 = load i32, ptr %generic_dict_key_slot3579, align 4
  %generic_dict_key_equal3581 = icmp eq i32 %generic_dict_key3580, 11
  br i1 %generic_dict_key_equal3581, label %bb_generic_dict_group_match821, label %bb_generic_dict_candidate_next818

bb_generic_dict_candidate_next818:
  %generic_dict_candidate_bits_minus_one3582 = sub i16 %generic_dict_candidate_bits3568, 1
  %generic_dict_candidate_cleared_bits3569 = and i16 %generic_dict_candidate_bits3568, %generic_dict_candidate_bits_minus_one3582
  br label %bb_generic_dict_candidate_loop816

bb_generic_dict_group_decision819:
  %generic_dict_group_has_empty3583 = icmp ne i16 %generic_dict_group_empty_bits3555, 0
  br i1 %generic_dict_group_has_empty3583, label %bb_generic_dict_group_empty820, label %bb_generic_dict_group_next822

bb_generic_dict_group_empty820:
  %generic_dict_group_empty_offset163584 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3555, i1 false)
  %generic_dict_group_empty_offset3585 = zext i16 %generic_dict_group_empty_offset163584 to i64
  %generic_dict_group_empty_unwrapped3586 = add i64 %generic_dict_group_start3547, %generic_dict_group_empty_offset3585
  %generic_dict_group_empty_slot3587 = and i64 %generic_dict_group_empty_unwrapped3586, %dict_capacity_mask3539
  %generic_dict_group_use_empty3588 = icmp eq i64 %generic_dict_group_captured_deleted3567, %set_grown_capacity3387
  %generic_dict_group_insertion_slot3589 = select i1 %generic_dict_group_use_empty3588, i64 %generic_dict_group_empty_slot3587, i64 %generic_dict_group_captured_deleted3567
  br label %bb_generic_dict_group_done824

bb_generic_dict_group_match821:
  br label %bb_generic_dict_group_done824

bb_generic_dict_group_next822:
  %generic_dict_group_next_probe3541 = add i64 %generic_dict_group_probe3543, 16
  %generic_dict_group_next_deleted3542 = add i64 %generic_dict_group_captured_deleted3567, 0
  br label %bb_generic_dict_group_find814

bb_generic_dict_group_miss823:
  %generic_dict_group_miss_no_deleted3590 = icmp eq i64 %generic_dict_group_deleted3544, %set_grown_capacity3387
  %generic_dict_group_miss_slot3591 = select i1 %generic_dict_group_miss_no_deleted3590, i64 0, i64 %generic_dict_group_deleted3544
  br label %bb_generic_dict_group_done824

bb_generic_dict_group_done824:
  %generic_dict_find_found3592 = phi i1 [ false, %bb_generic_dict_group_empty820 ], [ true, %bb_generic_dict_group_match821 ], [ false, %bb_generic_dict_group_miss823 ]
  %generic_dict_find_slot_result3593 = phi i64 [ %generic_dict_group_insertion_slot3589, %bb_generic_dict_group_empty820 ], [ %generic_dict_candidate_slot3574, %bb_generic_dict_group_match821 ], [ %generic_dict_group_miss_slot3591, %bb_generic_dict_group_miss823 ]
  br label %bb_generic_dict_insert_first_done811

bb_generic_dict_insert_first_done811:
  %generic_dict_insert_first_found3594 = phi i1 [ true, %bb_generic_dict_insert_first_match808 ], [ false, %bb_generic_dict_insert_first_vacant810 ], [ %generic_dict_find_found3592, %bb_generic_dict_group_done824 ], [ false, %bb_generic_dict_insert_no_capacity813 ]
  %generic_dict_insert_first_slot_result3595 = phi i64 [ %dict_start_slot3517, %bb_generic_dict_insert_first_match808 ], [ %dict_start_slot3517, %bb_generic_dict_insert_first_vacant810 ], [ %generic_dict_find_slot_result3593, %bb_generic_dict_group_done824 ], [ 0, %bb_generic_dict_insert_no_capacity813 ]
  %set_key_entries_offset_mirror3596 = add i64 %set_grown_capacity3387, 23
  %set_key_entries_offset3597 = and i64 %set_key_entries_offset_mirror3596, -8
  %set_key_entries3598 = getelementptr i8, ptr %heap3392, i64 %set_key_entries_offset3597
  %set_key_entry_offset3599 = mul i64 %generic_dict_insert_first_slot_result3595, 4
  %set_key_slot3600 = getelementptr i8, ptr %set_key_entries3598, i64 %set_key_entry_offset3599
  store i32 11, ptr %set_key_slot3600, align 4
  %generic_dict_control_slot3601 = getelementptr i8, ptr %heap3392, i64 %generic_dict_insert_first_slot_result3595
  store i8 %dict_h2_byte3515, ptr %generic_dict_control_slot3601, align 1
  %generic_dict_control_mirrored3602 = icmp ult i64 %generic_dict_insert_first_slot_result3595, 16
  br i1 %generic_dict_control_mirrored3602, label %bb_generic_dict_control_mirror825, label %bb_generic_dict_control_done826

bb_generic_dict_control_mirror825:
  %generic_dict_control_mirror_index3603 = add i64 %set_grown_capacity3387, %generic_dict_insert_first_slot_result3595
  %generic_dict_control_mirror_slot3604 = getelementptr i8, ptr %heap3392, i64 %generic_dict_control_mirror_index3603
  store i8 %dict_h2_byte3515, ptr %generic_dict_control_mirror_slot3604, align 1
  br label %bb_generic_dict_control_done826

bb_generic_dict_control_done826:
  br label %bb_set_insert_done775

bb_set_insert_done775:
  %set_pointer3605 = phi ptr [ %mutable_ptr3282, %bb_set_insert_duplicate771 ], [ %mutable_ptr3282, %bb_generic_dict_control_done777 ], [ %heap3392, %bb_generic_dict_control_done826 ]
  %set_length3606 = phi i64 [ %mutable_len3283, %bb_set_insert_duplicate771 ], [ %set_insert_length3374, %bb_generic_dict_control_done777 ], [ %set_insert_length3374, %bb_generic_dict_control_done826 ]
  %set_capacity3607 = phi i64 [ %mutable_capacity3284, %bb_set_insert_duplicate771 ], [ %mutable_capacity3284, %bb_generic_dict_control_done777 ], [ %set_grown_capacity3387, %bb_generic_dict_control_done826 ]
  %set_inserted3608 = phi i1 [ false, %bb_set_insert_duplicate771 ], [ true, %bb_generic_dict_control_done777 ], [ true, %bb_generic_dict_control_done826 ]
  store ptr %set_pointer3605, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length3606, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity3607, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr3609 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len3610 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity3611 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key3612 = sext i32 12 to i64
  %hash_high3614 = lshr i64 %hash_key3612, 32
  %hash_fold3613 = xor i64 %hash_key3612, %hash_high3614
  %hash3615 = mul i64 %hash_fold3613, -7046029254386353131
  %dict_h2_shifted3616 = lshr i64 %hash3615, 57
  %dict_h2_raw3617 = and i64 %dict_h2_shifted3616, 127
  %dict_h2_zero3618 = icmp eq i64 %dict_h2_raw3617, 0
  %dict_h23619 = select i1 %dict_h2_zero3618, i64 1, i64 %dict_h2_raw3617
  %dict_h2_byte3620 = trunc i64 %dict_h23619 to i8
  %dict_capacity_mask3621 = sub i64 %mutable_capacity3611, 1
  %dict_start_slot3622 = and i64 %hash3615, %dict_capacity_mask3621
  %generic_dict_insert_has_capacity3623 = icmp ugt i64 %mutable_capacity3611, 0
  br i1 %generic_dict_insert_has_capacity3623, label %bb_generic_dict_insert_first833, label %bb_generic_dict_insert_no_capacity834

bb_generic_dict_insert_no_capacity834:
  br label %bb_generic_dict_insert_first_done832

bb_generic_dict_insert_first833:
  %generic_dict_control_slot3624 = getelementptr i8, ptr %mutable_ptr3609, i64 %dict_start_slot3622
  %generic_dict_control3625 = load i8, ptr %generic_dict_control_slot3624, align 1
  %generic_dict_insert_first_empty3626 = icmp eq i8 %generic_dict_control3625, 0
  br i1 %generic_dict_insert_first_empty3626, label %bb_generic_dict_insert_first_vacant831, label %bb_generic_dict_insert_first_occupied827

bb_generic_dict_insert_first_occupied827:
  %generic_dict_insert_first_h23627 = icmp eq i8 %generic_dict_control3625, %dict_h2_byte3620
  br i1 %generic_dict_insert_first_h23627, label %bb_generic_dict_insert_first_compare828, label %bb_generic_dict_insert_first_fallback830

bb_generic_dict_insert_first_compare828:
  %generic_dict_insert_first_key_entries_offset_mirror3628 = add i64 %mutable_capacity3611, 23
  %generic_dict_insert_first_key_entries_offset3629 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3628, -8
  %generic_dict_insert_first_key_entries3630 = getelementptr i8, ptr %mutable_ptr3609, i64 %generic_dict_insert_first_key_entries_offset3629
  %generic_dict_insert_first_key_entry_offset3631 = mul i64 %dict_start_slot3622, 4
  %generic_dict_insert_first_key_slot3632 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3630, i64 %generic_dict_insert_first_key_entry_offset3631
  %generic_dict_insert_first_key3633 = load i32, ptr %generic_dict_insert_first_key_slot3632, align 4
  %generic_dict_key_equal3634 = icmp eq i32 %generic_dict_insert_first_key3633, 12
  br i1 %generic_dict_key_equal3634, label %bb_generic_dict_insert_first_match829, label %bb_generic_dict_insert_first_fallback830

bb_generic_dict_insert_first_match829:
  br label %bb_generic_dict_insert_first_done832

bb_generic_dict_insert_first_vacant831:
  br label %bb_generic_dict_insert_first_done832

bb_generic_dict_insert_first_fallback830:
  %hash_key3635 = sext i32 12 to i64
  %hash_high3637 = lshr i64 %hash_key3635, 32
  %hash_fold3636 = xor i64 %hash_key3635, %hash_high3637
  %hash3638 = mul i64 %hash_fold3636, -7046029254386353131
  %dict_h2_shifted3639 = lshr i64 %hash3638, 57
  %dict_h2_raw3640 = and i64 %dict_h2_shifted3639, 127
  %dict_h2_zero3641 = icmp eq i64 %dict_h2_raw3640, 0
  %dict_h23642 = select i1 %dict_h2_zero3641, i64 1, i64 %dict_h2_raw3640
  %dict_h2_byte3643 = trunc i64 %dict_h23642 to i8
  %dict_capacity_mask3644 = sub i64 %mutable_capacity3611, 1
  %dict_start_slot3645 = and i64 %hash3638, %dict_capacity_mask3644
  br label %bb_generic_dict_group_find835

bb_generic_dict_group_find835:
  %generic_dict_group_probe3648 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback830 ], [ %generic_dict_group_next_probe3646, %bb_generic_dict_group_next843 ]
  %generic_dict_group_deleted3649 = phi i64 [ %mutable_capacity3611, %bb_generic_dict_insert_first_fallback830 ], [ %generic_dict_group_next_deleted3647, %bb_generic_dict_group_next843 ]
  %generic_dict_group_active3650 = icmp ult i64 %generic_dict_group_probe3648, %mutable_capacity3611
  br i1 %generic_dict_group_active3650, label %bb_generic_dict_group_body836, label %bb_generic_dict_group_miss844

bb_generic_dict_group_body836:
  %generic_dict_group_unwrapped3651 = add i64 %dict_start_slot3645, %generic_dict_group_probe3648
  %generic_dict_group_start3652 = and i64 %generic_dict_group_unwrapped3651, %dict_capacity_mask3644
  %generic_dict_group_pointer3653 = getelementptr i8, ptr %mutable_ptr3609, i64 %generic_dict_group_start3652
  %generic_dict_group_controls3654 = load <16 x i8>, ptr %generic_dict_group_pointer3653, align 1
  %generic_dict_group_h2_seed3655 = insertelement <16 x i8> poison, i8 %dict_h2_byte3643, i64 0
  %generic_dict_group_h2_vector3656 = shufflevector <16 x i8> %generic_dict_group_h2_seed3655, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3657 = icmp eq <16 x i8> %generic_dict_group_controls3654, %generic_dict_group_h2_vector3656
  %generic_dict_group_match_bits3658 = bitcast <16 x i1> %generic_dict_group_matches_vector3657 to i16
  %generic_dict_group_empty_vector3659 = icmp eq <16 x i8> %generic_dict_group_controls3654, zeroinitializer
  %generic_dict_group_empty_bits3660 = bitcast <16 x i1> %generic_dict_group_empty_vector3659 to i16
  %generic_dict_group_deleted_seed3661 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3662 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3661, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3663 = icmp eq <16 x i8> %generic_dict_group_controls3654, %generic_dict_group_deleted_vector3662
  %generic_dict_group_deleted_bits3664 = bitcast <16 x i1> %generic_dict_group_deleted_matches3663 to i16
  %generic_dict_group_has_deleted3665 = icmp ne i16 %generic_dict_group_deleted_bits3664, 0
  %generic_dict_group_no_previous_deleted3666 = icmp eq i64 %generic_dict_group_deleted3649, %mutable_capacity3611
  %generic_dict_group_capture_deleted3667 = and i1 %generic_dict_group_has_deleted3665, %generic_dict_group_no_previous_deleted3666
  %generic_dict_group_deleted_offset163668 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3664, i1 false)
  %generic_dict_group_deleted_offset3669 = zext i16 %generic_dict_group_deleted_offset163668 to i64
  %generic_dict_group_deleted_unwrapped3670 = add i64 %generic_dict_group_start3652, %generic_dict_group_deleted_offset3669
  %generic_dict_group_deleted_slot3671 = and i64 %generic_dict_group_deleted_unwrapped3670, %dict_capacity_mask3644
  %generic_dict_group_captured_deleted3672 = select i1 %generic_dict_group_capture_deleted3667, i64 %generic_dict_group_deleted_slot3671, i64 %generic_dict_group_deleted3649
  br label %bb_generic_dict_candidate_loop837

bb_generic_dict_candidate_loop837:
  %generic_dict_candidate_bits3673 = phi i16 [ %generic_dict_group_match_bits3658, %bb_generic_dict_group_body836 ], [ %generic_dict_candidate_cleared_bits3674, %bb_generic_dict_candidate_next839 ]
  %generic_dict_has_candidate3675 = icmp ne i16 %generic_dict_candidate_bits3673, 0
  br i1 %generic_dict_has_candidate3675, label %bb_generic_dict_candidate_body838, label %bb_generic_dict_group_decision840

bb_generic_dict_candidate_body838:
  %generic_dict_candidate_offset163676 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3673, i1 false)
  %generic_dict_candidate_offset3677 = zext i16 %generic_dict_candidate_offset163676 to i64
  %generic_dict_candidate_unwrapped3678 = add i64 %generic_dict_group_start3652, %generic_dict_candidate_offset3677
  %generic_dict_candidate_slot3679 = and i64 %generic_dict_candidate_unwrapped3678, %dict_capacity_mask3644
  %generic_dict_key_entries_offset_mirror3680 = add i64 %mutable_capacity3611, 23
  %generic_dict_key_entries_offset3681 = and i64 %generic_dict_key_entries_offset_mirror3680, -8
  %generic_dict_key_entries3682 = getelementptr i8, ptr %mutable_ptr3609, i64 %generic_dict_key_entries_offset3681
  %generic_dict_key_entry_offset3683 = mul i64 %generic_dict_candidate_slot3679, 4
  %generic_dict_key_slot3684 = getelementptr i8, ptr %generic_dict_key_entries3682, i64 %generic_dict_key_entry_offset3683
  %generic_dict_key3685 = load i32, ptr %generic_dict_key_slot3684, align 4
  %generic_dict_key_equal3686 = icmp eq i32 %generic_dict_key3685, 12
  br i1 %generic_dict_key_equal3686, label %bb_generic_dict_group_match842, label %bb_generic_dict_candidate_next839

bb_generic_dict_candidate_next839:
  %generic_dict_candidate_bits_minus_one3687 = sub i16 %generic_dict_candidate_bits3673, 1
  %generic_dict_candidate_cleared_bits3674 = and i16 %generic_dict_candidate_bits3673, %generic_dict_candidate_bits_minus_one3687
  br label %bb_generic_dict_candidate_loop837

bb_generic_dict_group_decision840:
  %generic_dict_group_has_empty3688 = icmp ne i16 %generic_dict_group_empty_bits3660, 0
  br i1 %generic_dict_group_has_empty3688, label %bb_generic_dict_group_empty841, label %bb_generic_dict_group_next843

bb_generic_dict_group_empty841:
  %generic_dict_group_empty_offset163689 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3660, i1 false)
  %generic_dict_group_empty_offset3690 = zext i16 %generic_dict_group_empty_offset163689 to i64
  %generic_dict_group_empty_unwrapped3691 = add i64 %generic_dict_group_start3652, %generic_dict_group_empty_offset3690
  %generic_dict_group_empty_slot3692 = and i64 %generic_dict_group_empty_unwrapped3691, %dict_capacity_mask3644
  %generic_dict_group_use_empty3693 = icmp eq i64 %generic_dict_group_captured_deleted3672, %mutable_capacity3611
  %generic_dict_group_insertion_slot3694 = select i1 %generic_dict_group_use_empty3693, i64 %generic_dict_group_empty_slot3692, i64 %generic_dict_group_captured_deleted3672
  br label %bb_generic_dict_group_done845

bb_generic_dict_group_match842:
  br label %bb_generic_dict_group_done845

bb_generic_dict_group_next843:
  %generic_dict_group_next_probe3646 = add i64 %generic_dict_group_probe3648, 16
  %generic_dict_group_next_deleted3647 = add i64 %generic_dict_group_captured_deleted3672, 0
  br label %bb_generic_dict_group_find835

bb_generic_dict_group_miss844:
  %generic_dict_group_miss_no_deleted3695 = icmp eq i64 %generic_dict_group_deleted3649, %mutable_capacity3611
  %generic_dict_group_miss_slot3696 = select i1 %generic_dict_group_miss_no_deleted3695, i64 0, i64 %generic_dict_group_deleted3649
  br label %bb_generic_dict_group_done845

bb_generic_dict_group_done845:
  %generic_dict_find_found3697 = phi i1 [ false, %bb_generic_dict_group_empty841 ], [ true, %bb_generic_dict_group_match842 ], [ false, %bb_generic_dict_group_miss844 ]
  %generic_dict_find_slot_result3698 = phi i64 [ %generic_dict_group_insertion_slot3694, %bb_generic_dict_group_empty841 ], [ %generic_dict_candidate_slot3679, %bb_generic_dict_group_match842 ], [ %generic_dict_group_miss_slot3696, %bb_generic_dict_group_miss844 ]
  br label %bb_generic_dict_insert_first_done832

bb_generic_dict_insert_first_done832:
  %generic_dict_insert_first_found3699 = phi i1 [ true, %bb_generic_dict_insert_first_match829 ], [ false, %bb_generic_dict_insert_first_vacant831 ], [ %generic_dict_find_found3697, %bb_generic_dict_group_done845 ], [ false, %bb_generic_dict_insert_no_capacity834 ]
  %generic_dict_insert_first_slot_result3700 = phi i64 [ %dict_start_slot3622, %bb_generic_dict_insert_first_match829 ], [ %dict_start_slot3622, %bb_generic_dict_insert_first_vacant831 ], [ %generic_dict_find_slot_result3698, %bb_generic_dict_group_done845 ], [ 0, %bb_generic_dict_insert_no_capacity834 ]
  br i1 %generic_dict_insert_first_found3699, label %bb_set_insert_duplicate846, label %bb_set_insert_new847

bb_set_insert_duplicate846:
  br label %bb_set_insert_done850

bb_set_insert_new847:
  %set_insert_length3701 = add i64 %mutable_len3610, 1
  %set_insert_load_num3702 = mul i64 %set_insert_length3701, 8
  %set_insert_load_den3703 = mul i64 %mutable_capacity3611, 7
  %set_insert_should_grow3704 = icmp ugt i64 %set_insert_load_num3702, %set_insert_load_den3703
  br i1 %set_insert_should_grow3704, label %bb_set_insert_grow849, label %bb_set_insert_current848

bb_set_insert_current848:
  %set_key_entries_offset_mirror3705 = add i64 %mutable_capacity3611, 23
  %set_key_entries_offset3706 = and i64 %set_key_entries_offset_mirror3705, -8
  %set_key_entries3707 = getelementptr i8, ptr %mutable_ptr3609, i64 %set_key_entries_offset3706
  %set_key_entry_offset3708 = mul i64 %generic_dict_insert_first_slot_result3700, 4
  %set_key_slot3709 = getelementptr i8, ptr %set_key_entries3707, i64 %set_key_entry_offset3708
  store i32 12, ptr %set_key_slot3709, align 4
  %generic_dict_control_slot3710 = getelementptr i8, ptr %mutable_ptr3609, i64 %generic_dict_insert_first_slot_result3700
  store i8 %dict_h2_byte3620, ptr %generic_dict_control_slot3710, align 1
  %generic_dict_control_mirrored3711 = icmp ult i64 %generic_dict_insert_first_slot_result3700, 16
  br i1 %generic_dict_control_mirrored3711, label %bb_generic_dict_control_mirror851, label %bb_generic_dict_control_done852

bb_generic_dict_control_mirror851:
  %generic_dict_control_mirror_index3712 = add i64 %mutable_capacity3611, %generic_dict_insert_first_slot_result3700
  %generic_dict_control_mirror_slot3713 = getelementptr i8, ptr %mutable_ptr3609, i64 %generic_dict_control_mirror_index3712
  store i8 %dict_h2_byte3620, ptr %generic_dict_control_mirror_slot3713, align 1
  br label %bb_generic_dict_control_done852

bb_generic_dict_control_done852:
  br label %bb_set_insert_done850

bb_set_insert_grow849:
  %set_grown_capacity3714 = mul i64 %mutable_capacity3611, 2
  %generic_dict_entries_offset_mirror3715 = add i64 %set_grown_capacity3714, 23
  %generic_dict_entries_offset3716 = and i64 %generic_dict_entries_offset_mirror3715, -8
  %generic_dict_entries_bytes3717 = mul i64 %set_grown_capacity3714, 4
  %generic_dict_bytes3718 = add i64 %generic_dict_entries_offset3716, %generic_dict_entries_bytes3717
  %heap3719 = call ptr @sollang_alloc(i64 %generic_dict_bytes3718)
  %heap_ok3720 = icmp ne ptr %heap3719, null
  br i1 %heap_ok3720, label %bb_alloc_ok853, label %bb_alloc_fail854

bb_alloc_fail854:
  %trap_stderr3721 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr3721, ptr @.slg.str.module.x.12, i32 25, ptr %trap_written3722, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok853:
  %generic_dict_control_bytes3723 = add i64 %set_grown_capacity3714, 16
  call void @llvm.memset.p0.i64(ptr %heap3719, i8 0, i64 %generic_dict_control_bytes3723, i1 false)
  br label %bb_set_rehash855

bb_set_rehash855:
  %set_rehash_index3725 = phi i64 [ 0, %bb_alloc_ok853 ], [ %set_rehash_next_index3724, %bb_set_rehash_next858 ]
  %set_rehash_active3726 = icmp ult i64 %set_rehash_index3725, %mutable_capacity3611
  br i1 %set_rehash_active3726, label %bb_set_rehash_body856, label %bb_set_rehash_done859

bb_set_rehash_body856:
  %generic_dict_control_slot3727 = getelementptr i8, ptr %mutable_ptr3609, i64 %set_rehash_index3725
  %generic_dict_control3728 = load i8, ptr %generic_dict_control_slot3727, align 1
  %set_rehash_occupied3729 = icmp sgt i8 %generic_dict_control3728, 0
  br i1 %set_rehash_occupied3729, label %bb_set_rehash_move857, label %bb_set_rehash_next858

bb_set_rehash_move857:
  %set_rehash_key_entries_offset_mirror3730 = add i64 %mutable_capacity3611, 23
  %set_rehash_key_entries_offset3731 = and i64 %set_rehash_key_entries_offset_mirror3730, -8
  %set_rehash_key_entries3732 = getelementptr i8, ptr %mutable_ptr3609, i64 %set_rehash_key_entries_offset3731
  %set_rehash_key_entry_offset3733 = mul i64 %set_rehash_index3725, 4
  %set_rehash_key_slot3734 = getelementptr i8, ptr %set_rehash_key_entries3732, i64 %set_rehash_key_entry_offset3733
  %set_rehash_key3735 = load i32, ptr %set_rehash_key_slot3734, align 4
  %hash_key3736 = sext i32 %set_rehash_key3735 to i64
  %hash_high3738 = lshr i64 %hash_key3736, 32
  %hash_fold3737 = xor i64 %hash_key3736, %hash_high3738
  %hash3739 = mul i64 %hash_fold3737, -7046029254386353131
  %dict_h2_shifted3740 = lshr i64 %hash3739, 57
  %dict_h2_raw3741 = and i64 %dict_h2_shifted3740, 127
  %dict_h2_zero3742 = icmp eq i64 %dict_h2_raw3741, 0
  %dict_h23743 = select i1 %dict_h2_zero3742, i64 1, i64 %dict_h2_raw3741
  %dict_h2_byte3744 = trunc i64 %dict_h23743 to i8
  %dict_capacity_mask3745 = sub i64 %set_grown_capacity3714, 1
  %dict_start_slot3746 = and i64 %hash3739, %dict_capacity_mask3745
  %generic_dict_insert_has_capacity3747 = icmp ugt i64 %set_grown_capacity3714, 0
  br i1 %generic_dict_insert_has_capacity3747, label %bb_generic_dict_insert_first866, label %bb_generic_dict_insert_no_capacity867

bb_generic_dict_insert_no_capacity867:
  br label %bb_generic_dict_insert_first_done865

bb_generic_dict_insert_first866:
  %generic_dict_control_slot3748 = getelementptr i8, ptr %heap3719, i64 %dict_start_slot3746
  %generic_dict_control3749 = load i8, ptr %generic_dict_control_slot3748, align 1
  %generic_dict_insert_first_empty3750 = icmp eq i8 %generic_dict_control3749, 0
  br i1 %generic_dict_insert_first_empty3750, label %bb_generic_dict_insert_first_vacant864, label %bb_generic_dict_insert_first_occupied860

bb_generic_dict_insert_first_occupied860:
  %generic_dict_insert_first_h23751 = icmp eq i8 %generic_dict_control3749, %dict_h2_byte3744
  br i1 %generic_dict_insert_first_h23751, label %bb_generic_dict_insert_first_compare861, label %bb_generic_dict_insert_first_fallback863

bb_generic_dict_insert_first_compare861:
  %generic_dict_insert_first_key_entries_offset_mirror3752 = add i64 %set_grown_capacity3714, 23
  %generic_dict_insert_first_key_entries_offset3753 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3752, -8
  %generic_dict_insert_first_key_entries3754 = getelementptr i8, ptr %heap3719, i64 %generic_dict_insert_first_key_entries_offset3753
  %generic_dict_insert_first_key_entry_offset3755 = mul i64 %dict_start_slot3746, 4
  %generic_dict_insert_first_key_slot3756 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3754, i64 %generic_dict_insert_first_key_entry_offset3755
  %generic_dict_insert_first_key3757 = load i32, ptr %generic_dict_insert_first_key_slot3756, align 4
  %generic_dict_key_equal3758 = icmp eq i32 %generic_dict_insert_first_key3757, %set_rehash_key3735
  br i1 %generic_dict_key_equal3758, label %bb_generic_dict_insert_first_match862, label %bb_generic_dict_insert_first_fallback863

bb_generic_dict_insert_first_match862:
  br label %bb_generic_dict_insert_first_done865

bb_generic_dict_insert_first_vacant864:
  br label %bb_generic_dict_insert_first_done865

bb_generic_dict_insert_first_fallback863:
  %hash_key3759 = sext i32 %set_rehash_key3735 to i64
  %hash_high3761 = lshr i64 %hash_key3759, 32
  %hash_fold3760 = xor i64 %hash_key3759, %hash_high3761
  %hash3762 = mul i64 %hash_fold3760, -7046029254386353131
  %dict_h2_shifted3763 = lshr i64 %hash3762, 57
  %dict_h2_raw3764 = and i64 %dict_h2_shifted3763, 127
  %dict_h2_zero3765 = icmp eq i64 %dict_h2_raw3764, 0
  %dict_h23766 = select i1 %dict_h2_zero3765, i64 1, i64 %dict_h2_raw3764
  %dict_h2_byte3767 = trunc i64 %dict_h23766 to i8
  %dict_capacity_mask3768 = sub i64 %set_grown_capacity3714, 1
  %dict_start_slot3769 = and i64 %hash3762, %dict_capacity_mask3768
  br label %bb_generic_dict_group_find868

bb_generic_dict_group_find868:
  %generic_dict_group_probe3772 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback863 ], [ %generic_dict_group_next_probe3770, %bb_generic_dict_group_next876 ]
  %generic_dict_group_deleted3773 = phi i64 [ %set_grown_capacity3714, %bb_generic_dict_insert_first_fallback863 ], [ %generic_dict_group_next_deleted3771, %bb_generic_dict_group_next876 ]
  %generic_dict_group_active3774 = icmp ult i64 %generic_dict_group_probe3772, %set_grown_capacity3714
  br i1 %generic_dict_group_active3774, label %bb_generic_dict_group_body869, label %bb_generic_dict_group_miss877

bb_generic_dict_group_body869:
  %generic_dict_group_unwrapped3775 = add i64 %dict_start_slot3769, %generic_dict_group_probe3772
  %generic_dict_group_start3776 = and i64 %generic_dict_group_unwrapped3775, %dict_capacity_mask3768
  %generic_dict_group_pointer3777 = getelementptr i8, ptr %heap3719, i64 %generic_dict_group_start3776
  %generic_dict_group_controls3778 = load <16 x i8>, ptr %generic_dict_group_pointer3777, align 1
  %generic_dict_group_h2_seed3779 = insertelement <16 x i8> poison, i8 %dict_h2_byte3767, i64 0
  %generic_dict_group_h2_vector3780 = shufflevector <16 x i8> %generic_dict_group_h2_seed3779, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3781 = icmp eq <16 x i8> %generic_dict_group_controls3778, %generic_dict_group_h2_vector3780
  %generic_dict_group_match_bits3782 = bitcast <16 x i1> %generic_dict_group_matches_vector3781 to i16
  %generic_dict_group_empty_vector3783 = icmp eq <16 x i8> %generic_dict_group_controls3778, zeroinitializer
  %generic_dict_group_empty_bits3784 = bitcast <16 x i1> %generic_dict_group_empty_vector3783 to i16
  %generic_dict_group_deleted_seed3785 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3786 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3785, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3787 = icmp eq <16 x i8> %generic_dict_group_controls3778, %generic_dict_group_deleted_vector3786
  %generic_dict_group_deleted_bits3788 = bitcast <16 x i1> %generic_dict_group_deleted_matches3787 to i16
  %generic_dict_group_has_deleted3789 = icmp ne i16 %generic_dict_group_deleted_bits3788, 0
  %generic_dict_group_no_previous_deleted3790 = icmp eq i64 %generic_dict_group_deleted3773, %set_grown_capacity3714
  %generic_dict_group_capture_deleted3791 = and i1 %generic_dict_group_has_deleted3789, %generic_dict_group_no_previous_deleted3790
  %generic_dict_group_deleted_offset163792 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3788, i1 false)
  %generic_dict_group_deleted_offset3793 = zext i16 %generic_dict_group_deleted_offset163792 to i64
  %generic_dict_group_deleted_unwrapped3794 = add i64 %generic_dict_group_start3776, %generic_dict_group_deleted_offset3793
  %generic_dict_group_deleted_slot3795 = and i64 %generic_dict_group_deleted_unwrapped3794, %dict_capacity_mask3768
  %generic_dict_group_captured_deleted3796 = select i1 %generic_dict_group_capture_deleted3791, i64 %generic_dict_group_deleted_slot3795, i64 %generic_dict_group_deleted3773
  br label %bb_generic_dict_candidate_loop870

bb_generic_dict_candidate_loop870:
  %generic_dict_candidate_bits3797 = phi i16 [ %generic_dict_group_match_bits3782, %bb_generic_dict_group_body869 ], [ %generic_dict_candidate_cleared_bits3798, %bb_generic_dict_candidate_next872 ]
  %generic_dict_has_candidate3799 = icmp ne i16 %generic_dict_candidate_bits3797, 0
  br i1 %generic_dict_has_candidate3799, label %bb_generic_dict_candidate_body871, label %bb_generic_dict_group_decision873

bb_generic_dict_candidate_body871:
  %generic_dict_candidate_offset163800 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3797, i1 false)
  %generic_dict_candidate_offset3801 = zext i16 %generic_dict_candidate_offset163800 to i64
  %generic_dict_candidate_unwrapped3802 = add i64 %generic_dict_group_start3776, %generic_dict_candidate_offset3801
  %generic_dict_candidate_slot3803 = and i64 %generic_dict_candidate_unwrapped3802, %dict_capacity_mask3768
  %generic_dict_key_entries_offset_mirror3804 = add i64 %set_grown_capacity3714, 23
  %generic_dict_key_entries_offset3805 = and i64 %generic_dict_key_entries_offset_mirror3804, -8
  %generic_dict_key_entries3806 = getelementptr i8, ptr %heap3719, i64 %generic_dict_key_entries_offset3805
  %generic_dict_key_entry_offset3807 = mul i64 %generic_dict_candidate_slot3803, 4
  %generic_dict_key_slot3808 = getelementptr i8, ptr %generic_dict_key_entries3806, i64 %generic_dict_key_entry_offset3807
  %generic_dict_key3809 = load i32, ptr %generic_dict_key_slot3808, align 4
  %generic_dict_key_equal3810 = icmp eq i32 %generic_dict_key3809, %set_rehash_key3735
  br i1 %generic_dict_key_equal3810, label %bb_generic_dict_group_match875, label %bb_generic_dict_candidate_next872

bb_generic_dict_candidate_next872:
  %generic_dict_candidate_bits_minus_one3811 = sub i16 %generic_dict_candidate_bits3797, 1
  %generic_dict_candidate_cleared_bits3798 = and i16 %generic_dict_candidate_bits3797, %generic_dict_candidate_bits_minus_one3811
  br label %bb_generic_dict_candidate_loop870

bb_generic_dict_group_decision873:
  %generic_dict_group_has_empty3812 = icmp ne i16 %generic_dict_group_empty_bits3784, 0
  br i1 %generic_dict_group_has_empty3812, label %bb_generic_dict_group_empty874, label %bb_generic_dict_group_next876

bb_generic_dict_group_empty874:
  %generic_dict_group_empty_offset163813 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3784, i1 false)
  %generic_dict_group_empty_offset3814 = zext i16 %generic_dict_group_empty_offset163813 to i64
  %generic_dict_group_empty_unwrapped3815 = add i64 %generic_dict_group_start3776, %generic_dict_group_empty_offset3814
  %generic_dict_group_empty_slot3816 = and i64 %generic_dict_group_empty_unwrapped3815, %dict_capacity_mask3768
  %generic_dict_group_use_empty3817 = icmp eq i64 %generic_dict_group_captured_deleted3796, %set_grown_capacity3714
  %generic_dict_group_insertion_slot3818 = select i1 %generic_dict_group_use_empty3817, i64 %generic_dict_group_empty_slot3816, i64 %generic_dict_group_captured_deleted3796
  br label %bb_generic_dict_group_done878

bb_generic_dict_group_match875:
  br label %bb_generic_dict_group_done878

bb_generic_dict_group_next876:
  %generic_dict_group_next_probe3770 = add i64 %generic_dict_group_probe3772, 16
  %generic_dict_group_next_deleted3771 = add i64 %generic_dict_group_captured_deleted3796, 0
  br label %bb_generic_dict_group_find868

bb_generic_dict_group_miss877:
  %generic_dict_group_miss_no_deleted3819 = icmp eq i64 %generic_dict_group_deleted3773, %set_grown_capacity3714
  %generic_dict_group_miss_slot3820 = select i1 %generic_dict_group_miss_no_deleted3819, i64 0, i64 %generic_dict_group_deleted3773
  br label %bb_generic_dict_group_done878

bb_generic_dict_group_done878:
  %generic_dict_find_found3821 = phi i1 [ false, %bb_generic_dict_group_empty874 ], [ true, %bb_generic_dict_group_match875 ], [ false, %bb_generic_dict_group_miss877 ]
  %generic_dict_find_slot_result3822 = phi i64 [ %generic_dict_group_insertion_slot3818, %bb_generic_dict_group_empty874 ], [ %generic_dict_candidate_slot3803, %bb_generic_dict_group_match875 ], [ %generic_dict_group_miss_slot3820, %bb_generic_dict_group_miss877 ]
  br label %bb_generic_dict_insert_first_done865

bb_generic_dict_insert_first_done865:
  %generic_dict_insert_first_found3823 = phi i1 [ true, %bb_generic_dict_insert_first_match862 ], [ false, %bb_generic_dict_insert_first_vacant864 ], [ %generic_dict_find_found3821, %bb_generic_dict_group_done878 ], [ false, %bb_generic_dict_insert_no_capacity867 ]
  %generic_dict_insert_first_slot_result3824 = phi i64 [ %dict_start_slot3746, %bb_generic_dict_insert_first_match862 ], [ %dict_start_slot3746, %bb_generic_dict_insert_first_vacant864 ], [ %generic_dict_find_slot_result3822, %bb_generic_dict_group_done878 ], [ 0, %bb_generic_dict_insert_no_capacity867 ]
  %set_key_entries_offset_mirror3825 = add i64 %set_grown_capacity3714, 23
  %set_key_entries_offset3826 = and i64 %set_key_entries_offset_mirror3825, -8
  %set_key_entries3827 = getelementptr i8, ptr %heap3719, i64 %set_key_entries_offset3826
  %set_key_entry_offset3828 = mul i64 %generic_dict_insert_first_slot_result3824, 4
  %set_key_slot3829 = getelementptr i8, ptr %set_key_entries3827, i64 %set_key_entry_offset3828
  store i32 %set_rehash_key3735, ptr %set_key_slot3829, align 4
  %generic_dict_control_slot3830 = getelementptr i8, ptr %heap3719, i64 %generic_dict_insert_first_slot_result3824
  store i8 %dict_h2_byte3744, ptr %generic_dict_control_slot3830, align 1
  %generic_dict_control_mirrored3831 = icmp ult i64 %generic_dict_insert_first_slot_result3824, 16
  br i1 %generic_dict_control_mirrored3831, label %bb_generic_dict_control_mirror879, label %bb_generic_dict_control_done880

bb_generic_dict_control_mirror879:
  %generic_dict_control_mirror_index3832 = add i64 %set_grown_capacity3714, %generic_dict_insert_first_slot_result3824
  %generic_dict_control_mirror_slot3833 = getelementptr i8, ptr %heap3719, i64 %generic_dict_control_mirror_index3832
  store i8 %dict_h2_byte3744, ptr %generic_dict_control_mirror_slot3833, align 1
  br label %bb_generic_dict_control_done880

bb_generic_dict_control_done880:
  br label %bb_set_rehash_next858

bb_set_rehash_next858:
  %set_rehash_next_index3724 = add i64 %set_rehash_index3725, 1
  br label %bb_set_rehash855

bb_set_rehash_done859:
  call void @sollang_free(ptr %mutable_ptr3609)
  %hash_key3834 = sext i32 12 to i64
  %hash_high3836 = lshr i64 %hash_key3834, 32
  %hash_fold3835 = xor i64 %hash_key3834, %hash_high3836
  %hash3837 = mul i64 %hash_fold3835, -7046029254386353131
  %dict_h2_shifted3838 = lshr i64 %hash3837, 57
  %dict_h2_raw3839 = and i64 %dict_h2_shifted3838, 127
  %dict_h2_zero3840 = icmp eq i64 %dict_h2_raw3839, 0
  %dict_h23841 = select i1 %dict_h2_zero3840, i64 1, i64 %dict_h2_raw3839
  %dict_h2_byte3842 = trunc i64 %dict_h23841 to i8
  %dict_capacity_mask3843 = sub i64 %set_grown_capacity3714, 1
  %dict_start_slot3844 = and i64 %hash3837, %dict_capacity_mask3843
  %generic_dict_insert_has_capacity3845 = icmp ugt i64 %set_grown_capacity3714, 0
  br i1 %generic_dict_insert_has_capacity3845, label %bb_generic_dict_insert_first887, label %bb_generic_dict_insert_no_capacity888

bb_generic_dict_insert_no_capacity888:
  br label %bb_generic_dict_insert_first_done886

bb_generic_dict_insert_first887:
  %generic_dict_control_slot3846 = getelementptr i8, ptr %heap3719, i64 %dict_start_slot3844
  %generic_dict_control3847 = load i8, ptr %generic_dict_control_slot3846, align 1
  %generic_dict_insert_first_empty3848 = icmp eq i8 %generic_dict_control3847, 0
  br i1 %generic_dict_insert_first_empty3848, label %bb_generic_dict_insert_first_vacant885, label %bb_generic_dict_insert_first_occupied881

bb_generic_dict_insert_first_occupied881:
  %generic_dict_insert_first_h23849 = icmp eq i8 %generic_dict_control3847, %dict_h2_byte3842
  br i1 %generic_dict_insert_first_h23849, label %bb_generic_dict_insert_first_compare882, label %bb_generic_dict_insert_first_fallback884

bb_generic_dict_insert_first_compare882:
  %generic_dict_insert_first_key_entries_offset_mirror3850 = add i64 %set_grown_capacity3714, 23
  %generic_dict_insert_first_key_entries_offset3851 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3850, -8
  %generic_dict_insert_first_key_entries3852 = getelementptr i8, ptr %heap3719, i64 %generic_dict_insert_first_key_entries_offset3851
  %generic_dict_insert_first_key_entry_offset3853 = mul i64 %dict_start_slot3844, 4
  %generic_dict_insert_first_key_slot3854 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3852, i64 %generic_dict_insert_first_key_entry_offset3853
  %generic_dict_insert_first_key3855 = load i32, ptr %generic_dict_insert_first_key_slot3854, align 4
  %generic_dict_key_equal3856 = icmp eq i32 %generic_dict_insert_first_key3855, 12
  br i1 %generic_dict_key_equal3856, label %bb_generic_dict_insert_first_match883, label %bb_generic_dict_insert_first_fallback884

bb_generic_dict_insert_first_match883:
  br label %bb_generic_dict_insert_first_done886

bb_generic_dict_insert_first_vacant885:
  br label %bb_generic_dict_insert_first_done886

bb_generic_dict_insert_first_fallback884:
  %hash_key3857 = sext i32 12 to i64
  %hash_high3859 = lshr i64 %hash_key3857, 32
  %hash_fold3858 = xor i64 %hash_key3857, %hash_high3859
  %hash3860 = mul i64 %hash_fold3858, -7046029254386353131
  %dict_h2_shifted3861 = lshr i64 %hash3860, 57
  %dict_h2_raw3862 = and i64 %dict_h2_shifted3861, 127
  %dict_h2_zero3863 = icmp eq i64 %dict_h2_raw3862, 0
  %dict_h23864 = select i1 %dict_h2_zero3863, i64 1, i64 %dict_h2_raw3862
  %dict_h2_byte3865 = trunc i64 %dict_h23864 to i8
  %dict_capacity_mask3866 = sub i64 %set_grown_capacity3714, 1
  %dict_start_slot3867 = and i64 %hash3860, %dict_capacity_mask3866
  br label %bb_generic_dict_group_find889

bb_generic_dict_group_find889:
  %generic_dict_group_probe3870 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback884 ], [ %generic_dict_group_next_probe3868, %bb_generic_dict_group_next897 ]
  %generic_dict_group_deleted3871 = phi i64 [ %set_grown_capacity3714, %bb_generic_dict_insert_first_fallback884 ], [ %generic_dict_group_next_deleted3869, %bb_generic_dict_group_next897 ]
  %generic_dict_group_active3872 = icmp ult i64 %generic_dict_group_probe3870, %set_grown_capacity3714
  br i1 %generic_dict_group_active3872, label %bb_generic_dict_group_body890, label %bb_generic_dict_group_miss898

bb_generic_dict_group_body890:
  %generic_dict_group_unwrapped3873 = add i64 %dict_start_slot3867, %generic_dict_group_probe3870
  %generic_dict_group_start3874 = and i64 %generic_dict_group_unwrapped3873, %dict_capacity_mask3866
  %generic_dict_group_pointer3875 = getelementptr i8, ptr %heap3719, i64 %generic_dict_group_start3874
  %generic_dict_group_controls3876 = load <16 x i8>, ptr %generic_dict_group_pointer3875, align 1
  %generic_dict_group_h2_seed3877 = insertelement <16 x i8> poison, i8 %dict_h2_byte3865, i64 0
  %generic_dict_group_h2_vector3878 = shufflevector <16 x i8> %generic_dict_group_h2_seed3877, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3879 = icmp eq <16 x i8> %generic_dict_group_controls3876, %generic_dict_group_h2_vector3878
  %generic_dict_group_match_bits3880 = bitcast <16 x i1> %generic_dict_group_matches_vector3879 to i16
  %generic_dict_group_empty_vector3881 = icmp eq <16 x i8> %generic_dict_group_controls3876, zeroinitializer
  %generic_dict_group_empty_bits3882 = bitcast <16 x i1> %generic_dict_group_empty_vector3881 to i16
  %generic_dict_group_deleted_seed3883 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3884 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3883, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3885 = icmp eq <16 x i8> %generic_dict_group_controls3876, %generic_dict_group_deleted_vector3884
  %generic_dict_group_deleted_bits3886 = bitcast <16 x i1> %generic_dict_group_deleted_matches3885 to i16
  %generic_dict_group_has_deleted3887 = icmp ne i16 %generic_dict_group_deleted_bits3886, 0
  %generic_dict_group_no_previous_deleted3888 = icmp eq i64 %generic_dict_group_deleted3871, %set_grown_capacity3714
  %generic_dict_group_capture_deleted3889 = and i1 %generic_dict_group_has_deleted3887, %generic_dict_group_no_previous_deleted3888
  %generic_dict_group_deleted_offset163890 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3886, i1 false)
  %generic_dict_group_deleted_offset3891 = zext i16 %generic_dict_group_deleted_offset163890 to i64
  %generic_dict_group_deleted_unwrapped3892 = add i64 %generic_dict_group_start3874, %generic_dict_group_deleted_offset3891
  %generic_dict_group_deleted_slot3893 = and i64 %generic_dict_group_deleted_unwrapped3892, %dict_capacity_mask3866
  %generic_dict_group_captured_deleted3894 = select i1 %generic_dict_group_capture_deleted3889, i64 %generic_dict_group_deleted_slot3893, i64 %generic_dict_group_deleted3871
  br label %bb_generic_dict_candidate_loop891

bb_generic_dict_candidate_loop891:
  %generic_dict_candidate_bits3895 = phi i16 [ %generic_dict_group_match_bits3880, %bb_generic_dict_group_body890 ], [ %generic_dict_candidate_cleared_bits3896, %bb_generic_dict_candidate_next893 ]
  %generic_dict_has_candidate3897 = icmp ne i16 %generic_dict_candidate_bits3895, 0
  br i1 %generic_dict_has_candidate3897, label %bb_generic_dict_candidate_body892, label %bb_generic_dict_group_decision894

bb_generic_dict_candidate_body892:
  %generic_dict_candidate_offset163898 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits3895, i1 false)
  %generic_dict_candidate_offset3899 = zext i16 %generic_dict_candidate_offset163898 to i64
  %generic_dict_candidate_unwrapped3900 = add i64 %generic_dict_group_start3874, %generic_dict_candidate_offset3899
  %generic_dict_candidate_slot3901 = and i64 %generic_dict_candidate_unwrapped3900, %dict_capacity_mask3866
  %generic_dict_key_entries_offset_mirror3902 = add i64 %set_grown_capacity3714, 23
  %generic_dict_key_entries_offset3903 = and i64 %generic_dict_key_entries_offset_mirror3902, -8
  %generic_dict_key_entries3904 = getelementptr i8, ptr %heap3719, i64 %generic_dict_key_entries_offset3903
  %generic_dict_key_entry_offset3905 = mul i64 %generic_dict_candidate_slot3901, 4
  %generic_dict_key_slot3906 = getelementptr i8, ptr %generic_dict_key_entries3904, i64 %generic_dict_key_entry_offset3905
  %generic_dict_key3907 = load i32, ptr %generic_dict_key_slot3906, align 4
  %generic_dict_key_equal3908 = icmp eq i32 %generic_dict_key3907, 12
  br i1 %generic_dict_key_equal3908, label %bb_generic_dict_group_match896, label %bb_generic_dict_candidate_next893

bb_generic_dict_candidate_next893:
  %generic_dict_candidate_bits_minus_one3909 = sub i16 %generic_dict_candidate_bits3895, 1
  %generic_dict_candidate_cleared_bits3896 = and i16 %generic_dict_candidate_bits3895, %generic_dict_candidate_bits_minus_one3909
  br label %bb_generic_dict_candidate_loop891

bb_generic_dict_group_decision894:
  %generic_dict_group_has_empty3910 = icmp ne i16 %generic_dict_group_empty_bits3882, 0
  br i1 %generic_dict_group_has_empty3910, label %bb_generic_dict_group_empty895, label %bb_generic_dict_group_next897

bb_generic_dict_group_empty895:
  %generic_dict_group_empty_offset163911 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3882, i1 false)
  %generic_dict_group_empty_offset3912 = zext i16 %generic_dict_group_empty_offset163911 to i64
  %generic_dict_group_empty_unwrapped3913 = add i64 %generic_dict_group_start3874, %generic_dict_group_empty_offset3912
  %generic_dict_group_empty_slot3914 = and i64 %generic_dict_group_empty_unwrapped3913, %dict_capacity_mask3866
  %generic_dict_group_use_empty3915 = icmp eq i64 %generic_dict_group_captured_deleted3894, %set_grown_capacity3714
  %generic_dict_group_insertion_slot3916 = select i1 %generic_dict_group_use_empty3915, i64 %generic_dict_group_empty_slot3914, i64 %generic_dict_group_captured_deleted3894
  br label %bb_generic_dict_group_done899

bb_generic_dict_group_match896:
  br label %bb_generic_dict_group_done899

bb_generic_dict_group_next897:
  %generic_dict_group_next_probe3868 = add i64 %generic_dict_group_probe3870, 16
  %generic_dict_group_next_deleted3869 = add i64 %generic_dict_group_captured_deleted3894, 0
  br label %bb_generic_dict_group_find889

bb_generic_dict_group_miss898:
  %generic_dict_group_miss_no_deleted3917 = icmp eq i64 %generic_dict_group_deleted3871, %set_grown_capacity3714
  %generic_dict_group_miss_slot3918 = select i1 %generic_dict_group_miss_no_deleted3917, i64 0, i64 %generic_dict_group_deleted3871
  br label %bb_generic_dict_group_done899

bb_generic_dict_group_done899:
  %generic_dict_find_found3919 = phi i1 [ false, %bb_generic_dict_group_empty895 ], [ true, %bb_generic_dict_group_match896 ], [ false, %bb_generic_dict_group_miss898 ]
  %generic_dict_find_slot_result3920 = phi i64 [ %generic_dict_group_insertion_slot3916, %bb_generic_dict_group_empty895 ], [ %generic_dict_candidate_slot3901, %bb_generic_dict_group_match896 ], [ %generic_dict_group_miss_slot3918, %bb_generic_dict_group_miss898 ]
  br label %bb_generic_dict_insert_first_done886

bb_generic_dict_insert_first_done886:
  %generic_dict_insert_first_found3921 = phi i1 [ true, %bb_generic_dict_insert_first_match883 ], [ false, %bb_generic_dict_insert_first_vacant885 ], [ %generic_dict_find_found3919, %bb_generic_dict_group_done899 ], [ false, %bb_generic_dict_insert_no_capacity888 ]
  %generic_dict_insert_first_slot_result3922 = phi i64 [ %dict_start_slot3844, %bb_generic_dict_insert_first_match883 ], [ %dict_start_slot3844, %bb_generic_dict_insert_first_vacant885 ], [ %generic_dict_find_slot_result3920, %bb_generic_dict_group_done899 ], [ 0, %bb_generic_dict_insert_no_capacity888 ]
  %set_key_entries_offset_mirror3923 = add i64 %set_grown_capacity3714, 23
  %set_key_entries_offset3924 = and i64 %set_key_entries_offset_mirror3923, -8
  %set_key_entries3925 = getelementptr i8, ptr %heap3719, i64 %set_key_entries_offset3924
  %set_key_entry_offset3926 = mul i64 %generic_dict_insert_first_slot_result3922, 4
  %set_key_slot3927 = getelementptr i8, ptr %set_key_entries3925, i64 %set_key_entry_offset3926
  store i32 12, ptr %set_key_slot3927, align 4
  %generic_dict_control_slot3928 = getelementptr i8, ptr %heap3719, i64 %generic_dict_insert_first_slot_result3922
  store i8 %dict_h2_byte3842, ptr %generic_dict_control_slot3928, align 1
  %generic_dict_control_mirrored3929 = icmp ult i64 %generic_dict_insert_first_slot_result3922, 16
  br i1 %generic_dict_control_mirrored3929, label %bb_generic_dict_control_mirror900, label %bb_generic_dict_control_done901

bb_generic_dict_control_mirror900:
  %generic_dict_control_mirror_index3930 = add i64 %set_grown_capacity3714, %generic_dict_insert_first_slot_result3922
  %generic_dict_control_mirror_slot3931 = getelementptr i8, ptr %heap3719, i64 %generic_dict_control_mirror_index3930
  store i8 %dict_h2_byte3842, ptr %generic_dict_control_mirror_slot3931, align 1
  br label %bb_generic_dict_control_done901

bb_generic_dict_control_done901:
  br label %bb_set_insert_done850

bb_set_insert_done850:
  %set_pointer3932 = phi ptr [ %mutable_ptr3609, %bb_set_insert_duplicate846 ], [ %mutable_ptr3609, %bb_generic_dict_control_done852 ], [ %heap3719, %bb_generic_dict_control_done901 ]
  %set_length3933 = phi i64 [ %mutable_len3610, %bb_set_insert_duplicate846 ], [ %set_insert_length3701, %bb_generic_dict_control_done852 ], [ %set_insert_length3701, %bb_generic_dict_control_done901 ]
  %set_capacity3934 = phi i64 [ %mutable_capacity3611, %bb_set_insert_duplicate846 ], [ %mutable_capacity3611, %bb_generic_dict_control_done852 ], [ %set_grown_capacity3714, %bb_generic_dict_control_done901 ]
  %set_inserted3935 = phi i1 [ false, %bb_set_insert_duplicate846 ], [ true, %bb_generic_dict_control_done852 ], [ true, %bb_generic_dict_control_done901 ]
  store ptr %set_pointer3932, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length3933, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity3934, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr3936 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len3937 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity3938 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key3939 = sext i32 13 to i64
  %hash_high3941 = lshr i64 %hash_key3939, 32
  %hash_fold3940 = xor i64 %hash_key3939, %hash_high3941
  %hash3942 = mul i64 %hash_fold3940, -7046029254386353131
  %dict_h2_shifted3943 = lshr i64 %hash3942, 57
  %dict_h2_raw3944 = and i64 %dict_h2_shifted3943, 127
  %dict_h2_zero3945 = icmp eq i64 %dict_h2_raw3944, 0
  %dict_h23946 = select i1 %dict_h2_zero3945, i64 1, i64 %dict_h2_raw3944
  %dict_h2_byte3947 = trunc i64 %dict_h23946 to i8
  %dict_capacity_mask3948 = sub i64 %mutable_capacity3938, 1
  %dict_start_slot3949 = and i64 %hash3942, %dict_capacity_mask3948
  %generic_dict_insert_has_capacity3950 = icmp ugt i64 %mutable_capacity3938, 0
  br i1 %generic_dict_insert_has_capacity3950, label %bb_generic_dict_insert_first908, label %bb_generic_dict_insert_no_capacity909

bb_generic_dict_insert_no_capacity909:
  br label %bb_generic_dict_insert_first_done907

bb_generic_dict_insert_first908:
  %generic_dict_control_slot3951 = getelementptr i8, ptr %mutable_ptr3936, i64 %dict_start_slot3949
  %generic_dict_control3952 = load i8, ptr %generic_dict_control_slot3951, align 1
  %generic_dict_insert_first_empty3953 = icmp eq i8 %generic_dict_control3952, 0
  br i1 %generic_dict_insert_first_empty3953, label %bb_generic_dict_insert_first_vacant906, label %bb_generic_dict_insert_first_occupied902

bb_generic_dict_insert_first_occupied902:
  %generic_dict_insert_first_h23954 = icmp eq i8 %generic_dict_control3952, %dict_h2_byte3947
  br i1 %generic_dict_insert_first_h23954, label %bb_generic_dict_insert_first_compare903, label %bb_generic_dict_insert_first_fallback905

bb_generic_dict_insert_first_compare903:
  %generic_dict_insert_first_key_entries_offset_mirror3955 = add i64 %mutable_capacity3938, 23
  %generic_dict_insert_first_key_entries_offset3956 = and i64 %generic_dict_insert_first_key_entries_offset_mirror3955, -8
  %generic_dict_insert_first_key_entries3957 = getelementptr i8, ptr %mutable_ptr3936, i64 %generic_dict_insert_first_key_entries_offset3956
  %generic_dict_insert_first_key_entry_offset3958 = mul i64 %dict_start_slot3949, 4
  %generic_dict_insert_first_key_slot3959 = getelementptr i8, ptr %generic_dict_insert_first_key_entries3957, i64 %generic_dict_insert_first_key_entry_offset3958
  %generic_dict_insert_first_key3960 = load i32, ptr %generic_dict_insert_first_key_slot3959, align 4
  %generic_dict_key_equal3961 = icmp eq i32 %generic_dict_insert_first_key3960, 13
  br i1 %generic_dict_key_equal3961, label %bb_generic_dict_insert_first_match904, label %bb_generic_dict_insert_first_fallback905

bb_generic_dict_insert_first_match904:
  br label %bb_generic_dict_insert_first_done907

bb_generic_dict_insert_first_vacant906:
  br label %bb_generic_dict_insert_first_done907

bb_generic_dict_insert_first_fallback905:
  %hash_key3962 = sext i32 13 to i64
  %hash_high3964 = lshr i64 %hash_key3962, 32
  %hash_fold3963 = xor i64 %hash_key3962, %hash_high3964
  %hash3965 = mul i64 %hash_fold3963, -7046029254386353131
  %dict_h2_shifted3966 = lshr i64 %hash3965, 57
  %dict_h2_raw3967 = and i64 %dict_h2_shifted3966, 127
  %dict_h2_zero3968 = icmp eq i64 %dict_h2_raw3967, 0
  %dict_h23969 = select i1 %dict_h2_zero3968, i64 1, i64 %dict_h2_raw3967
  %dict_h2_byte3970 = trunc i64 %dict_h23969 to i8
  %dict_capacity_mask3971 = sub i64 %mutable_capacity3938, 1
  %dict_start_slot3972 = and i64 %hash3965, %dict_capacity_mask3971
  br label %bb_generic_dict_group_find910

bb_generic_dict_group_find910:
  %generic_dict_group_probe3975 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback905 ], [ %generic_dict_group_next_probe3973, %bb_generic_dict_group_next918 ]
  %generic_dict_group_deleted3976 = phi i64 [ %mutable_capacity3938, %bb_generic_dict_insert_first_fallback905 ], [ %generic_dict_group_next_deleted3974, %bb_generic_dict_group_next918 ]
  %generic_dict_group_active3977 = icmp ult i64 %generic_dict_group_probe3975, %mutable_capacity3938
  br i1 %generic_dict_group_active3977, label %bb_generic_dict_group_body911, label %bb_generic_dict_group_miss919

bb_generic_dict_group_body911:
  %generic_dict_group_unwrapped3978 = add i64 %dict_start_slot3972, %generic_dict_group_probe3975
  %generic_dict_group_start3979 = and i64 %generic_dict_group_unwrapped3978, %dict_capacity_mask3971
  %generic_dict_group_pointer3980 = getelementptr i8, ptr %mutable_ptr3936, i64 %generic_dict_group_start3979
  %generic_dict_group_controls3981 = load <16 x i8>, ptr %generic_dict_group_pointer3980, align 1
  %generic_dict_group_h2_seed3982 = insertelement <16 x i8> poison, i8 %dict_h2_byte3970, i64 0
  %generic_dict_group_h2_vector3983 = shufflevector <16 x i8> %generic_dict_group_h2_seed3982, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector3984 = icmp eq <16 x i8> %generic_dict_group_controls3981, %generic_dict_group_h2_vector3983
  %generic_dict_group_match_bits3985 = bitcast <16 x i1> %generic_dict_group_matches_vector3984 to i16
  %generic_dict_group_empty_vector3986 = icmp eq <16 x i8> %generic_dict_group_controls3981, zeroinitializer
  %generic_dict_group_empty_bits3987 = bitcast <16 x i1> %generic_dict_group_empty_vector3986 to i16
  %generic_dict_group_deleted_seed3988 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector3989 = shufflevector <16 x i8> %generic_dict_group_deleted_seed3988, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches3990 = icmp eq <16 x i8> %generic_dict_group_controls3981, %generic_dict_group_deleted_vector3989
  %generic_dict_group_deleted_bits3991 = bitcast <16 x i1> %generic_dict_group_deleted_matches3990 to i16
  %generic_dict_group_has_deleted3992 = icmp ne i16 %generic_dict_group_deleted_bits3991, 0
  %generic_dict_group_no_previous_deleted3993 = icmp eq i64 %generic_dict_group_deleted3976, %mutable_capacity3938
  %generic_dict_group_capture_deleted3994 = and i1 %generic_dict_group_has_deleted3992, %generic_dict_group_no_previous_deleted3993
  %generic_dict_group_deleted_offset163995 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits3991, i1 false)
  %generic_dict_group_deleted_offset3996 = zext i16 %generic_dict_group_deleted_offset163995 to i64
  %generic_dict_group_deleted_unwrapped3997 = add i64 %generic_dict_group_start3979, %generic_dict_group_deleted_offset3996
  %generic_dict_group_deleted_slot3998 = and i64 %generic_dict_group_deleted_unwrapped3997, %dict_capacity_mask3971
  %generic_dict_group_captured_deleted3999 = select i1 %generic_dict_group_capture_deleted3994, i64 %generic_dict_group_deleted_slot3998, i64 %generic_dict_group_deleted3976
  br label %bb_generic_dict_candidate_loop912

bb_generic_dict_candidate_loop912:
  %generic_dict_candidate_bits4000 = phi i16 [ %generic_dict_group_match_bits3985, %bb_generic_dict_group_body911 ], [ %generic_dict_candidate_cleared_bits4001, %bb_generic_dict_candidate_next914 ]
  %generic_dict_has_candidate4002 = icmp ne i16 %generic_dict_candidate_bits4000, 0
  br i1 %generic_dict_has_candidate4002, label %bb_generic_dict_candidate_body913, label %bb_generic_dict_group_decision915

bb_generic_dict_candidate_body913:
  %generic_dict_candidate_offset164003 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4000, i1 false)
  %generic_dict_candidate_offset4004 = zext i16 %generic_dict_candidate_offset164003 to i64
  %generic_dict_candidate_unwrapped4005 = add i64 %generic_dict_group_start3979, %generic_dict_candidate_offset4004
  %generic_dict_candidate_slot4006 = and i64 %generic_dict_candidate_unwrapped4005, %dict_capacity_mask3971
  %generic_dict_key_entries_offset_mirror4007 = add i64 %mutable_capacity3938, 23
  %generic_dict_key_entries_offset4008 = and i64 %generic_dict_key_entries_offset_mirror4007, -8
  %generic_dict_key_entries4009 = getelementptr i8, ptr %mutable_ptr3936, i64 %generic_dict_key_entries_offset4008
  %generic_dict_key_entry_offset4010 = mul i64 %generic_dict_candidate_slot4006, 4
  %generic_dict_key_slot4011 = getelementptr i8, ptr %generic_dict_key_entries4009, i64 %generic_dict_key_entry_offset4010
  %generic_dict_key4012 = load i32, ptr %generic_dict_key_slot4011, align 4
  %generic_dict_key_equal4013 = icmp eq i32 %generic_dict_key4012, 13
  br i1 %generic_dict_key_equal4013, label %bb_generic_dict_group_match917, label %bb_generic_dict_candidate_next914

bb_generic_dict_candidate_next914:
  %generic_dict_candidate_bits_minus_one4014 = sub i16 %generic_dict_candidate_bits4000, 1
  %generic_dict_candidate_cleared_bits4001 = and i16 %generic_dict_candidate_bits4000, %generic_dict_candidate_bits_minus_one4014
  br label %bb_generic_dict_candidate_loop912

bb_generic_dict_group_decision915:
  %generic_dict_group_has_empty4015 = icmp ne i16 %generic_dict_group_empty_bits3987, 0
  br i1 %generic_dict_group_has_empty4015, label %bb_generic_dict_group_empty916, label %bb_generic_dict_group_next918

bb_generic_dict_group_empty916:
  %generic_dict_group_empty_offset164016 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits3987, i1 false)
  %generic_dict_group_empty_offset4017 = zext i16 %generic_dict_group_empty_offset164016 to i64
  %generic_dict_group_empty_unwrapped4018 = add i64 %generic_dict_group_start3979, %generic_dict_group_empty_offset4017
  %generic_dict_group_empty_slot4019 = and i64 %generic_dict_group_empty_unwrapped4018, %dict_capacity_mask3971
  %generic_dict_group_use_empty4020 = icmp eq i64 %generic_dict_group_captured_deleted3999, %mutable_capacity3938
  %generic_dict_group_insertion_slot4021 = select i1 %generic_dict_group_use_empty4020, i64 %generic_dict_group_empty_slot4019, i64 %generic_dict_group_captured_deleted3999
  br label %bb_generic_dict_group_done920

bb_generic_dict_group_match917:
  br label %bb_generic_dict_group_done920

bb_generic_dict_group_next918:
  %generic_dict_group_next_probe3973 = add i64 %generic_dict_group_probe3975, 16
  %generic_dict_group_next_deleted3974 = add i64 %generic_dict_group_captured_deleted3999, 0
  br label %bb_generic_dict_group_find910

bb_generic_dict_group_miss919:
  %generic_dict_group_miss_no_deleted4022 = icmp eq i64 %generic_dict_group_deleted3976, %mutable_capacity3938
  %generic_dict_group_miss_slot4023 = select i1 %generic_dict_group_miss_no_deleted4022, i64 0, i64 %generic_dict_group_deleted3976
  br label %bb_generic_dict_group_done920

bb_generic_dict_group_done920:
  %generic_dict_find_found4024 = phi i1 [ false, %bb_generic_dict_group_empty916 ], [ true, %bb_generic_dict_group_match917 ], [ false, %bb_generic_dict_group_miss919 ]
  %generic_dict_find_slot_result4025 = phi i64 [ %generic_dict_group_insertion_slot4021, %bb_generic_dict_group_empty916 ], [ %generic_dict_candidate_slot4006, %bb_generic_dict_group_match917 ], [ %generic_dict_group_miss_slot4023, %bb_generic_dict_group_miss919 ]
  br label %bb_generic_dict_insert_first_done907

bb_generic_dict_insert_first_done907:
  %generic_dict_insert_first_found4026 = phi i1 [ true, %bb_generic_dict_insert_first_match904 ], [ false, %bb_generic_dict_insert_first_vacant906 ], [ %generic_dict_find_found4024, %bb_generic_dict_group_done920 ], [ false, %bb_generic_dict_insert_no_capacity909 ]
  %generic_dict_insert_first_slot_result4027 = phi i64 [ %dict_start_slot3949, %bb_generic_dict_insert_first_match904 ], [ %dict_start_slot3949, %bb_generic_dict_insert_first_vacant906 ], [ %generic_dict_find_slot_result4025, %bb_generic_dict_group_done920 ], [ 0, %bb_generic_dict_insert_no_capacity909 ]
  br i1 %generic_dict_insert_first_found4026, label %bb_set_insert_duplicate921, label %bb_set_insert_new922

bb_set_insert_duplicate921:
  br label %bb_set_insert_done925

bb_set_insert_new922:
  %set_insert_length4028 = add i64 %mutable_len3937, 1
  %set_insert_load_num4029 = mul i64 %set_insert_length4028, 8
  %set_insert_load_den4030 = mul i64 %mutable_capacity3938, 7
  %set_insert_should_grow4031 = icmp ugt i64 %set_insert_load_num4029, %set_insert_load_den4030
  br i1 %set_insert_should_grow4031, label %bb_set_insert_grow924, label %bb_set_insert_current923

bb_set_insert_current923:
  %set_key_entries_offset_mirror4032 = add i64 %mutable_capacity3938, 23
  %set_key_entries_offset4033 = and i64 %set_key_entries_offset_mirror4032, -8
  %set_key_entries4034 = getelementptr i8, ptr %mutable_ptr3936, i64 %set_key_entries_offset4033
  %set_key_entry_offset4035 = mul i64 %generic_dict_insert_first_slot_result4027, 4
  %set_key_slot4036 = getelementptr i8, ptr %set_key_entries4034, i64 %set_key_entry_offset4035
  store i32 13, ptr %set_key_slot4036, align 4
  %generic_dict_control_slot4037 = getelementptr i8, ptr %mutable_ptr3936, i64 %generic_dict_insert_first_slot_result4027
  store i8 %dict_h2_byte3947, ptr %generic_dict_control_slot4037, align 1
  %generic_dict_control_mirrored4038 = icmp ult i64 %generic_dict_insert_first_slot_result4027, 16
  br i1 %generic_dict_control_mirrored4038, label %bb_generic_dict_control_mirror926, label %bb_generic_dict_control_done927

bb_generic_dict_control_mirror926:
  %generic_dict_control_mirror_index4039 = add i64 %mutable_capacity3938, %generic_dict_insert_first_slot_result4027
  %generic_dict_control_mirror_slot4040 = getelementptr i8, ptr %mutable_ptr3936, i64 %generic_dict_control_mirror_index4039
  store i8 %dict_h2_byte3947, ptr %generic_dict_control_mirror_slot4040, align 1
  br label %bb_generic_dict_control_done927

bb_generic_dict_control_done927:
  br label %bb_set_insert_done925

bb_set_insert_grow924:
  %set_grown_capacity4041 = mul i64 %mutable_capacity3938, 2
  %generic_dict_entries_offset_mirror4042 = add i64 %set_grown_capacity4041, 23
  %generic_dict_entries_offset4043 = and i64 %generic_dict_entries_offset_mirror4042, -8
  %generic_dict_entries_bytes4044 = mul i64 %set_grown_capacity4041, 4
  %generic_dict_bytes4045 = add i64 %generic_dict_entries_offset4043, %generic_dict_entries_bytes4044
  %heap4046 = call ptr @sollang_alloc(i64 %generic_dict_bytes4045)
  %heap_ok4047 = icmp ne ptr %heap4046, null
  br i1 %heap_ok4047, label %bb_alloc_ok928, label %bb_alloc_fail929

bb_alloc_fail929:
  %trap_stderr4048 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr4048, ptr @.slg.str.module.x.13, i32 25, ptr %trap_written4049, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok928:
  %generic_dict_control_bytes4050 = add i64 %set_grown_capacity4041, 16
  call void @llvm.memset.p0.i64(ptr %heap4046, i8 0, i64 %generic_dict_control_bytes4050, i1 false)
  br label %bb_set_rehash930

bb_set_rehash930:
  %set_rehash_index4052 = phi i64 [ 0, %bb_alloc_ok928 ], [ %set_rehash_next_index4051, %bb_set_rehash_next933 ]
  %set_rehash_active4053 = icmp ult i64 %set_rehash_index4052, %mutable_capacity3938
  br i1 %set_rehash_active4053, label %bb_set_rehash_body931, label %bb_set_rehash_done934

bb_set_rehash_body931:
  %generic_dict_control_slot4054 = getelementptr i8, ptr %mutable_ptr3936, i64 %set_rehash_index4052
  %generic_dict_control4055 = load i8, ptr %generic_dict_control_slot4054, align 1
  %set_rehash_occupied4056 = icmp sgt i8 %generic_dict_control4055, 0
  br i1 %set_rehash_occupied4056, label %bb_set_rehash_move932, label %bb_set_rehash_next933

bb_set_rehash_move932:
  %set_rehash_key_entries_offset_mirror4057 = add i64 %mutable_capacity3938, 23
  %set_rehash_key_entries_offset4058 = and i64 %set_rehash_key_entries_offset_mirror4057, -8
  %set_rehash_key_entries4059 = getelementptr i8, ptr %mutable_ptr3936, i64 %set_rehash_key_entries_offset4058
  %set_rehash_key_entry_offset4060 = mul i64 %set_rehash_index4052, 4
  %set_rehash_key_slot4061 = getelementptr i8, ptr %set_rehash_key_entries4059, i64 %set_rehash_key_entry_offset4060
  %set_rehash_key4062 = load i32, ptr %set_rehash_key_slot4061, align 4
  %hash_key4063 = sext i32 %set_rehash_key4062 to i64
  %hash_high4065 = lshr i64 %hash_key4063, 32
  %hash_fold4064 = xor i64 %hash_key4063, %hash_high4065
  %hash4066 = mul i64 %hash_fold4064, -7046029254386353131
  %dict_h2_shifted4067 = lshr i64 %hash4066, 57
  %dict_h2_raw4068 = and i64 %dict_h2_shifted4067, 127
  %dict_h2_zero4069 = icmp eq i64 %dict_h2_raw4068, 0
  %dict_h24070 = select i1 %dict_h2_zero4069, i64 1, i64 %dict_h2_raw4068
  %dict_h2_byte4071 = trunc i64 %dict_h24070 to i8
  %dict_capacity_mask4072 = sub i64 %set_grown_capacity4041, 1
  %dict_start_slot4073 = and i64 %hash4066, %dict_capacity_mask4072
  %generic_dict_insert_has_capacity4074 = icmp ugt i64 %set_grown_capacity4041, 0
  br i1 %generic_dict_insert_has_capacity4074, label %bb_generic_dict_insert_first941, label %bb_generic_dict_insert_no_capacity942

bb_generic_dict_insert_no_capacity942:
  br label %bb_generic_dict_insert_first_done940

bb_generic_dict_insert_first941:
  %generic_dict_control_slot4075 = getelementptr i8, ptr %heap4046, i64 %dict_start_slot4073
  %generic_dict_control4076 = load i8, ptr %generic_dict_control_slot4075, align 1
  %generic_dict_insert_first_empty4077 = icmp eq i8 %generic_dict_control4076, 0
  br i1 %generic_dict_insert_first_empty4077, label %bb_generic_dict_insert_first_vacant939, label %bb_generic_dict_insert_first_occupied935

bb_generic_dict_insert_first_occupied935:
  %generic_dict_insert_first_h24078 = icmp eq i8 %generic_dict_control4076, %dict_h2_byte4071
  br i1 %generic_dict_insert_first_h24078, label %bb_generic_dict_insert_first_compare936, label %bb_generic_dict_insert_first_fallback938

bb_generic_dict_insert_first_compare936:
  %generic_dict_insert_first_key_entries_offset_mirror4079 = add i64 %set_grown_capacity4041, 23
  %generic_dict_insert_first_key_entries_offset4080 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4079, -8
  %generic_dict_insert_first_key_entries4081 = getelementptr i8, ptr %heap4046, i64 %generic_dict_insert_first_key_entries_offset4080
  %generic_dict_insert_first_key_entry_offset4082 = mul i64 %dict_start_slot4073, 4
  %generic_dict_insert_first_key_slot4083 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4081, i64 %generic_dict_insert_first_key_entry_offset4082
  %generic_dict_insert_first_key4084 = load i32, ptr %generic_dict_insert_first_key_slot4083, align 4
  %generic_dict_key_equal4085 = icmp eq i32 %generic_dict_insert_first_key4084, %set_rehash_key4062
  br i1 %generic_dict_key_equal4085, label %bb_generic_dict_insert_first_match937, label %bb_generic_dict_insert_first_fallback938

bb_generic_dict_insert_first_match937:
  br label %bb_generic_dict_insert_first_done940

bb_generic_dict_insert_first_vacant939:
  br label %bb_generic_dict_insert_first_done940

bb_generic_dict_insert_first_fallback938:
  %hash_key4086 = sext i32 %set_rehash_key4062 to i64
  %hash_high4088 = lshr i64 %hash_key4086, 32
  %hash_fold4087 = xor i64 %hash_key4086, %hash_high4088
  %hash4089 = mul i64 %hash_fold4087, -7046029254386353131
  %dict_h2_shifted4090 = lshr i64 %hash4089, 57
  %dict_h2_raw4091 = and i64 %dict_h2_shifted4090, 127
  %dict_h2_zero4092 = icmp eq i64 %dict_h2_raw4091, 0
  %dict_h24093 = select i1 %dict_h2_zero4092, i64 1, i64 %dict_h2_raw4091
  %dict_h2_byte4094 = trunc i64 %dict_h24093 to i8
  %dict_capacity_mask4095 = sub i64 %set_grown_capacity4041, 1
  %dict_start_slot4096 = and i64 %hash4089, %dict_capacity_mask4095
  br label %bb_generic_dict_group_find943

bb_generic_dict_group_find943:
  %generic_dict_group_probe4099 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback938 ], [ %generic_dict_group_next_probe4097, %bb_generic_dict_group_next951 ]
  %generic_dict_group_deleted4100 = phi i64 [ %set_grown_capacity4041, %bb_generic_dict_insert_first_fallback938 ], [ %generic_dict_group_next_deleted4098, %bb_generic_dict_group_next951 ]
  %generic_dict_group_active4101 = icmp ult i64 %generic_dict_group_probe4099, %set_grown_capacity4041
  br i1 %generic_dict_group_active4101, label %bb_generic_dict_group_body944, label %bb_generic_dict_group_miss952

bb_generic_dict_group_body944:
  %generic_dict_group_unwrapped4102 = add i64 %dict_start_slot4096, %generic_dict_group_probe4099
  %generic_dict_group_start4103 = and i64 %generic_dict_group_unwrapped4102, %dict_capacity_mask4095
  %generic_dict_group_pointer4104 = getelementptr i8, ptr %heap4046, i64 %generic_dict_group_start4103
  %generic_dict_group_controls4105 = load <16 x i8>, ptr %generic_dict_group_pointer4104, align 1
  %generic_dict_group_h2_seed4106 = insertelement <16 x i8> poison, i8 %dict_h2_byte4094, i64 0
  %generic_dict_group_h2_vector4107 = shufflevector <16 x i8> %generic_dict_group_h2_seed4106, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4108 = icmp eq <16 x i8> %generic_dict_group_controls4105, %generic_dict_group_h2_vector4107
  %generic_dict_group_match_bits4109 = bitcast <16 x i1> %generic_dict_group_matches_vector4108 to i16
  %generic_dict_group_empty_vector4110 = icmp eq <16 x i8> %generic_dict_group_controls4105, zeroinitializer
  %generic_dict_group_empty_bits4111 = bitcast <16 x i1> %generic_dict_group_empty_vector4110 to i16
  %generic_dict_group_deleted_seed4112 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4113 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4112, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4114 = icmp eq <16 x i8> %generic_dict_group_controls4105, %generic_dict_group_deleted_vector4113
  %generic_dict_group_deleted_bits4115 = bitcast <16 x i1> %generic_dict_group_deleted_matches4114 to i16
  %generic_dict_group_has_deleted4116 = icmp ne i16 %generic_dict_group_deleted_bits4115, 0
  %generic_dict_group_no_previous_deleted4117 = icmp eq i64 %generic_dict_group_deleted4100, %set_grown_capacity4041
  %generic_dict_group_capture_deleted4118 = and i1 %generic_dict_group_has_deleted4116, %generic_dict_group_no_previous_deleted4117
  %generic_dict_group_deleted_offset164119 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4115, i1 false)
  %generic_dict_group_deleted_offset4120 = zext i16 %generic_dict_group_deleted_offset164119 to i64
  %generic_dict_group_deleted_unwrapped4121 = add i64 %generic_dict_group_start4103, %generic_dict_group_deleted_offset4120
  %generic_dict_group_deleted_slot4122 = and i64 %generic_dict_group_deleted_unwrapped4121, %dict_capacity_mask4095
  %generic_dict_group_captured_deleted4123 = select i1 %generic_dict_group_capture_deleted4118, i64 %generic_dict_group_deleted_slot4122, i64 %generic_dict_group_deleted4100
  br label %bb_generic_dict_candidate_loop945

bb_generic_dict_candidate_loop945:
  %generic_dict_candidate_bits4124 = phi i16 [ %generic_dict_group_match_bits4109, %bb_generic_dict_group_body944 ], [ %generic_dict_candidate_cleared_bits4125, %bb_generic_dict_candidate_next947 ]
  %generic_dict_has_candidate4126 = icmp ne i16 %generic_dict_candidate_bits4124, 0
  br i1 %generic_dict_has_candidate4126, label %bb_generic_dict_candidate_body946, label %bb_generic_dict_group_decision948

bb_generic_dict_candidate_body946:
  %generic_dict_candidate_offset164127 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4124, i1 false)
  %generic_dict_candidate_offset4128 = zext i16 %generic_dict_candidate_offset164127 to i64
  %generic_dict_candidate_unwrapped4129 = add i64 %generic_dict_group_start4103, %generic_dict_candidate_offset4128
  %generic_dict_candidate_slot4130 = and i64 %generic_dict_candidate_unwrapped4129, %dict_capacity_mask4095
  %generic_dict_key_entries_offset_mirror4131 = add i64 %set_grown_capacity4041, 23
  %generic_dict_key_entries_offset4132 = and i64 %generic_dict_key_entries_offset_mirror4131, -8
  %generic_dict_key_entries4133 = getelementptr i8, ptr %heap4046, i64 %generic_dict_key_entries_offset4132
  %generic_dict_key_entry_offset4134 = mul i64 %generic_dict_candidate_slot4130, 4
  %generic_dict_key_slot4135 = getelementptr i8, ptr %generic_dict_key_entries4133, i64 %generic_dict_key_entry_offset4134
  %generic_dict_key4136 = load i32, ptr %generic_dict_key_slot4135, align 4
  %generic_dict_key_equal4137 = icmp eq i32 %generic_dict_key4136, %set_rehash_key4062
  br i1 %generic_dict_key_equal4137, label %bb_generic_dict_group_match950, label %bb_generic_dict_candidate_next947

bb_generic_dict_candidate_next947:
  %generic_dict_candidate_bits_minus_one4138 = sub i16 %generic_dict_candidate_bits4124, 1
  %generic_dict_candidate_cleared_bits4125 = and i16 %generic_dict_candidate_bits4124, %generic_dict_candidate_bits_minus_one4138
  br label %bb_generic_dict_candidate_loop945

bb_generic_dict_group_decision948:
  %generic_dict_group_has_empty4139 = icmp ne i16 %generic_dict_group_empty_bits4111, 0
  br i1 %generic_dict_group_has_empty4139, label %bb_generic_dict_group_empty949, label %bb_generic_dict_group_next951

bb_generic_dict_group_empty949:
  %generic_dict_group_empty_offset164140 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4111, i1 false)
  %generic_dict_group_empty_offset4141 = zext i16 %generic_dict_group_empty_offset164140 to i64
  %generic_dict_group_empty_unwrapped4142 = add i64 %generic_dict_group_start4103, %generic_dict_group_empty_offset4141
  %generic_dict_group_empty_slot4143 = and i64 %generic_dict_group_empty_unwrapped4142, %dict_capacity_mask4095
  %generic_dict_group_use_empty4144 = icmp eq i64 %generic_dict_group_captured_deleted4123, %set_grown_capacity4041
  %generic_dict_group_insertion_slot4145 = select i1 %generic_dict_group_use_empty4144, i64 %generic_dict_group_empty_slot4143, i64 %generic_dict_group_captured_deleted4123
  br label %bb_generic_dict_group_done953

bb_generic_dict_group_match950:
  br label %bb_generic_dict_group_done953

bb_generic_dict_group_next951:
  %generic_dict_group_next_probe4097 = add i64 %generic_dict_group_probe4099, 16
  %generic_dict_group_next_deleted4098 = add i64 %generic_dict_group_captured_deleted4123, 0
  br label %bb_generic_dict_group_find943

bb_generic_dict_group_miss952:
  %generic_dict_group_miss_no_deleted4146 = icmp eq i64 %generic_dict_group_deleted4100, %set_grown_capacity4041
  %generic_dict_group_miss_slot4147 = select i1 %generic_dict_group_miss_no_deleted4146, i64 0, i64 %generic_dict_group_deleted4100
  br label %bb_generic_dict_group_done953

bb_generic_dict_group_done953:
  %generic_dict_find_found4148 = phi i1 [ false, %bb_generic_dict_group_empty949 ], [ true, %bb_generic_dict_group_match950 ], [ false, %bb_generic_dict_group_miss952 ]
  %generic_dict_find_slot_result4149 = phi i64 [ %generic_dict_group_insertion_slot4145, %bb_generic_dict_group_empty949 ], [ %generic_dict_candidate_slot4130, %bb_generic_dict_group_match950 ], [ %generic_dict_group_miss_slot4147, %bb_generic_dict_group_miss952 ]
  br label %bb_generic_dict_insert_first_done940

bb_generic_dict_insert_first_done940:
  %generic_dict_insert_first_found4150 = phi i1 [ true, %bb_generic_dict_insert_first_match937 ], [ false, %bb_generic_dict_insert_first_vacant939 ], [ %generic_dict_find_found4148, %bb_generic_dict_group_done953 ], [ false, %bb_generic_dict_insert_no_capacity942 ]
  %generic_dict_insert_first_slot_result4151 = phi i64 [ %dict_start_slot4073, %bb_generic_dict_insert_first_match937 ], [ %dict_start_slot4073, %bb_generic_dict_insert_first_vacant939 ], [ %generic_dict_find_slot_result4149, %bb_generic_dict_group_done953 ], [ 0, %bb_generic_dict_insert_no_capacity942 ]
  %set_key_entries_offset_mirror4152 = add i64 %set_grown_capacity4041, 23
  %set_key_entries_offset4153 = and i64 %set_key_entries_offset_mirror4152, -8
  %set_key_entries4154 = getelementptr i8, ptr %heap4046, i64 %set_key_entries_offset4153
  %set_key_entry_offset4155 = mul i64 %generic_dict_insert_first_slot_result4151, 4
  %set_key_slot4156 = getelementptr i8, ptr %set_key_entries4154, i64 %set_key_entry_offset4155
  store i32 %set_rehash_key4062, ptr %set_key_slot4156, align 4
  %generic_dict_control_slot4157 = getelementptr i8, ptr %heap4046, i64 %generic_dict_insert_first_slot_result4151
  store i8 %dict_h2_byte4071, ptr %generic_dict_control_slot4157, align 1
  %generic_dict_control_mirrored4158 = icmp ult i64 %generic_dict_insert_first_slot_result4151, 16
  br i1 %generic_dict_control_mirrored4158, label %bb_generic_dict_control_mirror954, label %bb_generic_dict_control_done955

bb_generic_dict_control_mirror954:
  %generic_dict_control_mirror_index4159 = add i64 %set_grown_capacity4041, %generic_dict_insert_first_slot_result4151
  %generic_dict_control_mirror_slot4160 = getelementptr i8, ptr %heap4046, i64 %generic_dict_control_mirror_index4159
  store i8 %dict_h2_byte4071, ptr %generic_dict_control_mirror_slot4160, align 1
  br label %bb_generic_dict_control_done955

bb_generic_dict_control_done955:
  br label %bb_set_rehash_next933

bb_set_rehash_next933:
  %set_rehash_next_index4051 = add i64 %set_rehash_index4052, 1
  br label %bb_set_rehash930

bb_set_rehash_done934:
  call void @sollang_free(ptr %mutable_ptr3936)
  %hash_key4161 = sext i32 13 to i64
  %hash_high4163 = lshr i64 %hash_key4161, 32
  %hash_fold4162 = xor i64 %hash_key4161, %hash_high4163
  %hash4164 = mul i64 %hash_fold4162, -7046029254386353131
  %dict_h2_shifted4165 = lshr i64 %hash4164, 57
  %dict_h2_raw4166 = and i64 %dict_h2_shifted4165, 127
  %dict_h2_zero4167 = icmp eq i64 %dict_h2_raw4166, 0
  %dict_h24168 = select i1 %dict_h2_zero4167, i64 1, i64 %dict_h2_raw4166
  %dict_h2_byte4169 = trunc i64 %dict_h24168 to i8
  %dict_capacity_mask4170 = sub i64 %set_grown_capacity4041, 1
  %dict_start_slot4171 = and i64 %hash4164, %dict_capacity_mask4170
  %generic_dict_insert_has_capacity4172 = icmp ugt i64 %set_grown_capacity4041, 0
  br i1 %generic_dict_insert_has_capacity4172, label %bb_generic_dict_insert_first962, label %bb_generic_dict_insert_no_capacity963

bb_generic_dict_insert_no_capacity963:
  br label %bb_generic_dict_insert_first_done961

bb_generic_dict_insert_first962:
  %generic_dict_control_slot4173 = getelementptr i8, ptr %heap4046, i64 %dict_start_slot4171
  %generic_dict_control4174 = load i8, ptr %generic_dict_control_slot4173, align 1
  %generic_dict_insert_first_empty4175 = icmp eq i8 %generic_dict_control4174, 0
  br i1 %generic_dict_insert_first_empty4175, label %bb_generic_dict_insert_first_vacant960, label %bb_generic_dict_insert_first_occupied956

bb_generic_dict_insert_first_occupied956:
  %generic_dict_insert_first_h24176 = icmp eq i8 %generic_dict_control4174, %dict_h2_byte4169
  br i1 %generic_dict_insert_first_h24176, label %bb_generic_dict_insert_first_compare957, label %bb_generic_dict_insert_first_fallback959

bb_generic_dict_insert_first_compare957:
  %generic_dict_insert_first_key_entries_offset_mirror4177 = add i64 %set_grown_capacity4041, 23
  %generic_dict_insert_first_key_entries_offset4178 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4177, -8
  %generic_dict_insert_first_key_entries4179 = getelementptr i8, ptr %heap4046, i64 %generic_dict_insert_first_key_entries_offset4178
  %generic_dict_insert_first_key_entry_offset4180 = mul i64 %dict_start_slot4171, 4
  %generic_dict_insert_first_key_slot4181 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4179, i64 %generic_dict_insert_first_key_entry_offset4180
  %generic_dict_insert_first_key4182 = load i32, ptr %generic_dict_insert_first_key_slot4181, align 4
  %generic_dict_key_equal4183 = icmp eq i32 %generic_dict_insert_first_key4182, 13
  br i1 %generic_dict_key_equal4183, label %bb_generic_dict_insert_first_match958, label %bb_generic_dict_insert_first_fallback959

bb_generic_dict_insert_first_match958:
  br label %bb_generic_dict_insert_first_done961

bb_generic_dict_insert_first_vacant960:
  br label %bb_generic_dict_insert_first_done961

bb_generic_dict_insert_first_fallback959:
  %hash_key4184 = sext i32 13 to i64
  %hash_high4186 = lshr i64 %hash_key4184, 32
  %hash_fold4185 = xor i64 %hash_key4184, %hash_high4186
  %hash4187 = mul i64 %hash_fold4185, -7046029254386353131
  %dict_h2_shifted4188 = lshr i64 %hash4187, 57
  %dict_h2_raw4189 = and i64 %dict_h2_shifted4188, 127
  %dict_h2_zero4190 = icmp eq i64 %dict_h2_raw4189, 0
  %dict_h24191 = select i1 %dict_h2_zero4190, i64 1, i64 %dict_h2_raw4189
  %dict_h2_byte4192 = trunc i64 %dict_h24191 to i8
  %dict_capacity_mask4193 = sub i64 %set_grown_capacity4041, 1
  %dict_start_slot4194 = and i64 %hash4187, %dict_capacity_mask4193
  br label %bb_generic_dict_group_find964

bb_generic_dict_group_find964:
  %generic_dict_group_probe4197 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback959 ], [ %generic_dict_group_next_probe4195, %bb_generic_dict_group_next972 ]
  %generic_dict_group_deleted4198 = phi i64 [ %set_grown_capacity4041, %bb_generic_dict_insert_first_fallback959 ], [ %generic_dict_group_next_deleted4196, %bb_generic_dict_group_next972 ]
  %generic_dict_group_active4199 = icmp ult i64 %generic_dict_group_probe4197, %set_grown_capacity4041
  br i1 %generic_dict_group_active4199, label %bb_generic_dict_group_body965, label %bb_generic_dict_group_miss973

bb_generic_dict_group_body965:
  %generic_dict_group_unwrapped4200 = add i64 %dict_start_slot4194, %generic_dict_group_probe4197
  %generic_dict_group_start4201 = and i64 %generic_dict_group_unwrapped4200, %dict_capacity_mask4193
  %generic_dict_group_pointer4202 = getelementptr i8, ptr %heap4046, i64 %generic_dict_group_start4201
  %generic_dict_group_controls4203 = load <16 x i8>, ptr %generic_dict_group_pointer4202, align 1
  %generic_dict_group_h2_seed4204 = insertelement <16 x i8> poison, i8 %dict_h2_byte4192, i64 0
  %generic_dict_group_h2_vector4205 = shufflevector <16 x i8> %generic_dict_group_h2_seed4204, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4206 = icmp eq <16 x i8> %generic_dict_group_controls4203, %generic_dict_group_h2_vector4205
  %generic_dict_group_match_bits4207 = bitcast <16 x i1> %generic_dict_group_matches_vector4206 to i16
  %generic_dict_group_empty_vector4208 = icmp eq <16 x i8> %generic_dict_group_controls4203, zeroinitializer
  %generic_dict_group_empty_bits4209 = bitcast <16 x i1> %generic_dict_group_empty_vector4208 to i16
  %generic_dict_group_deleted_seed4210 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4211 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4210, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4212 = icmp eq <16 x i8> %generic_dict_group_controls4203, %generic_dict_group_deleted_vector4211
  %generic_dict_group_deleted_bits4213 = bitcast <16 x i1> %generic_dict_group_deleted_matches4212 to i16
  %generic_dict_group_has_deleted4214 = icmp ne i16 %generic_dict_group_deleted_bits4213, 0
  %generic_dict_group_no_previous_deleted4215 = icmp eq i64 %generic_dict_group_deleted4198, %set_grown_capacity4041
  %generic_dict_group_capture_deleted4216 = and i1 %generic_dict_group_has_deleted4214, %generic_dict_group_no_previous_deleted4215
  %generic_dict_group_deleted_offset164217 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4213, i1 false)
  %generic_dict_group_deleted_offset4218 = zext i16 %generic_dict_group_deleted_offset164217 to i64
  %generic_dict_group_deleted_unwrapped4219 = add i64 %generic_dict_group_start4201, %generic_dict_group_deleted_offset4218
  %generic_dict_group_deleted_slot4220 = and i64 %generic_dict_group_deleted_unwrapped4219, %dict_capacity_mask4193
  %generic_dict_group_captured_deleted4221 = select i1 %generic_dict_group_capture_deleted4216, i64 %generic_dict_group_deleted_slot4220, i64 %generic_dict_group_deleted4198
  br label %bb_generic_dict_candidate_loop966

bb_generic_dict_candidate_loop966:
  %generic_dict_candidate_bits4222 = phi i16 [ %generic_dict_group_match_bits4207, %bb_generic_dict_group_body965 ], [ %generic_dict_candidate_cleared_bits4223, %bb_generic_dict_candidate_next968 ]
  %generic_dict_has_candidate4224 = icmp ne i16 %generic_dict_candidate_bits4222, 0
  br i1 %generic_dict_has_candidate4224, label %bb_generic_dict_candidate_body967, label %bb_generic_dict_group_decision969

bb_generic_dict_candidate_body967:
  %generic_dict_candidate_offset164225 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4222, i1 false)
  %generic_dict_candidate_offset4226 = zext i16 %generic_dict_candidate_offset164225 to i64
  %generic_dict_candidate_unwrapped4227 = add i64 %generic_dict_group_start4201, %generic_dict_candidate_offset4226
  %generic_dict_candidate_slot4228 = and i64 %generic_dict_candidate_unwrapped4227, %dict_capacity_mask4193
  %generic_dict_key_entries_offset_mirror4229 = add i64 %set_grown_capacity4041, 23
  %generic_dict_key_entries_offset4230 = and i64 %generic_dict_key_entries_offset_mirror4229, -8
  %generic_dict_key_entries4231 = getelementptr i8, ptr %heap4046, i64 %generic_dict_key_entries_offset4230
  %generic_dict_key_entry_offset4232 = mul i64 %generic_dict_candidate_slot4228, 4
  %generic_dict_key_slot4233 = getelementptr i8, ptr %generic_dict_key_entries4231, i64 %generic_dict_key_entry_offset4232
  %generic_dict_key4234 = load i32, ptr %generic_dict_key_slot4233, align 4
  %generic_dict_key_equal4235 = icmp eq i32 %generic_dict_key4234, 13
  br i1 %generic_dict_key_equal4235, label %bb_generic_dict_group_match971, label %bb_generic_dict_candidate_next968

bb_generic_dict_candidate_next968:
  %generic_dict_candidate_bits_minus_one4236 = sub i16 %generic_dict_candidate_bits4222, 1
  %generic_dict_candidate_cleared_bits4223 = and i16 %generic_dict_candidate_bits4222, %generic_dict_candidate_bits_minus_one4236
  br label %bb_generic_dict_candidate_loop966

bb_generic_dict_group_decision969:
  %generic_dict_group_has_empty4237 = icmp ne i16 %generic_dict_group_empty_bits4209, 0
  br i1 %generic_dict_group_has_empty4237, label %bb_generic_dict_group_empty970, label %bb_generic_dict_group_next972

bb_generic_dict_group_empty970:
  %generic_dict_group_empty_offset164238 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4209, i1 false)
  %generic_dict_group_empty_offset4239 = zext i16 %generic_dict_group_empty_offset164238 to i64
  %generic_dict_group_empty_unwrapped4240 = add i64 %generic_dict_group_start4201, %generic_dict_group_empty_offset4239
  %generic_dict_group_empty_slot4241 = and i64 %generic_dict_group_empty_unwrapped4240, %dict_capacity_mask4193
  %generic_dict_group_use_empty4242 = icmp eq i64 %generic_dict_group_captured_deleted4221, %set_grown_capacity4041
  %generic_dict_group_insertion_slot4243 = select i1 %generic_dict_group_use_empty4242, i64 %generic_dict_group_empty_slot4241, i64 %generic_dict_group_captured_deleted4221
  br label %bb_generic_dict_group_done974

bb_generic_dict_group_match971:
  br label %bb_generic_dict_group_done974

bb_generic_dict_group_next972:
  %generic_dict_group_next_probe4195 = add i64 %generic_dict_group_probe4197, 16
  %generic_dict_group_next_deleted4196 = add i64 %generic_dict_group_captured_deleted4221, 0
  br label %bb_generic_dict_group_find964

bb_generic_dict_group_miss973:
  %generic_dict_group_miss_no_deleted4244 = icmp eq i64 %generic_dict_group_deleted4198, %set_grown_capacity4041
  %generic_dict_group_miss_slot4245 = select i1 %generic_dict_group_miss_no_deleted4244, i64 0, i64 %generic_dict_group_deleted4198
  br label %bb_generic_dict_group_done974

bb_generic_dict_group_done974:
  %generic_dict_find_found4246 = phi i1 [ false, %bb_generic_dict_group_empty970 ], [ true, %bb_generic_dict_group_match971 ], [ false, %bb_generic_dict_group_miss973 ]
  %generic_dict_find_slot_result4247 = phi i64 [ %generic_dict_group_insertion_slot4243, %bb_generic_dict_group_empty970 ], [ %generic_dict_candidate_slot4228, %bb_generic_dict_group_match971 ], [ %generic_dict_group_miss_slot4245, %bb_generic_dict_group_miss973 ]
  br label %bb_generic_dict_insert_first_done961

bb_generic_dict_insert_first_done961:
  %generic_dict_insert_first_found4248 = phi i1 [ true, %bb_generic_dict_insert_first_match958 ], [ false, %bb_generic_dict_insert_first_vacant960 ], [ %generic_dict_find_found4246, %bb_generic_dict_group_done974 ], [ false, %bb_generic_dict_insert_no_capacity963 ]
  %generic_dict_insert_first_slot_result4249 = phi i64 [ %dict_start_slot4171, %bb_generic_dict_insert_first_match958 ], [ %dict_start_slot4171, %bb_generic_dict_insert_first_vacant960 ], [ %generic_dict_find_slot_result4247, %bb_generic_dict_group_done974 ], [ 0, %bb_generic_dict_insert_no_capacity963 ]
  %set_key_entries_offset_mirror4250 = add i64 %set_grown_capacity4041, 23
  %set_key_entries_offset4251 = and i64 %set_key_entries_offset_mirror4250, -8
  %set_key_entries4252 = getelementptr i8, ptr %heap4046, i64 %set_key_entries_offset4251
  %set_key_entry_offset4253 = mul i64 %generic_dict_insert_first_slot_result4249, 4
  %set_key_slot4254 = getelementptr i8, ptr %set_key_entries4252, i64 %set_key_entry_offset4253
  store i32 13, ptr %set_key_slot4254, align 4
  %generic_dict_control_slot4255 = getelementptr i8, ptr %heap4046, i64 %generic_dict_insert_first_slot_result4249
  store i8 %dict_h2_byte4169, ptr %generic_dict_control_slot4255, align 1
  %generic_dict_control_mirrored4256 = icmp ult i64 %generic_dict_insert_first_slot_result4249, 16
  br i1 %generic_dict_control_mirrored4256, label %bb_generic_dict_control_mirror975, label %bb_generic_dict_control_done976

bb_generic_dict_control_mirror975:
  %generic_dict_control_mirror_index4257 = add i64 %set_grown_capacity4041, %generic_dict_insert_first_slot_result4249
  %generic_dict_control_mirror_slot4258 = getelementptr i8, ptr %heap4046, i64 %generic_dict_control_mirror_index4257
  store i8 %dict_h2_byte4169, ptr %generic_dict_control_mirror_slot4258, align 1
  br label %bb_generic_dict_control_done976

bb_generic_dict_control_done976:
  br label %bb_set_insert_done925

bb_set_insert_done925:
  %set_pointer4259 = phi ptr [ %mutable_ptr3936, %bb_set_insert_duplicate921 ], [ %mutable_ptr3936, %bb_generic_dict_control_done927 ], [ %heap4046, %bb_generic_dict_control_done976 ]
  %set_length4260 = phi i64 [ %mutable_len3937, %bb_set_insert_duplicate921 ], [ %set_insert_length4028, %bb_generic_dict_control_done927 ], [ %set_insert_length4028, %bb_generic_dict_control_done976 ]
  %set_capacity4261 = phi i64 [ %mutable_capacity3938, %bb_set_insert_duplicate921 ], [ %mutable_capacity3938, %bb_generic_dict_control_done927 ], [ %set_grown_capacity4041, %bb_generic_dict_control_done976 ]
  %set_inserted4262 = phi i1 [ false, %bb_set_insert_duplicate921 ], [ true, %bb_generic_dict_control_done927 ], [ true, %bb_generic_dict_control_done976 ]
  store ptr %set_pointer4259, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length4260, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity4261, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr4263 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len4264 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity4265 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key4266 = sext i32 14 to i64
  %hash_high4268 = lshr i64 %hash_key4266, 32
  %hash_fold4267 = xor i64 %hash_key4266, %hash_high4268
  %hash4269 = mul i64 %hash_fold4267, -7046029254386353131
  %dict_h2_shifted4270 = lshr i64 %hash4269, 57
  %dict_h2_raw4271 = and i64 %dict_h2_shifted4270, 127
  %dict_h2_zero4272 = icmp eq i64 %dict_h2_raw4271, 0
  %dict_h24273 = select i1 %dict_h2_zero4272, i64 1, i64 %dict_h2_raw4271
  %dict_h2_byte4274 = trunc i64 %dict_h24273 to i8
  %dict_capacity_mask4275 = sub i64 %mutable_capacity4265, 1
  %dict_start_slot4276 = and i64 %hash4269, %dict_capacity_mask4275
  %generic_dict_insert_has_capacity4277 = icmp ugt i64 %mutable_capacity4265, 0
  br i1 %generic_dict_insert_has_capacity4277, label %bb_generic_dict_insert_first983, label %bb_generic_dict_insert_no_capacity984

bb_generic_dict_insert_no_capacity984:
  br label %bb_generic_dict_insert_first_done982

bb_generic_dict_insert_first983:
  %generic_dict_control_slot4278 = getelementptr i8, ptr %mutable_ptr4263, i64 %dict_start_slot4276
  %generic_dict_control4279 = load i8, ptr %generic_dict_control_slot4278, align 1
  %generic_dict_insert_first_empty4280 = icmp eq i8 %generic_dict_control4279, 0
  br i1 %generic_dict_insert_first_empty4280, label %bb_generic_dict_insert_first_vacant981, label %bb_generic_dict_insert_first_occupied977

bb_generic_dict_insert_first_occupied977:
  %generic_dict_insert_first_h24281 = icmp eq i8 %generic_dict_control4279, %dict_h2_byte4274
  br i1 %generic_dict_insert_first_h24281, label %bb_generic_dict_insert_first_compare978, label %bb_generic_dict_insert_first_fallback980

bb_generic_dict_insert_first_compare978:
  %generic_dict_insert_first_key_entries_offset_mirror4282 = add i64 %mutable_capacity4265, 23
  %generic_dict_insert_first_key_entries_offset4283 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4282, -8
  %generic_dict_insert_first_key_entries4284 = getelementptr i8, ptr %mutable_ptr4263, i64 %generic_dict_insert_first_key_entries_offset4283
  %generic_dict_insert_first_key_entry_offset4285 = mul i64 %dict_start_slot4276, 4
  %generic_dict_insert_first_key_slot4286 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4284, i64 %generic_dict_insert_first_key_entry_offset4285
  %generic_dict_insert_first_key4287 = load i32, ptr %generic_dict_insert_first_key_slot4286, align 4
  %generic_dict_key_equal4288 = icmp eq i32 %generic_dict_insert_first_key4287, 14
  br i1 %generic_dict_key_equal4288, label %bb_generic_dict_insert_first_match979, label %bb_generic_dict_insert_first_fallback980

bb_generic_dict_insert_first_match979:
  br label %bb_generic_dict_insert_first_done982

bb_generic_dict_insert_first_vacant981:
  br label %bb_generic_dict_insert_first_done982

bb_generic_dict_insert_first_fallback980:
  %hash_key4289 = sext i32 14 to i64
  %hash_high4291 = lshr i64 %hash_key4289, 32
  %hash_fold4290 = xor i64 %hash_key4289, %hash_high4291
  %hash4292 = mul i64 %hash_fold4290, -7046029254386353131
  %dict_h2_shifted4293 = lshr i64 %hash4292, 57
  %dict_h2_raw4294 = and i64 %dict_h2_shifted4293, 127
  %dict_h2_zero4295 = icmp eq i64 %dict_h2_raw4294, 0
  %dict_h24296 = select i1 %dict_h2_zero4295, i64 1, i64 %dict_h2_raw4294
  %dict_h2_byte4297 = trunc i64 %dict_h24296 to i8
  %dict_capacity_mask4298 = sub i64 %mutable_capacity4265, 1
  %dict_start_slot4299 = and i64 %hash4292, %dict_capacity_mask4298
  br label %bb_generic_dict_group_find985

bb_generic_dict_group_find985:
  %generic_dict_group_probe4302 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback980 ], [ %generic_dict_group_next_probe4300, %bb_generic_dict_group_next993 ]
  %generic_dict_group_deleted4303 = phi i64 [ %mutable_capacity4265, %bb_generic_dict_insert_first_fallback980 ], [ %generic_dict_group_next_deleted4301, %bb_generic_dict_group_next993 ]
  %generic_dict_group_active4304 = icmp ult i64 %generic_dict_group_probe4302, %mutable_capacity4265
  br i1 %generic_dict_group_active4304, label %bb_generic_dict_group_body986, label %bb_generic_dict_group_miss994

bb_generic_dict_group_body986:
  %generic_dict_group_unwrapped4305 = add i64 %dict_start_slot4299, %generic_dict_group_probe4302
  %generic_dict_group_start4306 = and i64 %generic_dict_group_unwrapped4305, %dict_capacity_mask4298
  %generic_dict_group_pointer4307 = getelementptr i8, ptr %mutable_ptr4263, i64 %generic_dict_group_start4306
  %generic_dict_group_controls4308 = load <16 x i8>, ptr %generic_dict_group_pointer4307, align 1
  %generic_dict_group_h2_seed4309 = insertelement <16 x i8> poison, i8 %dict_h2_byte4297, i64 0
  %generic_dict_group_h2_vector4310 = shufflevector <16 x i8> %generic_dict_group_h2_seed4309, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4311 = icmp eq <16 x i8> %generic_dict_group_controls4308, %generic_dict_group_h2_vector4310
  %generic_dict_group_match_bits4312 = bitcast <16 x i1> %generic_dict_group_matches_vector4311 to i16
  %generic_dict_group_empty_vector4313 = icmp eq <16 x i8> %generic_dict_group_controls4308, zeroinitializer
  %generic_dict_group_empty_bits4314 = bitcast <16 x i1> %generic_dict_group_empty_vector4313 to i16
  %generic_dict_group_deleted_seed4315 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4316 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4315, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4317 = icmp eq <16 x i8> %generic_dict_group_controls4308, %generic_dict_group_deleted_vector4316
  %generic_dict_group_deleted_bits4318 = bitcast <16 x i1> %generic_dict_group_deleted_matches4317 to i16
  %generic_dict_group_has_deleted4319 = icmp ne i16 %generic_dict_group_deleted_bits4318, 0
  %generic_dict_group_no_previous_deleted4320 = icmp eq i64 %generic_dict_group_deleted4303, %mutable_capacity4265
  %generic_dict_group_capture_deleted4321 = and i1 %generic_dict_group_has_deleted4319, %generic_dict_group_no_previous_deleted4320
  %generic_dict_group_deleted_offset164322 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4318, i1 false)
  %generic_dict_group_deleted_offset4323 = zext i16 %generic_dict_group_deleted_offset164322 to i64
  %generic_dict_group_deleted_unwrapped4324 = add i64 %generic_dict_group_start4306, %generic_dict_group_deleted_offset4323
  %generic_dict_group_deleted_slot4325 = and i64 %generic_dict_group_deleted_unwrapped4324, %dict_capacity_mask4298
  %generic_dict_group_captured_deleted4326 = select i1 %generic_dict_group_capture_deleted4321, i64 %generic_dict_group_deleted_slot4325, i64 %generic_dict_group_deleted4303
  br label %bb_generic_dict_candidate_loop987

bb_generic_dict_candidate_loop987:
  %generic_dict_candidate_bits4327 = phi i16 [ %generic_dict_group_match_bits4312, %bb_generic_dict_group_body986 ], [ %generic_dict_candidate_cleared_bits4328, %bb_generic_dict_candidate_next989 ]
  %generic_dict_has_candidate4329 = icmp ne i16 %generic_dict_candidate_bits4327, 0
  br i1 %generic_dict_has_candidate4329, label %bb_generic_dict_candidate_body988, label %bb_generic_dict_group_decision990

bb_generic_dict_candidate_body988:
  %generic_dict_candidate_offset164330 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4327, i1 false)
  %generic_dict_candidate_offset4331 = zext i16 %generic_dict_candidate_offset164330 to i64
  %generic_dict_candidate_unwrapped4332 = add i64 %generic_dict_group_start4306, %generic_dict_candidate_offset4331
  %generic_dict_candidate_slot4333 = and i64 %generic_dict_candidate_unwrapped4332, %dict_capacity_mask4298
  %generic_dict_key_entries_offset_mirror4334 = add i64 %mutable_capacity4265, 23
  %generic_dict_key_entries_offset4335 = and i64 %generic_dict_key_entries_offset_mirror4334, -8
  %generic_dict_key_entries4336 = getelementptr i8, ptr %mutable_ptr4263, i64 %generic_dict_key_entries_offset4335
  %generic_dict_key_entry_offset4337 = mul i64 %generic_dict_candidate_slot4333, 4
  %generic_dict_key_slot4338 = getelementptr i8, ptr %generic_dict_key_entries4336, i64 %generic_dict_key_entry_offset4337
  %generic_dict_key4339 = load i32, ptr %generic_dict_key_slot4338, align 4
  %generic_dict_key_equal4340 = icmp eq i32 %generic_dict_key4339, 14
  br i1 %generic_dict_key_equal4340, label %bb_generic_dict_group_match992, label %bb_generic_dict_candidate_next989

bb_generic_dict_candidate_next989:
  %generic_dict_candidate_bits_minus_one4341 = sub i16 %generic_dict_candidate_bits4327, 1
  %generic_dict_candidate_cleared_bits4328 = and i16 %generic_dict_candidate_bits4327, %generic_dict_candidate_bits_minus_one4341
  br label %bb_generic_dict_candidate_loop987

bb_generic_dict_group_decision990:
  %generic_dict_group_has_empty4342 = icmp ne i16 %generic_dict_group_empty_bits4314, 0
  br i1 %generic_dict_group_has_empty4342, label %bb_generic_dict_group_empty991, label %bb_generic_dict_group_next993

bb_generic_dict_group_empty991:
  %generic_dict_group_empty_offset164343 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4314, i1 false)
  %generic_dict_group_empty_offset4344 = zext i16 %generic_dict_group_empty_offset164343 to i64
  %generic_dict_group_empty_unwrapped4345 = add i64 %generic_dict_group_start4306, %generic_dict_group_empty_offset4344
  %generic_dict_group_empty_slot4346 = and i64 %generic_dict_group_empty_unwrapped4345, %dict_capacity_mask4298
  %generic_dict_group_use_empty4347 = icmp eq i64 %generic_dict_group_captured_deleted4326, %mutable_capacity4265
  %generic_dict_group_insertion_slot4348 = select i1 %generic_dict_group_use_empty4347, i64 %generic_dict_group_empty_slot4346, i64 %generic_dict_group_captured_deleted4326
  br label %bb_generic_dict_group_done995

bb_generic_dict_group_match992:
  br label %bb_generic_dict_group_done995

bb_generic_dict_group_next993:
  %generic_dict_group_next_probe4300 = add i64 %generic_dict_group_probe4302, 16
  %generic_dict_group_next_deleted4301 = add i64 %generic_dict_group_captured_deleted4326, 0
  br label %bb_generic_dict_group_find985

bb_generic_dict_group_miss994:
  %generic_dict_group_miss_no_deleted4349 = icmp eq i64 %generic_dict_group_deleted4303, %mutable_capacity4265
  %generic_dict_group_miss_slot4350 = select i1 %generic_dict_group_miss_no_deleted4349, i64 0, i64 %generic_dict_group_deleted4303
  br label %bb_generic_dict_group_done995

bb_generic_dict_group_done995:
  %generic_dict_find_found4351 = phi i1 [ false, %bb_generic_dict_group_empty991 ], [ true, %bb_generic_dict_group_match992 ], [ false, %bb_generic_dict_group_miss994 ]
  %generic_dict_find_slot_result4352 = phi i64 [ %generic_dict_group_insertion_slot4348, %bb_generic_dict_group_empty991 ], [ %generic_dict_candidate_slot4333, %bb_generic_dict_group_match992 ], [ %generic_dict_group_miss_slot4350, %bb_generic_dict_group_miss994 ]
  br label %bb_generic_dict_insert_first_done982

bb_generic_dict_insert_first_done982:
  %generic_dict_insert_first_found4353 = phi i1 [ true, %bb_generic_dict_insert_first_match979 ], [ false, %bb_generic_dict_insert_first_vacant981 ], [ %generic_dict_find_found4351, %bb_generic_dict_group_done995 ], [ false, %bb_generic_dict_insert_no_capacity984 ]
  %generic_dict_insert_first_slot_result4354 = phi i64 [ %dict_start_slot4276, %bb_generic_dict_insert_first_match979 ], [ %dict_start_slot4276, %bb_generic_dict_insert_first_vacant981 ], [ %generic_dict_find_slot_result4352, %bb_generic_dict_group_done995 ], [ 0, %bb_generic_dict_insert_no_capacity984 ]
  br i1 %generic_dict_insert_first_found4353, label %bb_set_insert_duplicate996, label %bb_set_insert_new997

bb_set_insert_duplicate996:
  br label %bb_set_insert_done1000

bb_set_insert_new997:
  %set_insert_length4355 = add i64 %mutable_len4264, 1
  %set_insert_load_num4356 = mul i64 %set_insert_length4355, 8
  %set_insert_load_den4357 = mul i64 %mutable_capacity4265, 7
  %set_insert_should_grow4358 = icmp ugt i64 %set_insert_load_num4356, %set_insert_load_den4357
  br i1 %set_insert_should_grow4358, label %bb_set_insert_grow999, label %bb_set_insert_current998

bb_set_insert_current998:
  %set_key_entries_offset_mirror4359 = add i64 %mutable_capacity4265, 23
  %set_key_entries_offset4360 = and i64 %set_key_entries_offset_mirror4359, -8
  %set_key_entries4361 = getelementptr i8, ptr %mutable_ptr4263, i64 %set_key_entries_offset4360
  %set_key_entry_offset4362 = mul i64 %generic_dict_insert_first_slot_result4354, 4
  %set_key_slot4363 = getelementptr i8, ptr %set_key_entries4361, i64 %set_key_entry_offset4362
  store i32 14, ptr %set_key_slot4363, align 4
  %generic_dict_control_slot4364 = getelementptr i8, ptr %mutable_ptr4263, i64 %generic_dict_insert_first_slot_result4354
  store i8 %dict_h2_byte4274, ptr %generic_dict_control_slot4364, align 1
  %generic_dict_control_mirrored4365 = icmp ult i64 %generic_dict_insert_first_slot_result4354, 16
  br i1 %generic_dict_control_mirrored4365, label %bb_generic_dict_control_mirror1001, label %bb_generic_dict_control_done1002

bb_generic_dict_control_mirror1001:
  %generic_dict_control_mirror_index4366 = add i64 %mutable_capacity4265, %generic_dict_insert_first_slot_result4354
  %generic_dict_control_mirror_slot4367 = getelementptr i8, ptr %mutable_ptr4263, i64 %generic_dict_control_mirror_index4366
  store i8 %dict_h2_byte4274, ptr %generic_dict_control_mirror_slot4367, align 1
  br label %bb_generic_dict_control_done1002

bb_generic_dict_control_done1002:
  br label %bb_set_insert_done1000

bb_set_insert_grow999:
  %set_grown_capacity4368 = mul i64 %mutable_capacity4265, 2
  %generic_dict_entries_offset_mirror4369 = add i64 %set_grown_capacity4368, 23
  %generic_dict_entries_offset4370 = and i64 %generic_dict_entries_offset_mirror4369, -8
  %generic_dict_entries_bytes4371 = mul i64 %set_grown_capacity4368, 4
  %generic_dict_bytes4372 = add i64 %generic_dict_entries_offset4370, %generic_dict_entries_bytes4371
  %heap4373 = call ptr @sollang_alloc(i64 %generic_dict_bytes4372)
  %heap_ok4374 = icmp ne ptr %heap4373, null
  br i1 %heap_ok4374, label %bb_alloc_ok1003, label %bb_alloc_fail1004

bb_alloc_fail1004:
  %trap_stderr4375 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr4375, ptr @.slg.str.module.x.14, i32 26, ptr %trap_written4376, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok1003:
  %generic_dict_control_bytes4377 = add i64 %set_grown_capacity4368, 16
  call void @llvm.memset.p0.i64(ptr %heap4373, i8 0, i64 %generic_dict_control_bytes4377, i1 false)
  br label %bb_set_rehash1005

bb_set_rehash1005:
  %set_rehash_index4379 = phi i64 [ 0, %bb_alloc_ok1003 ], [ %set_rehash_next_index4378, %bb_set_rehash_next1008 ]
  %set_rehash_active4380 = icmp ult i64 %set_rehash_index4379, %mutable_capacity4265
  br i1 %set_rehash_active4380, label %bb_set_rehash_body1006, label %bb_set_rehash_done1009

bb_set_rehash_body1006:
  %generic_dict_control_slot4381 = getelementptr i8, ptr %mutable_ptr4263, i64 %set_rehash_index4379
  %generic_dict_control4382 = load i8, ptr %generic_dict_control_slot4381, align 1
  %set_rehash_occupied4383 = icmp sgt i8 %generic_dict_control4382, 0
  br i1 %set_rehash_occupied4383, label %bb_set_rehash_move1007, label %bb_set_rehash_next1008

bb_set_rehash_move1007:
  %set_rehash_key_entries_offset_mirror4384 = add i64 %mutable_capacity4265, 23
  %set_rehash_key_entries_offset4385 = and i64 %set_rehash_key_entries_offset_mirror4384, -8
  %set_rehash_key_entries4386 = getelementptr i8, ptr %mutable_ptr4263, i64 %set_rehash_key_entries_offset4385
  %set_rehash_key_entry_offset4387 = mul i64 %set_rehash_index4379, 4
  %set_rehash_key_slot4388 = getelementptr i8, ptr %set_rehash_key_entries4386, i64 %set_rehash_key_entry_offset4387
  %set_rehash_key4389 = load i32, ptr %set_rehash_key_slot4388, align 4
  %hash_key4390 = sext i32 %set_rehash_key4389 to i64
  %hash_high4392 = lshr i64 %hash_key4390, 32
  %hash_fold4391 = xor i64 %hash_key4390, %hash_high4392
  %hash4393 = mul i64 %hash_fold4391, -7046029254386353131
  %dict_h2_shifted4394 = lshr i64 %hash4393, 57
  %dict_h2_raw4395 = and i64 %dict_h2_shifted4394, 127
  %dict_h2_zero4396 = icmp eq i64 %dict_h2_raw4395, 0
  %dict_h24397 = select i1 %dict_h2_zero4396, i64 1, i64 %dict_h2_raw4395
  %dict_h2_byte4398 = trunc i64 %dict_h24397 to i8
  %dict_capacity_mask4399 = sub i64 %set_grown_capacity4368, 1
  %dict_start_slot4400 = and i64 %hash4393, %dict_capacity_mask4399
  %generic_dict_insert_has_capacity4401 = icmp ugt i64 %set_grown_capacity4368, 0
  br i1 %generic_dict_insert_has_capacity4401, label %bb_generic_dict_insert_first1016, label %bb_generic_dict_insert_no_capacity1017

bb_generic_dict_insert_no_capacity1017:
  br label %bb_generic_dict_insert_first_done1015

bb_generic_dict_insert_first1016:
  %generic_dict_control_slot4402 = getelementptr i8, ptr %heap4373, i64 %dict_start_slot4400
  %generic_dict_control4403 = load i8, ptr %generic_dict_control_slot4402, align 1
  %generic_dict_insert_first_empty4404 = icmp eq i8 %generic_dict_control4403, 0
  br i1 %generic_dict_insert_first_empty4404, label %bb_generic_dict_insert_first_vacant1014, label %bb_generic_dict_insert_first_occupied1010

bb_generic_dict_insert_first_occupied1010:
  %generic_dict_insert_first_h24405 = icmp eq i8 %generic_dict_control4403, %dict_h2_byte4398
  br i1 %generic_dict_insert_first_h24405, label %bb_generic_dict_insert_first_compare1011, label %bb_generic_dict_insert_first_fallback1013

bb_generic_dict_insert_first_compare1011:
  %generic_dict_insert_first_key_entries_offset_mirror4406 = add i64 %set_grown_capacity4368, 23
  %generic_dict_insert_first_key_entries_offset4407 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4406, -8
  %generic_dict_insert_first_key_entries4408 = getelementptr i8, ptr %heap4373, i64 %generic_dict_insert_first_key_entries_offset4407
  %generic_dict_insert_first_key_entry_offset4409 = mul i64 %dict_start_slot4400, 4
  %generic_dict_insert_first_key_slot4410 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4408, i64 %generic_dict_insert_first_key_entry_offset4409
  %generic_dict_insert_first_key4411 = load i32, ptr %generic_dict_insert_first_key_slot4410, align 4
  %generic_dict_key_equal4412 = icmp eq i32 %generic_dict_insert_first_key4411, %set_rehash_key4389
  br i1 %generic_dict_key_equal4412, label %bb_generic_dict_insert_first_match1012, label %bb_generic_dict_insert_first_fallback1013

bb_generic_dict_insert_first_match1012:
  br label %bb_generic_dict_insert_first_done1015

bb_generic_dict_insert_first_vacant1014:
  br label %bb_generic_dict_insert_first_done1015

bb_generic_dict_insert_first_fallback1013:
  %hash_key4413 = sext i32 %set_rehash_key4389 to i64
  %hash_high4415 = lshr i64 %hash_key4413, 32
  %hash_fold4414 = xor i64 %hash_key4413, %hash_high4415
  %hash4416 = mul i64 %hash_fold4414, -7046029254386353131
  %dict_h2_shifted4417 = lshr i64 %hash4416, 57
  %dict_h2_raw4418 = and i64 %dict_h2_shifted4417, 127
  %dict_h2_zero4419 = icmp eq i64 %dict_h2_raw4418, 0
  %dict_h24420 = select i1 %dict_h2_zero4419, i64 1, i64 %dict_h2_raw4418
  %dict_h2_byte4421 = trunc i64 %dict_h24420 to i8
  %dict_capacity_mask4422 = sub i64 %set_grown_capacity4368, 1
  %dict_start_slot4423 = and i64 %hash4416, %dict_capacity_mask4422
  br label %bb_generic_dict_group_find1018

bb_generic_dict_group_find1018:
  %generic_dict_group_probe4426 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1013 ], [ %generic_dict_group_next_probe4424, %bb_generic_dict_group_next1026 ]
  %generic_dict_group_deleted4427 = phi i64 [ %set_grown_capacity4368, %bb_generic_dict_insert_first_fallback1013 ], [ %generic_dict_group_next_deleted4425, %bb_generic_dict_group_next1026 ]
  %generic_dict_group_active4428 = icmp ult i64 %generic_dict_group_probe4426, %set_grown_capacity4368
  br i1 %generic_dict_group_active4428, label %bb_generic_dict_group_body1019, label %bb_generic_dict_group_miss1027

bb_generic_dict_group_body1019:
  %generic_dict_group_unwrapped4429 = add i64 %dict_start_slot4423, %generic_dict_group_probe4426
  %generic_dict_group_start4430 = and i64 %generic_dict_group_unwrapped4429, %dict_capacity_mask4422
  %generic_dict_group_pointer4431 = getelementptr i8, ptr %heap4373, i64 %generic_dict_group_start4430
  %generic_dict_group_controls4432 = load <16 x i8>, ptr %generic_dict_group_pointer4431, align 1
  %generic_dict_group_h2_seed4433 = insertelement <16 x i8> poison, i8 %dict_h2_byte4421, i64 0
  %generic_dict_group_h2_vector4434 = shufflevector <16 x i8> %generic_dict_group_h2_seed4433, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4435 = icmp eq <16 x i8> %generic_dict_group_controls4432, %generic_dict_group_h2_vector4434
  %generic_dict_group_match_bits4436 = bitcast <16 x i1> %generic_dict_group_matches_vector4435 to i16
  %generic_dict_group_empty_vector4437 = icmp eq <16 x i8> %generic_dict_group_controls4432, zeroinitializer
  %generic_dict_group_empty_bits4438 = bitcast <16 x i1> %generic_dict_group_empty_vector4437 to i16
  %generic_dict_group_deleted_seed4439 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4440 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4439, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4441 = icmp eq <16 x i8> %generic_dict_group_controls4432, %generic_dict_group_deleted_vector4440
  %generic_dict_group_deleted_bits4442 = bitcast <16 x i1> %generic_dict_group_deleted_matches4441 to i16
  %generic_dict_group_has_deleted4443 = icmp ne i16 %generic_dict_group_deleted_bits4442, 0
  %generic_dict_group_no_previous_deleted4444 = icmp eq i64 %generic_dict_group_deleted4427, %set_grown_capacity4368
  %generic_dict_group_capture_deleted4445 = and i1 %generic_dict_group_has_deleted4443, %generic_dict_group_no_previous_deleted4444
  %generic_dict_group_deleted_offset164446 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4442, i1 false)
  %generic_dict_group_deleted_offset4447 = zext i16 %generic_dict_group_deleted_offset164446 to i64
  %generic_dict_group_deleted_unwrapped4448 = add i64 %generic_dict_group_start4430, %generic_dict_group_deleted_offset4447
  %generic_dict_group_deleted_slot4449 = and i64 %generic_dict_group_deleted_unwrapped4448, %dict_capacity_mask4422
  %generic_dict_group_captured_deleted4450 = select i1 %generic_dict_group_capture_deleted4445, i64 %generic_dict_group_deleted_slot4449, i64 %generic_dict_group_deleted4427
  br label %bb_generic_dict_candidate_loop1020

bb_generic_dict_candidate_loop1020:
  %generic_dict_candidate_bits4451 = phi i16 [ %generic_dict_group_match_bits4436, %bb_generic_dict_group_body1019 ], [ %generic_dict_candidate_cleared_bits4452, %bb_generic_dict_candidate_next1022 ]
  %generic_dict_has_candidate4453 = icmp ne i16 %generic_dict_candidate_bits4451, 0
  br i1 %generic_dict_has_candidate4453, label %bb_generic_dict_candidate_body1021, label %bb_generic_dict_group_decision1023

bb_generic_dict_candidate_body1021:
  %generic_dict_candidate_offset164454 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4451, i1 false)
  %generic_dict_candidate_offset4455 = zext i16 %generic_dict_candidate_offset164454 to i64
  %generic_dict_candidate_unwrapped4456 = add i64 %generic_dict_group_start4430, %generic_dict_candidate_offset4455
  %generic_dict_candidate_slot4457 = and i64 %generic_dict_candidate_unwrapped4456, %dict_capacity_mask4422
  %generic_dict_key_entries_offset_mirror4458 = add i64 %set_grown_capacity4368, 23
  %generic_dict_key_entries_offset4459 = and i64 %generic_dict_key_entries_offset_mirror4458, -8
  %generic_dict_key_entries4460 = getelementptr i8, ptr %heap4373, i64 %generic_dict_key_entries_offset4459
  %generic_dict_key_entry_offset4461 = mul i64 %generic_dict_candidate_slot4457, 4
  %generic_dict_key_slot4462 = getelementptr i8, ptr %generic_dict_key_entries4460, i64 %generic_dict_key_entry_offset4461
  %generic_dict_key4463 = load i32, ptr %generic_dict_key_slot4462, align 4
  %generic_dict_key_equal4464 = icmp eq i32 %generic_dict_key4463, %set_rehash_key4389
  br i1 %generic_dict_key_equal4464, label %bb_generic_dict_group_match1025, label %bb_generic_dict_candidate_next1022

bb_generic_dict_candidate_next1022:
  %generic_dict_candidate_bits_minus_one4465 = sub i16 %generic_dict_candidate_bits4451, 1
  %generic_dict_candidate_cleared_bits4452 = and i16 %generic_dict_candidate_bits4451, %generic_dict_candidate_bits_minus_one4465
  br label %bb_generic_dict_candidate_loop1020

bb_generic_dict_group_decision1023:
  %generic_dict_group_has_empty4466 = icmp ne i16 %generic_dict_group_empty_bits4438, 0
  br i1 %generic_dict_group_has_empty4466, label %bb_generic_dict_group_empty1024, label %bb_generic_dict_group_next1026

bb_generic_dict_group_empty1024:
  %generic_dict_group_empty_offset164467 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4438, i1 false)
  %generic_dict_group_empty_offset4468 = zext i16 %generic_dict_group_empty_offset164467 to i64
  %generic_dict_group_empty_unwrapped4469 = add i64 %generic_dict_group_start4430, %generic_dict_group_empty_offset4468
  %generic_dict_group_empty_slot4470 = and i64 %generic_dict_group_empty_unwrapped4469, %dict_capacity_mask4422
  %generic_dict_group_use_empty4471 = icmp eq i64 %generic_dict_group_captured_deleted4450, %set_grown_capacity4368
  %generic_dict_group_insertion_slot4472 = select i1 %generic_dict_group_use_empty4471, i64 %generic_dict_group_empty_slot4470, i64 %generic_dict_group_captured_deleted4450
  br label %bb_generic_dict_group_done1028

bb_generic_dict_group_match1025:
  br label %bb_generic_dict_group_done1028

bb_generic_dict_group_next1026:
  %generic_dict_group_next_probe4424 = add i64 %generic_dict_group_probe4426, 16
  %generic_dict_group_next_deleted4425 = add i64 %generic_dict_group_captured_deleted4450, 0
  br label %bb_generic_dict_group_find1018

bb_generic_dict_group_miss1027:
  %generic_dict_group_miss_no_deleted4473 = icmp eq i64 %generic_dict_group_deleted4427, %set_grown_capacity4368
  %generic_dict_group_miss_slot4474 = select i1 %generic_dict_group_miss_no_deleted4473, i64 0, i64 %generic_dict_group_deleted4427
  br label %bb_generic_dict_group_done1028

bb_generic_dict_group_done1028:
  %generic_dict_find_found4475 = phi i1 [ false, %bb_generic_dict_group_empty1024 ], [ true, %bb_generic_dict_group_match1025 ], [ false, %bb_generic_dict_group_miss1027 ]
  %generic_dict_find_slot_result4476 = phi i64 [ %generic_dict_group_insertion_slot4472, %bb_generic_dict_group_empty1024 ], [ %generic_dict_candidate_slot4457, %bb_generic_dict_group_match1025 ], [ %generic_dict_group_miss_slot4474, %bb_generic_dict_group_miss1027 ]
  br label %bb_generic_dict_insert_first_done1015

bb_generic_dict_insert_first_done1015:
  %generic_dict_insert_first_found4477 = phi i1 [ true, %bb_generic_dict_insert_first_match1012 ], [ false, %bb_generic_dict_insert_first_vacant1014 ], [ %generic_dict_find_found4475, %bb_generic_dict_group_done1028 ], [ false, %bb_generic_dict_insert_no_capacity1017 ]
  %generic_dict_insert_first_slot_result4478 = phi i64 [ %dict_start_slot4400, %bb_generic_dict_insert_first_match1012 ], [ %dict_start_slot4400, %bb_generic_dict_insert_first_vacant1014 ], [ %generic_dict_find_slot_result4476, %bb_generic_dict_group_done1028 ], [ 0, %bb_generic_dict_insert_no_capacity1017 ]
  %set_key_entries_offset_mirror4479 = add i64 %set_grown_capacity4368, 23
  %set_key_entries_offset4480 = and i64 %set_key_entries_offset_mirror4479, -8
  %set_key_entries4481 = getelementptr i8, ptr %heap4373, i64 %set_key_entries_offset4480
  %set_key_entry_offset4482 = mul i64 %generic_dict_insert_first_slot_result4478, 4
  %set_key_slot4483 = getelementptr i8, ptr %set_key_entries4481, i64 %set_key_entry_offset4482
  store i32 %set_rehash_key4389, ptr %set_key_slot4483, align 4
  %generic_dict_control_slot4484 = getelementptr i8, ptr %heap4373, i64 %generic_dict_insert_first_slot_result4478
  store i8 %dict_h2_byte4398, ptr %generic_dict_control_slot4484, align 1
  %generic_dict_control_mirrored4485 = icmp ult i64 %generic_dict_insert_first_slot_result4478, 16
  br i1 %generic_dict_control_mirrored4485, label %bb_generic_dict_control_mirror1029, label %bb_generic_dict_control_done1030

bb_generic_dict_control_mirror1029:
  %generic_dict_control_mirror_index4486 = add i64 %set_grown_capacity4368, %generic_dict_insert_first_slot_result4478
  %generic_dict_control_mirror_slot4487 = getelementptr i8, ptr %heap4373, i64 %generic_dict_control_mirror_index4486
  store i8 %dict_h2_byte4398, ptr %generic_dict_control_mirror_slot4487, align 1
  br label %bb_generic_dict_control_done1030

bb_generic_dict_control_done1030:
  br label %bb_set_rehash_next1008

bb_set_rehash_next1008:
  %set_rehash_next_index4378 = add i64 %set_rehash_index4379, 1
  br label %bb_set_rehash1005

bb_set_rehash_done1009:
  call void @sollang_free(ptr %mutable_ptr4263)
  %hash_key4488 = sext i32 14 to i64
  %hash_high4490 = lshr i64 %hash_key4488, 32
  %hash_fold4489 = xor i64 %hash_key4488, %hash_high4490
  %hash4491 = mul i64 %hash_fold4489, -7046029254386353131
  %dict_h2_shifted4492 = lshr i64 %hash4491, 57
  %dict_h2_raw4493 = and i64 %dict_h2_shifted4492, 127
  %dict_h2_zero4494 = icmp eq i64 %dict_h2_raw4493, 0
  %dict_h24495 = select i1 %dict_h2_zero4494, i64 1, i64 %dict_h2_raw4493
  %dict_h2_byte4496 = trunc i64 %dict_h24495 to i8
  %dict_capacity_mask4497 = sub i64 %set_grown_capacity4368, 1
  %dict_start_slot4498 = and i64 %hash4491, %dict_capacity_mask4497
  %generic_dict_insert_has_capacity4499 = icmp ugt i64 %set_grown_capacity4368, 0
  br i1 %generic_dict_insert_has_capacity4499, label %bb_generic_dict_insert_first1037, label %bb_generic_dict_insert_no_capacity1038

bb_generic_dict_insert_no_capacity1038:
  br label %bb_generic_dict_insert_first_done1036

bb_generic_dict_insert_first1037:
  %generic_dict_control_slot4500 = getelementptr i8, ptr %heap4373, i64 %dict_start_slot4498
  %generic_dict_control4501 = load i8, ptr %generic_dict_control_slot4500, align 1
  %generic_dict_insert_first_empty4502 = icmp eq i8 %generic_dict_control4501, 0
  br i1 %generic_dict_insert_first_empty4502, label %bb_generic_dict_insert_first_vacant1035, label %bb_generic_dict_insert_first_occupied1031

bb_generic_dict_insert_first_occupied1031:
  %generic_dict_insert_first_h24503 = icmp eq i8 %generic_dict_control4501, %dict_h2_byte4496
  br i1 %generic_dict_insert_first_h24503, label %bb_generic_dict_insert_first_compare1032, label %bb_generic_dict_insert_first_fallback1034

bb_generic_dict_insert_first_compare1032:
  %generic_dict_insert_first_key_entries_offset_mirror4504 = add i64 %set_grown_capacity4368, 23
  %generic_dict_insert_first_key_entries_offset4505 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4504, -8
  %generic_dict_insert_first_key_entries4506 = getelementptr i8, ptr %heap4373, i64 %generic_dict_insert_first_key_entries_offset4505
  %generic_dict_insert_first_key_entry_offset4507 = mul i64 %dict_start_slot4498, 4
  %generic_dict_insert_first_key_slot4508 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4506, i64 %generic_dict_insert_first_key_entry_offset4507
  %generic_dict_insert_first_key4509 = load i32, ptr %generic_dict_insert_first_key_slot4508, align 4
  %generic_dict_key_equal4510 = icmp eq i32 %generic_dict_insert_first_key4509, 14
  br i1 %generic_dict_key_equal4510, label %bb_generic_dict_insert_first_match1033, label %bb_generic_dict_insert_first_fallback1034

bb_generic_dict_insert_first_match1033:
  br label %bb_generic_dict_insert_first_done1036

bb_generic_dict_insert_first_vacant1035:
  br label %bb_generic_dict_insert_first_done1036

bb_generic_dict_insert_first_fallback1034:
  %hash_key4511 = sext i32 14 to i64
  %hash_high4513 = lshr i64 %hash_key4511, 32
  %hash_fold4512 = xor i64 %hash_key4511, %hash_high4513
  %hash4514 = mul i64 %hash_fold4512, -7046029254386353131
  %dict_h2_shifted4515 = lshr i64 %hash4514, 57
  %dict_h2_raw4516 = and i64 %dict_h2_shifted4515, 127
  %dict_h2_zero4517 = icmp eq i64 %dict_h2_raw4516, 0
  %dict_h24518 = select i1 %dict_h2_zero4517, i64 1, i64 %dict_h2_raw4516
  %dict_h2_byte4519 = trunc i64 %dict_h24518 to i8
  %dict_capacity_mask4520 = sub i64 %set_grown_capacity4368, 1
  %dict_start_slot4521 = and i64 %hash4514, %dict_capacity_mask4520
  br label %bb_generic_dict_group_find1039

bb_generic_dict_group_find1039:
  %generic_dict_group_probe4524 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1034 ], [ %generic_dict_group_next_probe4522, %bb_generic_dict_group_next1047 ]
  %generic_dict_group_deleted4525 = phi i64 [ %set_grown_capacity4368, %bb_generic_dict_insert_first_fallback1034 ], [ %generic_dict_group_next_deleted4523, %bb_generic_dict_group_next1047 ]
  %generic_dict_group_active4526 = icmp ult i64 %generic_dict_group_probe4524, %set_grown_capacity4368
  br i1 %generic_dict_group_active4526, label %bb_generic_dict_group_body1040, label %bb_generic_dict_group_miss1048

bb_generic_dict_group_body1040:
  %generic_dict_group_unwrapped4527 = add i64 %dict_start_slot4521, %generic_dict_group_probe4524
  %generic_dict_group_start4528 = and i64 %generic_dict_group_unwrapped4527, %dict_capacity_mask4520
  %generic_dict_group_pointer4529 = getelementptr i8, ptr %heap4373, i64 %generic_dict_group_start4528
  %generic_dict_group_controls4530 = load <16 x i8>, ptr %generic_dict_group_pointer4529, align 1
  %generic_dict_group_h2_seed4531 = insertelement <16 x i8> poison, i8 %dict_h2_byte4519, i64 0
  %generic_dict_group_h2_vector4532 = shufflevector <16 x i8> %generic_dict_group_h2_seed4531, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4533 = icmp eq <16 x i8> %generic_dict_group_controls4530, %generic_dict_group_h2_vector4532
  %generic_dict_group_match_bits4534 = bitcast <16 x i1> %generic_dict_group_matches_vector4533 to i16
  %generic_dict_group_empty_vector4535 = icmp eq <16 x i8> %generic_dict_group_controls4530, zeroinitializer
  %generic_dict_group_empty_bits4536 = bitcast <16 x i1> %generic_dict_group_empty_vector4535 to i16
  %generic_dict_group_deleted_seed4537 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4538 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4537, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4539 = icmp eq <16 x i8> %generic_dict_group_controls4530, %generic_dict_group_deleted_vector4538
  %generic_dict_group_deleted_bits4540 = bitcast <16 x i1> %generic_dict_group_deleted_matches4539 to i16
  %generic_dict_group_has_deleted4541 = icmp ne i16 %generic_dict_group_deleted_bits4540, 0
  %generic_dict_group_no_previous_deleted4542 = icmp eq i64 %generic_dict_group_deleted4525, %set_grown_capacity4368
  %generic_dict_group_capture_deleted4543 = and i1 %generic_dict_group_has_deleted4541, %generic_dict_group_no_previous_deleted4542
  %generic_dict_group_deleted_offset164544 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4540, i1 false)
  %generic_dict_group_deleted_offset4545 = zext i16 %generic_dict_group_deleted_offset164544 to i64
  %generic_dict_group_deleted_unwrapped4546 = add i64 %generic_dict_group_start4528, %generic_dict_group_deleted_offset4545
  %generic_dict_group_deleted_slot4547 = and i64 %generic_dict_group_deleted_unwrapped4546, %dict_capacity_mask4520
  %generic_dict_group_captured_deleted4548 = select i1 %generic_dict_group_capture_deleted4543, i64 %generic_dict_group_deleted_slot4547, i64 %generic_dict_group_deleted4525
  br label %bb_generic_dict_candidate_loop1041

bb_generic_dict_candidate_loop1041:
  %generic_dict_candidate_bits4549 = phi i16 [ %generic_dict_group_match_bits4534, %bb_generic_dict_group_body1040 ], [ %generic_dict_candidate_cleared_bits4550, %bb_generic_dict_candidate_next1043 ]
  %generic_dict_has_candidate4551 = icmp ne i16 %generic_dict_candidate_bits4549, 0
  br i1 %generic_dict_has_candidate4551, label %bb_generic_dict_candidate_body1042, label %bb_generic_dict_group_decision1044

bb_generic_dict_candidate_body1042:
  %generic_dict_candidate_offset164552 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4549, i1 false)
  %generic_dict_candidate_offset4553 = zext i16 %generic_dict_candidate_offset164552 to i64
  %generic_dict_candidate_unwrapped4554 = add i64 %generic_dict_group_start4528, %generic_dict_candidate_offset4553
  %generic_dict_candidate_slot4555 = and i64 %generic_dict_candidate_unwrapped4554, %dict_capacity_mask4520
  %generic_dict_key_entries_offset_mirror4556 = add i64 %set_grown_capacity4368, 23
  %generic_dict_key_entries_offset4557 = and i64 %generic_dict_key_entries_offset_mirror4556, -8
  %generic_dict_key_entries4558 = getelementptr i8, ptr %heap4373, i64 %generic_dict_key_entries_offset4557
  %generic_dict_key_entry_offset4559 = mul i64 %generic_dict_candidate_slot4555, 4
  %generic_dict_key_slot4560 = getelementptr i8, ptr %generic_dict_key_entries4558, i64 %generic_dict_key_entry_offset4559
  %generic_dict_key4561 = load i32, ptr %generic_dict_key_slot4560, align 4
  %generic_dict_key_equal4562 = icmp eq i32 %generic_dict_key4561, 14
  br i1 %generic_dict_key_equal4562, label %bb_generic_dict_group_match1046, label %bb_generic_dict_candidate_next1043

bb_generic_dict_candidate_next1043:
  %generic_dict_candidate_bits_minus_one4563 = sub i16 %generic_dict_candidate_bits4549, 1
  %generic_dict_candidate_cleared_bits4550 = and i16 %generic_dict_candidate_bits4549, %generic_dict_candidate_bits_minus_one4563
  br label %bb_generic_dict_candidate_loop1041

bb_generic_dict_group_decision1044:
  %generic_dict_group_has_empty4564 = icmp ne i16 %generic_dict_group_empty_bits4536, 0
  br i1 %generic_dict_group_has_empty4564, label %bb_generic_dict_group_empty1045, label %bb_generic_dict_group_next1047

bb_generic_dict_group_empty1045:
  %generic_dict_group_empty_offset164565 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4536, i1 false)
  %generic_dict_group_empty_offset4566 = zext i16 %generic_dict_group_empty_offset164565 to i64
  %generic_dict_group_empty_unwrapped4567 = add i64 %generic_dict_group_start4528, %generic_dict_group_empty_offset4566
  %generic_dict_group_empty_slot4568 = and i64 %generic_dict_group_empty_unwrapped4567, %dict_capacity_mask4520
  %generic_dict_group_use_empty4569 = icmp eq i64 %generic_dict_group_captured_deleted4548, %set_grown_capacity4368
  %generic_dict_group_insertion_slot4570 = select i1 %generic_dict_group_use_empty4569, i64 %generic_dict_group_empty_slot4568, i64 %generic_dict_group_captured_deleted4548
  br label %bb_generic_dict_group_done1049

bb_generic_dict_group_match1046:
  br label %bb_generic_dict_group_done1049

bb_generic_dict_group_next1047:
  %generic_dict_group_next_probe4522 = add i64 %generic_dict_group_probe4524, 16
  %generic_dict_group_next_deleted4523 = add i64 %generic_dict_group_captured_deleted4548, 0
  br label %bb_generic_dict_group_find1039

bb_generic_dict_group_miss1048:
  %generic_dict_group_miss_no_deleted4571 = icmp eq i64 %generic_dict_group_deleted4525, %set_grown_capacity4368
  %generic_dict_group_miss_slot4572 = select i1 %generic_dict_group_miss_no_deleted4571, i64 0, i64 %generic_dict_group_deleted4525
  br label %bb_generic_dict_group_done1049

bb_generic_dict_group_done1049:
  %generic_dict_find_found4573 = phi i1 [ false, %bb_generic_dict_group_empty1045 ], [ true, %bb_generic_dict_group_match1046 ], [ false, %bb_generic_dict_group_miss1048 ]
  %generic_dict_find_slot_result4574 = phi i64 [ %generic_dict_group_insertion_slot4570, %bb_generic_dict_group_empty1045 ], [ %generic_dict_candidate_slot4555, %bb_generic_dict_group_match1046 ], [ %generic_dict_group_miss_slot4572, %bb_generic_dict_group_miss1048 ]
  br label %bb_generic_dict_insert_first_done1036

bb_generic_dict_insert_first_done1036:
  %generic_dict_insert_first_found4575 = phi i1 [ true, %bb_generic_dict_insert_first_match1033 ], [ false, %bb_generic_dict_insert_first_vacant1035 ], [ %generic_dict_find_found4573, %bb_generic_dict_group_done1049 ], [ false, %bb_generic_dict_insert_no_capacity1038 ]
  %generic_dict_insert_first_slot_result4576 = phi i64 [ %dict_start_slot4498, %bb_generic_dict_insert_first_match1033 ], [ %dict_start_slot4498, %bb_generic_dict_insert_first_vacant1035 ], [ %generic_dict_find_slot_result4574, %bb_generic_dict_group_done1049 ], [ 0, %bb_generic_dict_insert_no_capacity1038 ]
  %set_key_entries_offset_mirror4577 = add i64 %set_grown_capacity4368, 23
  %set_key_entries_offset4578 = and i64 %set_key_entries_offset_mirror4577, -8
  %set_key_entries4579 = getelementptr i8, ptr %heap4373, i64 %set_key_entries_offset4578
  %set_key_entry_offset4580 = mul i64 %generic_dict_insert_first_slot_result4576, 4
  %set_key_slot4581 = getelementptr i8, ptr %set_key_entries4579, i64 %set_key_entry_offset4580
  store i32 14, ptr %set_key_slot4581, align 4
  %generic_dict_control_slot4582 = getelementptr i8, ptr %heap4373, i64 %generic_dict_insert_first_slot_result4576
  store i8 %dict_h2_byte4496, ptr %generic_dict_control_slot4582, align 1
  %generic_dict_control_mirrored4583 = icmp ult i64 %generic_dict_insert_first_slot_result4576, 16
  br i1 %generic_dict_control_mirrored4583, label %bb_generic_dict_control_mirror1050, label %bb_generic_dict_control_done1051

bb_generic_dict_control_mirror1050:
  %generic_dict_control_mirror_index4584 = add i64 %set_grown_capacity4368, %generic_dict_insert_first_slot_result4576
  %generic_dict_control_mirror_slot4585 = getelementptr i8, ptr %heap4373, i64 %generic_dict_control_mirror_index4584
  store i8 %dict_h2_byte4496, ptr %generic_dict_control_mirror_slot4585, align 1
  br label %bb_generic_dict_control_done1051

bb_generic_dict_control_done1051:
  br label %bb_set_insert_done1000

bb_set_insert_done1000:
  %set_pointer4586 = phi ptr [ %mutable_ptr4263, %bb_set_insert_duplicate996 ], [ %mutable_ptr4263, %bb_generic_dict_control_done1002 ], [ %heap4373, %bb_generic_dict_control_done1051 ]
  %set_length4587 = phi i64 [ %mutable_len4264, %bb_set_insert_duplicate996 ], [ %set_insert_length4355, %bb_generic_dict_control_done1002 ], [ %set_insert_length4355, %bb_generic_dict_control_done1051 ]
  %set_capacity4588 = phi i64 [ %mutable_capacity4265, %bb_set_insert_duplicate996 ], [ %mutable_capacity4265, %bb_generic_dict_control_done1002 ], [ %set_grown_capacity4368, %bb_generic_dict_control_done1051 ]
  %set_inserted4589 = phi i1 [ false, %bb_set_insert_duplicate996 ], [ true, %bb_generic_dict_control_done1002 ], [ true, %bb_generic_dict_control_done1051 ]
  store ptr %set_pointer4586, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length4587, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity4588, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr4590 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len4591 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity4592 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key4593 = sext i32 15 to i64
  %hash_high4595 = lshr i64 %hash_key4593, 32
  %hash_fold4594 = xor i64 %hash_key4593, %hash_high4595
  %hash4596 = mul i64 %hash_fold4594, -7046029254386353131
  %dict_h2_shifted4597 = lshr i64 %hash4596, 57
  %dict_h2_raw4598 = and i64 %dict_h2_shifted4597, 127
  %dict_h2_zero4599 = icmp eq i64 %dict_h2_raw4598, 0
  %dict_h24600 = select i1 %dict_h2_zero4599, i64 1, i64 %dict_h2_raw4598
  %dict_h2_byte4601 = trunc i64 %dict_h24600 to i8
  %dict_capacity_mask4602 = sub i64 %mutable_capacity4592, 1
  %dict_start_slot4603 = and i64 %hash4596, %dict_capacity_mask4602
  %generic_dict_insert_has_capacity4604 = icmp ugt i64 %mutable_capacity4592, 0
  br i1 %generic_dict_insert_has_capacity4604, label %bb_generic_dict_insert_first1058, label %bb_generic_dict_insert_no_capacity1059

bb_generic_dict_insert_no_capacity1059:
  br label %bb_generic_dict_insert_first_done1057

bb_generic_dict_insert_first1058:
  %generic_dict_control_slot4605 = getelementptr i8, ptr %mutable_ptr4590, i64 %dict_start_slot4603
  %generic_dict_control4606 = load i8, ptr %generic_dict_control_slot4605, align 1
  %generic_dict_insert_first_empty4607 = icmp eq i8 %generic_dict_control4606, 0
  br i1 %generic_dict_insert_first_empty4607, label %bb_generic_dict_insert_first_vacant1056, label %bb_generic_dict_insert_first_occupied1052

bb_generic_dict_insert_first_occupied1052:
  %generic_dict_insert_first_h24608 = icmp eq i8 %generic_dict_control4606, %dict_h2_byte4601
  br i1 %generic_dict_insert_first_h24608, label %bb_generic_dict_insert_first_compare1053, label %bb_generic_dict_insert_first_fallback1055

bb_generic_dict_insert_first_compare1053:
  %generic_dict_insert_first_key_entries_offset_mirror4609 = add i64 %mutable_capacity4592, 23
  %generic_dict_insert_first_key_entries_offset4610 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4609, -8
  %generic_dict_insert_first_key_entries4611 = getelementptr i8, ptr %mutable_ptr4590, i64 %generic_dict_insert_first_key_entries_offset4610
  %generic_dict_insert_first_key_entry_offset4612 = mul i64 %dict_start_slot4603, 4
  %generic_dict_insert_first_key_slot4613 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4611, i64 %generic_dict_insert_first_key_entry_offset4612
  %generic_dict_insert_first_key4614 = load i32, ptr %generic_dict_insert_first_key_slot4613, align 4
  %generic_dict_key_equal4615 = icmp eq i32 %generic_dict_insert_first_key4614, 15
  br i1 %generic_dict_key_equal4615, label %bb_generic_dict_insert_first_match1054, label %bb_generic_dict_insert_first_fallback1055

bb_generic_dict_insert_first_match1054:
  br label %bb_generic_dict_insert_first_done1057

bb_generic_dict_insert_first_vacant1056:
  br label %bb_generic_dict_insert_first_done1057

bb_generic_dict_insert_first_fallback1055:
  %hash_key4616 = sext i32 15 to i64
  %hash_high4618 = lshr i64 %hash_key4616, 32
  %hash_fold4617 = xor i64 %hash_key4616, %hash_high4618
  %hash4619 = mul i64 %hash_fold4617, -7046029254386353131
  %dict_h2_shifted4620 = lshr i64 %hash4619, 57
  %dict_h2_raw4621 = and i64 %dict_h2_shifted4620, 127
  %dict_h2_zero4622 = icmp eq i64 %dict_h2_raw4621, 0
  %dict_h24623 = select i1 %dict_h2_zero4622, i64 1, i64 %dict_h2_raw4621
  %dict_h2_byte4624 = trunc i64 %dict_h24623 to i8
  %dict_capacity_mask4625 = sub i64 %mutable_capacity4592, 1
  %dict_start_slot4626 = and i64 %hash4619, %dict_capacity_mask4625
  br label %bb_generic_dict_group_find1060

bb_generic_dict_group_find1060:
  %generic_dict_group_probe4629 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1055 ], [ %generic_dict_group_next_probe4627, %bb_generic_dict_group_next1068 ]
  %generic_dict_group_deleted4630 = phi i64 [ %mutable_capacity4592, %bb_generic_dict_insert_first_fallback1055 ], [ %generic_dict_group_next_deleted4628, %bb_generic_dict_group_next1068 ]
  %generic_dict_group_active4631 = icmp ult i64 %generic_dict_group_probe4629, %mutable_capacity4592
  br i1 %generic_dict_group_active4631, label %bb_generic_dict_group_body1061, label %bb_generic_dict_group_miss1069

bb_generic_dict_group_body1061:
  %generic_dict_group_unwrapped4632 = add i64 %dict_start_slot4626, %generic_dict_group_probe4629
  %generic_dict_group_start4633 = and i64 %generic_dict_group_unwrapped4632, %dict_capacity_mask4625
  %generic_dict_group_pointer4634 = getelementptr i8, ptr %mutable_ptr4590, i64 %generic_dict_group_start4633
  %generic_dict_group_controls4635 = load <16 x i8>, ptr %generic_dict_group_pointer4634, align 1
  %generic_dict_group_h2_seed4636 = insertelement <16 x i8> poison, i8 %dict_h2_byte4624, i64 0
  %generic_dict_group_h2_vector4637 = shufflevector <16 x i8> %generic_dict_group_h2_seed4636, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4638 = icmp eq <16 x i8> %generic_dict_group_controls4635, %generic_dict_group_h2_vector4637
  %generic_dict_group_match_bits4639 = bitcast <16 x i1> %generic_dict_group_matches_vector4638 to i16
  %generic_dict_group_empty_vector4640 = icmp eq <16 x i8> %generic_dict_group_controls4635, zeroinitializer
  %generic_dict_group_empty_bits4641 = bitcast <16 x i1> %generic_dict_group_empty_vector4640 to i16
  %generic_dict_group_deleted_seed4642 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4643 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4642, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4644 = icmp eq <16 x i8> %generic_dict_group_controls4635, %generic_dict_group_deleted_vector4643
  %generic_dict_group_deleted_bits4645 = bitcast <16 x i1> %generic_dict_group_deleted_matches4644 to i16
  %generic_dict_group_has_deleted4646 = icmp ne i16 %generic_dict_group_deleted_bits4645, 0
  %generic_dict_group_no_previous_deleted4647 = icmp eq i64 %generic_dict_group_deleted4630, %mutable_capacity4592
  %generic_dict_group_capture_deleted4648 = and i1 %generic_dict_group_has_deleted4646, %generic_dict_group_no_previous_deleted4647
  %generic_dict_group_deleted_offset164649 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4645, i1 false)
  %generic_dict_group_deleted_offset4650 = zext i16 %generic_dict_group_deleted_offset164649 to i64
  %generic_dict_group_deleted_unwrapped4651 = add i64 %generic_dict_group_start4633, %generic_dict_group_deleted_offset4650
  %generic_dict_group_deleted_slot4652 = and i64 %generic_dict_group_deleted_unwrapped4651, %dict_capacity_mask4625
  %generic_dict_group_captured_deleted4653 = select i1 %generic_dict_group_capture_deleted4648, i64 %generic_dict_group_deleted_slot4652, i64 %generic_dict_group_deleted4630
  br label %bb_generic_dict_candidate_loop1062

bb_generic_dict_candidate_loop1062:
  %generic_dict_candidate_bits4654 = phi i16 [ %generic_dict_group_match_bits4639, %bb_generic_dict_group_body1061 ], [ %generic_dict_candidate_cleared_bits4655, %bb_generic_dict_candidate_next1064 ]
  %generic_dict_has_candidate4656 = icmp ne i16 %generic_dict_candidate_bits4654, 0
  br i1 %generic_dict_has_candidate4656, label %bb_generic_dict_candidate_body1063, label %bb_generic_dict_group_decision1065

bb_generic_dict_candidate_body1063:
  %generic_dict_candidate_offset164657 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4654, i1 false)
  %generic_dict_candidate_offset4658 = zext i16 %generic_dict_candidate_offset164657 to i64
  %generic_dict_candidate_unwrapped4659 = add i64 %generic_dict_group_start4633, %generic_dict_candidate_offset4658
  %generic_dict_candidate_slot4660 = and i64 %generic_dict_candidate_unwrapped4659, %dict_capacity_mask4625
  %generic_dict_key_entries_offset_mirror4661 = add i64 %mutable_capacity4592, 23
  %generic_dict_key_entries_offset4662 = and i64 %generic_dict_key_entries_offset_mirror4661, -8
  %generic_dict_key_entries4663 = getelementptr i8, ptr %mutable_ptr4590, i64 %generic_dict_key_entries_offset4662
  %generic_dict_key_entry_offset4664 = mul i64 %generic_dict_candidate_slot4660, 4
  %generic_dict_key_slot4665 = getelementptr i8, ptr %generic_dict_key_entries4663, i64 %generic_dict_key_entry_offset4664
  %generic_dict_key4666 = load i32, ptr %generic_dict_key_slot4665, align 4
  %generic_dict_key_equal4667 = icmp eq i32 %generic_dict_key4666, 15
  br i1 %generic_dict_key_equal4667, label %bb_generic_dict_group_match1067, label %bb_generic_dict_candidate_next1064

bb_generic_dict_candidate_next1064:
  %generic_dict_candidate_bits_minus_one4668 = sub i16 %generic_dict_candidate_bits4654, 1
  %generic_dict_candidate_cleared_bits4655 = and i16 %generic_dict_candidate_bits4654, %generic_dict_candidate_bits_minus_one4668
  br label %bb_generic_dict_candidate_loop1062

bb_generic_dict_group_decision1065:
  %generic_dict_group_has_empty4669 = icmp ne i16 %generic_dict_group_empty_bits4641, 0
  br i1 %generic_dict_group_has_empty4669, label %bb_generic_dict_group_empty1066, label %bb_generic_dict_group_next1068

bb_generic_dict_group_empty1066:
  %generic_dict_group_empty_offset164670 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4641, i1 false)
  %generic_dict_group_empty_offset4671 = zext i16 %generic_dict_group_empty_offset164670 to i64
  %generic_dict_group_empty_unwrapped4672 = add i64 %generic_dict_group_start4633, %generic_dict_group_empty_offset4671
  %generic_dict_group_empty_slot4673 = and i64 %generic_dict_group_empty_unwrapped4672, %dict_capacity_mask4625
  %generic_dict_group_use_empty4674 = icmp eq i64 %generic_dict_group_captured_deleted4653, %mutable_capacity4592
  %generic_dict_group_insertion_slot4675 = select i1 %generic_dict_group_use_empty4674, i64 %generic_dict_group_empty_slot4673, i64 %generic_dict_group_captured_deleted4653
  br label %bb_generic_dict_group_done1070

bb_generic_dict_group_match1067:
  br label %bb_generic_dict_group_done1070

bb_generic_dict_group_next1068:
  %generic_dict_group_next_probe4627 = add i64 %generic_dict_group_probe4629, 16
  %generic_dict_group_next_deleted4628 = add i64 %generic_dict_group_captured_deleted4653, 0
  br label %bb_generic_dict_group_find1060

bb_generic_dict_group_miss1069:
  %generic_dict_group_miss_no_deleted4676 = icmp eq i64 %generic_dict_group_deleted4630, %mutable_capacity4592
  %generic_dict_group_miss_slot4677 = select i1 %generic_dict_group_miss_no_deleted4676, i64 0, i64 %generic_dict_group_deleted4630
  br label %bb_generic_dict_group_done1070

bb_generic_dict_group_done1070:
  %generic_dict_find_found4678 = phi i1 [ false, %bb_generic_dict_group_empty1066 ], [ true, %bb_generic_dict_group_match1067 ], [ false, %bb_generic_dict_group_miss1069 ]
  %generic_dict_find_slot_result4679 = phi i64 [ %generic_dict_group_insertion_slot4675, %bb_generic_dict_group_empty1066 ], [ %generic_dict_candidate_slot4660, %bb_generic_dict_group_match1067 ], [ %generic_dict_group_miss_slot4677, %bb_generic_dict_group_miss1069 ]
  br label %bb_generic_dict_insert_first_done1057

bb_generic_dict_insert_first_done1057:
  %generic_dict_insert_first_found4680 = phi i1 [ true, %bb_generic_dict_insert_first_match1054 ], [ false, %bb_generic_dict_insert_first_vacant1056 ], [ %generic_dict_find_found4678, %bb_generic_dict_group_done1070 ], [ false, %bb_generic_dict_insert_no_capacity1059 ]
  %generic_dict_insert_first_slot_result4681 = phi i64 [ %dict_start_slot4603, %bb_generic_dict_insert_first_match1054 ], [ %dict_start_slot4603, %bb_generic_dict_insert_first_vacant1056 ], [ %generic_dict_find_slot_result4679, %bb_generic_dict_group_done1070 ], [ 0, %bb_generic_dict_insert_no_capacity1059 ]
  br i1 %generic_dict_insert_first_found4680, label %bb_set_insert_duplicate1071, label %bb_set_insert_new1072

bb_set_insert_duplicate1071:
  br label %bb_set_insert_done1075

bb_set_insert_new1072:
  %set_insert_length4682 = add i64 %mutable_len4591, 1
  %set_insert_load_num4683 = mul i64 %set_insert_length4682, 8
  %set_insert_load_den4684 = mul i64 %mutable_capacity4592, 7
  %set_insert_should_grow4685 = icmp ugt i64 %set_insert_load_num4683, %set_insert_load_den4684
  br i1 %set_insert_should_grow4685, label %bb_set_insert_grow1074, label %bb_set_insert_current1073

bb_set_insert_current1073:
  %set_key_entries_offset_mirror4686 = add i64 %mutable_capacity4592, 23
  %set_key_entries_offset4687 = and i64 %set_key_entries_offset_mirror4686, -8
  %set_key_entries4688 = getelementptr i8, ptr %mutable_ptr4590, i64 %set_key_entries_offset4687
  %set_key_entry_offset4689 = mul i64 %generic_dict_insert_first_slot_result4681, 4
  %set_key_slot4690 = getelementptr i8, ptr %set_key_entries4688, i64 %set_key_entry_offset4689
  store i32 15, ptr %set_key_slot4690, align 4
  %generic_dict_control_slot4691 = getelementptr i8, ptr %mutable_ptr4590, i64 %generic_dict_insert_first_slot_result4681
  store i8 %dict_h2_byte4601, ptr %generic_dict_control_slot4691, align 1
  %generic_dict_control_mirrored4692 = icmp ult i64 %generic_dict_insert_first_slot_result4681, 16
  br i1 %generic_dict_control_mirrored4692, label %bb_generic_dict_control_mirror1076, label %bb_generic_dict_control_done1077

bb_generic_dict_control_mirror1076:
  %generic_dict_control_mirror_index4693 = add i64 %mutable_capacity4592, %generic_dict_insert_first_slot_result4681
  %generic_dict_control_mirror_slot4694 = getelementptr i8, ptr %mutable_ptr4590, i64 %generic_dict_control_mirror_index4693
  store i8 %dict_h2_byte4601, ptr %generic_dict_control_mirror_slot4694, align 1
  br label %bb_generic_dict_control_done1077

bb_generic_dict_control_done1077:
  br label %bb_set_insert_done1075

bb_set_insert_grow1074:
  %set_grown_capacity4695 = mul i64 %mutable_capacity4592, 2
  %generic_dict_entries_offset_mirror4696 = add i64 %set_grown_capacity4695, 23
  %generic_dict_entries_offset4697 = and i64 %generic_dict_entries_offset_mirror4696, -8
  %generic_dict_entries_bytes4698 = mul i64 %set_grown_capacity4695, 4
  %generic_dict_bytes4699 = add i64 %generic_dict_entries_offset4697, %generic_dict_entries_bytes4698
  %heap4700 = call ptr @sollang_alloc(i64 %generic_dict_bytes4699)
  %heap_ok4701 = icmp ne ptr %heap4700, null
  br i1 %heap_ok4701, label %bb_alloc_ok1078, label %bb_alloc_fail1079

bb_alloc_fail1079:
  %trap_stderr4702 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr4702, ptr @.slg.str.module.x.15, i32 26, ptr %trap_written4703, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok1078:
  %generic_dict_control_bytes4704 = add i64 %set_grown_capacity4695, 16
  call void @llvm.memset.p0.i64(ptr %heap4700, i8 0, i64 %generic_dict_control_bytes4704, i1 false)
  br label %bb_set_rehash1080

bb_set_rehash1080:
  %set_rehash_index4706 = phi i64 [ 0, %bb_alloc_ok1078 ], [ %set_rehash_next_index4705, %bb_set_rehash_next1083 ]
  %set_rehash_active4707 = icmp ult i64 %set_rehash_index4706, %mutable_capacity4592
  br i1 %set_rehash_active4707, label %bb_set_rehash_body1081, label %bb_set_rehash_done1084

bb_set_rehash_body1081:
  %generic_dict_control_slot4708 = getelementptr i8, ptr %mutable_ptr4590, i64 %set_rehash_index4706
  %generic_dict_control4709 = load i8, ptr %generic_dict_control_slot4708, align 1
  %set_rehash_occupied4710 = icmp sgt i8 %generic_dict_control4709, 0
  br i1 %set_rehash_occupied4710, label %bb_set_rehash_move1082, label %bb_set_rehash_next1083

bb_set_rehash_move1082:
  %set_rehash_key_entries_offset_mirror4711 = add i64 %mutable_capacity4592, 23
  %set_rehash_key_entries_offset4712 = and i64 %set_rehash_key_entries_offset_mirror4711, -8
  %set_rehash_key_entries4713 = getelementptr i8, ptr %mutable_ptr4590, i64 %set_rehash_key_entries_offset4712
  %set_rehash_key_entry_offset4714 = mul i64 %set_rehash_index4706, 4
  %set_rehash_key_slot4715 = getelementptr i8, ptr %set_rehash_key_entries4713, i64 %set_rehash_key_entry_offset4714
  %set_rehash_key4716 = load i32, ptr %set_rehash_key_slot4715, align 4
  %hash_key4717 = sext i32 %set_rehash_key4716 to i64
  %hash_high4719 = lshr i64 %hash_key4717, 32
  %hash_fold4718 = xor i64 %hash_key4717, %hash_high4719
  %hash4720 = mul i64 %hash_fold4718, -7046029254386353131
  %dict_h2_shifted4721 = lshr i64 %hash4720, 57
  %dict_h2_raw4722 = and i64 %dict_h2_shifted4721, 127
  %dict_h2_zero4723 = icmp eq i64 %dict_h2_raw4722, 0
  %dict_h24724 = select i1 %dict_h2_zero4723, i64 1, i64 %dict_h2_raw4722
  %dict_h2_byte4725 = trunc i64 %dict_h24724 to i8
  %dict_capacity_mask4726 = sub i64 %set_grown_capacity4695, 1
  %dict_start_slot4727 = and i64 %hash4720, %dict_capacity_mask4726
  %generic_dict_insert_has_capacity4728 = icmp ugt i64 %set_grown_capacity4695, 0
  br i1 %generic_dict_insert_has_capacity4728, label %bb_generic_dict_insert_first1091, label %bb_generic_dict_insert_no_capacity1092

bb_generic_dict_insert_no_capacity1092:
  br label %bb_generic_dict_insert_first_done1090

bb_generic_dict_insert_first1091:
  %generic_dict_control_slot4729 = getelementptr i8, ptr %heap4700, i64 %dict_start_slot4727
  %generic_dict_control4730 = load i8, ptr %generic_dict_control_slot4729, align 1
  %generic_dict_insert_first_empty4731 = icmp eq i8 %generic_dict_control4730, 0
  br i1 %generic_dict_insert_first_empty4731, label %bb_generic_dict_insert_first_vacant1089, label %bb_generic_dict_insert_first_occupied1085

bb_generic_dict_insert_first_occupied1085:
  %generic_dict_insert_first_h24732 = icmp eq i8 %generic_dict_control4730, %dict_h2_byte4725
  br i1 %generic_dict_insert_first_h24732, label %bb_generic_dict_insert_first_compare1086, label %bb_generic_dict_insert_first_fallback1088

bb_generic_dict_insert_first_compare1086:
  %generic_dict_insert_first_key_entries_offset_mirror4733 = add i64 %set_grown_capacity4695, 23
  %generic_dict_insert_first_key_entries_offset4734 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4733, -8
  %generic_dict_insert_first_key_entries4735 = getelementptr i8, ptr %heap4700, i64 %generic_dict_insert_first_key_entries_offset4734
  %generic_dict_insert_first_key_entry_offset4736 = mul i64 %dict_start_slot4727, 4
  %generic_dict_insert_first_key_slot4737 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4735, i64 %generic_dict_insert_first_key_entry_offset4736
  %generic_dict_insert_first_key4738 = load i32, ptr %generic_dict_insert_first_key_slot4737, align 4
  %generic_dict_key_equal4739 = icmp eq i32 %generic_dict_insert_first_key4738, %set_rehash_key4716
  br i1 %generic_dict_key_equal4739, label %bb_generic_dict_insert_first_match1087, label %bb_generic_dict_insert_first_fallback1088

bb_generic_dict_insert_first_match1087:
  br label %bb_generic_dict_insert_first_done1090

bb_generic_dict_insert_first_vacant1089:
  br label %bb_generic_dict_insert_first_done1090

bb_generic_dict_insert_first_fallback1088:
  %hash_key4740 = sext i32 %set_rehash_key4716 to i64
  %hash_high4742 = lshr i64 %hash_key4740, 32
  %hash_fold4741 = xor i64 %hash_key4740, %hash_high4742
  %hash4743 = mul i64 %hash_fold4741, -7046029254386353131
  %dict_h2_shifted4744 = lshr i64 %hash4743, 57
  %dict_h2_raw4745 = and i64 %dict_h2_shifted4744, 127
  %dict_h2_zero4746 = icmp eq i64 %dict_h2_raw4745, 0
  %dict_h24747 = select i1 %dict_h2_zero4746, i64 1, i64 %dict_h2_raw4745
  %dict_h2_byte4748 = trunc i64 %dict_h24747 to i8
  %dict_capacity_mask4749 = sub i64 %set_grown_capacity4695, 1
  %dict_start_slot4750 = and i64 %hash4743, %dict_capacity_mask4749
  br label %bb_generic_dict_group_find1093

bb_generic_dict_group_find1093:
  %generic_dict_group_probe4753 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1088 ], [ %generic_dict_group_next_probe4751, %bb_generic_dict_group_next1101 ]
  %generic_dict_group_deleted4754 = phi i64 [ %set_grown_capacity4695, %bb_generic_dict_insert_first_fallback1088 ], [ %generic_dict_group_next_deleted4752, %bb_generic_dict_group_next1101 ]
  %generic_dict_group_active4755 = icmp ult i64 %generic_dict_group_probe4753, %set_grown_capacity4695
  br i1 %generic_dict_group_active4755, label %bb_generic_dict_group_body1094, label %bb_generic_dict_group_miss1102

bb_generic_dict_group_body1094:
  %generic_dict_group_unwrapped4756 = add i64 %dict_start_slot4750, %generic_dict_group_probe4753
  %generic_dict_group_start4757 = and i64 %generic_dict_group_unwrapped4756, %dict_capacity_mask4749
  %generic_dict_group_pointer4758 = getelementptr i8, ptr %heap4700, i64 %generic_dict_group_start4757
  %generic_dict_group_controls4759 = load <16 x i8>, ptr %generic_dict_group_pointer4758, align 1
  %generic_dict_group_h2_seed4760 = insertelement <16 x i8> poison, i8 %dict_h2_byte4748, i64 0
  %generic_dict_group_h2_vector4761 = shufflevector <16 x i8> %generic_dict_group_h2_seed4760, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4762 = icmp eq <16 x i8> %generic_dict_group_controls4759, %generic_dict_group_h2_vector4761
  %generic_dict_group_match_bits4763 = bitcast <16 x i1> %generic_dict_group_matches_vector4762 to i16
  %generic_dict_group_empty_vector4764 = icmp eq <16 x i8> %generic_dict_group_controls4759, zeroinitializer
  %generic_dict_group_empty_bits4765 = bitcast <16 x i1> %generic_dict_group_empty_vector4764 to i16
  %generic_dict_group_deleted_seed4766 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4767 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4766, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4768 = icmp eq <16 x i8> %generic_dict_group_controls4759, %generic_dict_group_deleted_vector4767
  %generic_dict_group_deleted_bits4769 = bitcast <16 x i1> %generic_dict_group_deleted_matches4768 to i16
  %generic_dict_group_has_deleted4770 = icmp ne i16 %generic_dict_group_deleted_bits4769, 0
  %generic_dict_group_no_previous_deleted4771 = icmp eq i64 %generic_dict_group_deleted4754, %set_grown_capacity4695
  %generic_dict_group_capture_deleted4772 = and i1 %generic_dict_group_has_deleted4770, %generic_dict_group_no_previous_deleted4771
  %generic_dict_group_deleted_offset164773 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4769, i1 false)
  %generic_dict_group_deleted_offset4774 = zext i16 %generic_dict_group_deleted_offset164773 to i64
  %generic_dict_group_deleted_unwrapped4775 = add i64 %generic_dict_group_start4757, %generic_dict_group_deleted_offset4774
  %generic_dict_group_deleted_slot4776 = and i64 %generic_dict_group_deleted_unwrapped4775, %dict_capacity_mask4749
  %generic_dict_group_captured_deleted4777 = select i1 %generic_dict_group_capture_deleted4772, i64 %generic_dict_group_deleted_slot4776, i64 %generic_dict_group_deleted4754
  br label %bb_generic_dict_candidate_loop1095

bb_generic_dict_candidate_loop1095:
  %generic_dict_candidate_bits4778 = phi i16 [ %generic_dict_group_match_bits4763, %bb_generic_dict_group_body1094 ], [ %generic_dict_candidate_cleared_bits4779, %bb_generic_dict_candidate_next1097 ]
  %generic_dict_has_candidate4780 = icmp ne i16 %generic_dict_candidate_bits4778, 0
  br i1 %generic_dict_has_candidate4780, label %bb_generic_dict_candidate_body1096, label %bb_generic_dict_group_decision1098

bb_generic_dict_candidate_body1096:
  %generic_dict_candidate_offset164781 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4778, i1 false)
  %generic_dict_candidate_offset4782 = zext i16 %generic_dict_candidate_offset164781 to i64
  %generic_dict_candidate_unwrapped4783 = add i64 %generic_dict_group_start4757, %generic_dict_candidate_offset4782
  %generic_dict_candidate_slot4784 = and i64 %generic_dict_candidate_unwrapped4783, %dict_capacity_mask4749
  %generic_dict_key_entries_offset_mirror4785 = add i64 %set_grown_capacity4695, 23
  %generic_dict_key_entries_offset4786 = and i64 %generic_dict_key_entries_offset_mirror4785, -8
  %generic_dict_key_entries4787 = getelementptr i8, ptr %heap4700, i64 %generic_dict_key_entries_offset4786
  %generic_dict_key_entry_offset4788 = mul i64 %generic_dict_candidate_slot4784, 4
  %generic_dict_key_slot4789 = getelementptr i8, ptr %generic_dict_key_entries4787, i64 %generic_dict_key_entry_offset4788
  %generic_dict_key4790 = load i32, ptr %generic_dict_key_slot4789, align 4
  %generic_dict_key_equal4791 = icmp eq i32 %generic_dict_key4790, %set_rehash_key4716
  br i1 %generic_dict_key_equal4791, label %bb_generic_dict_group_match1100, label %bb_generic_dict_candidate_next1097

bb_generic_dict_candidate_next1097:
  %generic_dict_candidate_bits_minus_one4792 = sub i16 %generic_dict_candidate_bits4778, 1
  %generic_dict_candidate_cleared_bits4779 = and i16 %generic_dict_candidate_bits4778, %generic_dict_candidate_bits_minus_one4792
  br label %bb_generic_dict_candidate_loop1095

bb_generic_dict_group_decision1098:
  %generic_dict_group_has_empty4793 = icmp ne i16 %generic_dict_group_empty_bits4765, 0
  br i1 %generic_dict_group_has_empty4793, label %bb_generic_dict_group_empty1099, label %bb_generic_dict_group_next1101

bb_generic_dict_group_empty1099:
  %generic_dict_group_empty_offset164794 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4765, i1 false)
  %generic_dict_group_empty_offset4795 = zext i16 %generic_dict_group_empty_offset164794 to i64
  %generic_dict_group_empty_unwrapped4796 = add i64 %generic_dict_group_start4757, %generic_dict_group_empty_offset4795
  %generic_dict_group_empty_slot4797 = and i64 %generic_dict_group_empty_unwrapped4796, %dict_capacity_mask4749
  %generic_dict_group_use_empty4798 = icmp eq i64 %generic_dict_group_captured_deleted4777, %set_grown_capacity4695
  %generic_dict_group_insertion_slot4799 = select i1 %generic_dict_group_use_empty4798, i64 %generic_dict_group_empty_slot4797, i64 %generic_dict_group_captured_deleted4777
  br label %bb_generic_dict_group_done1103

bb_generic_dict_group_match1100:
  br label %bb_generic_dict_group_done1103

bb_generic_dict_group_next1101:
  %generic_dict_group_next_probe4751 = add i64 %generic_dict_group_probe4753, 16
  %generic_dict_group_next_deleted4752 = add i64 %generic_dict_group_captured_deleted4777, 0
  br label %bb_generic_dict_group_find1093

bb_generic_dict_group_miss1102:
  %generic_dict_group_miss_no_deleted4800 = icmp eq i64 %generic_dict_group_deleted4754, %set_grown_capacity4695
  %generic_dict_group_miss_slot4801 = select i1 %generic_dict_group_miss_no_deleted4800, i64 0, i64 %generic_dict_group_deleted4754
  br label %bb_generic_dict_group_done1103

bb_generic_dict_group_done1103:
  %generic_dict_find_found4802 = phi i1 [ false, %bb_generic_dict_group_empty1099 ], [ true, %bb_generic_dict_group_match1100 ], [ false, %bb_generic_dict_group_miss1102 ]
  %generic_dict_find_slot_result4803 = phi i64 [ %generic_dict_group_insertion_slot4799, %bb_generic_dict_group_empty1099 ], [ %generic_dict_candidate_slot4784, %bb_generic_dict_group_match1100 ], [ %generic_dict_group_miss_slot4801, %bb_generic_dict_group_miss1102 ]
  br label %bb_generic_dict_insert_first_done1090

bb_generic_dict_insert_first_done1090:
  %generic_dict_insert_first_found4804 = phi i1 [ true, %bb_generic_dict_insert_first_match1087 ], [ false, %bb_generic_dict_insert_first_vacant1089 ], [ %generic_dict_find_found4802, %bb_generic_dict_group_done1103 ], [ false, %bb_generic_dict_insert_no_capacity1092 ]
  %generic_dict_insert_first_slot_result4805 = phi i64 [ %dict_start_slot4727, %bb_generic_dict_insert_first_match1087 ], [ %dict_start_slot4727, %bb_generic_dict_insert_first_vacant1089 ], [ %generic_dict_find_slot_result4803, %bb_generic_dict_group_done1103 ], [ 0, %bb_generic_dict_insert_no_capacity1092 ]
  %set_key_entries_offset_mirror4806 = add i64 %set_grown_capacity4695, 23
  %set_key_entries_offset4807 = and i64 %set_key_entries_offset_mirror4806, -8
  %set_key_entries4808 = getelementptr i8, ptr %heap4700, i64 %set_key_entries_offset4807
  %set_key_entry_offset4809 = mul i64 %generic_dict_insert_first_slot_result4805, 4
  %set_key_slot4810 = getelementptr i8, ptr %set_key_entries4808, i64 %set_key_entry_offset4809
  store i32 %set_rehash_key4716, ptr %set_key_slot4810, align 4
  %generic_dict_control_slot4811 = getelementptr i8, ptr %heap4700, i64 %generic_dict_insert_first_slot_result4805
  store i8 %dict_h2_byte4725, ptr %generic_dict_control_slot4811, align 1
  %generic_dict_control_mirrored4812 = icmp ult i64 %generic_dict_insert_first_slot_result4805, 16
  br i1 %generic_dict_control_mirrored4812, label %bb_generic_dict_control_mirror1104, label %bb_generic_dict_control_done1105

bb_generic_dict_control_mirror1104:
  %generic_dict_control_mirror_index4813 = add i64 %set_grown_capacity4695, %generic_dict_insert_first_slot_result4805
  %generic_dict_control_mirror_slot4814 = getelementptr i8, ptr %heap4700, i64 %generic_dict_control_mirror_index4813
  store i8 %dict_h2_byte4725, ptr %generic_dict_control_mirror_slot4814, align 1
  br label %bb_generic_dict_control_done1105

bb_generic_dict_control_done1105:
  br label %bb_set_rehash_next1083

bb_set_rehash_next1083:
  %set_rehash_next_index4705 = add i64 %set_rehash_index4706, 1
  br label %bb_set_rehash1080

bb_set_rehash_done1084:
  call void @sollang_free(ptr %mutable_ptr4590)
  %hash_key4815 = sext i32 15 to i64
  %hash_high4817 = lshr i64 %hash_key4815, 32
  %hash_fold4816 = xor i64 %hash_key4815, %hash_high4817
  %hash4818 = mul i64 %hash_fold4816, -7046029254386353131
  %dict_h2_shifted4819 = lshr i64 %hash4818, 57
  %dict_h2_raw4820 = and i64 %dict_h2_shifted4819, 127
  %dict_h2_zero4821 = icmp eq i64 %dict_h2_raw4820, 0
  %dict_h24822 = select i1 %dict_h2_zero4821, i64 1, i64 %dict_h2_raw4820
  %dict_h2_byte4823 = trunc i64 %dict_h24822 to i8
  %dict_capacity_mask4824 = sub i64 %set_grown_capacity4695, 1
  %dict_start_slot4825 = and i64 %hash4818, %dict_capacity_mask4824
  %generic_dict_insert_has_capacity4826 = icmp ugt i64 %set_grown_capacity4695, 0
  br i1 %generic_dict_insert_has_capacity4826, label %bb_generic_dict_insert_first1112, label %bb_generic_dict_insert_no_capacity1113

bb_generic_dict_insert_no_capacity1113:
  br label %bb_generic_dict_insert_first_done1111

bb_generic_dict_insert_first1112:
  %generic_dict_control_slot4827 = getelementptr i8, ptr %heap4700, i64 %dict_start_slot4825
  %generic_dict_control4828 = load i8, ptr %generic_dict_control_slot4827, align 1
  %generic_dict_insert_first_empty4829 = icmp eq i8 %generic_dict_control4828, 0
  br i1 %generic_dict_insert_first_empty4829, label %bb_generic_dict_insert_first_vacant1110, label %bb_generic_dict_insert_first_occupied1106

bb_generic_dict_insert_first_occupied1106:
  %generic_dict_insert_first_h24830 = icmp eq i8 %generic_dict_control4828, %dict_h2_byte4823
  br i1 %generic_dict_insert_first_h24830, label %bb_generic_dict_insert_first_compare1107, label %bb_generic_dict_insert_first_fallback1109

bb_generic_dict_insert_first_compare1107:
  %generic_dict_insert_first_key_entries_offset_mirror4831 = add i64 %set_grown_capacity4695, 23
  %generic_dict_insert_first_key_entries_offset4832 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4831, -8
  %generic_dict_insert_first_key_entries4833 = getelementptr i8, ptr %heap4700, i64 %generic_dict_insert_first_key_entries_offset4832
  %generic_dict_insert_first_key_entry_offset4834 = mul i64 %dict_start_slot4825, 4
  %generic_dict_insert_first_key_slot4835 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4833, i64 %generic_dict_insert_first_key_entry_offset4834
  %generic_dict_insert_first_key4836 = load i32, ptr %generic_dict_insert_first_key_slot4835, align 4
  %generic_dict_key_equal4837 = icmp eq i32 %generic_dict_insert_first_key4836, 15
  br i1 %generic_dict_key_equal4837, label %bb_generic_dict_insert_first_match1108, label %bb_generic_dict_insert_first_fallback1109

bb_generic_dict_insert_first_match1108:
  br label %bb_generic_dict_insert_first_done1111

bb_generic_dict_insert_first_vacant1110:
  br label %bb_generic_dict_insert_first_done1111

bb_generic_dict_insert_first_fallback1109:
  %hash_key4838 = sext i32 15 to i64
  %hash_high4840 = lshr i64 %hash_key4838, 32
  %hash_fold4839 = xor i64 %hash_key4838, %hash_high4840
  %hash4841 = mul i64 %hash_fold4839, -7046029254386353131
  %dict_h2_shifted4842 = lshr i64 %hash4841, 57
  %dict_h2_raw4843 = and i64 %dict_h2_shifted4842, 127
  %dict_h2_zero4844 = icmp eq i64 %dict_h2_raw4843, 0
  %dict_h24845 = select i1 %dict_h2_zero4844, i64 1, i64 %dict_h2_raw4843
  %dict_h2_byte4846 = trunc i64 %dict_h24845 to i8
  %dict_capacity_mask4847 = sub i64 %set_grown_capacity4695, 1
  %dict_start_slot4848 = and i64 %hash4841, %dict_capacity_mask4847
  br label %bb_generic_dict_group_find1114

bb_generic_dict_group_find1114:
  %generic_dict_group_probe4851 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1109 ], [ %generic_dict_group_next_probe4849, %bb_generic_dict_group_next1122 ]
  %generic_dict_group_deleted4852 = phi i64 [ %set_grown_capacity4695, %bb_generic_dict_insert_first_fallback1109 ], [ %generic_dict_group_next_deleted4850, %bb_generic_dict_group_next1122 ]
  %generic_dict_group_active4853 = icmp ult i64 %generic_dict_group_probe4851, %set_grown_capacity4695
  br i1 %generic_dict_group_active4853, label %bb_generic_dict_group_body1115, label %bb_generic_dict_group_miss1123

bb_generic_dict_group_body1115:
  %generic_dict_group_unwrapped4854 = add i64 %dict_start_slot4848, %generic_dict_group_probe4851
  %generic_dict_group_start4855 = and i64 %generic_dict_group_unwrapped4854, %dict_capacity_mask4847
  %generic_dict_group_pointer4856 = getelementptr i8, ptr %heap4700, i64 %generic_dict_group_start4855
  %generic_dict_group_controls4857 = load <16 x i8>, ptr %generic_dict_group_pointer4856, align 1
  %generic_dict_group_h2_seed4858 = insertelement <16 x i8> poison, i8 %dict_h2_byte4846, i64 0
  %generic_dict_group_h2_vector4859 = shufflevector <16 x i8> %generic_dict_group_h2_seed4858, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4860 = icmp eq <16 x i8> %generic_dict_group_controls4857, %generic_dict_group_h2_vector4859
  %generic_dict_group_match_bits4861 = bitcast <16 x i1> %generic_dict_group_matches_vector4860 to i16
  %generic_dict_group_empty_vector4862 = icmp eq <16 x i8> %generic_dict_group_controls4857, zeroinitializer
  %generic_dict_group_empty_bits4863 = bitcast <16 x i1> %generic_dict_group_empty_vector4862 to i16
  %generic_dict_group_deleted_seed4864 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4865 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4864, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4866 = icmp eq <16 x i8> %generic_dict_group_controls4857, %generic_dict_group_deleted_vector4865
  %generic_dict_group_deleted_bits4867 = bitcast <16 x i1> %generic_dict_group_deleted_matches4866 to i16
  %generic_dict_group_has_deleted4868 = icmp ne i16 %generic_dict_group_deleted_bits4867, 0
  %generic_dict_group_no_previous_deleted4869 = icmp eq i64 %generic_dict_group_deleted4852, %set_grown_capacity4695
  %generic_dict_group_capture_deleted4870 = and i1 %generic_dict_group_has_deleted4868, %generic_dict_group_no_previous_deleted4869
  %generic_dict_group_deleted_offset164871 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4867, i1 false)
  %generic_dict_group_deleted_offset4872 = zext i16 %generic_dict_group_deleted_offset164871 to i64
  %generic_dict_group_deleted_unwrapped4873 = add i64 %generic_dict_group_start4855, %generic_dict_group_deleted_offset4872
  %generic_dict_group_deleted_slot4874 = and i64 %generic_dict_group_deleted_unwrapped4873, %dict_capacity_mask4847
  %generic_dict_group_captured_deleted4875 = select i1 %generic_dict_group_capture_deleted4870, i64 %generic_dict_group_deleted_slot4874, i64 %generic_dict_group_deleted4852
  br label %bb_generic_dict_candidate_loop1116

bb_generic_dict_candidate_loop1116:
  %generic_dict_candidate_bits4876 = phi i16 [ %generic_dict_group_match_bits4861, %bb_generic_dict_group_body1115 ], [ %generic_dict_candidate_cleared_bits4877, %bb_generic_dict_candidate_next1118 ]
  %generic_dict_has_candidate4878 = icmp ne i16 %generic_dict_candidate_bits4876, 0
  br i1 %generic_dict_has_candidate4878, label %bb_generic_dict_candidate_body1117, label %bb_generic_dict_group_decision1119

bb_generic_dict_candidate_body1117:
  %generic_dict_candidate_offset164879 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4876, i1 false)
  %generic_dict_candidate_offset4880 = zext i16 %generic_dict_candidate_offset164879 to i64
  %generic_dict_candidate_unwrapped4881 = add i64 %generic_dict_group_start4855, %generic_dict_candidate_offset4880
  %generic_dict_candidate_slot4882 = and i64 %generic_dict_candidate_unwrapped4881, %dict_capacity_mask4847
  %generic_dict_key_entries_offset_mirror4883 = add i64 %set_grown_capacity4695, 23
  %generic_dict_key_entries_offset4884 = and i64 %generic_dict_key_entries_offset_mirror4883, -8
  %generic_dict_key_entries4885 = getelementptr i8, ptr %heap4700, i64 %generic_dict_key_entries_offset4884
  %generic_dict_key_entry_offset4886 = mul i64 %generic_dict_candidate_slot4882, 4
  %generic_dict_key_slot4887 = getelementptr i8, ptr %generic_dict_key_entries4885, i64 %generic_dict_key_entry_offset4886
  %generic_dict_key4888 = load i32, ptr %generic_dict_key_slot4887, align 4
  %generic_dict_key_equal4889 = icmp eq i32 %generic_dict_key4888, 15
  br i1 %generic_dict_key_equal4889, label %bb_generic_dict_group_match1121, label %bb_generic_dict_candidate_next1118

bb_generic_dict_candidate_next1118:
  %generic_dict_candidate_bits_minus_one4890 = sub i16 %generic_dict_candidate_bits4876, 1
  %generic_dict_candidate_cleared_bits4877 = and i16 %generic_dict_candidate_bits4876, %generic_dict_candidate_bits_minus_one4890
  br label %bb_generic_dict_candidate_loop1116

bb_generic_dict_group_decision1119:
  %generic_dict_group_has_empty4891 = icmp ne i16 %generic_dict_group_empty_bits4863, 0
  br i1 %generic_dict_group_has_empty4891, label %bb_generic_dict_group_empty1120, label %bb_generic_dict_group_next1122

bb_generic_dict_group_empty1120:
  %generic_dict_group_empty_offset164892 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4863, i1 false)
  %generic_dict_group_empty_offset4893 = zext i16 %generic_dict_group_empty_offset164892 to i64
  %generic_dict_group_empty_unwrapped4894 = add i64 %generic_dict_group_start4855, %generic_dict_group_empty_offset4893
  %generic_dict_group_empty_slot4895 = and i64 %generic_dict_group_empty_unwrapped4894, %dict_capacity_mask4847
  %generic_dict_group_use_empty4896 = icmp eq i64 %generic_dict_group_captured_deleted4875, %set_grown_capacity4695
  %generic_dict_group_insertion_slot4897 = select i1 %generic_dict_group_use_empty4896, i64 %generic_dict_group_empty_slot4895, i64 %generic_dict_group_captured_deleted4875
  br label %bb_generic_dict_group_done1124

bb_generic_dict_group_match1121:
  br label %bb_generic_dict_group_done1124

bb_generic_dict_group_next1122:
  %generic_dict_group_next_probe4849 = add i64 %generic_dict_group_probe4851, 16
  %generic_dict_group_next_deleted4850 = add i64 %generic_dict_group_captured_deleted4875, 0
  br label %bb_generic_dict_group_find1114

bb_generic_dict_group_miss1123:
  %generic_dict_group_miss_no_deleted4898 = icmp eq i64 %generic_dict_group_deleted4852, %set_grown_capacity4695
  %generic_dict_group_miss_slot4899 = select i1 %generic_dict_group_miss_no_deleted4898, i64 0, i64 %generic_dict_group_deleted4852
  br label %bb_generic_dict_group_done1124

bb_generic_dict_group_done1124:
  %generic_dict_find_found4900 = phi i1 [ false, %bb_generic_dict_group_empty1120 ], [ true, %bb_generic_dict_group_match1121 ], [ false, %bb_generic_dict_group_miss1123 ]
  %generic_dict_find_slot_result4901 = phi i64 [ %generic_dict_group_insertion_slot4897, %bb_generic_dict_group_empty1120 ], [ %generic_dict_candidate_slot4882, %bb_generic_dict_group_match1121 ], [ %generic_dict_group_miss_slot4899, %bb_generic_dict_group_miss1123 ]
  br label %bb_generic_dict_insert_first_done1111

bb_generic_dict_insert_first_done1111:
  %generic_dict_insert_first_found4902 = phi i1 [ true, %bb_generic_dict_insert_first_match1108 ], [ false, %bb_generic_dict_insert_first_vacant1110 ], [ %generic_dict_find_found4900, %bb_generic_dict_group_done1124 ], [ false, %bb_generic_dict_insert_no_capacity1113 ]
  %generic_dict_insert_first_slot_result4903 = phi i64 [ %dict_start_slot4825, %bb_generic_dict_insert_first_match1108 ], [ %dict_start_slot4825, %bb_generic_dict_insert_first_vacant1110 ], [ %generic_dict_find_slot_result4901, %bb_generic_dict_group_done1124 ], [ 0, %bb_generic_dict_insert_no_capacity1113 ]
  %set_key_entries_offset_mirror4904 = add i64 %set_grown_capacity4695, 23
  %set_key_entries_offset4905 = and i64 %set_key_entries_offset_mirror4904, -8
  %set_key_entries4906 = getelementptr i8, ptr %heap4700, i64 %set_key_entries_offset4905
  %set_key_entry_offset4907 = mul i64 %generic_dict_insert_first_slot_result4903, 4
  %set_key_slot4908 = getelementptr i8, ptr %set_key_entries4906, i64 %set_key_entry_offset4907
  store i32 15, ptr %set_key_slot4908, align 4
  %generic_dict_control_slot4909 = getelementptr i8, ptr %heap4700, i64 %generic_dict_insert_first_slot_result4903
  store i8 %dict_h2_byte4823, ptr %generic_dict_control_slot4909, align 1
  %generic_dict_control_mirrored4910 = icmp ult i64 %generic_dict_insert_first_slot_result4903, 16
  br i1 %generic_dict_control_mirrored4910, label %bb_generic_dict_control_mirror1125, label %bb_generic_dict_control_done1126

bb_generic_dict_control_mirror1125:
  %generic_dict_control_mirror_index4911 = add i64 %set_grown_capacity4695, %generic_dict_insert_first_slot_result4903
  %generic_dict_control_mirror_slot4912 = getelementptr i8, ptr %heap4700, i64 %generic_dict_control_mirror_index4911
  store i8 %dict_h2_byte4823, ptr %generic_dict_control_mirror_slot4912, align 1
  br label %bb_generic_dict_control_done1126

bb_generic_dict_control_done1126:
  br label %bb_set_insert_done1075

bb_set_insert_done1075:
  %set_pointer4913 = phi ptr [ %mutable_ptr4590, %bb_set_insert_duplicate1071 ], [ %mutable_ptr4590, %bb_generic_dict_control_done1077 ], [ %heap4700, %bb_generic_dict_control_done1126 ]
  %set_length4914 = phi i64 [ %mutable_len4591, %bb_set_insert_duplicate1071 ], [ %set_insert_length4682, %bb_generic_dict_control_done1077 ], [ %set_insert_length4682, %bb_generic_dict_control_done1126 ]
  %set_capacity4915 = phi i64 [ %mutable_capacity4592, %bb_set_insert_duplicate1071 ], [ %mutable_capacity4592, %bb_generic_dict_control_done1077 ], [ %set_grown_capacity4695, %bb_generic_dict_control_done1126 ]
  %set_inserted4916 = phi i1 [ false, %bb_set_insert_duplicate1071 ], [ true, %bb_generic_dict_control_done1077 ], [ true, %bb_generic_dict_control_done1126 ]
  store ptr %set_pointer4913, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length4914, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity4915, ptr %mutable_capacity_addr11, align 8
  %mutable_ptr4917 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len4918 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity4919 = load i64, ptr %mutable_capacity_addr11, align 8
  %hash_key4920 = sext i32 16 to i64
  %hash_high4922 = lshr i64 %hash_key4920, 32
  %hash_fold4921 = xor i64 %hash_key4920, %hash_high4922
  %hash4923 = mul i64 %hash_fold4921, -7046029254386353131
  %dict_h2_shifted4924 = lshr i64 %hash4923, 57
  %dict_h2_raw4925 = and i64 %dict_h2_shifted4924, 127
  %dict_h2_zero4926 = icmp eq i64 %dict_h2_raw4925, 0
  %dict_h24927 = select i1 %dict_h2_zero4926, i64 1, i64 %dict_h2_raw4925
  %dict_h2_byte4928 = trunc i64 %dict_h24927 to i8
  %dict_capacity_mask4929 = sub i64 %mutable_capacity4919, 1
  %dict_start_slot4930 = and i64 %hash4923, %dict_capacity_mask4929
  %generic_dict_insert_has_capacity4931 = icmp ugt i64 %mutable_capacity4919, 0
  br i1 %generic_dict_insert_has_capacity4931, label %bb_generic_dict_insert_first1133, label %bb_generic_dict_insert_no_capacity1134

bb_generic_dict_insert_no_capacity1134:
  br label %bb_generic_dict_insert_first_done1132

bb_generic_dict_insert_first1133:
  %generic_dict_control_slot4932 = getelementptr i8, ptr %mutable_ptr4917, i64 %dict_start_slot4930
  %generic_dict_control4933 = load i8, ptr %generic_dict_control_slot4932, align 1
  %generic_dict_insert_first_empty4934 = icmp eq i8 %generic_dict_control4933, 0
  br i1 %generic_dict_insert_first_empty4934, label %bb_generic_dict_insert_first_vacant1131, label %bb_generic_dict_insert_first_occupied1127

bb_generic_dict_insert_first_occupied1127:
  %generic_dict_insert_first_h24935 = icmp eq i8 %generic_dict_control4933, %dict_h2_byte4928
  br i1 %generic_dict_insert_first_h24935, label %bb_generic_dict_insert_first_compare1128, label %bb_generic_dict_insert_first_fallback1130

bb_generic_dict_insert_first_compare1128:
  %generic_dict_insert_first_key_entries_offset_mirror4936 = add i64 %mutable_capacity4919, 23
  %generic_dict_insert_first_key_entries_offset4937 = and i64 %generic_dict_insert_first_key_entries_offset_mirror4936, -8
  %generic_dict_insert_first_key_entries4938 = getelementptr i8, ptr %mutable_ptr4917, i64 %generic_dict_insert_first_key_entries_offset4937
  %generic_dict_insert_first_key_entry_offset4939 = mul i64 %dict_start_slot4930, 4
  %generic_dict_insert_first_key_slot4940 = getelementptr i8, ptr %generic_dict_insert_first_key_entries4938, i64 %generic_dict_insert_first_key_entry_offset4939
  %generic_dict_insert_first_key4941 = load i32, ptr %generic_dict_insert_first_key_slot4940, align 4
  %generic_dict_key_equal4942 = icmp eq i32 %generic_dict_insert_first_key4941, 16
  br i1 %generic_dict_key_equal4942, label %bb_generic_dict_insert_first_match1129, label %bb_generic_dict_insert_first_fallback1130

bb_generic_dict_insert_first_match1129:
  br label %bb_generic_dict_insert_first_done1132

bb_generic_dict_insert_first_vacant1131:
  br label %bb_generic_dict_insert_first_done1132

bb_generic_dict_insert_first_fallback1130:
  %hash_key4943 = sext i32 16 to i64
  %hash_high4945 = lshr i64 %hash_key4943, 32
  %hash_fold4944 = xor i64 %hash_key4943, %hash_high4945
  %hash4946 = mul i64 %hash_fold4944, -7046029254386353131
  %dict_h2_shifted4947 = lshr i64 %hash4946, 57
  %dict_h2_raw4948 = and i64 %dict_h2_shifted4947, 127
  %dict_h2_zero4949 = icmp eq i64 %dict_h2_raw4948, 0
  %dict_h24950 = select i1 %dict_h2_zero4949, i64 1, i64 %dict_h2_raw4948
  %dict_h2_byte4951 = trunc i64 %dict_h24950 to i8
  %dict_capacity_mask4952 = sub i64 %mutable_capacity4919, 1
  %dict_start_slot4953 = and i64 %hash4946, %dict_capacity_mask4952
  br label %bb_generic_dict_group_find1135

bb_generic_dict_group_find1135:
  %generic_dict_group_probe4956 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1130 ], [ %generic_dict_group_next_probe4954, %bb_generic_dict_group_next1143 ]
  %generic_dict_group_deleted4957 = phi i64 [ %mutable_capacity4919, %bb_generic_dict_insert_first_fallback1130 ], [ %generic_dict_group_next_deleted4955, %bb_generic_dict_group_next1143 ]
  %generic_dict_group_active4958 = icmp ult i64 %generic_dict_group_probe4956, %mutable_capacity4919
  br i1 %generic_dict_group_active4958, label %bb_generic_dict_group_body1136, label %bb_generic_dict_group_miss1144

bb_generic_dict_group_body1136:
  %generic_dict_group_unwrapped4959 = add i64 %dict_start_slot4953, %generic_dict_group_probe4956
  %generic_dict_group_start4960 = and i64 %generic_dict_group_unwrapped4959, %dict_capacity_mask4952
  %generic_dict_group_pointer4961 = getelementptr i8, ptr %mutable_ptr4917, i64 %generic_dict_group_start4960
  %generic_dict_group_controls4962 = load <16 x i8>, ptr %generic_dict_group_pointer4961, align 1
  %generic_dict_group_h2_seed4963 = insertelement <16 x i8> poison, i8 %dict_h2_byte4951, i64 0
  %generic_dict_group_h2_vector4964 = shufflevector <16 x i8> %generic_dict_group_h2_seed4963, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector4965 = icmp eq <16 x i8> %generic_dict_group_controls4962, %generic_dict_group_h2_vector4964
  %generic_dict_group_match_bits4966 = bitcast <16 x i1> %generic_dict_group_matches_vector4965 to i16
  %generic_dict_group_empty_vector4967 = icmp eq <16 x i8> %generic_dict_group_controls4962, zeroinitializer
  %generic_dict_group_empty_bits4968 = bitcast <16 x i1> %generic_dict_group_empty_vector4967 to i16
  %generic_dict_group_deleted_seed4969 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector4970 = shufflevector <16 x i8> %generic_dict_group_deleted_seed4969, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches4971 = icmp eq <16 x i8> %generic_dict_group_controls4962, %generic_dict_group_deleted_vector4970
  %generic_dict_group_deleted_bits4972 = bitcast <16 x i1> %generic_dict_group_deleted_matches4971 to i16
  %generic_dict_group_has_deleted4973 = icmp ne i16 %generic_dict_group_deleted_bits4972, 0
  %generic_dict_group_no_previous_deleted4974 = icmp eq i64 %generic_dict_group_deleted4957, %mutable_capacity4919
  %generic_dict_group_capture_deleted4975 = and i1 %generic_dict_group_has_deleted4973, %generic_dict_group_no_previous_deleted4974
  %generic_dict_group_deleted_offset164976 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits4972, i1 false)
  %generic_dict_group_deleted_offset4977 = zext i16 %generic_dict_group_deleted_offset164976 to i64
  %generic_dict_group_deleted_unwrapped4978 = add i64 %generic_dict_group_start4960, %generic_dict_group_deleted_offset4977
  %generic_dict_group_deleted_slot4979 = and i64 %generic_dict_group_deleted_unwrapped4978, %dict_capacity_mask4952
  %generic_dict_group_captured_deleted4980 = select i1 %generic_dict_group_capture_deleted4975, i64 %generic_dict_group_deleted_slot4979, i64 %generic_dict_group_deleted4957
  br label %bb_generic_dict_candidate_loop1137

bb_generic_dict_candidate_loop1137:
  %generic_dict_candidate_bits4981 = phi i16 [ %generic_dict_group_match_bits4966, %bb_generic_dict_group_body1136 ], [ %generic_dict_candidate_cleared_bits4982, %bb_generic_dict_candidate_next1139 ]
  %generic_dict_has_candidate4983 = icmp ne i16 %generic_dict_candidate_bits4981, 0
  br i1 %generic_dict_has_candidate4983, label %bb_generic_dict_candidate_body1138, label %bb_generic_dict_group_decision1140

bb_generic_dict_candidate_body1138:
  %generic_dict_candidate_offset164984 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits4981, i1 false)
  %generic_dict_candidate_offset4985 = zext i16 %generic_dict_candidate_offset164984 to i64
  %generic_dict_candidate_unwrapped4986 = add i64 %generic_dict_group_start4960, %generic_dict_candidate_offset4985
  %generic_dict_candidate_slot4987 = and i64 %generic_dict_candidate_unwrapped4986, %dict_capacity_mask4952
  %generic_dict_key_entries_offset_mirror4988 = add i64 %mutable_capacity4919, 23
  %generic_dict_key_entries_offset4989 = and i64 %generic_dict_key_entries_offset_mirror4988, -8
  %generic_dict_key_entries4990 = getelementptr i8, ptr %mutable_ptr4917, i64 %generic_dict_key_entries_offset4989
  %generic_dict_key_entry_offset4991 = mul i64 %generic_dict_candidate_slot4987, 4
  %generic_dict_key_slot4992 = getelementptr i8, ptr %generic_dict_key_entries4990, i64 %generic_dict_key_entry_offset4991
  %generic_dict_key4993 = load i32, ptr %generic_dict_key_slot4992, align 4
  %generic_dict_key_equal4994 = icmp eq i32 %generic_dict_key4993, 16
  br i1 %generic_dict_key_equal4994, label %bb_generic_dict_group_match1142, label %bb_generic_dict_candidate_next1139

bb_generic_dict_candidate_next1139:
  %generic_dict_candidate_bits_minus_one4995 = sub i16 %generic_dict_candidate_bits4981, 1
  %generic_dict_candidate_cleared_bits4982 = and i16 %generic_dict_candidate_bits4981, %generic_dict_candidate_bits_minus_one4995
  br label %bb_generic_dict_candidate_loop1137

bb_generic_dict_group_decision1140:
  %generic_dict_group_has_empty4996 = icmp ne i16 %generic_dict_group_empty_bits4968, 0
  br i1 %generic_dict_group_has_empty4996, label %bb_generic_dict_group_empty1141, label %bb_generic_dict_group_next1143

bb_generic_dict_group_empty1141:
  %generic_dict_group_empty_offset164997 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits4968, i1 false)
  %generic_dict_group_empty_offset4998 = zext i16 %generic_dict_group_empty_offset164997 to i64
  %generic_dict_group_empty_unwrapped4999 = add i64 %generic_dict_group_start4960, %generic_dict_group_empty_offset4998
  %generic_dict_group_empty_slot5000 = and i64 %generic_dict_group_empty_unwrapped4999, %dict_capacity_mask4952
  %generic_dict_group_use_empty5001 = icmp eq i64 %generic_dict_group_captured_deleted4980, %mutable_capacity4919
  %generic_dict_group_insertion_slot5002 = select i1 %generic_dict_group_use_empty5001, i64 %generic_dict_group_empty_slot5000, i64 %generic_dict_group_captured_deleted4980
  br label %bb_generic_dict_group_done1145

bb_generic_dict_group_match1142:
  br label %bb_generic_dict_group_done1145

bb_generic_dict_group_next1143:
  %generic_dict_group_next_probe4954 = add i64 %generic_dict_group_probe4956, 16
  %generic_dict_group_next_deleted4955 = add i64 %generic_dict_group_captured_deleted4980, 0
  br label %bb_generic_dict_group_find1135

bb_generic_dict_group_miss1144:
  %generic_dict_group_miss_no_deleted5003 = icmp eq i64 %generic_dict_group_deleted4957, %mutable_capacity4919
  %generic_dict_group_miss_slot5004 = select i1 %generic_dict_group_miss_no_deleted5003, i64 0, i64 %generic_dict_group_deleted4957
  br label %bb_generic_dict_group_done1145

bb_generic_dict_group_done1145:
  %generic_dict_find_found5005 = phi i1 [ false, %bb_generic_dict_group_empty1141 ], [ true, %bb_generic_dict_group_match1142 ], [ false, %bb_generic_dict_group_miss1144 ]
  %generic_dict_find_slot_result5006 = phi i64 [ %generic_dict_group_insertion_slot5002, %bb_generic_dict_group_empty1141 ], [ %generic_dict_candidate_slot4987, %bb_generic_dict_group_match1142 ], [ %generic_dict_group_miss_slot5004, %bb_generic_dict_group_miss1144 ]
  br label %bb_generic_dict_insert_first_done1132

bb_generic_dict_insert_first_done1132:
  %generic_dict_insert_first_found5007 = phi i1 [ true, %bb_generic_dict_insert_first_match1129 ], [ false, %bb_generic_dict_insert_first_vacant1131 ], [ %generic_dict_find_found5005, %bb_generic_dict_group_done1145 ], [ false, %bb_generic_dict_insert_no_capacity1134 ]
  %generic_dict_insert_first_slot_result5008 = phi i64 [ %dict_start_slot4930, %bb_generic_dict_insert_first_match1129 ], [ %dict_start_slot4930, %bb_generic_dict_insert_first_vacant1131 ], [ %generic_dict_find_slot_result5006, %bb_generic_dict_group_done1145 ], [ 0, %bb_generic_dict_insert_no_capacity1134 ]
  br i1 %generic_dict_insert_first_found5007, label %bb_set_insert_duplicate1146, label %bb_set_insert_new1147

bb_set_insert_duplicate1146:
  br label %bb_set_insert_done1150

bb_set_insert_new1147:
  %set_insert_length5009 = add i64 %mutable_len4918, 1
  %set_insert_load_num5010 = mul i64 %set_insert_length5009, 8
  %set_insert_load_den5011 = mul i64 %mutable_capacity4919, 7
  %set_insert_should_grow5012 = icmp ugt i64 %set_insert_load_num5010, %set_insert_load_den5011
  br i1 %set_insert_should_grow5012, label %bb_set_insert_grow1149, label %bb_set_insert_current1148

bb_set_insert_current1148:
  %set_key_entries_offset_mirror5013 = add i64 %mutable_capacity4919, 23
  %set_key_entries_offset5014 = and i64 %set_key_entries_offset_mirror5013, -8
  %set_key_entries5015 = getelementptr i8, ptr %mutable_ptr4917, i64 %set_key_entries_offset5014
  %set_key_entry_offset5016 = mul i64 %generic_dict_insert_first_slot_result5008, 4
  %set_key_slot5017 = getelementptr i8, ptr %set_key_entries5015, i64 %set_key_entry_offset5016
  store i32 16, ptr %set_key_slot5017, align 4
  %generic_dict_control_slot5018 = getelementptr i8, ptr %mutable_ptr4917, i64 %generic_dict_insert_first_slot_result5008
  store i8 %dict_h2_byte4928, ptr %generic_dict_control_slot5018, align 1
  %generic_dict_control_mirrored5019 = icmp ult i64 %generic_dict_insert_first_slot_result5008, 16
  br i1 %generic_dict_control_mirrored5019, label %bb_generic_dict_control_mirror1151, label %bb_generic_dict_control_done1152

bb_generic_dict_control_mirror1151:
  %generic_dict_control_mirror_index5020 = add i64 %mutable_capacity4919, %generic_dict_insert_first_slot_result5008
  %generic_dict_control_mirror_slot5021 = getelementptr i8, ptr %mutable_ptr4917, i64 %generic_dict_control_mirror_index5020
  store i8 %dict_h2_byte4928, ptr %generic_dict_control_mirror_slot5021, align 1
  br label %bb_generic_dict_control_done1152

bb_generic_dict_control_done1152:
  br label %bb_set_insert_done1150

bb_set_insert_grow1149:
  %set_grown_capacity5022 = mul i64 %mutable_capacity4919, 2
  %generic_dict_entries_offset_mirror5023 = add i64 %set_grown_capacity5022, 23
  %generic_dict_entries_offset5024 = and i64 %generic_dict_entries_offset_mirror5023, -8
  %generic_dict_entries_bytes5025 = mul i64 %set_grown_capacity5022, 4
  %generic_dict_bytes5026 = add i64 %generic_dict_entries_offset5024, %generic_dict_entries_bytes5025
  %heap5027 = call ptr @sollang_alloc(i64 %generic_dict_bytes5026)
  %heap_ok5028 = icmp ne ptr %heap5027, null
  br i1 %heap_ok5028, label %bb_alloc_ok1153, label %bb_alloc_fail1154

bb_alloc_fail1154:
  %trap_stderr5029 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr5029, ptr @.slg.str.module.x.16, i32 26, ptr %trap_written5030, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok1153:
  %generic_dict_control_bytes5031 = add i64 %set_grown_capacity5022, 16
  call void @llvm.memset.p0.i64(ptr %heap5027, i8 0, i64 %generic_dict_control_bytes5031, i1 false)
  br label %bb_set_rehash1155

bb_set_rehash1155:
  %set_rehash_index5033 = phi i64 [ 0, %bb_alloc_ok1153 ], [ %set_rehash_next_index5032, %bb_set_rehash_next1158 ]
  %set_rehash_active5034 = icmp ult i64 %set_rehash_index5033, %mutable_capacity4919
  br i1 %set_rehash_active5034, label %bb_set_rehash_body1156, label %bb_set_rehash_done1159

bb_set_rehash_body1156:
  %generic_dict_control_slot5035 = getelementptr i8, ptr %mutable_ptr4917, i64 %set_rehash_index5033
  %generic_dict_control5036 = load i8, ptr %generic_dict_control_slot5035, align 1
  %set_rehash_occupied5037 = icmp sgt i8 %generic_dict_control5036, 0
  br i1 %set_rehash_occupied5037, label %bb_set_rehash_move1157, label %bb_set_rehash_next1158

bb_set_rehash_move1157:
  %set_rehash_key_entries_offset_mirror5038 = add i64 %mutable_capacity4919, 23
  %set_rehash_key_entries_offset5039 = and i64 %set_rehash_key_entries_offset_mirror5038, -8
  %set_rehash_key_entries5040 = getelementptr i8, ptr %mutable_ptr4917, i64 %set_rehash_key_entries_offset5039
  %set_rehash_key_entry_offset5041 = mul i64 %set_rehash_index5033, 4
  %set_rehash_key_slot5042 = getelementptr i8, ptr %set_rehash_key_entries5040, i64 %set_rehash_key_entry_offset5041
  %set_rehash_key5043 = load i32, ptr %set_rehash_key_slot5042, align 4
  %hash_key5044 = sext i32 %set_rehash_key5043 to i64
  %hash_high5046 = lshr i64 %hash_key5044, 32
  %hash_fold5045 = xor i64 %hash_key5044, %hash_high5046
  %hash5047 = mul i64 %hash_fold5045, -7046029254386353131
  %dict_h2_shifted5048 = lshr i64 %hash5047, 57
  %dict_h2_raw5049 = and i64 %dict_h2_shifted5048, 127
  %dict_h2_zero5050 = icmp eq i64 %dict_h2_raw5049, 0
  %dict_h25051 = select i1 %dict_h2_zero5050, i64 1, i64 %dict_h2_raw5049
  %dict_h2_byte5052 = trunc i64 %dict_h25051 to i8
  %dict_capacity_mask5053 = sub i64 %set_grown_capacity5022, 1
  %dict_start_slot5054 = and i64 %hash5047, %dict_capacity_mask5053
  %generic_dict_insert_has_capacity5055 = icmp ugt i64 %set_grown_capacity5022, 0
  br i1 %generic_dict_insert_has_capacity5055, label %bb_generic_dict_insert_first1166, label %bb_generic_dict_insert_no_capacity1167

bb_generic_dict_insert_no_capacity1167:
  br label %bb_generic_dict_insert_first_done1165

bb_generic_dict_insert_first1166:
  %generic_dict_control_slot5056 = getelementptr i8, ptr %heap5027, i64 %dict_start_slot5054
  %generic_dict_control5057 = load i8, ptr %generic_dict_control_slot5056, align 1
  %generic_dict_insert_first_empty5058 = icmp eq i8 %generic_dict_control5057, 0
  br i1 %generic_dict_insert_first_empty5058, label %bb_generic_dict_insert_first_vacant1164, label %bb_generic_dict_insert_first_occupied1160

bb_generic_dict_insert_first_occupied1160:
  %generic_dict_insert_first_h25059 = icmp eq i8 %generic_dict_control5057, %dict_h2_byte5052
  br i1 %generic_dict_insert_first_h25059, label %bb_generic_dict_insert_first_compare1161, label %bb_generic_dict_insert_first_fallback1163

bb_generic_dict_insert_first_compare1161:
  %generic_dict_insert_first_key_entries_offset_mirror5060 = add i64 %set_grown_capacity5022, 23
  %generic_dict_insert_first_key_entries_offset5061 = and i64 %generic_dict_insert_first_key_entries_offset_mirror5060, -8
  %generic_dict_insert_first_key_entries5062 = getelementptr i8, ptr %heap5027, i64 %generic_dict_insert_first_key_entries_offset5061
  %generic_dict_insert_first_key_entry_offset5063 = mul i64 %dict_start_slot5054, 4
  %generic_dict_insert_first_key_slot5064 = getelementptr i8, ptr %generic_dict_insert_first_key_entries5062, i64 %generic_dict_insert_first_key_entry_offset5063
  %generic_dict_insert_first_key5065 = load i32, ptr %generic_dict_insert_first_key_slot5064, align 4
  %generic_dict_key_equal5066 = icmp eq i32 %generic_dict_insert_first_key5065, %set_rehash_key5043
  br i1 %generic_dict_key_equal5066, label %bb_generic_dict_insert_first_match1162, label %bb_generic_dict_insert_first_fallback1163

bb_generic_dict_insert_first_match1162:
  br label %bb_generic_dict_insert_first_done1165

bb_generic_dict_insert_first_vacant1164:
  br label %bb_generic_dict_insert_first_done1165

bb_generic_dict_insert_first_fallback1163:
  %hash_key5067 = sext i32 %set_rehash_key5043 to i64
  %hash_high5069 = lshr i64 %hash_key5067, 32
  %hash_fold5068 = xor i64 %hash_key5067, %hash_high5069
  %hash5070 = mul i64 %hash_fold5068, -7046029254386353131
  %dict_h2_shifted5071 = lshr i64 %hash5070, 57
  %dict_h2_raw5072 = and i64 %dict_h2_shifted5071, 127
  %dict_h2_zero5073 = icmp eq i64 %dict_h2_raw5072, 0
  %dict_h25074 = select i1 %dict_h2_zero5073, i64 1, i64 %dict_h2_raw5072
  %dict_h2_byte5075 = trunc i64 %dict_h25074 to i8
  %dict_capacity_mask5076 = sub i64 %set_grown_capacity5022, 1
  %dict_start_slot5077 = and i64 %hash5070, %dict_capacity_mask5076
  br label %bb_generic_dict_group_find1168

bb_generic_dict_group_find1168:
  %generic_dict_group_probe5080 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1163 ], [ %generic_dict_group_next_probe5078, %bb_generic_dict_group_next1176 ]
  %generic_dict_group_deleted5081 = phi i64 [ %set_grown_capacity5022, %bb_generic_dict_insert_first_fallback1163 ], [ %generic_dict_group_next_deleted5079, %bb_generic_dict_group_next1176 ]
  %generic_dict_group_active5082 = icmp ult i64 %generic_dict_group_probe5080, %set_grown_capacity5022
  br i1 %generic_dict_group_active5082, label %bb_generic_dict_group_body1169, label %bb_generic_dict_group_miss1177

bb_generic_dict_group_body1169:
  %generic_dict_group_unwrapped5083 = add i64 %dict_start_slot5077, %generic_dict_group_probe5080
  %generic_dict_group_start5084 = and i64 %generic_dict_group_unwrapped5083, %dict_capacity_mask5076
  %generic_dict_group_pointer5085 = getelementptr i8, ptr %heap5027, i64 %generic_dict_group_start5084
  %generic_dict_group_controls5086 = load <16 x i8>, ptr %generic_dict_group_pointer5085, align 1
  %generic_dict_group_h2_seed5087 = insertelement <16 x i8> poison, i8 %dict_h2_byte5075, i64 0
  %generic_dict_group_h2_vector5088 = shufflevector <16 x i8> %generic_dict_group_h2_seed5087, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector5089 = icmp eq <16 x i8> %generic_dict_group_controls5086, %generic_dict_group_h2_vector5088
  %generic_dict_group_match_bits5090 = bitcast <16 x i1> %generic_dict_group_matches_vector5089 to i16
  %generic_dict_group_empty_vector5091 = icmp eq <16 x i8> %generic_dict_group_controls5086, zeroinitializer
  %generic_dict_group_empty_bits5092 = bitcast <16 x i1> %generic_dict_group_empty_vector5091 to i16
  %generic_dict_group_deleted_seed5093 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector5094 = shufflevector <16 x i8> %generic_dict_group_deleted_seed5093, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches5095 = icmp eq <16 x i8> %generic_dict_group_controls5086, %generic_dict_group_deleted_vector5094
  %generic_dict_group_deleted_bits5096 = bitcast <16 x i1> %generic_dict_group_deleted_matches5095 to i16
  %generic_dict_group_has_deleted5097 = icmp ne i16 %generic_dict_group_deleted_bits5096, 0
  %generic_dict_group_no_previous_deleted5098 = icmp eq i64 %generic_dict_group_deleted5081, %set_grown_capacity5022
  %generic_dict_group_capture_deleted5099 = and i1 %generic_dict_group_has_deleted5097, %generic_dict_group_no_previous_deleted5098
  %generic_dict_group_deleted_offset165100 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits5096, i1 false)
  %generic_dict_group_deleted_offset5101 = zext i16 %generic_dict_group_deleted_offset165100 to i64
  %generic_dict_group_deleted_unwrapped5102 = add i64 %generic_dict_group_start5084, %generic_dict_group_deleted_offset5101
  %generic_dict_group_deleted_slot5103 = and i64 %generic_dict_group_deleted_unwrapped5102, %dict_capacity_mask5076
  %generic_dict_group_captured_deleted5104 = select i1 %generic_dict_group_capture_deleted5099, i64 %generic_dict_group_deleted_slot5103, i64 %generic_dict_group_deleted5081
  br label %bb_generic_dict_candidate_loop1170

bb_generic_dict_candidate_loop1170:
  %generic_dict_candidate_bits5105 = phi i16 [ %generic_dict_group_match_bits5090, %bb_generic_dict_group_body1169 ], [ %generic_dict_candidate_cleared_bits5106, %bb_generic_dict_candidate_next1172 ]
  %generic_dict_has_candidate5107 = icmp ne i16 %generic_dict_candidate_bits5105, 0
  br i1 %generic_dict_has_candidate5107, label %bb_generic_dict_candidate_body1171, label %bb_generic_dict_group_decision1173

bb_generic_dict_candidate_body1171:
  %generic_dict_candidate_offset165108 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits5105, i1 false)
  %generic_dict_candidate_offset5109 = zext i16 %generic_dict_candidate_offset165108 to i64
  %generic_dict_candidate_unwrapped5110 = add i64 %generic_dict_group_start5084, %generic_dict_candidate_offset5109
  %generic_dict_candidate_slot5111 = and i64 %generic_dict_candidate_unwrapped5110, %dict_capacity_mask5076
  %generic_dict_key_entries_offset_mirror5112 = add i64 %set_grown_capacity5022, 23
  %generic_dict_key_entries_offset5113 = and i64 %generic_dict_key_entries_offset_mirror5112, -8
  %generic_dict_key_entries5114 = getelementptr i8, ptr %heap5027, i64 %generic_dict_key_entries_offset5113
  %generic_dict_key_entry_offset5115 = mul i64 %generic_dict_candidate_slot5111, 4
  %generic_dict_key_slot5116 = getelementptr i8, ptr %generic_dict_key_entries5114, i64 %generic_dict_key_entry_offset5115
  %generic_dict_key5117 = load i32, ptr %generic_dict_key_slot5116, align 4
  %generic_dict_key_equal5118 = icmp eq i32 %generic_dict_key5117, %set_rehash_key5043
  br i1 %generic_dict_key_equal5118, label %bb_generic_dict_group_match1175, label %bb_generic_dict_candidate_next1172

bb_generic_dict_candidate_next1172:
  %generic_dict_candidate_bits_minus_one5119 = sub i16 %generic_dict_candidate_bits5105, 1
  %generic_dict_candidate_cleared_bits5106 = and i16 %generic_dict_candidate_bits5105, %generic_dict_candidate_bits_minus_one5119
  br label %bb_generic_dict_candidate_loop1170

bb_generic_dict_group_decision1173:
  %generic_dict_group_has_empty5120 = icmp ne i16 %generic_dict_group_empty_bits5092, 0
  br i1 %generic_dict_group_has_empty5120, label %bb_generic_dict_group_empty1174, label %bb_generic_dict_group_next1176

bb_generic_dict_group_empty1174:
  %generic_dict_group_empty_offset165121 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits5092, i1 false)
  %generic_dict_group_empty_offset5122 = zext i16 %generic_dict_group_empty_offset165121 to i64
  %generic_dict_group_empty_unwrapped5123 = add i64 %generic_dict_group_start5084, %generic_dict_group_empty_offset5122
  %generic_dict_group_empty_slot5124 = and i64 %generic_dict_group_empty_unwrapped5123, %dict_capacity_mask5076
  %generic_dict_group_use_empty5125 = icmp eq i64 %generic_dict_group_captured_deleted5104, %set_grown_capacity5022
  %generic_dict_group_insertion_slot5126 = select i1 %generic_dict_group_use_empty5125, i64 %generic_dict_group_empty_slot5124, i64 %generic_dict_group_captured_deleted5104
  br label %bb_generic_dict_group_done1178

bb_generic_dict_group_match1175:
  br label %bb_generic_dict_group_done1178

bb_generic_dict_group_next1176:
  %generic_dict_group_next_probe5078 = add i64 %generic_dict_group_probe5080, 16
  %generic_dict_group_next_deleted5079 = add i64 %generic_dict_group_captured_deleted5104, 0
  br label %bb_generic_dict_group_find1168

bb_generic_dict_group_miss1177:
  %generic_dict_group_miss_no_deleted5127 = icmp eq i64 %generic_dict_group_deleted5081, %set_grown_capacity5022
  %generic_dict_group_miss_slot5128 = select i1 %generic_dict_group_miss_no_deleted5127, i64 0, i64 %generic_dict_group_deleted5081
  br label %bb_generic_dict_group_done1178

bb_generic_dict_group_done1178:
  %generic_dict_find_found5129 = phi i1 [ false, %bb_generic_dict_group_empty1174 ], [ true, %bb_generic_dict_group_match1175 ], [ false, %bb_generic_dict_group_miss1177 ]
  %generic_dict_find_slot_result5130 = phi i64 [ %generic_dict_group_insertion_slot5126, %bb_generic_dict_group_empty1174 ], [ %generic_dict_candidate_slot5111, %bb_generic_dict_group_match1175 ], [ %generic_dict_group_miss_slot5128, %bb_generic_dict_group_miss1177 ]
  br label %bb_generic_dict_insert_first_done1165

bb_generic_dict_insert_first_done1165:
  %generic_dict_insert_first_found5131 = phi i1 [ true, %bb_generic_dict_insert_first_match1162 ], [ false, %bb_generic_dict_insert_first_vacant1164 ], [ %generic_dict_find_found5129, %bb_generic_dict_group_done1178 ], [ false, %bb_generic_dict_insert_no_capacity1167 ]
  %generic_dict_insert_first_slot_result5132 = phi i64 [ %dict_start_slot5054, %bb_generic_dict_insert_first_match1162 ], [ %dict_start_slot5054, %bb_generic_dict_insert_first_vacant1164 ], [ %generic_dict_find_slot_result5130, %bb_generic_dict_group_done1178 ], [ 0, %bb_generic_dict_insert_no_capacity1167 ]
  %set_key_entries_offset_mirror5133 = add i64 %set_grown_capacity5022, 23
  %set_key_entries_offset5134 = and i64 %set_key_entries_offset_mirror5133, -8
  %set_key_entries5135 = getelementptr i8, ptr %heap5027, i64 %set_key_entries_offset5134
  %set_key_entry_offset5136 = mul i64 %generic_dict_insert_first_slot_result5132, 4
  %set_key_slot5137 = getelementptr i8, ptr %set_key_entries5135, i64 %set_key_entry_offset5136
  store i32 %set_rehash_key5043, ptr %set_key_slot5137, align 4
  %generic_dict_control_slot5138 = getelementptr i8, ptr %heap5027, i64 %generic_dict_insert_first_slot_result5132
  store i8 %dict_h2_byte5052, ptr %generic_dict_control_slot5138, align 1
  %generic_dict_control_mirrored5139 = icmp ult i64 %generic_dict_insert_first_slot_result5132, 16
  br i1 %generic_dict_control_mirrored5139, label %bb_generic_dict_control_mirror1179, label %bb_generic_dict_control_done1180

bb_generic_dict_control_mirror1179:
  %generic_dict_control_mirror_index5140 = add i64 %set_grown_capacity5022, %generic_dict_insert_first_slot_result5132
  %generic_dict_control_mirror_slot5141 = getelementptr i8, ptr %heap5027, i64 %generic_dict_control_mirror_index5140
  store i8 %dict_h2_byte5052, ptr %generic_dict_control_mirror_slot5141, align 1
  br label %bb_generic_dict_control_done1180

bb_generic_dict_control_done1180:
  br label %bb_set_rehash_next1158

bb_set_rehash_next1158:
  %set_rehash_next_index5032 = add i64 %set_rehash_index5033, 1
  br label %bb_set_rehash1155

bb_set_rehash_done1159:
  call void @sollang_free(ptr %mutable_ptr4917)
  %hash_key5142 = sext i32 16 to i64
  %hash_high5144 = lshr i64 %hash_key5142, 32
  %hash_fold5143 = xor i64 %hash_key5142, %hash_high5144
  %hash5145 = mul i64 %hash_fold5143, -7046029254386353131
  %dict_h2_shifted5146 = lshr i64 %hash5145, 57
  %dict_h2_raw5147 = and i64 %dict_h2_shifted5146, 127
  %dict_h2_zero5148 = icmp eq i64 %dict_h2_raw5147, 0
  %dict_h25149 = select i1 %dict_h2_zero5148, i64 1, i64 %dict_h2_raw5147
  %dict_h2_byte5150 = trunc i64 %dict_h25149 to i8
  %dict_capacity_mask5151 = sub i64 %set_grown_capacity5022, 1
  %dict_start_slot5152 = and i64 %hash5145, %dict_capacity_mask5151
  %generic_dict_insert_has_capacity5153 = icmp ugt i64 %set_grown_capacity5022, 0
  br i1 %generic_dict_insert_has_capacity5153, label %bb_generic_dict_insert_first1187, label %bb_generic_dict_insert_no_capacity1188

bb_generic_dict_insert_no_capacity1188:
  br label %bb_generic_dict_insert_first_done1186

bb_generic_dict_insert_first1187:
  %generic_dict_control_slot5154 = getelementptr i8, ptr %heap5027, i64 %dict_start_slot5152
  %generic_dict_control5155 = load i8, ptr %generic_dict_control_slot5154, align 1
  %generic_dict_insert_first_empty5156 = icmp eq i8 %generic_dict_control5155, 0
  br i1 %generic_dict_insert_first_empty5156, label %bb_generic_dict_insert_first_vacant1185, label %bb_generic_dict_insert_first_occupied1181

bb_generic_dict_insert_first_occupied1181:
  %generic_dict_insert_first_h25157 = icmp eq i8 %generic_dict_control5155, %dict_h2_byte5150
  br i1 %generic_dict_insert_first_h25157, label %bb_generic_dict_insert_first_compare1182, label %bb_generic_dict_insert_first_fallback1184

bb_generic_dict_insert_first_compare1182:
  %generic_dict_insert_first_key_entries_offset_mirror5158 = add i64 %set_grown_capacity5022, 23
  %generic_dict_insert_first_key_entries_offset5159 = and i64 %generic_dict_insert_first_key_entries_offset_mirror5158, -8
  %generic_dict_insert_first_key_entries5160 = getelementptr i8, ptr %heap5027, i64 %generic_dict_insert_first_key_entries_offset5159
  %generic_dict_insert_first_key_entry_offset5161 = mul i64 %dict_start_slot5152, 4
  %generic_dict_insert_first_key_slot5162 = getelementptr i8, ptr %generic_dict_insert_first_key_entries5160, i64 %generic_dict_insert_first_key_entry_offset5161
  %generic_dict_insert_first_key5163 = load i32, ptr %generic_dict_insert_first_key_slot5162, align 4
  %generic_dict_key_equal5164 = icmp eq i32 %generic_dict_insert_first_key5163, 16
  br i1 %generic_dict_key_equal5164, label %bb_generic_dict_insert_first_match1183, label %bb_generic_dict_insert_first_fallback1184

bb_generic_dict_insert_first_match1183:
  br label %bb_generic_dict_insert_first_done1186

bb_generic_dict_insert_first_vacant1185:
  br label %bb_generic_dict_insert_first_done1186

bb_generic_dict_insert_first_fallback1184:
  %hash_key5165 = sext i32 16 to i64
  %hash_high5167 = lshr i64 %hash_key5165, 32
  %hash_fold5166 = xor i64 %hash_key5165, %hash_high5167
  %hash5168 = mul i64 %hash_fold5166, -7046029254386353131
  %dict_h2_shifted5169 = lshr i64 %hash5168, 57
  %dict_h2_raw5170 = and i64 %dict_h2_shifted5169, 127
  %dict_h2_zero5171 = icmp eq i64 %dict_h2_raw5170, 0
  %dict_h25172 = select i1 %dict_h2_zero5171, i64 1, i64 %dict_h2_raw5170
  %dict_h2_byte5173 = trunc i64 %dict_h25172 to i8
  %dict_capacity_mask5174 = sub i64 %set_grown_capacity5022, 1
  %dict_start_slot5175 = and i64 %hash5168, %dict_capacity_mask5174
  br label %bb_generic_dict_group_find1189

bb_generic_dict_group_find1189:
  %generic_dict_group_probe5178 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback1184 ], [ %generic_dict_group_next_probe5176, %bb_generic_dict_group_next1197 ]
  %generic_dict_group_deleted5179 = phi i64 [ %set_grown_capacity5022, %bb_generic_dict_insert_first_fallback1184 ], [ %generic_dict_group_next_deleted5177, %bb_generic_dict_group_next1197 ]
  %generic_dict_group_active5180 = icmp ult i64 %generic_dict_group_probe5178, %set_grown_capacity5022
  br i1 %generic_dict_group_active5180, label %bb_generic_dict_group_body1190, label %bb_generic_dict_group_miss1198

bb_generic_dict_group_body1190:
  %generic_dict_group_unwrapped5181 = add i64 %dict_start_slot5175, %generic_dict_group_probe5178
  %generic_dict_group_start5182 = and i64 %generic_dict_group_unwrapped5181, %dict_capacity_mask5174
  %generic_dict_group_pointer5183 = getelementptr i8, ptr %heap5027, i64 %generic_dict_group_start5182
  %generic_dict_group_controls5184 = load <16 x i8>, ptr %generic_dict_group_pointer5183, align 1
  %generic_dict_group_h2_seed5185 = insertelement <16 x i8> poison, i8 %dict_h2_byte5173, i64 0
  %generic_dict_group_h2_vector5186 = shufflevector <16 x i8> %generic_dict_group_h2_seed5185, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector5187 = icmp eq <16 x i8> %generic_dict_group_controls5184, %generic_dict_group_h2_vector5186
  %generic_dict_group_match_bits5188 = bitcast <16 x i1> %generic_dict_group_matches_vector5187 to i16
  %generic_dict_group_empty_vector5189 = icmp eq <16 x i8> %generic_dict_group_controls5184, zeroinitializer
  %generic_dict_group_empty_bits5190 = bitcast <16 x i1> %generic_dict_group_empty_vector5189 to i16
  %generic_dict_group_deleted_seed5191 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector5192 = shufflevector <16 x i8> %generic_dict_group_deleted_seed5191, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches5193 = icmp eq <16 x i8> %generic_dict_group_controls5184, %generic_dict_group_deleted_vector5192
  %generic_dict_group_deleted_bits5194 = bitcast <16 x i1> %generic_dict_group_deleted_matches5193 to i16
  %generic_dict_group_has_deleted5195 = icmp ne i16 %generic_dict_group_deleted_bits5194, 0
  %generic_dict_group_no_previous_deleted5196 = icmp eq i64 %generic_dict_group_deleted5179, %set_grown_capacity5022
  %generic_dict_group_capture_deleted5197 = and i1 %generic_dict_group_has_deleted5195, %generic_dict_group_no_previous_deleted5196
  %generic_dict_group_deleted_offset165198 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits5194, i1 false)
  %generic_dict_group_deleted_offset5199 = zext i16 %generic_dict_group_deleted_offset165198 to i64
  %generic_dict_group_deleted_unwrapped5200 = add i64 %generic_dict_group_start5182, %generic_dict_group_deleted_offset5199
  %generic_dict_group_deleted_slot5201 = and i64 %generic_dict_group_deleted_unwrapped5200, %dict_capacity_mask5174
  %generic_dict_group_captured_deleted5202 = select i1 %generic_dict_group_capture_deleted5197, i64 %generic_dict_group_deleted_slot5201, i64 %generic_dict_group_deleted5179
  br label %bb_generic_dict_candidate_loop1191

bb_generic_dict_candidate_loop1191:
  %generic_dict_candidate_bits5203 = phi i16 [ %generic_dict_group_match_bits5188, %bb_generic_dict_group_body1190 ], [ %generic_dict_candidate_cleared_bits5204, %bb_generic_dict_candidate_next1193 ]
  %generic_dict_has_candidate5205 = icmp ne i16 %generic_dict_candidate_bits5203, 0
  br i1 %generic_dict_has_candidate5205, label %bb_generic_dict_candidate_body1192, label %bb_generic_dict_group_decision1194

bb_generic_dict_candidate_body1192:
  %generic_dict_candidate_offset165206 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits5203, i1 false)
  %generic_dict_candidate_offset5207 = zext i16 %generic_dict_candidate_offset165206 to i64
  %generic_dict_candidate_unwrapped5208 = add i64 %generic_dict_group_start5182, %generic_dict_candidate_offset5207
  %generic_dict_candidate_slot5209 = and i64 %generic_dict_candidate_unwrapped5208, %dict_capacity_mask5174
  %generic_dict_key_entries_offset_mirror5210 = add i64 %set_grown_capacity5022, 23
  %generic_dict_key_entries_offset5211 = and i64 %generic_dict_key_entries_offset_mirror5210, -8
  %generic_dict_key_entries5212 = getelementptr i8, ptr %heap5027, i64 %generic_dict_key_entries_offset5211
  %generic_dict_key_entry_offset5213 = mul i64 %generic_dict_candidate_slot5209, 4
  %generic_dict_key_slot5214 = getelementptr i8, ptr %generic_dict_key_entries5212, i64 %generic_dict_key_entry_offset5213
  %generic_dict_key5215 = load i32, ptr %generic_dict_key_slot5214, align 4
  %generic_dict_key_equal5216 = icmp eq i32 %generic_dict_key5215, 16
  br i1 %generic_dict_key_equal5216, label %bb_generic_dict_group_match1196, label %bb_generic_dict_candidate_next1193

bb_generic_dict_candidate_next1193:
  %generic_dict_candidate_bits_minus_one5217 = sub i16 %generic_dict_candidate_bits5203, 1
  %generic_dict_candidate_cleared_bits5204 = and i16 %generic_dict_candidate_bits5203, %generic_dict_candidate_bits_minus_one5217
  br label %bb_generic_dict_candidate_loop1191

bb_generic_dict_group_decision1194:
  %generic_dict_group_has_empty5218 = icmp ne i16 %generic_dict_group_empty_bits5190, 0
  br i1 %generic_dict_group_has_empty5218, label %bb_generic_dict_group_empty1195, label %bb_generic_dict_group_next1197

bb_generic_dict_group_empty1195:
  %generic_dict_group_empty_offset165219 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits5190, i1 false)
  %generic_dict_group_empty_offset5220 = zext i16 %generic_dict_group_empty_offset165219 to i64
  %generic_dict_group_empty_unwrapped5221 = add i64 %generic_dict_group_start5182, %generic_dict_group_empty_offset5220
  %generic_dict_group_empty_slot5222 = and i64 %generic_dict_group_empty_unwrapped5221, %dict_capacity_mask5174
  %generic_dict_group_use_empty5223 = icmp eq i64 %generic_dict_group_captured_deleted5202, %set_grown_capacity5022
  %generic_dict_group_insertion_slot5224 = select i1 %generic_dict_group_use_empty5223, i64 %generic_dict_group_empty_slot5222, i64 %generic_dict_group_captured_deleted5202
  br label %bb_generic_dict_group_done1199

bb_generic_dict_group_match1196:
  br label %bb_generic_dict_group_done1199

bb_generic_dict_group_next1197:
  %generic_dict_group_next_probe5176 = add i64 %generic_dict_group_probe5178, 16
  %generic_dict_group_next_deleted5177 = add i64 %generic_dict_group_captured_deleted5202, 0
  br label %bb_generic_dict_group_find1189

bb_generic_dict_group_miss1198:
  %generic_dict_group_miss_no_deleted5225 = icmp eq i64 %generic_dict_group_deleted5179, %set_grown_capacity5022
  %generic_dict_group_miss_slot5226 = select i1 %generic_dict_group_miss_no_deleted5225, i64 0, i64 %generic_dict_group_deleted5179
  br label %bb_generic_dict_group_done1199

bb_generic_dict_group_done1199:
  %generic_dict_find_found5227 = phi i1 [ false, %bb_generic_dict_group_empty1195 ], [ true, %bb_generic_dict_group_match1196 ], [ false, %bb_generic_dict_group_miss1198 ]
  %generic_dict_find_slot_result5228 = phi i64 [ %generic_dict_group_insertion_slot5224, %bb_generic_dict_group_empty1195 ], [ %generic_dict_candidate_slot5209, %bb_generic_dict_group_match1196 ], [ %generic_dict_group_miss_slot5226, %bb_generic_dict_group_miss1198 ]
  br label %bb_generic_dict_insert_first_done1186

bb_generic_dict_insert_first_done1186:
  %generic_dict_insert_first_found5229 = phi i1 [ true, %bb_generic_dict_insert_first_match1183 ], [ false, %bb_generic_dict_insert_first_vacant1185 ], [ %generic_dict_find_found5227, %bb_generic_dict_group_done1199 ], [ false, %bb_generic_dict_insert_no_capacity1188 ]
  %generic_dict_insert_first_slot_result5230 = phi i64 [ %dict_start_slot5152, %bb_generic_dict_insert_first_match1183 ], [ %dict_start_slot5152, %bb_generic_dict_insert_first_vacant1185 ], [ %generic_dict_find_slot_result5228, %bb_generic_dict_group_done1199 ], [ 0, %bb_generic_dict_insert_no_capacity1188 ]
  %set_key_entries_offset_mirror5231 = add i64 %set_grown_capacity5022, 23
  %set_key_entries_offset5232 = and i64 %set_key_entries_offset_mirror5231, -8
  %set_key_entries5233 = getelementptr i8, ptr %heap5027, i64 %set_key_entries_offset5232
  %set_key_entry_offset5234 = mul i64 %generic_dict_insert_first_slot_result5230, 4
  %set_key_slot5235 = getelementptr i8, ptr %set_key_entries5233, i64 %set_key_entry_offset5234
  store i32 16, ptr %set_key_slot5235, align 4
  %generic_dict_control_slot5236 = getelementptr i8, ptr %heap5027, i64 %generic_dict_insert_first_slot_result5230
  store i8 %dict_h2_byte5150, ptr %generic_dict_control_slot5236, align 1
  %generic_dict_control_mirrored5237 = icmp ult i64 %generic_dict_insert_first_slot_result5230, 16
  br i1 %generic_dict_control_mirrored5237, label %bb_generic_dict_control_mirror1200, label %bb_generic_dict_control_done1201

bb_generic_dict_control_mirror1200:
  %generic_dict_control_mirror_index5238 = add i64 %set_grown_capacity5022, %generic_dict_insert_first_slot_result5230
  %generic_dict_control_mirror_slot5239 = getelementptr i8, ptr %heap5027, i64 %generic_dict_control_mirror_index5238
  store i8 %dict_h2_byte5150, ptr %generic_dict_control_mirror_slot5239, align 1
  br label %bb_generic_dict_control_done1201

bb_generic_dict_control_done1201:
  br label %bb_set_insert_done1150

bb_set_insert_done1150:
  %set_pointer5240 = phi ptr [ %mutable_ptr4917, %bb_set_insert_duplicate1146 ], [ %mutable_ptr4917, %bb_generic_dict_control_done1152 ], [ %heap5027, %bb_generic_dict_control_done1201 ]
  %set_length5241 = phi i64 [ %mutable_len4918, %bb_set_insert_duplicate1146 ], [ %set_insert_length5009, %bb_generic_dict_control_done1152 ], [ %set_insert_length5009, %bb_generic_dict_control_done1201 ]
  %set_capacity5242 = phi i64 [ %mutable_capacity4919, %bb_set_insert_duplicate1146 ], [ %mutable_capacity4919, %bb_generic_dict_control_done1152 ], [ %set_grown_capacity5022, %bb_generic_dict_control_done1201 ]
  %set_inserted5243 = phi i1 [ false, %bb_set_insert_duplicate1146 ], [ true, %bb_generic_dict_control_done1152 ], [ true, %bb_generic_dict_control_done1201 ]
  store ptr %set_pointer5240, ptr %mutable_ptr_addr9, align 8
  store i64 %set_length5241, ptr %mutable_len_addr10, align 8
  store i64 %set_capacity5242, ptr %mutable_capacity_addr11, align 8
  br i1 %set_inserted338, label %bb_if_then1202, label %bb_if_else1203
bb_if_then1202:
  %write5244 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.17, i64 10, ptr %written)
  %is_ok5245 = icmp ne i32 %write5244, 0
  %previous_ok5246 = load i1, ptr %ok_state, align 1
  %ok5247 = and i1 %previous_ok5246, %is_ok5245
  store i1 %ok5247, ptr %ok_state, align 1
  %write5248 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.18, i64 1, ptr %written)
  %is_ok5249 = icmp ne i32 %write5248, 0
  %previous_ok5250 = load i1, ptr %ok_state, align 1
  %ok5251 = and i1 %previous_ok5250, %is_ok5249
  store i1 %ok5251, ptr %ok_state, align 1
  br label %bb_if_end1204
bb_if_else1203:
  %write5252 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.19, i64 11, ptr %written)
  %is_ok5253 = icmp ne i32 %write5252, 0
  %previous_ok5254 = load i1, ptr %ok_state, align 1
  %ok5255 = and i1 %previous_ok5254, %is_ok5253
  store i1 %ok5255, ptr %ok_state, align 1
  %write5256 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.20, i64 1, ptr %written)
  %is_ok5257 = icmp ne i32 %write5256, 0
  %previous_ok5258 = load i1, ptr %ok_state, align 1
  %ok5259 = and i1 %previous_ok5258, %is_ok5257
  store i1 %ok5259, ptr %ok_state, align 1
  br label %bb_if_end1204
bb_if_end1204:
  br i1 %set_inserted992, label %bb_if_then1205, label %bb_if_else1206
bb_if_then1205:
  %write5260 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.21, i64 14, ptr %written)
  %is_ok5261 = icmp ne i32 %write5260, 0
  %previous_ok5262 = load i1, ptr %ok_state, align 1
  %ok5263 = and i1 %previous_ok5262, %is_ok5261
  store i1 %ok5263, ptr %ok_state, align 1
  %write5264 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.22, i64 1, ptr %written)
  %is_ok5265 = icmp ne i32 %write5264, 0
  %previous_ok5266 = load i1, ptr %ok_state, align 1
  %ok5267 = and i1 %previous_ok5266, %is_ok5265
  store i1 %ok5267, ptr %ok_state, align 1
  br label %bb_if_end1207
bb_if_else1206:
  %write5268 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.23, i64 15, ptr %written)
  %is_ok5269 = icmp ne i32 %write5268, 0
  %previous_ok5270 = load i1, ptr %ok_state, align 1
  %ok5271 = and i1 %previous_ok5270, %is_ok5269
  store i1 %ok5271, ptr %ok_state, align 1
  %write5272 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.24, i64 1, ptr %written)
  %is_ok5273 = icmp ne i32 %write5272, 0
  %previous_ok5274 = load i1, ptr %ok_state, align 1
  %ok5275 = and i1 %previous_ok5274, %is_ok5273
  store i1 %ok5275, ptr %ok_state, align 1
  br label %bb_if_end1207
bb_if_end1207:
  %mutable_ptr5276 = load ptr, ptr %mutable_ptr_addr9, align 8
  %mutable_len5277 = load i64, ptr %mutable_len_addr10, align 8
  %mutable_capacity5278 = load i64, ptr %mutable_capacity_addr11, align 8
  %generic_dict_value5279 = insertvalue %sollang.int_dictionary poison, ptr %mutable_ptr5276, 0
  %generic_dict_value5280 = insertvalue %sollang.int_dictionary %generic_dict_value5279, i64 %mutable_len5277, 1
  %generic_dict_value5281 = insertvalue %sollang.int_dictionary %generic_dict_value5280, i64 %mutable_capacity5278, 2
  ret %sollang.int_dictionary %generic_dict_value5281
}

@.slg.str.suffix.0 = private unnamed_addr constant [20 x i8] c"main:bb_alloc_fail44", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [20 x i8] c"main:bb_alloc_fail95", align 1
@.slg.str.suffix.2 = private unnamed_addr constant [40 x i8] c"main:bb_numeric_conversion_upper_fail143", align 1
@.slg.str.suffix.3 = private unnamed_addr constant [11 x i8] c"before=true", align 1
@.slg.str.suffix.4 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.5 = private unnamed_addr constant [12 x i8] c"before=false", align 1
@.slg.str.suffix.6 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.7 = private unnamed_addr constant [12 x i8] c"removed=true", align 1
@.slg.str.suffix.8 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.9 = private unnamed_addr constant [13 x i8] c"removed=false", align 1
@.slg.str.suffix.10 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.11 = private unnamed_addr constant [10 x i8] c"again=true", align 1
@.slg.str.suffix.12 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.13 = private unnamed_addr constant [11 x i8] c"again=false", align 1
@.slg.str.suffix.14 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.15 = private unnamed_addr constant [10 x i8] c"after=true", align 1
@.slg.str.suffix.16 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.17 = private unnamed_addr constant [11 x i8] c"after=false", align 1
@.slg.str.suffix.18 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.19 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.20 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.21 = private unnamed_addr constant [4 x i8] c"len=", align 1
@.slg.str.suffix.22 = private unnamed_addr constant [10 x i8] c" capacity=", align 1
@.slg.str.suffix.23 = private unnamed_addr constant [1 x i8] c"\0A", align 1
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
  %written = alloca i32, align 4
  %read = alloca i32, align 4
  %ok_state = alloca i1, align 1
  %mutable_ptr_addr4 = alloca ptr, align 8
  %mutable_len_addr5 = alloca i64, align 8
  %mutable_capacity_addr6 = alloca i64, align 8
  %mutable_scalar_slot7 = alloca i32, align 4
  %trap_written178 = alloca i32, align 4
  %trap_written376 = alloca i32, align 4
  %mutable_scalar_slot560 = alloca i32, align 4
  %trap_written588 = alloca i32, align 4
  store i1 true, ptr %ok_state, align 1
  %stdin = call ptr @GetStdHandle(i32 -10)
  %stdout = call ptr @GetStdHandle(i32 -11)
  %stdout_mode = alloca i32, align 4
  %stdout_is_console_status = call i32 @GetConsoleMode(ptr %stdout, ptr %stdout_mode)
  %stdout_is_console = icmp ne i32 %stdout_is_console_status, 0
  store i1 %stdout_is_console, ptr @sollang_stdout_line_buffered, align 1
  %generic_dict0 = call %sollang.int_dictionary @sollang_fn_makeSet(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state)
  %generic_dict_ptr1 = extractvalue %sollang.int_dictionary %generic_dict0, 0
  %generic_dict_len2 = extractvalue %sollang.int_dictionary %generic_dict0, 1
  %generic_dict_capacity3 = extractvalue %sollang.int_dictionary %generic_dict0, 2
  store ptr %generic_dict_ptr1, ptr %mutable_ptr_addr4, align 8
  store i64 %generic_dict_len2, ptr %mutable_len_addr5, align 8
  store i64 %generic_dict_capacity3, ptr %mutable_capacity_addr6, align 8
  store i32 0, ptr %mutable_scalar_slot7, align 4
  %mutable_ptr8 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len9 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity10 = load i64, ptr %mutable_capacity_addr6, align 8
  %dictionary_each_empty12 = icmp eq i64 %mutable_capacity10, 0
  br i1 %dictionary_each_empty12, label %bb_dictionary_each_end3, label %bb_dictionary_each0

bb_dictionary_each0:
  %dictionary_each_slot13 = phi i64 [ 0, %entry ], [ %dictionary_each_next11, %bb_dictionary_each_continue2 ]
  %generic_dict_control_slot14 = getelementptr i8, ptr %mutable_ptr8, i64 %dictionary_each_slot13
  %generic_dict_control15 = load i8, ptr %generic_dict_control_slot14, align 1
  %dictionary_each_occupied16 = icmp sgt i8 %generic_dict_control15, 0
  br i1 %dictionary_each_occupied16, label %bb_dictionary_each_body1, label %bb_dictionary_each_continue2

bb_dictionary_each_body1:
  %dictionary_each_key_entries_offset_mirror17 = add i64 %mutable_capacity10, 23
  %dictionary_each_key_entries_offset18 = and i64 %dictionary_each_key_entries_offset_mirror17, -8
  %dictionary_each_key_entries19 = getelementptr i8, ptr %mutable_ptr8, i64 %dictionary_each_key_entries_offset18
  %dictionary_each_key_entry_offset20 = mul i64 %dictionary_each_slot13, 4
  %dictionary_each_key_slot21 = getelementptr i8, ptr %dictionary_each_key_entries19, i64 %dictionary_each_key_entry_offset20
  %dictionary_each_key22 = load i32, ptr %dictionary_each_key_slot21, align 4
  %mutable_scalar23 = load i32, ptr %mutable_scalar_slot7, align 4
  %add24 = add i32 %mutable_scalar23, %dictionary_each_key22
  store i32 %add24, ptr %mutable_scalar_slot7, align 4
  br label %bb_dictionary_each_continue2

bb_dictionary_each_continue2:
  %dictionary_each_next11 = add i64 %dictionary_each_slot13, 1
  %dictionary_each_done25 = icmp eq i64 %dictionary_each_next11, %mutable_capacity10
  br i1 %dictionary_each_done25, label %bb_dictionary_each_end3, label %bb_dictionary_each0

bb_dictionary_each_end3:
  %mutable_ptr26 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len27 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity28 = load i64, ptr %mutable_capacity_addr6, align 8
  %hash_key29 = sext i32 20 to i64
  %hash_high31 = lshr i64 %hash_key29, 32
  %hash_fold30 = xor i64 %hash_key29, %hash_high31
  %hash32 = mul i64 %hash_fold30, -7046029254386353131
  %dict_h2_shifted33 = lshr i64 %hash32, 57
  %dict_h2_raw34 = and i64 %dict_h2_shifted33, 127
  %dict_h2_zero35 = icmp eq i64 %dict_h2_raw34, 0
  %dict_h236 = select i1 %dict_h2_zero35, i64 1, i64 %dict_h2_raw34
  %dict_h2_byte37 = trunc i64 %dict_h236 to i8
  %dict_capacity_mask38 = sub i64 %mutable_capacity28, 1
  %dict_start_slot39 = and i64 %hash32, %dict_capacity_mask38
  %generic_dict_control_slot40 = getelementptr i8, ptr %mutable_ptr26, i64 %dict_start_slot39
  %generic_dict_control41 = load i8, ptr %generic_dict_control_slot40, align 1
  %generic_dict_lookup_first_empty42 = icmp eq i8 %generic_dict_control41, 0
  br i1 %generic_dict_lookup_first_empty42, label %bb_generic_dict_lookup_first_miss8, label %bb_generic_dict_lookup_first_occupied4

bb_generic_dict_lookup_first_occupied4:
  %generic_dict_lookup_first_h243 = icmp eq i8 %generic_dict_control41, %dict_h2_byte37
  br i1 %generic_dict_lookup_first_h243, label %bb_generic_dict_lookup_first_compare5, label %bb_generic_dict_lookup_first_fallback7

bb_generic_dict_lookup_first_compare5:
  %generic_dict_lookup_first_key_entries_offset_mirror44 = add i64 %mutable_capacity28, 23
  %generic_dict_lookup_first_key_entries_offset45 = and i64 %generic_dict_lookup_first_key_entries_offset_mirror44, -8
  %generic_dict_lookup_first_key_entries46 = getelementptr i8, ptr %mutable_ptr26, i64 %generic_dict_lookup_first_key_entries_offset45
  %generic_dict_lookup_first_key_entry_offset47 = mul i64 %dict_start_slot39, 4
  %generic_dict_lookup_first_key_slot48 = getelementptr i8, ptr %generic_dict_lookup_first_key_entries46, i64 %generic_dict_lookup_first_key_entry_offset47
  %generic_dict_lookup_first_key49 = load i32, ptr %generic_dict_lookup_first_key_slot48, align 4
  %generic_dict_key_equal50 = icmp eq i32 %generic_dict_lookup_first_key49, 20
  br i1 %generic_dict_key_equal50, label %bb_generic_dict_lookup_first_match6, label %bb_generic_dict_lookup_first_fallback7

bb_generic_dict_lookup_first_match6:
  br label %bb_generic_dict_lookup_first_done9

bb_generic_dict_lookup_first_miss8:
  br label %bb_generic_dict_lookup_first_done9

bb_generic_dict_lookup_first_fallback7:
  %hash_key51 = sext i32 20 to i64
  %hash_high53 = lshr i64 %hash_key51, 32
  %hash_fold52 = xor i64 %hash_key51, %hash_high53
  %hash54 = mul i64 %hash_fold52, -7046029254386353131
  %dict_h2_shifted55 = lshr i64 %hash54, 57
  %dict_h2_raw56 = and i64 %dict_h2_shifted55, 127
  %dict_h2_zero57 = icmp eq i64 %dict_h2_raw56, 0
  %dict_h258 = select i1 %dict_h2_zero57, i64 1, i64 %dict_h2_raw56
  %dict_h2_byte59 = trunc i64 %dict_h258 to i8
  %dict_capacity_mask60 = sub i64 %mutable_capacity28, 1
  %dict_start_slot61 = and i64 %hash54, %dict_capacity_mask60
  br label %bb_generic_dict_lookup_group10

bb_generic_dict_lookup_group10:
  %generic_dict_lookup_group_probe63 = phi i64 [ 0, %bb_generic_dict_lookup_first_fallback7 ], [ %generic_dict_lookup_group_next_probe62, %bb_generic_dict_lookup_group_next17 ]
  %generic_dict_lookup_group_active64 = icmp ult i64 %generic_dict_lookup_group_probe63, %mutable_capacity28
  br i1 %generic_dict_lookup_group_active64, label %bb_generic_dict_lookup_group_body11, label %bb_generic_dict_lookup_group_miss18

bb_generic_dict_lookup_group_body11:
  %generic_dict_lookup_group_unwrapped65 = add i64 %dict_start_slot61, %generic_dict_lookup_group_probe63
  %generic_dict_lookup_group_start66 = and i64 %generic_dict_lookup_group_unwrapped65, %dict_capacity_mask60
  %generic_dict_lookup_group_pointer67 = getelementptr i8, ptr %mutable_ptr26, i64 %generic_dict_lookup_group_start66
  %generic_dict_lookup_group_controls68 = load <16 x i8>, ptr %generic_dict_lookup_group_pointer67, align 1
  %generic_dict_lookup_group_h2_seed69 = insertelement <16 x i8> poison, i8 %dict_h2_byte59, i64 0
  %generic_dict_lookup_group_h2_vector70 = shufflevector <16 x i8> %generic_dict_lookup_group_h2_seed69, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_lookup_group_matches_vector71 = icmp eq <16 x i8> %generic_dict_lookup_group_controls68, %generic_dict_lookup_group_h2_vector70
  %generic_dict_lookup_group_match_bits72 = bitcast <16 x i1> %generic_dict_lookup_group_matches_vector71 to i16
  %generic_dict_lookup_group_empty_vector73 = icmp eq <16 x i8> %generic_dict_lookup_group_controls68, zeroinitializer
  %generic_dict_lookup_group_empty_bits74 = bitcast <16 x i1> %generic_dict_lookup_group_empty_vector73 to i16
  br label %bb_generic_dict_lookup_candidate_loop12

bb_generic_dict_lookup_candidate_loop12:
  %generic_dict_lookup_candidate_bits75 = phi i16 [ %generic_dict_lookup_group_match_bits72, %bb_generic_dict_lookup_group_body11 ], [ %generic_dict_lookup_candidate_cleared_bits76, %bb_generic_dict_lookup_candidate_next14 ]
  %generic_dict_lookup_has_candidate77 = icmp ne i16 %generic_dict_lookup_candidate_bits75, 0
  br i1 %generic_dict_lookup_has_candidate77, label %bb_generic_dict_lookup_candidate_body13, label %bb_generic_dict_lookup_group_decision15

bb_generic_dict_lookup_candidate_body13:
  %generic_dict_lookup_candidate_offset1678 = call i16 @llvm.cttz.i16(i16 %generic_dict_lookup_candidate_bits75, i1 false)
  %generic_dict_lookup_candidate_offset79 = zext i16 %generic_dict_lookup_candidate_offset1678 to i64
  %generic_dict_lookup_candidate_unwrapped80 = add i64 %generic_dict_lookup_group_start66, %generic_dict_lookup_candidate_offset79
  %generic_dict_lookup_candidate_slot81 = and i64 %generic_dict_lookup_candidate_unwrapped80, %dict_capacity_mask60
  %generic_dict_lookup_key_entries_offset_mirror82 = add i64 %mutable_capacity28, 23
  %generic_dict_lookup_key_entries_offset83 = and i64 %generic_dict_lookup_key_entries_offset_mirror82, -8
  %generic_dict_lookup_key_entries84 = getelementptr i8, ptr %mutable_ptr26, i64 %generic_dict_lookup_key_entries_offset83
  %generic_dict_lookup_key_entry_offset85 = mul i64 %generic_dict_lookup_candidate_slot81, 4
  %generic_dict_lookup_key_slot86 = getelementptr i8, ptr %generic_dict_lookup_key_entries84, i64 %generic_dict_lookup_key_entry_offset85
  %generic_dict_lookup_key87 = load i32, ptr %generic_dict_lookup_key_slot86, align 4
  %generic_dict_key_equal88 = icmp eq i32 %generic_dict_lookup_key87, 20
  br i1 %generic_dict_key_equal88, label %bb_generic_dict_lookup_group_match16, label %bb_generic_dict_lookup_candidate_next14

bb_generic_dict_lookup_candidate_next14:
  %generic_dict_lookup_candidate_bits_minus_one89 = sub i16 %generic_dict_lookup_candidate_bits75, 1
  %generic_dict_lookup_candidate_cleared_bits76 = and i16 %generic_dict_lookup_candidate_bits75, %generic_dict_lookup_candidate_bits_minus_one89
  br label %bb_generic_dict_lookup_candidate_loop12

bb_generic_dict_lookup_group_decision15:
  %generic_dict_lookup_group_has_empty90 = icmp ne i16 %generic_dict_lookup_group_empty_bits74, 0
  br i1 %generic_dict_lookup_group_has_empty90, label %bb_generic_dict_lookup_group_miss18, label %bb_generic_dict_lookup_group_next17

bb_generic_dict_lookup_group_next17:
  %generic_dict_lookup_group_next_probe62 = add i64 %generic_dict_lookup_group_probe63, 16
  br label %bb_generic_dict_lookup_group10

bb_generic_dict_lookup_group_match16:
  br label %bb_generic_dict_lookup_group_done19

bb_generic_dict_lookup_group_miss18:
  br label %bb_generic_dict_lookup_group_done19

bb_generic_dict_lookup_group_done19:
  %generic_dict_lookup_found91 = phi i1 [ true, %bb_generic_dict_lookup_group_match16 ], [ false, %bb_generic_dict_lookup_group_miss18 ]
  %generic_dict_lookup_slot_result92 = phi i64 [ %generic_dict_lookup_candidate_slot81, %bb_generic_dict_lookup_group_match16 ], [ 0, %bb_generic_dict_lookup_group_miss18 ]
  br label %bb_generic_dict_lookup_first_done9

bb_generic_dict_lookup_first_done9:
  %generic_dict_lookup_first_found93 = phi i1 [ true, %bb_generic_dict_lookup_first_match6 ], [ false, %bb_generic_dict_lookup_first_miss8 ], [ %generic_dict_lookup_found91, %bb_generic_dict_lookup_group_done19 ]
  %generic_dict_lookup_first_slot_result94 = phi i64 [ %dict_start_slot39, %bb_generic_dict_lookup_first_match6 ], [ 0, %bb_generic_dict_lookup_first_miss8 ], [ %generic_dict_lookup_slot_result92, %bb_generic_dict_lookup_group_done19 ]
  %mutable_ptr95 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len96 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity97 = load i64, ptr %mutable_capacity_addr6, align 8
  %hash_key98 = sext i32 20 to i64
  %hash_high100 = lshr i64 %hash_key98, 32
  %hash_fold99 = xor i64 %hash_key98, %hash_high100
  %hash101 = mul i64 %hash_fold99, -7046029254386353131
  %dict_h2_shifted102 = lshr i64 %hash101, 57
  %dict_h2_raw103 = and i64 %dict_h2_shifted102, 127
  %dict_h2_zero104 = icmp eq i64 %dict_h2_raw103, 0
  %dict_h2105 = select i1 %dict_h2_zero104, i64 1, i64 %dict_h2_raw103
  %dict_h2_byte106 = trunc i64 %dict_h2105 to i8
  %dict_capacity_mask107 = sub i64 %mutable_capacity97, 1
  %dict_start_slot108 = and i64 %hash101, %dict_capacity_mask107
  %generic_dict_control_slot109 = getelementptr i8, ptr %mutable_ptr95, i64 %dict_start_slot108
  %generic_dict_control110 = load i8, ptr %generic_dict_control_slot109, align 1
  %generic_dict_lookup_first_empty111 = icmp eq i8 %generic_dict_control110, 0
  br i1 %generic_dict_lookup_first_empty111, label %bb_generic_dict_lookup_first_miss24, label %bb_generic_dict_lookup_first_occupied20

bb_generic_dict_lookup_first_occupied20:
  %generic_dict_lookup_first_h2112 = icmp eq i8 %generic_dict_control110, %dict_h2_byte106
  br i1 %generic_dict_lookup_first_h2112, label %bb_generic_dict_lookup_first_compare21, label %bb_generic_dict_lookup_first_fallback23

bb_generic_dict_lookup_first_compare21:
  %generic_dict_lookup_first_key_entries_offset_mirror113 = add i64 %mutable_capacity97, 23
  %generic_dict_lookup_first_key_entries_offset114 = and i64 %generic_dict_lookup_first_key_entries_offset_mirror113, -8
  %generic_dict_lookup_first_key_entries115 = getelementptr i8, ptr %mutable_ptr95, i64 %generic_dict_lookup_first_key_entries_offset114
  %generic_dict_lookup_first_key_entry_offset116 = mul i64 %dict_start_slot108, 4
  %generic_dict_lookup_first_key_slot117 = getelementptr i8, ptr %generic_dict_lookup_first_key_entries115, i64 %generic_dict_lookup_first_key_entry_offset116
  %generic_dict_lookup_first_key118 = load i32, ptr %generic_dict_lookup_first_key_slot117, align 4
  %generic_dict_key_equal119 = icmp eq i32 %generic_dict_lookup_first_key118, 20
  br i1 %generic_dict_key_equal119, label %bb_generic_dict_lookup_first_match22, label %bb_generic_dict_lookup_first_fallback23

bb_generic_dict_lookup_first_match22:
  br label %bb_generic_dict_lookup_first_done25

bb_generic_dict_lookup_first_miss24:
  br label %bb_generic_dict_lookup_first_done25

bb_generic_dict_lookup_first_fallback23:
  %hash_key120 = sext i32 20 to i64
  %hash_high122 = lshr i64 %hash_key120, 32
  %hash_fold121 = xor i64 %hash_key120, %hash_high122
  %hash123 = mul i64 %hash_fold121, -7046029254386353131
  %dict_h2_shifted124 = lshr i64 %hash123, 57
  %dict_h2_raw125 = and i64 %dict_h2_shifted124, 127
  %dict_h2_zero126 = icmp eq i64 %dict_h2_raw125, 0
  %dict_h2127 = select i1 %dict_h2_zero126, i64 1, i64 %dict_h2_raw125
  %dict_h2_byte128 = trunc i64 %dict_h2127 to i8
  %dict_capacity_mask129 = sub i64 %mutable_capacity97, 1
  %dict_start_slot130 = and i64 %hash123, %dict_capacity_mask129
  br label %bb_generic_dict_lookup_group26

bb_generic_dict_lookup_group26:
  %generic_dict_lookup_group_probe132 = phi i64 [ 0, %bb_generic_dict_lookup_first_fallback23 ], [ %generic_dict_lookup_group_next_probe131, %bb_generic_dict_lookup_group_next33 ]
  %generic_dict_lookup_group_active133 = icmp ult i64 %generic_dict_lookup_group_probe132, %mutable_capacity97
  br i1 %generic_dict_lookup_group_active133, label %bb_generic_dict_lookup_group_body27, label %bb_generic_dict_lookup_group_miss34

bb_generic_dict_lookup_group_body27:
  %generic_dict_lookup_group_unwrapped134 = add i64 %dict_start_slot130, %generic_dict_lookup_group_probe132
  %generic_dict_lookup_group_start135 = and i64 %generic_dict_lookup_group_unwrapped134, %dict_capacity_mask129
  %generic_dict_lookup_group_pointer136 = getelementptr i8, ptr %mutable_ptr95, i64 %generic_dict_lookup_group_start135
  %generic_dict_lookup_group_controls137 = load <16 x i8>, ptr %generic_dict_lookup_group_pointer136, align 1
  %generic_dict_lookup_group_h2_seed138 = insertelement <16 x i8> poison, i8 %dict_h2_byte128, i64 0
  %generic_dict_lookup_group_h2_vector139 = shufflevector <16 x i8> %generic_dict_lookup_group_h2_seed138, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_lookup_group_matches_vector140 = icmp eq <16 x i8> %generic_dict_lookup_group_controls137, %generic_dict_lookup_group_h2_vector139
  %generic_dict_lookup_group_match_bits141 = bitcast <16 x i1> %generic_dict_lookup_group_matches_vector140 to i16
  %generic_dict_lookup_group_empty_vector142 = icmp eq <16 x i8> %generic_dict_lookup_group_controls137, zeroinitializer
  %generic_dict_lookup_group_empty_bits143 = bitcast <16 x i1> %generic_dict_lookup_group_empty_vector142 to i16
  br label %bb_generic_dict_lookup_candidate_loop28

bb_generic_dict_lookup_candidate_loop28:
  %generic_dict_lookup_candidate_bits144 = phi i16 [ %generic_dict_lookup_group_match_bits141, %bb_generic_dict_lookup_group_body27 ], [ %generic_dict_lookup_candidate_cleared_bits145, %bb_generic_dict_lookup_candidate_next30 ]
  %generic_dict_lookup_has_candidate146 = icmp ne i16 %generic_dict_lookup_candidate_bits144, 0
  br i1 %generic_dict_lookup_has_candidate146, label %bb_generic_dict_lookup_candidate_body29, label %bb_generic_dict_lookup_group_decision31

bb_generic_dict_lookup_candidate_body29:
  %generic_dict_lookup_candidate_offset16147 = call i16 @llvm.cttz.i16(i16 %generic_dict_lookup_candidate_bits144, i1 false)
  %generic_dict_lookup_candidate_offset148 = zext i16 %generic_dict_lookup_candidate_offset16147 to i64
  %generic_dict_lookup_candidate_unwrapped149 = add i64 %generic_dict_lookup_group_start135, %generic_dict_lookup_candidate_offset148
  %generic_dict_lookup_candidate_slot150 = and i64 %generic_dict_lookup_candidate_unwrapped149, %dict_capacity_mask129
  %generic_dict_lookup_key_entries_offset_mirror151 = add i64 %mutable_capacity97, 23
  %generic_dict_lookup_key_entries_offset152 = and i64 %generic_dict_lookup_key_entries_offset_mirror151, -8
  %generic_dict_lookup_key_entries153 = getelementptr i8, ptr %mutable_ptr95, i64 %generic_dict_lookup_key_entries_offset152
  %generic_dict_lookup_key_entry_offset154 = mul i64 %generic_dict_lookup_candidate_slot150, 4
  %generic_dict_lookup_key_slot155 = getelementptr i8, ptr %generic_dict_lookup_key_entries153, i64 %generic_dict_lookup_key_entry_offset154
  %generic_dict_lookup_key156 = load i32, ptr %generic_dict_lookup_key_slot155, align 4
  %generic_dict_key_equal157 = icmp eq i32 %generic_dict_lookup_key156, 20
  br i1 %generic_dict_key_equal157, label %bb_generic_dict_lookup_group_match32, label %bb_generic_dict_lookup_candidate_next30

bb_generic_dict_lookup_candidate_next30:
  %generic_dict_lookup_candidate_bits_minus_one158 = sub i16 %generic_dict_lookup_candidate_bits144, 1
  %generic_dict_lookup_candidate_cleared_bits145 = and i16 %generic_dict_lookup_candidate_bits144, %generic_dict_lookup_candidate_bits_minus_one158
  br label %bb_generic_dict_lookup_candidate_loop28

bb_generic_dict_lookup_group_decision31:
  %generic_dict_lookup_group_has_empty159 = icmp ne i16 %generic_dict_lookup_group_empty_bits143, 0
  br i1 %generic_dict_lookup_group_has_empty159, label %bb_generic_dict_lookup_group_miss34, label %bb_generic_dict_lookup_group_next33

bb_generic_dict_lookup_group_next33:
  %generic_dict_lookup_group_next_probe131 = add i64 %generic_dict_lookup_group_probe132, 16
  br label %bb_generic_dict_lookup_group26

bb_generic_dict_lookup_group_match32:
  br label %bb_generic_dict_lookup_group_done35

bb_generic_dict_lookup_group_miss34:
  br label %bb_generic_dict_lookup_group_done35

bb_generic_dict_lookup_group_done35:
  %generic_dict_lookup_found160 = phi i1 [ true, %bb_generic_dict_lookup_group_match32 ], [ false, %bb_generic_dict_lookup_group_miss34 ]
  %generic_dict_lookup_slot_result161 = phi i64 [ %generic_dict_lookup_candidate_slot150, %bb_generic_dict_lookup_group_match32 ], [ 0, %bb_generic_dict_lookup_group_miss34 ]
  br label %bb_generic_dict_lookup_first_done25

bb_generic_dict_lookup_first_done25:
  %generic_dict_lookup_first_found162 = phi i1 [ true, %bb_generic_dict_lookup_first_match22 ], [ false, %bb_generic_dict_lookup_first_miss24 ], [ %generic_dict_lookup_found160, %bb_generic_dict_lookup_group_done35 ]
  %generic_dict_lookup_first_slot_result163 = phi i64 [ %dict_start_slot108, %bb_generic_dict_lookup_first_match22 ], [ 0, %bb_generic_dict_lookup_first_miss24 ], [ %generic_dict_lookup_slot_result161, %bb_generic_dict_lookup_group_done35 ]
  br i1 %generic_dict_lookup_first_found162, label %bb_set_remove_found36, label %bb_set_remove_missing37

bb_set_remove_found36:
  %generic_dict_control_slot164 = getelementptr i8, ptr %mutable_ptr95, i64 %generic_dict_lookup_first_slot_result163
  store i8 -1, ptr %generic_dict_control_slot164, align 1
  %generic_dict_control_mirrored165 = icmp ult i64 %generic_dict_lookup_first_slot_result163, 16
  br i1 %generic_dict_control_mirrored165, label %bb_generic_dict_control_mirror41, label %bb_generic_dict_control_done42

bb_generic_dict_control_mirror41:
  %generic_dict_control_mirror_index166 = add i64 %mutable_capacity97, %generic_dict_lookup_first_slot_result163
  %generic_dict_control_mirror_slot167 = getelementptr i8, ptr %mutable_ptr95, i64 %generic_dict_control_mirror_index166
  store i8 -1, ptr %generic_dict_control_mirror_slot167, align 1
  br label %bb_generic_dict_control_done42

bb_generic_dict_control_done42:
  %set_remove_length168 = sub i64 %mutable_len96, 1
  %set_remove_compact_threshold169 = lshr i64 %mutable_capacity97, 3
  %set_remove_should_compact170 = icmp eq i64 %set_remove_length168, %set_remove_compact_threshold169
  br i1 %set_remove_should_compact170, label %bb_set_remove_compact39, label %bb_set_remove_keep_tombstone38

bb_set_remove_keep_tombstone38:
  br label %bb_set_remove_done40

bb_set_remove_compact39:
  %generic_dict_entries_offset_mirror171 = add i64 %mutable_capacity97, 23
  %generic_dict_entries_offset172 = and i64 %generic_dict_entries_offset_mirror171, -8
  %generic_dict_entries_bytes173 = mul i64 %mutable_capacity97, 4
  %generic_dict_bytes174 = add i64 %generic_dict_entries_offset172, %generic_dict_entries_bytes173
  %heap175 = call ptr @sollang_alloc(i64 %generic_dict_bytes174)
  %heap_ok176 = icmp ne ptr %heap175, null
  br i1 %heap_ok176, label %bb_alloc_ok43, label %bb_alloc_fail44

bb_alloc_fail44:
  %trap_stderr177 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr177, ptr @.slg.str.suffix.0, i32 20, ptr %trap_written178, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok43:
  %generic_dict_control_bytes179 = add i64 %mutable_capacity97, 16
  call void @llvm.memset.p0.i64(ptr %heap175, i8 0, i64 %generic_dict_control_bytes179, i1 false)
  br label %bb_set_compact45

bb_set_compact45:
  %set_compact_index181 = phi i64 [ 0, %bb_alloc_ok43 ], [ %set_compact_next_index180, %bb_set_compact_next48 ]
  %set_compact_active182 = icmp ult i64 %set_compact_index181, %mutable_capacity97
  br i1 %set_compact_active182, label %bb_set_compact_body46, label %bb_set_compact_done49

bb_set_compact_body46:
  %generic_dict_control_slot183 = getelementptr i8, ptr %mutable_ptr95, i64 %set_compact_index181
  %generic_dict_control184 = load i8, ptr %generic_dict_control_slot183, align 1
  %set_compact_occupied185 = icmp sgt i8 %generic_dict_control184, 0
  br i1 %set_compact_occupied185, label %bb_set_compact_move47, label %bb_set_compact_next48

bb_set_compact_move47:
  %set_compact_key_entries_offset_mirror186 = add i64 %mutable_capacity97, 23
  %set_compact_key_entries_offset187 = and i64 %set_compact_key_entries_offset_mirror186, -8
  %set_compact_key_entries188 = getelementptr i8, ptr %mutable_ptr95, i64 %set_compact_key_entries_offset187
  %set_compact_key_entry_offset189 = mul i64 %set_compact_index181, 4
  %set_compact_key_slot190 = getelementptr i8, ptr %set_compact_key_entries188, i64 %set_compact_key_entry_offset189
  %set_compact_key191 = load i32, ptr %set_compact_key_slot190, align 4
  %hash_key192 = sext i32 %set_compact_key191 to i64
  %hash_high194 = lshr i64 %hash_key192, 32
  %hash_fold193 = xor i64 %hash_key192, %hash_high194
  %hash195 = mul i64 %hash_fold193, -7046029254386353131
  %dict_h2_shifted196 = lshr i64 %hash195, 57
  %dict_h2_raw197 = and i64 %dict_h2_shifted196, 127
  %dict_h2_zero198 = icmp eq i64 %dict_h2_raw197, 0
  %dict_h2199 = select i1 %dict_h2_zero198, i64 1, i64 %dict_h2_raw197
  %dict_h2_byte200 = trunc i64 %dict_h2199 to i8
  %dict_capacity_mask201 = sub i64 %mutable_capacity97, 1
  %dict_start_slot202 = and i64 %hash195, %dict_capacity_mask201
  %generic_dict_insert_has_capacity203 = icmp ugt i64 %mutable_capacity97, 0
  br i1 %generic_dict_insert_has_capacity203, label %bb_generic_dict_insert_first56, label %bb_generic_dict_insert_no_capacity57

bb_generic_dict_insert_no_capacity57:
  br label %bb_generic_dict_insert_first_done55

bb_generic_dict_insert_first56:
  %generic_dict_control_slot204 = getelementptr i8, ptr %heap175, i64 %dict_start_slot202
  %generic_dict_control205 = load i8, ptr %generic_dict_control_slot204, align 1
  %generic_dict_insert_first_empty206 = icmp eq i8 %generic_dict_control205, 0
  br i1 %generic_dict_insert_first_empty206, label %bb_generic_dict_insert_first_vacant54, label %bb_generic_dict_insert_first_occupied50

bb_generic_dict_insert_first_occupied50:
  %generic_dict_insert_first_h2207 = icmp eq i8 %generic_dict_control205, %dict_h2_byte200
  br i1 %generic_dict_insert_first_h2207, label %bb_generic_dict_insert_first_compare51, label %bb_generic_dict_insert_first_fallback53

bb_generic_dict_insert_first_compare51:
  %generic_dict_insert_first_key_entries_offset_mirror208 = add i64 %mutable_capacity97, 23
  %generic_dict_insert_first_key_entries_offset209 = and i64 %generic_dict_insert_first_key_entries_offset_mirror208, -8
  %generic_dict_insert_first_key_entries210 = getelementptr i8, ptr %heap175, i64 %generic_dict_insert_first_key_entries_offset209
  %generic_dict_insert_first_key_entry_offset211 = mul i64 %dict_start_slot202, 4
  %generic_dict_insert_first_key_slot212 = getelementptr i8, ptr %generic_dict_insert_first_key_entries210, i64 %generic_dict_insert_first_key_entry_offset211
  %generic_dict_insert_first_key213 = load i32, ptr %generic_dict_insert_first_key_slot212, align 4
  %generic_dict_key_equal214 = icmp eq i32 %generic_dict_insert_first_key213, %set_compact_key191
  br i1 %generic_dict_key_equal214, label %bb_generic_dict_insert_first_match52, label %bb_generic_dict_insert_first_fallback53

bb_generic_dict_insert_first_match52:
  br label %bb_generic_dict_insert_first_done55

bb_generic_dict_insert_first_vacant54:
  br label %bb_generic_dict_insert_first_done55

bb_generic_dict_insert_first_fallback53:
  %hash_key215 = sext i32 %set_compact_key191 to i64
  %hash_high217 = lshr i64 %hash_key215, 32
  %hash_fold216 = xor i64 %hash_key215, %hash_high217
  %hash218 = mul i64 %hash_fold216, -7046029254386353131
  %dict_h2_shifted219 = lshr i64 %hash218, 57
  %dict_h2_raw220 = and i64 %dict_h2_shifted219, 127
  %dict_h2_zero221 = icmp eq i64 %dict_h2_raw220, 0
  %dict_h2222 = select i1 %dict_h2_zero221, i64 1, i64 %dict_h2_raw220
  %dict_h2_byte223 = trunc i64 %dict_h2222 to i8
  %dict_capacity_mask224 = sub i64 %mutable_capacity97, 1
  %dict_start_slot225 = and i64 %hash218, %dict_capacity_mask224
  br label %bb_generic_dict_group_find58

bb_generic_dict_group_find58:
  %generic_dict_group_probe228 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback53 ], [ %generic_dict_group_next_probe226, %bb_generic_dict_group_next66 ]
  %generic_dict_group_deleted229 = phi i64 [ %mutable_capacity97, %bb_generic_dict_insert_first_fallback53 ], [ %generic_dict_group_next_deleted227, %bb_generic_dict_group_next66 ]
  %generic_dict_group_active230 = icmp ult i64 %generic_dict_group_probe228, %mutable_capacity97
  br i1 %generic_dict_group_active230, label %bb_generic_dict_group_body59, label %bb_generic_dict_group_miss67

bb_generic_dict_group_body59:
  %generic_dict_group_unwrapped231 = add i64 %dict_start_slot225, %generic_dict_group_probe228
  %generic_dict_group_start232 = and i64 %generic_dict_group_unwrapped231, %dict_capacity_mask224
  %generic_dict_group_pointer233 = getelementptr i8, ptr %heap175, i64 %generic_dict_group_start232
  %generic_dict_group_controls234 = load <16 x i8>, ptr %generic_dict_group_pointer233, align 1
  %generic_dict_group_h2_seed235 = insertelement <16 x i8> poison, i8 %dict_h2_byte223, i64 0
  %generic_dict_group_h2_vector236 = shufflevector <16 x i8> %generic_dict_group_h2_seed235, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector237 = icmp eq <16 x i8> %generic_dict_group_controls234, %generic_dict_group_h2_vector236
  %generic_dict_group_match_bits238 = bitcast <16 x i1> %generic_dict_group_matches_vector237 to i16
  %generic_dict_group_empty_vector239 = icmp eq <16 x i8> %generic_dict_group_controls234, zeroinitializer
  %generic_dict_group_empty_bits240 = bitcast <16 x i1> %generic_dict_group_empty_vector239 to i16
  %generic_dict_group_deleted_seed241 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector242 = shufflevector <16 x i8> %generic_dict_group_deleted_seed241, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches243 = icmp eq <16 x i8> %generic_dict_group_controls234, %generic_dict_group_deleted_vector242
  %generic_dict_group_deleted_bits244 = bitcast <16 x i1> %generic_dict_group_deleted_matches243 to i16
  %generic_dict_group_has_deleted245 = icmp ne i16 %generic_dict_group_deleted_bits244, 0
  %generic_dict_group_no_previous_deleted246 = icmp eq i64 %generic_dict_group_deleted229, %mutable_capacity97
  %generic_dict_group_capture_deleted247 = and i1 %generic_dict_group_has_deleted245, %generic_dict_group_no_previous_deleted246
  %generic_dict_group_deleted_offset16248 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits244, i1 false)
  %generic_dict_group_deleted_offset249 = zext i16 %generic_dict_group_deleted_offset16248 to i64
  %generic_dict_group_deleted_unwrapped250 = add i64 %generic_dict_group_start232, %generic_dict_group_deleted_offset249
  %generic_dict_group_deleted_slot251 = and i64 %generic_dict_group_deleted_unwrapped250, %dict_capacity_mask224
  %generic_dict_group_captured_deleted252 = select i1 %generic_dict_group_capture_deleted247, i64 %generic_dict_group_deleted_slot251, i64 %generic_dict_group_deleted229
  br label %bb_generic_dict_candidate_loop60

bb_generic_dict_candidate_loop60:
  %generic_dict_candidate_bits253 = phi i16 [ %generic_dict_group_match_bits238, %bb_generic_dict_group_body59 ], [ %generic_dict_candidate_cleared_bits254, %bb_generic_dict_candidate_next62 ]
  %generic_dict_has_candidate255 = icmp ne i16 %generic_dict_candidate_bits253, 0
  br i1 %generic_dict_has_candidate255, label %bb_generic_dict_candidate_body61, label %bb_generic_dict_group_decision63

bb_generic_dict_candidate_body61:
  %generic_dict_candidate_offset16256 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits253, i1 false)
  %generic_dict_candidate_offset257 = zext i16 %generic_dict_candidate_offset16256 to i64
  %generic_dict_candidate_unwrapped258 = add i64 %generic_dict_group_start232, %generic_dict_candidate_offset257
  %generic_dict_candidate_slot259 = and i64 %generic_dict_candidate_unwrapped258, %dict_capacity_mask224
  %generic_dict_key_entries_offset_mirror260 = add i64 %mutable_capacity97, 23
  %generic_dict_key_entries_offset261 = and i64 %generic_dict_key_entries_offset_mirror260, -8
  %generic_dict_key_entries262 = getelementptr i8, ptr %heap175, i64 %generic_dict_key_entries_offset261
  %generic_dict_key_entry_offset263 = mul i64 %generic_dict_candidate_slot259, 4
  %generic_dict_key_slot264 = getelementptr i8, ptr %generic_dict_key_entries262, i64 %generic_dict_key_entry_offset263
  %generic_dict_key265 = load i32, ptr %generic_dict_key_slot264, align 4
  %generic_dict_key_equal266 = icmp eq i32 %generic_dict_key265, %set_compact_key191
  br i1 %generic_dict_key_equal266, label %bb_generic_dict_group_match65, label %bb_generic_dict_candidate_next62

bb_generic_dict_candidate_next62:
  %generic_dict_candidate_bits_minus_one267 = sub i16 %generic_dict_candidate_bits253, 1
  %generic_dict_candidate_cleared_bits254 = and i16 %generic_dict_candidate_bits253, %generic_dict_candidate_bits_minus_one267
  br label %bb_generic_dict_candidate_loop60

bb_generic_dict_group_decision63:
  %generic_dict_group_has_empty268 = icmp ne i16 %generic_dict_group_empty_bits240, 0
  br i1 %generic_dict_group_has_empty268, label %bb_generic_dict_group_empty64, label %bb_generic_dict_group_next66

bb_generic_dict_group_empty64:
  %generic_dict_group_empty_offset16269 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits240, i1 false)
  %generic_dict_group_empty_offset270 = zext i16 %generic_dict_group_empty_offset16269 to i64
  %generic_dict_group_empty_unwrapped271 = add i64 %generic_dict_group_start232, %generic_dict_group_empty_offset270
  %generic_dict_group_empty_slot272 = and i64 %generic_dict_group_empty_unwrapped271, %dict_capacity_mask224
  %generic_dict_group_use_empty273 = icmp eq i64 %generic_dict_group_captured_deleted252, %mutable_capacity97
  %generic_dict_group_insertion_slot274 = select i1 %generic_dict_group_use_empty273, i64 %generic_dict_group_empty_slot272, i64 %generic_dict_group_captured_deleted252
  br label %bb_generic_dict_group_done68

bb_generic_dict_group_match65:
  br label %bb_generic_dict_group_done68

bb_generic_dict_group_next66:
  %generic_dict_group_next_probe226 = add i64 %generic_dict_group_probe228, 16
  %generic_dict_group_next_deleted227 = add i64 %generic_dict_group_captured_deleted252, 0
  br label %bb_generic_dict_group_find58

bb_generic_dict_group_miss67:
  %generic_dict_group_miss_no_deleted275 = icmp eq i64 %generic_dict_group_deleted229, %mutable_capacity97
  %generic_dict_group_miss_slot276 = select i1 %generic_dict_group_miss_no_deleted275, i64 0, i64 %generic_dict_group_deleted229
  br label %bb_generic_dict_group_done68

bb_generic_dict_group_done68:
  %generic_dict_find_found277 = phi i1 [ false, %bb_generic_dict_group_empty64 ], [ true, %bb_generic_dict_group_match65 ], [ false, %bb_generic_dict_group_miss67 ]
  %generic_dict_find_slot_result278 = phi i64 [ %generic_dict_group_insertion_slot274, %bb_generic_dict_group_empty64 ], [ %generic_dict_candidate_slot259, %bb_generic_dict_group_match65 ], [ %generic_dict_group_miss_slot276, %bb_generic_dict_group_miss67 ]
  br label %bb_generic_dict_insert_first_done55

bb_generic_dict_insert_first_done55:
  %generic_dict_insert_first_found279 = phi i1 [ true, %bb_generic_dict_insert_first_match52 ], [ false, %bb_generic_dict_insert_first_vacant54 ], [ %generic_dict_find_found277, %bb_generic_dict_group_done68 ], [ false, %bb_generic_dict_insert_no_capacity57 ]
  %generic_dict_insert_first_slot_result280 = phi i64 [ %dict_start_slot202, %bb_generic_dict_insert_first_match52 ], [ %dict_start_slot202, %bb_generic_dict_insert_first_vacant54 ], [ %generic_dict_find_slot_result278, %bb_generic_dict_group_done68 ], [ 0, %bb_generic_dict_insert_no_capacity57 ]
  %set_key_entries_offset_mirror281 = add i64 %mutable_capacity97, 23
  %set_key_entries_offset282 = and i64 %set_key_entries_offset_mirror281, -8
  %set_key_entries283 = getelementptr i8, ptr %heap175, i64 %set_key_entries_offset282
  %set_key_entry_offset284 = mul i64 %generic_dict_insert_first_slot_result280, 4
  %set_key_slot285 = getelementptr i8, ptr %set_key_entries283, i64 %set_key_entry_offset284
  store i32 %set_compact_key191, ptr %set_key_slot285, align 4
  %generic_dict_control_slot286 = getelementptr i8, ptr %heap175, i64 %generic_dict_insert_first_slot_result280
  store i8 %dict_h2_byte200, ptr %generic_dict_control_slot286, align 1
  %generic_dict_control_mirrored287 = icmp ult i64 %generic_dict_insert_first_slot_result280, 16
  br i1 %generic_dict_control_mirrored287, label %bb_generic_dict_control_mirror69, label %bb_generic_dict_control_done70

bb_generic_dict_control_mirror69:
  %generic_dict_control_mirror_index288 = add i64 %mutable_capacity97, %generic_dict_insert_first_slot_result280
  %generic_dict_control_mirror_slot289 = getelementptr i8, ptr %heap175, i64 %generic_dict_control_mirror_index288
  store i8 %dict_h2_byte200, ptr %generic_dict_control_mirror_slot289, align 1
  br label %bb_generic_dict_control_done70

bb_generic_dict_control_done70:
  br label %bb_set_compact_next48

bb_set_compact_next48:
  %set_compact_next_index180 = add i64 %set_compact_index181, 1
  br label %bb_set_compact45

bb_set_compact_done49:
  call void @sollang_free(ptr %mutable_ptr95)
  br label %bb_set_remove_done40

bb_set_remove_missing37:
  br label %bb_set_remove_done40

bb_set_remove_done40:
  %set_pointer290 = phi ptr [ %mutable_ptr95, %bb_set_remove_keep_tombstone38 ], [ %heap175, %bb_set_compact_done49 ], [ %mutable_ptr95, %bb_set_remove_missing37 ]
  %set_length291 = phi i64 [ %set_remove_length168, %bb_set_remove_keep_tombstone38 ], [ %set_remove_length168, %bb_set_compact_done49 ], [ %mutable_len96, %bb_set_remove_missing37 ]
  %set_removed292 = phi i1 [ true, %bb_set_remove_keep_tombstone38 ], [ true, %bb_set_compact_done49 ], [ false, %bb_set_remove_missing37 ]
  store ptr %set_pointer290, ptr %mutable_ptr_addr4, align 8
  store i64 %set_length291, ptr %mutable_len_addr5, align 8
  store i64 %mutable_capacity97, ptr %mutable_capacity_addr6, align 8
  %mutable_ptr293 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len294 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity295 = load i64, ptr %mutable_capacity_addr6, align 8
  %hash_key296 = sext i32 20 to i64
  %hash_high298 = lshr i64 %hash_key296, 32
  %hash_fold297 = xor i64 %hash_key296, %hash_high298
  %hash299 = mul i64 %hash_fold297, -7046029254386353131
  %dict_h2_shifted300 = lshr i64 %hash299, 57
  %dict_h2_raw301 = and i64 %dict_h2_shifted300, 127
  %dict_h2_zero302 = icmp eq i64 %dict_h2_raw301, 0
  %dict_h2303 = select i1 %dict_h2_zero302, i64 1, i64 %dict_h2_raw301
  %dict_h2_byte304 = trunc i64 %dict_h2303 to i8
  %dict_capacity_mask305 = sub i64 %mutable_capacity295, 1
  %dict_start_slot306 = and i64 %hash299, %dict_capacity_mask305
  %generic_dict_control_slot307 = getelementptr i8, ptr %mutable_ptr293, i64 %dict_start_slot306
  %generic_dict_control308 = load i8, ptr %generic_dict_control_slot307, align 1
  %generic_dict_lookup_first_empty309 = icmp eq i8 %generic_dict_control308, 0
  br i1 %generic_dict_lookup_first_empty309, label %bb_generic_dict_lookup_first_miss75, label %bb_generic_dict_lookup_first_occupied71

bb_generic_dict_lookup_first_occupied71:
  %generic_dict_lookup_first_h2310 = icmp eq i8 %generic_dict_control308, %dict_h2_byte304
  br i1 %generic_dict_lookup_first_h2310, label %bb_generic_dict_lookup_first_compare72, label %bb_generic_dict_lookup_first_fallback74

bb_generic_dict_lookup_first_compare72:
  %generic_dict_lookup_first_key_entries_offset_mirror311 = add i64 %mutable_capacity295, 23
  %generic_dict_lookup_first_key_entries_offset312 = and i64 %generic_dict_lookup_first_key_entries_offset_mirror311, -8
  %generic_dict_lookup_first_key_entries313 = getelementptr i8, ptr %mutable_ptr293, i64 %generic_dict_lookup_first_key_entries_offset312
  %generic_dict_lookup_first_key_entry_offset314 = mul i64 %dict_start_slot306, 4
  %generic_dict_lookup_first_key_slot315 = getelementptr i8, ptr %generic_dict_lookup_first_key_entries313, i64 %generic_dict_lookup_first_key_entry_offset314
  %generic_dict_lookup_first_key316 = load i32, ptr %generic_dict_lookup_first_key_slot315, align 4
  %generic_dict_key_equal317 = icmp eq i32 %generic_dict_lookup_first_key316, 20
  br i1 %generic_dict_key_equal317, label %bb_generic_dict_lookup_first_match73, label %bb_generic_dict_lookup_first_fallback74

bb_generic_dict_lookup_first_match73:
  br label %bb_generic_dict_lookup_first_done76

bb_generic_dict_lookup_first_miss75:
  br label %bb_generic_dict_lookup_first_done76

bb_generic_dict_lookup_first_fallback74:
  %hash_key318 = sext i32 20 to i64
  %hash_high320 = lshr i64 %hash_key318, 32
  %hash_fold319 = xor i64 %hash_key318, %hash_high320
  %hash321 = mul i64 %hash_fold319, -7046029254386353131
  %dict_h2_shifted322 = lshr i64 %hash321, 57
  %dict_h2_raw323 = and i64 %dict_h2_shifted322, 127
  %dict_h2_zero324 = icmp eq i64 %dict_h2_raw323, 0
  %dict_h2325 = select i1 %dict_h2_zero324, i64 1, i64 %dict_h2_raw323
  %dict_h2_byte326 = trunc i64 %dict_h2325 to i8
  %dict_capacity_mask327 = sub i64 %mutable_capacity295, 1
  %dict_start_slot328 = and i64 %hash321, %dict_capacity_mask327
  br label %bb_generic_dict_lookup_group77

bb_generic_dict_lookup_group77:
  %generic_dict_lookup_group_probe330 = phi i64 [ 0, %bb_generic_dict_lookup_first_fallback74 ], [ %generic_dict_lookup_group_next_probe329, %bb_generic_dict_lookup_group_next84 ]
  %generic_dict_lookup_group_active331 = icmp ult i64 %generic_dict_lookup_group_probe330, %mutable_capacity295
  br i1 %generic_dict_lookup_group_active331, label %bb_generic_dict_lookup_group_body78, label %bb_generic_dict_lookup_group_miss85

bb_generic_dict_lookup_group_body78:
  %generic_dict_lookup_group_unwrapped332 = add i64 %dict_start_slot328, %generic_dict_lookup_group_probe330
  %generic_dict_lookup_group_start333 = and i64 %generic_dict_lookup_group_unwrapped332, %dict_capacity_mask327
  %generic_dict_lookup_group_pointer334 = getelementptr i8, ptr %mutable_ptr293, i64 %generic_dict_lookup_group_start333
  %generic_dict_lookup_group_controls335 = load <16 x i8>, ptr %generic_dict_lookup_group_pointer334, align 1
  %generic_dict_lookup_group_h2_seed336 = insertelement <16 x i8> poison, i8 %dict_h2_byte326, i64 0
  %generic_dict_lookup_group_h2_vector337 = shufflevector <16 x i8> %generic_dict_lookup_group_h2_seed336, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_lookup_group_matches_vector338 = icmp eq <16 x i8> %generic_dict_lookup_group_controls335, %generic_dict_lookup_group_h2_vector337
  %generic_dict_lookup_group_match_bits339 = bitcast <16 x i1> %generic_dict_lookup_group_matches_vector338 to i16
  %generic_dict_lookup_group_empty_vector340 = icmp eq <16 x i8> %generic_dict_lookup_group_controls335, zeroinitializer
  %generic_dict_lookup_group_empty_bits341 = bitcast <16 x i1> %generic_dict_lookup_group_empty_vector340 to i16
  br label %bb_generic_dict_lookup_candidate_loop79

bb_generic_dict_lookup_candidate_loop79:
  %generic_dict_lookup_candidate_bits342 = phi i16 [ %generic_dict_lookup_group_match_bits339, %bb_generic_dict_lookup_group_body78 ], [ %generic_dict_lookup_candidate_cleared_bits343, %bb_generic_dict_lookup_candidate_next81 ]
  %generic_dict_lookup_has_candidate344 = icmp ne i16 %generic_dict_lookup_candidate_bits342, 0
  br i1 %generic_dict_lookup_has_candidate344, label %bb_generic_dict_lookup_candidate_body80, label %bb_generic_dict_lookup_group_decision82

bb_generic_dict_lookup_candidate_body80:
  %generic_dict_lookup_candidate_offset16345 = call i16 @llvm.cttz.i16(i16 %generic_dict_lookup_candidate_bits342, i1 false)
  %generic_dict_lookup_candidate_offset346 = zext i16 %generic_dict_lookup_candidate_offset16345 to i64
  %generic_dict_lookup_candidate_unwrapped347 = add i64 %generic_dict_lookup_group_start333, %generic_dict_lookup_candidate_offset346
  %generic_dict_lookup_candidate_slot348 = and i64 %generic_dict_lookup_candidate_unwrapped347, %dict_capacity_mask327
  %generic_dict_lookup_key_entries_offset_mirror349 = add i64 %mutable_capacity295, 23
  %generic_dict_lookup_key_entries_offset350 = and i64 %generic_dict_lookup_key_entries_offset_mirror349, -8
  %generic_dict_lookup_key_entries351 = getelementptr i8, ptr %mutable_ptr293, i64 %generic_dict_lookup_key_entries_offset350
  %generic_dict_lookup_key_entry_offset352 = mul i64 %generic_dict_lookup_candidate_slot348, 4
  %generic_dict_lookup_key_slot353 = getelementptr i8, ptr %generic_dict_lookup_key_entries351, i64 %generic_dict_lookup_key_entry_offset352
  %generic_dict_lookup_key354 = load i32, ptr %generic_dict_lookup_key_slot353, align 4
  %generic_dict_key_equal355 = icmp eq i32 %generic_dict_lookup_key354, 20
  br i1 %generic_dict_key_equal355, label %bb_generic_dict_lookup_group_match83, label %bb_generic_dict_lookup_candidate_next81

bb_generic_dict_lookup_candidate_next81:
  %generic_dict_lookup_candidate_bits_minus_one356 = sub i16 %generic_dict_lookup_candidate_bits342, 1
  %generic_dict_lookup_candidate_cleared_bits343 = and i16 %generic_dict_lookup_candidate_bits342, %generic_dict_lookup_candidate_bits_minus_one356
  br label %bb_generic_dict_lookup_candidate_loop79

bb_generic_dict_lookup_group_decision82:
  %generic_dict_lookup_group_has_empty357 = icmp ne i16 %generic_dict_lookup_group_empty_bits341, 0
  br i1 %generic_dict_lookup_group_has_empty357, label %bb_generic_dict_lookup_group_miss85, label %bb_generic_dict_lookup_group_next84

bb_generic_dict_lookup_group_next84:
  %generic_dict_lookup_group_next_probe329 = add i64 %generic_dict_lookup_group_probe330, 16
  br label %bb_generic_dict_lookup_group77

bb_generic_dict_lookup_group_match83:
  br label %bb_generic_dict_lookup_group_done86

bb_generic_dict_lookup_group_miss85:
  br label %bb_generic_dict_lookup_group_done86

bb_generic_dict_lookup_group_done86:
  %generic_dict_lookup_found358 = phi i1 [ true, %bb_generic_dict_lookup_group_match83 ], [ false, %bb_generic_dict_lookup_group_miss85 ]
  %generic_dict_lookup_slot_result359 = phi i64 [ %generic_dict_lookup_candidate_slot348, %bb_generic_dict_lookup_group_match83 ], [ 0, %bb_generic_dict_lookup_group_miss85 ]
  br label %bb_generic_dict_lookup_first_done76

bb_generic_dict_lookup_first_done76:
  %generic_dict_lookup_first_found360 = phi i1 [ true, %bb_generic_dict_lookup_first_match73 ], [ false, %bb_generic_dict_lookup_first_miss75 ], [ %generic_dict_lookup_found358, %bb_generic_dict_lookup_group_done86 ]
  %generic_dict_lookup_first_slot_result361 = phi i64 [ %dict_start_slot306, %bb_generic_dict_lookup_first_match73 ], [ 0, %bb_generic_dict_lookup_first_miss75 ], [ %generic_dict_lookup_slot_result359, %bb_generic_dict_lookup_group_done86 ]
  br i1 %generic_dict_lookup_first_found360, label %bb_set_remove_found87, label %bb_set_remove_missing88

bb_set_remove_found87:
  %generic_dict_control_slot362 = getelementptr i8, ptr %mutable_ptr293, i64 %generic_dict_lookup_first_slot_result361
  store i8 -1, ptr %generic_dict_control_slot362, align 1
  %generic_dict_control_mirrored363 = icmp ult i64 %generic_dict_lookup_first_slot_result361, 16
  br i1 %generic_dict_control_mirrored363, label %bb_generic_dict_control_mirror92, label %bb_generic_dict_control_done93

bb_generic_dict_control_mirror92:
  %generic_dict_control_mirror_index364 = add i64 %mutable_capacity295, %generic_dict_lookup_first_slot_result361
  %generic_dict_control_mirror_slot365 = getelementptr i8, ptr %mutable_ptr293, i64 %generic_dict_control_mirror_index364
  store i8 -1, ptr %generic_dict_control_mirror_slot365, align 1
  br label %bb_generic_dict_control_done93

bb_generic_dict_control_done93:
  %set_remove_length366 = sub i64 %mutable_len294, 1
  %set_remove_compact_threshold367 = lshr i64 %mutable_capacity295, 3
  %set_remove_should_compact368 = icmp eq i64 %set_remove_length366, %set_remove_compact_threshold367
  br i1 %set_remove_should_compact368, label %bb_set_remove_compact90, label %bb_set_remove_keep_tombstone89

bb_set_remove_keep_tombstone89:
  br label %bb_set_remove_done91

bb_set_remove_compact90:
  %generic_dict_entries_offset_mirror369 = add i64 %mutable_capacity295, 23
  %generic_dict_entries_offset370 = and i64 %generic_dict_entries_offset_mirror369, -8
  %generic_dict_entries_bytes371 = mul i64 %mutable_capacity295, 4
  %generic_dict_bytes372 = add i64 %generic_dict_entries_offset370, %generic_dict_entries_bytes371
  %heap373 = call ptr @sollang_alloc(i64 %generic_dict_bytes372)
  %heap_ok374 = icmp ne ptr %heap373, null
  br i1 %heap_ok374, label %bb_alloc_ok94, label %bb_alloc_fail95

bb_alloc_fail95:
  %trap_stderr375 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr375, ptr @.slg.str.suffix.1, i32 20, ptr %trap_written376, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok94:
  %generic_dict_control_bytes377 = add i64 %mutable_capacity295, 16
  call void @llvm.memset.p0.i64(ptr %heap373, i8 0, i64 %generic_dict_control_bytes377, i1 false)
  br label %bb_set_compact96

bb_set_compact96:
  %set_compact_index379 = phi i64 [ 0, %bb_alloc_ok94 ], [ %set_compact_next_index378, %bb_set_compact_next99 ]
  %set_compact_active380 = icmp ult i64 %set_compact_index379, %mutable_capacity295
  br i1 %set_compact_active380, label %bb_set_compact_body97, label %bb_set_compact_done100

bb_set_compact_body97:
  %generic_dict_control_slot381 = getelementptr i8, ptr %mutable_ptr293, i64 %set_compact_index379
  %generic_dict_control382 = load i8, ptr %generic_dict_control_slot381, align 1
  %set_compact_occupied383 = icmp sgt i8 %generic_dict_control382, 0
  br i1 %set_compact_occupied383, label %bb_set_compact_move98, label %bb_set_compact_next99

bb_set_compact_move98:
  %set_compact_key_entries_offset_mirror384 = add i64 %mutable_capacity295, 23
  %set_compact_key_entries_offset385 = and i64 %set_compact_key_entries_offset_mirror384, -8
  %set_compact_key_entries386 = getelementptr i8, ptr %mutable_ptr293, i64 %set_compact_key_entries_offset385
  %set_compact_key_entry_offset387 = mul i64 %set_compact_index379, 4
  %set_compact_key_slot388 = getelementptr i8, ptr %set_compact_key_entries386, i64 %set_compact_key_entry_offset387
  %set_compact_key389 = load i32, ptr %set_compact_key_slot388, align 4
  %hash_key390 = sext i32 %set_compact_key389 to i64
  %hash_high392 = lshr i64 %hash_key390, 32
  %hash_fold391 = xor i64 %hash_key390, %hash_high392
  %hash393 = mul i64 %hash_fold391, -7046029254386353131
  %dict_h2_shifted394 = lshr i64 %hash393, 57
  %dict_h2_raw395 = and i64 %dict_h2_shifted394, 127
  %dict_h2_zero396 = icmp eq i64 %dict_h2_raw395, 0
  %dict_h2397 = select i1 %dict_h2_zero396, i64 1, i64 %dict_h2_raw395
  %dict_h2_byte398 = trunc i64 %dict_h2397 to i8
  %dict_capacity_mask399 = sub i64 %mutable_capacity295, 1
  %dict_start_slot400 = and i64 %hash393, %dict_capacity_mask399
  %generic_dict_insert_has_capacity401 = icmp ugt i64 %mutable_capacity295, 0
  br i1 %generic_dict_insert_has_capacity401, label %bb_generic_dict_insert_first107, label %bb_generic_dict_insert_no_capacity108

bb_generic_dict_insert_no_capacity108:
  br label %bb_generic_dict_insert_first_done106

bb_generic_dict_insert_first107:
  %generic_dict_control_slot402 = getelementptr i8, ptr %heap373, i64 %dict_start_slot400
  %generic_dict_control403 = load i8, ptr %generic_dict_control_slot402, align 1
  %generic_dict_insert_first_empty404 = icmp eq i8 %generic_dict_control403, 0
  br i1 %generic_dict_insert_first_empty404, label %bb_generic_dict_insert_first_vacant105, label %bb_generic_dict_insert_first_occupied101

bb_generic_dict_insert_first_occupied101:
  %generic_dict_insert_first_h2405 = icmp eq i8 %generic_dict_control403, %dict_h2_byte398
  br i1 %generic_dict_insert_first_h2405, label %bb_generic_dict_insert_first_compare102, label %bb_generic_dict_insert_first_fallback104

bb_generic_dict_insert_first_compare102:
  %generic_dict_insert_first_key_entries_offset_mirror406 = add i64 %mutable_capacity295, 23
  %generic_dict_insert_first_key_entries_offset407 = and i64 %generic_dict_insert_first_key_entries_offset_mirror406, -8
  %generic_dict_insert_first_key_entries408 = getelementptr i8, ptr %heap373, i64 %generic_dict_insert_first_key_entries_offset407
  %generic_dict_insert_first_key_entry_offset409 = mul i64 %dict_start_slot400, 4
  %generic_dict_insert_first_key_slot410 = getelementptr i8, ptr %generic_dict_insert_first_key_entries408, i64 %generic_dict_insert_first_key_entry_offset409
  %generic_dict_insert_first_key411 = load i32, ptr %generic_dict_insert_first_key_slot410, align 4
  %generic_dict_key_equal412 = icmp eq i32 %generic_dict_insert_first_key411, %set_compact_key389
  br i1 %generic_dict_key_equal412, label %bb_generic_dict_insert_first_match103, label %bb_generic_dict_insert_first_fallback104

bb_generic_dict_insert_first_match103:
  br label %bb_generic_dict_insert_first_done106

bb_generic_dict_insert_first_vacant105:
  br label %bb_generic_dict_insert_first_done106

bb_generic_dict_insert_first_fallback104:
  %hash_key413 = sext i32 %set_compact_key389 to i64
  %hash_high415 = lshr i64 %hash_key413, 32
  %hash_fold414 = xor i64 %hash_key413, %hash_high415
  %hash416 = mul i64 %hash_fold414, -7046029254386353131
  %dict_h2_shifted417 = lshr i64 %hash416, 57
  %dict_h2_raw418 = and i64 %dict_h2_shifted417, 127
  %dict_h2_zero419 = icmp eq i64 %dict_h2_raw418, 0
  %dict_h2420 = select i1 %dict_h2_zero419, i64 1, i64 %dict_h2_raw418
  %dict_h2_byte421 = trunc i64 %dict_h2420 to i8
  %dict_capacity_mask422 = sub i64 %mutable_capacity295, 1
  %dict_start_slot423 = and i64 %hash416, %dict_capacity_mask422
  br label %bb_generic_dict_group_find109

bb_generic_dict_group_find109:
  %generic_dict_group_probe426 = phi i64 [ 0, %bb_generic_dict_insert_first_fallback104 ], [ %generic_dict_group_next_probe424, %bb_generic_dict_group_next117 ]
  %generic_dict_group_deleted427 = phi i64 [ %mutable_capacity295, %bb_generic_dict_insert_first_fallback104 ], [ %generic_dict_group_next_deleted425, %bb_generic_dict_group_next117 ]
  %generic_dict_group_active428 = icmp ult i64 %generic_dict_group_probe426, %mutable_capacity295
  br i1 %generic_dict_group_active428, label %bb_generic_dict_group_body110, label %bb_generic_dict_group_miss118

bb_generic_dict_group_body110:
  %generic_dict_group_unwrapped429 = add i64 %dict_start_slot423, %generic_dict_group_probe426
  %generic_dict_group_start430 = and i64 %generic_dict_group_unwrapped429, %dict_capacity_mask422
  %generic_dict_group_pointer431 = getelementptr i8, ptr %heap373, i64 %generic_dict_group_start430
  %generic_dict_group_controls432 = load <16 x i8>, ptr %generic_dict_group_pointer431, align 1
  %generic_dict_group_h2_seed433 = insertelement <16 x i8> poison, i8 %dict_h2_byte421, i64 0
  %generic_dict_group_h2_vector434 = shufflevector <16 x i8> %generic_dict_group_h2_seed433, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_matches_vector435 = icmp eq <16 x i8> %generic_dict_group_controls432, %generic_dict_group_h2_vector434
  %generic_dict_group_match_bits436 = bitcast <16 x i1> %generic_dict_group_matches_vector435 to i16
  %generic_dict_group_empty_vector437 = icmp eq <16 x i8> %generic_dict_group_controls432, zeroinitializer
  %generic_dict_group_empty_bits438 = bitcast <16 x i1> %generic_dict_group_empty_vector437 to i16
  %generic_dict_group_deleted_seed439 = insertelement <16 x i8> poison, i8 -1, i64 0
  %generic_dict_group_deleted_vector440 = shufflevector <16 x i8> %generic_dict_group_deleted_seed439, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_group_deleted_matches441 = icmp eq <16 x i8> %generic_dict_group_controls432, %generic_dict_group_deleted_vector440
  %generic_dict_group_deleted_bits442 = bitcast <16 x i1> %generic_dict_group_deleted_matches441 to i16
  %generic_dict_group_has_deleted443 = icmp ne i16 %generic_dict_group_deleted_bits442, 0
  %generic_dict_group_no_previous_deleted444 = icmp eq i64 %generic_dict_group_deleted427, %mutable_capacity295
  %generic_dict_group_capture_deleted445 = and i1 %generic_dict_group_has_deleted443, %generic_dict_group_no_previous_deleted444
  %generic_dict_group_deleted_offset16446 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_deleted_bits442, i1 false)
  %generic_dict_group_deleted_offset447 = zext i16 %generic_dict_group_deleted_offset16446 to i64
  %generic_dict_group_deleted_unwrapped448 = add i64 %generic_dict_group_start430, %generic_dict_group_deleted_offset447
  %generic_dict_group_deleted_slot449 = and i64 %generic_dict_group_deleted_unwrapped448, %dict_capacity_mask422
  %generic_dict_group_captured_deleted450 = select i1 %generic_dict_group_capture_deleted445, i64 %generic_dict_group_deleted_slot449, i64 %generic_dict_group_deleted427
  br label %bb_generic_dict_candidate_loop111

bb_generic_dict_candidate_loop111:
  %generic_dict_candidate_bits451 = phi i16 [ %generic_dict_group_match_bits436, %bb_generic_dict_group_body110 ], [ %generic_dict_candidate_cleared_bits452, %bb_generic_dict_candidate_next113 ]
  %generic_dict_has_candidate453 = icmp ne i16 %generic_dict_candidate_bits451, 0
  br i1 %generic_dict_has_candidate453, label %bb_generic_dict_candidate_body112, label %bb_generic_dict_group_decision114

bb_generic_dict_candidate_body112:
  %generic_dict_candidate_offset16454 = call i16 @llvm.cttz.i16(i16 %generic_dict_candidate_bits451, i1 false)
  %generic_dict_candidate_offset455 = zext i16 %generic_dict_candidate_offset16454 to i64
  %generic_dict_candidate_unwrapped456 = add i64 %generic_dict_group_start430, %generic_dict_candidate_offset455
  %generic_dict_candidate_slot457 = and i64 %generic_dict_candidate_unwrapped456, %dict_capacity_mask422
  %generic_dict_key_entries_offset_mirror458 = add i64 %mutable_capacity295, 23
  %generic_dict_key_entries_offset459 = and i64 %generic_dict_key_entries_offset_mirror458, -8
  %generic_dict_key_entries460 = getelementptr i8, ptr %heap373, i64 %generic_dict_key_entries_offset459
  %generic_dict_key_entry_offset461 = mul i64 %generic_dict_candidate_slot457, 4
  %generic_dict_key_slot462 = getelementptr i8, ptr %generic_dict_key_entries460, i64 %generic_dict_key_entry_offset461
  %generic_dict_key463 = load i32, ptr %generic_dict_key_slot462, align 4
  %generic_dict_key_equal464 = icmp eq i32 %generic_dict_key463, %set_compact_key389
  br i1 %generic_dict_key_equal464, label %bb_generic_dict_group_match116, label %bb_generic_dict_candidate_next113

bb_generic_dict_candidate_next113:
  %generic_dict_candidate_bits_minus_one465 = sub i16 %generic_dict_candidate_bits451, 1
  %generic_dict_candidate_cleared_bits452 = and i16 %generic_dict_candidate_bits451, %generic_dict_candidate_bits_minus_one465
  br label %bb_generic_dict_candidate_loop111

bb_generic_dict_group_decision114:
  %generic_dict_group_has_empty466 = icmp ne i16 %generic_dict_group_empty_bits438, 0
  br i1 %generic_dict_group_has_empty466, label %bb_generic_dict_group_empty115, label %bb_generic_dict_group_next117

bb_generic_dict_group_empty115:
  %generic_dict_group_empty_offset16467 = call i16 @llvm.cttz.i16(i16 %generic_dict_group_empty_bits438, i1 false)
  %generic_dict_group_empty_offset468 = zext i16 %generic_dict_group_empty_offset16467 to i64
  %generic_dict_group_empty_unwrapped469 = add i64 %generic_dict_group_start430, %generic_dict_group_empty_offset468
  %generic_dict_group_empty_slot470 = and i64 %generic_dict_group_empty_unwrapped469, %dict_capacity_mask422
  %generic_dict_group_use_empty471 = icmp eq i64 %generic_dict_group_captured_deleted450, %mutable_capacity295
  %generic_dict_group_insertion_slot472 = select i1 %generic_dict_group_use_empty471, i64 %generic_dict_group_empty_slot470, i64 %generic_dict_group_captured_deleted450
  br label %bb_generic_dict_group_done119

bb_generic_dict_group_match116:
  br label %bb_generic_dict_group_done119

bb_generic_dict_group_next117:
  %generic_dict_group_next_probe424 = add i64 %generic_dict_group_probe426, 16
  %generic_dict_group_next_deleted425 = add i64 %generic_dict_group_captured_deleted450, 0
  br label %bb_generic_dict_group_find109

bb_generic_dict_group_miss118:
  %generic_dict_group_miss_no_deleted473 = icmp eq i64 %generic_dict_group_deleted427, %mutable_capacity295
  %generic_dict_group_miss_slot474 = select i1 %generic_dict_group_miss_no_deleted473, i64 0, i64 %generic_dict_group_deleted427
  br label %bb_generic_dict_group_done119

bb_generic_dict_group_done119:
  %generic_dict_find_found475 = phi i1 [ false, %bb_generic_dict_group_empty115 ], [ true, %bb_generic_dict_group_match116 ], [ false, %bb_generic_dict_group_miss118 ]
  %generic_dict_find_slot_result476 = phi i64 [ %generic_dict_group_insertion_slot472, %bb_generic_dict_group_empty115 ], [ %generic_dict_candidate_slot457, %bb_generic_dict_group_match116 ], [ %generic_dict_group_miss_slot474, %bb_generic_dict_group_miss118 ]
  br label %bb_generic_dict_insert_first_done106

bb_generic_dict_insert_first_done106:
  %generic_dict_insert_first_found477 = phi i1 [ true, %bb_generic_dict_insert_first_match103 ], [ false, %bb_generic_dict_insert_first_vacant105 ], [ %generic_dict_find_found475, %bb_generic_dict_group_done119 ], [ false, %bb_generic_dict_insert_no_capacity108 ]
  %generic_dict_insert_first_slot_result478 = phi i64 [ %dict_start_slot400, %bb_generic_dict_insert_first_match103 ], [ %dict_start_slot400, %bb_generic_dict_insert_first_vacant105 ], [ %generic_dict_find_slot_result476, %bb_generic_dict_group_done119 ], [ 0, %bb_generic_dict_insert_no_capacity108 ]
  %set_key_entries_offset_mirror479 = add i64 %mutable_capacity295, 23
  %set_key_entries_offset480 = and i64 %set_key_entries_offset_mirror479, -8
  %set_key_entries481 = getelementptr i8, ptr %heap373, i64 %set_key_entries_offset480
  %set_key_entry_offset482 = mul i64 %generic_dict_insert_first_slot_result478, 4
  %set_key_slot483 = getelementptr i8, ptr %set_key_entries481, i64 %set_key_entry_offset482
  store i32 %set_compact_key389, ptr %set_key_slot483, align 4
  %generic_dict_control_slot484 = getelementptr i8, ptr %heap373, i64 %generic_dict_insert_first_slot_result478
  store i8 %dict_h2_byte398, ptr %generic_dict_control_slot484, align 1
  %generic_dict_control_mirrored485 = icmp ult i64 %generic_dict_insert_first_slot_result478, 16
  br i1 %generic_dict_control_mirrored485, label %bb_generic_dict_control_mirror120, label %bb_generic_dict_control_done121

bb_generic_dict_control_mirror120:
  %generic_dict_control_mirror_index486 = add i64 %mutable_capacity295, %generic_dict_insert_first_slot_result478
  %generic_dict_control_mirror_slot487 = getelementptr i8, ptr %heap373, i64 %generic_dict_control_mirror_index486
  store i8 %dict_h2_byte398, ptr %generic_dict_control_mirror_slot487, align 1
  br label %bb_generic_dict_control_done121

bb_generic_dict_control_done121:
  br label %bb_set_compact_next99

bb_set_compact_next99:
  %set_compact_next_index378 = add i64 %set_compact_index379, 1
  br label %bb_set_compact96

bb_set_compact_done100:
  call void @sollang_free(ptr %mutable_ptr293)
  br label %bb_set_remove_done91

bb_set_remove_missing88:
  br label %bb_set_remove_done91

bb_set_remove_done91:
  %set_pointer488 = phi ptr [ %mutable_ptr293, %bb_set_remove_keep_tombstone89 ], [ %heap373, %bb_set_compact_done100 ], [ %mutable_ptr293, %bb_set_remove_missing88 ]
  %set_length489 = phi i64 [ %set_remove_length366, %bb_set_remove_keep_tombstone89 ], [ %set_remove_length366, %bb_set_compact_done100 ], [ %mutable_len294, %bb_set_remove_missing88 ]
  %set_removed490 = phi i1 [ true, %bb_set_remove_keep_tombstone89 ], [ true, %bb_set_compact_done100 ], [ false, %bb_set_remove_missing88 ]
  store ptr %set_pointer488, ptr %mutable_ptr_addr4, align 8
  store i64 %set_length489, ptr %mutable_len_addr5, align 8
  store i64 %mutable_capacity295, ptr %mutable_capacity_addr6, align 8
  %mutable_ptr491 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len492 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity493 = load i64, ptr %mutable_capacity_addr6, align 8
  %hash_key494 = sext i32 20 to i64
  %hash_high496 = lshr i64 %hash_key494, 32
  %hash_fold495 = xor i64 %hash_key494, %hash_high496
  %hash497 = mul i64 %hash_fold495, -7046029254386353131
  %dict_h2_shifted498 = lshr i64 %hash497, 57
  %dict_h2_raw499 = and i64 %dict_h2_shifted498, 127
  %dict_h2_zero500 = icmp eq i64 %dict_h2_raw499, 0
  %dict_h2501 = select i1 %dict_h2_zero500, i64 1, i64 %dict_h2_raw499
  %dict_h2_byte502 = trunc i64 %dict_h2501 to i8
  %dict_capacity_mask503 = sub i64 %mutable_capacity493, 1
  %dict_start_slot504 = and i64 %hash497, %dict_capacity_mask503
  %generic_dict_control_slot505 = getelementptr i8, ptr %mutable_ptr491, i64 %dict_start_slot504
  %generic_dict_control506 = load i8, ptr %generic_dict_control_slot505, align 1
  %generic_dict_lookup_first_empty507 = icmp eq i8 %generic_dict_control506, 0
  br i1 %generic_dict_lookup_first_empty507, label %bb_generic_dict_lookup_first_miss126, label %bb_generic_dict_lookup_first_occupied122

bb_generic_dict_lookup_first_occupied122:
  %generic_dict_lookup_first_h2508 = icmp eq i8 %generic_dict_control506, %dict_h2_byte502
  br i1 %generic_dict_lookup_first_h2508, label %bb_generic_dict_lookup_first_compare123, label %bb_generic_dict_lookup_first_fallback125

bb_generic_dict_lookup_first_compare123:
  %generic_dict_lookup_first_key_entries_offset_mirror509 = add i64 %mutable_capacity493, 23
  %generic_dict_lookup_first_key_entries_offset510 = and i64 %generic_dict_lookup_first_key_entries_offset_mirror509, -8
  %generic_dict_lookup_first_key_entries511 = getelementptr i8, ptr %mutable_ptr491, i64 %generic_dict_lookup_first_key_entries_offset510
  %generic_dict_lookup_first_key_entry_offset512 = mul i64 %dict_start_slot504, 4
  %generic_dict_lookup_first_key_slot513 = getelementptr i8, ptr %generic_dict_lookup_first_key_entries511, i64 %generic_dict_lookup_first_key_entry_offset512
  %generic_dict_lookup_first_key514 = load i32, ptr %generic_dict_lookup_first_key_slot513, align 4
  %generic_dict_key_equal515 = icmp eq i32 %generic_dict_lookup_first_key514, 20
  br i1 %generic_dict_key_equal515, label %bb_generic_dict_lookup_first_match124, label %bb_generic_dict_lookup_first_fallback125

bb_generic_dict_lookup_first_match124:
  br label %bb_generic_dict_lookup_first_done127

bb_generic_dict_lookup_first_miss126:
  br label %bb_generic_dict_lookup_first_done127

bb_generic_dict_lookup_first_fallback125:
  %hash_key516 = sext i32 20 to i64
  %hash_high518 = lshr i64 %hash_key516, 32
  %hash_fold517 = xor i64 %hash_key516, %hash_high518
  %hash519 = mul i64 %hash_fold517, -7046029254386353131
  %dict_h2_shifted520 = lshr i64 %hash519, 57
  %dict_h2_raw521 = and i64 %dict_h2_shifted520, 127
  %dict_h2_zero522 = icmp eq i64 %dict_h2_raw521, 0
  %dict_h2523 = select i1 %dict_h2_zero522, i64 1, i64 %dict_h2_raw521
  %dict_h2_byte524 = trunc i64 %dict_h2523 to i8
  %dict_capacity_mask525 = sub i64 %mutable_capacity493, 1
  %dict_start_slot526 = and i64 %hash519, %dict_capacity_mask525
  br label %bb_generic_dict_lookup_group128

bb_generic_dict_lookup_group128:
  %generic_dict_lookup_group_probe528 = phi i64 [ 0, %bb_generic_dict_lookup_first_fallback125 ], [ %generic_dict_lookup_group_next_probe527, %bb_generic_dict_lookup_group_next135 ]
  %generic_dict_lookup_group_active529 = icmp ult i64 %generic_dict_lookup_group_probe528, %mutable_capacity493
  br i1 %generic_dict_lookup_group_active529, label %bb_generic_dict_lookup_group_body129, label %bb_generic_dict_lookup_group_miss136

bb_generic_dict_lookup_group_body129:
  %generic_dict_lookup_group_unwrapped530 = add i64 %dict_start_slot526, %generic_dict_lookup_group_probe528
  %generic_dict_lookup_group_start531 = and i64 %generic_dict_lookup_group_unwrapped530, %dict_capacity_mask525
  %generic_dict_lookup_group_pointer532 = getelementptr i8, ptr %mutable_ptr491, i64 %generic_dict_lookup_group_start531
  %generic_dict_lookup_group_controls533 = load <16 x i8>, ptr %generic_dict_lookup_group_pointer532, align 1
  %generic_dict_lookup_group_h2_seed534 = insertelement <16 x i8> poison, i8 %dict_h2_byte524, i64 0
  %generic_dict_lookup_group_h2_vector535 = shufflevector <16 x i8> %generic_dict_lookup_group_h2_seed534, <16 x i8> poison, <16 x i32> zeroinitializer
  %generic_dict_lookup_group_matches_vector536 = icmp eq <16 x i8> %generic_dict_lookup_group_controls533, %generic_dict_lookup_group_h2_vector535
  %generic_dict_lookup_group_match_bits537 = bitcast <16 x i1> %generic_dict_lookup_group_matches_vector536 to i16
  %generic_dict_lookup_group_empty_vector538 = icmp eq <16 x i8> %generic_dict_lookup_group_controls533, zeroinitializer
  %generic_dict_lookup_group_empty_bits539 = bitcast <16 x i1> %generic_dict_lookup_group_empty_vector538 to i16
  br label %bb_generic_dict_lookup_candidate_loop130

bb_generic_dict_lookup_candidate_loop130:
  %generic_dict_lookup_candidate_bits540 = phi i16 [ %generic_dict_lookup_group_match_bits537, %bb_generic_dict_lookup_group_body129 ], [ %generic_dict_lookup_candidate_cleared_bits541, %bb_generic_dict_lookup_candidate_next132 ]
  %generic_dict_lookup_has_candidate542 = icmp ne i16 %generic_dict_lookup_candidate_bits540, 0
  br i1 %generic_dict_lookup_has_candidate542, label %bb_generic_dict_lookup_candidate_body131, label %bb_generic_dict_lookup_group_decision133

bb_generic_dict_lookup_candidate_body131:
  %generic_dict_lookup_candidate_offset16543 = call i16 @llvm.cttz.i16(i16 %generic_dict_lookup_candidate_bits540, i1 false)
  %generic_dict_lookup_candidate_offset544 = zext i16 %generic_dict_lookup_candidate_offset16543 to i64
  %generic_dict_lookup_candidate_unwrapped545 = add i64 %generic_dict_lookup_group_start531, %generic_dict_lookup_candidate_offset544
  %generic_dict_lookup_candidate_slot546 = and i64 %generic_dict_lookup_candidate_unwrapped545, %dict_capacity_mask525
  %generic_dict_lookup_key_entries_offset_mirror547 = add i64 %mutable_capacity493, 23
  %generic_dict_lookup_key_entries_offset548 = and i64 %generic_dict_lookup_key_entries_offset_mirror547, -8
  %generic_dict_lookup_key_entries549 = getelementptr i8, ptr %mutable_ptr491, i64 %generic_dict_lookup_key_entries_offset548
  %generic_dict_lookup_key_entry_offset550 = mul i64 %generic_dict_lookup_candidate_slot546, 4
  %generic_dict_lookup_key_slot551 = getelementptr i8, ptr %generic_dict_lookup_key_entries549, i64 %generic_dict_lookup_key_entry_offset550
  %generic_dict_lookup_key552 = load i32, ptr %generic_dict_lookup_key_slot551, align 4
  %generic_dict_key_equal553 = icmp eq i32 %generic_dict_lookup_key552, 20
  br i1 %generic_dict_key_equal553, label %bb_generic_dict_lookup_group_match134, label %bb_generic_dict_lookup_candidate_next132

bb_generic_dict_lookup_candidate_next132:
  %generic_dict_lookup_candidate_bits_minus_one554 = sub i16 %generic_dict_lookup_candidate_bits540, 1
  %generic_dict_lookup_candidate_cleared_bits541 = and i16 %generic_dict_lookup_candidate_bits540, %generic_dict_lookup_candidate_bits_minus_one554
  br label %bb_generic_dict_lookup_candidate_loop130

bb_generic_dict_lookup_group_decision133:
  %generic_dict_lookup_group_has_empty555 = icmp ne i16 %generic_dict_lookup_group_empty_bits539, 0
  br i1 %generic_dict_lookup_group_has_empty555, label %bb_generic_dict_lookup_group_miss136, label %bb_generic_dict_lookup_group_next135

bb_generic_dict_lookup_group_next135:
  %generic_dict_lookup_group_next_probe527 = add i64 %generic_dict_lookup_group_probe528, 16
  br label %bb_generic_dict_lookup_group128

bb_generic_dict_lookup_group_match134:
  br label %bb_generic_dict_lookup_group_done137

bb_generic_dict_lookup_group_miss136:
  br label %bb_generic_dict_lookup_group_done137

bb_generic_dict_lookup_group_done137:
  %generic_dict_lookup_found556 = phi i1 [ true, %bb_generic_dict_lookup_group_match134 ], [ false, %bb_generic_dict_lookup_group_miss136 ]
  %generic_dict_lookup_slot_result557 = phi i64 [ %generic_dict_lookup_candidate_slot546, %bb_generic_dict_lookup_group_match134 ], [ 0, %bb_generic_dict_lookup_group_miss136 ]
  br label %bb_generic_dict_lookup_first_done127

bb_generic_dict_lookup_first_done127:
  %generic_dict_lookup_first_found558 = phi i1 [ true, %bb_generic_dict_lookup_first_match124 ], [ false, %bb_generic_dict_lookup_first_miss126 ], [ %generic_dict_lookup_found556, %bb_generic_dict_lookup_group_done137 ]
  %generic_dict_lookup_first_slot_result559 = phi i64 [ %dict_start_slot504, %bb_generic_dict_lookup_first_match124 ], [ 0, %bb_generic_dict_lookup_first_miss126 ], [ %generic_dict_lookup_slot_result557, %bb_generic_dict_lookup_group_done137 ]
  store i32 0, ptr %mutable_scalar_slot560, align 4
  %mutable_ptr561 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len562 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity563 = load i64, ptr %mutable_capacity_addr6, align 8
  %dictionary_each_empty565 = icmp eq i64 %mutable_capacity563, 0
  br i1 %dictionary_each_empty565, label %bb_dictionary_each_end141, label %bb_dictionary_each138

bb_dictionary_each138:
  %dictionary_each_slot566 = phi i64 [ 0, %bb_generic_dict_lookup_first_done127 ], [ %dictionary_each_next564, %bb_dictionary_each_continue140 ]
  %generic_dict_control_slot567 = getelementptr i8, ptr %mutable_ptr561, i64 %dictionary_each_slot566
  %generic_dict_control568 = load i8, ptr %generic_dict_control_slot567, align 1
  %dictionary_each_occupied569 = icmp sgt i8 %generic_dict_control568, 0
  br i1 %dictionary_each_occupied569, label %bb_dictionary_each_body139, label %bb_dictionary_each_continue140

bb_dictionary_each_body139:
  %dictionary_each_key_entries_offset_mirror570 = add i64 %mutable_capacity563, 23
  %dictionary_each_key_entries_offset571 = and i64 %dictionary_each_key_entries_offset_mirror570, -8
  %dictionary_each_key_entries572 = getelementptr i8, ptr %mutable_ptr561, i64 %dictionary_each_key_entries_offset571
  %dictionary_each_key_entry_offset573 = mul i64 %dictionary_each_slot566, 4
  %dictionary_each_key_slot574 = getelementptr i8, ptr %dictionary_each_key_entries572, i64 %dictionary_each_key_entry_offset573
  %dictionary_each_key575 = load i32, ptr %dictionary_each_key_slot574, align 4
  %mutable_scalar576 = load i32, ptr %mutable_scalar_slot560, align 4
  %add577 = add i32 %mutable_scalar576, %dictionary_each_key575
  store i32 %add577, ptr %mutable_scalar_slot560, align 4
  br label %bb_dictionary_each_continue140

bb_dictionary_each_continue140:
  %dictionary_each_next564 = add i64 %dictionary_each_slot566, 1
  %dictionary_each_done578 = icmp eq i64 %dictionary_each_next564, %mutable_capacity563
  br i1 %dictionary_each_done578, label %bb_dictionary_each_end141, label %bb_dictionary_each138

bb_dictionary_each_end141:
  %mutable_ptr579 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len580 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity581 = load i64, ptr %mutable_capacity_addr6, align 8
  %dict_len_value582 = trunc i64 %mutable_len580 to i32
  %mutable_ptr583 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len584 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity585 = load i64, ptr %mutable_capacity_addr6, align 8
  %numeric_upper_bound586 = icmp ule i64 %mutable_capacity585, 2147483647
  br i1 %numeric_upper_bound586, label %bb_numeric_conversion_upper_ok142, label %bb_numeric_conversion_upper_fail143

bb_numeric_conversion_upper_fail143:
  %trap_stderr587 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr587, ptr @.slg.str.suffix.2, i32 40, ptr %trap_written588, ptr null)
  call void @llvm.trap()
  unreachable

bb_numeric_conversion_upper_ok142:
  %dict_capacity_value589 = trunc i64 %mutable_capacity585 to i32
  br i1 %generic_dict_lookup_first_found93, label %bb_if_then144, label %bb_if_else145
bb_if_then144:
  %write590 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.3, i64 11, ptr %written)
  %is_ok591 = icmp ne i32 %write590, 0
  %previous_ok592 = load i1, ptr %ok_state, align 1
  %ok593 = and i1 %previous_ok592, %is_ok591
  store i1 %ok593, ptr %ok_state, align 1
  %write594 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.4, i64 1, ptr %written)
  %is_ok595 = icmp ne i32 %write594, 0
  %previous_ok596 = load i1, ptr %ok_state, align 1
  %ok597 = and i1 %previous_ok596, %is_ok595
  store i1 %ok597, ptr %ok_state, align 1
  br label %bb_if_end146
bb_if_else145:
  %write598 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.5, i64 12, ptr %written)
  %is_ok599 = icmp ne i32 %write598, 0
  %previous_ok600 = load i1, ptr %ok_state, align 1
  %ok601 = and i1 %previous_ok600, %is_ok599
  store i1 %ok601, ptr %ok_state, align 1
  %write602 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.6, i64 1, ptr %written)
  %is_ok603 = icmp ne i32 %write602, 0
  %previous_ok604 = load i1, ptr %ok_state, align 1
  %ok605 = and i1 %previous_ok604, %is_ok603
  store i1 %ok605, ptr %ok_state, align 1
  br label %bb_if_end146
bb_if_end146:
  br i1 %set_removed292, label %bb_if_then147, label %bb_if_else148
bb_if_then147:
  %write606 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.7, i64 12, ptr %written)
  %is_ok607 = icmp ne i32 %write606, 0
  %previous_ok608 = load i1, ptr %ok_state, align 1
  %ok609 = and i1 %previous_ok608, %is_ok607
  store i1 %ok609, ptr %ok_state, align 1
  %write610 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.8, i64 1, ptr %written)
  %is_ok611 = icmp ne i32 %write610, 0
  %previous_ok612 = load i1, ptr %ok_state, align 1
  %ok613 = and i1 %previous_ok612, %is_ok611
  store i1 %ok613, ptr %ok_state, align 1
  br label %bb_if_end149
bb_if_else148:
  %write614 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.9, i64 13, ptr %written)
  %is_ok615 = icmp ne i32 %write614, 0
  %previous_ok616 = load i1, ptr %ok_state, align 1
  %ok617 = and i1 %previous_ok616, %is_ok615
  store i1 %ok617, ptr %ok_state, align 1
  %write618 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.10, i64 1, ptr %written)
  %is_ok619 = icmp ne i32 %write618, 0
  %previous_ok620 = load i1, ptr %ok_state, align 1
  %ok621 = and i1 %previous_ok620, %is_ok619
  store i1 %ok621, ptr %ok_state, align 1
  br label %bb_if_end149
bb_if_end149:
  br i1 %set_removed490, label %bb_if_then150, label %bb_if_else151
bb_if_then150:
  %write622 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.11, i64 10, ptr %written)
  %is_ok623 = icmp ne i32 %write622, 0
  %previous_ok624 = load i1, ptr %ok_state, align 1
  %ok625 = and i1 %previous_ok624, %is_ok623
  store i1 %ok625, ptr %ok_state, align 1
  %write626 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.12, i64 1, ptr %written)
  %is_ok627 = icmp ne i32 %write626, 0
  %previous_ok628 = load i1, ptr %ok_state, align 1
  %ok629 = and i1 %previous_ok628, %is_ok627
  store i1 %ok629, ptr %ok_state, align 1
  br label %bb_if_end152
bb_if_else151:
  %write630 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.13, i64 11, ptr %written)
  %is_ok631 = icmp ne i32 %write630, 0
  %previous_ok632 = load i1, ptr %ok_state, align 1
  %ok633 = and i1 %previous_ok632, %is_ok631
  store i1 %ok633, ptr %ok_state, align 1
  %write634 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.14, i64 1, ptr %written)
  %is_ok635 = icmp ne i32 %write634, 0
  %previous_ok636 = load i1, ptr %ok_state, align 1
  %ok637 = and i1 %previous_ok636, %is_ok635
  store i1 %ok637, ptr %ok_state, align 1
  br label %bb_if_end152
bb_if_end152:
  br i1 %generic_dict_lookup_first_found558, label %bb_if_then153, label %bb_if_else154
bb_if_then153:
  %write638 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.15, i64 10, ptr %written)
  %is_ok639 = icmp ne i32 %write638, 0
  %previous_ok640 = load i1, ptr %ok_state, align 1
  %ok641 = and i1 %previous_ok640, %is_ok639
  store i1 %ok641, ptr %ok_state, align 1
  %write642 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.16, i64 1, ptr %written)
  %is_ok643 = icmp ne i32 %write642, 0
  %previous_ok644 = load i1, ptr %ok_state, align 1
  %ok645 = and i1 %previous_ok644, %is_ok643
  store i1 %ok645, ptr %ok_state, align 1
  br label %bb_if_end155
bb_if_else154:
  %write646 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.17, i64 11, ptr %written)
  %is_ok647 = icmp ne i32 %write646, 0
  %previous_ok648 = load i1, ptr %ok_state, align 1
  %ok649 = and i1 %previous_ok648, %is_ok647
  store i1 %ok649, ptr %ok_state, align 1
  %write650 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.18, i64 1, ptr %written)
  %is_ok651 = icmp ne i32 %write650, 0
  %previous_ok652 = load i1, ptr %ok_state, align 1
  %ok653 = and i1 %previous_ok652, %is_ok651
  store i1 %ok653, ptr %ok_state, align 1
  br label %bb_if_end155
bb_if_end155:
  %mutable_scalar654 = load i32, ptr %mutable_scalar_slot7, align 4
  %print_integer655 = sext i32 %mutable_scalar654 to i64
  %write656 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer655, ptr %written)
  %is_ok657 = icmp ne i32 %write656, 0
  %previous_ok658 = load i1, ptr %ok_state, align 1
  %ok659 = and i1 %previous_ok658, %is_ok657
  store i1 %ok659, ptr %ok_state, align 1
  %write660 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.19, i64 1, ptr %written)
  %is_ok661 = icmp ne i32 %write660, 0
  %previous_ok662 = load i1, ptr %ok_state, align 1
  %ok663 = and i1 %previous_ok662, %is_ok661
  store i1 %ok663, ptr %ok_state, align 1
  %mutable_scalar664 = load i32, ptr %mutable_scalar_slot560, align 4
  %print_integer665 = sext i32 %mutable_scalar664 to i64
  %write666 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer665, ptr %written)
  %is_ok667 = icmp ne i32 %write666, 0
  %previous_ok668 = load i1, ptr %ok_state, align 1
  %ok669 = and i1 %previous_ok668, %is_ok667
  store i1 %ok669, ptr %ok_state, align 1
  %write670 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.20, i64 1, ptr %written)
  %is_ok671 = icmp ne i32 %write670, 0
  %previous_ok672 = load i1, ptr %ok_state, align 1
  %ok673 = and i1 %previous_ok672, %is_ok671
  store i1 %ok673, ptr %ok_state, align 1
  %write674 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.21, i64 4, ptr %written)
  %is_ok675 = icmp ne i32 %write674, 0
  %previous_ok676 = load i1, ptr %ok_state, align 1
  %ok677 = and i1 %previous_ok676, %is_ok675
  store i1 %ok677, ptr %ok_state, align 1
  %print_integer678 = sext i32 %dict_len_value582 to i64
  %write679 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer678, ptr %written)
  %is_ok680 = icmp ne i32 %write679, 0
  %previous_ok681 = load i1, ptr %ok_state, align 1
  %ok682 = and i1 %previous_ok681, %is_ok680
  store i1 %ok682, ptr %ok_state, align 1
  %write683 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.22, i64 10, ptr %written)
  %is_ok684 = icmp ne i32 %write683, 0
  %previous_ok685 = load i1, ptr %ok_state, align 1
  %ok686 = and i1 %previous_ok685, %is_ok684
  store i1 %ok686, ptr %ok_state, align 1
  %print_integer687 = sext i32 %dict_capacity_value589 to i64
  %write688 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer687, ptr %written)
  %is_ok689 = icmp ne i32 %write688, 0
  %previous_ok690 = load i1, ptr %ok_state, align 1
  %ok691 = and i1 %previous_ok690, %is_ok689
  store i1 %ok691, ptr %ok_state, align 1
  %write692 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.23, i64 1, ptr %written)
  %is_ok693 = icmp ne i32 %write692, 0
  %previous_ok694 = load i1, ptr %ok_state, align 1
  %ok695 = and i1 %previous_ok694, %is_ok693
  store i1 %ok695, ptr %ok_state, align 1
  %mutable_ptr696 = load ptr, ptr %mutable_ptr_addr4, align 8
  %mutable_len697 = load i64, ptr %mutable_len_addr5, align 8
  %mutable_capacity698 = load i64, ptr %mutable_capacity_addr6, align 8
  call void @sollang_free(ptr %mutable_ptr696)
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %final_ok699 = load i1, ptr %ok_state, align 1
  %exit700 = select i1 %final_ok699, i32 0, i32 1
  ret i32 %exit700
}

attributes #0 = { nounwind }
