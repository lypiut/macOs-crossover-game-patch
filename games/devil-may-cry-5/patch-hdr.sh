#!/usr/bin/env bash

set -euo pipefail

# This patch is intentionally limited to the DMC5 build verified below.
readonly ORIGINAL_SHA256="1b881b52184fbb4de08740d68e77b49093bf4c5e8310ba185454fd34eba18e1d"
readonly PATCHED_SHA256="d9e3406b5d2f0a60eb999882eb36c17602ccfa0c84b763b3ac2112d9e668d643"
readonly PATCH_OFFSET=$((0x02C2CE0F))
readonly ORIGINAL_BYTES="0f84c5020000"
readonly PATCHED_BYTES="909090909090"

usage() {
  cat <<'EOF'
Devil May Cry 5 HDR patch for CrossOver

Usage:
  patch-hdr.sh
      Start the guided patcher.

  patch-hdr.sh --yes /path/to/DevilMayCry5.exe
      Apply the patch without prompts. A backup is still created first.

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

read_patch_bytes() {
  local size

  size="$(stat -f '%z' "$1" 2>/dev/null || stat -c '%s' "$1")"
  if ((size < PATCH_OFFSET + 6)); then
    printf 'too-short\n'
    return
  fi
  od -An -tx1 -j "$PATCH_OFFSET" -N 6 "$1" | tr -d '[:space:]'
}

file_state() {
  local executable="$1"
  local hash bytes

  [[ -f "$executable" ]] || {
    printf 'missing\n'
    return
  }

  hash="$(sha256_file "$executable")"
  bytes="$(read_patch_bytes "$executable")"
  case "$hash:$bytes" in
    "$ORIGINAL_SHA256:$ORIGINAL_BYTES") printf 'original\n' ;;
    "$PATCHED_SHA256:$PATCHED_BYTES") printf 'patched\n' ;;
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
  [[ "$(basename "$executable")" == "DevilMayCry5.exe" ]] || \
    fail "Please choose the file named DevilMayCry5.exe."
}

apply_patch() {
  local executable="$1"
  local allow_without_prompt="$2"
  local state backup tmp actual_hash actual_bytes

  require_supported_path "$executable"
  state="$(file_state "$executable")"
  case "$state" in
    patched)
      printf '\nThis game executable is already patched. Nothing was changed.\n'
      return
      ;;
    original)
      ;;
    unsupported)
      fail "This is not the DMC5 version supported by this tool. Nothing was changed. Steam may have updated the game."
      ;;
    *)
      fail "The game executable could not be read. Nothing was changed."
      ;;
  esac

  backup="$(backup_path "$executable")"
  if [[ -e "$backup" ]]; then
    [[ "$(file_state "$backup")" == "original" ]] || \
      fail "A backup already exists but does not match the supported original: $backup"
  fi

  if [[ "$allow_without_prompt" != "yes" ]]; then
    printf '\nThis will patch only this file:\n  %s\n' "$executable"
    printf 'A safe backup will be kept here:\n  %s\n' "$backup"
    printf 'You can restore the original from this menu at any time.\n\n'
    confirm "Apply the HDR patch now?" || {
      printf 'No changes were made.\n'
      return
    }
  fi

  if [[ ! -e "$backup" ]]; then
    cp -p "$executable" "$backup"
    printf '\nBackup created.\n'
  fi

  tmp="$(mktemp "${executable}.tmp.XXXXXX")"
  cleanup() { rm -f "$tmp"; }
  trap cleanup RETURN

  cp -p "$executable" "$tmp"
  printf '\220\220\220\220\220\220' | \
    dd of="$tmp" bs=1 seek="$PATCH_OFFSET" conv=notrunc 2>/dev/null

  actual_hash="$(sha256_file "$tmp")"
  actual_bytes="$(read_patch_bytes "$tmp")"
  [[ "$actual_hash" == "$PATCHED_SHA256" && "$actual_bytes" == "$PATCHED_BYTES" ]] || \
    fail "Verification failed. Your original game executable was left untouched."

  mv -f "$tmp" "$executable"
  trap - RETURN
  printf '\nSuccess: the DX11 HDR patch is installed.\n'
  printf 'Your original file is safely kept at:\n  %s\n' "$backup"
}

restore_original() {
  local executable="$1"
  local state backup tmp

  require_supported_path "$executable"
  state="$(file_state "$executable")"
  [[ "$state" == "patched" ]] || {
    if [[ "$state" == "original" ]]; then
      printf '\nThis game executable is already original. Nothing was changed.\n'
      return
    fi
    fail "This executable is not recognized. Nothing was changed."
  }

  backup="$(backup_path "$executable")"
  [[ -f "$backup" && "$(file_state "$backup")" == "original" ]] || \
    fail "A matching original backup was not found. Nothing was changed."

  printf '\nThis will restore the original game executable from:\n  %s\n' "$backup"
  confirm "Restore it now?" || {
    printf 'No changes were made.\n'
    return
  }

  tmp="$(mktemp "${executable}.tmp.XXXXXX")"
  cleanup() { rm -f "$tmp"; }
  trap cleanup RETURN
  cp -p "$backup" "$tmp"
  [[ "$(file_state "$tmp")" == "original" ]] || \
    fail "Backup verification failed. Your patched game executable was left untouched."
  mv -f "$tmp" "$executable"
  trap - RETURN
  printf '\nThe original game executable has been restored. The backup was kept.\n'
}

ask_for_executable() {
  local executable
  printf '\nPaste or drag DevilMayCry5.exe into this window, then press Return.\n> ' >&2
  read -r executable
  executable="${executable#\'}"
  executable="${executable%\'}"
  printf '%s\n' "$executable"
}

guided_mode() {
  local choice executable

  while true; do
    cat <<'EOF'

Devil May Cry 5 — HDR patch for CrossOver

This tool changes one verified location in the game executable.
It checks the game version before doing anything and creates a backup first.

1) Apply the DX11 HDR patch
2) Restore the original game executable
3) Quit
EOF
    printf '\nChoose an option: '
    read -r choice
    case "$choice" in
      1)
        executable="$(ask_for_executable)"
        apply_patch "$executable" "no"
        ;;
      2)
        executable="$(ask_for_executable)"
        restore_original "$executable"
        ;;
      3|q|Q)
        printf 'No changes were made.\n'
        return
        ;;
      *)
        printf 'Please enter 1, 2, or 3.\n'
        ;;
    esac
  done
}

case "${1:-}" in
  "")
    guided_mode
    ;;
  --yes)
    (($# == 2)) || fail "--yes needs the full path to DevilMayCry5.exe"
    apply_patch "$2" "yes"
    ;;
  -h|--help)
    (($# == 1)) || fail "--help does not take another option"
    usage
    ;;
  *)
    fail "Use the guided tool with no options, or use --yes for automation. Try --help for details."
    ;;
esac
