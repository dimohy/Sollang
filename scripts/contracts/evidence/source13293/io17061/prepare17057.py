from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');cases=json.loads(Path('tests/Sollang.ExampleTests/Fixtures/storage-placement-readonly-controls.json').read_text())['cases']
s='''import sollang.compiler.semantic.analysis as analysis
import sys.file as file

capture source: Text -> Unit uses File {
    [source,; ~] -> analysis.analyze => package
    package.ranges[0] => range
    range.astCount -> file.write
    package.nodes -> each node {
'''
for f in ['kind','parent','payloadToken','secondaryToken','tertiaryToken','flags','firstToken','tokenCount','start','length']:s+=f'        Int(node.{f}) -> file.write\n'
s+='''    }
    range.tokenCount -> file.write
    package.tokens -> each token {
        token.kind -> file.write
        Int(token.span.start) -> file.write
        Int(token.span.length) -> file.write
    }
}

main {
    "artifacts/scratch/resume-20261006-owner-continuation22/readonly17057-ast.bin" -> file.openWriter
'''
for i,c in enumerate(cases):s+='    """\n'+''.join('    '+x+'\n' for x in c['source'].splitlines())+f'    """ => source{i}\n    source{i} -> capture\n'
s+='    file.closeWriter()\n    "captured13" -> println\n}\n';(b/'readonly17057-ast.slg').write_text(s,encoding='utf-8')
d=json.loads((b/'uses17020-contract22.json').read_text());d['scope']='Bounded diagnostic capture of source-local AST/token contracts for13 existing CSharp readonly reference sources; no readonly admission acceptance.';d['cases'][0].update(id='readonly-ast-capture13',source=(b/'readonly17057-ast.slg').as_posix(),stdout='captured13');d['cases'][0]['additionalSources']=[p for p in d['cases'][0]['additionalSources'] if 'placement16881-candidate' not in p];d['formatCheckSources']=[(b/'readonly17057-ast.slg').as_posix()];d['runtimeInputFiles']=['tests/Sollang.ExampleTests/Fixtures/storage-placement-readonly-controls.json',(b/'readonly17039-reference13/source-frame-result.json').as_posix()];(b/'readonly17057-ast.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
