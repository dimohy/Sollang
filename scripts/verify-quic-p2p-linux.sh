#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiler="${1:-$repo_root/artifacts/example-tests/selfhost-stage3-linux}"
llvm_home="${SOLLANG_LLVM_HOME:-/usr/lib/llvm-18}"
scratch="$repo_root/artifacts/scratch/quic-p2p-linux"
server="$scratch/quic-p2p-chat-server"
client="$scratch/quic-p2p-chat-client"
server_out="$scratch/server.stdout.log"
server_err="$scratch/server.stderr.log"
client_out="$scratch/client.stdout.log"
client_err="$scratch/client.stderr.log"

mkdir -p "$scratch"

echo "[p2p-linux 1/3] Build both peers with the selected native compiler."
"$compiler" build "$repo_root/examples/interop/quic-p2p-chat-server.slg" \
    -o "$server" --target linux-x64 --llvm "$llvm_home" \
    --stdlib "$repo_root/stdlib" -O1
"$compiler" build "$repo_root/examples/interop/quic-p2p-chat-client.slg" \
    -o "$client" --target linux-x64 --llvm "$llvm_home" \
    --stdlib "$repo_root/stdlib" -O1

echo "[p2p-linux 2/3] Run authenticated peer discovery, protocol negotiation, and chat."
"$server" >"$server_out" 2>"$server_err" &
server_pid=$!
cleanup() {
    if kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

sleep 0.75
if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "P2P server exited during startup" >&2
    cat "$server_err" >&2
    exit 1
fi

if ! timeout 15 "$client" >"$client_out" 2>"$client_err"; then
    echo "P2P client failed" >&2
    cat "$client_err" >&2
    exit 1
fi

for _ in $(seq 1 100); do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
done
if kill -0 "$server_pid" 2>/dev/null; then
    echo "P2P server did not complete" >&2
    exit 1
fi
wait "$server_pid"
trap - EXIT

echo "[p2p-linux 3/3] Verify exact application results."
expected_server=$'p2p-ready=44434\nserver-received=10\np2p-server-complete'
expected_client=$'client-received=12\np2p-client-complete'
actual_server="$(tr -d '\r' <"$server_out")"
actual_client="$(tr -d '\r' <"$client_out")"
if [[ "$actual_server" != "$expected_server" ]]; then
    printf 'P2P server output mismatch.\nExpected:\n%s\nActual:\n%s\n' "$expected_server" "$actual_server" >&2
    exit 1
fi
if [[ "$actual_client" != "$expected_client" ]]; then
    printf 'P2P client output mismatch.\nExpected:\n%s\nActual:\n%s\n' "$expected_client" "$actual_client" >&2
    exit 1
fi

echo "QUIC P2P Linux verification passed."
