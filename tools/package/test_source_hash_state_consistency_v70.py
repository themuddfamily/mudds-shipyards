import unittest

from tools.package.source_hash_state_consistency_v70 import validate_v70


def record():
    commit = "0" * 40
    digest = "b" * 64
    source_id = "source-70"
    state_id = "state-70"
    source_version = "src-70"
    package_version = "7.0.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 70,
        "build_label": "state-consistency-v70",
        **common,
        "state_id": state_id,
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, **common, "valid": True},
        "consistency": {"status": "PASS", "evidence": "consistency", "state_id": state_id, **common, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashStateConsistencyV70Test(unittest.TestCase):
    def test_accepts_valid_consistent_state(self):
        self.assertEqual(validate_v70(record()), [])

    def test_requires_state_and_consistency_hash_binding(self):
        item = record()
        item["state"]["source_hash"] = "c" * 64
        item["consistency"]["state_id"] = "state-other"
        errors = validate_v70(item)
        self.assertTrue(any("state.source_hash must match" in error for error in errors))
        self.assertTrue(any("consistency.state_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 69
        item["state"]["valid"] = False
        item["consistency"]["consistent"] = False
        errors = validate_v70(item)
        self.assertTrue(any("schema_version must be 70" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))
        self.assertTrue(any("consistent must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v70(item)))


if __name__ == "__main__":
    unittest.main()
