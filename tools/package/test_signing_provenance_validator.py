import unittest

from tools.package.signing_provenance_validator import validate_provenance


def record():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "candidate-42",
        "source_commit": commit,
        "artifact_path": "build/game.exe",
        "artifact_sha256": "b" * 64,
        "signature": {"status": "NOT_RUN", "evidence": None, "algorithm": None, "certificate_subject": None, "certificate_digest": None},
        "source_attestation": {"status": "PASS", "evidence": "clean-source manifest", "commit": commit, "manifest": "manifest.sha256"},
        "signature_grants_distribution_rights": False,
    }


class SigningProvenanceValidatorTest(unittest.TestCase):
    def test_accepts_unrun_signature_with_source_attestation(self):
        self.assertEqual(validate_provenance(record()), [])

    def test_not_run_signature_cannot_carry_certificate_claim(self):
        item = record()
        item["signature"]["certificate_subject"] = "CN=release"
        self.assertTrue(any("certificate_subject must be null" in error for error in validate_provenance(item)))

    def test_verified_signature_requires_digest_and_algorithm(self):
        item = record()
        item["signature"] = {"status": "PASS", "evidence": "verification log"}
        errors = validate_provenance(item)
        self.assertTrue(any("signature.algorithm" in error for error in errors))
        self.assertTrue(any("certificate_digest" in error for error in errors))

    def test_source_attestation_must_bind_to_commit(self):
        item = record()
        item["source_attestation"]["commit"] = "c" * 40
        self.assertTrue(any("must match source_commit" in error for error in validate_provenance(item)))


if __name__ == "__main__":
    unittest.main()
