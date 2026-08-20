import unittest

from tools.package.installer_update_rollup_validator import validate_rollup


def rollup():
    return {
        "schema_version": 1,
        "release_version": "v1.2.3",
        "build_label": "gateE-update-42",
        "source_commit": "a" * 40,
        "artifact_sha256": "b" * 64,
        "installer": {"status": "PASS", "evidence": "manifest inspection", "path": "build/setup.exe", "sha256": "c" * 64, "provenance": "operator manifest"},
        "save_migration": {"status": "PASS", "evidence": "fixture migration log", "from_schema": 3, "to_schema": 4},
        "native_update": {"status": "NOT_RUN", "evidence": None, "platform": None, "evidence_path": None},
        "install_or_update_executed": False,
    }


class InstallerUpdateRollupValidatorTest(unittest.TestCase):
    def test_accepts_verified_artifact_and_explicit_native_not_run(self):
        self.assertEqual(validate_rollup(rollup()), [])

    def test_not_run_native_update_cannot_carry_platform_or_evidence(self):
        item = rollup()
        item["native_update"]["platform"] = "Windows"
        item["native_update"]["evidence"] = "upgrade log"
        errors = validate_rollup(item)
        self.assertTrue(any("evidence must be null" in error for error in errors))
        self.assertTrue(any("platform must be null" in error for error in errors))

    def test_pass_requires_installer_digest_and_provenance(self):
        item = rollup()
        item["installer"]["sha256"] = "bad"
        item["installer"]["provenance"] = None
        errors = validate_rollup(item)
        self.assertTrue(any("installer.sha256" in error for error in errors))
        self.assertTrue(any("installer.provenance" in error for error in errors))

    def test_execution_must_remain_false(self):
        item = rollup()
        item["install_or_update_executed"] = True
        self.assertTrue(any("executed must be false" in error for error in validate_rollup(item)))


if __name__ == "__main__":
    unittest.main()
