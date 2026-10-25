"""Run the approved private session-start C contract on current SLG emission."""

import argparse
import hashlib
import json
import re
from pathlib import Path

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution

ROOT = Path(__file__).resolve().parent.parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path,
                        default=ROOT / "scripts/contracts/async-diagnostic-session-start.json")
    parser.add_argument("--producer-proof", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    contract_path, proof_path = args.contract.resolve(), args.producer_proof.resolve()
    contract, proof = read(contract_path), read(proof_path)
    if (contract.get("schemaVersion") != 1 or contract.get("status") != "approved"
            or contract.get("sessionBytes") != 48 or contract.get("controlCount") != 9
            or contract.get("caseTimeoutSeconds") != 180
            or contract.get("linkOptimization") != "-O0"
            or contract.get("expectedStdout") != "diagnostic-start-boundaries=9\n"
            or len(set(contract.get("controls", []))) != 9):
        raise ValueError("ASYNC_START_APPROVED_LAYOUT_CONTRACT_REQUIRED")
    fixture = (ROOT / contract["fixture"]).resolve()
    if not fixture.is_relative_to(ROOT) or sha(fixture) != contract["fixtureSha256"]:
        raise ValueError("ASYNC_START_FIXTURE_CHANGED")
    if (proof.get("status") != "passed" or not proof.get("inputsStable")
            or not proof.get("processesStopped") or proof.get("activeProcess")):
        raise ValueError("ASYNC_START_CURRENT_PRODUCER_REQUIRED")
    builds = [p["command"] for p in proof["processes"]
              if len(p["command"]) > 2 and p["command"][1] == "build" and "-o" in p["command"]]
    if len(builds) != 1:
        raise ValueError("ASYNC_START_PRODUCER_BUILD_IDENTITY")
    build = builds[0]
    producer = Path(build[build.index("-o") + 1]).resolve()
    module = Path(str(producer) + ".ll")
    with module.open(encoding="utf-8-sig") as source:
        target = next((line.strip() for line in source if line.startswith("target triple =")), None)
    if target != 'target triple = "x86_64-pc-windows-msvc"':
        raise ValueError("ASYNC_START_WINDOWS_X64_PRODUCER_REQUIRED")
    manifest = ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
    canonical = [(ROOT / line.strip()).resolve() for line in
                 manifest.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    sources = [Path(p).resolve() for p in build[2:build.index("-o")]]
    if len(sources) != 151 or sources[1:] != canonical[1:]:
        raise ValueError("ASYNC_START_CANONICAL_SOURCE_CLOSURE")
    generated = proof["generatedOutputHashes"]
    for path in (producer, module):
        if generated.get(str(path)) != sha(path):
            raise ValueError("ASYNC_START_PRODUCER_OUTPUT_CHANGED")
    llvm_as = ROOT / ".tools/llvm-22.1.8/bin/llvm-as.exe"
    clang = ROOT / ".tools/llvm-22.1.8/bin/clang.exe"
    pins = dict(proof["inputHashes"])
    for path in (contract_path, proof_path, fixture, producer, module, manifest,
                 Path(__file__).resolve(), llvm_as, clang):
        pins[str(path)] = sha(path)
    stable = lambda: all(Path(p).is_file() and sha(p) == value for p, value in pins.items())
    with VerificationContractLease(list(map(Path, pins))):
        if not stable():
            raise ValueError("ASYNC_START_INPUT_CHANGED_BEFORE_EXECUTION")
        output = args.output.resolve()
        initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
        output.mkdir(exist_ok=False)
        record = dict(schemaVersion=1, status="running", completed=0, total=9,
                      inputHashes=pins, cases=[], approvedContract=str(contract_path),
                      producerBuilds=0, sessionBytes=48, claimsOriginal40ProbePassed=False,
                      compilerSourceChanged=False, claimsGoalComplete=False)
        execution = VerificationExecution(ROOT, output, record, stable, sha)
        error = None
        try:
            emitted = execution.run([str(producer), "x" * 21], output / "runtime-source", timeout=180)
            if emitted.returncode != 0 or emitted.stderr:
                raise ValueError("ASYNC_START_CURRENT_SOURCE_EMISSION_FAILED")
            text = (output / "runtime-source.stdout").read_text(encoding="utf-8-sig")
            start = text.index("define internal { ptr, i32 } @sollang_diagnostic_start(")
            end = text.index("\n}", start) + 2
            body = text[start:end]
            if body.count("@malloc(") != 1:
                raise ValueError("ASYNC_START_ALLOCATOR_HOOK_SHAPE")
            global_line = next(line for line in text.splitlines()
                               if line.startswith("@sollang_diagnostic_next_session_id ="))
            headers = [line for line in module.read_text(encoding="utf-8-sig").splitlines()
                       if line.startswith("target ") or re.match(r"^%[^ ]+ = type ", line)]
            # Only the original allocator-failure hook and C ABI accessors are added.
            # The actual production start body and session-ID global remain visible.
            body = body.replace("@malloc(", "@diagnostic_test_alloc(")
            glue = """
declare ptr @diagnostic_test_alloc(i64)
define ptr @diagnostic_start_probe(i32 %capacity, ptr %error) {
entry:
  %pair = call { ptr, i32 } @sollang_diagnostic_start(i32 %capacity)
  %session = extractvalue { ptr, i32 } %pair, 0
  %status = extractvalue { ptr, i32 } %pair, 1
  store i32 %status, ptr %error, align 4
  ret ptr %session
}
define void @diagnostic_set_next_id(i64 %id) {
entry:
  store i64 %id, ptr @sollang_diagnostic_next_session_id, align 8
  ret void
}
define i64 @diagnostic_get_next_id() {
entry:
  %id = load i64, ptr @sollang_diagnostic_next_session_id, align 8
  ret i64 %id
}
"""
            llvm = output / "runtime.ll"
            llvm.write_text("\n".join(headers) + "\n" + global_line + "\n" + body + "\n" + glue,
                            encoding="utf-8")
            record["productionRuntimeSha256"] = sha(output / "runtime-source.stdout")
            record["derivedRuntimeSha256"] = sha(llvm)
            execution.save()
            commands = [
                ("assemble", [str(llvm_as), str(llvm), "-o", str(output / "runtime.bc")]),
                ("link", [str(clang), str(llvm), str(fixture), "-O0", "-Wno-override-module",
                          "-o", str(output / "runtime.exe")]),
                ("run", [str(output / "runtime.exe")]),
            ]
            for name, command in commands:
                result = execution.run(command, output / name, timeout=180)
                if result.returncode != 0 or result.stderr:
                    raise ValueError("ASYNC_START_" + name.upper() + "_FAILED")
            actual = (output / "run.stdout").read_bytes().replace(b"\r\n", b"\n")
            if actual != contract["expectedStdout"].encode("utf-8"):
                raise ValueError("ASYNC_START_ORIGINAL_CONTROL_OUTPUT_CHANGED")
            record.update(status="passed", completed=9,
                          cases=[dict(id=name, status="passed", passed=True)
                                 for name in contract["controls"]])
        except BaseException as caught:
            error = caught
        finally:
            execution.finalize(error, cleanup=False)
        print(json.dumps({key: record.get(key) for key in
                          ("status", "completed", "total", "inputsStable", "processesStopped", "failure")}))
        return 0 if record["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
