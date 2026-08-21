import unittest

from tools.package.source_hash_provenance_v137 import validate_v137


def record():
    common = {"source_id": "source-137", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-137", "package_version": "13.7.0", "security_class": "internal", "support_tier": "desktop"}
    return {
        "schema_version": 137, "build_label": "source-provenance-v137", **common, "provenance_id": "provenance-137",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-137", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV137Test(unittest.TestCase):
    def test_accepts_class_tier_binding(self):
        self.assertEqual(validate_v137(record()), [])

    def test_requires_class_and_tier_binding(self):
        item = record()
        item["source"]["security_class"] = "public"
        item["provenance"]["support_tier"] = "mobile"
        errors = validate_v137(item)
        self.assertTrue(any("source.security_class must match" in error for error in errors))
        self.assertTrue(any("provenance.support_tier must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 136
        item["provenance"]["proven"] = False
        errors = validate_v137(item)
        self.assertTrue(any("schema_version must be 137" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "runtime.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v137(item)))


if __name__ == "__main__":
    unittest.main()
