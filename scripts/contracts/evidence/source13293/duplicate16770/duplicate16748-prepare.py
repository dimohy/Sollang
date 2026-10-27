from pathlib import Path
import json,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'duplicate16748-input';out.mkdir(exist_ok=False)
cases=[]
def add(id,files,exit,fragment='',stdout=''):
 paths=[]
 for name,source in files.items():
  p=out/id/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(source,encoding='utf-8');paths.append(p.relative_to(root).as_posix())
 cases.append(dict(id=id,sources=paths,expectedExit=exit,expectedFragment=fragment,expectedStdout=stdout))
add('distinct-functions',{'main.slg':'import alpha as a\nmain {\n    1 -> a.first => x\n    2 -> a.second => y\n    x + y -> println\n}\n','first.slg':'namespace alpha\npublic first value: Int -> Int { value }\n','second.slg':'namespace alpha\npublic second value: Int -> Int { value }\n'},0,stdout='3')
add('same-file',{'main.slg':'f value: Int -> Int { value }\nf other: Int -> Int { other }\nmain { 1 -> println }\n'},1,"function 'f' already exists")
add('different-arity',{'main.slg':'f value: Int -> Int { value }\nf value: Int, other: Int -> Int { value + other }\nmain { 1 -> println }\n'},1,"function 'f' already exists")
add('different-namespaces',{'main.slg':'import alpha as a\nimport beta as b\nmain {\n    1 -> a.value => x\n    2 -> b.value => y\n    x + y -> println\n}\n','first.slg':'namespace alpha\npublic value input: Int -> Int { input }\n','second.slg':'namespace beta\npublic value input: Int -> Int { input }\n'},0,stdout='3')
add('namespace-trivia',{'main.slg':'import alpha.beta as a\nmain { 1 -> a.value -> println }\n','first.slg':'namespace alpha . /* same logical path */ beta\npublic value input: Int -> Int { input }\n','second.slg':'namespace alpha.beta\npublic value other: Int -> Int { other }\n'},1,"function 'alpha.beta.value' already exists")
add('local-scope',{'main.slg':'outerA value: Int -> Int {\n    local input: Int -> Int { input }\n    value -> local\n}\nouterB value: Int -> Int {\n    local input: Int -> Int { input }\n    value -> local\n}\nmain {\n    1 -> outerA => x\n    2 -> outerB => y\n    x + y -> println\n}\n'},0,stdout='3')
add('earlier-bad-signature',{'main.slg':'bad value: Missing -> Int { 1 }\nf value: Int -> Int { value }\nf other: Int -> Int { other }\nmain { 1 -> println }\n'},1,'Missing')
add('duplicate-before-bad-signature',{'main.slg':'f value: Int -> Int { value }\nf other: Missing -> Int { 1 }\nmain { 1 -> println }\n'},1,"function 'f' already exists")
add('duplicate-before-body-error',{'main.slg':'f value: Int -> Int { missing }\nf other: Int -> Int { other }\nmain { 1 -> println }\n'},1,"function 'f' already exists")
fixture=b/'runner16643-fixture/examples/regression';cases.insert(0,dict(id='original-cross-module',sources=[str((fixture/x).relative_to(root)).replace('\\','/') for x in ['diagnostics/module-duplicate.slg','diagnostics/duplicate/first.slg','diagnostics/duplicate/second.slg']],expectedExit=1,expectedFragment="function 'duplicate.module.value' already exists",expectedStdout=''))
plan=dict(schemaVersion=1,scope='CSharp-first declaration uniqueness and priority controls. Original duplicate fixture unchanged; nine new focused controls. No canonical source implementation change.',cases=cases,caseBudgetSeconds=180,expectedManagedDllSha256='375D9B7D7448758904AFE49F1F8DDD9136E218EFFCC75A221E63C395B501DDB1');(b/'duplicate16748-reference10.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8');print('prepared ten CSharp-first controls')
