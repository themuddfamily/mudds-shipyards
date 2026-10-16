"""Focused runner fixtures: real completion forms, nested identities and modes."""
import csv
import hashlib
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
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

    def test_declared_filename_terminal_requires_one_final_completion(self):
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / 'game_flow_planetary_return_approach_test.gd'
            log = Path(temporary) / 'log'
            intermediate = ('HOME_RETURN_STREAMED_RELAY_CLEANUP_OK: strict home '
                            'contract retires its composition without detaching the streamed-out relay twice')
            for suffix in ('OK', 'PASS', 'PASSED'):
                terminal = script.stem.upper() + '_' + suffix
                script.write_text('print("' + intermediate + '")\n'
                                  'print("' + terminal + ': %d assertions" % _checks)\n')
                completion = terminal + ': 44 assertions'
                cases = [
                    ('complete', intermediate + '\n' + completion + '\n', 1, terminal),
                    ('missing', intermediate + '\n', 0, '<none>'),
                    ('duplicate', intermediate + '\n' + completion + '\n' + completion + '\n', 2, terminal),
                    ('early', completion + '\n' + intermediate + '\n', 1, '<none>'),
                    ('trailing', intermediate + '\n' + completion + '\nunexpected trailing output\n', 1, '<none>'),
                    ('foreign', intermediate + '\nUNRELATED_TEST_OK\n', 0, '<none>'),
                ]
                for name, output, count, last in cases:
                    with self.subTest(suffix=suffix, case=name):
                        log.write_text(output)
                        found, actual_count, actual_last, assertions = catalog.assess(script, log)
                        self.assertEqual(actual_count, count)
                        self.assertEqual(actual_last, last)
                        self.assertEqual(found, terminal if count else '<none>')
                        if name == 'complete':
                            self.assertEqual(assertions, 44)

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
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py', 'suite_process.py'):
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
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py', 'suite_process.py'):
                shutil.copy2(SUPPORT / name, release / name)
            scripts = ['network/a_test.gd', 'network/b_test.gd', 'network/c_test.gd', 'network_top_test.gd', 'world/shared_test.gd', 'z_other_test.gd']
            for relative in scripts:
                script = root / 'tests' / relative
                script.parent.mkdir(parents=True, exist_ok=True)
                script.write_text(('## test-matrix-network: required\n' if relative == 'world/shared_test.gd' else '') + 'print("OK: network lane fixture")')
            fake = root / 'fake-godot'
            fake.write_text('''#!/usr/bin/env python3
import os,sys,pathlib,time,signal,fcntl
root=pathlib.Path(os.environ['LANE_FIXTURE_ROOT'])
args=sys.argv[1:]
script=args[args.index('--script')+1]
network='/network/' in script or script.endswith(('/network_top_test.gd', '/world/shared_test.gd'))
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
                    self.assertEqual(len(completed), 4 if timeout else 5)
                    with (root / 'results' / run_id / 'results.tsv').open() as stream:
                        rows = list(csv.DictReader(stream, delimiter='\t'))
                    self.assertEqual([row['test_path'] for row in rows], sorted('tests/' + item for item in scripts))
                    self.assertEqual(rows[0]['exit_code'], '124' if timeout else '0')
                    self.assertTrue(all(row['status'] == 'PASS' for row in rows[1:]))

    def test_parallel_graphical_display_lane_keeps_headless_parallel_and_wait_outside_clock(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'tools/release'
            release.mkdir(parents=True)
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py', 'suite_process.py'):
                shutil.copy2(SUPPORT / name, release / name)
            # Both queued graphical suites sort before runnable headless work.
            # Queued graphical suites must leave slots for runnable headless work.
            scripts = ['network/a_display_test.gd', 'ui/d_input_test.gd', 'ui/e_readback_test.gd',
                       'z_b_headless_test.gd', 'z_c_headless_test.gd']
            for relative in scripts:
                script = root / 'tests' / relative
                script.parent.mkdir(parents=True, exist_ok=True)
                display = ('await RenderingServer.frame_post_draw\n' if 'readback' in relative
                           else '## test-matrix-display: input-only\n') if relative.startswith(('network/', 'ui/')) else ''
                script.write_text(display + 'print("DISPLAY_LANE_TEST_OK: 1 assertions")\n')
            fake = root / 'fake-godot'
            fake.write_text('''#!/usr/bin/env python3
import os,sys,pathlib,time
root=pathlib.Path(os.environ['DISPLAY_LANE_ROOT'])
args=sys.argv[1:]
script=args[args.index('--script')+1]
assert args[args.index('--audio-driver')+1] == 'Dummy'
graphical='--headless' not in args
if graphical:
    assert args[args.index('--display-driver')+1] == 'x11'
    active=root/'pointer-owner'
    try: active.mkdir()
    except FileExistsError:
        (root/'collision').touch()
        print('ERROR: NO GRAB')
        print('DISPLAY_LANE_TEST_OK: 1 assertions')
        sys.exit(0)
    if os.environ['DISPLAY_LANE_JOBS'] != '1':
        deadline=time.monotonic()+1
        while not (root/'headless-overlap').exists() and time.monotonic()<deadline: time.sleep(0.01)
        assert (root/'headless-overlap').exists(), 'display lock starved headless workers'
    time.sleep(1.1)
    active.rmdir()
else:
    own=root/pathlib.Path(script).stem
    own.touch()
    if os.environ['DISPLAY_LANE_JOBS'] != '1':
        deadline=time.monotonic()+1
        while len(list(root.glob('*_headless_test')))<2 and time.monotonic()<deadline: time.sleep(0.01)
        assert len(list(root.glob('*_headless_test')))==2, 'headless suites no longer overlap'
    (root/'headless-overlap').touch()
print('DISPLAY_LANE_TEST_OK: 1 assertions')
''')
            fake.chmod(0o755)
            command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake),
                       '--jobs', '3', '--mode', 'all', '--display-driver', 'x11',
                       '--results-dir', str(root / 'results'), '--manifest-scope', 'tests',
                       '--import-gate', 'never', '--timeout', '2']
            for jobs in (3, 1):
                with self.subTest(jobs=jobs):
                    for marker in ('z_b_headless_test', 'z_c_headless_test', 'headless-overlap', 'collision'):
                        (root / marker).unlink(missing_ok=True)
                    if (root / 'pointer-owner').exists():
                        (root / 'pointer-owner').rmdir()
                    run_id = f'display-lane-{jobs}'
                    result = subprocess.run(command + ['--jobs', str(jobs)], cwd=root,
                                            env={**os.environ, 'DISPLAY_LANE_ROOT': str(root),
                                                 'DISPLAY_LANE_JOBS': str(jobs),
                                                 'DISPLAY': ':fixture', 'TEST_MATRIX_RUN_ID': run_id},
                                            text=True, capture_output=True, timeout=15)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertFalse((root / 'collision').exists())
                    self.assertFalse((root / 'pointer-owner').exists())
                    with (root / 'results' / run_id / 'results.tsv').open() as stream:
                        rows = list(csv.DictReader(stream, delimiter='\t'))
                    self.assertEqual([row['test_path'] for row in rows],
                                     sorted('tests/' + item for item in scripts))
                    self.assertTrue(all(row['status'] == 'PASS' and row['diagnostic_count'] == '0' for row in rows))
                    self.assertTrue(all(int(row['duration_ms']) < 2000 for row in rows))

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
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py', 'suite_process.py'):
                shutil.copy2(SUPPORT / name, release / name)
            for relative in ('a/probe_test.gd', 'b/probe_test.gd', 'ui/render_test.gd', 'ui/input_test.gd', 'ui/declared_readback_test.gd'):
                script = root / 'tests' / relative
                script.parent.mkdir(parents=True, exist_ok=True)
                script.write_text('print("OK: fixture (%d assertions)" % 2)\n'
                                  + ('## test-matrix-display: input-only\n' if relative in ('ui/input_test.gd', 'ui/declared_readback_test.gd') else '')
                                  + ('await RenderingServer.frame_post_draw\n' if relative in ('ui/render_test.gd', 'ui/declared_readback_test.gd') else ''))
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
assert ('--disable-render-loop' in args) == script.endswith('/ui/input_test.gd')
assert ('--rendering-driver' in args) == script.endswith('/ui/input_test.gd')
if '--rendering-driver' in args:
    assert args[args.index('--rendering-driver')+1] == 'dummy'
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
            self.assertIn('mode_excluded_suite_count=3', manifest)
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

    def test_declared_input_display_requirement_keeps_readback_drawing(self):
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / 'probe_test.gd'
            for source, expected in (
                ('extends SceneTree\n', 'headless'),
                ('## test-matrix-display: input-only\nextends SceneTree\n', 'graphical'),
                ('## test-matrix-display: headless\nextends SceneTree\n', 'headless'),
                ('var label = "## test-matrix-display: input-only"\n', 'headless'),
            ):
                with self.subTest(source=source):
                    script.write_text(source)
                    self.assertEqual(catalog.mode(script), expected)
                    self.assertEqual(catalog.input_only(script), expected == 'graphical')
            for marker in catalog.RENDER_MARKERS:
                with self.subTest(readback=marker):
                    for declaration in ('headless', 'input-only'):
                        script.write_text('## test-matrix-display: ' + declaration + '\n' + marker + '\n')
                        self.assertEqual(catalog.mode(script), 'graphical')
                        self.assertFalse(catalog.input_only(script))

    def test_all_mode_preserves_headless_and_graphical_timeout_budgets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'tools/release'
            release.mkdir(parents=True)
            for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py', 'suite_process.py'):
                shutil.copy2(SUPPORT / name, release / name)
            tests = root / 'tests'
            tests.mkdir()
            for name, graphical, declared in (
                ('headless', False, 0), ('headless_long', False, 1500),
                ('graphical', True, 0), ('graphical_long', True, 900),
            ):
                (tests / f'{name}_test.gd').write_text(
                    (f'## test-matrix-timeout-seconds: {declared}\n' if declared else '')
                    + ('await RenderingServer.frame_post_draw\n' if graphical else '')
                    + 'print("OK: fixture (2 assertions)")\n')
            fake = root / 'fake-godot'
            fake.write_text('#!/usr/bin/env bash\nprintf "OK: fixture (2 assertions)\\n"\n')
            fake.chmod(0o755)
            # Record the actual worker budget without waiting for a fake engine.
            supervisor = release / 'suite_process.py'
            supervisor.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
args = sys.argv[1:]
script = args[args.index('--script') + 1]
with pathlib.Path(os.environ['BUDGET_RECORD']).open('a') as stream:
    stream.write(script + '\\t' + args[args.index('--timeout') + 1] + '\\n')
command = args[args.index('--') + 1:]
os.execvp(command[0], command)
''')
            record = root / 'budgets.tsv'
            environment = {**os.environ, 'BUDGET_RECORD': str(record), 'DISPLAY': ':fixture'}
            command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake),
                       '--mode', 'all', '--jobs', '1', '--display-driver', 'x11',
                       '--audio-driver', 'Dummy', '--import-gate', 'never', '--timeout', '300',
                       '--results-dir', str(root / 'results'), '--manifest-scope', 'tests']
            for override, expected_headless in (([], '300'), (['--headless-timeout', '1200'], '1200')):
                with self.subTest(override=override):
                    record.unlink(missing_ok=True)
                    run_id = 'override' if override else 'default'
                    result = subprocess.run(command + override, cwd=root,
                                            env={**environment, 'TEST_MATRIX_RUN_ID': run_id},
                                            text=True, capture_output=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    budgets = dict(line.split('\t') for line in record.read_text().splitlines())
                    self.assertEqual(budgets, {
                        'res://tests/headless_test.gd': expected_headless,
                        'res://tests/headless_long_test.gd': '1500',
                        'res://tests/graphical_test.gd': '300',
                        'res://tests/graphical_long_test.gd': '900',
                    })
                    manifest = (root / 'results' / run_id / 'run-manifest.txt').read_text()
                    self.assertIn('scope_specs=all\n', manifest)
                    self.assertIn('mode_excluded_suite_count=0\n', manifest)
                    self.assertIn(f'headless_timeout_seconds={expected_headless}\n', manifest)
            for invalid in ('0', '-1', 'bogus'):
                with self.subTest(invalid=invalid):
                    result = subprocess.run(command + ['--headless-timeout', invalid], cwd=root,
                                            env=environment, text=True, capture_output=True, timeout=20)
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn('Invalid --headless-timeout', result.stdout)

    def test_failed_suite_and_matrix_cancel_reap_detached_peers_before_return(self):
        from test_suite_process import FIXTURE
        for mode in ('0', 'wait'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                release = root / 'tools/release'
                release.mkdir(parents=True)
                for name in ('run_test_matrix.sh', 'test_suite_catalog.py', 'source_manifest.py', 'suite_process.py'):
                    shutil.copy2(SUPPORT / name, release / name)
                (root / 'tests').mkdir()
                (root / 'tests/probe_test.gd').write_text('print("PROBE_TEST_OK")')
                fixture = root / 'fixture.py'
                fixture.write_text(FIXTURE)
                fake = root / 'fake-godot'
                fake.write_text('#!/usr/bin/env python3\nimport os,sys\n'
                                f'os.execv(sys.executable, [sys.executable, {str(fixture)!r}, '
                                f'{str(root)!r}, "root", {mode!r}])\n')
                fake.chmod(0o755)
                command = ['bash', str(release / 'run_test_matrix.sh'), '--godot', str(fake),
                           '--jobs', '1', '--results-dir', str(root / 'results'),
                           '--manifest-scope', 'tests', '--import-gate', 'never']
                process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, text=True)
                try:
                    if mode == 'wait':
                        deadline = time.monotonic() + 10
                        while not (root / 'leaf.pid').exists() and time.monotonic() < deadline:
                            time.sleep(.01)
                        self.assertTrue((root / 'leaf.pid').exists(), 'detached peer starts')
                        process.send_signal(signal.SIGTERM)
                    stdout, stderr = process.communicate(timeout=15)
                    self.assertEqual(process.returncode, 130 if mode == 'wait' else 1, stdout + stderr)
                    if mode == '0':
                        self.assertIn('owned child processes running', stdout)
                    for role in ('root', 'middle', 'leaf'):
                        pid = int((root / (role + '.pid')).read_text())
                        with self.assertRaises(ProcessLookupError, msg=role):
                            os.kill(pid, 0)
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.communicate(timeout=15)

    def test_live_roster_covers_nested_suites_and_rendering(self):
        root = SUPPORT.resolve().parents[1]
        paths = catalog.suites(root)
        self.assertGreaterEqual(sum(len(p.relative_to(root / 'tests').parts) > 1 for p in paths), 272)
        self.assertEqual(catalog.mode(root / 'tests/ui/cinder_navigator_ping_hud_render_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/aft_junction_stair_handoff_visual_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/cinder_cargo_hauler_freight_frame_visual_test.gd'), 'graphical')
        self.assertEqual(catalog.mode(root / 'tests/network/network_enet_keepalive_test.gd'), 'headless')
        self.assertEqual(catalog.mode(root / 'tests/bulwark_crew_gunner_gameplay_test.gd'), 'graphical')


if __name__ == '__main__':
    unittest.main()
