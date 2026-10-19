"""Check that the await ownership LLVM regression really loads the pinned stdlib."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import textwrap

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT / "scripts/contracts/full-stdlib-nested-await-owner-emission.json"


def validate_runtime_sources(contract, wrapper, stdlib_sources, program):
    paths = contract.get("observedSourceOrder")
    if (not isinstance(paths, list) or len(paths) < 2
            or any(not isinstance(path, str) for path in paths)
            or len(paths) != len(set(paths))):
        raise ValueError("AWAIT_OWNER_SOURCE_ORDER_INVALID")
    if set(paths[:-1]) != set(stdlib_sources):
        raise ValueError("AWAIT_OWNER_STDLIB_SCOPE_MISMATCH")
    actual = re.findall(r'"(stdlib/[^"\r\n]+\.slg)"', wrapper)
    if actual != paths[:-1]:
        raise ValueError("AWAIT_OWNER_RUNTIME_SOURCE_ORDER_MISMATCH")
    embedded = re.findall(r'"""(.*?)"""', wrapper, re.DOTALL)
    if len(embedded) != 1 or textwrap.dedent(embedded[0]).strip() != program.strip():
        raise ValueError("AWAIT_OWNER_EMBEDDED_PROGRAM_MISMATCH")
    if re.search(r"sources!\s*->\s*compiler\.emitChecked\b", wrapper) is None:
        raise ValueError("AWAIT_OWNER_NATIVE_PREPARATION_MISSING")


def validate_proof(proof, contract_path, wrapper_path):
    if (proof.get("status") != "passed" or proof.get("inputsStable") is not True
            or proof.get("processesStopped") is not True
            or proof.get("completed") != 1 or proof.get("total") != 1):
        raise ValueError("AWAIT_OWNER_LLVM_PROOF_NOT_COMPLETE")
    cases = proof.get("cases", [])
    if (len(cases) != 1 or cases[0].get("passed") is not True
            or cases[0].get("status") != "passed"
            or re.fullmatch(r"[0-9A-Fa-f]{64}", cases[0].get("emittedLlvmSha256", "")) is None
            or any(cases[0].get(key) != 0 for key in
                   ("buildExit", "assemblyExit", "nativeLinkExit", "nativeRunExit"))):
        raise ValueError("AWAIT_OWNER_LLVM_NOT_EXECUTED")
    if cases[0].get("nativeRunStdout") != "count=1,status=0":
        raise ValueError("AWAIT_OWNER_NATIVE_OUTPUT_MISMATCH")
    pins = proof.get("inputHashes", {})
    for path in (contract_path, wrapper_path):
        if pins.get(str(path)) != hashlib.sha256(path.read_bytes()).hexdigest().upper():
            raise ValueError("AWAIT_OWNER_PROOF_INPUT_DRIFT")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proof", type=Path, required=True)
    parser.add_argument("--contract", type=Path, default=CONTRACT,
                        help="Exact source contract pinned by the selected execution proof")
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output", type=Path)
    destination.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    contract_path = args.contract.resolve(strict=True)
    if not contract_path.is_relative_to(ROOT) or contract_path.suffix != ".json":
        raise ValueError("AWAIT_OWNER_CONTRACT_PATH_INVALID")
    contract = json.loads(contract_path.read_text(encoding="utf-8-sig"))
    wrapper_path = ROOT / contract["cases"][0]["source"]
    program_path = ROOT / contract["observedSourceOrder"][-1]
    stdlib = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "stdlib").rglob("*.slg"))
    validate_runtime_sources(contract, wrapper_path.read_text(encoding="utf-8-sig"),
                             stdlib, program_path.read_text(encoding="utf-8-sig"))
    proof_path = args.proof.resolve()
    proof = json.loads(proof_path.read_text(encoding="utf-8-sig"))
    validate_proof(proof, contract_path, wrapper_path)
    if args.check_only:
        print(json.dumps({"status": "passed", "stdlibSources": len(stdlib), "packageSources": len(stdlib) + 1}))
        return
    output = args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / "artifacts"):
        raise ValueError("AWAIT_OWNER_FRESH_RESULT_PATH_REQUIRED")
    inputs = [Path(__file__).resolve(), contract_path, wrapper_path, program_path, proof_path,
              *[ROOT / path for path in stdlib]]
    record = {"schemaVersion": 1, "status": "passed", "scope": "await-function-owner-runtime-input-contract",
              "stdlibSources": len(stdlib), "packageSources": len(stdlib) + 1,
              "inputHashes": {str(path): hashlib.sha256(path.read_bytes()).hexdigest().upper() for path in inputs},
              "actualLlvmExecutionProof": str(proof_path), "compilerStabilizationPromoted": False}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "stdlibSources": len(stdlib), "packageSources": len(stdlib) + 1}))


if __name__ == "__main__":
    main()
