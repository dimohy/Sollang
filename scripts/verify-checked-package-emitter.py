"""Reject unchecked or incomplete package emitters before compiling a harness."""

import argparse
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "scripts/generate-selection-result-emitter.py"


def validate_emitted_entrypoint(llvm_text, target):
    """Check target entry identity; LLVM-as remains the LLVM syntax authority."""
    entry = {"windows": "main", "windows-x64": "main",
             "wasm": "sollang_start", "wasm32-browser": "sollang_start"}.get(target)
    if entry is None:
        raise ValueError("EMISSION_ENTRY_TARGET_UNSUPPORTED")
    definitions = re.findall(r"^\s*define\b[^@\r\n]*@" + entry + r"\s*\(", llvm_text, re.M)
    if len(definitions) != 1:
        raise ValueError("EMISSION_ENTRY_DEFINITION_COUNT")
    return entry


def validate_reusable(contract, root=ROOT):
    spec = importlib.util.spec_from_file_location('checked_package_generator', GENERATOR)
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    order, programs = generator.validated_runtime_programs(contract, root)
    producer = contract['reusableCheckedProducer']
    if (not isinstance(producer.get('id'), str) or not producer['id']
            or any(character not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_'
                   for character in producer['id'])):
        raise ValueError('CHECKED_PACKAGE_PRODUCER_ID_INVALID')
    def source_path(name):
        if not isinstance(name, str) or not name:
            raise ValueError('CHECKED_PACKAGE_PRODUCER_SOURCE_INVALID')
        path = (root / name).resolve()
        if (not path.is_relative_to(root.resolve()) or not path.is_file() or path.suffix != '.slg'
                or path.relative_to(root.resolve()).as_posix() != name):
            raise ValueError('CHECKED_PACKAGE_PRODUCER_SOURCE_INVALID')
        return path
    wrapper = source_path(producer.get('source'))
    additional = producer.get('additionalSources')
    if (not isinstance(additional, list) or not additional
            or any(not isinstance(name, str) for name in additional)
            or len(additional) != len(set(additional)) or producer['source'] in additional):
        raise ValueError('CHECKED_PACKAGE_PRODUCER_CLOSURE_INVALID')
    for name in additional:
        source_path(name)
    if 'observedSourceOrder' in contract:
        raise ValueError('CHECKED_PACKAGE_REUSABLE_TOP_LEVEL_ORDER_AMBIGUOUS')
    for case in contract['cases']:
        if case.get('source') != producer['source'] or case.get('additionalSources') != additional:
            raise ValueError('CHECKED_PACKAGE_PRODUCER_CASE_MISMATCH')
        if (type(case.get('emittedLlvm')) is not bool
                or type(case.get('exit')) is not int or case['exit'] != 0):
            raise ValueError('CHECKED_PACKAGE_REUSABLE_CASE_SCOPE_INVALID')
    expected = generator.render('', checked=True, package_paths=order,
                                runtime_program_paths=programs,
                                checked_files=generator.runtime_input_mode(contract) == 'checked-files').decode('utf-8')
    if wrapper.read_text(encoding='utf-8-sig') != expected:
        raise ValueError('CHECKED_PACKAGE_EMITTER_NOT_CANONICAL_CHECKED')
    return len(order)


def validate(contract, root=ROOT):
    if 'reusableCheckedProducer' in contract:
        return validate_reusable(contract, root)
    order = contract.get("observedSourceOrder")
    if (not isinstance(order, list) or len(order) < 2
            or any(not isinstance(name, str) for name in order)
            or len(order) != len(set(order))):
        raise ValueError("CHECKED_PACKAGE_SOURCE_ORDER_INVALID")
    stdlib = {p.relative_to(root).as_posix() for p in (root / "stdlib").rglob("*.slg")}
    if set(order[:-1]) != stdlib:
        raise ValueError("CHECKED_PACKAGE_STDLIB_SCOPE_INVALID")
    paths = []
    for name in order:
        path = (root / name).resolve(strict=True)
        if not path.is_relative_to(root) or path.suffix != ".slg":
            raise ValueError("CHECKED_PACKAGE_SOURCE_BOUNDARY_INVALID")
        paths.append(path)
    spec = importlib.util.spec_from_file_location("checked_package_generator", GENERATOR)
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    expected = generator.render(paths[-1].read_text(encoding="utf-8-sig"), checked=True,
                                package_paths=order[:-1], program_path=order[-1]).decode("utf-8")
    cases = contract.get("cases")
    if (not isinstance(cases, list) or len(cases) != 1
            or not isinstance(cases[0], dict) or cases[0].get("emittedLlvm") is not True):
        raise ValueError("CHECKED_PACKAGE_CASE_SCOPE_INVALID")
    wrapper = (root / cases[0]["source"]).resolve(strict=True)
    if not wrapper.is_relative_to(root) or wrapper.suffix != ".slg":
        raise ValueError("CHECKED_PACKAGE_WRAPPER_BOUNDARY_INVALID")
    if wrapper.read_text(encoding="utf-8-sig") != expected:
        raise ValueError("CHECKED_PACKAGE_EMITTER_NOT_CANONICAL_CHECKED")
    return len(stdlib)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    args = parser.parse_args()
    contract = json.loads(args.contract.read_text(encoding='utf-8-sig'))
    count = validate(contract)
    result = {"status": "passed", "checkedEmissionRequired": True,
              "stdlibSources": count, "programSources": 1}
    if 'reusableCheckedProducer' in contract:
        result.update(programSources=len({case['programSource'] for case in contract['cases']}),
                      cases=len(contract['cases']), reusableCheckedProducer=True)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
