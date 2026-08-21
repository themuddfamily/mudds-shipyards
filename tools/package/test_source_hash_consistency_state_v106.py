import unittest

from tools.package.source_hash_consistency_state_v106 import validate_v106


def record():
    commit = "6" * 40
    digest = "d" * 64
    source_id = "source-106"
    consistency_id = "consistency-106"
    state_id = "state-106"
    source_version = "src-106"
    package_version = "10.6.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 106,
        "build_label": "consistency-state-v106",
        **common,
        "consistency_id": consistency_id,
        "state_id": state_id,
        "consistency": {"status": "PASS", "evidence": "consistency", "consistency_id": consistency_id, **common, "consistent": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "consistency_id": consistency_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashConsistencyStateV106Test(unittest.TestCase):
    def test_accepts_consistent_valid_state(self):
        self.assertEqual(validate_v106(record()), [])

    def test_requires_consistency_and_state_hash_binding(self):
        item = record()
        item["consistency"]["source_hash"] = "e" * 64
        item["state"]["consistency_id"] = "consistency-other"
        errors = validate_v106(item)
        self.assertTrue(any("consistency.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.consistency_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 105
        item["consistency"]["consistent"] = False
        item["state"]["valid"] = False
        errors = validate_v106(item)
        self.assertTrue(any("schema_version must be 106" in error for error in errors))
        self.assertTrue(any("consistent must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v106(item)))


if __name__ == "__main__":
    unittest.main()
