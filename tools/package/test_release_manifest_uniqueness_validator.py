import unittest

from tools.package.release_manifest_uniqueness_validator import validate_manifest


def manifest():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "source_commit": commit,
        "releases": [
            {"status": "PASS", "evidence": "manifest row", "release_label": "candidate-1", "artifact_path": "build/one.exe", "source_commit": commit, "artifact_hash_recorded": True},
            {"status": "NOT_RUN", "evidence": None, "release_label": "candidate-2", "artifact_path": "build/two.exe", "source_commit": commit, "artifact_hash_recorded": None},
        ],
        "uniqueness_audit": {"status": "PASS", "evidence": "duplicate scan", "duplicates": 0},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ReleaseManifestUniquenessValidatorTest(unittest.TestCase):
    def test_accepts_unique_release_entries(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_rejects_duplicate_release_labels_and_paths(self):
        item = manifest()
        item["releases"][1]["release_label"] = "candidate-1"
        item["releases"][1]["artifact_path"] = "build/one.exe"
        errors = validate_manifest(item)
        self.assertTrue(any("release_label must be unique" in error for error in errors))
        self.assertTrue(any("artifact_path must be unique" in error for error in errors))

    def test_entries_must_share_source_commit(self):
        item = manifest()
        item["releases"][0]["source_commit"] = "b" * 40
        self.assertTrue(any("source_commit must match" in error for error in validate_manifest(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = manifest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
