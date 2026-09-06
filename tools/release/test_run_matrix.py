#!/usr/bin/env python3
"""Exercise the legacy release runner in disposable Git repositories."""
import csv
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

RUNNER = Path(__file__).with_name("run_matrix.sh")


class LegacyMatrixTest(unittest.TestCase):
    def run_fixture(self, command, timeout="5"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tools/release").mkdir(parents=True)
            shutil.copy2(RUNNER, root / "tools/release/run_matrix.sh")
            (root / "tests").mkdir()
            (root / "tests/probe_test.gd").write_text("original source\n")
            def git(*args):
                subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)
            git("init", "-q")
            git("config", "user.email", "fixture@example.invalid")
            git("config", "user.name", "Fixture")
            git("add", ".")
            git("commit", "-qm", "fixture")
            godot = root / "fake-godot"
            godot.write_text("#!/usr/bin/env bash\nset -eu\n" + command + "\n")
            godot.chmod(0o755)
            result = subprocess.run(
                ["bash", "tools/release/run_matrix.sh", "output", timeout, str(godot)],
                cwd=root, text=True, capture_output=True, timeout=15,
            )
            with (root / "output/matrix_summary.csv").open() as stream:
                rows = list(csv.DictReader(stream))
            report = json.loads((root / "output/matrix_results.json").read_text())
            return result, rows, report

    def test_actual_exit_status(self):
        for command, timeout, expected in [
            ("echo PROBE_TEST_OK; exit 0", "5", 0),
            ("echo PROBE_TEST_OK; exit 7", "5", 7),
            ("echo PROBE_TEST_OK; sleep 10", "0.1", 124),
            ("exit 7", "5", 7),
        ]:
            with self.subTest(expected=expected, command=command):
                result, rows, report = self.run_fixture(command, timeout)
                self.assertEqual(int(rows[0]["exit_code"]), expected)
                self.assertEqual(report["suite_failures"], int(expected != 0))
                self.assertEqual(result.returncode, int(expected != 0), result.stdout + result.stderr)
                self.assertEqual("MATRIX_OK" in result.stdout, expected == 0)


if __name__ == "__main__":
    unittest.main()
