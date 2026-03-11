#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat >&2 <<'EOF'
Usage: scripts/dump_layout_input.sh <out-dir> [--engine elk|dagre] [examples/*.d2 ...]

Internal helper for layout-debug input dumps.
It invokes the hidden CLI subcommand `__dump-input`.
EOF
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$1"
shift

engine="elk"
if [[ $# -ge 2 && "$1" == "--engine" ]]; then
  engine="$2"
  shift 2
fi

cd "$root_dir"
moon run --target native cmd/diago -- __dump-input --engine "$engine" --out-dir "$out_dir" "$@"
