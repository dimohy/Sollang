"""Verify C#-first source closure and direct dictionary pre-IR facts."""

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c587-dictionary-index-preir-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(str(RECEIPT))
comparison = read(unit["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert sha(comparison["managedSource"]) == comparison["managedSourceSha256"]
assert comparison["slgSources"]["selfhost/semantic/expression_type_ids.slg"] != unit["currentSourceSha256"]
assert sha("selfhost/semantic/expression_type_ids.slg") == unit["currentSourceSha256"]
assert unit["status"] == "passed" and (unit["stepsComplete"], unit["stepsTotal"]) == (4, 4)
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (2, 2)

managed = read(unit["managedFirst"])
assert managed["positiveBuildExit"] == managed["positiveNativeExit"] == 0
assert managed["negativeExit"] != 0
assert managed["positiveOutput"] == path("examples/regression/expected/1426-dictionary-index-interpolation.stdout.txt").read_text(encoding="utf-8").strip()
assert managed["negativeStderr"] == "sollang: semantic error at 1:8: [module '<main>'] index must be Text"
assert sha("src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll") == managed["managedSha"]

baseline = unit["baselinePreIrProbe"]
assert sha(baseline["source"]) == baseline["sourceSha256"]
assert sha(baseline["executable"]) == baseline["executableSha256"]
before_lines = path(baseline["output"]).read_text(encoding="utf-8").splitlines()
assert len(before_lines) == 3 and all(re.fullmatch(r"index=\d+ type=-1 expected=-1", line) for line in before_lines)

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
compiler = str(path(unit["selfhostBuild"]).parent / "compiler.exe")
assert sha(compiler) == unit["selfhostCompilerSha256"]
current = unit["currentPreIrProbe"]
assert sha(current["executable"]) == current["executableSha256"]
after_lines = path(current["output"]).read_text(encoding="utf-8").splitlines()
assert after_lines == ["index=0 type=2 expected=-1", "index=3 type=2 expected=-1", "index=6 type=-1 expected=1"]

positive = read(unit["positivePair"])
assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (15, 15)
assert {row["compilerSha256"] for row in positive["runs"] if row["compiler"] == "selfhost"} == {unit["selfhostCompilerSha256"]}
negative = read(unit["negativePair"])
assert negative["state"] == "passed" and negative["inputsStable"]
assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
managed_stderr = path(negative["logs"]["managedStderr"]).read_text(encoding="utf-8-sig").strip()
selfhost_stderr = path(negative["logs"]["selfhostStderr"]).read_text(encoding="utf-8-sig").strip()
assert managed_stderr == selfhost_stderr == managed["negativeStderr"]

controls = read(unit["retainedControls"])
assert controls["status"] == "passed" and controls["completed"] == controls["total"] == 22
assert controls["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
retained_positive = read(controls["positivePair"])
assert retained_positive["status"] == "passed" and retained_positive["inputStable"]
assert retained_positive["completed"] == retained_positive["total"] == 15
assert len(controls["negativePairs"]) == 7
for value in controls["negativePairs"]:
    retained = read(value)
    assert retained["state"] == "passed" and retained["inputsStable"], value
    assert retained["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    left = path(retained["logs"]["managedStderr"]).read_text(encoding="utf-8-sig").strip()
    right = path(retained["logs"]["selfhostStderr"]).read_text(encoding="utf-8-sig").strip()
    assert left == right and left.startswith("sollang: semantic error at "), value
print("[C587 dictionary index pre-IR] PASS facts 3/3, paired 2/2, retained 22/22 exact")
