import unittest

from tools.package.source_hash_source_state_v83 import validate_v83


def record():
    commit = "5" * 40
    digest = "a" * 64
    source_id = "source-83"
    state_id = "state-83"
    source_version = "src-83"
    package_version = "8.3.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 83,
        "build_label": "source-state-v83",
        **common,
        "state_id": state_id,
        "source": {"status": "PASS", "evidence": "source", **common, "identified": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSourceStateV83Test(unittest.TestCase):
    def test_accepts_identified_valid_state(self):
        self.assertEqual(validate_v83(record()), [])

    def test_requires_source_and_state_hash_binding(self):
        item = record()
        item["source"]["source_hash"] = "b" * 64
        item["state"]["state_id"] = "state-other"
        errors = validate_v83(item)
        self.assertTrue(any("source.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.state_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 82
        item["source"]["identified"] = False
        item["state"]["valid"] = False
        errors = validate_v83(item)
        self.assertTrue(any("schema_version must be 83" in error for error in errors))
        self.assertTrue(any("identified must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v83(item)))


if __name__ == "__main__":
    unittest.main()
