#!/usr/bin/env python3
"""Check current C# and SLG imported nominal interpolation results."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-imported-struct-compiler-o1-20260929-02")
OUT = ROOT / "artifacts/scratch/c527-imported-struct-paired-20260929-01.json"
CASES = {
    "importedPositive": (
        "artifacts/scratch/c527-imported-struct-managed-first-20260929-03/result.json",
        "artifacts/scratch/c527-imported-struct-slg-focused-20260929-02/result.json",
        0, "value=5\n", None,
    ),
    "importedBadField": (
        "artifacts/scratch/c527-imported-bad-field-managed-20260929-01/result.json",
        "artifacts/scratch/c527-imported-bad-field-slg-20260929-01/result.json",
        1, None,
        "sollang: semantic error at 1:20: [module '<main>'] field 'x' expects Int, got Bool\n",
    ),
    "namespacedPositive": (
        "artifacts/scratch/c527-namespaced-struct-managed-20260929-01/result.json",
        "artifacts/scratch/c527-namespaced-struct-slg-20260929-02/result.json",
        0, "value=5\n", None,
    ),
}
FIXTURES = {
    "scripts/probes/interpolation/c527-imported-struct-literal-field.slg": "examples/regression/2112-interpolation-imported-struct-literal-field.slg",
    "scripts/probes/interpolation/c527-imported-struct-literal-bad-field.slg": "examples/regression/diagnostics/2113-interpolation-imported-struct-literal-bad-field.slg",
    "scripts/probes/interpolation/c527-imported-struct-literal-library.slg": "examples/regression/fixtures/2112-imported-interpolation-point.slg",
    "scripts/probes/interpolation/c527-namespaced-struct-literal-field.slg": "examples/regression/2114-interpolation-namespaced-struct-literal-field.slg",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    build = json.loads((BUILD / "result.json").read_text(encoding="utf-8"))
    assert build["status"] == "passed" and build["inputsStable"]
    assert build["compilerSha256"] == sha(BUILD / "compiler.exe")
    source = json.loads(text("artifacts/scratch/c527-imported-struct-source-comparison-20260929-01.json"))
    assert source["status"] == "passed"
    for probe, fixture in FIXTURES.items():
        assert text(probe) == text(fixture), (probe, fixture)
    result = {}
    for case, (managed_path, slg_path, code, stdout, stderr) in CASES.items():
        managed = json.loads(text(managed_path))
        slg = json.loads(text(slg_path))
        for name, actual in (("managed", managed), ("slg", slg)):
            if code == 0:
                assert actual["buildExit"] == actual["runExit"] == 0, (case, name)
                assert actual["runStdout"] == stdout, (case, name)
            else:
                assert actual["buildExit"] != 0, (case, name)
                assert actual["buildStderr"].replace("\r\n", "\n") == stderr, (case, name)
        result[case] = {"managed": managed_path, "slg": slg_path, "status": "passed"}
    inputs = [ROOT / path for path in FIXTURES] + [ROOT / path for path in FIXTURES.values()]
    inputs += [ROOT / path for pair in CASES.values() for path in pair[:2]]
    inputs += [ROOT / "selfhost/ir/interpolation.slg", ROOT / "selfhost/semantic/expression_type_ids.slg",
               ROOT / "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
               ROOT / "src/Sollang.Compiler/Parsing/StringLiteralParser.cs", Path(__file__)]
    hashes = {str(path): sha(path) for path in inputs}
    record = {"schemaVersion": 1, "status": "passed", "completed": len(result),
              "total": len(result), "compilerSha256": build["compilerSha256"],
              "sourceComparison": "artifacts/scratch/c527-imported-struct-source-comparison-20260929-01.json",
              "inputSha256": hashes, "cases": result, "fixturesEquivalentToProbes": True,
              "excludedRuns": ["artifacts/scratch/c527-imported-struct-slg-focused-20260929-01/result.json"]}
    assert hashes == {str(path): sha(path) for path in inputs}
    OUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUT.relative_to(ROOT)}: {len(result)}/{len(result)}")


if __name__ == "__main__":
    main()
