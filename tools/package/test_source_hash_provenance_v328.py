import unittest

from tools.package.source_hash_provenance_v328 import validate_v328

def record() -> dict:
    binding = {"source_id": "source-328", "source_commit": "b" * 40, "source_hash": "c" * 64,
               "package_version": "32.8.0", "source_artifact_hash_count": 2,
               "package_artifact_hash_count": 3, "authorization_attestation_id": "authorization-attestation-328",
               "authorization_attestation_digest": "d" * 64, "authorization_attestation_entry_count": 4}
    not_run = {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None,
               "reviewer": None, "evidence_path": None}
    return {"schema_version": 328, "build_label": "source-provenance-v328", **binding,
            "source": {"status": "PASS", "evidence": "source", **binding, "identified": True},
            "authorization_attestation": {"status": "PASS", "evidence": "attestation",
                "authorization_attestation_id": "authorization-attestation-328",
                "authorization_attestation_digest": "d" * 64, "source_hash": "c" * 64,
                "package_artifact_hash_count": 3, "authorization_attestation_entry_count": 4,
                "authorized": True}, "native_execution": dict(not_run),
            "hardware_execution": dict(not_run), "human_review": dict(not_run)}

class SourceHashProvenanceV328Test(unittest.TestCase):
    def test_accepts_attestation_binding_and_not_run_gates(self):
        self.assertEqual(validate_v328(record()), [])
    def test_requires_matching_attestation_digest_and_count(self):
        item = record()
        item["authorization_attestation"]["authorization_attestation_digest"] = "e" * 64
        item["authorization_attestation"]["authorization_attestation_entry_count"] = 5
        errors = validate_v328(item)
        self.assertTrue(any("authorization_attestation.authorization_attestation_digest must match" in error for error in errors))
        self.assertTrue(any("authorization_attestation.authorization_attestation_entry_count must match" in error for error in errors))
    def test_rejects_schema_or_authorized_flag(self):
        item = record()
        item["schema_version"] = 327
        item["authorization_attestation"]["authorized"] = False
        errors = validate_v328(item)
        self.assertTrue(any("schema_version must be 328" in error for error in errors))
        self.assertTrue(any("authorization_attestation.authorized must be true" in error for error in errors))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        item["human_review"]["reviewer"] = "alice"
        errors = validate_v328(item)
        self.assertTrue(any("native_execution.platform must be null" in error for error in errors))
        self.assertTrue(any("human_review.reviewer must be null" in error for error in errors))

if __name__ == "__main__":
    unittest.main()
