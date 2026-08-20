import unittest

from tools.package.manifest_source_alignment_validator import validate_alignment


def alignment():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "manifest-42",
        "source_commit": commit,
        "manifest_path": "manifest.json",
        "manifest": {"status": "PASS", "evidence": "manifest report", "source_commit": commit, "entry_count": 2},
        "entries": [{"path": "game.exe", "source_commit": commit}, {"path": "game.pck", "source_commit": commit}],
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestSourceAlignmentValidatorTest(unittest.TestCase):
    def test_accepts_manifest_entries_aligned_to_source(self):
        self.assertEqual(validate_alignment(alignment()), [])

    def test_rejects_entry_source_commit_drift(self):
        item = alignment()
        item["entries"][1]["source_commit"] = "b" * 40
        self.assertTrue(any("entries[1].source_commit must match" in error for error in validate_alignment(item)))

    def test_rejects_duplicate_paths_and_count_drift(self):
        item = alignment()
        item["entries"][1]["path"] = "game.exe"
        item["manifest"]["entry_count"] = 3
        errors = validate_alignment(item)
        self.assertTrue(any("path must be unique" in error for error in errors))
        self.assertTrue(any("entry_count must equal" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = alignment()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_alignment(item)))


if __name__ == "__main__":
    unittest.main()
