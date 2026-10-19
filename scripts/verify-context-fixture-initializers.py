"""Check all qualified fixture struct initializers against their source declarations."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def masked(text: str) -> str:
    # Preserve offsets and newlines while excluding string/comment punctuation.
    return re.sub(r'"(?:\\.|[^"\\])*"|#[^\n]*',
                  lambda match: re.sub(r'[^\n]', ' ', match.group()), text)


def body(text: str, start: int) -> str:
    depth = 1
    for end in range(start + 1, len(text)):
        depth += (text[end] == '{') - (text[end] == '}')
        if depth == 0:
            return text[start + 1:end]
    raise ValueError(f"CONTEXT_UNCLOSED_INITIALIZER: offset {start}")


def keys(text: str) -> list[str]:
    # Nested expressions may contain their own labels and separators.
    chars = list(text)
    depth = 0
    for index, char in enumerate(chars):
        if char in '{[(':
            depth += 1
            chars[index] = ' '
        elif char in '}])':
            depth -= 1
            chars[index] = ' '
        elif depth:
            chars[index] = '\n' if char == '\n' else ' '
    if depth:
        raise ValueError("CONTEXT_UNBALANCED_EXPRESSION")
    return re.findall(r'(?:^|[,\n])\s*(\w+)\s*:', ''.join(chars))


def verify(fixtures: list[Path], source_manifest: Path | None = None) -> dict:
    if source_manifest is not None:
        if len(fixtures) != 1:
            raise ValueError('CONTEXT_EXPLICIT_MANIFEST_REQUIRES_ONE_FIXTURE')
        source_manifest = (ROOT / source_manifest).resolve()
        if not source_manifest.is_relative_to(ROOT):
            raise ValueError('CONTEXT_SOURCE_MANIFEST_OUTSIDE_REPOSITORY')
    declarations = {}
    for fixture in fixtures:
        manifest = source_manifest or ROOT / 'examples/regression/expected' / (fixture.stem + '.sources.txt')
        sources = [ROOT / line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines()
                   if line.strip()]
        if source_manifest is not None:
            sources = [source.resolve() for source in sources]
            if any(not source.is_relative_to(ROOT) for source in sources):
                raise ValueError('CONTEXT_SOURCE_OUTSIDE_REPOSITORY')
            if fixture.resolve() not in sources:
                raise ValueError('CONTEXT_FIXTURE_MISSING_FROM_MANIFEST')
        sources.extend((ROOT / 'stdlib').rglob('*.slg'))
        for path in sources:
            if path in declarations:
                continue
            text = masked(path.read_text(encoding='utf-8-sig'))
            namespace = re.search(r'(?m)^namespace\s+(\S+)', text)
            shapes = {}
            if namespace:
                for match in re.finditer(r'\bpublic struct\s+(\w+)(?:<[^>]+>)?\s*\{', text):
                    fields = re.findall(r'(?m)^\s+public\s+(\w+)\s*:', body(text, match.end() - 1))
                    if len(fields) != len(set(fields)):
                        raise ValueError(f"CONTEXT_DUPLICATE_DECLARATION_FIELD: {path}")
                    shapes[namespace[1] + '.' + match[1]] = set(fields)
            declarations[path] = shapes
    shapes = {}
    for declared in declarations.values():
        for name, fields in declared.items():
            if name in shapes:
                raise ValueError(f"CONTEXT_DUPLICATE_STRUCT: {name}")
            shapes[name] = fields
    failures = []
    counts = {}
    for fixture in fixtures:
        text = masked(fixture.read_text(encoding='utf-8-sig'))
        aliases = dict((alias, namespace) for namespace, alias in
                       re.findall(r'(?m)^import\s+(\S+)\s+as\s+(\w+)', text))
        count = 0
        for match in re.finditer(r'\b(\w+)\.(\w+)\s*\{', text):
            name = aliases.get(match[1], match[1]) + '.' + match[2]
            if name not in shapes:
                failures.append(f'{fixture.name}: unknown struct {name}')
                continue
            actual = keys(body(text, match.end() - 1))
            missing = shapes[name] - set(actual)
            extra = set(actual) - shapes[name]
            duplicate = sorted({key for key in actual if actual.count(key) > 1})
            if missing or extra or duplicate:
                failures.append(f'{fixture.name}: {name}: missing={sorted(missing)} '
                                f'extra={sorted(extra)} duplicate={duplicate}')
            count += 1
        if count == 0:
            failures.append(f'{fixture.name}: no qualified struct initializers')
        counts[fixture.name] = count
    if failures:
        raise ValueError('CONTEXT_INITIALIZER_SHAPE_MISMATCH:\n' + '\n'.join(failures))
    return {'status': 'passed', 'fixtures': counts, 'initializers': sum(counts.values())}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixtures', nargs='+', type=Path)
    parser.add_argument('--source-manifest', type=Path,
                        help='Repository-owned source manifest for one private fixture')
    args = parser.parse_args()
    print(json.dumps(verify(args.fixtures, args.source_manifest), indent=2))
