#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_PREVIEW_APP="/Applications/CrossOver Preview.app"
readonly DEFAULT_STABLE_APP="/Applications/CrossOver.app"

usage() {
  cat <<'EOF'
Usage:
  launch-with-game-mode.sh [options] DevilMayCry5.exe [-- game arguments]

Options:
  --bottle NAME          CrossOver bottle name (default: Steam)
  --crossover-app PATH   CrossOver application bundle
  --metal-hud            Enable Apple's Metal performance HUD
  --log PATH             Write a CrossOver log
  --dry-run              Print resolved commands without changing state
  -h, --help             Show this help

The launcher temporarily forces macOS Game Mode on when Xcode's
gamepolicyctl is available, waits for the game, then restores policy to auto.
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

print_command() {
  printf '%q ' "$@"
  printf '\n'
}

bottle="Steam"
crossover_app=""
metal_hud=0
dry_run=0
log_path=""
exe=""
game_args=()

while (($#)); do
  case "$1" in
    --bottle)
      (($# >= 2)) || fail "--bottle requires a name"
      bottle="$2"
      shift 2
      ;;
    --crossover-app)
      (($# >= 2)) || fail "--crossover-app requires a path"
      crossover_app="${2%/}"
      shift 2
      ;;
    --metal-hud)
      metal_hud=1
      shift
      ;;
    --log)
      (($# >= 2)) || fail "--log requires a path"
      log_path="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      game_args=("$@")
      break
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "$exe" ]] || fail "expected one executable before --"
      exe="$1"
      shift
      ;;
  esac
done

[[ -n "$exe" ]] || {
  usage >&2
  exit 2
}
[[ -f "$exe" ]] || fail "executable not found: $exe"

if [[ -z "$crossover_app" ]]; then
  if [[ -d "$DEFAULT_PREVIEW_APP" ]]; then
    crossover_app="$DEFAULT_PREVIEW_APP"
  else
    crossover_app="$DEFAULT_STABLE_APP"
  fi
fi

wine="$crossover_app/Contents/SharedSupport/CrossOver/bin/wine"
[[ -x "$wine" ]] || fail "CrossOver wine launcher not found: $wine"

patch_status="$("$SCRIPT_DIR/patch-hdr.sh" --check "$exe")" || \
  fail "refusing to launch an unsupported DMC5 executable"
printf '%s\n' "$patch_status"
if [[ "$patch_status" == supported\ original:* ]]; then
  warn "this executable does not contain the HDR patch"
fi

game_mode_tool=""
if command -v xcrun >/dev/null 2>&1; then
  game_mode_tool="$(xcrun --toolchain XcodeDefault --find gamepolicyctl 2>/dev/null || true)"
fi

game_mode_prefix=(xcrun --toolchain XcodeDefault gamepolicyctl game-mode set)
wine_args=(
  --bottle "$bottle"
  --no-update
  --untrusted
  --workdir "$(dirname "$exe")"
  --wait
  --env "SteamAppId=601150"
)
if [[ -n "$log_path" ]]; then
  wine_args+=(--cx-log "$log_path")
fi
launch_args=("${wine_args[@]}" "$exe")
if ((${#game_args[@]})); then
  launch_args+=("${game_args[@]}")
fi

if ((dry_run)); then
  if [[ -n "$game_mode_tool" ]]; then
    printf 'enable Game Mode: '
    print_command "${game_mode_prefix[@]}" on
    printf 'restore Game Mode: '
    print_command "${game_mode_prefix[@]}" auto
  else
    printf 'Game Mode: unavailable (full Xcode with gamepolicyctl not found)\n'
  fi
  printf 'launch: '
  if ((metal_hud)); then
    print_command env MTL_HUD_ENABLED=1 "$wine" "${launch_args[@]}"
  else
    print_command "$wine" "${launch_args[@]}"
  fi
  exit 0
fi

game_mode_forced=0
restore_game_mode() {
  if ((game_mode_forced)); then
    if ! "${game_mode_prefix[@]}" auto; then
      warn "could not restore Game Mode policy to auto"
    fi
  fi
}
trap restore_game_mode EXIT

if [[ -n "$game_mode_tool" ]]; then
  "${game_mode_prefix[@]}" on
  game_mode_forced=1
  printf 'Game Mode policy forced on for this launch.\n'
else
  warn "full Xcode with gamepolicyctl was not found; continuing without a Game Mode override"
fi

set +e
if ((metal_hud)); then
  MTL_HUD_ENABLED=1 "$wine" "${launch_args[@]}"
  exit_status=$?
else
  "$wine" "${launch_args[@]}"
  exit_status=$?
fi
set -e

exit "$exit_status"
