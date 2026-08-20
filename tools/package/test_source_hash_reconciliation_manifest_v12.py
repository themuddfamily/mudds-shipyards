import unittest

from tools.package.source_hash_reconciliation_manifest_v12 import validate_v12


def manifest():
    commit = "b" * 40
    return {
        "schema_version": 12,
        "build_label": "manifest-v12-42",
        "source_commit": commit,
        "root_digest": "a" * 64,
        "manifest_id": "manifest-42",
        "entries": [{"path": "game.exe", "source_commit": commit, "digest": "c" * 64, "manifest_id": "manifest-42"}],
        "reconciliation": {"status": "PASS", "evidence": "manifest reconciliation", "manifest_id": "manifest-42", "root_digest": "a" * 64, "entry_count": 1, "all_entries_reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReconciliationManifestV12Test(unittest.TestCase):
    def test_accepts_reconciled_manifest(self):
        self.assertEqual(validate_v12(manifest()), [])

    def test_requires_schema_v12_and_matching_entry_count(self):
        item = manifest()
        item["schema_version"] = 11
        item["reconciliation"]["entry_count"] = 2
        errors = validate_v12(item)
        self.assertTrue(any("schema_version must be 12" in error for error in errors))
        self.assertTrue(any("entry_count must equal" in error for error in errors))

    def test_rejects_entry_source_or_manifest_drift(self):
        item = manifest()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][0]["manifest_id"] = "other"
        errors = validate_v12(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("manifest_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = manifest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v12(item)))


if __name__ == "__main__":
    unittest.main()
