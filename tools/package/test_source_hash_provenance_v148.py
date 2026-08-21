import unittest

from tools.package.source_hash_provenance_v148 import validate_v148


def record():
    common = {"source_id": "source-148", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-148", "package_version": "14.8.0", "source_digest": "c" * 64, "package_digest": "d" * 64}
    return {
        "schema_version": 148, "build_label": "source-provenance-v148", **common, "provenance_id": "provenance-148",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-148", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV148Test(unittest.TestCase):
    def test_accepts_source_package_digest_binding(self):
        self.assertEqual(validate_v148(record()), [])

    def test_requires_source_package_digest_binding(self):
        item = record()
        item["source"]["source_digest"] = "e" * 64
        item["provenance"]["package_digest"] = "f" * 64
        errors = validate_v148(item)
        self.assertTrue(any("source.source_digest must match" in error for error in errors))
        self.assertTrue(any("provenance.package_digest must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 147
        item["provenance"]["proven"] = False
        errors = validate_v148(item)
        self.assertTrue(any("schema_version must be 148" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v148(item)))


if __name__ == "__main__":
    unittest.main()
