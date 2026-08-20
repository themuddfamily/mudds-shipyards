import unittest

from tools.package.source_hash_manifest_digest_completeness_v17 import validate_v17


def manifest():
    commit = "b" * 40
    return {
        "schema_version": 17,
        "build_label": "digest-complete-v17-42",
        "source_commit": commit,
        "manifest_id": "manifest-42",
        "manifest_digest": "a" * 64,
        "entries": [{"entry_id": "entry-1", "source_commit": commit, "manifest_id": "manifest-42", "digest": "c" * 64}],
        "completeness_audit": {"status": "PASS", "evidence": "completeness report", "manifest_id": "manifest-42", "entry_count": 1, "complete_digest_count": 1, "all_digests_present": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashManifestDigestCompletenessV17Test(unittest.TestCase):
    def test_accepts_complete_digest_manifest(self):
        self.assertEqual(validate_v17(manifest()), [])

    def test_requires_schema_v17_and_complete_count(self):
        item = manifest()
        item["schema_version"] = 16
        item["completeness_audit"]["complete_digest_count"] = 0
        errors = validate_v17(item)
        self.assertTrue(any("schema_version must be 17" in error for error in errors))
        self.assertTrue(any("complete_digest_count must equal" in error for error in errors))

    def test_rejects_duplicate_entry_or_missing_digest(self):
        item = manifest()
        item["entries"].append(dict(item["entries"][0]))
        item["entries"][1]["digest"] = "bad"
        errors = validate_v17(item)
        self.assertTrue(any("entry_id must be unique" in error for error in errors))
        self.assertTrue(any("digest must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = manifest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v17(item)))


if __name__ == "__main__":
    unittest.main()
