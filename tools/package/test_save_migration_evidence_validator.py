import unittest

from tools.package.save_migration_evidence_validator import validate_migrations


def migrations():
    return {
        "schema_version": 1,
        "release_version": "v1.2.3",
        "build_label": "update-42",
        "source_commit": "a" * 40,
        "target_schema": 4,
        "migrations": [{"from_schema": 3, "to_schema": 4, "status": "PASS", "evidence": "fixture migration report"}],
        "migration_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "save_path": None, "evidence_path": None},
        "save_mutated": False,
    }


class SaveMigrationEvidenceValidatorTest(unittest.TestCase):
    def test_accepts_sequential_recorded_migration_without_execution(self):
        self.assertEqual(validate_migrations(migrations()), [])

    def test_pass_requires_adjacent_schema_transition_and_target(self):
        item = migrations()
        item["migrations"][0]["to_schema"] = 5
        errors = validate_migrations(item)
        self.assertTrue(any("exactly from_schema + 1" in error for error in errors))
        self.assertTrue(any("target_schema" in error for error in errors))

    def test_not_run_execution_cannot_carry_save_path(self):
        item = migrations()
        item["migration_execution"]["save_path"] = "user://save.dat"
        self.assertTrue(any("save_path must be null" in error for error in validate_migrations(item)))

    def test_migration_record_cannot_claim_save_mutation(self):
        item = migrations()
        item["save_mutated"] = True
        self.assertTrue(any("save_mutated must be false" in error for error in validate_migrations(item)))


if __name__ == "__main__":
    unittest.main()
