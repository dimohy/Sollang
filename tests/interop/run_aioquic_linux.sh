#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
    echo "usage: $0 <server> <python> <version> <qlog> <stdout> <stderr>" >&2
    exit 2
fi

server=$1
python=$2
version=$3
qlog=$4
stdout_path=$5
stderr_path=$6

"$server" >"$stdout_path" 2>"$stderr_path" &
server_pid=$!

cleanup() {
    kill "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 100); do
    if grep -q ready "$stdout_path" 2>/dev/null; then
        break
    fi
    if ! kill -0 "$server_pid" 2>/dev/null; then
        cat "$stderr_path" >&2
        exit 1
    fi
    sleep 0.05
done

grep -q ready "$stdout_path"
"$python" tests/interop/aioquic_client.py \
    --host 127.0.0.1 \
    --port 44433 \
    --version "$version" \
    --qlog "$qlog"

wait "$server_pid"
trap - EXIT
cat "$stdout_path"
