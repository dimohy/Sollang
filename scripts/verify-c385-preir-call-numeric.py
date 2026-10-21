"""Run the frozen semantic numeric-call cases with pinned compiler inputs."""

import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path

from verification_fingerprints import managed_runtime_inputs, input_file_identity, unique_input_files
from verification_observed_sources import observed_source_paths
from completed_artifact_plan import initialize_output, cleanup_output, assert_output_shutdown, assert_build_space, GENERATED
from verification_execution import VerificationExecution
from verification_json_records import write_json_atomic
from verification_step_diagnostics import SlowStepDiagnostics


ROOT = Path(__file__).resolve().parent.parent
WINDOWS_RUNTIME_LIBRARIES = ("-lws2_32", "-lshell32", "-lbcrypt", "-lole32")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def native_build_timeout(contract, mode="paired"):
    """Reuse the original context budget only for its unchanged suite contract."""
    if mode == "paired":
        private_fixture = ROOT / "artifacts/scratch/resume-20261006-owner-continuation22/array-layout-live-types-focused212.slg"
        private_hash = sha(private_fixture) if private_fixture.is_file() else None
        for case in contract.get("cases", []):
            if case.get("id") == "array-layout-live-type-roots":
                raise ValueError("PRIVATE_COMPILER_WORKLOAD_REQUIRES_SEPARATE_BUDGET")
            for source in case_sources(case):
                if source == private_fixture or (private_hash is not None and sha(source) == private_hash):
                    raise ValueError("PRIVATE_COMPILER_WORKLOAD_REQUIRES_SEPARATE_BUDGET")
    authority = contract.get("nativeBuildTimeoutAuthority")
    if authority is None:
        if mode == "paired" and any(case.get("id") == "1999-selfhost-context-fixture-suite"
                                    for case in contract.get("cases", [])):
            raise ValueError("CONTEXT_NATIVE_TIMEOUT_AUTHORITY_REQUIRED")
        return 180, []
    plan = ROOT / "scripts/contracts/context-fixture-pair-plan.json"
    manifest = ROOT / "examples/regression/expected/1999-selfhost-context-fixture-suite.sources.txt"
    expected = ROOT / "examples/regression/expected/1999-selfhost-context-fixture-suite.stdout.txt"
    if not isinstance(authority, dict) or authority != {
            "path": "scripts/contracts/context-fixture-pair-plan.json",
            "sha256": sha(plan)}:
        raise ValueError("CONTEXT_NATIVE_TIMEOUT_AUTHORITY_INVALID")
    original = json.loads(read(plan))
    cases = contract.get("cases", [])
    if (original.get("timeoutMillisecondsPerCompilerBuild") != 1200000
            or len(cases) != 1 or cases[0].get("id") != "1999-selfhost-context-fixture-suite"
            or cases[0].get("exit") != 0 or cases[0].get("stderr") != ""
            or cases[0].get("stdout") != read(expected).strip()
            or case_sources(cases[0]) != [ROOT / line.strip() for line in read(manifest).splitlines() if line.strip()]):
        raise ValueError("CONTEXT_NATIVE_TIMEOUT_SCOPE_INVALID")
    return 1200, [plan, manifest, expected]


def case_sources(case):
    additional = case.get("additionalSources", [])
    if not isinstance(additional, list):
        raise ValueError(f"invalid additional sources: {case['id']}")
    sources = [case["source"], *additional]
    resolved = []
    for source in sources:
        if not isinstance(source, str) or not source:
            raise ValueError(f"invalid source: {case['id']}")
        path = (ROOT / source).resolve()
        if not path.is_relative_to(ROOT) or path.suffix != ".slg" or not path.is_file():
            raise ValueError(f"invalid source path: {case['id']}: {source}")
        if path in resolved:
            raise ValueError(f"duplicate source: {case['id']}: {source}")
        resolved.append(path)
    return resolved


def contract_observed_sources(contract):
    """Lease every declared runtime program while preserving each case's order."""
    group = contract.get("reusableCheckedProducer")
    runtime_fields = {"programSource", "runArguments", "observedSourceOrder"}
    if group is None:
        if any(runtime_fields.intersection(case) for case in contract["cases"]):
            raise ValueError("CHECKED_PRODUCER_RUNTIME_FIELDS_REQUIRE_GROUP")
        return observed_source_paths(ROOT, contract)
    paths = observed_source_paths(ROOT, contract)
    for case in contract["cases"]:
        for path in observed_source_paths(ROOT, {"observedSourceOrder": case.get("observedSourceOrder")}):
            if path not in paths:
                paths.append(path)
    return paths


def contract_runtime_inputs(contract):
    """Resolve explicit runtime data files without treating them as compiler sources."""
    if "runtimeInputFiles" not in contract:
        return []
    names = contract["runtimeInputFiles"]
    if not isinstance(names, list) or not names:
        raise ValueError("RUNTIME_INPUT_FILES_INVALID")
    paths = []
    for name in names:
        if not isinstance(name, str) or not name:
            raise ValueError("RUNTIME_INPUT_PATH_INVALID")
        relative = Path(name)
        if relative.is_absolute() or relative.drive or ".." in relative.parts:
            raise ValueError("RUNTIME_INPUT_PATH_INVALID: " + name)
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
            raise ValueError("RUNTIME_INPUT_PATH_INVALID: " + name)
        paths.append(path)
    return unique_input_files(paths, duplicate_error="RUNTIME_INPUT_PATH_DUPLICATE")


def reusable_producer(contract):
    group = contract.get("reusableCheckedProducer")
    if group is None:
        contract_observed_sources(contract)
        return None
    if (not isinstance(group, dict) or not isinstance(group.get("id"), str)
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", group["id"])
            or group["id"] in (".", "..")):
        raise ValueError("CHECKED_PRODUCER_ID_INVALID")
    validator_path = ROOT / "scripts/verify-checked-package-emitter.py"
    spec = importlib.util.spec_from_file_location("numeric_checked_package_validator", validator_path)
    validator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator)
    validator.validate_reusable(contract, ROOT)
    if any(case.get("exit") != 0 or case.get("stderr") != "" for case in contract["cases"]):
        raise ValueError("CHECKED_PRODUCER_REQUIRES_SUCCESSFUL_HARNESS_BUILD")
    if any(not isinstance(case.get("id"), str)
           or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", case["id"])
           or case["id"] == "_checked-producer" for case in contract["cases"]):
        raise ValueError("CHECKED_PRODUCER_CASE_ID_INVALID")
    return group


def harness_build_options(contract, mode):
    optimization = contract.get('harnessBuildOptimization')
    if optimization is None:
        options = ['-O1'] if mode == 'paired' else []
    elif optimization not in ('-O0', '-O1', '-O2', '-O3'):
        raise ValueError('HARNESS_BUILD_OPTIMIZATION_INVALID')
    else:
        options = [optimization]
    jobs = contract.get('harnessBuildJobs')
    if jobs is not None:
        if type(jobs) is not int or not 1 <= jobs <= 64:
            raise ValueError('HARNESS_BUILD_JOBS_INVALID')
        options += ['--jobs', str(jobs)]
    return options


def binary_inputs_stable(pins):
    return all(path.is_file() and sha(path) == expected for path, expected in pins.items())


def producer_lease_paths(args, contract):
    """Protect shared producer inputs through every case, including cancellation."""
    if contract.get("reusableCheckedProducer") is None:
        return []
    managed = args.managed_compiler.resolve()
    paths = [*managed_runtime_inputs(managed), Path(__file__),
             ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
             *[p for case in contract["cases"] for p in case_sources(case)],
             *sorted((ROOT / "stdlib").rglob("*.slg"))]
    paths += [ROOT / name for name in (
        "scripts/verification_execution.py", "scripts/verification_step_diagnostics.py",
        "scripts/verification_observed_sources.py", "scripts/verification_contract_lease.py",
        "scripts/verification_fingerprints.py", "scripts/verify-checked-package-emitter.py",
        "scripts/generate-selection-result-emitter.py", "scripts/completed_artifact_plan.py",
        "scripts/ArtifactLifecycle.ps1", "scripts/Invoke-CompletedArtifactCleanup.ps1",
        "scripts/contracts/artifact-lifecycle.json", "scripts/contracts/checked-producer-reuse-acceptance.json",
        ".tools/llvm-22.1.8/bin/clang.exe")]
    for key in ("semanticPreflightProof", "stdlibSourcePreflightProof"):
        name = contract.get(key)
        if name is not None:
            if not isinstance(name, str) or not name:
                raise ValueError("CHECKED_PRODUCER_PROOF_PATH_INVALID")
            proof_path = (ROOT / name).resolve()
            if not proof_path.is_relative_to(ROOT) or proof_path.name != "result.json":
                raise ValueError("CHECKED_PRODUCER_PROOF_PATH_INVALID")
            paths.append(proof_path)
            proof = json.loads(read(proof_path))
            for pins_key in ("inputHashes", "compilerSourceHashes"):
                paths += [(ROOT / source).resolve() for source in proof.get(pins_key, {})]
    if any(case.get("emittedLlvm") for case in contract["cases"]):
        paths.append(ROOT / ".tools/llvm-22.1.8/bin/llvm-as.exe")
        paths.append(Path(__file__).with_name("verify-checked-package-emitter.py"))
    if any("expectedAllocations" in case for case in contract["cases"]):
        paths.append(ROOT / "tests/native-interop/owned_array_audit.c")
    if args.format_compiler is not None:
        paths.append(args.format_compiler.resolve())
    if args.mode == "paired":
        from verification_source_proof import current_build_inputs
        build_record = json.loads(read(args.build / "result.json"))
        paths += [args.build / "compiler.exe", *current_build_inputs(ROOT, build_record),
                  *sorted((ROOT / "selfhost").rglob("*.slg"))]
    return unique_input_files(paths)


def emission_semantic_proof(contract, cases):
    required = contract.get("reusableCheckedProducer") is not None or any(case.get("emittedLlvm") and any(
        path.startswith("selfhost/") for path in case.get("additionalSources", [])) for case in cases)
    kind_inputs = []
    if required:
        from ast_expression_kind_contract import contract_inputs, validate_repository
        issues = validate_repository(ROOT)
        if issues:
            raise ValueError("EMISSION_AST_KIND_PREFLIGHT_FAILED: " + ", ".join(issues))
        kind_inputs = contract_inputs(ROOT)
    name = contract.get("semanticPreflightProof")
    if not required and name is None:
        return []
    if not isinstance(name, str) or not name:
        raise ValueError("EMISSION_SEMANTIC_PREFLIGHT_REQUIRED_BEFORE_BUILD")
    path = (ROOT / name).resolve()
    if not path.is_relative_to(ROOT) or path.name != "result.json" or not path.is_file():
        raise ValueError("EMISSION_SEMANTIC_PREFLIGHT_INVALID_PATH")
    proof = json.loads(read(path))
    cases_by_id = {row.get("id"): row for row in proof.get("cases", [])}
    expected_ids = {"positive", "deferred-text", "rebound-owner", "focused-selfhost"}
    if (proof.get("status") != "passed" or proof.get("scope") != "focused-selfhost"
            or proof.get("codegenInvoked") is not False or proof.get("codegenPathGuard") != "passed"
            or proof.get("inputsStable") is not True or proof.get("processesStopped") is not True
            or proof.get("failureIds") != [] or proof.get("completed") != 4 or proof.get("total") != 4
            or set(cases_by_id) != expected_ids
            or not all(row.get("passed") is True for row in cases_by_id.values())):
        raise ValueError("EMISSION_SEMANTIC_PREFLIGHT_INCOMPLETE")
    pins = proof.get("inputHashes")
    if not isinstance(pins, dict) or not pins:
        raise ValueError("EMISSION_SEMANTIC_PREFLIGHT_INPUTS_MISSING")
    for source, expected in pins.items():
        if not Path(source).is_file() or sha(Path(source)) != expected:
            raise ValueError(f"EMISSION_SEMANTIC_PREFLIGHT_INPUT_DRIFT: {source}")
    for case in cases:
        if case.get("emittedLlvm") or contract.get("reusableCheckedProducer") is not None:
            for source in case_sources(case)[1:]:
                if pins.get(str(source)) != sha(source):
                    raise ValueError(f"EMISSION_SEMANTIC_PREFLIGHT_UNCOVERED_SOURCE: {source}")
    return [path, *[Path(source) for source in pins], *kind_inputs]


def emission_stdlib_source_proof_inputs(contract, cases, observed):
    stdlib = {path.resolve() for path in (ROOT / "stdlib").rglob("*.slg")}
    required = (contract.get("reusableCheckedProducer") is not None
                or any(case.get("emittedLlvm") is True for case in cases)) and stdlib.issubset(observed)
    name = contract.get("stdlibSourcePreflightProof")
    if not required and name is None:
        return []
    if not isinstance(name, str) or not name:
        raise ValueError("EMISSION_STDLIB_SOURCE_PREFLIGHT_REQUIRED_BEFORE_BUILD")
    proof_path = (ROOT / name).resolve()
    if not proof_path.is_relative_to(ROOT) or proof_path.name != "result.json" or not proof_path.is_file():
        raise ValueError("EMISSION_STDLIB_SOURCE_PREFLIGHT_INVALID_PATH")
    proof = json.loads(read(proof_path))
    paths = [proof_path, ROOT / "scripts/verification_stdlib_source_preflight.py"]
    for key in ("inputHashes", "compilerSourceHashes"):
        pins = proof.get(key)
        if isinstance(pins, dict):
            paths += [(ROOT / source).resolve() for source in pins]
    return unique_input_files(paths)


def finalize_result(result, inputs_stable, error=None):
    """Close durable state on success, failure, timeout, and user cancellation."""
    result["inputsStable"] = inputs_stable
    if isinstance(error, KeyboardInterrupt):
        terminal = "canceled"
    elif isinstance(error, subprocess.TimeoutExpired):
        terminal = "timed-out"
    else:
        terminal = "failed"
    if error is not None:
        result["status"] = terminal
        result["failure"] = f"{type(error).__name__}: {error}"
    elif not inputs_stable:
        result["status"] = "failed"
        result["failure"] = "INPUT_DRIFT after cases"
    for row in result["cases"]:
        if row["status"] == "running":
            row["status"] = terminal
            row["passed"] = False
    result["processesStopped"] = not result.get("activeProcess") and all(
        isinstance(process.get("exit"), int) and process.get('shutdownConfirmed') is True
        for process in result.get("processes", []))
    if not result['processesStopped'] and error is None and inputs_stable:
        result.update(status='failed', failure='PROCESS_SHUTDOWN_UNCONFIRMED')
    return result


def load_diagnostics_plan(path):
    if path is None:
        return None
    plan = json.loads(read(path.resolve()))
    diagnostics = SlowStepDiagnostics(plan)
    if diagnostics.hard_timeout_seconds != 180:
        raise ValueError('NUMERIC_DIAGNOSTICS_HARD_TIMEOUT_MISMATCH')
    return plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--managed-compiler", type=Path,
                        default=ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
                        help="Explicit managed apphost, including a verified isolated build; no fallback")
    parser.add_argument("--format-compiler", type=Path,
                        help="Explicit native formatter for contract formatCheckSources; no implicit fallback")
    parser.add_argument("--artifact-cleanup", choices=("execute", "plan-only"), default="execute")
    parser.add_argument('--diagnostics-plan', type=Path,
                        help='Explicit bounded slow-step investigation plan; hard timeout remains 180 seconds')
    parser.add_argument("--contract", type=Path,
                        default=ROOT / "scripts/contracts/c385-preir-call-numeric-coverage.json")
    parser.add_argument("--source-comparison", type=Path,
                        default=ROOT / "artifacts/scratch/c385-preir-call-numeric-source-comparison-20261001-01.json")
    args = parser.parse_args()
    args.diagnostics_configuration = load_diagnostics_plan(args.diagnostics_plan)
    from verification_contract_lease import VerificationContractLease
    contracts = [args.contract]
    if args.diagnostics_plan is not None:
        contracts.append(args.diagnostics_plan)
    if args.mode == "paired":
        if not args.build or not args.managed_proof:
            parser.error("paired mode requires --build and --managed-proof")
        contracts += [args.source_comparison, args.managed_proof, args.build / "result.json"]
    with VerificationContractLease(contracts) as lease:
        contract = json.loads(read(args.contract))
        observed = contract_observed_sources(contract)
        runtime_inputs = contract_runtime_inputs(contract)
        stdlib_proof_inputs = emission_stdlib_source_proof_inputs(contract, contract["cases"], observed)
        with VerificationContractLease([*observed, *runtime_inputs, *stdlib_proof_inputs,
                                        *producer_lease_paths(args, contract)]):
            if [input_file_identity(p) for p in contract_runtime_inputs(json.loads(read(args.contract)))] != [input_file_identity(p) for p in runtime_inputs]:
                raise ValueError("RUNTIME_INPUT_CONTRACT_CHANGED")
            execute(args, parser, lease.mode, observed, stdlib_proof_inputs, runtime_inputs)


def execute(args, parser, lease_mode, observed, stdlib_proof_inputs=(), runtime_inputs=None):
    contract_path = args.contract.resolve()
    contract = json.loads(read(contract_path))
    build_options = harness_build_options(contract, args.mode)
    resolved_runtime_inputs = contract_runtime_inputs(contract)
    if runtime_inputs is not None and [input_file_identity(p) for p in runtime_inputs] != [input_file_identity(p) for p in resolved_runtime_inputs]:
        raise ValueError("RUNTIME_INPUT_CONTRACT_CHANGED")
    runtime_inputs = resolved_runtime_inputs
    cases = contract["cases"]
    native_timeout, timeout_inputs = native_build_timeout(contract, args.mode)
    if contract["schemaVersion"] != 1 or not cases or len({c["id"] for c in cases}) != len(cases):
        raise ValueError("invalid case contract")
    group = reusable_producer(contract)
    for case in cases:
        if case["exit"] not in (0, 1) or not isinstance(case["stderr"], str):
            raise ValueError(f"invalid expectation: {case['id']}")
        if case["exit"] == 0 and not isinstance(case.get("stdout"), str):
            raise ValueError(f"CASE_STDOUT_EXPECTATION_REQUIRED: {case['id']}")
        if isinstance(case.get("stdout"), str) and case["stdout"] != case["stdout"].strip():
            raise ValueError(f"CASE_STDOUT_EXPECTATION_NONCANONICAL: {case['id']}")
        if case["stderr"] != case["stderr"].strip():
            raise ValueError(f"CASE_STDERR_EXPECTATION_NONCANONICAL: {case['id']}")
        if not isinstance(case.get("runStderr", ""), str):
            raise ValueError(f"RUN_STDERR_EXPECTATION_INVALID: {case['id']}")
        if "runStderr" in case and case["exit"] != 0:
            raise ValueError(f"RUN_STDERR_EXPECTATION_REQUIRES_SUCCESS: {case['id']}")
        if not isinstance(case.get("emittedLlvm", False), bool):
            raise ValueError(f"EMISSION_PREFLIGHT_INVALID_CONTRACT: {case['id']}")
        if case.get("emittedLlvm") and (case["exit"] != 0 or case["stderr"]):
            raise ValueError(f"EMISSION_PREFLIGHT_REQUIRES_SUCCESS: {case['id']}")
        if "expectedAllocations" in case and (
                type(case["expectedAllocations"]) is not int or case["expectedAllocations"] < 0
                or not case.get("emittedLlvm")):
            raise ValueError(f"EMISSION_AUDIT_INVALID_CONTRACT: {case['id']}")
        case_sources(case)
    format_sources = contract.get("formatCheckSources", [])
    if not isinstance(format_sources, list) or any(not isinstance(p, str) for p in format_sources):
        raise ValueError("FORMAT_PREFLIGHT_INVALID_SOURCES")
    declared_sources = {p for case in cases for p in case_sources(case)}
    # Runtime-loaded SLG inputs have the same declared, pinned and leased
    # authority as build inputs; check their format before building a producer.
    declared_sources.update(observed)
    format_paths = [(ROOT / p).resolve() for p in format_sources]
    if len(set(format_paths)) != len(format_paths) or any(p not in declared_sources for p in format_paths):
        raise ValueError("FORMAT_PREFLIGHT_UNDECLARED_SOURCE")
    if format_paths and (not args.format_compiler or not args.format_compiler.is_file()):
        raise ValueError("FORMAT_PREFLIGHT_EXPLICIT_COMPILER_REQUIRED")
    stdlib_preflight = None
    if stdlib_proof_inputs:
        from verification_stdlib_source_preflight import validate
        stdlib_preflight = validate(ROOT, stdlib_proof_inputs[0])
    semantic_proof_inputs = emission_semantic_proof(contract, cases)
    managed = args.managed_compiler.resolve()
    managed_inputs = managed_runtime_inputs(managed)
    expected_managed_hash = contract.get("expectedManagedDllSha256")
    if expected_managed_hash is not None and sha(managed.with_suffix(".dll")) != expected_managed_hash:
        raise ValueError("MANAGED_COMPILER_CONTRACT_HASH_MISMATCH")
    compiler = managed
    paths = [*managed_inputs, contract_path, Path(__file__), *semantic_proof_inputs, *timeout_inputs,
             *stdlib_proof_inputs,
             ROOT / 'scripts/verification_execution.py', ROOT / 'scripts/verification_json_records.py', ROOT / 'scripts/verification_step_diagnostics.py',
             ROOT / 'scripts/verification_observed_sources.py', *observed, *runtime_inputs,
             ROOT / "scripts/verification_contract_lease.py",
             ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
             *[path for case in cases for path in case_sources(case)], *sorted((ROOT / "stdlib").rglob("*.slg"))]
    if format_paths:
        paths += [args.format_compiler.resolve()]
    if args.diagnostics_plan is not None:
        paths += [args.diagnostics_plan.resolve()]
    if args.mode == "paired":
        if not args.build or not args.managed_proof:
            parser.error("paired mode requires --build and --managed-proof")
        build = args.build.resolve()
        build_record = json.loads(read(build / "result.json"))
        compiler = build / "compiler.exe"
        if build_record["status"] != "passed" or not build_record["inputsStable"] or sha(compiler) != build_record["compilerSha256"]:
            raise ValueError("invalid self-host build")
        from verification_source_proof import current_build_inputs
        paths += current_build_inputs(ROOT, build_record)
        proof = json.loads(read(args.managed_proof))
        if proof["status"] != "passed" or proof["completed"] != len(cases) or not proof["inputsStable"]:
            raise ValueError("managed-first proof is incomplete")
        for path, expected in proof["inputHashes"].items():
            if sha(Path(path)) != expected:
                raise ValueError(f"managed-first proof drift: {path}")
        if proof["inputHashes"].get(str(contract_path)) != sha(contract_path):
            raise ValueError("managed proof does not cover this contract")
        comparison_path = args.source_comparison.resolve()
        paths += [compiler, build / "result.json", args.managed_proof.resolve(), comparison_path,
                  *sorted((ROOT / "selfhost").rglob("*.slg"))]
        comparison = json.loads(read(comparison_path))
        if comparison["status"] != "compared-before-slg-edit":
            raise ValueError("source comparison is missing")
    lifecycle_inputs = [ROOT / "scripts/completed_artifact_plan.py", ROOT / "scripts/ArtifactLifecycle.ps1",
                        ROOT / "scripts/Invoke-CompletedArtifactCleanup.ps1", ROOT / "scripts/contracts/artifact-lifecycle.json"]
    paths += [ROOT / ".tools/llvm-22.1.8/bin/clang.exe", *lifecycle_inputs]
    if group is not None:
        paths += [ROOT / "scripts/verify-checked-package-emitter.py",
                  ROOT / "scripts/generate-selection-result-emitter.py",
                  ROOT / "scripts/contracts/checked-producer-reuse-acceptance.json"]
    if any(case.get("emittedLlvm") for case in cases):
        paths += [ROOT / ".tools/llvm-22.1.8/bin/llvm-as.exe"]
    if any("expectedAllocations" in case for case in cases):
        paths += [ROOT / "tests/native-interop/owned_array_audit.c"]
    hashes = {str(p): sha(p) for p in paths}
    binary_pins = {}
    binary_lease = None
    output = args.output.resolve()
    initialize_output(ROOT, output)
    output.mkdir(parents=True, exist_ok=False)
    result = {"schemaVersion": 1, "status": "running", "mode": args.mode,
              "completed": 0, "total": len(cases), "inputHashes": hashes, "cases": [], "processes": [],
              "managedCompiler": str(managed), "managedCompilerDllSha256": sha(managed.with_suffix(".dll")),
              "artifactCleanupMode": args.artifact_cleanup,
              "contractLease": lease_mode}
    if observed:
        result['observedSourceOrder'] = [str(path) for path in observed]
        result['observedSourceLease'] = lease_mode
    if runtime_inputs:
        result["runtimeInputFiles"] = [str(path) for path in runtime_inputs]
        result["runtimeInputLease"] = lease_mode
    if semantic_proof_inputs:
        result["semanticPreflight"] = {"status": "passed-current-source",
                                      "proof": str(semantic_proof_inputs[0]), "codegenInvoked": False}
    if stdlib_preflight is not None:
        result["stdlibSourcePreflight"] = {**stdlib_preflight, "proof": str(stdlib_proof_inputs[0])}
    if group is not None:
        result["reusableCheckedProducer"] = {"id": group["id"], "status": "pending",
            "source": group["source"], "additionalSources": group["additionalSources"],
            "stdlibSourceOrder": group["stdlibSourceOrder"], "buildCount": 0,
            "programHashes": {case["programSource"]: sha((ROOT / case["programSource"]).resolve())
                              for case in cases}}

    def save():
        write_json_atomic(output / "result.json", result)

    def stable():
        return (hashes == {str(p): sha(p) if p.is_file() else "MISSING" for p in paths}
                and binary_inputs_stable(binary_pins))

    execution = VerificationExecution(ROOT, output, result, stable, sha)

    def run(command, prefix):
        if len(command) > 1 and command[0] == str(compiler) and command[1] == 'build':
            assert_build_space(output)
        diagnostics = None if args.diagnostics_configuration is None else SlowStepDiagnostics(
            args.diagnostics_configuration, prefix.with_suffix('.diagnostics.json'))
        timeout = native_timeout if args.mode == "paired" and command[:2] == [str(compiler), "build"] else 180
        exit_code = execution.run(command, prefix, timeout=timeout, diagnostics=diagnostics).returncode
        if group is not None and not stable():
            raise ValueError("CHECKED_PRODUCER_INPUT_OR_BINARY_DRIFT_AFTER_COMMAND")
        return exit_code

    save()
    terminal_error = None
    try:
        if format_paths:
            format_exit = run([str(args.format_compiler.resolve()), "format", "--check",
                               *[str(p) for p in format_paths]], output / "format-preflight")
            result["formatPreflight"] = {"exit": format_exit, "sources": format_sources,
                                       "compiler": str(args.format_compiler.resolve())}
            save()
            if format_exit != 0:
                raise ValueError("FORMAT_PREFLIGHT_FAILED_BEFORE_BUILD")
        for case in cases:
            folder = output / case["id"]
            folder.mkdir()
            row = {"id": case["id"], "status": "running", "passed": False,
                   "expectedBuildExit": case["exit"]}
            result["cases"].append(row)
            save()
            if group is not None:
                build_folder = output / "_checked-producer" / group["id"]
                exe = build_folder / "probe.exe"
                row["producerId"] = group["id"]
                row["programSource"] = case["programSource"]
                row["programSha256"] = sha((ROOT / case["programSource"]).resolve())
                row["observedSourceOrder"] = case["observedSourceOrder"]
                row["runArguments"] = case["runArguments"]
            else:
                build_folder = folder
                exe = folder / "probe.exe"
            command = [str(compiler), "build", *[str(path) for path in case_sources(case)], "-o", str(exe), "--target", "windows-x64", "--keep-temps"]
            command += build_options
            if args.mode == "paired":
                command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib")]
            if group is not None:
                producer = result["reusableCheckedProducer"]
                if producer["buildCount"] == 0:
                    build_folder.mkdir(parents=True)
                    producer.update(status="building", buildCount=1)
                    save()
                    producer["buildExit"] = run(command, build_folder / "build")
                    producer["buildStderr"] = read(build_folder / "build.stderr").strip()
                    if producer["buildExit"] == 0 and not producer["buildStderr"]:
                        from verification_contract_lease import VerificationContractLease
                        binary_lease = VerificationContractLease([exe])
                        binary_lease.__enter__()
                        binary_pins[exe] = sha(exe)
                        producer.update(status="built", executable=str(exe), executableSha256=binary_pins[exe])
                    else:
                        producer["status"] = "failed"
                    save()
                row["buildExit"] = producer["buildExit"]
                row["buildStderr"] = producer["buildStderr"]
                row["reusedProducer"] = len(result["cases"]) > 1
                row["producerSha256"] = producer.get("executableSha256")
            else:
                row["buildExit"] = run(command, folder / "build")
                row["buildStderr"] = read(folder / "build.stderr").strip()
            passed = row["buildExit"] == case["exit"] and row["buildStderr"] == case["stderr"]
            if passed and row["buildExit"] == 0 and (group is None or (
                    producer["status"] == "built" and row["producerSha256"])):
                row["runExit"] = run([str(exe), *case["runArguments"]] if group is not None else [str(exe)], folder / "run")
                row["runStdout"] = read(folder / "run.stdout").strip()
                row["runStderr"] = read(folder / "run.stderr").strip()
                passed = (passed and row["runExit"] == 0
                          and row["runStderr"] == case.get("runStderr", ""))
                if case.get("emittedLlvm"):
                    llvm = folder / "emitted.ll"
                    llvm.write_bytes((folder / "run.stdout").read_bytes())
                    row["emittedLlvmSha256"] = sha(llvm)
                    row["emittedLlvmBytes"] = llvm.stat().st_size
                    row.pop("runStdout", None)
                    if passed:
                        row["assemblyExit"] = run([
                            str(ROOT / ".tools/llvm-22.1.8/bin/llvm-as.exe"), str(llvm),
                            "-o", str(folder / "emitted.bc")], folder / "assemble")
                        passed = row["assemblyExit"] == 0 and not read(folder / "assemble.stderr").strip()
                    if passed:
                        validator_path = Path(__file__).with_name("verify-checked-package-emitter.py")
                        spec = importlib.util.spec_from_file_location("numeric_emission_entry_validator", validator_path)
                        validator = importlib.util.module_from_spec(spec)
                        spec.loader.exec_module(validator)
                        row["emittedEntryPoint"] = validator.validate_emitted_entrypoint(read(llvm), "windows")
                    if passed:
                        native = folder / "emitted.exe"
                        row["nativeLinkExit"] = run([
                            str(ROOT / ".tools/llvm-22.1.8/bin/clang.exe"),
                            "-Wno-override-module", str(llvm), "-O1", "-o", str(native),
                            *WINDOWS_RUNTIME_LIBRARIES], folder / "native-link")
                        passed = row["nativeLinkExit"] == 0 and not read(folder / "native-link.stderr").strip()
                    if passed:
                        row["nativeRunExit"] = run([str(native)], folder / "native-run")
                        row["nativeRunStdout"] = read(folder / "native-run.stdout").strip()
                        passed = (row["nativeRunExit"] == 0
                                  and row["nativeRunStdout"] == case["stdout"]
                                  and not read(folder / "native-run.stderr").strip())
                    if passed and "expectedAllocations" in case:
                        audit_text = read(llvm)
                        for source, target in (
                                ("call ptr @malloc(", "call ptr @audit_malloc("),
                                ("call ptr @sollang_alloc(", "call ptr @audit_malloc("),
                                ("call ptr @realloc(", "call ptr @audit_realloc("),
                                ("call void @free(", "call void @audit_free("),
                                ("call void @sollang_free(", "call void @audit_free("),
                                ("ptr @free,", "ptr @audit_free,"),
                                ("ptr @free)", "ptr @audit_free)"),
                                ("ptr @sollang_free,", "ptr @audit_free,"),
                                ("ptr @sollang_free)", "ptr @audit_free)"),
                                ("@sollang_start()", "@slg_program_main()"),
                                ("define i32 @main()", "define i32 @slg_program_main()"),
                                ("define dso_local i32 @main()", "define dso_local i32 @slg_program_main()")):
                            audit_text = audit_text.replace(source, target)
                        if len(re.findall(r"^define (?:dso_local )?i32 @slg_program_main\(\)", audit_text, re.M)) != 1:
                            raise ValueError("EMISSION_AUDIT_ENTRY_SHAPE")
                        audit_text += "\ndeclare ptr @audit_malloc(i64)\ndeclare ptr @audit_realloc(ptr,i64)\ndeclare void @audit_free(ptr)\n"
                        audit_llvm = folder / "audit.ll"
                        audit_llvm.write_text(audit_text, encoding="utf-8")
                        row["auditLlvmSha256"] = sha(audit_llvm)
                        audit_exe = folder / "audit.exe"
                        row["auditLinkExit"] = run([
                            str(ROOT / ".tools/llvm-22.1.8/bin/clang.exe"),
                            "-Wno-override-module", str(audit_llvm),
                            str(ROOT / "tests/native-interop/owned_array_audit.c"),
                            f"-DEXPECTED_ALLOCATIONS={case['expectedAllocations']}",
                            "-O1", "-o", str(audit_exe), *WINDOWS_RUNTIME_LIBRARIES],
                            folder / "audit-link")
                        passed = row["auditLinkExit"] == 0 and not read(folder / "audit-link.stderr").strip()
                        if passed:
                            row["auditRunExit"] = run([str(audit_exe)], folder / "audit-run")
                            row["auditRunStdout"] = read(folder / "audit-run.stdout").strip()
                            row["expectedAllocations"] = case["expectedAllocations"]
                            audit_summary = f"allocations={case['expectedAllocations']},releases={case['expectedAllocations']}"
                            audit_expected = "\n".join(part for part in (case["stdout"], audit_summary) if part)
                            passed = (row["auditRunExit"] == 0 and row["auditRunStdout"] == audit_expected
                                      and not read(folder / "audit-run.stderr").strip())
                else:
                    passed = passed and row["runStdout"] == case["stdout"]
            row["status"] = "passed" if passed else "failed"
            row["passed"] = passed
            result["completed"] += int(passed)
            save()
            print(f"{case['id']}: {'PASS' if passed else 'FAIL'}", flush=True)
            if not passed:
                # A failed acceptance must not start another whole compiler pass.
                # Retain its existing LLVM and logs; diagnostics need a separate
                # explicitly budgeted execution.
                row["failureDiagnosticsMode"] = "retained-output-only"
                save()
                raise ValueError(f"semantic numeric call case failed: {case['id']}")
        result["inputsStable"] = stable()
        if not result["inputsStable"]:
            raise ValueError("INPUT_DRIFT after cases")
        result["status"] = "passed"
    except (Exception, KeyboardInterrupt) as error:
        terminal_error = error
        raise
    finally:
        finalize_result(result, stable(), terminal_error)
        if group is not None:
            result["reusableCheckedProducer"]["consumerStatus"] = result["status"]
            result["reusableCheckedProducer"]["consumersCompleted"] = result["completed"]
            result["reusableCheckedProducer"]["consumersTotal"] = len(cases)
        result["generatedOutputHashes"] = {str(path): sha(path) for path in output.rglob("*")
            if path.is_file() and (GENERATED.search(path.name)
                                  or ".sollang-cache" in path.parts)}
        save()
        if binary_lease is not None and result["processesStopped"]:
            binary_lease.__exit__(None, None, None)
        if result["status"] == "passed" and result["inputsStable"] and result["processesStopped"]:
            assert_output_shutdown(ROOT, output)
            cleanup_output(ROOT, output, execute=args.artifact_cleanup == "execute")


if __name__ == "__main__":
    main()
