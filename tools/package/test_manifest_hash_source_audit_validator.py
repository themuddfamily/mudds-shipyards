import unittest

from tools.package.manifest_hash_source_audit_validator import validate_audit


def audit():
    commit = "a" * 40
    digest = "b" * 64
    return {
        "schema_version": 1,
        "build_label": "manifest-audit-42",
        "source_commit": commit,
        "manifest_sha256": digest,
        "source": {"status": "PASS", "evidence": "source ledger", "commit": commit, "manifest_sha256": digest},
        "manifest_digest": {"status": "PASS", "evidence": "digest record", "computed_sha256": digest},
        "audit": {"status": "PASS", "evidence": "audit report", "source_match": True, "hash_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestHashSourceAuditValidatorTest(unittest.TestCase):
    def test_accepts_matching_manifest_hash_source_audit(self):
        self.assertEqual(validate_audit(audit()), [])

    def test_rejects_source_commit_or_manifest_hash_drift(self):
        item = audit()
        item["source"]["commit"] = "c" * 40
        item["manifest_digest"]["computed_sha256"] = "c" * 64
        errors = validate_audit(item)
        self.assertTrue(any("source.commit must match" in error for error in errors))
        self.assertTrue(any("computed_sha256 must match" in error for error in errors))

    def test_passed_audit_requires_both_match_flags(self):
        item = audit()
        item["audit"]["hash_match"] = False
        self.assertTrue(any("hash_match must be true" in error for error in validate_audit(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_audit(item)))


if __name__ == "__main__":
    unittest.main()
