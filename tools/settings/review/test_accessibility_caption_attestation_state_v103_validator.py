import copy
import unittest

from tools.settings.review.accessibility_caption_attestation_state_v103_validator import (
    ATTESTATION_CHECKS,
    ATTESTATION_ID,
    ATTESTATION_STATE,
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_EVIDENCE_ID,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_attestation_state,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_attestation_state_v103_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-attestation-state-v103",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v103 attestation/state review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "attestation_claimed": False,
        "state_claimed": False,
        "attestation_verified": False,
        "stale_payload_mutation": False,
        "binding": copy.deepcopy(BINDING),
        "attestation_state": copy.deepcopy(ATTESTATION_STATE),
        "attestation_checks": copy.deepcopy(ATTESTATION_CHECKS),
        "authority": copy.deepcopy(AUTHORITY),
        "attestation_id": ATTESTATION_ID,
        "attestation_status": "unverified",
        "state_status": "open",
        "state_mode": "exact",
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "source_evidence_id": SOURCE_EVIDENCE_ID,
        "source_evidence_status": "unverified",
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


class AccessibilityCaptionAttestationStateV103Tests(unittest.TestCase):
    def test_complete_record_keeps_attestation_unverified_and_native_gate_closed(self):
        self.assertEqual(validate_attestation_state(_record()), [])

    def test_v102_source_chain_is_exact(self):
        value = _record()
        value["source_schema"] = "accessibility_caption_evidence_closure_v101_evidence_v1"
        value["source_evidence_id"] = "caption-accessibility-evidence-v101"
        value["attestation_state"]["previous_version"] = "v101"
        errors = validate_attestation_state(value)
        self.assertTrue(any("source_schema must be" in error for error in errors))
        self.assertTrue(any("source_evidence_id must be" in error for error in errors))
        self.assertTrue(any("attestation_state must exactly" in error for error in errors))

    def test_human_native_and_attestation_gates_remain_open(self):
        value = _record()
        value["native_render_status"] = "planned"
        value["human_review_performed"] = True
        value["attestation_claimed"] = True
        errors = validate_attestation_state(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("attestation_claimed must be false" in error for error in errors))

    def test_authority_and_stale_policy_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_attestation_state(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_attestation_checks_are_exact(self):
        value = _record()
        value["attestation_checks"]["attestation_owner"] = False
        value["state_mode"] = "best_effort"
        errors = validate_attestation_state(value)
        self.assertTrue(any("attestation_checks must exactly" in error for error in errors))
        self.assertTrue(any("state_mode must be exact" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v103.json", "sha256": "bad"}]
        errors = validate_attestation_state(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["binding"] = []
        value["attestation_state"] = []
        value["attestation_checks"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_attestation_state(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("attestation_state must exactly" in error for error in errors))
        self.assertTrue(any("attestation_checks must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
