#!/usr/bin/env bash
set -euo pipefail

mode="${1:-all}"
case "$mode" in
  all|reference|diago|railway) ;;
  *)
    echo "Usage: $0 [all|reference|diago|railway]" >&2
    exit 1
    ;;
esac

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
examples_dir="$root_dir/examples"
cd "$root_dir"

reference_cmd="${REFERENCE_CMD:-}"
if [[ -z "$reference_cmd" ]]; then
  reference_cmd="$(command -v d2 || true)"
fi

need_reference=false
need_diago=false
need_railway=false
[[ "$mode" == "all" || "$mode" == "reference" ]] && need_reference=true
[[ "$mode" == "all" || "$mode" == "diago" ]] && need_diago=true
[[ "$mode" == "all" || "$mode" == "railway" ]] && need_railway=true

if $need_reference; then
  [[ -n "$reference_cmd" ]] || {
    echo "Error: reference renderer command not found. Set REFERENCE_CMD." >&2
    exit 1
  }
  mkdir -p "$examples_dir/reference-dagre-output"
  mkdir -p "$examples_dir/reference-elk-svg-output"
  mkdir -p "$examples_dir/reference-elk-ascii-output"
  mkdir -p "$examples_dir/reference-elk-unicode-output"
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

  if $need_reference; then
    echo "reference: $name (dagre svg, elk svg/ascii/unicode)"
    "$reference_cmd" --layout dagre --target '' "$src" "$examples_dir/reference-dagre-output/$name.svg"
    "$reference_cmd" --layout elk --target '' "$src" "$examples_dir/reference-elk-svg-output/$name.svg"
    "$reference_cmd" --layout elk --ascii-mode standard --target '' "$src" "$examples_dir/reference-elk-ascii-output/$name.txt"
    "$reference_cmd" --layout elk --ascii-mode extended --target '' "$src" "$examples_dir/reference-elk-unicode-output/$name.txt"
  fi

  if $need_diago; then
    echo "diago: $name (dagre svg, elk svg/ascii/unicode)"
    moon run --target native cmd/diago -- render --layout dagre --target '' "$src" "$examples_dir/diago-dagre-output/$name.svg"
    moon run --target native cmd/diago -- render --layout elk --target '' "$src" "$examples_dir/diago-elk-svg-output/$name.svg"
    moon run --target native cmd/diago -- render --layout elk --format ascii --target '' "$src" "$examples_dir/diago-elk-ascii-output/$name.txt"
    moon run --target native cmd/diago -- render --layout elk --format unicode --target '' "$src" "$examples_dir/diago-elk-unicode-output/$name.txt"
  fi

  if $need_railway; then
    echo "diago: $name (railway svg/ascii/unicode)"
    moon run --target native cmd/diago -- render --layout railway --target '' "$src" "$examples_dir/diago-railway-svg-output/$name.svg"
    moon run --target native cmd/diago -- render --layout railway --format ascii --target '' "$src" "$examples_dir/diago-railway-ascii-output/$name.txt"
    moon run --target native cmd/diago -- render --layout railway --format unicode --target '' "$src" "$examples_dir/diago-railway-unicode-output/$name.txt"
  fi
done

echo "Done."
