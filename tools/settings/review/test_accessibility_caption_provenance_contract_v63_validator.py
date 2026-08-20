import copy
import unittest

from tools.settings.review.accessibility_caption_provenance_contract_v63_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PREVIOUS_VERSION,
    PROVENANCE_CONTRACT,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_provenance_contract,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_provenance_contract_v63_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-provenance-contract-v63",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v63 provenance/contract review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "provenance_contract_verified": False,
        "stale_payload_mutation": False,
        "provenance_contract": copy.deepcopy(PROVENANCE_CONTRACT),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "contract_id": CONTRACT_ID,
        "contract_mode": "exact",
        "provenance_scope": "authority_and_generation",
        "provenance_source_of_truth": "presentation_only",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "status": "planned",
        "authority_owner": SOURCE_ID,
        "generation_owner": SOURCE_ID,
        "service_id": SOURCE_ID,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionProvenanceContractV63Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_provenance_contract(_record()), [])

    def test_provenance_contract_is_exact(self):
        value = _record()
        value["contract_id"] = "other-contract"
        value["provenance_contract"]["contract_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_provenance_contract(value)
        self.assertTrue(any("contract_id must be" in error for error in errors))
        self.assertTrue(any("provenance_contract must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_provenance_contract(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["provenance_contract_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_provenance_contract(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("provenance_contract_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v63.json", "sha256": "bad"}]
        errors = validate_provenance_contract(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["provenance_contract"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_provenance_contract(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("provenance_contract must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
