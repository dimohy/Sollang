"""Verify committed conditional numeric types across real semantic-cache reuse."""

import argparse
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path

from focused_verification_output import VerificationOutput, lifecycle_inputs, sha
from verification_fingerprints import managed_runtime_inputs


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "scripts/probes/numeric-context-cache"


def generic_closure_inputs():
    return [ROOT / "examples/regression/1712-algorithm-in-place-ordering.slg",
            ROOT / "examples/regression/expected/1712-algorithm-in-place-ordering.stdout.txt",
            FIXTURES / "generic-unrelated-a.slg", FIXTURES / "generic-unrelated-b.slg"]


def verify_generic_closure(compiler, output, inputs, parent_result, compiler_kind):
    main_source, expected_path, *versions = generic_closure_inputs()
    expected = expected_path.read_text(encoding="utf-8-sig").strip()
    control_output = output / "generic-closure"
    result = {"schemaVersion": 1, "scope": "Nested generic call closure across private declaration changes",
              "total": 2, "cases": [], "claimsGoalComplete": False}
    parent_result["genericClosureControl"] = {"status": "running", "result": str(control_output / "result.json")}
    try:
        with VerificationOutput(ROOT, control_output, inputs, result, timeout_seconds=180) as execution:
            helper, executable = control_output / "unrelated.slg", control_output / "probe.exe"
            for label, version in zip(("cold", "warm"), versions):
                shutil.copyfile(version, helper)
                helper_hash = sha(helper)
                row = {"id": label, "status": "running", "helperSha256": helper_hash}
                result["cases"].append(row)
                execution.save()
                command = [str(compiler), "build", str(main_source), str(helper), "-o", str(executable),
                           "--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--target", "windows-x64", "-O1"]
                code = execution.run(command, control_output / f"{label}.build.stdout.log",
                                     control_output / f"{label}.build.stderr.log")
                stdout = (control_output / f"{label}.build.stdout.log").read_text(encoding="utf-8-sig")
                stderr = (control_output / f"{label}.build.stderr.log").read_text(encoding="utf-8-sig")
                row.update(buildExit=code, buildStderr=stderr, cacheStatus=stdout)
                execution.save()
                if code != 0 or stderr.strip() or sha(helper) != helper_hash:
                    raise ValueError(f"GENERIC_CACHE_CLOSURE_BUILD_FAILED: {label}: {stderr}")
                code = execution.run([str(executable)], control_output / f"{label}.run.stdout.log",
                                     control_output / f"{label}.run.stderr.log")
                actual = (control_output / f"{label}.run.stdout.log").read_text(encoding="utf-8-sig").strip()
                passed = (code == 0 and actual == expected
                          and not (control_output / f"{label}.run.stderr.log").read_bytes()
                          and (label == "cold" or ("[semantic-cache] loaded;" in stdout
                               if compiler_kind == "managed" else native_cache_words(control_output)[4] == 0)))
                if compiler_kind == "native":
                    words = native_cache_words(control_output)
                    row["nativeAdmission"] = {"reused": words[5], "rejected": words[6], "uncached": words[7],
                                              "restorationExercised": words[5] > 0}
                row.update(status="passed" if passed else "failed", passed=passed,
                           runExit=code, stdoutMatchesExpected=actual == expected)
                execution.save()
                if not passed:
                    raise ValueError(f"GENERIC_CACHE_CLOSURE_RESTORATION_CHANGED: {label}")
                print(f"generic-closure/{label}: PASS", flush=True)
    finally:
        parent_result["genericClosureControl"]["status"] = result.get("status", "unresolved")


def semantic_facts(path):
    data = path.read_bytes()
    if hashlib.sha256(data[:-32]).digest() != data[-32:]:
        raise ValueError("CONTEXTUAL_NUMERIC_CACHE_CHECKSUM_CHANGED")
    if struct.unpack_from("<Q", data, 8)[0] != 9:
        raise ValueError("CONTEXTUAL_NUMERIC_CACHE_SCHEMA_CHANGED")
    position = 13 * 8 + 32

    def word():
        nonlocal position
        value = struct.unpack_from("<Q", data, position)[0]
        position += 8
        return value

    def string():
        nonlocal position
        length = word()
        value = data[position:position + length].decode("utf-8")
        position += length
        return value

    result = {}
    for _ in range(word()):
        key, value = string(), string()
        if key in result:
            raise ValueError("CONTEXTUAL_NUMERIC_CACHE_DUPLICATE")
        result[key] = value
    main_module = string()
    bindings = {string(): string() for _ in range(word())}
    return result, main_module, bindings


def native_cache_words(output):
    paths = list((output / ".sollang-cache").glob("*.semantic"))
    if len(paths) != 1:
        raise ValueError("CONTEXTUAL_NUMERIC_CACHE_NOT_UNIQUE")
    data = paths[0].read_bytes()
    if sys.byteorder != "little" or len(data) % 8:
        raise ValueError("NATIVE_NUMERIC_CACHE_WORD_FORMAT")
    words = memoryview(data).cast("Q")
    verify_native_envelope(words, 6002245308512486735, 41)
    if words[8] or words[3] > (len(words) - 41) // 2:
        raise ValueError("NATIVE_NUMERIC_CACHE_HEADER")
    return words


def verify_native_envelope(words, magic, minimum):
    if len(words) < minimum or tuple(words[:3]) != (magic, 1, len(words)):
        raise ValueError("NATIVE_NUMERIC_CACHE_HEADER")
    if any(word > 255 for word in words[-32:]):
        raise ValueError("NATIVE_NUMERIC_CACHE_DIGEST_BYTES")
    if hashlib.sha256(words[:-32].cast("B")).digest() != bytes(list(words[-32:])):
        raise ValueError("NATIVE_NUMERIC_CACHE_CHECKSUM")


def native_cache_reused(output):
    words = native_cache_words(output)
    # resolve counts previously uncacheable rows as rejected too. The changed
    # provider is the one additional rejection among persisted owners.
    return (words[4] == 0 and words[5] > 0 and words[6] == words[7] + 1
            and words[5] + words[6] == words[3])


def native_semantic_facts(output, source):
    """Inspect the published normal cache, not a fresh binding dump.

    Native owners retain template expression facts and typed call environments;
    C# numeric annotation strings are not their persistence format.
    """
    words = native_cache_words(output)
    cursor, matches = 9, []
    for _ in range(words[3]):
        if cursor + 2 > len(words) - 32:
            raise ValueError("NATIVE_NUMERIC_CACHE_ROW_BOUNDS")
        status, length = words[cursor:cursor + 2]
        cursor += 2
        if status > 255 or cursor + length > len(words) - 32 or (status != 0 and length):
            raise ValueError("NATIVE_NUMERIC_CACHE_ROW_BOUNDS")
        generation = words[cursor:cursor + length]
        cursor += length
        if status:
            continue
        verify_native_envelope(generation, 6002245308512486734, 72)
        position = 40
        for _ in range(generation[7]):
            if position >= len(generation) - 32:
                raise ValueError("NATIVE_NUMERIC_GENERATION_BOUNDS")
            position += 1 + generation[position] + 32
        if position + generation[6] != len(generation) - 32:
            raise ValueError("NATIVE_NUMERIC_GENERATION_BOUNDS")
        calls = generation[position:position + generation[6]]
        if len(calls) < 6 or tuple(calls[:3]) != (6002245308495514451, 2, len(calls)):
            raise ValueError("NATIVE_NUMERIC_OWNER_CALLS_HEADER")
        owner = calls[6:6 + calls[3]]
        if len(owner) < 7 or tuple(owner[:3]) != (6002245308478540870, 1, len(owner)):
            raise ValueError("NATIVE_NUMERIC_OWNER_TYPES_HEADER")
        facts_start = 7 + owner[3] + owner[4]
        if facts_start + 2 * (owner[5] + owner[6]) != len(owner):
            raise ValueError("NATIVE_NUMERIC_OWNER_FACTS_BOUNDS")
        if any(byte > 255 for byte in owner[7:7 + owner[3]]):
            raise ValueError("NATIVE_NUMERIC_OWNER_SOURCE_BYTES")
        if bytes(list(owner[7:7 + owner[3]])) != source:
            continue
        recipes = owner[7 + owner[3]:facts_start]
        if len(recipes) < 7 or tuple(recipes[:2]) != (6002245308444529748, 1) or recipes[4] != len(recipes):
            raise ValueError("NATIVE_NUMERIC_RECIPES_HEADER")
        recipe_position, identities = 7 + recipes[6], []
        for _ in range(recipes[5]):
            if recipe_position + 10 > len(recipes):
                raise ValueError("NATIVE_NUMERIC_RECIPES_BOUNDS")
            end = recipe_position + 10 + recipes[recipe_position + 9]
            if end > len(recipes):
                raise ValueError("NATIVE_NUMERIC_RECIPES_BOUNDS")
            identities.append(tuple(recipes[recipe_position:end]))
            recipe_position = end
        if recipe_position != len(recipes):
            raise ValueError("NATIVE_NUMERIC_RECIPES_BOUNDS")
        def facts(start, count):
            result = {}
            for index in range(count):
                identity, recipe = owner[start + 2 * index:start + 2 * index + 2]
                if str(identity) in result or recipe >= len(identities):
                    raise ValueError("NATIVE_NUMERIC_FACT_DUPLICATE_OR_TYPE")
                result[str(identity)] = identities[recipe]
            return result
        bindings = facts(facts_start, owner[5])
        expressions = facts(facts_start + 2 * owner[5], owner[6])
        builtin_symbols = {value[3] for value in expressions.values() if value[0] == 1 and value[2] == 0}
        if not {16, 18}.issubset(builtin_symbols):  # signedWord(UInt8/UInt16 builtin symbols 8/9)
            raise ValueError("NATIVE_NUMERIC_CONTEXT_TYPES_MISSING")
        matches.append((expressions, "exact-source-main", bindings))
    if cursor != len(words) - 32 or len(matches) != 1:
        raise ValueError("NATIVE_NUMERIC_MAIN_OWNER_NOT_UNIQUE")
    return matches[0]


def verify_link_failure(compiler, output, inputs, parent_result, main_source, provider, expected):
    """Exercise the real native publication boundary with an existing cache.

    Reuse the C476 injected-clang failure technique; do not manufacture a bad
    cache or report an emitter error as a successful linker-failure control.
    """
    control = output / "link-failure"
    cache = next((output / ".sollang-cache").glob("*.semantic"))
    executable = output / "probe.exe"
    originals = {path: (sha(path), path.stat().st_size, path.stat().st_mtime_ns)
                 for path in (cache, executable)}
    clang = ROOT / ".tools/llvm-22.1.8/bin/clang.exe"
    result = {"schemaVersion": 1, "scope": "Native link failure preserves published cache and executable",
              "total": 1, "cases": [], "claimsGoalComplete": False}
    contract = output / "link-failure-contract.json"
    contract.write_text(json.dumps({"schemaVersion": 1, "cases": [
        {"id": "existing-cache-link-failure", "exit": 42, "expectedRuntimeExit": 0}]
    }, indent=2) + "\n", encoding="utf-8")
    parent_result["linkFailureControl"] = {"status": "running", "result": str(control / "result.json")}
    try:
        with VerificationOutput(ROOT, control, [*inputs, clang, main_source, provider, cache, executable, contract], result) as execution:
            source, fake_llvm = control / "fail-clang.c", control / "fake-llvm"
            (fake_llvm / "bin").mkdir(parents=True)
            fake_clang = fake_llvm / "bin/clang.exe"
            source.write_text('#include <stdio.h>\nint main(void) { fputs("C476 injected linker failure\\n", stderr); return 42; }\n', encoding="utf-8")
            code = execution.run([str(clang), "-x", "c", str(source), "-o", str(fake_clang)],
                                 control / "prepare.stdout", control / "prepare.stderr")
            if code or (control / "prepare.stderr").read_bytes():
                raise ValueError("NATIVE_CACHE_FAILURE_CONTROL_PREPARATION")
            row = {"id": "existing-cache-link-failure", "status": "running", "expectedBuildExit": 42}
            result["cases"].append(row)
            code = execution.run([str(compiler), "build", str(main_source), str(provider), "-o", str(executable),
                                  "--llvm", str(fake_llvm), "--target", "windows-x64"],
                                 control / "build.stdout", control / "build.stderr")
            stdout = (control / "build.stdout").read_text(encoding="utf-8-sig")
            stderr = (control / "build.stderr").read_text(encoding="utf-8-sig")
            after = {path: (sha(path), path.stat().st_size, path.stat().st_mtime_ns) for path in originals}
            row.update(buildExit=code, preserved=originals == after,
                       cacheSha256Before=originals[cache][0], cacheSha256After=after[cache][0],
                       executableSha256Before=originals[executable][0], executableSha256After=after[executable][0])
            if (code != 42 or "C476 injected linker failure" not in stderr
                    or "sollang: native linker failed with exit code 42" not in stdout
                    or "[semantic-cache]" in stdout or originals != after):
                raise ValueError("NATIVE_CACHE_FAILED_LINK_PUBLISHED_OR_NOT_REACHED")
            code = execution.run([str(executable)], control / "run.stdout", control / "run.stderr")
            actual = (control / "run.stdout").read_text(encoding="utf-8-sig").strip()
            row.update(runExit=code, passed=code == 0 and actual == expected and not (control / "run.stderr").read_bytes())
            row["status"] = "passed" if row["passed"] else "failed"
            if not row["passed"]:
                raise ValueError("NATIVE_CACHE_FAILED_LINK_EXISTING_PRODUCT_CHANGED")
    finally:
        parent_result["linkFailureControl"]["status"] = result.get("status", "unresolved")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--compiler-kind", choices=("managed", "native"), default="managed")
    parser.add_argument("--verify-link-failure", action="store_true")
    parser.add_argument("--fixtures", type=Path, default=FIXTURES)
    parser.add_argument("--expected-binding", action="append", default=[], metavar="NAME=IDENTITY")
    args = parser.parse_args()
    if args.compiler_kind == "native" and args.expected_binding:
        parser.error("native cache bindings use source-local symbol identities; named managed binding assertions are unsupported")
    if args.verify_link_failure and args.compiler_kind != "native":
        parser.error("--verify-link-failure requires --compiler-kind native")
    compiler, output = args.compiler.resolve(), args.output.resolve()
    expected_bindings = {}
    for specification in args.expected_binding:
        name, separator, identity = specification.partition("=")
        if not separator or not name or not identity or name in expected_bindings:
            parser.error("--expected-binding requires unique NAME=IDENTITY entries")
        expected_bindings[name] = identity
    versions = [args.fixtures.resolve() / name for name in ("main.slg", "provider-a.slg", "provider-b.slg")]
    if not all(path.is_file() for path in versions):
        parser.error("fixture directory must contain main.slg, provider-a.slg and provider-b.slg")
    if not all(path.is_file() for path in generic_closure_inputs()):
        parser.error("generic closure control inputs are missing")
    compiler_inputs = managed_runtime_inputs(compiler) if args.compiler_kind == "managed" else [compiler]
    inputs = [*compiler_inputs, *versions, *generic_closure_inputs(), Path(__file__),
              *sorted((ROOT / "stdlib").rglob("*.slg")), *lifecycle_inputs(ROOT)]
    result = {"schemaVersion": 1, "scope": "C543 cold/warm semantic numeric type restoration",
              "compilerKind": args.compiler_kind, "total": 2, "cases": [], "claimsGoalComplete": False}
    with VerificationOutput(ROOT, output, inputs, result, timeout_seconds=180) as execution:
        (output / "numeric_cache").mkdir()
        main_source, provider = output / "main.slg", output / "numeric_cache/provider.slg"
        shutil.copyfile(versions[0], main_source)
        baseline_annotations, baseline_stderr = None, None
        for index, label in enumerate(("cold", "warm")):
            shutil.copyfile(versions[index + 1], provider)
            source_hashes = {str(path): sha(path) for path in (main_source, provider)}
            executable = output / "probe.exe"
            row = {"id": label, "status": "running", "sourceHashes": source_hashes}
            result["cases"].append(row)
            execution.save()
            command = [str(compiler), "build", str(main_source), str(provider), "-o", str(executable),
                       "--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--target", "windows-x64"]
            build_exit = execution.run(command, output / f"{label}.build.stdout.log",
                                       output / f"{label}.build.stderr.log")
            stdout = (output / f"{label}.build.stdout.log").read_text(encoding="utf-8-sig")
            stderr = (output / f"{label}.build.stderr.log").read_text(encoding="utf-8-sig")
            if build_exit != 0 or source_hashes != {str(path): sha(path) for path in (main_source, provider)}:
                raise ValueError(f"CONTEXTUAL_NUMERIC_BUILD_FAILED: {label}: {stderr}")
            if execution.run([str(executable)], output / f"{label}.run.stdout.log",
                             output / f"{label}.run.stderr.log") != 0:
                raise ValueError(f"CONTEXTUAL_NUMERIC_RUN_FAILED: {label}")
            actual = (output / f"{label}.run.stdout.log").read_text(encoding="utf-8-sig").strip()
            if actual != f"4,4,4,{index + 1}" or (output / f"{label}.run.stderr.log").read_text().strip():
                raise ValueError(f"CONTEXTUAL_NUMERIC_OUTPUT_CHANGED: {label}: {actual}")
            caches = list((output / ".sollang-cache").glob("*.semantic"))
            if len(caches) != 1:
                raise ValueError("CONTEXTUAL_NUMERIC_CACHE_NOT_UNIQUE")
            annotations, main_module, bindings = (semantic_facts(caches[0]) if args.compiler_kind == "managed"
                                                 else native_semantic_facts(output, main_source.read_bytes()))
            if any(bindings.get(name) != identity for name, identity in expected_bindings.items()):
                raise ValueError(f"CONTEXTUAL_NUMERIC_BINDING_IDENTITY_CHANGED: {label}: {bindings}")
            if len(annotations) < 3:
                raise ValueError("CONTEXTUAL_NUMERIC_ANNOTATIONS_MISSING")
            if index == 0:
                baseline_annotations, baseline_stderr = annotations, stderr
            elif (("[semantic-cache] loaded;" not in stdout or "; main reused;" not in stdout)
                  if args.compiler_kind == "managed" else not native_cache_reused(output)):
                raise ValueError(f"CONTEXTUAL_NUMERIC_RESTORATION_CHANGED: {stdout}")
            if index and (annotations != baseline_annotations or stderr != baseline_stderr):
                raise ValueError(f"CONTEXTUAL_NUMERIC_RESTORATION_CHANGED: {stdout}")
            row.update(status="passed", passed=True, runStdout=actual, numericAnnotations=annotations,
                       mainModule=main_module, expectedBindings={name: bindings[name] for name in expected_bindings},
                       buildStderr=stderr, semanticStatus=[line for line in stdout.splitlines()
                                                         if line.startswith("[semantic-cache]")])
            execution.save()
            print(f"{label}: PASS", flush=True)
        if args.verify_link_failure:
            verify_link_failure(compiler, output, inputs, result, main_source, provider, "4,4,4,2")
        verify_generic_closure(compiler, output, inputs, result, args.compiler_kind)
        execution.save()


if __name__ == "__main__":
    main()
