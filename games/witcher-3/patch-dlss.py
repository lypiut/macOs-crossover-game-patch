#!/usr/bin/env python3
"""Experimental, game-local Witcher 3 Streamline initialization patch."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import re
import stat
import subprocess
import sys
import tempfile

ORIGINAL = '2df765398a3d1f165db418271be7200178320a4466817379f2fa0dc0001fb101'
PATCHED = 'd8df34019c81abf04aedc256e7783fe88f93ad77dc27cf37c4c245d8e06a32ca'
OFFSET = 0x1B77ECB
BEFORE = bytes.fromhex('75 42')
AFTER = bytes.fromhex('90 90')
BACKUP_SUFFIX = '.pre-dlss-wine-gate.' + ORIGINAL[:12]


class PatchError(Exception):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(path):
    s = path.lstat()
    return s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns


def read_regular(path):
    s = path.lstat()
    if not stat.S_ISREG(s.st_mode) or s.st_nlink != 1:
        raise PatchError(f'Expected a regular, non-symlink file with one link: {path}')
    identity = fingerprint(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        data = stream.read()
    if fingerprint(path) != identity:
        raise PatchError(f'File changed while reading: {path}')
    return data, identity


def state(data):
    sha = digest(data)
    if sha == ORIGINAL:
        expected, label = BEFORE, 'original'
    elif sha == PATCHED:
        expected, label = AFTER, 'patched'
    else:
        raise PatchError(f'Unsupported executable SHA-256: {sha}. No force option is provided.')
    if data[OFFSET:OFFSET + len(expected)] != expected:
        raise PatchError('Patch-site bytes disagree with the supported file identity.')
    return label


def backup_path(target):
    return target.with_name(target.name + BACKUP_SUFFIX)


def validate_backup(path, required=False):
    if not os.path.lexists(path):
        if required:
            raise PatchError(f'Verified original backup is required: {path}')
        return
    data, _ = read_regular(path)
    if digest(data) != ORIGINAL or data[OFFSET:OFFSET + 2] != BEFORE:
        raise PatchError(f'Backup conflict: {path}. Preserve it and inspect it; it will not be overwritten.')


def ensure_stopped():
    try:
        result = subprocess.run(['/bin/ps', '-axo', 'comm=,args='], capture_output=True,
                                text=True, check=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise PatchError('Cannot check running processes. Run from a normal macOS Terminal; '
                         'no files were changed.') from exc
    for line in result.stdout.splitlines():
        command = line.strip().split('  ', 1)[0]
        direct_game = Path(command).name.lower() == 'witcher3.exe'
        wine_loader = re.search(r'(?i)(?:^|[\\/])wine(?:64)?(?:-preloader)?(?:\s|$)', line)
        game_argument = re.search(r'(?i)(?:^|[\\/])witcher3\.exe(?:\s|"|$)', line)
        if direct_game or (wine_loader and game_argument):
            raise PatchError('Quit Witcher 3 before applying or restoring this patch.')


def copy_metadata(source, destination):
    shutil.copystat(source, destination, follow_symlinks=False)
    s = source.stat()
    ds = destination.stat()
    if (s.st_uid, s.st_gid) != (ds.st_uid, ds.st_gid):
        os.chown(destination, s.st_uid, s.st_gid)
    if hasattr(os, 'listxattr'):
        for name in os.listxattr(source, follow_symlinks=False):
            os.setxattr(destination, name, os.getxattr(source, name, follow_symlinks=False),
                        follow_symlinks=False)


def unchanged(target, identity, expected_hash):
    data, current = read_regular(target)
    if current != identity or digest(data) != expected_hash:
        raise PatchError('Executable changed during the operation. Nothing was installed.')


def make_backup(target, backup, data):
    if os.path.lexists(backup):
        validate_backup(backup, required=True)
        return
    # Exclusive creation prevents replacing any pre-existing backup or symlink.
    with backup.open('xb') as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    copy_metadata(target, backup)
    validate_backup(backup, required=True)


def change(target, action):
    lock = target.with_name(target.name + '.dlss-wine-gate.lock')
    try:
        lock_fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as exc:
        raise PatchError(f'Operation lock exists: {lock}. See interruption recovery in README.md.') from exc
    lock_identity = lock.lstat().st_ino
    staged = None
    try:
        with os.fdopen(lock_fd, 'w') as stream:
            stream.write(f'PID={os.getpid()}\n')
        data, identity = read_regular(target)
        current = state(data)
        backup = backup_path(target)
        validate_backup(backup, required=(current == 'patched'))
        if (action == 'apply' and current == 'patched') or (action == 'restore' and current == 'original'):
            print(f'Already {current}; no changes.')
            return
        if action == 'apply':
            output = data[:OFFSET] + AFTER + data[OFFSET + len(BEFORE):]
            expected_hash = PATCHED
        else:
            output, _ = read_regular(backup)
            expected_hash = ORIGINAL
        if digest(output) != expected_hash:
            raise PatchError('Output verification failed before staging.')
        fd, name = tempfile.mkstemp(prefix='.witcher3-dlss-stage-', dir=target.parent)
        staged = Path(name)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(output)
            stream.flush()
            os.fsync(stream.fileno())
        copy_metadata(target, staged)
        staged_data, _ = read_regular(staged)
        if digest(staged_data) != expected_hash:
            raise PatchError('Staged output verification failed.')
        unchanged(target, identity, digest(data))
        if action == 'apply':
            make_backup(target, backup, data)
        validate_backup(backup, required=True)
        ensure_stopped()
        unchanged(target, identity, digest(data))
        os.replace(staged, target)
        staged = None
        installed, _ = read_regular(target)
        if digest(installed) != expected_hash:
            raise PatchError('Installed file verification failed. Keep the verified backup for recovery.')
        print(f'{action.capitalize()} completed and verified. Backup kept: {backup}')
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)
        if os.path.lexists(lock) and lock.lstat().st_ino == lock_identity:
            lock.unlink()


def target_path(value):
    target = Path(value).expanduser().absolute()
    if target.is_dir():
        target = target / 'bin' / 'x64_dx12' / 'witcher3.exe'
    if target.name.lower() != 'witcher3.exe' or target.parent.name.lower() != 'x64_dx12':
        raise PatchError('Supply the game root or its bin/x64_dx12/witcher3.exe; DX11 is not supported.')
    if target.is_symlink():
        raise PatchError('Executable symlinks are refused. Supply the real DX12 executable path.')
    # Canonicalize parent directories only, retaining the checked target filename.
    return target.parent.resolve(strict=True) / target.name


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--check', action='store_true', help='read-only state check (default)')
    modes.add_argument('--dry-run', action='store_true', help='read-only apply plan')
    modes.add_argument('--apply', action='store_true', help='apply the experimental Wine-gate patch')
    modes.add_argument('--restore', action='store_true', help='restore from a verified original backup')
    parser.add_argument('--yes', action='store_true', help='skip confirmation for explicit apply/restore')
    parser.add_argument('path', help='game root or DX12 witcher3.exe')
    args = parser.parse_args(argv)
    try:
        target = target_path(args.path)
        data, _ = read_regular(target)
        current = state(data)
        backup = backup_path(target)
        validate_backup(backup, required=(current == 'patched'))
        print(f'Target: {target}\nScope: this game executable only\nState: {current}\nBackup: {backup}')
        print(f'Patch: file offset {OFFSET:#x}, {BEFORE.hex(" ")} -> {AFTER.hex(" ")}')
        print('Experimental: permits Streamline initialization; DLSS success is not yet validated in game.')
        if args.check or args.dry_run or not (args.apply or args.restore):
            return 0
        ensure_stopped()
        if not args.yes:
            if not sys.stdin.isatty():
                raise PatchError('Use --yes with explicit --apply/--restore for unattended operation.')
            if input('Continue? [y/N] ').strip().lower() not in ('y', 'yes'):
                print('Cancelled; no changes.')
                return 0
        change(target, 'apply' if args.apply else 'restore')
        return 0
    except (PatchError, OSError) as exc:
        print(f'Unable to continue: {exc}', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('Interrupted. Keep backups; see interruption recovery in README.md.', file=sys.stderr)
        return 130


if __name__ == '__main__':
    sys.exit(main())
