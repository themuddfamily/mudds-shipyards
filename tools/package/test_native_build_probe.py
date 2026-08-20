import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.package import native_build_probe


class NativeBuildProbeTest(unittest.TestCase):
    def test_present_artifact_records_hash_and_native_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "MuddsShipyards.exe"
            package.write_bytes(b"exported-package")
            report = native_build_probe.inspect_package(package)
        self.assertEqual(report["status"], "PRESENT")
        self.assertEqual(report["native_execution_status"], "NOT_RUN")
        self.assertEqual(report["package_size_bytes"], len(b"exported-package"))
        self.assertEqual(report["package_sha256"], hashlib.sha256(b"exported-package").hexdigest())
        self.assertTrue(report["native_execution_required"])

    def test_missing_artifact_fails_closed_without_hash(self):
        report = native_build_probe.inspect_package(Path(tempfile.gettempdir()) / "does-not-exist.exe")
        self.assertEqual(report["status"], "MISSING")
        self.assertEqual(report["native_execution_status"], "NOT_RUN")
        self.assertNotIn("package_sha256", report)

    def test_cli_writes_machine_readable_report(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "build.exe"
            output = Path(directory) / "evidence.json"
            package.write_bytes(b"x")
            self.assertEqual(native_build_probe.main(["--package", str(package), "--output", str(output)]), 0)
            self.assertEqual(json.loads(output.read_text()), native_build_probe.inspect_package(package))


if __name__ == "__main__":
    unittest.main()
