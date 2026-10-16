"""Real process checks for suite teardown across detached sessions."""
import os
from pathlib import Path
import signal
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
