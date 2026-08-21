import unittest
from tools.package.source_hash_provenance_v284 import validate_v284


def record() -> dict:
    b = {"source_id": "source-284", "source_commit": "b" * 40, "source_hash": "c" * 64, "package_version": "28.4.0", "source_artifact_hash_count": 2, "package_artifact_hash_count": 3, "review_id": "review-284", "review_timestamp": "2026-08-21T12:00:00Z", "review_entry_count": 4}
    g = {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "reviewer": None, "evidence_path": None}
    return {"schema_version": 284, "build_label": "source-provenance-v284", **b, "source": {"status": "PASS", "evidence": "source", **b, "identified": True}, "review": {"status": "PASS", "evidence": "review", "review_id": "review-284", "review_timestamp": b["review_timestamp"], "source_hash": b["source_hash"], "package_artifact_hash_count": 3, "review_entry_count": 4, "complete": True}, "native_execution": dict(g), "hardware_execution": dict(g), "human_review": dict(g)}


class SourceHashProvenanceV284Test(unittest.TestCase):
    def test_accepts_review_binding_and_not_run_gates(self):
        self.assertEqual(validate_v284(record()), [])

    def test_requires_matching_review_timestamp_and_count(self):
        i = record(); i["review"]["review_timestamp"] = "2026-08-22T12:00:00Z"; i["review"]["review_entry_count"] = 5; e = validate_v284(i)
        self.assertTrue(any("review.review_timestamp must match" in x for x in e)); self.assertTrue(any("review.review_entry_count must match" in x for x in e))

    def test_rejects_schema_or_completion_flag(self):
        i = record(); i["schema_version"] = 283; i["review"]["complete"] = False; e = validate_v284(i)
        self.assertTrue(any("schema_version must be 284" in x for x in e)); self.assertTrue(any("review.complete must be true" in x for x in e))

    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i = record(); i["native_execution"]["platform"] = "Windows"; i["human_review"]["reviewer"] = "alice"; e = validate_v284(i)
        self.assertTrue(any("native_execution.platform must be null" in x for x in e)); self.assertTrue(any("human_review.reviewer must be null" in x for x in e))


if __name__ == "__main__":
    unittest.main()
