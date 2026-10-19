"""Compare malformed UTF-8 diagnostic locations across source newline forms."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--managed", type=Path, required=True)
    parser.add_argument("--selfhost", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    if managed == selfhost:
        parser.error("compilers must be separate artifacts")
    runtime = [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs = [managed, selfhost, Path(__file__).resolve(), *runtime]
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    cases = (
        ("bare-cr", b"main {\r\xff}\n", 2, 1),
        ("crlf", b"main {\r\n\xff}\n", 2, 1),
        ("emoji-cr", b'main { "' + "🙂".encode() + b'"\r\xff}\n', 2, 1),
        ("lf-control", b"main {\n\xff}\n", 2, 1),
    )
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, source, line, column in cases:
            row = {"id": case_id, "inputSha256": hashlib.sha256(source).hexdigest().upper()}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                run = subprocess.run([str(compiler), "format", "--stdin"], input=source, capture_output=True, timeout=30, cwd=ROOT)
                (output / f"{case_id}-{label}.stderr").write_bytes(run.stderr)
                row[label] = {
                    "exitCode": run.returncode,
                    "stdout": run.stdout.decode("utf-8", "replace").replace("\r\n", "\n"),
                    "stderr": run.stderr.decode("utf-8", "replace").replace("\r\n", "\n"),
                }
            row["passed"] = row["managed"] == row["selfhost"] == {
                "exitCode": 1,
                "stdout": "",
                "stderr": f"sollang: lex error at {line}:{column}: unexpected character '�'\n",
            }
            result["cases"].append(row)
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(result["cases"]) == len(cases) and all(row["passed"] for row in result["cases"]) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[C493 UTF-8 newline] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
