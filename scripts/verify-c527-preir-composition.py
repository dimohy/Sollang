#!/usr/bin/env python3
"""Prove C# nested numeric conversion and binary behavior, then pair SLG."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
MANAGED_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
SLG_SOURCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
BINARY_CASES = {
    "floatBinary": ("float-binary", "string interpolation expects Text, Int, or Bool but received Float", None),
    "floatConversion": ("float-conversion", "string interpolation expects Text, Int, or Bool but received Float", None),
    "intBinary": ("int-binary", None, "value=6\n"),
    "nestedWidth": ("nested-width", None, "value=4\n"),
    "invalidConversionBinary": ("invalid-conversion-binary", "numeric conversion 'Float' expects a numeric value, got Bool", None),
    "invalidInnerBinary": ("invalid-inner-binary", "operands of '+' must have the same numeric type", None),
    "invalidNestedConversion": ("invalid-nested-conversion", "numeric conversion 'Float' expects a numeric value, got Bool", None),
}
UNARY_CASES = {
    "floatConversion": ("float-conversion", "string interpolation expects Text, Int, or Bool but received Float", None),
    "floatBinary": ("float-binary", "string interpolation expects Text, Int, or Bool but received Float", None),
    "intConversion": ("int-conversion", None, "value=-3\n"),
    "notCompare": ("not-compare", None, "value=false\n"),
    "notFloatCompare": ("not-float-compare", None, "value=false\n"),
    "invalidNotFloat": ("invalid-not-float", "'not' expects Bool", None),
    "invalidNegateCompare": ("invalid-negate-compare", "operand of unary '-' must be a signed numeric value", None),
    "invalidChildConversion": ("invalid-child-conversion", "numeric conversion 'Float' expects a numeric value, got Bool", None),
}
CASE_SETS = {"binary-conversion": BINARY_CASES, "unary-composed": UNARY_CASES}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def execute(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--scope", choices=CASE_SETS, default="binary-conversion")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--source-comparison", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    cases_to_run = CASE_SETS[args.scope]
    probe_prefix = "c527-preir-composed" if args.scope == "binary-conversion" else "c527-preir-unary-composed"
    if args.mode == "managed":
        if args.build or args.managed_proof or args.source_comparison:
            raise ValueError("managed mode accepts no paired inputs")
        compiler = MANAGED
        managed_proof = None
        inputs = [compiler, MANAGED_SOURCE, SLG_SOURCE, Path(__file__).resolve()]
    else:
        if not args.build or not args.managed_proof or not args.source_comparison:
            raise ValueError("paired mode requires build, managed proof, and source comparison")
        build = args.build.resolve()
        compiler = build / "compiler.exe"
        build_record = json.loads((build / "result.json").read_text(encoding="utf-8-sig"))
        managed_proof = json.loads(args.managed_proof.resolve().read_text(encoding="utf-8-sig"))
        comparison = json.loads(args.source_comparison.resolve().read_text(encoding="utf-8-sig"))
        if (build_record["status"] != "passed" or not build_record["inputsStable"]
                or build_record["compilerSha256"] != sha(compiler)):
            raise ValueError("focused self-host build is not a stable pass")
        if (managed_proof["status"] != "passed" or not managed_proof["inputStable"]
                or managed_proof.get("scope", "binary-conversion") != args.scope
                or managed_proof["compilerSha256"] != sha(MANAGED)
                or managed_proof["managedSourceSha256"] != sha(MANAGED_SOURCE)):
            raise ValueError("C# first proof is not current")
        if comparison["status"] != "compared-before-slg-edit":
            raise ValueError("pre-edit source comparison is missing")
        inputs = [compiler, build / "result.json", MANAGED, MANAGED_SOURCE, SLG_SOURCE,
                  args.managed_proof.resolve(), args.source_comparison.resolve(), Path(__file__).resolve()]
    inputs.extend(ROOT / f"scripts/probes/interpolation/{probe_prefix}-{suffix}.slg" for suffix, _, _ in cases_to_run.values())
    start_hashes = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for name, (suffix, expected_error, expected_stdout) in cases_to_run.items():
        case_dir = output / name
        case_dir.mkdir()
        source = ROOT / f"scripts/probes/interpolation/{probe_prefix}-{suffix}.slg"
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", str(source), "-o", str(exe), "--target", "windows-x64"]
        if args.mode == "paired":
            command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"]
        code = execute(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = normalized(case_dir / "build.stderr.txt")
        run_code = None
        stdout = None
        if code == 0:
            run_code = execute([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = normalized(case_dir / "run.stdout.txt")
        if args.mode == "managed":
            passed = ((code != 0 and expected_error in stderr) if expected_error
                      else (code == 0 and run_code == 0 and stdout == expected_stdout))
        else:
            reference = managed_proof["cases"][name]
            passed = ((code != 0) == (reference["buildExit"] != 0)
                      and stderr == reference["buildStderr"]
                      and (code != 0 or (run_code == 0 and stdout == reference["runStdout"])))
        cases[name] = {"status": "passed" if passed else "failed", "source": str(source.relative_to(ROOT)),
                       "buildExit": code, "buildStderr": stderr, "runExit": run_code, "runStdout": stdout}
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = start_hashes == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": ("C527 nested numeric conversion and binary pre-IR composition"
                                              if args.scope == "binary-conversion" else
                                              "C527 unary composition pre-IR type"),
              "mode": args.mode, "scope": args.scope,
              "status": "passed" if stable and completed == len(cases) else "failed",
              "completed": completed, "total": len(cases), "inputStable": stable,
              "compilerSha256": sha(compiler), "managedSourceSha256": sha(MANAGED_SOURCE),
              "inputSha256": start_hashes, "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"composition proof failed: {completed}/{len(cases)}")


if __name__ == "__main__":
    main()
