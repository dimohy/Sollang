#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for family in $(seq 1 20); do
  input=1000
  if [[ "$family" -eq 19 ]]; then input=20; fi
  expected="$(artifacts/perf100/bin/sollang "$family" "$input" 17)"
  for runner in cpp rust go; do
    actual="$(artifacts/perf100/bin/$runner "$family" "$input" 17)"
    if [[ "$actual" != "$expected" ]]; then
      echo "mismatch family=$family language=$runner expected=$expected actual=$actual" >&2
      exit 1
    fi
  done
  actual="$(artifacts/perf100/bin/csharp-nativeaot/Perf100 "$family" "$input" 17)"
  if [[ "$actual" != "$expected" ]]; then
    echo "mismatch family=$family language=csharp-nativeaot expected=$expected actual=$actual" >&2
    exit 1
  fi
  actual="$(java -jar artifacts/perf100/bin/java.jar "$family" "$input" 17)"
  if [[ "$actual" != "$expected" ]]; then
    echo "mismatch family=$family language=java expected=$expected actual=$actual" >&2
    exit 1
  fi
  printf '[%d/20] checksum=%s\n' "$family" "$expected"
done
