from pathlib import Path
import json
B=Path('artifacts/scratch/resume-20261006-owner-continuation22')
cases=[]
def add(name,source,expected):cases.append(dict(id=name,source=source,warnings=[],expected=expected))
def promoted(line,end,size=8,endKind='BindingStatement',function=None):
 kind='DictionaryLiteralExpression' if size==56 else 'ArrayLiteralExpression'
 result=[f'main|slots:{size}/8',f'main|alloc:{kind}@{line},0,{size}',f'main|end:{endKind}@{end},0,{size}']
 if function:result.append(f'function:{function}@1|slots:')
 return result
view='readFirst values: [Int] -> Int => values[0]\n\n'
add('readonly-view-primary',view+'main {\n    [1, 2; ~] => values\n    values -> readFirst => first\n}\n',promoted(4,5,function='readFirst'))
add('readonly-view-prefix',view+'main {\n    [1, 2; ~] => values\n    readFirst(values) => first\n}\n',promoted(4,5,function='readFirst'))
add('owning-input-rejects-payload','readOwnedFirst values: [Int; ~] -> Int => values[0]\n\nmain {\n    [1, 2; ~] => values\n    values -> readOwnedFirst => first\n}\n',['main|slots:','function:readOwnedFirst@1|slots:'])
add('additional-view-conservative-rejection','withFallback fallback: Int, values: [Int] -> Int => fallback + values[0]\n\nmain {\n    [1, 2; ~] => values\n    0 -> withFallback(values) => first\n}\n',['main|slots:','function:withFallback@1|slots:'])
add('direct-owner-alias-rejects-payload','main {\n    [1, 2; ~] => values\n    values => alias\n    alias[0] => first\n}\n',['main|slots:'])
add('readonly-fold-input','main {\n    [1, 2; ~] => values\n    values -> fold 0 total, item { total + item } => sum\n}\n',promoted(2,3))
add('readonly-each-input','main {\n    [1, 2; ~] => values\n    values -> each item { item -> println }\n}\n',promoted(2,3,endKind='BlockFunctionCallStatement'))
add('later-escape-rejects-all-uses','main {\n    [1, 2; ~] => values\n    values[0] => first\n    values -> append(3) => grown\n}\n',['main|slots:'])
add('unused-immutable-payload','main {\n    [1, 2; ~] => values\n}\n',promoted(2,2))
add('mutable-owner-header-only','main {\n    [1, 2; ~] => values!\n    values! -> push(3)\n    values![0] => first\n}\n',['main|slots:24/8','main|alloc:BindingStatement@2,0,24'])
add('readonly-dictionary-function','readScore scores: {Int: Int} -> Int => scores[1]\n\nmain {\n    { 1: 2 } => scores\n    scores -> readScore => first\n}\n',promoted(4,5,56,function='readScore'))
add('dictionary-transform-rejects-payload','main {\n    { 1: 2 } => scores\n    scores -> updated(1, 3) => changed\n}\n',['main|slots:'])
add('nested-readonly-use','main {\n    [1, 2; ~] => values\n    true -> if {\n        values[0] -> println\n    } else {\n        0 -> println\n    }\n}\n',promoted(2,3,endKind='ExpressionStatement'))
add('loop-transfer-conservative-rejection','main {\n    true -> while {\n        [1, 2; ~] => values\n        values[0] => first\n        break\n    }\n}\n',['main|slots:'])
p=Path('tests/Sollang.ExampleTests/Fixtures/storage-placement-readonly-controls.json')
p.write_text(json.dumps(dict(schemaVersion=1,scope='source-frames',cases=cases),indent=2)+'\n',encoding='utf-8')
(B/'readonly17038-reference14.json').write_bytes(p.read_bytes())
s=(B/'candidates17007-reference22.py').read_text().replace('candidates17007-reference22','readonly17038-reference14').replace('==22','==14')
(B/'readonly17038-reference14.py').write_text(s,encoding='utf-8')
