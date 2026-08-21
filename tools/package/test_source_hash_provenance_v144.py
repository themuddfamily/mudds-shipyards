import unittest

from tools.package.source_hash_provenance_v144 import validate_v144


def record():
    common = {"source_id": "source-144", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-144", "package_version": "14.4.0", "source_reviewer": "reviewer-144", "package_approver": "approver-144"}
    return {
        "schema_version": 144, "build_label": "source-provenance-v144", **common, "provenance_id": "provenance-144",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-144", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV144Test(unittest.TestCase):
    def test_accepts_reviewer_approver_binding(self):
        self.assertEqual(validate_v144(record()), [])

    def test_requires_reviewer_approver_binding(self):
        item = record()
        item["source"]["source_reviewer"] = "reviewer-other"
        item["provenance"]["package_approver"] = "approver-other"
        errors = validate_v144(item)
        self.assertTrue(any("source.source_reviewer must match" in error for error in errors))
        self.assertTrue(any("provenance.package_approver must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 143
        item["provenance"]["proven"] = False
        errors = validate_v144(item)
        self.assertTrue(any("schema_version must be 144" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v144(item)))


if __name__ == "__main__":
    unittest.main()
