import unittest

from tools.package.manifest_normalized_uniqueness_validator import validate_uniqueness


def uniqueness():
    return {
        "schema_version": 1,
        "build_label": "unique-42",
        "manifest_path": "manifest.json",
        "entries": [{"path": "bin/game.exe"}, {"path": "bin/game.pck"}],
        "audit": {"status": "PASS", "evidence": "duplicate scan", "duplicate_count": 0},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestNormalizedUniquenessValidatorTest(unittest.TestCase):
    def test_accepts_unique_relative_paths(self):
        self.assertEqual(validate_uniqueness(uniqueness()), [])

    def test_rejects_normalization_collisions(self):
        item = uniqueness()
        item["entries"][1]["path"] = "bin/./game.exe"
        self.assertTrue(any("unique after normalization" in error for error in validate_uniqueness(item)))

    def test_rejects_parent_escape(self):
        item = uniqueness()
        item["entries"][0]["path"] = "../game.exe"
        self.assertTrue(any("relative path" in error for error in validate_uniqueness(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = uniqueness()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_uniqueness(item)))


if __name__ == "__main__":
    unittest.main()
