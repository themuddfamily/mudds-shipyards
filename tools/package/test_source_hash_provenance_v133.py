import unittest

from tools.package.source_hash_provenance_v133 import validate_v133


def record():
    common = {"source_id": "source-133", "source_commit": "7" * 40, "source_hash": "e" * 64, "source_version": "src-133", "package_version": "13.3.0", "source_revision": "rev-133", "artifact_locator": "artifact://desktop/133"}
    return {
        "schema_version": 133, "build_label": "source-provenance-v133", **common, "provenance_id": "provenance-133",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-133", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV133Test(unittest.TestCase):
    def test_accepts_revision_locator_binding(self):
        self.assertEqual(validate_v133(record()), [])

    def test_requires_revision_and_locator_binding(self):
        item = record()
        item["source"]["source_revision"] = "rev-other"
        item["provenance"]["artifact_locator"] = "artifact://other"
        errors = validate_v133(item)
        self.assertTrue(any("source.source_revision must match" in error for error in errors))
        self.assertTrue(any("provenance.artifact_locator must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 132
        item["provenance"]["proven"] = False
        errors = validate_v133(item)
        self.assertTrue(any("schema_version must be 133" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v133(item)))


if __name__ == "__main__":
    unittest.main()
