#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || {
  printf 'Python 3.9 or newer is required. See README.md.\n' >&2
  exit 1
}
exec python3 "${SCRIPT_DIR}/patch-dlss.py" "$@"
