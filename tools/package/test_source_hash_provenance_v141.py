import unittest

from tools.package.source_hash_provenance_v141 import validate_v141


def record():
    common = {"source_id": "source-141", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-141", "package_version": "14.1.0", "source_branch": "main", "update_policy": "compatible"}
    return {
        "schema_version": 141, "build_label": "source-provenance-v141", **common, "provenance_id": "provenance-141",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-141", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV141Test(unittest.TestCase):
    def test_accepts_branch_policy_binding(self):
        self.assertEqual(validate_v141(record()), [])

    def test_requires_branch_policy_binding(self):
        item = record()
        item["source"]["source_branch"] = "release"
        item["provenance"]["update_policy"] = "breaking"
        errors = validate_v141(item)
        self.assertTrue(any("source.source_branch must match" in error for error in errors))
        self.assertTrue(any("provenance.update_policy must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 140
        item["provenance"]["proven"] = False
        errors = validate_v141(item)
        self.assertTrue(any("schema_version must be 141" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v141(item)))


if __name__ == "__main__":
    unittest.main()
