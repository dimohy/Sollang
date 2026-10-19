"""Freeze observed C# diagnostics without promoting capture to verification."""

import argparse
import copy
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def freeze(intent, observation):
    if observation.get("mode") != "managed":
        raise ValueError("MANAGED_REFERENCE_REQUIRED")
    if observation.get("status") not in ("passed", "failed"):
        raise ValueError("MANAGED_REFERENCE_NONTERMINAL_OR_CANCELLED")
    if not observation.get("inputsStable") or not observation.get("processesStopped"):
        raise ValueError("MANAGED_REFERENCE_NOT_STABLE_AND_STOPPED")
    for name, expected in observation["inputHashes"].items():
        if sha(Path(name)) != expected:
            raise ValueError("MANAGED_REFERENCE_INPUT_CHANGED: " + name)
    actual = {row["id"]: row for row in observation["cases"]}
    if len(actual) != len(observation["cases"]) or len(actual) != len(intent["cases"]) or set(actual) != {case["id"] for case in intent["cases"]}:
        raise ValueError("MANAGED_REFERENCE_INCOMPLETE")
    output = copy.deepcopy(intent)
    phases = {}
    for case in output["cases"]:
        row = actual[case["id"]]
        source = Path(case["source"]).resolve()
        if observation["inputHashes"].get(str(source)) != sha(source):
            raise ValueError("MANAGED_REFERENCE_SOURCE_NOT_COVERED")
        if row["buildExit"] != case["exit"]:
            raise ValueError("MANAGED_REFERENCE_REQUIRED_OUTCOME_CHANGED")
        if case["exit"] == 0:
            if row.get("runExit") != 0 or row.get("runStdout") != case.get("stdout", ""):
                raise ValueError("MANAGED_REFERENCE_POSITIVE_BEHAVIOR_CHANGED")
            if row["buildStderr"] != case["stderr"]:
                raise ValueError("MANAGED_REFERENCE_POSITIVE_DIAGNOSTIC_CHANGED")
            phases[case["id"]] = "compile-and-run"
        else:
            diagnostic = row["buildStderr"]
            if not diagnostic.startswith("sollang:"):
                raise ValueError("MANAGED_REFERENCE_COMPILER_DIAGNOSTIC_REQUIRED")
            case["stderr"] = diagnostic
            phases[case["id"]] = "parsing" if ": parse error at " in diagnostic else "semantic"
    output["status"] = "managed-reference-expectations-frozen"
    output["diagnosticPhases"] = phases
    output["completionScope"] = "reference capture only; requires a fresh frozen-contract managed verification and source comparison"
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--intent", type=Path, required=True)
    parser.add_argument("--observation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("MANAGED_REFERENCE_OUTPUT_EXISTS")
    read = lambda path: json.loads(path.read_text(encoding="utf-8-sig"))
    result = freeze(read(args.intent), read(args.observation))
    result["referenceObservation"] = {"path": str(args.observation), "sha256": sha(args.observation)}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("MANAGED_REFERENCE_CAPTURED; VERIFICATION_NOT_PROMOTED")


if __name__ == "__main__":
    main()
