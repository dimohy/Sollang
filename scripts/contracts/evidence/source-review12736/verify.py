"""Replay the bounded C708 proof; compiler execution records retain their scope."""
from pathlib import Path
import hashlib
import json
import sys

E = Path(__file__).resolve().parent
ROOT = E.parents[3]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def record(name):
    return read(E / "records" / name / "result.json")


def terminal(result, status):
    assert result["status"] == status
    assert result["inputsStable"] and result["processesStopped"]


phase = sys.argv[1]
assert phase in ["baseline", "candidate"]
manifest = read(E / "proof-inputs12744.json")
for relative, expected in manifest["archiveHashes"].items():
    assert sha(E / relative) == expected, relative
for relative, expected in manifest["languageInputHashes"].items():
    assert sha(ROOT / relative) == expected, relative

before = record("scratch12734-native")
terminal(before, "failed")
assert before["compilerIdentitySha256"] == "176259CF34B20130F13FF2B7C5FB1D77AD044F6BE9693D9B54AAC519C8B3909B"
assert before["completed"] == 0 and before["total"] == 1
assert before["cases"][0]["buildExit"] != 0
assert "extractvalue operand must be aggregate type" in before["failure"]
assert "extractvalue ptr %arg, 0" in (E / "records/scratch12734-native/.l0.ll").read_text(encoding="utf-8-sig")
source = "selfhost/llvm/text/platform_io.slg"
before_pins = {p.replace("\\", "/"): h for p, h in before["inputHashes"].items()}
assert next(h for p, h in before_pins.items() if p.endswith("/" + source)) == sha(E / "platform_io.before.slg")

if phase == "candidate":
    q = read(E / "qualification12744.json")
    assert q["focused"] == [9, 9] and not q["claimsGoalComplete"]
    assert sha(ROOT / source) == q["sourceSha256"] == sha(E / "qualified-source" / source)
    contract = read(E / "records/scratch12735-cases.json")
    expected = {row["id"]: row for row in contract["cases"]}
    assert len(expected) == 3
    for name in ["scratch12735-managed", "scratch12740-runtime", "native12743"]:
        result = record(name)
        terminal(result, "passed")
        assert result["completed"] == result["total"] == 3
        assert {row["id"] for row in result["cases"]} == set(expected)
        for row in result["cases"]:
            oracle = expected[row["id"]]
            assert row["passed"] and row["runExit"] == oracle["exit"]
            assert row["stdout"].replace("\r\n", "\n") == oracle["stdout"]
            assert row["stderr"].replace("\r\n", "\n") == oracle["stderr"]
    result = record("scratch12741-source")
    terminal(result, "passed")
    assert result["completed"] == result["total"] == 3
    for row in result["cases"]:
        assert row["assemblyExit"] == 0
        llvm = E / "records/scratch12741-source" / row["id"] / "emitted.ll"
        assert sha(llvm) == row["emittedLlvmSha256"]
        assert "extractvalue ptr " not in llvm.read_text(encoding="utf-8-sig")
    native = record("native12743")
    build = record("v12742/compiler-build01")
    assert build["status"] == "passed" and build["inputsStable"]
    assert native["compilerSha256"] == build["compilerSha256"] == q["nativeSha256"]
    terminal(record("scratch12737-preflight"), "passed")
    stdlib = record("scratch12738-stdlib")
    terminal(stdlib, "passed")
    assert stdlib["fullStdlibSourceCount"] == 144 and stdlib["checkedSemanticDiagnosticCount"] == 0

print(json.dumps({"phase": phase, "status": "passed", "baselineActualProgramCompileFailed": True,
                  "candidateFocused": [9, 9] if phase == "candidate" else None,
                  "claimsGoalComplete": False}, sort_keys=True))
