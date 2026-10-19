#!/usr/bin/env python3
"""Pin C# ordinary-expression S001 behavior and compare the self-host compiler."""

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
COVERAGE = ROOT / "scripts/contracts/c385-s001-ordinary-coverage.json"
CASES = {
    "rightConversion": ("right-conversion", 1, "value=3\n"),
    "leftConversion": ("left-conversion", 1, "value=3\n"),
    "twoConversions": ("two-conversions", 1, "value=true\n"),
    "contextual": ("contextual", 0, "value=true\n"),
    "invalid": ("invalid", 0, None),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--source-comparison", type=Path)
    parser.add_argument("--artifact-cleanup", choices=("execute", "plan-only"), default="execute")
    parser.add_argument("--timeout-seconds", type=float, default=180)
    args = parser.parse_args()
    coverage = json.loads(read(COVERAGE))
    if coverage != {"schemaVersion": 1, "cases": [{"id": name, "exit": 1 if name in ("invalid", "wrong") else 0} for name in CASES]}:
        raise ValueError("S001_COVERAGE_CONTRACT_CHANGED")
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    compiler = MANAGED
    reference = None
    inputs = [*managed_runtime_inputs(MANAGED), ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs", Path(__file__).resolve(), COVERAGE, *sorted((ROOT / "stdlib").rglob("*.slg")),
              ROOT / ".tools/llvm-22.1.8/bin/clang.exe", *lifecycle_inputs(ROOT)]
    if args.mode == "paired":
        if not args.build or not args.managed_proof or not args.source_comparison:
            raise ValueError("paired mode requires build, C# proof, and source comparison")
        build = args.build.resolve()
        proof = args.managed_proof.resolve()
        comparison = args.source_comparison.resolve()
        build_record = json.loads((build / "result.json").read_text(encoding="utf-8"))
        reference = json.loads(proof.read_text(encoding="utf-8"))
        source_record = json.loads(comparison.read_text(encoding="utf-8"))
        if build_record["status"] != "passed" or not build_record["inputsStable"]:
            raise ValueError("self-host build is not stable")
        if reference["status"] != "passed" or not reference["inputStable"] or set(reference["cases"]) != set(CASES):
            raise ValueError("C# proof lacks exact case coverage")
        expected_managed_inputs = [*managed_runtime_inputs(MANAGED), ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
                                   Path(__file__).resolve(), COVERAGE, *sorted((ROOT / "stdlib").rglob("*.slg")),
              ROOT / ".tools/llvm-22.1.8/bin/clang.exe", *lifecycle_inputs(ROOT)]
        expected_managed_inputs.extend(
            ROOT / f"scripts/probes/diagnostics/c385-s001-ordinary-{suffix}.slg"
            for suffix, _, _ in CASES.values())
        if set(reference["inputSha256"]) != {str(path) for path in expected_managed_inputs}:
            raise ValueError("C# proof input set changed")
        for path in expected_managed_inputs:
            if reference["inputSha256"][str(path)] != sha(path):
                raise ValueError(f"C# proof input changed: {path}")
        if source_record["status"] != "compared-before-slg-edit":
            raise ValueError("source comparison is not ready")
        compiler = build / "compiler.exe"
        if sha(compiler) != build_record["compilerSha256"]:
            raise ValueError("self-host binary changed")
        inputs.extend((compiler, build / "result.json", proof, comparison))
        inputs.extend(sorted((ROOT / "selfhost").rglob("*.slg")))
    elif args.build or args.managed_proof or args.source_comparison:
        raise ValueError("managed mode takes no paired inputs")
    inputs.extend(ROOT / f"scripts/probes/diagnostics/c385-s001-ordinary-{suffix}.slg" for suffix, _, _ in CASES.values())
    cases = {}
    result = {"schemaVersion": 1, "unit": "C385 ordinary numeric expression S001 parity",
              "mode": args.mode, "completed": 0, "total": len(CASES),
              "compilerSha256": sha(compiler), "cases": cases}
    with VerificationOutput(ROOT, output, inputs, result,
                            cleanup_mode=args.artifact_cleanup, timeout_seconds=args.timeout_seconds) as supervision:
        for name, (suffix, warning_count, expected_stdout) in CASES.items():
            case_dir = output / name
            case_dir.mkdir()
            cases[name] = {"id": name, "status": "running", "passed": False}
            supervision.save()
            source = ROOT / f"scripts/probes/diagnostics/c385-s001-ordinary-{suffix}.slg"
            exe = case_dir / "probe.exe"
            command = [str(compiler), "build", str(source), "-o", str(exe), "--target", "windows-x64"]
            if args.mode == "paired":
                command.extend(("--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"))
            build_exit = supervision.run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
            stderr = read(case_dir / "build.stderr.txt")
            run_exit = None
            stdout = None
            if build_exit == 0:
                run_exit = supervision.run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
                stdout = read(case_dir / "run.stdout.txt")
            if args.mode == "managed":
                passed = stderr.count("warning S001") == warning_count
                if expected_stdout is None:
                    passed = passed and build_exit != 0 and "sollang: semantic error" in stderr
                else:
                    passed = passed and build_exit == run_exit == 0 and stdout == expected_stdout
            else:
                expected = reference["cases"][name]
                passed = (build_exit == expected["buildExit"] and stderr == expected["buildStderr"]
                          and run_exit == expected["runExit"] and stdout == expected["runStdout"])
            if build_exit == 0:
                passed = passed and not read(case_dir / "run.stderr.txt").strip()
            cases[name] = {"id": name, "status": "passed" if passed else "failed", "passed": passed, "expectedBuildExit": 1 if expected_stdout is None else 0, "source": str(source.relative_to(ROOT)),
                           "buildExit": build_exit, "buildStderr": stderr, "runExit": run_exit, "runStdout": stdout}
            supervision.save()
            print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
            if not passed:
                raise ValueError(f"focused S001 parity failed: {name}")


if __name__ == "__main__":
    main()
