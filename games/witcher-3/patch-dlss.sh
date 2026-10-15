#!/usr/bin/env bash
# Game-local Wine gate fixes for one verified Witcher 3 DX12 build.
set -euo pipefail
export LC_ALL=C

readonly ORIGINAL_SHA256="2df765398a3d1f165db418271be7200178320a4466817379f2fa0dc0001fb101"
readonly PATCHED_SHA256="5dc266a88709f0bfe3573ef5f5e3d055dfcd6a5a698a8ab4aa390be34015e419"
readonly DLSS_OFFSET=$((0x1B77ECB))
readonly FG_OFFSET=$((0x1B7CE30))
readonly RT_OFFSET=$((0x1ECEECD))
readonly BACKUP_SUFFIX=".pre-dlss-wine-gate.2df765398a3d"

stage=""
lock=""
lock_identity=""

usage() {
  cat <<'EOF'
The Witcher 3 — CrossOver graphics patch

Apply:   patch-dlss.sh "/path/to/The Witcher 3"
Restore: patch-dlss.sh --restore "/path/to/The Witcher 3"

You can also supply bin/x64_dx12/witcher3.exe directly.
Quit Witcher 3 first. Apply includes DLSS, frame generation and ray tracing.
Normal device and feature support checks remain in place.
A verified original backup is kept beside the executable.
EOF
}

fail() { printf '\nUnable to continue: %s\n' "$*" >&2; exit 1; }
sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
identity() { stat -f '%d:%i:%z:%m:%c:%p:%u:%g:%l' "$1"; }

require_regular() {
  [[ -f "$1" && ! -L "$1" ]] || fail "Expected a regular file, not a symlink: $1"
  [[ "$(stat -f '%l' "$1")" == 1 ]] || fail "Hard-linked files are refused: $1"
  [[ -r "$1" ]] || fail "File is not readable: $1"
}

read_bytes() {
  od -v -An -tx1 -j "$2" -N "$3" "$1" | tr -d '[:space:]'
}

expect_bytes() {
  [[ "$(read_bytes "$1" "$2" "$3")" == "$4" ]] ||
    fail "Unexpected bytes at file offset $(printf '0x%X' "$2"): $1"
}

file_state() {
  case "$1" in
    "$ORIGINAL_SHA256") printf 'original\n' ;;
    "$PATCHED_SHA256") printf 'patched\n' ;;
    *) fail "Unsupported executable SHA-256: $1. Steam may have updated the game, or another mod changed it." ;;
  esac
}

verify_layout() {
  case "$2" in
    original) expect_bytes "$1" "$DLSS_OFFSET" 2 7542 ;;
    patched) expect_bytes "$1" "$DLSS_OFFSET" 2 9090 ;;
  esac
  if [[ "$2" == patched ]]; then
    expect_bytes "$1" "$FG_OFFSET" 2 eb17
    expect_bytes "$1" "$RT_OFFSET" 6 e96701000090
  else
    expect_bytes "$1" "$FG_OFFSET" 2 7417
    expect_bytes "$1" "$RT_OFFSET" 6 0f8466010000
  fi
}

verify_backup() {
  require_regular "$backup"
  [[ "$(sha256_file "$backup")" == "$ORIGINAL_SHA256" ]] ||
    fail "Backup conflict: $backup. Keep it for inspection; it will not be overwritten."
  verify_layout "$backup" original
}

ensure_stopped() {
  local processes candidates pid arguments
  processes="$(/bin/ps -axo pid=,comm=)" || fail "Cannot check running processes. Run from a normal macOS Terminal."
  candidates="$(printf '%s\n' "$processes" | awk '
    { pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "");
      sub(/[[:space:]]+$/, ""); s=tolower($0);
      if (s ~ /(^|[\\\/])witcher3[.]exe$/) print "game";
      else if (s ~ /(^|[\\\/])wine(64)?(-preloader)?$/) print pid }')"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    [[ "$pid" != game ]] || fail "Quit Witcher 3 before applying or restoring the patch."
    arguments="$(/bin/ps -p "$pid" -o args=)" || fail "A Wine process changed during the process check. Try again."
    if printf '%s\n' "$arguments" | awk '
      { if (tolower($0) ~ /(^|[\\\/])witcher3[.]exe([[:space:]"\047]|$)/) found=1 }
      END { exit !found }'; then
      fail "Quit Witcher 3 before applying or restoring the patch."
    fi
  done <<< "$candidates"
}

cleanup() {
  if [[ -n "$stage" ]]; then rm -f -- "$stage"; fi
  if [[ -n "$lock" && -d "$lock" && ! -L "$lock" ]]; then
    if [[ "$(stat -f '%d:%i' "$lock")" == "$lock_identity" ]]; then
      rm -f -- "$lock/pid"
      rmdir -- "$lock" || true
    fi
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

verify_unchanged() {
  require_regular "$executable"
  [[ "$(identity "$executable")" == "$source_identity" &&
     "$(sha256_file "$executable")" == "$source_hash" ]] ||
    fail "The executable changed during validation. Nothing was installed."
}

main() {
  local action=apply supplied parent name state tool expected_hash source_hash source_identity backup
  local executable prospective_lock
  if [[ $# == 1 && "$1" == --help ]]; then usage; return; fi
  if [[ $# == 2 && "$1" == --restore ]]; then
    action=restore; supplied="$2"
  elif [[ $# == 1 && "$1" != --* ]]; then
    supplied="$1"
  else
    usage >&2; exit 2
  fi
  for tool in shasum awk stat od tr cp dd mktemp mv mkdir rmdir rm touch; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required macOS tool is missing: $tool"
  done
  [[ -x /bin/ps ]] || fail "The macOS process checker /bin/ps is missing."
  [[ -n "$supplied" ]] || fail "Supply the game folder or DX12 executable path."
  if [[ -d "$supplied" ]]; then supplied="${supplied%/}/bin/x64_dx12/witcher3.exe"; fi
  [[ ! -L "$supplied" ]] || fail "Executable symlinks are refused. Supply the real path."
  parent="$(cd -- "$(dirname -- "$supplied")" && pwd -P)" || fail "Cannot open the executable folder."
  name="$(basename -- "$supplied")"
  [[ "$name" == witcher3.exe && "${parent##*/}" == x64_dx12 ]] ||
    fail "Supply the game folder or bin/x64_dx12/witcher3.exe. DX11 is not supported."
  executable="$parent/$name"
  backup="${executable}${BACKUP_SUFFIX}"
  require_regular "$executable"
  source_identity="$(identity "$executable")"
  source_hash="$(sha256_file "$executable")"
  state="$(file_state "$source_hash")"
  verify_layout "$executable" "$state"
  [[ -w "$parent" ]] || fail "The executable folder is not writable: $parent"
  if [[ -e "$backup" || -L "$backup" ]]; then
    verify_backup
  elif [[ "$state" != original ]]; then
    fail "The verified original backup is missing: $backup"
  fi
  printf 'Target: %s\nState: %s\nAction: %s\nBackup: %s\n' "$executable" "$state" "$action" "$backup"
  printf 'Scope: this executable only. Normal feature support checks remain in place.\n'
  ensure_stopped

  prospective_lock="${executable}.dlss-wine-gate.lock"
  mkdir -- "$prospective_lock" 2>/dev/null || fail "Operation lock exists or cannot be created: $prospective_lock. See recovery in TECHNICAL.md."
  lock_identity="$(stat -f '%d:%i' "$prospective_lock")"
  lock="$prospective_lock"
  printf '%s\n' "$$" > "$lock/pid"
  verify_unchanged
  if [[ "$action" == apply && "$state" == patched ]]; then
    printf 'The full patch is already installed. Nothing changed.\n'; return
  fi
  if [[ "$action" == restore && "$state" == original ]]; then
    printf 'The original executable is already installed. Nothing changed.\n'; return
  fi

  stage="$(mktemp "${executable}.tmp.XXXXXX")"
  if [[ "$action" == apply ]]; then
    cp -p "$executable" "$stage"
    # One complete instruction per site. Only the staged copy is edited.
    printf '\220\220' | dd of="$stage" bs=1 seek="$DLSS_OFFSET" conv=notrunc 2>/dev/null
    printf '\353\027' | dd of="$stage" bs=1 seek="$FG_OFFSET" conv=notrunc 2>/dev/null
    printf '\351\147\001\000\000\220' | dd of="$stage" bs=1 seek="$RT_OFFSET" conv=notrunc 2>/dev/null
    touch -r "$executable" "$stage"
    expected_hash="$PATCHED_SHA256"
    verify_layout "$stage" patched
  else
    verify_backup
    cp -p "$backup" "$stage"
    expected_hash="$ORIGINAL_SHA256"
    verify_layout "$stage" original
  fi
  [[ "$(sha256_file "$stage")" == "$expected_hash" ]] || fail "Staged output hash did not match. Nothing was installed."
  verify_unchanged
  if [[ "$action" == apply && ! -e "$backup" && ! -L "$backup" ]]; then
    # Exclusive creation also works on filesystems without hard-link support.
    (set -o noclobber; : > "$backup") || fail "A backup appeared during validation. Nothing was installed."
    cp -p "$executable" "$backup"
  fi
  verify_backup
  ensure_stopped
  verify_unchanged
  mv -f -- "$stage" "$executable"
  stage=""
  [[ "$(sha256_file "$executable")" == "$expected_hash" ]] || fail "Installed file verification failed. Keep the verified backup for recovery."
  printf '%s completed and verified. The original backup was kept.\n' "$action"
}

main "$@"
