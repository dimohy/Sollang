"""Audit source-decision associations without changing phase-execution authority."""

import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "structural_detail", Path(__file__).with_name("verify-structural-parity-detail.py"))
DETAIL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DETAIL)
PHASE_SCOPES = DETAIL.PHASE_SCOPES
require = DETAIL.require
validate_decision_source_scope = DETAIL.validate_decision_source_scope


def phase_source_files(root, phase, inventory, side, extension):
    """Resolve the frozen source inventory for both intake and promotion."""
    require(inventory["sourceScopes"] == PHASE_SCOPES[phase],
            "phase source scope cannot be narrowed")
    root = root.resolve()
    sources = set()
    prefixes = ("src/Sollang.Compiler/", "src/Sollang.Compiler.Generators/") if side == "managed" else ("selfhost/",)
    for scope in inventory["sourceScopes"][side]:
        path = (root / scope).resolve()
        require(path.is_relative_to(root) and path.exists(), "invalid source scope")
        require(path.relative_to(root).as_posix().startswith(prefixes),
                "source scope belongs to the wrong compiler")
        candidates = [path] if path.is_file() else path.rglob("*" + extension)
        sources.update(p.relative_to(root).as_posix() for p in candidates
                       if p.is_file() and p.suffix == extension)
    require(bool(sources), f"empty {side} source scope")
    return sources


def audit_source_connections(detail, root):
    """Measure named source links; never grant execution or phase credit."""
    rows = detail["phaseProgress"]
    require([row["phase"] for row in rows] == list(PHASE_SCOPES),
            "phase inventory must retain all seven phases")
    phases = []
    for row in rows:
        phase, inventory = row["phase"], row["decisionInventory"]
        decisions = inventory["decisions"]
        ids = [decision["id"] for decision in decisions]
        required = inventory["requiredDecisionIds"]
        require(len(ids) == len(set(ids)) and len(required) == len(set(required)),
                "duplicate decision identity")
        require(set(ids) == set(required), "required decision inventory differs")
        coverage = {}
        for side, extension in detail["promotionRequirements"]["sourceExtensions"].items():
            sources = phase_source_files(root, phase, inventory, side, extension)
            named = set()
            for decision in decisions:
                require(decision["status"] in ("pending", "complete"), "invalid decision status")
                for field in detail["promotionRequirements"]["decisionFields"]:
                    require(isinstance(decision.get(field), str) and bool(decision[field].strip()),
                            f"missing decision comparison: {field}")
                links = decision.get(side + "Sources")
                require(isinstance(links, list) and all(isinstance(name, str) for name in links),
                        "invalid decision source list")
                require(len(links) == len(set(links)), "duplicate decision source")
                validate_decision_source_scope(links, sources)
                named.update(links)
            coverage[side] = {"actual": len(sources), "named": len(named),
                              "missing": sorted(sources - named), "outOfScope": []}
        if phase != "parsing":
            phases.append({"phase": phase, "inventoryStatus": inventory["status"],
                           "registeredDecisions": len(decisions), "coverage": coverage,
                           "sourceConnectionsComplete": all(not value["missing"] for value in coverage.values())})
    return {"schemaVersion": 1, "status": "measured-source-connection-intake-not-phase-qualification",
            "observedAtUtc": datetime.now(timezone.utc).isoformat(),
            "completed": sum(phase["sourceConnectionsComplete"] for phase in phases),
            "total": len(phases), "phases": phases, "compilerExecutions": 0,
            "claimsPhaseComplete": False, "claimsGoalComplete": False}


if __name__ == "__main__":
    path = DETAIL.ROOT / "scripts/contracts/structural-parity-detail.json"
    detail = DETAIL.read("scripts/contracts/structural-parity-detail.json")
    audit = audit_source_connections(detail, DETAIL.ROOT)
    audit["authority"] = {"path": path.relative_to(DETAIL.ROOT).as_posix(), "sha256": DETAIL.file_hash(path)}
    audit["validator"] = {"path": "scripts/verify-structural-parity-detail.py", "sha256": DETAIL.file_hash(Path(SPEC.origin))}
    print(json.dumps(audit, indent=2))
