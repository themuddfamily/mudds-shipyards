import copy
import unittest

from tools.settings.review.accessibility_caption_state_consistency_v71_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_PROVENANCE_ID,
    SOURCE_SCHEMA,
    STATE_CHECKS,
    STATE_CONSISTENCY,
    STATE_ID,
    validate_state_consistency,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_state_consistency_v71_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-state-v71",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v71 state/consistency review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "state_claimed": False,
        "consistency_verified": False,
        "stale_payload_mutation": False,
        "binding": copy.deepcopy(BINDING),
        "state_consistency": copy.deepcopy(STATE_CONSISTENCY),
        "state_checks": copy.deepcopy(STATE_CHECKS),
        "authority": copy.deepcopy(AUTHORITY),
        "state_id": STATE_ID,
        "state_status": "open",
        "consistency_status": "unverified",
        "consistency_mode": "exact",
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "source_provenance_id": SOURCE_PROVENANCE_ID,
        "source_provenance_status": "unverified",
        "contract_id": CONTRACT_ID,
        "contract_mode": "exact",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "provenance_source_of_truth": "presentation_only",
        "status": "planned",
        "authority_owner": SOURCE_ID,
        "generation_owner": SOURCE_ID,
        "service_id": SOURCE_ID,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionStateConsistencyV71Tests(unittest.TestCase):
    def test_complete_record_keeps_state_unverified_and_native_gate_closed(self):
        self.assertEqual(validate_state_consistency(_record()), [])

    def test_v70_source_chain_is_exact(self):
        value = _record()
        value["source_schema"] = "accessibility_caption_provenance_closure_v69_evidence_v1"
        value["source_provenance_id"] = "caption-accessibility-provenance-v69"
        value["state_consistency"]["previous_version"] = "v69"
        errors = validate_state_consistency(value)
        self.assertTrue(any("source_schema must be" in error for error in errors))
        self.assertTrue(any("source_provenance_id must be" in error for error in errors))
        self.assertTrue(any("state_consistency must exactly" in error for error in errors))

    def test_human_native_and_state_gates_remain_open(self):
        value = _record()
        value["native_render_status"] = "planned"
        value["human_review_performed"] = True
        value["state_claimed"] = True
        errors = validate_state_consistency(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("state_claimed must be false" in error for error in errors))

    def test_authority_and_stale_policy_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_state_consistency(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_state_checks_are_exact(self):
        value = _record()
        value["state_checks"]["state_owner"] = False
        value["consistency_mode"] = "best_effort"
        errors = validate_state_consistency(value)
        self.assertTrue(any("state_checks must exactly" in error for error in errors))
        self.assertTrue(any("consistency_mode must be exact" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v71.json", "sha256": "bad"}]
        errors = validate_state_consistency(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["binding"] = []
        value["state_consistency"] = []
        value["state_checks"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_state_consistency(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("state_consistency must exactly" in error for error in errors))
        self.assertTrue(any("state_checks must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
