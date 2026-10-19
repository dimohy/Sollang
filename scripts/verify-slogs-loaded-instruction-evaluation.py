"""Check Sollang's Slogs preference lookup and Korean status-text guard."""

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def run_guard(guard: Path, message: str) -> tuple[int, dict]:
    completed = subprocess.run(
        [sys.executable, str(guard), "lint-text"],
        input=message,
        text=True,
        encoding="utf-8",
        capture_output=True,
        check=False,
    )
    return completed.returncode, json.loads(completed.stdout)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--guard", required=True, type=Path)
    args = parser.parse_args()
    guard = args.guard.resolve()
    assert guard.is_file()

    contract = json.loads((ROOT / "scripts/contracts/slogs-loaded-instruction-evaluation.json").read_text(encoding="utf-8"))
    assert contract["schemaVersion"] == 1
    cases = {case["id"]: case for case in contract["cases"]}
    assert len(cases) == 4
    assert {case["kind"] for case in cases.values()} == {"normal", "regression", "negative"}
    assert all(case["required"] and case["forbidden"] for case in cases.values())

    instructions = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    assert "search user-wide Korean software terminology" in instructions
    assert "separately from Sollang project memory" in instructions
    assert "deterministic text" in instructions
    assert "Recheck the relevant" in instructions

    good_exit, good = run_guard(guard, "검증 기록과 빌드 출처 정보를 확인했습니다.")
    bad_exit, bad = run_guard(guard, "빌드 영수증을 확인했습니다.")
    assert good_exit == 0 and good["count"] == 0
    assert bad_exit == 1 and bad["count"] == 1
    assert bad["findings"][0]["ruleId"] == "artifact-records"

    print("[Slogs loaded-instruction evaluation] PASS 4 scenarios; preference lookup contract, text guard normal/negative")


if __name__ == "__main__":
    main()
