import unittest

from tools.package.source_hash_provenance_v138 import validate_v138


def record():
    common = {"source_id": "source-138", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-138", "package_version": "13.8.0", "source_owner": "source-team", "package_maintainer": "release-team"}
    return {
        "schema_version": 138, "build_label": "source-provenance-v138", **common, "provenance_id": "provenance-138",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-138", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV138Test(unittest.TestCase):
    def test_accepts_owner_maintainer_binding(self):
        self.assertEqual(validate_v138(record()), [])

    def test_requires_owner_maintainer_binding(self):
        item = record()
        item["source"]["source_owner"] = "other-team"
        item["provenance"]["package_maintainer"] = "other-release"
        errors = validate_v138(item)
        self.assertTrue(any("source.source_owner must match" in error for error in errors))
        self.assertTrue(any("provenance.package_maintainer must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 137
        item["provenance"]["proven"] = False
        errors = validate_v138(item)
        self.assertTrue(any("schema_version must be 138" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v138(item)))


if __name__ == "__main__":
    unittest.main()
