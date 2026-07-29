#!/usr/bin/env bash
set -euo pipefail

compiler="$1"
source="$2"
stdlib="$3"
llvm_home="$4"
output="$5"

actual="$(
    "$compiler" run "$source" \
        -o "$output" \
        --target linux-x64 \
        --stdlib "$stdlib" \
        --llvm "$llvm_home" \
        -O1 \
        -- \
        "hello world" "한글 인자"
)"
expected=$'argument count = 3\nfirst argument = hello world\nsecond argument = 한글 인자'

if [[ "$actual" != "$expected" ]]; then
    printf 'Linux native argv output mismatch.\nExpected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
fi

printf '%s\n' "$actual"
