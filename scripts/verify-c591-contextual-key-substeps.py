"""Validate the C591 contextual key source, compiler, and focused pairs."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c591-contextual-key-substeps-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def sha256(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


def lines(value: str) -> list[str]:
    return path(value).read_text(encoding="utf-8-sig").splitlines()


receipt = json.loads(RECEIPT.read_text(encoding="utf-8-sig"))
assert receipt["status"] == "passed"
assert (receipt["completed"], receipt["total"]) == (6, 6)
assert [step["status"] for step in receipt["steps"]] == ["complete"] * 6
for value, expected in receipt["sourceHashes"].items():
    assert sha256(value) == expected, value
for key in ("managedPositive", "astProbe", "preIrProbe"):
    item = receipt[key]
    assert sha256(item["executable"]) == item["sha256"], key

assert lines(receipt["managedPositive"]["stdout"]) == ["value=lexer"]
assert receipt["managedNegative"]["compilerExitCode"] == 1
assert lines(receipt["managedNegative"]["stderr"]) == [
    "sollang: semantic error at 1:9: [module '<main>'] contextual SymbolKey literal is missing field 'id'"
]
ast = lines(receipt["astProbe"]["stdout"])
assert "ir=2 kind=12 parent=0 operand0=3 operand1=4" in ast
assert "ir=5 kind=13 parent=2 operand0=-1 operand1=-1" in ast
assert "ir=6 kind=1 parent=2 operand0=-1 operand1=-1" in ast
assert lines(receipt["preIrProbe"]["stdout"]) == [
    "literal=2 type=27", "field=3 ordinal=1", "field=5 ordinal=0"
]
build = json.loads(path(receipt["selfhostBuild"]).read_text(encoding="utf-8-sig"))
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == receipt["selfhostCompilerSha256"]
assert sha256(str(path(receipt["selfhostBuild"]).parent / "compiler.exe")) == receipt["selfhostCompilerSha256"]
pair = json.loads(path(receipt["positivePair"]).read_text(encoding="utf-8-sig"))
assert pair["status"] == "passed" and pair["inputStable"]
assert pair["completed"] == pair["total"] and pair["total"] >= 2
assert len(pair["runs"]) == 2 * pair["total"]
runs = [run for run in pair["runs"] if run["fixture"].startswith(("2042-", "2046-"))]
assert len(runs) == 4
for run in runs:
    assert (run["buildExit"], run["llvmAsExit"], run["directCallExit"], run["nativeExit"]) == (0, 0, 0, 0)
    if run["compiler"] == "selfhost":
        assert run["compilerSha256"] == receipt["selfhostCompilerSha256"]

for negative in receipt["negativePairs"]:
    number = negative["number"]
    native = path(negative["selfhost"])
    managed = path(negative["managed"])
    expected = next((ROOT / "examples/regression/diagnostics").glob(f"{number}-*.stderr.contains.txt"))
    assert lines(str(native)) == lines(str(managed)), number
    assert len(lines(str(native))) == len(lines(str(expected))) == 1, number
    assert lines(str(expected))[0] in lines(str(native))[0], number
    assert not (native.parent / "case.exe").exists(), number

print("[C591 contextual key] VERIFIED 6/6 substeps; 2 positive and 4 exact negative C# pairs")
