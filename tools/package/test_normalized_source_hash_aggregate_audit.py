import unittest

from tools.package.normalized_source_hash_aggregate_audit import validate_audit


def audit():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "aggregate-audit-42",
        "source_commit": commit,
        "audit_digest": "b" * 64,
        "entries": [{"normalized_path": "game.exe", "source_commit": commit, "sha256": "c" * 64}],
        "entry_count": 1,
        "source_bound_count": 1,
        "hashed_count": 1,
        "audit": {"status": "PASS", "evidence": "aggregate audit", "aggregate_complete": True, "counts_consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class NormalizedSourceHashAggregateAuditTest(unittest.TestCase):
    def test_accepts_complete_aggregate_audit(self):
        self.assertEqual(validate_audit(audit()), [])

    def test_rejects_count_drift(self):
        item = audit()
        item["hashed_count"] = 0
        self.assertTrue(any("hashed_count must equal" in error for error in validate_audit(item)))

    def test_rejects_source_or_hash_drift(self):
        item = audit()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][0]["sha256"] = "bad"
        errors = validate_audit(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_audit(item)))


if __name__ == "__main__":
    unittest.main()
