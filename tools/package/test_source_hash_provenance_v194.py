import unittest

from tools.package.source_hash_provenance_v194 import validate_v194


def record():
    common = {"source_id": "source-194", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-194", "package_version": "19.4.0", "source_contract_count": 2, "package_contract_count": 3}
    return {
        "schema_version": 194, "build_label": "source-provenance-v194", **common, "provenance_id": "provenance-194",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-194", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV194Test(unittest.TestCase):
    def test_accepts_contract_counts(self):
        self.assertEqual(validate_v194(record()), [])

    def test_requires_matching_contract_counts(self):
        item = record()
        item["source"]["source_contract_count"] = 1
        item["provenance"]["package_contract_count"] = 4
        errors = validate_v194(item)
        self.assertTrue(any("source.source_contract_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_contract_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 193
        item["provenance"]["proven"] = False
        errors = validate_v194(item)
        self.assertTrue(any("schema_version must be 194" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v194(item)))


if __name__ == "__main__":
    unittest.main()
