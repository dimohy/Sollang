"""Keep the four direct EmitContext regression fixtures in schema order."""

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = (
    "1000-selfhost-partition-route-type-invariant",
    "1100-selfhost-enum-match-variant-invariant",
    "1126-selfhost-console-emission-invariant",
    "1290-selfhost-provisional-unit-match-invariant",
)
START = "    emitterContext.EmitContext {\n"
END = "    } => context"
SPECIAL_INITIALIZERS = {
    "globalFunctionAliasDiagnostic": "calls.noGlobalFunctionAliasDiagnostic()",
    "inferredInputConflict": (
        "semanticDiagnostics.InferredInputConflictDiagnostic "
        "{ sourceModule: -1, functionSymbol: -1, firstTypeId: -1, actualTypeId: -1 }"
    ),
    "memberFieldCollision": (
        "semanticDiagnostics.MemberFieldCollisionDiagnostic "
        "{ sourceModule: -1, functionSymbol: -1, ownerType: -1 }"
    ),
}


def context_fields() -> list[tuple[str, str]]:
    text = (ROOT / "selfhost/llvm/emitter/context.slg").read_text(encoding="utf-8-sig")
    body = text.split("public struct EmitContext {", 1)[1].split("\n}", 1)[0]
    fields = re.findall(r"(?m)^    public (\w+): ([^\n]+)$", body)
    if not fields or len(fields) != len({name for name, _ in fields}):
        raise ValueError("EmitContext fields are absent or duplicated")
    return fields


def sync_fixture(path: Path, fields: list[tuple[str, str]], write: bool) -> int:
    source = path.read_text(encoding="utf-8-sig")
    before, tail = source.split(START, 1)
    body, after = tail.split(END, 1)
    lines = body.splitlines()
    keys = [match.group(1) for line in lines if (match := re.match(r"^        (\w+):", line))]
    if len(keys) != len(set(keys)):
        raise ValueError(f"duplicate initializer key: {path}")
    expected = {name for name, _ in fields}
    if set(keys) - expected:
        raise ValueError(f"unknown initializer key: {path}: {sorted(set(keys) - expected)}")
    missing = [(name, type_name) for name, type_name in fields if name not in keys]
    if not write and missing:
        raise ValueError(f"missing EmitContext fields: {path}: {[name for name, _ in missing]}")
    for name, type_name in missing:
        if type_name.startswith("["):
            initializer = "[]"
        elif name in SPECIAL_INITIALIZERS:
            initializer = SPECIAL_INITIALIZERS[name]
        else:
            raise ValueError(f"explicit initializer needed for {name}: {type_name}")
        ordinal = next(index for index, (field, _) in enumerate(fields) if field == name)
        later = {field for field, _ in fields[ordinal + 1 :]}
        insertion = next(
            (index for index, line in enumerate(lines)
             if (match := re.match(r"^        (\w+):", line)) and match.group(1) in later),
            len(lines),
        )
        lines.insert(insertion, f"        {name}: {initializer}")
    if write and missing:
        path.write_text(before + START + "\n".join(lines) + "\n" + END + after, encoding="utf-8")
    return len(missing)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    fields = context_fields()
    added = sum(sync_fixture(ROOT / "examples/regression" / f"{fixture}.slg", fields, args.write)
                for fixture in FIXTURES)
    print(f"[EmitContext fixtures] {len(FIXTURES)} fixtures, {len(fields)} fields, {added} new initializers")


if __name__ == "__main__":
    main()
