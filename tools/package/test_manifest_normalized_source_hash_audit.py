import unittest

from tools.package.manifest_normalized_source_hash_audit import validate_audit


def audit():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "source-hash-audit-42",
        "source_commit": commit,
        "manifest_digest": "b" * 64,
        "entries": [{"normalized_path": "game.exe", "source_commit": commit, "sha256": "c" * 64}],
        "declared_count": 1,
        "audit_check": {"status": "PASS", "evidence": "aggregate audit", "normalized": True, "source_bound": True, "hashes_complete": True, "counts_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestNormalizedSourceHashAuditTest(unittest.TestCase):
    def test_accepts_complete_aggregate_audit(self):
        self.assertEqual(validate_audit(audit()), [])

    def test_rejects_source_or_hash_drift(self):
        item = audit()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][0]["sha256"] = "bad"
        errors = validate_audit(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_passed_audit_requires_all_flags(self):
        item = audit()
        item["audit_check"]["counts_match"] = False
        self.assertTrue(any("counts_match must be true" in error for error in validate_audit(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_audit(item)))


if __name__ == "__main__":
    unittest.main()
