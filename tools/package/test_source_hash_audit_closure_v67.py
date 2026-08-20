import unittest

from tools.package.source_hash_audit_closure_v67 import validate_v67


def record():
    commit = "7" * 40
    digest = "e" * 64
    source_id = "source-67"
    audit_id = "audit-67"
    closure_id = "closure-67"
    source_version = "src-67"
    package_version = "6.7.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 67,
        "build_label": "audit-closure-v67",
        **common,
        "audit_id": audit_id,
        "closure_id": closure_id,
        "audit": {"status": "PASS", "evidence": "audit", "audit_id": audit_id, **common, "audited": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "audit_id": audit_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditClosureV67Test(unittest.TestCase):
    def test_accepts_audited_closed_record(self):
        self.assertEqual(validate_v67(record()), [])

    def test_requires_audit_and_closure_hash_binding(self):
        item = record()
        item["audit"]["source_hash"] = "f" * 64
        item["closure"]["audit_id"] = "audit-other"
        errors = validate_v67(item)
        self.assertTrue(any("audit.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.audit_id must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 66
        item["audit"]["audited"] = False
        item["closure"]["closed"] = False
        errors = validate_v67(item)
        self.assertTrue(any("schema_version must be 67" in error for error in errors))
        self.assertTrue(any("audited must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "macOS"
        self.assertTrue(any("platform must be null" in error for error in validate_v67(item)))


if __name__ == "__main__":
    unittest.main()
