#!/usr/bin/env python3
"""Pin C# numeric call literal ranges, then compare the self-host compiler."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from verification_fingerprints import managed_runtime_inputs
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
MANAGED_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
BARE = ROOT / "scripts/probes/diagnostics/c385-indexed-enum-method-bare-arguments.slg"
BRANCH = ROOT / "scripts/probes/diagnostics/c385-indexed-enum-method-contextual-if-argument.slg"
DIRECT = ROOT / "scripts/probes/diagnostics/c385-direct-numeric-call-argument.slg"
CASES = {
    "maxValid": ("bare", "id(1, 2)", "id(255, 2)", "value=321", None),
    "characterValid": ("bare", "id(1, 2)", "id('%', 2)", "value=103", None),
    "characterOverflow": ("bare", "id(1, 2)", "id('Ā', 2)", None,
                          "numeric literal 256 is out of range for UInt8 (0..255)"),
    "firstOverflow": ("bare", "id(1, 2)", "id(256, 2)", None, "numeric literal 256 is out of range for UInt8 (0..255)"),
    "secondOverflow": ("bare", "id(1, 2)", "id(1, 256)", None, "numeric literal 256 is out of range for UInt8 (0..255)"),
    "negative": ("bare", "id(1, 2)", "id(-1, 2)", None, "numeric literal -1 is out of range for UInt8 (0..255)"),
    "negativeZero": ("bare", "id(1, 2)", "id(-0, 2)", "value=66", None),
    "branchOverflow": ("branch", "if { 1 } else { 2 }", "if { 256 } else { 2 }", None,
                       "numeric literal 256 is out of range for UInt8 (0..255)"),
    "directValid": ("direct", "1 -> hexValue", "255 -> hexValue", "value=191", None),
    "directOverflow": ("direct", "1 -> hexValue", "256 -> hexValue", None,
                       "numeric literal 256 is out of range for UInt8 (0..255)"),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    sources = {"bare": read(BARE), "branch": read(BRANCH), "direct": read(DIRECT)}
    checked = [*managed_runtime_inputs(MANAGED), MANAGED_SOURCE, BARE, BRANCH, DIRECT, Path(__file__).resolve()]
    checked.extend(sorted((ROOT / "stdlib").rglob("*.slg")))
    checked.extend([ROOT / "scripts/verification_execution.py", ROOT / "scripts/completed_artifact_plan.py",
                    ROOT / "scripts/ArtifactLifecycle.ps1", ROOT / "scripts/Invoke-CompletedArtifactCleanup.ps1",
                    ROOT / "scripts/contracts/artifact-lifecycle.json"])
    for name, (source_key, anchor, *_rest) in CASES.items():
        if sources[source_key].count(anchor) != 1:
            raise ValueError(f"{name} source anchor changed")
    native = None
    reference = None
    if args.mode == "paired":
        if not args.build or not args.managed_proof:
            raise ValueError("paired mode requires --build and --managed-proof")
        build = args.build.resolve()
        record = json.loads(read(build / "result.json"))
        native = build / "compiler.exe"
        if record["status"] != "passed" or not record["inputsStable"] or sha256(native) != record["compilerSha256"]:
            raise ValueError("self-host build did not pass with stable inputs")
        reference = json.loads(read(args.managed_proof.resolve()))
        if reference["status"] != "passed" or reference["inputSha256"] != {str(path): sha256(path) for path in checked}:
            raise ValueError("C# proof inputs changed")
        checked.extend([native, build / "result.json", args.managed_proof.resolve()])
        checked.extend(sorted((ROOT / "selfhost").rglob("*.slg")))
    before = {str(path): sha256(path) for path in checked}
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    cases: dict[str, dict[str, object]] = {}
    result = {"schemaVersion": 1, "status": "running", "mode": args.mode,
              "completed": 0, "total": len(CASES), "cases": cases,
              "inputSha256": before, "inputHashes": before}
    execution = VerificationExecution(ROOT, output, result,
        lambda: before == {str(path): sha256(path) if path.is_file() else "MISSING" for path in checked}, sha256)
    execution.save()
    error = None
    try:
        for name, (source_key, anchor, replacement, expected_stdout, expected_error) in CASES.items():
            source = sources[source_key]
            if source.count(anchor) != 1:
                raise ValueError(f"{name} source anchor changed")
            case_dir = output / name
            case_dir.mkdir()
            path = case_dir / "probe.slg"
            path.write_text(source.replace(anchor, replacement), encoding="utf-8", newline="\n")
            managed_exe = case_dir / "managed.exe"
            managed_build = execution.run([str(MANAGED), "build", str(path), "-o", str(managed_exe), "--target", "windows-x64"], case_dir / "managed-build")
            managed_run = execution.run([str(managed_exe)], case_dir / "managed-run") if managed_build.returncode == 0 else None
            managed_stderr = managed_build.stderr.strip()
            managed_passed = (
                managed_build.returncode == 0 and managed_stderr == "" and managed_run is not None
                and managed_run.returncode == 0 and managed_run.stdout.strip() == expected_stdout
                if expected_error is None
                else managed_build.returncode != 0 and expected_error in managed_stderr
                and managed_stderr.startswith("sollang: semantic error at ") and managed_run is None
            )
            (case_dir / "managed.stderr.txt").write_text(managed_build.stderr, encoding="utf-8")
            native_build = None
            native_run = None
            paired_passed = None
            if native is not None:
                native_exe = case_dir / "native.exe"
                native_build = execution.run([
                    str(native), "build", str(path), "-o", str(native_exe), "--target", "windows-x64",
                    "--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1",
                ], case_dir / "native-build")
                native_run = execution.run([str(native_exe)], case_dir / "native-run") if native_build.returncode == 0 else None
                paired_passed = (
                    native_build.returncode == managed_build.returncode
                    and native_build.stderr.strip() == managed_stderr
                    and (native_run.returncode if native_run else None) == (managed_run.returncode if managed_run else None)
                    and (native_run.stdout.strip() if native_run else None) == (managed_run.stdout.strip() if managed_run else None)
                )
                (case_dir / "native.stderr.txt").write_text(native_build.stderr, encoding="utf-8")
            cases[name] = {
                "passed": managed_passed and (native is None or paired_passed is True),
                "status": "passed" if managed_passed and (native is None or paired_passed is True) else "failed",
                "sourceSha256": sha256(path), "managedPassed": managed_passed,
                "managedBuildExit": managed_build.returncode, "managedBuildStderr": managed_stderr,
                "managedRunExit": managed_run.returncode if managed_run else None,
                "managedRunStdout": managed_run.stdout.strip() if managed_run else None,
                "nativeBuildExit": native_build.returncode if native_build else None,
                "nativeBuildStderr": native_build.stderr.strip() if native_build else None,
                "nativeRunExit": native_run.returncode if native_run else None,
                "nativeRunStdout": native_run.stdout.strip() if native_run else None,
                "pairedPassed": paired_passed,
            }
            print(f"{name}: C# {'PASS' if managed_passed else 'FAIL'}"
                  + (f", paired {'PASS' if paired_passed else 'FAIL'}" if native else ""), flush=True)
            result["completed"] = sum(row["passed"] for row in cases.values())
            execution.save()
        stable = before == {str(path): sha256(path) for path in checked}
        managed_completed = sum(case["managedPassed"] for case in cases.values())
        paired_completed = sum(case["pairedPassed"] is True for case in cases.values()) if native else None
        passed = stable and managed_completed == len(cases) and (native is None or paired_completed == len(cases))
        result.update({
            "schemaVersion": 1, "unit": "C385 numeric call argument range", "mode": args.mode,
            "status": "passed" if passed else "mismatch", "managedCompleted": managed_completed,
            "pairedCompleted": paired_completed, "total": len(cases), "inputsStable": stable,
            "inputSha256": before, "cases": cases,
            "completed": paired_completed if native else managed_completed,
        })
        execution.save()
        if not passed:
            raise ValueError("FOCUSED_NUMERIC_RANGE_MISMATCH")
    except (Exception, KeyboardInterrupt) as failure:
        error = failure
        raise
    finally:
        execution.finalize(error)



if __name__ == "__main__":
    main()
