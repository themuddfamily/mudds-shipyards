import unittest

from tools.package.source_hash_provenance_v272 import validate_v272


def record():
    common = {"source_id": "source-272", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-272", "package_version": "27.2.0", "source_evidence_count": 1, "package_evidence_count": 2}
    gates = {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "reviewer": None, "evidence_path": None}
    return {"schema_version": 272, "build_label": "source-provenance-v272", **common, "provenance_id": "provenance-272", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-272", **common, "proven": True}, "native_execution": dict(gates), "hardware_execution": dict(gates), "human_review": dict(gates)}


class SourceHashProvenanceV272Test(unittest.TestCase):
    def test_accepts_evidence_counts_and_not_run_gates(self):
        self.assertEqual(validate_v272(record()), [])

    def test_requires_matching_evidence_counts(self):
        item = record()
        item["source"]["source_evidence_count"] = 0
        item["provenance"]["package_evidence_count"] = 3
        errors = validate_v272(item)
        self.assertTrue(any("source.source_evidence_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_evidence_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 271
        item["provenance"]["proven"] = False
        errors = validate_v272(item)
        self.assertTrue(any("schema_version must be 272" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_not_run_gates_cannot_carry_hardware_or_reviewer(self):
        item = record()
        item["hardware_execution"]["hardware"] = "GPU"
        item["human_review"]["reviewer"] = "alice"
        errors = validate_v272(item)
        self.assertTrue(any("hardware_execution.hardware must be null" in error for error in errors))
        self.assertTrue(any("human_review.reviewer must be null" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
