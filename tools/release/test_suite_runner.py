"""Focused runner fixtures: real completion forms, nested identities and modes."""
import csv
import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
import test_suite_catalog as catalog
import source_manifest

SUPPORT = Path(__file__).parent


class SuiteRunnerTests(unittest.TestCase):
    def test_source_declared_completion_forms_and_fail_closed(self):
        cases = [
            ('print("OTHER_NAME_TEST_OK")', 'OTHER_NAME_TEST_OK', 0),
            ('print("OTHER_NAME_TEST_PASSED")', 'OTHER_NAME_TEST_PASSED', 0),
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

    def test_assertion_summary_precedes_required_terminal_token(self):
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / 'probe_test.gd'
            log = Path(temporary) / 'log'
            script.write_text('print("probe: %d assertions" % _assertions)\nprint("PROBE_TEST_OK")')
            log.write_text('probe: 5 assertions\nPROBE_TEST_OK\n')
            self.assertEqual(catalog.assess(script, log), ('PROBE_TEST_OK', 1, 'PROBE_TEST_OK', 5))
            log.write_text('probe: 5 assertions\n')
            self.assertEqual(catalog.assess(script, log)[1], 0)
            log.write_text('probe: 5 assertions\nPROBE_TEST_OK\nPROBE_TEST_OK\n')
            self.assertEqual(catalog.assess(script, log)[1], 2)

    def test_source_manifest_matches_shell_and_detects_drift(self):
        # Differential coverage of the former find/stat/sha256sum contract.
        old_writer = r'''set -euo pipefail
root="$1"; output="$2"; shift 2
paths="$(mktemp)"
trap 'rm -f "$paths"' EXIT
for entry in "$@"; do
    if [[ -f "$root/$entry" ]]; then printf '%s\0' "$root/$entry" >> "$paths"
    elif [[ -d "$root/$entry" ]]; then find "$root/$entry" -type f -print0 >> "$paths"
    fi
done
printf 'path,size_bytes,sha256\n' > "$output"
while IFS= read -r -d '' file; do
    relative="${file#"$root"/}"
    printf '%s,%s,%s\n' "$relative" "$(stat -c '%s' "$file")" "$(sha256sum "$file" | cut -d' ' -f1)" >> "$output"
done < <(LC_ALL=C sort -z "$paths")
'''
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'tree/nested').mkdir(parents=True)
            target = root / 'tree/nested/space name.gd'
            target.write_text('before')
            (root / 'tree/.hidden').write_bytes(b'\x00\xff')
            (root / 'tree/excluded-link').symlink_to(target)
            (root / 'tree/excluded-directory').symlink_to(root / 'tree/nested')
            (root / 'explicit-link').symlink_to(target)
            (root / 'explicit-directory').symlink_to(root / 'tree')
            scope = ['tree', 'explicit-link', 'explicit-directory', 'missing', 'tree/nested']
            old = root / 'old.csv'
            new = root / 'new.csv'
            subprocess.run(['bash', '-c', old_writer, 'fixture', str(root), str(old), *scope], check=True)
            source_manifest.write_manifest(root, scope, new)
            baseline = new.read_bytes()
            self.assertEqual(old.read_bytes(), baseline)
            self.assertNotIn(b'excluded', baseline)
            self.assertIn(b'explicit-link', baseline)
            # Content changes of identical length, new paths and removed paths
            # must all change the source-freeze bytes.
            target.write_text('after!')
            source_manifest.write_manifest(root, scope, new)
            self.assertNotEqual(new.read_bytes(), baseline)
            baseline = new.read_bytes()
            added = root / 'tree/new.gd'
            added.write_text('new')
            source_manifest.write_manifest(root, scope, new)
            self.assertNotEqual(new.read_bytes(), baseline)
            added.unlink()
            source_manifest.write_manifest(root, scope, new)
            self.assertEqual(new.read_bytes(), baseline)

    def test_render_001_requires_explicit_opt_in_and_exact_shutdown_block(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'tools/release'
            release.mkdir(parents=True)
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py'):
                shutil.copy2(SUPPORT / name, release / name)
            (root / 'tests').mkdir()
            (root / 'tests/probe_test.gd').write_text('print("PROBE_TEST_OK")')
            fake = root / 'fake-godot'
            fake.write_text('#!/usr/bin/env bash\ncat "$RISK_FIXTURE_LOG"\n')
            fake.chmod(0o755)
            raw = root / 'raw.log'
            block = '\n'.join(catalog.RENDER_001_BLOCK) + '\n'
            cases = [
                ('strict', block, False, 1),
                ('accepted', block, True, 0),
                ('clean-opt-in', '', True, 0),
                ('trailing-text', block + 'unexpected trailing text\n', True, 1),
                ('changed-count', block.replace('7 RIDs', '8 RIDs'), True, 1),
                ('changed-type', block.replace('"Texture"', '"Buffer"'), True, 1),
                ('changed-location', block.replace(':8900', ':8901'), True, 1),
                ('extra-error', block + 'ERROR: another error\n', True, 1),
                ('earlier-error', 'ERROR: another error\n' + block, True, 1),
                ('repeated', block + block, True, 1),
            ]
            for run_id, ending, opt_in, expected_exit in cases:
                with self.subTest(run_id=run_id):
                    raw.write_text('PASS: fixture assertion\nPROBE_TEST_OK\n' + ending)
                    command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake), '--jobs', '1', '--results-dir', str(root / 'results'), '--manifest-scope', 'tests', '--import-gate', 'never']
                    if opt_in:
                        command += ['--accepted-risk', 'RENDER-001']
                    result = subprocess.run(command, cwd=root, env={**os.environ, 'RISK_FIXTURE_LOG': str(raw), 'TEST_MATRIX_RUN_ID': run_id}, text=True, capture_output=True, timeout=20)
                    self.assertEqual(result.returncode, expected_exit, result.stdout + result.stderr)
                    run = root / 'results' / run_id
                    self.assertEqual((run / 'logs/probe_test.log').read_bytes(), raw.read_bytes())
                    with (run / 'results.tsv').open() as stream:
                        detail = next(csv.DictReader(stream, delimiter='\t'))
                    self.assertEqual(detail['log_sha256'], hashlib.sha256(raw.read_bytes()).hexdigest())
                    with (run / 'results-canonical.tsv').open() as stream:
                        row = next(csv.DictReader(stream, delimiter='\t'))
                    if run_id == 'accepted':
                        self.assertEqual(row['accepted_risk_ids'], 'RENDER-001')
                        self.assertEqual(row['accepted_risk_count'], '1')
                        self.assertEqual(row['diagnostic_count'], '0')
                        self.assertEqual(row['raw_diagnostic_count'], '1')
                        self.assertIn('accepted_risk_count=1', (run / 'run-manifest.txt').read_text())
                    elif run_id != 'earlier-error':
                        self.assertEqual(row.get('accepted_risk_count', '0'), '0')

    def test_parallel_network_lane_allows_other_work_and_releases_after_timeout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'tools/release'
            release.mkdir(parents=True)
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py'):
                shutil.copy2(SUPPORT / name, release / name)
            scripts = ['network/a_test.gd', 'network/b_test.gd', 'network/c_test.gd', 'network_top_test.gd', 'z_other_test.gd']
            for relative in scripts:
                script = root / 'tests' / relative
                script.parent.mkdir(parents=True, exist_ok=True)
                script.write_text('print("OK: network lane fixture")')
            fake = root / 'fake-godot'
            fake.write_text('''#!/usr/bin/env python3
import os,sys,pathlib,time,signal,fcntl
root=pathlib.Path(os.environ['LANE_FIXTURE_ROOT'])
args=sys.argv[1:]
script=args[args.index('--script')+1]
network='/network/' in script or script.endswith('/network_top_test.gd')
active=root/'active-network'
def stop(*_):
    if network and active.exists(): active.rmdir()
    sys.exit(143)
signal.signal(signal.SIGTERM,stop)
if network:
    inherited=[]
    for fd in pathlib.Path('/proc/self/fd').iterdir():
        try: path=os.readlink(fd)
        except FileNotFoundError: continue
        if path.endswith('/network.lock'): inherited.append(path)
    assert len(inherited)==1, 'network lock descriptor was not inherited'
    with open(inherited[0], 'w') as contender:
        try: fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: pass
        else: raise AssertionError('parent did not hold the network flock')
    try: active.mkdir()
    except FileExistsError:
        (root/'collision').touch()
        sys.exit(7)
    if script.endswith('/a_test.gd'):
        deadline=time.monotonic()+3
        while not (root/'other-complete').exists() and time.monotonic()<deadline: time.sleep(0.01)
        assert (root/'other-complete').exists(), 'nonnetwork workers were starved'
        if os.environ.get('LANE_TIMEOUT') == '1': time.sleep(10)
    with (root/'network-complete').open('a') as out: out.write(script+'\\n')
    active.rmdir()
else:
    (root/'other-complete').touch()
print('OK: network lane fixture')
''')
            fake.chmod(0o755)
            command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake), '--jobs', '4', '--results-dir', str(root / 'results'), '--manifest-scope', 'tests', '--import-gate', 'never', '--timeout', '4']
            for timeout in (False, True):
                with self.subTest(timeout=timeout):
                    for marker in ('other-complete', 'network-complete'):
                        (root / marker).unlink(missing_ok=True)
                    run_id = 'timeout' if timeout else 'success'
                    extra = ['--timeout', '1'] if timeout else []
                    result = subprocess.run(command + extra, cwd=root, env={**os.environ, 'LANE_FIXTURE_ROOT': str(root), 'LANE_TIMEOUT': str(int(timeout)), 'TEST_MATRIX_RUN_ID': run_id}, text=True, capture_output=True, timeout=15)
                    self.assertEqual(result.returncode, int(timeout), result.stdout + result.stderr)
                    self.assertFalse((root / 'collision').exists())
                    self.assertFalse((root / 'active-network').exists())
                    completed = (root / 'network-complete').read_text().splitlines()
                    self.assertEqual(len(completed), 3 if timeout else 4)
                    with (root / 'results' / run_id / 'results.tsv').open() as stream:
                        rows = list(csv.DictReader(stream, delimiter='\t'))
                    self.assertEqual([row['test_path'] for row in rows], sorted('tests/' + item for item in scripts))
                    self.assertEqual(rows[0]['exit_code'], '124' if timeout else '0')
                    self.assertTrue(all(row['status'] == 'PASS' for row in rows[1:]))

    def test_generic_pass_descriptions_are_not_completion(self):
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / 'probe_test.gd'
            log = Path(temporary) / 'log'
            for source, output in (
                ('print("PASS %s" % description)', 'PASS a successful assertion'),
                ('print("PASS %s (%d assertions)" % [description, 2])', 'PASS arbitrary (2 assertions)'),
                ('print("OK: %s" % description)', 'OK: a successful assertion'),
                ('print("PASS ", description)', 'PASS '),
            ):
                with self.subTest(source=source):
                    script.write_text(source)
                    log.write_text(output + '\n')
                    self.assertEqual(catalog.assess(script, log)[1:3], (0, '<none>'))

    def test_recursive_parallel_isolation_import_audio_and_display_selection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'tools/release'
            release.mkdir(parents=True)
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py'):
                shutil.copy2(SUPPORT / name, release / name)
            for relative in ('a/probe_test.gd', 'b/probe_test.gd', 'ui/render_test.gd'):
                script = root / 'tests' / relative
                script.parent.mkdir(parents=True, exist_ok=True)
                script.write_text('print("OK: fixture (%d assertions)" % 2)\n' + ('await RenderingServer.frame_post_draw\n' if relative.startswith('ui/') else ''))
            (root / 'tests/probe_support.py').write_text('VALUE = 1\n')
            fake = root / 'fake-godot'
            fake.write_text('''#!/usr/bin/env python3
import os,sys,pathlib
args=sys.argv[1:]
assert args[args.index('--audio-driver')+1] == 'Dummy'
if '--editor' in args:
    assert '--headless' in args and '--display-driver' not in args
    pathlib.Path('import-seen').write_text('yes')
    sys.exit(0)
script=args[args.index('--script')+1]
sys.path.insert(0, 'tests')
import probe_support
assert ('--headless' in args) == ('/ui/' not in script)
if '/ui/' in script:
    assert args[args.index('--display-driver')+1] == 'x11'
else:
    assert '--display-driver' not in args
user=pathlib.Path(os.environ['XDG_DATA_HOME'])
assert not (user/'marker').exists()
(user/'marker').write_text(script)
print('OK: fixture (2 assertions)')
''')
            fake.chmod(0o755)
            command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake), '--jobs', '2', '--results-dir', str(root / 'results'), '--manifest-scope', 'tests', '--import-gate', 'always']
            result = subprocess.run(command, cwd=root, env={**os.environ, 'TEST_MATRIX_DISPLAY_DRIVER': 'x11', 'TEST_MATRIX_RUN_ID': 'headless'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('NOT_RUN (graphical;', result.stdout)
            self.assertTrue((root / 'import-seen').exists())
            self.assertFalse((root / 'tests/__pycache__').exists())
            manifest = (root / 'results/headless/run-manifest.txt').read_text()
            self.assertIn('scope_specs=headless:all', manifest)
            self.assertIn('mode_excluded_suite_count=1', manifest)
            with (root / 'results/headless/results.tsv').open() as stream:
                rows = list(csv.DictReader(stream, delimiter='\t'))
            self.assertEqual([row['test_path'] for row in rows], ['tests/a/probe_test.gd', 'tests/b/probe_test.gd'])
            self.assertNotEqual(rows[0]['log_path'], rows[1]['log_path'])
            self.assertTrue(all(row['status'] == 'PASS' for row in rows))
            result = subprocess.run(command + ['--mode', 'graphical'], cwd=root, env={**os.environ, 'TEST_MATRIX_DISPLAY_DRIVER': 'x11', 'DISPLAY': ':fixture', 'TEST_MATRIX_RUN_ID': 'graphical'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            manifest = (root / 'results/graphical/run-manifest.txt').read_text()
            self.assertIn('display_driver=x11\n', manifest)
            # CLI wins over the inherited backend in a mixed run, without
            # forwarding it to either headless children or the import gate.
            result = subprocess.run(command + ['--mode', 'all', '--display-driver', 'x11'], cwd=root, env={**os.environ, 'TEST_MATRIX_DISPLAY_DRIVER': 'wayland', 'DISPLAY': ':fixture', 'TEST_MATRIX_RUN_ID': 'all'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('display_driver=x11\n', (root / 'results/all/run-manifest.txt').read_text())
            result = subprocess.run(command + ['--mode', 'graphical'], cwd=root, env={**os.environ, 'DISPLAY': '', 'WAYLAND_DISPLAY': '', 'TEST_MATRIX_RUN_ID': 'no-display'}, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 2)
            self.assertIn('require DISPLAY', result.stdout)

    def test_live_roster_covers_nested_suites_and_rendering(self):
        root = SUPPORT.resolve().parents[1]
        paths = catalog.suites(root)
        self.assertGreaterEqual(sum(len(p.relative_to(root / 'tests').parts) > 1 for p in paths), 272)
        self.assertEqual(catalog.mode(root / 'tests/ui/cinder_navigator_ping_hud_render_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/aft_junction_stair_handoff_visual_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/cinder_cargo_hauler_freight_frame_visual_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/network/network_enet_keepalive_test.gd'), 'headless')


if __name__ == '__main__':
    unittest.main()
