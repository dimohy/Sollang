; sollang cpu contract cpu1-d-r1-a3fe-f0
target triple = "x86_64-unknown-linux-gnu"

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
%sollang.struct.2705 = type { %sollang.event_stream, %sollang.event_stream }
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

@sollang_file_writer_fd = internal global i32 -1
@sollang_file_reader_fd = internal global i32 -1
@sollang_argument_count_value = internal global i64 0
@sollang_argument_vector = internal global ptr null
@sollang_stdout_buffer = internal global [65536 x i8] zeroinitializer, align 16
@sollang_stdout_buffer_count = internal global i64 0
@sollang_stdout_line_buffered = internal global i1 false
@sollang_random_state = internal global i64 88172645463393265
@sollang_writer_buffer = internal global [8192 x i64] zeroinitializer, align 8
@sollang_writer_buffer_count = internal global i64 0

declare i64 @write(i32, ptr, i64)
declare i64 @read(i32, ptr, i64)
declare i32 @isatty(i32)
declare i64 @pread(i32, ptr, i64, i64)
declare i64 @pwrite(i32, ptr, i64, i64)
declare i32 @open(ptr, i32, i32)
declare i32 @close(i32)
declare i32 @dup(i32)
declare i32 @fsync(i32)
declare i32 @rename(ptr, ptr)
declare i32 @unlink(ptr)
declare i64 @lseek(i32, i64, i32)
declare i32 @ftruncate(i32, i64)
declare ptr @mmap(ptr, i64, i32, i32, i32, i64)
declare i32 @munmap(ptr, i64)
declare i32 @msync(ptr, i64, i32)
declare i32 @clock_gettime(i32, ptr)
declare i32 @nanosleep(ptr, ptr)
declare ptr @getenv(ptr)
declare i32 @posix_spawnp(ptr, ptr, ptr, ptr, ptr, ptr)
declare i32 @posix_spawn_file_actions_init(ptr)
declare i32 @posix_spawn_file_actions_addchdir_np(ptr, ptr)
declare i32 @posix_spawn_file_actions_adddup2(ptr, i32, i32)
declare i32 @posix_spawn_file_actions_addclose(ptr, i32)
declare i32 @posix_spawn_file_actions_destroy(ptr)
declare i32 @waitpid(i32, ptr, i32)
declare i32 @kill(i32, i32)
declare ptr @__errno_location()
declare i32 @pthread_create(ptr, ptr, ptr, ptr)
declare i32 @pthread_join(i64, ptr)
declare i32 @eventfd(i32, i32)
declare i32 @poll(ptr, i64, i32)
declare i32 @tcgetattr(i32, ptr)
declare i32 @tcsetattr(i32, i32, ptr)
declare i32 @pthread_mutex_init(ptr, ptr)
declare i32 @pthread_mutex_destroy(ptr)
declare i32 @pthread_mutex_lock(ptr)
declare i32 @pthread_mutex_unlock(ptr)
declare i32 @pthread_cond_init(ptr, ptr)
declare i32 @pthread_cond_destroy(ptr)
declare i32 @pthread_cond_wait(ptr, ptr)
declare i32 @pthread_cond_broadcast(ptr)
@environ = external global ptr
declare ptr @malloc(i64)
declare void @free(ptr)
define internal ptr @sollang_linux_stream_join_worker(ptr %argument) #0 {
entry:
  call void @sollang_stream_join_worker_run(ptr %argument)
  ret ptr null
}

define internal i1 @sollang_stream_join_sync_init(ptr %runtime) #0 {
entry:
  %mutex = getelementptr i8, ptr %runtime, i64 112
  %mutex_result = call i32 @pthread_mutex_init(ptr %mutex, ptr null)
  %mutex_ok = icmp eq i32 %mutex_result, 0
  br i1 %mutex_ok, label %initialize_condition, label %fail

initialize_condition:
  %condition = getelementptr i8, ptr %runtime, i64 152
  %condition_result = call i32 @pthread_cond_init(ptr %condition, ptr null)
  %condition_ok = icmp eq i32 %condition_result, 0
  br i1 %condition_ok, label %ready, label %destroy_mutex

destroy_mutex:
  %destroyed = call i32 @pthread_mutex_destroy(ptr %mutex)
  br label %fail

ready:
  ret i1 true

fail:
  ret i1 false
}

define internal void @sollang_stream_join_lock(ptr %runtime) #0 {
entry:
  %mutex = getelementptr i8, ptr %runtime, i64 112
  %locked = call i32 @pthread_mutex_lock(ptr %mutex)
  ret void
}

define internal void @sollang_stream_join_unlock(ptr %runtime) #0 {
entry:
  %mutex = getelementptr i8, ptr %runtime, i64 112
  %unlocked = call i32 @pthread_mutex_unlock(ptr %mutex)
  ret void
}

define internal void @sollang_stream_join_wait(ptr %runtime) #0 {
entry:
  %mutex = getelementptr i8, ptr %runtime, i64 112
  %condition = getelementptr i8, ptr %runtime, i64 152
  %waited = call i32 @pthread_cond_wait(ptr %condition, ptr %mutex)
  ret void
}

define internal void @sollang_stream_join_wake_all(ptr %runtime) #0 {
entry:
  %condition = getelementptr i8, ptr %runtime, i64 152
  %woken = call i32 @pthread_cond_broadcast(ptr %condition)
  ret void
}

define internal void @sollang_stream_join_sync_destroy(ptr %runtime) #0 {
entry:
  %condition = getelementptr i8, ptr %runtime, i64 152
  %condition_destroyed = call i32 @pthread_cond_destroy(ptr %condition)
  %mutex = getelementptr i8, ptr %runtime, i64 112
  %mutex_destroyed = call i32 @pthread_mutex_destroy(ptr %mutex)
  ret void
}

define internal i1 @sollang_stream_join_thread_start(ptr %thread_slot, ptr %argument) #0 {
entry:
  %created = call i32 @pthread_create(ptr %thread_slot, ptr null, ptr @sollang_linux_stream_join_worker, ptr %argument)
  %ok = icmp eq i32 %created, 0
  ret i1 %ok
}

define internal void @sollang_stream_join_thread_join(ptr %thread_slot) #0 {
entry:
  %thread = load i64, ptr %thread_slot, align 8
  %joined = call i32 @pthread_join(i64 %thread, ptr null)
  ret void
}

define internal void @sollang_stream_join_enqueue_locked(ptr %runtime, i32 %event) #0 {
entry:
  %count = load i32, ptr %runtime, align 4
  %tail_address = getelementptr i8, ptr %runtime, i64 12
  %tail = load i32, ptr %tail_address, align 4
  %queue_address = getelementptr i8, ptr %runtime, i64 72
  %queue = load ptr, ptr %queue_address, align 8
  %event_address = getelementptr i32, ptr %queue, i32 %tail
  store i32 %event, ptr %event_address, align 4
  %next_tail_unwrapped = add i32 %tail, 1
  %next_tail = urem i32 %next_tail_unwrapped, %count
  store i32 %next_tail, ptr %tail_address, align 4
  %queued_address = getelementptr i8, ptr %runtime, i64 16
  %queued = load i32, ptr %queued_address, align 4
  %queue_full = icmp eq i32 %queued, %count
  br i1 %queue_full, label %invalid, label %append

append:
  %next_queued = add i32 %queued, 1
  store i32 %next_queued, ptr %queued_address, align 4
  ret void

invalid:
  call void @llvm.trap()
  unreachable
}

define internal void @sollang_stream_join_worker_exit_locked(ptr %runtime) #0 {
entry:
  %exited_address = getelementptr i8, ptr %runtime, i64 104
  %exited = load i32, ptr %exited_address, align 4
  %next_exited = add i32 %exited, 1
  store i32 %next_exited, ptr %exited_address, align 4
  call void @sollang_stream_join_wake_all(ptr %runtime)
  call void @sollang_stream_join_unlock(ptr %runtime)
  ret void
}

define internal void @sollang_stream_join_worker_exit(ptr %runtime) #0 {
entry:
  call void @sollang_stream_join_lock(ptr %runtime)
  call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
  ret void
}

define internal void @sollang_stream_join_worker_run(ptr %argument) #0 {
entry:
  %runtime = load ptr, ptr %argument, align 8
  %index_address = getelementptr i8, ptr %argument, i64 8
  %index = load i32, ptr %index_address, align 4
  %item_size_address = getelementptr i8, ptr %runtime, i64 24
  %item_size = load i64, ptr %item_size_address, align 8
  %slots_address = getelementptr i8, ptr %runtime, i64 56
  %slots = load ptr, ptr %slots_address, align 8
  %index64 = zext i32 %index to i64
  %slot_offset = mul i64 %index64, %item_size
  %slot = getelementptr i8, ptr %slots, i64 %slot_offset
  %pull_address = getelementptr i8, ptr %runtime, i64 32
  %pull = load ptr, ptr %pull_address, align 8
  %drop_address = getelementptr i8, ptr %runtime, i64 40
  %drop = load ptr, ptr %drop_address, align 8
  %owner_address = getelementptr i8, ptr %runtime, i64 48
  %owner = load ptr, ptr %owner_address, align 8
  %full_array_address = getelementptr i8, ptr %runtime, i64 64
  %full_array = load ptr, ptr %full_array_address, align 8
  %full_address = getelementptr i8, ptr %full_array, i32 %index
  br label %check

check:
  call void @sollang_stream_join_lock(ptr %runtime)
  %cancel_address = getelementptr i8, ptr %runtime, i64 20
  %cancelled = load i32, ptr %cancel_address, align 4
  %active = icmp eq i32 %cancelled, 0
  br i1 %active, label %register_pull, label %cancelled_before_pull

register_pull:
  %pulling_address = getelementptr i8, ptr %runtime, i64 100
  %pulling = load i32, ptr %pulling_address, align 4
  %next_pulling = add i32 %pulling, 1
  store i32 %next_pulling, ptr %pulling_address, align 4
  call void @sollang_stream_join_unlock(ptr %runtime)
  br label %pull_value

cancelled_before_pull:
  call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
  ret void

pull_value:
  %has_value = call i1 %pull(ptr %owner, i32 %index, ptr %slot)
  call void @sollang_stream_join_lock(ptr %runtime)
  %pulling_after = load i32, ptr %pulling_address, align 4
  %next_pulling_after = sub i32 %pulling_after, 1
  store i32 %next_pulling_after, ptr %pulling_address, align 4
  call void @sollang_stream_join_wake_all(ptr %runtime)
  %cancelled_after_pull = load i32, ptr %cancel_address, align 4
  %cancelled_now = icmp ne i32 %cancelled_after_pull, 0
  br i1 %has_value, label %publish_or_drop, label %complete_or_cancel

publish_or_drop:
  br i1 %cancelled_now, label %drop_unpublished, label %publish

drop_unpublished:
  call void @sollang_stream_join_unlock(ptr %runtime)
  call void %drop(ptr %owner, i32 %index, ptr %slot)
  call void @sollang_stream_join_worker_exit(ptr %runtime)
  ret void

publish:
  store i8 1, ptr %full_address, align 1
  call void @sollang_stream_join_enqueue_locked(ptr %runtime, i32 %index)
  call void @sollang_stream_join_wake_all(ptr %runtime)
  br label %backpressure

backpressure:
  %full = load i8, ptr %full_address, align 1
  %still_full = icmp ne i8 %full, 0
  %cancelled_while_full = load i32, ptr %cancel_address, align 4
  %not_cancelled = icmp eq i32 %cancelled_while_full, 0
  %must_wait = and i1 %still_full, %not_cancelled
  br i1 %must_wait, label %wait_release, label %released

wait_release:
  call void @sollang_stream_join_wait(ptr %runtime)
  br label %backpressure

released:
  call void @sollang_stream_join_unlock(ptr %runtime)
  br i1 %not_cancelled, label %check, label %cancelled_after_release

cancelled_after_release:
  call void @sollang_stream_join_worker_exit(ptr %runtime)
  ret void

complete_or_cancel:
  br i1 %cancelled_now, label %unlock_done, label %complete

complete:
  %active_address = getelementptr i8, ptr %runtime, i64 4
  %active_count = load i32, ptr %active_address, align 4
  %next_active = sub i32 %active_count, 1
  store i32 %next_active, ptr %active_address, align 4
  %completion_event = or i32 %index, -2147483648
  call void @sollang_stream_join_enqueue_locked(ptr %runtime, i32 %completion_event)
  call void @sollang_stream_join_wake_all(ptr %runtime)
  call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
  ret void

unlock_done:
  call void @sollang_stream_join_worker_exit_locked(ptr %runtime)
  ret void
}

define internal ptr @sollang_stream_join_runtime_create(i32 %count, i64 %item_size, ptr %pull, ptr %drop, ptr %owner) #0 {
entry:
  %valid_count = icmp sgt i32 %count, 0
  %valid_size = icmp ugt i64 %item_size, 0
  %valid = and i1 %valid_count, %valid_size
  br i1 %valid, label %allocate, label %invalid

allocate:
  %runtime = call ptr @sollang_alloc(i64 208)
  %runtime_ok = icmp ne ptr %runtime, null
  br i1 %runtime_ok, label %allocate_arrays, label %invalid

allocate_arrays:
  call void @llvm.memset.p0.i64(ptr %runtime, i8 0, i64 208, i1 false)
  %count64 = zext i32 %count to i64
  %slots_size = mul i64 %count64, %item_size
  %slots = call ptr @sollang_alloc(i64 %slots_size)
  %full = call ptr @sollang_alloc(i64 %count64)
  %queue_size = mul i64 %count64, 4
  %queue = call ptr @sollang_alloc(i64 %queue_size)
  %thread_size = mul i64 %count64, 8
  %threads = call ptr @sollang_alloc(i64 %thread_size)
  %argument_size = mul i64 %count64, 16
  %arguments = call ptr @sollang_alloc(i64 %argument_size)
  %slots_ok = icmp ne ptr %slots, null
  %full_ok = icmp ne ptr %full, null
  %queue_ok = icmp ne ptr %queue, null
  %threads_ok = icmp ne ptr %threads, null
  %arguments_ok = icmp ne ptr %arguments, null
  %arrays_ok0 = and i1 %slots_ok, %full_ok
  %arrays_ok1 = and i1 %queue_ok, %threads_ok
  %arrays_ok2 = and i1 %arrays_ok0, %arrays_ok1
  %arrays_ok = and i1 %arrays_ok2, %arguments_ok
  br i1 %arrays_ok, label %initialize, label %free_arrays

initialize:
  call void @llvm.memset.p0.i64(ptr %full, i8 0, i64 %count64, i1 false)
  store i32 %count, ptr %runtime, align 4
  %active_address = getelementptr i8, ptr %runtime, i64 4
  store i32 %count, ptr %active_address, align 4
  %item_size_address = getelementptr i8, ptr %runtime, i64 24
  store i64 %item_size, ptr %item_size_address, align 8
  %pull_address = getelementptr i8, ptr %runtime, i64 32
  store ptr %pull, ptr %pull_address, align 8
  %drop_address = getelementptr i8, ptr %runtime, i64 40
  store ptr %drop, ptr %drop_address, align 8
  %owner_address = getelementptr i8, ptr %runtime, i64 48
  store ptr %owner, ptr %owner_address, align 8
  %slots_address = getelementptr i8, ptr %runtime, i64 56
  store ptr %slots, ptr %slots_address, align 8
  %full_address = getelementptr i8, ptr %runtime, i64 64
  store ptr %full, ptr %full_address, align 8
  %queue_address = getelementptr i8, ptr %runtime, i64 72
  store ptr %queue, ptr %queue_address, align 8
  %threads_address = getelementptr i8, ptr %runtime, i64 80
  store ptr %threads, ptr %threads_address, align 8
  %arguments_address = getelementptr i8, ptr %runtime, i64 88
  store ptr %arguments, ptr %arguments_address, align 8
  %sync_ok = call i1 @sollang_stream_join_sync_init(ptr %runtime)
  br i1 %sync_ok, label %start_loop, label %free_arrays

start_loop:
  br label %start

start:
  %index = phi i32 [ 0, %start_loop ], [ %next_index, %started ]
  %all_started = icmp eq i32 %index, %count
  br i1 %all_started, label %ready, label %start_one

start_one:
  %index64_start = zext i32 %index to i64
  %argument_offset = mul i64 %index64_start, 16
  %argument = getelementptr i8, ptr %arguments, i64 %argument_offset
  store ptr %runtime, ptr %argument, align 8
  %argument_index = getelementptr i8, ptr %argument, i64 8
  store i32 %index, ptr %argument_index, align 4
  %thread = getelementptr i64, ptr %threads, i32 %index
  %thread_ok = call i1 @sollang_stream_join_thread_start(ptr %thread, ptr %argument)
  br i1 %thread_ok, label %started, label %start_failed

started:
  %next_index = add i32 %index, 1
  %created_address = getelementptr i8, ptr %runtime, i64 96
  store i32 %next_index, ptr %created_address, align 4
  br label %start

ready:
  ret ptr %runtime

start_failed:
  call void @sollang_stream_join_runtime_cancel(ptr %runtime)
  call void @sollang_stream_join_runtime_join_destroy(ptr %runtime)
  ret ptr null

free_arrays:
  call void @sollang_free(ptr %arguments)
  call void @sollang_free(ptr %threads)
  call void @sollang_free(ptr %queue)
  call void @sollang_free(ptr %full)
  call void @sollang_free(ptr %slots)
  call void @sollang_free(ptr %runtime)
  ret ptr null

invalid:
  ret ptr null
}

define internal i1 @sollang_stream_join_runtime_next_event(ptr %runtime, ptr %index_output, ptr %kind_output, ptr %slot_output) #0 {
entry:
  call void @sollang_stream_join_lock(ptr %runtime)
  br label %inspect

inspect:
  %queued_address = getelementptr i8, ptr %runtime, i64 16
  %queued = load i32, ptr %queued_address, align 4
  %has_event = icmp sgt i32 %queued, 0
  br i1 %has_event, label %pop, label %empty

empty:
  %cancel_address = getelementptr i8, ptr %runtime, i64 20
  %cancelled = load i32, ptr %cancel_address, align 4
  %is_cancelled = icmp ne i32 %cancelled, 0
  %active_address = getelementptr i8, ptr %runtime, i64 4
  %active = load i32, ptr %active_address, align 4
  %complete = icmp eq i32 %active, 0
  %finished = or i1 %is_cancelled, %complete
  br i1 %finished, label %done, label %wait

wait:
  call void @sollang_stream_join_wait(ptr %runtime)
  br label %inspect

pop:
  %head_address = getelementptr i8, ptr %runtime, i64 8
  %head = load i32, ptr %head_address, align 4
  %queue_address = getelementptr i8, ptr %runtime, i64 72
  %queue = load ptr, ptr %queue_address, align 8
  %event_address = getelementptr i32, ptr %queue, i32 %head
  %event = load i32, ptr %event_address, align 4
  %count = load i32, ptr %runtime, align 4
  %next_head_unwrapped = add i32 %head, 1
  %next_head = urem i32 %next_head_unwrapped, %count
  store i32 %next_head, ptr %head_address, align 4
  %next_queued = sub i32 %queued, 1
  store i32 %next_queued, ptr %queued_address, align 4
  %kind = lshr i32 %event, 31
  %index = and i32 %event, 2147483647
  store i32 %index, ptr %index_output, align 4
  store i32 %kind, ptr %kind_output, align 4
  %item_size_address = getelementptr i8, ptr %runtime, i64 24
  %item_size = load i64, ptr %item_size_address, align 8
  %index64 = zext i32 %index to i64
  %slot_offset = mul i64 %index64, %item_size
  %slots_address = getelementptr i8, ptr %runtime, i64 56
  %slots = load ptr, ptr %slots_address, align 8
  %slot = getelementptr i8, ptr %slots, i64 %slot_offset
  store ptr %slot, ptr %slot_output, align 8
  call void @sollang_stream_join_unlock(ptr %runtime)
  ret i1 true

done:
  call void @sollang_stream_join_unlock(ptr %runtime)
  ret i1 false
}

define internal void @sollang_stream_join_runtime_release(ptr %runtime, i32 %index) #0 {
entry:
  call void @sollang_stream_join_lock(ptr %runtime)
  %full_array_address = getelementptr i8, ptr %runtime, i64 64
  %full_array = load ptr, ptr %full_array_address, align 8
  %full_address = getelementptr i8, ptr %full_array, i32 %index
  store i8 0, ptr %full_address, align 1
  call void @sollang_stream_join_wake_all(ptr %runtime)
  call void @sollang_stream_join_unlock(ptr %runtime)
  ret void
}

define internal void @sollang_stream_join_runtime_cancel(ptr %runtime) #0 {
entry:
  call void @sollang_stream_join_lock(ptr %runtime)
  %cancel_address = getelementptr i8, ptr %runtime, i64 20
  store atomic i32 1, ptr %cancel_address release, align 4
  call void @sollang_stream_join_wake_all(ptr %runtime)
  br label %settle

settle:
  %created_address = getelementptr i8, ptr %runtime, i64 96
  %created = load i32, ptr %created_address, align 4
  %pulling_address = getelementptr i8, ptr %runtime, i64 100
  %pulling = load i32, ptr %pulling_address, align 4
  %exited_address = getelementptr i8, ptr %runtime, i64 104
  %exited = load i32, ptr %exited_address, align 4
  %settled = add i32 %pulling, %exited
  %all_settled = icmp eq i32 %settled, %created
  br i1 %all_settled, label %done, label %wait

wait:
  call void @sollang_stream_join_wait(ptr %runtime)
  br label %settle

done:
  call void @sollang_stream_join_unlock(ptr %runtime)
  ret void
}

define internal void @sollang_stream_join_runtime_join_destroy(ptr %runtime) #0 {
entry:
  %created_address = getelementptr i8, ptr %runtime, i64 96
  %created = load i32, ptr %created_address, align 4
  %threads_address = getelementptr i8, ptr %runtime, i64 80
  %threads = load ptr, ptr %threads_address, align 8
  br label %join

join:
  %join_index = phi i32 [ 0, %entry ], [ %next_join, %join_one ]
  %all_joined = icmp eq i32 %join_index, %created
  br i1 %all_joined, label %drop_pending, label %join_one

join_one:
  %thread = getelementptr i64, ptr %threads, i32 %join_index
  call void @sollang_stream_join_thread_join(ptr %thread)
  %next_join = add i32 %join_index, 1
  br label %join

drop_pending:
  %count = load i32, ptr %runtime, align 4
  %full_array_address = getelementptr i8, ptr %runtime, i64 64
  %full_array = load ptr, ptr %full_array_address, align 8
  %item_size_address = getelementptr i8, ptr %runtime, i64 24
  %item_size = load i64, ptr %item_size_address, align 8
  %slots_address = getelementptr i8, ptr %runtime, i64 56
  %slots = load ptr, ptr %slots_address, align 8
  %drop_address = getelementptr i8, ptr %runtime, i64 40
  %drop = load ptr, ptr %drop_address, align 8
  %owner_address = getelementptr i8, ptr %runtime, i64 48
  %owner = load ptr, ptr %owner_address, align 8
  br label %drop_loop

drop_loop:
  %drop_index = phi i32 [ 0, %drop_pending ], [ %next_drop, %drop_continue ]
  %all_dropped = icmp eq i32 %drop_index, %count
  br i1 %all_dropped, label %destroy, label %inspect_pending

inspect_pending:
  %full_address = getelementptr i8, ptr %full_array, i32 %drop_index
  %full = load i8, ptr %full_address, align 1
  %has_pending = icmp ne i8 %full, 0
  br i1 %has_pending, label %drop_one, label %drop_continue

drop_one:
  %drop_index64 = zext i32 %drop_index to i64
  %slot_offset = mul i64 %drop_index64, %item_size
  %slot = getelementptr i8, ptr %slots, i64 %slot_offset
  call void %drop(ptr %owner, i32 %drop_index, ptr %slot)
  br label %drop_continue

drop_continue:
  %next_drop = add i32 %drop_index, 1
  br label %drop_loop

destroy:
  call void @sollang_stream_join_sync_destroy(ptr %runtime)
  %arguments_address = getelementptr i8, ptr %runtime, i64 88
  %arguments = load ptr, ptr %arguments_address, align 8
  %queue_address = getelementptr i8, ptr %runtime, i64 72
  %queue = load ptr, ptr %queue_address, align 8
  call void @sollang_free(ptr %arguments)
  call void @sollang_free(ptr %threads)
  call void @sollang_free(ptr %queue)
  call void @sollang_free(ptr %full_array)
  call void @sollang_free(ptr %slots)
  call void @sollang_free(ptr %runtime)
  ret void
}

declare void @llvm.trap()
declare i64 @llvm.ctpop.i64(i64)
declare i16 @llvm.cttz.i16(i16, i1 immarg)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg)
declare void @llvm.memcpy.p0.p0.i64(ptr nocapture writeonly, ptr nocapture readonly, i64, i1 immarg)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)

define internal void @sollang_drop_2705(%sollang.struct.2705 %value) #0 {
entry:
  %drop_field0 = extractvalue %sollang.struct.2705 %value, 0
  %stream_context1 = extractvalue %sollang.event_stream %drop_field0, 0
  %stream_next2 = extractvalue %sollang.event_stream %drop_field0, 1
  %stream_drop3 = extractvalue %sollang.event_stream %drop_field0, 2
  %stream_has_drop4 = icmp ne ptr %stream_drop3, null
  br i1 %stream_has_drop4, label %bb_stream_drop0, label %bb_stream_drop_done1

bb_stream_drop0:
  call void %stream_drop3(ptr %stream_context1, i1 true)
  br label %bb_stream_drop_done1

bb_stream_drop_done1:
  %drop_field5 = extractvalue %sollang.struct.2705 %value, 1
  %stream_context6 = extractvalue %sollang.event_stream %drop_field5, 0
  %stream_next7 = extractvalue %sollang.event_stream %drop_field5, 1
  %stream_drop8 = extractvalue %sollang.event_stream %drop_field5, 2
  %stream_has_drop9 = icmp ne ptr %stream_drop8, null
  br i1 %stream_has_drop9, label %bb_stream_drop2, label %bb_stream_drop_done3

bb_stream_drop2:
  call void %stream_drop8(ptr %stream_context6, i1 true)
  br label %bb_stream_drop_done3

bb_stream_drop_done3:
  ret void
}

define internal i1 @sollang_stream_join_0_pull(ptr %context, i32 %index, ptr %slot) #0 {
entry:
  switch i32 %index, label %bb_stream_join_pull_invalid4 [
    i32 0, label %bb_stream_join_pull_05
    i32 1, label %bb_stream_join_pull_16
  ]

bb_stream_join_pull_05:
  %stream_join_input_address10 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 0
  %stream_join_input11 = load %sollang.event_stream, ptr %stream_join_input_address10, align 8
  %stream_context12 = extractvalue %sollang.event_stream %stream_join_input11, 0
  %stream_next13 = extractvalue %sollang.event_stream %stream_join_input11, 1
  %stream_drop14 = extractvalue %sollang.event_stream %stream_join_input11, 2
  %stream_join_pulled15 = call i1 %stream_next13(ptr %stream_context12, ptr %slot)
  ret i1 %stream_join_pulled15

bb_stream_join_pull_16:
  %stream_join_input_address16 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 1
  %stream_join_input17 = load %sollang.event_stream, ptr %stream_join_input_address16, align 8
  %stream_context18 = extractvalue %sollang.event_stream %stream_join_input17, 0
  %stream_next19 = extractvalue %sollang.event_stream %stream_join_input17, 1
  %stream_drop20 = extractvalue %sollang.event_stream %stream_join_input17, 2
  %stream_join_pulled21 = call i1 %stream_next19(ptr %stream_context18, ptr %slot)
  ret i1 %stream_join_pulled21

bb_stream_join_pull_invalid4:
  call void @llvm.trap()
  unreachable
}

define internal void @sollang_stream_join_0_drop_item(ptr %context, i32 %index, ptr %slot) #0 {
entry:
  ret void
}

define internal i1 @sollang_stream_join_0_next(ptr %context, ptr %output) #0 {
entry:
  %stream_join_runtime_address22 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %context, i32 0, i32 2
  %stream_join_runtime23 = load ptr, ptr %stream_join_runtime_address22, align 8
  %merge_event_index_address24 = alloca i32, align 4
  %merge_event_kind_address25 = alloca i32, align 4
  %merge_event_slot_address26 = alloca ptr, align 8
  br label %bb_merge_event_wait7

bb_merge_event_wait7:
  %merge_event_available27 = call i1 @sollang_stream_join_runtime_next_event(ptr %stream_join_runtime23, ptr %merge_event_index_address24, ptr %merge_event_kind_address25, ptr %merge_event_slot_address26)
  br i1 %merge_event_available27, label %bb_merge_event_received8, label %bb_merge_event_done9

bb_merge_event_received8:
  %merge_event_kind28 = load i32, ptr %merge_event_kind_address25, align 4
  %merge_event_is_value29 = icmp eq i32 %merge_event_kind28, 0
  br i1 %merge_event_is_value29, label %bb_merge_event_value10, label %bb_merge_event_wait7

bb_merge_event_value10:
  %merge_event_index30 = load i32, ptr %merge_event_index_address24, align 4
  %merge_event_slot31 = load ptr, ptr %merge_event_slot_address26, align 8
  %merge_event_value32 = load %sollang.struct.44, ptr %merge_event_slot31, align 8
  store %sollang.struct.44 %merge_event_value32, ptr %output, align 8
  call void @sollang_stream_join_runtime_release(ptr %stream_join_runtime23, i32 %merge_event_index30)
  ret i1 true

bb_merge_event_done9:
  ret i1 false
}

define internal void @sollang_stream_join_0_drop(ptr %context, i1 %destroy) #0 {
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

define internal %sollang.enum.2611 @sollang_fn_sys_input_mouse_source(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, i32 %it, %sollang.enum.46 %arg_0) #0 {
entry:
  %enum_init_slot4 = alloca %sollang.enum.1581, align 8
  %enum_init_slot9 = alloca %sollang.enum.2611, align 8
  %enum_init_slot15 = alloca %sollang.enum.2611, align 8
  %cmp0 = icmp sge i32 %it, 2
  br i1 %cmp0, label %bb_and_rhs0, label %bb_and_end1
bb_and_rhs0:
  %cmp1 = icmp sle i32 %it, 65536
  br label %bb_and_end1
bb_and_end1:
  %and2 = phi i1 [ false, %entry ], [ %cmp1, %bb_and_rhs0 ]
  %not3 = xor i1 %and2, true
  br i1 %not3, label %bb_if_then2, label %bb_if_end3
bb_if_then2:
  store %sollang.enum.1581 zeroinitializer, ptr %enum_init_slot4, align 8
  %enum_tag_addr5 = getelementptr inbounds %sollang.enum.1581, ptr %enum_init_slot4, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr5, align 4
  %enum_value6 = load %sollang.enum.1581, ptr %enum_init_slot4, align 8
  %struct_init7 = insertvalue %sollang.struct.1436 poison, %sollang.enum.1581 %enum_value6, 0
  %struct_init8 = insertvalue %sollang.struct.1436 %struct_init7, i32 %it, 1
  store %sollang.enum.2611 zeroinitializer, ptr %enum_init_slot9, align 8
  %enum_tag_addr10 = getelementptr inbounds %sollang.enum.2611, ptr %enum_init_slot9, i32 0, i32 0
  store i32 1, ptr %enum_tag_addr10, align 4
  %enum_payload_addr11 = getelementptr inbounds %sollang.enum.2611, ptr %enum_init_slot9, i32 0, i32 1
  store %sollang.struct.1436 %struct_init8, ptr %enum_payload_addr11, align 8
  %enum_value12 = load %sollang.enum.2611, ptr %enum_init_slot9, align 8
  ret %sollang.enum.2611 %enum_value12
bb_if_end3:
  %struct_init13 = insertvalue %sollang.struct.1437 poison, i32 %it, 0
  %struct_init14 = insertvalue %sollang.struct.1437 %struct_init13, %sollang.enum.46 %arg_0, 1
  store %sollang.enum.2611 zeroinitializer, ptr %enum_init_slot15, align 8
  %enum_tag_addr16 = getelementptr inbounds %sollang.enum.2611, ptr %enum_init_slot15, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr16, align 4
  %enum_payload_addr17 = getelementptr inbounds %sollang.enum.2611, ptr %enum_init_slot15, i32 0, i32 1
  store %sollang.struct.1437 %struct_init14, ptr %enum_payload_addr17, align 8
  %enum_value18 = load %sollang.enum.2611, ptr %enum_init_slot15, align 8
  ret %sollang.enum.2611 %enum_value18
}

@.slg.str.suffix.0 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [1 x i8] c"\0A", align 1
@.slg.str.suffix.2 = private unnamed_addr constant [1 x i8] c"\0A", align 1
define internal i32 @sollang_flush_stdout(ptr %stdout, ptr %written) #0 {
entry:
  %count = load i64, ptr @sollang_stdout_buffer_count, align 8
  %has_data = icmp ne i64 %count, 0
  br i1 %has_data, label %write_buffer, label %empty

write_buffer:
  %buffer = getelementptr inbounds [65536 x i8], ptr @sollang_stdout_buffer, i64 0, i64 0
  %written64 = call i64 @write(i32 1, ptr %buffer, i64 %count)
  %written32 = trunc i64 %written64 to i32
  store i32 %written32, ptr %written, align 4
  store i64 0, ptr @sollang_stdout_buffer_count, align 8
  %nonnegative = icmp sge i64 %written64, 0
  %complete = icmp eq i64 %written64, %count
  %ok = and i1 %nonnegative, %complete
  %ok32 = zext i1 %ok to i32
  ret i32 %ok32

empty:
  store i32 0, ptr %written, align 4
  ret i32 1
}

define internal i32 @sollang_write(ptr %stdout, ptr %data, i64 %len64, ptr %written) #0 {
entry:
  br label %write_prepare

write_prepare:
  %oversized = icmp ugt i64 %len64, 65536
  br i1 %oversized, label %write_direct_prepare, label %buffer_prepare

write_direct_prepare:
  %flushed_direct = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %written64 = call i64 @write(i32 1, ptr %data, i64 %len64)
  %written32 = trunc i64 %written64 to i32
  store i32 %written32, ptr %written, align 4
  %direct_nonnegative = icmp sge i64 %written64, 0
  %direct_complete = icmp eq i64 %written64, %len64
  %direct_ok = and i1 %direct_nonnegative, %direct_complete
  %direct_ok32 = zext i1 %direct_ok to i32
  ret i32 %direct_ok32

buffer_prepare:
  %count = load i64, ptr @sollang_stdout_buffer_count, align 8
  %combined = add i64 %count, %len64
  %needs_flush = icmp ugt i64 %combined, 65536
  br i1 %needs_flush, label %flush, label %append

flush:
  %flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  br label %append

append:
  %offset = phi i64 [ %count, %buffer_prepare ], [ 0, %flush ]
  %destination = getelementptr inbounds [65536 x i8], ptr @sollang_stdout_buffer, i64 0, i64 %offset
  %copied = call ptr @memcpy(ptr %destination, ptr %data, i64 %len64)
  %next_count = add i64 %offset, %len64
  store i64 %next_count, ptr @sollang_stdout_buffer_count, align 8
  %appended32 = trunc i64 %len64 to i32
  store i32 %appended32, ptr %written, align 4
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
  %stdout = inttoptr i64 1 to ptr
  %written = alloca i32, align 4
  %flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %read64 = call i64 @read(i32 0, ptr %data, i64 %len64)
  %read32 = trunc i64 %read64 to i32
  store i32 %read32, ptr %read, align 4
  %ok = icmp sge i64 %read64, 0
  %ok32 = zext i1 %ok to i32
  ret i32 %ok32
}

define internal i32 @sollang_platform_create_exclusive_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [4096 x i8], align 1
  %buf_ptr = getelementptr inbounds [4096 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copied = icmp ne i32 %copy_ok, 0
  br i1 %copied, label %check_nul, label %fail

check_nul:
  %no_nul = call i32 @sollang_file_path_has_no_nul(ptr %path, i64 %len)
  %valid = icmp ne i32 %no_nul, 0
  br i1 %valid, label %create, label %fail

create:
  %fd = call i32 @open(ptr %buf_ptr, i32 193, i32 384)
  %opened = icmp sge i32 %fd, 0
  br i1 %opened, label %close, label %create_failed

close:
  %closed = call i32 @close(i32 %fd)
  %close_ok = icmp eq i32 %closed, 0
  %status = select i1 %close_ok, i32 1, i32 -1
  ret i32 %status

create_failed:
  %errno_ptr = call ptr @__errno_location()
  %errno = load i32, ptr %errno_ptr, align 4
  %exists = icmp eq i32 %errno, 17
  %status_failed = select i1 %exists, i32 0, i32 -1
  ret i32 %status_failed

fail:
  ret i32 -1
}

define internal i32 @sollang_platform_remove_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [4096 x i8], align 1
  %buf_ptr = getelementptr inbounds [4096 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copied = icmp ne i32 %copy_ok, 0
  br i1 %copied, label %check_nul, label %fail

check_nul:
  %no_nul = call i32 @sollang_file_path_has_no_nul(ptr %path, i64 %len)
  %valid = icmp ne i32 %no_nul, 0
  br i1 %valid, label %remove, label %fail

remove:
  %removed = call i32 @unlink(ptr %buf_ptr)
  %success = icmp eq i32 %removed, 0
  br i1 %success, label %removed_file, label %remove_failed

removed_file:
  ret i32 1

remove_failed:
  %errno_ptr = call ptr @__errno_location()
  %errno = load i32, ptr %errno_ptr, align 4
  %missing = icmp eq i32 %errno, 2
  %status = select i1 %missing, i32 0, i32 -1
  ret i32 %status

fail:
  ret i32 -1
}

define internal i32 @sollang_platform_atomic_replace_file(ptr %temporary, i64 %temporary_len, ptr %destination, i64 %destination_len) #0 {
entry:
  %temporary_buf = alloca [4096 x i8], align 1
  %temporary_ptr = getelementptr inbounds [4096 x i8], ptr %temporary_buf, i64 0, i64 0
  %temporary_ok = call i32 @sollang_copy_text_to_c_path(ptr %temporary, i64 %temporary_len, ptr %temporary_ptr)
  %temporary_valid = icmp ne i32 %temporary_ok, 0
  br i1 %temporary_valid, label %copy_destination, label %fail

copy_destination:
  %destination_buf = alloca [4096 x i8], align 1
  %destination_ptr = getelementptr inbounds [4096 x i8], ptr %destination_buf, i64 0, i64 0
  %destination_ok = call i32 @sollang_copy_text_to_c_path(ptr %destination, i64 %destination_len, ptr %destination_ptr)
  %destination_valid = icmp ne i32 %destination_ok, 0
  br i1 %destination_valid, label %replace, label %fail

replace:
  %status = call i32 @rename(ptr %temporary_ptr, ptr %destination_ptr)
  %ok = icmp eq i32 %status, 0
  %ok32 = zext i1 %ok to i32
  ret i32 %ok32

fail:
  ret i32 0
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_read_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open_file, label %fail

open_file:
  %fd = call i32 @open(ptr %buf_ptr, i32 0, i32 0)
  %ok = icmp sge i32 %fd, 0
  br i1 %ok, label %success, label %fail

success:
  %handle = sext i32 %fd to i64
  %ok0 = insertvalue %sollang.file_handle_result poison, i64 %handle, 0
  %ok1 = insertvalue %sollang.file_handle_result %ok0, i32 1, 1
  ret %sollang.file_handle_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %fail1 = insertvalue %sollang.file_handle_result %fail0, i32 0, 1
  ret %sollang.file_handle_result %fail1
}

define internal %sollang.file_handle_result @sollang_platform_open_owned_write_file(ptr %path, i64 %len) #0 {
entry:
  %buf = alloca [4096 x i8], align 1
  %buf_ptr = getelementptr inbounds [4096 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %len, ptr %buf_ptr)
  %copy_is_ok = icmp ne i32 %copy_ok, 0
  br i1 %copy_is_ok, label %open_file, label %fail

open_file:
  %fd = call i32 @open(ptr %buf_ptr, i32 577, i32 438)
  %valid = icmp sge i32 %fd, 0
  br i1 %valid, label %success, label %fail

success:
  %handle = sext i32 %fd to i64
  %ok0 = insertvalue %sollang.file_handle_result poison, i64 %handle, 0
  %ok1 = insertvalue %sollang.file_handle_result %ok0, i32 1, 1
  ret %sollang.file_handle_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_handle_result poison, i64 -1, 0
  %fail1 = insertvalue %sollang.file_handle_result %fail0, i32 0, 1
  ret %sollang.file_handle_result %fail1
}

define internal i64 @sollang_platform_duplicate_owned_file(i64 %source) #0 {
entry:
  %source_fd = trunc i64 %source to i32
  %fd = call i32 @dup(i32 %source_fd)
  %handle = sext i32 %fd to i64
  ret i64 %handle
}

define internal %sollang.file_count_result @sollang_platform_read_owned_file_at(i64 %handle, ptr %data, i64 %len, i64 %offset) #0 {
entry:
  %valid_handle = icmp sge i64 %handle, 0
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %ready = and i1 %valid_handle, %valid_offset
  br i1 %ready, label %read_file, label %fail

read_file:
  %fd = trunc i64 %handle to i32
  %count = call i64 @pread(i32 %fd, ptr %data, i64 %len, i64 %offset)
  %ok = icmp sge i64 %count, 0
  br i1 %ok, label %success, label %fail

success:
  %ok0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.file_count_result %ok0, i32 1, 1
  ret %sollang.file_count_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1
  ret %sollang.file_count_result %fail1
}

define internal %sollang.file_count_result @sollang_platform_write_owned_file_at(i64 %handle, ptr %data, i64 %len, i64 %offset) #0 {
entry:
  %fd = trunc i64 %handle to i32
  %valid_fd = icmp sge i32 %fd, 0
  %valid_offset = icmp ule i64 %offset, 9223372036854775807
  %ready = and i1 %valid_fd, %valid_offset
  br i1 %ready, label %write_file, label %fail

write_file:
  %count = call i64 @pwrite(i32 %fd, ptr %data, i64 %len, i64 %offset)
  %ok = icmp sge i64 %count, 0
  br i1 %ok, label %success, label %fail

success:
  %ok0 = insertvalue %sollang.file_count_result poison, i64 %count, 0
  %ok1 = insertvalue %sollang.file_count_result %ok0, i32 1, 1
  ret %sollang.file_count_result %ok1

fail:
  %fail0 = insertvalue %sollang.file_count_result poison, i64 0, 0
  %fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1
  ret %sollang.file_count_result %fail1
}

define internal i32 @sollang_platform_sync_owned_file(i64 %handle) #0 {
entry:
  %fd = trunc i64 %handle to i32
  %valid = icmp sge i32 %fd, 0
  br i1 %valid, label %sync_file, label %fail

sync_file:
  %status = call i32 @fsync(i32 %fd)
  %ok = icmp eq i32 %status, 0
  %ok32 = zext i1 %ok to i32
  ret i32 %ok32

fail:
  ret i32 0
}

define internal void @sollang_platform_close_owned_file(i64 %handle) #0 {
entry:
  %valid = icmp sge i64 %handle, 0
  br i1 %valid, label %close_file, label %done

close_file:
  %fd = trunc i64 %handle to i32
  %ignored = call i32 @close(i32 %fd)
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
  br i1 %copy_is_ok, label %open_file, label %fail

open_file:
  %fd = call i32 @open(ptr %buf_ptr, i32 577, i32 420)
  %ok = icmp sge i32 %fd, 0
  br i1 %ok, label %success, label %fail

success:
  store i32 %fd, ptr @sollang_file_writer_fd, align 4
  ret i32 1

fail:
  ret i32 0
}

define internal i32 @sollang_platform_write_file_bytes(ptr %data, i64 %len64) #0 {
entry:
  %fd = load i32, ptr @sollang_file_writer_fd, align 4
  %has_fd = icmp sge i32 %fd, 0
  br i1 %has_fd, label %write_file, label %fail

write_file:
  %written = call i64 @write(i32 %fd, ptr %data, i64 %len64)
  %ok1 = icmp sge i64 %written, 0
  %ok2 = icmp eq i64 %written, %len64
  %ok = and i1 %ok1, %ok2
  %result = zext i1 %ok to i32
  ret i32 %result

fail:
  ret i32 0
}

define internal i32 @sollang_platform_close_write_file() #0 {
entry:
  %fd = load i32, ptr @sollang_file_writer_fd, align 4
  %has_fd = icmp sge i32 %fd, 0
  br i1 %has_fd, label %close_file, label %fail

close_file:
  %close_result = call i32 @close(i32 %fd)
  %ok = icmp eq i32 %close_result, 0
  br i1 %ok, label %success, label %fail

success:
  store i32 -1, ptr @sollang_file_writer_fd, align 4
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
  br i1 %copy_is_ok, label %open_file, label %fail

open_file:
  %fd = call i32 @open(ptr %buf_ptr, i32 0, i32 0)
  %ok = icmp sge i32 %fd, 0
  br i1 %ok, label %success, label %fail

success:
  store i32 %fd, ptr @sollang_file_reader_fd, align 4
  ret i32 1

fail:
  ret i32 0
}

define internal %sollang.file_count_result @sollang_platform_i64_file_count() #0 {
entry:
  %fd = load i32, ptr @sollang_file_reader_fd, align 4
  %has_fd = icmp sge i32 %fd, 0
  br i1 %has_fd, label %size, label %fail

size:
  %end = call i64 @lseek(i32 %fd, i64 0, i32 2)
  %size_ok = icmp sge i64 %end, 0
  br i1 %size_ok, label %check, label %fail

check:
  %rem = urem i64 %end, 8
  %aligned = icmp eq i64 %rem, 0
  br i1 %aligned, label %success, label %fail

success:
  %count = udiv i64 %end, 8
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
  %fd = load i32, ptr @sollang_file_reader_fd, align 4
  %has_fd = icmp sge i32 %fd, 0
  br i1 %has_fd, label %seek, label %fail

seek:
  %offset = mul i64 %index, 8
  %pos = call i64 @lseek(i32 %fd, i64 %offset, i32 0)
  %seek_ok = icmp eq i64 %pos, %offset
  br i1 %seek_ok, label %read_file, label %fail

read_file:
  %value_ptr = alloca i64, align 8
  %read_bytes = call i64 @read(i32 %fd, ptr %value_ptr, i64 8)
  %read_ok = icmp eq i64 %read_bytes, 8
  br i1 %read_ok, label %success, label %fail

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

define internal %sollang.file_count_result @sollang_platform_read_file_bytes(ptr %data, i64 %len) #0 {
entry:
  %fd = load i32, ptr @sollang_file_reader_fd, align 4
  %has_fd = icmp sge i32 %fd, 0
  br i1 %has_fd, label %read_file, label %fail

read_file:
  %count = call i64 @read(i32 %fd, ptr %data, i64 %len)
  %ok = icmp sge i64 %count, 0
  br i1 %ok, label %success, label %fail

success:
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
  %fd = load i32, ptr @sollang_file_reader_fd, align 4
  %has_fd = icmp sge i32 %fd, 0
  br i1 %has_fd, label %close_file, label %fail

close_file:
  %close_result = call i32 @close(i32 %fd)
  %ok = icmp eq i32 %close_result, 0
  br i1 %ok, label %success, label %fail

success:
  store i32 -1, ptr @sollang_file_reader_fd, align 4
  ret i32 1

fail:
  ret i32 0
}

define internal %sollang.mapped_bytes @sollang_map_file(ptr %path, i64 %path_len, i64 %offset, i64 %requested_len, i64 %requested_size, i1 %writable) #0 {
entry:
  %buf = alloca [260 x i8], align 1
  %buf_ptr = getelementptr inbounds [260 x i8], ptr %buf, i64 0, i64 0
  %copy_ok = call i32 @sollang_copy_text_to_c_path(ptr %path, i64 %path_len, ptr %buf_ptr)
  %path_ok = icmp ne i32 %copy_ok, 0
  br i1 %path_ok, label %open_file, label %fail

open_file:
  %flags = select i1 %writable, i32 66, i32 0
  %fd = call i32 @open(ptr %buf_ptr, i32 %flags, i32 420)
  %fd_ok = icmp sge i32 %fd, 0
  br i1 %fd_ok, label %resize_check, label %fail

resize_check:
  %has_requested_size = icmp ne i64 %requested_size, 0
  %resize = and i1 %writable, %has_requested_size
  br i1 %resize, label %resize_file, label %read_size

resize_file:
  %truncate_result = call i32 @ftruncate(i32 %fd, i64 %requested_size)
  %truncate_ok = icmp eq i32 %truncate_result, 0
  br i1 %truncate_ok, label %read_size, label %close_fail

read_size:
  %file_size = call i64 @lseek(i32 %fd, i64 0, i32 2)
  %size_ok = icmp sge i64 %file_size, 0
  br i1 %size_ok, label %bounds, label %close_fail

bounds:
  %offset_ok = icmp ule i64 %offset, %file_size
  %remaining = sub i64 %file_size, %offset
  %whole = icmp eq i64 %requested_len, 0
  %view_len = select i1 %whole, i64 %remaining, i64 %requested_len
  %len_nonzero = icmp ne i64 %view_len, 0
  %len_ok = icmp ule i64 %view_len, %remaining
  %bounds1 = and i1 %offset_ok, %len_nonzero
  %bounds_ok = and i1 %bounds1, %len_ok
  br i1 %bounds_ok, label %view, label %close_fail

view:
  %aligned = and i64 %offset, -4096
  %delta = sub i64 %offset, %aligned
  %mapped_len = add i64 %delta, %view_len
  %protect_extra = select i1 %writable, i32 2, i32 0
  %protect = or i32 1, %protect_extra
  %base = call ptr @mmap(ptr null, i64 %mapped_len, i32 %protect, i32 1, i32 %fd, i64 %aligned)
  %base_int = ptrtoint ptr %base to i64
  %base_ok = icmp ne i64 %base_int, -1
  br i1 %base_ok, label %success, label %close_fail

success:
  %data = getelementptr i8, ptr %base, i64 %delta
  %ignored_close = call i32 @close(i32 %fd)
  %r0 = insertvalue %sollang.mapped_bytes poison, ptr %data, 0
  %r1 = insertvalue %sollang.mapped_bytes %r0, i64 %view_len, 1
  %r2 = insertvalue %sollang.mapped_bytes %r1, ptr %base, 2
  %r3 = insertvalue %sollang.mapped_bytes %r2, i64 %mapped_len, 3
  %r4 = insertvalue %sollang.mapped_bytes %r3, i1 %writable, 4
  ret %sollang.mapped_bytes %r4

close_fail:
  %ignored_close_fail = call i32 @close(i32 %fd)
  br label %fail

fail:
  %f0 = insertvalue %sollang.mapped_bytes zeroinitializer, i1 %writable, 4
  ret %sollang.mapped_bytes %f0
}

define internal i32 @sollang_mapped_flush(ptr %base, i64 %mapped_len) #0 {
entry:
  %result = call i32 @msync(ptr %base, i64 %mapped_len, i32 4)
  %ok = icmp eq i32 %result, 0
  %ok32 = zext i1 %ok to i32
  ret i32 %ok32
}

define internal void @sollang_mapped_unmap(ptr %base, i64 %mapped_len) #0 {
entry:
  %ignored = call i32 @munmap(ptr %base, i64 %mapped_len)
  ret void
}

define internal i64 @sollang_now_millis() #0 {
entry:
  %ts = alloca [2 x i64], align 8
  %ignored = call i32 @clock_gettime(i32 1, ptr %ts)
  %sec_ptr = getelementptr inbounds [2 x i64], ptr %ts, i64 0, i64 0
  %nsec_ptr = getelementptr inbounds [2 x i64], ptr %ts, i64 0, i64 1
  %sec = load i64, ptr %sec_ptr, align 8
  %nsec = load i64, ptr %nsec_ptr, align 8
  %sec_ms = mul i64 %sec, 1000
  %nsec_ms = udiv i64 %nsec, 1000000
  %millis = add i64 %sec_ms, %nsec_ms
  ret i64 %millis
}

define internal i64 @sollang_utc_now_millis() #0 {
entry:
  %ts = alloca [2 x i64], align 8
  %ignored = call i32 @clock_gettime(i32 0, ptr %ts)
  %sec_ptr = getelementptr inbounds [2 x i64], ptr %ts, i64 0, i64 0
  %nsec_ptr = getelementptr inbounds [2 x i64], ptr %ts, i64 0, i64 1
  %sec = load i64, ptr %sec_ptr, align 8
  %nsec = load i64, ptr %nsec_ptr, align 8
  %sec_ms = mul i64 %sec, 1000
  %nsec_ms = udiv i64 %nsec, 1000000
  %millis = add i64 %sec_ms, %nsec_ms
  ret i64 %millis
}

define internal void @sollang_wait_millis(i64 %millis) #0 {
entry:
  %positive = icmp sgt i64 %millis, 0
  br i1 %positive, label %wait, label %done

wait:
  %ts = alloca [2 x i64], align 8
  %seconds = sdiv i64 %millis, 1000
  %remaining = srem i64 %millis, 1000
  %nanoseconds = mul i64 %remaining, 1000000
  %sec_ptr = getelementptr inbounds [2 x i64], ptr %ts, i64 0, i64 0
  %nsec_ptr = getelementptr inbounds [2 x i64], ptr %ts, i64 0, i64 1
  store i64 %seconds, ptr %sec_ptr, align 8
  store i64 %nanoseconds, ptr %nsec_ptr, align 8
  %ignored = call i32 @nanosleep(ptr %ts, ptr null)
  br label %done

done:
  ret void
}

define internal ptr @sollang_alloc(i64 %bytes) #0 {
entry:
  %ptr = call ptr @malloc(i64 %bytes)
  ret ptr %ptr
}

define internal void @sollang_free(ptr %ptr) #0 {
entry:
  %is_null = icmp eq ptr %ptr, null
  br i1 %is_null, label %done, label %free

free:
  call void @free(ptr %ptr)
  br label %done

done:
  ret void
}

@sollang_mouse_enable = private constant [16 x i8] c"\1B[?1003h\1B[?1006h"
@sollang_mouse_disable = private constant [16 x i8] c"\1B[?1003l\1B[?1006l"

define internal i32 @sollang_linux_mouse_read_byte(ptr %context) #0 {
entry:
  %poll_record = alloca [8 x i8], align 4
  %byte = alloca i8, align 1
  store i32 0, ptr %poll_record, align 4
  %events = getelementptr i8, ptr %poll_record, i64 4
  store i16 1, ptr %events, align 2
  br label %wait

wait:
  %cancel_address = getelementptr i8, ptr %context, i64 20
  %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
  %active = icmp eq i32 %cancelled, 0
  br i1 %active, label %poll, label %closed

poll:
  %ready = call i32 @poll(ptr %poll_record, i64 1, i32 50)
  %has_input = icmp sgt i32 %ready, 0
  br i1 %has_input, label %read_byte, label %wait

read_byte:
  %read_count = call i64 @read(i32 0, ptr %byte, i64 1)
  %read_ok = icmp eq i64 %read_count, 1
  br i1 %read_ok, label %got_value, label %wait

got_value:
  %raw = load i8, ptr %byte, align 1
  %byte_value = zext i8 %raw to i32
  ret i32 %byte_value

closed:
  ret i32 -1
}

define internal void @sollang_linux_mouse_signal(ptr %context) #0 {
entry:
  %one = alloca i64, align 8
  store i64 1, ptr %one, align 8
  %fd_address = getelementptr i8, ptr %context, i64 28
  %fd = load i32, ptr %fd_address, align 4
  %written = call i64 @write(i32 %fd, ptr %one, i64 8)
  ret void
}

define internal void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 %delta, i32 %button, i32 %kind) #0 {
entry:
  br label %queue_lock

queue_lock:
  %lock_address = getelementptr i8, ptr %context, i64 24
  %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
  %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
  br i1 %lock_acquired, label %queue_state, label %queue_lock

queue_state:
  %capacity = load i32, ptr %context, align 4
  %policy_address = getelementptr i8, ptr %context, i64 4
  %policy = load i32, ptr %policy_address, align 4
  %count_address = getelementptr i8, ptr %context, i64 16
  %count = load i32, ptr %count_address, align 4
  %full = icmp uge i32 %count, %capacity
  br i1 %full, label %overflow, label %write

overflow:
  %drop_newest = icmp eq i32 %policy, 0
  br i1 %drop_newest, label %unlock_drop, label %not_drop_newest

not_drop_newest:
  %coalesce = icmp eq i32 %policy, 2
  %is_move = icmp eq i32 %kind, 0
  %coalesce_move = and i1 %coalesce, %is_move
  br i1 %coalesce_move, label %replace_move_check, label %drop_oldest

replace_move_check:
  %tail_address0 = getelementptr i8, ptr %context, i64 12
  %tail0 = load i32, ptr %tail_address0, align 4
  %tail_plus_capacity = add i32 %tail0, %capacity
  %last_unwrapped = sub i32 %tail_plus_capacity, 1
  %last_index = urem i32 %last_unwrapped, %capacity
  %last_index64 = zext i32 %last_index to i64
  %last_offset = mul i64 %last_index64, 20
  %buffer_address0 = getelementptr i8, ptr %context, i64 40
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
  br label %unlock_signal

drop_oldest:
  %head_address = getelementptr i8, ptr %context, i64 8
  %head = load i32, ptr %head_address, align 4
  %next_head_unwrapped = add i32 %head, 1
  %next_head = urem i32 %next_head_unwrapped, %capacity
  store i32 %next_head, ptr %head_address, align 4
  %reduced_count = sub i32 %count, 1
  store i32 %reduced_count, ptr %count_address, align 4
  br label %write

write:
  %tail_address = getelementptr i8, ptr %context, i64 12
  %tail = load i32, ptr %tail_address, align 4
  %tail64 = zext i32 %tail to i64
  %offset = mul i64 %tail64, 20
  %buffer_address = getelementptr i8, ptr %context, i64 40
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
  br label %unlock_signal

unlock_drop:
  store atomic i32 0, ptr %lock_address release, align 4
  ret void

unlock_signal:
  store atomic i32 0, ptr %lock_address release, align 4
  call void @sollang_linux_mouse_signal(ptr %context)
  ret void
}

define internal ptr @sollang_linux_mouse_worker(ptr %context) #0 {
entry:
  %button_value = alloca i32, align 4
  %x_value = alloca i32, align 4
  %y_value = alloca i32, align 4
  br label %seek_escape

seek_escape:
  %escape = call i32 @sollang_linux_mouse_read_byte(ptr %context)
  %escape_closed = icmp slt i32 %escape, 0
  br i1 %escape_closed, label %done, label %check_escape

check_escape:
  %is_escape = icmp eq i32 %escape, 27
  br i1 %is_escape, label %expect_bracket, label %seek_escape

expect_bracket:
  %bracket = call i32 @sollang_linux_mouse_read_byte(ptr %context)
  %is_bracket = icmp eq i32 %bracket, 91
  br i1 %is_bracket, label %expect_less, label %seek_escape

expect_less:
  %less = call i32 @sollang_linux_mouse_read_byte(ptr %context)
  %is_less = icmp eq i32 %less, 60
  br i1 %is_less, label %button_start, label %seek_escape

button_start:
  store i32 0, ptr %button_value, align 4
  br label %button_digit

button_digit:
  %button_char = call i32 @sollang_linux_mouse_read_byte(ptr %context)
  %button_is_digit_low = icmp sge i32 %button_char, 48
  %button_is_digit_high = icmp sle i32 %button_char, 57
  %button_is_digit = and i1 %button_is_digit_low, %button_is_digit_high
  br i1 %button_is_digit, label %button_accumulate, label %button_separator

button_accumulate:
  %button_old = load i32, ptr %button_value, align 4
  %button_times_ten = mul i32 %button_old, 10
  %button_digit_value = sub i32 %button_char, 48
  %button_next = add i32 %button_times_ten, %button_digit_value
  store i32 %button_next, ptr %button_value, align 4
  br label %button_digit

button_separator:
  %button_has_separator = icmp eq i32 %button_char, 59
  br i1 %button_has_separator, label %x_start, label %seek_escape

x_start:
  store i32 0, ptr %x_value, align 4
  br label %x_digit

x_digit:
  %x_char = call i32 @sollang_linux_mouse_read_byte(ptr %context)
  %x_is_digit_low = icmp sge i32 %x_char, 48
  %x_is_digit_high = icmp sle i32 %x_char, 57
  %x_is_digit = and i1 %x_is_digit_low, %x_is_digit_high
  br i1 %x_is_digit, label %x_accumulate, label %x_separator

x_accumulate:
  %x_old = load i32, ptr %x_value, align 4
  %x_times_ten = mul i32 %x_old, 10
  %x_digit_value = sub i32 %x_char, 48
  %x_next = add i32 %x_times_ten, %x_digit_value
  store i32 %x_next, ptr %x_value, align 4
  br label %x_digit

x_separator:
  %x_has_separator = icmp eq i32 %x_char, 59
  br i1 %x_has_separator, label %y_start, label %seek_escape

y_start:
  store i32 0, ptr %y_value, align 4
  br label %y_digit

y_digit:
  %y_char = call i32 @sollang_linux_mouse_read_byte(ptr %context)
  %y_is_digit_low = icmp sge i32 %y_char, 48
  %y_is_digit_high = icmp sle i32 %y_char, 57
  %y_is_digit = and i1 %y_is_digit_low, %y_is_digit_high
  br i1 %y_is_digit, label %y_accumulate, label %finish_event

y_accumulate:
  %y_old = load i32, ptr %y_value, align 4
  %y_times_ten = mul i32 %y_old, 10
  %y_digit_value = sub i32 %y_char, 48
  %y_next = add i32 %y_times_ten, %y_digit_value
  store i32 %y_next, ptr %y_value, align 4
  br label %y_digit

finish_event:
  %is_press = icmp eq i32 %y_char, 77
  %is_release = icmp eq i32 %y_char, 109
  %valid_final = or i1 %is_press, %is_release
  br i1 %valid_final, label %classify, label %seek_escape

classify:
  %raw_button = load i32, ptr %button_value, align 4
  %raw_x = load i32, ptr %x_value, align 4
  %raw_y = load i32, ptr %y_value, align 4
  %x = sub i32 %raw_x, 1
  %y = sub i32 %raw_y, 1
  %wheel_bit = and i32 %raw_button, 64
  %is_wheel = icmp ne i32 %wheel_bit, 0
  br i1 %is_wheel, label %wheel, label %non_wheel

wheel:
  %wheel_direction = and i32 %raw_button, 1
  %wheel_down = icmp ne i32 %wheel_direction, 0
  %delta = select i1 %wheel_down, i32 -120, i32 120
  call void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 %delta, i32 -1, i32 3)
  br label %seek_escape

non_wheel:
  %motion_bit = and i32 %raw_button, 32
  %is_motion = icmp ne i32 %motion_bit, 0
  br i1 %is_motion, label %move, label %button

move:
  call void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 0, i32 -1, i32 0)
  br label %seek_escape

button:
  %button_index = and i32 %raw_button, 3
  %kind = select i1 %is_release, i32 2, i32 1
  call void @sollang_linux_mouse_enqueue(ptr %context, i32 %x, i32 %y, i32 0, i32 %button_index, i32 %kind)
  br label %seek_escape

done:
  call void @sollang_linux_mouse_signal(ptr %context)
  ret ptr null
}

define internal ptr @sollang_mouse_event_stream_create(i32 %requested_capacity, i32 %overflow) #0 {
entry:
  %capacity_low = icmp slt i32 %requested_capacity, 2
  %capacity_high = icmp sgt i32 %requested_capacity, 65536
  %capacity_invalid = or i1 %capacity_low, %capacity_high
  %overflow_invalid = icmp ugt i32 %overflow, 2
  %invalid = or i1 %capacity_invalid, %overflow_invalid
  br i1 %invalid, label %fail, label %tty

tty:
  %interactive = call i32 @isatty(i32 0)
  %is_tty = icmp ne i32 %interactive, 0
  br i1 %is_tty, label %allocate_context, label %fail

allocate_context:
  %context = call ptr @sollang_alloc(i64 64)
  %context_ok = icmp ne ptr %context, null
  br i1 %context_ok, label %allocate_buffer, label %fail

allocate_buffer:
  %capacity64 = zext i32 %requested_capacity to i64
  %buffer_bytes = mul i64 %capacity64, 20
  %buffer = call ptr @sollang_alloc(i64 %buffer_bytes)
  %buffer_ok = icmp ne ptr %buffer, null
  br i1 %buffer_ok, label %allocate_termios, label %free_context

allocate_termios:
  %original = call ptr @sollang_alloc(i64 64)
  %original_ok = icmp ne ptr %original, null
  br i1 %original_ok, label %read_termios, label %free_buffer

read_termios:
  %got_termios = call i32 @tcgetattr(i32 0, ptr %original)
  %termios_ok = icmp eq i32 %got_termios, 0
  br i1 %termios_ok, label %configure_termios, label %free_termios

configure_termios:
  %current = alloca [64 x i8], align 8
  call void @llvm.memcpy.p0.p0.i64(ptr %current, ptr %original, i64 64, i1 false)
  %lflag_address = getelementptr i8, ptr %current, i64 12
  %lflag = load i32, ptr %lflag_address, align 4
  %raw_lflag = and i32 %lflag, -11
  store i32 %raw_lflag, ptr %lflag_address, align 4
  %vtime = getelementptr i8, ptr %current, i64 22
  store i8 0, ptr %vtime, align 1
  %vmin = getelementptr i8, ptr %current, i64 23
  store i8 1, ptr %vmin, align 1
  %set_termios = call i32 @tcsetattr(i32 0, i32 0, ptr %current)
  %termios_set = icmp eq i32 %set_termios, 0
  br i1 %termios_set, label %create_event, label %free_termios

create_event:
  %event_fd = call i32 @eventfd(i32 0, i32 0)
  %event_ok = icmp sge i32 %event_fd, 0
  br i1 %event_ok, label %initialize, label %restore

initialize:
  store i32 %requested_capacity, ptr %context, align 4
  %policy_address = getelementptr i8, ptr %context, i64 4
  store i32 %overflow, ptr %policy_address, align 4
  %head_address = getelementptr i8, ptr %context, i64 8
  store i32 0, ptr %head_address, align 4
  %tail_address = getelementptr i8, ptr %context, i64 12
  store i32 0, ptr %tail_address, align 4
  %count_address = getelementptr i8, ptr %context, i64 16
  store i32 0, ptr %count_address, align 4
  %cancel_address = getelementptr i8, ptr %context, i64 20
  store atomic i32 0, ptr %cancel_address release, align 4
  %lock_address = getelementptr i8, ptr %context, i64 24
  store atomic i32 0, ptr %lock_address release, align 4
  %event_address = getelementptr i8, ptr %context, i64 28
  store i32 %event_fd, ptr %event_address, align 4
  %buffer_address = getelementptr i8, ptr %context, i64 40
  store ptr %buffer, ptr %buffer_address, align 8
  %termios_address = getelementptr i8, ptr %context, i64 48
  store ptr %original, ptr %termios_address, align 8
  %enabled = call i64 @write(i32 1, ptr @sollang_mouse_enable, i64 16)
  %thread_slot = alloca i64, align 8
  %created = call i32 @pthread_create(ptr %thread_slot, ptr null, ptr @sollang_linux_mouse_worker, ptr %context)
  %thread_ok = icmp eq i32 %created, 0
  br i1 %thread_ok, label %ready, label %close_event

ready:
  %thread = load i64, ptr %thread_slot, align 8
  %thread_address = getelementptr i8, ptr %context, i64 32
  store i64 %thread, ptr %thread_address, align 8
  ret ptr %context

close_event:
  %closed_event = call i32 @close(i32 %event_fd)
  br label %restore

restore:
  %restored = call i32 @tcsetattr(i32 0, i32 0, ptr %original)
  br label %free_termios

free_termios:
  call void @sollang_free(ptr %original)
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
  %lock_address = getelementptr i8, ptr %context, i64 24
  %lock_result = cmpxchg ptr %lock_address, i32 0, i32 1 acquire monotonic, align 4
  %lock_acquired = extractvalue { i32, i1 } %lock_result, 1
  br i1 %lock_acquired, label %queue_state, label %queue_lock

queue_state:
  %count_address = getelementptr i8, ptr %context, i64 16
  %count = load i32, ptr %count_address, align 4
  %available = icmp ugt i32 %count, 0
  br i1 %available, label %read, label %unlock_empty

unlock_empty:
  store atomic i32 0, ptr %lock_address release, align 4
  %cancel_address = getelementptr i8, ptr %context, i64 20
  %cancelled = load atomic i32, ptr %cancel_address acquire, align 4
  %active = icmp eq i32 %cancelled, 0
  br i1 %active, label %wait, label %closed

wait:
  %counter = alloca i64, align 8
  %event_address = getelementptr i8, ptr %context, i64 28
  %event_fd = load i32, ptr %event_address, align 4
  %read_signal = call i64 @read(i32 %event_fd, ptr %counter, i64 8)
  br label %queue_lock

read:
  %capacity = load i32, ptr %context, align 4
  %head_address = getelementptr i8, ptr %context, i64 8
  %head = load i32, ptr %head_address, align 4
  %head64 = zext i32 %head to i64
  %offset = mul i64 %head64, 20
  %buffer_address = getelementptr i8, ptr %context, i64 40
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
  %cancel_address = getelementptr i8, ptr %context, i64 20
  store atomic i32 1, ptr %cancel_address release, align 4
  call void @sollang_linux_mouse_signal(ptr %context)
  br i1 %destroy, label %join_worker, label %cancelled_only

cancelled_only:
  ret void

join_worker:
  %thread_address = getelementptr i8, ptr %context, i64 32
  %thread = load i64, ptr %thread_address, align 8
  %joined = call i32 @pthread_join(i64 %thread, ptr null)
  %disabled = call i64 @write(i32 1, ptr @sollang_mouse_disable, i64 16)
  %termios_address = getelementptr i8, ptr %context, i64 48
  %original = load ptr, ptr %termios_address, align 8
  %restored = call i32 @tcsetattr(i32 0, i32 0, ptr %original)
  %event_address = getelementptr i8, ptr %context, i64 28
  %event_fd = load i32, ptr %event_address, align 4
  %closed_event = call i32 @close(i32 %event_fd)
  %buffer_address = getelementptr i8, ptr %context, i64 40
  %buffer = load ptr, ptr %buffer_address, align 8
  call void @sollang_free(ptr %original)
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

define dso_local i32 @main(i32 %argc, ptr %argv) local_unnamed_addr {
entry:
  %written = alloca i32, align 4
  %read = alloca i32, align 4
  %ok_state = alloca i1, align 1
  %enum_init_slot0 = alloca %sollang.enum.46, align 8
  %enum_match_slot6 = alloca %sollang.enum.2611, align 8
  %enum_init_slot14 = alloca %sollang.enum.46, align 8
  %enum_match_slot20 = alloca %sollang.enum.2611, align 8
  %stream_cancelled53 = alloca i1, align 1
  %stream_element_address54 = alloca %sollang.struct.44, align 8
  %enum_match_slot70 = alloca %sollang.enum.2611, align 8
  %enum_match_slot85 = alloca %sollang.enum.2611, align 8
  store i1 true, ptr %ok_state, align 1
  %stdin = inttoptr i64 0 to ptr
  %stdout = inttoptr i64 1 to ptr
  %stdout_is_tty_status = call i32 @isatty(i32 1)
  %stdout_is_tty = icmp ne i32 %stdout_is_tty_status, 0
  store i1 %stdout_is_tty, ptr @sollang_stdout_line_buffered, align 1
  store %sollang.enum.46 zeroinitializer, ptr %enum_init_slot0, align 8
  %enum_tag_addr1 = getelementptr inbounds %sollang.enum.46, ptr %enum_init_slot0, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr1, align 4
  %enum_value2 = load %sollang.enum.46, ptr %enum_init_slot0, align 8
  %struct_call3 = call %sollang.enum.2611 @sollang_fn_sys_input_mouse_source(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, i32 2, %sollang.enum.46 %enum_value2)
  %enum_tag4 = extractvalue %sollang.enum.2611 %struct_call3, 0
  %enum_matches5 = icmp eq i32 %enum_tag4, 0
  br i1 %enum_matches5, label %bb_enum_when_arm1, label %bb_enum_when_next2
bb_enum_when_arm1:
  store %sollang.enum.2611 %struct_call3, ptr %enum_match_slot6, align 8
  %enum_payload_addr7 = getelementptr inbounds %sollang.enum.2611, ptr %enum_match_slot6, i32 0, i32 1
  %enum_payload8 = load %sollang.struct.1437, ptr %enum_payload_addr7, align 8
  %mouse_event_capacity9 = extractvalue %sollang.struct.1437 %enum_payload8, 0
  %mouse_event_overflow_value10 = extractvalue %sollang.struct.1437 %enum_payload8, 1
  %mouse_event_overflow11 = extractvalue %sollang.enum.46 %mouse_event_overflow_value10, 0
  %mouse_event_context12 = call ptr @sollang_mouse_event_stream_create(i32 %mouse_event_capacity9, i32 %mouse_event_overflow11)
  %mouse_event_stream_created13 = icmp ne ptr %mouse_event_context12, null
  br i1 %mouse_event_stream_created13, label %bb_mouse_event_stream_create_ok3, label %bb_mouse_event_stream_create_fail4

bb_mouse_event_stream_create_fail4:
  call void @llvm.trap()
  unreachable

bb_mouse_event_stream_create_ok3:
  store %sollang.enum.46 zeroinitializer, ptr %enum_init_slot14, align 8
  %enum_tag_addr15 = getelementptr inbounds %sollang.enum.46, ptr %enum_init_slot14, i32 0, i32 0
  store i32 0, ptr %enum_tag_addr15, align 4
  %enum_value16 = load %sollang.enum.46, ptr %enum_init_slot14, align 8
  %struct_call17 = call %sollang.enum.2611 @sollang_fn_sys_input_mouse_source(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, i32 2, %sollang.enum.46 %enum_value16)
  %enum_tag18 = extractvalue %sollang.enum.2611 %struct_call17, 0
  %enum_matches19 = icmp eq i32 %enum_tag18, 0
  br i1 %enum_matches19, label %bb_enum_when_arm6, label %bb_enum_when_next7
bb_enum_when_arm6:
  store %sollang.enum.2611 %struct_call17, ptr %enum_match_slot20, align 8
  %enum_payload_addr21 = getelementptr inbounds %sollang.enum.2611, ptr %enum_match_slot20, i32 0, i32 1
  %enum_payload22 = load %sollang.struct.1437, ptr %enum_payload_addr21, align 8
  %mouse_event_capacity23 = extractvalue %sollang.struct.1437 %enum_payload22, 0
  %mouse_event_overflow_value24 = extractvalue %sollang.struct.1437 %enum_payload22, 1
  %mouse_event_overflow25 = extractvalue %sollang.enum.46 %mouse_event_overflow_value24, 0
  %mouse_event_context26 = call ptr @sollang_mouse_event_stream_create(i32 %mouse_event_capacity23, i32 %mouse_event_overflow25)
  %mouse_event_stream_created27 = icmp ne ptr %mouse_event_context26, null
  br i1 %mouse_event_stream_created27, label %bb_mouse_event_stream_create_ok8, label %bb_mouse_event_stream_create_fail9

bb_mouse_event_stream_create_fail9:
  call void @llvm.trap()
  unreachable

bb_mouse_event_stream_create_ok8:
  %stream_with_context28 = insertvalue %sollang.event_stream poison, ptr %mouse_event_context12, 0
  %stream_with_next29 = insertvalue %sollang.event_stream %stream_with_context28, ptr @sollang_mouse_event_stream_next, 1
  %stream_with_drop30 = insertvalue %sollang.event_stream %stream_with_next29, ptr @sollang_mouse_event_stream_drop, 2
  %product_init31 = insertvalue %sollang.struct.2705 poison, %sollang.event_stream %stream_with_drop30, 0
  %stream_with_context32 = insertvalue %sollang.event_stream poison, ptr %mouse_event_context26, 0
  %stream_with_next33 = insertvalue %sollang.event_stream %stream_with_context32, ptr @sollang_mouse_event_stream_next, 1
  %stream_with_drop34 = insertvalue %sollang.event_stream %stream_with_next33, ptr @sollang_mouse_event_stream_drop, 2
  %product_init35 = insertvalue %sollang.struct.2705 %product_init31, %sollang.event_stream %stream_with_drop34, 1
  %stream_join_context_size_pointer36 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr null, i32 1
  %stream_join_context_size37 = ptrtoint ptr %stream_join_context_size_pointer36 to i64
  %stream_join_context38 = call ptr @sollang_alloc(i64 %stream_join_context_size37)
  %stream_join_context_allocated39 = icmp ne ptr %stream_join_context38, null
  br i1 %stream_join_context_allocated39, label %bb_stream_join_context_alloc_ok10, label %bb_stream_join_context_alloc_fail11

bb_stream_join_context_alloc_fail11:
  call void @llvm.trap()
  unreachable

bb_stream_join_context_alloc_ok10:
  %stream_join_source40 = extractvalue %sollang.struct.2705 %product_init35, 0
  %stream_join_context_input41 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %stream_join_context38, i32 0, i32 0
  store %sollang.event_stream %stream_join_source40, ptr %stream_join_context_input41, align 8
  %stream_join_source42 = extractvalue %sollang.struct.2705 %product_init35, 1
  %stream_join_context_input43 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %stream_join_context38, i32 0, i32 1
  store %sollang.event_stream %stream_join_source42, ptr %stream_join_context_input43, align 8
  %stream_join_item_size_pointer44 = getelementptr %sollang.struct.44, ptr null, i32 1
  %stream_join_item_size45 = ptrtoint ptr %stream_join_item_size_pointer44 to i64
  %stream_join_item_size_pointer46 = getelementptr %sollang.struct.44, ptr null, i32 1
  %stream_join_item_size47 = ptrtoint ptr %stream_join_item_size_pointer46 to i64
  %stream_join_item_size_larger48 = icmp ugt i64 %stream_join_item_size47, %stream_join_item_size45
  %stream_join_item_size_maximum49 = select i1 %stream_join_item_size_larger48, i64 %stream_join_item_size47, i64 %stream_join_item_size45
  %stream_join_runtime50 = call ptr @sollang_stream_join_runtime_create(i32 2, i64 %stream_join_item_size_maximum49, ptr @sollang_stream_join_0_pull, ptr @sollang_stream_join_0_drop_item, ptr %stream_join_context38)
  %stream_join_runtime_created51 = icmp ne ptr %stream_join_runtime50, null
  br i1 %stream_join_runtime_created51, label %bb_stream_join_runtime_create_ok12, label %bb_stream_join_runtime_create_fail13

bb_stream_join_runtime_create_fail13:
  call void @llvm.trap()
  unreachable

bb_stream_join_runtime_create_ok12:
  %stream_join_runtime_address52 = getelementptr { %sollang.event_stream, %sollang.event_stream, ptr }, ptr %stream_join_context38, i32 0, i32 2
  store ptr %stream_join_runtime50, ptr %stream_join_runtime_address52, align 8
  store i1 false, ptr %stream_cancelled53, align 1
  br label %bb_stream_next14

bb_stream_next14:
  %stream_has_value55 = call i1 @sollang_stream_join_0_next(ptr %stream_join_context38, ptr %stream_element_address54)
  br i1 %stream_has_value55, label %bb_stream_value15, label %bb_stream_done17

bb_stream_value15:
  %stream_element56 = load %sollang.struct.44, ptr %stream_element_address54, align 8
  %field57 = extractvalue %sollang.struct.44 %stream_element56, 0
  %print_integer58 = sext i32 %field57 to i64
  %write59 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer58, ptr %written)
  %is_ok60 = icmp ne i32 %write59, 0
  %previous_ok61 = load i1, ptr %ok_state, align 1
  %ok62 = and i1 %previous_ok61, %is_ok60
  store i1 %ok62, ptr %ok_state, align 1
  %write63 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.0, i64 1, ptr %written)
  %is_ok64 = icmp ne i32 %write63, 0
  %previous_ok65 = load i1, ptr %ok_state, align 1
  %ok66 = and i1 %previous_ok65, %is_ok64
  store i1 %ok66, ptr %ok_state, align 1
  store i1 true, ptr %stream_cancelled53, align 1
  br label %bb_stream_continue16

bb_stream_continue16:
  %stream_cancelled67 = load i1, ptr %stream_cancelled53, align 1
  br i1 %stream_cancelled67, label %bb_stream_done17, label %bb_stream_next14

bb_stream_done17:
  %stream_has_drop68 = icmp ne ptr @sollang_stream_join_0_drop, null
  br i1 %stream_has_drop68, label %bb_stream_drop18, label %bb_stream_drop_done19

bb_stream_drop18:
  call void @sollang_stream_join_0_drop(ptr %stream_join_context38, i1 true)
  br label %bb_stream_drop_done19

bb_stream_drop_done19:
  br label %bb_enum_when_end5
bb_enum_when_next7:
  %enum_matches69 = icmp eq i32 %enum_tag18, 1
  br i1 %enum_matches69, label %bb_enum_when_arm20, label %bb_enum_when_next21
bb_enum_when_arm20:
  store %sollang.enum.2611 %struct_call17, ptr %enum_match_slot70, align 8
  %enum_payload_addr71 = getelementptr inbounds %sollang.enum.2611, ptr %enum_match_slot70, i32 0, i32 1
  %enum_payload72 = load %sollang.struct.1436, ptr %enum_payload_addr71, align 8
  %field73 = extractvalue %sollang.struct.1436 %enum_payload72, 1
  %print_integer74 = sext i32 %field73 to i64
  %write75 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer74, ptr %written)
  %is_ok76 = icmp ne i32 %write75, 0
  %previous_ok77 = load i1, ptr %ok_state, align 1
  %ok78 = and i1 %previous_ok77, %is_ok76
  store i1 %ok78, ptr %ok_state, align 1
  %write79 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.1, i64 1, ptr %written)
  %is_ok80 = icmp ne i32 %write79, 0
  %previous_ok81 = load i1, ptr %ok_state, align 1
  %ok82 = and i1 %previous_ok81, %is_ok80
  store i1 %ok82, ptr %ok_state, align 1
  %stream_has_drop83 = icmp ne ptr @sollang_mouse_event_stream_drop, null
  br i1 %stream_has_drop83, label %bb_stream_drop22, label %bb_stream_drop_done23

bb_stream_drop22:
  call void @sollang_mouse_event_stream_drop(ptr %mouse_event_context12, i1 true)
  br label %bb_stream_drop_done23

bb_stream_drop_done23:
  br label %bb_enum_when_end5
bb_enum_when_next21:
  call void @llvm.trap()
  unreachable
bb_enum_when_end5:
  br label %bb_enum_when_end0
bb_enum_when_next2:
  %enum_matches84 = icmp eq i32 %enum_tag4, 1
  br i1 %enum_matches84, label %bb_enum_when_arm24, label %bb_enum_when_next25
bb_enum_when_arm24:
  store %sollang.enum.2611 %struct_call3, ptr %enum_match_slot85, align 8
  %enum_payload_addr86 = getelementptr inbounds %sollang.enum.2611, ptr %enum_match_slot85, i32 0, i32 1
  %enum_payload87 = load %sollang.struct.1436, ptr %enum_payload_addr86, align 8
  %field88 = extractvalue %sollang.struct.1436 %enum_payload87, 1
  %print_integer89 = sext i32 %field88 to i64
  %write90 = call i32 @sollang_write_i64(ptr %stdout, i64 %print_integer89, ptr %written)
  %is_ok91 = icmp ne i32 %write90, 0
  %previous_ok92 = load i1, ptr %ok_state, align 1
  %ok93 = and i1 %previous_ok92, %is_ok91
  store i1 %ok93, ptr %ok_state, align 1
  %write94 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.2, i64 1, ptr %written)
  %is_ok95 = icmp ne i32 %write94, 0
  %previous_ok96 = load i1, ptr %ok_state, align 1
  %ok97 = and i1 %previous_ok96, %is_ok95
  store i1 %ok97, ptr %ok_state, align 1
  br label %bb_enum_when_end0
bb_enum_when_next25:
  call void @llvm.trap()
  unreachable
bb_enum_when_end0:
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %final_ok98 = load i1, ptr %ok_state, align 1
  %exit99 = select i1 %final_ok98, i32 0, i32 1
  ret i32 %exit99
}

attributes #0 = { nounwind }
