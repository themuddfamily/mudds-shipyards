import unittest

from tools.package.source_hash_provenance_v193 import validate_v193


def record():
    common = {"source_id": "source-193", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-193", "package_version": "19.3.0", "source_invariant_count": 2, "package_invariant_count": 3}
    return {
        "schema_version": 193, "build_label": "source-provenance-v193", **common, "provenance_id": "provenance-193",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-193", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV193Test(unittest.TestCase):
    def test_accepts_invariant_counts(self):
        self.assertEqual(validate_v193(record()), [])

    def test_requires_matching_invariant_counts(self):
        item = record()
        item["source"]["source_invariant_count"] = 1
        item["provenance"]["package_invariant_count"] = 4
        errors = validate_v193(item)
        self.assertTrue(any("source.source_invariant_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_invariant_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 192
        item["provenance"]["proven"] = False
        errors = validate_v193(item)
        self.assertTrue(any("schema_version must be 193" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v193(item)))


if __name__ == "__main__":
    unittest.main()
