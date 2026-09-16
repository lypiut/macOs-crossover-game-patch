#!/usr/bin/env bash

set -euo pipefail

readonly ORIGINAL_SHA256="1b881b52184fbb4de08740d68e77b49093bf4c5e8310ba185454fd34eba18e1d"
readonly PATCHED_SHA256="d9e3406b5d2f0a60eb999882eb36c17602ccfa0c84b763b3ac2112d9e668d643"
readonly PATCH_OFFSET=$((0x02C2CE0F))
readonly ORIGINAL_BYTES="0f84c5020000"
readonly PATCHED_BYTES="909090909090"

usage() {
  cat <<'EOF'
Usage:
  patch-hdr.sh [--output PATH] DevilMayCry5.exe
  patch-hdr.sh --in-place DevilMayCry5.exe
  patch-hdr.sh --check DevilMayCry5.exe

By default, writes DevilMayCry5.hdr.exe beside the input file.
--in-place first creates DevilMayCry5.exe.pre-hdr.
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

read_patch_bytes() {
  od -An -tx1 -j "$PATCH_OFFSET" -N 6 "$1" | tr -d '[:space:]'
}

mode="patch"
output=""
input=""

while (($#)); do
  case "$1" in
    --check)
      mode="check"
      shift
      ;;
    --in-place)
      mode="in-place"
      shift
      ;;
    --output)
      (($# >= 2)) || fail "--output requires a path"
      output="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      (($# == 1)) || fail "expected exactly one executable after --"
      input="$1"
      shift
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "$input" ]] || fail "expected exactly one executable"
      input="$1"
      shift
      ;;
  esac
done

[[ -n "$input" ]] || {
  usage >&2
  exit 2
}
[[ -f "$input" ]] || fail "file not found: $input"
[[ "$mode" != "check" || -z "$output" ]] || fail "--check and --output cannot be combined"
[[ "$mode" != "in-place" || -z "$output" ]] || fail "--in-place and --output cannot be combined"

input_hash="$(sha256_file "$input")"
input_bytes="$(read_patch_bytes "$input")"

if [[ "$mode" == "check" ]]; then
  case "$input_hash:$input_bytes" in
    "$ORIGINAL_SHA256:$ORIGINAL_BYTES")
      printf 'supported original: %s\n' "$input"
      ;;
    "$PATCHED_SHA256:$PATCHED_BYTES")
      printf 'supported patched: %s\n' "$input"
      ;;
    *)
      fail "unsupported or modified executable (sha256: $input_hash, bytes: $input_bytes)"
      ;;
  esac
  exit 0
fi

if [[ "$input_hash" == "$PATCHED_SHA256" && "$input_bytes" == "$PATCHED_BYTES" ]]; then
  printf 'already patched: %s\n' "$input"
  exit 0
fi

[[ "$input_hash" == "$ORIGINAL_SHA256" ]] || \
  fail "unsupported executable hash: $input_hash"
[[ "$input_bytes" == "$ORIGINAL_BYTES" ]] || \
  fail "unexpected bytes at patch offset: $input_bytes"

if [[ "$mode" == "in-place" ]]; then
  output="$input"
  backup="${input}.pre-hdr"
  if [[ -e "$backup" ]]; then
    [[ "$(sha256_file "$backup")" == "$ORIGINAL_SHA256" ]] || \
      fail "refusing to overwrite non-matching backup: $backup"
  else
    cp -p "$input" "$backup"
    printf 'backup created: %s\n' "$backup"
  fi
elif [[ -z "$output" ]]; then
  case "$input" in
    *.exe) output="${input%.exe}.hdr.exe" ;;
    *) output="${input}.hdr.exe" ;;
  esac
fi

if [[ "$output" != "$input" && -e "$output" ]]; then
  if [[ "$(sha256_file "$output")" == "$PATCHED_SHA256" ]]; then
    printf 'already patched: %s\n' "$output"
    exit 0
  fi
  fail "refusing to overwrite existing output: $output"
fi

output_dir="$(dirname "$output")"
[[ -d "$output_dir" ]] || fail "output directory does not exist: $output_dir"

tmp="$(mktemp "${output}.tmp.XXXXXX")"
cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT HUP INT TERM

cp -p "$input" "$tmp"
printf '\220\220\220\220\220\220' | \
  dd of="$tmp" bs=1 seek="$PATCH_OFFSET" conv=notrunc 2>/dev/null

actual_hash="$(sha256_file "$tmp")"
actual_bytes="$(read_patch_bytes "$tmp")"
[[ "$actual_bytes" == "$PATCHED_BYTES" ]] || \
  fail "patch verification failed: wrote $actual_bytes"
[[ "$actual_hash" == "$PATCHED_SHA256" ]] || \
  fail "patched hash verification failed: $actual_hash"

mv -f "$tmp" "$output"
trap - EXIT HUP INT TERM
printf 'patched executable written: %s\n' "$output"
printf 'sha256: %s\n' "$actual_hash"
