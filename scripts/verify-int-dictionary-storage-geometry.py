"""Compare Int dictionary arithmetic using real SLG emission and bounded observers."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from xml.sax.saxutils import escape
from pathlib import Path

from completed_artifact_plan import cleanup_output, initialize_output
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs

ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / "scripts/probes/dictionary-storage-boundaries"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def require(condition, failure):
    if not condition:
        raise ValueError(failure)


def managed_arithmetic(args, output, retained, matrix_path, expected):
    located = shutil.which("dotnet")
    require(located is not None, "DICTIONARY_ARITHMETIC_DOTNET_MISSING")
    dotnet = Path(located).resolve()
    initialize_output(ROOT, output, reusable_directories=retained)
    output.mkdir(exist_ok=False)
    project = output / "Arithmetic.csproj"
    sources = [PROBE / "managed-arithmetic.cs", ROOT / "src/Sollang.Compiler/Semantics/IntDictionaryLayout.cs"]
    includes = "".join('<Compile Include="' + escape(str(p), {'"': '&quot;'}) + '" />' for p in sources)
    project.write_text('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup>' + includes + '</ItemGroup></Project>', encoding="utf-8")
    inputs = [Path(__file__).resolve(), project, matrix_path, dotnet, *sources, ROOT / "scripts/verification_execution.py", ROOT / "scripts/completed_artifact_plan.py"]
    pins = {str(p): sha(p) for p in inputs}
    record = dict(schemaVersion=1, status="running", scope="Actual CSharp IntDictionaryLayout source arithmetic without large allocation.", provider="managed-helper-source", inputHashes=pins, completed=0, total=13, cases=[], producerBuildCount=0, producerBuildMaximum=1, caseBudgetSeconds=180, warningsAsErrors=True, claimsGoalComplete=False)
    execution = VerificationExecution(ROOT, output, record, lambda: all(Path(p).is_file() and sha(p) == h for p, h in pins.items()), sha)
    error = None
    try:
        version = execution.run([str(dotnet), "--version"], output / "dotnet-version", timeout=180)
        require(version.returncode == 0 and not version.stderr, "DICTIONARY_ARITHMETIC_DOTNET_VERSION")
        record["dotnetVersion"] = version.stdout.strip()
        record["producerBuildCount"] = 1
        built = execution.run([str(dotnet), "build", str(project), "-c", "Release", "--nologo", "--disable-build-servers", "-nodeReuse:false", "-p:UseSharedCompilation=false"], output / "build", timeout=180)
        # The project treats compiler warnings as errors. Do not parse localized SDK prose.
        require(built.returncode == 0 and not built.stderr, "DICTIONARY_ARITHMETIC_BUILD")
        checked = execution.run([str(dotnet), str(output / "bin/Release/net11.0/Arithmetic.dll"), str(matrix_path)], output / "run", timeout=180)
        actual = checked.stdout.strip().splitlines()
        require(checked.returncode == 0 and not checked.stderr and actual == expected, "DICTIONARY_ARITHMETIC_ORACLE")
        record.update(status="passed", completed=13, cases=[dict(id="arithmetic-" + str(i), status="passed", passed=True, buildExit=0, runExit=0, expected=v, actual=actual[i]) for i, v in enumerate(expected)])
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    if record["status"] == "passed" and record["inputsStable"] and record["processesStopped"]:
        cleanup_output(ROOT, output, execute=True, reusable_directories=retained)
    print(json.dumps({k: record.get(k) for k in ["status", "provider", "completed", "total", "inputsStable", "processesStopped", "failure"]}))
    return 0 if record["status"] == "passed" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["managed-arithmetic", "slg-geometry"], default="slg-geometry")
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--semantic-proof", type=Path)
    parser.add_argument("--source-comparison", type=Path)
    parser.add_argument("--format-compiler", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--producer-preparation-plan", type=Path,
                        help="Explicit preparation-only budget; individual arithmetic executions remain 180 seconds")
    parser.add_argument("--llvm", type=Path, default=ROOT / ".tools/llvm-22.1.8")
    parser.add_argument("--reusable-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    output, llvm = args.output.resolve(), args.llvm.resolve()
    retained = [p.absolute() for p in args.reusable_directory]
    matrix_path, manifest = PROBE / "arithmetic.json", PROBE / "geometry.sources.txt"
    matrix = read(matrix_path)
    rows = matrix["rows"]
    require(matrix["schemaVersion"] == 1 and len(rows) == 12, "DICTIONARY_GEOMETRY_MATRIX_SCOPE")
    for row in rows:
        require(all(type(row[k]) is int for k in ["length", "hint", "capacity", "entriesOffset", "allocationBytes"]), "DICTIONARY_GEOMETRY_MATRIX_TYPES")
        require(0 <= row["length"] <= 2147483647 and row["hint"] in (-1, 0), "DICTIONARY_GEOMETRY_INPUT_RANGE")
        require(0 < row["capacity"] <= 4294967296 and 0 < row["allocationBytes"] < 2**63, "DICTIONARY_GEOMETRY_EXPECTATION_RANGE")
    expected = [",".join(str(row[k]) for k in ["length", "capacity", "entriesOffset", "allocationBytes"]) for row in rows]
    expected += [f"layout={matrix['expectedValueOffset']},{matrix['expectedStride']},{matrix['expectedAlignment']}"]
    if args.mode == "managed-arithmetic":
        return managed_arithmetic(args, output, retained, matrix_path, expected)
    require(all(p is not None for p in [args.compiler, args.managed_proof, args.semantic_proof, args.source_comparison, args.format_compiler]), "DICTIONARY_GEOMETRY_ARGUMENTS")
    compiler = args.compiler.resolve()
    names = manifest.read_text(encoding="utf-8-sig").splitlines()
    original = (ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt").read_text(encoding="utf-8-sig").splitlines()
    require(names == ["scripts/probes/dictionary-storage-boundaries/geometry-emitter.slg", *original[1:]], "DICTIONARY_GEOMETRY_MANIFEST_SCOPE")
    sources = [(ROOT / name).resolve() for name in names]
    inputs = [Path(__file__).resolve(), matrix_path, manifest, PROBE / "geometry-observer.c", PROBE / "observer-contract.json", *sources, *sorted((ROOT / "stdlib").rglob("*.slg")), args.format_compiler.resolve(), llvm / "bin/clang.exe", llvm / "bin/llvm-as.exe"]
    pins = {}
    for proof_path, count in [(args.managed_proof.resolve(), 13), (args.semantic_proof.resolve(), 4)]:
        proof = read(proof_path)
        require(proof["status"] == "passed" and proof["completed"] == proof["total"] == count and proof["inputsStable"] and proof["processesStopped"], "DICTIONARY_GEOMETRY_PREREQUISITE")
        if count == 13:
            covered = [ROOT / "src/Sollang.Compiler/Semantics/IntDictionaryLayout.cs", PROBE / "managed-arithmetic.cs", matrix_path]
            require(all(str(p) in proof["inputHashes"] for p in covered), "DICTIONARY_GEOMETRY_MANAGED_SCOPE")
            require(len(proof["cases"]) == 13 and all(c.get("passed") is True and c.get("actual") == value for c, value in zip(proof["cases"], expected)), "DICTIONARY_GEOMETRY_MANAGED_ORACLE")
        else:
            require(proof.get("scope") == "focused-selfhost" and proof.get("codegenInvoked") is False and all(str(p) in proof["inputHashes"] for p in sources), "DICTIONARY_GEOMETRY_SEMANTIC_SCOPE")
        for path, digest in proof["inputHashes"].items():
            require(Path(path).is_file() and sha(path) == digest.upper(), "DICTIONARY_GEOMETRY_PREREQUISITE_DRIFT:" + path)
            require(path not in pins or pins[path] == digest.upper(), "DICTIONARY_GEOMETRY_PIN_CONFLICT")
            pins[path] = digest.upper()
        inputs.append(proof_path)
    comparison = read(args.source_comparison)
    require(comparison["status"] == "compared-before-slg-edit", "DICTIONARY_GEOMETRY_SOURCE_COMPARISON")
    require(Path(comparison["managedFirstRecord"]).resolve() == args.managed_proof.resolve(), "DICTIONARY_GEOMETRY_COMPARISON_BASELINE")
    require(sha(ROOT / comparison["managedSource"]) == comparison["managedSourceSha256"] and all(sha(ROOT / name) == digest for name, digest in comparison["selfhostSources"].items()), "DICTIONARY_GEOMETRY_COMPARISON_DRIFT")
    inputs.append(args.source_comparison.resolve())
    preparation_budget = 180
    if args.producer_preparation_plan is not None:
        plan_path = args.producer_preparation_plan.resolve()
        plan = read(plan_path)
        require(plan["schemaVersion"] == 1 and plan["scope"] == "dictionary-geometry-producer-preparation"
                and plan["programCaseBudgetSeconds"] == 180
                and plan["producerPreparationBudgetSeconds"] == 1200
                and plan["maximumProducerBuilds"] == 1
                and plan["manifestSha256"] == sha(manifest)
                and plan["matrixSha256"] == sha(matrix_path)
                and plan["producerSourceSha256"] == sha(PROBE / "geometry-emitter.slg"),
                "DICTIONARY_GEOMETRY_PREPARATION_AUTHORITY")
        preparation_budget = plan["producerPreparationBudgetSeconds"]
        inputs.append(plan_path)
    managed = args.build is None
    if managed:
        inputs += managed_runtime_inputs(compiler)
    else:
        require(args.build is not None and compiler == args.build.resolve() / "compiler.exe", "DICTIONARY_GEOMETRY_NATIVE_PRODUCT")
        build = read(args.build / "result.json")
        require(build["status"] == "passed" and build["inputsStable"] and sha(compiler) == build["compilerSha256"], "DICTIONARY_GEOMETRY_NATIVE_IDENTITY")
        inputs += [compiler, args.build.resolve() / "result.json", *current_build_inputs(ROOT, build)]
    for name in ["verification_execution.py", "completed_artifact_plan.py", "verification_source_proof.py", "verification_fingerprints.py"]:
        inputs.append(ROOT / "scripts" / name)
    for path in inputs:
        require(path.is_file(), "DICTIONARY_GEOMETRY_INPUT_MISSING:" + str(path))
        pins[str(path)] = sha(path)
    initialize_output(ROOT, output, reusable_directories=retained)
    output.mkdir(exist_ok=False)
    header = output / "dictionary_geometry_expected.h"
    table = "\n".join("    {" + str(r["length"]) + ", UINT64_C(" + str(r["capacity"]) + "), UINT64_C(" + str(r["entriesOffset"]) + "), UINT64_C(" + str(r["allocationBytes"]) + ")}," for r in rows)
    header.write_text("struct ExpectedRow { int32_t length; uint64_t capacity, offset, bytes; };\nstatic const struct ExpectedRow expected_rows[] = {\n" + table + "\n};\nstatic const size_t expected_count = 12;\n" + f"static const int expected_value_offset = {matrix['expectedValueOffset']};\nstatic const int expected_stride = {matrix['expectedStride']};\nstatic const int expected_alignment = {matrix['expectedAlignment']};\n", encoding="utf-8")
    pins[str(header)] = sha(header)
    record = dict(schemaVersion=1, status="running", scope="Actual SLG Int dictionary capacity and emitted LLVM arithmetic with explicit nonallocating observers; includes a rejected offset mutation. This does not prove real large allocation, allocation placement, whole compiler or Stage acceptance.", provider="managed-compiled-slg-source" if managed else "native-compiled-slg-source", inputHashes=pins, completed=0, total=14, cases=[], producerBuildCount=0, producerBuildMaximum=1, caseBudgetSeconds=180, producerPreparationBudgetSeconds=preparation_budget, usesAllocatorObservers=True, claimsLargeAllocationPassed=False, claimsGoalComplete=False)
    execution = VerificationExecution(ROOT, output, record, lambda: all(Path(p).is_file() and sha(p) == h for p, h in pins.items()), sha)
    error = None
    def run(command, label):
        return execution.run([str(p) for p in command], output / label,
                             timeout=preparation_budget if label == "producer-build" else 180)
    try:
        tools = run([llvm / "bin/clang.exe", "--version"], "clang-version")
        require(tools.returncode == 0 and "22.1.8" in tools.stdout, "DICTIONARY_GEOMETRY_LLVM_VERSION")
        formatted = run([args.format_compiler, "format", "--check", sources[0]], "format")
        require(formatted.returncode == 0 and not formatted.stderr, "DICTIONARY_GEOMETRY_FORMAT")
        producer = output / "emitter.exe"
        record["producerBuildCount"] = 1
        built = run([compiler, "build", *sources, "-o", producer, "--target", "windows-x64", "--keep-temps", "--llvm", llvm, "-O1", "--jobs", "4", *([] if managed else ["--stdlib", ROOT / "stdlib"])], "producer-build")
        require(built.returncode == 0 and not built.stderr, "DICTIONARY_GEOMETRY_PRODUCER_BUILD")
        emitted = run([producer], "emission")
        require(emitted.returncode == 0 and not emitted.stderr, "DICTIONARY_GEOMETRY_EMISSION")
        raw = emitted.stdout.replace("\r\n", "\n")
        require(raw.count("call ptr @malloc(") == 12 and raw.count("call void @llvm.memset.p0.i64(") == 12, "DICTIONARY_GEOMETRY_ALLOCATION_SHAPE")
        original_ll = output / "original.ll"
        original_ll.write_text(raw, encoding="utf-8")
        assembled = run([llvm / "bin/llvm-as.exe", original_ll, "-o", output / "original.bc"], "original-assemble")
        require(assembled.returncode == 0 and not assembled.stderr, "DICTIONARY_GEOMETRY_ORIGINAL_LLVM")
        instrumented = raw.replace("@malloc(", "@dict_test_allocate(").replace("@llvm.memset.p0.i64(", "@dict_test_zero(")
        audit_ll = output / "observed.ll"
        audit_ll.write_text(instrumented, encoding="utf-8")
        executable = output / "observed.exe"
        def link(source, destination, label):
            linked = run([llvm / "bin/clang.exe", "-Wno-override-module", "-Wall", "-Wextra", "-Werror", source, PROBE / "geometry-observer.c", "-I", output, "-O1", "-o", destination], label)
            require(linked.returncode == 0 and not linked.stderr, "DICTIONARY_GEOMETRY_LINK:" + label)
        link(audit_ll, executable, "observed-link")
        observed = run([executable], "observed-run")
        actual = observed.stdout.strip().splitlines()
        require(observed.returncode == 0 and not observed.stderr and actual == expected, "DICTIONARY_GEOMETRY_ORACLE")
        record["cases"] = [dict(id="arithmetic-" + str(i), status="passed", passed=True, buildExit=0, runExit=0, expected=v, actual=actual[i]) for i, v in enumerate(expected)]
        record["completed"] = 13
        needle = "  %g0_values = getelementptr i8, ptr %g0_keys, i64 4"
        require(instrumented.count(needle) == 1, "DICTIONARY_GEOMETRY_MUTATION_TARGET")
        negative = output / "wrong-offset.ll"
        negative.write_text(instrumented.replace(needle, needle[:-1] + "8", 1), encoding="utf-8")
        negative_exe = output / "wrong-offset.exe"
        link(negative, negative_exe, "negative-link")
        rejected = run([negative_exe], "negative-run")
        require(rejected.returncode == 17 and rejected.stderr.strip() == "dictionary-geometry:mismatch:0:values" and not rejected.stdout, "DICTIONARY_GEOMETRY_MUTATION_NOT_REJECTED")
        record["cases"].append(dict(id="reject-wrong-value-offset", status="passed", passed=True, buildExit=0, runExit=17, expectedRuntimeExit=17, mutationScope="audit LLVM only; production source and golden data unchanged"))
        record.update(status="passed", completed=14, originalLlvmSha256=sha(original_ll), observedLlvmSha256=sha(audit_ll), negativeLlvmSha256=sha(negative))
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    if record["status"] == "passed" and record["inputsStable"] and record["processesStopped"]:
        cleanup_output(ROOT, output, execute=True, reusable_directories=retained)
    print(json.dumps({k: record.get(k) for k in ["status", "provider", "completed", "total", "inputsStable", "processesStopped", "failure"]}))
    return 0 if record["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
