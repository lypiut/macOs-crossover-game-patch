#!/usr/bin/env bash

# Experimental static HDR patch for Mafia: Definitive Edition GOG 1.0.3 v2.
# It patches only the game executable and its game-owned DX11 shader cache.
set -euo pipefail

readonly ORIGINAL_EXE_SHA256="f063bf8ce27cee297abb6c374f383a922cf772f6984797fee9b4456986516abf"
readonly PATCHED_EXE_SHA256="fc0cbcce2b4aaca344f9a2b1566f371aa9a32831a7ef2e6f3aeddab86c823429"
readonly LEGACY_SCRGB_EXE_SHA256="d56b36ab376d9474eebfd0f62a2dbf5e529e54b82aa6aaf48a5dbdb8a8683467"
readonly ORIGINAL_CACHE_SHA256="b39eb3bca641020bd88ac27132f83d1d2ac4cdf521cc48565b5da9126317473f"
readonly PATCHED_CACHE_SHA256="6ef65ce9259d2f2e40d6a1a58264b1932727e8082d1fe684e6aacb4d131f05bb"
readonly ORIGINAL_EXE_SIZE=111434896
readonly PATCHED_EXE_SIZE=111439360
readonly ORIGINAL_CACHE_SIZE=19602354
readonly PATCHED_CACHE_SIZE=19767922
readonly ASSET_ARCHIVE_SHA256="93546dad0c22f65811e156baeb5a6b1523487b54ce17e44ee0d25186f73f1fdd"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ASSET_BUNDLE="${SCRIPT_DIR}/assets/mafiade-hdr-assets.tar.gz.b64"

ASSET_TEMP=""
ASSET_DIR=""
EXE_TEMP=""
CACHE_TEMP=""
ROLLBACK_TEMP=""
TRANSACTION_MODE=""

usage() {
  cat <<'EOF'
Mafia: Definitive Edition experimental static HDR patch

Usage:
  patch-hdr.sh
      Start the guided patcher.

  patch-hdr.sh --yes /path/to/mafiadefinitiveedition.exe
      Apply the HDR patch without prompts.

  patch-hdr.sh --restore --yes /path/to/mafiadefinitiveedition.exe
      Restore both original game files without prompts.

  patch-hdr.sh --check /path/to/mafiadefinitiveedition.exe
      Show the current patch state without changing anything.

  patch-hdr.sh --help
      Show this help.

Only GOG 1.0.3 v2 is supported. The game must be stopped.
EOF
}

fail() {
  printf '\nUnable to continue: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
  stat -f '%z' "$1" 2>/dev/null || stat -c '%s' "$1"
}

read_bytes() {
  local file="$1" offset="$2" length="$3" size
  size="$(file_size "$file")"
  ((size >= offset + length)) || { printf 'too-short\n'; return; }
  od -v -An -tx1 -j "$offset" -N "$length" "$file" | tr -d '[:space:]'
}

expect_bytes() {
  local file="$1" offset="$2" length="$3" expected="$4" actual
  actual="$(read_bytes "$file" "$offset" "$length")"
  [[ "$actual" == "$expected" ]] || \
    fail "unexpected bytes at file offset $(printf '0x%X' "$offset") in $file"
}

write_hex() {
  local file="$1" offset="$2" hex="$3"
  printf '%s' "$hex" | xxd -r -p | \
    dd of="$file" bs=1 seek="$offset" conv=notrunc 2>/dev/null
}

append_hex() {
  printf '%s' "$1" | xxd -r -p
}

append_range() {
  local input="$1" offset="$2" length="$3"
  xxd -s "$offset" -l "$length" -p "$input" | xxd -r -p
}

cache_path() {
  printf '%s/edit/shaders/shaders_binaries_[dx11].sc\n' "$(dirname -- "$1")"
}

backup_path() {
  local file="$1" original_hash="$2"
  printf '%s.pre-hdr.%s\n' "$file" "${original_hash:0:12}"
}

file_state() {
  local file="$1" original_hash="$2" patched_hash="$3" legacy_hash="${4:-}" hash
  [[ -f "$file" && ! -L "$file" ]] || { printf 'missing-or-symlink\n'; return; }
  hash="$(sha256_file "$file")"
  case "$hash" in
    "$original_hash") printf 'original\n' ;;
    "$patched_hash") printf 'patched\n' ;;
    "$legacy_hash") [[ -n "$legacy_hash" ]] && printf 'legacy-scrgb-patched\n' || printf 'unsupported\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

require_tools() {
  local tool
  for tool in awk base64 dd find mktemp od shasum stat tar tr xxd; do
    command -v "$tool" >/dev/null 2>&1 || fail "required macOS tool not found: $tool"
  done
}

require_supported_path() {
  local executable="$1" cache
  [[ "$(basename -- "$executable")" == "mafiadefinitiveedition.exe" ]] || \
    fail "choose the file named mafiadefinitiveedition.exe"
  [[ -f "$executable" && ! -L "$executable" ]] || \
    fail "the executable is missing or is a symbolic link: $executable"
  cache="$(cache_path "$executable")"
  [[ -f "$cache" && ! -L "$cache" ]] || \
    fail "the DX11 shader cache is missing or is a symbolic link: $cache"
}

require_game_stopped() {
  if command -v pgrep >/dev/null 2>&1 && \
      pgrep -if '[m]afiadefinitiveedition\.exe' >/dev/null 2>&1; then
    fail "Mafia: Definitive Edition is running. Quit the game first."
  fi
}

verify_original_executable_layout() {
  local executable="$1"
  [[ "$(file_size "$executable")" == "$ORIGINAL_EXE_SIZE" ]] || \
    fail "the supported executable has an unexpected size"
  expect_bytes "$executable" $((0x1BE)) 2 0c00
  expect_bytes "$executable" $((0x208)) 4 00900307
  expect_bytes "$executable" $((0x210)) 4 4cefa406
  expect_bytes "$executable" $((0x260)) 8 0040a406901c0000
  expect_bytes "$executable" $((0x4A0)) 40 \
    00000000000000000000000000000000000000000000000000000000000000000000000000000000
  expect_bytes "$executable" $((0x3B17DE8)) 7 c745c01c000000
  expect_bytes "$executable" $((0x3B17BB1)) 43 \
    488b4a204c8d4a30488978084c8d05e49a49014c89601833d24c8968204c8970e04c8978d8488b01ff5048
  expect_bytes "$executable" $((0x3B17BF8)) 4 1c000000
  expect_bytes "$executable" $((0x3B17C1F)) 4 1d000000
  expect_bytes "$executable" $((0x3B17C52)) 4 1c000000
  expect_bytes "$executable" $((0x3B17CB3)) 4 15000000
  expect_bytes "$executable" $((0x3B0803A)) 14 48897350488b742430488b5c2438
  expect_bytes "$executable" $((0x3B1BF4D)) 14 498b064533c08bd6498bceff5040
}

verify_backup() {
  local backup="$1" expected_hash="$2"
  [[ -e "$backup" ]] || return 1
  [[ -f "$backup" && ! -L "$backup" ]] || \
    fail "a backup path exists but is not a regular file: $backup"
  [[ "$(sha256_file "$backup")" == "$expected_hash" ]] || \
    fail "an existing backup does not match the supported original: $backup"
  return 0
}

create_backup() {
  local source="$1" backup="$2" expected_hash="$3"
  if verify_backup "$backup" "$expected_hash"; then return; fi
  cp -p "$source" "$backup"
  [[ "$(sha256_file "$backup")" == "$expected_hash" ]] || \
    fail "backup verification failed: $backup"
}

decode_assets() {
  local archive file expected actual
  [[ -f "$ASSET_BUNDLE" && ! -L "$ASSET_BUNDLE" ]] || \
    fail "the bundled HDR assets are missing or are a symbolic link: $ASSET_BUNDLE"
  ASSET_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mafiade-hdr-assets.XXXXXX")"
  archive="${ASSET_TEMP}/assets.tar.gz"
  if ! base64 -D <"$ASSET_BUNDLE" >"$archive" 2>/dev/null; then
    base64 -d <"$ASSET_BUNDLE" >"$archive" 2>/dev/null || \
      fail "the bundled HDR assets could not be decoded"
  fi
  [[ "$(sha256_file "$archive")" == "$ASSET_ARCHIVE_SHA256" ]] || \
    fail "the bundled HDR asset archive failed verification"
  ASSET_DIR="${ASSET_TEMP}/files"
  mkdir "$ASSET_DIR"
  tar -xzf "$archive" -C "$ASSET_DIR"
  [[ -z "$(find "$ASSET_DIR" -type l -print -quit)" ]] || \
    fail "the bundled HDR asset archive contains a symbolic link"
  while read -r expected file; do
    [[ -f "${ASSET_DIR}/${file}" && ! -L "${ASSET_DIR}/${file}" ]] || \
      fail "a bundled HDR asset is missing: $file"
    actual="$(sha256_file "${ASSET_DIR}/${file}")"
    [[ "$actual" == "$expected" ]] || fail "a bundled HDR asset failed verification: $file"
  done <<'EOF'
9f39defe736be985173ae58342ce9704051829f14f6cf49e32d4b7e58c73d7b7 dof7.dxbc
721efcd975bfa5e794e628d93c7a67c34c0218cf0d0d175816837c23978505af fireworks.dxbc
cb5ffedb4d34797f46d606ffdbbac83d60bb306c6e28c8728e15e072a9333c86 loading.dxbc
84f4c5c6b6b5d6dd7ce57eaafc3c48c8181be5616923d0536fd89f04133bc409 lowhealth.dxbc
7f34283b5f0b93a3226a4f8fec81c9f81da18312d9df8bc72fc4e10658624cfa mafiade-hdr-section.bin
41ad69465e6e9d197eb62c4f5ce69c25f0104ee4fd54f6c6dc79fdbf060c686f something.dxbc
3c844d6e7457d525096a8347c6cc32c4267c2916dd1e8a191085cb4111a16fda tonemap.dxbc
2f06d5c29d77a26fa40a3e6be2dca57e019e3f274b6a5ec58f945ded73ba3410 videos.dxbc
7c0a511608341e03baa75745ecfa50a8a1de5e43fe6d8dea3008ccfd6b0ad117 videos2.dxbc
EOF
  [[ "$(file_size "${ASSET_DIR}/mafiade-hdr-section.bin")" == 4096 ]] || \
    fail "the executable section asset has an unexpected size"
}

build_patched_executable() {
  local source="$1" output="$2" section="${ASSET_DIR}/mafiade-hdr-section.bin" actual_hash
  cp -p "$source" "$output"
  dd if=/dev/zero of="$output" bs=1 seek="$ORIGINAL_EXE_SIZE" count=368 conv=notrunc 2>/dev/null
  dd if="$section" of="$output" bs=1 seek=$((0x6A45E00)) conv=notrunc 2>/dev/null

  write_hex "$output" $((0x1BE)) 0d00
  write_hex "$output" $((0x208)) 00a00307
  write_hex "$output" $((0x210)) 00000000
  write_hex "$output" $((0x260)) 0000000000000000
  write_hex "$output" $((0x4A0)) \
    2e68647200000000780f00000090030700100000005ea406000000000000000000000000200000e0

  write_hex "$output" $((0x3B17DE8)) c745c018000000
  write_hex "$output" $((0x3B17BB1)) \
    488978084c8960184c8968204c8970e04c8978d84889f14889dae8300a5203e90700000090909090909090
  write_hex "$output" $((0x3B17BF8)) 0a000000
  write_hex "$output" $((0x3B17C1F)) 0a000000
  write_hex "$output" $((0x3B17C52)) 0a000000
  write_hex "$output" $((0x3B17CB3)) 20000000
  write_hex "$output" $((0x3B0803A)) e921155303909090909090909090
  write_hex "$output" $((0x3B1BF4D)) 4889f989f2e899c9510390909090

  [[ "$(file_size "$output")" == "$PATCHED_EXE_SIZE" ]] || \
    fail "the staged executable has an unexpected size"
  actual_hash="$(sha256_file "$output")"
  [[ "$actual_hash" == "$PATCHED_EXE_SHA256" ]] || \
    fail "staged executable verification failed ($actual_hash); the installed game was not changed"
}

build_patched_cache() {
  local source="$1" output="$2" cursor=0 index header_offset range_length
  local names=(videos2 lowhealth fireworks loading dof7 videos something tonemap)
  local offsets=(4901394 5059206 9747712 12072256 13358916 14818784 15379744 16691212)
  local sizes=(444 2420 6344 896 1364 1004 2772 9704)
  local size_hex=(a8010000 78110000 3c240000 2c040000 580d0000 4c930000 dc120000 2cf90100)

  cp -p "$source" "$output"
  : >"$output"
  for index in 0 1 2 3 4 5 6 7; do
    header_offset=$((offsets[index] - 18))
    range_length=$((header_offset - cursor))
    append_range "$source" "$cursor" "$range_length" >>"$output"
    append_range "$source" "$header_offset" 14 >>"$output"
    append_hex "${size_hex[index]}" >>"$output"
    append_range "${ASSET_DIR}/${names[index]}.dxbc" 0 \
      "$(file_size "${ASSET_DIR}/${names[index]}.dxbc")" >>"$output"
    cursor=$((offsets[index] + sizes[index]))
  done
  append_range "$source" "$cursor" $((ORIGINAL_CACHE_SIZE - cursor)) >>"$output"

  [[ "$(file_size "$output")" == "$PATCHED_CACHE_SIZE" ]] || \
    fail "the staged shader cache has an unexpected size"
  [[ "$(sha256_file "$output")" == "$PATCHED_CACHE_SHA256" ]] || \
    fail "staged shader-cache verification failed; the installed game was not changed"
}

cleanup() {
  local executable cache cache_backup current_exe current_cache
  set +e
  if [[ "$TRANSACTION_MODE" == apply && -n "${TARGET_EXE:-}" ]]; then
    executable="$TARGET_EXE"
    cache="$(cache_path "$executable")"
    current_exe="$(file_state "$executable" "$ORIGINAL_EXE_SHA256" "$PATCHED_EXE_SHA256" "$LEGACY_SCRGB_EXE_SHA256")"
    current_cache="$(file_state "$cache" "$ORIGINAL_CACHE_SHA256" "$PATCHED_CACHE_SHA256")"
    if [[ "$current_exe" == original && "$current_cache" == patched ]]; then
      cache_backup="$(backup_path "$cache" "$ORIGINAL_CACHE_SHA256")"
      if [[ -f "$cache_backup" && "$(sha256_file "$cache_backup")" == "$ORIGINAL_CACHE_SHA256" ]]; then
        cp -p "$cache_backup" "${cache}.rollback.$$" && mv -f "${cache}.rollback.$$" "$cache"
      fi
    fi
  elif [[ "$TRANSACTION_MODE" == restore && -n "$ROLLBACK_TEMP" && -f "$ROLLBACK_TEMP" && -n "${TARGET_EXE:-}" ]]; then
    executable="$TARGET_EXE"
    cache="$(cache_path "$executable")"
    current_exe="$(file_state "$executable" "$ORIGINAL_EXE_SHA256" "$PATCHED_EXE_SHA256" "$LEGACY_SCRGB_EXE_SHA256")"
    current_cache="$(file_state "$cache" "$ORIGINAL_CACHE_SHA256" "$PATCHED_CACHE_SHA256")"
    if [[ ("$current_exe" == patched || "$current_exe" == legacy-scrgb-patched) && "$current_cache" == original ]]; then
      mv -f "$ROLLBACK_TEMP" "$cache"
      ROLLBACK_TEMP=""
    fi
  fi
  [[ -z "$EXE_TEMP" ]] || rm -f "$EXE_TEMP"
  [[ -z "$CACHE_TEMP" ]] || rm -f "$CACHE_TEMP"
  [[ -z "$ROLLBACK_TEMP" ]] || rm -f "$ROLLBACK_TEMP"
  [[ -z "$ASSET_TEMP" ]] || rm -rf "$ASSET_TEMP"
}

trap cleanup EXIT
trap 'exit 130' HUP INT TERM

confirm() {
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

report_state() {
  local executable="$1" cache
  cache="$(cache_path "$executable")"
  printf 'build: GOG 1.0.3 v2\nexecutable: %s\nshader-cache: %s\n' \
    "$(file_state "$executable" "$ORIGINAL_EXE_SHA256" "$PATCHED_EXE_SHA256" "$LEGACY_SCRGB_EXE_SHA256")" \
    "$(file_state "$cache" "$ORIGINAL_CACHE_SHA256" "$PATCHED_CACHE_SHA256")"
}

apply_patch() {
  local executable="$1" unattended="$2" cache exe_state cache_state exe_backup cache_backup
  TARGET_EXE="$executable"
  require_tools
  require_supported_path "$executable"
  require_game_stopped
  cache="$(cache_path "$executable")"
  exe_state="$(file_state "$executable" "$ORIGINAL_EXE_SHA256" "$PATCHED_EXE_SHA256" "$LEGACY_SCRGB_EXE_SHA256")"
  cache_state="$(file_state "$cache" "$ORIGINAL_CACHE_SHA256" "$PATCHED_CACHE_SHA256")"
  if [[ "$exe_state" == patched && "$cache_state" == patched ]]; then
    printf '\nThe experimental HDR patch is already installed. Nothing was changed.\n'
    return
  fi
  [[ "$exe_state" != legacy-scrgb-patched ]] || \
    fail "the earlier scRGB prototype is installed. Restore it with --restore --yes, then apply this HDR10/PQ revision."
  [[ "$exe_state" == original && "$cache_state" == original ]] || \
    fail "the two files are not a supported, consistent original pair. Run --check; use --restore only if verified patch backups exist."
  [[ "$(file_size "$cache")" == "$ORIGINAL_CACHE_SIZE" ]] || \
    fail "the supported shader cache has an unexpected size"
  verify_original_executable_layout "$executable"

  exe_backup="$(backup_path "$executable" "$ORIGINAL_EXE_SHA256")"
  cache_backup="$(backup_path "$cache" "$ORIGINAL_CACHE_SHA256")"
  [[ ! -e "$exe_backup" ]] || verify_backup "$exe_backup" "$ORIGINAL_EXE_SHA256"
  [[ ! -e "$cache_backup" ]] || verify_backup "$cache_backup" "$ORIGINAL_CACHE_SHA256"
  decode_assets
  if [[ "$unattended" != yes ]]; then
    printf '\nThis experimental patch changes two game-owned files:\n  %s\n  %s\n' "$executable" "$cache"
    printf 'Verified backups will be kept beside both files.\n'
    printf 'No Wine, CrossOver, ReShade, RenoDX, or registry component is installed.\n\n'
    confirm "Apply the experimental HDR patch now?" || { printf 'No changes were made.\n'; return; }
  fi

  create_backup "$executable" "$exe_backup" "$ORIGINAL_EXE_SHA256"
  create_backup "$cache" "$cache_backup" "$ORIGINAL_CACHE_SHA256"
  EXE_TEMP="$(mktemp "${executable}.hdr-tmp.XXXXXX")"
  CACHE_TEMP="$(mktemp "${cache}.hdr-tmp.XXXXXX")"
  build_patched_executable "$executable" "$EXE_TEMP"
  build_patched_cache "$cache" "$CACHE_TEMP"
  [[ "$(sha256_file "$executable")" == "$ORIGINAL_EXE_SHA256" && \
     "$(sha256_file "$cache")" == "$ORIGINAL_CACHE_SHA256" ]] || \
    fail "a game file changed during staging; nothing was installed"

  TRANSACTION_MODE=apply
  mv -f "$CACHE_TEMP" "$cache"
  CACHE_TEMP=""
  mv -f "$EXE_TEMP" "$executable"
  EXE_TEMP=""
  TRANSACTION_MODE=""
  printf '\nThe experimental static HDR patch is installed.\n'
  printf 'Backups:\n  %s\n  %s\n' "$exe_backup" "$cache_backup"
}

restore_original() {
  local executable="$1" unattended="$2" cache exe_state cache_state exe_backup cache_backup
  TARGET_EXE="$executable"
  require_tools
  require_supported_path "$executable"
  require_game_stopped
  cache="$(cache_path "$executable")"
  exe_state="$(file_state "$executable" "$ORIGINAL_EXE_SHA256" "$PATCHED_EXE_SHA256" "$LEGACY_SCRGB_EXE_SHA256")"
  cache_state="$(file_state "$cache" "$ORIGINAL_CACHE_SHA256" "$PATCHED_CACHE_SHA256")"
  [[ "$exe_state" != unsupported && "$cache_state" != unsupported ]] || \
    fail "an installed file is not recognized; it was not overwritten"
  if [[ "$exe_state" == original && "$cache_state" == original ]]; then
    printf '\nThe original game files are already restored. Nothing was changed.\n'
    return
  fi
  exe_backup="$(backup_path "$executable" "$ORIGINAL_EXE_SHA256")"
  cache_backup="$(backup_path "$cache" "$ORIGINAL_CACHE_SHA256")"
  [[ "$exe_state" != patched && "$exe_state" != legacy-scrgb-patched ]] || verify_backup "$exe_backup" "$ORIGINAL_EXE_SHA256" || \
    fail "the verified executable backup is missing"
  [[ "$cache_state" != patched ]] || verify_backup "$cache_backup" "$ORIGINAL_CACHE_SHA256" || \
    fail "the verified shader-cache backup is missing"

  if [[ "$unattended" != yes ]]; then
    printf '\nThis restores only the files owned by this patch. Verified backups are kept.\n\n'
    confirm "Restore the original Mafia: Definitive Edition files now?" || \
      { printf 'No changes were made.\n'; return; }
  fi

  if [[ "$exe_state" == patched || "$exe_state" == legacy-scrgb-patched ]]; then
    EXE_TEMP="$(mktemp "${executable}.restore-tmp.XXXXXX")"
    cp -p "$exe_backup" "$EXE_TEMP"
    [[ "$(sha256_file "$EXE_TEMP")" == "$ORIGINAL_EXE_SHA256" ]] || fail "staged executable restore failed"
  fi
  if [[ "$cache_state" == patched ]]; then
    CACHE_TEMP="$(mktemp "${cache}.restore-tmp.XXXXXX")"
    cp -p "$cache_backup" "$CACHE_TEMP"
    [[ "$(sha256_file "$CACHE_TEMP")" == "$ORIGINAL_CACHE_SHA256" ]] || fail "staged shader-cache restore failed"
    ROLLBACK_TEMP="$(mktemp "${cache}.rollback-tmp.XXXXXX")"
    cp -p "$cache" "$ROLLBACK_TEMP"
    [[ "$(sha256_file "$ROLLBACK_TEMP")" == "$PATCHED_CACHE_SHA256" ]] || fail "restore rollback staging failed"
  fi

  TRANSACTION_MODE=restore
  if [[ -n "$CACHE_TEMP" ]]; then mv -f "$CACHE_TEMP" "$cache"; CACHE_TEMP=""; fi
  if [[ -n "$EXE_TEMP" ]]; then mv -f "$EXE_TEMP" "$executable"; EXE_TEMP=""; fi
  TRANSACTION_MODE=""
  [[ -z "$ROLLBACK_TEMP" ]] || { rm -f "$ROLLBACK_TEMP"; ROLLBACK_TEMP=""; }
  printf '\nThe original game files have been restored. Verified backups were kept.\n'
}

ask_for_executable() {
  local executable
  printf '\nPaste or drag mafiadefinitiveedition.exe into this window, then press Return.\n> ' >&2
  read -r executable
  executable="${executable#\'}"; executable="${executable%\'}"
  printf '%s\n' "$executable"
}

guided_mode() {
  local choice executable
  while true; do
    cat <<'EOF'

Mafia: Definitive Edition — experimental static HDR patch

1) Apply the HDR patch
2) Restore the original game files
3) Check patch state
4) Quit
EOF
    printf '\nChoose an option: '; read -r choice
    case "$choice" in
      1) executable="$(ask_for_executable)"; apply_patch "$executable" no ;;
      2) executable="$(ask_for_executable)"; restore_original "$executable" no ;;
      3) executable="$(ask_for_executable)"; require_supported_path "$executable"; report_state "$executable" ;;
      4|q|Q) printf 'No changes were made.\n'; return ;;
      *) printf 'Please enter 1, 2, 3, or 4.\n' ;;
    esac
  done
}

case "${1:-}" in
  "") guided_mode ;;
  --yes) (($# == 2)) || fail "--yes needs the full path to mafiadefinitiveedition.exe"; apply_patch "$2" yes ;;
  --restore) [[ "${2:-}" == --yes && $# == 3 ]] || fail "use --restore --yes followed by the full executable path"; restore_original "$3" yes ;;
  --check) (($# == 2)) || fail "--check needs the full executable path"; require_supported_path "$2"; report_state "$2" ;;
  -h|--help) (($# == 1)) || fail "--help does not take another option"; usage ;;
  *) fail "use the guided tool, --yes, --restore --yes, or --check. Try --help." ;;
esac
