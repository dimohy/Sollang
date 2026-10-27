from pathlib import Path
import re,json
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'duplicate16756-candidate';out.mkdir(exist_ok=False)
s=(b/'duplicate16746-candidate/semantic-diagnostics.slg').read_text(encoding='utf-8-sig')
old='firstFunctionNameDiagnostic prepared: ref semanticContext.SemanticSnapshot, declaredEffects: ref effects.DeclaredEffectIndex -> ExpressionOperandDiagnostic {'
assert s.count(old)==1;s=s.replace(old,'functionNameDiagnostic prepared: ref semanticContext.SemanticSnapshot, declaredEffects: ref effects.DeclaredEffectIndex, includeLocal: Bool -> ExpressionOperandDiagnostic {')
start=s.index('functionNameDiagnostic prepared:');end=s.index('\n# Repeat owns',start);part=s[start:end];needle='(symbol.kind == 7 or symbol.kind == 31) and symbol.astNode >= 0 and symbol.nameToken >= 0';assert part.count(needle)==1;part=part.replace(needle,needle+' and (includeLocal or symbol.parent < 0)');s=s[:start]+part+s[end:]
insert='''firstFunctionNameDiagnostic prepared: ref semanticContext.SemanticSnapshot, declaredEffects: ref effects.DeclaredEffectIndex -> ExpressionOperandDiagnostic {
    prepared -> functionNameDiagnostic(declaredEffects, true)
}

public firstTopLevelFunctionNameDiagnostic prepared: ref semanticContext.SemanticSnapshot -> ExpressionOperandDiagnostic {
    prepared -> effects.indexDeclaredEffects => declaredEffects
    prepared -> functionNameDiagnostic(declaredEffects, false)
}

public functionDeclarationPrecedesSignature prepared: ref semanticContext.SemanticSnapshot, declaration: ExpressionOperandDiagnostic, signature: SignatureTypeDiagnostic -> Bool {
    declaration.code <= 0 -> if { false -> return }
    signature.sourceModule < 0 -> if { true -> return }
    declaration.sourceModule != signature.sourceModule -> if {
        declaration.sourceModule < signature.sourceModule -> return
    }
    prepared.package.ranges[signature.sourceModule] => range
    prepared.package.tokens[range.tokenStart + signature.nameToken] => token
    declaration.locationOffset <= token.span.start
}

'''
pos=s.index('\n# Repeat owns',s.index('functionNameDiagnostic prepared:'));s=s[:pos]+'\n'+insert+s[pos:];(out/'semantic-diagnostics.slg').write_text(s,encoding='utf-8')
(out/'emitter-diagnostics.slg').write_bytes((b/'duplicate16746-candidate/emitter-diagnostics.slg').read_bytes())
s=(root/'selfhost/llvm/text/context_prepare.slg').read_text(encoding='utf-8-sig');needle='struct SignatureRejection {';assert s.count(needle)==1;s=s.replace(needle,'''struct FunctionDeclarationRejection {
    prepared: semanticContext.SemanticSnapshot
    diagnostic: semanticDiagnostics.ExpressionOperandDiagnostic
}

'''+needle);needle='    Rejected(SignatureRejection)';assert s.count(needle)==1;s=s.replace(needle,needle+'\n    DeclarationRejected(FunctionDeclarationRejection)')
needle='    prepared -> semanticDiagnostics.firstPreparedSignatureTypeDiagnostic => diagnostic\n';assert s.count(needle)==2
cached='''    prepared -> semanticDiagnostics.firstTopLevelFunctionNameDiagnostic => declaration
    prepared -> semanticDiagnostics.functionDeclarationPrecedesSignature(declaration, diagnostic) -> if {
        CheckedPreparation.DeclarationRejected(FunctionDeclarationRejection { prepared: prepared, diagnostic: declaration }) => checked
        CachedCheckedPreparation { checked: checked, words: [UInt64; ~] } -> Result<CachedCheckedPreparation, Int>.Ok -> return
    }
'''
normal='''    prepared -> semanticDiagnostics.firstTopLevelFunctionNameDiagnostic => declaration
    prepared -> semanticDiagnostics.functionDeclarationPrecedesSignature(declaration, diagnostic) -> if {
        CheckedPreparation.DeclarationRejected(FunctionDeclarationRejection { prepared: prepared, diagnostic: declaration }) -> return
    }
'''
s=s.replace(needle,needle+cached,1);pos=s.index(needle,s.index('prepareCheckedSnapshot request:'));s=s[:pos]+s[pos:].replace(needle,needle+normal,1);(out/'context_prepare.slg').write_text(s,encoding='utf-8')
s=(root/'selfhost/llvm/text/entrypoints.slg').read_text(encoding='utf-8-sig')
# Keep every existing rejection consumer exhaustive, with its original return
# and profiling behavior. No default branch can hide a new rejection kind.
pattern=re.compile(r'(?m)^(\s*)Rejected\(rejection\) \{');matches=list(pattern.finditer(s));assert len(matches)>=5
for m in reversed(matches):
 opening=s.index('{',m.start());depth=1;i=opening+1
 while depth:
  if s[i]=='{':depth+=1
  elif s[i]=='}':depth-=1
  i+=1
 branch=s[m.start():i];new=branch.replace('Rejected(rejection)','DeclarationRejected(rejection)',1).replace('emitSignatureRejection','emitFunctionDeclarationRejection');s=s[:m.start()]+new+'\n'+s[m.start():]
renderer='''emitFunctionDeclarationRejection rejection: ref FunctionDeclarationRejection, paths: [Text; ~] -> Unit uses Console {
    rejection.diagnostic => diagnostic
    rejection.prepared.package.ranges[diagnostic.sourceModule] => range
    rejection.prepared.modules[diagnostic.sourceModule] => identity
    rejection.prepared.package.sources[diagnostic.sourceModule] -> slice(UIntSize(0), rejection.prepared.package.sources[diagnostic.sourceModule] -> len) => source
    "<main>" => moduleName!
    identity.pathLength > 0 -> if { source -> slice(identity.pathStart, identity.pathLength) => moduleName! }
    source -> syntaxDiagnostics.sourceLocation(diagnostic.locationOffset) => location
    "sollang: semantic error at $(location.line):$(location.column): [module '$(moduleName!)'] " -> print
    diagnostic.code == 49 -> if { "the sys namespace is reserved for the standard library" -> println
        return }
    rejection.prepared.package.nodes[range.astStart + diagnostic.astNode] => function
    [UInt8; ~] => bytes!
    source -> semanticDiagnostics.appendFunctionDeclarationName(rejection.prepared.package.tokens, range.tokenStart, range.tokenCount, identity.pathStart, identity.pathLength, function.payloadToken, bytes!)
    bytes! -> file.borrowBytes => nameView
    nameView -> slice(UIntSize(0), nameView -> len) => name
    diagnostic.code == 73 -> if { "function '$name' already exists" -> println } else {
        diagnostic.code == 46 -> if { "function name '$name' is reserved" -> println } else {
            "unsupported function declaration diagnostic $(diagnostic.code)" -> println
        }
    }
}

'''
pos=s.index('emitSignatureRejection rejection:');s=s[:pos]+renderer+s[pos:];(out/'entrypoints.slg').write_text(s,encoding='utf-8')
plan=json.loads((b/'duplicate16752-contract.json').read_text(encoding='utf-8-sig'));mapping={'selfhost/semantic/diagnostics.slg':'semantic-diagnostics.slg','selfhost/llvm/emitter/diagnostics.slg':'emitter-diagnostics.slg','selfhost/llvm/text/context_prepare.slg':'context_prepare.slg','selfhost/llvm/text/entrypoints.slg':'entrypoints.slg'}
canonical=(root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt').read_text(encoding='utf-8-sig').splitlines()[1:];providers=[str((out/mapping[p]).relative_to(root)).replace('\\','/') if p in mapping else p for p in canonical];assert len(providers)==150
plan['providers']=providers;plan['semanticProof']=str((b/'duplicate16757-semantic/result.json').relative_to(root)).replace('\\','/');(b/'duplicate16756-contract.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8');(out/'producer.sources.txt').write_text('\n'.join([plan['producer'],*providers])+'\n',encoding='utf-8')
runner=(b/'duplicate16754-source10.py').read_text(encoding='utf-8-sig').replace('duplicate16752-contract.json','duplicate16756-contract.json').replace("out=b/'duplicate16754-source10'","out=b/'duplicate16758-source10'").replace("'-lws2_32','-lbcrypt','-ldnsapi','-lole32','-loleaut32','-luser32','-luuid'","'-lws2_32','-lshell32','-lbcrypt','-lole32'");(b/'duplicate16758-source10.py').write_text(runner,encoding='utf-8');print('prepared typed early declaration rejection across',len(matches),'existing consumers; canonical source untouched')
