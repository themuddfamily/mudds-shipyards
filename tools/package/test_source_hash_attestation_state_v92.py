import unittest

from tools.package.source_hash_attestation_state_v92 import validate_v92


def record():
    commit = "4" * 40
    digest = "a" * 64
    source_id = "source-92"
    attestation_id = "attestation-92"
    state_id = "state-92"
    source_version = "src-92"
    package_version = "9.2.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 92,
        "build_label": "attestation-state-v92",
        **common,
        "attestation_id": attestation_id,
        "state_id": state_id,
        "attestation": {"status": "PASS", "evidence": "attestation", "attestation_id": attestation_id, **common, "attested": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "attestation_id": attestation_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAttestationStateV92Test(unittest.TestCase):
    def test_accepts_attested_valid_state(self):
        self.assertEqual(validate_v92(record()), [])

    def test_requires_attestation_and_state_hash_binding(self):
        item = record()
        item["attestation"]["source_hash"] = "b" * 64
        item["state"]["attestation_id"] = "attestation-other"
        errors = validate_v92(item)
        self.assertTrue(any("attestation.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.attestation_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 91
        item["attestation"]["attested"] = False
        item["state"]["valid"] = False
        errors = validate_v92(item)
        self.assertTrue(any("schema_version must be 92" in error for error in errors))
        self.assertTrue(any("attested must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v92(item)))


if __name__ == "__main__":
    unittest.main()
