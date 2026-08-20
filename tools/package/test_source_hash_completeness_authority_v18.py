import unittest

from tools.package.source_hash_completeness_authority_v18 import validate_v18


def authority():
    commit = "b" * 40
    return {
        "schema_version": 18,
        "build_label": "authority-v18-42",
        "source_commit": commit,
        "manifest_id": "manifest-42",
        "authority_digest": "a" * 64,
        "authority": {"status": "PASS", "evidence": "authority ledger", "owner": "release operator", "manifest_id": "manifest-42", "digest": "a" * 64},
        "entries": [{"source_commit": commit, "manifest_id": "manifest-42", "digest": "c" * 64}],
        "completeness": {"status": "PASS", "evidence": "completeness report", "entry_count": 1, "complete_digest_count": 1, "authority_matches": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashCompletenessAuthorityV18Test(unittest.TestCase):
    def test_accepts_complete_authority_digest(self):
        self.assertEqual(validate_v18(authority()), [])

    def test_requires_schema_v18_and_matching_authority(self):
        item = authority()
        item["schema_version"] = 17
        item["authority"]["digest"] = "d" * 64
        errors = validate_v18(item)
        self.assertTrue(any("schema_version must be 18" in error for error in errors))
        self.assertTrue(any("authority.digest must match" in error for error in errors))

    def test_rejects_entry_or_completeness_drift(self):
        item = authority()
        item["entries"][0]["source_commit"] = "d" * 40
        item["completeness"]["complete_digest_count"] = 0
        errors = validate_v18(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("complete_digest_count must equal" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = authority()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v18(item)))


if __name__ == "__main__":
    unittest.main()
