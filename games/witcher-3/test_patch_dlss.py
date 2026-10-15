"""Disposable fixtures; no proprietary game data is stored in this repository."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('patch_dlss', Path(__file__).with_name('patch-dlss.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class PatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='witcher test é ')
        self.root = Path(self.temp.name)
        self.exe = self.root / 'bin' / 'x64_dx12' / 'witcher3.exe'
        self.exe.parent.mkdir(parents=True)
        self.data = b'fixture-header' + m.BEFORE + b'fixture-tail'
        self.exe.write_bytes(self.data)
        offset = len(b'fixture-header')
        output = self.data[:offset] + m.AFTER + self.data[offset + 2:]
        self.constants = patch.multiple(m, OFFSET=offset, ORIGINAL=m.digest(self.data),
                                        PATCHED=m.digest(output), BACKUP_SUFFIX='.fixture-backup')
        self.constants.start()
        self.stop = patch.object(m, 'ensure_stopped')
        self.stop.start()

    def tearDown(self):
        self.stop.stop()
        self.constants.stop()
        self.temp.cleanup()

    def test_apply_repeat_restore_repeat(self):
        self.exe.chmod(0o750)
        m.change(self.exe, 'apply')
        self.assertEqual(m.state(self.exe.read_bytes()), 'patched')
        self.assertEqual(self.exe.stat().st_mode & 0o777, 0o750)
        backup = m.backup_path(self.exe)
        identity = m.fingerprint(backup)
        m.change(self.exe, 'apply')
        m.change(self.exe, 'restore')
        m.change(self.exe, 'restore')
        self.assertEqual(self.exe.read_bytes(), self.data)
        self.assertEqual(m.fingerprint(backup), identity)

    def test_check_and_dry_run_no_writes(self):
        before = list(self.exe.parent.iterdir())
        for mode in ['--check', '--dry-run']:
            self.assertEqual(m.main([mode, str(self.root)]), 0)
        self.assertEqual(list(self.exe.parent.iterdir()), before)
        self.assertEqual(self.exe.read_bytes(), self.data)

    def test_unsupported_and_backup_conflicts(self):
        self.exe.write_bytes(b'unsupported')
        with self.assertRaises(m.PatchError):
            m.change(self.exe, 'apply')
        self.assertEqual(self.exe.read_bytes(), b'unsupported')
        self.exe.write_bytes(self.data)
        backup = m.backup_path(self.exe)
        backup.write_bytes(b'conflict')
        with self.assertRaises(m.PatchError):
            m.change(self.exe, 'apply')
        self.assertEqual(backup.read_bytes(), b'conflict')
        self.assertEqual(self.exe.read_bytes(), self.data)

    def test_symlinks_lock_and_missing_backup(self):
        backup = m.backup_path(self.exe)
        backup.symlink_to(self.exe)
        with self.assertRaises(m.PatchError):
            m.change(self.exe, 'apply')
        backup.unlink()
        lock = self.exe.with_name(self.exe.name + '.dlss-wine-gate.lock')
        lock.write_text('other operation')
        with self.assertRaises(m.PatchError):
            m.change(self.exe, 'apply')
        self.assertEqual(lock.read_text(), 'other operation')
        lock.unlink()
        m.change(self.exe, 'apply')
        backup.unlink()
        with self.assertRaises(m.PatchError):
            m.change(self.exe, 'restore')
        link = self.root / 'symlink' / 'x64_dx12'
        link.mkdir(parents=True)
        (link / 'witcher3.exe').symlink_to(self.exe)
        with self.assertRaises(m.PatchError):
            m.target_path(str(link / 'witcher3.exe'))

    def test_output_failure_and_atomic_install_failure(self):
        with patch.object(m, 'PATCHED', '0' * 64):
            with self.assertRaises(m.PatchError):
                m.change(self.exe, 'apply')
        self.assertFalse(m.backup_path(self.exe).exists())
        with patch.object(m.os, 'replace', side_effect=OSError('simulated install failure')):
            with self.assertRaises(OSError):
                m.change(self.exe, 'apply')
        self.assertEqual(self.exe.read_bytes(), self.data)
        self.assertEqual(m.backup_path(self.exe).read_bytes(), self.data)
        self.assertFalse(list(self.exe.parent.glob('.witcher3-dlss-stage-*')))
        m.change(self.exe, 'apply')  # recovery reuses the verified backup

    def test_changed_input_and_later_edits_refused(self):
        real_backup = m.make_backup
        def changed_input(target, backup, data):
            real_backup(target, backup, data)
            target.write_bytes(b'concurrent update')
        with patch.object(m, 'make_backup', side_effect=changed_input):
            with self.assertRaises(m.PatchError):
                m.change(self.exe, 'apply')
        self.assertEqual(self.exe.read_bytes(), b'concurrent update')
        self.exe.write_bytes(self.data)
        m.change(self.exe, 'apply')
        self.exe.write_bytes(self.exe.read_bytes() + b'later unrelated edit')
        later = self.exe.read_bytes()
        with self.assertRaises(m.PatchError):
            m.change(self.exe, 'restore')
        self.assertEqual(self.exe.read_bytes(), later)

    def test_interruption_cleanup(self):
        with patch.object(m.os, 'replace', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                m.change(self.exe, 'apply')
        self.assertEqual(self.exe.read_bytes(), self.data)
        self.assertEqual(m.backup_path(self.exe).read_bytes(), self.data)
        self.assertFalse(list(self.exe.parent.glob('.witcher3-dlss-stage-*')))
        self.assertFalse(list(self.exe.parent.glob('*.lock')))

    def test_stop_check_failures(self):
        self.stop.stop()
        try:
            with patch.object(m.subprocess, 'run', return_value=m.subprocess.CompletedProcess([], 0, '/game/witcher3.exe\n', '')):
                with self.assertRaises(m.PatchError):
                    m.ensure_stopped()
            with patch.object(m.subprocess, 'run', return_value=m.subprocess.CompletedProcess([], 0, '/app/wine64-preloader  Z:\\Games\\The Witcher 3\\witcher3.exe\n', '')):
                with self.assertRaises(m.PatchError):
                    m.ensure_stopped()
            with patch.object(m.subprocess, 'run', side_effect=OSError('not permitted')):
                with self.assertRaises(m.PatchError):
                    m.ensure_stopped()
        finally:
            self.stop.start()


if __name__ == '__main__':
    unittest.main()
