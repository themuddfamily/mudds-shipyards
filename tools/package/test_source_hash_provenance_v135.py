import unittest

from tools.package.source_hash_provenance_v135 import validate_v135


def record():
    common = {"source_id": "source-135", "source_commit": "9" * 40, "source_hash": "a" * 64, "source_version": "src-135", "package_version": "13.5.0", "source_date": "2026-08-21", "package_channel": "stable"}
    return {
        "schema_version": 135, "build_label": "source-provenance-v135", **common, "provenance_id": "provenance-135",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-135", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV135Test(unittest.TestCase):
    def test_accepts_date_channel_binding(self):
        self.assertEqual(validate_v135(record()), [])

    def test_requires_date_and_channel_binding(self):
        item = record()
        item["source"]["source_date"] = "2026-08-20"
        item["provenance"]["package_channel"] = "beta"
        errors = validate_v135(item)
        self.assertTrue(any("source.source_date must match" in error for error in errors))
        self.assertTrue(any("provenance.package_channel must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 134
        item["provenance"]["proven"] = False
        errors = validate_v135(item)
        self.assertTrue(any("schema_version must be 135" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v135(item)))


if __name__ == "__main__":
    unittest.main()
