import unittest

from tools.package.source_hash_audit_state_v112 import validate_v112


def record():
    commit = "2" * 40
    digest = "b" * 64
    source_id = "source-112"
    audit_id = "audit-112"
    state_id = "state-112"
    source_version = "src-112"
    package_version = "11.2.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 112,
        "build_label": "audit-state-v112",
        **common,
        "audit_id": audit_id,
        "state_id": state_id,
        "audit": {"status": "PASS", "evidence": "audit", "audit_id": audit_id, **common, "audited": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "audit_id": audit_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditStateV112Test(unittest.TestCase):
    def test_accepts_audited_valid_state(self):
        self.assertEqual(validate_v112(record()), [])

    def test_requires_audit_and_state_hash_binding(self):
        item = record()
        item["audit"]["source_hash"] = "c" * 64
        item["state"]["audit_id"] = "audit-other"
        errors = validate_v112(item)
        self.assertTrue(any("audit.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.audit_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 111
        item["audit"]["audited"] = False
        item["state"]["valid"] = False
        errors = validate_v112(item)
        self.assertTrue(any("schema_version must be 112" in error for error in errors))
        self.assertTrue(any("audited must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v112(item)))


if __name__ == "__main__":
    unittest.main()
