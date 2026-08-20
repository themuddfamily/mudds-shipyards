import unittest

from tools.package.manifest_path_hash_source_rollup import validate_rollup


def rollup():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "paths-42",
        "source_commit": commit,
        "entries": [{"path": "bin/game.exe", "source_commit": commit, "sha256": "b" * 64}, {"path": "bin/game.pck", "source_commit": commit, "sha256": "c" * 64}],
        "audit": {"status": "PASS", "evidence": "path/hash audit", "unique_paths": True, "source_bound": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestPathHashSourceRollupTest(unittest.TestCase):
    def test_accepts_unique_source_bound_entries(self):
        self.assertEqual(validate_rollup(rollup()), [])

    def test_rejects_duplicate_and_unsafe_paths(self):
        item = rollup()
        item["entries"].append(dict(item["entries"][1]))
        item["entries"][2]["path"] = "bin/game.pck"
        item["entries"][0]["path"] = "../game.exe"
        errors = validate_rollup(item)
        self.assertTrue(any("path must be unique" in error for error in errors))
        self.assertTrue(any("relative normalized" in error for error in errors))

    def test_rejects_source_or_hash_drift(self):
        item = rollup()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][1]["sha256"] = "bad"
        errors = validate_rollup(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = rollup()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_rollup(item)))


if __name__ == "__main__":
    unittest.main()
