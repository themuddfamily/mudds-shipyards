import unittest

from tools.package.source_hash_verification_state_v96 import validate_v96


def record():
    commit = "9" * 40
    digest = "d" * 64
    source_id = "source-96"
    verification_id = "verification-96"
    state_id = "state-96"
    source_version = "src-96"
    package_version = "9.6.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 96,
        "build_label": "verification-state-v96",
        **common,
        "verification_id": verification_id,
        "state_id": state_id,
        "verification": {"status": "PASS", "evidence": "verification", "verification_id": verification_id, **common, "verified": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "verification_id": verification_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVerificationStateV96Test(unittest.TestCase):
    def test_accepts_verified_valid_state(self):
        self.assertEqual(validate_v96(record()), [])

    def test_requires_verification_and_state_hash_binding(self):
        item = record()
        item["verification"]["source_hash"] = "e" * 64
        item["state"]["verification_id"] = "verification-other"
        errors = validate_v96(item)
        self.assertTrue(any("verification.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.verification_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 95
        item["verification"]["verified"] = False
        item["state"]["valid"] = False
        errors = validate_v96(item)
        self.assertTrue(any("schema_version must be 96" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v96(item)))


if __name__ == "__main__":
    unittest.main()
