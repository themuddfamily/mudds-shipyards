import copy
import unittest

from tools.settings.review.accessibility_caption_versioned_authority_reconciliation_v51_validator import (
    AUTHORITY,
    BINDING,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_SCHEMA,
    VERSIONED_AUTHORITY_RECONCILIATION,
    validate_versioned_authority_reconciliation,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_versioned_authority_reconciliation_v51_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-versioned-authority-v51",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v51 authority/reconciliation review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "versioned_authority_reconciliation_verified": False,
        "stale_payload_mutation": False,
        "versioned_authority_reconciliation": copy.deepcopy(VERSIONED_AUTHORITY_RECONCILIATION),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "status": "planned",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "authority_mode": "exact",
        "reconciliation_mode": "exact",
        "authority_owner": "caption-presentation-service",
        "generation_owner": "caption-presentation-service",
        "provenance_source_of_truth": "presentation_only",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionVersionedAuthorityReconciliationV51Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_versioned_authority_reconciliation(_record()), [])

    def test_versions_authority_reconciliation_and_binding_are_exact(self):
        value = _record()
        value["current_version"] = "v50"
        value["previous_version"] = "v49"
        value["versioned_authority_reconciliation"]["reconciliation_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_versioned_authority_reconciliation(value)
        self.assertTrue(any("current_version must be v51" in error for error in errors))
        self.assertTrue(any("previous_version must be v50" in error for error in errors))
        self.assertTrue(any("versioned_authority_reconciliation must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_versioned_authority_reconciliation(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["versioned_authority_reconciliation_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_versioned_authority_reconciliation(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("versioned_authority_reconciliation_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v51.json", "sha256": "bad"}]
        errors = validate_versioned_authority_reconciliation(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["versioned_authority_reconciliation"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_versioned_authority_reconciliation(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("versioned_authority_reconciliation must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
