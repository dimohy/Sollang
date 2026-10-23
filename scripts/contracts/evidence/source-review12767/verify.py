"""Replay the C710/C711 proof without rebuilding or allocating fixture storage."""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from large_layout_storage import observe, verify_helper_source, helper_declarations

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


phase, unit = sys.argv[1:]
assert phase in ["baseline", "candidate"]
assert unit in ["C2026-10-23-710", "C2026-10-23-711"]
manifest = read(E / "proof-inputs12792.json")
for relative, expected in manifest["archiveHashes"].items():
    assert sha(E / relative) == expected, relative
for relative, expected in manifest["languageInputHashes"].items():
    assert sha(ROOT / relative) == expected, relative

if unit.endswith("710"):
    before = record("scratch12763-native")
    terminal(before, "failed")
    assert before["compilerIdentitySha256"] == "D1F9ACFDD2DC3B87270E97A2CFDA68D587293A809F580655EE05AEA1A4873245"
    assert before["completed"] == 0 and before["total"] == 1
    assert before["cases"][0]["buildExit"] != 0
    assert "extractvalue operand must be aggregate type" in before["failure"]
    assert "extractvalue ptr %arg1, 0" in (E / "records/scratch12763-native/.l0.ll").read_text(encoding="utf-8-sig")
else:
    before = record("scratch12769-managed")
    terminal(before, "passed")  # Observation runner passed; actual program was rejected.
    assert before["compilerIdentitySha256"] == "95E8C2ABA0F8F3EB7AF9A3D959C21D9D8FCFA388C16C809ACFEA842D7D8FFD15"
    assert before["completed"] == before["total"] == 1
    assert before["cases"][0]["buildExit"] == 1
    assert before["cases"][0]["actualProgramAccepted"] is False
    assert "Arithmetic operation resulted in an overflow" in (E / "records/scratch12769-managed/layout-wide-numerator-build.stderr").read_text(encoding="utf-8-sig")
    old = read(E / "records/managed12710/inputs-after.json")
    assert next(row["sha256"] for row in old["files"] if row["path"].replace("\\", "/").endswith("/Semantics/BoundProgram.cs")) == sha(E / "BoundProgram.cs.before")

if phase == "candidate":
    q = read(E / "qualification12792.json")
    assert q["focused"] == [18, 18] and not q["claimsGoalComplete"]
    assert q["status"] == "focused-candidates-qualified-with-numeric-proof"
    assert verify_helper_source((ROOT / "selfhost/llvm/text/foundation.slg").read_text(encoding="utf-8-sig"), (ROOT / "scripts/probes/source-review-boundaries/layout-production-helper.slg").read_text(encoding="utf-8-sig"))
    for relative, expected in q["sourceHashes"].items():
        assert sha(ROOT / relative) == expected == sha(E / "qualified-source" / relative)
    contract = read(E / "records/scratch12784-cases.json")
    expected = {row["id"]: row for row in contract["cases"]}
    assert len(expected) == 6
    for name in ["scratch12784-managed", "scratch12789-runtime", "native12791"]:
        result = record(name)
        terminal(result, "passed")
        assert result["completed"] == result["total"] == 6
        assert {row["id"] for row in result["cases"]} == set(expected)
        for row in result["cases"]:
            oracle = expected[row["id"]]
            assert row["passed"] and row["runExit"] == oracle["exit"]
            assert row["stdout"].replace("\r\n", "\n") == oracle["stdout"]
            assert row["stderr"].replace("\r\n", "\n") == oracle["stderr"]
            if row["id"].startswith("layout-") and name != "scratch12789-runtime":
                assert row["largeStorageInstanceAbsent"]
                llvm = E / "records" / name / (row["id"] + ".exe.ll")
                assert sha(llvm) == row["emittedLlvmSha256"]
                observe(llvm.read_text(encoding="utf-8-sig"))
    source = record("scratch12788-source")
    terminal(source, "passed")
    assert source["completed"] == source["total"] == 6
    for row in source["cases"]:
        assert row["assemblyExit"] == 0
        llvm = E / "records/scratch12788-source" / row["id"] / "emitted.ll"
        assert sha(llvm) == row["emittedLlvmSha256"]
        assert "extractvalue ptr " not in llvm.read_text(encoding="utf-8-sig")
        if row["id"].startswith("layout-"):
            assert row["largeStorageInstanceAbsent"]
            observe(llvm.read_text(encoding="utf-8-sig"))
    native = record("native12791")
    build = record("v12790/compiler-build01")
    assert build["status"] == "passed" and build["inputsStable"]
    assert native["compilerSha256"] == build["compilerSha256"] == q["nativeSha256"]
    terminal(record("scratch12785-preflight"), "passed")
    stdlib = record("scratch12786-stdlib")
    terminal(stdlib, "passed")
    assert stdlib["fullStdlibSourceCount"] == 144 and stdlib["checkedSemanticDiagnosticCount"] == 0
    semantic = record("layout12771-semantic")
    terminal(semantic, "passed")
    assert semantic["codegenInvoked"] is False
    for row in semantic["cases"]:
        rejected = row["id"] == "fixed-length-domain"
        assert row["csharpExit"] == int(rejected)
        assert row["nativeStdout"] == f"checked diagnostics = {int(rejected)}\n"
    assert read(E / "large-storage-guard-evaluation.json")["status"] == "passed"
    api = record("layout12780-observations")
    terminal(api, "passed")
    after = next(row["result"] for row in api["cases"] if row["phase"] == "after")
    assert after["status"] == "passed" and after["completed"] == after["total"] == 6
    table = {}
    for row in after["rows"]:
        if row["capacity"] in table:
            assert table[row["capacity"]] == row["actual"]
        table[row["capacity"]] = row["actual"]
    expected_helper = "".join(str(cap) + ":" + ",".join(map(str, values)) + "\n" for cap, values in table.items())
    for name in ["scratch12784-managed", "scratch12789-runtime", "native12791"]:
        row = next(row for row in record(name)["cases"] if row["id"] == "layout-production-helper")
        assert row["stdout"].replace("\r\n", "\n") == expected_helper
    old_helper = record("layout12781-managed")
    terminal(old_helper, "failed")
    assert old_helper["cases"][0]["runExit"] == 0
    assert "268435456:16,32,64,72\n" in old_helper["cases"][0]["stdout"]
    assert helper_declarations((E / "foundation.before.slg").read_text(encoding="utf-8-sig")) == helper_declarations((E / "records/layout12781-before.slg").read_text(encoding="utf-8-sig"))
    assert read(E / "helper-source-alignment-controls.json")["staleCopiedImplementationRejected"]


print(json.dumps({"phase": phase, "unit": unit, "status": "passed",
                  "baselineActualProgramRejected": True,
                  "candidateFocused": [18, 18] if phase == "candidate" else None,
                  "claimsGoalComplete": False}, sort_keys=True))
