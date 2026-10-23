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
@sollang_winsock_state = internal global i32 0
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

declare dllimport i32 @WSAStartup(i16, ptr)
declare dllimport i32 @WSACleanup()
declare dllimport i32 @WSAGetLastError()
declare dllimport i64 @WSASocketW(i32, i32, i32, ptr, i32, i32)
declare dllimport i32 @WSADuplicateSocketW(i64, i32, ptr)
declare dllimport i32 @GetCurrentProcessId()
declare dllimport i32 @closesocket(i64)
declare dllimport i32 @bind(i64, ptr, i32)
declare dllimport i32 @getsockname(i64, ptr, ptr)
declare dllimport i32 @getpeername(i64, ptr, ptr)
declare dllimport i32 @listen(i64, i32)
declare dllimport i64 @accept(i64, ptr, ptr)
declare dllimport i32 @connect(i64, ptr, i32)
declare dllimport i32 @recv(i64, ptr, i32, i32)
declare dllimport i32 @send(i64, ptr, i32, i32)
declare dllimport i32 @WSARecv(i64, ptr, i32, ptr, ptr, ptr, ptr)
declare dllimport i32 @WSASend(i64, ptr, i32, ptr, i32, ptr, ptr)
declare dllimport i32 @WSAGetOverlappedResult(i64, ptr, ptr, i32, ptr)
declare dllimport i32 @recvfrom(i64, ptr, i32, i32, ptr, ptr)
declare dllimport i32 @WSARecvFrom(i64, ptr, i32, ptr, ptr, ptr, ptr, ptr, ptr)
declare dllimport i32 @sendto(i64, ptr, i32, i32, ptr, i32)
declare dllimport i32 @shutdown(i64, i32)
declare dllimport i32 @setsockopt(i64, i32, i32, ptr, i32)
declare dllimport i32 @getsockopt(i64, i32, i32, ptr, ptr)
declare dllimport i32 @ioctlsocket(i64, i32, ptr)
declare dllimport i32 @WSAPoll(ptr, i32, i32)
declare dllimport i32 @GetAddrInfoW(ptr, ptr, ptr, ptr)
declare dllimport void @FreeAddrInfoW(ptr)

define internal %sollang.socket_result @sollang_socket_result(i64 %value, i32 %kind, i32 %code) #0 {
entry:
  %with_value = insertvalue %sollang.socket_result poison, i64 %value, 0
  %with_kind = insertvalue %sollang.socket_result %with_value, i32 %kind, 1
  %result = insertvalue %sollang.socket_result %with_kind, i32 %code, 2
  ret %sollang.socket_result %result
}

define internal i32 @sollang_socket_error_kind(i32 %code) #0 {
entry:
  switch i32 %code, label %other [
    i32 10022, label %invalid_argument
    i32 10048, label %address_in_use
    i32 10061, label %connection_refused
    i32 10054, label %connection_reset
    i32 10060, label %timed_out
    i32 10004, label %interrupted
    i32 10035, label %would_block
    i32 10047, label %unsupported
    i32 10045, label %unsupported
  ]

invalid_argument:
  ret i32 1
address_in_use:
  ret i32 2
connection_refused:
  ret i32 3
connection_reset:
  ret i32 4
timed_out:
  ret i32 5
interrupted:
  ret i32 6
would_block:
  ret i32 10
unsupported:
  ret i32 7
other:
  ret i32 8
}

define internal %sollang.socket_result @sollang_platform_socket_try_clone(i64 %socket) #0 {
entry:
  %protocol_info = alloca [640 x i8], align 8
  %process_id = call i32 @GetCurrentProcessId()
  %duplicate_status = call i32 @WSADuplicateSocketW(i64 %socket, i32 %process_id, ptr %protocol_info)
  %duplicate_failed = icmp ne i32 %duplicate_status, 0
  br i1 %duplicate_failed, label %failure, label %create

create:
  %clone = call i64 @WSASocketW(i32 -1, i32 -1, i32 -1, ptr %protocol_info, i32 0, i32 129)
  %create_failed = icmp eq i64 %clone, -1
  br i1 %create_failed, label %failure, label %success

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failure_result

success:
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %clone, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal i32 @sollang_winsock_ensure_started() #0 {
entry:
  br label %retry

retry:
  %state = load atomic i32, ptr @sollang_winsock_state acquire, align 4
  %ready = icmp eq i32 %state, 1
  br i1 %ready, label %success, label %check_failed

check_failed:
  %failed = icmp slt i32 %state, 0
  br i1 %failed, label %previous_failure, label %claim_start

previous_failure:
  %previous_code = sub i32 0, %state
  ret i32 %previous_code

claim_start:
  %initializing = icmp eq i32 %state, 2
  br i1 %initializing, label %retry, label %claim

claim:
  %claimed = cmpxchg ptr @sollang_winsock_state, i32 0, i32 2 acq_rel acquire
  %won = extractvalue { i32, i1 } %claimed, 1
  br i1 %won, label %start, label %retry

start:
  %data = alloca [408 x i8], align 8
  %status = call i32 @WSAStartup(i16 514, ptr %data)
  %started = icmp eq i32 %status, 0
  br i1 %started, label %mark_ready, label %mark_failed

mark_ready:
  store atomic i32 1, ptr @sollang_winsock_state release, align 4
  br label %success

mark_failed:
  %stored_failure = sub i32 0, %status
  store atomic i32 %stored_failure, ptr @sollang_winsock_state release, align 4
  ret i32 %status

success:
  ret i32 0
}

define internal %sollang.socket_result @sollang_platform_socket_set_nonblocking(i64 %socket, i1 %enabled) #0 {
entry:
  %mode = alloca i32, align 4
  %value = zext i1 %enabled to i32
  store i32 %value, ptr %mode, align 4
  %status = call i32 @ioctlsocket(i64 %socket, i32 -2147195266, ptr %mode)
  %failed = icmp ne i32 %status, 0
  br i1 %failed, label %failure, label %success

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failure_result

success:
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal %sollang.socket_result @sollang_platform_socket_poll(i64 %socket, i32 %mode, i1 %has_timeout, i64 %milliseconds) #0 {
entry:
  %descriptor = alloca { i64, i16, i16 }, align 8
  %fd = getelementptr inbounds { i64, i16, i16 }, ptr %descriptor, i32 0, i32 0
  %events = getelementptr inbounds { i64, i16, i16 }, ptr %descriptor, i32 0, i32 1
  %revents = getelementptr inbounds { i64, i16, i16 }, ptr %descriptor, i32 0, i32 2
  store i64 %socket, ptr %fd, align 8
  %is_read = icmp eq i32 %mode, 0
  %requested = select i1 %is_read, i16 256, i16 16
  %is_error = icmp eq i32 %mode, 2
  %event_mask = select i1 %is_error, i16 0, i16 %requested
  store i16 %event_mask, ptr %events, align 2
  store i16 0, ptr %revents, align 2
  %timeout_overflow = icmp sgt i64 %milliseconds, 2147483647
  %bounded_timeout = select i1 %timeout_overflow, i64 2147483647, i64 %milliseconds
  %timeout32 = trunc i64 %bounded_timeout to i32
  %timeout = select i1 %has_timeout, i32 %timeout32, i32 -1
  %status = call i32 @WSAPoll(ptr %descriptor, i32 1, i32 %timeout)
  %failed = icmp slt i32 %status, 0
  br i1 %failed, label %failure, label %success

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failure_result

success:
  %returned = load i16, ptr %revents, align 2
  %normal_mask = or i16 %event_mask, 7
  %selected_mask = select i1 %is_error, i16 7, i16 %normal_mask
  %matched_bits = and i16 %returned, %selected_mask
  %ready = icmp ne i16 %matched_bits, 0
  %ready64 = zext i1 %ready to i64
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %ready64, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal %sollang.socket_result @sollang_platform_socket_reactor_wait(ptr %interests, i64 %interest_count, i64 %interest_stride, i64 %key_offset, i64 %source_offset, i64 %mode_offset, i64 %maximum_events, ptr %event_buffer, ptr %event_length_address, i64 %event_capacity, i64 %event_stride, i64 %event_key_offset, i64 %event_read_offset, i64 %event_write_offset, i64 %event_error_offset, i1 %has_timeout, i64 %milliseconds) #0 {
entry:
  %within_declared = icmp ule i64 %interest_count, %maximum_events
  %within_stack = icmp ule i64 %interest_count, 1024
  %count_valid = and i1 %within_declared, %within_stack
  %capacity_valid = icmp ule i64 %interest_count, %event_capacity
  %shape_valid = and i1 %count_valid, %capacity_valid
  br i1 %shape_valid, label %check_empty, label %invalid_argument

check_empty:
  %empty = icmp eq i64 %interest_count, 0
  br i1 %empty, label %success_empty, label %prepare

prepare:
  %descriptors = alloca { i64, i16, i16 }, i64 %interest_count, align 8
  br label %build

build:
  %index = phi i64 [ 0, %prepare ], [ %next, %store_descriptor ]
  %interest_byte_offset = mul i64 %index, %interest_stride
  %interest = getelementptr i8, ptr %interests, i64 %interest_byte_offset
  %source = getelementptr i8, ptr %interest, i64 %source_offset
  %source_tag = load i32, ptr %source, align 4
  %source_valid = icmp ule i32 %source_tag, 2
  br i1 %source_valid, label %load_owner, label %invalid_argument

load_owner:
  %source_payload = getelementptr i8, ptr %source, i64 8
  %owner = load ptr, ptr %source_payload, align 8
  %owner_valid = icmp ne ptr %owner, null
  br i1 %owner_valid, label %load_mode, label %invalid_argument

load_mode:
  %handle = load i64, ptr %owner, align 8
  %mode_address = getelementptr i8, ptr %interest, i64 %mode_offset
  %mode = load i32, ptr %mode_address, align 4
  %mode_valid = icmp ule i32 %mode, 2
  br i1 %mode_valid, label %store_descriptor, label %invalid_argument

store_descriptor:
  %descriptor = getelementptr { i64, i16, i16 }, ptr %descriptors, i64 %index
  %descriptor_fd = getelementptr { i64, i16, i16 }, ptr %descriptor, i32 0, i32 0
  %descriptor_events = getelementptr { i64, i16, i16 }, ptr %descriptor, i32 0, i32 1
  %descriptor_revents = getelementptr { i64, i16, i16 }, ptr %descriptor, i32 0, i32 2
  %wants_read = icmp ne i32 %mode, 1
  %wants_write = icmp ne i32 %mode, 0
  %read_mask = select i1 %wants_read, i16 256, i16 0
  %write_mask = select i1 %wants_write, i16 16, i16 0
  %requested = or i16 %read_mask, %write_mask
  store i64 %handle, ptr %descriptor_fd, align 8
  store i16 %requested, ptr %descriptor_events, align 2
  store i16 0, ptr %descriptor_revents, align 2
  %next = add i64 %index, 1
  %built = icmp eq i64 %next, %interest_count
  br i1 %built, label %wait, label %build

wait:
  %timeout_overflow = icmp sgt i64 %milliseconds, 2147483647
  %bounded_timeout = select i1 %timeout_overflow, i64 2147483647, i64 %milliseconds
  %timeout32 = trunc i64 %bounded_timeout to i32
  %timeout = select i1 %has_timeout, i32 %timeout32, i32 -1
  %count32 = trunc i64 %interest_count to i32
  %status = call i32 @WSAPoll(ptr %descriptors, i32 %count32, i32 %timeout)
  %failed = icmp slt i32 %status, 0
  br i1 %failed, label %failure, label %scan_prepare

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failure_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failure_result

scan_prepare:
  %output_count_address = alloca i64, align 8
  store i64 0, ptr %output_count_address, align 8
  br label %scan

scan:
  %scan_index = phi i64 [ 0, %scan_prepare ], [ %scan_next, %advance ]
  %scan_descriptor = getelementptr { i64, i16, i16 }, ptr %descriptors, i64 %scan_index
  %scan_events_address = getelementptr { i64, i16, i16 }, ptr %scan_descriptor, i32 0, i32 1
  %scan_revents_address = getelementptr { i64, i16, i16 }, ptr %scan_descriptor, i32 0, i32 2
  %scan_events = load i16, ptr %scan_events_address, align 2
  %scan_revents = load i16, ptr %scan_revents_address, align 2
  %read_interest_bits = and i16 %scan_events, 256
  %read_interested = icmp ne i16 %read_interest_bits, 0
  %read_ready_bits = and i16 %scan_revents, 770
  %read_ready_raw = icmp ne i16 %read_ready_bits, 0
  %readable = and i1 %read_interested, %read_ready_raw
  %write_interest_bits = and i16 %scan_events, 16
  %write_interested = icmp ne i16 %write_interest_bits, 0
  %write_ready_bits = and i16 %scan_revents, 16
  %write_ready_raw = icmp ne i16 %write_ready_bits, 0
  %writable = and i1 %write_interested, %write_ready_raw
  %error_bits = and i16 %scan_revents, 7
  %has_error = icmp ne i16 %error_bits, 0
  %read_or_write = or i1 %readable, %writable
  %ready = or i1 %read_or_write, %has_error
  br i1 %ready, label %publish, label %advance

publish:
  %output_count = load i64, ptr %output_count_address, align 8
  %event_byte_offset = mul i64 %output_count, %event_stride
  %event = getelementptr i8, ptr %event_buffer, i64 %event_byte_offset
  %interest_scan_offset = mul i64 %scan_index, %interest_stride
  %scan_interest = getelementptr i8, ptr %interests, i64 %interest_scan_offset
  %key_address = getelementptr i8, ptr %scan_interest, i64 %key_offset
  %key = load i64, ptr %key_address, align 8
  %event_key = getelementptr i8, ptr %event, i64 %event_key_offset
  %event_read = getelementptr i8, ptr %event, i64 %event_read_offset
  %event_write = getelementptr i8, ptr %event, i64 %event_write_offset
  %event_error = getelementptr i8, ptr %event, i64 %event_error_offset
  store i64 %key, ptr %event_key, align 8
  store i1 %readable, ptr %event_read, align 1
  store i1 %writable, ptr %event_write, align 1
  store i1 %has_error, ptr %event_error, align 1
  %output_next = add i64 %output_count, 1
  store i64 %output_next, ptr %output_count_address, align 8
  br label %advance

advance:
  %scan_next = add i64 %scan_index, 1
  %scan_done = icmp eq i64 %scan_next, %interest_count
  br i1 %scan_done, label %success, label %scan

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid

success_empty:
  store i64 0, ptr %event_length_address, align 8
  %empty_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %empty_result

success:
  %published = load i64, ptr %output_count_address, align 8
  store i64 %published, ptr %event_length_address, align 8
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %published, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal void @sollang_platform_socket_cleanup() #0 {
entry:
  %claimed = cmpxchg ptr @sollang_winsock_state, i32 1, i32 0 acq_rel acquire
  %started = extractvalue { i32, i1 } %claimed, 1
  br i1 %started, label %cleanup, label %done

cleanup:
  %ignored = call i32 @WSACleanup()
  br label %done

done:
  ret void
}

define internal i16 @sollang_socket_network_port(i16 %port) #0 {
entry:
  %low = shl i16 %port, 8
  %high = lshr i16 %port, 8
  %network = or i16 %low, %high
  ret i16 %network
}

define internal i32 @sollang_socket_network_u32(i32 %value) #0 {
entry:
  %a = shl i32 %value, 24
  %b0 = shl i32 %value, 8
  %b = and i32 %b0, 16711680
  %c0 = lshr i32 %value, 8
  %c = and i32 %c0, 65280
  %d = lshr i32 %value, 24
  %ab = or i32 %a, %b
  %cd = or i32 %c, %d
  %network = or i32 %ab, %cd
  ret i32 %network
}

define internal i32 @sollang_socket_address(ptr %endpoint, ptr %storage) #0 {
entry:
  call void @llvm.memset.p0.i64(ptr %storage, i8 0, i64 28, i1 false)
  %family = load i32, ptr %endpoint, align 4
  switch i32 %family, label %invalid [
    i32 4, label %ipv4
    i32 6, label %ipv6
  ]

ipv4:
  store i16 2, ptr %storage, align 2
  %port4_source = getelementptr i8, ptr %endpoint, i64 20
  %port4 = load i16, ptr %port4_source, align 2
  %network_port4 = call i16 @sollang_socket_network_port(i16 %port4)
  %port4_target = getelementptr i8, ptr %storage, i64 2
  store i16 %network_port4, ptr %port4_target, align 2
  br label %ipv4_copy

ipv4_copy:
  %octet = phi i64 [ 0, %ipv4 ], [ %octet_next, %ipv4_copy ]
  %endpoint_offset = mul i64 %octet, 2
  %endpoint_index = add i64 %endpoint_offset, 4
  %octet_source = getelementptr i8, ptr %endpoint, i64 %endpoint_index
  %octet_word = load i16, ptr %octet_source, align 2
  %octet_value = trunc i16 %octet_word to i8
  %socket_index = add i64 %octet, 4
  %octet_target = getelementptr i8, ptr %storage, i64 %socket_index
  store i8 %octet_value, ptr %octet_target, align 1
  %octet_next = add i64 %octet, 1
  %octets_complete = icmp eq i64 %octet_next, 4
  br i1 %octets_complete, label %ipv4_done, label %ipv4_copy

ipv4_done:
  ret i32 2

ipv6:
  store i16 23, ptr %storage, align 2
  %port6_source = getelementptr i8, ptr %endpoint, i64 20
  %port6 = load i16, ptr %port6_source, align 2
  %network_port6 = call i16 @sollang_socket_network_port(i16 %port6)
  %port6_target = getelementptr i8, ptr %storage, i64 2
  store i16 %network_port6, ptr %port6_target, align 2
  %flow_source = getelementptr i8, ptr %endpoint, i64 24
  %flow = load i32, ptr %flow_source, align 4
  %network_flow = call i32 @sollang_socket_network_u32(i32 %flow)
  %flow_target = getelementptr i8, ptr %storage, i64 4
  store i32 %network_flow, ptr %flow_target, align 4
  %scope_source = getelementptr i8, ptr %endpoint, i64 28
  %scope = load i32, ptr %scope_source, align 4
  %scope_target = getelementptr i8, ptr %storage, i64 24
  store i32 %scope, ptr %scope_target, align 4
  br label %ipv6_copy

ipv6_copy:
  %group = phi i64 [ 0, %ipv6 ], [ %group_next, %ipv6_copy ]
  %group_offset = mul i64 %group, 2
  %group_source_index = add i64 %group_offset, 4
  %group_source = getelementptr i8, ptr %endpoint, i64 %group_source_index
  %group_value = load i16, ptr %group_source, align 2
  %network_group = call i16 @sollang_socket_network_port(i16 %group_value)
  %group_target_index = add i64 %group_offset, 8
  %group_target = getelementptr i8, ptr %storage, i64 %group_target_index
  store i16 %network_group, ptr %group_target, align 2
  %group_next = add i64 %group, 1
  %groups_complete = icmp eq i64 %group_next, 8
  br i1 %groups_complete, label %ipv6_done, label %ipv6_copy

ipv6_done:
  ret i32 23

invalid:
  ret i32 0
}

define internal i32 @sollang_socket_endpoint(ptr %source, ptr %endpoint) #0 {
entry:
  call void @llvm.memset.p0.i64(ptr %endpoint, i8 0, i64 32, i1 false)
  %family16 = load i16, ptr %source, align 2
  %family = zext i16 %family16 to i32
  switch i32 %family, label %invalid [
    i32 2, label %ipv4
    i32 23, label %ipv6
  ]

ipv4:
  store i32 4, ptr %endpoint, align 4
  br label %ipv4_copy

ipv4_copy:
  %octet = phi i64 [ 0, %ipv4 ], [ %octet_next, %ipv4_copy ]
  %source_index = add i64 %octet, 4
  %octet_source = getelementptr i8, ptr %source, i64 %source_index
  %octet_value = load i8, ptr %octet_source, align 1
  %octet_word = zext i8 %octet_value to i16
  %endpoint_offset = mul i64 %octet, 2
  %endpoint_index = add i64 %endpoint_offset, 4
  %octet_target = getelementptr i8, ptr %endpoint, i64 %endpoint_index
  store i16 %octet_word, ptr %octet_target, align 2
  %octet_next = add i64 %octet, 1
  %octets_complete = icmp eq i64 %octet_next, 4
  br i1 %octets_complete, label %publish_ipv4, label %ipv4_copy

publish_ipv4:
  %network_port4_address = getelementptr i8, ptr %source, i64 2
  %network_port4 = load i16, ptr %network_port4_address, align 2
  %port4 = call i16 @sollang_socket_network_port(i16 %network_port4)
  %port4_target = getelementptr i8, ptr %endpoint, i64 20
  store i16 %port4, ptr %port4_target, align 2
  ret i32 4

ipv6:
  store i32 6, ptr %endpoint, align 4
  br label %ipv6_copy

ipv6_copy:
  %group = phi i64 [ 0, %ipv6 ], [ %group_next, %ipv6_copy ]
  %group_offset = mul i64 %group, 2
  %source_index6 = add i64 %group_offset, 8
  %group_source = getelementptr i8, ptr %source, i64 %source_index6
  %network_group = load i16, ptr %group_source, align 2
  %group_value = call i16 @sollang_socket_network_port(i16 %network_group)
  %endpoint_index6 = add i64 %group_offset, 4
  %group_target = getelementptr i8, ptr %endpoint, i64 %endpoint_index6
  store i16 %group_value, ptr %group_target, align 2
  %group_next = add i64 %group, 1
  %groups_complete = icmp eq i64 %group_next, 8
  br i1 %groups_complete, label %publish_ipv6, label %ipv6_copy

publish_ipv6:
  %network_port6_address = getelementptr i8, ptr %source, i64 2
  %network_port6 = load i16, ptr %network_port6_address, align 2
  %port6 = call i16 @sollang_socket_network_port(i16 %network_port6)
  %port6_target = getelementptr i8, ptr %endpoint, i64 20
  store i16 %port6, ptr %port6_target, align 2
  %network_flow_address = getelementptr i8, ptr %source, i64 4
  %network_flow = load i32, ptr %network_flow_address, align 4
  %flow = call i32 @sollang_socket_network_u32(i32 %network_flow)
  %flow_target = getelementptr i8, ptr %endpoint, i64 24
  store i32 %flow, ptr %flow_target, align 4
  %scope_address = getelementptr i8, ptr %source, i64 24
  %scope = load i32, ptr %scope_address, align 4
  %scope_target = getelementptr i8, ptr %endpoint, i64 28
  store i32 %scope, ptr %scope_target, align 4
  ret i32 6

invalid:
  ret i32 0
}

define internal %sollang.socket_result @sollang_platform_socket_listen(ptr %endpoint, i64 %backlog, i1 %reuse) #0 {
entry:
  %started = call i32 @sollang_winsock_ensure_started()
  %start_ok = icmp eq i32 %started, 0
  br i1 %start_ok, label %validate_backlog, label %start_failed

start_failed:
  %start_kind = call i32 @sollang_socket_error_kind(i32 %started)
  %start_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %start_kind, i32 %started)
  ret %sollang.socket_result %start_result

validate_backlog:
  %backlog_positive = icmp sgt i64 %backlog, 0
  %backlog_fits = icmp sle i64 %backlog, 2147483647
  %backlog_valid = and i1 %backlog_positive, %backlog_fits
  br i1 %backlog_valid, label %parse, label %invalid_argument

parse:
  %socket_address = alloca [28 x i8], align 8
  %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
  %address_valid = icmp ne i32 %family, 0
  br i1 %address_valid, label %create, label %invalid_address

create:
  %socket = call i64 @WSASocketW(i32 %family, i32 1, i32 6, ptr null, i32 0, i32 129)
  %created = icmp ne i64 %socket, -1
  br i1 %created, label %configure, label %create_failed

configure:
  br i1 %reuse, label %set_reuse, label %bind_socket

set_reuse:
  %reuse_value = alloca i32, align 4
  store i32 1, ptr %reuse_value, align 4
  %reuse_status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4, ptr %reuse_value, i32 4)
  %reuse_ok = icmp eq i32 %reuse_status, 0
  br i1 %reuse_ok, label %bind_socket, label %socket_failed

bind_socket:
  %is_ipv4 = icmp eq i32 %family, 2
  %address_size = select i1 %is_ipv4, i32 16, i32 28
  %bind_status = call i32 @bind(i64 %socket, ptr %socket_address, i32 %address_size)
  %bind_ok = icmp eq i32 %bind_status, 0
  br i1 %bind_ok, label %listen_socket, label %socket_failed

listen_socket:
  %backlog32 = trunc i64 %backlog to i32
  %listen_status = call i32 @listen(i64 %socket, i32 %backlog32)
  %listen_ok = icmp eq i32 %listen_status, 0
  br i1 %listen_ok, label %success, label %socket_failed

socket_failed:
  %socket_error = call i32 @WSAGetLastError()
  %close_failed_socket = call i32 @closesocket(i64 %socket)
  %socket_kind = call i32 @sollang_socket_error_kind(i32 %socket_error)
  %socket_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %socket_kind, i32 %socket_error)
  ret %sollang.socket_result %socket_result

create_failed:
  %create_error = call i32 @WSAGetLastError()
  %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
  %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
  ret %sollang.socket_result %create_result

invalid_address:
  %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %address_result

invalid_argument:
  %argument_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %argument_result

success:
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal %sollang.socket_result @sollang_platform_socket_connect(ptr %endpoint) #0 {
entry:
  %started = call i32 @sollang_winsock_ensure_started()
  %start_ok = icmp eq i32 %started, 0
  br i1 %start_ok, label %parse, label %start_failed

start_failed:
  %start_kind = call i32 @sollang_socket_error_kind(i32 %started)
  %start_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %start_kind, i32 %started)
  ret %sollang.socket_result %start_result

parse:
  %socket_address = alloca [28 x i8], align 8
  %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
  %address_valid = icmp ne i32 %family, 0
  br i1 %address_valid, label %create, label %invalid_address

create:
  %socket = call i64 @WSASocketW(i32 %family, i32 1, i32 6, ptr null, i32 0, i32 129)
  %created = icmp ne i64 %socket, -1
  br i1 %created, label %connect_socket, label %create_failed

connect_socket:
  %is_ipv4 = icmp eq i32 %family, 2
  %address_size = select i1 %is_ipv4, i32 16, i32 28
  %connect_status = call i32 @connect(i64 %socket, ptr %socket_address, i32 %address_size)
  %connect_ok = icmp eq i32 %connect_status, 0
  br i1 %connect_ok, label %success, label %connect_failed

connect_failed:
  %connect_error = call i32 @WSAGetLastError()
  %close_failed_socket = call i32 @closesocket(i64 %socket)
  %connect_kind = call i32 @sollang_socket_error_kind(i32 %connect_error)
  %connect_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %connect_kind, i32 %connect_error)
  ret %sollang.socket_result %connect_result

create_failed:
  %create_error = call i32 @WSAGetLastError()
  %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
  %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
  ret %sollang.socket_result %create_result

invalid_address:
  %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %address_result

success:
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal %sollang.socket_result @sollang_platform_socket_accept(i64 %listener) #0 {
entry:
  %socket = call i64 @accept(i64 %listener, ptr null, ptr null)
  %accepted = icmp ne i64 %socket, -1
  br i1 %accepted, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_receive(i64 %socket, ptr %buffer, i64 %capacity, i32 %flags) #0 {
entry:
  %positive = icmp ugt i64 %capacity, 0
  %fits = icmp ule i64 %capacity, 2147483647
  %valid = and i1 %positive, %fits
  br i1 %valid, label %receive, label %invalid_argument

receive:
  %capacity32 = trunc i64 %capacity to i32
  %count32 = call i32 @recv(i64 %socket, ptr %buffer, i32 %capacity32, i32 %flags)
  %ok = icmp sge i32 %count32, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid

success:
  %count = zext i32 %count32 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_receive_append(i64 %socket, ptr %buffer, i64 %buffer_length, i64 %buffer_capacity) #0 {
entry:
  %length_valid = icmp ult i64 %buffer_length, %buffer_capacity
  br i1 %length_valid, label %receive_append, label %invalid_argument

receive_append:
  %start = getelementptr i8, ptr %buffer, i64 %buffer_length
  %remaining = sub i64 %buffer_capacity, %buffer_length
  %result = call %sollang.socket_result @sollang_platform_socket_receive(i64 %socket, ptr %start, i64 %remaining, i32 0)
  ret %sollang.socket_result %result

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid
}

define internal %sollang.socket_result @sollang_platform_socket_send(i64 %socket, ptr %buffer, i64 %length) #0 {
entry:
  %fits = icmp ule i64 %length, 2147483647
  br i1 %fits, label %send_bytes, label %invalid_argument

send_bytes:
  %length32 = trunc i64 %length to i32
  %count32 = call i32 @send(i64 %socket, ptr %buffer, i32 %length32, i32 0)
  %ok = icmp sge i32 %count32, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid

success:
  %count = zext i32 %count32 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_send_range(i64 %socket, ptr %buffer, i64 %buffer_length, i64 %offset, i64 %length) #0 {
entry:
  %offset_valid = icmp ule i64 %offset, %buffer_length
  br i1 %offset_valid, label %check_length, label %invalid_argument

check_length:
  %remaining = sub i64 %buffer_length, %offset
  %length_valid = icmp ule i64 %length, %remaining
  br i1 %length_valid, label %send_range, label %invalid_argument

send_range:
  %start = getelementptr i8, ptr %buffer, i64 %offset
  %result = call %sollang.socket_result @sollang_platform_socket_send(i64 %socket, ptr %start, i64 %length)
  ret %sollang.socket_result %result

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid
}

define internal %sollang.socket_result @sollang_platform_socket_send_vectored(i64 %socket, ptr %buffers, i64 %buffer_count, i64 %stride, i64 %bytes_field_offset, i64 %offset_field_offset, i64 %length_field_offset) #0 {
entry:
  %count_valid = icmp ule i64 %buffer_count, 64
  br i1 %count_valid, label %check_empty, label %invalid_argument

check_empty:
  %empty = icmp eq i64 %buffer_count, 0
  br i1 %empty, label %success_empty, label %prepare

prepare:
  %native_buffers = alloca { i32, ptr }, i64 %buffer_count, align 8
  br label %build

build:
  %index = phi i64 [ 0, %prepare ], [ %next, %store_buffer ]
  %descriptor_offset = mul i64 %index, %stride
  %descriptor = getelementptr i8, ptr %buffers, i64 %descriptor_offset
  %bytes_address = getelementptr i8, ptr %descriptor, i64 %bytes_field_offset
  %bytes = load ptr, ptr %bytes_address, align 8
  %bytes_valid = icmp ne ptr %bytes, null
  br i1 %bytes_valid, label %load_range, label %invalid_argument

load_range:
  %data = load ptr, ptr %bytes, align 8
  %buffer_length_address = getelementptr i8, ptr %bytes, i64 8
  %buffer_length = load i64, ptr %buffer_length_address, align 8
  %range_offset_address = getelementptr i8, ptr %descriptor, i64 %offset_field_offset
  %range_offset = load i64, ptr %range_offset_address, align 8
  %range_length_address = getelementptr i8, ptr %descriptor, i64 %length_field_offset
  %range_length = load i64, ptr %range_length_address, align 8
  %offset_valid = icmp ule i64 %range_offset, %buffer_length
  br i1 %offset_valid, label %check_range_length, label %invalid_argument

check_range_length:
  %remaining = sub i64 %buffer_length, %range_offset
  %length_valid = icmp ule i64 %range_length, %remaining
  %length_fits = icmp ule i64 %range_length, 4294967295
  %range_valid = and i1 %length_valid, %length_fits
  br i1 %range_valid, label %store_buffer, label %invalid_argument

store_buffer:
  %start = getelementptr i8, ptr %data, i64 %range_offset
  %native_buffer = getelementptr { i32, ptr }, ptr %native_buffers, i64 %index
  %native_length = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 0
  %native_data = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 1
  %range_length32 = trunc i64 %range_length to i32
  store i32 %range_length32, ptr %native_length, align 4
  store ptr %start, ptr %native_data, align 8
  %next = add i64 %index, 1
  %done = icmp eq i64 %next, %buffer_count
  br i1 %done, label %send_buffers, label %build

send_buffers:
  %sent_address = alloca i32, align 4
  %buffer_count32 = trunc i64 %buffer_count to i32
  %status = call i32 @WSASend(i64 %socket, ptr %native_buffers, i32 %buffer_count32, ptr %sent_address, i32 0, ptr null, ptr null)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid

success_empty:
  %empty_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %empty_result

success:
  %sent32 = load i32, ptr %sent_address, align 4
  %sent = zext i32 %sent32 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %sent, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_receive_vectored(i64 %socket, ptr %buffers, i64 %buffer_count, i64 %stride, i64 %bytes_field_offset) #0 {
entry:
  %count_valid = icmp ule i64 %buffer_count, 64
  br i1 %count_valid, label %check_empty, label %invalid_argument

check_empty:
  %empty = icmp eq i64 %buffer_count, 0
  br i1 %empty, label %success_empty, label %prepare

prepare:
  %native_buffers = alloca { i32, ptr }, i64 %buffer_count, align 8
  br label %build

build:
  %index = phi i64 [ 0, %prepare ], [ %next, %store_buffer ]
  %descriptor_offset = mul i64 %index, %stride
  %descriptor = getelementptr i8, ptr %buffers, i64 %descriptor_offset
  %bytes = getelementptr i8, ptr %descriptor, i64 %bytes_field_offset
  %data = load ptr, ptr %bytes, align 8
  %capacity_address = getelementptr i8, ptr %bytes, i64 16
  %capacity = load i64, ptr %capacity_address, align 8
  %capacity_fits = icmp ule i64 %capacity, 4294967295
  br i1 %capacity_fits, label %store_buffer, label %invalid_argument

store_buffer:
  %native_buffer = getelementptr { i32, ptr }, ptr %native_buffers, i64 %index
  %native_length = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 0
  %native_data = getelementptr { i32, ptr }, ptr %native_buffer, i32 0, i32 1
  %capacity32 = trunc i64 %capacity to i32
  store i32 %capacity32, ptr %native_length, align 4
  store ptr %data, ptr %native_data, align 8
  %next = add i64 %index, 1
  %done = icmp eq i64 %next, %buffer_count
  br i1 %done, label %receive_buffers, label %build

receive_buffers:
  %received_address = alloca i32, align 4
  %flags_address = alloca i32, align 4
  store i32 0, ptr %flags_address, align 4
  %buffer_count32 = trunc i64 %buffer_count to i32
  %status = call i32 @WSARecv(i64 %socket, ptr %native_buffers, i32 %buffer_count32, ptr %received_address, ptr %flags_address, ptr null, ptr null)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %publish_prepare, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

publish_prepare:
  %received32 = load i32, ptr %received_address, align 4
  %received = zext i32 %received32 to i64
  br label %publish

publish:
  %publish_index = phi i64 [ 0, %publish_prepare ], [ %publish_next, %publish_store ]
  %remaining = phi i64 [ %received, %publish_prepare ], [ %remaining_next, %publish_store ]
  %publish_descriptor_offset = mul i64 %publish_index, %stride
  %publish_descriptor = getelementptr i8, ptr %buffers, i64 %publish_descriptor_offset
  %publish_bytes = getelementptr i8, ptr %publish_descriptor, i64 %bytes_field_offset
  %publish_capacity_address = getelementptr i8, ptr %publish_bytes, i64 16
  %publish_capacity = load i64, ptr %publish_capacity_address, align 8
  %fills_segment = icmp uge i64 %remaining, %publish_capacity
  %published_length = select i1 %fills_segment, i64 %publish_capacity, i64 %remaining
  %remaining_next = sub i64 %remaining, %published_length
  %published_length_address = getelementptr i8, ptr %publish_bytes, i64 8
  br label %publish_store

publish_store:
  store i64 %published_length, ptr %published_length_address, align 8
  %publish_next = add i64 %publish_index, 1
  %publish_done = icmp eq i64 %publish_next, %buffer_count
  br i1 %publish_done, label %success, label %publish

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid

success_empty:
  %empty_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %empty_result

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 %received, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_shutdown(i64 %socket, i32 %direction) #0 {
entry:
  %status = call i32 @shutdown(i64 %socket, i32 %direction)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_set_no_delay(i64 %socket, i1 %enabled) #0 {
entry:
  %value = alloca i32, align 4
  %value32 = zext i1 %enabled to i32
  store i32 %value32, ptr %value, align 4
  %status = call i32 @setsockopt(i64 %socket, i32 6, i32 1, ptr %value, i32 4)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_no_delay(i64 %socket) #0 {
entry:
  %value = alloca i32, align 4
  %length = alloca i32, align 4
  store i32 0, ptr %value, align 4
  store i32 4, ptr %length, align 4
  %status = call i32 @getsockopt(i64 %socket, i32 6, i32 1, ptr %value, ptr %length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %value32 = load i32, ptr %value, align 4
  %value64 = zext i32 %value32 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %value64, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_set_keep_alive(i64 %socket, i1 %enabled) #0 {
entry:
  %value = alloca i32, align 4
  %value32 = zext i1 %enabled to i32
  store i32 %value32, ptr %value, align 4
  %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 8, ptr %value, i32 4)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_keep_alive(i64 %socket) #0 {
entry:
  %value = alloca i32, align 4
  %length = alloca i32, align 4
  store i32 0, ptr %value, align 4
  store i32 4, ptr %length, align 4
  %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 8, ptr %value, ptr %length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %value32 = load i32, ptr %value, align 4
  %value64 = zext i32 %value32 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %value64, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_set_linger(i64 %socket, i1 %enabled, i64 %millis) #0 {
entry:
  %checked_millis = select i1 %enabled, i64 %millis, i64 1
  %positive = icmp sgt i64 %checked_millis, 0
  %fits = icmp ule i64 %checked_millis, 65535000
  %duration_valid = and i1 %positive, %fits
  %disabled = xor i1 %enabled, true
  %valid = or i1 %disabled, %duration_valid
  br i1 %valid, label %configure, label %invalid_argument

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 10022)
  ret %sollang.socket_result %invalid

configure:
  %value = alloca [2 x i16], align 2
  %onoff = zext i1 %enabled to i16
  %rounded = add i64 %checked_millis, 999
  %seconds64 = udiv i64 %rounded, 1000
  %seconds = trunc i64 %seconds64 to i16
  %onoff_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 0
  %seconds_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 1
  store i16 %onoff, ptr %onoff_address, align 2
  store i16 %seconds, ptr %seconds_address, align 2
  %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 128, ptr %value, i32 4)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_linger(i64 %socket) #0 {
entry:
  %value = alloca [2 x i16], align 2
  %length = alloca i32, align 4
  store i32 0, ptr %value, align 2
  store i32 4, ptr %length, align 4
  %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 128, ptr %value, ptr %length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %decode, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

decode:
  %onoff_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 0
  %seconds_address = getelementptr inbounds [2 x i16], ptr %value, i32 0, i32 1
  %onoff = load i16, ptr %onoff_address, align 2
  %seconds = load i16, ptr %seconds_address, align 2
  %enabled = icmp ne i16 %onoff, 0
  %seconds64 = zext i16 %seconds to i64
  %millis = mul i64 %seconds64, 1000
  %selected = select i1 %enabled, i64 %millis, i64 -1
  %result = call %sollang.socket_result @sollang_socket_result(i64 %selected, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_set_read_timeout(i64 %socket, i1 %has_timeout, i64 %millis) #0 {
entry:
  %positive = icmp sgt i64 %millis, 0
  %fits = icmp ule i64 %millis, 4294967295
  %duration_valid = and i1 %positive, %fits
  %disabled = xor i1 %has_timeout, true
  %valid = or i1 %disabled, %duration_valid
  br i1 %valid, label %configure, label %invalid_argument

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 10022)
  ret %sollang.socket_result %invalid

configure:
  %value = alloca i32, align 4
  %millis32 = trunc i64 %millis to i32
  %selected = select i1 %has_timeout, i32 %millis32, i32 0
  store i32 %selected, ptr %value, align 4
  %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4102, ptr %value, i32 4)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_read_timeout(i64 %socket) #0 {
entry:
  %value = alloca i32, align 4
  %length = alloca i32, align 4
  store i32 0, ptr %value, align 4
  store i32 4, ptr %length, align 4
  %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 4102, ptr %value, ptr %length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %value32 = load i32, ptr %value, align 4
  %value64 = zext i32 %value32 to i64
  %disabled = icmp eq i32 %value32, 0
  %timeout = select i1 %disabled, i64 -1, i64 %value64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %timeout, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_set_write_timeout(i64 %socket, i1 %has_timeout, i64 %millis) #0 {
entry:
  %positive = icmp sgt i64 %millis, 0
  %fits = icmp ule i64 %millis, 4294967295
  %duration_valid = and i1 %positive, %fits
  %disabled = xor i1 %has_timeout, true
  %valid = or i1 %disabled, %duration_valid
  br i1 %valid, label %configure, label %invalid_argument

invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 10022)
  ret %sollang.socket_result %invalid

configure:
  %value = alloca i32, align 4
  %millis32 = trunc i64 %millis to i32
  %selected = select i1 %has_timeout, i32 %millis32, i32 0
  store i32 %selected, ptr %value, align 4
  %status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4101, ptr %value, i32 4)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_write_timeout(i64 %socket) #0 {
entry:
  %value = alloca i32, align 4
  %length = alloca i32, align 4
  store i32 0, ptr %value, align 4
  store i32 4, ptr %length, align 4
  %status = call i32 @getsockopt(i64 %socket, i32 65535, i32 4101, ptr %value, ptr %length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure

failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed

success:
  %value32 = load i32, ptr %value, align 4
  %value64 = zext i32 %value32 to i64
  %disabled = icmp eq i32 %value32, 0
  %timeout = select i1 %disabled, i64 -1, i64 %value64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %timeout, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_bind_datagram(ptr %endpoint, i1 %reuse) #0 {
entry:
  %started = call i32 @sollang_winsock_ensure_started()
  %start_ok = icmp eq i32 %started, 0
  br i1 %start_ok, label %parse, label %start_failed
start_failed:
  %start_kind = call i32 @sollang_socket_error_kind(i32 %started)
  %start_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %start_kind, i32 %started)
  ret %sollang.socket_result %start_result
parse:
  %socket_address = alloca [28 x i8], align 8
  %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
  %address_valid = icmp ne i32 %family, 0
  br i1 %address_valid, label %create, label %invalid_address
create:
  %socket = call i64 @WSASocketW(i32 %family, i32 2, i32 17, ptr null, i32 0, i32 129)
  %created = icmp ne i64 %socket, -1
  br i1 %created, label %configure, label %create_failed
configure:
  br i1 %reuse, label %set_reuse, label %bind_socket
set_reuse:
  %reuse_value = alloca i32, align 4
  store i32 1, ptr %reuse_value, align 4
  %reuse_status = call i32 @setsockopt(i64 %socket, i32 65535, i32 4, ptr %reuse_value, i32 4)
  %reuse_ok = icmp eq i32 %reuse_status, 0
  br i1 %reuse_ok, label %bind_socket, label %socket_failed
bind_socket:
  %is_ipv4 = icmp eq i32 %family, 2
  %address_size = select i1 %is_ipv4, i32 16, i32 28
  %bind_status = call i32 @bind(i64 %socket, ptr %socket_address, i32 %address_size)
  %bind_ok = icmp eq i32 %bind_status, 0
  br i1 %bind_ok, label %success, label %socket_failed
socket_failed:
  %socket_error = call i32 @WSAGetLastError()
  %ignored_close = call i32 @closesocket(i64 %socket)
  %socket_kind = call i32 @sollang_socket_error_kind(i32 %socket_error)
  %socket_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %socket_kind, i32 %socket_error)
  ret %sollang.socket_result %socket_result
create_failed:
  %create_error = call i32 @WSAGetLastError()
  %create_kind = call i32 @sollang_socket_error_kind(i32 %create_error)
  %create_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %create_kind, i32 %create_error)
  ret %sollang.socket_result %create_result
invalid_address:
  %invalid_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %invalid_result
success:
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %socket, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}

define internal %sollang.socket_result @sollang_platform_socket_send_to(i64 %socket, ptr %endpoint, ptr %buffer, i64 %length) #0 {
entry:
  %fits = icmp ule i64 %length, 2147483647
  br i1 %fits, label %parse, label %invalid_argument
parse:
  %socket_address = alloca [28 x i8], align 8
  %family = call i32 @sollang_socket_address(ptr %endpoint, ptr %socket_address)
  %valid = icmp ne i32 %family, 0
  br i1 %valid, label %send_datagram, label %invalid_address
send_datagram:
  %is_ipv4 = icmp eq i32 %family, 2
  %address_size = select i1 %is_ipv4, i32 16, i32 28
  %length32 = trunc i64 %length to i32
  %count32 = call i32 @sendto(i64 %socket, ptr %buffer, i32 %length32, i32 0, ptr %socket_address, i32 %address_size)
  %ok = icmp sge i32 %count32, 0
  br i1 %ok, label %success, label %failure
failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed
invalid_address:
  %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %address_result
invalid_argument:
  %argument_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %argument_result
success:
  %count = zext i32 %count32 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_local_port(i64 %socket) #0 {
entry:
  %address = alloca [28 x i8], align 8
  %address_length = alloca i32, align 4
  store i32 28, ptr %address_length, align 4
  %status = call i32 @getsockname(i64 %socket, ptr %address, ptr %address_length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %success, label %failure
failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed
success:
  %network_port_address = getelementptr i8, ptr %address, i64 2
  %network_port = load i16, ptr %network_port_address, align 2
  %port16 = call i16 @sollang_socket_network_port(i16 %network_port)
  %port = zext i16 %port16 to i64
  %result = call %sollang.socket_result @sollang_socket_result(i64 %port, i32 -1, i32 0)
  ret %sollang.socket_result %result
}

define internal %sollang.socket_result @sollang_platform_socket_local_endpoint(i64 %socket, ptr %endpoint) #0 {
entry:
  %address = alloca [28 x i8], align 8
  %address_length = alloca i32, align 4
  store i32 28, ptr %address_length, align 4
  %status = call i32 @getsockname(i64 %socket, ptr %address, ptr %address_length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %pack, label %failure
pack:
  %family = call i32 @sollang_socket_endpoint(ptr %address, ptr %endpoint)
  %packed = icmp ne i32 %family, 0
  br i1 %packed, label %success, label %invalid_address
success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed
invalid_address:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %invalid
}

define internal %sollang.socket_result @sollang_platform_socket_remote_endpoint(i64 %socket, ptr %endpoint) #0 {
entry:
  %address = alloca [28 x i8], align 8
  %address_length = alloca i32, align 4
  store i32 28, ptr %address_length, align 4
  %status = call i32 @getpeername(i64 %socket, ptr %address, ptr %address_length)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %pack, label %failure
pack:
  %family = call i32 @sollang_socket_endpoint(ptr %address, ptr %endpoint)
  %packed = icmp ne i32 %family, 0
  br i1 %packed, label %success, label %invalid_address
success:
  %result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 -1, i32 0)
  ret %sollang.socket_result %result
failure:
  %error = call i32 @WSAGetLastError()
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed
invalid_address:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %invalid
}

define internal %sollang.socket_result @sollang_platform_socket_receive_from(i64 %socket, ptr %buffer, i64 %capacity, i32 %flags, ptr %endpoint, ptr %truncated) #0 {
entry:
  store i8 0, ptr %truncated, align 1
  %positive = icmp ugt i64 %capacity, 0
  %fits = icmp ule i64 %capacity, 2147483647
  %valid = and i1 %positive, %fits
  br i1 %valid, label %receive, label %invalid_argument
receive:
  %source = alloca [28 x i8], align 8
  %source_length = alloca i32, align 4
  %received = alloca i32, align 4
  %received_flags = alloca i32, align 4
  %wsabuf = alloca { i32, ptr }, align 8
  store i32 28, ptr %source_length, align 4
  store i32 0, ptr %received, align 4
  store i32 %flags, ptr %received_flags, align 4
  %capacity32 = trunc i64 %capacity to i32
  %wsabuf_length = getelementptr inbounds { i32, ptr }, ptr %wsabuf, i32 0, i32 0
  %wsabuf_buffer = getelementptr inbounds { i32, ptr }, ptr %wsabuf, i32 0, i32 1
  store i32 %capacity32, ptr %wsabuf_length, align 4
  store ptr %buffer, ptr %wsabuf_buffer, align 8
  %status = call i32 @WSARecvFrom(i64 %socket, ptr %wsabuf, i32 1, ptr %received, ptr %received_flags, ptr %source, ptr %source_length, ptr null, ptr null)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %received_ok, label %classify_failure
received_ok:
  %received32 = load i32, ptr %received, align 4
  %count_ok = zext i32 %received32 to i64
  br label %pack
classify_failure:
  %error = call i32 @WSAGetLastError()
  %message_too_large = icmp eq i32 %error, 10040
  br i1 %message_too_large, label %received_truncated, label %failure
received_truncated:
  store i8 1, ptr %truncated, align 1
  br label %pack
pack:
  %count = phi i64 [ %count_ok, %received_ok ], [ %capacity, %received_truncated ]
  %family = call i32 @sollang_socket_endpoint(ptr %source, ptr %endpoint)
  %packed = icmp ne i32 %family, 0
  br i1 %packed, label %publish, label %invalid_address
publish:
  %result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
  ret %sollang.socket_result %result
failure:
  %kind = call i32 @sollang_socket_error_kind(i32 %error)
  %failed = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 %kind, i32 %error)
  ret %sollang.socket_result %failed
invalid_address:
  %address_result = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 0, i32 0)
  ret %sollang.socket_result %address_result
invalid_argument:
  %invalid = call %sollang.socket_result @sollang_socket_result(i64 -1, i32 1, i32 0)
  ret %sollang.socket_result %invalid
}

define internal void @sollang_platform_close_socket(i64 %socket) #0 {
entry:
  %valid = icmp ne i64 %socket, -1
  br i1 %valid, label %close, label %done

close:
  %ignored = call i32 @closesocket(i64 %socket)
  br label %done

done:
  ret void
}

define internal i32 @sollang_dns_windows_error_kind(i32 %code) #0 {
entry:
  switch i32 %code, label %system [
    i32 11001, label %not_found
    i32 11002, label %temporary
    i32 10047, label %family
  ]
not_found:
  ret i32 3
temporary:
  ret i32 4
family:
  ret i32 5
system:
  ret i32 8
}

define internal %sollang.socket_result @sollang_platform_dns_lookup(i32 %policy, ptr %host, i64 %length, i16 %port, i64 %max_host, i64 %maximum, ptr %output) #0 {
entry:
  %valid_maximum_low = icmp ugt i64 %maximum, 0
  %valid_maximum_high = icmp ule i64 %maximum, 64
  %valid_maximum = and i1 %valid_maximum_low, %valid_maximum_high
  %valid_host_limit_low = icmp ugt i64 %max_host, 0
  %valid_host_limit_high = icmp ule i64 %max_host, 253
  %valid_host_limit = and i1 %valid_host_limit_low, %valid_host_limit_high
  %valid_limits = and i1 %valid_maximum, %valid_host_limit
  br i1 %valid_limits, label %validate_host, label %invalid_limit

invalid_limit:
  %invalid_limit_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 0, i32 0)
  ret %sollang.socket_result %invalid_limit_result

validate_host:
  %host_not_empty = icmp ugt i64 %length, 0
  br i1 %host_not_empty, label %validate_host_length, label %invalid_host

validate_host_length:
  %within_policy_limit = icmp ule i64 %length, %max_host
  %within_dns_limit = icmp ule i64 %length, 253
  %within_host_limit = and i1 %within_policy_limit, %within_dns_limit
  br i1 %within_host_limit, label %start_host_copy, label %host_too_long

host_too_long:
  %host_too_long_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 2, i32 0)
  ret %sollang.socket_result %host_too_long_result

start_host_copy:
  %wide_host = alloca [254 x i16], align 2
  br label %copy_host

copy_host:
  %host_index = phi i64 [ 0, %start_host_copy ], [ %host_next, %copy_host_character ]
  %numeric = phi i1 [ true, %start_host_copy ], [ %numeric_next, %copy_host_character ]
  %host_complete = icmp eq i64 %host_index, %length
  br i1 %host_complete, label %finish_host, label %validate_host_character

validate_host_character:
  %host_source = getelementptr i8, ptr %host, i64 %host_index
  %character = load i8, ptr %host_source, align 1
  %lower_a = icmp uge i8 %character, 97
  %lower_z = icmp ule i8 %character, 122
  %lower = and i1 %lower_a, %lower_z
  %upper_a = icmp uge i8 %character, 65
  %upper_z = icmp ule i8 %character, 90
  %upper = and i1 %upper_a, %upper_z
  %digit_0 = icmp uge i8 %character, 48
  %digit_9 = icmp ule i8 %character, 57
  %digit = and i1 %digit_0, %digit_9
  %hyphen = icmp eq i8 %character, 45
  %dot = icmp eq i8 %character, 46
  %letter = or i1 %lower, %upper
  %alphanumeric = or i1 %letter, %digit
  %punctuation = or i1 %hyphen, %dot
  %allowed = or i1 %alphanumeric, %punctuation
  br i1 %allowed, label %copy_host_character, label %invalid_host

copy_host_character:
  %wide_character = zext i8 %character to i16
  %host_target = getelementptr i16, ptr %wide_host, i64 %host_index
  store i16 %wide_character, ptr %host_target, align 2
  %numeric_character = or i1 %digit, %dot
  %numeric_next = and i1 %numeric, %numeric_character
  %host_next = add i64 %host_index, 1
  br label %copy_host

finish_host:
  br i1 %numeric, label %invalid_host, label %terminate_host

terminate_host:
  %terminator = getelementptr i16, ptr %wide_host, i64 %length
  store i16 0, ptr %terminator, align 2
  %started = call i32 @sollang_winsock_ensure_started()
  %start_ok = icmp eq i32 %started, 0
  br i1 %start_ok, label %prepare_lookup, label %startup_failed

startup_failed:
  %startup_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 8, i32 %started)
  ret %sollang.socket_result %startup_result

invalid_host:
  %invalid_host_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 1, i32 0)
  ret %sollang.socket_result %invalid_host_result

prepare_lookup:
  %hints = alloca [48 x i8], align 8
  call void @llvm.memset.p0.i64(ptr %hints, i8 0, i64 48, i1 false)
  %is_ipv4 = icmp eq i32 %policy, 1
  %is_ipv6 = icmp eq i32 %policy, 2
  %selected_ipv6 = select i1 %is_ipv6, i32 23, i32 0
  %selected_family = select i1 %is_ipv4, i32 2, i32 %selected_ipv6
  %family_address = getelementptr i8, ptr %hints, i64 4
  store i32 %selected_family, ptr %family_address, align 4
  %results = alloca ptr, align 8
  store ptr null, ptr %results, align 8
  %lookup_code = call i32 @GetAddrInfoW(ptr %wide_host, ptr null, ptr %hints, ptr %results)
  %lookup_ok = icmp eq i32 %lookup_code, 0
  br i1 %lookup_ok, label %begin_results, label %lookup_failed

lookup_failed:
  %lookup_kind = call i32 @sollang_dns_windows_error_kind(i32 %lookup_code)
  %lookup_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 %lookup_kind, i32 %lookup_code)
  ret %sollang.socket_result %lookup_result

begin_results:
  %first = load ptr, ptr %results, align 8
  %candidate = alloca [32 x i8], align 8
  br label %visit_result

visit_result:
  %current = phi ptr [ %first, %begin_results ], [ %following, %next_result ]
  %count = phi i64 [ 0, %begin_results ], [ %next_count, %next_result ]
  %finished = icmp eq ptr %current, null
  br i1 %finished, label %finish_results, label %convert_result

convert_result:
  %address_pointer = getelementptr i8, ptr %current, i64 32
  %address = load ptr, ptr %address_pointer, align 8
  %has_address = icmp ne ptr %address, null
  br i1 %has_address, label %convert_address, label %skip_result

convert_address:
  %converted_family = call i32 @sollang_socket_endpoint(ptr %address, ptr %candidate)
  %supported_family = icmp ne i32 %converted_family, 0
  br i1 %supported_family, label %set_port, label %skip_result

set_port:
  %port_target = getelementptr i8, ptr %candidate, i64 20
  store i16 %port, ptr %port_target, align 2
  br label %scan_duplicate

scan_duplicate:
  %scan_index = phi i64 [ 0, %set_port ], [ %scan_next, %not_duplicate ]
  %scan_complete = icmp eq i64 %scan_index, %count
  br i1 %scan_complete, label %publish_result, label %compare_result

compare_result:
  %existing_offset = mul i64 %scan_index, 32
  %existing = getelementptr i8, ptr %output, i64 %existing_offset
  %existing0 = load i64, ptr %existing, align 1
  %candidate0 = load i64, ptr %candidate, align 1
  %equal0 = icmp eq i64 %existing0, %candidate0
  %existing8 = getelementptr i8, ptr %existing, i64 8
  %candidate8 = getelementptr i8, ptr %candidate, i64 8
  %existing1 = load i64, ptr %existing8, align 1
  %candidate1 = load i64, ptr %candidate8, align 1
  %equal1 = icmp eq i64 %existing1, %candidate1
  %equal01 = and i1 %equal0, %equal1
  %existing16 = getelementptr i8, ptr %existing, i64 16
  %candidate16 = getelementptr i8, ptr %candidate, i64 16
  %existing2 = load i64, ptr %existing16, align 1
  %candidate2 = load i64, ptr %candidate16, align 1
  %equal2 = icmp eq i64 %existing2, %candidate2
  %existing24 = getelementptr i8, ptr %existing, i64 24
  %candidate24 = getelementptr i8, ptr %candidate, i64 24
  %existing3 = load i64, ptr %existing24, align 1
  %candidate3 = load i64, ptr %candidate24, align 1
  %equal3 = icmp eq i64 %existing3, %candidate3
  %equal23 = and i1 %equal2, %equal3
  %duplicate = and i1 %equal01, %equal23
  br i1 %duplicate, label %skip_result, label %not_duplicate

not_duplicate:
  %scan_next = add i64 %scan_index, 1
  br label %scan_duplicate

publish_result:
  %limit_reached = icmp eq i64 %count, %maximum
  br i1 %limit_reached, label %result_limit, label %copy_result

copy_result:
  %output_offset = mul i64 %count, 32
  %output_item = getelementptr i8, ptr %output, i64 %output_offset
  call void @llvm.memcpy.p0.p0.i64(ptr %output_item, ptr %candidate, i64 32, i1 false)
  %published_count = add i64 %count, 1
  br label %skip_result

skip_result:
  %next_count = phi i64 [ %count, %convert_result ], [ %count, %convert_address ], [ %count, %compare_result ], [ %published_count, %copy_result ]
  br label %next_result

next_result:
  %next_address = getelementptr i8, ptr %current, i64 40
  %following = load ptr, ptr %next_address, align 8
  br label %visit_result

result_limit:
  call void @FreeAddrInfoW(ptr %first)
  %limit_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 6, i32 0)
  ret %sollang.socket_result %limit_result

finish_results:
  %has_first = icmp ne ptr %first, null
  br i1 %has_first, label %release_results, label %no_results

release_results:
  call void @FreeAddrInfoW(ptr %first)
  %has_results = icmp ugt i64 %count, 0
  br i1 %has_results, label %lookup_success, label %no_results

no_results:
  %not_found_result = call %sollang.socket_result @sollang_socket_result(i64 0, i32 3, i32 0)
  ret %sollang.socket_result %not_found_result

lookup_success:
  %success_result = call %sollang.socket_result @sollang_socket_result(i64 %count, i32 -1, i32 0)
  ret %sollang.socket_result %success_result
}
declare void @llvm.trap()
declare i64 @llvm.ctpop.i64(i64)
declare i16 @llvm.cttz.i16(i16, i1 immarg)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg)
declare void @llvm.memcpy.p0.p0.i64(ptr nocapture writeonly, ptr nocapture readonly, i64, i1 immarg)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)

define internal void @sollang_drop_2705(%sollang.int_slice %value) #0 {
entry:
  %fixed_array_ptr0 = extractvalue %sollang.int_slice %value, 0
  %fixed_array_len1 = extractvalue %sollang.int_slice %value, 1
  call void @sollang_free(ptr %fixed_array_ptr0)
  ret void
}

define internal void @sollang_drop_36(%sollang.dynamic_int_array %value) #0 {
entry:
  %drop_array_ptr2 = extractvalue %sollang.dynamic_int_array %value, 0
  call void @sollang_free(ptr %drop_array_ptr2)
  ret void
}

define internal void @sollang_drop_1354(%sollang.struct.1354 %value) #0 {
entry:
  %drop_socket_handle3 = extractvalue %sollang.struct.1354 %value, 0
  call void @sollang_platform_close_socket(i64 %drop_socket_handle3)
  ret void
}

define internal void @sollang_drop_1355(%sollang.struct.1355 %value) #0 {
entry:
  %drop_socket_handle4 = extractvalue %sollang.struct.1355 %value, 0
  call void @sollang_platform_close_socket(i64 %drop_socket_handle4)
  ret void
}

define internal void @sollang_drop_2636(%sollang.enum.2636 %value) #0 {
entry:
  %drop_enum_tag5 = extractvalue %sollang.enum.2636 %value, 0
  switch i32 %drop_enum_tag5, label %bb_drop_enum_end0 [ i32 0, label %bb_drop_enum_variant1 ]
bb_drop_enum_variant1:
  %drop_enum_slot6 = alloca %sollang.enum.2636, align 8
  store %sollang.enum.2636 %value, ptr %drop_enum_slot6, align 8
  %drop_enum_payload_addr7 = getelementptr inbounds %sollang.enum.2636, ptr %drop_enum_slot6, i32 0, i32 1
  %drop_enum_payload8 = load %sollang.struct.1354, ptr %drop_enum_payload_addr7, align 8
  call void @sollang_drop_1354(%sollang.struct.1354 %drop_enum_payload8)
  br label %bb_drop_enum_end0
bb_drop_enum_end0:
  ret void
}

define internal void @sollang_drop_2638(%sollang.enum.2638 %value) #0 {
entry:
  %drop_enum_tag9 = extractvalue %sollang.enum.2638 %value, 0
  switch i32 %drop_enum_tag9, label %bb_drop_enum_end2 [ i32 0, label %bb_drop_enum_variant3 ]
bb_drop_enum_variant3:
  %drop_enum_slot10 = alloca %sollang.enum.2638, align 8
  store %sollang.enum.2638 %value, ptr %drop_enum_slot10, align 8
  %drop_enum_payload_addr11 = getelementptr inbounds %sollang.enum.2638, ptr %drop_enum_slot10, i32 0, i32 1
  %drop_enum_payload12 = load %sollang.struct.1355, ptr %drop_enum_payload_addr11, align 8
  call void @sollang_drop_1355(%sollang.struct.1355 %drop_enum_payload12)
  br label %bb_drop_enum_end2
bb_drop_enum_end2:
  ret void
}

define internal void @sollang_drop_2645(%sollang.enum.2645 %value) #0 {
entry:
  %drop_enum_tag13 = extractvalue %sollang.enum.2645 %value, 0
  switch i32 %drop_enum_tag13, label %bb_drop_enum_end4 [ i32 0, label %bb_drop_enum_variant5 ]
bb_drop_enum_variant5:
  %drop_enum_slot14 = alloca %sollang.enum.2645, align 8
  store %sollang.enum.2645 %value, ptr %drop_enum_slot14, align 8
  %drop_enum_payload_addr15 = getelementptr inbounds %sollang.enum.2645, ptr %drop_enum_slot14, i32 0, i32 1
  %drop_enum_payload16 = load %sollang.dynamic_int_array, ptr %drop_enum_payload_addr15, align 8
  call void @sollang_drop_36(%sollang.dynamic_int_array %drop_enum_payload16)
  br label %bb_drop_enum_end4
bb_drop_enum_end4:
  ret void
}

@.slg.str.module.x.0 = private unnamed_addr constant [24 x i8] c".observe:bb_alloc_fail30", align 1
@.slg.str.module.x.1 = private unnamed_addr constant [24 x i8] c".observe:bb_alloc_fail32", align 1
@.slg.str.module.x.2 = private unnamed_addr constant [24 x i8] c".observe:bb_alloc_fail34", align 1
@.slg.str.module.x.3 = private unnamed_addr constant [24 x i8] c".observe:bb_alloc_fail41", align 1
@.slg.str.module.x.4 = private unnamed_addr constant [40 x i8] c".observe:bb_dynamic_inline_bounds_fail52", align 1
@.slg.str.module.x.5 = private unnamed_addr constant [40 x i8] c".observe:bb_dynamic_inline_bounds_fail56", align 1
@.slg.str.module.x.6 = private unnamed_addr constant [40 x i8] c".observe:bb_dynamic_inline_bounds_fail60", align 1
@.slg.str.module.x.7 = private unnamed_addr constant [40 x i8] c".observe:bb_dynamic_inline_bounds_fail64", align 1
@.slg.str.module.x.8 = private unnamed_addr constant [40 x i8] c".observe:bb_dynamic_inline_bounds_fail68", align 1
define internal ptr @sollang_fn_borrow(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %it) #0 {
entry:
  ret ptr %it
}

define internal %sollang.struct.1357 @sollang_fn_sendBuffer(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %it, i64 %arg_0, i64 %arg_1) #0 {
entry:
  %ref_value0 = load %sollang.dynamic_int_array, ptr %it, align 8
  %array_ptr1 = extractvalue %sollang.dynamic_int_array %ref_value0, 0
  %array_len2 = extractvalue %sollang.dynamic_int_array %ref_value0, 1
  %array_capacity3 = extractvalue %sollang.dynamic_int_array %ref_value0, 2
  %ref_call4 = call ptr @sollang_fn_borrow(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %it)
  %struct_init5 = insertvalue %sollang.struct.1357 poison, ptr %ref_call4, 0
  %struct_init6 = insertvalue %sollang.struct.1357 %struct_init5, i64 %arg_0, 1
  %struct_init7 = insertvalue %sollang.struct.1357 %struct_init6, i64 %arg_1, 2
  ret %sollang.struct.1357 %struct_init7
}

define internal %sollang.enum.2642 @sollang_fn_observe(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.enum.1525 %it) #0 {
entry:
  %stack_slot0 = alloca [8 x i8], align 8
  %socket_endpoint_descriptor4 = alloca [32 x i8], align 8
  %enum_match_slot7 = alloca %sollang.enum.1525, align 8
  %enum_match_slot26 = alloca %sollang.enum.1525, align 8
  %enum_init_slot62 = alloca %sollang.enum.2636, align 8
  %socket_error_kind_slot66 = alloca %sollang.enum.1557, align 8
  %enum_init_slot71 = alloca %sollang.enum.2636, align 8
  %enum_match_slot78 = alloca %sollang.enum.2636, align 8
  %enum_init_slot81 = alloca %sollang.enum.2642, align 8
  %enum_match_slot85 = alloca %sollang.enum.2636, align 8
  %socket_local_endpoint_descriptor88 = alloca [32 x i8], align 8
  %enum_init_slot117 = alloca %sollang.enum.1525, align 8
  %enum_init_slot155 = alloca %sollang.enum.1525, align 8
  %enum_init_slot161 = alloca %sollang.enum.2643, align 8
  %socket_error_kind_slot165 = alloca %sollang.enum.1557, align 8
  %enum_init_slot170 = alloca %sollang.enum.2643, align 8
  %enum_match_slot177 = alloca %sollang.enum.2643, align 8
  %enum_init_slot180 = alloca %sollang.enum.2642, align 8
  %enum_match_slot184 = alloca %sollang.enum.2643, align 8
  %socket_endpoint_descriptor187 = alloca [32 x i8], align 8
  %enum_match_slot190 = alloca %sollang.enum.1525, align 8
  %enum_match_slot209 = alloca %sollang.enum.1525, align 8
  %enum_init_slot242 = alloca %sollang.enum.2638, align 8
  %socket_error_kind_slot246 = alloca %sollang.enum.1557, align 8
  %enum_init_slot251 = alloca %sollang.enum.2638, align 8
  %enum_match_slot258 = alloca %sollang.enum.2638, align 8
  %enum_init_slot261 = alloca %sollang.enum.2642, align 8
  %enum_match_slot265 = alloca %sollang.enum.2638, align 8
  %enum_init_slot275 = alloca %sollang.enum.2638, align 8
  %socket_error_kind_slot279 = alloca %sollang.enum.1557, align 8
  %enum_init_slot284 = alloca %sollang.enum.2638, align 8
  %enum_match_slot291 = alloca %sollang.enum.2638, align 8
  %enum_init_slot294 = alloca %sollang.enum.2642, align 8
  %enum_match_slot298 = alloca %sollang.enum.2638, align 8
  %trap_written304 = alloca i32, align 4
  %trap_written311 = alloca i32, align 4
  %ref_arg319 = alloca %sollang.dynamic_int_array, align 8
  %ref_arg324 = alloca %sollang.dynamic_int_array, align 8
  %trap_written329 = alloca i32, align 4
  %enum_init_slot338 = alloca %sollang.enum.2639, align 8
  %socket_error_kind_slot342 = alloca %sollang.enum.1557, align 8
  %enum_init_slot347 = alloca %sollang.enum.2639, align 8
  %enum_match_slot354 = alloca %sollang.enum.2639, align 8
  %enum_init_slot357 = alloca %sollang.enum.2642, align 8
  %enum_match_slot361 = alloca %sollang.enum.2639, align 8
  %trap_written369 = alloca i32, align 4
  %enum_init_slot376 = alloca %sollang.enum.2645, align 8
  %socket_error_kind_slot383 = alloca %sollang.enum.1557, align 8
  %enum_init_slot388 = alloca %sollang.enum.2645, align 8
  %enum_match_slot395 = alloca %sollang.enum.2645, align 8
  %enum_init_slot398 = alloca %sollang.enum.2642, align 8
  %enum_match_slot402 = alloca %sollang.enum.2645, align 8
  %trap_written418 = alloca i32, align 4
  %trap_written426 = alloca i32, align 4
  %trap_written434 = alloca i32, align 4
  %trap_written442 = alloca i32, align 4
  %trap_written450 = alloca i32, align 4
  %enum_init_slot455 = alloca %sollang.enum.2642, align 8
  %struct_init0 = insertvalue %sollang.struct.1352 poison, %sollang.enum.1525 %it, 0
  %struct_init1 = insertvalue %sollang.struct.1352 %struct_init0, i32 4, 1
  %struct_init2 = insertvalue %sollang.struct.1352 %struct_init1, i1 true, 2
  %socket_field3 = extractvalue %sollang.struct.1352 %struct_init2, 0
  call void @llvm.memset.p0.i64(ptr %socket_endpoint_descriptor4, i8 0, i64 32, i1 false)
  %socket_endpoint_tag5 = extractvalue %sollang.enum.1525 %socket_field3, 0
  %socket_endpoint_is_ipv46 = icmp eq i32 %socket_endpoint_tag5, 0
  br i1 %socket_endpoint_is_ipv46, label %bb_socket_endpoint_ipv40, label %bb_socket_endpoint_ipv61
bb_socket_endpoint_ipv40:
  store %sollang.enum.1525 %socket_field3, ptr %enum_match_slot7, align 8
  %enum_payload_addr8 = getelementptr inbounds %sollang.enum.1525, ptr %enum_match_slot7, i32 0, i32 1
  %enum_payload9 = load %sollang.struct.1220, ptr %enum_payload_addr8, align 2
  %socket_field10 = extractvalue %sollang.struct.1220 %enum_payload9, 0
  %socket_endpoint_family411 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 0
  store i32 4, ptr %socket_endpoint_family411, align 4
  %socket_field12 = extractvalue %sollang.struct.1219 %socket_field10, 0
  %socket_ipv4_octet13 = zext i8 %socket_field12 to i16
  %socket_endpoint_ipv4_a14 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 4
  store i16 %socket_ipv4_octet13, ptr %socket_endpoint_ipv4_a14, align 2
  %socket_field15 = extractvalue %sollang.struct.1219 %socket_field10, 1
  %socket_ipv4_octet16 = zext i8 %socket_field15 to i16
  %socket_endpoint_ipv4_b17 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 6
  store i16 %socket_ipv4_octet16, ptr %socket_endpoint_ipv4_b17, align 2
  %socket_field18 = extractvalue %sollang.struct.1219 %socket_field10, 2
  %socket_ipv4_octet19 = zext i8 %socket_field18 to i16
  %socket_endpoint_ipv4_c20 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 8
  store i16 %socket_ipv4_octet19, ptr %socket_endpoint_ipv4_c20, align 2
  %socket_field21 = extractvalue %sollang.struct.1219 %socket_field10, 3
  %socket_ipv4_octet22 = zext i8 %socket_field21 to i16
  %socket_endpoint_ipv4_d23 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 10
  store i16 %socket_ipv4_octet22, ptr %socket_endpoint_ipv4_d23, align 2
  %socket_field24 = extractvalue %sollang.struct.1220 %enum_payload9, 1
  %socket_endpoint_port425 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 20
  store i16 %socket_field24, ptr %socket_endpoint_port425, align 2
  br label %bb_socket_endpoint_complete2
bb_socket_endpoint_ipv61:
  store %sollang.enum.1525 %socket_field3, ptr %enum_match_slot26, align 8
  %enum_payload_addr27 = getelementptr inbounds %sollang.enum.1525, ptr %enum_match_slot26, i32 0, i32 1
  %enum_payload28 = load %sollang.struct.1222, ptr %enum_payload_addr27, align 4
  %socket_field29 = extractvalue %sollang.struct.1222 %enum_payload28, 0
  %socket_endpoint_family630 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 0
  store i32 6, ptr %socket_endpoint_family630, align 4
  %socket_field31 = extractvalue %sollang.struct.1221 %socket_field29, 0
  %socket_endpoint_ipv6_a32 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 4
  store i16 %socket_field31, ptr %socket_endpoint_ipv6_a32, align 2
  %socket_field33 = extractvalue %sollang.struct.1221 %socket_field29, 1
  %socket_endpoint_ipv6_b34 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 6
  store i16 %socket_field33, ptr %socket_endpoint_ipv6_b34, align 2
  %socket_field35 = extractvalue %sollang.struct.1221 %socket_field29, 2
  %socket_endpoint_ipv6_c36 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 8
  store i16 %socket_field35, ptr %socket_endpoint_ipv6_c36, align 2
  %socket_field37 = extractvalue %sollang.struct.1221 %socket_field29, 3
  %socket_endpoint_ipv6_d38 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 10
  store i16 %socket_field37, ptr %socket_endpoint_ipv6_d38, align 2
  %socket_field39 = extractvalue %sollang.struct.1221 %socket_field29, 4
  %socket_endpoint_ipv6_e40 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 12
  store i16 %socket_field39, ptr %socket_endpoint_ipv6_e40, align 2
  %socket_field41 = extractvalue %sollang.struct.1221 %socket_field29, 5
  %socket_endpoint_ipv6_f42 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 14
  store i16 %socket_field41, ptr %socket_endpoint_ipv6_f42, align 2
  %socket_field43 = extractvalue %sollang.struct.1221 %socket_field29, 6
  %socket_endpoint_ipv6_g44 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 16
  store i16 %socket_field43, ptr %socket_endpoint_ipv6_g44, align 2
  %socket_field45 = extractvalue %sollang.struct.1221 %socket_field29, 7
  %socket_endpoint_ipv6_h46 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 18
  store i16 %socket_field45, ptr %socket_endpoint_ipv6_h46, align 2
  %socket_field47 = extractvalue %sollang.struct.1222 %enum_payload28, 1
  %socket_field48 = extractvalue %sollang.struct.1222 %enum_payload28, 2
  %socket_field49 = extractvalue %sollang.struct.1222 %enum_payload28, 3
  %socket_endpoint_port650 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 20
  store i16 %socket_field47, ptr %socket_endpoint_port650, align 2
  %socket_endpoint_flow651 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 24
  store i32 %socket_field48, ptr %socket_endpoint_flow651, align 4
  %socket_endpoint_scope652 = getelementptr i8, ptr %socket_endpoint_descriptor4, i64 28
  store i32 %socket_field49, ptr %socket_endpoint_scope652, align 4
  br label %bb_socket_endpoint_complete2
bb_socket_endpoint_complete2:
  %socket_field53 = extractvalue %sollang.struct.1352 %struct_init2, 1
  %socket_field54 = extractvalue %sollang.struct.1352 %struct_init2, 2
  %socket_backlog55 = sext i32 %socket_field53 to i64
  %socket_platform_result56 = call %sollang.socket_result @sollang_platform_socket_listen(ptr %socket_endpoint_descriptor4, i64 %socket_backlog55, i1 %socket_field54)
  %socket_platform_value57 = extractvalue %sollang.socket_result %socket_platform_result56, 0
  %socket_platform_kind58 = extractvalue %sollang.socket_result %socket_platform_result56, 1
  %socket_platform_code59 = extractvalue %sollang.socket_result %socket_platform_result56, 2
  %socket_owner_value60 = insertvalue %sollang.struct.1354 poison, i64 %socket_platform_value57, 0
  %socket_succeeded61 = icmp slt i32 %socket_platform_kind58, 0
  br i1 %socket_succeeded61, label %bb_socket_success3, label %bb_socket_failure4
bb_socket_success3:
  store %sollang.enum.2636 zeroinitializer, ptr %enum_init_slot62, align 8
  %enum_tag_addr63 = getelementptr inbounds %sollang.enum.2636, ptr %enum_init_slot62, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr63, align 4
  %enum_payload_addr64 = getelementptr inbounds %sollang.enum.2636, ptr %enum_init_slot62, i32 0, i32 1
  store %sollang.struct.1354 %socket_owner_value60, ptr %enum_payload_addr64, align 8
  %enum_value65 = load %sollang.enum.2636, ptr %enum_init_slot62, align 8
  br label %bb_socket_result_end5
bb_socket_failure4:
  store %sollang.enum.1557 zeroinitializer, ptr %socket_error_kind_slot66, align 8
  %socket_error_kind_tag_address67 = getelementptr inbounds %sollang.enum.1557, ptr %socket_error_kind_slot66, i32 0, i32 0
  store i32 %socket_platform_kind58, ptr %socket_error_kind_tag_address67, align 4
  %socket_error_kind68 = load %sollang.enum.1557, ptr %socket_error_kind_slot66, align 8
  %socket_error_with_kind69 = insertvalue %sollang.struct.1373 poison, %sollang.enum.1557 %socket_error_kind68, 0
  %socket_error_value70 = insertvalue %sollang.struct.1373 %socket_error_with_kind69, i32 %socket_platform_code59, 1
  store %sollang.enum.2636 zeroinitializer, ptr %enum_init_slot71, align 8
  %enum_tag_addr72 = getelementptr inbounds %sollang.enum.2636, ptr %enum_init_slot71, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr72, align 4
  %enum_payload_addr73 = getelementptr inbounds %sollang.enum.2636, ptr %enum_init_slot71, i32 0, i32 1
  store %sollang.struct.1373 %socket_error_value70, ptr %enum_payload_addr73, align 8
  %enum_value74 = load %sollang.enum.2636, ptr %enum_init_slot71, align 8
  br label %bb_socket_result_end5
bb_socket_result_end5:
  %socket_result75 = phi %sollang.enum.2636 [ %enum_value65, %bb_socket_success3 ], [ %enum_value74, %bb_socket_failure4 ]
  %try_tag76 = extractvalue %sollang.enum.2636 %socket_result75, 0
  %try_is_error77 = icmp eq i32 %try_tag76, 1
  br i1 %try_is_error77, label %bb_try_error6, label %bb_try_ok7
bb_try_error6:
  store %sollang.enum.2636 %socket_result75, ptr %enum_match_slot78, align 8
  %enum_payload_addr79 = getelementptr inbounds %sollang.enum.2636, ptr %enum_match_slot78, i32 0, i32 1
  %enum_payload80 = load %sollang.struct.1373, ptr %enum_payload_addr79, align 8
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot81, align 8
  %enum_tag_addr82 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot81, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr82, align 4
  %enum_payload_addr83 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot81, i32 0, i32 1
  store %sollang.struct.1373 %enum_payload80, ptr %enum_payload_addr83, align 8
  %enum_value84 = load %sollang.enum.2642, ptr %enum_init_slot81, align 8
  ret %sollang.enum.2642 %enum_value84
bb_try_ok7:
  store %sollang.enum.2636 %socket_result75, ptr %enum_match_slot85, align 8
  %enum_payload_addr86 = getelementptr inbounds %sollang.enum.2636, ptr %enum_match_slot85, i32 0, i32 1
  %enum_payload87 = load %sollang.struct.1354, ptr %enum_payload_addr86, align 8
  call void @llvm.memset.p0.i64(ptr %socket_local_endpoint_descriptor88, i8 0, i64 32, i1 false)
  %socket_handle89 = extractvalue %sollang.struct.1354 %enum_payload87, 0
  %socket_platform_result90 = call %sollang.socket_result @sollang_platform_socket_local_endpoint(i64 %socket_handle89, ptr %socket_local_endpoint_descriptor88)
  %socket_platform_value91 = extractvalue %sollang.socket_result %socket_platform_result90, 0
  %socket_platform_kind92 = extractvalue %sollang.socket_result %socket_platform_result90, 1
  %socket_platform_code93 = extractvalue %sollang.socket_result %socket_platform_result90, 2
  %socket_endpoint_source_family_address94 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 0
  %socket_endpoint_source_family95 = load i32, ptr %socket_endpoint_source_family_address94, align 4
  %socket_source_is_ipv496 = icmp eq i32 %socket_endpoint_source_family95, 4
  br i1 %socket_source_is_ipv496, label %bb_socket_source_ipv48, label %bb_socket_source_ipv69
bb_socket_source_ipv48:
  %socket_endpoint_source_ipv4_a_address97 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 4
  %socket_endpoint_source_ipv4_a98 = load i16, ptr %socket_endpoint_source_ipv4_a_address97, align 2
  %socket_source_ipv4_octet99 = trunc i16 %socket_endpoint_source_ipv4_a98 to i8
  %socket_endpoint_source_ipv4_b_address100 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 6
  %socket_endpoint_source_ipv4_b101 = load i16, ptr %socket_endpoint_source_ipv4_b_address100, align 2
  %socket_source_ipv4_octet102 = trunc i16 %socket_endpoint_source_ipv4_b101 to i8
  %socket_endpoint_source_ipv4_c_address103 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 8
  %socket_endpoint_source_ipv4_c104 = load i16, ptr %socket_endpoint_source_ipv4_c_address103, align 2
  %socket_source_ipv4_octet105 = trunc i16 %socket_endpoint_source_ipv4_c104 to i8
  %socket_endpoint_source_ipv4_d_address106 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 10
  %socket_endpoint_source_ipv4_d107 = load i16, ptr %socket_endpoint_source_ipv4_d_address106, align 2
  %socket_source_ipv4_octet108 = trunc i16 %socket_endpoint_source_ipv4_d107 to i8
  %socket_struct_field109 = insertvalue %sollang.struct.1219 poison, i8 %socket_source_ipv4_octet99, 0
  %socket_struct_field110 = insertvalue %sollang.struct.1219 %socket_struct_field109, i8 %socket_source_ipv4_octet102, 1
  %socket_struct_field111 = insertvalue %sollang.struct.1219 %socket_struct_field110, i8 %socket_source_ipv4_octet105, 2
  %socket_struct_field112 = insertvalue %sollang.struct.1219 %socket_struct_field111, i8 %socket_source_ipv4_octet108, 3
  %socket_endpoint_source_ipv4_port_address113 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 20
  %socket_endpoint_source_ipv4_port114 = load i16, ptr %socket_endpoint_source_ipv4_port_address113, align 2
  %socket_struct_field115 = insertvalue %sollang.struct.1220 poison, %sollang.struct.1219 %socket_struct_field112, 0
  %socket_struct_field116 = insertvalue %sollang.struct.1220 %socket_struct_field115, i16 %socket_endpoint_source_ipv4_port114, 1
  store %sollang.enum.1525 zeroinitializer, ptr %enum_init_slot117, align 8
  %enum_tag_addr118 = getelementptr inbounds %sollang.enum.1525, ptr %enum_init_slot117, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr118, align 4
  %enum_payload_addr119 = getelementptr inbounds %sollang.enum.1525, ptr %enum_init_slot117, i32 0, i32 1
  store %sollang.struct.1220 %socket_struct_field116, ptr %enum_payload_addr119, align 2
  %enum_value120 = load %sollang.enum.1525, ptr %enum_init_slot117, align 8
  br label %bb_socket_source_complete10
bb_socket_source_ipv69:
  %socket_endpoint_source_ipv6_a_address121 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 4
  %socket_endpoint_source_ipv6_a122 = load i16, ptr %socket_endpoint_source_ipv6_a_address121, align 2
  %socket_endpoint_source_ipv6_b_address123 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 6
  %socket_endpoint_source_ipv6_b124 = load i16, ptr %socket_endpoint_source_ipv6_b_address123, align 2
  %socket_endpoint_source_ipv6_c_address125 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 8
  %socket_endpoint_source_ipv6_c126 = load i16, ptr %socket_endpoint_source_ipv6_c_address125, align 2
  %socket_endpoint_source_ipv6_d_address127 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 10
  %socket_endpoint_source_ipv6_d128 = load i16, ptr %socket_endpoint_source_ipv6_d_address127, align 2
  %socket_endpoint_source_ipv6_e_address129 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 12
  %socket_endpoint_source_ipv6_e130 = load i16, ptr %socket_endpoint_source_ipv6_e_address129, align 2
  %socket_endpoint_source_ipv6_f_address131 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 14
  %socket_endpoint_source_ipv6_f132 = load i16, ptr %socket_endpoint_source_ipv6_f_address131, align 2
  %socket_endpoint_source_ipv6_g_address133 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 16
  %socket_endpoint_source_ipv6_g134 = load i16, ptr %socket_endpoint_source_ipv6_g_address133, align 2
  %socket_endpoint_source_ipv6_h_address135 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 18
  %socket_endpoint_source_ipv6_h136 = load i16, ptr %socket_endpoint_source_ipv6_h_address135, align 2
  %socket_struct_field137 = insertvalue %sollang.struct.1221 poison, i16 %socket_endpoint_source_ipv6_a122, 0
  %socket_struct_field138 = insertvalue %sollang.struct.1221 %socket_struct_field137, i16 %socket_endpoint_source_ipv6_b124, 1
  %socket_struct_field139 = insertvalue %sollang.struct.1221 %socket_struct_field138, i16 %socket_endpoint_source_ipv6_c126, 2
  %socket_struct_field140 = insertvalue %sollang.struct.1221 %socket_struct_field139, i16 %socket_endpoint_source_ipv6_d128, 3
  %socket_struct_field141 = insertvalue %sollang.struct.1221 %socket_struct_field140, i16 %socket_endpoint_source_ipv6_e130, 4
  %socket_struct_field142 = insertvalue %sollang.struct.1221 %socket_struct_field141, i16 %socket_endpoint_source_ipv6_f132, 5
  %socket_struct_field143 = insertvalue %sollang.struct.1221 %socket_struct_field142, i16 %socket_endpoint_source_ipv6_g134, 6
  %socket_struct_field144 = insertvalue %sollang.struct.1221 %socket_struct_field143, i16 %socket_endpoint_source_ipv6_h136, 7
  %socket_endpoint_source_ipv6_port_address145 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 20
  %socket_endpoint_source_ipv6_port146 = load i16, ptr %socket_endpoint_source_ipv6_port_address145, align 2
  %socket_endpoint_source_ipv6_flow_address147 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 24
  %socket_endpoint_source_ipv6_flow148 = load i32, ptr %socket_endpoint_source_ipv6_flow_address147, align 4
  %socket_endpoint_source_ipv6_scope_address149 = getelementptr i8, ptr %socket_local_endpoint_descriptor88, i64 28
  %socket_endpoint_source_ipv6_scope150 = load i32, ptr %socket_endpoint_source_ipv6_scope_address149, align 4
  %socket_struct_field151 = insertvalue %sollang.struct.1222 poison, %sollang.struct.1221 %socket_struct_field144, 0
  %socket_struct_field152 = insertvalue %sollang.struct.1222 %socket_struct_field151, i16 %socket_endpoint_source_ipv6_port146, 1
  %socket_struct_field153 = insertvalue %sollang.struct.1222 %socket_struct_field152, i32 %socket_endpoint_source_ipv6_flow148, 2
  %socket_struct_field154 = insertvalue %sollang.struct.1222 %socket_struct_field153, i32 %socket_endpoint_source_ipv6_scope150, 3
  store %sollang.enum.1525 zeroinitializer, ptr %enum_init_slot155, align 8
  %enum_tag_addr156 = getelementptr inbounds %sollang.enum.1525, ptr %enum_init_slot155, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr156, align 4
  %enum_payload_addr157 = getelementptr inbounds %sollang.enum.1525, ptr %enum_init_slot155, i32 0, i32 1
  store %sollang.struct.1222 %socket_struct_field154, ptr %enum_payload_addr157, align 4
  %enum_value158 = load %sollang.enum.1525, ptr %enum_init_slot155, align 8
  br label %bb_socket_source_complete10
bb_socket_source_complete10:
  %socket_source_endpoint159 = phi %sollang.enum.1525 [ %enum_value120, %bb_socket_source_ipv48 ], [ %enum_value158, %bb_socket_source_ipv69 ]
  %socket_succeeded160 = icmp slt i32 %socket_platform_kind92, 0
  br i1 %socket_succeeded160, label %bb_socket_success11, label %bb_socket_failure12
bb_socket_success11:
  store %sollang.enum.2643 zeroinitializer, ptr %enum_init_slot161, align 8
  %enum_tag_addr162 = getelementptr inbounds %sollang.enum.2643, ptr %enum_init_slot161, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr162, align 4
  %enum_payload_addr163 = getelementptr inbounds %sollang.enum.2643, ptr %enum_init_slot161, i32 0, i32 1
  store %sollang.enum.1525 %socket_source_endpoint159, ptr %enum_payload_addr163, align 8
  %enum_value164 = load %sollang.enum.2643, ptr %enum_init_slot161, align 8
  br label %bb_socket_result_end13
bb_socket_failure12:
  store %sollang.enum.1557 zeroinitializer, ptr %socket_error_kind_slot165, align 8
  %socket_error_kind_tag_address166 = getelementptr inbounds %sollang.enum.1557, ptr %socket_error_kind_slot165, i32 0, i32 0
  store i32 %socket_platform_kind92, ptr %socket_error_kind_tag_address166, align 4
  %socket_error_kind167 = load %sollang.enum.1557, ptr %socket_error_kind_slot165, align 8
  %socket_error_with_kind168 = insertvalue %sollang.struct.1373 poison, %sollang.enum.1557 %socket_error_kind167, 0
  %socket_error_value169 = insertvalue %sollang.struct.1373 %socket_error_with_kind168, i32 %socket_platform_code93, 1
  store %sollang.enum.2643 zeroinitializer, ptr %enum_init_slot170, align 8
  %enum_tag_addr171 = getelementptr inbounds %sollang.enum.2643, ptr %enum_init_slot170, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr171, align 4
  %enum_payload_addr172 = getelementptr inbounds %sollang.enum.2643, ptr %enum_init_slot170, i32 0, i32 1
  store %sollang.struct.1373 %socket_error_value169, ptr %enum_payload_addr172, align 8
  %enum_value173 = load %sollang.enum.2643, ptr %enum_init_slot170, align 8
  br label %bb_socket_result_end13
bb_socket_result_end13:
  %socket_result174 = phi %sollang.enum.2643 [ %enum_value164, %bb_socket_success11 ], [ %enum_value173, %bb_socket_failure12 ]
  %try_tag175 = extractvalue %sollang.enum.2643 %socket_result174, 0
  %try_is_error176 = icmp eq i32 %try_tag175, 1
  br i1 %try_is_error176, label %bb_try_error14, label %bb_try_ok15
bb_try_error14:
  store %sollang.enum.2643 %socket_result174, ptr %enum_match_slot177, align 8
  %enum_payload_addr178 = getelementptr inbounds %sollang.enum.2643, ptr %enum_match_slot177, i32 0, i32 1
  %enum_payload179 = load %sollang.struct.1373, ptr %enum_payload_addr178, align 8
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot180, align 8
  %enum_tag_addr181 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot180, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr181, align 4
  %enum_payload_addr182 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot180, i32 0, i32 1
  store %sollang.struct.1373 %enum_payload179, ptr %enum_payload_addr182, align 8
  %enum_value183 = load %sollang.enum.2642, ptr %enum_init_slot180, align 8
  call void @sollang_drop_1354(%sollang.struct.1354 %enum_payload87)
  ret %sollang.enum.2642 %enum_value183
bb_try_ok15:
  store %sollang.enum.2643 %socket_result174, ptr %enum_match_slot184, align 8
  %enum_payload_addr185 = getelementptr inbounds %sollang.enum.2643, ptr %enum_match_slot184, i32 0, i32 1
  %enum_payload186 = load %sollang.enum.1525, ptr %enum_payload_addr185, align 8
  call void @llvm.memset.p0.i64(ptr %socket_endpoint_descriptor187, i8 0, i64 32, i1 false)
  %socket_endpoint_tag188 = extractvalue %sollang.enum.1525 %enum_payload186, 0
  %socket_endpoint_is_ipv4189 = icmp eq i32 %socket_endpoint_tag188, 0
  br i1 %socket_endpoint_is_ipv4189, label %bb_socket_endpoint_ipv416, label %bb_socket_endpoint_ipv617
bb_socket_endpoint_ipv416:
  store %sollang.enum.1525 %enum_payload186, ptr %enum_match_slot190, align 8
  %enum_payload_addr191 = getelementptr inbounds %sollang.enum.1525, ptr %enum_match_slot190, i32 0, i32 1
  %enum_payload192 = load %sollang.struct.1220, ptr %enum_payload_addr191, align 2
  %socket_field193 = extractvalue %sollang.struct.1220 %enum_payload192, 0
  %socket_endpoint_family4194 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 0
  store i32 4, ptr %socket_endpoint_family4194, align 4
  %socket_field195 = extractvalue %sollang.struct.1219 %socket_field193, 0
  %socket_ipv4_octet196 = zext i8 %socket_field195 to i16
  %socket_endpoint_ipv4_a197 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 4
  store i16 %socket_ipv4_octet196, ptr %socket_endpoint_ipv4_a197, align 2
  %socket_field198 = extractvalue %sollang.struct.1219 %socket_field193, 1
  %socket_ipv4_octet199 = zext i8 %socket_field198 to i16
  %socket_endpoint_ipv4_b200 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 6
  store i16 %socket_ipv4_octet199, ptr %socket_endpoint_ipv4_b200, align 2
  %socket_field201 = extractvalue %sollang.struct.1219 %socket_field193, 2
  %socket_ipv4_octet202 = zext i8 %socket_field201 to i16
  %socket_endpoint_ipv4_c203 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 8
  store i16 %socket_ipv4_octet202, ptr %socket_endpoint_ipv4_c203, align 2
  %socket_field204 = extractvalue %sollang.struct.1219 %socket_field193, 3
  %socket_ipv4_octet205 = zext i8 %socket_field204 to i16
  %socket_endpoint_ipv4_d206 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 10
  store i16 %socket_ipv4_octet205, ptr %socket_endpoint_ipv4_d206, align 2
  %socket_field207 = extractvalue %sollang.struct.1220 %enum_payload192, 1
  %socket_endpoint_port4208 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 20
  store i16 %socket_field207, ptr %socket_endpoint_port4208, align 2
  br label %bb_socket_endpoint_complete18
bb_socket_endpoint_ipv617:
  store %sollang.enum.1525 %enum_payload186, ptr %enum_match_slot209, align 8
  %enum_payload_addr210 = getelementptr inbounds %sollang.enum.1525, ptr %enum_match_slot209, i32 0, i32 1
  %enum_payload211 = load %sollang.struct.1222, ptr %enum_payload_addr210, align 4
  %socket_field212 = extractvalue %sollang.struct.1222 %enum_payload211, 0
  %socket_endpoint_family6213 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 0
  store i32 6, ptr %socket_endpoint_family6213, align 4
  %socket_field214 = extractvalue %sollang.struct.1221 %socket_field212, 0
  %socket_endpoint_ipv6_a215 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 4
  store i16 %socket_field214, ptr %socket_endpoint_ipv6_a215, align 2
  %socket_field216 = extractvalue %sollang.struct.1221 %socket_field212, 1
  %socket_endpoint_ipv6_b217 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 6
  store i16 %socket_field216, ptr %socket_endpoint_ipv6_b217, align 2
  %socket_field218 = extractvalue %sollang.struct.1221 %socket_field212, 2
  %socket_endpoint_ipv6_c219 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 8
  store i16 %socket_field218, ptr %socket_endpoint_ipv6_c219, align 2
  %socket_field220 = extractvalue %sollang.struct.1221 %socket_field212, 3
  %socket_endpoint_ipv6_d221 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 10
  store i16 %socket_field220, ptr %socket_endpoint_ipv6_d221, align 2
  %socket_field222 = extractvalue %sollang.struct.1221 %socket_field212, 4
  %socket_endpoint_ipv6_e223 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 12
  store i16 %socket_field222, ptr %socket_endpoint_ipv6_e223, align 2
  %socket_field224 = extractvalue %sollang.struct.1221 %socket_field212, 5
  %socket_endpoint_ipv6_f225 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 14
  store i16 %socket_field224, ptr %socket_endpoint_ipv6_f225, align 2
  %socket_field226 = extractvalue %sollang.struct.1221 %socket_field212, 6
  %socket_endpoint_ipv6_g227 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 16
  store i16 %socket_field226, ptr %socket_endpoint_ipv6_g227, align 2
  %socket_field228 = extractvalue %sollang.struct.1221 %socket_field212, 7
  %socket_endpoint_ipv6_h229 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 18
  store i16 %socket_field228, ptr %socket_endpoint_ipv6_h229, align 2
  %socket_field230 = extractvalue %sollang.struct.1222 %enum_payload211, 1
  %socket_field231 = extractvalue %sollang.struct.1222 %enum_payload211, 2
  %socket_field232 = extractvalue %sollang.struct.1222 %enum_payload211, 3
  %socket_endpoint_port6233 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 20
  store i16 %socket_field230, ptr %socket_endpoint_port6233, align 2
  %socket_endpoint_flow6234 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 24
  store i32 %socket_field231, ptr %socket_endpoint_flow6234, align 4
  %socket_endpoint_scope6235 = getelementptr i8, ptr %socket_endpoint_descriptor187, i64 28
  store i32 %socket_field232, ptr %socket_endpoint_scope6235, align 4
  br label %bb_socket_endpoint_complete18
bb_socket_endpoint_complete18:
  %socket_platform_result236 = call %sollang.socket_result @sollang_platform_socket_connect(ptr %socket_endpoint_descriptor187)
  %socket_platform_value237 = extractvalue %sollang.socket_result %socket_platform_result236, 0
  %socket_platform_kind238 = extractvalue %sollang.socket_result %socket_platform_result236, 1
  %socket_platform_code239 = extractvalue %sollang.socket_result %socket_platform_result236, 2
  %socket_owner_value240 = insertvalue %sollang.struct.1355 poison, i64 %socket_platform_value237, 0
  %socket_succeeded241 = icmp slt i32 %socket_platform_kind238, 0
  br i1 %socket_succeeded241, label %bb_socket_success19, label %bb_socket_failure20
bb_socket_success19:
  store %sollang.enum.2638 zeroinitializer, ptr %enum_init_slot242, align 8
  %enum_tag_addr243 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot242, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr243, align 4
  %enum_payload_addr244 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot242, i32 0, i32 1
  store %sollang.struct.1355 %socket_owner_value240, ptr %enum_payload_addr244, align 8
  %enum_value245 = load %sollang.enum.2638, ptr %enum_init_slot242, align 8
  br label %bb_socket_result_end21
bb_socket_failure20:
  store %sollang.enum.1557 zeroinitializer, ptr %socket_error_kind_slot246, align 8
  %socket_error_kind_tag_address247 = getelementptr inbounds %sollang.enum.1557, ptr %socket_error_kind_slot246, i32 0, i32 0
  store i32 %socket_platform_kind238, ptr %socket_error_kind_tag_address247, align 4
  %socket_error_kind248 = load %sollang.enum.1557, ptr %socket_error_kind_slot246, align 8
  %socket_error_with_kind249 = insertvalue %sollang.struct.1373 poison, %sollang.enum.1557 %socket_error_kind248, 0
  %socket_error_value250 = insertvalue %sollang.struct.1373 %socket_error_with_kind249, i32 %socket_platform_code239, 1
  store %sollang.enum.2638 zeroinitializer, ptr %enum_init_slot251, align 8
  %enum_tag_addr252 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot251, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr252, align 4
  %enum_payload_addr253 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot251, i32 0, i32 1
  store %sollang.struct.1373 %socket_error_value250, ptr %enum_payload_addr253, align 8
  %enum_value254 = load %sollang.enum.2638, ptr %enum_init_slot251, align 8
  br label %bb_socket_result_end21
bb_socket_result_end21:
  %socket_result255 = phi %sollang.enum.2638 [ %enum_value245, %bb_socket_success19 ], [ %enum_value254, %bb_socket_failure20 ]
  %try_tag256 = extractvalue %sollang.enum.2638 %socket_result255, 0
  %try_is_error257 = icmp eq i32 %try_tag256, 1
  br i1 %try_is_error257, label %bb_try_error22, label %bb_try_ok23
bb_try_error22:
  store %sollang.enum.2638 %socket_result255, ptr %enum_match_slot258, align 8
  %enum_payload_addr259 = getelementptr inbounds %sollang.enum.2638, ptr %enum_match_slot258, i32 0, i32 1
  %enum_payload260 = load %sollang.struct.1373, ptr %enum_payload_addr259, align 8
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot261, align 8
  %enum_tag_addr262 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot261, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr262, align 4
  %enum_payload_addr263 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot261, i32 0, i32 1
  store %sollang.struct.1373 %enum_payload260, ptr %enum_payload_addr263, align 8
  %enum_value264 = load %sollang.enum.2642, ptr %enum_init_slot261, align 8
  call void @sollang_drop_1354(%sollang.struct.1354 %enum_payload87)
  ret %sollang.enum.2642 %enum_value264
bb_try_ok23:
  store %sollang.enum.2638 %socket_result255, ptr %enum_match_slot265, align 8
  %enum_payload_addr266 = getelementptr inbounds %sollang.enum.2638, ptr %enum_match_slot265, i32 0, i32 1
  %enum_payload267 = load %sollang.struct.1355, ptr %enum_payload_addr266, align 8
  %socket_handle268 = extractvalue %sollang.struct.1354 %enum_payload87, 0
  %socket_platform_result269 = call %sollang.socket_result @sollang_platform_socket_accept(i64 %socket_handle268)
  %socket_platform_value270 = extractvalue %sollang.socket_result %socket_platform_result269, 0
  %socket_platform_kind271 = extractvalue %sollang.socket_result %socket_platform_result269, 1
  %socket_platform_code272 = extractvalue %sollang.socket_result %socket_platform_result269, 2
  %socket_owner_value273 = insertvalue %sollang.struct.1355 poison, i64 %socket_platform_value270, 0
  %socket_succeeded274 = icmp slt i32 %socket_platform_kind271, 0
  br i1 %socket_succeeded274, label %bb_socket_success24, label %bb_socket_failure25
bb_socket_success24:
  store %sollang.enum.2638 zeroinitializer, ptr %enum_init_slot275, align 8
  %enum_tag_addr276 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot275, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr276, align 4
  %enum_payload_addr277 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot275, i32 0, i32 1
  store %sollang.struct.1355 %socket_owner_value273, ptr %enum_payload_addr277, align 8
  %enum_value278 = load %sollang.enum.2638, ptr %enum_init_slot275, align 8
  br label %bb_socket_result_end26
bb_socket_failure25:
  store %sollang.enum.1557 zeroinitializer, ptr %socket_error_kind_slot279, align 8
  %socket_error_kind_tag_address280 = getelementptr inbounds %sollang.enum.1557, ptr %socket_error_kind_slot279, i32 0, i32 0
  store i32 %socket_platform_kind271, ptr %socket_error_kind_tag_address280, align 4
  %socket_error_kind281 = load %sollang.enum.1557, ptr %socket_error_kind_slot279, align 8
  %socket_error_with_kind282 = insertvalue %sollang.struct.1373 poison, %sollang.enum.1557 %socket_error_kind281, 0
  %socket_error_value283 = insertvalue %sollang.struct.1373 %socket_error_with_kind282, i32 %socket_platform_code272, 1
  store %sollang.enum.2638 zeroinitializer, ptr %enum_init_slot284, align 8
  %enum_tag_addr285 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot284, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr285, align 4
  %enum_payload_addr286 = getelementptr inbounds %sollang.enum.2638, ptr %enum_init_slot284, i32 0, i32 1
  store %sollang.struct.1373 %socket_error_value283, ptr %enum_payload_addr286, align 8
  %enum_value287 = load %sollang.enum.2638, ptr %enum_init_slot284, align 8
  br label %bb_socket_result_end26
bb_socket_result_end26:
  %socket_result288 = phi %sollang.enum.2638 [ %enum_value278, %bb_socket_success24 ], [ %enum_value287, %bb_socket_failure25 ]
  %try_tag289 = extractvalue %sollang.enum.2638 %socket_result288, 0
  %try_is_error290 = icmp eq i32 %try_tag289, 1
  br i1 %try_is_error290, label %bb_try_error27, label %bb_try_ok28
bb_try_error27:
  store %sollang.enum.2638 %socket_result288, ptr %enum_match_slot291, align 8
  %enum_payload_addr292 = getelementptr inbounds %sollang.enum.2638, ptr %enum_match_slot291, i32 0, i32 1
  %enum_payload293 = load %sollang.struct.1373, ptr %enum_payload_addr292, align 8
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot294, align 8
  %enum_tag_addr295 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot294, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr295, align 4
  %enum_payload_addr296 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot294, i32 0, i32 1
  store %sollang.struct.1373 %enum_payload293, ptr %enum_payload_addr296, align 8
  %enum_value297 = load %sollang.enum.2642, ptr %enum_init_slot294, align 8
  call void @sollang_drop_1355(%sollang.struct.1355 %enum_payload267)
  call void @sollang_drop_1354(%sollang.struct.1354 %enum_payload87)
  ret %sollang.enum.2642 %enum_value297
bb_try_ok28:
  store %sollang.enum.2638 %socket_result288, ptr %enum_match_slot298, align 8
  %enum_payload_addr299 = getelementptr inbounds %sollang.enum.2638, ptr %enum_match_slot298, i32 0, i32 1
  %enum_payload300 = load %sollang.struct.1355, ptr %enum_payload_addr299, align 8
  %heap301 = call ptr @sollang_alloc(i64 3)
  %heap_ok302 = icmp ne ptr %heap301, null
  br i1 %heap_ok302, label %bb_alloc_ok29, label %bb_alloc_fail30

bb_alloc_fail30:
  %trap_stderr303 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr303, ptr @.slg.str.module.x.0, i32 24, ptr %trap_written304, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok29:
  %dynamic_inline_slot305 = getelementptr i8, ptr %heap301, i64 0
  store i8 10, ptr %dynamic_inline_slot305, align 1
  %dynamic_inline_slot306 = getelementptr i8, ptr %heap301, i64 1
  store i8 11, ptr %dynamic_inline_slot306, align 1
  %dynamic_inline_slot307 = getelementptr i8, ptr %heap301, i64 2
  store i8 12, ptr %dynamic_inline_slot307, align 1
  %heap308 = call ptr @sollang_alloc(i64 4)
  %heap_ok309 = icmp ne ptr %heap308, null
  br i1 %heap_ok309, label %bb_alloc_ok31, label %bb_alloc_fail32

bb_alloc_fail32:
  %trap_stderr310 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr310, ptr @.slg.str.module.x.1, i32 24, ptr %trap_written311, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok31:
  %dynamic_inline_slot312 = getelementptr i8, ptr %heap308, i64 0
  store i8 20, ptr %dynamic_inline_slot312, align 1
  %dynamic_inline_slot313 = getelementptr i8, ptr %heap308, i64 1
  store i8 21, ptr %dynamic_inline_slot313, align 1
  %dynamic_inline_slot314 = getelementptr i8, ptr %heap308, i64 2
  store i8 22, ptr %dynamic_inline_slot314, align 1
  %dynamic_inline_slot315 = getelementptr i8, ptr %heap308, i64 3
  store i8 23, ptr %dynamic_inline_slot315, align 1
  %generic_array_value316 = insertvalue %sollang.dynamic_int_array poison, ptr %heap301, 0
  %generic_array_value317 = insertvalue %sollang.dynamic_int_array %generic_array_value316, i64 3, 1
  %generic_array_value318 = insertvalue %sollang.dynamic_int_array %generic_array_value317, i64 3, 2
  store %sollang.dynamic_int_array %generic_array_value318, ptr %ref_arg319, align 8
  %struct_call320 = call %sollang.struct.1357 @sollang_fn_sendBuffer(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %ref_arg319, i64 1, i64 2)
  %generic_array_value321 = insertvalue %sollang.dynamic_int_array poison, ptr %heap308, 0
  %generic_array_value322 = insertvalue %sollang.dynamic_int_array %generic_array_value321, i64 4, 1
  %generic_array_value323 = insertvalue %sollang.dynamic_int_array %generic_array_value322, i64 4, 2
  store %sollang.dynamic_int_array %generic_array_value323, ptr %ref_arg324, align 8
  %struct_call325 = call %sollang.struct.1357 @sollang_fn_sendBuffer(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, ptr %ref_arg324, i64 0, i64 3)
  %heap326 = call ptr @sollang_alloc(i64 48)
  %heap_ok327 = icmp ne ptr %heap326, null
  br i1 %heap_ok327, label %bb_alloc_ok33, label %bb_alloc_fail34

bb_alloc_fail34:
  %trap_stderr328 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr328, ptr @.slg.str.module.x.2, i32 24, ptr %trap_written329, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok33:
  %inline_array_slot330 = getelementptr %sollang.struct.1357, ptr %heap326, i64 0
  store %sollang.struct.1357 %struct_call320, ptr %inline_array_slot330, align 8
  %inline_array_slot331 = getelementptr %sollang.struct.1357, ptr %heap326, i64 1
  store %sollang.struct.1357 %struct_call325, ptr %inline_array_slot331, align 8
  %socket_handle332 = extractvalue %sollang.struct.1355 %enum_payload267, 0
  %socket_platform_result333 = call %sollang.socket_result @sollang_platform_socket_send_vectored(i64 %socket_handle332, ptr %heap326, i64 2, i64 24, i64 0, i64 8, i64 16)
  %socket_platform_value334 = extractvalue %sollang.socket_result %socket_platform_result333, 0
  %socket_platform_kind335 = extractvalue %sollang.socket_result %socket_platform_result333, 1
  %socket_platform_code336 = extractvalue %sollang.socket_result %socket_platform_result333, 2
  %socket_succeeded337 = icmp slt i32 %socket_platform_kind335, 0
  br i1 %socket_succeeded337, label %bb_socket_success35, label %bb_socket_failure36
bb_socket_success35:
  store %sollang.enum.2639 zeroinitializer, ptr %enum_init_slot338, align 8
  %enum_tag_addr339 = getelementptr inbounds %sollang.enum.2639, ptr %enum_init_slot338, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr339, align 4
  %enum_payload_addr340 = getelementptr inbounds %sollang.enum.2639, ptr %enum_init_slot338, i32 0, i32 1
  store i64 %socket_platform_value334, ptr %enum_payload_addr340, align 8
  %enum_value341 = load %sollang.enum.2639, ptr %enum_init_slot338, align 8
  br label %bb_socket_result_end37
bb_socket_failure36:
  store %sollang.enum.1557 zeroinitializer, ptr %socket_error_kind_slot342, align 8
  %socket_error_kind_tag_address343 = getelementptr inbounds %sollang.enum.1557, ptr %socket_error_kind_slot342, i32 0, i32 0
  store i32 %socket_platform_kind335, ptr %socket_error_kind_tag_address343, align 4
  %socket_error_kind344 = load %sollang.enum.1557, ptr %socket_error_kind_slot342, align 8
  %socket_error_with_kind345 = insertvalue %sollang.struct.1373 poison, %sollang.enum.1557 %socket_error_kind344, 0
  %socket_error_value346 = insertvalue %sollang.struct.1373 %socket_error_with_kind345, i32 %socket_platform_code336, 1
  store %sollang.enum.2639 zeroinitializer, ptr %enum_init_slot347, align 8
  %enum_tag_addr348 = getelementptr inbounds %sollang.enum.2639, ptr %enum_init_slot347, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr348, align 4
  %enum_payload_addr349 = getelementptr inbounds %sollang.enum.2639, ptr %enum_init_slot347, i32 0, i32 1
  store %sollang.struct.1373 %socket_error_value346, ptr %enum_payload_addr349, align 8
  %enum_value350 = load %sollang.enum.2639, ptr %enum_init_slot347, align 8
  br label %bb_socket_result_end37
bb_socket_result_end37:
  %socket_result351 = phi %sollang.enum.2639 [ %enum_value341, %bb_socket_success35 ], [ %enum_value350, %bb_socket_failure36 ]
  %try_tag352 = extractvalue %sollang.enum.2639 %socket_result351, 0
  %try_is_error353 = icmp eq i32 %try_tag352, 1
  br i1 %try_is_error353, label %bb_try_error38, label %bb_try_ok39
bb_try_error38:
  store %sollang.enum.2639 %socket_result351, ptr %enum_match_slot354, align 8
  %enum_payload_addr355 = getelementptr inbounds %sollang.enum.2639, ptr %enum_match_slot354, i32 0, i32 1
  %enum_payload356 = load %sollang.struct.1373, ptr %enum_payload_addr355, align 8
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot357, align 8
  %enum_tag_addr358 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot357, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr358, align 4
  %enum_payload_addr359 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot357, i32 0, i32 1
  store %sollang.struct.1373 %enum_payload356, ptr %enum_payload_addr359, align 8
  %enum_value360 = load %sollang.enum.2642, ptr %enum_init_slot357, align 8
  call void @sollang_free(ptr %heap326)
  call void @sollang_free(ptr %heap308)
  call void @sollang_free(ptr %heap301)
  call void @sollang_drop_1355(%sollang.struct.1355 %enum_payload300)
  call void @sollang_drop_1355(%sollang.struct.1355 %enum_payload267)
  call void @sollang_drop_1354(%sollang.struct.1354 %enum_payload87)
  ret %sollang.enum.2642 %enum_value360
bb_try_ok39:
  store %sollang.enum.2639 %socket_result351, ptr %enum_match_slot361, align 8
  %enum_payload_addr362 = getelementptr inbounds %sollang.enum.2639, ptr %enum_match_slot361, i32 0, i32 1
  %enum_payload363 = load i64, ptr %enum_payload_addr362, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr %stack_slot0)
  %socket_receive_maximum_is_zero364 = icmp eq i64 16, 0
  %socket_receive_allocated_bytes365 = select i1 %socket_receive_maximum_is_zero364, i64 1, i64 16
  %heap366 = call ptr @sollang_alloc(i64 %socket_receive_allocated_bytes365)
  %heap_ok367 = icmp ne ptr %heap366, null
  br i1 %heap_ok367, label %bb_alloc_ok40, label %bb_alloc_fail41

bb_alloc_fail41:
  %trap_stderr368 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr368, ptr @.slg.str.module.x.3, i32 24, ptr %trap_written369, ptr null)
  call void @llvm.trap()
  unreachable

bb_alloc_ok40:
  %socket_handle370 = extractvalue %sollang.struct.1355 %enum_payload300, 0
  %socket_platform_result371 = call %sollang.socket_result @sollang_platform_socket_receive(i64 %socket_handle370, ptr %heap366, i64 16, i32 0)
  %socket_platform_value372 = extractvalue %sollang.socket_result %socket_platform_result371, 0
  %socket_platform_kind373 = extractvalue %sollang.socket_result %socket_platform_result371, 1
  %socket_platform_code374 = extractvalue %sollang.socket_result %socket_platform_result371, 2
  %socket_succeeded375 = icmp slt i32 %socket_platform_kind373, 0
  br i1 %socket_succeeded375, label %bb_socket_success42, label %bb_socket_failure43
bb_socket_success42:
  store %sollang.enum.2645 zeroinitializer, ptr %enum_init_slot376, align 8
  %enum_tag_addr377 = getelementptr inbounds %sollang.enum.2645, ptr %enum_init_slot376, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr377, align 4
  %enum_payload_addr378 = getelementptr inbounds %sollang.enum.2645, ptr %enum_init_slot376, i32 0, i32 1
  %generic_array_value379 = insertvalue %sollang.dynamic_int_array poison, ptr %heap366, 0
  %generic_array_value380 = insertvalue %sollang.dynamic_int_array %generic_array_value379, i64 %socket_platform_value372, 1
  %generic_array_value381 = insertvalue %sollang.dynamic_int_array %generic_array_value380, i64 16, 2
  store %sollang.dynamic_int_array %generic_array_value381, ptr %enum_payload_addr378, align 8
  %enum_value382 = load %sollang.enum.2645, ptr %enum_init_slot376, align 8
  br label %bb_socket_result_end44
bb_socket_failure43:
  call void @sollang_free(ptr %heap366)
  store %sollang.enum.1557 zeroinitializer, ptr %socket_error_kind_slot383, align 8
  %socket_error_kind_tag_address384 = getelementptr inbounds %sollang.enum.1557, ptr %socket_error_kind_slot383, i32 0, i32 0
  store i32 %socket_platform_kind373, ptr %socket_error_kind_tag_address384, align 4
  %socket_error_kind385 = load %sollang.enum.1557, ptr %socket_error_kind_slot383, align 8
  %socket_error_with_kind386 = insertvalue %sollang.struct.1373 poison, %sollang.enum.1557 %socket_error_kind385, 0
  %socket_error_value387 = insertvalue %sollang.struct.1373 %socket_error_with_kind386, i32 %socket_platform_code374, 1
  store %sollang.enum.2645 zeroinitializer, ptr %enum_init_slot388, align 8
  %enum_tag_addr389 = getelementptr inbounds %sollang.enum.2645, ptr %enum_init_slot388, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr389, align 4
  %enum_payload_addr390 = getelementptr inbounds %sollang.enum.2645, ptr %enum_init_slot388, i32 0, i32 1
  store %sollang.struct.1373 %socket_error_value387, ptr %enum_payload_addr390, align 8
  %enum_value391 = load %sollang.enum.2645, ptr %enum_init_slot388, align 8
  br label %bb_socket_result_end44
bb_socket_result_end44:
  %socket_result392 = phi %sollang.enum.2645 [ %enum_value382, %bb_socket_success42 ], [ %enum_value391, %bb_socket_failure43 ]
  %try_tag393 = extractvalue %sollang.enum.2645 %socket_result392, 0
  %try_is_error394 = icmp eq i32 %try_tag393, 1
  br i1 %try_is_error394, label %bb_try_error45, label %bb_try_ok46
bb_try_error45:
  store %sollang.enum.2645 %socket_result392, ptr %enum_match_slot395, align 8
  %enum_payload_addr396 = getelementptr inbounds %sollang.enum.2645, ptr %enum_match_slot395, i32 0, i32 1
  %enum_payload397 = load %sollang.struct.1373, ptr %enum_payload_addr396, align 8
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot398, align 8
  %enum_tag_addr399 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot398, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr399, align 4
  %enum_payload_addr400 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot398, i32 0, i32 1
  store %sollang.struct.1373 %enum_payload397, ptr %enum_payload_addr400, align 8
  %enum_value401 = load %sollang.enum.2642, ptr %enum_init_slot398, align 8
  call void @sollang_free(ptr %heap326)
  call void @sollang_free(ptr %heap308)
  call void @sollang_free(ptr %heap301)
  call void @sollang_drop_1355(%sollang.struct.1355 %enum_payload300)
  call void @sollang_drop_1355(%sollang.struct.1355 %enum_payload267)
  call void @sollang_drop_1354(%sollang.struct.1354 %enum_payload87)
  ret %sollang.enum.2642 %enum_value401
bb_try_ok46:
  store %sollang.enum.2645 %socket_result392, ptr %enum_match_slot402, align 8
  %enum_payload_addr403 = getelementptr inbounds %sollang.enum.2645, ptr %enum_match_slot402, i32 0, i32 1
  %enum_payload404 = load %sollang.dynamic_int_array, ptr %enum_payload_addr403, align 8
  %array_ptr405 = extractvalue %sollang.dynamic_int_array %enum_payload404, 0
  %array_len406 = extractvalue %sollang.dynamic_int_array %enum_payload404, 1
  %array_capacity407 = extractvalue %sollang.dynamic_int_array %enum_payload404, 2
  %socket_handle408 = extractvalue %sollang.struct.1355 %enum_payload267, 0
  call void @sollang_platform_close_socket(i64 %socket_handle408)
  %socket_handle409 = extractvalue %sollang.struct.1355 %enum_payload300, 0
  call void @sollang_platform_close_socket(i64 %socket_handle409)
  %socket_handle410 = extractvalue %sollang.struct.1354 %enum_payload87, 0
  call void @sollang_platform_close_socket(i64 %socket_handle410)
  %cmp411 = icmp eq i64 %enum_payload363, 5
  br i1 %cmp411, label %bb_and_rhs47, label %bb_and_end48
bb_and_rhs47:
  %array_len_value412 = trunc i64 %array_len406 to i32
  %cmp413 = icmp eq i32 %array_len_value412, 5
  br label %bb_and_end48
bb_and_end48:
  %and414 = phi i1 [ false, %bb_try_ok46 ], [ %cmp413, %bb_and_rhs47 ]
  br i1 %and414, label %bb_and_rhs49, label %bb_and_end50
bb_and_rhs49:
  %index_size415 = sext i32 0 to i64
  %dynamic_inline_in_bounds416 = icmp ult i64 %index_size415, %array_len406
  br i1 %dynamic_inline_in_bounds416, label %bb_dynamic_inline_bounds_ok51, label %bb_dynamic_inline_bounds_fail52

bb_dynamic_inline_bounds_fail52:
  %trap_stderr417 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr417, ptr @.slg.str.module.x.4, i32 40, ptr %trap_written418, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok51:
  %dynamic_inline_slot419 = getelementptr i8, ptr %array_ptr405, i64 %index_size415
  %dynamic_inline_item420 = load i8, ptr %dynamic_inline_slot419, align 1
  %cmp421 = icmp eq i8 %dynamic_inline_item420, 11
  br label %bb_and_end50
bb_and_end50:
  %and422 = phi i1 [ false, %bb_and_end48 ], [ %cmp421, %bb_dynamic_inline_bounds_ok51 ]
  br i1 %and422, label %bb_and_rhs53, label %bb_and_end54
bb_and_rhs53:
  %index_size423 = sext i32 1 to i64
  %dynamic_inline_in_bounds424 = icmp ult i64 %index_size423, %array_len406
  br i1 %dynamic_inline_in_bounds424, label %bb_dynamic_inline_bounds_ok55, label %bb_dynamic_inline_bounds_fail56

bb_dynamic_inline_bounds_fail56:
  %trap_stderr425 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr425, ptr @.slg.str.module.x.5, i32 40, ptr %trap_written426, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok55:
  %dynamic_inline_slot427 = getelementptr i8, ptr %array_ptr405, i64 %index_size423
  %dynamic_inline_item428 = load i8, ptr %dynamic_inline_slot427, align 1
  %cmp429 = icmp eq i8 %dynamic_inline_item428, 12
  br label %bb_and_end54
bb_and_end54:
  %and430 = phi i1 [ false, %bb_and_end50 ], [ %cmp429, %bb_dynamic_inline_bounds_ok55 ]
  br i1 %and430, label %bb_and_rhs57, label %bb_and_end58
bb_and_rhs57:
  %index_size431 = sext i32 2 to i64
  %dynamic_inline_in_bounds432 = icmp ult i64 %index_size431, %array_len406
  br i1 %dynamic_inline_in_bounds432, label %bb_dynamic_inline_bounds_ok59, label %bb_dynamic_inline_bounds_fail60

bb_dynamic_inline_bounds_fail60:
  %trap_stderr433 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr433, ptr @.slg.str.module.x.6, i32 40, ptr %trap_written434, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok59:
  %dynamic_inline_slot435 = getelementptr i8, ptr %array_ptr405, i64 %index_size431
  %dynamic_inline_item436 = load i8, ptr %dynamic_inline_slot435, align 1
  %cmp437 = icmp eq i8 %dynamic_inline_item436, 20
  br label %bb_and_end58
bb_and_end58:
  %and438 = phi i1 [ false, %bb_and_end54 ], [ %cmp437, %bb_dynamic_inline_bounds_ok59 ]
  br i1 %and438, label %bb_and_rhs61, label %bb_and_end62
bb_and_rhs61:
  %index_size439 = sext i32 3 to i64
  %dynamic_inline_in_bounds440 = icmp ult i64 %index_size439, %array_len406
  br i1 %dynamic_inline_in_bounds440, label %bb_dynamic_inline_bounds_ok63, label %bb_dynamic_inline_bounds_fail64

bb_dynamic_inline_bounds_fail64:
  %trap_stderr441 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr441, ptr @.slg.str.module.x.7, i32 40, ptr %trap_written442, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok63:
  %dynamic_inline_slot443 = getelementptr i8, ptr %array_ptr405, i64 %index_size439
  %dynamic_inline_item444 = load i8, ptr %dynamic_inline_slot443, align 1
  %cmp445 = icmp eq i8 %dynamic_inline_item444, 21
  br label %bb_and_end62
bb_and_end62:
  %and446 = phi i1 [ false, %bb_and_end58 ], [ %cmp445, %bb_dynamic_inline_bounds_ok63 ]
  br i1 %and446, label %bb_and_rhs65, label %bb_and_end66
bb_and_rhs65:
  %index_size447 = sext i32 4 to i64
  %dynamic_inline_in_bounds448 = icmp ult i64 %index_size447, %array_len406
  br i1 %dynamic_inline_in_bounds448, label %bb_dynamic_inline_bounds_ok67, label %bb_dynamic_inline_bounds_fail68

bb_dynamic_inline_bounds_fail68:
  %trap_stderr449 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr449, ptr @.slg.str.module.x.8, i32 40, ptr %trap_written450, ptr null)
  call void @llvm.trap()
  unreachable

bb_dynamic_inline_bounds_ok67:
  %dynamic_inline_slot451 = getelementptr i8, ptr %array_ptr405, i64 %index_size447
  %dynamic_inline_item452 = load i8, ptr %dynamic_inline_slot451, align 1
  %cmp453 = icmp eq i8 %dynamic_inline_item452, 22
  br label %bb_and_end66
bb_and_end66:
  %and454 = phi i1 [ false, %bb_and_end62 ], [ %cmp453, %bb_dynamic_inline_bounds_ok67 ]
  store %sollang.enum.2642 zeroinitializer, ptr %enum_init_slot455, align 8
  %enum_tag_addr456 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot455, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr456, align 4
  %enum_payload_addr457 = getelementptr inbounds %sollang.enum.2642, ptr %enum_init_slot455, i32 0, i32 1
  store i1 %and454, ptr %enum_payload_addr457, align 1
  %enum_value458 = load %sollang.enum.2642, ptr %enum_init_slot455, align 8
  call void @sollang_free(ptr %array_ptr405)
  call void @sollang_free(ptr %heap326)
  call void @sollang_free(ptr %heap308)
  call void @sollang_free(ptr %heap301)
  ret %sollang.enum.2642 %enum_value458
}

@.slg.str.suffix.0 = private unnamed_addr constant [16 x i8] c"socket-vectored=", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [4 x i8] c"true", align 1
@.slg.str.suffix.2 = private unnamed_addr constant [5 x i8] c"false", align 1
@.slg.str.suffix.3 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.4 = private unnamed_addr constant [22 x i8] c"socket-vectored-error=", align 1
@.slg.str.suffix.5 = private unnamed_addr constant [1 x i8] c"\0A", align 1
define dso_local void @__chkstk() naked nounwind {
entry:
  call void asm sideeffect inteldialect "push rcx\0Apush rax\0Alea rcx, [rsp + 24]\0Acmp rax, 4096\0Ajb .Lsollang_chkstk_tail\0A.Lsollang_chkstk_loop:\0Asub rcx, 4096\0Atest byte ptr [rcx], 0\0Asub rax, 4096\0Acmp rax, 4096\0Ajae .Lsollang_chkstk_loop\0A.Lsollang_chkstk_tail:\0Asub rcx, rax\0Atest byte ptr [rcx], 0\0Apop rax\0Apop rcx\0Aret", "~{memory},~{flags}"()
  unreachable
}

define internal i32 @sollang_write_stdout_bytes(ptr %stdout, ptr %data, i32 %len, ptr %written) #0 {
entry:
  %empty = icmp eq i32 %len, 0
  br i1 %empty, label %success_empty, label %classify

success_empty:
  store i32 0, ptr %written, align 4
  ret i32 1

classify:
  %is_console = load i1, ptr @sollang_stdout_line_buffered, align 1
  br i1 %is_console, label %console_prepare, label %redirected

redirected:
  br label %redirected_write

redirected_write:
  %redirected_offset = phi i32 [ 0, %redirected ], [ %redirected_next, %redirected_advance ]
  %redirected_remaining = sub i32 %len, %redirected_offset
  %redirected_offset64 = zext i32 %redirected_offset to i64
  %redirected_data = getelementptr i8, ptr %data, i64 %redirected_offset64
  store i32 0, ptr %written, align 4
  %redirected_ok = call i32 @WriteFile(ptr %stdout, ptr %redirected_data, i32 %redirected_remaining, ptr %written, ptr null)
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
  %console_ok = call i32 @WriteConsoleW(ptr %stdout, ptr %console_data, i32 %console_remaining, ptr %wide_written, ptr null)
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
  %direct_len = trunc i64 %len64 to i32
  %direct_ok = call i32 @sollang_write_stdout_bytes(ptr %stdout, ptr %data, i32 %direct_len, ptr %written)
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
  %len = trunc i64 %len64 to i32
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
  %enum_init_slot6 = alloca %sollang.enum.1525, align 8
  %enum_match_slot13 = alloca %sollang.enum.2642, align 8
  %enum_match_slot31 = alloca %sollang.enum.2642, align 8
  store i1 true, ptr %ok_state, align 1
  %stdin = call ptr @GetStdHandle(i32 -10)
  %stdout = call ptr @GetStdHandle(i32 -11)
  %stdout_mode = alloca i32, align 4
  %stdout_is_console_status = call i32 @GetConsoleMode(ptr %stdout, ptr %stdout_mode)
  %stdout_is_console = icmp ne i32 %stdout_is_console_status, 0
  store i1 %stdout_is_console, ptr @sollang_stdout_line_buffered, align 1
  %struct_init0 = insertvalue %sollang.struct.1219 poison, i8 127, 0
  %struct_init1 = insertvalue %sollang.struct.1219 %struct_init0, i8 0, 1
  %struct_init2 = insertvalue %sollang.struct.1219 %struct_init1, i8 0, 2
  %struct_init3 = insertvalue %sollang.struct.1219 %struct_init2, i8 1, 3
  %struct_init4 = insertvalue %sollang.struct.1220 poison, %sollang.struct.1219 %struct_init3, 0
  %struct_init5 = insertvalue %sollang.struct.1220 %struct_init4, i16 0, 1
  store %sollang.enum.1525 zeroinitializer, ptr %enum_init_slot6, align 8
  %enum_tag_addr7 = getelementptr inbounds %sollang.enum.1525, ptr %enum_init_slot6, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr7, align 4
  %enum_payload_addr8 = getelementptr inbounds %sollang.enum.1525, ptr %enum_init_slot6, i32 0, i32 1
  store %sollang.struct.1220 %struct_init5, ptr %enum_payload_addr8, align 2
  %enum_value9 = load %sollang.enum.1525, ptr %enum_init_slot6, align 8
  %struct_call10 = call %sollang.enum.2642 @sollang_fn_observe(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.enum.1525 %enum_value9)
  %enum_tag11 = extractvalue %sollang.enum.2642 %struct_call10, 0
  %enum_matches12 = icmp eq i32 %enum_tag11, 0
  br i1 %enum_matches12, label %bb_enum_when_arm1, label %bb_enum_when_next2
bb_enum_when_arm1:
  store %sollang.enum.2642 %struct_call10, ptr %enum_match_slot13, align 8
  %enum_payload_addr14 = getelementptr inbounds %sollang.enum.2642, ptr %enum_match_slot13, i32 0, i32 1
  %enum_payload15 = load i1, ptr %enum_payload_addr14, align 1
  %write16 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.0, i64 16, ptr %written)
  %is_ok17 = icmp ne i32 %write16, 0
  %previous_ok18 = load i1, ptr %ok_state, align 1
  %ok19 = and i1 %previous_ok18, %is_ok17
  store i1 %ok19, ptr %ok_state, align 1
  %format_bool_pointer20 = select i1 %enum_payload15, ptr @.slg.str.suffix.1, ptr @.slg.str.suffix.2
  %format_bool_length21 = select i1 %enum_payload15, i64 4, i64 5
  %write22 = call i32 @sollang_write(ptr %stdout, ptr %format_bool_pointer20, i64 %format_bool_length21, ptr %written)
  %is_ok23 = icmp ne i32 %write22, 0
  %previous_ok24 = load i1, ptr %ok_state, align 1
  %ok25 = and i1 %previous_ok24, %is_ok23
  store i1 %ok25, ptr %ok_state, align 1
  %write26 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.3, i64 1, ptr %written)
  %is_ok27 = icmp ne i32 %write26, 0
  %previous_ok28 = load i1, ptr %ok_state, align 1
  %ok29 = and i1 %previous_ok28, %is_ok27
  store i1 %ok29, ptr %ok_state, align 1
  br label %bb_enum_when_end0
bb_enum_when_next2:
  %enum_matches30 = icmp eq i32 %enum_tag11, 1
  br i1 %enum_matches30, label %bb_enum_when_arm3, label %bb_enum_when_next4
bb_enum_when_arm3:
  store %sollang.enum.2642 %struct_call10, ptr %enum_match_slot31, align 8
  %enum_payload_addr32 = getelementptr inbounds %sollang.enum.2642, ptr %enum_match_slot31, i32 0, i32 1
  %enum_payload33 = load %sollang.struct.1373, ptr %enum_payload_addr32, align 8
  %write34 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.4, i64 22, ptr %written)
  %is_ok35 = icmp ne i32 %write34, 0
  %previous_ok36 = load i1, ptr %ok_state, align 1
  %ok37 = and i1 %previous_ok36, %is_ok35
  store i1 %ok37, ptr %ok_state, align 1
  %field38 = extractvalue %sollang.struct.1373 %enum_payload33, 1
  %print_integer39 = sext i32 %field38 to i64
  %write40 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer39, ptr %written)
  %is_ok41 = icmp ne i32 %write40, 0
  %previous_ok42 = load i1, ptr %ok_state, align 1
  %ok43 = and i1 %previous_ok42, %is_ok41
  store i1 %ok43, ptr %ok_state, align 1
  %write44 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.5, i64 1, ptr %written)
  %is_ok45 = icmp ne i32 %write44, 0
  %previous_ok46 = load i1, ptr %ok_state, align 1
  %ok47 = and i1 %previous_ok46, %is_ok45
  store i1 %ok47, ptr %ok_state, align 1
  br label %bb_enum_when_end0
bb_enum_when_next4:
  call void @llvm.trap()
  unreachable
bb_enum_when_end0:
  call void @sollang_platform_socket_cleanup()
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %final_ok48 = load i1, ptr %ok_state, align 1
  %exit49 = select i1 %final_ok48, i32 0, i32 1
  ret i32 %exit49
}

attributes #0 = { nounwind }
