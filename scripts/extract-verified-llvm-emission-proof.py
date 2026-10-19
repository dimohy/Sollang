"""Select actually executed LLVM cases from a completed mixed verification record."""

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def emitted_cases(parent):
    if (parent.get("schemaVersion") != 1 or parent.get("status") != "passed"
            or parent.get("mode") != "managed" or parent.get("inputsStable") is not True
            or parent.get("processesStopped") is not True
            or type(parent.get("completed")) is not int or type(parent.get("total")) is not int
            or parent["total"] <= 0
            or parent.get("completed") != parent.get("total")
            or not parent.get("cases") or len(parent["cases"]) != parent["total"]):
        raise ValueError("LLVM_SUBSET_PARENT_NOT_VERIFIED")
    semantic = parent.get("semanticPreflight", {})
    if semantic.get("status") != "passed-current-source" or semantic.get("codegenInvoked") is not False:
        raise ValueError("LLVM_SUBSET_SEMANTIC_PREFLIGHT_MISSING")
    selected = []
    for case in parent["cases"]:
        if case.get("passed") is not True or case.get("status") != "passed":
            raise ValueError("LLVM_SUBSET_CASE_NOT_VERIFIED")
        digest = case.get("emittedLlvmSha256")
        if digest is None:
            continue
        if (not isinstance(digest, str) or len(digest) != 64
                or any(c not in "0123456789abcdefABCDEF" for c in digest)
                or any(type(case.get(key)) is not int or case[key] != 0
                       for key in ("buildExit", "assemblyExit", "nativeLinkExit", "nativeRunExit"))):
            raise ValueError("LLVM_SUBSET_EMISSION_NOT_EXECUTED")
        selected.append(case)
    if not selected:
        raise ValueError("LLVM_SUBSET_EMPTY")
    return selected


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parent-proof", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source, output = args.parent_proof.resolve(), args.output.resolve()
    if not source.is_relative_to(ROOT / "artifacts") or not output.is_relative_to(ROOT / "artifacts") or output.exists():
        raise ValueError("LLVM_SUBSET_FRESH_ARTIFACT_PATH_REQUIRED")
    parent = json.loads(source.read_text(encoding="utf-8-sig"))
    selected = emitted_cases(parent)
    pins = parent.get("inputHashes")
    if not isinstance(pins, dict) or not pins:
        raise ValueError("LLVM_SUBSET_INPUTS_MISSING")
    for name, digest in pins.items():
        path = Path(name)
        if (not isinstance(digest, str) or len(digest) != 64
                or not path.is_absolute() or not path.is_file() or sha(path) != digest.upper()):
            raise ValueError("LLVM_SUBSET_INPUT_DRIFT: " + name)
    manifest = ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
    if pins.get(str(manifest)) != sha(manifest):
        raise ValueError("LLVM_SUBSET_CANONICAL_MANIFEST_MISSING")
    record = {
        "schemaVersion": 1, "scope": "verified-llvm-emission-subset", "status": "passed",
        "mode": "managed", "completed": len(selected), "total": len(selected),
        "inputsStable": True, "processesStopped": True,
        "parentProof": str(source), "parentProofSha256": sha(source),
        "parentCompleted": parent["completed"], "parentTotal": parent["total"],
        "semanticPreflight": parent["semanticPreflight"], "cases": selected,
        "inputHashes": {**pins, str(source): sha(source), str(Path(__file__).resolve()): sha(Path(__file__).resolve())}
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "completed": len(selected), "total": len(selected), "output": str(output)}))


if __name__ == "__main__":
    main()
