import unittest

from tools.package.source_hash_provenance_v177 import validate_v177


def record():
    common = {"source_id": "source-177", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-177", "package_version": "17.7.0", "source_proof_count": 2, "package_proof_count": 3}
    return {
        "schema_version": 177, "build_label": "source-provenance-v177", **common, "provenance_id": "provenance-177",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-177", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV177Test(unittest.TestCase):
    def test_accepts_proof_counts(self):
        self.assertEqual(validate_v177(record()), [])

    def test_requires_matching_proof_counts(self):
        item = record()
        item["source"]["source_proof_count"] = 1
        item["provenance"]["package_proof_count"] = 4
        errors = validate_v177(item)
        self.assertTrue(any("source.source_proof_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_proof_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 176
        item["provenance"]["proven"] = False
        errors = validate_v177(item)
        self.assertTrue(any("schema_version must be 177" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v177(item)))


if __name__ == "__main__":
    unittest.main()
