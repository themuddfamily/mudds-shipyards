import unittest

from tools.package.source_hash_provenance_v140 import validate_v140


def record():
    common = {"source_id": "source-140", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-140", "package_version": "14.0.0", "source_visibility": "private", "install_scope": "per-user"}
    return {
        "schema_version": 140, "build_label": "source-provenance-v140", **common, "provenance_id": "provenance-140",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-140", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV140Test(unittest.TestCase):
    def test_accepts_visibility_scope_binding(self):
        self.assertEqual(validate_v140(record()), [])

    def test_requires_visibility_scope_binding(self):
        item = record()
        item["source"]["source_visibility"] = "public"
        item["provenance"]["install_scope"] = "system"
        errors = validate_v140(item)
        self.assertTrue(any("source.source_visibility must match" in error for error in errors))
        self.assertTrue(any("provenance.install_scope must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 139
        item["provenance"]["proven"] = False
        errors = validate_v140(item)
        self.assertTrue(any("schema_version must be 140" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "runtime.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v140(item)))


if __name__ == "__main__":
    unittest.main()
