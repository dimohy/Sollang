#!/usr/bin/env python3
"""Pin C# numeric call argument warnings and compare the self-host compiler."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from verification_fingerprints import managed_runtime_inputs
from focused_verification_output import VerificationOutput, lifecycle_inputs


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
COVERAGE = ROOT / "scripts/contracts/c385-s001-argument-coverage.json"
SEMANTIC_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
PROBES = ROOT / "scripts/probes/diagnostics"
CASES = {
    "explicit": (PROBES / "c385-indexed-enum-method-result.slg", 0, "value=67", 2),
    "bare": (PROBES / "c385-indexed-enum-method-bare-arguments.slg", 0, "value=67", 0),
    "contextualIf": (PROBES / "c385-indexed-enum-method-contextual-if-argument.slg", 0, "value=67", 0),
    "wrong": (PROBES / "c385-indexed-enum-method-wrong-argument.slg", 1, None, 0),
}
WRONG_ERROR = (
    "sollang: semantic error at 20:34: [module '<main>'] "
    "function 'id' parameter 'previous' expects UInt8 but received UInt16"
)
COMPARISON = ROOT / "artifacts/scratch/c385-call-argument-s001-source-comparison-20260929-01.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def inputs() -> list[Path]:
    return [*managed_runtime_inputs(MANAGED), SEMANTIC_SOURCE, Path(__file__).resolve(), COVERAGE, *[case[0] for case in CASES.values()],
            *sorted((ROOT / "stdlib").rglob("*.slg")), ROOT / ".tools/llvm-22.1.8/bin/clang.exe",
            *lifecycle_inputs(ROOT)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--artifact-cleanup", choices=("execute", "plan-only"), default="execute")
    parser.add_argument("--timeout-seconds", type=float, default=180)
    args = parser.parse_args()
    coverage = json.loads(read(COVERAGE))
    if coverage != {"schemaVersion": 1, "cases": [{"id": name, "exit": 1 if name in ("invalid", "wrong") else 0} for name in CASES]}:
        raise ValueError("S001_COVERAGE_CONTRACT_CHANGED")
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    checked_inputs = inputs()
    compiler = MANAGED
    expected = None
    if args.mode == "paired":
        if not args.build or not args.managed_proof:
            raise ValueError("paired mode requires build and C# proof")
        build = args.build.resolve()
        build_record = json.loads(read(build / "result.json"))
        if build_record["status"] != "passed" or not build_record["inputsStable"]:
            raise ValueError("self-host build is not stable")
        compiler = build / "compiler.exe"
        if digest(compiler) != build_record["compilerSha256"]:
            raise ValueError("self-host compiler hash changed")
        expected = json.loads(read(args.managed_proof.resolve()))
        if expected["status"] != "passed" or expected["inputSha256"] != {
            str(path): digest(path) for path in checked_inputs
        }:
            raise ValueError("C# proof inputs changed")
        comparison = json.loads(read(COMPARISON))
        if comparison["status"] != "compared-before-slg-edit":
            raise ValueError("source comparison missing")
        checked_inputs += [compiler, build / "result.json", args.managed_proof.resolve(), COMPARISON]
        checked_inputs += sorted((ROOT / "selfhost").rglob("*.slg"))
    cases = {}
    result = {"schemaVersion": 1, "unit": "C385 numeric call argument S001 parity",
              "mode": args.mode, "completed": 0, "total": len(CASES),
              "compilerSha256": digest(compiler), "cases": cases}
    with VerificationOutput(ROOT, output, checked_inputs, result,
                            cleanup_mode=args.artifact_cleanup, timeout_seconds=args.timeout_seconds) as supervision:
        for name, (source, expected_exit, expected_stdout, expected_warnings) in CASES.items():
            case_dir = output / name
            case_dir.mkdir()
            cases[name] = {"id": name, "status": "running", "passed": False}
            supervision.save()
            exe = case_dir / "probe.exe"
            command = [str(compiler), "build", str(source), "-o", str(exe), "--target", "windows-x64"]
            if args.mode == "paired":
                command.extend(("--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib",
                                str(ROOT / "stdlib"), "-O1"))
            build_exit = supervision.run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
            stderr = read(case_dir / "build.stderr.txt").strip()
            run_exit = None
            run_stdout = None
            if build_exit == 0:
                run_exit = supervision.run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
                run_stdout = read(case_dir / "run.stdout.txt").strip()
            warnings = [line for line in stderr.splitlines() if line.startswith("warning S001 ")]
            passed = build_exit == expected_exit and len(warnings) == expected_warnings
            if expected_exit == 0:
                passed = passed and run_exit == 0 and run_stdout == expected_stdout
                passed = passed and len(stderr.splitlines()) == expected_warnings
            else:
                passed = passed and stderr == WRONG_ERROR and run_exit is None
            if expected is not None:
                reference = expected["cases"][name]
                passed = passed and stderr == reference["buildStderr"]
                passed = passed and run_exit == reference["runExit"]
                passed = passed and run_stdout == reference["runStdout"]
            if build_exit == 0:
                passed = passed and not read(case_dir / "run.stderr.txt").strip()
            cases[name] = {"id": name, "status": "passed" if passed else "failed", "passed": passed, "expectedBuildExit": expected_exit, "buildExit": build_exit,
                           "buildStderr": stderr, "runExit": run_exit, "runStdout": run_stdout,
                           "warningCount": len(warnings)}
            supervision.save()
            print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
            if not passed:
                raise ValueError(f"focused S001 parity failed: {name}")


if __name__ == "__main__":
    main()
