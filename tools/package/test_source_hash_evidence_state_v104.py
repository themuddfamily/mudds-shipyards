import unittest

from tools.package.source_hash_evidence_state_v104 import validate_v104


def record():
    commit = "4" * 40
    digest = "b" * 64
    source_id = "source-104"
    evidence_id = "evidence-104"
    state_id = "state-104"
    source_version = "src-104"
    package_version = "10.4.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 104,
        "build_label": "evidence-state-v104",
        **common,
        "evidence_id": evidence_id,
        "state_id": state_id,
        "evidence_record": {"status": "PASS", "evidence": "evidence", "evidence_id": evidence_id, **common, "captured": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "evidence_id": evidence_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashEvidenceStateV104Test(unittest.TestCase):
    def test_accepts_captured_valid_state(self):
        self.assertEqual(validate_v104(record()), [])

    def test_requires_evidence_and_state_hash_binding(self):
        item = record()
        item["evidence_record"]["source_hash"] = "c" * 64
        item["state"]["evidence_id"] = "evidence-other"
        errors = validate_v104(item)
        self.assertTrue(any("evidence_record.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.evidence_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 103
        item["evidence_record"]["captured"] = False
        item["state"]["valid"] = False
        errors = validate_v104(item)
        self.assertTrue(any("schema_version must be 104" in error for error in errors))
        self.assertTrue(any("captured must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v104(item)))


if __name__ == "__main__":
    unittest.main()
