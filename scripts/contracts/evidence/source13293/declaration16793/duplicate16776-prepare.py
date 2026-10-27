from pathlib import Path
import json,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';p=b/'duplicate16776-input';p.mkdir(exist_ok=False)
source=(b/'duplicate16752-input/probe.slg').read_text(encoding='utf-8-sig')
source=source.replace('import sys.process as process','import sys.process as process\nimport sys.file as file\nimport sollang.compiler.syntax.source_decoding as sourceDecoding\nimport sollang.compiler.semantic.semantic_cache as semanticCache\nimport sollang.compiler.semantic.semantic_generations as semanticGenerations')
assert source.count('(arguments -> len) != 2')==1
source=source.replace('(arguments -> len) != 2','(arguments -> len) != 5')
old='    paths! -> compiler.emitCheckedFilesWithStandardLibrarySources(144) => diagnostics'
new='''    [file.SourceText; ~] => owners!
    paths! -> each current { current -> file.mapText => owner
        owners! -> push(owner) }
    [Text; ~] => sources!
    0 => index!
    index! < (owners! -> len) -> while {
        owners![index!] -> sourceDecoding.utf8Text => source
        sources! -> push(source)
        index! + 1 => index!
    }
    arguments[0] -> semanticCache.compilerIdentity -> when {
        Ok(value) { value }
        Err(code) { process.exit(code)
            UInt64(0) }
    } => compilerIdentity
    semanticGenerations.CompilationIdentity { compiler: compilerIdentity, target: 0, configuration: 16776 } => identity
    semanticCache.Request { enabled: true, destination: arguments[2], staged: arguments[3], identity: identity } => cache
    arguments[4] == "warm" -> if {
        arguments[2] -> semanticCache.load => loaded
        loaded.status != 0 -> if { process.exit(4) }
    }
    sources! -> compiler.emitCheckedWithPathsCached(paths!, 144, cache) => diagnostics'''
assert source.count(old)==1;source=source.replace(old,new);(p/'probe.slg').write_text(source,encoding='utf-8')
plan=json.loads((b/'duplicate16760-contract.json').read_text(encoding='utf-8-sig'));plan['producer']=str((p/'probe.slg').relative_to(root)).replace('\\','/');plan['scope']='Private declaration candidate enabled-cache10 and positive warm restoration controls, unchanged original CSharp references, fixed-source producer only; no general compiler product or final credit';(b/'duplicate16776-contract.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8')
providers=[plan['producer'],*plan['providers']];(p/'producer.sources.txt').write_text('\n'.join(providers)+'\n',encoding='utf-8')
script=(b/'duplicate16762-source10.py').read_text(encoding='utf-8-sig').replace('import json,hashlib,sys,time','import json,hashlib,sys,time,shutil').replace("b/'duplicate16760-contract.json'","b/'duplicate16776-contract.json'").replace("b/'duplicate16762-source10'","b/'duplicate16778-cache10'")
script=script.replace("case['id']],folder/'emission'","case['id'],str(folder/'cache.semantic'),str(folder/'cache.staged'),'cold'],folder/'emission'")
anchor="   row.update(status='passed' if ok else 'failed',passed=ok);r['cases'].append(row)"
extra="""   if ok and reference['buildExit']==0:
    destination=folder/'cache.semantic';staged=folder/'cache.staged';assert staged.is_file(),'POSITIVE_CACHE_NOT_STAGED'
    shutil.copyfile(staged,destination);cacheHash=sha(destination)
    warm=run([str(producer),case['id'],str(destination),str(folder/'warm.staged'),'warm'],folder/'warm',deadline)
    warmtext=(folder/'warm.stdout').read_text(encoding='utf-8-sig').replace('\\r\\n','\\n').strip();warmerr=(folder/'warm.stderr').read_text(encoding='utf-8-sig').strip()
    ok=warm.returncode==0 and not warmerr and warmtext==actual and sha(destination)==cacheHash and (folder/'warm.staged').is_file()
    row.update(warmExit=warm.returncode,warmStderr=warmerr,warmLlvmExact=warmtext==actual,cacheSha256=cacheHash,loadedFrameValidated=True)
   elif ok:
    ok=not (folder/'cache.staged').exists();row['rejectedBeforeCacheStage']=ok
"""
assert script.count(anchor)==1;script=script.replace(anchor,extra+anchor);(b/'duplicate16778-cache10.py').write_text(script,encoding='utf-8')
comparison=dict(schemaVersion=1,decision='reuse-existing',managed='src/Sollang.Compiler/Semantics/SemanticCompiler.cs:525',slg='duplicate16760-candidate/semantic-diagnostics.slg:5253',decisions=['DeclareFunctions checks exact canonical function name before BindFunctionDeclaration; arity cannot distinguish duplicate declarations','Earlier declaration signature failure wins; duplicate at same/later declaration wins before its signature/body','SLG compares full namespace/dotted spelling, excludes local owners, preserves ordinal name comparison','Both cached and ordinary preparation select DeclarationRejected before signature rejection using declaration order','All seven checked entrypoint consumers emit the same declaration rejection; no LLVM or cache stage after rejection'],evidence='scripts/contracts/evidence/source13293/duplicate16770/qualification.json',limits='Enabled cache and general Native behavior remain pending; 10/10 fixed-source ordinary execution is not final qualification',claimsGoalComplete=False)
(p/'source-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
print('Prepared fixed-source cache controls; canonical sources unchanged')
