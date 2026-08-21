import unittest

from tools.package.source_hash_attestation_state_v84 import validate_v84


def record():
    commit = "6" * 40
    digest = "b" * 64
    source_id = "source-84"
    attestation_id = "attestation-84"
    state_id = "state-84"
    source_version = "src-84"
    package_version = "8.4.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 84,
        "build_label": "attestation-state-v84",
        **common,
        "attestation_id": attestation_id,
        "state_id": state_id,
        "attestation": {"status": "PASS", "evidence": "attestation", "attestation_id": attestation_id, **common, "attested": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "attestation_id": attestation_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAttestationStateV84Test(unittest.TestCase):
    def test_accepts_attested_valid_state(self):
        self.assertEqual(validate_v84(record()), [])

    def test_requires_attestation_and_state_hash_binding(self):
        item = record()
        item["attestation"]["source_hash"] = "c" * 64
        item["state"]["attestation_id"] = "attestation-other"
        errors = validate_v84(item)
        self.assertTrue(any("attestation.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.attestation_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 83
        item["attestation"]["attested"] = False
        item["state"]["valid"] = False
        errors = validate_v84(item)
        self.assertTrue(any("schema_version must be 84" in error for error in errors))
        self.assertTrue(any("attested must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v84(item)))


if __name__ == "__main__":
    unittest.main()
