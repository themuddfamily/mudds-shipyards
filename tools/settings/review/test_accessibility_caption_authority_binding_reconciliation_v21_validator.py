import copy
import unittest

from tools.settings.review.accessibility_caption_authority_binding_reconciliation_v21_validator import (
    AUTHORITY,
    BINDING,
    RECONCILIATION,
    SOURCE_SCHEMA,
    validate_reconciliation,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_authority_binding_reconciliation_v21_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-reconciliation-v21",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v21 reconciliation review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "binding_reconciled": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "reconciliation": copy.deepcopy(RECONCILIATION),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "binding_digest": None,
        "status": "planned",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionAuthorityBindingReconciliationV21Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_reconciliation(_record()), [])

    def test_reconciliation_and_binding_are_exact(self):
        value = _record()
        value["reconciliation"]["authority_projection"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_reconciliation(value)
        self.assertTrue(any("reconciliation must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_reconciliation(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["binding_reconciled"] = True
        value["stale_payload_mutation"] = True
        errors = validate_reconciliation(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("binding_reconciled must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_digest_and_evidence_require_sha256_metadata(self):
        value = _record()
        value["binding_digest"] = "not-a-digest"
        value["evidence"] = [{"kind": "report", "path": "reports/v21.json", "sha256": "bad"}]
        errors = validate_reconciliation(value)
        self.assertTrue(any("binding_digest must be null" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["reconciliation"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_reconciliation(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("reconciliation must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
