#!/usr/bin/env bash

# Universal DMC5 HDR patch for the exact executable verified below.
# It enables the separate DX11 and DX12 paths in one game binary.
set -euo pipefail

readonly ORIGINAL_SHA256="1b881b52184fbb4de08740d68e77b49093bf4c5e8310ba185454fd34eba18e1d"
readonly PATCHED_SHA256="9f44117a8a38f54a4c35de0b24932c63e0dab7bce6f72bf1dd0124febe49c5da"

usage() {
  cat <<'EOF'
Devil May Cry 5 HDR patch for CrossOver

Usage:
  patch-hdr.sh
      Start the guided patcher.

  patch-hdr.sh --yes /path/to/DevilMayCry5.exe
      Apply the universal DX11/DX12 HDR patch without prompts.

  patch-hdr.sh --check /path/to/DevilMayCry5.exe
      Report whether the executable is supported, original, or patched.

  patch-hdr.sh --help
      Show this help.
EOF
}

fail() {
  printf '\nUnable to continue: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

read_bytes() {
  local executable="$1" offset="$2" length="$3" size
  size="$(stat -f '%z' "$executable" 2>/dev/null || stat -c '%s' "$executable")"
  ((size >= offset + length)) || { printf 'too-short\n'; return; }
  od -v -An -tx1 -j "$offset" -N "$length" "$executable" | tr -d '[:space:]'
}

expect_bytes() {
  local executable="$1" offset="$2" length="$3" expected="$4" actual
  actual="$(read_bytes "$executable" "$offset" "$length")"
  [[ "$actual" == "$expected" ]] || fail "unexpected bytes at file offset $(printf '0x%X' "$offset")"
}

verify_original_layout() {
  local executable="$1" cave
  expect_bytes "$executable" $((0x02C2CE0F)) 6 0f84c5020000
  expect_bytes "$executable" $((0x02C1E221)) 7 453aa8b7b33000
  expect_bytes "$executable" $((0x02C1EA27)) 2 747f
  expect_bytes "$executable" $((0x02C1EA45)) 2 7461
  expect_bytes "$executable" $((0x02C12CD8)) 5 0f57c04c89
  expect_bytes "$executable" $((0x02BC)) 4 40000040
  cave="$(read_bytes "$executable" $((0x04C75502)) 64)"
  [[ ${#cave} == 128 && "$cave" != *[!c]* ]] || fail "the DX12 patch area is not untouched padding"
}

file_state() {
  local executable="$1" hash
  [[ -f "$executable" ]] || { printf 'missing\n'; return; }
  hash="$(sha256_file "$executable")"
  case "$hash" in
    "$ORIGINAL_SHA256") printf 'original\n' ;;
    "$PATCHED_SHA256") printf 'patched\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

backup_path() {
  printf '%s.pre-hdr\n' "$1"
}

confirm() {
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

require_supported_path() {
  local executable="$1"
  [[ -f "$executable" ]] || fail "The file was not found: $executable"
  [[ "$(basename "$executable")" == "DevilMayCry5.exe" ]] || fail "Please choose the file named DevilMayCry5.exe."
}

write_hex() {
  local executable="$1" offset="$2" hex="$3"
  printf '%s' "$hex" | xxd -r -p | dd of="$executable" bs=1 seek="$offset" conv=notrunc 2>/dev/null
}

apply_patch_bytes() {
  local executable="$1"
  # DX11 HDR renderer gate.
  write_hex "$executable" $((0x02C2CE0F)) 909090909090

  # DX12 native HDR transition and HDR10/PQ swapchain presentation.
  write_hex "$executable" $((0x02C1E221)) e9007d05029090
  write_hex "$executable" $((0x04C75526)) 41c680b7b3300001453aa8b7b330000f9545a8e9ee82fafd
  write_hex "$executable" $((0x02C1EA27)) 9090
  write_hex "$executable" $((0x02C1EA45)) 9090
  write_hex "$executable" $((0x02C12CD8)) e925320602
  write_hex "$executable" $((0x04C75502)) 488b4c24504885c9740e488b01ba0c000000ff90300100000f57c04c897df8e9b9cdf9fd
  # Allow execution only in the existing padding section used by the DX12 hooks.
  write_hex "$executable" $((0x02BC)) 40000060
}

apply_patch() {
  local executable="$1" allow_without_prompt="$2" state backup tmp actual_hash
  require_supported_path "$executable"
  state="$(file_state "$executable")"
  case "$state" in
    patched) printf '\nThis game executable is already patched. Nothing was changed.\n'; return ;;
    original) verify_original_layout "$executable" ;;
    unsupported) fail "This is not the DMC5 version supported by this tool. Nothing was changed. Steam may have updated the game." ;;
    *) fail "The game executable could not be read. Nothing was changed." ;;
  esac

  backup="$(backup_path "$executable")"
  if [[ -e "$backup" ]]; then
    [[ "$(file_state "$backup")" == "original" ]] || fail "A backup already exists but does not match the supported original: $backup"
  fi

  if [[ "$allow_without_prompt" != yes ]]; then
    printf '\nThis will patch only this file:\n  %s\n' "$executable"
    printf 'A safe backup will be kept here:\n  %s\n' "$backup"
    printf 'The resulting binary supports both DX11 and DX12.\n\n'
    confirm "Apply the HDR patch now?" || { printf 'No changes were made.\n'; return; }
  fi

  if [[ ! -e "$backup" ]]; then
    cp -p "$executable" "$backup"
    [[ "$(file_state "$backup")" == original ]] || fail "Backup verification failed."
    printf '\nBackup created.\n'
  fi

  tmp="$(mktemp "${executable}.tmp.XXXXXX")"
  cleanup() { rm -f "$tmp"; }
  trap cleanup RETURN
  cp -p "$executable" "$tmp"
  apply_patch_bytes "$tmp"
  actual_hash="$(sha256_file "$tmp")"
  [[ "$actual_hash" == "$PATCHED_SHA256" ]] || fail "Verification failed. Your original game executable was left untouched."
  mv -f "$tmp" "$executable"
  trap - RETURN
  printf '\nSuccess: the universal DX11/DX12 HDR patch is installed.\n'
  printf 'Your original file is safely kept at:\n  %s\n' "$backup"
}

restore_original() {
  local executable="$1" state backup tmp
  require_supported_path "$executable"
  state="$(file_state "$executable")"
  [[ "$state" == patched ]] || {
    [[ "$state" == original ]] && { printf '\nThis game executable is already original. Nothing was changed.\n'; return; }
    fail "This executable is not recognized. Nothing was changed."
  }
  backup="$(backup_path "$executable")"
  [[ -f "$backup" && "$(file_state "$backup")" == original ]] || fail "A matching original backup was not found. Nothing was changed."
  printf '\nThis will restore the original game executable from:\n  %s\n' "$backup"
  confirm "Restore it now?" || { printf 'No changes were made.\n'; return; }
  tmp="$(mktemp "${executable}.tmp.XXXXXX")"
  cleanup() { rm -f "$tmp"; }
  trap cleanup RETURN
  cp -p "$backup" "$tmp"
  [[ "$(file_state "$tmp")" == original ]] || fail "Backup verification failed. Your patched game executable was left untouched."
  mv -f "$tmp" "$executable"
  trap - RETURN
  printf '\nThe original game executable has been restored. The backup was kept.\n'
}

ask_for_executable() {
  local executable
  printf '\nPaste or drag DevilMayCry5.exe into this window, then press Return.\n> ' >&2
  read -r executable
  executable="${executable#\'}"; executable="${executable%\'}"
  printf '%s\n' "$executable"
}

guided_mode() {
  local choice executable
  while true; do
    cat <<'EOF'

Devil May Cry 5 — HDR patch for CrossOver

This tool installs one verified game binary that supports DirectX 11 and 12.
It checks the game version and creates a backup first.

1) Apply the universal DX11/DX12 HDR patch
2) Restore the original game executable
3) Quit
EOF
    printf '\nChoose an option: '; read -r choice
    case "$choice" in
      1) executable="$(ask_for_executable)"; apply_patch "$executable" no ;;
      2) executable="$(ask_for_executable)"; restore_original "$executable" ;;
      3|q|Q) printf 'No changes were made.\n'; return ;;
      *) printf 'Please enter 1, 2, or 3.\n' ;;
    esac
  done
}

case "${1:-}" in
  "") guided_mode ;;
  --yes) (($# == 2)) || fail "--yes needs the full path to DevilMayCry5.exe"; apply_patch "$2" yes ;;
  --check) (($# == 2)) || fail "--check needs the full path to DevilMayCry5.exe"; require_supported_path "$2"; printf '%s\n' "$(file_state "$2")" ;;
  -h|--help) (($# == 1)) || fail "--help does not take another option"; usage ;;
  *) fail "Use the guided tool with no options, --yes, or --check. Try --help for details." ;;
esac
