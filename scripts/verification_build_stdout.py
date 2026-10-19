"""Strict successful-build telemetry protocol shared by phase evidence consumers.

This interprets CLI build messages only. It never edits the raw process streams
or changes program output, diagnostics, exit codes, or negative-stage oracles.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

POLICY = "compiler-build-telemetry-v1"


def validate_policy(oracle, stage):
    if "stdoutPolicy" in oracle and not (
        oracle["stdoutPolicy"] == POLICY and stage == "compile"
        and oracle.get("exitCode") == 0 and oracle.get("stdout") == ""
        and oracle.get("stderr") == ""
    ):
        raise ValueError("BUILD_STDOUT_POLICY_SCOPE")


def validate_build_stdout(raw, binary_path, side):
    binary = Path(binary_path).resolve(strict=True)
    if side not in ("managed", "selfhost") or not binary.is_file():
        raise ValueError("BUILD_STDOUT_PRODUCER_OR_PRODUCT")
    lines = [line for line in raw.decode("utf-8").splitlines() if line]
    seen, partitions = set(), []
    cache_root = binary.parent / ".sollang-cache"

    def cache(path, suffix):
        location = Path(path).resolve()
        if (location.parent != cache_root or not location.name.startswith(binary.stem + ".")
                or location.suffix != suffix):
            raise ValueError("BUILD_STDOUT_CACHE_PATH")

    patterns = {
        "frontend": (r"\[frontend-cache\] (?:cold; rebuilt and published [0-9]+ sources|exact hit; skipped parsing and semantic analysis for [0-9]+ sources); (.+)", ".sources"),
        "codegen": (r"\[codegen-cache\] (?:cold|loaded|exact); reused [0-9]+/[0-9]+ units; (.+)", ".cgu"),
        "semantic": (r"\[semantic-cache\] (?:(?:cold|loaded); reused [0-9]+/[0-9]+ functions; main (?:rebuilt|reused); mapped [0-9]+/[0-9]+ functions, [0-9]+/[0-9]+ call sites|exact via frontend; skipped semantic loading); (.+)", ".semantic"),
        "product": (r"\[product-cache\] (?:rebuilt; linked and published|exact hit; skipped linking); (.+)", ".product"),
    }
    for index, line in enumerate(lines):
        match = re.fullmatch(r"\[native ([1-9][0-9]*)/([1-9][0-9]*)\] optimized partition", line)
        if match and side == "managed" and not seen:
            partitions.append(tuple(map(int, match.groups())))
            continue
        match = re.fullmatch(r"Wrote (.+) \(([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+) bytes\)", line) if side == "managed" else re.fullmatch(r"Wrote (.+)", line)
        if match:
            if "wrote" in seen or index != len(lines) - 1 or Path(match[1]).resolve() != binary:
                raise ValueError("BUILD_STDOUT_PRODUCT_PATH")
            if side == "managed" and int(match[2].replace(",", "")) != binary.stat().st_size:
                raise ValueError("BUILD_STDOUT_PRODUCT_SIZE")
            seen.add("wrote")
            continue
        if line.startswith("Kept "):
            if "kept" in seen or Path(line[5:]).resolve() != Path(str(binary) + ".ll"):
                raise ValueError("BUILD_STDOUT_KEPT_PATH")
            seen.add("kept")
            continue
        if side == "selfhost":
            match = re.fullmatch(r"\[semantic-cache\] load-status (?:0|50); reused [0-9]+/[0-9]+ sources; rejected 0; uncached [0-9]+; (.+)", line)
            if match and "semantic" not in seen:
                cache(match[1], ".semantic")
                seen.add("semantic")
                continue
        else:
            matched = False
            for kind, (pattern, suffix) in patterns.items():
                match = re.fullmatch(pattern, line)
                if match and kind not in seen:
                    cache(match[1], suffix)
                    seen.add(kind)
                    matched = True
                    break
            if matched:
                continue
        raise ValueError("BUILD_STDOUT_UNKNOWN_OR_DUPLICATE_LINE")
    if partitions and (partitions != [(i, len(partitions)) for i in range(1, len(partitions) + 1)]):
        raise ValueError("BUILD_STDOUT_PARTITION_SEQUENCE")
    required = {"wrote", "frontend", "codegen", "semantic", "product"} if side == "managed" else {"wrote", "semantic"}
    if not required <= seen:
        raise ValueError("BUILD_STDOUT_INCOMPLETE")
    return {"policy": POLICY, "semanticStdout": "", "rawSha256": hashlib.sha256(raw).hexdigest().upper(),
            "binarySha256": hashlib.sha256(binary.read_bytes()).hexdigest().upper(),
            "binaryLength": binary.stat().st_size, "compilerSide": side, "lineCount": len(lines)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--stdout-path", required=True)
    parser.add_argument("--binary-path", required=True)
    parser.add_argument("--compiler-side", required=True, choices=("managed", "selfhost"))
    args = parser.parse_args()
    print(json.dumps(validate_build_stdout(Path(args.stdout_path).read_bytes(), args.binary_path, args.compiler_side)))
