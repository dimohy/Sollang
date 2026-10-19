#!/usr/bin/env python3
"""Verify current self-hosted nominal member behavior against managed proofs."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIBRARY = "scripts/probes/interpolation/c527-imported-struct-literal-library.slg"
CASES = {
    "spacedAssociatedMember": (
        "scripts/probes/interpolation/c527-spaced-associated-member.slg",
        "artifacts/scratch/c527-spaced-associated-managed-20260929-01/result.json",
        False,
    ),
    "associatedMemberControl": (
        "examples/regression/diagnostics/2062-interpolated-uninvoked-associated-member.slg",
        "artifacts/scratch/c527-associated-control-managed-20260929-01/result.json",
        False,
    ),
    "spacedMissingAssociatedMember": (
        "scripts/probes/interpolation/c527-spaced-missing-associated-member.slg",
        "artifacts/scratch/c527-spaced-missing-associated-managed-20260929-01/result.json",
        False,
    ),
    "spacedUnknownEnumVariant": (
        "scripts/probes/interpolation/c527-spaced-unknown-enum-variant.slg",
        "artifacts/scratch/c527-spaced-unknown-enum-managed-20260929-01/result.json",
        False,
    ),
    "spacedEnumVariant": (
        "scripts/probes/interpolation/c527-spaced-enum-variant.slg",
        "artifacts/scratch/c527-spaced-enum-managed-20260929-01/result.json",
        False,
    ),
    "enumVariantControl": (
        "scripts/probes/interpolation/c527-enum-variant-control.slg",
        "artifacts/scratch/c527-enum-control-managed-20260929-01/result.json",
        False,
    ),
    "spacedGenericEnumVariant": (
        "scripts/probes/interpolation/c527-spaced-generic-enum-variant.slg",
        "artifacts/scratch/c527-spaced-generic-enum-managed-20260929-01/result.json",
        False,
    ),
    "genericEnumVariantControl": (
        "scripts/probes/interpolation/c527-generic-enum-variant-control.slg",
        "artifacts/scratch/c527-generic-enum-control-managed-20260929-01/result.json",
        False,
    ),
    "spacedComputedMember": (
        "scripts/probes/interpolation/c527-spaced-computed-member.slg",
        "artifacts/scratch/c527-spaced-computed-managed-20260929-01/result.json",
        False,
    ),
    "computedMemberControl": (
        "scripts/probes/interpolation/c527-computed-member-control.slg",
        "artifacts/scratch/c527-computed-control-managed-20260929-01/result.json",
        False,
    ),
    "spacedMissingMember": (
        "scripts/probes/interpolation/c527-fully-qualified-struct-missing-member-spaced.slg",
        "artifacts/scratch/c527-spaced-missing-member-managed-20260929-01/result.json",
        True,
    ),
    "missingMember": (
        "scripts/probes/interpolation/c527-fully-qualified-struct-missing-member.slg",
        "artifacts/scratch/c527-fullpath-missing-member-managed-20260929-01/result.json",
        True,
    ),
    "privateMemberLocationControl": (
        "scripts/probes/interpolation/c527-nested-private-intermediate.slg",
        "artifacts/scratch/c527-private-member-managed-control-20260929-01/result.json",
        "scripts/probes/interpolation/sample/nested_private.slg",
    ),
    "fullPathPositive": (
        "scripts/probes/interpolation/c527-fully-qualified-struct-literal-field.slg",
        "artifacts/scratch/c527-fully-qualified-managed-first-20260929-01/result.json",
        True,
    ),
    "fullPathUnknown": (
        "scripts/probes/interpolation/c527-fully-qualified-unknown-struct.slg",
        "artifacts/scratch/c527-fully-qualified-unknown-managed-20260929-01/result.json",
        True,
    ),
    "importAliasControl": (
        "scripts/probes/interpolation/c527-imported-struct-literal-field.slg",
        "artifacts/scratch/c527-imported-struct-managed-first-20260929-03/result.json",
        True,
    ),
    "importAliasFieldTypeControl": (
        "scripts/probes/interpolation/c527-imported-struct-literal-bad-field.slg",
        "artifacts/scratch/c527-imported-bad-field-managed-20260929-01/result.json",
        True,
    ),
    "localNamespaceControl": (
        "scripts/probes/interpolation/c527-namespaced-struct-literal-field.slg",
        "artifacts/scratch/c527-namespaced-struct-managed-20260929-01/result.json",
        False,
    ),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True, help="Completed focused compiler output directory")
    parser.add_argument("--output", type=Path, required=True, help="New proof directory")
    parser.add_argument("--case", action="append", choices=CASES,
                        help="Run only the named case; may be repeated")
    args = parser.parse_args()
    selected = list(dict.fromkeys(args.case or CASES))
    build = args.build.resolve()
    output = args.output.resolve()
    assert not output.exists(), f"Proof output already exists: {output}"
    build_record = json.loads((build / "result.json").read_text(encoding="utf-8"))
    compiler = build / "compiler.exe"
    assert build_record["status"] == "passed" and build_record["inputsStable"]
    assert build_record["compilerSha256"] == sha(compiler)
    comparisons = [ROOT / path for path in (
        "artifacts/scratch/c527-missing-member-source-comparison-20260929-01.json",
        "artifacts/scratch/c527-spaced-missing-member-source-comparison-20260929-01.json",
        "artifacts/scratch/c527-private-member-location-source-comparison-20260929-01.json",
        "artifacts/scratch/c527-spaced-computed-source-comparison-20260929-01.json",
        "artifacts/scratch/c527-spaced-enum-source-comparison-20260929-01.json",
        "artifacts/scratch/c527-spaced-associated-source-comparison-20260929-01.json",
    )]
    assert all(json.loads(path.read_text(encoding="utf-8"))["status"] == "passed"
               for path in comparisons)
    fixtures = {
        "scripts/probes/interpolation/c527-fully-qualified-struct-missing-member.slg":
            "examples/regression/diagnostics/2117-interpolation-fullpath-missing-member.slg",
        "scripts/probes/interpolation/c527-fully-qualified-struct-missing-member-spaced.slg":
            "examples/regression/diagnostics/2118-interpolation-spaced-fullpath-missing-member.slg",
        LIBRARY: "examples/regression/fixtures/2112-imported-interpolation-point.slg",
        "scripts/probes/interpolation/c527-spaced-computed-member.slg":
            "examples/regression/2119-interpolation-spaced-computed-member.slg",
        "scripts/probes/interpolation/c527-spaced-enum-variant.slg":
            "examples/regression/diagnostics/2120-interpolation-spaced-enum-variant.slg",
        "scripts/probes/interpolation/c527-spaced-generic-enum-variant.slg":
            "examples/regression/diagnostics/2121-interpolation-spaced-generic-enum-variant.slg",
        "scripts/probes/interpolation/c527-spaced-associated-member.slg":
            "examples/regression/diagnostics/2122-interpolation-spaced-associated-member.slg",
        "scripts/probes/interpolation/c527-spaced-missing-associated-member.slg":
            "examples/regression/diagnostics/2123-interpolation-spaced-missing-associated-member.slg",
        "scripts/probes/interpolation/c527-spaced-unknown-enum-variant.slg":
            "examples/regression/diagnostics/2124-interpolation-spaced-unknown-enum-variant.slg",
    }
    for probe, fixture in fixtures.items():
        assert (ROOT / probe).read_bytes() == (ROOT / fixture).read_bytes(), (probe, fixture)
    inputs = [compiler, build / "result.json", Path(__file__), ROOT / LIBRARY]
    inputs += comparisons + [ROOT / path for path in fixtures.values()]
    for name in selected:
        probe, managed, extra_source = CASES[name]
        inputs.extend((ROOT / probe, ROOT / managed))
        if isinstance(extra_source, str):
            inputs.append(ROOT / extra_source)
        proof = json.loads((ROOT / managed).read_text(encoding="utf-8"))
        assert isinstance(proof["buildExit"], int)
        assert proof.get("buildStderr") is None or isinstance(proof.get("buildStderr"), str)
    input_hashes = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for name in selected:
        probe, managed_path, extra_source = CASES[name]
        case_dir = output / name
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", probe]
        if extra_source:
            command.append(LIBRARY if extra_source is True else extra_source)
        command += ["-o", str(exe), "--target", "windows-x64", "--llvm",
                    ".tools/llvm-22.1.8", "--stdlib", "stdlib", "-O1"]
        build_exit = run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        run_exit = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
        managed = json.loads((ROOT / managed_path).read_text(encoding="utf-8"))
        expected_error = managed["buildExit"] != 0
        actual_stderr = text(case_dir / "build.stderr.txt")
        expected_stderr = (managed.get("buildStderr") or "").replace("\r\n", "\n")
        actual_stdout = text(case_dir / "run.stdout.txt") if run_exit is not None else None
        expected_stdout = managed.get("runStdout")
        passed = (
            (build_exit != 0) == expected_error
            and actual_stderr == expected_stderr
            and (expected_error or (run_exit == 0 and actual_stdout == expected_stdout))
        )
        cases[name] = {"status": "passed" if passed else "failed", "managed": managed_path,
                       "probe": probe, "buildExit": build_exit, "runExit": run_exit,
                       "actualStderr": actual_stderr, "expectedStderr": expected_stderr,
                       "actualStdout": actual_stdout, "expectedStdout": expected_stdout}
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
    assert input_hashes == {str(path): sha(path) for path in inputs}, "Input drift during verification"
    completed = sum(case["status"] == "passed" for case in cases.values())
    record = {"schemaVersion": 1, "status": "passed" if completed == len(selected) else "failed",
              "completed": completed, "total": len(selected), "compilerSha256": sha(compiler),
              "inputSha256": input_hashes, "cases": cases, "selectedCases": selected,
              "fixturesEquivalentToProbes": True}
    (output / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    assert completed == len(selected), f"Paired behavior failed: {completed}/{len(selected)}"


if __name__ == "__main__":
    main()
