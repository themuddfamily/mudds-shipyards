import unittest

from tools.package.source_hash_provenance_v283 import validate_v283


def record() -> dict:
    b = {"source_id": "source-283", "source_commit": "b" * 40, "source_hash": "c" * 64, "package_version": "28.3.0", "source_artifact_hash_count": 2, "package_artifact_hash_count": 3, "attestation_id": "attest-283", "attestation_digest": "d" * 64, "attestation_entry_count": 4}
    gate = {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "reviewer": None, "evidence_path": None}
    return {"schema_version": 283, "build_label": "source-provenance-v283", **b, "provenance_id": "provenance-283", "source": {"status": "PASS", "evidence": "source", **b, "identified": True}, "attestation": {"status": "PASS", "evidence": "attestation", "provenance_id": "provenance-283", "attestation_id": "attest-283", "attestation_digest": "d" * 64, "source_hash": "c" * 64, "package_artifact_hash_count": 3, "attestation_entry_count": 4, "attested": True}, "native_execution": dict(gate), "hardware_execution": dict(gate), "human_review": dict(gate)}


class SourceHashProvenanceV283Test(unittest.TestCase):
    def test_accepts_attestation_and_not_run_gates(self):
        self.assertEqual(validate_v283(record()), [])

    def test_requires_matching_attestation_digest_and_count(self):
        invalid = record(); invalid["attestation"]["attestation_digest"] = "e" * 64; invalid["attestation"]["attestation_entry_count"] = 5
        errors = validate_v283(invalid)
        self.assertTrue(any("attestation.attestation_digest must match" in e for e in errors)); self.assertTrue(any("attestation.attestation_entry_count must match" in e for e in errors))

    def test_rejects_schema_or_attested_flag(self):
        invalid = record(); invalid["schema_version"] = 282; invalid["attestation"]["attested"] = False
        errors = validate_v283(invalid)
        self.assertTrue(any("schema_version must be 283" in e for e in errors)); self.assertTrue(any("attestation.attested must be true" in e for e in errors))

    def test_not_run_gates_cannot_carry_hardware_or_reviewer(self):
        invalid = record(); invalid["hardware_execution"]["hardware"] = "GPU"; invalid["human_review"]["reviewer"] = "alice"
        errors = validate_v283(invalid)
        self.assertTrue(any("hardware_execution.hardware must be null" in e for e in errors)); self.assertTrue(any("human_review.reviewer must be null" in e for e in errors))


if __name__ == "__main__": unittest.main()
