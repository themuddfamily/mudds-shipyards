import unittest

from tools.package.update_compatibility_manifest import validate_manifest


def manifest():
    return {
        "schema_version": 1,
        "release_version": "v1.2.3",
        "build_label": "release-42",
        "source_commit": "a" * 40,
        "artifact_sha256": "b" * 64,
        "save_migrations": [{"from_schema": 2, "to_schema": 3, "status": "PASS", "evidence": "migration log"}],
        "signature_status": "VERIFIED",
        "signature_evidence": "detached signature report",
        "signature_grants_distribution_rights": False,
        "native_update_status": "PASS",
        "native_update_evidence": "Windows upgrade smoke log",
        "install_or_update_executed": False,
    }


class UpdateCompatibilityManifestTest(unittest.TestCase):
    def test_accepts_versioned_migration_signature_and_native_record(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_rejects_unsafe_execution_claim(self):
        item = manifest()
        item["install_or_update_executed"] = True
        self.assertTrue(any("executed" in error for error in validate_manifest(item)))

    def test_rejects_missing_migration_evidence(self):
        item = manifest()
        item["save_migrations"][0]["evidence"] = None
        self.assertTrue(any("migration" in error and "evidence" in error for error in validate_manifest(item)))

    def test_rejects_unverified_signature_evidence(self):
        item = manifest()
        item["signature_status"] = "UNSIGNED"
        self.assertTrue(any("signature_evidence" in error for error in validate_manifest(item)))

    def test_not_run_native_update_cannot_carry_evidence(self):
        item = manifest()
        item["native_update_status"] = "NOT_RUN"
        self.assertTrue(any("native_update_evidence" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
