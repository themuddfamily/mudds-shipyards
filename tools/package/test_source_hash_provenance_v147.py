import unittest

from tools.package.source_hash_provenance_v147 import validate_v147


def record():
    common = {"source_id": "source-147", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-147", "package_version": "14.7.0", "source_hash_algorithm": "sha256", "package_checksum_algorithm": "sha256"}
    return {
        "schema_version": 147, "build_label": "source-provenance-v147", **common, "provenance_id": "provenance-147",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-147", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV147Test(unittest.TestCase):
    def test_accepts_digest_algorithm_binding(self):
        self.assertEqual(validate_v147(record()), [])

    def test_requires_digest_algorithm_binding(self):
        item = record()
        item["source"]["source_hash_algorithm"] = "sha1"
        item["provenance"]["package_checksum_algorithm"] = "md5"
        errors = validate_v147(item)
        self.assertTrue(any("source.source_hash_algorithm must match" in error for error in errors))
        self.assertTrue(any("provenance.package_checksum_algorithm must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 146
        item["provenance"]["proven"] = False
        errors = validate_v147(item)
        self.assertTrue(any("schema_version must be 147" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "runtime.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v147(item)))


if __name__ == "__main__":
    unittest.main()
