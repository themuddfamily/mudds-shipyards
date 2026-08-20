import unittest

from tools.package.source_hash_paired_digest_reconciliation_v27 import validate_v27


def paired():
    commit = "b" * 40
    source_digest = "a" * 64
    artifact_digest = "c" * 64
    return {
        "schema_version": 27,
        "build_label": "paired-v27-42",
        "source_commit": commit,
        "source_digest": source_digest,
        "artifact_digest": artifact_digest,
        "pair_id": "pair-42",
        "source": {"status": "PASS", "evidence": "source record", "digest": source_digest, "commit": commit},
        "artifact": {"status": "PASS", "evidence": "artifact record", "digest": artifact_digest, "commit": commit},
        "pair": {"status": "PASS", "evidence": "pair report", "pair_id": "pair-42", "source_digest": source_digest, "artifact_digest": artifact_digest, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashPairedDigestReconciliationV27Test(unittest.TestCase):
    def test_accepts_paired_digest_reconciliation(self):
        self.assertEqual(validate_v27(paired()), [])

    def test_requires_schema_v27_and_matching_pair_digests(self):
        item = paired()
        item["schema_version"] = 26
        item["pair"]["artifact_digest"] = "d" * 64
        errors = validate_v27(item)
        self.assertTrue(any("schema_version must be 27" in error for error in errors))
        self.assertTrue(any("pair digests must match" in error for error in errors))

    def test_rejects_source_or_artifact_drift(self):
        item = paired()
        item["source"]["commit"] = "d" * 40
        item["artifact"]["digest"] = "d" * 64
        errors = validate_v27(item)
        self.assertTrue(any("source.commit must match" in error for error in errors))
        self.assertTrue(any("artifact.digest must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = paired()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v27(item)))


if __name__ == "__main__":
    unittest.main()
