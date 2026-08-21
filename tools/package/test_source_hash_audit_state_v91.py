import unittest

from tools.package.source_hash_audit_state_v91 import validate_v91


def record():
    commit = "3" * 40
    digest = "f" * 64
    source_id = "source-91"
    audit_id = "audit-91"
    state_id = "state-91"
    source_version = "src-91"
    package_version = "9.1.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 91,
        "build_label": "audit-state-v91",
        **common,
        "audit_id": audit_id,
        "state_id": state_id,
        "audit": {"status": "PASS", "evidence": "audit", "audit_id": audit_id, **common, "audited": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "audit_id": audit_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditStateV91Test(unittest.TestCase):
    def test_accepts_audited_valid_state(self):
        self.assertEqual(validate_v91(record()), [])

    def test_requires_audit_and_state_hash_binding(self):
        item = record()
        item["audit"]["source_hash"] = "a" * 64
        item["state"]["audit_id"] = "audit-other"
        errors = validate_v91(item)
        self.assertTrue(any("audit.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.audit_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 90
        item["audit"]["audited"] = False
        item["state"]["valid"] = False
        errors = validate_v91(item)
        self.assertTrue(any("schema_version must be 91" in error for error in errors))
        self.assertTrue(any("audited must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v91(item)))


if __name__ == "__main__":
    unittest.main()
