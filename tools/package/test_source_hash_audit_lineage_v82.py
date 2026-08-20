import unittest

from tools.package.source_hash_audit_lineage_v82 import validate_v82


def record():
    commit = "4" * 40
    digest = "f" * 64
    source_id = "source-82"
    audit_id = "audit-82"
    lineage_id = "lineage-82"
    source_version = "src-82"
    package_version = "8.2.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 82,
        "build_label": "audit-lineage-v82",
        **common,
        "audit_id": audit_id,
        "lineage_id": lineage_id,
        "audit": {"status": "PASS", "evidence": "audit", "audit_id": audit_id, **common, "audited": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "audit_id": audit_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditLineageV82Test(unittest.TestCase):
    def test_accepts_audited_traced_record(self):
        self.assertEqual(validate_v82(record()), [])

    def test_requires_audit_and_lineage_hash_binding(self):
        item = record()
        item["audit"]["source_hash"] = "a" * 64
        item["lineage"]["audit_id"] = "audit-other"
        errors = validate_v82(item)
        self.assertTrue(any("audit.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.audit_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 81
        item["audit"]["audited"] = False
        item["lineage"]["traced"] = False
        errors = validate_v82(item)
        self.assertTrue(any("schema_version must be 82" in error for error in errors))
        self.assertTrue(any("audited must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v82(item)))


if __name__ == "__main__":
    unittest.main()
