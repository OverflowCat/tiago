#!/usr/bin/env bash
set -euo pipefail

mode="${1:-all}"
case "$mode" in
  all|d2|diago) ;;
  *)
    echo "Usage: $0 [all|d2|diago]" >&2
    exit 1
    ;;
esac

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
examples_dir="$root_dir/examples"
cd "$root_dir"

d2_cmd="${D2_CMD:-}"
if [[ -z "$d2_cmd" && -x "$root_dir/../d2/bin/d2" ]]; then
  d2_cmd="$root_dir/../d2/bin/d2"
fi
if [[ -z "$d2_cmd" ]]; then
  d2_cmd="$(command -v d2 || true)"
fi

need_d2=false
need_diago=false
[[ "$mode" == "all" || "$mode" == "d2" ]] && need_d2=true
[[ "$mode" == "all" || "$mode" == "diago" ]] && need_diago=true

if $need_d2; then
  [[ -n "$d2_cmd" ]] || {
    echo "Error: d2 command not found. Set D2_CMD or install d2." >&2
    exit 1
  }
  mkdir -p "$examples_dir/d2-dagre-output"
fi

if $need_diago; then
  command -v moon >/dev/null 2>&1 || {
    echo "Error: moon command not found." >&2
    exit 1
  }
  mkdir -p "$examples_dir/diago-dagre-output"
fi

for src in "$examples_dir"/*.d2; do
  name="$(basename "${src%.d2}")"

  if $need_d2; then
    "$d2_cmd" --layout dagre --target '' "$src" "$examples_dir/d2-dagre-output/$name.svg"
  fi

  if $need_diago; then
    moon run cmd/main -- --layout dagre --target '' "$src" "$examples_dir/diago-dagre-output/$name.svg"
  fi
done

echo "Done."
