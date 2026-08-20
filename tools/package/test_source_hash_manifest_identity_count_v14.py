import unittest

from tools.package.source_hash_manifest_identity_count_v14 import validate_v14


def identity():
    commit = "b" * 40
    return {
        "schema_version": 14,
        "build_label": "identity-count-v14-42",
        "source_commit": commit,
        "manifest_id": "manifest-42",
        "root_digest": "a" * 64,
        "identity": {"status": "PASS", "evidence": "identity record", "manifest_id": "manifest-42", "source_commit": commit, "root_digest": "a" * 64},
        "entries": [{"entry_id": "entry-1", "manifest_id": "manifest-42", "source_commit": commit, "digest": "c" * 64}],
        "count_audit": {"status": "PASS", "evidence": "count audit", "manifest_id": "manifest-42", "declared_count": 1, "unique_entries": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashManifestIdentityCountV14Test(unittest.TestCase):
    def test_accepts_identity_and_count(self):
        self.assertEqual(validate_v14(identity()), [])

    def test_requires_schema_v14_and_matching_count(self):
        item = identity()
        item["schema_version"] = 13
        item["count_audit"]["declared_count"] = 2
        errors = validate_v14(item)
        self.assertTrue(any("schema_version must be 14" in error for error in errors))
        self.assertTrue(any("declared_count must equal" in error for error in errors))

    def test_rejects_duplicate_entry_or_digest_drift(self):
        item = identity()
        item["entries"].append(dict(item["entries"][0]))
        item["entries"][1]["digest"] = "bad"
        errors = validate_v14(item)
        self.assertTrue(any("entry_id must be unique" in error for error in errors))
        self.assertTrue(any("digest must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = identity()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v14(item)))


if __name__ == "__main__":
    unittest.main()
