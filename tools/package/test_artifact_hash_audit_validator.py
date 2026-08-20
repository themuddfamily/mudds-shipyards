import unittest

from tools.package.artifact_hash_audit_validator import validate_hash_audit


def audit():
    return {
        "schema_version": 1,
        "build_label": "hash-audit-42",
        "source_commit": "a" * 40,
        "artifacts": [{"path": "build/game.exe", "sha256": "b" * 64, "kind": "executable"}, {"path": "build/game.pck", "sha256": "c" * 64, "kind": "embedded-pack"}],
        "audit": {"status": "PASS", "evidence": "hash inventory", "hashed_count": 2, "missing_hashes": 0},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ArtifactHashAuditValidatorTest(unittest.TestCase):
    def test_accepts_complete_hash_audit(self):
        self.assertEqual(validate_hash_audit(audit()), [])

    def test_requires_valid_hash_and_unique_path(self):
        item = audit()
        item["artifacts"][1]["path"] = "build/game.exe"
        item["artifacts"][0]["sha256"] = "bad"
        errors = validate_hash_audit(item)
        self.assertTrue(any("path must be unique" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_passed_audit_requires_matching_counts(self):
        item = audit()
        item["audit"]["hashed_count"] = 1
        item["audit"]["missing_hashes"] = 1
        errors = validate_hash_audit(item)
        self.assertTrue(any("hashed_count must equal" in error for error in errors))
        self.assertTrue(any("missing_hashes must be 0" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = audit()
        item["native_execution"]["hardware"] = "GPU"
        self.assertTrue(any("hardware must be null" in error for error in validate_hash_audit(item)))


if __name__ == "__main__":
    unittest.main()
