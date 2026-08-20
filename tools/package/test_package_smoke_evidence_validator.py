import hashlib
import tempfile
import unittest
from pathlib import Path

from tools.package.package_smoke_evidence_validator import validate_evidence


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class PackageSmokeEvidenceValidatorTest(unittest.TestCase):
    def test_valid_record_checks_artifact_and_source_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / "build.exe"
            source = root / "project.godot"
            artifact.write_bytes(b"package")
            source.write_bytes(b"source")
            record = {"schema_version": 1, "build_label": "candidate-01", "source_commit": "abc123", "godot_version": "4.5", "artifact_path": "build.exe", "artifact_sha256": _sha(artifact), "source_hashes": {"project.godot": _sha(source)}, "startup_status": "PASS", "loop_checkpoints": {key: "PASS" for key in ("cold_boot", "begin", "traverse", "launch", "land", "reenter")}, "native_status": "NOT_RUN", "native_evidence": None}
            self.assertEqual(validate_evidence(record, root), [])

    def test_missing_checkpoint_and_native_claim_are_rejected(self):
        record = {"schema_version": 1, "build_label": "x", "source_commit": "x", "godot_version": "x", "artifact_path": "x", "artifact_sha256": "0" * 64, "source_hashes": {"x": "0" * 64}, "startup_status": "PASS", "loop_checkpoints": {}, "native_status": "NOT_RUN", "native_evidence": "claimed"}
        errors = validate_evidence(record)
        self.assertTrue(any("cold_boot" in error for error in errors))
        self.assertIn("native_evidence must be null", " ".join(errors))

    def test_hash_mismatch_is_reported_when_files_are_available(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "build.exe").write_bytes(b"actual")
            record = {"schema_version": 1, "build_label": "x", "source_commit": "x", "godot_version": "x", "artifact_path": "build.exe", "artifact_sha256": "0" * 64, "source_hashes": {"virtual/source": "0" * 64}, "startup_status": "PASS", "loop_checkpoints": {key: "PASS" for key in ("cold_boot", "begin", "traverse", "launch", "land", "reenter")}, "native_status": "FAIL", "native_evidence": "native log"}
            self.assertIn("does not match artifact_path", " ".join(validate_evidence(record, root)))


if __name__ == "__main__":
    unittest.main()
