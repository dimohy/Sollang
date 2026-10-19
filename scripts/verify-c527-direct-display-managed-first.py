#!/usr/bin/env python3
"""Pin C# direct interpolation display decisions before changing the SLG compiler."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPILER = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
SELFHOST = ROOT / "selfhost/semantic/interpolation_inference.slg"
CASES = {
    "nominal": ("c527-direct-nominal-display.slg", "string interpolation expects Text, Int, or Bool but received Point", None),
    "invalidField": ("c527-direct-nominal-invalid-field.slg", "field 'x' expects Int, got Bool", None),
    "float": ("c527-direct-float-display.slg", "string interpolation expects Text, Int, or Bool but received Float", None),
    "scalarControl": ("c527-struct-literal-field-positive.slg", None, "value=5\n"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def position(lines: list[str], needle: str) -> int:
    positions = [i + 1 for i, line in enumerate(lines) if needle in line]
    if len(positions) != 1:
        raise ValueError(f"expected one {needle!r}, got {positions}")
    return positions[0]


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"proof output exists: {output}")
    sources = {name: (ROOT / name).read_text(encoding="utf-8-sig").splitlines()
               for name in ("src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
                            "selfhost/semantic/interpolation_inference.slg")}
    managed = sources["src/Sollang.Compiler/Semantics/SemanticCompiler.cs"]
    selfhost = sources["selfhost/semantic/interpolation_inference.slg"]
    source_order = {
        "managedInferFragment": position(managed, "var interpolationType = InferExpression("),
        "managedCheckDisplay": position(managed, "EnsureDisplayable(interpolationType, expression.Line"),
        "managedStructInitializer": position(managed, "private BoundType InferStructLiteralExpression("),
        "selfhostPreIrDisplay": position(selfhost, "public preIrInvalidDirectDisplayTypeByNode prepared:"),
        "selfhostPostIrDisplay": position(selfhost, "public invalidDisplayTypeByNode prepared:"),
    }
    if not (source_order["managedInferFragment"] < source_order["managedCheckDisplay"]
            and source_order["selfhostPreIrDisplay"] < source_order["selfhostPostIrDisplay"]):
        raise ValueError("source order drift")
    pre_ir_body = "\n".join(selfhost[source_order["selfhostPreIrDisplay"]:source_order["selfhostPostIrDisplay"] - 1])
    if "node.kind == 14" in pre_ir_body or "node.kind == 0" in pre_ir_body:
        raise ValueError("the baseline pre-IR direct type gap has already changed")
    inputs = [COMPILER, MANAGED, SELFHOST, Path(__file__).resolve()]
    inputs += [ROOT / "scripts/probes/interpolation" / name for name, _, _ in CASES.values()]
    before = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for key, (name, expected_error, expected_run) in CASES.items():
        case_dir = output / key
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        source = ROOT / "scripts/probes/interpolation" / name
        build_exit = run([str(COMPILER), "build", str(source), "-o", str(exe),
                          "--target", "windows-x64"],
                         case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = (case_dir / "build.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = (case_dir / "run.stdout.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        passed = (expected_error in stderr if expected_error else build_exit == 0 and run_exit == 0 and stdout == expected_run)
        cases[key] = {"status": "passed" if passed else "failed", "source": str(source.relative_to(ROOT)),
                      "buildExit": build_exit, "buildStderr": stderr, "runExit": run_exit,
                      "runStdout": stdout}
        print(f"{key}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = before == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C527 direct interpolation display C# first and source comparison",
              "status": "passed" if completed == len(CASES) and stable else "failed",
              "completed": completed, "total": len(CASES), "inputStable": stable,
              "inputSha256": before, "sourceOrder": source_order,
              "sourceComparison": "C# infers the complete struct initializer before checking display; SLG currently classifies direct nominal and float roots only after Typed IR.",
              "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"C# focused proof failed: {completed}/{len(CASES)}")


if __name__ == "__main__":
    main()
