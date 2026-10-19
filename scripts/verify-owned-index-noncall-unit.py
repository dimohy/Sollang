"""Close the owned-index source unit from current, linked execution proofs."""

import argparse
import hashlib
import json
import re
import textwrap
from pathlib import Path

from verification_source_proof import current_build_inputs
from verification_focused_proof import generic_proof

ROOT = Path(__file__).resolve().parent.parent


def require(condition, failure):
    if not condition:
        raise ValueError(failure)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("contract", "managed", "paired", "phase", "phase-contract", "related", "related-contract",
                 "production", "build", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    require(not args.output.exists(), "OWNED_INDEX_UNIT_OUTPUT_EXISTS")
    contract = args.contract.resolve()
    build_path = args.build.resolve() / "result.json"
    build = read(build_path)
    current_build_inputs(ROOT, build)
    binary = args.build.resolve() / "compiler.exe"
    require(sha(binary) == build["compilerSha256"], "OWNED_INDEX_UNIT_COMPILER_DRIFT")
    managed = generic_proof(args.managed, contract, 19, "managed")
    paired = generic_proof(args.paired, contract, 19, "paired")
    phase = generic_proof(args.phase, args.phase_contract, 1, "managed")
    related = generic_proof(args.related, args.related_contract, 16, "paired")
    related_contract = read(args.related_contract)
    related_cases = []
    for origin in related_contract.get("sourceContracts", []):
        source = ROOT / origin["path"]
        require(sha(source) == origin["sha256"], "OWNED_INDEX_UNIT_RELATED_CONTRACT_DRIFT")
        related_cases.extend(read(source)["cases"])
    require(related_cases == related_contract["cases"], "OWNED_INDEX_UNIT_RELATED_CASE_COVERAGE")
    for proof in (paired, related):
        require(proof["inputHashes"].get(str(build_path)) == sha(build_path)
                and proof["inputHashes"].get(str(binary)) == sha(binary), "OWNED_INDEX_UNIT_BUILD_LINK")
    require(paired["inputHashes"].get(str(args.managed.resolve())) == sha(args.managed),
            "OWNED_INDEX_UNIT_MANAGED_LINK")
    phase_contract = read(args.phase_contract)
    require(phase_contract.get("phaseScope") == "owned-index-noncall-before-typed-ir"
            and phase_contract.get("caseIds") == [case["id"] for case in read(contract)["cases"]]
            and phase["cases"][0].get("runStdout") == "semantic-owner=19/19", "OWNED_INDEX_UNIT_PHASE_COVERAGE")
    driver = ROOT / phase_contract["cases"][0]["source"]
    literals = re.findall(r'"""\n(.*?)\n\s*"""', driver.read_text(encoding="utf-8-sig"), re.S)
    require(len(literals) == 19, "OWNED_INDEX_UNIT_PHASE_FIXTURES")
    for literal, case in zip(literals, read(contract)["cases"]):
        require(textwrap.dedent(literal).strip()
                == (ROOT / case["source"]).read_text(encoding="utf-8-sig").strip(),
                "OWNED_INDEX_UNIT_PHASE_FIXTURE_DRIFT: " + case["id"])
    helper = ROOT / "scripts/probes/owned-index-storage-responsibility/semantic-phase-controls.slg"
    helper_text = helper.read_text(encoding="utf-8-sig")
    require(all(name in helper_text for name in ("semanticContext.prepare", "expressionTypeIds.resolveCallContext",
                "firstOwnedIndexReadDiagnostic")) and not any(name in helper_text for name in
                ("lowerPreparedIr", "lowerResolvedContext", "prepareNative", "emitChecked")),
            "OWNED_INDEX_UNIT_PHASE_BOUNDARY")
    require("input: Text -> Int" in helper_text and "diagnostic.sourceModule" in helper_text
            and "expectedModule" not in helper_text
            and phase["inputHashes"].get(str(helper.resolve())) == sha(helper), "OWNED_INDEX_UNIT_PHASE_VALUE")
    production = read(args.production)
    require(production.get("status") == "passed" and production.get("completed") == 6
            and production.get("total") == 6 and production.get("inputStable") is True
            and production.get("processesStopped") is True and production.get("inputDrift") == []
            and production.get("compilerSha256") == sha(binary)
            and production.get("inputHashes", {}).get(str(build_path)) == sha(build_path)
            and len(production.get("cases", [])) == 6
            and all(case.get("passed") is True and case.get("warningNoteFree") is True
                    for case in production["cases"]),
            "OWNED_INDEX_UNIT_PRODUCTION_LINK")
    audit = next(case for case in production["cases"] if case["id"] == "P1206")
    require(audit.get("allocationCount") == audit.get("releaseCount") == 169877
            and audit.get("invalidReleaseCount") == 0 and audit.get("auditRunCount") == 3
            and len(audit.get("auditRuns", [])) == 3
            and all(run.get("exact") is True and run.get("allocationCount") == run.get("releaseCount") == 169877
                    and run.get("invalidReleaseCount") == 0 for run in audit["auditRuns"]), "OWNED_INDEX_UNIT_PRODUCTION_AUDIT")
    paths = [args.managed, args.paired, args.phase, args.phase_contract, args.related,
             args.related_contract, args.production, build_path, contract, driver, helper, Path(__file__),
             ROOT / 'scripts/verification_focused_proof.py']
    record = {"schemaVersion": 1, "status": "passed", "unit": "C385-owned-index-noncall-semantic-boundary",
              "managedCompleted": 19, "managedTotal": 19, "pairedCompleted": 19, "pairedTotal": 19,
              "semanticBeforeTypedIrCompleted": 19, "semanticBeforeTypedIrTotal": 19,
              "relatedCompleted": 16, "relatedTotal": 16, "productionCompleted": 6, "productionTotal": 6,
              "compilerSha256": sha(binary), "inputsStable": True, "processesStopped": True,
              "records": {str(path.resolve()): sha(path) for path in paths},
              "scope": "Owned-index binding/return and readonly/scalar projection unit only; other units, seven phases, final sweep, Stage and frozen backlog remain pending."}
    args.output.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print("OWNED_INDEX_UNIT_PASSED paired19 phase19 related16 production6")


if __name__ == "__main__":
    main()
