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

need_d2=false
need_diago=false
[[ "$mode" == "all" || "$mode" == "d2" ]] && need_d2=true
[[ "$mode" == "all" || "$mode" == "diago" ]] && need_diago=true

if $need_d2; then
  command -v d2 >/dev/null 2>&1 || {
    echo "Error: d2 command not found." >&2
    exit 1
  }
  mkdir -p \
    "$examples_dir/d2-dagre-output" \
    "$examples_dir/d2-dagre-ascii-output" \
    "$examples_dir/d2-dagre-unicode-output"
fi

if $need_diago; then
  command -v moon >/dev/null 2>&1 || {
    echo "Error: moon command not found." >&2
    exit 1
  }
  mkdir -p \
    "$examples_dir/diago-dagre-output" \
    "$examples_dir/diago-dagre-ascii-output" \
    "$examples_dir/diago-dagre-unicode-output"
fi

for src in "$examples_dir"/*.d2; do
  name="$(basename "${src%.d2}")"

  if $need_d2; then
    d2 --layout dagre --target '' "$src" "$examples_dir/d2-dagre-output/$name.svg"
    d2 --layout dagre --target '' --ascii-mode standard "$src" "$examples_dir/d2-dagre-ascii-output/$name.txt"
    d2 --layout dagre --target '' --ascii-mode extended "$src" "$examples_dir/d2-dagre-unicode-output/$name.txt"
  fi

  if $need_diago; then
    moon run cmd/main -- --layout dagre --target '' "$src" "$examples_dir/diago-dagre-output/$name.svg"
    moon run cmd/main -- --layout dagre --target '' --ascii "$src" "$examples_dir/diago-dagre-ascii-output/$name.txt"
    moon run cmd/main -- --layout dagre --target '' --unicode "$src" "$examples_dir/diago-dagre-unicode-output/$name.txt"
  fi
done

echo "Done."
