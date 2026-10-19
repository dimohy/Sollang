"""Require current SLG semantic evidence for the complete stdlib before a build."""
import argparse
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def compiler_manifest_inputs(repo, selected_manifest=None):
    """Resolve the canonical closure before execution and after proof capture."""
    repo = Path(repo).resolve()
    canonical = repo / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
    selected = canonical if selected_manifest is None else Path(selected_manifest)
    if not selected.is_absolute():
        selected = repo / selected
    selected = selected.resolve()

    def sources(manifest):
        if not manifest.is_relative_to(repo) or not manifest.is_file():
            raise ValueError("STDLIB_SOURCE_PREFLIGHT_MANIFEST_INVALID")
        paths = [(repo / line.strip()).resolve() for line in
                 manifest.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
        if (not paths or len(set(paths)) != len(paths)
                or any(not path.is_relative_to(repo) or not path.is_file() for path in paths)):
            raise ValueError("STDLIB_SOURCE_PREFLIGHT_MANIFEST_INVALID")
        return paths

    canonical_sources = sources(canonical)
    selected_sources = sources(selected)
    if selected_sources != canonical_sources:
        raise ValueError("STDLIB_SOURCE_PREFLIGHT_MANIFEST_SCOPE_MISMATCH")
    return canonical, canonical_sources, list(dict.fromkeys([canonical, selected]))


def validate(repo, proof_path):
    proof = json.loads(proof_path.read_text(encoding="utf-8-sig"))
    def require(condition, failure):
        if not condition:
            raise ValueError(failure)
    require(proof.get("scope") == "owned-index-full-stdlib-source",
            "STDLIB_SOURCE_PREFLIGHT_SCOPE")
    require(proof.get("status") == "passed" and proof.get("completed") == 1
            and proof.get("total") == 1 and proof.get("inputsStable") is True
            and proof.get("processesStopped") is True,
            "STDLIB_SOURCE_PREFLIGHT_INCOMPLETE")
    require(proof.get("diagnosticSourceModule") == -1,
            "STDLIB_SOURCE_PREFLIGHT_DIAGNOSTIC")
    require(type(proof.get("checkedSemanticDiagnosticCount")) is int
            and proof["checkedSemanticDiagnosticCount"] == 0,
            "STDLIB_SOURCE_PREFLIGHT_CHECKED_SEMANTIC_DIAGNOSTIC")
    stdlib = sorted((repo / "stdlib").rglob("*.slg"))
    require(bool(stdlib) and proof.get("fullStdlibSourceCount") == len(stdlib),
            "STDLIB_SOURCE_PREFLIGHT_SOURCE_COUNT")
    require(type(proof.get("activeStdlibBodyCount")) is int
            and proof["activeStdlibBodyCount"] > 0,
            "STDLIB_SOURCE_PREFLIGHT_ACTIVE_BODIES")
    require(type(proof.get("packageSourceCount")) is int
            and proof["packageSourceCount"] > len(stdlib),
            "STDLIB_SOURCE_PREFLIGHT_PACKAGE_COUNT")
    def pinned(values):
        require(isinstance(values, dict) and bool(values),
                "STDLIB_SOURCE_PREFLIGHT_HASHES_MISSING")
        result = {}
        for name, expected in values.items():
            path = Path(name)
            if not path.is_absolute():
                path = repo / path
            path = path.resolve()
            require(path.is_file() and isinstance(expected, str)
                    and sha(path) == expected.upper(),
                    "STDLIB_SOURCE_PREFLIGHT_INPUT_DRIFT: " + str(path))
            result[path] = expected.upper()
        return result
    inputs = pinned(proof.get("inputHashes"))
    sources = pinned(proof.get("compilerSourceHashes"))
    execution_path = Path(proof.get("executionResult", ""))
    stdout_path = Path(proof.get("executionStdout", ""))
    if not execution_path.is_absolute():
        execution_path = repo / execution_path
    if not stdout_path.is_absolute():
        stdout_path = repo / stdout_path
    execution_path, stdout_path = execution_path.resolve(), stdout_path.resolve()
    require(execution_path in inputs and stdout_path in inputs,
            "STDLIB_SOURCE_PREFLIGHT_EXECUTION_MISSING")
    execution = json.loads(execution_path.read_text(encoding="utf-8-sig"))
    require(execution.get("status") == "passed" and execution.get("completed") == 1
            and execution.get("total") == 1 and execution.get("inputsStable") is True
            and execution.get("processesStopped") is True,
            "STDLIB_SOURCE_PREFLIGHT_EXECUTION_INCOMPLETE")
    cases = execution.get("cases", [])
    require(len(cases) == 1 and cases[0].get("passed") is True
            and cases[0].get("buildExit") == 0 and cases[0].get("runExit") == 0,
            "STDLIB_SOURCE_PREFLIGHT_NOT_EXECUTED")
    require(cases[0].get("buildStderr") == "" and cases[0].get("runStderr") == "",
            "STDLIB_SOURCE_PREFLIGHT_UNEXPECTED_STDERR")
    stdout = stdout_path.read_text(encoding="utf-8-sig").strip()
    require(cases[0].get("runStdout") == stdout,
            "STDLIB_SOURCE_PREFLIGHT_STDOUT_CONFLICT")
    observed = json.loads(stdout)
    counters = ("diagnosticSourceModule", "fullStdlibSourceCount", "packageSourceCount",
                "activeStdlibBodyCount", "stdlibBodyCount", "inactiveStdlibBodyCount",
                "checkedSemanticDiagnosticCount")
    require(all(key in proof and observed.get(key) == proof[key] for key in counters),
            "STDLIB_SOURCE_PREFLIGHT_OBSERVATION_CONFLICT")
    require(type(proof["stdlibBodyCount"]) is int and type(proof["inactiveStdlibBodyCount"]) is int
            and proof["inactiveStdlibBodyCount"] >= 0
            and proof["stdlibBodyCount"] == proof["activeStdlibBodyCount"] + proof["inactiveStdlibBodyCount"],
            "STDLIB_SOURCE_PREFLIGHT_BODY_COVERAGE")
    execution_inputs = pinned(execution.get("inputHashes"))
    require(all(inputs.get(path) == expected for path, expected in execution_inputs.items()),
            "STDLIB_SOURCE_PREFLIGHT_EXECUTION_INPUTS_MISSING")
    manifest, compiler, _ = compiler_manifest_inputs(repo)
    require(manifest.resolve() in inputs and all(path.resolve() in inputs for path in stdlib)
            and all(path in sources and path in inputs for path in compiler)
            and all(path.resolve() in execution_inputs for path in stdlib)
            and all(path in execution_inputs for path in compiler),
            "STDLIB_SOURCE_PREFLIGHT_CLOSURE_MISSING")
    return {"status": "passed", "fullStdlibSourceCount": len(stdlib),
            "activeStdlibBodyCount": proof["activeStdlibBodyCount"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--proof", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(validate(args.repo.resolve(), args.proof.resolve())))
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "failed", "failureId": str(error)}))
        raise SystemExit(1)
