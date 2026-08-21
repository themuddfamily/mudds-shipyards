import unittest

from tools.package.source_hash_provenance_v132 import validate_v132


def record():
    common = {"source_id": "source-132", "source_commit": "6" * 40, "source_hash": "d" * 64, "source_version": "src-132", "package_version": "13.2.0", "repository_id": "repo-132", "package_namespace": "desktop.app"}
    return {
        "schema_version": 132, "build_label": "source-provenance-v132", **common, "provenance_id": "provenance-132",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-132", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV132Test(unittest.TestCase):
    def test_accepts_repository_namespace_binding(self):
        self.assertEqual(validate_v132(record()), [])

    def test_requires_repository_and_namespace_binding(self):
        item = record()
        item["source"]["repository_id"] = "repo-other"
        item["provenance"]["package_namespace"] = "other.app"
        errors = validate_v132(item)
        self.assertTrue(any("source.repository_id must match" in error for error in errors))
        self.assertTrue(any("provenance.package_namespace must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 131
        item["provenance"]["proven"] = False
        errors = validate_v132(item)
        self.assertTrue(any("schema_version must be 132" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v132(item)))


if __name__ == "__main__":
    unittest.main()
