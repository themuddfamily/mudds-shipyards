import unittest

from tools.package.source_hash_consistency_state_v88 import validate_v88


def record():
    commit = "0" * 40
    digest = "c" * 64
    source_id = "source-88"
    consistency_id = "consistency-88"
    state_id = "state-88"
    source_version = "src-88"
    package_version = "8.8.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 88,
        "build_label": "consistency-state-v88",
        **common,
        "consistency_id": consistency_id,
        "state_id": state_id,
        "consistency": {"status": "PASS", "evidence": "consistency", "consistency_id": consistency_id, **common, "consistent": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "consistency_id": consistency_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashConsistencyStateV88Test(unittest.TestCase):
    def test_accepts_consistent_valid_state(self):
        self.assertEqual(validate_v88(record()), [])

    def test_requires_consistency_and_state_hash_binding(self):
        item = record()
        item["consistency"]["source_hash"] = "d" * 64
        item["state"]["consistency_id"] = "consistency-other"
        errors = validate_v88(item)
        self.assertTrue(any("consistency.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.consistency_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 87
        item["consistency"]["consistent"] = False
        item["state"]["valid"] = False
        errors = validate_v88(item)
        self.assertTrue(any("schema_version must be 88" in error for error in errors))
        self.assertTrue(any("consistent must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v88(item)))


if __name__ == "__main__":
    unittest.main()
