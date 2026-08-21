import unittest

from tools.package.source_hash_evidence_lineage_v98 import validate_v98


def record():
    commit = "7" * 40
    digest = "a" * 64
    source_id = "source-98"
    evidence_id = "evidence-98"
    lineage_id = "lineage-98"
    source_version = "src-98"
    package_version = "9.8.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 98,
        "build_label": "evidence-lineage-v98",
        **common,
        "evidence_id": evidence_id,
        "lineage_id": lineage_id,
        "evidence_record": {"status": "PASS", "evidence": "evidence", "evidence_id": evidence_id, **common, "captured": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "evidence_id": evidence_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashEvidenceLineageV98Test(unittest.TestCase):
    def test_accepts_captured_traced_record(self):
        self.assertEqual(validate_v98(record()), [])

    def test_requires_evidence_and_lineage_hash_binding(self):
        item = record()
        item["evidence_record"]["source_hash"] = "b" * 64
        item["lineage"]["evidence_id"] = "evidence-other"
        errors = validate_v98(item)
        self.assertTrue(any("evidence_record.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.evidence_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 97
        item["evidence_record"]["captured"] = False
        item["lineage"]["traced"] = False
        errors = validate_v98(item)
        self.assertTrue(any("schema_version must be 98" in error for error in errors))
        self.assertTrue(any("captured must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v98(item)))


if __name__ == "__main__":
    unittest.main()
