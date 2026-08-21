import unittest

from tools.package.source_hash_provenance_v129 import validate_v129


def record():
    common = {"source_id": "source-129", "source_commit": "3" * 40, "source_hash": "a" * 64, "source_version": "src-129", "package_version": "12.9.0", "manifest_id": "manifest-129", "artifact_id": "artifact-129"}
    return {
        "schema_version": 129, "build_label": "source-provenance-v129", **common, "provenance_id": "provenance-129",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-129", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV129Test(unittest.TestCase):
    def test_accepts_manifest_artifact_binding(self):
        self.assertEqual(validate_v129(record()), [])

    def test_requires_manifest_and_artifact_binding(self):
        item = record()
        item["source"]["manifest_id"] = "manifest-other"
        item["provenance"]["artifact_id"] = "artifact-other"
        errors = validate_v129(item)
        self.assertTrue(any("source.manifest_id must match" in error for error in errors))
        self.assertTrue(any("provenance.artifact_id must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 128
        item["provenance"]["proven"] = False
        errors = validate_v129(item)
        self.assertTrue(any("schema_version must be 129" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v129(item)))


if __name__ == "__main__":
    unittest.main()
