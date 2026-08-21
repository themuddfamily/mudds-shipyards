import unittest

from tools.package.source_hash_provenance_v146 import validate_v146


def record():
    common = {"source_id": "source-146", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-146", "package_version": "14.6.0", "source_integrity": "verified", "package_artifact_state": "staged"}
    return {
        "schema_version": 146, "build_label": "source-provenance-v146", **common, "provenance_id": "provenance-146",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-146", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV146Test(unittest.TestCase):
    def test_accepts_integrity_artifact_binding(self):
        self.assertEqual(validate_v146(record()), [])

    def test_requires_integrity_artifact_binding(self):
        item = record()
        item["source"]["source_integrity"] = "unverified"
        item["provenance"]["package_artifact_state"] = "missing"
        errors = validate_v146(item)
        self.assertTrue(any("source.source_integrity must match" in error for error in errors))
        self.assertTrue(any("provenance.package_artifact_state must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 145
        item["provenance"]["proven"] = False
        errors = validate_v146(item)
        self.assertTrue(any("schema_version must be 146" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v146(item)))


if __name__ == "__main__":
    unittest.main()
