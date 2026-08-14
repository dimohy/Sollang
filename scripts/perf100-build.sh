#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bin_dir="$repo_root/artifacts/perf100/bin"
if [[ "$bin_dir" != "$repo_root/artifacts/perf100/bin" ]]; then
  echo "refusing to clean unexpected Perf100 output directory: $bin_dir" >&2
  exit 2
fi
rm -rf -- "$bin_dir"
mkdir -p "$bin_dir"

compiler="${SOLLANG_PERF_COMPILER:-$repo_root/artifacts/example-tests/selfhost-stage3-linux}"
if [[ ! -x "$compiler" ]]; then
  echo "Perf100 requires an executable self-host Linux Sollang compiler: $compiler" >&2
  exit 2
fi

timings="$bin_dir/build-timings.tsv"
: > "$timings"

measure_build() {
  local language="$1"
  shift
  local started_ns finished_ns
  started_ns="$(date +%s%N)"
  "$@"
  finished_ns="$(date +%s%N)"
  printf '%s\t%s\n' "$language" "$(( (finished_ns - started_ns) / 1000000 ))" >> "$timings"
}

build_csharp_nativeaot() {
  (
    cd /tmp
    dotnet publish "$repo_root/benchmarks/perf100/csharp/Perf100.csproj" \
      -c Release -r linux-x64 -o "$bin_dir/csharp-nativeaot" --nologo
  )
}

echo "[1/6] C++"
measure_build cpp g++ -O3 -march=native -DNDEBUG benchmarks/perf100/cpp/runner.cpp -o "$bin_dir/cpp"

echo "[2/6] Rust"
source "$HOME/.cargo/env"
measure_build rust rustc -C opt-level=3 -C target-cpu=native -C overflow-checks=off \
  benchmarks/perf100/rust/runner.rs -o "$bin_dir/rust"

echo "[3/6] C# NativeAOT"
measure_build csharp-nativeaot build_csharp_nativeaot

echo "[4/6] Go"
export PATH="/usr/local/go/bin:$PATH"
measure_build go go build -trimpath -ldflags="-s -w" -o "$bin_dir/go" benchmarks/perf100/go/runner.go

echo "[5/6] Java"
java_classes="$bin_dir/java-classes"
mkdir -p "$java_classes"
measure_build java bash -c \
  'javac -d "$1" "$2" && jar --create --file "$3" --main-class Perf100 -C "$1" .' \
  _ "$java_classes" "$repo_root/benchmarks/perf100/java/Perf100.java" "$bin_dir/java.jar"

echo "[6/6] Sollang"
measure_build sollang "$compiler" build benchmarks/perf100/sollang/runner.slg \
  --stdlib "$repo_root/stdlib" -O3 -o "$bin_dir/sollang"

node scripts/perf100-build-report.mjs "$compiler" "$timings"
rm -f -- "$timings"

echo "Perf100 runners built in $bin_dir"
