import unittest

from tools.package.clean_directory_startup_validator import validate_startup


def startup():
    digest = "d" * 64
    return {
        "schema_version": 1,
        "build_label": "candidate-clean-42",
        "source_commit": "a" * 40,
        "artifact_path": "build/game.exe",
        "clean_directory": {"status": "PASS", "evidence": "fresh temp directory", "created_before_run": True, "user_data_present": False},
        "embedded_pck_startup": {"status": "PASS", "evidence": "startup log", "embedded": True, "exit_code": 0, "frames": 300},
        "user_data_isolation": {"status": "PASS", "evidence": "before/after manifest", "before_digest": digest, "after_digest": digest},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class CleanDirectoryStartupValidatorTest(unittest.TestCase):
    def test_accepts_isolated_embedded_startup_record(self):
        self.assertEqual(validate_startup(startup()), [])

    def test_clean_pass_requires_empty_user_data(self):
        item = startup()
        item["clean_directory"]["user_data_present"] = True
        self.assertTrue(any("user_data_present must be false" in error for error in validate_startup(item)))

    def test_embedded_pass_requires_zero_exit_and_positive_frames(self):
        item = startup()
        item["embedded_pck_startup"]["exit_code"] = 1
        item["embedded_pck_startup"]["frames"] = 0
        errors = validate_startup(item)
        self.assertTrue(any("exit_code must be 0" in error for error in errors))
        self.assertTrue(any("frames must be positive" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = startup()
        item["native_execution"]["hardware"] = "GPU"
        self.assertTrue(any("hardware must be null" in error for error in validate_startup(item)))


if __name__ == "__main__":
    unittest.main()
