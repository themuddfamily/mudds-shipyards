#!/usr/bin/env python3
"""Inert lifecycle-consumer boundary tests; never run a manager, game or X server."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import tarfile
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

if __package__:
    from . import run_linux_install_lifecycle as lifecycle
else:
    import run_linux_install_lifecycle as lifecycle


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='lifecycle-inert-')
        self.base = Path(self.temporary.name)
        self.root = self.base / 'fresh root'
        self.tag = 'MuddsShipyards-1234567'
        self.binary = self.tag + '.x86_64'
        self.template = b'\x7fELFinert-template'
        self.elf = self.template + b'inert-payload'
        self.save = b'{"inert":"save"}'
        self.archive = self.base / (self.tag + '-linux-x86_64.tar.gz')
        with tarfile.open(self.archive, 'w:gz') as archive:
            directory = tarfile.TarInfo(self.tag)
            directory.type = tarfile.DIRTYPE
            directory.mode = 0o755
            archive.addfile(directory)
            for name, raw in ((self.binary, self.elf), ('mudds-shipyards.png', b'\x89PNG\r\n\x1a\nicon'),
                              ('mudds-shipyards.desktop', b'entry'), ('install-desktop-entry.sh', b'shell'),
                              ('install_linux_desktop.py', b'# inert shipped manager\n')):
                member = tarfile.TarInfo(self.tag + '/' + name)
                member.size = len(raw)
                member.mode = 0o755 if name == self.binary else 0o644
                archive.addfile(member, io.BytesIO(raw))
        self.export = self.base / 'export-result.json'
        self.record = dict(schema_version=1, platform='linux', architecture='x86_64', preset='Linux',
                           source_commit='1234567' + 'a' * 33, tarball_root=self.tag,
                           binary=dict(path='/old/deleted/' + self.binary, bytes=len(self.elf), sha256=digest(self.elf)),
                           tarball=dict(path='/old/deleted/' + self.archive.name, bytes=self.archive.stat().st_size,
                                        sha256=lifecycle.manager.digest(self.archive)),
                           release_template=dict(bytes=len(self.template), sha256=digest(self.template),
                                                 expected_sha256=digest(self.template)))
        self.export.write_text(json.dumps(self.record))
        self.save_path = self.base / 'save.json'
        self.save_path.write_bytes(self.save)
        self.args = argparse.Namespace(archive=str(self.archive), archive_sha256=lifecycle.manager.digest(self.archive),
                                       export_result=str(self.export), retained_save=str(self.save_path),
                                       retained_save_sha256=digest(self.save), root=str(self.root))
        self.pins = patch.multiple(lifecycle, SAVE_SHA=digest(self.save), SAVE_BYTES=len(self.save))
        self.pins.start()
        self.addCleanup(self.pins.stop)
        self.addCleanup(self.temporary.cleanup)

    def test_preflight_trusts_exact_export_bytes_not_obsolete_export_path(self):
        root, paths, inputs, export, payload = lifecycle.preflight(self.args)
        self.assertEqual(root, self.root)
        self.assertEqual(payload[self.binary], dict(bytes=len(self.elf), sha256=digest(self.elf)))
        self.assertFalse(root.exists())

    def test_existing_root_is_refused_without_mutation(self):
        self.root.mkdir()
        note = self.root / 'do-not-touch'
        note.write_bytes(b'keep')
        with self.assertRaises(lifecycle.Refusal): lifecycle.preflight(self.args)
        self.assertEqual(note.read_bytes(), b'keep')
        self.assertEqual(list(self.root.iterdir()), [note])

    def test_symlink_root_parent_and_input_are_refused_before_mutation(self):
        link = self.base / 'link'
        link.symlink_to(self.base, target_is_directory=True)
        self.args.root = str(link / 'fresh')
        with self.assertRaises(lifecycle.manager.InstallError): lifecycle.preflight(self.args)
        self.args.root = str(self.root)
        self.args.retained_save = str(link / self.save_path.name)
        with self.assertRaises(lifecycle.manager.InstallError): lifecycle.preflight(self.args)
        self.assertFalse(self.root.exists())

    def test_archive_tamper_and_template_mismatch_refuse_before_mutation(self):
        original = self.archive.read_bytes()
        self.archive.write_bytes(original + b'tamper')
        with self.assertRaises(lifecycle.Refusal): lifecycle.preflight(self.args)
        self.assertFalse(self.root.exists())
        self.archive.write_bytes(original)
        self.record['release_template']['expected_sha256'] = 'a' * 64
        self.export.write_text(json.dumps(self.record))
        with self.assertRaisesRegex(lifecycle.Refusal, 'template pin'): lifecycle.preflight(self.args)
        self.assertFalse(self.root.exists())

    def test_protected_files_require_exact_bytes_and_mode(self):
        path = self.base / 'protected'
        path.write_bytes(b'root notes\n')
        path.chmod(0o640)
        expected = {path: lifecycle.identity(path)}
        lifecycle.preserved(expected)
        path.chmod(0o600)
        with self.assertRaises(lifecycle.Refusal): lifecycle.preserved(expected)
        path.chmod(0o640)
        path.write_bytes(b'root notes!\n')
        with self.assertRaises(lifecycle.Refusal): lifecycle.preserved(expected)

    def test_child_boundary_uses_existing_supervisor_and_preserves_caps(self):
        process = Mock()
        process.wait.return_value = 0
        steps = []
        env = dict(HOME='/inherited', TMPDIR='/private/tmp')
        with patch.object(lifecycle.subprocess, 'Popen', return_value=process) as spawn:
            lifecycle.run_child(['inert-manager', 'uninstall'], 10, env, self.base / 'child.log', steps, child_umask=0o022)
        argv = spawn.call_args.args[0]
        self.assertEqual(argv[-2:], ['inert-manager', 'uninstall'])
        self.assertEqual(argv[2:5], ['--timeout', '10', '--'])
        self.assertTrue(argv[1].endswith('/suite_process.py'))
        self.assertEqual(spawn.call_args.kwargs['env'], env)
        self.assertEqual(spawn.call_args.kwargs['umask'], 0o022)
        process.wait.assert_called_once_with(timeout=20)
        self.assertEqual(steps[0]['exit_code'], 0)

    def test_timeout_and_abort_terminate_supervisor_and_propagate(self):
        for error in (subprocess.TimeoutExpired('inert', 340), lifecycle.Abort(signal.SIGINT)):
            process = Mock()
            process.wait.side_effect = [error, 143]
            with patch.object(lifecycle.subprocess, 'Popen', return_value=process):
                with self.assertRaises(type(error)):
                    lifecycle.run_child(['inert-guided'], 330, {}, self.base / ('timeout-' + type(error).__name__), [])
            process.send_signal.assert_called_once_with(signal.SIGTERM)
            self.assertEqual(process.wait.call_args_list[0].kwargs, {'timeout': 340})

    def test_startup_requires_exactly_one_marker_and_no_diagnostics(self):
        binary = self.base / self.binary
        record = dict(status='PASS', check='linux_startup_menu_ready', exit_code=0,
                      sentinel_count=1, binary_sha256=digest(self.elf), input=str(binary),
                      launch_mode='headless', wall_ms=100, reasons=[])
        result_path = self.base / (self.binary + '.startup-check.json')
        log = self.base / (self.binary + '.startup-check.log')
        result_path.write_text(json.dumps(record))
        log.write_bytes(b'STARTUP_MENU_READY_OK\n')
        lifecycle.startup_result(self.base, binary, digest(self.elf))
        actual_marker = b'STARTUP_MENU_READY_OK: {"mouse_free_during_load":true,"stages":[],"time_to_interactive_ms":20429.85}\n'
        log.write_bytes(actual_marker)
        lifecycle.startup_result(self.base, binary, digest(self.elf))
        for raw in (b'STARTUP_MENU_READY_OK\nSTARTUP_MENU_READY_OK\n', b'STARTUP_MENU_READY_OK\nERROR: bad\n',
                    actual_marker + actual_marker, b'STARTUP_MENU_READY_OKnot-a-token\n'):
            log.write_bytes(raw)
            with self.assertRaises(lifecycle.Refusal): lifecycle.startup_result(self.base, binary, digest(self.elf))

    def test_independent_timer_aborts_in_process_work_and_pauses_only_gamechecks(self):
        started = time.monotonic()
        with self.assertRaisesRegex(lifecycle.Refusal, 'exceeded120s'):
            with lifecycle.InstallerBudget(0.08) as budget:
                with budget.gameplay():
                    time.sleep(0.12)  # Longer than the whole budget; explicitly suspended.
                self.assertFalse(budget.paused)
                remaining, _interval = signal.getitimer(signal.ITIMER_REAL)
                self.assertGreater(remaining, 0)
                self.assertLessEqual(remaining, 0.08)
                time.sleep(0.3)  # No elapsed-time polling or child process needed to abort.
        self.assertGreaterEqual(time.monotonic() - started, 0.12)
        self.assertEqual(signal.getitimer(signal.ITIMER_REAL), (0.0, 0.0))

    def test_execution_arms_independent_budget_before_preflight(self):
        def preflight(_args):
            self.assertGreater(signal.getitimer(signal.ITIMER_REAL)[0], 0)
            self.assertLessEqual(signal.getitimer(signal.ITIMER_REAL)[0], 120)
            raise lifecycle.Refusal('inert preflight stop')
        with patch.object(lifecycle, 'preflight', side_effect=preflight):
            with self.assertRaisesRegex(lifecycle.Refusal, 'inert preflight stop'):
                lifecycle.execute(self.args)
        self.assertFalse(self.root.exists())
        self.assertEqual(signal.getitimer(signal.ITIMER_REAL), (0.0, 0.0))

    def guided(self):
        binary = self.base / self.binary
        document = dict(payload=dict(crash_recovery=dict(state='clean'), safe_start_recovery=dict(state='clean_shutdown')))
        raw = json.dumps(document).encode()
        (self.base / 'guided-post-exit-user-data.json').write_bytes(raw)
        record = dict(success=True, route='guided', cap_seconds=300, elapsed_seconds=55,
                      binary=str(binary), binary_sha256=digest(self.elf), diagnostic_count=0,
                      inputs_released=True, game_reaped=True, xvfb_reaped=True, input_helper_reaped=True,
                      arguments=[str(binary), '--audio-driver', 'Dummy', '--display-driver', 'x11',
                                 '--rendering-driver', 'dummy', '--disable-render-loop', '--native-sortie-observer'],
                      sortie=dict(normal_ui_exit=True, exit_code=0, default_sampler=True, walked_m=9,
                                  phases=lifecycle.PHASES, receipts=dict(exit_ui=dict(focused=True))),
                      game_legs=[dict(exit_code=0, reaped=True, normal_ui_exit=True)],
                      post_exit_user_data=dict(captured=True, crash_recovery_state='clean',
                                               safe_start_recovery_state='clean_shutdown', sha256=digest(raw), document=document))
        (self.base / 'game.log').write_bytes(b'ordinary game log\n')
        return binary, record

    def test_guided_requires_full_real_result_contract_not_exit_success(self):
        binary, record = self.guided()
        result_path = self.base / 'result.json'
        result_path.write_text(json.dumps(record))
        lifecycle.guided_result(self.base, binary, digest(self.elf))
        for key, value in [('post_exit_user_data', {}), ('game_legs', []), ('sortie', {}),
                           ('inputs_released', False), ('diagnostic_count', 1)]:
            altered = dict(record, **{key: value})
            result_path.write_text(json.dumps(altered))
            with self.assertRaises(lifecycle.Refusal): lifecycle.guided_result(self.base, binary, digest(self.elf))
        result_path.write_text(json.dumps(record))
        (self.base / 'guided-post-exit-user-data.json').write_bytes(b'tampered')
        with self.assertRaises(lifecycle.Refusal): lifecycle.guided_result(self.base, binary, digest(self.elf))


if __name__ == '__main__':
    unittest.main()
