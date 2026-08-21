import copy
import unittest

from tools.settings.review.accessibility_caption_evidence_state_v105_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    EVIDENCE_CHECKS,
    EVIDENCE_ID,
    EVIDENCE_STATE,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_AUDIT_ID,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_evidence_state,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_evidence_state_v105_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-evidence-state-v105",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v105 evidence/state review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "evidence_claimed": False,
        "state_claimed": False,
        "evidence_verified": False,
        "stale_payload_mutation": False,
        "binding": copy.deepcopy(BINDING),
        "evidence_state": copy.deepcopy(EVIDENCE_STATE),
        "evidence_checks": copy.deepcopy(EVIDENCE_CHECKS),
        "authority": copy.deepcopy(AUTHORITY),
        "evidence_id": EVIDENCE_ID,
        "evidence_status": "unverified",
        "state_status": "open",
        "state_mode": "exact",
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "source_audit_id": SOURCE_AUDIT_ID,
        "source_audit_status": "unverified",
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


class AccessibilityCaptionEvidenceStateV105Tests(unittest.TestCase):
    def test_complete_record_keeps_evidence_unverified_and_native_gate_closed(self):
        self.assertEqual(validate_evidence_state(_record()), [])

    def test_v104_source_chain_is_exact(self):
        value = _record()
        value["source_schema"] = "accessibility_caption_audit_lineage_v103_evidence_v1"
        value["source_audit_id"] = "caption-accessibility-audit-v103"
        value["evidence_state"]["previous_version"] = "v103"
        errors = validate_evidence_state(value)
        self.assertTrue(any("source_schema must be" in error for error in errors))
        self.assertTrue(any("source_audit_id must be" in error for error in errors))
        self.assertTrue(any("evidence_state must exactly" in error for error in errors))

    def test_human_native_and_evidence_gates_remain_open(self):
        value = _record()
        value["native_render_status"] = "planned"
        value["human_review_performed"] = True
        value["evidence_claimed"] = True
        errors = validate_evidence_state(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("evidence_claimed must be false" in error for error in errors))

    def test_authority_and_stale_policy_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_evidence_state(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_evidence_checks_are_exact(self):
        value = _record()
        value["evidence_checks"]["evidence_owner"] = False
        value["state_mode"] = "best_effort"
        errors = validate_evidence_state(value)
        self.assertTrue(any("evidence_checks must exactly" in error for error in errors))
        self.assertTrue(any("state_mode must be exact" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v105.json", "sha256": "bad"}]
        errors = validate_evidence_state(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["binding"] = []
        value["evidence_state"] = []
        value["evidence_checks"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_evidence_state(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("evidence_state must exactly" in error for error in errors))
        self.assertTrue(any("evidence_checks must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
