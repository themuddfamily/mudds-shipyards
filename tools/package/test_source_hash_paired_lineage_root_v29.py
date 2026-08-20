import unittest

from tools.package.source_hash_paired_lineage_root_v29 import validate_v29


def root():
    commit = "b" * 40
    source = "a" * 64
    artifact = "c" * 64
    root_digest = "d" * 64
    return {
        "schema_version": 29,
        "build_label": "root-v29-42",
        "source_commit": commit,
        "source_digest": source,
        "artifact_digest": artifact,
        "root_id": "root-42",
        "root_digest": root_digest,
        "root": {"status": "PASS", "evidence": "root record", "root_id": "root-42", "source_commit": commit, "digest": root_digest},
        "pair": {"status": "PASS", "evidence": "pair record", "source_digest": source, "artifact_digest": artifact, "root_id": "root-42", "root_digest": root_digest, "rooted": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "root_id": "root-42", "root_digest": root_digest, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashPairedLineageRootV29Test(unittest.TestCase):
    def test_accepts_paired_lineage_root(self):
        self.assertEqual(validate_v29(root()), [])

    def test_requires_schema_v29_and_matching_root_digest(self):
        item = root()
        item["schema_version"] = 28
        item["pair"]["root_digest"] = "e" * 64
        errors = validate_v29(item)
        self.assertTrue(any("schema_version must be 29" in error for error in errors))
        self.assertTrue(any("pair root identity must match" in error for error in errors))

    def test_rejects_pair_or_root_drift(self):
        item = root()
        item["root"]["source_commit"] = "e" * 40
        item["reconciliation"]["root_id"] = "other"
        errors = validate_v29(item)
        self.assertTrue(any("root.source_commit must match" in error for error in errors))
        self.assertTrue(any("reconciliation.root_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = root()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v29(item)))


if __name__ == "__main__":
    unittest.main()
