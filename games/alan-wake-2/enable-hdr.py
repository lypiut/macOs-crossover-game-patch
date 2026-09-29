#!/usr/bin/env python3
"""Enable Alan Wake 2's native HDR setting in CrossOver's renderer.ini."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile


CROSSOVER_BOTTLES = Path.home() / "Library/Application Support/CrossOver/Bottles"
CONFIG_PATTERN = (
    "*/drive_c/users/*/AppData/Local/Remedy/AlanWake2/renderer.ini"
)
HDR_LINE = re.compile(
    r'(?m)^([ \t]*"m_eHdrQuality"[ \t]*:[ \t]*)([0-9]+)([ \t]*,?[ \t]*)$'
)


def fail(message: str) -> None:
    raise ValueError(message)


def unique_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def read_config(path: Path) -> tuple[str, int]:
    if path.is_symlink() or not path.is_file():
        fail(f"renderer.ini was not found as a regular file: {path}")
    contents = path.read_text(encoding="utf-8")
    settings = json.loads(contents, object_pairs_hook=unique_keys)
    if not isinstance(settings, dict) or settings.get("objectType") != "rend::UserRendererSettings":
        fail(f"this is not an Alan Wake 2 renderer.ini: {path}")
    value = settings.get("m_eHdrQuality")
    if type(value) is not int or value not in (0, 1):
        fail(f"unsupported m_eHdrQuality value in {path}: {value!r}")
    matches = list(HDR_LINE.finditer(contents))
    if len(matches) != 1 or int(matches[0].group(2)) != value:
        fail(f"could not safely locate the HDR setting in {path}")
    return contents, value


def replace_hdr_line(contents: str, value: int) -> str:
    updated, count = HDR_LINE.subn(lambda match: match.group(1) + str(value) + match.group(3), contents)
    if count != 1:
        fail("could not safely replace the HDR setting")
    return updated


def find_config() -> Path:
    candidates = sorted(
        path for path in CROSSOVER_BOTTLES.glob(CONFIG_PATTERN)
        if path.is_file() and not path.is_symlink()
    )
    if not candidates:
        fail(
            "no Alan Wake 2 renderer.ini was found in the CrossOver bottles; "
            "pass its path with --config"
        )
    if len(candidates) > 1:
        choices = "\n  ".join(str(path) for path in candidates)
        fail(
            "multiple Alan Wake 2 configurations were found; choose one with "
            f"--config:\n  {choices}"
        )
    return candidates[0]


def write_config(path: Path, contents: str) -> None:
    original_mode = stat.S_IMODE(path.stat().st_mode)
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", newline="", dir=path.parent,
            prefix=f".{path.name}.", delete=False,
        ) as temporary:
            temporary_name = temporary.name
            temporary.write(contents)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_name, original_mode)
        read_config(Path(temporary_name))
        os.replace(temporary_name, path)
    finally:
        if temporary_name is not None and os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config", type=Path,
        help="path to Alan Wake 2 renderer.ini (auto-detected when omitted)",
    )
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", action="store_true", help="show HDR state without changing the file")
    action.add_argument("--restore", action="store_true", help="restore only the HDR value from the backup")
    args = parser.parse_args()

    path = args.config.expanduser() if args.config else find_config()
    contents, value = read_config(path)
    backup = path.with_name(path.name + ".pre-hdr")

    if args.check:
        print(f"HDR is {'enabled' if value == 1 else 'disabled'}: {path}")
        return

    if args.restore:
        _, original_value = read_config(backup)
        if original_value != 0:
            fail(f"the backup does not contain the original disabled HDR setting: {backup}")
        if value == 0:
            print(f"HDR is already disabled: {path}")
            return
        write_config(path, replace_hdr_line(contents, original_value))
        print(f"Restored m_eHdrQuality to {original_value}: {path}")
        return

    if value == 1:
        print(f"HDR is already enabled; nothing changed: {path}")
        return

    if backup.exists() or backup.is_symlink():
        _, original_value = read_config(backup)
        if original_value != 0:
            fail(f"the existing backup is not an original HDR-disabled config: {backup}")
    else:
        shutil.copy2(path, backup)
        _, original_value = read_config(backup)
        if original_value != 0:
            fail(f"backup verification failed: {backup}")

    write_config(path, replace_hdr_line(contents, 1))
    print(f"Enabled native HDR (m_eHdrQuality = 1): {path}")
    print(f"Backup: {backup}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        print(f"Unable to continue: {error}", file=sys.stderr)
        sys.exit(1)
