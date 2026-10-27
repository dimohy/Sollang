from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');cases=json.loads(Path('tests/Sollang.ExampleTests/Fixtures/storage-placement-readonly-controls.json').read_text())['cases']
s='''import sollang.compiler.semantic.context as semanticContext
import sollang.compiler.semantic.storage_placement_source_index as sourceIndex
import sollang.compiler.semantic.storage_placement_units as sourceUnits
import sollang.compiler.semantic.storage_placement_uses as uses
import sollang.compiler.semantic.storage_placement_literals as literals
import sys.process as process

inspect label: Text, source: Text -> Unit uses Console, Process {
    [source,; ~] -> semanticContext.prepare => prepared
    prepared.package.ranges[0] => range
    range.astStart -> sourceIndex.build(range.astCount, prepared.package.nodes) -> when {
        Err(_) { process.exit(1) }
        Ok(indexed) { prepared.package -> sourceUnits.build(0, indexed) -> when {
                Err(_) { process.exit(2) }
                Ok(units) {
                    -1 => binding!
                    literals.Kind.DynamicArray => kind!
                    0 => index!
                    index! < range.astCount -> while {
                        prepared.package.nodes[range.astStart + index!] => node
                        node.kind == 9 -> if {
                            indexed.firstChild[index!] => child
                            child >= 0 -> if {
                                prepared.package.nodes[range.astStart + child].kind => shape
                                shape == 37 or shape == 38 -> if {
                                    index! => binding!
                                    shape == 38 -> if { literals.Kind.Dictionary => kind! }
                                }
                            }
                        }
                        index! + 1 => index!
                    }
                    binding! < 0 -> if { process.exit(3) }
                    binding! -> uses.readonlyPayload(kind!, source, prepared, 0, indexed, units) -> when {
                        Err(_) { process.exit(4) }
                        Ok(admitted) { "$label|$admitted" -> println }
                    }
                }
        } }
    }
}

main {
'''
expected=[]
for i,c in enumerate(cases):
 s+='    """\n'+''.join('    '+x+'\n' for x in c['source'].splitlines())+f'    """ => source{i}\n    '+json.dumps(c['id'])+f' -> inspect(source{i})\n';admit=any('|alloc:ArrayLiteralExpression' in x or '|alloc:DictionaryLiteralExpression' in x for x in c['expected']);expected.append(c['id']+'|'+str(admit).lower())
s+='}\n';(b/'readonly17082-probe13.slg').write_text(s,encoding='utf-8');d=json.loads((b/'uses17020-contract22.json').read_text());p=d['cases'][0];p.update(id='readonly-admission13',source=(b/'readonly17082-probe13.slg').as_posix(),stdout='\n'.join(expected));p['additionalSources'] += [(b/'placement16881-candidate/storage_placement_readonly.slg').as_posix(),(b/'placement16881-candidate/storage_placement_literals.slg').as_posix()];d['formatCheckSources']=[p['source'],(b/'placement16881-candidate/storage_placement_readonly.slg').as_posix()];d['runtimeInputFiles']=['tests/Sollang.ExampleTests/Fixtures/storage-placement-readonly-controls.json',(b/'readonly17039-reference13/source-frame-result.json').as_posix(),(b/'readonly17051-source-comparison.json').as_posix()];d['expectedManagedDllSha256']='672CD039C491A57E7C26472FEEFB886552DF2A6560DCDC0673467DA7B7B82B98';d['scope']='C742 first readonly admission13 against qualified CSharp payload decisions; includes diagnostic-only unused growable case. Legacy interpolation precision and wider statement coverage remain pending.';(b/'readonly17082-contract13.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
