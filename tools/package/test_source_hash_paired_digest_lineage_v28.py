import unittest

from tools.package.source_hash_paired_digest_lineage_v28 import validate_v28


def lineage():
    commit = "b" * 40
    source_digest = "a" * 64
    artifact_digest = "c" * 64
    return {
        "schema_version": 28,
        "build_label": "lineage-v28-42",
        "source_commit": commit,
        "source_digest": source_digest,
        "artifact_digest": artifact_digest,
        "lineage_id": "lineage-42",
        "lineage": {"status": "PASS", "evidence": "lineage report", "lineage_id": "lineage-42", "source_commit": commit, "source_digest": source_digest, "artifact_digest": artifact_digest, "parent": "source-manifest"},
        "pair": {"status": "PASS", "evidence": "pair report", "lineage_id": "lineage-42", "source_digest": source_digest, "artifact_digest": artifact_digest, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashPairedDigestLineageV28Test(unittest.TestCase):
    def test_accepts_paired_digest_lineage(self):
        self.assertEqual(validate_v28(lineage()), [])

    def test_requires_schema_v28_and_lineage_parent(self):
        item = lineage()
        item["schema_version"] = 27
        item["lineage"]["parent"] = None
        errors = validate_v28(item)
        self.assertTrue(any("schema_version must be 28" in error for error in errors))
        self.assertTrue(any("parent is required" in error for error in errors))

    def test_rejects_pair_or_digest_drift(self):
        item = lineage()
        item["pair"]["artifact_digest"] = "d" * 64
        item["lineage"]["lineage_id"] = "other"
        errors = validate_v28(item)
        self.assertTrue(any("pair digests must match" in error for error in errors))
        self.assertTrue(any("lineage.lineage_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = lineage()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v28(item)))


if __name__ == "__main__":
    unittest.main()
