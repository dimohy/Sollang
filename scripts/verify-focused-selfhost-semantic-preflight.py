"""Check the production managed frontend without LLVM generation.

Temporary single-path adapter; remove it and its reflection harness when the
canonical managed semantic-only check command is available and verified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
from xml.sax.saxutils import escape

from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from verification_execution import VerificationExecution
from verification_json_records import write_json_atomic
from completed_artifact_plan import initialize_output, cleanup_output

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "scripts/contracts/fixtures"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def finalize_result(record, inputs_stable, error=None):
    terminal = "canceled" if isinstance(error, KeyboardInterrupt) else "failed"
    record["inputsStable"] = inputs_stable
    if error is not None:
        record["status"] = terminal
        failure_id = "SEMANTIC_PREFLIGHT_CANCELED" if isinstance(error, KeyboardInterrupt) else (
            "SEMANTIC_PREFLIGHT_TIMEOUT" if isinstance(error, subprocess.TimeoutExpired)
            else str(error) or type(error).__name__)
        record["failureIds"].append(failure_id)
    if not inputs_stable:
        record["status"] = "failed"
        record["failureIds"].append("SEMANTIC_PREFLIGHT_INPUT_DRIFT")
    for step in record.get("steps", []):
        if step["status"] == "running":
            step["status"] = "timed-out" if isinstance(error, subprocess.TimeoutExpired) else terminal
    record["processesStopped"] = not record.get("activeProcess") and all(
        "pid" not in step or isinstance(step.get("exit"), int) for step in record.get("steps", []))
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, default=ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe")
    parser.add_argument("--manifest", type=Path, default=ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    parser.add_argument("--controls-only", action="store_true")
    parser.add_argument("--artifact-cleanup", choices=("execute", "plan-only"), default="execute")
    parser.add_argument("--expected-managed-dll-sha256")
    parser.add_argument("--timeout-seconds", type=int, default=600)
    args = parser.parse_args()
    if args.timeout_seconds <= 0:
        parser.error("timeout must be positive")
    managed = args.compiler.resolve()
    runtime = managed_runtime_inputs(managed)
    dll = managed.with_suffix(".dll")
    if args.expected_managed_dll_sha256 and sha(dll) != args.expected_managed_dll_sha256.upper():
        raise ValueError("SEMANTIC_PREFLIGHT_MANAGED_DLL_DRIFT")
    manifest = args.manifest.resolve()
    manifest_text = manifest.read_text(encoding="utf-8-sig")
    sources = [ROOT / line.strip() for line in manifest_text.splitlines() if line.strip()]
    if not sources or len(set(sources)) != len(sources):
        raise ValueError("SEMANTIC_PREFLIGHT_MANIFEST_INVALID")
    harness = FIXTURES / "focused-selfhost-semantic-preflight-harness.cs"
    controls = [("positive", 0, None), ("deferred-text", 1, "deferred interpolation"),
                ("rebound-owner", 1, "owned container binding")]
    producer_paths = [ROOT / "src/Sollang.Compiler/Cli/CompilerApp.cs",
                      ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"]
    forbidden = ("LlvmIrGenerator", "WriteAndLink", 'GetMethod("Build"', "CompileStandalone")
    harness_text = harness.read_text(encoding="utf-8-sig")
    if any(token in harness_text for token in forbidden):
        raise ValueError("SEMANTIC_PREFLIGHT_CODEGEN_PATH_FORBIDDEN")
    lifecycle_inputs = [ROOT / "scripts/completed_artifact_plan.py", ROOT / "scripts/ArtifactLifecycle.ps1",
                        ROOT / "scripts/Invoke-CompletedArtifactCleanup.ps1", ROOT / "scripts/contracts/artifact-lifecycle.json"]
    inputs = [*runtime, Path(__file__), manifest, harness, *producer_paths, *lifecycle_inputs,
              *[FIXTURES / f"semantic-preflight-{name}.slg" for name, _, _ in controls],
              *(sources if not args.controls_only else []), *sorted((ROOT / "stdlib").rglob("*.slg"))]
    dotnet = shutil.which("dotnet")
    if not dotnet:
        raise FileNotFoundError("SEMANTIC_PREFLIGHT_DOTNET_MISSING")
    inputs.append(Path(dotnet))
    inputs.extend(ROOT / "scripts" / name for name in (
        "verification_contract_lease.py", "verification_execution.py",
        "verification_fingerprints.py", "verification_json_records.py"))
    inputs = list(dict.fromkeys(path.resolve() for path in inputs))
    with VerificationContractLease(inputs):
        # Discovery must still describe the closure now held by the lease.
        if manifest.read_text(encoding="utf-8-sig") != manifest_text or harness.read_text(encoding="utf-8-sig") != harness_text:
            raise ValueError("SEMANTIC_PREFLIGHT_DISCOVERY_INPUT_DRIFT")
        if args.expected_managed_dll_sha256 and sha(dll) != args.expected_managed_dll_sha256.upper():
            raise ValueError("SEMANTIC_PREFLIGHT_MANAGED_DLL_DRIFT")
        hashes = {str(path): sha(path) for path in inputs}
        output = args.output.resolve()
        initialize_output(ROOT, output)
        output.mkdir(parents=True, exist_ok=False)
        record = {"schemaVersion": 1, "status": "running", "scope": "controls-only" if args.controls_only else "focused-selfhost",
                  "inputHashes": hashes, "managedDllSha256": sha(dll), "tool": dotnet,
                  "codegenInvoked": False, "cases": [], "steps": [], "failureIds": [],
                  "productionSourcePaths": [str(path) for path in producer_paths],
                  "productionApiPath": "CompilerApp.LoadProgram -> SemanticCompiler.Compile(null)",
                  "codegenPathGuard": "passed", "artifactCleanupMode": args.artifact_cleanup}
        def save():
            write_json_atomic(output / "result.json", record)
        def stable():
            return hashes == {str(path): sha(path) if path.is_file() else "MISSING" for path in inputs}
        execution = VerificationExecution(ROOT, output, record, stable, sha)
        def run(command, name):
            if not stable():
                raise ValueError("SEMANTIC_PREFLIGHT_INPUT_DRIFT")
            started = time.monotonic()
            step = {"id": name, "status": "running", "command": command}
            record["steps"].append(step)
            try:
                process = execution.run(command, output / name, timeout=args.timeout_seconds)
                code = process.returncode
            finally:
                # Preserve the existing log paths for downstream consumers.
                for channel in ("stdout", "stderr"):
                    captured = output / (name + "." + channel)
                    if captured.is_file():
                        shutil.copyfile(captured, output / (name + "." + channel + ".txt"))
                if record["processes"]:
                    owned = record["processes"][-1]
                    step["pid"] = owned["pid"]
                    if isinstance(owned.get("exit"), int):
                        step["exit"] = owned["exit"]
            step.update(status="exited", exit=code, elapsedSeconds=time.monotonic() - started)
            return code, time.monotonic() - started
        save()
        terminal_error = None
        try:
            code, _ = run([dotnet, "--version"], "tool-probe")
            if code != 0:
                raise ValueError("SEMANTIC_PREFLIGHT_TOOL_PROBE_FAILED")
            record["toolVersion"] = (output / "tool-probe.stdout.txt").read_text().strip()
            if not args.controls_only:
                code, _ = run([dotnet, str(dll), "format", "--check", *map(str, sources)], "compiler-source-format")
                record["formatPreflight"] = {"status": "passed" if code == 0 else "failed",
                                            "sourceCount": len(sources), "exit": code,
                                            "codegenInvoked": False}
                if code != 0:
                    invalid_sources = []
                    for index, source in enumerate(sources):
                        source_exit, _ = run([dotnet, str(dll), "format", "--check", str(source)],
                                             f"compiler-source-format-detail-{index}")
                        if source_exit != 0:
                            invalid_sources.append(str(source))
                    record["formatPreflight"]["invalidSources"] = invalid_sources
                    raise ValueError("SEMANTIC_PREFLIGHT_COMPILER_SOURCE_FORMAT_FAILED")
            project = output / "SemanticPreflight.csproj"
            project.write_text('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup><ItemGroup><Compile Include="' + escape(str(harness), {'"': '&quot;'}) + '" /></ItemGroup></Project>', encoding="utf-8")
            code, _ = run([dotnet, "build", str(project), "-c", "Release", "--nologo",
                           "--disable-build-servers", "-nodeReuse:false",
                           "-p:UseSharedCompilation=false"], "harness-build")
            if code != 0:
                raise ValueError("SEMANTIC_PREFLIGHT_HARNESS_BUILD_FAILED")
            adapter = output / "bin/Release/net11.0/SemanticPreflight.dll"
            record["harnessSha256"] = sha(adapter)
            for name, expected, fragment in controls:
                code, elapsed = run([dotnet, str(adapter), str(dll), str(FIXTURES / f"semantic-preflight-{name}.slg")], name)
                stderr = (output / (name + ".stderr.txt")).read_text(encoding="utf-8-sig")
                payload = json.loads((output / (name + ".stdout.txt")).read_text(encoding="utf-8-sig"))
                passed = code == expected and payload["codegenInvoked"] is False and (fragment in stderr if fragment else not stderr and not payload["warnings"])
                record["cases"].append({"id": name, "exit": code, "elapsedSeconds": elapsed, "passed": passed})
                save()
                if not passed:
                    raise ValueError("SEMANTIC_PREFLIGHT_CONTROL_FAILED:" + name)
            if not args.controls_only:
                code, elapsed = run([dotnet, str(adapter), str(dll), *map(str, sources)], "focused-selfhost")
                payload = json.loads((output / "focused-selfhost.stdout.txt").read_text(encoding="utf-8-sig"))
                stderr = (output / "focused-selfhost.stderr.txt").read_text(encoding="utf-8-sig")
                passed = code == 0 and not stderr and payload["codegenInvoked"] is False and not payload["warnings"]
                record["cases"].append({"id": "focused-selfhost", "exit": code, "elapsedSeconds": elapsed, "passed": passed, "sourceCount": len(sources)})
                if not passed:
                    raise ValueError("SEMANTIC_PREFLIGHT_FOCUSED_FAILED")
            record["status"] = "passed"
        except (Exception, KeyboardInterrupt) as error:
            terminal_error = error
        finally:
            finalize_result(record, stable(), terminal_error)
            execution.finalize(terminal_error, cleanup=False)
            record["completed"] = sum(case["passed"] for case in record["cases"])
            record["total"] = 3 if args.controls_only else 4
            record["generatedOutputHashes"] = {str(path): sha(path) for path in output.rglob("*")
                if path.is_file() and (path.suffix.lower() in (".exe", ".dll", ".ll", ".bc", ".obj", ".o", ".pdb")
                                      or ".sollang-cache" in path.parts)}
            save()
    if record["status"] == "passed" and record["inputsStable"] and record["processesStopped"]:
        cleanup_output(ROOT, output, execute=args.artifact_cleanup == "execute")
    print(json.dumps({key: record[key] for key in ("status", "completed", "total", "inputsStable", "failureIds")}))
    return 0 if record["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
