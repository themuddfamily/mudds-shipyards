import unittest

from tools.package.source_hash_provenance_v139 import validate_v139


def record():
    common = {"source_id": "source-139", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-139", "package_version": "13.9.0", "attestation_method": "reviewed-manifest", "package_distribution": "internal"}
    return {
        "schema_version": 139, "build_label": "source-provenance-v139", **common, "provenance_id": "provenance-139",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-139", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV139Test(unittest.TestCase):
    def test_accepts_attestation_distribution_binding(self):
        self.assertEqual(validate_v139(record()), [])

    def test_requires_attestation_distribution_binding(self):
        item = record()
        item["source"]["attestation_method"] = "unsigned"
        item["provenance"]["package_distribution"] = "public"
        errors = validate_v139(item)
        self.assertTrue(any("source.attestation_method must match" in error for error in errors))
        self.assertTrue(any("provenance.package_distribution must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 138
        item["provenance"]["proven"] = False
        errors = validate_v139(item)
        self.assertTrue(any("schema_version must be 139" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v139(item)))


if __name__ == "__main__":
    unittest.main()
