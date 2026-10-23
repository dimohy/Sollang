"""Qualify the current slice repair without promoting the original final gates."""
from pathlib import Path
import hashlib
import json
import sys

E = Path(__file__).resolve().parent
R = E.parents[3]
P = E.parent / "slice13055"
sys.path.insert(0, str(R / "scripts"))
from verification_source_proof import current_build_inputs


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


for archive in (P, E):
    for item in load(archive / "manifest.json")["files"]:
        assert sha(archive / item["archive"]) == item["sha256"], item["archive"]

contract = load(E / "records/slice13057-managed-contract.json")
assert len(contract["cases"]) == 17
records = [
    load(P / "records/slice13057-managed/result.json"),
    load(P / "records/slice13079-source-requalified/result.json"),
    load(P / "records/slice13080-runtime/result.json"),
    load(E / "records/slice13083-native/result.json"),
]
for result in records:
    assert result["status"] == "passed"
    assert result["completed"] == result["total"] == 17
    assert result["inputsStable"] and result["processesStopped"]
    assert {c["id"] for c in result["cases"]} == {c["id"] for c in contract["cases"]}
    for case in contract["cases"]:
        source = R / case["source"]
        assert sha(source) == result["inputHashes"][str(source)]
        row = next(c for c in result["cases"] if c["id"] == case["id"])
        assert row["status"] == "passed"
        if "stdout" in row:
            assert row["stdout"].replace("\r\n", "\n") == case["stdout"] + "\n"
            assert row["stderr"] == case["stderr"] == ""

product = load(E / "records/v13072/compiler-build01/result.json")
current_build_inputs(R, product)
native = R / "artifacts/scratch/resume-20261006-owner-continuation22/v13072/compiler-build01/compiler.exe"
assert sha(native) == product["compilerSha256"] == records[-1]["inputHashes"][str(native)]
managed = R / "artifacts/scratch/resume-20261006-owner-continuation22/managed13056/compiler/Sollang.Compiler.dll"
assert sha(managed) == "8310858A4407EF263ACE7292A2CF1EA70FB018DB6520E450CC100F2BE777394D"
for directory in ("slice13066-original487-managed", "slice13084-original487-native"):
    proof = load(E / "records" / directory / "controller.execution.json")
    assert proof["status"] == "passed" and proof["exit"] == 0 and proof["processesStopped"]
    log = (E / "records" / directory / "controller.execution.json.stdout.log").read_text(encoding="utf-8-sig")
    assert "487-selfhost-borrowed-container-return-analysis" in log and "PASS" in log
admission = records[1]["stdlibSourcePreflight"]
assert admission["status"] == "passed-current-source"
assert Path(admission["proof"]).parts[-2:] == ("slice13077-stdlib", "result.json")
assert admission["validation"]["status"] == "passed"
assert records[1]["producerBuildCount"] == 0 and records[1]["reusedProducer"]
print("PASS: unchanged17 across CSharp, admitted SLG source and current native; original487 pair passed. Candidate only; original final gates remain pending.")
