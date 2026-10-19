#!/usr/bin/env python3
"""Pair a contextual numeric literal with a Float32 lexical binary operand."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/probes/interpolation/c527-preir-binary-lexical-float.slg"
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
COMPARISON = ROOT / "artifacts/scratch/c527-preir-binary-source-comparison-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    compiler = build / "compiler.exe"
    built = json.loads((build / "result.json").read_text(encoding="utf-8"))
    compared = json.loads(COMPARISON.read_text(encoding="utf-8"))
    if built["status"] != "passed" or not built["inputsStable"] or built["compilerSha256"] != sha(compiler):
        raise ValueError("current SLG compiler build is not a stable pass")
    if compared["status"] != "passed" or compared["managed"]["sha256"] != sha(ROOT / compared["managed"]["path"]):
        raise ValueError("C# source comparison is not applicable")
    inputs = [SOURCE, MANAGED, compiler, build / "result.json", COMPARISON, Path(__file__).resolve()]
    before = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    results = {}
    for label, executable in (("managed", MANAGED), ("selfhost", compiler)):
        case_dir = output / label
        case_dir.mkdir()
        command = [str(executable), "build", str(SOURCE), "-o", str(case_dir / "probe.exe"),
                   "--target", "windows-x64"]
        if label == "selfhost":
            command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"]
        exit_code = run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        results[label] = {"buildExit": exit_code, "buildStderr": contents(case_dir / "build.stderr.txt")}
        print(f"{label}: exit {exit_code}", flush=True)
    expected = "sollang: semantic error at 3:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"
    passed = (results["managed"]["buildExit"] != 0 and results["selfhost"]["buildExit"] != 0
              and results["managed"]["buildStderr"] == results["selfhost"]["buildStderr"] == expected)
    stable = before == {str(path): sha(path) for path in inputs}
    result = {"schemaVersion": 1, "unit": "C527 contextual Float32 binary literal control",
              "status": "passed" if passed and stable else "failed", "completed": int(passed and stable), "total": 1,
              "inputStable": stable, "inputSha256": before, "results": results}
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError("C# and SLG contextual Float32 binary decisions diverged")


if __name__ == "__main__":
    main()
