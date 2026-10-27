from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');o=Path('scripts/probes/io-failure-abi');o.mkdir(exist_ok=True)
sources={
'unit-write-success':('''emit value: Int -> Unit uses File { value -> file.write }
main {
    "artifacts/scratch/resume-20261006-owner-continuation22/io17062-success.bin" -> file.openWriter
    42 -> emit
    file.closeWriter()
    "ok" -> println
}
''','ok',0),
'unit-write-failure':('''emit value: Int -> Unit uses File { value -> file.write }
main {
    42 -> emit
    "after" -> println
}
''','',1),
'int-write-failure':('''emit value: Int -> Int uses File { value -> file.write; 7 }
main {
    42 -> emit => value
    "after=$value" -> println
}
''','',1),
'bool-write-failure':('''emit value: Int -> Bool uses File { value -> file.write; true }
main {
    42 -> emit => value
    "after=$value" -> println
}
''','',1),
'product-write-failure':('''emit value: Int -> (left: Int, right: Int) uses File { value -> file.write; (left: value, right: 7) }
main {
    42 -> emit => value
    "after" -> println
}
''','',1),
'unit-open-failure':('''open: -> Unit uses File {
    "artifacts/scratch/resume-20261006-owner-continuation22/io17062-missing-parent/no.bin" -> file.openWriter
}
main {
    open()
    "after" -> println
}
''','',1),
'unit-legacy-write-failure':('''emit value: Int -> Unit uses File { value -> file.writeInt }
main {
    42 -> emit
    "after" -> println
}
''','',1),
'main-write-failure':('''main {
    42 -> file.write
    "after" -> println
}
''','',1)
}
d=dict(schemaVersion=1,scope='C745 CSharp first runtime I/O failure ABI: exact success output and exit1 without downstream effects across entry/Unit/Int/Bool/product/open/legacy paths. Case180/retry0.',expectedManagedDllSha256='556889B756A7F4E78899B3A8D0C9AF4131C37B9BAC825AC47ECBFF0831B2970F',formatCheckSources=[],cases=[],runtimeInputFiles=['scripts/contracts/evidence/source13293/io17061/baseline.json'])
for name,(src,stdout,exitcode) in sources.items():
 p=o/(name+'.slg');p.write_text('import sys.file as file\n\n'+src.replace('; ','\n    '),encoding='utf-8');d['formatCheckSources'].append(p.as_posix());d['cases'].append(dict(id=name,source=p.as_posix(),exit=0,stderr='',stdout=stdout,runStderr='',expectedRuntimeExit=exitcode))
(b/'io17062-managed8.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
