"""Capture current phase source identities; this does not establish source review."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def capture():
    definitions = runpy.run_path(str(ROOT / "scripts/verify-structural-parity-detail.py"))
    rows = []
    for phase, scopes in definitions["PHASE_SCOPES"].items():
        sides = {}
        for side, extension in (("managed", ".cs"), ("selfhost", ".slg")):
            sources = set()
            for relative in scopes[side]:
                path = (ROOT / relative).resolve()
                if not path.is_relative_to(ROOT) or not path.exists():
                    raise ValueError("PARITY_INVENTORY_SCOPE_MISSING: " + relative)
                candidates = [path] if path.is_file() else path.rglob("*" + extension)
                sources.update(p for p in candidates if p.is_file() and p.suffix == extension)
            if not sources:
                raise ValueError("PARITY_INVENTORY_EMPTY_SIDE: " + phase + "/" + side)
            sides[side] = [{"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path),
                            "reviewStatus": "pending"} for path in sorted(sources)]
        rows.append({"phase": phase, "reviewStatus": "pending", "sources": sides})
    shared = [{"path": relative, "sha256": sha(ROOT / relative)}
              for relative in definitions["PARSING_SHARED_DEPENDENCIES"]]
    return {"schemaVersion": 1, "status": "captured-unreviewed", "phaseClosure": {"completed": 0, "total": 7},
            "sourceAuthority": "scripts/verify-structural-parity-detail.py:PHASE_SCOPES",
            "scopeDefinitionSha256": sha(ROOT / "scripts/verify-structural-parity-detail.py"),
            "phases": rows, "parsingSharedDependencies": shared}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / "artifacts") or output.exists():
        raise ValueError("PARITY_INVENTORY_FRESH_ARTIFACT_OUTPUT_REQUIRED")
    inventory = capture()
    if capture() != inventory:
        raise ValueError("PARITY_INVENTORY_INPUT_DRIFT")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(inventory, indent=2) + "\n")
    print(json.dumps({"status": inventory["status"], "phases": [
        {"phase": phase["phase"], "managedFiles": len(phase["sources"]["managed"]),
         "selfhostFiles": len(phase["sources"]["selfhost"])} for phase in inventory["phases"]]}))


if __name__ == "__main__":
    main()
