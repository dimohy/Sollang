"""Replay the preserved C706/C707 source and runtime evidence without builds."""
from pathlib import Path
import hashlib
import json
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def relative_pin(record, relative):
    matches = [value for path, value in record["inputHashes"].items()
               if path.replace("\\", "/").endswith("/" + relative)]
    assert len(matches) == 1
    return matches[0]


def normalized_functions(row):
    path = HERE / row["functions"]
    helpers = HERE / row["helpers"]
    assert sha(path) == row["sha256"]
    assert sha(helpers) == row["helpersSha256"]
    text = path.read_text(encoding="utf-8-sig")
    definitions = {}
    for match in re.finditer(r"^define [^\n]*\{\n.*?^}", helpers.read_text(encoding="utf-8-sig"), re.M | re.S):
        key = re.search(r"@sollang_drop_t\d+", match.group().splitlines()[0]).group()
        assert key not in definitions
        definitions[key] = match.group()
    hashes = {}
    active = set()

    def digest(key):
        if key in hashes:
            return hashes[key]
        assert key in definitions and key not in active
        active.add(key)
        body = definitions[key].replace(key, "@canonical_drop", 1)
        body = re.sub(r"@sollang_drop_t\d+", lambda match: "@drop_body_" + digest(match.group()), body)
        active.remove(key)
        hashes[key] = hashlib.sha256(body.encode()).hexdigest().upper()
        return hashes[key]

    result = re.sub(r"@sollang_drop_t\d+", lambda match: "@drop_body_" + digest(match.group()), text)
    assert hashes == row["helperBodyHashes"]
    ignored = []
    block = None
    for line in text.splitlines():
        if re.match(r"^[\w.$-]+:", line):
            block = line.split(":", 1)[0]
        if line in row["unusedEntryReservations"]:
            match = re.fullmatch(r"  (%calltext\d+_arg\d+_root\d+_buffer) = alloca \[21 x i8\], align 1", line)
            assert match and block == "entry"
            assert len(re.findall(re.escape(match.group(1)) + r"\b", text)) == 1
            result = result.replace(line + "\n", "")
            ignored.append(line)
    assert ignored == row["unusedEntryReservations"]
    if ignored:
        assert row["backend"] == "source" and row["id"] == "1486-interpolation-capacity-receivers"
        assert len(ignored) == 43
    return result


def verify(phase, defect):
    assert defect in ["C2026-10-23-706", "C2026-10-23-707"]
    before = read(HERE / "before-CSharp-result.json")
    after = read(HERE / "CSharp-result.json")
    assert before["status"] == after["status"] == "passed"
    assert before["completed"] == before["total"] == 2
    assert after["completed"] == after["total"] == 6
    assert before["inputsStable"] and before["processesStopped"]
    assert after["inputsStable"] and after["processesStopped"]
    for case in before["cases"]:
        assert case["buildExit"] == 1 and case["knownPositiveRejectedBeforeFix"]
        assert "unknown value-flow target 'len'" in case["buildStderr"]
    paths = read(HERE / "source-contract.json")["cases"]
    for case in paths[:2]:
        relative = case["source"]
        assert relative_pin(before, relative) == relative_pin(after, relative) == sha(ROOT / relative)
    checked_stdlib = 0
    for key, value in before["inputHashes"].items():
        key = key.replace("\\", "/")
        if "/stdlib/" in key:
            relative = "stdlib/" + key.split("/stdlib/", 1)[1]
            assert relative_pin(after, relative) == value == sha(ROOT / relative)
            checked_stdlib += 1
    assert checked_stdlib == 144
    pair = read(HERE.parent / "C2026-10-23-706/managed-source-pair12717.json")
    assert len(pair["changedCommonInputs"]) == 2 and pair["compilerSourceChangesOnlyExpectedTwoFiles"]
    old_snapshot = HERE / "records/managed12581/inputs-after.json"
    new_snapshot = HERE / "records/managed12710/inputs-before.json"
    assert sha(old_snapshot) == pair["oldSnapshotSha256"]
    assert sha(new_snapshot) == pair["newSnapshotSha256"]
    old_inputs = {row["path"]: row["sha256"] for row in read(old_snapshot)["files"]}
    new_inputs = {row["path"]: row["sha256"] for row in read(new_snapshot)["files"]}
    changed = {path for path in old_inputs.keys() & new_inputs.keys() if old_inputs[path] != new_inputs[path]}
    assert changed == set(pair["changedCommonInputs"])
    assert len(old_inputs.keys() - new_inputs.keys()) == len(new_inputs.keys() - old_inputs.keys()) == 1
    for relative, saved in [("src/Sollang.Compiler/Semantics/SemanticCompiler.cs", "SemanticCompiler.cs.before"),
                            ("src/Sollang.Compiler/CodeGen/LlvmEmitter.Flow.cs", "LlvmEmitter.Flow.cs.before")]:
        match = [value for path, value in old_inputs.items() if path.replace("\\", "/").endswith("/" + relative)]
        assert len(match) == 1 and match[0] == sha(HERE.parent / "C2026-10-23-706" / saved)
    failed = read(HERE / "scratch12711-native-result.json")
    assert failed["status"] == "failed" and failed["inputsStable"] and failed["processesStopped"]
    assert "multiple definition" in failed["failure"]
    if phase == "baseline":
        print(f"{defect}: genuine pre-fix CSharp rejects two exact current positive inputs; native duplicates a capacity SSA and reads an unrelated slot. Baseline programs are not counted as passing.")
        return
    assert phase == "candidate"
    q = read(HERE / "qualification12724.json")
    assert q["CSharp"] == q["SLGSource"] == q["SLGNormalRuntime"] == q["freshNative"] == [6, 6]
    assert q["combined"] == [18, 18]
    assert q["compilerBuildCount"] == q["managedCompilerBuildCount"] == q["sourceProducerBuildCount"] == 1
    oracles = {row["id"]: row["stdout"] for row in paths}
    for row in q["records"]:
        path = HERE / row["path"]
        assert sha(path) == row["sha256"]
        record = read(path)
        assert record["status"] == "passed" and record["inputsStable"]
        if row["id"] in ["CSharp", "source", "runtime", "native"]:
            assert record["completed"] == record["total"] == 6 and record["processesStopped"]
            assert {case["id"] for case in record["cases"]} == set(oracles)
        if row["id"] in ["CSharp", "runtime", "native"]:
            for case in record["cases"]:
                assert case["passed"] and case["runExit"] == 0 and not case["stderr"]
                assert case["stdout"].replace("\r\n", "\n") == oracles[case["id"]]
        if row["id"] == "source":
            for case in record["cases"]:
                emitted = HERE / "records/scratch12720-source" / case["id"] / "emit.stdout"
                assert sha(emitted) == case["emittedLlvmSha256"]
                assert not re.search(r"^\s*; sollang (?:compiler|semantic) error|^warning S\d",
                                     emitted.read_text(encoding="utf-8-sig"), re.M)
        if row["id"] == "negative-CSharp":
            assert record["completed"] == record["total"] == 1
            assert record["cases"][0]["buildExit"] == 1 and record["cases"][0]["admissionRejected"]
        if row["id"] == "dead-scratch-observation":
            assert record["cases"][0]["removedReservationCount"] == 43
    comparison = HERE / q["functionComparison"]
    assert sha(comparison) == q["functionComparisonSha256"]
    data = read(comparison)
    originals = {row["id"]: normalized_functions(row) for row in data["rows"] if row["backend"] == "baseline"}
    invalid = originals["capacity-reference-call-shadow"]
    bad = re.findall(r"^  %v\d+_capacity_source = load [^\n]*ptr %slot\d+, align 8\n", invalid, re.M)
    assert len(bad) == 2
    for line in bad:
        invalid = invalid.replace(line, "")
    originals["capacity-reference-call-shadow"] = invalid
    covered = {"source": set(), "native": set()}
    for row in data["rows"]:
        if row["backend"] != "baseline":
            assert normalized_functions(row) == originals[row["id"]]
            covered[row["backend"]].add(row["id"])
    assert covered["source"] == covered["native"] == set(oracles)
    for path, value in q["canonicalSourceHashes"].items():
        assert sha(ROOT / path) == value
    print(f"{defect}: CSharp6/source6/native6 pass18/18, source runtime6 and negative ownership guard pass. Drop-helper graphs verified; two wrong-slot loads removed.43 unused checked-source entry buffers remain an explicit representation limitation. Final gates remain.")


if __name__ == "__main__":
    verify(*sys.argv[1:])
