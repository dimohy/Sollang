"""Check frozen legacy integer-input cases against an existing executable."""
import json
from pathlib import Path
import subprocess
import sys

program, contract = map(Path, sys.argv[1:])
cases = json.loads(contract.read_text(encoding="utf-8"))["cases"]
observed = []
for case in cases:
    run = subprocess.run([str(program)], input=case["input"].encode("utf-8"),
                         capture_output=True, timeout=5)
    assert (run.returncode, run.stdout, run.stderr) == (
        case["exit"], case["stdout"].encode("utf-8"), b""), (
            case["id"], run.returncode, run.stdout, run.stderr)
    observed.append({"id": case["id"], "passed": True,
                     "exit": run.returncode, "stdout": run.stdout.decode("utf-8")})
print(json.dumps({"completed": len(observed), "total": len(cases), "cases": observed}))
