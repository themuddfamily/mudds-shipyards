import unittest

from tools.package.source_hash_manifest_count_digest_v15 import validate_v15


def manifest():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 15,
        "build_label": "count-digest-v15-42",
        "source_commit": commit,
        "manifest_id": "manifest-42",
        "manifest_digest": digest,
        "entries": [{"path": "game.exe", "source_commit": commit, "digest": "c" * 64}],
        "count_digest_audit": {"status": "PASS", "evidence": "count/digest report", "manifest_id": "manifest-42", "declared_count": 1, "computed_digest": digest, "counts_and_digest_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashManifestCountDigestV15Test(unittest.TestCase):
    def test_accepts_count_digest_manifest(self):
        self.assertEqual(validate_v15(manifest()), [])

    def test_requires_schema_v15_and_matching_count(self):
        item = manifest()
        item["schema_version"] = 14
        item["count_digest_audit"]["declared_count"] = 2
        errors = validate_v15(item)
        self.assertTrue(any("schema_version must be 15" in error for error in errors))
        self.assertTrue(any("declared_count must equal" in error for error in errors))

    def test_rejects_digest_or_path_drift(self):
        item = manifest()
        item["count_digest_audit"]["computed_digest"] = "d" * 64
        item["entries"][0]["path"] = ""
        errors = validate_v15(item)
        self.assertTrue(any("computed_digest must match" in error for error in errors))
        self.assertTrue(any("path is required" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = manifest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v15(item)))


if __name__ == "__main__":
    unittest.main()
