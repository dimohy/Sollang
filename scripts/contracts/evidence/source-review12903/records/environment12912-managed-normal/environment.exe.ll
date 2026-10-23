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
declare dllimport i32 @CreateProcessW(ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr)
declare dllimport ptr @GetEnvironmentStringsW()
declare dllimport i32 @FreeEnvironmentStringsW(ptr)
declare dllimport i32 @CompareStringOrdinal(ptr, i32, ptr, i32, i32)
declare dllimport i32 @GetProcessId(ptr)
declare dllimport i32 @GetExitCodeProcess(ptr, ptr)
declare dllimport i32 @TerminateProcess(ptr, i32)
declare dllimport i32 @WaitForSingleObject(ptr, i32)
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

@.slg.str.module.x.0 = private unnamed_addr constant [7 x i8] c"missing", align 1
define internal %sollang.text @sollang_fn_describe(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.enum.2621 %it) #0 {
entry:
  %enum_match_slot3 = alloca %sollang.enum.2621, align 8
  %enum_tag0 = extractvalue %sollang.enum.2621 %it, 0
  %enum_matches1 = icmp eq i32 %enum_tag0, 0
  br i1 %enum_matches1, label %bb_enum_when_arm1, label %bb_enum_when_next2
bb_enum_when_arm1:
  br label %bb_enum_when_end0
bb_enum_when_next2:
  %enum_matches2 = icmp eq i32 %enum_tag0, 1
  br i1 %enum_matches2, label %bb_enum_when_arm3, label %bb_enum_when_next4
bb_enum_when_arm3:
  store %sollang.enum.2621 %it, ptr %enum_match_slot3, align 8
  %enum_payload_addr4 = getelementptr inbounds %sollang.enum.2621, ptr %enum_match_slot3, i32 0, i32 1
  %enum_payload5 = load %sollang.text, ptr %enum_payload_addr4, align 8
  %text_ptr6 = extractvalue %sollang.text %enum_payload5, 0
  %text_len7 = extractvalue %sollang.text %enum_payload5, 1
  br label %bb_enum_when_end0
bb_enum_when_next4:
  call void @llvm.trap()
  unreachable
bb_enum_when_end0:
  %enum_when_ptr8 = phi ptr [ @.slg.str.module.x.0, %bb_enum_when_arm1 ], [ %text_ptr6, %bb_enum_when_arm3 ]
  %enum_when_len9 = phi i64 [ 7, %bb_enum_when_arm1 ], [ %text_len7, %bb_enum_when_arm3 ]
  %text_ret10 = insertvalue %sollang.text poison, ptr %enum_when_ptr8, 0
  %text_ret11 = insertvalue %sollang.text %text_ret10, i64 %enum_when_len9, 1
  ret %sollang.text %text_ret11
}

@.slg.str.suffix.0 = private unnamed_addr constant [18 x i8] c"SOLLANG_TEST_VALUE", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [32 x i8] c"main:bb_environment_lookup_fail1", align 1
@.slg.str.suffix.2 = private unnamed_addr constant [18 x i8] c"SOLLANG_TEST_EMPTY", align 1
@.slg.str.suffix.3 = private unnamed_addr constant [32 x i8] c"main:bb_environment_lookup_fail6", align 1
@.slg.str.suffix.4 = private unnamed_addr constant [20 x i8] c"SOLLANG_TEST_MISSING", align 1
@.slg.str.suffix.5 = private unnamed_addr constant [33 x i8] c"main:bb_environment_lookup_fail11", align 1
@.slg.str.suffix.6 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.7 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.8 = private unnamed_addr constant [1 x i8] c"\0A", align 1
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

define internal i32 @sollang_init_arguments() #0 {
entry:
  %argc_slot = alloca i32, align 4
  %command = call ptr @GetCommandLineW()
  %wide_argv = call ptr @CommandLineToArgvW(ptr %command, ptr %argc_slot)
  %argv_ok = icmp ne ptr %wide_argv, null
  br i1 %argv_ok, label %allocate, label %fail

allocate:
  %argc32 = load i32, ptr %argc_slot, align 4
  %argc = zext i32 %argc32 to i64
  %record_bytes = mul i64 %argc, 16
  %records = call ptr @sollang_alloc(i64 %record_bytes)
  %records_ok = icmp ne ptr %records, null
  br i1 %records_ok, label %loop, label %free_wide_fail

loop:
  %i = phi i64 [ 0, %allocate ], [ %next, %stored ]
  %done = icmp eq i64 %i, %argc
  br i1 %done, label %success, label %convert_size

convert_size:
  %wide_slot = getelementptr ptr, ptr %wide_argv, i64 %i
  %wide = load ptr, ptr %wide_slot, align 8
  %bytes32 = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide, i32 -1, ptr null, i32 0, ptr null, ptr null)
  %bytes_valid = icmp sgt i32 %bytes32, 0
  br i1 %bytes_valid, label %convert_alloc, label %cleanup_partial

convert_alloc:
  %bytes = zext i32 %bytes32 to i64
  %utf8 = call ptr @sollang_alloc(i64 %bytes)
  %utf8_ok = icmp ne ptr %utf8, null
  br i1 %utf8_ok, label %convert, label %cleanup_partial

convert:
  %written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide, i32 -1, ptr %utf8, i32 %bytes32, ptr null, ptr null)
  %converted = icmp eq i32 %written, %bytes32
  br i1 %converted, label %stored, label %free_current

free_current:
  call void @sollang_free(ptr %utf8)
  br label %cleanup_partial

stored:
  %record = getelementptr %sollang.text, ptr %records, i64 %i
  %ptr_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  store ptr %utf8, ptr %ptr_slot, align 8
  %len_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 1
  %length = sub i64 %bytes, 1
  store i64 %length, ptr %len_slot, align 8
  %next = add i64 %i, 1
  br label %loop

cleanup_partial:
  %j = phi i64 [ %i, %convert_size ], [ %i, %convert_alloc ], [ %i, %free_current ], [ %prev, %cleanup_free ]
  %cleanup_done = icmp eq i64 %j, 0
  br i1 %cleanup_done, label %free_records_fail, label %cleanup_free

cleanup_free:
  %prev = sub i64 %j, 1
  %old_record = getelementptr %sollang.text, ptr %records, i64 %prev
  %old_ptr_slot = getelementptr inbounds %sollang.text, ptr %old_record, i32 0, i32 0
  %old_ptr = load ptr, ptr %old_ptr_slot, align 8
  call void @sollang_free(ptr %old_ptr)
  br label %cleanup_partial

free_records_fail:
  call void @sollang_free(ptr %records)
  br label %free_wide_fail

success:
  store i64 %argc, ptr @sollang_argument_count_value, align 8
  store ptr %records, ptr @sollang_argument_records, align 8
  %ignored_wide = call ptr @LocalFree(ptr %wide_argv)
  ret i32 1

free_wide_fail:
  %ignored_fail = call ptr @LocalFree(ptr %wide_argv)
  br label %fail

fail:
  ret i32 0
}

define internal i64 @sollang_argument_count() #0 {
entry:
  %count = load i64, ptr @sollang_argument_count_value, align 8
  ret i64 %count
}

define internal %sollang.text @sollang_argument(i64 %index) #0 {
entry:
  %records = load ptr, ptr @sollang_argument_records, align 8
  %record = getelementptr %sollang.text, ptr %records, i64 %index
  %value = load %sollang.text, ptr %record, align 8
  ret %sollang.text %value
}

define internal ptr @sollang_quote_windows_arg(ptr %src, i32 %chars) #0 {
entry:
  %chars64 = zext i32 %chars to i64
  %double = mul i64 %chars64, 2
  %capacity = add i64 %double, 3
  %bytes = mul i64 %capacity, 2
  %out = call ptr @sollang_alloc(i64 %bytes)
  %out_ok = icmp ne ptr %out, null
  br i1 %out_ok, label %init, label %fail

init:
  store i16 34, ptr %out, align 2
  %i_slot = alloca i32, align 4
  %o_slot = alloca i64, align 8
  %slashes_slot = alloca i64, align 8
  store i32 0, ptr %i_slot, align 4
  store i64 1, ptr %o_slot, align 8
  store i64 0, ptr %slashes_slot, align 8
  br label %loop

loop:
  %i = load i32, ptr %i_slot, align 4
  %done = icmp eq i32 %i, %chars
  br i1 %done, label %finish_prepare, label %read

read:
  %char_ptr = getelementptr i16, ptr %src, i32 %i
  %char = load i16, ptr %char_ptr, align 2
  %is_slash = icmp eq i16 %char, 92
  br i1 %is_slash, label %remember_slash, label %flush_prepare

remember_slash:
  %slashes = load i64, ptr %slashes_slot, align 8
  %more_slashes = add i64 %slashes, 1
  store i64 %more_slashes, ptr %slashes_slot, align 8
  %slash_next_i = add i32 %i, 1
  store i32 %slash_next_i, ptr %i_slot, align 4
  br label %loop

flush_prepare:
  %pending = load i64, ptr %slashes_slot, align 8
  %is_quote = icmp eq i16 %char, 34
  %doubled_pending = mul i64 %pending, 2
  %quote_escape = add i64 %doubled_pending, 1
  %flush_count = select i1 %is_quote, i64 %quote_escape, i64 %pending
  br label %flush_loop

flush_loop:
  %flush_i = phi i64 [ 0, %flush_prepare ], [ %flush_next, %flush_body ]
  %flush_done = icmp eq i64 %flush_i, %flush_count
  br i1 %flush_done, label %write_char, label %flush_body

flush_body:
  %flush_o = load i64, ptr %o_slot, align 8
  %flush_ptr = getelementptr i16, ptr %out, i64 %flush_o
  store i16 92, ptr %flush_ptr, align 2
  %flush_o_next = add i64 %flush_o, 1
  store i64 %flush_o_next, ptr %o_slot, align 8
  %flush_next = add i64 %flush_i, 1
  br label %flush_loop

write_char:
  %o = load i64, ptr %o_slot, align 8
  %out_char = getelementptr i16, ptr %out, i64 %o
  store i16 %char, ptr %out_char, align 2
  %o_next = add i64 %o, 1
  store i64 %o_next, ptr %o_slot, align 8
  store i64 0, ptr %slashes_slot, align 8
  %next_i = add i32 %i, 1
  store i32 %next_i, ptr %i_slot, align 4
  br label %loop

finish_prepare:
  %trailing = load i64, ptr %slashes_slot, align 8
  %finish_count = mul i64 %trailing, 2
  br label %finish_loop

finish_loop:
  %finish_i = phi i64 [ 0, %finish_prepare ], [ %finish_next, %finish_body ]
  %finish_done = icmp eq i64 %finish_i, %finish_count
  br i1 %finish_done, label %close_quote, label %finish_body

finish_body:
  %finish_o = load i64, ptr %o_slot, align 8
  %finish_ptr = getelementptr i16, ptr %out, i64 %finish_o
  store i16 92, ptr %finish_ptr, align 2
  %finish_o_next = add i64 %finish_o, 1
  store i64 %finish_o_next, ptr %o_slot, align 8
  %finish_next = add i64 %finish_i, 1
  br label %finish_loop

close_quote:
  %close_o = load i64, ptr %o_slot, align 8
  %quote_ptr = getelementptr i16, ptr %out, i64 %close_o
  store i16 34, ptr %quote_ptr, align 2
  %null_i = add i64 %close_o, 1
  %null_ptr = getelementptr i16, ptr %out, i64 %null_i
  store i16 0, ptr %null_ptr, align 2
  ret ptr %out

fail:
  ret ptr null
}

define internal ptr @sollang_process_windows_text(ptr %data, i64 %length64) #0 {
entry:
  %length_fits = icmp ule i64 %length64, 2147483647
  br i1 %length_fits, label %measure, label %fail

measure:
  %length = trunc i64 %length64 to i32
  %chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr null, i32 0)
  %chars_valid = icmp sgt i32 %chars, 0
  %empty = icmp eq i32 %length, 0
  %valid = or i1 %chars_valid, %empty
  br i1 %valid, label %allocate, label %fail

allocate:
  %with_null = add i32 %chars, 1
  %with_null64 = zext i32 %with_null to i64
  %bytes = mul i64 %with_null64, 2
  %wide = call ptr @sollang_alloc(i64 %bytes)
  %allocated = icmp ne ptr %wide, null
  br i1 %allocated, label %convert, label %fail

convert:
  %written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %data, i32 %length, ptr %wide, i32 %chars)
  %converted = icmp eq i32 %written, %chars
  br i1 %converted, label %terminate, label %free_fail

terminate:
  %end = getelementptr i16, ptr %wide, i32 %chars
  store i16 0, ptr %end, align 2
  ret ptr %wide

free_fail:
  call void @sollang_free(ptr %wide)
  br label %fail

fail:
  ret ptr null
}

define internal ptr @sollang_process_windows_path(ptr %data, i64 %length) #0 {
entry:
  %present = icmp ugt i64 %length, 0
  br i1 %present, label %check, label %fail

check:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %convert, label %inspect

inspect:
  %byte_ptr = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %byte_ptr, align 1
  %nul = icmp eq i8 %byte, 0
  br i1 %nul, label %fail, label %advance

advance:
  %next = add i64 %index, 1
  br label %check

convert:
  %wide = call ptr @sollang_process_windows_text(ptr %data, i64 %length)
  ret ptr %wide

fail:
  ret ptr null
}

define internal ptr @sollang_join_windows_args(ptr %argv, i64 %count) #0 {
entry:
  %i_slot = alloca i64, align 8
  %total_slot = alloca i64, align 8
  store i64 0, ptr %i_slot, align 8
  store i64 0, ptr %total_slot, align 8
  br label %measure_outer

measure_outer:
  %i = load i64, ptr %i_slot, align 8
  %outer_done = icmp eq i64 %i, %count
  br i1 %outer_done, label %allocate, label %measure_inner

measure_inner:
  %j = phi i64 [ 0, %measure_outer ], [ %j_next, %measure_more ]
  %arg_slot = getelementptr ptr, ptr %argv, i64 %i
  %arg = load ptr, ptr %arg_slot, align 8
  %char_ptr = getelementptr i16, ptr %arg, i64 %j
  %char = load i16, ptr %char_ptr, align 2
  %arg_done = icmp eq i16 %char, 0
  br i1 %arg_done, label %measure_arg_done, label %measure_more

measure_more:
  %j_next = add i64 %j, 1
  br label %measure_inner

measure_arg_done:
  %total = load i64, ptr %total_slot, align 8
  %needs_space = icmp ne i64 %i, 0
  %space = zext i1 %needs_space to i64
  %with_arg = add i64 %total, %j
  %next_total = add i64 %with_arg, %space
  store i64 %next_total, ptr %total_slot, align 8
  %i_next = add i64 %i, 1
  store i64 %i_next, ptr %i_slot, align 8
  br label %measure_outer

allocate:
  %total_chars = load i64, ptr %total_slot, align 8
  %chars_with_null = add i64 %total_chars, 1
  %bytes = mul i64 %chars_with_null, 2
  %command = call ptr @sollang_alloc(i64 %bytes)
  %allocated = icmp ne ptr %command, null
  br i1 %allocated, label %copy_setup, label %fail

copy_setup:
  store i64 0, ptr %i_slot, align 8
  store i64 0, ptr %total_slot, align 8
  br label %copy_outer

copy_outer:
  %copy_i = load i64, ptr %i_slot, align 8
  %copy_done = icmp eq i64 %copy_i, %count
  br i1 %copy_done, label %terminate, label %copy_space

copy_space:
  %copy_offset = load i64, ptr %total_slot, align 8
  %copy_needs_space = icmp ne i64 %copy_i, 0
  br i1 %copy_needs_space, label %store_space, label %copy_inner

store_space:
  %space_ptr = getelementptr i16, ptr %command, i64 %copy_offset
  store i16 32, ptr %space_ptr, align 2
  %after_space = add i64 %copy_offset, 1
  store i64 %after_space, ptr %total_slot, align 8
  br label %copy_inner

copy_inner:
  %copy_j = phi i64 [ 0, %copy_space ], [ 0, %store_space ], [ %copy_j_next, %copy_more ]
  %copy_arg_slot = getelementptr ptr, ptr %argv, i64 %copy_i
  %copy_arg = load ptr, ptr %copy_arg_slot, align 8
  %copy_char_ptr = getelementptr i16, ptr %copy_arg, i64 %copy_j
  %copy_char = load i16, ptr %copy_char_ptr, align 2
  %copy_arg_done = icmp eq i16 %copy_char, 0
  br i1 %copy_arg_done, label %copy_arg_finish, label %copy_more

copy_more:
  %current_offset = load i64, ptr %total_slot, align 8
  %destination = getelementptr i16, ptr %command, i64 %current_offset
  store i16 %copy_char, ptr %destination, align 2
  %next_offset = add i64 %current_offset, 1
  store i64 %next_offset, ptr %total_slot, align 8
  %copy_j_next = add i64 %copy_j, 1
  br label %copy_inner

copy_arg_finish:
  %copy_i_next = add i64 %copy_i, 1
  store i64 %copy_i_next, ptr %i_slot, align 8
  br label %copy_outer

terminate:
  %final_offset = load i64, ptr %total_slot, align 8
  %null_ptr = getelementptr i16, ptr %command, i64 %final_offset
  store i16 0, ptr %null_ptr, align 2
  ret ptr %command

fail:
  ret ptr null
}

define internal i64 @sollang_windows_wide_length(ptr %text) #0 {
entry:
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %more ]
  %at = getelementptr i16, ptr %text, i64 %index
  %character = load i16, ptr %at, align 2
  %done = icmp eq i16 %character, 0
  br i1 %done, label %result, label %more
more:
  %next = add i64 %index, 1
  br label %loop
result:
  ret i64 %index
}

define internal i64 @sollang_windows_environment_name_length(ptr %entry) #0 {
entry_block:
  %first = load i16, ptr %entry, align 2
  %hidden = icmp eq i16 %first, 61
  %start = select i1 %hidden, i64 1, i64 0
  br label %loop
loop:
  %index = phi i64 [ %start, %entry_block ], [ %next, %more ]
  %at = getelementptr i16, ptr %entry, i64 %index
  %character = load i16, ptr %at, align 2
  %separator = icmp eq i16 %character, 61
  %end = icmp eq i16 %character, 0
  %done = or i1 %separator, %end
  br i1 %done, label %result, label %more
more:
  %next = add i64 %index, 1
  br label %loop
result:
  ret i64 %index
}

define internal i1 @sollang_windows_environment_text_valid(ptr %data, i64 %length, i1 %name) #0 {
entry:
  br label %loop
loop:
  %index = phi i64 [ 0, %entry ], [ %next, %more ]
  %done = icmp eq i64 %index, %length
  br i1 %done, label %valid, label %inspect
inspect:
  %at = getelementptr i8, ptr %data, i64 %index
  %byte = load i8, ptr %at, align 1
  %nul = icmp eq i8 %byte, 0
  %equal = icmp eq i8 %byte, 61
  %name_equal = and i1 %name, %equal
  %invalid = or i1 %nul, %name_equal
  br i1 %invalid, label %failure, label %more
more:
  %next = add i64 %index, 1
  br label %loop
valid:
  ret i1 true
failure:
  ret i1 false
}

define internal i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %count, ptr %name, i64 %name_length) #0 {
entry:
  %name_fits = icmp ule i64 %name_length, 2147483647
  br i1 %name_fits, label %loop, label %missing
loop:
  %remaining = phi i64 [ %count, %entry ], [ %index, %different ]
  %done = icmp eq i64 %remaining, 0
  br i1 %done, label %missing, label %inspect
inspect:
  %index = sub i64 %remaining, 1
  %entry_slot = getelementptr ptr, ptr %entries, i64 %index
  %candidate = load ptr, ptr %entry_slot, align 8
  %length_slot = getelementptr i64, ptr %name_lengths, i64 %index
  %candidate_length64 = load i64, ptr %length_slot, align 8
  %candidate_fits = icmp ule i64 %candidate_length64, 2147483647
  br i1 %candidate_fits, label %compare, label %different
compare:
  %candidate_length = trunc i64 %candidate_length64 to i32
  %target_length = trunc i64 %name_length to i32
  %order = call i32 @CompareStringOrdinal(ptr %candidate, i32 %candidate_length, ptr %name, i32 %target_length, i32 1)
  %matches = icmp eq i32 %order, 2
  br i1 %matches, label %found, label %different
different:
  br label %loop
found:
  ret i64 %index
missing:
  ret i64 -1
}

define internal void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %count, ptr %parent) #0 {
entry:
  %has_entries = icmp ne ptr %entries, null
  br i1 %has_entries, label %entry_loop, label %free_arrays
entry_loop:
  %index = phi i64 [ 0, %entry ], [ %next, %entry_more ]
  %entries_done = icmp eq i64 %index, %count
  br i1 %entries_done, label %free_arrays, label %entry_more
entry_more:
  %slot = getelementptr ptr, ptr %entries, i64 %index
  %value = load ptr, ptr %slot, align 8
  call void @sollang_free(ptr %value)
  %next = add i64 %index, 1
  br label %entry_loop
free_arrays:
  call void @sollang_free(ptr %entries)
  call void @sollang_free(ptr %name_lengths)
  call void @sollang_free(ptr %list)
  %has_parent = icmp ne ptr %parent, null
  br i1 %has_parent, label %free_parent, label %cleanup_done
free_parent:
  %parent_freed = call i32 @FreeEnvironmentStringsW(ptr %parent)
  br label %cleanup_done
cleanup_done:
  ret void
}

define internal %sollang.process_environment_result @sollang_windows_build_environment(ptr %changes, i64 %change_count, i1 %inherits) #0 {
entry:
  %has_changes = icmp ne i64 %change_count, 0
  %cleared = xor i1 %inherits, true
  %custom = or i1 %has_changes, %cleared
  br i1 %custom, label %allocate_entries, label %fast
fast:
  %fast0 = insertvalue %sollang.process_environment_result poison, ptr null, 0
  %fast1 = insertvalue %sollang.process_environment_result %fast0, i64 0, 1
  %fast2 = insertvalue %sollang.process_environment_result %fast1, i64 -1, 2
  %fast3 = insertvalue %sollang.process_environment_result %fast2, i1 true, 3
  ret %sollang.process_environment_result %fast3
allocate_entries:
  %entry_slots0 = select i1 %has_changes, i64 %change_count, i64 1
  %entry_bytes = mul i64 %entry_slots0, 8
  %entries = call ptr @sollang_alloc(i64 %entry_bytes)
  %entries_ok = icmp ne ptr %entries, null
  br i1 %entries_ok, label %allocate_lengths, label %failure
allocate_lengths:
  %name_lengths = call ptr @sollang_alloc(i64 %entry_bytes)
  %lengths_ok = icmp ne ptr %name_lengths, null
  br i1 %lengths_ok, label %initialize_entries, label %free_entries_failure
initialize_entries:
  %init_index = phi i64 [ 0, %allocate_lengths ], [ %init_next, %init_more ]
  %init_done = icmp eq i64 %init_index, %change_count
  br i1 %init_done, label %convert_changes, label %init_more
init_more:
  %init_slot = getelementptr ptr, ptr %entries, i64 %init_index
  store ptr null, ptr %init_slot, align 8
  %init_next = add i64 %init_index, 1
  br label %initialize_entries
convert_changes:
  %change_index = phi i64 [ 0, %initialize_entries ], [ %change_next_removed, %store_removed ], [ %change_next_set, %store_set ]
  %changes_done = icmp eq i64 %change_index, %change_count
  br i1 %changes_done, label %parent_select, label %load_change
load_change:
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
convert_name:
  %wide_name = call ptr @sollang_process_windows_text(ptr %name_data, i64 %name_length)
  %wide_name_ok = icmp ne ptr %wide_name, null
  br i1 %wide_name_ok, label %measure_name, label %build_failure
measure_name:
  %wide_name_length = call i64 @sollang_windows_wide_length(ptr %wide_name)
  %name_length_store = getelementptr i64, ptr %name_lengths, i64 %change_index
  store i64 %wide_name_length, ptr %name_length_store, align 8
  %removed_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %change, i32 0, i32 2
  %removed = load i1, ptr %removed_slot, align 1
  br i1 %removed, label %store_removed, label %convert_value
store_removed:
  %removed_entry_slot = getelementptr ptr, ptr %entries, i64 %change_index
  store ptr %wide_name, ptr %removed_entry_slot, align 8
  %change_next_removed = add i64 %change_index, 1
  br label %convert_changes
convert_value:
  %wide_value = call ptr @sollang_process_windows_text(ptr %value_data, i64 %value_length)
  %wide_value_ok = icmp ne ptr %wide_value, null
  br i1 %wide_value_ok, label %allocate_entry, label %free_name_failure
allocate_entry:
  %wide_value_length = call i64 @sollang_windows_wide_length(ptr %wide_value)
  %entry_without_end = add i64 %wide_name_length, %wide_value_length
  %entry_chars = add i64 %entry_without_end, 2
  %wide_entry_bytes = mul i64 %entry_chars, 2
  %wide_entry = call ptr @sollang_alloc(i64 %wide_entry_bytes)
  %wide_entry_ok = icmp ne ptr %wide_entry, null
  br i1 %wide_entry_ok, label %copy_entry, label %free_name_value_failure
copy_entry:
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
  call void @sollang_free(ptr %wide_name)
  call void @sollang_free(ptr %wide_value)
  br label %store_set
store_set:
  %set_entry_slot = getelementptr ptr, ptr %entries, i64 %change_index
  store ptr %wide_entry, ptr %set_entry_slot, align 8
  %change_next_set = add i64 %change_index, 1
  br label %convert_changes
free_name_failure:
  call void @sollang_free(ptr %wide_name)
  br label %build_failure
free_name_value_failure:
  call void @sollang_free(ptr %wide_name)
  call void @sollang_free(ptr %wide_value)
  br label %build_failure
parent_select:
  br i1 %inherits, label %load_parent, label %allocate_list
load_parent:
  %parent = call ptr @GetEnvironmentStringsW()
  %parent_ok = icmp ne ptr %parent, null
  br i1 %parent_ok, label %count_parent, label %build_failure
count_parent:
  %parent_count = phi i64 [ 0, %load_parent ], [ %parent_count_next, %parent_more ]
  %parent_cursor = phi ptr [ %parent, %load_parent ], [ %parent_next, %parent_more ]
  %parent_first = load i16, ptr %parent_cursor, align 2
  %parent_done = icmp eq i16 %parent_first, 0
  br i1 %parent_done, label %allocate_list, label %parent_more
parent_more:
  %parent_length = call i64 @sollang_windows_wide_length(ptr %parent_cursor)
  %parent_stride = add i64 %parent_length, 1
  %parent_next = getelementptr i16, ptr %parent_cursor, i64 %parent_stride
  %parent_count_next = add i64 %parent_count, 1
  br label %count_parent
allocate_list:
  %selected_parent = phi ptr [ null, %parent_select ], [ %parent, %count_parent ]
  %selected_parent_count = phi i64 [ 0, %parent_select ], [ %parent_count, %count_parent ]
  %maximum_count = add i64 %selected_parent_count, %change_count
  %list_slots = add i64 %maximum_count, 1
  %list_bytes = mul i64 %list_slots, 8
  %list = call ptr @sollang_alloc(i64 %list_bytes)
  %list_ok = icmp ne ptr %list, null
  br i1 %list_ok, label %copy_parent, label %build_failure_with_parent
copy_parent:
  %copy_parent_index = phi i64 [ 0, %allocate_list ], [ %copy_parent_next, %copy_parent_continue ]
  %copy_parent_cursor = phi ptr [ %selected_parent, %allocate_list ], [ %copy_parent_cursor_next, %copy_parent_continue ]
  %kept_count = phi i64 [ 0, %allocate_list ], [ %kept_next, %copy_parent_continue ]
  %copy_parent_done = icmp eq i64 %copy_parent_index, %selected_parent_count
  br i1 %copy_parent_done, label %append_changes, label %copy_parent_inspect
copy_parent_inspect:
  %parent_entry_length = call i64 @sollang_windows_wide_length(ptr %copy_parent_cursor)
  %parent_name_length = call i64 @sollang_windows_environment_name_length(ptr %copy_parent_cursor)
  %parent_change = call i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %change_count, ptr %copy_parent_cursor, i64 %parent_name_length)
  %parent_overridden = icmp sge i64 %parent_change, 0
  br i1 %parent_overridden, label %copy_parent_skip, label %copy_parent_keep
copy_parent_keep:
  %parent_destination = getelementptr ptr, ptr %list, i64 %kept_count
  store ptr %copy_parent_cursor, ptr %parent_destination, align 8
  %kept_after_copy = add i64 %kept_count, 1
  br label %copy_parent_continue
copy_parent_skip:
  br label %copy_parent_continue
copy_parent_continue:
  %kept_next = phi i64 [ %kept_after_copy, %copy_parent_keep ], [ %kept_count, %copy_parent_skip ]
  %copy_parent_stride = add i64 %parent_entry_length, 1
  %copy_parent_cursor_next = getelementptr i16, ptr %copy_parent_cursor, i64 %copy_parent_stride
  %copy_parent_next = add i64 %copy_parent_index, 1
  br label %copy_parent
append_changes:
  %append_index = phi i64 [ 0, %copy_parent ], [ %append_next, %append_continue ]
  %output_count = phi i64 [ %kept_count, %copy_parent ], [ %output_next, %append_continue ]
  %append_done = icmp eq i64 %append_index, %change_count
  br i1 %append_done, label %sort_outer, label %append_inspect
append_inspect:
  %append_entry_slot = getelementptr ptr, ptr %entries, i64 %append_index
  %append_entry = load ptr, ptr %append_entry_slot, align 8
  %append_name_length_slot = getelementptr i64, ptr %name_lengths, i64 %append_index
  %append_name_length = load i64, ptr %append_name_length_slot, align 8
  %latest = call i64 @sollang_windows_latest_environment_change(ptr %entries, ptr %name_lengths, i64 %change_count, ptr %append_entry, i64 %append_name_length)
  %is_latest = icmp eq i64 %latest, %append_index
  br i1 %is_latest, label %append_latest, label %append_skip
append_latest:
  %append_change = getelementptr { %sollang.text, %sollang.text, i1 }, ptr %changes, i64 %append_index
  %append_removed_slot = getelementptr inbounds { %sollang.text, %sollang.text, i1 }, ptr %append_change, i32 0, i32 2
  %append_removed = load i1, ptr %append_removed_slot, align 1
  br i1 %append_removed, label %append_skip, label %append_keep
append_keep:
  %append_destination = getelementptr ptr, ptr %list, i64 %output_count
  store ptr %append_entry, ptr %append_destination, align 8
  %output_after_append = add i64 %output_count, 1
  br label %append_continue
append_skip:
  br label %append_continue
append_continue:
  %output_next = phi i64 [ %output_after_append, %append_keep ], [ %output_count, %append_skip ]
  %append_next = add i64 %append_index, 1
  br label %append_changes
sort_outer:
  %sort_index = phi i64 [ 1, %append_changes ], [ %sort_next, %sort_store ]
  %sort_done = icmp uge i64 %sort_index, %output_count
  br i1 %sort_done, label %measure_block, label %sort_load
sort_load:
  %sort_key_slot = getelementptr ptr, ptr %list, i64 %sort_index
  %sort_key = load ptr, ptr %sort_key_slot, align 8
  br label %sort_inner
sort_inner:
  %sort_position = phi i64 [ %sort_index, %sort_load ], [ %sort_previous, %sort_shift ]
  %at_start = icmp eq i64 %sort_position, 0
  br i1 %at_start, label %sort_store, label %sort_compare
sort_compare:
  %sort_previous = sub i64 %sort_position, 1
  %sort_previous_slot = getelementptr ptr, ptr %list, i64 %sort_previous
  %sort_previous_value = load ptr, ptr %sort_previous_slot, align 8
  %sort_order = call i32 @CompareStringOrdinal(ptr %sort_key, i32 -1, ptr %sort_previous_value, i32 -1, i32 1)
  %sort_before = icmp eq i32 %sort_order, 1
  br i1 %sort_before, label %sort_shift, label %sort_store
sort_shift:
  %sort_shift_destination = getelementptr ptr, ptr %list, i64 %sort_position
  store ptr %sort_previous_value, ptr %sort_shift_destination, align 8
  br label %sort_inner
sort_store:
  %sort_destination = getelementptr ptr, ptr %list, i64 %sort_position
  store ptr %sort_key, ptr %sort_destination, align 8
  %sort_next = add i64 %sort_index, 1
  br label %sort_outer
measure_block:
  %measure_index = phi i64 [ 0, %sort_outer ], [ %measure_next, %measure_more ]
  %measure_chars = phi i64 [ 0, %sort_outer ], [ %measure_total, %measure_more ]
  %measure_done = icmp eq i64 %measure_index, %output_count
  br i1 %measure_done, label %allocate_block, label %measure_more
measure_more:
  %measure_slot = getelementptr ptr, ptr %list, i64 %measure_index
  %measure_entry = load ptr, ptr %measure_slot, align 8
  %measure_length = call i64 @sollang_windows_wide_length(ptr %measure_entry)
  %measure_with_null = add i64 %measure_length, 1
  %measure_total = add i64 %measure_chars, %measure_with_null
  %measure_next = add i64 %measure_index, 1
  br label %measure_block
allocate_block:
  %empty_block = icmp eq i64 %output_count, 0
  %nonempty_chars = add i64 %measure_chars, 1
  %block_chars = select i1 %empty_block, i64 2, i64 %nonempty_chars
  %block_bytes = mul i64 %block_chars, 2
  %block = call ptr @sollang_alloc(i64 %block_bytes)
  %block_ok = icmp ne ptr %block, null
  br i1 %block_ok, label %copy_block, label %build_failure_with_list
copy_block:
  %block_index = phi i64 [ 0, %allocate_block ], [ %block_next, %block_more ]
  %block_offset = phi i64 [ 0, %allocate_block ], [ %block_offset_next, %block_more ]
  %block_done = icmp eq i64 %block_index, %output_count
  br i1 %block_done, label %terminate_block, label %block_more
block_more:
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
terminate_block:
  %final_null = getelementptr i16, ptr %block, i64 %block_offset
  store i16 0, ptr %final_null, align 2
  %empty_second = getelementptr i16, ptr %block, i64 1
  br i1 %empty_block, label %terminate_empty, label %finish
terminate_empty:
  store i16 0, ptr %empty_second, align 2
  br label %finish
finish:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %change_count, ptr %selected_parent)
  %ok0 = insertvalue %sollang.process_environment_result poison, ptr %block, 0
  %ok1 = insertvalue %sollang.process_environment_result %ok0, i64 0, 1
  %ok2 = insertvalue %sollang.process_environment_result %ok1, i64 -1, 2
  %ok3 = insertvalue %sollang.process_environment_result %ok2, i1 true, 3
  ret %sollang.process_environment_result %ok3
build_failure_with_list:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr %list, i64 %change_count, ptr %selected_parent)
  br label %failure
build_failure_with_parent:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr null, i64 %change_count, ptr %selected_parent)
  br label %failure
build_failure:
  call void @sollang_windows_dispose_environment_build(ptr %entries, ptr %name_lengths, ptr null, i64 %change_count, ptr null)
  br label %failure
free_entries_failure:
  call void @sollang_free(ptr %entries)
  br label %failure
failure:
  ret %sollang.process_environment_result zeroinitializer
}

define internal ptr @sollang_inherit_windows_handle(ptr %source) #0 {
entry:
  %process = call ptr @GetCurrentProcess()
  %target_slot = alloca ptr, align 8
  %duplicated = call i32 @DuplicateHandle(ptr %process, ptr %source, ptr %process, ptr %target_slot, i32 0, i32 1, i32 2)
  %ok = icmp ne i32 %duplicated, 0
  br i1 %ok, label %success, label %fail
success:
  %target = load ptr, ptr %target_slot, align 8
  ret ptr %target
fail:
  ret ptr null
}

define internal i64 @sollang_spawn_windows(ptr %program, ptr %argv, i64 %count, ptr %working_directory, ptr %environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override) #0 {
entry:
  %command = call ptr @sollang_join_windows_args(ptr %argv, i64 %count)
  %command_ok = icmp ne ptr %command, null
  br i1 %command_ok, label %handles, label %fail

handles:
  %has_stdin_override = icmp ne ptr %stdin_override, null
  %stdin_default = call ptr @GetStdHandle(i32 -10)
  %stdin_source = select i1 %has_stdin_override, ptr %stdin_override, ptr %stdin_default
  %has_stdout_override = icmp ne ptr %stdout_override, null
  %stdout_default = call ptr @GetStdHandle(i32 -11)
  %stdout_source = select i1 %has_stdout_override, ptr %stdout_override, ptr %stdout_default
  %has_stderr_override = icmp ne ptr %stderr_override, null
  %stderr_default = call ptr @GetStdHandle(i32 -12)
  %stderr_source = select i1 %has_stderr_override, ptr %stderr_override, ptr %stderr_default
  %stdin_handle = call ptr @sollang_inherit_windows_handle(ptr %stdin_source)
  %stdout_handle = call ptr @sollang_inherit_windows_handle(ptr %stdout_source)
  %stderr_handle = call ptr @sollang_inherit_windows_handle(ptr %stderr_source)
  %stdin_ok = icmp ne ptr %stdin_handle, null
  %stdout_ok = icmp ne ptr %stdout_handle, null
  %stderr_ok = icmp ne ptr %stderr_handle, null
  %io_ok0 = and i1 %stdin_ok, %stdout_ok
  %io_ok = and i1 %io_ok0, %stderr_ok
  br i1 %io_ok, label %create, label %close_handles_fail

create:
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

spawned:
  %process_handle = load ptr, ptr %process_info, align 8
  %thread_ptr = getelementptr i8, ptr %process_info, i64 8
  %thread_handle = load ptr, ptr %thread_ptr, align 8
  %closed_thread = call i32 @CloseHandle(ptr %thread_handle)
  %closed_stdin = call i32 @CloseHandle(ptr %stdin_handle)
  %closed_stdout = call i32 @CloseHandle(ptr %stdout_handle)
  %closed_stderr = call i32 @CloseHandle(ptr %stderr_handle)
  call void @sollang_free(ptr %command)
  %process_token = ptrtoint ptr %process_handle to i64
  ret i64 %process_token

close_handles_fail:
  br i1 %stdin_ok, label %close_stdin_fail, label %close_stdout_fail
close_stdin_fail:
  %closed_stdin_fail = call i32 @CloseHandle(ptr %stdin_handle)
  br label %close_stdout_fail
close_stdout_fail:
  br i1 %stdout_ok, label %close_stdout_present, label %close_stderr_fail
close_stdout_present:
  %closed_stdout_fail = call i32 @CloseHandle(ptr %stdout_handle)
  br label %close_stderr_fail
close_stderr_fail:
  br i1 %stderr_ok, label %close_stderr_present, label %free_fail
close_stderr_present:
  %closed_stderr_fail = call i32 @CloseHandle(ptr %stderr_handle)
  br label %free_fail
free_fail:
  call void @sollang_free(ptr %command)
  br label %fail_return

fail:
  br label %fail_return
fail_return:
  ret i64 -1
}

define internal %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override) #0 {
entry:
  %has_program = icmp ugt i64 %count, 0
  br i1 %has_program, label %allocate, label %spawn_error

allocate:
  %program_slot = alloca ptr, align 8
  store ptr null, ptr %program_slot, align 8
  %slots = add i64 %count, 1
  %argv_bytes = mul i64 %slots, 8
  %wide_argv = call ptr @sollang_alloc(i64 %argv_bytes)
  %argv_ok = icmp ne ptr %wide_argv, null
  br i1 %argv_ok, label %convert_loop, label %spawn_error

convert_loop:
  %i = phi i64 [ 0, %allocate ], [ %next, %store_quoted ]
  %convert_done = icmp eq i64 %i, %count
  br i1 %convert_done, label %terminate, label %convert_size

convert_size:
  %record = getelementptr %sollang.text, ptr %records, i64 %i
  %src_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  %src = load ptr, ptr %src_slot, align 8
  %len_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 1
  %len64 = load i64, ptr %len_slot, align 8
  %len_fits = icmp ule i64 %len64, 2147483647
  br i1 %len_fits, label %convert_measure, label %convert_fail

convert_measure:
  %len = trunc i64 %len64 to i32
  %chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %src, i32 %len, ptr null, i32 0)
  %chars_valid = icmp sgt i32 %chars, 0
  %empty = icmp eq i32 %len, 0
  %valid_or_empty = or i1 %chars_valid, %empty
  br i1 %valid_or_empty, label %convert_alloc, label %convert_fail

convert_alloc:
  %with_null = add i32 %chars, 1
  %with_null64 = zext i32 %with_null to i64
  %bytes = mul i64 %with_null64, 2
  %wide = call ptr @sollang_alloc(i64 %bytes)
  %wide_ok = icmp ne ptr %wide, null
  br i1 %wide_ok, label %convert_value, label %convert_fail

convert_value:
  %written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %src, i32 %len, ptr %wide, i32 %chars)
  %converted = icmp eq i32 %written, %chars
  br i1 %converted, label %convert_store, label %free_current

free_current:
  call void @sollang_free(ptr %wide)
  br label %convert_fail

convert_store:
  %wide_end = getelementptr i16, ptr %wide, i32 %chars
  store i16 0, ptr %wide_end, align 2
  %quoted = call ptr @sollang_quote_windows_arg(ptr %wide, i32 %chars)
  %quoted_ok = icmp ne ptr %quoted, null
  br i1 %quoted_ok, label %preserve_program, label %free_current

preserve_program:
  %is_program = icmp eq i64 %i, 0
  br i1 %is_program, label %store_program, label %free_unquoted

store_program:
  store ptr %wide, ptr %program_slot, align 8
  br label %store_quoted

free_unquoted:
  call void @sollang_free(ptr %wide)
  br label %store_quoted

store_quoted:
  %argv_slot = getelementptr ptr, ptr %wide_argv, i64 %i
  store ptr %quoted, ptr %argv_slot, align 8
  %next = add i64 %i, 1
  br label %convert_loop

convert_fail:
  br label %cleanup_failure

cleanup_failure:
  %failure_j = phi i64 [ %i, %convert_fail ], [ %count, %working_directory_convert ], [ %failure_prev, %cleanup_failure_item ]
  %failure_done = icmp eq i64 %failure_j, 0
  br i1 %failure_done, label %free_argv_error, label %cleanup_failure_item

cleanup_failure_item:
  %failure_prev = sub i64 %failure_j, 1
  %failure_slot = getelementptr ptr, ptr %wide_argv, i64 %failure_prev
  %failure_arg = load ptr, ptr %failure_slot, align 8
  call void @sollang_free(ptr %failure_arg)
  br label %cleanup_failure

free_argv_error:
  %failed_program = load ptr, ptr %program_slot, align 8
  call void @sollang_free(ptr %failed_program)
  call void @sollang_free(ptr %wide_argv)
  br label %spawn_error

terminate:
  %null_slot = getelementptr ptr, ptr %wide_argv, i64 %count
  store ptr null, ptr %null_slot, align 8
  %program = load ptr, ptr %program_slot, align 8
  br i1 %has_working_directory, label %working_directory_convert, label %spawn

working_directory_convert:
  %working_directory_wide = call ptr @sollang_process_windows_text(ptr %working_directory_data, i64 %working_directory_length)
  %working_directory_ok = icmp ne ptr %working_directory_wide, null
  br i1 %working_directory_ok, label %working_directory_ready, label %cleanup_failure

working_directory_ready:
  br label %spawn

spawn:
  %working_directory = phi ptr [ null, %terminate ], [ %working_directory_wide, %working_directory_ready ]
  %environment_result = call %sollang.process_environment_result @sollang_windows_build_environment(ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  %environment = extractvalue %sollang.process_environment_result %environment_result, 0
  %environment_ok = extractvalue %sollang.process_environment_result %environment_result, 3
  br i1 %environment_ok, label %environment_ready, label %environment_failure

environment_ready:
  %spawned_result = call i64 @sollang_spawn_windows(ptr %program, ptr %wide_argv, i64 %count, ptr %working_directory, ptr %environment, ptr %stdin_override, ptr %stdout_override, ptr %stderr_override)
  call void @sollang_free(ptr %environment)
  br label %cleanup_begin

environment_failure:
  br label %cleanup_begin

cleanup_begin:
  %spawn_result = phi i64 [ %spawned_result, %environment_ready ], [ -1, %environment_failure ]
  br label %cleanup

cleanup:
  %j = phi i64 [ %count, %cleanup_begin ], [ %prev, %cleanup_item ]
  %cleanup_done = icmp eq i64 %j, 0
  br i1 %cleanup_done, label %free_argv, label %cleanup_item

cleanup_item:
  %prev = sub i64 %j, 1
  %old_slot = getelementptr ptr, ptr %wide_argv, i64 %prev
  %old_arg = load ptr, ptr %old_slot, align 8
  call void @sollang_free(ptr %old_arg)
  br label %cleanup

free_argv:
  %saved_program = load ptr, ptr %program_slot, align 8
  call void @sollang_free(ptr %saved_program)
  call void @sollang_free(ptr %wide_argv)
  call void @sollang_free(ptr %working_directory)
  %spawn_ok = icmp ne i64 %spawn_result, -1
  br i1 %spawn_ok, label %read_process_id, label %spawn_error

read_process_id:
  %spawn_handle = inttoptr i64 %spawn_result to ptr
  %process_id32 = call i32 @GetProcessId(ptr %spawn_handle)
  %process_id_ok = icmp ne i32 %process_id32, 0
  br i1 %process_id_ok, label %success, label %process_id_error

process_id_error:
  %terminated_id_error = call i32 @TerminateProcess(ptr %spawn_handle, i32 1)
  %reaped_id_error = call i32 @WaitForSingleObject(ptr %spawn_handle, i32 -1)
  %closed_id_error = call i32 @CloseHandle(ptr %spawn_handle)
  br label %spawn_error

success:
  %process_id = zext i32 %process_id32 to i64
  %ok0 = insertvalue %sollang.process_spawn_result poison, i64 %spawn_result, 0
  %ok1 = insertvalue %sollang.process_spawn_result %ok0, i64 %process_id, 1
  %ok2 = insertvalue %sollang.process_spawn_result %ok1, i32 0, 2
  ret %sollang.process_spawn_result %ok2

spawn_error:
  %error0 = insertvalue %sollang.process_spawn_result poison, i64 0, 0
  %error1 = insertvalue %sollang.process_spawn_result %error0, i64 0, 1
  %error2 = insertvalue %sollang.process_spawn_result %error1, i32 1, 2
  ret %sollang.process_spawn_result %error2
}

define internal %sollang.process_spawn_result @sollang_spawn_process_with_stdout(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdout_override) #0 {
entry:
  %result = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr null, ptr %stdout_override, ptr null)
  ret %sollang.process_spawn_result %result
}

@sollang_process_null_windows = private unnamed_addr constant [4 x i8] c"NUL\00"

define internal ptr @sollang_process_open_windows_stdio(i32 %mode, ptr %path, i64 %path_length, i1 %input) #0 {
entry:
  %inherits = icmp eq i32 %mode, 0
  br i1 %inherits, label %inherit, label %select_file

select_file:
  %is_file = icmp eq i32 %mode, 1
  br i1 %is_file, label %copy_path, label %select_null

select_null:
  %is_null = icmp eq i32 %mode, 2
  br i1 %is_null, label %open_null, label %failure

copy_path:
  %path_copy = call ptr @sollang_process_windows_path(ptr %path, i64 %path_length)
  %path_ok = icmp ne ptr %path_copy, null
  br i1 %path_ok, label %open, label %failure

open:
  %access = select i1 %input, i32 -2147483648, i32 1073741824
  %creation = select i1 %input, i32 3, i32 2
  %handle = call ptr @CreateFileW(ptr %path_copy, i32 %access, i32 1, ptr null, i32 %creation, i32 128, ptr null)
  call void @sollang_free(ptr %path_copy)
  ret ptr %handle

open_null:
  %null_access = select i1 %input, i32 -2147483648, i32 1073741824
  %null_creation = select i1 %input, i32 3, i32 2
  %null_handle = call ptr @CreateFileA(ptr @sollang_process_null_windows, i32 %null_access, i32 3, ptr null, i32 %null_creation, i32 128, ptr null)
  ret ptr %null_handle

inherit:
  ret ptr null

failure:
  ret ptr inttoptr (i64 -1 to ptr)
}

define internal void @sollang_process_close_windows_stdio(ptr %handle) #0 {
entry:
  %value = ptrtoint ptr %handle to i64
  %present = icmp ne i64 %value, 0
  %valid = icmp ne i64 %value, -1
  %should_close = and i1 %present, %valid
  br i1 %should_close, label %close, label %done

close:
  %closed = call i32 @CloseHandle(ptr %handle)
  br label %done

done:
  ret void
}

define internal %sollang.process_spawn_result @sollang_spawn_process_configured(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length) #0 {
entry:
  %stdin_inherits = icmp eq i32 %stdin_mode, 0
  %stdout_inherits = icmp eq i32 %stdout_mode, 0
  %stderr_inherits = icmp eq i32 %stderr_mode, 0
  %output_inherits = and i1 %stdout_inherits, %stderr_inherits
  %all_inherit = and i1 %stdin_inherits, %output_inherits
  br i1 %all_inherit, label %inherit, label %open

inherit:
  %inherited = call %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  ret %sollang.process_spawn_result %inherited

open:
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

spawn:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %stdin_handle, ptr %stdout_handle, ptr %stderr_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdin_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdout_handle)
  call void @sollang_process_close_windows_stdio(ptr %stderr_handle)
  ret %sollang.process_spawn_result %spawned

open_failure:
  call void @sollang_process_close_windows_stdio(ptr %stdin_handle)
  call void @sollang_process_close_windows_stdio(ptr %stdout_handle)
  call void @sollang_process_close_windows_stdio(ptr %stderr_handle)
  ret %sollang.process_spawn_result { i64 0, i64 0, i32 1 }
}

define internal %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment) #0 {
entry:
  %result = call %sollang.process_spawn_result @sollang_spawn_process_with_stdio(ptr %records, i64 %count, ptr %working_directory_data, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr null, ptr null, ptr null)
  ret %sollang.process_spawn_result %result
}

define internal %sollang.process_result @sollang_wait_process(i64 %token) #0 {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %wait, label %wait_error

wait:
  %process_handle = inttoptr i64 %token to ptr
  %waited = call i32 @WaitForSingleObject(ptr %process_handle, i32 -1)
  %wait_ok = icmp eq i32 %waited, 0
  br i1 %wait_ok, label %read_exit, label %terminate_error

read_exit:
  %exit_slot = alloca i32, align 4
  %exit_read = call i32 @GetExitCodeProcess(ptr %process_handle, ptr %exit_slot)
  %exit_ok = icmp ne i32 %exit_read, 0
  br i1 %exit_ok, label %success, label %terminate_error

success:
  %exit_code = load i32, ptr %exit_slot, align 4
  %closed_success = call i32 @CloseHandle(ptr %process_handle)
  %ok0 = insertvalue %sollang.process_result poison, i32 %exit_code, 0
  %ok1 = insertvalue %sollang.process_result %ok0, i32 0, 1
  ret %sollang.process_result %ok1

terminate_error:
  %terminated = call i32 @TerminateProcess(ptr %process_handle, i32 1)
  %reaped = call i32 @WaitForSingleObject(ptr %process_handle, i32 -1)
  %closed_error = call i32 @CloseHandle(ptr %process_handle)
  br label %wait_error

wait_error:
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 2, 1
  ret %sollang.process_result %error1
}

define internal %sollang.process_poll_result @sollang_poll_process(i64 %token) #0 {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %poll, label %poll_error

poll:
  %process_handle = inttoptr i64 %token to ptr
  %waited = call i32 @WaitForSingleObject(ptr %process_handle, i32 0)
  %exited = icmp eq i32 %waited, 0
  %running = icmp eq i32 %waited, 258
  br i1 %exited, label %read_exit, label %classify_pending

classify_pending:
  br i1 %running, label %poll_running, label %poll_error

read_exit:
  %exit_slot = alloca i32, align 4
  %exit_read = call i32 @GetExitCodeProcess(ptr %process_handle, ptr %exit_slot)
  %exit_ok = icmp ne i32 %exit_read, 0
  br i1 %exit_ok, label %close_exit, label %poll_error

close_exit:
  %exit_code = load i32, ptr %exit_slot, align 4
  %closed = call i32 @CloseHandle(ptr %process_handle)
  %close_ok = icmp ne i32 %closed, 0
  br i1 %close_ok, label %poll_exited, label %poll_error

poll_exited:
  %exited0 = insertvalue %sollang.process_poll_result poison, i32 %exit_code, 0
  %exited1 = insertvalue %sollang.process_poll_result %exited0, i32 1, 1
  ret %sollang.process_poll_result %exited1

poll_running:
  ret %sollang.process_poll_result { i32 0, i32 0 }

poll_error:
  ret %sollang.process_poll_result { i32 0, i32 2 }
}

define internal i1 @sollang_kill_process(i64 %token) #0 {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %terminate, label %failure

terminate:
  %process_handle = inttoptr i64 %token to ptr
  %terminated = call i32 @TerminateProcess(ptr %process_handle, i32 1)
  %succeeded = icmp ne i32 %terminated, 0
  ret i1 %succeeded

failure:
  ret i1 false
}

define internal void @sollang_drop_process_child(i64 %token) #0 {
entry:
  %valid = icmp ne i64 %token, 0
  br i1 %valid, label %dispose, label %done

dispose:
  %process_handle = inttoptr i64 %token to ptr
  %terminated = call i32 @TerminateProcess(ptr %process_handle, i32 1)
  %reaped = call i32 @WaitForSingleObject(ptr %process_handle, i32 -1)
  %closed = call i32 @CloseHandle(ptr %process_handle)
  br label %done

done:
  ret void
}

define internal %sollang.process_result @sollang_run_process(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment) #0 {
entry:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %error = extractvalue %sollang.process_spawn_result %spawned, 2
  %spawn_ok = icmp eq i32 %error, 0
  br i1 %spawn_ok, label %wait, label %spawn_error

wait:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result

spawn_error:
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 1, 1
  ret %sollang.process_result %error1
}

define internal %sollang.process_result @sollang_run_process_configured(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length) #0 {
entry:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_configured(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, i32 %stdin_mode, ptr %stdin_path, i64 %stdin_path_length, i32 %stdout_mode, ptr %stdout_path, i64 %stdout_path_length, i32 %stderr_mode, ptr %stderr_path, i64 %stderr_path_length)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %error = extractvalue %sollang.process_spawn_result %spawned, 2
  %ok = icmp eq i32 %error, 0
  br i1 %ok, label %wait, label %spawn_error

wait:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result

spawn_error:
  ret %sollang.process_result { i32 0, i32 1 }
}

define internal %sollang.process_result @sollang_run_process_to_file(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %path, i64 %path_len) #0 {
entry:
  %wide_path = call ptr @sollang_process_windows_path(ptr %path, i64 %path_len)
  %path_valid = icmp ne ptr %wide_path, null
  br i1 %path_valid, label %open, label %error

open:
  %handle = call ptr @CreateFileW(ptr %wide_path, i32 1073741824, i32 1, ptr null, i32 2, i32 128, ptr null)
  call void @sollang_free(ptr %wide_path)
  %handle_value = ptrtoint ptr %handle to i64
  %open_ok = icmp ne i64 %handle_value, -1
  br i1 %open_ok, label %run, label %error

run:
  %spawned = call %sollang.process_spawn_result @sollang_spawn_process_with_stdout(ptr %records, i64 %count, ptr %working_directory, i64 %working_directory_length, i1 %has_working_directory, ptr %environment_changes, i64 %environment_change_count, i1 %inherits_environment, ptr %handle)
  %closed = call i32 @CloseHandle(ptr %handle)
  %token = extractvalue %sollang.process_spawn_result %spawned, 0
  %spawn_error = extractvalue %sollang.process_spawn_result %spawned, 2
  %spawn_ok = icmp eq i32 %spawn_error, 0
  br i1 %spawn_ok, label %wait, label %error

wait:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  ret %sollang.process_result %result

error:
  %error0 = insertvalue %sollang.process_result poison, i32 0, 0
  %error1 = insertvalue %sollang.process_result %error0, i32 1, 1
  ret %sollang.process_result %error1
}

define internal void @sollang_dispose_arguments() #0 {
entry:
  %count = load i64, ptr @sollang_argument_count_value, align 8
  %records = load ptr, ptr @sollang_argument_records, align 8
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %next, %free_item ]
  %done = icmp eq i64 %i, %count
  br i1 %done, label %finish, label %free_item

free_item:
  %record = getelementptr %sollang.text, ptr %records, i64 %i
  %ptr_slot = getelementptr inbounds %sollang.text, ptr %record, i32 0, i32 0
  %ptr = load ptr, ptr %ptr_slot, align 8
  call void @sollang_free(ptr %ptr)
  %next = add i64 %i, 1
  br label %loop

finish:
  call void @sollang_free(ptr %records)
  ret void
}

define internal i1 @sollang_track_environment_allocation(ptr %allocation) #0 {
entry:
  %node = call ptr @sollang_alloc(i64 16)
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

define internal %sollang.environment_result @sollang_environment(ptr %name, i64 %name_len) #0 {
entry:
  %empty = icmp eq i64 %name_len, 0
  br i1 %empty, label %missing, label %check_length

check_length:
  %name_fits_i32 = icmp ule i64 %name_len, 2147483647
  br i1 %name_fits_i32, label %validate, label %error

validate:
  %vi = phi i64 [ 0, %check_length ], [ %vnext, %valid_byte ]
  %validated = icmp eq i64 %vi, %name_len
  br i1 %validated, label %key_size, label %check_byte

check_byte:
  %name_byte_ptr = getelementptr i8, ptr %name, i64 %vi
  %name_byte = load i8, ptr %name_byte_ptr, align 1
  %name_byte_valid = icmp ne i8 %name_byte, 0
  br i1 %name_byte_valid, label %valid_byte, label %error

valid_byte:
  %vnext = add i64 %vi, 1
  br label %validate

key_size:
  %name_len32 = trunc i64 %name_len to i32
  %wide_chars = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %name, i32 %name_len32, ptr null, i32 0)
  %wide_valid = icmp sgt i32 %wide_chars, 0
  br i1 %wide_valid, label %key_alloc, label %error

key_alloc:
  %wide_chars_plus_null = add i32 %wide_chars, 1
  %wide_chars64 = zext i32 %wide_chars_plus_null to i64
  %key_bytes = mul i64 %wide_chars64, 2
  %wide_key = call ptr @sollang_alloc(i64 %key_bytes)
  %key_ok = icmp ne ptr %wide_key, null
  br i1 %key_ok, label %key_convert, label %error

key_convert:
  %key_written = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %name, i32 %name_len32, ptr %wide_key, i32 %wide_chars)
  %key_converted = icmp eq i32 %key_written, %wide_chars
  br i1 %key_converted, label %key_terminate, label %free_key_error

key_terminate:
  %key_end = getelementptr i16, ptr %wide_key, i32 %wide_chars
  store i16 0, ptr %key_end, align 2
  call void @SetLastError(i32 0)
  %required = call i32 @GetEnvironmentVariableW(ptr %wide_key, ptr null, i32 0)
  %last_error = call i32 @GetLastError()
  %has_size = icmp ne i32 %required, 0
  br i1 %has_size, label %value_alloc, label %zero_result

zero_result:
  call void @sollang_free(ptr %wide_key)
  br label %classify_zero

classify_zero:
  %zero_error = phi i32 [ %last_error, %zero_result ], [ %value_error, %free_wide_empty ]
  %not_found = icmp eq i32 %zero_error, 203
  br i1 %not_found, label %missing, label %check_empty_value

check_empty_value:
  %empty_succeeded = icmp eq i32 %zero_error, 0
  br i1 %empty_succeeded, label %empty_present, label %error

empty_present:
  %empty_ptr = getelementptr inbounds [1 x i8], ptr @sollang_environment_empty, i64 0, i64 0
  %e0 = insertvalue %sollang.environment_result zeroinitializer, ptr %empty_ptr, 0
  %e1 = insertvalue %sollang.environment_result %e0, i1 true, 2
  %e2 = insertvalue %sollang.environment_result %e1, i1 true, 3
  ret %sollang.environment_result %e2

value_alloc:
  %required64 = zext i32 %required to i64
  %wide_bytes = mul i64 %required64, 2
  %wide_value = call ptr @sollang_alloc(i64 %wide_bytes)
  %wide_value_ok = icmp ne ptr %wide_value, null
  br i1 %wide_value_ok, label %value_read, label %free_key_error

value_read:
  call void @SetLastError(i32 0)
  %value_chars = call i32 @GetEnvironmentVariableW(ptr %wide_key, ptr %wide_value, i32 %required)
  %value_error = call i32 @GetLastError()
  call void @sollang_free(ptr %wide_key)
  %value_empty = icmp eq i32 %value_chars, 0
  br i1 %value_empty, label %free_wide_empty, label %value_read_check

free_wide_empty:
  call void @sollang_free(ptr %wide_value)
  br label %classify_zero

value_read_check:
  %value_read_ok = icmp ult i32 %value_chars, %required
  br i1 %value_read_ok, label %utf8_size, label %free_wide_error

utf8_size:
  %utf8_bytes32 = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide_value, i32 %value_chars, ptr null, i32 0, ptr null, ptr null)
  %utf8_size_ok = icmp sgt i32 %utf8_bytes32, 0
  br i1 %utf8_size_ok, label %utf8_alloc, label %free_wide_error

utf8_alloc:
  %utf8_bytes = zext i32 %utf8_bytes32 to i64
  %utf8 = call ptr @sollang_alloc(i64 %utf8_bytes)
  %utf8_ok = icmp ne ptr %utf8, null
  br i1 %utf8_ok, label %utf8_convert, label %free_wide_error

utf8_convert:
  %utf8_written = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide_value, i32 %value_chars, ptr %utf8, i32 %utf8_bytes32, ptr null, ptr null)
  call void @sollang_free(ptr %wide_value)
  %utf8_converted = icmp eq i32 %utf8_written, %utf8_bytes32
  br i1 %utf8_converted, label %track, label %free_utf8_error

track:
  %tracked = call i1 @sollang_track_environment_allocation(ptr %utf8)
  br i1 %tracked, label %present, label %free_utf8_error

present:
  %p0 = insertvalue %sollang.environment_result poison, ptr %utf8, 0
  %p1 = insertvalue %sollang.environment_result %p0, i64 %utf8_bytes, 1
  %p2 = insertvalue %sollang.environment_result %p1, i1 true, 2
  %p3 = insertvalue %sollang.environment_result %p2, i1 true, 3
  ret %sollang.environment_result %p3

free_utf8_error:
  call void @sollang_free(ptr %utf8)
  br label %error

free_wide_error:
  call void @sollang_free(ptr %wide_value)
  br label %error

free_key_error:
  call void @sollang_free(ptr %wide_key)
  br label %error

missing:
  %m0 = insertvalue %sollang.environment_result zeroinitializer, i1 true, 3
  ret %sollang.environment_result %m0

error:
  ret %sollang.environment_result zeroinitializer
}

define internal void @sollang_dispose_environment() #0 {
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
  call void @sollang_free(ptr %allocation)
  call void @sollang_free(ptr %node)
  br label %loop

finish:
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
  %trap_written6 = alloca i32, align 4
  %enum_init_slot7 = alloca %sollang.enum.2621, align 8
  %enum_init_slot13 = alloca %sollang.enum.2621, align 8
  %trap_written26 = alloca i32, align 4
  %enum_init_slot27 = alloca %sollang.enum.2621, align 8
  %enum_init_slot33 = alloca %sollang.enum.2621, align 8
  %trap_written46 = alloca i32, align 4
  %enum_init_slot47 = alloca %sollang.enum.2621, align 8
  %enum_init_slot53 = alloca %sollang.enum.2621, align 8
  store i1 true, ptr %ok_state, align 1
  %stdin = call ptr @GetStdHandle(i32 -10)
  %stdout = call ptr @GetStdHandle(i32 -11)
  %stdout_mode = alloca i32, align 4
  %stdout_is_console_status = call i32 @GetConsoleMode(ptr %stdout, ptr %stdout_mode)
  %stdout_is_console = icmp ne i32 %stdout_is_console_status, 0
  store i1 %stdout_is_console, ptr @sollang_stdout_line_buffered, align 1
  %environment_result0 = call %sollang.environment_result @sollang_environment(ptr @.slg.str.suffix.0, i64 18)
  %environment_ptr1 = extractvalue %sollang.environment_result %environment_result0, 0
  %environment_len2 = extractvalue %sollang.environment_result %environment_result0, 1
  %environment_found3 = extractvalue %sollang.environment_result %environment_result0, 2
  %environment_ok4 = extractvalue %sollang.environment_result %environment_result0, 3
  br i1 %environment_ok4, label %bb_environment_lookup_ok0, label %bb_environment_lookup_fail1

bb_environment_lookup_fail1:
  %trap_stderr5 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr5, ptr @.slg.str.suffix.1, i32 32, ptr %trap_written6, ptr null)
  call void @llvm.trap()
  unreachable

bb_environment_lookup_ok0:
  br i1 %environment_found3, label %bb_environment_some2, label %bb_environment_none3
bb_environment_some2:
  store %sollang.enum.2621 zeroinitializer, ptr %enum_init_slot7, align 8
  %enum_tag_addr8 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot7, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr8, align 4
  %enum_payload_addr9 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot7, i32 0, i32 1
  %text_value10 = insertvalue %sollang.text poison, ptr %environment_ptr1, 0
  %text_value11 = insertvalue %sollang.text %text_value10, i64 %environment_len2, 1
  store %sollang.text %text_value11, ptr %enum_payload_addr9, align 8
  %enum_value12 = load %sollang.enum.2621, ptr %enum_init_slot7, align 8
  br label %bb_environment_end4
bb_environment_none3:
  store %sollang.enum.2621 zeroinitializer, ptr %enum_init_slot13, align 8
  %enum_tag_addr14 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot13, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr14, align 4
  %enum_value15 = load %sollang.enum.2621, ptr %enum_init_slot13, align 8
  br label %bb_environment_end4
bb_environment_end4:
  %environment_option16 = phi %sollang.enum.2621 [ %enum_value12, %bb_environment_some2 ], [ %enum_value15, %bb_environment_none3 ]
  %text17 = call %sollang.text @sollang_fn_describe(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.enum.2621 %environment_option16)
  %text_ptr18 = extractvalue %sollang.text %text17, 0
  %text_len19 = extractvalue %sollang.text %text17, 1
  %environment_result20 = call %sollang.environment_result @sollang_environment(ptr @.slg.str.suffix.2, i64 18)
  %environment_ptr21 = extractvalue %sollang.environment_result %environment_result20, 0
  %environment_len22 = extractvalue %sollang.environment_result %environment_result20, 1
  %environment_found23 = extractvalue %sollang.environment_result %environment_result20, 2
  %environment_ok24 = extractvalue %sollang.environment_result %environment_result20, 3
  br i1 %environment_ok24, label %bb_environment_lookup_ok5, label %bb_environment_lookup_fail6

bb_environment_lookup_fail6:
  %trap_stderr25 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr25, ptr @.slg.str.suffix.3, i32 32, ptr %trap_written26, ptr null)
  call void @llvm.trap()
  unreachable

bb_environment_lookup_ok5:
  br i1 %environment_found23, label %bb_environment_some7, label %bb_environment_none8
bb_environment_some7:
  store %sollang.enum.2621 zeroinitializer, ptr %enum_init_slot27, align 8
  %enum_tag_addr28 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot27, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr28, align 4
  %enum_payload_addr29 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot27, i32 0, i32 1
  %text_value30 = insertvalue %sollang.text poison, ptr %environment_ptr21, 0
  %text_value31 = insertvalue %sollang.text %text_value30, i64 %environment_len22, 1
  store %sollang.text %text_value31, ptr %enum_payload_addr29, align 8
  %enum_value32 = load %sollang.enum.2621, ptr %enum_init_slot27, align 8
  br label %bb_environment_end9
bb_environment_none8:
  store %sollang.enum.2621 zeroinitializer, ptr %enum_init_slot33, align 8
  %enum_tag_addr34 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot33, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr34, align 4
  %enum_value35 = load %sollang.enum.2621, ptr %enum_init_slot33, align 8
  br label %bb_environment_end9
bb_environment_end9:
  %environment_option36 = phi %sollang.enum.2621 [ %enum_value32, %bb_environment_some7 ], [ %enum_value35, %bb_environment_none8 ]
  %text37 = call %sollang.text @sollang_fn_describe(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.enum.2621 %environment_option36)
  %text_ptr38 = extractvalue %sollang.text %text37, 0
  %text_len39 = extractvalue %sollang.text %text37, 1
  %environment_result40 = call %sollang.environment_result @sollang_environment(ptr @.slg.str.suffix.4, i64 20)
  %environment_ptr41 = extractvalue %sollang.environment_result %environment_result40, 0
  %environment_len42 = extractvalue %sollang.environment_result %environment_result40, 1
  %environment_found43 = extractvalue %sollang.environment_result %environment_result40, 2
  %environment_ok44 = extractvalue %sollang.environment_result %environment_result40, 3
  br i1 %environment_ok44, label %bb_environment_lookup_ok10, label %bb_environment_lookup_fail11

bb_environment_lookup_fail11:
  %trap_stderr45 = call ptr @GetStdHandle(i32 -12)
  call i32 @WriteFile(ptr %trap_stderr45, ptr @.slg.str.suffix.5, i32 33, ptr %trap_written46, ptr null)
  call void @llvm.trap()
  unreachable

bb_environment_lookup_ok10:
  br i1 %environment_found43, label %bb_environment_some12, label %bb_environment_none13
bb_environment_some12:
  store %sollang.enum.2621 zeroinitializer, ptr %enum_init_slot47, align 8
  %enum_tag_addr48 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot47, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr48, align 4
  %enum_payload_addr49 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot47, i32 0, i32 1
  %text_value50 = insertvalue %sollang.text poison, ptr %environment_ptr41, 0
  %text_value51 = insertvalue %sollang.text %text_value50, i64 %environment_len42, 1
  store %sollang.text %text_value51, ptr %enum_payload_addr49, align 8
  %enum_value52 = load %sollang.enum.2621, ptr %enum_init_slot47, align 8
  br label %bb_environment_end14
bb_environment_none13:
  store %sollang.enum.2621 zeroinitializer, ptr %enum_init_slot53, align 8
  %enum_tag_addr54 = getelementptr inbounds %sollang.enum.2621, ptr %enum_init_slot53, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr54, align 4
  %enum_value55 = load %sollang.enum.2621, ptr %enum_init_slot53, align 8
  br label %bb_environment_end14
bb_environment_end14:
  %environment_option56 = phi %sollang.enum.2621 [ %enum_value52, %bb_environment_some12 ], [ %enum_value55, %bb_environment_none13 ]
  %text57 = call %sollang.text @sollang_fn_describe(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, %sollang.enum.2621 %environment_option56)
  %text_ptr58 = extractvalue %sollang.text %text57, 0
  %text_len59 = extractvalue %sollang.text %text57, 1
  %write60 = call i32 @sollang_write(ptr %stdout, ptr %text_ptr18, i64 %text_len19, ptr %written)
  %is_ok61 = icmp ne i32 %write60, 0
  %previous_ok62 = load i1, ptr %ok_state, align 1
  %ok63 = and i1 %previous_ok62, %is_ok61
  store i1 %ok63, ptr %ok_state, align 1
  %write64 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.6, i64 1, ptr %written)
  %is_ok65 = icmp ne i32 %write64, 0
  %previous_ok66 = load i1, ptr %ok_state, align 1
  %ok67 = and i1 %previous_ok66, %is_ok65
  store i1 %ok67, ptr %ok_state, align 1
  %write68 = call i32 @sollang_write(ptr %stdout, ptr %text_ptr38, i64 %text_len39, ptr %written)
  %is_ok69 = icmp ne i32 %write68, 0
  %previous_ok70 = load i1, ptr %ok_state, align 1
  %ok71 = and i1 %previous_ok70, %is_ok69
  store i1 %ok71, ptr %ok_state, align 1
  %write72 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.7, i64 1, ptr %written)
  %is_ok73 = icmp ne i32 %write72, 0
  %previous_ok74 = load i1, ptr %ok_state, align 1
  %ok75 = and i1 %previous_ok74, %is_ok73
  store i1 %ok75, ptr %ok_state, align 1
  %write76 = call i32 @sollang_write(ptr %stdout, ptr %text_ptr58, i64 %text_len59, ptr %written)
  %is_ok77 = icmp ne i32 %write76, 0
  %previous_ok78 = load i1, ptr %ok_state, align 1
  %ok79 = and i1 %previous_ok78, %is_ok77
  store i1 %ok79, ptr %ok_state, align 1
  %write80 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.8, i64 1, ptr %written)
  %is_ok81 = icmp ne i32 %write80, 0
  %previous_ok82 = load i1, ptr %ok_state, align 1
  %ok83 = and i1 %previous_ok82, %is_ok81
  store i1 %ok83, ptr %ok_state, align 1
  call void @sollang_dispose_environment()
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %final_ok84 = load i1, ptr %ok_state, align 1
  %exit85 = select i1 %final_ok84, i32 0, i32 1
  ret i32 %exit85
}

attributes #0 = { nounwind }
