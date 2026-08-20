import unittest

from tools.package.source_hash_verification_attestation_v64 import validate_v64


def record():
    commit = "4" * 40
    digest = "b" * 64
    source_id = "source-64"
    source_version = "src-64"
    package_version = "6.4.0"
    verification_id = "verification-64"
    attestation_id = "attestation-64"
    return {
        "schema_version": 64,
        "build_label": "verification-attestation-v64",
        "source_id": source_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "verification_id": verification_id,
        "attestation_id": attestation_id,
        "verification": {"status": "PASS", "evidence": "verification", "verification_id": verification_id, "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "verified": True},
        "attestation": {"status": "PASS", "evidence": "attestation", "attestation_id": attestation_id, "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "attested": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVerificationAttestationV64Test(unittest.TestCase):
    def test_accepts_verified_attestation(self):
        self.assertEqual(validate_v64(record()), [])

    def test_requires_verification_and_attestation_hash_binding(self):
        item = record()
        item["verification"]["source_hash"] = "c" * 64
        item["attestation"]["source_version"] = "src-other"
        errors = validate_v64(item)
        self.assertTrue(any("verification.source_hash must match" in error for error in errors))
        self.assertTrue(any("attestation.source_version must match" in error for error in errors))

    def test_rejects_schema_or_flags(self):
        item = record()
        item["schema_version"] = 63
        item["verification"]["verified"] = False
        item["attestation"]["attested"] = False
        errors = validate_v64(item)
        self.assertTrue(any("schema_version must be 64" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("attested must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v64(item)))


if __name__ == "__main__":
    unittest.main()
