#!/usr/bin/env bash

# This affects every bottle in the selected CrossOver application.
set -euo pipefail

readonly SYSTEM_FRAMEWORK="/Library/Frameworks/GStreamer.framework"
readonly MARKER_NAME=".system-gstreamer-patch-applied"
readonly BACKUP_NAME="gstreamer-system-backup"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPLACEMENT_MODULE="$SCRIPT_DIR/winegstreamer.so"

usage() {
  cat <<'EOF'
CrossOver system-GStreamer patcher

Usage:
  patch-system-gstreamer.sh
      Start the guided patcher.

  patch-system-gstreamer.sh --apply --app "/Applications/CrossOver.app" \
      [--dry-run]
      Patch one CrossOver application.

  patch-system-gstreamer.sh --restore --app "/Applications/CrossOver.app"
      Restore the exact runtime saved by this tool.

The included winegstreamer.so replacement is checked before any changes are
made. Add --dry-run to preview an operation without changing the application.
EOF
}

fail() {
  printf '\nUnable to continue: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

confirm() {
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

app=""
operation=""
dry_run=0

while (($#)); do
  case "$1" in
    --app)
      (($# >= 2)) || fail "--app needs a CrossOver application path"
      app="${2%/}"
      shift 2
      ;;
    --apply|--restore)
      [[ -z "$operation" ]] || fail "choose only one operation"
      operation="${1#--}"
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) fail "unknown option: $1" ;;
  esac
done

root=""
wine_module=""
library_dir=""
library_rel=""
backup_dir=""
marker=""
items=()

resolve_app() {
  local candidate fallback=""

  [[ -d "$app" ]] || fail "CrossOver application not found: $app"
  [[ "$(basename "$app")" == *.app ]] || fail "please select a CrossOver .app bundle"
  root="$app/Contents/SharedSupport/CrossOver"
  [[ -d "$root" ]] || fail "this does not look like a CrossOver application: $app"
  wine_module="$root/lib/wine/x86_64-unix/winegstreamer.so"
  [[ -f "$wine_module" ]] || fail "winegstreamer.so was not found in this app"
  for candidate in "$root/lib/x86_64" "$root/lib64"; do
    if [[ -d "$candidate/gstreamer-1.0" ]]; then
      library_dir="$candidate"
      break
    fi
    [[ -d "$candidate" && -z "$fallback" ]] && fallback="$candidate"
  done
  [[ -n "$library_dir" ]] || library_dir="$fallback"
  [[ -n "$library_dir" ]] || fail "could not find the active bundled GStreamer directory"
  library_rel="${library_dir#"$root"/}"
  backup_dir="$root/$BACKUP_NAME"
  marker="$root/$MARKER_NAME"
}

collect_items() {
  items=()
  while IFS= read -r -d '' item; do
    items+=("$item")
  done < <(
    find "$library_dir" -maxdepth 1 -mindepth 1 \( -type f -o -type d \) \
      \( -name 'libgst*.dylib' -o -name 'libgio-2.0*.dylib' -o \
         -name 'libglib-2.0*.dylib' -o -name 'libgmodule-2.0*.dylib' -o \
         -name 'libgobject-2.0*.dylib' -o -name 'libgthread-2.0*.dylib' -o \
         -name 'libffi*.dylib' -o -name 'libintl*.dylib' -o \
         -name 'libpcre2*.dylib' -o -name 'gstreamer-1.0' \) -print0
  )
  ((${#items[@]})) || fail "no bundled GStreamer components were found in $library_dir"
}

show_gstreamer_setup() {
  cat >&2 <<'EOF'

GStreamer is required before this patch can be applied. This tool never installs
software for you.

Recommended: install the official macOS runtime package from:
  https://gstreamer.freedesktop.org/download/

Alternative: Homebrew can install GStreamer with:
  brew install gstreamer

This patcher expects the official framework at
/Library/Frameworks/GStreamer.framework. Do not mix an official installation
with Homebrew libraries in the same CrossOver app.
EOF
}

require_system_gstreamer() {
  if [[ ! -d "$SYSTEM_FRAMEWORK" || ! -f "$SYSTEM_FRAMEWORK/Libraries/libgstreamer-1.0.0.dylib" ]]; then
    show_gstreamer_setup
    fail "the official macOS GStreamer framework was not found"
  fi
}

validate_replacement() {
  local module="$1"

  [[ -f "$module" ]] || fail "replacement module not found: $module"
  file "$module" | grep -q 'x86_64' || fail "replacement winegstreamer.so must contain x86_64 code"
  otool -l "$module" | grep -Fq "$SYSTEM_FRAMEWORK/Libraries" || \
    fail "replacement winegstreamer.so is not configured for the macOS GStreamer framework"
}

app_state() {
  if [[ -f "$marker" ]]; then
    printf 'system patch installed\n'
  else
    printf 'unpatched\n'
  fi
}

show_plan() {
  printf '\nCrossOver application:\n  %s\n' "$app"
  printf 'Bundled GStreamer location:\n  %s\n' "$library_dir"
  printf 'Bundled components to isolate: %d\n' "${#items[@]}"
  printf 'Backup location:\n  %s\n' "$backup_dir"
  printf 'Included replacement module:\n  %s\n' "$REPLACEMENT_MODULE"
  printf '\nThis changes the CrossOver app, not an individual bottle. All bottles in this app will use macOS GStreamer.\n'
}

moved_sources=()
moved_destinations=()
previous_module=""
module_replaced=0

rollback_apply() {
  local index
  set +e
  if ((module_replaced)) && [[ -n "$previous_module" && -f "$previous_module" ]]; then
    cp -p "$previous_module" "$wine_module"
  fi
  for ((index=${#moved_sources[@]} - 1; index >= 0; index--)); do
    if [[ -e "${moved_destinations[index]}" && ! -e "${moved_sources[index]}" ]]; then
      mv "${moved_destinations[index]}" "${moved_sources[index]}"
    fi
  done
  rm -rf "$backup_dir"
  printf '\nThe patch was rolled back because an operation failed.\n' >&2
}

apply_patch() {
  local item destination staged_module

  require_system_gstreamer
  validate_replacement "$REPLACEMENT_MODULE"
  [[ ! -e "$marker" ]] || fail "this app is already patched by this tool"
  [[ ! -e "$backup_dir" ]] || fail "a previous backup exists at $backup_dir; restore it or inspect it first"
  [[ -f "$wine_module" ]] || fail "original winegstreamer.so was not found"
  collect_items
  show_plan
  if ((dry_run)); then
    printf '\nDry run only: no application files were changed.\n'
    return
  fi
  confirm "Create the backup and apply this system-GStreamer patch?" || {
    printf 'No changes were made.\n'
    return
  }

  mkdir -p "$backup_dir/$library_rel"
  cp -p "$wine_module" "$backup_dir/winegstreamer.so"
  cp -p "$wine_module" "$backup_dir/active-winegstreamer.so"
  previous_module="$backup_dir/active-winegstreamer.so"
  trap rollback_apply ERR
  for item in "${items[@]}"; do
    destination="$backup_dir/$library_rel/$(basename "$item")"
    mv "$item" "$destination"
    moved_sources+=("$item")
    moved_destinations+=("$destination")
  done
  staged_module="$wine_module.system-gstreamer-new"
  cp -p "$REPLACEMENT_MODULE" "$staged_module"
  mv -f "$staged_module" "$wine_module"
  module_replaced=1
  printf 'patched on %s\napp=%s\nlibrary_dir=%s\nreplacement_sha256=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$app" "$library_rel" "$(sha256_file "$REPLACEMENT_MODULE")" > "$marker"
  trap - ERR
  printf '\nSuccess. The original CrossOver GStreamer runtime is backed up at:\n  %s\n' "$backup_dir"
  printf 'Restart CrossOver before launching any game.\n'
}

restore_patch() {
  local backup_libraries=() item target staged_module

  [[ -f "$marker" ]] || fail "this app is not patched by this tool"
  [[ -f "$backup_dir/winegstreamer.so" ]] || fail "the original winegstreamer backup is missing"
  [[ -d "$backup_dir/$library_rel" ]] || fail "the bundled library backup is missing"
  while IFS= read -r -d '' item; do
    backup_libraries+=("$item")
  done < <(find "$backup_dir/$library_rel" -maxdepth 1 -mindepth 1 -print0)
  ((${#backup_libraries[@]})) || fail "the bundled library backup is empty"
  for item in "${backup_libraries[@]}"; do
    target="$library_dir/$(basename "$item")"
    [[ ! -e "$target" ]] || fail "refusing to overwrite $target; CrossOver may have been updated"
  done
  printf '\nThis will restore CrossOver\x27s original winegstreamer module and %d bundled components.\n' "${#backup_libraries[@]}"
  if ((dry_run)); then
    printf 'Dry run only: no application files were changed.\n'
    return
  fi
  confirm "Restore this CrossOver application now?" || {
    printf 'No changes were made.\n'
    return
  }
  staged_module="$wine_module.system-gstreamer-restore"
  cp -p "$backup_dir/winegstreamer.so" "$staged_module"
  for item in "${backup_libraries[@]}"; do
    mv "$item" "$library_dir/$(basename "$item")"
  done
  mv -f "$staged_module" "$wine_module"
  rm -f "$marker"
  rm -rf "$backup_dir"
  printf '\nCrossOver\x27s original GStreamer runtime has been restored. Restart CrossOver before launching a game.\n'
}

discover_apps() {
  find /Applications -maxdepth 1 -type d -name 'CrossOver*.app' -print | sort
}

guided_mode() {
  local apps=() candidate choice selected state

  while IFS= read -r candidate; do apps+=("$candidate"); done < <(discover_apps)
  ((${#apps[@]})) || fail "no CrossOver applications were found in /Applications"
  printf '\nCrossOver system-GStreamer patcher\n\n'
  for choice in "${!apps[@]}"; do
    app="${apps[choice]}"
    resolve_app
    printf '%d) %s — %s\n' "$((choice + 1))" "$(basename "$app")" "$(app_state)"
  done
  printf 'q) Quit\n\nChoose an application: '
  read -r selected
  [[ "$selected" =~ ^[0-9]+$ ]] || {
    [[ "$selected" =~ ^[Qq]$ ]] && return
    fail "please choose an application number"
  }
  ((selected >= 1 && selected <= ${#apps[@]})) || fail "invalid application number"
  app="${apps[selected - 1]}"
  resolve_app
  state="$(app_state)"
  case "$state" in
    'system patch installed') restore_patch ;;
    *)
      apply_patch
      ;;
  esac
}

if [[ -z "$operation" ]]; then
  [[ -z "$app" && "$dry_run" == 0 ]] || fail "choose an operation"
  guided_mode
  exit 0
fi

[[ -n "$app" ]] || fail "--app is required for non-interactive use"
resolve_app
case "$operation" in
  apply)
    apply_patch
    ;;
  restore)
    restore_patch
    ;;
esac
