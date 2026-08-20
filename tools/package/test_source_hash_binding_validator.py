import unittest

from tools.package.source_hash_binding_validator import validate_binding


def binding():
    commit = "a" * 40
    digest = "b" * 64
    record = lambda evidence: {"status": "PASS", "evidence": evidence, "source_commit": commit, "artifact_sha256": digest}
    return {
        "schema_version": 1,
        "build_label": "binding-42",
        "source_commit": commit,
        "artifact_path": "build/game.exe",
        "artifact_sha256": digest,
        "build_record": record("build record"),
        "manifest_record": record("manifest record"),
        "binding_audit": {"status": "PASS", "evidence": "identity audit", "commit_match": True, "hash_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashBindingValidatorTest(unittest.TestCase):
    def test_accepts_matching_commit_and_hash_records(self):
        self.assertEqual(validate_binding(binding()), [])

    def test_rejects_build_commit_drift(self):
        item = binding()
        item["build_record"]["source_commit"] = "c" * 40
        self.assertTrue(any("build_record.source_commit must match" in error for error in validate_binding(item)))

    def test_rejects_manifest_hash_drift(self):
        item = binding()
        item["manifest_record"]["artifact_sha256"] = "c" * 64
        self.assertTrue(any("manifest_record.artifact_sha256 must match" in error for error in validate_binding(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = binding()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_binding(item)))


if __name__ == "__main__":
    unittest.main()
