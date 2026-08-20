import unittest

from tools.package.source_hash_manifest_digest_count_v16 import validate_v16


def manifest():
    commit = "b" * 40
    return {
        "schema_version": 16,
        "build_label": "digest-count-v16-42",
        "source_commit": commit,
        "manifest_digest": "a" * 64,
        "manifest_id": "manifest-42",
        "entries": [{"entry_id": "entry-1", "source_commit": commit, "manifest_id": "manifest-42", "digest": "c" * 64}],
        "digest_count_audit": {"status": "PASS", "evidence": "digest count report", "manifest_id": "manifest-42", "declared_count": 1, "hashed_count": 1, "complete": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashManifestDigestCountV16Test(unittest.TestCase):
    def test_accepts_digest_count_manifest(self):
        self.assertEqual(validate_v16(manifest()), [])

    def test_requires_schema_v16_and_matching_counts(self):
        item = manifest()
        item["schema_version"] = 15
        item["digest_count_audit"]["hashed_count"] = 0
        errors = validate_v16(item)
        self.assertTrue(any("schema_version must be 16" in error for error in errors))
        self.assertTrue(any("hashed_count must equal" in error for error in errors))

    def test_rejects_duplicate_entry_or_source_drift(self):
        item = manifest()
        item["entries"].append(dict(item["entries"][0]))
        item["entries"][1]["source_commit"] = "d" * 40
        errors = validate_v16(item)
        self.assertTrue(any("entry_id must be unique" in error for error in errors))
        self.assertTrue(any("source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = manifest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v16(item)))


if __name__ == "__main__":
    unittest.main()
