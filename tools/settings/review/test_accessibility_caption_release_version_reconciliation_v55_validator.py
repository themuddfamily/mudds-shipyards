import copy
import unittest

from tools.settings.review.accessibility_caption_release_version_reconciliation_v55_validator import (
    AUTHORITY,
    BINDING,
    PREVIOUS_VERSION,
    RELEASE_ID,
    RELEASE_VERSION_RECONCILIATION,
    SCHEMA_VERSION,
    SOURCE_SCHEMA,
    validate_release_version_reconciliation,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_release_version_reconciliation_v55_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-release-reconciliation-v55",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v55 release/reconciliation review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "release_version_reconciliation_verified": False,
        "stale_payload_mutation": False,
        "release_version_reconciliation": copy.deepcopy(RELEASE_VERSION_RECONCILIATION),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "status": "planned",
        "release_id": RELEASE_ID,
        "release_status": "unreleased",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "reconciliation_mode": "exact",
        "authority_owner": "caption-presentation-service",
        "generation_owner": "caption-presentation-service",
        "provenance_source_of_truth": "presentation_only",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionReleaseVersionReconciliationV55Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_release_version_reconciliation(_record()), [])

    def test_release_version_reconciliation_is_exact(self):
        value = _record()
        value["release_id"] = "other-release"
        value["release_version_reconciliation"]["reconciliation_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_release_version_reconciliation(value)
        self.assertTrue(any("release_id must be" in error for error in errors))
        self.assertTrue(any("release_version_reconciliation must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_release_version_reconciliation(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["release_version_reconciliation_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_release_version_reconciliation(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("release_version_reconciliation_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v55.json", "sha256": "bad"}]
        errors = validate_release_version_reconciliation(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["release_version_reconciliation"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_release_version_reconciliation(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("release_version_reconciliation must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
