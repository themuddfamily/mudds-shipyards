import unittest

from tools.package.source_hash_source_lineage_v89 import validate_v89


def record():
    commit = "1" * 40
    digest = "d" * 64
    source_id = "source-89"
    lineage_id = "lineage-89"
    source_version = "src-89"
    package_version = "8.9.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 89,
        "build_label": "source-lineage-v89",
        **common,
        "lineage_id": lineage_id,
        "source": {"status": "PASS", "evidence": "source", **common, "identified": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSourceLineageV89Test(unittest.TestCase):
    def test_accepts_identified_traced_source(self):
        self.assertEqual(validate_v89(record()), [])

    def test_requires_source_and_lineage_hash_binding(self):
        item = record()
        item["source"]["source_hash"] = "e" * 64
        item["lineage"]["source_version"] = "src-other"
        errors = validate_v89(item)
        self.assertTrue(any("source.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.source_version must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 88
        item["source"]["identified"] = False
        item["lineage"]["traced"] = False
        errors = validate_v89(item)
        self.assertTrue(any("schema_version must be 89" in error for error in errors))
        self.assertTrue(any("identified must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v89(item)))


if __name__ == "__main__":
    unittest.main()
