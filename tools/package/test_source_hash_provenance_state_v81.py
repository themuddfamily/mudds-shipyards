import unittest

from tools.package.source_hash_provenance_state_v81 import validate_v81


def record():
    commit = "3" * 40
    digest = "d" * 64
    source_id = "source-81"
    provenance_id = "provenance-81"
    state_id = "state-81"
    source_version = "src-81"
    package_version = "8.1.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 81,
        "build_label": "provenance-state-v81",
        **common,
        "provenance_id": provenance_id,
        "state_id": state_id,
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": provenance_id, **common, "proven": True},
        "state": {"status": "PASS", "evidence": "state", "state_id": state_id, "provenance_id": provenance_id, **common, "valid": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceStateV81Test(unittest.TestCase):
    def test_accepts_proven_valid_state(self):
        self.assertEqual(validate_v81(record()), [])

    def test_requires_provenance_and_state_hash_binding(self):
        item = record()
        item["provenance"]["source_hash"] = "e" * 64
        item["state"]["provenance_id"] = "provenance-other"
        errors = validate_v81(item)
        self.assertTrue(any("provenance.source_hash must match" in error for error in errors))
        self.assertTrue(any("state.provenance_id must match" in error for error in errors))

    def test_rejects_schema_or_state_flags(self):
        item = record()
        item["schema_version"] = 80
        item["provenance"]["proven"] = False
        item["state"]["valid"] = False
        errors = validate_v81(item)
        self.assertTrue(any("schema_version must be 81" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))
        self.assertTrue(any("valid must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v81(item)))


if __name__ == "__main__":
    unittest.main()
