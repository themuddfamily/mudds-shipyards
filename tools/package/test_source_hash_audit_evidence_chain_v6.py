import unittest

from tools.package.source_hash_audit_evidence_chain_v6 import validate_v6


def chain():
    digest = "a" * 64
    return {
        "schema_version": 6,
        "build_label": "chain-v6-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "chain_id": "chain-42",
        "source_binding": {"status": "PASS", "evidence": "binding record", "commit": "b" * 40, "deterministic": True},
        "reproducibility": {"status": "PASS", "evidence": "reproduction record", "reproduced_digest": digest, "reproduced": True},
        "audit": {"status": "PASS", "evidence": "chain audit", "chain_id": "chain-42", "source_hash_bound": True},
        "review": {"status": "PASS", "evidence": "review ledger", "audit_id": "chain-42", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditEvidenceChainV6Test(unittest.TestCase):
    def test_accepts_complete_v6_chain(self):
        self.assertEqual(validate_v6(chain()), [])

    def test_requires_schema_v6_and_deterministic_source_binding(self):
        item = chain()
        item["schema_version"] = 5
        item["source_binding"]["deterministic"] = False
        errors = validate_v6(item)
        self.assertTrue(any("schema_version must be 6" in error for error in errors))
        self.assertTrue(any("deterministic must be true" in error for error in errors))

    def test_rejects_reproduction_or_audit_id_drift(self):
        item = chain()
        item["reproducibility"]["reproduced_digest"] = "c" * 64
        item["review"]["audit_id"] = "other"
        errors = validate_v6(item)
        self.assertTrue(any("reproduced_digest must match" in error for error in errors))
        self.assertTrue(any("review.audit_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = chain()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v6(item)))


if __name__ == "__main__":
    unittest.main()
