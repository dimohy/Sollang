#!/usr/bin/env python3
"""Close the focused C527 direct binary pre-IR unit from pinned proofs."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROOFS = {
    "managed": "artifacts/scratch/c527-preir-binary-managed-first-20260929-01/result.json",
    "comparison": "artifacts/scratch/c527-preir-binary-source-comparison-20260929-01.json",
    "paired": "artifacts/scratch/c527-preir-binary-paired-20260929-01/result.json",
    "lexical": "artifacts/scratch/c527-preir-binary-lexical-float-paired-20260929-01/result.json",
    "unaryControls": "artifacts/scratch/c527-preir-binary-prior-unary-controls-20260929-01/result.json",
    "directControls": "artifacts/scratch/c527-preir-binary-prior-direct-controls-20260929-01/result.json",
    "memberControls": "artifacts/scratch/c527-preir-binary-prior-member-controls-20260929-01/result.json",
    "sourceAudit": "artifacts/scratch/c527-semantic-source-order-20260929-05.json",
}
FIXTURES = {
    "float": ("diagnostics/2131-interpolation-preir-binary-float", "stderr.contains"),
    "int": ("2132-interpolation-preir-binary-int", "stdout"),
    "compare": ("2133-interpolation-preir-binary-compare", "stdout"),
    "logical": ("2134-interpolation-preir-binary-logical", "stdout"),
    "invalidArithmetic": ("diagnostics/2135-interpolation-preir-binary-invalid-arithmetic", "stderr.contains"),
    "invalidLogical": ("diagnostics/2136-interpolation-preir-binary-invalid-logical", "stderr.contains"),
    "lexical": ("diagnostics/2137-interpolation-preir-binary-lexical-float", "stderr.contains"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    paths = {name: ROOT / relative for name, relative in PROOFS.items()}
    records = {name: read(path) for name, path in paths.items()}
    build_path = args.build.resolve()
    build_result = read(build_path / "result.json")
    compiler = build_path / "compiler.exe"
    if build_result["status"] != "passed" or not build_result["inputsStable"] or build_result["compilerSha256"] != sha(compiler):
        raise ValueError("SLG compiler build is not a stable pass")
    for name in ("managed", "comparison", "paired", "lexical", "unaryControls", "directControls", "memberControls", "sourceAudit"):
        if records[name]["status"] != "passed":
            raise ValueError(f"{name} proof did not pass")
    if records["managed"]["completed"] != 6 or records["managed"]["total"] != 6:
        raise ValueError("C# first coverage changed")
    if records["paired"]["completed"] != 6 or records["paired"]["total"] != 6:
        raise ValueError("direct binary paired coverage changed")
    if records["lexical"]["completed"] != 1 or records["lexical"]["total"] != 1:
        raise ValueError("lexical Float32 paired coverage changed")
    if any(records[name]["completed"] != total or records[name]["total"] != total
           for name, total in (("unaryControls", 4), ("directControls", 4), ("memberControls", 2))):
        raise ValueError("retained control coverage changed")
    if any(not records[name].get("inputStable", all(sha(Path(path)) == digest
                                                     for path, digest in records[name]["inputSha256"].items()))
           for name in ("managed", "paired", "lexical", "unaryControls", "directControls", "memberControls")):
        raise ValueError("a focused proof has unstable inputs")
    if any(records[name]["compilerSha256"] != sha(compiler)
           for name in ("paired", "unaryControls", "directControls", "memberControls")):
        raise ValueError("focused proofs used different SLG compilers")
    comparison = records["comparison"]
    if comparison["managed"]["sha256"] != sha(ROOT / comparison["managed"]["path"]):
        raise ValueError("managed source changed after source comparison")
    if not any(key.endswith(comparison["selfhost"]["paths"][0].replace("/", "\\"))
               and digest == comparison["selfhost"]["sha256"][0]
               for key, digest in records["managed"]["inputSha256"].items()):
        raise ValueError("SLG baseline source comparison differs from C# first proof")
    source_audit = records["sourceAudit"]
    if not all(sha(ROOT / name) == digest for name, digest in source_audit["sourceSha256"].items()):
        raise ValueError("current source changed after its order audit")
    inputs = [*paths.values(), build_path / "result.json", compiler, Path(__file__).resolve()]
    for key, (fixture, suffix) in FIXTURES.items():
        case = (records["managed"]["cases"][key] if key != "lexical" else None)
        probe = ROOT / (case["source"] if case else "scripts/probes/interpolation/c527-preir-binary-lexical-float.slg")
        fixture_source = ROOT / "examples/regression" / f"{fixture}.slg"
        output_base = ROOT / "examples/regression" / ("expected" if suffix == "stdout" else "")
        fixture_output = output_base / f"{fixture}.{suffix}.txt"
        if fixture_source.read_bytes() != probe.read_bytes():
            raise ValueError(f"fixture source differs from probe: {fixture}")
        expected_output = (records["lexical"]["results"]["managed"]["buildStderr"] if key == "lexical"
                           else case["buildStderr"] if suffix == "stderr.contains" else case["runStdout"])
        if fixture_output.read_text(encoding="utf-8").strip() not in expected_output:
            raise ValueError(f"fixture output differs from C# proof: {fixture}")
        inputs.extend((probe, fixture_source, fixture_output))
    before = {str(path): sha(path) for path in inputs}
    stable = before == {str(path): sha(path) for path in inputs}
    result = {"schemaVersion": 1, "unit": "C527 direct binary pre-IR result type",
              "status": "passed" if stable else "failed", "completed": 7 if stable else 0,
              "total": 7, "controlsCompleted": 10, "controlsTotal": 10,
              "fixturesVerified": len(FIXTURES), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": before,
              "proofs": PROOFS, "buildResult": str(build_path / "result.json")}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError("unit inputs drifted during closure")
    print("PASS C527 direct binary 7/7, related controls 10/10, retained fixtures 7/7")


if __name__ == "__main__":
    main()
