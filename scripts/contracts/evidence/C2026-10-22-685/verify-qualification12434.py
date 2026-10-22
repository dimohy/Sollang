"""Validate retained actual executions; this command does not rerun a compiler."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[4]
E684 = ROOT / "scripts/contracts/evidence/C2026-10-22-684"
E685 = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def require_pass(record, count):
    assert record["status"] == "passed"
    assert record["completed"] == record["total"] == count
    assert record["processesStopped"] is True
    if "inputsStable" in record:
        assert record["inputsStable"] is True


mode = sys.argv[1]
assert mode in ("C684", "C685", "C684-measurement")
native = read(E685 / "native12433-qualification/result.json")
require_pass(native, 17)
assert len(native["cases"]) == 17
assert len({case["id"] for case in native["cases"]}) == 17
assert all(case["passed"] and case["runExit"] == case["expectedRuntimeExit"]
           for case in native["cases"])
assert native["axisResults"]["C684"]["completed"] == 11
assert native["axisResults"]["C685"]["completed"] == 8

if mode.startswith("C684"):
    baseline = read(E684 / "result.json")
    contract = read(E684 / "baseline-contract12369.json")
    managed = read(E684 / "stdout12382-managed/result.json")
    require_pass(managed, 5)
    failure = next(case for case in managed["cases"] if case["id"] == "linux-failure")
    normal = next(case for case in managed["cases"] if case["id"] == "linux-normal")
    assert baseline["status"] == "failure-reproduced"
    assert baseline["normalExit"] == 0 and baseline["normalStdout"] == normal["stdout"]
    assert baseline["fullExit"] == 0 and baseline["fullStdout"] == failure["stdout"] == ""
    assert failure["runExit"] == failure["expectedRuntimeExit"] == 1
    assert normal["runExit"] == 0
    assert hashlib.sha256((E684 / "buffered.slg").read_bytes()).hexdigest().upper() == contract["sourceSha256"]
    candidate_build = read(E684 / "stdout12382-managed/linux/probe.compiler-build.json")
    assert candidate_build["status"] == "passed" and candidate_build["inputsStable"]
    assert candidate_build["inputHashes"][str(ROOT / contract["source"])] == contract["sourceSha256"]
    metric = {"metric": "misses", "missKind": "incorrect-success-on-output-failure",
              "before": int(baseline["fullExit"] == 0),
              "after": int(failure["runExit"] == 0),
              "baselineProgramExit": 0, "candidateProgramExit": 1,
              "normalControlExitBefore": 0, "normalControlExitAfter": 0,
              "sourceSha256": contract["sourceSha256"],
              "scope": "Same frozen program, CSharp Linux backend, actual /dev/full redirection. Preserve the genuine baseline exit0; no fabricated nonzero baseline."}
    if mode == "C684-measurement":
        print(json.dumps(metric))
    else:
        require_pass(read(E684 / "parallel12406-managed/result.json"), 2)
        require_pass(read(E684 / "direct-output12426-managed/result.json"), 2)
        print(json.dumps({"CSharpChecks": 14, "nativeChecks": 11,
                          "retainedSLGSourceChecks": 16, "claimsGoalComplete": False,
                          "outputFailureMetric": metric}))
else:
    original = read(E685 / "csharp-first12406.json")
    related = read(E685 / "parallel12413-managed/result.json")
    admission = read(E685 / "parallel12429-managed/result.json")
    source = read(E685 / "parallel12422-runtime/result.json")
    for record, count in ((original, 2), (related, 4), (admission, 2), (source, 6)):
        require_pass(record, count)
    baseline = read(E685 / "baseline12410.json")
    assert all(row["actualLinkExit"] == 1 for row in baseline["nativeEmissions"])
    assert hashlib.sha256((ROOT / baseline["source"]).read_bytes()).hexdigest().upper() == baseline["sourceSha256"]
    assert all(row["usesComputePool"] == row["expectedComputePool"]
               for row in native["bodyDecisions"])
    print(json.dumps({"CSharpChecks": 8, "SLGSourceChecks": 6,
                      "nativeChecks": 8, "distinctNativeBatchExecutions": 17,
                      "claimsGoalComplete": False}))
