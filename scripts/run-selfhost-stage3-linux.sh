#!/usr/bin/env bash
set -euo pipefail

# Temporary release workaround: the complete self-host compiler still needs a
# deep native stack while it analyzes its own full source set. A follow-up
# optimization will make this pass with Linux's default 8 MiB stack.
ulimit -s 262144
exec "$@"
