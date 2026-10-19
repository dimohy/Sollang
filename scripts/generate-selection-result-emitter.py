"""Keep the managed baseline and SLG emission fixture on one source program."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROGRAM = ROOT / "scripts/contracts/fixtures/c385-selection-and-literal-flow-program.slg"
EMITTER = ROOT / "scripts/contracts/fixtures/c385-selection-and-literal-flow-emission.slg"


def validated_package_paths(order, program):
    stdlib = {path.relative_to(ROOT).as_posix() for path in (ROOT / 'stdlib').rglob('*.slg')}
    if (not isinstance(order, list) or not order
            or any(not isinstance(path, str) for path in order)
            or order[-1] != program.relative_to(ROOT).as_posix()
            or len(order[:-1]) != len(stdlib) or set(order[:-1]) != stdlib):
        raise ValueError('SELECTION_FIXTURE_PACKAGE_SOURCE_ORDER_INVALID')
    return order[:-1]


def validated_runtime_programs(contract, root=ROOT):
    producer = contract.get('reusableCheckedProducer')
    if not isinstance(producer, dict):
        raise ValueError('SELECTION_FIXTURE_RUNTIME_PRODUCER_REQUIRED')
    order = producer.get('stdlibSourceOrder')
    stdlib = {path.relative_to(root).as_posix() for path in (root / 'stdlib').rglob('*.slg')}
    if (not isinstance(order, list) or not order or len(order) != len(stdlib)
            or any(not isinstance(name, str) for name in order) or set(order) != stdlib):
        raise ValueError('SELECTION_FIXTURE_RUNTIME_STDLIB_ORDER_INVALID')
    cases = contract.get('cases')
    if not isinstance(cases, list) or not cases:
        raise ValueError('SELECTION_FIXTURE_RUNTIME_CASES_REQUIRED')
    programs = []
    for case in cases:
        name = case.get('programSource') if isinstance(case, dict) else None
        if not isinstance(name, str) or not name:
            raise ValueError('SELECTION_FIXTURE_RUNTIME_PROGRAM_INVALID')
        path = (root / name).resolve()
        if (not path.is_relative_to(root.resolve()) or not path.is_file()
                or path.suffix != '.slg' or path.relative_to(root.resolve()).as_posix() != name
                or name in stdlib):
            raise ValueError('SELECTION_FIXTURE_RUNTIME_PROGRAM_INVALID')
        if case.get('runArguments') != [name] or case.get('observedSourceOrder') != order + [name]:
            raise ValueError('SELECTION_FIXTURE_RUNTIME_PROGRAM_ARGUMENT_MISMATCH')
        if name not in programs:
            programs.append(name)
    return order, programs


def runtime_input_mode(contract):
    mode = contract['reusableCheckedProducer'].get('inputMode', 'source-text')
    if mode not in ('source-text', 'checked-files'):
        raise ValueError('SELECTION_FIXTURE_RUNTIME_INPUT_MODE_INVALID')
    return mode


def render(program, checked=False, package_paths=None, program_path=None, runtime_program_paths=None,
           checked_files=False):
    runtime = runtime_program_paths is not None
    if checked_files and not runtime:
        raise ValueError('SELECTION_FIXTURE_CHECKED_FILES_REQUIRES_RUNTIME_PACKAGE')
    if runtime and (not checked or package_paths is None or program_path is not None
                    or not runtime_program_paths):
        raise ValueError('SELECTION_FIXTURE_RUNTIME_MODE_INVALID')
    if program_path is not None and package_paths is None:
        raise ValueError('SELECTION_FIXTURE_PROGRAM_FILE_REQUIRES_PACKAGE')
    if '"""' in program and program_path is None and not runtime:
        raise ValueError("SELECTION_FIXTURE_RAW_DELIMITER_CONFLICT")
    lines = program.strip().splitlines()
    if not lines and not runtime:
        raise ValueError("SELECTION_FIXTURE_PROGRAM_EMPTY")
    prefix = 'import sollang.compiler.llvm.text as compiler\n\nmain {\n'
    if package_paths is not None:
        paths = package_paths + ([program_path] if program_path is not None else [])
        runtime_prefix = ''
        path_items = [json.dumps(path) for path in paths]
        if runtime:
            runtime_prefix = (
                'import sys.process as process\n'
                'import sys.text as text\n\nmain {\n'
                '    process.arguments() => arguments\n'
                '    (arguments -> len) != 2 -> if {\n'
                '        "SELECTION_RUNTIME_PROGRAM_ARGUMENT_COUNT" -> println\n'
                '        process.exit(1)\n    }\n'
                '    arguments[1] => programPath\n    [\n'
                + ',\n'.join('    ' + json.dumps(path) for path in runtime_program_paths)
                + '\n    ] => allowedPrograms\n    false => allowed!\n'
                '    allowedPrograms -> each candidate {\n'
                '        (programPath -> text.compareOrdinal(candidate)) == 0\n'
                '            -> if { true => allowed! }\n'
                '    }\n    not allowed! -> if {\n'
                '        "SELECTION_RUNTIME_PROGRAM_PATH_NOT_DECLARED" -> println\n'
                '        process.exit(1)\n    }\n    [\n')
            path_items.append('programPath')
        if checked_files:
            return ('import sollang.compiler.llvm.text as compiler\n' + runtime_prefix
                    + ',\n'.join('    ' + item for item in path_items) + '\n'
                    + '    ] => declaredPaths\n    [Text; ~] => paths!\n'
                    + '    declaredPaths -> each sourcePath { paths! -> push(sourcePath) }\n'
                    + f'    paths! -> compiler.emitCheckedFilesWithStandardLibrarySources({len(package_paths)}) => diagnosticCount\n'
                    + '    diagnosticCount != 0 -> if { "selection-emission-rejected" -> println }\n}\n').encode('utf-8')
        prefix = ('import sollang.compiler.llvm.text as compiler\n'
                  'import sollang.compiler.syntax.source_decoding as sourceDecoding\n'
                  'import sys.file as file\n' + (runtime_prefix if runtime else '\nmain {\n    [\n')
                  + ',\n'.join('    ' + item for item in path_items) + '\n'
                  + '    ] => declaredPaths\n    [Text; ~] => paths!\n'
                  + '    declaredPaths -> each sourcePath { paths! -> push(sourcePath) }\n'
                  + '    [file.SourceText; ~] => owners!\n'
                  + '    paths! -> each sourcePath {\n'
                  '        sourcePath -> file.mapText => owner\n'
                  '        owners! -> push(owner)\n    }\n'
                  '    [Text; ~] => sources!\n    owners! -> each owner {\n'
                  '        owner -> sourceDecoding.utf8Text => source\n'
                  '        sources! -> push(source)\n    }\n')
    source = prefix
    if program_path is None and not runtime:
        source += ('    """\n'
                   + "".join(("    " + line if line else "") + "\n" for line in lines)
                   + '    """ => input\n')
        source += ('    [input,; ~] => sources\n' if package_paths is None
                   else '    sources! -> push(input)\n')
    receiver = 'sources' if package_paths is None else 'sources!'
    if checked:
        # Package order is validated before rendering. Preserve that explicit
        # authority prefix; user-only emitChecked/emitCheckedFiles grant none.
        checked_call = ('compiler.emitChecked' if package_paths is None else
                        f'compiler.emitCheckedWithPaths(paths!, {len(package_paths)})')
        source += (f'    {receiver} -> {checked_call} => diagnosticCount\n'
                   '    diagnosticCount != 0 -> if { "selection-emission-rejected" -> println }\n')
    else:
        source += f'    {receiver} -> compiler.emit\n'
    source += '}\n'
    # Match the authoritative formatter without platform newline translation.
    return source.encode("utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--program", type=Path, default=PROGRAM)
    parser.add_argument("--emitter", type=Path, default=EMITTER)
    parser.add_argument("--checked", action="store_true")
    parser.add_argument("--package-contract", type=Path,
                        help="Contract with exact stdlib source order followed by --program")
    parser.add_argument("--load-program-from-file", action="store_true",
                        help="Load the exact program file after the package, without raw-string embedding")
    parser.add_argument("--runtime-program-argument", action="store_true",
                        help="Use the declared program argv with one reusable checked producer")
    args = parser.parse_args()
    program, emitter = args.program.resolve(), args.emitter.resolve()
    if not program.is_relative_to(ROOT) or not emitter.is_relative_to(ROOT):
        raise ValueError("SELECTION_FIXTURE_REPOSITORY_PATH_REQUIRED")
    if args.load_program_from_file and not args.package_contract:
        raise ValueError('SELECTION_FIXTURE_PROGRAM_FILE_REQUIRES_PACKAGE')
    package_paths = None
    runtime_programs = None
    if args.runtime_program_argument:
        if not (args.checked and args.load_program_from_file and args.package_contract):
            raise ValueError('SELECTION_FIXTURE_RUNTIME_MODE_INVALID')
        contract = json.loads(args.package_contract.read_text(encoding='utf-8-sig'))
        package_paths, runtime_programs = validated_runtime_programs(contract)
        if contract['reusableCheckedProducer'].get('source') != emitter.relative_to(ROOT).as_posix():
            raise ValueError('SELECTION_FIXTURE_RUNTIME_PRODUCER_SOURCE_MISMATCH')
    elif args.package_contract:
        contract = json.loads(args.package_contract.read_text(encoding="utf-8-sig"))
        package_paths = validated_package_paths(contract.get('observedSourceOrder'), program)
    program_path = program.relative_to(ROOT).as_posix() if args.load_program_from_file and not args.runtime_program_argument else None
    checked_files = args.runtime_program_argument and runtime_input_mode(contract) == 'checked-files'
    expected = render('' if args.runtime_program_argument else program.read_text(encoding="utf-8-sig"),
                      args.checked, package_paths, program_path, runtime_programs,
                      checked_files=checked_files)
    if args.check:
        if not emitter.is_file() or emitter.read_bytes() != expected:
            raise SystemExit("SELECTION_FIXTURE_SOURCE_DRIFT")
    else:
        emitter.write_bytes(expected)
    print("SELECTION_FIXTURE_SOURCE_MATCH")


if __name__ == "__main__":
    main()
