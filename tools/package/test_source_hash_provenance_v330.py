import unittest
from tools.package.source_hash_provenance_v330 import validate_v330

def record() -> dict:
    b = {"source_id": "source-330", "source_commit": "b" * 40, "source_hash": "c" * 64, "package_version": "33.0.0", "source_artifact_hash_count": 2, "package_artifact_hash_count": 3, "authorization_attestation_id": "authorization-attestation-330", "authorization_attestation_digest": "d" * 64, "authorization_attestation_entry_count": 4}
    g = {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "reviewer": None, "evidence_path": None}
    return {"schema_version": 330, "build_label": "source-provenance-v330", **b, "source": {"status": "PASS", "evidence": "source", **b, "identified": True}, "authorization_attestation": {"status": "PASS", "evidence": "attestation", "authorization_attestation_id": "authorization-attestation-330", "authorization_attestation_digest": "d" * 64, "source_hash": "c" * 64, "package_artifact_hash_count": 3, "authorization_attestation_entry_count": 4, "authorized": True}, "native_execution": dict(g), "hardware_execution": dict(g), "human_review": dict(g)}

class SourceHashProvenanceV330Test(unittest.TestCase):
    def test_accepts_attestation_binding_and_not_run_gates(self): self.assertEqual(validate_v330(record()), [])
    def test_requires_matching_attestation_digest_and_count(self):
        item = record(); item["authorization_attestation"]["authorization_attestation_digest"] = "e" * 64; item["authorization_attestation"]["authorization_attestation_entry_count"] = 5; errors = validate_v330(item)
        self.assertTrue(any("authorization_attestation.authorization_attestation_digest must match" in x for x in errors)); self.assertTrue(any("authorization_attestation.authorization_attestation_entry_count must match" in x for x in errors))
    def test_rejects_schema_or_authorized_flag(self):
        item = record(); item["schema_version"] = 329; item["authorization_attestation"]["authorized"] = False; errors = validate_v330(item)
        self.assertTrue(any("schema_version must be 330" in x for x in errors)); self.assertTrue(any("authorization_attestation.authorized must be true" in x for x in errors))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        item = record(); item["native_execution"]["platform"] = "Windows"; item["human_review"]["reviewer"] = "alice"; errors = validate_v330(item)
        self.assertTrue(any("native_execution.platform must be null" in x for x in errors)); self.assertTrue(any("human_review.reviewer must be null" in x for x in errors))

if __name__ == "__main__": unittest.main()
