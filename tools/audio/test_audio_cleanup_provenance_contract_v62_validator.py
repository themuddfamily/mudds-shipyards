"""Focused tests for v62 provenance/contract summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_provenance_contract_v62_validator as validator  # noqa: E402


def summary() -> dict:
    provenance, contract = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "provenance_digest": provenance, "contract_digest": contract, "provenance_id": "provenance-v62", "contract_id": "contract-v62", "canonicalization": "json-sorted-v1", "evidence": evidence, "contract_pass": True}
    return {"schema": "audio_cleanup_provenance_contract_v62", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-contract-v62", "evidence_bundle": "artifacts/audio/contract-v62.json", "canonicalization": "json-sorted-v1", "provenance_id": "provenance-v62", "contract_id": "contract-v62", "claim": "AUTOMATED_PROVENANCE_CONTRACT_ONLY", "boundary_note": "Contract validation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "provenance_digest": provenance, "contract_digest": contract, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "provenance_contract_pass": True}


class AudioCleanupProvenanceContractV62Tests(unittest.TestCase):
    def test_valid_contract_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_contract_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["contract_id"] = "other"
        self.assertIn("records[1].contract_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_digest"] = "c" * 64
        self.assertIn("records provenance/contract digest pairs must agree", validator.validate_summary(value))

    def test_contract_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["provenance_contract_pass"] = False
        value["records"][0]["contract_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("provenance_contract_pass must be true", errors)
        self.assertIn("records[0].contract_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
