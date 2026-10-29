from pathlib import Path
import json,hashlib,sys
from datetime import datetime,timezone
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'v18270/supervision';build=b/'v18270/compiler-build01'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proof=b/'runtime18266-positive17.json';p=json.loads(proof.read_text());assert p['status']=='passed' and p['completed']==p['total']==17 and p['inputsStable'] and p['processesStopped']
pins=dict(p['inputHashes'])
for path in [proof,b/'native18270-run.ps1',Path(__file__).resolve(),b/'runtime18245-semantic/result.json',b/'runtime18194-managed3/result.json',b/'runtime18235-managed2/result.json',b/'runtime18247-stdlib/result.json',*[root/name for name in ['scripts/build-focused-selfhost-compiler.ps1','scripts/focused-selfhost-input-contract.ps1','scripts/verification_execution.py','scripts/verification_contract_lease.py']]]:pins[str(path)]=sha(path)
stable=lambda:all(Path(path).is_file() and sha(path)==expected for path,expected in pins.items())
assert stable()
assert not (b/'v17599/compiler-build01/compiler.exe').exists()
retained=[b/'v12432/compiler-build01',b/'v18092/compiler-build01'];initialize_output(root,out,reusable_directories=retained)
out.mkdir(parents=True,exist_ok=False)
plan={'schemaVersion':1,'status':'declared-build-plan','observedAtUtc':datetime.now(timezone.utc).isoformat(),'completed':0,'total':1,'compilerSources':167,'stdlibSources':144,'sourceInputEpoch':'edf2ea7f','focusedProof':'scripts/contracts/evidence/source13293/runtime18266-qualified/qualification.json','positiveProjection':'runtime18266-positive17.json','wholeBuildSupervisorBudgetSeconds':900,'generatedCaseLimitSeconds':180,'maximumBuildAttempts':1,'retryCount':0,'optimization':'O1','jobs':24,'cacheSeed':None,'retainedGeneralProductsBefore':2,'retainedGeneralProductsAfterBuild':3,'claimsGoalComplete':False}
(b/'native18270-plan.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8');pins[str(b/'native18270-plan.json')]=sha(b/'native18270-plan.json')
r={'schemaVersion':1,'status':'running','completed':0,'total':1,'inputHashes':pins,'cases':[],'scope':'One current-source general Native build after CSharp source decisions and source SLG focused18/18, with existing900-second supervisor and180-second generated-case limits. Frozen66/111/100 are not replayed.','claimsGoalComplete':False}
with VerificationContractLease([Path(path) for path in pins]):
    x=VerificationExecution(root,out,r,stable,sha);error=None
    try:
        run=x.run(['pwsh','-NoProfile','-File',str(b/'native18270-run.ps1')],out/'build',timeout=900)
        assert run.returncode==0,run.stderr[-5000:]
        result=json.loads((build/'result.json').read_text());assert result['status']=='passed' and result['inputsStable']
        assert sha(build/'compiler.exe')==result['compilerSha256']
        r.update(status='passed',completed=1,compilerSha256=result['compilerSha256'],pendingNativeConsumersProtected=True)
        r['cases'].append({'id':'current-general-native-build','status':'passed','passed':True,'buildExit':0})
    except BaseException as exc:error=exc
    finally:x.finalize(error,cleanup=False)
    print({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure','compilerSha256']},flush=True)
    if error:raise error
