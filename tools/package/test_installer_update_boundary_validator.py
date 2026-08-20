import unittest

from tools.package.installer_update_boundary_validator import validate_boundary


def boundary():
    return {
        "schema_version": 1,
        "build_label": "boundary-42",
        "source_commit": "a" * 40,
        "from_version": "v1.1.0",
        "to_version": "v1.2.0",
        "install_or_update_executed": False,
        "user_data_mutated": False,
        "compatibility": {"status": "PASS", "evidence": "schema manifest", "save_schema_supported": True, "manifest": "compat.json"},
        "installer": {"status": "NOT_RUN", "evidence": None, "platform": None, "command": None, "evidence_path": None},
        "rollback": {"status": "PASS", "evidence": "reversal manifest", "reversible": True},
    }


class InstallerUpdateBoundaryValidatorTest(unittest.TestCase):
    def test_accepts_compatibility_without_executing_installer(self):
        self.assertEqual(validate_boundary(boundary()), [])

    def test_not_run_installer_cannot_carry_command_or_platform(self):
        item = boundary()
        item["installer"]["command"] = "setup.exe /upgrade"
        errors = validate_boundary(item)
        self.assertTrue(any("command must be null" in error for error in errors))

    def test_boundary_rejects_mutation_or_execution_claims(self):
        item = boundary()
        item["user_data_mutated"] = True
        item["install_or_update_executed"] = True
        errors = validate_boundary(item)
        self.assertTrue(any("user_data_mutated must be false" in error for error in errors))
        self.assertTrue(any("executed must be false" in error for error in errors))

    def test_passed_rollback_must_be_reversible(self):
        item = boundary()
        item["rollback"]["reversible"] = False
        self.assertTrue(any("reversible must be true" in error for error in validate_boundary(item)))


if __name__ == "__main__":
    unittest.main()
