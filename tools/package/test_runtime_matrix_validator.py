import hashlib
import tempfile
import unittest
from pathlib import Path

from tools.package.runtime_matrix_validator import CHECKPOINTS, validate_matrix


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class RuntimeMatrixValidatorTest(unittest.TestCase):
    def _record(self, root: Path) -> dict:
        artifact = root / "build.exe"
        source = root / "project.godot"
        artifact.write_bytes(b"artifact")
        source.write_bytes(b"source")
        return {"label": "linux-smoke", "source_commit": "abc", "artifact_path": "build.exe", "artifact_sha256": _sha(artifact), "source_hashes": {"project.godot": _sha(source)}, "startup_status": "PASS", "loop_checkpoints": {name: "PASS" for name in CHECKPOINTS}, "native_status": "NOT_RUN", "native_evidence": None, "execution_claims": []}

    def test_valid_record(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(validate_matrix({"schema_version": 1, "records": [self._record(root)]}, root), [])

    def test_rejects_execution_claim_and_missing_checkpoint(self):
        record = {"label": "x", "source_commit": "abc", "artifact_path": "x", "artifact_sha256": "0" * 64, "source_hashes": {"x": "0" * 64}, "startup_status": "PASS", "loop_checkpoints": {}, "native_status": "NOT_RUN", "native_evidence": None, "execution_claims": ["native-run"]}
        errors = validate_matrix({"schema_version": 1, "records": [record]})
        self.assertTrue(any("cold_boot" in error for error in errors))
        self.assertTrue(any("execution_claims" in error for error in errors))

    def test_rejects_duplicate_labels(self):
        record = {"label": "x", "source_commit": "abc", "artifact_path": "x", "artifact_sha256": "0" * 64, "source_hashes": {"x": "0" * 64}, "startup_status": "NOT_RUN", "loop_checkpoints": {name: "NOT_RUN" for name in CHECKPOINTS}, "native_status": "NOT_RUN", "native_evidence": None}
        errors = validate_matrix({"schema_version": 1, "records": [record, dict(record)]})
        self.assertTrue(any("unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
