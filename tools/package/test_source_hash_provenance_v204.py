import unittest

from tools.package.source_hash_provenance_v204 import validate_v204


def record():
    common = {"source_id": "source-204", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-204", "package_version": "20.4.0", "source_pass_count": 2, "package_pass_count": 3}
    return {
        "schema_version": 204, "build_label": "source-provenance-v204", **common, "provenance_id": "provenance-204",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-204", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV204Test(unittest.TestCase):
    def test_accepts_pass_counts(self):
        self.assertEqual(validate_v204(record()), [])

    def test_requires_matching_pass_counts(self):
        item = record()
        item["source"]["source_pass_count"] = 1
        item["provenance"]["package_pass_count"] = 4
        errors = validate_v204(item)
        self.assertTrue(any("source.source_pass_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_pass_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 203
        item["provenance"]["proven"] = False
        errors = validate_v204(item)
        self.assertTrue(any("schema_version must be 204" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v204(item)))


if __name__ == "__main__":
    unittest.main()
