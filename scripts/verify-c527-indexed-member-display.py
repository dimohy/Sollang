#!/usr/bin/env python3
"""Check dependency-ordered member/index pre-IR facts and paired behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-indexed-member-source-comparison-20260929-01.json"
CASES = {
    "indexedInt": [ROOT / "examples/regression/2055-indexed-struct-interpolation-type.slg"],
    "indexedFloat": [ROOT / "scripts/probes/interpolation/c527-indexed-member-display-negative.slg"],
    "mixedPath": [ROOT / "examples/regression/1826-indexed-member-array-interpolation.slg"],
    "nestedBool": [ROOT / "scripts/probes/interpolation/c527-nested-member-display-positive.slg"],
    "nestedFloat": [ROOT / "scripts/probes/interpolation/c527-nested-member-display-negative.slg"],
    "private": [ROOT / "scripts/probes/interpolation/c527-nested-private-intermediate.slg",
                ROOT / "scripts/probes/interpolation/sample/nested_private.slg"],
}
NEGATIVE = {
    "indexedFloat": "sollang: semantic error at 7:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "nestedFloat": "sollang: semantic error at 12:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "private": "sollang: semantic error at 1:1: [module '<main>'] cannot read private field 'hidden' of struct 'sample.nested_private.Wrapper' outside module 'sample.nested_private'; use its public factory or public instance methods\n",
}
POSITIVE = {"indexedInt": "value=5\n", "mixedPath": "value=30\n", "nestedBool": "value=true\n"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(result.stdout)
    (output / f"{label}.stderr.txt").write_bytes(result.stderr)
    return {
        "exitCode": result.returncode,
        "stdout": result.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
        "stderr": result.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "probe", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    probe = args.probe.resolve(strict=True)
    build_result = json.loads(args.build_result.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    if build_result["status"] != "passed" or not build_result["inputsStable"]:
        raise ValueError("selfhost compiler build did not pass with stable inputs")
    if build_result["compilerSha256"] != sha(selfhost):
        raise ValueError("selfhost compiler hash differs from its build record")
    managed_source = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
    if comparison["status"] != "passed" or comparison["inputSha256"][str(managed_source)] != sha(managed_source):
        raise ValueError("C# source comparison is invalid or stale")
    facts_source = (ROOT / "selfhost/semantic/expression_type_ids.slg").read_text(encoding="utf-8")
    dependency_order = [
        "memberNodeIndex! - 1 => memberNodeIndex!",
        "prepared.interpolations[memberNodeIndex!] => member",
        "interpolationIndexedTypeByNode![member.operand0] => ownerTypeId!",
        "prepared.interpolations[memberNodeIndex!] => indexed",
        "preIrInterpolationIndexOwnerTypeId(references!",
    ]
    positions = [facts_source.find(part) for part in dependency_order]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        raise ValueError("SLG member/index AST dependency order changed")
    inputs = [managed, selfhost, probe, args.build_result.resolve(), COMPARISON,
              ROOT / "selfhost/semantic/expression_type_ids.slg",
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "artifacts/scratch/c527-indexed-member-preir-probe-20260929-01.slg",
              Path(__file__).resolve()]
    for sources in CASES.values():
        inputs.extend(sources)
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {"preIrProbe": run([str(probe)], output, "preir-probe")}
    for compiler_name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[compiler_name] = {}
        for case, sources in CASES.items():
            executable = output / f"{compiler_name}-{case}.exe"
            command = [str(compiler), "build", *(str(path) for path in sources),
                       "-o", str(executable), "--target", "windows-x64"]
            if compiler_name == "selfhost":
                command.extend(["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                                "--stdlib", str(ROOT / "stdlib"), "-O1"])
            runs[compiler_name][case] = run(command, output, f"{compiler_name}-{case}-build")
            runs[compiler_name][case]["executableExists"] = executable.is_file()
            if case in POSITIVE and executable.is_file():
                runs[compiler_name][f"{case}Native"] = run(
                    [str(executable)], output, f"{compiler_name}-{case}-native")
    stable = start == {str(path): sha(path) for path in inputs}
    probe_output = (
        "node=0 kind=5 parent=-1 indexed=-1 member=20 invalid=20\n"
        "node=1 kind=7 parent=0 indexed=26 member=-1 invalid=-1\n"
    )
    passed = stable and runs["preIrProbe"] == {"exitCode": 0, "stdout": probe_output, "stderr": ""}
    for compiler_name in ("managed", "selfhost"):
        cases = runs[compiler_name]
        for case, expected in POSITIVE.items():
            build = cases[case]
            passed = passed and (build["exitCode"] == 0 and build["stderr"] == ""
                                 and build["executableExists"] and "Wrote " in build["stdout"]
                                 and cases.get(f"{case}Native") == {"exitCode": 0, "stdout": expected, "stderr": ""})
        for case, expected in NEGATIVE.items():
            passed = passed and cases[case] == {
                "exitCode": 1, "stdout": "", "stderr": expected, "executableExists": False}
    record = {
        "schemaVersion": 1,
        "unit": "C527 dependency-ordered member and index pre-IR types",
        "status": "passed" if passed else "failed",
        "completed": int(passed),
        "total": 1,
        "inputStable": stable,
        "inputSha256": start,
        "sourceComparison": str(COMPARISON),
        "selfhostBuildResult": str(args.build_result.resolve()),
        "runs": runs,
        "structuralPhasesClosed": "0/7",
        "fullPreIrExpressionClosure": False,
    }
    (output / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"focused verification failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: pre-IR fact and six paired cases")


if __name__ == "__main__":
    main()
