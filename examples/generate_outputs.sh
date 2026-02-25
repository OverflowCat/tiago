#!/usr/bin/env bash
set -euo pipefail

mode="${1:-all}"
case "$mode" in
  all|d2|diago|railway) ;;
  *)
    echo "Usage: $0 [all|d2|diago|railway]" >&2
    exit 1
    ;;
esac

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
examples_dir="$root_dir/examples"
cd "$root_dir"

d2_cmd="${D2_CMD:-}"
if [[ -z "$d2_cmd" ]]; then
  d2_cmd="$(command -v d2 || true)"
fi
if [[ -z "$d2_cmd" && -x "$root_dir/../d2/bin/d2" ]]; then
  d2_cmd="$root_dir/../d2/bin/d2"
fi

need_d2=false
need_diago=false
need_railway=false
[[ "$mode" == "all" || "$mode" == "d2" ]] && need_d2=true
[[ "$mode" == "all" || "$mode" == "diago" ]] && need_diago=true
[[ "$mode" == "all" || "$mode" == "railway" ]] && need_railway=true

if $need_d2; then
  [[ -n "$d2_cmd" ]] || {
    echo "Error: d2 command not found. Set D2_CMD or install d2." >&2
    exit 1
  }
  mkdir -p "$examples_dir/d2-dagre-output"
  mkdir -p "$examples_dir/d2-elk-svg-output"
  mkdir -p "$examples_dir/d2-elk-ascii-output"
  mkdir -p "$examples_dir/d2-elk-unicode-output"
fi

if $need_diago; then
  command -v moon >/dev/null 2>&1 || {
    echo "Error: moon command not found." >&2
    exit 1
  }
  mkdir -p "$examples_dir/diago-dagre-output"
  mkdir -p "$examples_dir/diago-elk-svg-output"
  mkdir -p "$examples_dir/diago-elk-ascii-output"
  mkdir -p "$examples_dir/diago-elk-unicode-output"
fi

if $need_railway; then
  command -v moon >/dev/null 2>&1 || {
    echo "Error: moon command not found." >&2
    exit 1
  }
  mkdir -p "$examples_dir/diago-railway-svg-output"
  mkdir -p "$examples_dir/diago-railway-ascii-output"
  mkdir -p "$examples_dir/diago-railway-unicode-output"
fi

for src in "$examples_dir"/*.d2; do
  name="$(basename "${src%.d2}")"

  if $need_d2; then
    echo "d2: $name (dagre svg, elk svg/ascii/unicode)"
    "$d2_cmd" --layout dagre --target '' "$src" "$examples_dir/d2-dagre-output/$name.svg"
    "$d2_cmd" --layout elk --target '' "$src" "$examples_dir/d2-elk-svg-output/$name.svg"
    "$d2_cmd" --layout elk --ascii-mode standard --target '' "$src" "$examples_dir/d2-elk-ascii-output/$name.txt"
    "$d2_cmd" --layout elk --ascii-mode extended --target '' "$src" "$examples_dir/d2-elk-unicode-output/$name.txt"
  fi

  if $need_diago; then
    echo "diago: $name (dagre svg, elk svg/ascii/unicode)"
    moon run cmd/main -- --layout dagre --target '' "$src" "$examples_dir/diago-dagre-output/$name.svg"
    moon run cmd/main -- --layout elk --target '' "$src" "$examples_dir/diago-elk-svg-output/$name.svg"
    moon run cmd/main -- --layout elk --ascii --target '' "$src" "$examples_dir/diago-elk-ascii-output/$name.txt"
    moon run cmd/main -- --layout elk --unicode --target '' "$src" "$examples_dir/diago-elk-unicode-output/$name.txt"
  fi

  if $need_railway; then
    echo "diago: $name (railway svg/ascii/unicode)"
    moon run cmd/main -- --layout railway --target '' "$src" "$examples_dir/diago-railway-svg-output/$name.svg"
    moon run cmd/main -- --layout railway --ascii --target '' "$src" "$examples_dir/diago-railway-ascii-output/$name.txt"
    moon run cmd/main -- --layout railway --unicode --target '' "$src" "$examples_dir/diago-railway-unicode-output/$name.txt"
  fi
done

echo "Done."
