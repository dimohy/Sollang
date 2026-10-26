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
%sollang.struct.32 = type { %sollang.dynamic_int_array, %sollang.text, i1, %sollang.dynamic_int_array, i1, %sollang.enum.1583, %sollang.enum.1584, %sollang.enum.1584 }
%sollang.struct.33 = type { %sollang.text, %sollang.text }
%sollang.struct.34 = type { %sollang.dynamic_int_array, %sollang.enum.35 }
%sollang.struct.43 = type { i32, i32 }
%sollang.struct.44 = type { i32, i32, i32, i32, %sollang.enum.45 }
%sollang.struct.1024 = type { %sollang.enum.1449 }
%sollang.struct.1025 = type {  }
%sollang.struct.1026 = type { i32, i1 }
%sollang.struct.1027 = type { i32, i32 }
%sollang.struct.1028 = type { %sollang.enum.1455, i64 }
%sollang.struct.1029 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1030 = type { %sollang.struct.1029 }
%sollang.struct.1031 = type { i32, i32, i32 }
%sollang.struct.1032 = type { %sollang.struct.1029, %sollang.enum.1453, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, i32, i32, i32, i32, %sollang.dynamic_int_array, i1, %sollang.struct.1031, i32, %sollang.struct.1184, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, i32, i32, %sollang.dynamic_int_array, i32, i1, %sollang.struct.1028 }
%sollang.struct.1033 = type { i32, i32, i32, i32, i32, i32, i32, i32 }
%sollang.struct.1034 = type { %sollang.struct.1033, %sollang.enum.1454, i32, i32, i32, i32, i32, i32, %sollang.struct.1184, %sollang.dynamic_int_array }
%sollang.struct.1035 = type { i32 }
%sollang.struct.1036 = type { %sollang.text, %sollang.text, i32, i64, i32, i32 }
%sollang.struct.1037 = type { i64, %sollang.enum.2153, %sollang.enum.1456, %sollang.enum.1457, %sollang.enum.2153, i64, %sollang.enum.2154 }
%sollang.struct.1038 = type { i64, i64, i64, i1 }
%sollang.struct.1039 = type { i64, i64, i64 }
%sollang.struct.1040 = type { i64 }
%sollang.struct.1041 = type { %sollang.struct.1040, %sollang.enum.1460 }
%sollang.struct.1042 = type { %sollang.enum.1487, i64 }
%sollang.struct.1043 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1044 = type { %sollang.struct.1043 }
%sollang.struct.1045 = type { i32, i32, i32, i32, i32, i32, i1 }
%sollang.struct.1046 = type { i32, i32, i32, i32, i32, i32, %sollang.enum.1486, %sollang.struct.1102, %sollang.struct.1060, %sollang.struct.1079, i32, i1, i32, i32, i32, %sollang.dynamic_int_array, i1, %sollang.struct.1042 }
%sollang.struct.1047 = type { i32, i32 }
%sollang.struct.1048 = type { i32, i32 }
%sollang.struct.1049 = type { i32, i32 }
%sollang.struct.1050 = type { i1, i64 }
%sollang.struct.1051 = type { %sollang.enum.1464, i64 }
%sollang.struct.1052 = type { i32, i32, i32 }
%sollang.struct.1053 = type { %sollang.struct.1071, i32, i32, i32, i32 }
%sollang.struct.1054 = type { %sollang.dynamic_int_array, %sollang.struct.1098 }
%sollang.struct.1055 = type { %sollang.struct.1071, %sollang.struct.1106, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32, %sollang.enum.1461, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.1461 }
%sollang.struct.1056 = type { %sollang.dynamic_int_array }
%sollang.struct.1057 = type { i32, %sollang.struct.1098 }
%sollang.struct.1058 = type { %sollang.enum.1477, i64 }
%sollang.struct.1059 = type { i32, i32, i32, i32, i32, i32 }
%sollang.struct.1060 = type { %sollang.struct.1089, %sollang.struct.1082, %sollang.struct.1110, i32, i32, i32 }
%sollang.struct.1061 = type { %sollang.enum.1465, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.1488, i32, i32 }
%sollang.struct.1062 = type { i32, i32, i32, i32, i32, %sollang.enum.1488, i32, i32 }
%sollang.struct.1063 = type { %sollang.struct.1089, i32, i32, %sollang.enum.1468, i32, i32, i32, i32, %sollang.enum.1467, %sollang.enum.1467 }
%sollang.struct.1064 = type { %sollang.struct.1060, %sollang.struct.1063, %sollang.enum.1470, i32, %sollang.dynamic_int_array, i32, i32, %sollang.dynamic_int_array }
%sollang.struct.1065 = type { %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, i32 }
%sollang.struct.1066 = type { %sollang.struct.1065, %sollang.struct.1084, %sollang.enum.1472, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1067 = type { %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1068 = type { %sollang.struct.1067, %sollang.struct.1112, %sollang.enum.1474, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1069 = type { i32, i32, %sollang.enum.1467, %sollang.enum.1467 }
%sollang.struct.1070 = type { i32, i32, %sollang.struct.1098 }
%sollang.struct.1071 = type { %sollang.dynamic_int_array, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.struct.1098 }
%sollang.struct.1072 = type { i32, %sollang.struct.1098 }
%sollang.struct.1073 = type { %sollang.struct.1069, %sollang.struct.1098 }
%sollang.struct.1074 = type { %sollang.enum.1487, i64 }
%sollang.struct.1075 = type { i32, i32, i32 }
%sollang.struct.1076 = type { %sollang.struct.1064, %sollang.struct.1092 }
%sollang.struct.1077 = type { %sollang.struct.1066, %sollang.struct.1092 }
%sollang.struct.1078 = type { %sollang.struct.1068, %sollang.struct.1092 }
%sollang.struct.1079 = type { %sollang.struct.1060, %sollang.struct.1075, i32, %sollang.dynamic_int_array, %sollang.enum.1478 }
%sollang.struct.1080 = type { %sollang.enum.1485, i64 }
%sollang.struct.1081 = type { i32, i32, i32 }
%sollang.struct.1082 = type { %sollang.struct.1089, i32, i32 }
%sollang.struct.1083 = type { %sollang.dynamic_int_array, i32, %sollang.struct.1098 }
%sollang.struct.1084 = type { %sollang.struct.1089, i32, i32, i32, %sollang.enum.1481, i32, i32, i32, %sollang.dynamic_int_array, %sollang.enum.1482 }
%sollang.struct.1085 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1086 = type { i32, %sollang.struct.1098 }
%sollang.struct.1087 = type { %sollang.enum.1494, i64 }
%sollang.struct.1088 = type { i32, i32 }
%sollang.struct.1089 = type { %sollang.struct.1096, i32 }
%sollang.struct.1090 = type { %sollang.struct.1097, %sollang.struct.1098 }
%sollang.struct.1091 = type { %sollang.enum.1489, i32 }
%sollang.struct.1092 = type { %sollang.struct.1096, i32, i32, i32, %sollang.enum.1491, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.struct.1091, %sollang.dynamic_int_array, i32, i32, i32, %sollang.enum.1492, i32, i32, i32, i32, i32, i32, %sollang.enum.1492 }
%sollang.struct.1093 = type { i32, %sollang.struct.1098 }
%sollang.struct.1094 = type { %sollang.enum.1497, i64 }
%sollang.struct.1095 = type { i32, i32 }
%sollang.struct.1096 = type { i32, i32 }
%sollang.struct.1097 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1098 = type { i32, i32 }
%sollang.struct.1099 = type { i32, %sollang.struct.1098 }
%sollang.struct.1100 = type { i32, i32 }
%sollang.struct.1101 = type { i32 }
%sollang.struct.1102 = type { i64, i32, i32 }
%sollang.struct.1103 = type { i32, i32 }
%sollang.struct.1104 = type { %sollang.enum.1499, i64 }
%sollang.struct.1105 = type { i32 }
%sollang.struct.1106 = type { i32 }
%sollang.struct.1107 = type { i32, %sollang.enum.1498, i32 }
%sollang.struct.1108 = type { %sollang.enum.1501, i64 }
%sollang.struct.1109 = type { i32, i32, i32, i32 }
%sollang.struct.1110 = type { %sollang.struct.1089, i32, i32, i32 }
%sollang.struct.1111 = type { %sollang.dynamic_int_array, %sollang.struct.1098 }
%sollang.struct.1112 = type { %sollang.struct.1089, i32, i32, i32, i32, i32, i32, i32, i32, %sollang.dynamic_int_array }
%sollang.struct.1113 = type { %sollang.dynamic_int_array }
%sollang.struct.1114 = type { %sollang.enum.1503, i64 }
%sollang.struct.1115 = type { i32, i32 }
%sollang.struct.1116 = type { %sollang.struct.1115 }
%sollang.struct.1117 = type { i32, i32 }
%sollang.struct.1118 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.1124 }
%sollang.struct.1119 = type { %sollang.struct.1116, i32, i32, i32, i32, i32, i32, %sollang.enum.1502, i32, i32, i32, i32, i32, i32, i32, i1, i32, i32, i32, i32, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.struct.1129, %sollang.struct.1129, %sollang.struct.1129, i32, i32, i32, i32, i32, i32, i32, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i32, i1, %sollang.struct.1114, i1, i1 }
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
%sollang.struct.1138 = type { %sollang.enum.1505, i64 }
%sollang.struct.1139 = type { %sollang.dynamic_int_array, %sollang.struct.1149, i1, %sollang.struct.1145, %sollang.struct.1145, %sollang.struct.1145, i1, i1, i1, i32, i32, i32 }
%sollang.struct.1140 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1141 = type { i1 }
%sollang.struct.1142 = type { %sollang.struct.1140, %sollang.struct.1141 }
%sollang.struct.1143 = type { i32, i32, i32, i32, i1, i1, %sollang.struct.1186 }
%sollang.struct.1144 = type { i32, i32, i32, i32, i32, i32, i32, i32, %sollang.enum.1504, i64, i32, i32, i32, i32, i32, i1, i64, i1, %sollang.struct.1186, i32, i32, i32, i32, i1, %sollang.dynamic_int_array, %sollang.struct.1149, i1, %sollang.struct.1145, %sollang.struct.1145, %sollang.struct.1145, i1, i1, i1, i32, i32, i32, %sollang.dynamic_int_array, i1, %sollang.struct.1138 }
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
%sollang.struct.1160 = type { %sollang.enum.1511 }
%sollang.struct.1161 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1162 = type { %sollang.struct.1164, %sollang.struct.1164 }
%sollang.struct.1163 = type { i8 }
%sollang.struct.1164 = type { %sollang.int_slice, %sollang.int_slice, i32, i64 }
%sollang.struct.1165 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1166 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1167 = type { %sollang.int_slice, %sollang.int_slice, %sollang.int_slice }
%sollang.struct.1168 = type { %sollang.enum.1513, i64 }
%sollang.struct.1169 = type { i32, i32 }
%sollang.struct.1170 = type { i32, i32 }
%sollang.struct.1171 = type { %sollang.enum.1514, %sollang.enum.1515 }
%sollang.struct.1172 = type { %sollang.struct.1171, i32, i32, i64, i8, i8, i32 }
%sollang.struct.1173 = type { %sollang.struct.1171, i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.1174 = type { i32, i32, i64, i32, i32, i32, i32, i64, i64, i64, i64, i32, i1 }
%sollang.struct.1175 = type { %sollang.enum.1517, i64 }
%sollang.struct.1176 = type { %sollang.enum.1516, i64 }
%sollang.struct.1177 = type { %sollang.enum.1516, i32, i32 }
%sollang.struct.1178 = type { %sollang.enum.1518, i64 }
%sollang.struct.1179 = type { i32, i32 }
%sollang.struct.1180 = type { i32, i32 }
%sollang.struct.1181 = type { i1 }
%sollang.struct.1182 = type { %sollang.struct.1181, i32, i32, i64 }
%sollang.struct.1183 = type { i32, i32, i64, i32, i64 }
%sollang.struct.1184 = type { %sollang.enum.1519, i32 }
%sollang.struct.1185 = type { i64 }
%sollang.struct.1186 = type { i64, i64, i64, i64, i64, i64, i64, %sollang.int_slice, i32 }
%sollang.struct.1187 = type { %sollang.enum.1520, i64 }
%sollang.struct.1188 = type { i32, %sollang.enum.1522 }
%sollang.struct.1189 = type { i32, i32 }
%sollang.struct.1190 = type { %sollang.dynamic_int_array, i32, %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1191 = type { %sollang.dynamic_int_array, i32, i32 }
%sollang.struct.1192 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1193 = type { i1 }
%sollang.struct.1194 = type { %sollang.struct.1191, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1195 = type { %sollang.struct.1191, %sollang.dynamic_int_array, %sollang.enum.1523 }
%sollang.struct.1196 = type { %sollang.struct.1192, %sollang.dynamic_int_array, i32 }
%sollang.struct.1197 = type { %sollang.struct.1192, %sollang.dynamic_int_array, %sollang.enum.1523 }
%sollang.struct.1198 = type { %sollang.dynamic_int_array, i32, i32, i32, i1 }
%sollang.struct.1199 = type { %sollang.struct.1198, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1200 = type { %sollang.struct.1198, %sollang.dynamic_int_array, %sollang.enum.1523 }
%sollang.struct.1201 = type { %sollang.struct.1198, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1202 = type { %sollang.struct.1198, %sollang.dynamic_int_array, %sollang.enum.1523 }
%sollang.struct.1203 = type { %sollang.struct.29, i64 }
%sollang.struct.1204 = type { %sollang.struct.30, i64 }
%sollang.struct.1205 = type { %sollang.struct.1203, %sollang.dynamic_int_array, i32, i1 }
%sollang.struct.1206 = type { %sollang.struct.1203, %sollang.dynamic_int_array, %sollang.enum.1581 }
%sollang.struct.1207 = type { %sollang.struct.1204, %sollang.dynamic_int_array, i32 }
%sollang.struct.1208 = type { %sollang.struct.1204, %sollang.dynamic_int_array, %sollang.enum.1581 }
%sollang.struct.1209 = type { %sollang.struct.1362, i64 }
%sollang.struct.1210 = type { %sollang.struct.1355, %sollang.struct.1373 }
%sollang.struct.1211 = type { %sollang.struct.1209, %sollang.dynamic_int_array, i64, i1 }
%sollang.struct.1212 = type { %sollang.struct.1209, %sollang.dynamic_int_array, %sollang.struct.1373 }
%sollang.struct.1213 = type { %sollang.struct.1209, %sollang.dynamic_int_array, i64 }
%sollang.struct.1214 = type { %sollang.struct.1209, %sollang.dynamic_int_array, %sollang.struct.1373 }
%sollang.struct.1215 = type { %sollang.text, %sollang.text }
%sollang.struct.1216 = type { %sollang.text }
%sollang.struct.1217 = type { %sollang.enum.1524, %sollang.text }
%sollang.struct.1218 = type { %sollang.enum.1524 }
%sollang.struct.1219 = type { i8, i8, i8, i8 }
%sollang.struct.1220 = type { %sollang.struct.1219, i16 }
%sollang.struct.1221 = type { i16, i16, i16, i16, i16, i16, i16, i16 }
%sollang.struct.1222 = type { %sollang.struct.1221, i16, i32, i32 }
%sollang.struct.1223 = type { %sollang.enum.1543, i64 }
%sollang.struct.1224 = type { %sollang.enum.1528, i32 }
%sollang.struct.1225 = type { %sollang.enum.1527, i64, i64 }
%sollang.struct.1226 = type { %sollang.enum.1535, i64 }
%sollang.struct.1227 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1228 = type { i64, i64 }
%sollang.struct.1229 = type { %sollang.struct.1228, %sollang.struct.1228 }
%sollang.struct.1230 = type { %sollang.struct.1227 }
%sollang.struct.1231 = type { %sollang.source_text, %sollang.struct.1228, %sollang.struct.1228, %sollang.enum.1529, %sollang.dynamic_int_array, i64 }
%sollang.struct.1232 = type { %sollang.source_text, %sollang.enum.1529, i32, %sollang.struct.1228, %sollang.dynamic_int_array, i64 }
%sollang.struct.1233 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1234 = type { i32, i32, i32, i32, i32 }
%sollang.struct.1235 = type { %sollang.struct.1234 }
%sollang.struct.1236 = type { %sollang.struct.1235, %sollang.text }
%sollang.struct.1237 = type { %sollang.enum.1530, %sollang.struct.1234 }
%sollang.struct.1238 = type { i64, i64, i1 }
%sollang.struct.1239 = type { %sollang.struct.1234, %sollang.enum.1531, %sollang.enum.1532, i64, i64, i64, i64, %sollang.dynamic_int_array, i1, i64, i32 }
%sollang.struct.1240 = type { i1, i64, i1, i1 }
%sollang.struct.1241 = type { %sollang.enum.1526, %sollang.struct.1230, %sollang.struct.1235, i32, i32 }
%sollang.struct.1242 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32 }
%sollang.struct.1243 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32, %sollang.enum.1538, %sollang.enum.1537 }
%sollang.struct.1244 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32, %sollang.enum.1538, %sollang.enum.1537, %sollang.dynamic_int_array, %sollang.struct.1232, i64 }
%sollang.struct.1245 = type { %sollang.struct.1355, %sollang.struct.1230, %sollang.struct.1235, i32, i32, %sollang.dynamic_int_array, i64, %sollang.dynamic_int_array, i64, %sollang.struct.1239, i1, i1, i1 }
%sollang.struct.1246 = type { i32, i32, i32, i32 }
%sollang.struct.1247 = type { %sollang.struct.1246 }
%sollang.struct.1248 = type { %sollang.struct.1246, %sollang.dynamic_int_array, %sollang.text, i32, i32, i1, i1, i1, i64, %sollang.enum.1537, %sollang.enum.1538 }
%sollang.struct.1249 = type { %sollang.dynamic_int_array, i64, %sollang.enum.1537, %sollang.enum.1538 }
%sollang.struct.1250 = type { i32, i32, i32, i32 }
%sollang.struct.1251 = type { %sollang.struct.1250 }
%sollang.struct.1252 = type { %sollang.struct.1250, %sollang.dynamic_int_array, i32, i32, i1, i1, i1, i64, %sollang.enum.1540 }
%sollang.struct.1253 = type { %sollang.dynamic_int_array, i64, %sollang.enum.1540, %sollang.enum.1539 }
%sollang.struct.1254 = type { %sollang.struct.1352, %sollang.struct.1227 }
%sollang.struct.1255 = type { %sollang.struct.1354, %sollang.struct.1230, i32 }
%sollang.struct.1256 = type { %sollang.struct.1355, %sollang.struct.1230, i32, %sollang.dynamic_int_array, i64 }
%sollang.struct.1257 = type { %sollang.struct.1355, %sollang.struct.1230, i32, %sollang.dynamic_int_array, %sollang.struct.1231, i64, %sollang.dynamic_int_array, i64, i1 }
%sollang.struct.1258 = type { %sollang.struct.1355, %sollang.struct.1230, i32, %sollang.dynamic_int_array, %sollang.struct.1231, i64, %sollang.dynamic_int_array, i64, %sollang.struct.1239 }
%sollang.struct.1259 = type { %sollang.enum.1544, i64 }
%sollang.struct.1260 = type { %sollang.int_slice }
%sollang.struct.1261 = type { %sollang.struct.1356, %sollang.enum.1526, i1, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64 }
%sollang.struct.1262 = type { i64, i64, i64, i64 }
%sollang.struct.1263 = type { i64, i64, i32, i32, i32, i64, %sollang.struct.1262 }
%sollang.struct.1264 = type { %sollang.struct.1260, %sollang.enum.1526, %sollang.struct.1263, i1 }
%sollang.struct.1265 = type { %sollang.dynamic_int_array, %sollang.enum.1526, %sollang.enum.1526, i1, i32, %sollang.int_slice, %sollang.int_slice, %sollang.int_slice, %sollang.struct.1275, %sollang.struct.1275, i64, i64, i1, %sollang.int_slice, %sollang.dynamic_int_array, %sollang.int_slice, %sollang.dynamic_int_array, i1, i1, %sollang.dynamic_int_array, %sollang.struct.1328, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, i64, i32, i64, i1, i1, %sollang.struct.1321, %sollang.struct.1303, %sollang.struct.1304, %sollang.struct.1332, %sollang.struct.1334, i64, i64, i64, i64, i64, i64, i8, i64, i64 }
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
%sollang.struct.1276 = type { i64, i1, %sollang.enum.1545 }
%sollang.struct.1277 = type { i64, i1, %sollang.dynamic_int_array }
%sollang.struct.1278 = type { i1, i1, i1, %sollang.struct.1332, %sollang.struct.1333 }
%sollang.struct.1279 = type { i64, i8 }
%sollang.struct.1280 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1281 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1282 = type { %sollang.dynamic_int_array, i64 }
%sollang.struct.1283 = type { i64, %sollang.dynamic_int_array }
%sollang.struct.1284 = type { %sollang.enum.1544, i64 }
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
%sollang.struct.1298 = type { %sollang.enum.1545, i64 }
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
%sollang.struct.1329 = type { i64, i64, %sollang.enum.1546, %sollang.enum.1547 }
%sollang.struct.1330 = type { i64, i64, i64, i1, i64 }
%sollang.struct.1331 = type { i64, i64, i1, i64 }
%sollang.struct.1332 = type { i64, i64, i64, i64, i64 }
%sollang.struct.1333 = type { i64, i64 }
%sollang.struct.1334 = type { i1, i64, i64, i1, i1, i64, i64, i64, i64, i64, i64, i32, %sollang.dynamic_int_array, i32, i32, i32, i32, %sollang.dynamic_int_array, i32, i32, i32 }
%sollang.struct.1335 = type { %sollang.dynamic_int_array }
%sollang.struct.1336 = type { i16, %sollang.dynamic_int_array }
%sollang.struct.1337 = type { %sollang.enum.1548, %sollang.struct.1344, %sollang.int_slice }
%sollang.struct.1338 = type { i8, %sollang.dynamic_int_array, i64 }
%sollang.struct.1339 = type { i16, %sollang.dynamic_int_array, i64 }
%sollang.struct.1340 = type { %sollang.int_slice, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.int_slice, %sollang.dynamic_int_array }
%sollang.struct.1341 = type { %sollang.int_slice, %sollang.dynamic_int_array, %sollang.int_slice }
%sollang.struct.1342 = type { %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1343 = type { %sollang.enum.1549, %sollang.struct.1344 }
%sollang.struct.1344 = type { %sollang.dynamic_int_array }
%sollang.struct.1345 = type { %sollang.struct.1317 }
%sollang.struct.1346 = type { i64, %sollang.dynamic_int_array, i64 }
%sollang.struct.1347 = type { i64 }
%sollang.struct.1348 = type { i64, i64 }
%sollang.struct.1349 = type { i32, %sollang.dynamic_int_array }
%sollang.struct.1350 = type { %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1351 = type { i8, i64, i64, i64 }
%sollang.struct.1352 = type { %sollang.enum.1526, i32, i1 }
%sollang.struct.1353 = type { %sollang.enum.1526, i1 }
%sollang.struct.1354 = type { i64 }
%sollang.struct.1355 = type { i64 }
%sollang.struct.1356 = type { i64 }
%sollang.struct.1357 = type { ptr, i64, i64 }
%sollang.struct.1358 = type { %sollang.dynamic_int_array }
%sollang.struct.1359 = type { i64, %sollang.enum.1553, %sollang.enum.1552 }
%sollang.struct.1360 = type { i64, i1, i1, i1 }
%sollang.struct.1361 = type { i64, i64, i64 }
%sollang.struct.1362 = type { i64 }
%sollang.struct.1363 = type { i64, %sollang.enum.1554, %sollang.dynamic_int_array, i64, i64, %sollang.enum.1555, %sollang.enum.2178, %sollang.enum.2179, %sollang.enum.2153 }
%sollang.struct.1364 = type { %sollang.struct.1362, %sollang.struct.1355, %sollang.struct.1373 }
%sollang.struct.1365 = type { %sollang.struct.1362, %sollang.struct.1355 }
%sollang.struct.1366 = type { %sollang.struct.1362, %sollang.struct.1373 }
%sollang.struct.1367 = type { %sollang.struct.1362, %sollang.struct.1363 }
%sollang.struct.1368 = type { %sollang.struct.1362, %sollang.struct.1363, %sollang.struct.1373 }
%sollang.struct.1369 = type { %sollang.struct.1363, %sollang.struct.1373 }
%sollang.struct.1370 = type { i64, %sollang.dynamic_int_array }
%sollang.struct.1371 = type { %sollang.enum.1526, %sollang.dynamic_int_array, i1 }
%sollang.struct.1372 = type { %sollang.enum.1526, i64, i1 }
%sollang.struct.1373 = type { %sollang.enum.1558, i32 }
%sollang.struct.1374 = type { %sollang.enum.1560, i64 }
%sollang.struct.1375 = type { i32, i32, i32 }
%sollang.struct.1376 = type { %sollang.enum.1559, i64, i64 }
%sollang.struct.1377 = type { %sollang.enum.1559, i64, i1 }
%sollang.struct.1378 = type { %sollang.source_text, i64, i64, i32, i1, %sollang.struct.1375, %sollang.struct.1377 }
%sollang.struct.1379 = type { %sollang.enum.1562, i64, i32 }
%sollang.struct.1380 = type { i32, i32, i32, i32 }
%sollang.struct.1381 = type { i32, i32, i32, i32 }
%sollang.struct.1382 = type { %sollang.enum.1561, i32 }
%sollang.struct.1383 = type { i32, i32, i32, i1 }
%sollang.struct.1384 = type { %sollang.source_text, i64, i64, i32, i32, i1, %sollang.struct.1382, %sollang.struct.1380 }
%sollang.struct.1385 = type { %sollang.struct.1381, i32, i32, i32, i32 }
%sollang.struct.1386 = type { i64, i64, i64, i32, i1, i1 }
%sollang.struct.1387 = type { i32, i32, i32 }
%sollang.struct.1388 = type { %sollang.enum.1563, i64, i64 }
%sollang.struct.1389 = type { %sollang.source_text, i64, i32, i32 }
%sollang.struct.1390 = type { %sollang.enum.1566, i64 }
%sollang.struct.1391 = type { i32, i32, i32, i32 }
%sollang.struct.1392 = type { %sollang.enum.1564, i64, i64, i64, i64, i32, i32 }
%sollang.struct.1393 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1394 = type { %sollang.enum.1565, i64, i64, i1, %sollang.dynamic_int_array, %sollang.dynamic_int_array, %sollang.dynamic_int_array }
%sollang.struct.1395 = type { %sollang.dynamic_int_array, i32 }
%sollang.struct.1396 = type { %sollang.source_text, i64, i64, i8, i32, %sollang.struct.1391, %sollang.dynamic_int_array }
%sollang.struct.1397 = type { %sollang.dynamic_int_array, i32, i32, i32, i8, %sollang.dynamic_int_array }
%sollang.struct.1398 = type { i64, i64, i32 }
%sollang.struct.1399 = type { i32, i32, i32, i32 }
%sollang.struct.1400 = type { %sollang.enum.1567, i64, i64, i64 }
%sollang.struct.1401 = type { i64, i64 }
%sollang.struct.1402 = type { %sollang.source_text, i64, i64, i32, i32, i1, i1, i32, i32 }
%sollang.struct.1403 = type { %sollang.enum.1568, i64, i64, i64, i1, %sollang.enum.1569, i64 }
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
%sollang.struct.1416 = type { %sollang.struct.27, %sollang.enum.1570, %sollang.struct.27 }
%sollang.struct.1417 = type { %sollang.dynamic_int_array, %sollang.struct.27, i64, %sollang.enum.1571 }
%sollang.struct.1418 = type { %sollang.struct.1417, %sollang.struct.1406, %sollang.struct.1406, i64 }
%sollang.struct.1419 = type { %sollang.enum.1572 }
%sollang.struct.1420 = type { %sollang.enum.1576, i64 }
%sollang.struct.1421 = type { i64, i64, i1 }
%sollang.struct.1422 = type { %sollang.struct.1421, %sollang.enum.1573, %sollang.enum.1574, %sollang.struct.1421 }
%sollang.struct.1423 = type { %sollang.source_text, %sollang.struct.1421, %sollang.enum.1575, %sollang.struct.1421, %sollang.struct.1421, %sollang.struct.1421 }
%sollang.struct.1424 = type { i1, i1, i1, i1, i1 }
%sollang.struct.1425 = type { %sollang.enum.1577, i64 }
%sollang.struct.1426 = type { i32, i32 }
%sollang.struct.1427 = type { %sollang.enum.1578 }
%sollang.struct.1428 = type { %sollang.enum.1580, i64 }
%sollang.struct.1429 = type { %sollang.int_slice }
%sollang.struct.1430 = type { i8 }
%sollang.struct.1431 = type { %sollang.struct.1410, %sollang.struct.1163 }
%sollang.struct.1432 = type { %sollang.struct.29, %sollang.dynamic_int_array, i64, i1 }
%sollang.struct.1433 = type { %sollang.struct.29, %sollang.dynamic_int_array, %sollang.enum.1581 }
%sollang.struct.1434 = type { %sollang.struct.30, %sollang.dynamic_int_array, i64 }
%sollang.struct.1435 = type { %sollang.struct.30, %sollang.dynamic_int_array, %sollang.enum.1581 }
%sollang.struct.1436 = type { %sollang.enum.1582, i32 }
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
%sollang.struct.1448 = type { %sollang.dynamic_int_array }
%sollang.enum.35 = type { i32, [0 x i64] }
%sollang.enum.38 = type { i32, [0 x i64] }
%sollang.enum.45 = type { i32, [0 x i64] }
%sollang.enum.46 = type { i32, [0 x i64] }
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
%sollang.enum.1461 = type { i32, [0 x i64] }
%sollang.enum.1462 = type { i32, [1 x i64] }
%sollang.enum.1463 = type { i32, [1 x i64] }
%sollang.enum.1464 = type { i32, [0 x i64] }
%sollang.enum.1465 = type { i32, [0 x i64] }
%sollang.enum.1466 = type { i32, [5 x i64] }
%sollang.enum.1467 = type { i32, [4 x i64] }
%sollang.enum.1468 = type { i32, [0 x i64] }
%sollang.enum.1469 = type { i32, [1 x i64] }
%sollang.enum.1470 = type { i32, [0 x i64] }
%sollang.enum.1471 = type { i32, [1 x i64] }
%sollang.enum.1472 = type { i32, [0 x i64] }
%sollang.enum.1473 = type { i32, [1 x i64] }
%sollang.enum.1474 = type { i32, [0 x i64] }
%sollang.enum.1475 = type { i32, [1 x i64] }
%sollang.enum.1476 = type { i32, [1 x i64] }
%sollang.enum.1477 = type { i32, [0 x i64] }
%sollang.enum.1478 = type { i32, [66 x i64] }
%sollang.enum.1479 = type { i32, [1 x i64] }
%sollang.enum.1480 = type { i32, [1 x i64] }
%sollang.enum.1481 = type { i32, [0 x i64] }
%sollang.enum.1482 = type { i32, [4 x i64] }
%sollang.enum.1483 = type { i32, [1 x i64] }
%sollang.enum.1484 = type { i32, [1 x i64] }
%sollang.enum.1485 = type { i32, [0 x i64] }
%sollang.enum.1486 = type { i32, [0 x i64] }
%sollang.enum.1487 = type { i32, [0 x i64] }
%sollang.enum.1488 = type { i32, [0 x i64] }
%sollang.enum.1489 = type { i32, [0 x i64] }
%sollang.enum.1490 = type { i32, [1 x i64] }
%sollang.enum.1491 = type { i32, [0 x i64] }
%sollang.enum.1492 = type { i32, [4 x i64] }
%sollang.enum.1493 = type { i32, [1 x i64] }
%sollang.enum.1494 = type { i32, [0 x i64] }
%sollang.enum.1495 = type { i32, [1 x i64] }
%sollang.enum.1496 = type { i32, [1 x i64] }
%sollang.enum.1497 = type { i32, [0 x i64] }
%sollang.enum.1498 = type { i32, [0 x i64] }
%sollang.enum.1499 = type { i32, [0 x i64] }
%sollang.enum.1500 = type { i32, [1 x i64] }
%sollang.enum.1501 = type { i32, [0 x i64] }
%sollang.enum.1502 = type { i32, [0 x i64] }
%sollang.enum.1503 = type { i32, [0 x i64] }
%sollang.enum.1504 = type { i32, [0 x i64] }
%sollang.enum.1505 = type { i32, [0 x i64] }
%sollang.enum.1506 = type { i32, [0 x i64] }
%sollang.enum.1507 = type { i32, [0 x i64] }
%sollang.enum.1508 = type { i32, [0 x i64] }
%sollang.enum.1509 = type { i32, [0 x i64] }
%sollang.enum.1510 = type { i32, [3 x i64] }
%sollang.enum.1511 = type { i32, [0 x i64] }
%sollang.enum.1512 = type { i32, [0 x i64] }
%sollang.enum.1513 = type { i32, [0 x i64] }
%sollang.enum.1514 = type { i32, [0 x i64] }
%sollang.enum.1515 = type { i32, [0 x i64] }
%sollang.enum.1516 = type { i32, [0 x i64] }
%sollang.enum.1517 = type { i32, [0 x i64] }
%sollang.enum.1518 = type { i32, [0 x i64] }
%sollang.enum.1519 = type { i32, [0 x i64] }
%sollang.enum.1520 = type { i32, [0 x i64] }
%sollang.enum.1521 = type { i32, [3 x i64] }
%sollang.enum.1522 = type { i32, [0 x i64] }
%sollang.enum.1523 = type { i32, [2 x i64] }
%sollang.enum.1524 = type { i32, [0 x i64] }
%sollang.enum.1525 = type { i32, [2 x i64] }
%sollang.enum.1526 = type { i32, [4 x i64] }
%sollang.enum.1527 = type { i32, [0 x i64] }
%sollang.enum.1528 = type { i32, [0 x i64] }
%sollang.enum.1529 = type { i32, [0 x i64] }
%sollang.enum.1530 = type { i32, [1 x i64] }
%sollang.enum.1531 = type { i32, [0 x i64] }
%sollang.enum.1532 = type { i32, [0 x i64] }
%sollang.enum.1533 = type { i32, [2 x i64] }
%sollang.enum.1534 = type { i32, [7 x i64] }
%sollang.enum.1535 = type { i32, [0 x i64] }
%sollang.enum.1536 = type { i32, [2 x i64] }
%sollang.enum.1537 = type { i32, [0 x i64] }
%sollang.enum.1538 = type { i32, [0 x i64] }
%sollang.enum.1539 = type { i32, [0 x i64] }
%sollang.enum.1540 = type { i32, [0 x i64] }
%sollang.enum.1541 = type { i32, [2 x i64] }
%sollang.enum.1542 = type { i32, [8 x i64] }
%sollang.enum.1543 = type { i32, [0 x i64] }
%sollang.enum.1544 = type { i32, [0 x i64] }
%sollang.enum.1545 = type { i32, [7 x i64] }
%sollang.enum.1546 = type { i32, [0 x i64] }
%sollang.enum.1547 = type { i32, [0 x i64] }
%sollang.enum.1548 = type { i32, [0 x i64] }
%sollang.enum.1549 = type { i32, [0 x i64] }
%sollang.enum.1550 = type { i32, [0 x i64] }
%sollang.enum.1551 = type { i32, [0 x i64] }
%sollang.enum.1552 = type { i32, [0 x i64] }
%sollang.enum.1553 = type { i32, [1 x i64] }
%sollang.enum.1554 = type { i32, [0 x i64] }
%sollang.enum.1555 = type { i32, [0 x i64] }
%sollang.enum.1556 = type { i32, [16 x i64] }
%sollang.enum.1557 = type { i32, [16 x i64] }
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
%sollang.enum.1572 = type { i32, [0 x i64] }
%sollang.enum.1573 = type { i32, [3 x i64] }
%sollang.enum.1574 = type { i32, [1 x i64] }
%sollang.enum.1575 = type { i32, [12 x i64] }
%sollang.enum.1576 = type { i32, [0 x i64] }
%sollang.enum.1577 = type { i32, [0 x i64] }
%sollang.enum.1578 = type { i32, [0 x i64] }
%sollang.enum.1579 = type { i32, [0 x i64] }
%sollang.enum.1580 = type { i32, [0 x i64] }
%sollang.enum.1581 = type { i32, [2 x i64] }
%sollang.enum.1582 = type { i32, [0 x i64] }
%sollang.enum.1583 = type { i32, [2 x i64] }
%sollang.enum.1584 = type { i32, [2 x i64] }
%sollang.enum.1585 = type { i32, [1 x i64] }
%sollang.enum.2153 = type { i32, [1 x i64] }
%sollang.enum.2154 = type { i32, [7 x i64] }
%sollang.enum.2178 = type { i32, [1 x i64] }
%sollang.enum.2179 = type { i32, [2 x i64] }
%sollang.enum.2188 = type { i32, [2 x i64] }
%sollang.enum.2191 = type { i32, [1 x i64] }
%sollang.enum.2192 = type { i32, [1 x i64] }
%sollang.enum.2193 = type { i32, [3 x i64] }
%sollang.enum.2194 = type { i32, [44 x i64] }
%sollang.enum.2195 = type { i32, [2 x i64] }
%sollang.enum.2196 = type { i32, [13 x i64] }
%sollang.enum.2197 = type { i32, [2 x i64] }
%sollang.enum.2199 = type { i32, [1 x i64] }
%sollang.enum.2202 = type { i32, [3 x i64] }
%sollang.enum.2203 = type { i32, [3 x i64] }
%sollang.enum.2204 = type { i32, [4 x i64] }
%sollang.enum.2205 = type { i32, [105 x i64] }
%sollang.enum.2206 = type { i32, [2 x i64] }
%sollang.enum.2207 = type { i32, [3 x i64] }
%sollang.enum.2208 = type { i32, [9 x i64] }
%sollang.enum.2209 = type { i32, [26 x i64] }
%sollang.enum.2210 = type { i32, [81 x i64] }
%sollang.enum.2211 = type { i32, [2 x i64] }
%sollang.enum.2214 = type { i32, [26 x i64] }
%sollang.enum.2215 = type { i32, [4 x i64] }
%sollang.enum.2216 = type { i32, [2 x i64] }
%sollang.enum.2217 = type { i32, [2 x i64] }
%sollang.enum.2218 = type { i32, [2 x i64] }
%sollang.enum.2219 = type { i32, [50 x i64] }
%sollang.enum.2220 = type { i32, [2 x i64] }
%sollang.enum.2221 = type { i32, [3 x i64] }
%sollang.enum.2222 = type { i32, [2 x i64] }
%sollang.enum.2223 = type { i32, [2 x i64] }
%sollang.enum.2225 = type { i32, [2 x i64] }
%sollang.enum.2226 = type { i32, [2 x i64] }
%sollang.enum.2228 = type { i32, [9 x i64] }
%sollang.enum.2229 = type { i32, [24 x i64] }
%sollang.enum.2230 = type { i32, [2 x i64] }
%sollang.enum.2231 = type { i32, [12 x i64] }
%sollang.enum.2232 = type { i32, [11 x i64] }
%sollang.enum.2233 = type { i32, [2 x i64] }
%sollang.enum.2234 = type { i32, [32 x i64] }
%sollang.enum.2235 = type { i32, [34 x i64] }
%sollang.enum.2236 = type { i32, [2 x i64] }
%sollang.enum.2237 = type { i32, [9 x i64] }
%sollang.enum.2238 = type { i32, [31 x i64] }
%sollang.enum.2239 = type { i32, [2 x i64] }
%sollang.enum.2240 = type { i32, [15 x i64] }
%sollang.enum.2241 = type { i32, [34 x i64] }
%sollang.enum.2242 = type { i32, [2 x i64] }
%sollang.enum.2243 = type { i32, [2 x i64] }
%sollang.enum.2244 = type { i32, [6 x i64] }
%sollang.enum.2245 = type { i32, [2 x i64] }
%sollang.enum.2246 = type { i32, [2 x i64] }
%sollang.enum.2247 = type { i32, [2 x i64] }
%sollang.enum.2249 = type { i32, [14 x i64] }
%sollang.enum.2250 = type { i32, [9 x i64] }
%sollang.enum.2251 = type { i32, [5 x i64] }
%sollang.enum.2252 = type { i32, [5 x i64] }
%sollang.enum.2253 = type { i32, [4 x i64] }
%sollang.enum.2254 = type { i32, [2 x i64] }
%sollang.enum.2256 = type { i32, [2 x i64] }
%sollang.enum.2257 = type { i32, [2 x i64] }
%sollang.enum.2258 = type { i32, [81 x i64] }
%sollang.enum.2259 = type { i32, [3 x i64] }
%sollang.enum.2260 = type { i32, [2 x i64] }
%sollang.enum.2261 = type { i32, [3 x i64] }
%sollang.enum.2262 = type { i32, [5 x i64] }
%sollang.enum.2263 = type { i32, [2 x i64] }
%sollang.enum.2264 = type { i32, [14 x i64] }
%sollang.enum.2265 = type { i32, [2 x i64] }
%sollang.enum.2266 = type { i32, [32 x i64] }
%sollang.enum.2267 = type { i32, [4 x i64] }
%sollang.enum.2268 = type { i32, [2 x i64] }
%sollang.enum.2270 = type { i32, [5 x i64] }
%sollang.enum.2271 = type { i32, [2 x i64] }
%sollang.enum.2272 = type { i32, [2 x i64] }
%sollang.enum.2273 = type { i32, [5 x i64] }
%sollang.enum.2274 = type { i32, [2 x i64] }
%sollang.enum.2275 = type { i32, [2 x i64] }
%sollang.enum.2276 = type { i32, [32 x i64] }
%sollang.enum.2277 = type { i32, [2 x i64] }
%sollang.enum.2278 = type { i32, [4 x i64] }
%sollang.enum.2280 = type { i32, [2 x i64] }
%sollang.enum.2281 = type { i32, [2 x i64] }
%sollang.enum.2282 = type { i32, [4 x i64] }
%sollang.enum.2283 = type { i32, [2 x i64] }
%sollang.enum.2284 = type { i32, [2 x i64] }
%sollang.enum.2285 = type { i32, [2 x i64] }
%sollang.enum.2286 = type { i32, [2 x i64] }
%sollang.enum.2287 = type { i32, [2 x i64] }
%sollang.enum.2288 = type { i32, [2 x i64] }
%sollang.enum.2289 = type { i32, [3 x i64] }
%sollang.enum.2290 = type { i32, [2 x i64] }
%sollang.enum.2292 = type { i32, [3 x i64] }
%sollang.enum.2293 = type { i32, [4 x i64] }
%sollang.enum.2294 = type { i32, [9 x i64] }
%sollang.enum.2295 = type { i32, [2 x i64] }
%sollang.enum.2296 = type { i32, [32 x i64] }
%sollang.enum.2297 = type { i32, [3 x i64] }
%sollang.enum.2299 = type { i32, [5 x i64] }
%sollang.enum.2300 = type { i32, [2 x i64] }
%sollang.enum.2301 = type { i32, [2 x i64] }
%sollang.enum.2302 = type { i32, [4 x i64] }
%sollang.enum.2303 = type { i32, [4 x i64] }
%sollang.enum.2304 = type { i32, [72 x i64] }
%sollang.enum.2305 = type { i32, [2 x i64] }
%sollang.enum.2306 = type { i32, [2 x i64] }
%sollang.enum.2307 = type { i32, [3 x i64] }
%sollang.enum.2308 = type { i32, [2 x i64] }
%sollang.enum.2309 = type { i32, [13 x i64] }
%sollang.enum.2310 = type { i32, [26 x i64] }
%sollang.enum.2311 = type { i32, [5 x i64] }
%sollang.enum.2312 = type { i32, [2 x i64] }
%sollang.enum.2315 = type { i32, [2 x i64] }
%sollang.enum.2316 = type { i32, [72 x i64] }
%sollang.enum.2317 = type { i32, [3 x i64] }
%sollang.enum.2318 = type { i32, [13 x i64] }
%sollang.enum.2319 = type { i32, [70 x i64] }
%sollang.enum.2320 = type { i32, [2 x i64] }
%sollang.enum.2321 = type { i32, [3 x i64] }
%sollang.enum.2322 = type { i32, [40 x i64] }
%sollang.enum.2326 = type { i32, [10 x i64] }
%sollang.enum.2327 = type { i32, [11 x i64] }
%sollang.enum.2328 = type { i32, [2 x i64] }
%sollang.enum.2329 = type { i32, [1 x i64] }
%sollang.enum.2330 = type { i32, [5 x i64] }
%sollang.enum.2331 = type { i32, [3 x i64] }
%sollang.enum.2332 = type { i32, [3 x i64] }
%sollang.enum.2333 = type { i32, [10 x i64] }
%sollang.enum.2334 = type { i32, [33 x i64] }
%sollang.enum.2335 = type { i32, [35 x i64] }
%sollang.enum.2336 = type { i32, [1 x i64] }
%sollang.enum.2338 = type { i32, [8 x i64] }
%sollang.enum.2339 = type { i32, [2 x i64] }
%sollang.enum.2340 = type { i32, [2 x i64] }
%sollang.enum.2341 = type { i32, [1 x i64] }
%sollang.enum.2342 = type { i32, [2 x i64] }
%sollang.enum.2345 = type { i32, [3 x i64] }
%sollang.enum.2347 = type { i32, [2 x i64] }
%sollang.enum.2348 = type { i32, [2 x i64] }
%sollang.enum.2349 = type { i32, [2 x i64] }
%sollang.enum.2350 = type { i32, [5 x i64] }
%sollang.enum.2351 = type { i32, [11 x i64] }
%sollang.enum.2352 = type { i32, [9 x i64] }
%sollang.enum.2354 = type { i32, [3 x i64] }
%sollang.enum.2355 = type { i32, [2 x i64] }
%sollang.enum.2356 = type { i32, [2 x i64] }
%sollang.enum.2357 = type { i32, [2 x i64] }
%sollang.enum.2358 = type { i32, [2 x i64] }
%sollang.enum.2359 = type { i32, [2 x i64] }
%sollang.enum.2360 = type { i32, [2 x i64] }
%sollang.enum.2361 = type { i32, [2 x i64] }
%sollang.enum.2362 = type { i32, [2 x i64] }
%sollang.enum.2363 = type { i32, [3 x i64] }
%sollang.enum.2364 = type { i32, [3 x i64] }
%sollang.enum.2365 = type { i32, [4 x i64] }
%sollang.enum.2366 = type { i32, [2 x i64] }
%sollang.enum.2367 = type { i32, [4 x i64] }
%sollang.enum.2368 = type { i32, [4 x i64] }
%sollang.enum.2369 = type { i32, [2 x i64] }
%sollang.enum.2370 = type { i32, [8 x i64] }
%sollang.enum.2371 = type { i32, [2 x i64] }
%sollang.enum.2372 = type { i32, [4 x i64] }
%sollang.enum.2373 = type { i32, [3 x i64] }
%sollang.enum.2374 = type { i32, [2 x i64] }
%sollang.enum.2375 = type { i32, [2 x i64] }
%sollang.enum.2376 = type { i32, [5 x i64] }
%sollang.enum.2377 = type { i32, [10 x i64] }
%sollang.enum.2378 = type { i32, [10 x i64] }
%sollang.enum.2379 = type { i32, [11 x i64] }
%sollang.enum.2380 = type { i32, [11 x i64] }
%sollang.enum.2381 = type { i32, [7 x i64] }
%sollang.enum.2382 = type { i32, [8 x i64] }
%sollang.enum.2383 = type { i32, [7 x i64] }
%sollang.enum.2384 = type { i32, [8 x i64] }
%sollang.enum.2385 = type { i32, [2 x i64] }
%sollang.enum.2386 = type { i32, [7 x i64] }
%sollang.enum.2387 = type { i32, [7 x i64] }
%sollang.enum.2388 = type { i32, [3 x i64] }
%sollang.enum.2389 = type { i32, [3 x i64] }
%sollang.enum.2390 = type { i32, [2 x i64] }
%sollang.enum.2391 = type { i32, [2 x i64] }
%sollang.enum.2393 = type { i32, [2 x i64] }
%sollang.enum.2394 = type { i32, [4 x i64] }
%sollang.enum.2395 = type { i32, [3 x i64] }
%sollang.enum.2396 = type { i32, [3 x i64] }
%sollang.enum.2397 = type { i32, [13 x i64] }
%sollang.enum.2398 = type { i32, [12 x i64] }
%sollang.enum.2399 = type { i32, [4 x i64] }
%sollang.enum.2400 = type { i32, [2 x i64] }
%sollang.enum.2401 = type { i32, [2 x i64] }
%sollang.enum.2403 = type { i32, [2 x i64] }
%sollang.enum.2404 = type { i32, [5 x i64] }
%sollang.enum.2405 = type { i32, [3 x i64] }
%sollang.enum.2406 = type { i32, [15 x i64] }
%sollang.enum.2407 = type { i32, [3 x i64] }
%sollang.enum.2408 = type { i32, [2 x i64] }
%sollang.enum.2409 = type { i32, [3 x i64] }
%sollang.enum.2414 = type { i32, [2 x i64] }
%sollang.enum.2415 = type { i32, [3 x i64] }
%sollang.enum.2416 = type { i32, [3 x i64] }
%sollang.enum.2417 = type { i32, [15 x i64] }
%sollang.enum.2418 = type { i32, [25 x i64] }
%sollang.enum.2419 = type { i32, [7 x i64] }
%sollang.enum.2420 = type { i32, [5 x i64] }
%sollang.enum.2421 = type { i32, [9 x i64] }
%sollang.enum.2422 = type { i32, [31 x i64] }
%sollang.enum.2423 = type { i32, [3 x i64] }
%sollang.enum.2424 = type { i32, [8 x i64] }
%sollang.enum.2425 = type { i32, [2 x i64] }
%sollang.enum.2426 = type { i32, [12 x i64] }
%sollang.enum.2427 = type { i32, [6 x i64] }
%sollang.enum.2428 = type { i32, [2 x i64] }
%sollang.enum.2429 = type { i32, [9 x i64] }
%sollang.enum.2430 = type { i32, [6 x i64] }
%sollang.enum.2431 = type { i32, [3 x i64] }
%sollang.enum.2432 = type { i32, [26 x i64] }
%sollang.enum.2433 = type { i32, [4 x i64] }
%sollang.enum.2434 = type { i32, [5 x i64] }
%sollang.enum.2435 = type { i32, [8 x i64] }
%sollang.enum.2436 = type { i32, [40 x i64] }
%sollang.enum.2437 = type { i32, [9 x i64] }
%sollang.enum.2438 = type { i32, [3 x i64] }
%sollang.enum.2442 = type { i32, [2 x i64] }
%sollang.enum.2443 = type { i32, [2 x i64] }
%sollang.enum.2444 = type { i32, [9 x i64] }
%sollang.enum.2445 = type { i32, [21 x i64] }
%sollang.enum.2446 = type { i32, [2 x i64] }
%sollang.enum.2447 = type { i32, [2 x i64] }
%sollang.enum.2448 = type { i32, [4 x i64] }
%sollang.enum.2449 = type { i32, [3 x i64] }
%sollang.enum.2450 = type { i32, [9 x i64] }
%sollang.enum.2451 = type { i32, [2 x i64] }
%sollang.enum.2452 = type { i32, [5 x i64] }
%sollang.enum.2453 = type { i32, [2 x i64] }
%sollang.enum.2454 = type { i32, [14 x i64] }
%sollang.enum.2456 = type { i32, [11 x i64] }
%sollang.enum.2457 = type { i32, [16 x i64] }
%sollang.enum.2458 = type { i32, [7 x i64] }
%sollang.enum.2461 = type { i32, [7 x i64] }
%sollang.enum.2462 = type { i32, [4 x i64] }
%sollang.enum.2463 = type { i32, [6 x i64] }
%sollang.enum.2464 = type { i32, [7 x i64] }
%sollang.enum.2465 = type { i32, [6 x i64] }
%sollang.enum.2466 = type { i32, [5 x i64] }
%sollang.enum.2467 = type { i32, [2 x i64] }
%sollang.enum.2468 = type { i32, [4 x i64] }
%sollang.enum.2469 = type { i32, [10 x i64] }
%sollang.enum.2470 = type { i32, [131 x i64] }
%sollang.enum.2471 = type { i32, [2 x i64] }
%sollang.enum.2472 = type { i32, [16 x i64] }
%sollang.enum.2473 = type { i32, [7 x i64] }
%sollang.enum.2474 = type { i32, [10 x i64] }
%sollang.enum.2475 = type { i32, [5 x i64] }
%sollang.enum.2477 = type { i32, [2 x i64] }
%sollang.enum.2478 = type { i32, [17 x i64] }
%sollang.enum.2480 = type { i32, [10 x i64] }
%sollang.enum.2481 = type { i32, [5 x i64] }
%sollang.enum.2482 = type { i32, [3 x i64] }
%sollang.enum.2483 = type { i32, [8 x i64] }
%sollang.enum.2484 = type { i32, [2 x i64] }
%sollang.enum.2485 = type { i32, [4 x i64] }
%sollang.enum.2486 = type { i32, [2 x i64] }
%sollang.enum.2487 = type { i32, [9 x i64] }
%sollang.enum.2488 = type { i32, [3 x i64] }
%sollang.enum.2489 = type { i32, [7 x i64] }
%sollang.enum.2490 = type { i32, [11 x i64] }
%sollang.enum.2491 = type { i32, [7 x i64] }
%sollang.enum.2495 = type { i32, [6 x i64] }
%sollang.enum.2497 = type { i32, [11 x i64] }
%sollang.enum.2498 = type { i32, [2 x i64] }
%sollang.enum.2499 = type { i32, [18 x i64] }
%sollang.enum.2500 = type { i32, [149 x i64] }
%sollang.enum.2502 = type { i32, [3 x i64] }
%sollang.enum.2503 = type { i32, [2 x i64] }
%sollang.enum.2504 = type { i32, [2 x i64] }
%sollang.enum.2506 = type { i32, [12 x i64] }
%sollang.enum.2507 = type { i32, [9 x i64] }
%sollang.enum.2508 = type { i32, [5 x i64] }
%sollang.enum.2509 = type { i32, [5 x i64] }
%sollang.enum.2510 = type { i32, [6 x i64] }
%sollang.enum.2511 = type { i32, [6 x i64] }
%sollang.enum.2512 = type { i32, [2 x i64] }
%sollang.enum.2513 = type { i32, [14 x i64] }
%sollang.enum.2514 = type { i32, [6 x i64] }
%sollang.enum.2515 = type { i32, [6 x i64] }
%sollang.enum.2516 = type { i32, [4 x i64] }
%sollang.enum.2517 = type { i32, [5 x i64] }
%sollang.enum.2518 = type { i32, [4 x i64] }
%sollang.enum.2519 = type { i32, [21 x i64] }
%sollang.enum.2520 = type { i32, [4 x i64] }
%sollang.enum.2521 = type { i32, [5 x i64] }
%sollang.enum.2522 = type { i32, [2 x i64] }
%sollang.enum.2524 = type { i32, [3 x i64] }
%sollang.enum.2525 = type { i32, [4 x i64] }
%sollang.enum.2526 = type { i32, [2 x i64] }
%sollang.enum.2527 = type { i32, [6 x i64] }
%sollang.enum.2528 = type { i32, [5 x i64] }
%sollang.enum.2529 = type { i32, [5 x i64] }
%sollang.enum.2532 = type { i32, [16 x i64] }
%sollang.enum.2533 = type { i32, [7 x i64] }
%sollang.enum.2534 = type { i32, [6 x i64] }
%sollang.enum.2535 = type { i32, [4 x i64] }
%sollang.enum.2536 = type { i32, [5 x i64] }
%sollang.enum.2537 = type { i32, [2 x i64] }
%sollang.enum.2538 = type { i32, [2 x i64] }
%sollang.enum.2539 = type { i32, [4 x i64] }
%sollang.enum.2541 = type { i32, [9 x i64] }
%sollang.enum.2542 = type { i32, [4 x i64] }
%sollang.enum.2543 = type { i32, [3 x i64] }
%sollang.enum.2544 = type { i32, [17 x i64] }
%sollang.enum.2545 = type { i32, [2 x i64] }
%sollang.enum.2546 = type { i32, [3 x i64] }
%sollang.enum.2547 = type { i32, [12 x i64] }
%sollang.enum.2548 = type { i32, [3 x i64] }
%sollang.enum.2549 = type { i32, [4 x i64] }
%sollang.enum.2550 = type { i32, [12 x i64] }
%sollang.enum.2551 = type { i32, [4 x i64] }
%sollang.enum.2552 = type { i32, [3 x i64] }
%sollang.enum.2553 = type { i32, [3 x i64] }
%sollang.enum.2554 = type { i32, [4 x i64] }
%sollang.enum.2555 = type { i32, [2 x i64] }
%sollang.enum.2556 = type { i32, [3 x i64] }
%sollang.enum.2558 = type { i32, [6 x i64] }
%sollang.enum.2559 = type { i32, [3 x i64] }
%sollang.enum.2560 = type { i32, [2 x i64] }
%sollang.enum.2561 = type { i32, [2 x i64] }
%sollang.enum.2562 = type { i32, [2 x i64] }
%sollang.enum.2563 = type { i32, [3 x i64] }
%sollang.enum.2564 = type { i32, [2 x i64] }
%sollang.enum.2565 = type { i32, [2 x i64] }
%sollang.enum.2566 = type { i32, [12 x i64] }
%sollang.enum.2567 = type { i32, [6 x i64] }
%sollang.enum.2568 = type { i32, [3 x i64] }
%sollang.enum.2569 = type { i32, [2 x i64] }
%sollang.enum.2570 = type { i32, [8 x i64] }
%sollang.enum.2572 = type { i32, [2 x i64] }
%sollang.enum.2573 = type { i32, [4 x i64] }
%sollang.enum.2576 = type { i32, [4 x i64] }
%sollang.enum.2577 = type { i32, [4 x i64] }
%sollang.enum.2578 = type { i32, [7 x i64] }
%sollang.enum.2579 = type { i32, [4 x i64] }
%sollang.enum.2581 = type { i32, [9 x i64] }
%sollang.enum.2582 = type { i32, [2 x i64] }
%sollang.enum.2583 = type { i32, [4 x i64] }
%sollang.enum.2584 = type { i32, [1 x i64] }
%sollang.enum.2585 = type { i32, [1 x i64] }
%sollang.enum.2586 = type { i32, [2 x i64] }
%sollang.enum.2587 = type { i32, [2 x i64] }
%sollang.enum.2588 = type { i32, [2 x i64] }
%sollang.enum.2589 = type { i32, [6 x i64] }
%sollang.enum.2590 = type { i32, [1 x i64] }
%sollang.enum.2591 = type { i32, [1 x i64] }
%sollang.enum.2592 = type { i32, [1 x i64] }
%sollang.enum.2593 = type { i32, [1 x i64] }
%sollang.enum.2594 = type { i32, [11 x i64] }
%sollang.enum.2595 = type { i32, [29 x i64] }
%sollang.enum.2596 = type { i32, [12 x i64] }
%sollang.enum.2597 = type { i32, [2 x i64] }
%sollang.enum.2598 = type { i32, [3 x i64] }
%sollang.enum.2599 = type { i32, [2 x i64] }
%sollang.enum.2601 = type { i32, [2 x i64] }
%sollang.enum.2602 = type { i32, [3 x i64] }
%sollang.enum.2603 = type { i32, [2 x i64] }
%sollang.enum.2604 = type { i32, [1 x i64] }
%sollang.enum.2605 = type { i32, [1 x i64] }
%sollang.enum.2608 = type { i32, [2 x i64] }
%sollang.enum.2609 = type { i32, [2 x i64] }
%sollang.enum.2610 = type { i32, [2 x i64] }
%sollang.enum.2613 = type { i32, [2 x i64] }
%sollang.enum.2614 = type { i32, [7 x i64] }
%sollang.enum.2615 = type { i32, [4 x i64] }
%sollang.enum.2616 = type { i32, [2 x i64] }
%sollang.enum.2617 = type { i32, [2 x i64] }
%sollang.enum.2619 = type { i32, [3 x i64] }
%sollang.enum.2622 = type { i32, [6 x i64] }
%sollang.enum.2623 = type { i32, [2 x i64] }
%sollang.enum.2624 = type { i32, [3 x i64] }
%sollang.enum.2625 = type { i32, [8 x i64] }
%sollang.enum.2626 = type { i32, [2 x i64] }
%sollang.enum.2627 = type { i32, [3 x i64] }
%sollang.enum.2628 = type { i32, [1 x i64] }
%sollang.enum.2629 = type { i32, [2 x i64] }
%sollang.enum.2630 = type { i32, [2 x i64] }
%sollang.enum.2632 = type { i32, [2 x i64] }
%sollang.enum.2633 = type { i32, [4 x i64] }
%sollang.enum.2634 = type { i32, [3 x i64] }
%sollang.enum.2635 = type { i32, [18 x i64] }
%sollang.enum.2636 = type { i32, [3 x i64] }
%sollang.enum.2637 = type { i32, [16 x i64] }
%sollang.enum.2638 = type { i32, [2 x i64] }
%sollang.enum.2639 = type { i32, [2 x i64] }
%sollang.enum.2640 = type { i32, [2 x i64] }
%sollang.enum.2641 = type { i32, [2 x i64] }
%sollang.enum.2643 = type { i32, [1 x i64] }
%sollang.enum.2644 = type { i32, [2 x i64] }
%sollang.enum.2645 = type { i32, [5 x i64] }
%sollang.enum.2646 = type { i32, [2 x i64] }
%sollang.enum.2647 = type { i32, [3 x i64] }
%sollang.enum.2650 = type { i32, [2 x i64] }
%sollang.enum.2651 = type { i32, [9 x i64] }
%sollang.enum.2652 = type { i32, [7 x i64] }

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
@sollang_task_ready_head = internal global ptr null
@sollang_task_ready_tail = internal global ptr null
@sollang_task_timer_head = internal global ptr null
@sollang_file_request_head = internal global ptr null
@sollang_io_completion_head = internal global ptr null
@sollang_file_worker_started = internal global i1 false
@sollang_file_worker_stopping = internal global i32 0
@sollang_io_outstanding = internal global i64 0

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
@environ = external global ptr
declare ptr @malloc(i64)
declare void @free(ptr)
define internal i1 @sollang_io_drain_completions() #0 {
entry:
  ret i1 false
}

define internal void @sollang_platform_io_wait_completion(i64 %requested) #0 {
entry:
  ret void
}

define internal void @sollang_file_wait_idle() #0 {
entry:
  ret void
}

define internal void @sollang_async_shutdown() #0 {
entry:
  ret void
}


define internal void @sollang_task_enqueue_ready(ptr %control) #0 {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  store i32 0, ptr %status_slot, align 4
  %next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 3
  store ptr null, ptr %next_slot, align 8
  %tail = load ptr, ptr @sollang_task_ready_tail, align 8
  %empty = icmp eq ptr %tail, null
  br i1 %empty, label %first, label %append

first:
  store ptr %control, ptr @sollang_task_ready_head, align 8
  br label %queued

append:
  %tail_next_slot = getelementptr %sollang.task_control, ptr %tail, i32 0, i32 3
  store ptr %control, ptr %tail_next_slot, align 8
  br label %queued

queued:
  store ptr %control, ptr @sollang_task_ready_tail, align 8
  ret void
}

define internal void @sollang_task_park_on(ptr %parent, ptr %child) #0 {
entry:
  %child_status_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 4
  %child_status = load i32, ptr %child_status_slot, align 4
  %completed = icmp eq i32 %child_status, 2
  br i1 %completed, label %done, label %park

park:
  %child_waiter_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 9
  %existing_waiter = load ptr, ptr %child_waiter_slot, align 8
  %available = icmp eq ptr %existing_waiter, null
  br i1 %available, label %attach, label %invalid

attach:
  store ptr %parent, ptr %child_waiter_slot, align 8
  %parent_child_slot = getelementptr %sollang.task_control, ptr %parent, i32 0, i32 10
  store ptr %child, ptr %parent_child_slot, align 8
  %parent_status_slot = getelementptr %sollang.task_control, ptr %parent, i32 0, i32 4
  store i32 5, ptr %parent_status_slot, align 4
  br label %done

invalid:
  call void @llvm.trap()
  unreachable

done:
  ret void
}

define internal void @sollang_task_wake_waiter(ptr %child) #0 {
entry:
  %waiter_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 9
  %waiter = load ptr, ptr %waiter_slot, align 8
  %has_waiter = icmp ne ptr %waiter, null
  br i1 %has_waiter, label %wake, label %done

wake:
  store ptr null, ptr %waiter_slot, align 8
  %waiter_child_slot = getelementptr %sollang.task_control, ptr %waiter, i32 0, i32 10
  store ptr null, ptr %waiter_child_slot, align 8
  call void @sollang_task_enqueue_ready(ptr %waiter)
  br label %done

done:
  ret void
}

define internal void @sollang_timer_park(ptr %control, i64 %deadline) #0 {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  store i32 4, ptr %status_slot, align 4
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  store i64 %deadline, ptr %deadline_slot, align 8
  %head = load ptr, ptr @sollang_task_timer_head, align 8
  br label %scan

scan:
  %previous = phi ptr [ null, %entry ], [ %current, %advance ]
  %current = phi ptr [ %head, %entry ], [ %next, %advance ]
  %has_current = icmp ne ptr %current, null
  br i1 %has_current, label %compare, label %insert

compare:
  %current_deadline_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 8
  %current_deadline = load i64, ptr %current_deadline_slot, align 8
  %before_current = icmp slt i64 %deadline, %current_deadline
  br i1 %before_current, label %insert, label %advance

advance:
  %current_next_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 7
  %next = load ptr, ptr %current_next_slot, align 8
  br label %scan

insert:
  %control_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 7
  store ptr %current, ptr %control_next_slot, align 8
  %at_head = icmp eq ptr %previous, null
  br i1 %at_head, label %insert_head, label %insert_after

insert_head:
  store ptr %control, ptr @sollang_task_timer_head, align 8
  ret void

insert_after:
  %previous_next_slot = getelementptr %sollang.task_control, ptr %previous, i32 0, i32 7
  store ptr %control, ptr %previous_next_slot, align 8
  ret void
}

define internal void @sollang_timer_wake_due() #0 {
entry:
  br label %scan

scan:
  %head = load ptr, ptr @sollang_task_timer_head, align 8
  %has_head = icmp ne ptr %head, null
  br i1 %has_head, label %check, label %done

check:
  %deadline_slot = getelementptr %sollang.task_control, ptr %head, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %due = icmp sge i64 %now, %deadline
  br i1 %due, label %wake, label %done

wake:
  %timer_next_slot = getelementptr %sollang.task_control, ptr %head, i32 0, i32 7
  %timer_next = load ptr, ptr %timer_next_slot, align 8
  store ptr %timer_next, ptr @sollang_task_timer_head, align 8
  store ptr null, ptr %timer_next_slot, align 8
  call void @sollang_task_enqueue_ready(ptr %head)
  br label %scan

done:
  ret void
}

define internal i1 @sollang_timer_wait_next() #0 {
entry:
  %file_progress = call i1 @sollang_io_drain_completions()
  call void @sollang_timer_wake_due()
  %ready = load ptr, ptr @sollang_task_ready_head, align 8
  %has_ready = icmp ne ptr %ready, null
  br i1 %has_ready, label %progress, label %inspect_timer

inspect_timer:
  %timer = load ptr, ptr @sollang_task_timer_head, align 8
  %has_timer = icmp ne ptr %timer, null
  %file_outstanding = load atomic i64, ptr @sollang_io_outstanding acquire, align 8
  %has_file = icmp ne i64 %file_outstanding, 0
  br i1 %has_timer, label %timer_timeout, label %inspect_file

inspect_file:
  br i1 %has_file, label %wait_file_only, label %stalled

timer_timeout:
  %deadline_slot = getelementptr %sollang.task_control, ptr %timer, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %remaining_raw = sub i64 %deadline, %now
  %positive = icmp sgt i64 %remaining_raw, 0
  %remaining = select i1 %positive, i64 %remaining_raw, i64 0
  br i1 %has_file, label %wait_file_or_timer, label %wait_timer_only

wait_file_or_timer:
  call void @sollang_platform_io_wait_completion(i64 %remaining)
  %file_timer_progress = call i1 @sollang_io_drain_completions()
  call void @sollang_timer_wake_due()
  br label %progress

wait_file_only:
  call void @sollang_platform_io_wait_completion(i64 -1)
  %file_only_progress = call i1 @sollang_io_drain_completions()
  br label %progress

wait_timer_only:
  call void @sollang_wait_millis(i64 %remaining)
  call void @sollang_timer_wake_due()
  br label %progress

progress:
  ret i1 true

stalled:
  ret i1 false
}

define internal i1 @sollang_sleep_worker(ptr %control) #0 {
entry:
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  %deadline = load i64, ptr %deadline_slot, align 8
  %now = call i64 @sollang_now_millis()
  %ready = icmp sge i64 %now, %deadline
  br i1 %ready, label %complete, label %pending

complete:
  ret i1 true

pending:
  call void @sollang_timer_park(ptr %control, i64 %deadline)
  ret i1 false
}

define internal void @sollang_sleep_cancel(ptr %control) #0 {
entry:
  %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %context_slot, align 8
  call void @sollang_free(ptr %context)
  ret void
}

define internal ptr @sollang_task_start(ptr %worker, ptr %destroy, ptr %cancel, ptr %context) #0 {
entry:
  %control = call ptr @sollang_alloc(i64 168)
  %allocated = icmp ne ptr %control, null
  br i1 %allocated, label %initialize, label %fail

initialize:
  %context_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  store ptr %context, ptr %context_slot, align 8
  %resume_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 1
  store ptr %worker, ptr %resume_slot, align 8
  %destroy_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 2
  store ptr %destroy, ptr %destroy_slot, align 8
  %next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 3
  store ptr null, ptr %next_slot, align 8
  %status_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  store i32 0, ptr %status_slot, align 4
  %state_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  store i32 0, ptr %state_slot, align 4
  %cancel_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 6
  store ptr %cancel, ptr %cancel_slot, align 8
  %timer_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 7
  store ptr null, ptr %timer_next_slot, align 8
  %deadline_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 8
  store i64 0, ptr %deadline_slot, align 8
  %waiter_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 9
  store ptr null, ptr %waiter_slot, align 8
  %waiting_child_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 10
  store ptr null, ptr %waiting_child_slot, align 8
  %file_size_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 11
  store i32 0, ptr %file_size_slot, align 4
  %file_phase_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 12
  store i32 0, ptr %file_phase_slot, align 4
  %file_data_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 13
  store i64 0, ptr %file_data_slot, align 8
  %file_count_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 14
  store i64 0, ptr %file_count_slot, align 8
  %file_ok_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 15
  store i32 0, ptr %file_ok_slot, align 4
  %file_next_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 16
  store ptr null, ptr %file_next_slot, align 8
  %file_handle_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 17
  store i64 -1, ptr %file_handle_slot, align 8
  %file_offset_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 18
  store i64 0, ptr %file_offset_slot, align 8
  %file_explicit_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 19
  store i32 0, ptr %file_explicit_slot, align 4
  %file_operation_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 20
  store i32 0, ptr %file_operation_slot, align 4
  %result_address_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 21
  store ptr null, ptr %result_address_slot, align 8
  %result_completion_slot = getelementptr %sollang.task_control, ptr %control, i32 0, i32 22
  store ptr null, ptr %result_completion_slot, align 8
  %tail = load ptr, ptr @sollang_task_ready_tail, align 8
  %empty = icmp eq ptr %tail, null
  br i1 %empty, label %first, label %append

first:
  store ptr %control, ptr @sollang_task_ready_head, align 8
  br label %queued

append:
  %tail_next_slot = getelementptr %sollang.task_control, ptr %tail, i32 0, i32 3
  store ptr %control, ptr %tail_next_slot, align 8
  br label %queued

queued:
  store ptr %control, ptr @sollang_task_ready_tail, align 8
  ret ptr %control

fail:
  ret ptr null
}

define internal i1 @sollang_task_join(ptr %handle) #0 {
entry:
  br label %poll

poll:
  %target_status_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 4
  %target_status = load i32, ptr %target_status_slot, align 4
  %completed = icmp eq i32 %target_status, 2
  br i1 %completed, label %success, label %dequeue

dequeue:
  %ready = load ptr, ptr @sollang_task_ready_head, align 8
  %has_ready = icmp ne ptr %ready, null
  br i1 %has_ready, label %run, label %wait

wait:
  %timer_progress = call i1 @sollang_timer_wait_next()
  br i1 %timer_progress, label %poll, label %fail

run:
  %next_slot = getelementptr %sollang.task_control, ptr %ready, i32 0, i32 3
  %next = load ptr, ptr %next_slot, align 8
  store ptr %next, ptr @sollang_task_ready_head, align 8
  %became_empty = icmp eq ptr %next, null
  br i1 %became_empty, label %clear_tail, label %invoke

clear_tail:
  store ptr null, ptr @sollang_task_ready_tail, align 8
  br label %invoke

invoke:
  %ready_status_slot = getelementptr %sollang.task_control, ptr %ready, i32 0, i32 4
  store i32 1, ptr %ready_status_slot, align 4
  %resume_slot = getelementptr %sollang.task_control, ptr %ready, i32 0, i32 1
  %worker = load ptr, ptr %resume_slot, align 8
  %worker_complete = call i1 %worker(ptr %ready)
  br i1 %worker_complete, label %complete, label %requeue

complete:
  store i32 2, ptr %ready_status_slot, align 4
  call void @sollang_task_wake_waiter(ptr %ready)
  br label %poll

requeue:
  %pending_status = load i32, ptr %ready_status_slot, align 4
  %waiting = icmp uge i32 %pending_status, 4
  br i1 %waiting, label %poll, label %requeue_ready

requeue_ready:
  store i32 0, ptr %ready_status_slot, align 4
  store ptr null, ptr %next_slot, align 8
  %tail = load ptr, ptr @sollang_task_ready_tail, align 8
  %queue_empty = icmp eq ptr %tail, null
  br i1 %queue_empty, label %requeue_first, label %requeue_append

requeue_first:
  store ptr %ready, ptr @sollang_task_ready_head, align 8
  br label %requeued

requeue_append:
  %tail_next_slot = getelementptr %sollang.task_control, ptr %tail, i32 0, i32 3
  store ptr %ready, ptr %tail_next_slot, align 8
  br label %requeued

requeued:
  store ptr %ready, ptr @sollang_task_ready_tail, align 8
  br label %poll

success:
  ret i1 true

fail:
  ret i1 false
}

define internal i1 @sollang_task_release(ptr %handle) #0 {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 4
  %status = load i32, ptr %status_slot, align 4
  %completed = icmp eq i32 %status, 2
  br i1 %completed, label %destroy, label %fail

destroy:
  %destroy_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 2
  %destroy_fn = load ptr, ptr %destroy_slot, align 8
  %context_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 0
  %context = load ptr, ptr %context_slot, align 8
  call void %destroy_fn(ptr %context)
  call void @sollang_free(ptr %handle)
  ret i1 true

fail:
  ret i1 false
}

define internal i1 @sollang_task_cancel(ptr %handle) #0 {
entry:
  %status_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 4
  %status = load i32, ptr %status_slot, align 4
  %completed = icmp eq i32 %status, 2
  br i1 %completed, label %destroy, label %check_queued

check_queued:
  %queued = icmp eq i32 %status, 0
  br i1 %queued, label %find, label %check_waiting

check_waiting:
  %waiting_timer = icmp eq i32 %status, 4
  br i1 %waiting_timer, label %timer_find, label %check_child_waiting

check_child_waiting:
  %waiting_child = icmp eq i32 %status, 5
  br i1 %waiting_child, label %detach_child, label %check_file_waiting

check_file_waiting:
  %waiting_file = icmp eq i32 %status, 6
  br i1 %waiting_file, label %cancel_file, label %check_socket_completion_waiting

check_socket_completion_waiting:
  %waiting_socket_completion = icmp eq i32 %status, 7
  br i1 %waiting_socket_completion, label %cancel_socket_completion, label %fail

cancel_file:
  %file_phase_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 12
  store atomic i32 3, ptr %file_phase_slot release, align 4
  store i32 3, ptr %status_slot, align 4
  ret i1 true

cancel_socket_completion:
  %socket_phase_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 12
  store atomic i32 3, ptr %socket_phase_slot release, align 4
  store i32 3, ptr %status_slot, align 4
  %socket_cancel_phase_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 19
  store atomic i32 1, ptr %socket_cancel_phase_slot release, align 4
  %socket_cancel_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 6
  %socket_cancel_fn = load ptr, ptr %socket_cancel_slot, align 8
  call void %socket_cancel_fn(ptr %handle)
  ret i1 true

detach_child:
  %waiting_child_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 10
  %child = load ptr, ptr %waiting_child_slot, align 8
  %has_child = icmp ne ptr %child, null
  br i1 %has_child, label %clear_child_waiter, label %fail

clear_child_waiter:
  %child_waiter_slot = getelementptr %sollang.task_control, ptr %child, i32 0, i32 9
  store ptr null, ptr %child_waiter_slot, align 8
  store ptr null, ptr %waiting_child_slot, align 8
  store i32 3, ptr %status_slot, align 4
  br label %destroy

find:
  %head = load ptr, ptr @sollang_task_ready_head, align 8
  br label %scan

scan:
  %previous = phi ptr [ null, %find ], [ %current, %advance ]
  %current = phi ptr [ %head, %find ], [ %next, %advance ]
  %has_current = icmp ne ptr %current, null
  br i1 %has_current, label %compare, label %fail

compare:
  %found = icmp eq ptr %current, %handle
  br i1 %found, label %unlink, label %advance

advance:
  %current_next_slot = getelementptr %sollang.task_control, ptr %current, i32 0, i32 3
  %next = load ptr, ptr %current_next_slot, align 8
  br label %scan

unlink:
  %handle_next_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 3
  %handle_next = load ptr, ptr %handle_next_slot, align 8
  %is_head = icmp eq ptr %previous, null
  br i1 %is_head, label %unlink_head, label %unlink_after

unlink_head:
  store ptr %handle_next, ptr @sollang_task_ready_head, align 8
  br label %repair_tail

unlink_after:
  %previous_next_slot = getelementptr %sollang.task_control, ptr %previous, i32 0, i32 3
  store ptr %handle_next, ptr %previous_next_slot, align 8
  br label %repair_tail

repair_tail:
  %tail = load ptr, ptr @sollang_task_ready_tail, align 8
  %is_tail = icmp eq ptr %tail, %handle
  br i1 %is_tail, label %replace_tail, label %mark_cancelled

replace_tail:
  store ptr %previous, ptr @sollang_task_ready_tail, align 8
  br label %mark_cancelled

mark_cancelled:
  store i32 3, ptr %status_slot, align 4
  br label %destroy

timer_find:
  %timer_head = load ptr, ptr @sollang_task_timer_head, align 8
  br label %timer_scan

timer_scan:
  %timer_previous = phi ptr [ null, %timer_find ], [ %timer_current, %timer_advance ]
  %timer_current = phi ptr [ %timer_head, %timer_find ], [ %timer_next, %timer_advance ]
  %timer_has_current = icmp ne ptr %timer_current, null
  br i1 %timer_has_current, label %timer_compare, label %fail

timer_compare:
  %timer_found = icmp eq ptr %timer_current, %handle
  br i1 %timer_found, label %timer_unlink, label %timer_advance

timer_advance:
  %timer_current_next_slot = getelementptr %sollang.task_control, ptr %timer_current, i32 0, i32 7
  %timer_next = load ptr, ptr %timer_current_next_slot, align 8
  br label %timer_scan

timer_unlink:
  %handle_timer_next_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 7
  %handle_timer_next = load ptr, ptr %handle_timer_next_slot, align 8
  %timer_is_head = icmp eq ptr %timer_previous, null
  br i1 %timer_is_head, label %timer_unlink_head, label %timer_unlink_after

timer_unlink_head:
  store ptr %handle_timer_next, ptr @sollang_task_timer_head, align 8
  br label %timer_mark_cancelled

timer_unlink_after:
  %timer_previous_next_slot = getelementptr %sollang.task_control, ptr %timer_previous, i32 0, i32 7
  store ptr %handle_timer_next, ptr %timer_previous_next_slot, align 8
  br label %timer_mark_cancelled

timer_mark_cancelled:
  store ptr null, ptr %handle_timer_next_slot, align 8
  store i32 3, ptr %status_slot, align 4
  br label %destroy

destroy:
  %cancel_slot = getelementptr %sollang.task_control, ptr %handle, i32 0, i32 6
  %cancel_fn = load ptr, ptr %cancel_slot, align 8
  call void %cancel_fn(ptr %handle)
  call void @sollang_free(ptr %handle)
  ret i1 true

fail:
  ret i1 false
}

declare void @llvm.trap()
declare i64 @llvm.ctpop.i64(i64)
declare i16 @llvm.cttz.i16(i16, i1 immarg)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg)
declare void @llvm.memcpy.p0.p0.i64(ptr nocapture writeonly, ptr nocapture readonly, i64, i1 immarg)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)

define internal void @sollang_drop_2708(%sollang.int_slice %value) #0 {
entry:
  %fixed_array_ptr0 = extractvalue %sollang.int_slice %value, 0
  %fixed_array_len1 = extractvalue %sollang.int_slice %value, 1
  %drop_array_slot2 = getelementptr %sollang.struct.1448, ptr %fixed_array_ptr0, i64 0
  %drop_array_value3 = load %sollang.struct.1448, ptr %drop_array_slot2, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %drop_array_value3)
  %drop_array_slot4 = getelementptr %sollang.struct.1448, ptr %fixed_array_ptr0, i64 1
  %drop_array_value5 = load %sollang.struct.1448, ptr %drop_array_slot4, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %drop_array_value5)
  call void @sollang_free(ptr %fixed_array_ptr0)
  ret void
}

define internal void @sollang_drop_23(%sollang.dynamic_int_array %value) #0 {
entry:
  %drop_array_ptr6 = extractvalue %sollang.dynamic_int_array %value, 0
  call void @sollang_free(ptr %drop_array_ptr6)
  ret void
}

define internal void @sollang_drop_1448(%sollang.struct.1448 %value) #0 {
entry:
  %drop_field7 = extractvalue %sollang.struct.1448 %value, 0
  call void @sollang_drop_23(%sollang.dynamic_int_array %drop_field7)
  ret void
}

@.slg.str.module.x.0 = private unnamed_addr constant [14 x i8] c"parent-started", align 1
@.slg.str.module.x.1 = private unnamed_addr constant [1 x i8] c"\0A", align 1
define internal i1 @sollang_fn_arrayChild_async_worker(ptr %control) #0 {
entry:
  %async_control_context_slot0 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %async_control_context_slot0, align 8
  %async_context_field1 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 0
  %stdin = load ptr, ptr %async_context_field1, align 8
  %async_context_field2 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 1
  %stdout = load ptr, ptr %async_context_field2, align 8
  %async_context_field3 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 2
  %written = load ptr, ptr %async_context_field3, align 8
  %async_context_field4 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 3
  %read = load ptr, ptr %async_context_field4, align 8
  %async_context_field5 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 4
  %ok_state = load ptr, ptr %async_context_field5, align 8
  %async_resume_state_slot6 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state7 = load i32, ptr %async_resume_state_slot6, align 4
  switch i32 %async_resume_state7, label %bb_async_state_invalid2 [ i32 0, label %bb_async_state_start0 i32 1, label %bb_async_cfg_resume1 ]
bb_async_state_invalid2:
  call void @llvm.trap()
  unreachable
bb_async_state_start0:
  store i32 1, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume1:
  %heap8 = call ptr @sollang_alloc(i64 12)
  %heap_ok9 = icmp ne ptr %heap8, null
  br i1 %heap_ok9, label %bb_alloc_ok3, label %bb_alloc_fail4

bb_alloc_fail4:
  call void @llvm.trap()
  unreachable

bb_alloc_ok3:
  %array_slot10 = getelementptr i32, ptr %heap8, i64 0
  store i32 2, ptr %array_slot10, align 4
  %array_slot11 = getelementptr i32, ptr %heap8, i64 1
  store i32 3, ptr %array_slot11, align 4
  %array_slot12 = getelementptr i32, ptr %heap8, i64 2
  store i32 5, ptr %array_slot12, align 4
  %generic_array_value13 = insertvalue %sollang.dynamic_int_array poison, ptr %heap8, 0
  %generic_array_value14 = insertvalue %sollang.dynamic_int_array %generic_array_value13, i64 3, 1
  %generic_array_value15 = insertvalue %sollang.dynamic_int_array %generic_array_value14, i64 3, 2
  %struct_init16 = insertvalue %sollang.struct.1448 poison, %sollang.dynamic_int_array %generic_array_value15, 0
  %async_result_address17 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 6
  store %sollang.struct.1448 %struct_init16, ptr %async_result_address17, align 8
  ret i1 true
}

define internal void @sollang_fn_arrayChild_async_cancel(ptr %control) #0 {
entry:
  %cancel_context_slot18 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %cancel_context_slot18, align 8
  %cancel_status_slot19 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %cancel_status20 = load i32, ptr %cancel_status_slot19, align 4
  %cancel_completed21 = icmp eq i32 %cancel_status20, 2
  br i1 %cancel_completed21, label %bb_cancel_completed5, label %bb_cancel_pending6
bb_cancel_completed5:
  %cancel_result_address22 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 6
  %cancel_result23 = load %sollang.struct.1448, ptr %cancel_result_address22, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %cancel_result23)
  br label %bb_cancel_cleanup7
bb_cancel_pending6:
  %cancel_state_slot24 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %cancel_state25 = load i32, ptr %cancel_state_slot24, align 4
  switch i32 %cancel_state25, label %bb_cancel_invalid10 [ i32 0, label %bb_cancel_initial8 i32 1, label %bb_cancel_suspended9 ]
bb_cancel_invalid10:
  call void @llvm.trap()
  unreachable
bb_cancel_initial8:
  br label %bb_cancel_cleanup7
bb_cancel_suspended9:
  br label %bb_cancel_cleanup7
bb_cancel_cleanup7:
  call void @sollang_free(ptr %context)
  ret void
}

define internal %sollang.task @sollang_fn_arrayChild(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state) #0 {
entry:
  %async_context26 = call ptr @sollang_alloc(i64 96)
  %async_context_field27 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 0
  store ptr %stdin, ptr %async_context_field27, align 8
  %async_context_field28 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 1
  store ptr %stdout, ptr %async_context_field28, align 8
  %async_context_field29 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 2
  store ptr %written, ptr %async_context_field29, align 8
  %async_context_field30 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 3
  store ptr %read, ptr %async_context_field30, align 8
  %async_context_field31 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 4
  store ptr %ok_state, ptr %async_context_field31, align 8
  %async_context_field32 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 5
  store i8 0, ptr %async_context_field32, align 1
  %async_context_field33 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 6
  store %sollang.struct.1448 zeroinitializer, ptr %async_context_field33, align 8
  %async_context_field34 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 7
  store ptr null, ptr %async_context_field34, align 8
  %async_context_field35 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 8
  store ptr null, ptr %async_context_field35, align 8
  %async_context_field36 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 9
  store ptr null, ptr %async_context_field36, align 8
  %async_handle37 = call ptr @sollang_task_start(ptr @sollang_fn_arrayChild_async_worker, ptr @sollang_free, ptr @sollang_fn_arrayChild_async_cancel, ptr %async_context26)
  %async_started38 = icmp ne ptr %async_handle37, null
  br i1 %async_started38, label %bb_async_ready11, label %bb_async_failed12
bb_async_failed12:
  call void @sollang_free(ptr %async_context26)
  call void @llvm.trap()
  unreachable
bb_async_ready11:
  %task_stored_result_address39 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 6
  %task_stored_result_slot40 = getelementptr %sollang.task_control, ptr %async_handle37, i32 0, i32 21
  store ptr %task_stored_result_address39, ptr %task_stored_result_slot40, align 8
  %task_stored_completion_slot41 = getelementptr %sollang.task_control, ptr %async_handle37, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot41, align 8
  %task42 = insertvalue %sollang.task poison, ptr %async_handle37, 0
  %task43 = insertvalue %sollang.task %task42, ptr %async_context26, 1
  ret %sollang.task %task43
}

define internal i1 @sollang_fn_secondChild_async_worker(ptr %control) #0 {
entry:
  %async_control_context_slot0 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %async_control_context_slot0, align 8
  %async_context_field1 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 0
  %stdin = load ptr, ptr %async_context_field1, align 8
  %async_context_field2 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 1
  %stdout = load ptr, ptr %async_context_field2, align 8
  %async_context_field3 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 2
  %written = load ptr, ptr %async_context_field3, align 8
  %async_context_field4 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 3
  %read = load ptr, ptr %async_context_field4, align 8
  %async_context_field5 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 4
  %ok_state = load ptr, ptr %async_context_field5, align 8
  %async_resume_state_slot6 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state7 = load i32, ptr %async_resume_state_slot6, align 4
  switch i32 %async_resume_state7, label %bb_async_state_invalid4 [ i32 0, label %bb_async_state_start0 i32 1, label %bb_async_cfg_resume1 i32 2, label %bb_async_cfg_resume2 i32 3, label %bb_async_cfg_resume3 ]
bb_async_state_invalid4:
  call void @llvm.trap()
  unreachable
bb_async_state_start0:
  store i32 1, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume1:
  store i32 2, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume2:
  store i32 3, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume3:
  %heap8 = call ptr @sollang_alloc(i64 12)
  %heap_ok9 = icmp ne ptr %heap8, null
  br i1 %heap_ok9, label %bb_alloc_ok5, label %bb_alloc_fail6

bb_alloc_fail6:
  call void @llvm.trap()
  unreachable

bb_alloc_ok5:
  %array_slot10 = getelementptr i32, ptr %heap8, i64 0
  store i32 7, ptr %array_slot10, align 4
  %array_slot11 = getelementptr i32, ptr %heap8, i64 1
  store i32 11, ptr %array_slot11, align 4
  %array_slot12 = getelementptr i32, ptr %heap8, i64 2
  store i32 13, ptr %array_slot12, align 4
  %generic_array_value13 = insertvalue %sollang.dynamic_int_array poison, ptr %heap8, 0
  %generic_array_value14 = insertvalue %sollang.dynamic_int_array %generic_array_value13, i64 3, 1
  %generic_array_value15 = insertvalue %sollang.dynamic_int_array %generic_array_value14, i64 3, 2
  %struct_init16 = insertvalue %sollang.struct.1448 poison, %sollang.dynamic_int_array %generic_array_value15, 0
  %async_result_address17 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 6
  store %sollang.struct.1448 %struct_init16, ptr %async_result_address17, align 8
  ret i1 true
}

define internal void @sollang_fn_secondChild_async_cancel(ptr %control) #0 {
entry:
  %cancel_context_slot18 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %cancel_context_slot18, align 8
  %cancel_status_slot19 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %cancel_status20 = load i32, ptr %cancel_status_slot19, align 4
  %cancel_completed21 = icmp eq i32 %cancel_status20, 2
  br i1 %cancel_completed21, label %bb_cancel_completed7, label %bb_cancel_pending8
bb_cancel_completed7:
  %cancel_result_address22 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %context, i32 0, i32 6
  %cancel_result23 = load %sollang.struct.1448, ptr %cancel_result_address22, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %cancel_result23)
  br label %bb_cancel_cleanup9
bb_cancel_pending8:
  %cancel_state_slot24 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %cancel_state25 = load i32, ptr %cancel_state_slot24, align 4
  switch i32 %cancel_state25, label %bb_cancel_invalid14 [ i32 0, label %bb_cancel_initial10 i32 1, label %bb_cancel_suspended11 i32 2, label %bb_cancel_suspended12 i32 3, label %bb_cancel_suspended13 ]
bb_cancel_invalid14:
  call void @llvm.trap()
  unreachable
bb_cancel_initial10:
  br label %bb_cancel_cleanup9
bb_cancel_suspended11:
  br label %bb_cancel_cleanup9
bb_cancel_suspended12:
  br label %bb_cancel_cleanup9
bb_cancel_suspended13:
  br label %bb_cancel_cleanup9
bb_cancel_cleanup9:
  call void @sollang_free(ptr %context)
  ret void
}

define internal %sollang.task @sollang_fn_secondChild(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state) #0 {
entry:
  %async_context26 = call ptr @sollang_alloc(i64 96)
  %async_context_field27 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 0
  store ptr %stdin, ptr %async_context_field27, align 8
  %async_context_field28 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 1
  store ptr %stdout, ptr %async_context_field28, align 8
  %async_context_field29 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 2
  store ptr %written, ptr %async_context_field29, align 8
  %async_context_field30 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 3
  store ptr %read, ptr %async_context_field30, align 8
  %async_context_field31 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 4
  store ptr %ok_state, ptr %async_context_field31, align 8
  %async_context_field32 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 5
  store i8 0, ptr %async_context_field32, align 1
  %async_context_field33 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 6
  store %sollang.struct.1448 zeroinitializer, ptr %async_context_field33, align 8
  %async_context_field34 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 7
  store ptr null, ptr %async_context_field34, align 8
  %async_context_field35 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 8
  store ptr null, ptr %async_context_field35, align 8
  %async_context_field36 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 9
  store ptr null, ptr %async_context_field36, align 8
  %async_handle37 = call ptr @sollang_task_start(ptr @sollang_fn_secondChild_async_worker, ptr @sollang_free, ptr @sollang_fn_secondChild_async_cancel, ptr %async_context26)
  %async_started38 = icmp ne ptr %async_handle37, null
  br i1 %async_started38, label %bb_async_ready15, label %bb_async_failed16
bb_async_failed16:
  call void @sollang_free(ptr %async_context26)
  call void @llvm.trap()
  unreachable
bb_async_ready15:
  %task_stored_result_address39 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_context26, i32 0, i32 6
  %task_stored_result_slot40 = getelementptr %sollang.task_control, ptr %async_handle37, i32 0, i32 21
  store ptr %task_stored_result_address39, ptr %task_stored_result_slot40, align 8
  %task_stored_completion_slot41 = getelementptr %sollang.task_control, ptr %async_handle37, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot41, align 8
  %task42 = insertvalue %sollang.task poison, ptr %async_handle37, 0
  %task43 = insertvalue %sollang.task %task42, ptr %async_context26, 1
  ret %sollang.task %task43
}

define internal i1 @sollang_fn_gate_async_worker(ptr %control) #0 {
entry:
  %async_control_context_slot0 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %async_control_context_slot0, align 8
  %async_context_field1 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 0
  %stdin = load ptr, ptr %async_context_field1, align 8
  %async_context_field2 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 1
  %stdout = load ptr, ptr %async_context_field2, align 8
  %async_context_field3 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 2
  %written = load ptr, ptr %async_context_field3, align 8
  %async_context_field4 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 3
  %read = load ptr, ptr %async_context_field4, align 8
  %async_context_field5 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 4
  %ok_state = load ptr, ptr %async_context_field5, align 8
  %async_resume_state_slot6 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state7 = load i32, ptr %async_resume_state_slot6, align 4
  switch i32 %async_resume_state7, label %bb_async_state_invalid4 [ i32 0, label %bb_async_state_start0 i32 1, label %bb_async_cfg_resume1 i32 2, label %bb_async_cfg_resume2 i32 3, label %bb_async_cfg_resume3 ]
bb_async_state_invalid4:
  call void @llvm.trap()
  unreachable
bb_async_state_start0:
  store i32 1, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume1:
  store i32 2, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume2:
  store i32 3, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume3:
  %async_result_address8 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 6
  store i32 0, ptr %async_result_address8, align 4
  ret i1 true
}

define internal void @sollang_fn_gate_async_cancel(ptr %control) #0 {
entry:
  %cancel_context_slot9 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %cancel_context_slot9, align 8
  %cancel_status_slot10 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %cancel_status11 = load i32, ptr %cancel_status_slot10, align 4
  %cancel_completed12 = icmp eq i32 %cancel_status11, 2
  br i1 %cancel_completed12, label %bb_cancel_completed5, label %bb_cancel_pending6
bb_cancel_completed5:
  br label %bb_cancel_cleanup7
bb_cancel_pending6:
  %cancel_state_slot13 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %cancel_state14 = load i32, ptr %cancel_state_slot13, align 4
  switch i32 %cancel_state14, label %bb_cancel_invalid12 [ i32 0, label %bb_cancel_initial8 i32 1, label %bb_cancel_suspended9 i32 2, label %bb_cancel_suspended10 i32 3, label %bb_cancel_suspended11 ]
bb_cancel_invalid12:
  call void @llvm.trap()
  unreachable
bb_cancel_initial8:
  br label %bb_cancel_cleanup7
bb_cancel_suspended9:
  br label %bb_cancel_cleanup7
bb_cancel_suspended10:
  br label %bb_cancel_cleanup7
bb_cancel_suspended11:
  br label %bb_cancel_cleanup7
bb_cancel_cleanup7:
  call void @sollang_free(ptr %context)
  ret void
}

define internal %sollang.task @sollang_fn_gate(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state) #0 {
entry:
  %async_context15 = call ptr @sollang_alloc(i64 72)
  %async_context_field16 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 0
  store ptr %stdin, ptr %async_context_field16, align 8
  %async_context_field17 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 1
  store ptr %stdout, ptr %async_context_field17, align 8
  %async_context_field18 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 2
  store ptr %written, ptr %async_context_field18, align 8
  %async_context_field19 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 3
  store ptr %read, ptr %async_context_field19, align 8
  %async_context_field20 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 4
  store ptr %ok_state, ptr %async_context_field20, align 8
  %async_context_field21 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 5
  store i8 0, ptr %async_context_field21, align 1
  %async_context_field22 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 6
  store i32 zeroinitializer, ptr %async_context_field22, align 4
  %async_context_field23 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 7
  store ptr null, ptr %async_context_field23, align 8
  %async_context_field24 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 8
  store ptr null, ptr %async_context_field24, align 8
  %async_context_field25 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 9
  store ptr null, ptr %async_context_field25, align 8
  %async_handle26 = call ptr @sollang_task_start(ptr @sollang_fn_gate_async_worker, ptr @sollang_free, ptr @sollang_fn_gate_async_cancel, ptr %async_context15)
  %async_started27 = icmp ne ptr %async_handle26, null
  br i1 %async_started27, label %bb_async_ready13, label %bb_async_failed14
bb_async_failed14:
  call void @sollang_free(ptr %async_context15)
  call void @llvm.trap()
  unreachable
bb_async_ready13:
  %task_stored_result_address28 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context15, i32 0, i32 6
  %task_stored_result_slot29 = getelementptr %sollang.task_control, ptr %async_handle26, i32 0, i32 21
  store ptr %task_stored_result_address28, ptr %task_stored_result_slot29, align 8
  %task_stored_completion_slot30 = getelementptr %sollang.task_control, ptr %async_handle26, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot30, align 8
  %task31 = insertvalue %sollang.task poison, ptr %async_handle26, 0
  %task32 = insertvalue %sollang.task %task31, ptr %async_context15, 1
  ret %sollang.task %task32
}

define internal i1 @sollang_fn_parent_async_worker(ptr %control) #0 {
entry:
  %async_control_context_slot0 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %async_control_context_slot0, align 8
  %async_context_field1 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 0
  %stdin = load ptr, ptr %async_context_field1, align 8
  %async_context_field2 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 1
  %stdout = load ptr, ptr %async_context_field2, align 8
  %async_context_field3 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 2
  %written = load ptr, ptr %async_context_field3, align 8
  %async_context_field4 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 3
  %read = load ptr, ptr %async_context_field4, align 8
  %async_context_field5 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 4
  %ok_state = load ptr, ptr %async_context_field5, align 8
  %async_resume_state_slot6 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %async_resume_state7 = load i32, ptr %async_resume_state_slot6, align 4
  switch i32 %async_resume_state7, label %bb_async_state_invalid3 [ i32 0, label %bb_async_state_start0 i32 1, label %bb_async_cfg_resume1 i32 2, label %bb_async_cfg_resume2 ]
bb_async_state_invalid3:
  call void @llvm.trap()
  unreachable
bb_async_state_start0:
  %write8 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.0, i64 14, ptr %written)
  %is_ok9 = icmp ne i32 %write8, 0
  %previous_ok10 = load i1, ptr %ok_state, align 1
  %ok11 = and i1 %previous_ok10, %is_ok9
  store i1 %ok11, ptr %ok_state, align 1
  %write12 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.module.x.1, i64 1, ptr %written)
  %is_ok13 = icmp ne i32 %write12, 0
  %previous_ok14 = load i1, ptr %ok_state, align 1
  %ok15 = and i1 %previous_ok14, %is_ok13
  store i1 %ok15, ptr %ok_state, align 1
  %task_call16 = call %sollang.task @sollang_fn_arrayChild(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state)
  %task_handle17 = extractvalue %sollang.task %task_call16, 0
  %task_context18 = extractvalue %sollang.task %task_call16, 1
  %task_stored_result_address19 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %task_context18, i32 0, i32 6
  %task_stored_result_slot20 = getelementptr %sollang.task_control, ptr %task_handle17, i32 0, i32 21
  store ptr %task_stored_result_address19, ptr %task_stored_result_slot20, align 8
  %task_stored_completion_slot21 = getelementptr %sollang.task_control, ptr %task_handle17, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot21, align 8
  %task_call22 = call %sollang.task @sollang_fn_secondChild(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state)
  %task_handle23 = extractvalue %sollang.task %task_call22, 0
  %task_context24 = extractvalue %sollang.task %task_call22, 1
  %task_stored_result_address25 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %task_context24, i32 0, i32 6
  %task_stored_result_slot26 = getelementptr %sollang.task_control, ptr %task_handle23, i32 0, i32 21
  store ptr %task_stored_result_address25, ptr %task_stored_result_slot26, align 8
  %task_stored_completion_slot27 = getelementptr %sollang.task_control, ptr %task_handle23, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot27, align 8
  %async_context_field28 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 7
  store ptr %task_handle17, ptr %async_context_field28, align 8
  %async_context_field29 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 8
  store ptr %task_context18, ptr %async_context_field29, align 8
  call void @sollang_task_park_on(ptr %control, ptr %task_handle17)
  %task_with_handle30 = insertvalue %sollang.task poison, ptr %task_handle23, 0
  %task_with_context31 = insertvalue %sollang.task %task_with_handle30, ptr %task_context24, 1
  %async_spill_frame32 = call ptr @sollang_alloc(i64 16)
  %async_context_field33 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 9
  store ptr %async_spill_frame32, ptr %async_context_field33, align 8
  %async_spill_address34 = getelementptr i8, ptr %async_spill_frame32, i64 0
  store %sollang.task %task_with_context31, ptr %async_spill_address34, align 8
  store i32 1, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume1:
  %async_spill_frame_address35 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 9
  %async_spill_frame36 = load ptr, ptr %async_spill_frame_address35, align 8
  %async_spill_address37 = getelementptr i8, ptr %async_spill_frame36, i64 0
  %async_spill_value38 = load %sollang.task, ptr %async_spill_address37, align 8
  %async_spill_task_handle39 = extractvalue %sollang.task %async_spill_value38, 0
  %async_spill_task_context40 = extractvalue %sollang.task %async_spill_value38, 1
  call void @sollang_free(ptr %async_spill_frame36)
  store ptr null, ptr %async_spill_frame_address35, align 8
  %async_child_handle_address41 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 7
  %async_child_handle42 = load ptr, ptr %async_child_handle_address41, align 8
  %async_child_context_address43 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 8
  %async_child_context44 = load ptr, ptr %async_child_context_address43, align 8
  %task_wait_succeeded45 = call i1 @sollang_task_join(ptr %async_child_handle42)
  br i1 %task_wait_succeeded45, label %bb_task_waited4, label %bb_task_wait_failed5
bb_task_wait_failed5:
  call void @llvm.trap()
  unreachable
bb_task_waited4:
  %task_result_address46 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_child_context44, i32 0, i32 6
  %task_result47 = load %sollang.struct.1448, ptr %task_result_address46, align 8
  %task_close_succeeded48 = call i1 @sollang_task_release(ptr %async_child_handle42)
  br i1 %task_close_succeeded48, label %bb_task_closed6, label %bb_task_close_failed7
bb_task_close_failed7:
  call void @llvm.trap()
  unreachable
bb_task_closed6:
  %async_context_field49 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 7
  store ptr %async_spill_task_handle39, ptr %async_context_field49, align 8
  %async_context_field50 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 8
  store ptr %async_spill_task_context40, ptr %async_context_field50, align 8
  call void @sollang_task_park_on(ptr %control, ptr %async_spill_task_handle39)
  %async_spill_frame51 = call ptr @sollang_alloc(i64 24)
  %async_context_field52 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 9
  store ptr %async_spill_frame51, ptr %async_context_field52, align 8
  %async_spill_address53 = getelementptr i8, ptr %async_spill_frame51, i64 0
  store %sollang.struct.1448 %task_result47, ptr %async_spill_address53, align 8
  store i32 2, ptr %async_resume_state_slot6, align 4
  ret i1 false
bb_async_cfg_resume2:
  %async_spill_frame_address54 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 9
  %async_spill_frame55 = load ptr, ptr %async_spill_frame_address54, align 8
  %async_spill_address56 = getelementptr i8, ptr %async_spill_frame55, i64 0
  %async_spill_value57 = load %sollang.struct.1448, ptr %async_spill_address56, align 8
  call void @sollang_free(ptr %async_spill_frame55)
  store ptr null, ptr %async_spill_frame_address54, align 8
  %async_child_handle_address58 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 7
  %async_child_handle59 = load ptr, ptr %async_child_handle_address58, align 8
  %async_child_context_address60 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 8
  %async_child_context61 = load ptr, ptr %async_child_context_address60, align 8
  %task_wait_succeeded62 = call i1 @sollang_task_join(ptr %async_child_handle59)
  br i1 %task_wait_succeeded62, label %bb_task_waited9, label %bb_task_wait_failed10
bb_task_wait_failed10:
  call void @llvm.trap()
  unreachable
bb_task_waited9:
  %task_result_address63 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, %sollang.struct.1448, ptr, ptr, ptr }, ptr %async_child_context61, i32 0, i32 6
  %task_result64 = load %sollang.struct.1448, ptr %task_result_address63, align 8
  %task_close_succeeded65 = call i1 @sollang_task_release(ptr %async_child_handle59)
  br i1 %task_close_succeeded65, label %bb_task_closed11, label %bb_task_close_failed12
bb_task_close_failed12:
  call void @llvm.trap()
  unreachable
bb_task_closed11:
  %heap66 = call ptr @sollang_alloc(i64 48)
  %heap_ok67 = icmp ne ptr %heap66, null
  br i1 %heap_ok67, label %bb_alloc_ok14, label %bb_alloc_fail15

bb_alloc_fail15:
  call void @llvm.trap()
  unreachable

bb_alloc_ok14:
  %inline_array_slot68 = getelementptr %sollang.struct.1448, ptr %heap66, i64 0
  store %sollang.struct.1448 %async_spill_value57, ptr %inline_array_slot68, align 8
  %inline_array_slot69 = getelementptr %sollang.struct.1448, ptr %heap66, i64 1
  store %sollang.struct.1448 %task_result64, ptr %inline_array_slot69, align 8
  %index_size70 = sext i32 0 to i64
  %inline_array_in_bounds71 = icmp ult i64 %index_size70, 2
  br i1 %inline_array_in_bounds71, label %bb_inline_array_bounds_ok16, label %bb_inline_array_bounds_fail17

bb_inline_array_bounds_fail17:
  call void @llvm.trap()
  unreachable

bb_inline_array_bounds_ok16:
  %inline_array_slot72 = getelementptr %sollang.struct.1448, ptr %heap66, i64 %index_size70
  %inline_array_item73 = load %sollang.struct.1448, ptr %inline_array_slot72, align 8
  %field74 = extractvalue %sollang.struct.1448 %inline_array_item73, 0
  %array_ptr75 = extractvalue %sollang.dynamic_int_array %field74, 0
  %array_len76 = extractvalue %sollang.dynamic_int_array %field74, 1
  %array_capacity77 = extractvalue %sollang.dynamic_int_array %field74, 2
  %array_len_value78 = trunc i64 %array_len76 to i32
  %index_size79 = sext i32 1 to i64
  %inline_array_in_bounds80 = icmp ult i64 %index_size79, 2
  br i1 %inline_array_in_bounds80, label %bb_inline_array_bounds_ok19, label %bb_inline_array_bounds_fail20

bb_inline_array_bounds_fail20:
  call void @llvm.trap()
  unreachable

bb_inline_array_bounds_ok19:
  %inline_array_slot81 = getelementptr %sollang.struct.1448, ptr %heap66, i64 %index_size79
  %inline_array_item82 = load %sollang.struct.1448, ptr %inline_array_slot81, align 8
  %field83 = extractvalue %sollang.struct.1448 %inline_array_item82, 0
  %array_ptr84 = extractvalue %sollang.dynamic_int_array %field83, 0
  %array_len85 = extractvalue %sollang.dynamic_int_array %field83, 1
  %array_capacity86 = extractvalue %sollang.dynamic_int_array %field83, 2
  %array_len_value87 = trunc i64 %array_len85 to i32
  %add88 = add i32 %array_len_value78, %array_len_value87
  %drop_array_slot89 = getelementptr %sollang.struct.1448, ptr %heap66, i64 0
  %drop_array_value90 = load %sollang.struct.1448, ptr %drop_array_slot89, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %drop_array_value90)
  %drop_array_slot91 = getelementptr %sollang.struct.1448, ptr %heap66, i64 1
  %drop_array_value92 = load %sollang.struct.1448, ptr %drop_array_slot91, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %drop_array_value92)
  call void @sollang_free(ptr %heap66)
  %async_result_address93 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 6
  store i32 %add88, ptr %async_result_address93, align 4
  ret i1 true
}

define internal void @sollang_fn_parent_async_cancel(ptr %control) #0 {
entry:
  %cancel_context_slot94 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 0
  %context = load ptr, ptr %cancel_context_slot94, align 8
  %cancel_status_slot95 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 4
  %cancel_status96 = load i32, ptr %cancel_status_slot95, align 4
  %cancel_completed97 = icmp eq i32 %cancel_status96, 2
  br i1 %cancel_completed97, label %bb_cancel_completed21, label %bb_cancel_pending22
bb_cancel_completed21:
  br label %bb_cancel_cleanup23
bb_cancel_pending22:
  %cancel_state_slot98 = getelementptr %sollang.task_control, ptr %control, i32 0, i32 5
  %cancel_state99 = load i32, ptr %cancel_state_slot98, align 4
  switch i32 %cancel_state99, label %bb_cancel_invalid27 [ i32 0, label %bb_cancel_initial24 i32 1, label %bb_cancel_suspended25 i32 2, label %bb_cancel_suspended26 ]
bb_cancel_invalid27:
  call void @llvm.trap()
  unreachable
bb_cancel_initial24:
  br label %bb_cancel_cleanup23
bb_cancel_suspended25:
  %cancel_child_handle_address100 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 7
  %cancel_child_handle101 = load ptr, ptr %cancel_child_handle_address100, align 8
  %task_cancel_succeeded102 = call i1 @sollang_task_cancel(ptr %cancel_child_handle101)
  br i1 %task_cancel_succeeded102, label %bb_task_cancelled28, label %bb_task_cancel_failed29
bb_task_cancel_failed29:
  call void @llvm.trap()
  unreachable
bb_task_cancelled28:
  %cancel_spill_frame_address103 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 9
  %cancel_spill_frame104 = load ptr, ptr %cancel_spill_frame_address103, align 8
  %cancel_spill_address105 = getelementptr i8, ptr %cancel_spill_frame104, i64 0
  %cancel_spill_value106 = load %sollang.task, ptr %cancel_spill_address105, align 8
  %cancel_spill_task_handle107 = extractvalue %sollang.task %cancel_spill_value106, 0
  %task_cancel_succeeded108 = call i1 @sollang_task_cancel(ptr %cancel_spill_task_handle107)
  br i1 %task_cancel_succeeded108, label %bb_task_cancelled30, label %bb_task_cancel_failed31
bb_task_cancel_failed31:
  call void @llvm.trap()
  unreachable
bb_task_cancelled30:
  call void @sollang_free(ptr %cancel_spill_frame104)
  br label %bb_cancel_cleanup23
bb_cancel_suspended26:
  %cancel_child_handle_address109 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 7
  %cancel_child_handle110 = load ptr, ptr %cancel_child_handle_address109, align 8
  %task_cancel_succeeded111 = call i1 @sollang_task_cancel(ptr %cancel_child_handle110)
  br i1 %task_cancel_succeeded111, label %bb_task_cancelled32, label %bb_task_cancel_failed33
bb_task_cancel_failed33:
  call void @llvm.trap()
  unreachable
bb_task_cancelled32:
  %cancel_spill_frame_address112 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %context, i32 0, i32 9
  %cancel_spill_frame113 = load ptr, ptr %cancel_spill_frame_address112, align 8
  %cancel_spill_address114 = getelementptr i8, ptr %cancel_spill_frame113, i64 0
  %cancel_spill_value115 = load %sollang.struct.1448, ptr %cancel_spill_address114, align 8
  call void @sollang_drop_1448(%sollang.struct.1448 %cancel_spill_value115)
  call void @sollang_free(ptr %cancel_spill_frame113)
  br label %bb_cancel_cleanup23
bb_cancel_cleanup23:
  call void @sollang_free(ptr %context)
  ret void
}

define internal %sollang.task @sollang_fn_parent(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state) #0 {
entry:
  %async_context116 = call ptr @sollang_alloc(i64 72)
  %async_context_field117 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 0
  store ptr %stdin, ptr %async_context_field117, align 8
  %async_context_field118 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 1
  store ptr %stdout, ptr %async_context_field118, align 8
  %async_context_field119 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 2
  store ptr %written, ptr %async_context_field119, align 8
  %async_context_field120 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 3
  store ptr %read, ptr %async_context_field120, align 8
  %async_context_field121 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 4
  store ptr %ok_state, ptr %async_context_field121, align 8
  %async_context_field122 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 5
  store i8 0, ptr %async_context_field122, align 1
  %async_context_field123 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 6
  store i32 zeroinitializer, ptr %async_context_field123, align 4
  %async_context_field124 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 7
  store ptr null, ptr %async_context_field124, align 8
  %async_context_field125 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 8
  store ptr null, ptr %async_context_field125, align 8
  %async_context_field126 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 9
  store ptr null, ptr %async_context_field126, align 8
  %async_handle127 = call ptr @sollang_task_start(ptr @sollang_fn_parent_async_worker, ptr @sollang_free, ptr @sollang_fn_parent_async_cancel, ptr %async_context116)
  %async_started128 = icmp ne ptr %async_handle127, null
  br i1 %async_started128, label %bb_async_ready34, label %bb_async_failed35
bb_async_failed35:
  call void @sollang_free(ptr %async_context116)
  call void @llvm.trap()
  unreachable
bb_async_ready34:
  %task_stored_result_address129 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %async_context116, i32 0, i32 6
  %task_stored_result_slot130 = getelementptr %sollang.task_control, ptr %async_handle127, i32 0, i32 21
  store ptr %task_stored_result_address129, ptr %task_stored_result_slot130, align 8
  %task_stored_completion_slot131 = getelementptr %sollang.task_control, ptr %async_handle127, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot131, align 8
  %task132 = insertvalue %sollang.task poison, ptr %async_handle127, 0
  %task133 = insertvalue %sollang.task %task132, ptr %async_context116, 1
  ret %sollang.task %task133
}

@.slg.str.suffix.0 = private unnamed_addr constant [9 x i8] c"cancelled", align 1
@.slg.str.suffix.1 = private unnamed_addr constant [1 x i8] c"\0A", align 1
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
  %direct_flush_ok = icmp ne i32 %flushed_direct, 0
  br i1 %direct_flush_ok, label %write_direct, label %write_failure

write_direct:
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
  %buffer_flush_ok = icmp ne i32 %flushed, 0
  br i1 %buffer_flush_ok, label %flushed_buffer, label %write_failure

flushed_buffer:
  br label %append

append:
  %offset = phi i64 [ %count, %buffer_prepare ], [ 0, %flushed_buffer ]
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

write_failure:
  store i32 0, ptr %written, align 4
  ret i32 0

done:
  ret i32 1
}

define internal i32 @sollang_read_stdin(ptr %stdin, ptr %data, i64 %len64, ptr %read) #0 {
entry:
  %stdout = inttoptr i64 1 to ptr
  %written = alloca i32, align 4
  %flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %flush_ok = icmp ne i32 %flushed, 0
  br i1 %flush_ok, label %read_bytes, label %read_failure

read_bytes:
  %read64 = call i64 @read(i32 0, ptr %data, i64 %len64)
  %read32 = trunc i64 %read64 to i32
  store i32 %read32, ptr %read, align 4
  %ok = icmp sge i64 %read64, 0
  %ok32 = zext i1 %ok to i32
  ret i32 %ok32

read_failure:
  store i32 0, ptr %read, align 4
  ret i32 0
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
  store i1 true, ptr %ok_state, align 1
  %stdin = inttoptr i64 0 to ptr
  %stdout = inttoptr i64 1 to ptr
  %stdout_is_tty_status = call i32 @isatty(i32 1)
  %stdout_is_tty = icmp ne i32 %stdout_is_tty_status, 0
  store i1 %stdout_is_tty, ptr @sollang_stdout_line_buffered, align 1
  %task_call0 = call %sollang.task @sollang_fn_parent(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state)
  %task_handle1 = extractvalue %sollang.task %task_call0, 0
  %task_context2 = extractvalue %sollang.task %task_call0, 1
  %task_stored_result_address3 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %task_context2, i32 0, i32 6
  %task_stored_result_slot4 = getelementptr %sollang.task_control, ptr %task_handle1, i32 0, i32 21
  store ptr %task_stored_result_address3, ptr %task_stored_result_slot4, align 8
  %task_stored_completion_slot5 = getelementptr %sollang.task_control, ptr %task_handle1, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot5, align 8
  %task_call6 = call %sollang.task @sollang_fn_gate(ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state)
  %task_handle7 = extractvalue %sollang.task %task_call6, 0
  %task_context8 = extractvalue %sollang.task %task_call6, 1
  %task_stored_result_address9 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %task_context8, i32 0, i32 6
  %task_stored_result_slot10 = getelementptr %sollang.task_control, ptr %task_handle7, i32 0, i32 21
  store ptr %task_stored_result_address9, ptr %task_stored_result_slot10, align 8
  %task_stored_completion_slot11 = getelementptr %sollang.task_control, ptr %task_handle7, i32 0, i32 22
  store ptr null, ptr %task_stored_completion_slot11, align 8
  %task_wait_succeeded12 = call i1 @sollang_task_join(ptr %task_handle7)
  br i1 %task_wait_succeeded12, label %bb_task_waited0, label %bb_task_wait_failed1
bb_task_wait_failed1:
  call void @llvm.trap()
  unreachable
bb_task_waited0:
  %task_result_address13 = getelementptr { ptr, ptr, ptr, ptr, ptr, i8, i32, ptr, ptr, ptr }, ptr %task_context8, i32 0, i32 6
  %task_result14 = load i32, ptr %task_result_address13, align 4
  %task_close_succeeded15 = call i1 @sollang_task_release(ptr %task_handle7)
  br i1 %task_close_succeeded15, label %bb_task_closed2, label %bb_task_close_failed3
bb_task_close_failed3:
  call void @llvm.trap()
  unreachable
bb_task_closed2:
  %task_cancel_succeeded16 = call i1 @sollang_task_cancel(ptr %task_handle1)
  br i1 %task_cancel_succeeded16, label %bb_task_cancelled4, label %bb_task_cancel_failed5
bb_task_cancel_failed5:
  call void @llvm.trap()
  unreachable
bb_task_cancelled4:
  %write17 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.0, i64 9, ptr %written)
  %is_ok18 = icmp ne i32 %write17, 0
  %previous_ok19 = load i1, ptr %ok_state, align 1
  %ok20 = and i1 %previous_ok19, %is_ok18
  store i1 %ok20, ptr %ok_state, align 1
  %write21 = call i32 @sollang_write(ptr %stdout, ptr @.slg.str.suffix.1, i64 1, ptr %written)
  %is_ok22 = icmp ne i32 %write21, 0
  %previous_ok23 = load i1, ptr %ok_state, align 1
  %ok24 = and i1 %previous_ok23, %is_ok22
  store i1 %ok24, ptr %ok_state, align 1
  call void @sollang_async_shutdown()
  %stdout_flushed = call i32 @sollang_flush_stdout(ptr %stdout, ptr %written)
  %stdout_flush_ok = icmp ne i32 %stdout_flushed, 0
  %stdout_previous_ok = load i1, ptr %ok_state, align 1
  %stdout_exit_ok = and i1 %stdout_previous_ok, %stdout_flush_ok
  store i1 %stdout_exit_ok, ptr %ok_state, align 1
  %final_ok25 = load i1, ptr %ok_state, align 1
  %exit26 = select i1 %final_ok25, i32 0, i32 1
  ret i32 %exit26
}

attributes #0 = { nounwind }
