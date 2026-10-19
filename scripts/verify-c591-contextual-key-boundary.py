"""Keep the C591 contextual key failure localized to interpolation lowering."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c591-contextual-key-boundary-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


boundary = read(str(RECEIPT))
assert boundary["status"] == "unresolved"
assert boundary["failureId"] == "C591.INTERPOLATION_CONTEXTUAL_STRUCT_LITERAL_DROPPED"
assert sha(boundary["currentSelfhostCompiler"]) == boundary["currentSelfhostCompilerSha256"]
assert sha(boundary["astProbeSource"]) == boundary["astProbeSourceSha256"]
assert sha(boundary["astProbeExecutable"]) == boundary["astProbeExecutableSha256"]

managed = read(boundary["managedFirst"])
positive = next(row for row in managed["cases"] if row["id"] == boundary["managedPositiveCase"])
assert managed["status"] == "passed" and positive["buildExitCode"] == 0
assert positive["nativeStdout"] == boundary["managedExpectedStdout"]
assert sha(positive["source"]) == positive["sourceSha256"]

named = read(boundary["namedKeyControl"])
assert named["status"] == "passed" and named["inputStable"]
assert named["completed"] == named["total"] == 1
assert {row["fixture"] for row in named["runs"]} == {"2045-interpolated-named-struct-dictionary-key"}

lines = path(boundary["astProbe"]).read_text(encoding="utf-8-sig").splitlines()
assert "ast=2 kind=38 parent=0 start=8 length=20" in lines
assert "ir=0 kind=7 parent=-1 operand0=1 operand1=2" in lines
assert "ir=2 kind=1 parent=0 operand0=-1 operand1=-1" in lines
assert not any(line.startswith("ir=") and "kind=38" in line for line in lines)

failure = path(boundary["currentFailureStderr"]).read_text(encoding="utf-8-sig").strip()
assert failure.startswith("sollang: semantic error at 1:11:")
assert "unknown binding 'scope'" in failure
print("[C591 contextual key boundary] VERIFIED unresolved: AST literal kind 38 dropped, named nominal key 1/1 passes")
