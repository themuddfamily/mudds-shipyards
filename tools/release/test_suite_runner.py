"""Focused runner fixtures: real completion forms, nested identities and modes."""
import csv
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
import test_suite_catalog as catalog

SUPPORT = Path(__file__).parent


class SuiteRunnerTests(unittest.TestCase):
    def test_source_declared_completion_forms_and_fail_closed(self):
        cases = [
            ('print("OTHER_NAME_TEST_OK")', 'OTHER_NAME_TEST_OK', 0),
            ('print("OK: ENet keepalive (%d assertions)" % _assertions)', 'OK: ENet keepalive (12 assertions)', 12),
            ('print("PASS local_test (%d assertions)" % _assertions)', 'PASS local_test (3 assertions)', 3),
            ('print("local_test: %d assertions" % _assertions)', 'local_test: 7 assertions', 7),
            ('print("CUE: %d checks, %d failures" % [_checks, _failures.size()])', 'CUE: 4 checks, 0 failures', 4),
            ('print("PASS: bomber payload (", _assertions, " assertions)")', 'PASS: bomber payload (5 assertions)', 5),
            ('print("Minimap tests passed")', 'Minimap tests passed', 0),
        ]
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / 'probe_test.gd'
            log = Path(temporary) / 'log'
            for source, output, assertions in cases:
                with self.subTest(output=output):
                    script.write_text(source)
                    log.write_text(output + '\n')
                    result = catalog.assess(script, log)
                    self.assertEqual(result[1], 1)
                    self.assertEqual(result[0], result[2])
                    self.assertEqual(result[3], assertions)
                    log.write_text(output + '\n' + output + '\n')
                    self.assertEqual(catalog.assess(script, log)[1], 2)
                    log.write_text(output + '\ntrailing unexpected output\n')
                    self.assertEqual(catalog.assess(script, log)[2], '<none>')
            script.write_text('print("PASS: %s" % description)\nprint("CUE: %d checks, %d failures")')
            for output in ('UNRELATED_TEST_OK', 'PASS: an assertion', 'CUE: 4 checks, 2 failures'):
                log.write_text(output + '\n')
                self.assertEqual(catalog.assess(script, log)[1], 0)

    def test_recursive_parallel_isolation_import_audio_and_display_selection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'tools/release'
            release.mkdir(parents=True)
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py'):
                shutil.copy2(SUPPORT / name, release / name)
            for relative in ('a/probe_test.gd', 'b/probe_test.gd', 'ui/render_test.gd'):
                script = root / 'tests' / relative
                script.parent.mkdir(parents=True, exist_ok=True)
                script.write_text('print("OK: fixture (%d assertions)" % 2)\n' + ('await RenderingServer.frame_post_draw\n' if relative.startswith('ui/') else ''))
            fake = root / 'fake-godot'
            fake.write_text('''#!/usr/bin/env python3
import os,sys,pathlib
args=sys.argv[1:]
assert args[args.index('--audio-driver')+1] == 'Dummy'
if '--editor' in args:
    pathlib.Path('import-seen').write_text('yes')
    sys.exit(0)
script=args[args.index('--script')+1]
assert ('--headless' in args) == ('/ui/' not in script)
user=pathlib.Path(os.environ['XDG_DATA_HOME'])
assert not (user/'marker').exists()
(user/'marker').write_text(script)
print('OK: fixture (2 assertions)')
''')
            fake.chmod(0o755)
            command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake), '--jobs', '2', '--results-dir', str(root / 'results'), '--manifest-scope', 'tests', '--import-gate', 'always']
            result = subprocess.run(command, cwd=root, env={**os.environ, 'TEST_MATRIX_RUN_ID': 'headless'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('NOT_RUN (graphical;', result.stdout)
            self.assertTrue((root / 'import-seen').exists())
            manifest = (root / 'results/headless/run-manifest.txt').read_text()
            self.assertIn('scope_specs=headless:all', manifest)
            self.assertIn('mode_excluded_suite_count=1', manifest)
            with (root / 'results/headless/results.tsv').open() as stream:
                rows = list(csv.DictReader(stream, delimiter='\t'))
            self.assertEqual([row['test_path'] for row in rows], ['tests/a/probe_test.gd', 'tests/b/probe_test.gd'])
            self.assertNotEqual(rows[0]['log_path'], rows[1]['log_path'])
            self.assertTrue(all(row['status'] == 'PASS' for row in rows))
            result = subprocess.run(command + ['--mode', 'graphical'], cwd=root, env={**os.environ, 'DISPLAY': ':fixture', 'TEST_MATRIX_RUN_ID': 'graphical'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run(command + ['--mode', 'graphical'], cwd=root, env={**os.environ, 'DISPLAY': '', 'WAYLAND_DISPLAY': '', 'TEST_MATRIX_RUN_ID': 'no-display'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 2)
            self.assertIn('require DISPLAY', result.stdout)

    def test_live_roster_covers_nested_suites_and_rendering(self):
        root = SUPPORT.resolve().parents[1]
        paths = catalog.suites(root)
        self.assertGreaterEqual(sum(len(p.relative_to(root / 'tests').parts) > 1 for p in paths), 272)
        self.assertEqual(catalog.mode(root / 'tests/ui/cinder_navigator_ping_hud_render_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/network/network_enet_keepalive_test.gd'), 'headless')


if __name__ == '__main__':
    unittest.main()
