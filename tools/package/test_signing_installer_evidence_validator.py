import unittest

from tools.package.signing_installer_evidence_validator import validate_evidence


def record():
    return {
        "schema_version": 1,
        "build_label": "v0.9.0-gateE",
        "source_commit": "a" * 40,
        "artifact_path": "build/MuddsShipyards.exe",
        "artifact_sha256": "b" * 64,
        "signature_status": "VERIFIED",
        "signature_tool": "signtool 10.0",
        "signer_subject": "CN=Example Release",
        "signature_evidence": "detached verification report",
        "signature_grants_distribution_rights": False,
        "installer_status": "VERIFIED",
        "installer_path": "build/MuddsShipyards-setup.exe",
        "installer_sha256": "c" * 64,
        "installer_provenance": "CI artifact manifest #42",
        "native_execution_status": "PASS",
        "native_execution_evidence": "Windows 11 clean-install smoke log",
    }


class SigningInstallerEvidenceTest(unittest.TestCase):
    def test_accepts_complete_verified_record(self):
        self.assertEqual(validate_evidence(record()), [])

    def test_verified_signature_requires_independent_metadata(self):
        item = record()
        item["signature_evidence"] = None
        item["signature_grants_distribution_rights"] = True
        errors = validate_evidence(item)
        self.assertTrue(any("signature_evidence" in error for error in errors))
        self.assertTrue(any("distribution_rights" in error for error in errors))

    def test_unverified_claims_cannot_carry_evidence(self):
        item = record()
        item["signature_status"] = "UNSIGNED"
        item["signature_evidence"] = "looks signed"
        item["installer_status"] = "NOT_PROVIDED"
        item["installer_path"] = "setup.exe"
        errors = validate_evidence(item)
        self.assertTrue(any("signature_evidence" in error for error in errors))
        self.assertTrue(any("installer evidence" in error for error in errors))

    def test_not_run_cannot_claim_native_execution(self):
        item = record()
        item["native_execution_status"] = "NOT_RUN"
        item["native_execution_evidence"] = "operator said it launched"
        self.assertTrue(any("native_execution_evidence" in error for error in validate_evidence(item)))


if __name__ == "__main__":
    unittest.main()
