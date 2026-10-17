"""Real process checks for suite teardown across detached sessions."""
import fcntl
import json
import os
from pathlib import Path
import signal
import select
import subprocess
import sys
import tempfile
import time
import unittest


SUPERVISOR = Path(__file__).with_name("suite_process.py")
FIXTURE = r'''
import os, pathlib, signal, subprocess, sys, time
root = pathlib.Path(sys.argv[1])
role = sys.argv[2]
if role in ('middle', 'leaf'):
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
(root / (role + '.pid')).write_text(str(os.getpid()))
if role != 'leaf':
    next_role = 'middle' if role == 'root' else 'leaf'
    subprocess.Popen([sys.executable, __file__, str(root), next_role], start_new_session=True)
if role == 'root':
    while not (root / 'leaf.pid').exists():
        time.sleep(.01)
    if sys.argv[3] != 'wait':
        print('PROBE_TEST_OK', flush=True)
        sys.exit(int(sys.argv[3]))
while True:
    time.sleep(60)
'''


@unittest.skipUnless(sys.platform == "linux", "Linux child subreaper contract")
class SuiteProcessTests(unittest.TestCase):
    def command(self, root, mode, timeout=5):
        script = root / 'fixture.py'
        script.write_text(FIXTURE)
        return [sys.executable, str(SUPERVISOR), '--timeout', str(timeout), '--',
                sys.executable, str(script), str(root), 'root', mode]

    def assert_reaped(self, root):
        for role in ('root', 'middle', 'leaf'):
            pid = int((root / (role + '.pid')).read_text())
            with self.subTest(role=role, pid=pid):
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)

    def detached(self, root, command, timeout=5, **kwargs):
        return subprocess.run([sys.executable, str(SUPERVISOR), '--timeout', str(timeout),
                               '--detach', '--log', str(root / 'output.log'),
                               '--status', str(root / 'status.json'), '--', *command],
                              capture_output=True, text=True, timeout=5, **kwargs)

    def wait_status(self, root, state):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            path = root / 'status.json'
            if path.exists() and path.stat().st_size:
                status = json.loads(path.read_text())
                if status['state'] == state:
                    return status
            time.sleep(.01)
        self.fail(f'suite did not reach {state}')

    def stop_owner(self, root):
        # Test cleanup also checks identity before signaling: a completed owner's
        # PID can have been recycled after its terminal status was published.
        path = root / 'status.json'
        if not path.exists() or not path.stat().st_size:
            return
        status = json.loads(path.read_text())
        if status['state'] in ('FINISHED', 'ERROR'):
            return
        try:
            ticks = int(Path(f"/proc/{status['owner_pid']}/stat").read_text().rsplit(')', 1)[1].split()[19])
            if ticks == status['owner_start_ticks']:
                os.kill(status['owner_pid'], signal.SIGTERM)
                self.wait_status(root, 'FINISHED')
        except FileNotFoundError:
            pass

    def test_detached_owner_survives_launch_session_hangup_and_captures_later_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command = [sys.executable, '-c', """
import pathlib, sys, time
print('before launcher exit', flush=True)
root = pathlib.Path(sys.argv[1])
while not (root / 'continue').exists():
    time.sleep(.01)
print('after launcher exit', flush=True)
print('captured stderr', file=sys.stderr, flush=True)
sys.exit(7)
""", str(root)]
            # Keep the original launching session alive after the CLI exits,
            # then hang up that entire session while the detached job waits.
            launcher_code = ('import subprocess,sys,time; '
                             'result=subprocess.run(sys.argv[1:],capture_output=True,text=True); '
                             'print(result.stdout, end="", flush=True); '
                             'sys.stderr.write(result.stderr); '
                             'time.sleep(60)')
            launcher = subprocess.Popen([sys.executable, '-c', launcher_code,
                                         sys.executable, str(SUPERVISOR), '--timeout', '5',
                                         '--detach', '--log', str(root / 'output.log'),
                                         '--status', str(root / 'status.json'), '--', *command],
                                        start_new_session=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, text=True)
            try:
                self.assertTrue(select.select([launcher.stdout], [], [], 5)[0], 'launcher reported readiness')
                identity = json.loads(launcher.stdout.readline())
                self.assertEqual(identity['state'], 'RUNNING')
                self.assertNotIn('exit_code', identity)
                owner_pid = identity['owner_pid']
                self.assertEqual(os.getsid(owner_pid), owner_pid)
                ticks = int(Path(f'/proc/{owner_pid}/stat').read_text().rsplit(')', 1)[1].split()[19])
                self.assertEqual(identity['owner_start_ticks'], ticks)
                os.killpg(launcher.pid, signal.SIGHUP)
                _stdout, stderr = launcher.communicate(timeout=5)
                self.assertEqual(launcher.returncode, -signal.SIGHUP, stderr)
                self.assertEqual(self.wait_status(root, 'RUNNING')['owner_pid'], owner_pid)
                (root / 'continue').touch()
                status = self.wait_status(root, 'FINISHED')
                self.assertEqual(status['exit_code'], 7, status)
                self.assertEqual(status['owner_pid'], owner_pid)
                output = (root / 'output.log').read_text()
                self.assertIn('before launcher exit', output)
                self.assertIn('after launcher exit', output)
                self.assertIn('captured stderr', output)
            finally:
                if launcher.poll() is None:
                    os.killpg(launcher.pid, signal.SIGTERM)
                    launcher.communicate(timeout=5)
                self.stop_owner(root)

    def test_detached_timeout_reaps_descendants_and_holds_inherited_lock_until_finished(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command = self.command(root, 'wait')[5:]
            launcher_code = """
import fcntl, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
for fd in (8, 9):
    lane = (root / f'lane{fd}.lock').open('w')
    fcntl.flock(lane, fcntl.LOCK_EX | fcntl.LOCK_NB)
    os.dup2(lane.fileno(), fd)
    os.set_inheritable(fd, True)
os.execv(sys.executable, sys.argv[2:])
"""
            result = subprocess.run([sys.executable, '-c', launcher_code, str(root),
                                     sys.executable, str(SUPERVISOR), '--timeout', '.8',
                                     '--detach', '--log', str(root / 'output.log'),
                                     '--status', str(root / 'status.json'), '--', *command],
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            try:
                with (root / 'lane8.lock').open('w') as probe, (root / 'lane9.lock').open('w') as probe9:
                    with self.assertRaises(BlockingIOError):
                        fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    with self.assertRaises(BlockingIOError):
                        fcntl.flock(probe9, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    running = self.wait_status(root, 'RUNNING')
                    self.assertNotIn('exit_code', running)
                    deadline = time.monotonic() + 5
                    while not (root / 'leaf.pid').exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertTrue((root / 'leaf.pid').exists())
                    root_pid = int((root / 'root.pid').read_text())
                    for pid in (running['owner_pid'], root_pid):
                        for fd in (8, 9):
                            self.assertEqual(Path(f'/proc/{pid}/fd/{fd}').resolve(), root / f'lane{fd}.lock')
                    # After timeout the root exits on TERM, while its peers
                    # resist TERM until KILL. Both lanes must remain held during
                    # that cleanup interval, not just during the suite itself.
                    deadline = time.monotonic() + 3
                    while Path(f'/proc/{root_pid}').exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertFalse(Path(f'/proc/{root_pid}').exists())
                    self.assertEqual(json.loads((root / 'status.json').read_text())['state'], 'RUNNING')
                    for lane in (probe, probe9):
                        with self.assertRaises(BlockingIOError):
                            fcntl.flock(lane, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    status = self.wait_status(root, 'FINISHED')
                    self.assertEqual(status['exit_code'], 124, status)
                    self.assertIn('exceeded timeout', (root / 'output.log').read_text())
                    self.assert_reaped(root)
                    # FINISHED precedes the owner's final _exit by a few
                    # instructions; the kernel releases its lock on that exit.
                    deadline = time.monotonic() + 2
                    while True:
                        try:
                            fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
                            fcntl.flock(probe9, fcntl.LOCK_EX | fcntl.LOCK_NB)
                            break
                        except BlockingIOError:
                            if time.monotonic() >= deadline:
                                self.fail('detached owner retained lane after completion')
                            time.sleep(.01)
            finally:
                self.stop_owner(root)

    def test_detached_paths_and_options_reject_ambiguous_or_existing_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            marker = root / 'executed'
            command = [sys.executable, '-c', f'from pathlib import Path; Path({str(marker)!r}).touch()']
            base = [sys.executable, str(SUPERVISOR), '--timeout', '5']
            for options in [ ['--detach'], ['--log', str(root / 'output.log')],
                             ['--detach', '--log', str(root / 'output.log')],
                             ['--detach', '--status', str(root / 'status.json')],
                             ['--log', str(root / 'output.log'), '--status', str(root / 'status.json')],
                             ['--detach', '--log', str(root / 'same'), '--status', str(root / 'same')]]:
                with self.subTest(options=options):
                    result = subprocess.run([*base, *options, '--', *command],
                                            capture_output=True, text=True, timeout=5)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(marker.exists())
            for existing in ['output.log', 'status.json']:
                for symlink in (False, True):
                    with self.subTest(existing=existing, symlink=symlink):
                        path = root / existing
                        target = root / 'absent-target'
                        if symlink:
                            path.symlink_to(target)
                        else:
                            path.write_text('prior launch artifact')
                        result = self.detached(root, command)
                        self.assertNotEqual(result.returncode, 0)
                        if symlink:
                            self.assertTrue(path.is_symlink())
                            self.assertFalse(target.exists())
                        else:
                            self.assertEqual(path.read_text(), 'prior launch artifact')
                        self.assertFalse(marker.exists())
                        self.assertFalse((root / ('status.json' if existing == 'output.log' else 'output.log')).exists())
                        path.unlink()

    def test_detached_cancel_checks_identity_and_reaps_only_owned_processes(self):
        sibling = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'],
                                   start_new_session=True)
        try:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                result = self.detached(root, self.command(root, 'wait')[5:])
                self.assertEqual(result.returncode, 0, result.stderr)
                try:
                    deadline = time.monotonic() + 5
                    while not (root / 'leaf.pid').exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertTrue((root / 'leaf.pid').exists())
                    identity = self.wait_status(root, 'RUNNING')
                    ticks = int(Path(f"/proc/{identity['owner_pid']}/stat").read_text().rsplit(')', 1)[1].split()[19])
                    self.assertEqual(ticks, identity['owner_start_ticks'])
                    os.kill(identity['owner_pid'], signal.SIGTERM)
                    status = self.wait_status(root, 'FINISHED')
                    self.assertEqual(status['exit_code'], 143, status)
                    self.assertIn('interrupted', (root / 'output.log').read_text())
                    self.assert_reaped(root)
                    self.assertIsNone(sibling.poll(), 'unrelated session remains running')
                finally:
                    self.stop_owner(root)
        finally:
            sibling.terminate()
            sibling.wait(timeout=5)

    def test_detached_supervisor_failure_reports_error_without_claiming_cleanup(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            launcher_code = """
import sys
sys.path.insert(0, sys.argv.pop(1))
import suite_process

def fail(command, timeout, *, _ready):
    _ready()
    raise RuntimeError('synthetic cleanup failure')

suite_process.run = fail
sys.exit(suite_process.main())
"""
            result = subprocess.run([sys.executable, '-c', launcher_code, str(SUPERVISOR.parent),
                                     '--timeout', '5', '--detach', '--log', str(root / 'output.log'),
                                     '--status', str(root / 'status.json'), '--', sys.executable, '-c', 'pass'],
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            status = self.wait_status(root, 'ERROR')
            self.assertEqual(status['exit_code'], 1)
            self.assertIn('synthetic cleanup failure', status['error'])
            self.assertIn('synthetic cleanup failure', (root / 'output.log').read_text())


    def test_clean_exit_and_signal_exit_preserve_status(self):
        for code, expected in [('raise SystemExit(7)', 7), ('print("clean")', 0),
                               ('import os,signal; os.kill(os.getpid(),signal.SIGTERM)', 143)]:
            with self.subTest(code=code):
                result = subprocess.run([sys.executable, str(SUPERVISOR), '--timeout', '5', '--',
                                         sys.executable, '-c', code], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertNotIn('ERROR:', result.stderr)

    def test_success_and_failure_reap_detached_term_resistant_descendants(self):
        for code, expected in [('0', 1), ('7', 7)]:
            with self.subTest(code=code), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                result = subprocess.run(self.command(root, code), capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertIn('PROBE_TEST_OK', result.stdout)
                self.assertIn('left owned child processes running', result.stderr)
                self.assert_reaped(root)

    def test_timeout_reaps_nested_detached_sessions(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            started = time.monotonic()
            result = subprocess.run(self.command(root, 'wait', timeout=0.5),
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 124, result.stderr)
            self.assertIn('exceeded timeout', result.stderr)
            self.assertLess(time.monotonic() - started, 6)
            self.assert_reaped(root)

    def test_external_cancel_reaps_only_owned_processes(self):
        sibling = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'],
                                   start_new_session=True)
        try:
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                supervisor = subprocess.Popen(self.command(root, 'wait'), stdout=subprocess.PIPE,
                                              stderr=subprocess.PIPE, text=True)
                try:
                    deadline = time.monotonic() + 5
                    while not (root / 'leaf.pid').exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    self.assertTrue((root / 'leaf.pid').exists(), 'fixture reached detached grandchild')
                    supervisor.send_signal(signal.SIGTERM)
                    _stdout, stderr = supervisor.communicate(timeout=10)
                    self.assertEqual(supervisor.returncode, 143, stderr)
                    self.assertIn('interrupted', stderr)
                    self.assert_reaped(root)
                    self.assertIsNone(sibling.poll(), 'unrelated session remains running')
                finally:
                    if supervisor.poll() is None:
                        supervisor.terminate()
                        supervisor.communicate(timeout=10)
        finally:
            sibling.terminate()
            sibling.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
