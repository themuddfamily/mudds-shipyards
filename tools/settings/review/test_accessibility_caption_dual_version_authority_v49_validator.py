import copy
import unittest

from tools.settings.review.accessibility_caption_dual_version_authority_v49_validator import (
    AUTHORITY,
    BINDING,
    DUAL_VERSION_AUTHORITY,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_SCHEMA,
    validate_dual_version_authority,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_dual_version_authority_v49_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-dual-authority-v49",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v49 authority review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "dual_version_authority_verified": False,
        "stale_payload_mutation": False,
        "dual_version_authority": copy.deepcopy(DUAL_VERSION_AUTHORITY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "status": "planned",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "authority_mode": "exact",
        "authority_owner": "caption-presentation-service",
        "generation_owner": "caption-presentation-service",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionDualVersionAuthorityV49Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_dual_version_authority(_record()), [])

    def test_dual_versions_authority_and_binding_are_exact(self):
        value = _record()
        value["current_version"] = "v48"
        value["previous_version"] = "v47"
        value["dual_version_authority"]["authority_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_dual_version_authority(value)
        self.assertTrue(any("current_version must be v49" in error for error in errors))
        self.assertTrue(any("previous_version must be v48" in error for error in errors))
        self.assertTrue(any("dual_version_authority must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_dual_version_authority(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["dual_version_authority_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_dual_version_authority(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("dual_version_authority_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v49.json", "sha256": "bad"}]
        errors = validate_dual_version_authority(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["dual_version_authority"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_dual_version_authority(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("dual_version_authority must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
