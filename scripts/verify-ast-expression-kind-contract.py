"""Reject AST kind collisions before compiler generation."""

import json
from pathlib import Path

from ast_expression_kind_contract import validate_repository


if __name__ == "__main__":
    issues = validate_repository(Path(__file__).resolve().parent.parent)
    print(json.dumps({"status": "failed" if issues else "passed", "failureIds": issues}))
    raise SystemExit(bool(issues))
