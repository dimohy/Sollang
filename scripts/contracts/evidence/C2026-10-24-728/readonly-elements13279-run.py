from pathlib import Path
import hashlib, importlib.util, json, shutil, sys

root = Path.cwd()
base = root / 'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()

prior_path = base/'readonly-elements13276-source/result.json'
prior = json.loads(prior_path.read_text(encoding='utf-8-sig'))
assert prior['status']=='failed' and prior['inputsStable'] and prior['processesStopped']
assert prior['reusableCheckedProducer']['status']=='built'
assert all(Path(p).is_file() and sha(p)==h for p,h in prior['inputHashes'].items())
producer = Path(prior['reusableCheckedProducer']['executable'])
assert sha(producer)==prior['reusableCheckedProducer']['executableSha256']
contract = json.loads((base/'readonly-elements13276-contract.json').read_text(encoding='utf-8-sig'))
original = json.loads((base/'readonly-elements13265-contract.json').read_text(encoding='utf-8-sig'))
for case, authority in zip(contract['cases'], original['cases']):
    assert case['programSource']==authority['source']
    case['runStderr'] = authority['stderr'] if authority['exit']==0 else ''
contract['scope'] += ' Reuse the verified producer and first emission; preserve original S003 warnings; zero new producer builds.'
contract_path = base/'readonly-elements13279-contract.json'
assert not contract_path.exists()
contract_path.write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
out = base/'readonly-elements13279-source'
out.mkdir(exist_ok=False)
old_first = base/'readonly-elements13276-source'/contract['cases'][0]['id']
assert sha(old_first/'emitted.ll')==prior['cases'][0]['emittedLlvmSha256']
pins = dict(prior['inputHashes'])
for p in [prior_path, contract_path, producer, Path(__file__), old_first/'emitted.ll',old_first/'run.stderr',old_first/'run.stdout']:
    pins[str(p)] = sha(p)
result = dict(schemaVersion=1,status='running',scope=contract['scope'],completed=0,total=4,
              inputHashes=pins,cases=[],producerReuse=dict(sourceResult=str(prior_path),sha256=sha(producer),newBuilds=0),
              claimsNativeProductAcceptance=False,claimsGoalComplete=False,
              budget=dict(producerBuilds=0,caseSeconds=180,retries=0))
execution = VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
spec = importlib.util.spec_from_file_location('entry_validator',root/'scripts/verify-checked-package-emitter.py')
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
error = None
try:
    for index,case in enumerate(contract['cases']):
        folder = out/case['id'];folder.mkdir()
        row = dict(id=case['id'],status='running',programSource=case['programSource'],observedSourceOrder=case['observedSourceOrder'])
        result['cases'].append(row);execution.save()
        if index==0:
            stdout=(old_first/'run.stdout').read_text(encoding='utf-8-sig')
            stderr=(old_first/'run.stderr').read_text(encoding='utf-8-sig')
            shutil.copyfile(old_first/'run.stdout',folder/'run.stdout')
            shutil.copyfile(old_first/'run.stderr',folder/'run.stderr')
            assert prior['cases'][0]['runExit']==0
            row.update(emissionReused=True,runExit=0)
        else:
            process=execution.run([str(producer),*case['runArguments']],folder/'run',timeout=180)
            row['runExit']=process.returncode
            assert process.returncode==0,process.stderr
            stdout,stderr=process.stdout,process.stderr
        assert stderr.replace('\r\n','\n').strip()==case['runStderr'],repr(stderr)
        row['runStderr']=stderr
        if case['emittedLlvm']:
            llvm=folder/'emitted.ll';llvm.write_bytes((folder/'run.stdout').read_bytes())
            row['emittedLlvmSha256']=sha(llvm)
            row['entryPoint']=validator.validate_emitted_entrypoint(stdout,'windows')
            process=execution.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble',timeout=180)
            assert process.returncode==0 and not process.stderr,process.stderr
            program=folder/'emitted.exe'
            process=execution.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O1','-o',str(program),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'native-link',timeout=180)
            assert process.returncode==0 and not process.stderr,process.stderr
            process=execution.run([str(program)],folder/'native-run',timeout=180)
            row.update(nativeRunExit=process.returncode,nativeRunStdout=process.stdout)
            assert process.returncode==0 and not process.stderr and process.stdout.replace('\r\n','\n').strip()==case['stdout'],repr(process.stdout)
        else:
            row['runStdout']=stdout
            assert stdout.replace('\r\n','\n').strip()==case['stdout'],repr(stdout)
        row.update(status='passed',passed=True);result['completed']+=1;execution.save()
        print(case['id'],'PASS',flush=True)
    result['status']='passed'
except BaseException as caught:
    error=caught
finally:
    execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ('status','completed','total','failure','inputsStable','processesStopped')}),flush=True)
sys.exit(0 if result['status']=='passed' else 1)
