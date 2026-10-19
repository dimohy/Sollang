#!/usr/bin/env python3
"""Pin C# binary interpolation decisions, then compare one focused SLG build."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
MANAGED_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
SELFHOST_SOURCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
DIAGNOSTIC_SOURCE = ROOT / "selfhost/llvm/emitter/diagnostics.slg"
DIRECT_CASES = {
    "float": ("c527-preir-binary-float.slg", "string interpolation expects Text, Int, or Bool but received Float", None),
    "int": ("c527-preir-binary-int.slg", None, "value=3\n"),
    "compare": ("c527-preir-binary-compare.slg", None, "value=true\n"),
    "logical": ("c527-preir-binary-logical.slg", None, "value=false\n"),
    "invalidArithmetic": ("c527-preir-binary-invalid-arithmetic.slg", "operands of '+' must have the same numeric type", None),
    "invalidLogical": ("c527-preir-binary-invalid-logical.slg", "left operand of 'and' must be Bool", None),
}
NESTED_CASES = {
    "float": ("c527-preir-nested-binary-float.slg", "string interpolation expects Text, Int, or Bool but received Float", None),
    "int": ("c527-preir-nested-binary-int.slg", None, "value=9\n"),
    "compare": ("c527-preir-nested-binary-compare.slg", None, "value=true\n"),
    "logical": ("c527-preir-nested-binary-logical.slg", None, "value=true\n"),
    "invalidInner": ("c527-preir-nested-binary-invalid.slg", "operands of '+' must have the same numeric type", None),
    "invalidRight": ("c527-preir-nested-binary-invalid-right.slg", "operands of '+' must have the same numeric type", None),
    "invalidBoth": ("c527-preir-nested-binary-invalid-both.slg", "operands of '+' must have the same numeric type", None),
}
CASE_SETS = {"direct": DIRECT_CASES, "nested": NESTED_CASES}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def source(name: str) -> Path:
    return ROOT / "scripts/probes/interpolation" / name


def require_exact_cases(proof: dict, selected_cases: dict, role: str) -> None:
    expected = set(selected_cases)
    actual = set(proof.get("cases", {}))
    if actual != expected:
        raise ValueError(f"{role} case set mismatch: missing={sorted(expected - actual)}, extra={sorted(actual - expected)}")


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def pre_ir_body() -> str:
    text = SELFHOST_SOURCE.read_text(encoding="utf-8-sig")
    return text.split("public preIrInvalidDirectDisplayTypeByNode prepared:", 1)[1].split(
        "public invalidDisplayTypeByNode prepared:", 1)[0]


def pre_ir_binary_body() -> str:
    text = SELFHOST_SOURCE.read_text(encoding="utf-8-sig")
    return text.split("preIrDirectBinaryTypeId prepared:", 1)[1].split(
        "public preIrInvalidDirectDisplayTypeByNode prepared:", 1)[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--scope", choices=CASE_SETS, default="direct")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--baseline-proof", type=Path)
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"proof output exists: {output}")
    selected_cases = CASE_SETS[args.scope]
    if args.mode == "managed":
        if args.build or args.managed_proof:
            raise ValueError("managed mode does not accept --build or --managed-proof")
        if args.baseline_proof:
            baseline = json.loads(args.baseline_proof.resolve().read_text(encoding="utf-8"))
            if (baseline["mode"] != "managed" or baseline["status"] != "passed"
                    or baseline.get("scope", "direct") != args.scope
                    or baseline["compilerSha256"] != sha(MANAGED)):
                raise ValueError("pre-edit C# proof is not a matching stable pass")
            require_exact_cases(baseline, selected_cases, "baseline proof")
        managed_source = MANAGED_SOURCE.read_text(encoding="utf-8-sig")
        if not (managed_source.index("private BoundType InferStringExpression(")
                < managed_source.index("var interpolationType = InferExpression(")
                < managed_source.index("EnsureDisplayable(interpolationType, expression.Line")):
            raise ValueError("C# interpolation source order changed")
        if not args.baseline_proof and args.scope == "direct" and "node.kind == 3" in pre_ir_body():
            raise ValueError("SLG direct binary pre-IR decision already exists; source comparison is stale")
        if not args.baseline_proof and args.scope == "nested" and any(name in pre_ir_binary_body() for name in ("binaryTypes", "computedTypes")):
            raise ValueError("SLG nested binary pre-IR decision already exists; source comparison is stale")
        compiler = MANAGED
        inputs = [compiler, MANAGED_SOURCE, SELFHOST_SOURCE, DIAGNOSTIC_SOURCE, Path(__file__).resolve()]
        if args.baseline_proof:
            inputs.append(args.baseline_proof.resolve())
        managed_proof = None
    else:
        if args.baseline_proof:
            raise ValueError("paired mode does not accept --baseline-proof")
        if not args.build or not args.managed_proof:
            raise ValueError("paired mode requires --build and --managed-proof")
        build = args.build.resolve()
        compiler = build / "compiler.exe"
        build_record = json.loads((build / "result.json").read_text(encoding="utf-8"))
        if build_record["status"] != "passed" or not build_record["inputsStable"] or build_record["compilerSha256"] != sha(compiler):
            raise ValueError("focused SLG compiler build is not a stable pass")
        managed_proof = args.managed_proof.resolve()
        managed_record = json.loads(managed_proof.read_text(encoding="utf-8"))
        if managed_record["status"] != "passed" or not managed_record["inputStable"]:
            raise ValueError("C# first proof is not complete")
        if managed_record.get("scope", "direct") != args.scope or managed_record["compilerSha256"] != sha(MANAGED):
            raise ValueError("C# first proof used a different scope or compiler")
        require_exact_cases(managed_record, selected_cases, "managed proof")
        if "node.kind == 3" not in pre_ir_body():
            raise ValueError("SLG binary result is not decided before Typed IR")
        if args.scope == "nested" and not any(name in pre_ir_binary_body() for name in ("binaryTypes", "computedTypes")):
            raise ValueError("SLG nested binary result is not composed before Typed IR")
        inputs = [compiler, build / "result.json", managed_proof, MANAGED, SELFHOST_SOURCE, DIAGNOSTIC_SOURCE, Path(__file__).resolve()]
    inputs += [source(name) for name, _, _ in selected_cases.values()]
    start_hashes = {str(path): sha(path) for path in inputs}
    if args.preflight_only:
        print(f"PASS {args.scope} {args.mode} preflight: exact {len(selected_cases)} cases; no compiler launched")
        return
    output.mkdir(parents=True)
    cases = {}
    for key, (name, expected_error, expected_run) in selected_cases.items():
        case_dir = output / key
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", str(source(name)), "-o", str(exe), "--target", "windows-x64"]
        if args.mode == "paired":
            command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"]
        build_exit = run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = contents(case_dir / "build.stderr.txt")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = contents(case_dir / "run.stdout.txt")
        if args.mode == "managed":
            passed = ((build_exit != 0 and expected_error in stderr) if expected_error
                      else (build_exit == 0 and run_exit == 0 and stdout == expected_run))
        else:
            expected = managed_record["cases"][key]
            passed = ((build_exit != 0) == (expected["buildExit"] != 0)
                      and stderr == expected["buildStderr"]
                      and (build_exit != 0 or (run_exit == 0 and stdout == expected["runStdout"])))
        cases[key] = {"status": "passed" if passed else "failed", "source": str(source(name).relative_to(ROOT)),
                      "buildExit": build_exit, "buildStderr": stderr, "runExit": run_exit, "runStdout": stdout}
        print(f"{key}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = start_hashes == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    if args.scope == "nested":
        source_comparison = ("C# recursively infers and validates each nested binary operand before checking the outer interpolation display; SLG currently composes direct binary types before Typed IR but nested binary results only after Typed IR."
                             if args.mode == "managed" else
                             "SLG composes child binary types before their parent and retains inner operand diagnostics before the outer display check.")
    else:
        source_comparison = ("C# infers and validates both operands, computes binary type, then checks interpolation display. SLG currently computes binary result after Typed IR."
                             if args.mode == "managed" else
                             "SLG uses pre-IR facts for direct binary root display type and retains operand-error precedence.")
    result = {"schemaVersion": 1, "unit": f"C527 {args.scope} binary root pre-IR displayability", "mode": args.mode,
              "scope": args.scope,
              "status": "passed" if completed == len(cases) and stable else "failed",
              "completed": completed, "total": len(cases), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": start_hashes,
              "sourceComparison": source_comparison,
              "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"focused binary proof failed: {completed}/{len(cases)}")


if __name__ == "__main__":
    main()
