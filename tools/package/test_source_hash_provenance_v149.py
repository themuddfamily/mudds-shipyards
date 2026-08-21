import unittest

from tools.package.source_hash_provenance_v149 import validate_v149


def record():
    common = {"source_id": "source-149", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-149", "package_version": "14.9.0", "source_proof_id": "source-proof-149", "package_proof_id": "package-proof-149"}
    return {
        "schema_version": 149, "build_label": "source-provenance-v149", **common, "provenance_id": "provenance-149",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-149", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV149Test(unittest.TestCase):
    def test_accepts_source_package_proof_binding(self):
        self.assertEqual(validate_v149(record()), [])

    def test_requires_source_package_proof_binding(self):
        item = record()
        item["source"]["source_proof_id"] = "source-proof-other"
        item["provenance"]["package_proof_id"] = "package-proof-other"
        errors = validate_v149(item)
        self.assertTrue(any("source.source_proof_id must match" in error for error in errors))
        self.assertTrue(any("provenance.package_proof_id must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 148
        item["provenance"]["proven"] = False
        errors = validate_v149(item)
        self.assertTrue(any("schema_version must be 149" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v149(item)))


if __name__ == "__main__":
    unittest.main()
