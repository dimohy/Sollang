"""Behavioral checks for explicit C527 historical replay authority."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()

def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))

def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    assert out.is_relative_to((ROOT / "artifacts/scratch").resolve())
    authority_path = ROOT / "scripts/contracts/c527-historical-baseline-authority.json"
    authority = read(authority_path)
    qualification = read(ROOT / authority["qualification"])
    original_path = ROOT / "artifacts/scratch/c527-large-integer-float-slice-20260927-01.json"
    entry = ROOT / "scripts/verify-c527-historical-baseline.ps1"
    module = ROOT / "scripts/verification-c527-historical-baseline.ps1"
    inputs = [Path(__file__), authority_path, ROOT / authority["qualification"], original_path, entry, module,
              ROOT / "scripts/verification-artifact-identity.ps1",
              *[ROOT / p for p in qualification["files"]],
              *[ROOT / p for p in qualification["currentSourceHashes"]],
              *[ROOT / c["source"] for c in qualification["originalControls"]]]
    ids = authority["evaluationCases"]
    assert ids == ["observed-file-present", "observed-file-missing-no-fallback", "valid-git-replay",
                   "missing-producer", "changed-baseline-with-updated-manifest",
                   "unrun-native-controls", "changed-original-oracle"]
    with VerificationContractLease(inputs):
        out.mkdir(exist_ok=False)
        pins = {str(p): sha(p) for p in inputs}
        result = dict(schemaVersion=1, status="running", scope="C527 baseline authority behavioral controls",
                      inputHashes=pins, completed=0, total=7, cases=[], claimsWholeParityComplete=False)
        execution = VerificationExecution(ROOT, out, result, lambda: all(sha(p) == h for p, h in pins.items()), sha)
        error = None
        try:
            for name in ids:
                directory = out / name
                selected_authority = authority_path
                selected_original = original_path
                failure_id = None
                if name.startswith("observed-file-"):
                    directory.mkdir()
                    selected_authority = directory / "authority.json"
                    save(selected_authority, dict(mode="observed-file"))
                    if name == "observed-file-present":
                        witness = directory / "observed-baseline.ll"
                        shutil.copyfile(ROOT / qualification["baselineLlvm"], witness)
                        data = read(original_path)
                        data["baselineLlvm"] = witness.relative_to(ROOT).as_posix()
                        selected_original = directory / "original.json"
                        save(selected_original, data)
                    else:
                        failure_id = "C527_ORIGINAL_BASELINE_MISSING"
                elif name == "valid-git-replay":
                    directory.mkdir()
                else:
                    # These are isolated negative test copies, never accepted historical baselines.
                    shutil.copytree(ROOT / authority["archiveRoot"], directory)
                    relative = directory.relative_to(ROOT).as_posix()
                    data = json.loads(json.dumps(qualification).replace(authority["archiveRoot"], relative))
                    def update_record(path, value):
                        save(ROOT / path, value)
                        data["files"][path] = sha(ROOT / path)
                    if name == "missing-producer":
                        path = data["producer"]["Sollang.Compiler.dll"]["path"]
                        target = (ROOT / path).resolve()
                        assert target.is_relative_to(directory)
                        target.unlink()
                        del data["files"][path]
                        failure_id = "C527_REPLAY_PRODUCER_INVALID"
                    elif name == "changed-baseline-with-updated-manifest":
                        path = ROOT / data["baselineLlvm"]
                        path.write_text("; negative test: fixed LLVM cannot become historical evidence\n"
                                        "define i32 @main() { ret i32 0 }\n", encoding="utf-8")
                        changed = sha(path)
                        data["baselineLlvmSha256"] = changed
                        data["files"][data["baselineLlvm"]] = changed
                        runtime = read(ROOT / data["runtimeRecord"])
                        runtime["actualLlvmSha256"] = changed
                        update_record(data["runtimeRecord"], runtime)
                        failure_id = "C527_REPLAY_BASELINE_PIN_INVALID"
                    elif name == "unrun-native-controls":
                        proof = read(ROOT / data["nativeControlRecord"])
                        proof["completed"] = 4
                        update_record(data["nativeControlRecord"], proof)
                        failure_id = "C527_REPLAY_CURRENT_CONTROLS_INCOMPLETE"
                    elif name == "changed-original-oracle":
                        oracle = data["originalControls"][0]
                        path = ROOT / oracle["oracle"]
                        path.write_text("changed-original-answer\n", encoding="utf-8")
                        oracle["oracleSha256"] = sha(path)
                        data["files"][oracle["oracle"]] = sha(path)
                        failure_id = "C527_REPLAY_ORIGINAL_ORACLE_CHANGED"
                    selected_qualification = directory / "qualification.json"
                    save(selected_qualification, data)
                    selected_authority = directory / "authority.json"
                    reference = dict(authority, archiveRoot=relative,
                                     qualification=selected_qualification.relative_to(ROOT).as_posix(),
                                     qualificationSha256=sha(selected_qualification))
                    save(selected_authority, reference)
                command = [shutil.which("pwsh"), "-NoProfile", "-File", str(entry),
                           "-RepositoryRoot", str(ROOT), "-AuthorityPath", str(selected_authority),
                           "-OriginalEvidencePath", str(selected_original)]
                observed = execution.run(command, directory / "verification", timeout=180)
                passed = (observed.returncode == 1 and failure_id in observed.stderr) if failure_id else (
                    observed.returncode == 0 and read(directory / "verification.stdout")["status"] == "passed")
                result["cases"].append(dict(id=name, expectedFailureId=failure_id,
                                            exit=observed.returncode, passed=passed))
                if not passed:
                    raise ValueError("C527_BEHAVIORAL_CONTROL_FAILED:" + name)
                result["completed"] += 1
                execution.save()
                print("PASSED " + name, flush=True)
            result["status"] = "passed"
        except BaseException as failure:
            error = failure
        finally:
            execution.finalize(error, cleanup=False)
    print(json.dumps({k: result.get(k) for k in ["status", "completed", "total", "failure"]}))
    if error:
        raise error

if __name__ == "__main__":
    main()
