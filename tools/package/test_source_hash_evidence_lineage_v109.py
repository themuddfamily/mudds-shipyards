import unittest

from tools.package.source_hash_evidence_lineage_v109 import validate_v109


def record():
    commit = "9" * 40
    digest = "c" * 64
    source_id = "source-109"
    evidence_id = "evidence-109"
    lineage_id = "lineage-109"
    source_version = "src-109"
    package_version = "10.9.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 109,
        "build_label": "evidence-lineage-v109",
        **common,
        "evidence_id": evidence_id,
        "lineage_id": lineage_id,
        "evidence_record": {"status": "PASS", "evidence": "evidence", "evidence_id": evidence_id, **common, "captured": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "evidence_id": evidence_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashEvidenceLineageV109Test(unittest.TestCase):
    def test_accepts_captured_traced_record(self):
        self.assertEqual(validate_v109(record()), [])

    def test_requires_evidence_and_lineage_hash_binding(self):
        item = record()
        item["evidence_record"]["source_hash"] = "d" * 64
        item["lineage"]["evidence_id"] = "evidence-other"
        errors = validate_v109(item)
        self.assertTrue(any("evidence_record.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.evidence_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 108
        item["evidence_record"]["captured"] = False
        item["lineage"]["traced"] = False
        errors = validate_v109(item)
        self.assertTrue(any("schema_version must be 109" in error for error in errors))
        self.assertTrue(any("captured must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v109(item)))


if __name__ == "__main__":
    unittest.main()
