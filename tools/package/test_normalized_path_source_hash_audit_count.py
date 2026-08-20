import unittest

from tools.package.normalized_path_source_hash_audit_count import validate_counts


def counts():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "audit-count-42",
        "source_commit": commit,
        "entries": [{"normalized_path": "game.exe", "source_commit": commit, "sha256": "b" * 64}, {"normalized_path": "game.pck", "source_commit": commit, "sha256": "c" * 64}],
        "path_count": 2,
        "source_count": 2,
        "hash_count": 2,
        "audit": {"status": "PASS", "evidence": "count report", "counts_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class NormalizedPathSourceHashAuditCountTest(unittest.TestCase):
    def test_accepts_matching_audit_counts(self):
        self.assertEqual(validate_counts(counts()), [])

    def test_rejects_hash_count_drift(self):
        item = counts()
        item["hash_count"] = 1
        self.assertTrue(any("hash_count must equal" in error for error in validate_counts(item)))

    def test_rejects_source_or_path_drift(self):
        item = counts()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][1]["normalized_path"] = "game.exe"
        errors = validate_counts(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("normalized_path must be unique" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = counts()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_counts(item)))


if __name__ == "__main__":
    unittest.main()
