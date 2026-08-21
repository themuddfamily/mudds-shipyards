import unittest

from tools.package.source_hash_provenance_v151 import validate_v151


def record():
    common = {"source_id": "source-151", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-151", "package_version": "15.1.0", "source_evidence_digest": "a" * 64, "package_evidence_digest": "b" * 64}
    return {
        "schema_version": 151, "build_label": "source-provenance-v151", **common, "provenance_id": "provenance-151",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-151", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV151Test(unittest.TestCase):
    def test_accepts_evidence_digest_binding(self):
        self.assertEqual(validate_v151(record()), [])

    def test_requires_evidence_digest_binding(self):
        item = record()
        item["source"]["source_evidence_digest"] = "c" * 64
        item["provenance"]["package_evidence_digest"] = "d" * 64
        errors = validate_v151(item)
        self.assertTrue(any("source.source_evidence_digest must match" in error for error in errors))
        self.assertTrue(any("provenance.package_evidence_digest must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 150
        item["provenance"]["proven"] = False
        errors = validate_v151(item)
        self.assertTrue(any("schema_version must be 151" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v151(item)))


if __name__ == "__main__":
    unittest.main()
