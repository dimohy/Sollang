from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[4];e=Path(__file__).resolve().parent
record=json.loads((e/'baseline-contract12520.json').read_text(encoding='utf-8-sig'))
assert hashlib.sha256((root/record['source']).read_bytes()).hexdigest().upper()==record['sourceSha256']
assert record['managed']['runExit']==record['native']['runExit']==0
assert record['managed']['stdout']=='4294967295\ninterpolated=4294967295\n-1\n'
assert record['native']['stdout']=='-1\ninterpolated=4294967295\n-1\n'
llvm=(e/'baseline.llvm.txt').read_text(encoding='utf-8-sig')
assert 'call void @sollang_runtime_print_i32(i32 %v' in llvm
assert 'call void @sollang_runtime_print_i64(i64 %v' in llvm
print('Frozen UInt32 maximum: CSharp prints4294967295; native prints-1 directly but4294967295 in interpolation. Genuine matching build0/run0 records; no repeated program execution.')
