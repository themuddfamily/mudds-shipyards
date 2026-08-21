import unittest

from tools.package.source_hash_provenance_v282 import validate_v282


def record() -> dict:
    binding = {
        "source_id": "source-282",
        "source_commit": "b" * 40,
        "source_hash": "c" * 64,
        "source_version": "src-282",
        "package_version": "28.2.0",
        "source_artifact_hash_count": 2,
        "package_artifact_hash_count": 3,
        "closure_id": "closure-282",
        "closure_digest": "d" * 64,
        "closure_entry_count": 4,
    }
    gate = {
        "status": "NOT_RUN",
        "evidence": None,
        "platform": None,
        "hardware": None,
        "reviewer": None,
        "evidence_path": None,
    }
    return {
        "schema_version": 282,
        "build_label": "source-provenance-v282",
        **binding,
        "provenance_id": "provenance-282",
        "source": {"status": "PASS", "evidence": "source-record", **binding, "identified": True},
        "provenance": {
            "status": "PASS",
            "evidence": "provenance-record",
            "provenance_id": "provenance-282",
            **binding,
            "proven": True,
        },
        "closure": {
            "status": "PASS",
            "evidence": "closure-record",
            "closure_id": "closure-282",
            "closure_digest": "d" * 64,
            "closure_entry_count": 4,
            "source_hash": "c" * 64,
            "package_artifact_hash_count": 3,
            "closed": True,
        },
        "native_execution": dict(gate),
        "hardware_execution": dict(gate),
        "human_review": dict(gate),
    }


class SourceHashProvenanceV282Test(unittest.TestCase):
    def test_accepts_closure_binding_and_not_run_gates(self):
        self.assertEqual(validate_v282(record()), [])

    def test_requires_matching_closure_identity_and_count(self):
        invalid = record()
        invalid["closure"]["closure_digest"] = "e" * 64
        invalid["closure"]["closure_entry_count"] = 5
        errors = validate_v282(invalid)
        self.assertTrue(any("closure.closure_digest must match" in error for error in errors))
        self.assertTrue(any("closure.closure_entry_count must match" in error for error in errors))

    def test_rejects_schema_or_closed_flag(self):
        invalid = record()
        invalid["schema_version"] = 281
        invalid["closure"]["closed"] = False
        errors = validate_v282(invalid)
        self.assertTrue(any("schema_version must be 282" in error for error in errors))
        self.assertTrue(any("closure.closed must be true" in error for error in errors))

    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        invalid = record()
        invalid["native_execution"]["platform"] = "Windows"
        invalid["human_review"]["reviewer"] = "alice"
        errors = validate_v282(invalid)
        self.assertTrue(any("native_execution.platform must be null" in error for error in errors))
        self.assertTrue(any("human_review.reviewer must be null" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
