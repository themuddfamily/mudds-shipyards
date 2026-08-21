import unittest

from tools.package.source_hash_evidence_closure_v111 import validate_v111


def record():
    commit = "1" * 40
    digest = "a" * 64
    source_id = "source-111"
    evidence_id = "evidence-111"
    closure_id = "closure-111"
    source_version = "src-111"
    package_version = "11.1.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 111,
        "build_label": "evidence-closure-v111",
        **common,
        "evidence_id": evidence_id,
        "closure_id": closure_id,
        "evidence_record": {"status": "PASS", "evidence": "evidence", "evidence_id": evidence_id, **common, "captured": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "evidence_id": evidence_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashEvidenceClosureV111Test(unittest.TestCase):
    def test_accepts_captured_closed_evidence(self):
        self.assertEqual(validate_v111(record()), [])

    def test_requires_evidence_and_closure_hash_binding(self):
        item = record()
        item["evidence_record"]["source_hash"] = "b" * 64
        item["closure"]["evidence_id"] = "evidence-other"
        errors = validate_v111(item)
        self.assertTrue(any("evidence_record.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.evidence_id must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 110
        item["evidence_record"]["captured"] = False
        item["closure"]["closed"] = False
        errors = validate_v111(item)
        self.assertTrue(any("schema_version must be 111" in error for error in errors))
        self.assertTrue(any("captured must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v111(item)))


if __name__ == "__main__":
    unittest.main()
