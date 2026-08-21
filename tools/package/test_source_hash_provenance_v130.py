import unittest

from tools.package.source_hash_provenance_v130 import validate_v130


def record():
    common = {"source_id": "source-130", "source_commit": "4" * 40, "source_hash": "b" * 64, "source_version": "src-130", "package_version": "13.0.0", "source_tree": "tree-130", "package_target": "desktop"}
    return {
        "schema_version": 130, "build_label": "source-provenance-v130", **common, "provenance_id": "provenance-130",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-130", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV130Test(unittest.TestCase):
    def test_accepts_tree_target_binding(self):
        self.assertEqual(validate_v130(record()), [])

    def test_requires_tree_and_target_binding(self):
        item = record()
        item["source"]["source_tree"] = "tree-other"
        item["provenance"]["package_target"] = "mobile"
        errors = validate_v130(item)
        self.assertTrue(any("source.source_tree must match" in error for error in errors))
        self.assertTrue(any("provenance.package_target must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 129
        item["provenance"]["proven"] = False
        errors = validate_v130(item)
        self.assertTrue(any("schema_version must be 130" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v130(item)))


if __name__ == "__main__":
    unittest.main()
