import unittest

from tools.package.source_hash_audit_chain_consistency_v7 import validate_v7


def chain():
    digest = "a" * 64
    return {
        "schema_version": 7,
        "build_label": "chain-v7-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "chain_id": "chain-42",
        "consistency_id": "consistency-42",
        "source_binding": {"status": "PASS", "evidence": "source binding", "commit": "b" * 40, "chain_id": "chain-42"},
        "digest_binding": {"status": "PASS", "evidence": "digest binding", "digest": digest, "reproducible": True},
        "consistency": {"status": "PASS", "evidence": "consistency report", "consistency_id": "consistency-42", "all_bindings_match": True},
        "review": {"status": "PASS", "evidence": "review ledger", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z", "consistency_id": "consistency-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditChainConsistencyV7Test(unittest.TestCase):
    def test_accepts_consistent_v7_chain(self):
        self.assertEqual(validate_v7(chain()), [])

    def test_requires_schema_v7_and_matching_chain_ids(self):
        item = chain()
        item["schema_version"] = 6
        item["source_binding"]["chain_id"] = "other"
        errors = validate_v7(item)
        self.assertTrue(any("schema_version must be 7" in error for error in errors))
        self.assertTrue(any("source_binding.chain_id must match" in error for error in errors))

    def test_rejects_digest_or_consistency_drift(self):
        item = chain()
        item["digest_binding"]["digest"] = "c" * 64
        item["review"]["consistency_id"] = "other"
        errors = validate_v7(item)
        self.assertTrue(any("digest_binding.digest must match" in error for error in errors))
        self.assertTrue(any("review.consistency_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = chain()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v7(item)))


if __name__ == "__main__":
    unittest.main()
