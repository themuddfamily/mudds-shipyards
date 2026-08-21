import unittest

from tools.package.source_hash_audit_lineage_v100 import validate_v100


def record():
    commit = "0" * 40
    digest = "e" * 64
    source_id = "source-100"
    audit_id = "audit-100"
    lineage_id = "lineage-100"
    source_version = "src-100"
    package_version = "10.0.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 100,
        "build_label": "audit-lineage-v100",
        **common,
        "audit_id": audit_id,
        "lineage_id": lineage_id,
        "audit": {"status": "PASS", "evidence": "audit", "audit_id": audit_id, **common, "audited": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "audit_id": audit_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditLineageV100Test(unittest.TestCase):
    def test_accepts_audited_traced_record(self):
        self.assertEqual(validate_v100(record()), [])

    def test_requires_audit_and_lineage_hash_binding(self):
        item = record()
        item["audit"]["source_hash"] = "f" * 64
        item["lineage"]["audit_id"] = "audit-other"
        errors = validate_v100(item)
        self.assertTrue(any("audit.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.audit_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 99
        item["audit"]["audited"] = False
        item["lineage"]["traced"] = False
        errors = validate_v100(item)
        self.assertTrue(any("schema_version must be 100" in error for error in errors))
        self.assertTrue(any("audited must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v100(item)))


if __name__ == "__main__":
    unittest.main()
