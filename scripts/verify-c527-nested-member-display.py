#!/usr/bin/env python3
"""Verify nested pre-IR field type decisions against focused managed behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_COMPARISON = ROOT / "artifacts/scratch/c527-nested-member-source-comparison-20260929-01.json"
PROBE_SOURCE = ROOT / "artifacts/scratch/c527-nested-member-preir-probe-20260929-01.slg"
CASES = {
    "positive": [ROOT / "scripts/probes/interpolation/c527-nested-member-display-positive.slg"],
    "negative": [ROOT / "scripts/probes/interpolation/c527-nested-member-display-negative.slg"],
    "private": [ROOT / "scripts/probes/interpolation/c527-nested-private-intermediate.slg",
                ROOT / "scripts/probes/interpolation/sample/nested_private.slg"],
    "directNegative": [ROOT / "scripts/probes/interpolation/c527-direct-member-display-negative.slg"],
}
EXPECTED_FLOAT = (
    "sollang: semantic error at 12:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)
EXPECTED_DIRECT_FLOAT = (
    "sollang: semantic error at 8:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)
EXPECTED_PRIVATE = (
    "sollang: semantic error at 1:1: [module '<main>'] cannot read private field 'hidden' "
    "of struct 'sample.nested_private.Wrapper' outside module 'sample.nested_private'; "
    "use its public factory or public instance methods\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(completed.stdout)
    (output / f"{label}.stderr.txt").write_bytes(completed.stderr)
    return {
        "exitCode": completed.returncode,
        "stdout": completed.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
        "stderr": completed.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    for option in ("managed", "selfhost", "build-result", "probe", "output"):
        parser.add_argument(f"--{option}", type=Path, required=True)
    parser.add_argument("--reuse-runs", type=Path)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    probe = args.probe.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    build_result = json.loads(args.build_result.read_text(encoding="utf-8"))
    source_comparison = json.loads(SOURCE_COMPARISON.read_text(encoding="utf-8"))
    if build_result["status"] != "passed" or not build_result["inputsStable"]:
        raise ValueError("selfhost build did not pass with stable inputs")
    if build_result["compilerSha256"] != sha(selfhost):
        raise ValueError("selfhost compiler differs from build result")
    if source_comparison["status"] != "passed" or source_comparison["implementationComplete"]:
        raise ValueError("pre-implementation source comparison is invalid")
    managed_source = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
    if source_comparison["inputSha256"][str(managed_source)] != sha(managed_source):
        raise ValueError("C# source drifted since source comparison")

    inputs = [managed, selfhost, probe, PROBE_SOURCE, SOURCE_COMPARISON,
              args.build_result.resolve(), Path(__file__).resolve()]
    for sources in CASES.values():
        inputs.extend(sources)
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    if args.reuse_runs:
        previous_path = args.reuse_runs.resolve(strict=True)
        previous = json.loads(previous_path.read_text(encoding="utf-8"))
        old_inputs = previous["inputSha256"]
        for path, digest in start.items():
            if path != str(Path(__file__).resolve()) and old_inputs.get(path) != digest:
                raise ValueError(f"captured run input drifted: {path}")
        previous_output = previous_path.parent
        runs = previous["runs"]
        for label, result in (("preir-probe", runs["preIrProbe"]),):
            for stream in ("stdout", "stderr"):
                recorded = (previous_output / f"{label}.{stream}.txt").read_text(encoding="utf-8").replace("\r\n", "\n")
                if recorded != result[stream]:
                    raise ValueError(f"captured {label} {stream} drifted")
        for compiler_name in ("managed", "selfhost"):
            for case in CASES:
                result = runs[compiler_name][case]
                label = f"{compiler_name}-{case}-build"
                for stream in ("stdout", "stderr"):
                    recorded = (previous_output / f"{label}.{stream}.txt").read_text(encoding="utf-8").replace("\r\n", "\n")
                    if recorded != result[stream]:
                        raise ValueError(f"captured {label} {stream} drifted")
                if (previous_output / f"{compiler_name}-{case}.exe").is_file() != result["executableExists"]:
                    raise ValueError(f"captured {label} executable drifted")
            native = runs[compiler_name]["positiveNative"]
            for stream in ("stdout", "stderr"):
                label = f"{compiler_name}-positive-native"
                recorded = (previous_output / f"{label}.{stream}.txt").read_text(encoding="utf-8").replace("\r\n", "\n")
                if recorded != native[stream]:
                    raise ValueError(f"captured {label} {stream} drifted")
    else:
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
                if case == "positive" and executable.is_file():
                    runs[compiler_name]["positiveNative"] = run(
                        [str(executable)], output, f"{compiler_name}-positive-native")

    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and runs["preIrProbe"] == {
        "exitCode": 0,
        "stdout": "node=0 parent=-1 member=20 invalid=20\nnode=1 parent=0 member=26 invalid=-1\n",
        "stderr": "",
    }
    for compiler_name in ("managed", "selfhost"):
        result = runs[compiler_name]
        passed = passed and (
            result["positive"]["exitCode"] == 0
            and result["positive"]["stdout"].endswith(f"{compiler_name}-positive.exe" + ("\n" if compiler_name == "selfhost" else " (3,072 bytes)\n"))
            and result["positive"]["stderr"] == ""
            and result["positive"]["executableExists"]
            and result.get("positiveNative") == {"exitCode": 0, "stdout": "value=true\n", "stderr": ""}
            and result["negative"] == {"exitCode": 1, "stdout": "", "stderr": EXPECTED_FLOAT, "executableExists": False}
            and result["private"] == {"exitCode": 1, "stdout": "", "stderr": EXPECTED_PRIVATE, "executableExists": False}
            and result["directNegative"] == {"exitCode": 1, "stdout": "", "stderr": EXPECTED_DIRECT_FLOAT, "executableExists": False}
        )
    record = {
        "schemaVersion": 1,
        "unit": "C527 nested member pre-IR type and displayability",
        "status": "passed" if passed else "failed",
        "completed": int(passed),
        "total": 1,
        "inputStable": stable,
        "inputSha256": start,
        "sourceComparison": str(SOURCE_COMPARISON),
        "selfhostBuildResult": str(args.build_result.resolve()),
        "reusedRuns": str(args.reuse_runs.resolve()) if args.reuse_runs else None,
        "runs": runs,
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": "0/7",
    }
    (output / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"focused verification failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: pre-IR type, paired nested cases, direct control")


if __name__ == "__main__":
    main()
