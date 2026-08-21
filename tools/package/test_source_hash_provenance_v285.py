import unittest
from tools.package.source_hash_provenance_v285 import validate_v285


def record() -> dict:
    b = {"source_id": "source-285", "source_commit": "b" * 40, "source_hash": "c" * 64, "package_version": "28.5.0", "source_artifact_hash_count": 2, "package_artifact_hash_count": 3, "reproducibility_id": "repro-285", "reproducibility_digest": "d" * 64, "reproducibility_entry_count": 4}
    g = {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "reviewer": None, "evidence_path": None}
    return {"schema_version": 285, "build_label": "source-provenance-v285", **b, "source": {"status": "PASS", "evidence": "source", **b, "identified": True}, "reproducibility": {"status": "PASS", "evidence": "repro", "reproducibility_id": "repro-285", "reproducibility_digest": "d" * 64, "source_hash": "c" * 64, "package_artifact_hash_count": 3, "reproducibility_entry_count": 4, "deterministic": True}, "native_execution": dict(g), "hardware_execution": dict(g), "human_review": dict(g)}


class SourceHashProvenanceV285Test(unittest.TestCase):
    def test_accepts_reproducibility_binding_and_not_run_gates(self): self.assertEqual(validate_v285(record()), [])
    def test_requires_matching_digest_and_count(self):
        i = record(); i["reproducibility"]["reproducibility_digest"] = "e" * 64; i["reproducibility"]["reproducibility_entry_count"] = 5; e = validate_v285(i)
        self.assertTrue(any("reproducibility.reproducibility_digest must match" in x for x in e)); self.assertTrue(any("reproducibility.reproducibility_entry_count must match" in x for x in e))
    def test_rejects_schema_or_deterministic_flag(self):
        i = record(); i["schema_version"] = 284; i["reproducibility"]["deterministic"] = False; e = validate_v285(i)
        self.assertTrue(any("schema_version must be 285" in x for x in e)); self.assertTrue(any("reproducibility.deterministic must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i = record(); i["native_execution"]["platform"] = "Windows"; i["human_review"]["reviewer"] = "alice"; e = validate_v285(i)
        self.assertTrue(any("native_execution.platform must be null" in x for x in e)); self.assertTrue(any("human_review.reviewer must be null" in x for x in e))


if __name__ == "__main__": unittest.main()
