"""Validate current managed/native CLI bytes without relying on retired products."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def strict_text(data):
    if data.startswith(b"\xef\xbb\xbf"):
        raise ValueError("DIAGNOSTIC_UTF8_BOM")
    return data.decode("utf-8", errors="strict").replace("\r\n", "\n")


def require_completed(proof, mode, count):
    if (proof.get("status") != "passed" or proof.get("mode") != mode
            or proof.get("completed") != count or proof.get("total") != count
            or proof.get("inputsStable") is not True or proof.get("processesStopped") is not True
            or proof.get("activeProcess") or len(proof.get("cases", [])) != count
            or any(row.get("passed") is not True for row in proof["cases"])
            or not proof.get("processes")
            or any(not isinstance(row.get("exit"), int) for row in proof["processes"])):
        raise ValueError("DIAGNOSTIC_ENCODING_PROOF_INCOMPLETE")


def execution_log_root(path, proof, case_path, evidence):
    """Resolve only the explicit, fully revalidated managed projection protocol."""
    if proof.get('executionEvidenceMode') != 'projected-current-parent':
        return path.parent
    if proof.get('mode') != 'managed':
        raise ValueError('DIAGNOSTIC_ENCODING_UNSUPPORTED_PROJECTION')
    parent = Path(proof['parentCoverage']['managedProof']).resolve()
    module_path = Path(__file__).with_name('verify-focused-case-projection.py')
    if (not parent.is_relative_to(ROOT / 'artifacts')
            or proof['inputHashes'].get(str(parent)) != sha(parent)
            or proof['inputHashes'].get(str(module_path)) != sha(module_path)):
        raise ValueError('DIAGNOSTIC_ENCODING_PROJECTION_LINEAGE_CHANGED')
    spec = importlib.util.spec_from_file_location('diagnostic_managed_projection', module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if module.project_managed_subset(case_path, parent) != proof:
        raise ValueError('DIAGNOSTIC_ENCODING_PROJECTION_CHANGED')
    parent_proof = read_json(parent)
    require_completed(parent_proof, 'managed', parent_proof['total'])
    evidence[str(parent)] = sha(parent)
    evidence[str(module_path)] = sha(module_path)
    return parent.parent


def verify(contract_path):
    contract = read_json(contract_path)
    if contract.get("schemaVersion") != 2 or contract.get("status") != "focused-passed-full-gate-open":
        raise ValueError("DIAGNOSTIC_ENCODING_CONTRACT_INVALID")
    records = [(ROOT / contract[key]).resolve() for key in ("managedProof", "pairedProof")]
    case_path = (ROOT / contract["caseContract"]).resolve()
    cases = read_json(case_path)["cases"]
    ids = [row["id"] for row in cases]
    if len(ids) != 4 or len(set(ids)) != 4 or sorted(row["exit"] for row in cases) != [0, 1, 1, 1]:
        raise ValueError("DIAGNOSTIC_ENCODING_SCOPE_INVALID")
    evidence = {str(path): sha(path) for path in [contract_path, case_path, *records, Path(__file__)]}
    proofs = [read_json(path) for path in records]
    for path, proof, mode in zip(records, proofs, ("managed", "paired")):
        log_root = execution_log_root(path, proof, case_path, evidence)
        if proof.get('executionEvidenceMode') != 'projected-current-parent':
            require_completed(proof, mode, 4)
        if [row["id"] for row in proof["cases"]] != ids:
            raise ValueError("DIAGNOSTIC_ENCODING_CASE_IDENTITY_CHANGED")
        if not proof.get("inputHashes") or proof["inputHashes"].get(str(case_path)) != sha(case_path):
            raise ValueError("DIAGNOSTIC_ENCODING_CONTRACT_NOT_PINNED")
        for name, expected in proof["inputHashes"].items():
            source = Path(name)
            if not source.is_file() or sha(source) != expected:
                raise ValueError("DIAGNOSTIC_ENCODING_INPUT_CHANGED: " + name)
        for case in cases:
            log = log_root / case["id"] / "build.stderr"
            text = strict_text(log.read_bytes())
            if text.rstrip("\n") != case["stderr"]:
                raise ValueError("DIAGNOSTIC_ENCODING_WHOLE_STDERR_MISMATCH: " + case["id"])
            evidence[str(log)] = sha(log)
            if case["exit"] == 0:
                output = log_root / case["id"] / "run.stdout"
                if strict_text(output.read_bytes()).rstrip("\n") != case["stdout"]:
                    raise ValueError("DIAGNOSTIC_ENCODING_POSITIVE_OUTPUT_CHANGED")
                evidence[str(output)] = sha(output)
    negatives = [row for row in cases if row["exit"] == 1]
    if sum(any("\uac00" <= char <= "\ud7a3" for char in row["stderr"]) for row in negatives) != 1:
        raise ValueError("DIAGNOSTIC_ENCODING_KOREAN_CASE_MISSING")
    if sum(row["stderr"].isascii() for row in negatives) != 2:
        raise ValueError("DIAGNOSTIC_ENCODING_ASCII_CONTROLS_MISSING")
    baseline_path = (ROOT / contract["historicalBaseline"]).resolve()
    baseline = read_json(baseline_path)
    data_path = Path(baseline["logs"]["managedStderr"])
    if baseline.get("failureId") != "NEGATIVE_CHECK_FAILED":
        raise ValueError("DIAGNOSTIC_ENCODING_BASELINE_CHANGED")
    try:
        strict_text(data_path.read_bytes())
    except UnicodeDecodeError:
        pass
    else:
        raise ValueError("DIAGNOSTIC_ENCODING_FAILED_UTF8_CONTROL_NOT_REPRODUCED")
    evidence[str(baseline_path)] = sha(baseline_path)
    evidence[str(data_path)] = sha(data_path)
    return {"schemaVersion": 1, "status": "passed", "completed": 4, "total": 4,
            "scope": "strict UTF8 Korean1 ASCII2 positive1; full compiler gates remain open",
            "evidenceHashes": evidence}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify(args.contract.resolve())
    if args.output:
        if args.output.exists():
            raise ValueError("DIAGNOSTIC_ENCODING_OUTPUT_ALREADY_EXISTS")
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("[CLI diagnostic encoding] PASS strict UTF8 Korean1 ASCII2 positive1; full gates open")


if __name__ == "__main__":
    main()
