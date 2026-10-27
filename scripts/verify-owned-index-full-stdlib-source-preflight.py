"""Execute current SLG owned-index decisions over the entire pinned stdlib."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from completed_artifact_plan import initialize_output, cleanup_output, assert_output_shutdown
from verification_fingerprints import managed_runtime_inputs
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_step_diagnostics import SlowStepDiagnostics
from verification_stdlib_source_preflight import compiler_manifest_inputs

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return path.read_text(encoding="utf-8-sig")


def parse_observation(stdout):
    lines = stdout.strip().splitlines()
    if not lines:
        raise ValueError("STDLIB_PREFLIGHT_OBSERVATION_MISSING")
    metadata = json.loads(lines[-1])
    diagnostics = lines[:-1]
    if diagnostics and (metadata.get("checkedSemanticDiagnosticCount", 0) <= 0
                        or not all(line.startswith(("; sollang ", "sollang: semantic error at ")) for line in diagnostics)):
        raise ValueError("STDLIB_PREFLIGHT_UNEXPECTED_DIAGNOSTIC_OUTPUT")
    return metadata, diagnostics


def load_diagnostics_plan(path):
    if path is None:
        return None
    configuration = json.loads(read(path))
    if SlowStepDiagnostics(configuration).hard_timeout_seconds != 600:
        raise ValueError("STDLIB_PREFLIGHT_DIAGNOSTIC_HARD_TIMEOUT_MISMATCH")
    return configuration


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--llvm", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=1,
                        help="Explicit compiler worker limit for the verification harness")
    parser.add_argument("--optimization", choices=("O0", "O1", "O2", "O3"), default="O1")
    parser.add_argument("--timeout-seconds", type=int, default=600,
                        help="Explicit per-step budget; existing callers retain 600 seconds")
    parser.add_argument("--diagnostics-plan", type=Path)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append")
    parser.add_argument("--contract", type=Path, default=ROOT / "scripts/contracts/owned-index-full-stdlib-source-preflight.json")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs expects a positive integer")
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds expects a positive integer")
    diagnostics_plan = None if args.diagnostics_plan is None else args.diagnostics_plan.resolve()
    diagnostics_configuration = load_diagnostics_plan(diagnostics_plan)
    if diagnostics_configuration is not None and args.timeout_seconds != 600:
        raise ValueError("STDLIB_PREFLIGHT_DIAGNOSTIC_SELECTED_BUDGET_MISMATCH")
    compiler, output, contract_path = args.compiler.resolve(), args.output.resolve(), args.contract.resolve()
    contract_text = read(contract_path)
    contract = json.loads(contract_text)
    if contract.get("schemaVersion") != 1 or contract.get("scope") != "owned-index-full-stdlib-source":
        raise ValueError("STDLIB_PREFLIGHT_INVALID_CONTRACT")
    template, manifest = ROOT / contract["template"], ROOT / contract["compilerManifest"]
    _, compiler_sources, manifest_inputs = compiler_manifest_inputs(ROOT, manifest)
    manifest_text = read(manifest)
    stdlib = sorted((ROOT / "stdlib").rglob("*.slg"))
    tool_inputs = [args.llvm.resolve() / "bin" / name for name in ("clang.exe", "llvm-as.exe", "llvm-link.exe", "opt.exe", "llc.exe")]
    lifecycle_inputs = [ROOT / "scripts" / name for name in ("completed_artifact_plan.py", "ArtifactLifecycle.ps1", "Invoke-CompletedArtifactCleanup.ps1", "verification_fingerprints.py", "contracts/artifact-lifecycle.json")]
    if not compiler.is_file() or not (args.llvm / "bin/clang.exe").is_file() or not stdlib:
        raise ValueError("STDLIB_PREFLIGHT_TOOL_OR_SOURCE_MISSING")
    if not all(path.is_file() for path in [template, *tool_inputs, *lifecycle_inputs]):
        raise ValueError("STDLIB_PREFLIGHT_DEPENDENCY_MISSING")
    runtime_inputs = managed_runtime_inputs(compiler)
    template_text = read(template)
    if template_text.count("    # ACTIVE_PROBE_PATH") != 1 or template_text.count("    # STDLIB_SOURCE_PATHS") != 1:
        raise ValueError("STDLIB_PREFLIGHT_TEMPLATE_INVALID")
    if len(compiler_sources) != len(set(compiler_sources)) or not all(path.is_file() for path in compiler_sources):
        raise ValueError("STDLIB_PREFLIGHT_MANIFEST_INVALID")
    if output.exists():
        raise ValueError("STDLIB_PREFLIGHT_OUTPUT_EXISTS")
    external_inputs = list(dict.fromkeys(path.resolve() for path in [
        contract_path, template, *manifest_inputs, Path(__file__).resolve(),
        ROOT / "scripts/verification_stdlib_source_preflight.py", ROOT / "scripts/verify-c385-preir-call-numeric.py",
        ROOT / "scripts/verification_execution.py", ROOT / "scripts/verification_step_diagnostics.py",
        ROOT / "scripts/verification_contract_lease.py",
        *([] if diagnostics_plan is None else [diagnostics_plan]),
        *tool_inputs, *lifecycle_inputs, *compiler_sources, *stdlib, *runtime_inputs]))
    with VerificationContractLease(external_inputs):
        if read(contract_path) != contract_text or read(manifest) != manifest_text or read(template) != template_text:
            raise ValueError("STDLIB_PREFLIGHT_DISCOVERY_INPUT_DRIFT")
        _, locked_sources, _ = compiler_manifest_inputs(ROOT, manifest)
        if locked_sources != compiler_sources:
            raise ValueError("STDLIB_PREFLIGHT_DISCOVERY_INPUT_DRIFT")
        diagnostics_configuration = load_diagnostics_plan(diagnostics_plan)
        initialize_output(ROOT, output, reusable_directories=args.reusable_compiler_directory)
        output.mkdir(parents=True)
        probe = output / "active-probe.slg"
        probe.write_text(contract["activeProbe"], encoding="utf-8")
        stdlib_manifest = output / "stdlib.sources.json"
        stdlib_manifest.write_text(json.dumps([str(path) for path in stdlib], indent=2) + "\n", encoding="utf-8")
        driver = output / "driver.slg"
        body = template_text.replace("    # ACTIVE_PROBE_PATH", "    sources! -> push(" + json.dumps(probe.as_posix()) + ")")
        body = body.replace("    # STDLIB_SOURCE_PATHS", "\n".join("    sources! -> push(" + json.dumps(path.as_posix()) + ")" for path in stdlib))
        formatted = subprocess.run([str(compiler), "format", "--stdin"], input=body,
            text=True, encoding="utf-8", capture_output=True, check=True, timeout=30)
        if formatted.stderr:
            raise ValueError("STDLIB_PREFLIGHT_DRIVER_FORMAT_DIAGNOSTIC")
        driver.write_bytes(formatted.stdout.encode("utf-8"))
        closure = [path for path in compiler_sources if path.name != "selfhost-sollangc-driver.slg"]
        inputs = list(dict.fromkeys([contract_path, template, *manifest_inputs, stdlib_manifest, probe, driver, Path(__file__).resolve(),
            ROOT / "scripts/verification_stdlib_source_preflight.py", ROOT / "scripts/verify-c385-preir-call-numeric.py",
            ROOT / "scripts/verification_execution.py", ROOT / "scripts/verification_step_diagnostics.py",
            *([] if diagnostics_plan is None else [diagnostics_plan]),
            *tool_inputs, *lifecycle_inputs, *compiler_sources, *stdlib, *runtime_inputs, ROOT / "scripts/verification_contract_lease.py"]))
        with VerificationContractLease([stdlib_manifest, probe, driver]):
            pins = {str(path): sha(path) for path in inputs}
            execution_path = output / "execution-result.json"
            stdout_path = output / "run.stdout"
            row = {"id": "owned-index-full-stdlib-source", "passed": False, "status": "running"}
            execution = {"schemaVersion": 1, "status": "running", "completed": 0, "total": 1,
                "inputHashes": pins, "cases": [row], "processes": []}
            supervisor = VerificationExecution(ROOT, output, execution,
                lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs), sha,
                record_path=execution_path)
            save = supervisor.save

            def run(command, prefix, timeout):
                diagnostic = None if diagnostics_configuration is None else SlowStepDiagnostics(
                    diagnostics_configuration, output / (prefix + ".diagnostics.json"))
                return supervisor.run(command, output / prefix, timeout=timeout, diagnostics=diagnostic).returncode

            metadata = {}
            try:
                row["formatExit"] = run([str(compiler), "format", "--check", str(driver), *map(str, closure)], "format", args.timeout_seconds)
                if row["formatExit"] != 0:
                    raise ValueError("STDLIB_PREFLIGHT_DRIVER_SOURCE_FORMAT_FAILED")
                row["buildExit"] = run([str(compiler), "build", str(driver), *map(str, closure), "-o", str(output / "probe.exe"), "--target", "windows-x64", "--keep-temps", "--llvm", str(args.llvm.resolve()), "--jobs", str(args.jobs), "-" + args.optimization], "build", args.timeout_seconds)
                row["buildStderr"] = read(output / "build.stderr").strip()
                if row["buildExit"] != 0 or row["buildStderr"]:
                    raise ValueError("STDLIB_PREFLIGHT_DRIVER_BUILD_FAILED")
                row["runExit"] = run([str(output / "probe.exe")], "run", args.timeout_seconds)
                row["runStdout"], row["runStderr"] = read(stdout_path).strip(), read(output / "run.stderr").strip()
                metadata, diagnostic_messages = parse_observation(row["runStdout"])
                row["checkedDiagnosticMessages"] = diagnostic_messages
                if row["runExit"] != 0 or row["runStderr"] or metadata["diagnosticSourceModule"] != contract["expectedDiagnosticSourceModule"]:
                    raise ValueError("STDLIB_PREFLIGHT_OWNED_INDEX_DIAGNOSTIC")
                if metadata["checkedSemanticDiagnosticCount"] != contract["expectedCheckedSemanticDiagnosticCount"]:
                    raise ValueError("STDLIB_PREFLIGHT_CHECKED_SEMANTIC_DIAGNOSTIC")
                if metadata["fullStdlibSourceCount"] != len(stdlib) or metadata["packageSourceCount"] != len(stdlib) + 1 or metadata["activeStdlibBodyCount"] <= 0:
                    raise ValueError("STDLIB_PREFLIGHT_EXECUTION_SCOPE")
                if metadata.get("declarationIdentityStatus") != 0 or metadata.get("declarationIdentityCount", 0) <= 0:
                    raise ValueError("STDLIB_PREFLIGHT_DECLARATION_IDENTITY_INDEX")
                if (metadata.get("typeDetailStatus") != 0
                        or metadata.get("typeDetailCount", 0) <= 0
                        or metadata.get("typeDetailCount") != metadata.get("resolvedTypeCount")):
                    raise ValueError("STDLIB_PREFLIGHT_TYPE_DETAIL_CAPTURE")
                row.update(status="passed", passed=True)
                execution.update(status="passed", completed=1)
            except (OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired, KeyboardInterrupt) as error:
                execution.update(status="failed", failure=f"{type(error).__name__}: {error}")
                execution["failureId"] = str(error) if isinstance(error, ValueError) and str(error).startswith("STDLIB_PREFLIGHT_") else "STDLIB_PREFLIGHT_EXECUTION_FAILED"
                row["status"] = "failed"
            finally:
                supervisor.finalize(cleanup=False)
                if not execution["inputsStable"] or not execution["processesStopped"]:
                    execution.update(status="failed", failure="STDLIB_PREFLIGHT_UNSTABLE_OR_RUNNING", failureId="STDLIB_PREFLIGHT_UNSTABLE_OR_RUNNING")
                save()
            proof = {"schemaVersion": 1, "scope": contract["scope"], "status": execution["status"],
                "completed": execution["completed"], "total": 1, "inputsStable": execution["inputsStable"],
                "processesStopped": execution["processesStopped"], **metadata,
                "compilerSourceHashes": {str(path): pins[str(path)] for path in compiler_sources},
                "executionResult": str(execution_path), "executionStdout": str(stdout_path),
                "checkedDiagnosticMessages": row.get("checkedDiagnosticMessages", []),
                "inputHashes": {**pins, str(execution_path): sha(execution_path)}}
            if stdout_path.is_file():
                proof["inputHashes"][str(stdout_path)] = sha(stdout_path)
            if execution.get("failureId"):
                proof["failureId"] = execution["failureId"]
            proof_path = output / "result.json"
            proof_path.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
            if execution["status"] != "passed":
                raise SystemExit(1)
            try:
                from verification_stdlib_source_preflight import validate
                validate(ROOT, proof_path)
                assert_output_shutdown(ROOT, output)
            except (OSError, ValueError, TypeError, subprocess.CalledProcessError) as error:
                proof.update(status="failed", completed=0, failureId="STDLIB_PREFLIGHT_POST_EXECUTION_LIFECYCLE_FAILURE",
                    observedSemanticCompleted=1, observedSemanticTotal=1, failure=f"{type(error).__name__}: {error}")
                proof_path.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
                raise SystemExit(1)
    try:
        cleanup_output(ROOT, output, execute=True,
                       reusable_directories=args.reusable_compiler_directory)
    except (OSError, ValueError, TypeError, subprocess.CalledProcessError) as error:
        proof.update(status="failed", completed=0, failureId="STDLIB_PREFLIGHT_POST_EXECUTION_LIFECYCLE_FAILURE",
            observedSemanticCompleted=1, observedSemanticTotal=1, failure=f"{type(error).__name__}: {error}")
        proof_path.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
        raise SystemExit(1)
    print(json.dumps({"status": "passed", **metadata}))


if __name__ == "__main__":
    main()
