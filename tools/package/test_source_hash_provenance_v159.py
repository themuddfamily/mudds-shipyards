import unittest

from tools.package.source_hash_provenance_v159 import validate_v159


def record():
    common = {"source_id": "source-159", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-159", "package_version": "15.9.0", "source_attestation_count": 2, "package_attestation_count": 3}
    return {
        "schema_version": 159, "build_label": "source-provenance-v159", **common, "provenance_id": "provenance-159",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-159", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV159Test(unittest.TestCase):
    def test_accepts_attestation_counts(self):
        self.assertEqual(validate_v159(record()), [])

    def test_requires_matching_attestation_counts(self):
        item = record()
        item["source"]["source_attestation_count"] = 1
        item["provenance"]["package_attestation_count"] = 4
        errors = validate_v159(item)
        self.assertTrue(any("source.source_attestation_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_attestation_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 158
        item["provenance"]["proven"] = False
        errors = validate_v159(item)
        self.assertTrue(any("schema_version must be 159" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v159(item)))


if __name__ == "__main__":
    unittest.main()
