import unittest

from tools.package.source_hash_release_state_v80 import validate_v80


def record():
    commit = "2" * 40
    digest = "c" * 64
    source_id = "source-80"
    release_id = "release-80"
    state_id = "state-80"
    source_version = "src-80"
    package_version = "8.0.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 80,
        "build_label": "release-state-v80",
        **common,
        "release_id": release_id,
        "state_id": state_id,
        "release": {"status": "PASS", "evidence": "release", "release_id": release_id, **common, "released": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "release_id": release_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseStateV80Test(unittest.TestCase):
    def test_accepts_released_valid_state(self):
        self.assertEqual(validate_v80(record()), [])

    def test_requires_release_and_state_hash_binding(self):
        item = record()
        item["release"]["source_hash"] = "d" * 64
        item["state"]["release_id"] = "release-other"
        errors = validate_v80(item)
        self.assertTrue(any("release.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.release_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 79
        item["release"]["released"] = False
        item["state"]["valid"] = False
        errors = validate_v80(item)
        self.assertTrue(any("schema_version must be 80" in error for error in errors))
        self.assertTrue(any("released must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v80(item)))


if __name__ == "__main__":
    unittest.main()
