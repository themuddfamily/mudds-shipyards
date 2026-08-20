import unittest

from tools.package.desktop_platform_rollup_validator import validate_platforms


def platforms():
    source = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "desktop-42",
        "source_commit": source,
        "artifact_path": "build/game.exe",
        "platforms": [
            {"name": "linux-lavapipe", "status": "PASS", "evidence": "matrix row", "os": "Linux", "architecture": "x86_64", "renderer": "Forward+", "assertions": 8},
            {"name": "windows-native", "status": "NOT_RUN", "evidence": None, "os": "Windows", "architecture": "x86_64", "renderer": "Forward+", "assertions": None},
        ],
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class DesktopPlatformRollupValidatorTest(unittest.TestCase):
    def test_accepts_platform_matrix_with_native_not_run(self):
        self.assertEqual(validate_platforms(platforms()), [])

    def test_rows_require_unique_names_and_runtime_dimensions(self):
        item = platforms()
        item["platforms"][1]["name"] = "linux-lavapipe"
        item["platforms"][1]["renderer"] = None
        errors = validate_platforms(item)
        self.assertTrue(any("name must be unique" in error for error in errors))
        self.assertTrue(any("renderer is required" in error for error in errors))

    def test_pass_row_requires_assertion_count(self):
        item = platforms()
        item["platforms"][0]["assertions"] = None
        self.assertTrue(any("assertions must be an integer" in error for error in validate_platforms(item)))

    def test_native_not_run_cannot_carry_hardware(self):
        item = platforms()
        item["native_execution"]["hardware"] = "GPU"
        self.assertTrue(any("hardware must be null" in error for error in validate_platforms(item)))


if __name__ == "__main__":
    unittest.main()
