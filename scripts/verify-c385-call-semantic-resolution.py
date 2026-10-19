#!/usr/bin/env python3
"""Compare C# call behavior with pre-IR self-host call resolution shapes."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from verification_fingerprints import managed_runtime_inputs


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
MANAGED_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
PROBE = ROOT / "scripts/probes/diagnostics/c385-indexed-enum-method-result.slg"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True, help="stable self-host build directory")
    parser.add_argument("--output", type=Path, required=True, help="new result directory")
    parser.add_argument("--paired", action="store_true", help="compile and run the same cases with the native compiler")
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    build_record = json.loads((build / "result.json").read_text(encoding="utf-8-sig"))
    native = build / "compiler.exe"
    if build_record["status"] != "passed" or not build_record["inputsStable"]:
        raise ValueError("self-host build did not pass with stable inputs")
    if sha256(native) != build_record["compilerSha256"]:
        raise ValueError("self-host compiler differs from build result")
    checked = [*managed_runtime_inputs(MANAGED), MANAGED_SOURCE, PROBE, Path(__file__), native, build / "result.json"]
    checked.extend(sorted((ROOT / "selfhost").rglob("*.slg")))
    checked.extend(sorted((ROOT / "stdlib").rglob("*.slg")))
    before = {str(path): sha256(path) for path in checked}
    source = PROBE.read_text(encoding="utf-8-sig")
    source = source.replace("\r\n", "\n")
    receiver_anchor = "header.contextModes[0] -> id"
    initializer_anchor = "Header { contextModes: [mode] } => header"
    if source.count(receiver_anchor) != 1 or source.count(initializer_anchor) != 1:
        raise ValueError("source probe anchors changed")
    replacements = {
        "direct": ("mode -> id", 56, True),
        "arrayBinding": ("modes[0] -> id", 53, True),
        "fieldBinding": ("modes[0] -> id", 59, True),
        "indexedField": ("header.contextModes[0] -> id", 56, True),
        "wrongReceiver": ("64 -> id", 56, False),
    }
    output.mkdir(parents=True)
    cases: dict[str, dict[str, object]] = {}
    for name, (receiver, call_ast, should_resolve) in replacements.items():
        case_source = source
        if name == "arrayBinding":
            case_source = case_source.replace(
                "Header { contextModes: [mode] } => header", "[mode] => modes"
            )
        elif name == "fieldBinding":
            case_source = case_source.replace(
                "header.contextModes[0] -> id",
                "header.contextModes => modes\n    modes[0] -> id",
            )
        if name != "fieldBinding":
            case_source = case_source.replace("header.contextModes[0] -> id", receiver)
        case_dir = output / name
        case_dir.mkdir()
        path = case_dir / "probe.slg"
        path.write_text(case_source, encoding="utf-8", newline="\n")
        executable = case_dir / "probe.exe"
        managed_build = run([str(MANAGED), "build", str(path), "-o", str(executable), "--target", "windows-x64"])
        managed_run = run([str(executable)]) if managed_build.returncode == 0 else None
        native_calls = run([str(native), "call-records", str(path)])
        match = re.search(
            rf"^call source 0 ast {call_ast} targetSource (?P<source>-?\d+) symbol (?P<symbol>-?\d+) status (?P<status>\d+)$",
            native_calls.stdout,
            re.MULTILINE,
        )
        warnings = [line for line in managed_build.stderr.splitlines() if line.startswith("warning S001 ")]
        managed_ok = (
            managed_build.returncode == 0
            and managed_run is not None
            and managed_run.returncode == 0
            and managed_run.stdout.strip() == "value=67"
            and len(warnings) == 2
            if should_resolve
            else managed_build.returncode != 0
            and "unknown value-flow target 'id'" in managed_build.stderr
            and managed_run is None
        )
        resolved = bool(match and match.group("source") == "0" and match.group("symbol") == "4" and match.group("status") == "0")
        pre_ir_passed = resolved if should_resolve else bool(match and match.group("symbol") == "-1" and match.group("status") == "2")
        native_build = None
        native_run = None
        paired_passed = None
        if args.paired:
            native_executable = case_dir / "native.exe"
            native_build = run([
                str(native), "build", str(path), "-o", str(native_executable),
                "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                "--stdlib", str(ROOT / "stdlib"), "-O1",
            ])
            native_run = run([str(native_executable)]) if native_build.returncode == 0 else None
            paired_passed = (
                native_build.returncode == managed_build.returncode
                and native_build.stderr.strip() == managed_build.stderr.strip()
                and (native_run.returncode if native_run else None) == (managed_run.returncode if managed_run else None)
                and (native_run.stdout.strip() if native_run else None) == (managed_run.stdout.strip() if managed_run else None)
            )
            (case_dir / "native.stderr.txt").write_text(native_build.stderr, encoding="utf-8")
        cases[name] = {
            "sourceSha256": sha256(path),
            "callAst": call_ast,
            "managedBuildExit": managed_build.returncode,
            "managedRunExit": managed_run.returncode if managed_run else None,
            "managedStdout": managed_run.stdout.strip() if managed_run else None,
            "managedWarningCount": len(warnings),
            "managedPassed": managed_ok,
            "nativeCallExit": native_calls.returncode,
            "nativeCallRecord": match.group(0) if match else None,
            "preIrResolved": resolved,
            "preIrPassed": pre_ir_passed,
            "shouldResolve": should_resolve,
            "nativeBuildExit": native_build.returncode if native_build else None,
            "nativeBuildStderr": native_build.stderr.strip() if native_build else None,
            "nativeRunExit": native_run.returncode if native_run else None,
            "nativeRunStdout": native_run.stdout.strip() if native_run else None,
            "pairedPassed": paired_passed,
        }
        (case_dir / "managed.stderr.txt").write_text(managed_build.stderr, encoding="utf-8")
        (case_dir / "native.calls.txt").write_text(native_calls.stdout, encoding="utf-8")
        print(f"{name}: C# {'PASS' if managed_ok else 'FAIL'}, pre-IR {'PASS' if pre_ir_passed else 'OPEN'}"
              + (f", paired {'PASS' if paired_passed else 'FAIL'}" if args.paired else ""), flush=True)
    stable = before == {str(path): sha256(path) for path in checked}
    completed = sum(case["preIrPassed"] for case in cases.values())
    paired_completed = sum(case["pairedPassed"] is True for case in cases.values()) if args.paired else None
    result = {
        "schemaVersion": 1,
        "unit": "C385 call receiver semantic resolution",
        "status": "passed" if stable and completed == len(cases) and all(case["managedPassed"] for case in cases.values())
                  and (not args.paired or paired_completed == len(cases)) else "structural-or-paired-gap-reproduced",
        "managedCompleted": sum(case["managedPassed"] for case in cases.values()),
        "preIrCompleted": completed,
        "pairedCompleted": paired_completed,
        "total": len(cases),
        "inputsStable": stable,
        "inputSha256": before,
        "cases": cases,
    }
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if not stable or not all(case["managedPassed"] for case in cases.values()):
        raise SystemExit(1)
    if completed != len(cases):
        raise SystemExit(2)
    if args.paired and paired_completed != len(cases):
        raise SystemExit(3)


if __name__ == "__main__":
    main()
