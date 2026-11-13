"""Source-only preflight and support-aware context for new phase executions.

Legacy parsing records retain their original producer. New consumers use the
same strict decision authority, including cross-phase supporting sources.
"""
import argparse
import importlib.util
import json
import sys
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "phase_authority", Path(__file__).with_name("verify-structural-parity-detail.py"))
authority = importlib.util.module_from_spec(spec)
spec.loader.exec_module(authority)
require = authority.require


def read(path):
    if str(path) == "-":
        return json.load(sys.stdin)
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def hashes(root, names):
    return {name: authority.file_hash(authority.phase_path(root, name)).upper() for name in sorted(names)}


def source_sets(root, phase, inventory):
    root = root.resolve()
    require(phase != "parsing", "parsing must retain its generation-aware legacy producer")
    require(inventory["sourceScopes"] == authority.PHASE_SCOPES[phase], "phase source scope cannot be narrowed")
    decisions = inventory["decisions"]
    ids = [item["id"] for item in decisions]
    required = inventory["requiredDecisionIds"]
    require(bool(ids) and len(ids) == len(set(ids)) and ids == required,
            "required decision inventory differs")
    primary, expanded = {}, {}
    for side, extension in (("managed", ".cs"), ("selfhost", ".slg")):
        sources = set()
        for scope in inventory["sourceScopes"][side]:
            path = (root / scope).resolve()
            require(path.is_relative_to(root) and path.exists(), "invalid source scope")
            require(authority.source_scope_belongs_to_compiler(
                path.relative_to(root).as_posix(), phase, side), "source scope belongs to the wrong compiler")
            candidates = [path] if path.is_file() else path.rglob("*" + extension)
            for item in candidates:
                if item.is_file() and item.suffix == extension:
                    require(item.resolve().is_relative_to(root), "source escapes repository")
                    sources.add(item.relative_to(root).as_posix())
        require(bool(sources), "empty source scope")
        covered, supporting = set(), set()
        for decision in decisions:
            require(decision["status"] == "complete", "pending phase decision")
            for field in ("structure", "branches", "logic", "diagnostics"):
                require(isinstance(decision.get(field), str) and bool(decision[field].strip()),
                        "missing decision comparison: " + field)
            named = decision[side + "Sources"]
            authority.validate_decision_source_scope(named, sources)
            covered.update(named)
            supporting.update(authority.supporting_decision_sources(decision, side, sources, root, phase))
        require(covered == sources, "unreviewed " + side + " sources")
        primary[side] = hashes(root, sources)
        expanded[side] = hashes(root, sources | supporting)
    return primary, expanded


def validate_build(root, phase, side, build, expected, binary=None):
    build = authority.normalize_phase_digest_fields(build)
    require(build.get("status") == "passed" and build.get("phase") == phase
            and build.get("compilerSide") == side and build.get("inputStable") is True
            and build.get("exitCode") == 0 and build.get("canceled") is False
            and build.get("failureIds") == [] and build.get("orphanProcessIds") == []
            and build.get("completed") == build.get("total") == 1, "invalid phase build view")
    require(build.get("sourceHashesStart") == expected
            and build.get("sourceHashesEnd") == expected, "phase build source membership or hash differs")
    actual = build["binary"]
    path = (root / actual["path"]).resolve()
    require(path.is_relative_to(root.resolve()) and path.is_file(), "invalid compiler path")
    require(authority.file_hash(path).upper() == actual["sha256"], "compiler binary drift")
    if binary is not None:
        require(actual == authority.normalize_phase_digest_fields(binary), "phase build binary differs")
    birth_ref = build["actualBuildRecord"]
    birth_path = authority.phase_path(root, birth_ref["path"])
    require(authority.file_hash(birth_path).upper() == birth_ref["sha256"], "actual build record drift")
    birth = read(birth_path)
    require(birth.get("status") == "passed" and birth.get("inputsStable") is True
            and birth.get("processesStopped") is True, "actual build not successfully closed")
    require(birth.get("generatedOutputHashes", {}).get(str(path), "").upper() == actual["sha256"],
            "binary absent from actual build products")
    provenance = build.get("sourceProvenance", {})
    require(set(provenance) == set(expected), "build provenance source membership differs")
    for name, digest in expected.items():
        item = provenance[name]
        require(item.get("method") == "direct-build-input" and item.get("record") == birth_ref,
                "source has no direct build provenance")
        require(item.get("inputKey") == str((root / name).resolve())
                and birth.get("inputHashes", {}).get(item["inputKey"], "").upper() == digest,
                "source was not an actual build input")


def runtime_inputs(root, inventory):
    references = inventory.get("runtimeInputs", [])
    require(isinstance(references, list), "runtime inputs must be a list")
    result = {}
    for reference in references:
        require(isinstance(reference, dict) and set(reference) == {"path", "sha256"}
                and isinstance(reference["path"], str) and isinstance(reference["sha256"], str),
                "invalid runtime input reference")
        path = authority.phase_path(root, reference["path"])
        require(path.is_relative_to(root.resolve()), "runtime input leaves repository")
        name = path.relative_to(root.resolve()).as_posix()
        require(name not in result, "duplicate runtime input")
        digest = authority.file_hash(path).upper()
        require(digest == reference["sha256"].upper(), "runtime input drift")
        result[name] = digest
    return result


def enrich(root, context, runner):
    root = root.resolve()
    phase, side = context["Contract"]["phase"], context["CompilerSide"]
    require(Path(context["Root"]).resolve() == root, "context repository differs")
    contract = context["Contract"]
    reference = contract["reviewedInventory"]
    require(authority.file_hash(root / reference["path"]).upper() == reference["sha256"].upper(),
            "reviewed inventory drift")
    inventory = read(root / reference["path"])
    require(inventory.get("status") == "reviewed" and inventory.get("phase") == phase,
            "unreviewed phase inventory")
    primary, expanded = source_sets(root, phase, inventory)
    base = authority.normalize_phase_digest_fields(context)
    require(base["SourceHashes"] == (primary["managed"] | primary["selfhost"])
            and base["SideSourceHashes"] == primary[side], "legacy context source scope differs")
    binary = contract["compilerBinaries"][side]
    build_path = root / binary["buildRecord"]
    require(authority.file_hash(build_path).upper() == binary["buildRecordSha256"].upper(),
            "phase build view drift")
    validate_build(root, phase, side, read(build_path), expanded[side], context["CompilerBinary"])
    combined = expanded["managed"] | expanded["selfhost"]
    if side == "selfhost":
        comparison_ref = context["SourceComparisonReference"]
        comparison_path = root / comparison_ref["path"]
        require(authority.file_hash(comparison_path).upper() == comparison_ref["sha256"].upper(),
                "source comparison drift")
        comparison = authority.normalize_phase_digest_fields(read(comparison_path))
        require(comparison.get("sourceHashes") == combined, "source comparison support coverage differs")
    runner = runner.resolve()
    require(runner.is_relative_to(root) and runner.is_file(), "invalid phase runner")
    standard_library = sorted((root / "stdlib").rglob("*.slg"))
    require(bool(standard_library), "selected standard library is missing or empty")
    pins = [Path(__file__), Path(authority.__file__),
            Path(__file__).with_name("context_suite_evidence.py"),
            Path(__file__).with_name("verification_build_stdout.py"),
            Path(__file__).with_name("verification_source_proof.py"),
            Path(__file__).with_name("completed_artifact_plan.py"), runner, *standard_library]
    inputs = dict(context["InputHashes"])
    for name, digest in (combined | runtime_inputs(root, inventory)).items():
        require(name not in inputs or inputs[name].upper() == digest, "source input drift")
        inputs[name] = digest
    for path in pins:
        inputs[path.resolve().relative_to(root).as_posix()] = authority.file_hash(path).upper()
    birth = read(build_path)["actualBuildRecord"]
    inputs[birth["path"]] = birth["sha256"]
    context.update(SourceHashes=combined, SideSourceHashes=expanded[side], InputHashes=inputs,
                   RunnerReference={"path": runner.relative_to(root).as_posix(),
                                    "sha256": authority.file_hash(runner).upper()})
    return context


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--enrich", action="store_true")
    parser.add_argument("--runner", type=Path)
    parser.add_argument("--phase", choices=authority.PHASE_SCOPES)
    parser.add_argument("--inventory", type=Path)
    parser.add_argument("--build-view", type=Path)
    parser.add_argument("--side", choices=("managed", "selfhost"))
    args = parser.parse_args()
    if args.enrich:
        require(args.runner is not None, "runner required")
        result = enrich(args.root, json.load(sys.stdin), args.runner)
    else:
        require(args.phase is not None and args.inventory is not None, "phase and inventory required")
        primary, expanded = source_sets(args.root, args.phase, read(args.inventory))
        if args.build_view:
            require(args.side is not None, "build side required")
            validate_build(args.root, args.phase, args.side, read(args.build_view), expanded[args.side])
        result = {"status": "source-scope-only", "phaseCompletionCredit": 0,
                  "primaryHashes": primary, "sourceHashes": expanded}
    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    main()
