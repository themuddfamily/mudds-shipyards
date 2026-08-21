import unittest

from tools.package.source_hash_provenance_v131 import validate_v131


def record():
    common = {"source_id": "source-131", "source_commit": "5" * 40, "source_hash": "c" * 64, "source_version": "src-131", "package_version": "13.1.0", "source_origin": "release-tag", "package_format": "bundle"}
    return {
        "schema_version": 131, "build_label": "source-provenance-v131", **common, "provenance_id": "provenance-131",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-131", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV131Test(unittest.TestCase):
    def test_accepts_origin_format_binding(self):
        self.assertEqual(validate_v131(record()), [])

    def test_requires_origin_and_format_binding(self):
        item = record()
        item["source"]["source_origin"] = "branch"
        item["provenance"]["package_format"] = "archive"
        errors = validate_v131(item)
        self.assertTrue(any("source.source_origin must match" in error for error in errors))
        self.assertTrue(any("provenance.package_format must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 130
        item["provenance"]["proven"] = False
        errors = validate_v131(item)
        self.assertTrue(any("schema_version must be 131" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "arm64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v131(item)))


if __name__ == "__main__":
    unittest.main()
