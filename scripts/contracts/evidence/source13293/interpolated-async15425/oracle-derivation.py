from pathlib import Path
import json,re,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22'; d=root/'scripts/probes/async-task-observability'
source=(b/'async15352-generic-interpolation-source-locator.slg').read_bytes(); p=d/'generic-interpolation-suspension-locator.slg';p.write_bytes(source)
text=source.decode();old=(d/'parent-child-states.expected.txt').read_text().replace('\r\n','\n')
module='probes.async_task_observability.generic_interpolation_source_locator'
def location(needle):
    offset=text.index(needle)+len(needle)-len(needle.split()[-1]);prefix=text[:offset];line=prefix.count('\n')+1;column=len(prefix.rsplit('\n',1)[-1].encode('utf-16-le'))//2+1
    return len(prefix.encode()),line,column
positions={'parent':location('childTask -> await'),'child':location('delay -> sleep -> await'),'sleep':location('delay -> sleep')}
expected=old.replace('probes.async_task_observability.parent_child_states',module)
def replace(m):
    who='sleep' if m[1]=='child' and int(m[3])==30 else m[1];offset,line,column=positions[who]
    return f'functionSymbol={m[1]};resumeState=1;byteOffset={offset};line={line};column={column}'
expected=re.sub(r'functionSymbol=(parent|child);resumeState=1;byteOffset=\d+;line=(\d+);column=(\d+)',replace,expected)
expected=expected.replace('snapshot sessionId=1 written=2','한글😀 snapshot sessionId=1 written=2',1).replace('\n7\nsnapshot','\n7\n42\nsnapshot')
expected+=expected.replace('sessionId=1','sessionId=2')
assert expected==(b/'async15382-managed-interpolation-run/command.stdout').read_text(encoding='utf-8').replace('\r\n','\n')
simple='''namespace probes.async_task_observability.multiple_interpolated_awaits

child: -> async Int {
    yield
    7
}

format<T>: -> async Unit uses Console {
    child() => first
    child() => second
    "한글😀 $(first -> await) / $(second -> await)" -> println
}

main {
    probes.async_task_observability.multiple_interpolated_awaits.format<Int>() => firstTask
    firstTask -> await
    probes.async_task_observability.multiple_interpolated_awaits.format<Bool>() => secondTask
    secondTask -> await
}
'''
(d/'multiple-interpolated-awaits.slg').write_bytes(simple.encode())
deferred=simple.replace('multiple_interpolated_awaits','deferred_interpolated_awaits').replace('" -> println','" => rendered\n    rendered -> println')
(d/'deferred-interpolated-awaits.slg').write_bytes(deferred.encode())
cases=[dict(id='generic-interpolation-suspension-locator',source=str(p.relative_to(root)).replace('\\','/'),exit=0,stdout=expected.strip(),expectedRawStdout=expected,stderr='')]
arena=simple.replace('multiple_interpolated_awaits','arena_interpolated_awaits').replace('    child() => first','    Arena(64) => owner!\n    child() => first').replace('" -> println','" -> materialize(owner!) => rendered\n    rendered -> println')
(d/'arena-interpolated-awaits.slg').write_bytes(arena.encode())
for name in ['multiple-interpolated-awaits','arena-interpolated-awaits']:
    output='한글😀 7 / 7\n한글😀 7 / 7\n';cases.append(dict(id=name,source=f'scripts/probes/async-task-observability/{name}.slg',exit=0,stdout=output.strip(),expectedRawStdout=output,stderr=''))
cases.append(dict(id='deferred-interpolated-awaits-rejected',source='scripts/probes/async-task-observability/deferred-interpolated-awaits.slg',exit=1,stdout='',stderr="sollang: semantic error at 11:5: [module 'probes.async_task_observability.deferred_interpolated_awaits'] deferred interpolation cannot be stored directly; materialize it into an explicit Arena owner"))
contract=dict(schemaVersion=1,scope='Additional interpolation-contained async suspension and source identity. Exact inherited parent-child scheduling oracle plus independently computed UTF8/UTF16 locations; direct and deferred multiple-hole controls.',expectedManagedDllSha256=hashlib.sha256((b/'managed15386/compiler/Sollang.Compiler.dll').read_bytes()).hexdigest().upper(),harnessBuildJobs=1,harnessBuildOptimization='-O1',cases=cases,semanticPreflightProof=str((b/'async15320-semantic/result.json').relative_to(root)).replace('\\','/'),stdlibSourcePreflightProof=str((b/'async15318-stdlib/result.json').relative_to(root)).replace('\\','/'))
(b/'interpolation15392-contract4.json').write_bytes((json.dumps(contract,ensure_ascii=False,indent=2)+'\n').encode())
print(json.dumps(dict(status='oracles-derived',positions=positions,sourceCases=len(cases))))
