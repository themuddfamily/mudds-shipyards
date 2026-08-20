import unittest

from tools.package.source_hash_manifest_identity_v13 import validate_v13


def identity():
    commit = "b" * 40
    return {
        "schema_version": 13,
        "build_label": "identity-v13-42",
        "source_commit": commit,
        "manifest_id": "manifest-42",
        "root_digest": "a" * 64,
        "identity": {"status": "PASS", "evidence": "identity record", "manifest_id": "manifest-42", "source_commit": commit, "root_digest": "a" * 64, "stable": True},
        "entries": [{"entry_id": "entry-1", "manifest_id": "manifest-42", "source_commit": commit, "digest": "c" * 64}],
        "audit": {"status": "PASS", "evidence": "identity audit", "entry_count": 1, "identity_matches": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashManifestIdentityV13Test(unittest.TestCase):
    def test_accepts_stable_manifest_identity(self):
        self.assertEqual(validate_v13(identity()), [])

    def test_requires_schema_v13_and_stable_identity(self):
        item = identity()
        item["schema_version"] = 12
        item["identity"]["stable"] = False
        errors = validate_v13(item)
        self.assertTrue(any("schema_version must be 13" in error for error in errors))
        self.assertTrue(any("stable must be true" in error for error in errors))

    def test_rejects_duplicate_entry_or_source_drift(self):
        item = identity()
        item["entries"].append(dict(item["entries"][0]))
        item["entries"][1]["source_commit"] = "d" * 40
        errors = validate_v13(item)
        self.assertTrue(any("entry_id must be unique" in error for error in errors))
        self.assertTrue(any("source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = identity()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v13(item)))


if __name__ == "__main__":
    unittest.main()
