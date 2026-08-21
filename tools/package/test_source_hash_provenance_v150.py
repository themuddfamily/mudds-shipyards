import unittest

from tools.package.source_hash_provenance_v150 import validate_v150


def record():
    common = {"source_id": "source-150", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-150", "package_version": "15.0.0", "source_evidence_uri": "evidence://source/150", "package_evidence_uri": "evidence://package/150"}
    return {
        "schema_version": 150, "build_label": "source-provenance-v150", **common, "provenance_id": "provenance-150",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-150", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV150Test(unittest.TestCase):
    def test_accepts_evidence_uri_binding(self):
        self.assertEqual(validate_v150(record()), [])

    def test_requires_evidence_uri_binding(self):
        item = record()
        item["source"]["source_evidence_uri"] = "evidence://other/source"
        item["provenance"]["package_evidence_uri"] = "evidence://other/package"
        errors = validate_v150(item)
        self.assertTrue(any("source.source_evidence_uri must match" in error for error in errors))
        self.assertTrue(any("provenance.package_evidence_uri must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 149
        item["provenance"]["proven"] = False
        errors = validate_v150(item)
        self.assertTrue(any("schema_version must be 150" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v150(item)))


if __name__ == "__main__":
    unittest.main()
