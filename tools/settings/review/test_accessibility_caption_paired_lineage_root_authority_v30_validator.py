import copy
import unittest

from tools.settings.review.accessibility_caption_paired_lineage_root_authority_v30_validator import (
    AUTHORITY,
    BINDING,
    LINEAGE_ROOT_AUTHORITY,
    SOURCE_SCHEMA,
    validate_lineage_root,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_paired_lineage_root_authority_v30_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-lineage-root-v30",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v30 lineage-root review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "lineage_root_verified": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "lineage_root_authority": copy.deepcopy(LINEAGE_ROOT_AUTHORITY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "root_digest": None,
        "status": "planned",
        "root_owner": "caption-presentation-service",
        "root_source_of_truth": "presentation_only",
        "generation_owner": "caption-presentation-service",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionPairedLineageRootAuthorityV30Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_lineage_root(_record()), [])

    def test_lineage_root_and_binding_are_exact(self):
        value = _record()
        value["lineage_root_authority"]["root_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_lineage_root(value)
        self.assertTrue(any("lineage_root_authority must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_lineage_root(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["lineage_root_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_lineage_root(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("lineage_root_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_root_digest_and_evidence_require_sha256_metadata(self):
        value = _record()
        value["root_digest"] = "not-a-digest"
        value["evidence"] = [{"kind": "report", "path": "reports/v30.json", "sha256": "bad"}]
        errors = validate_lineage_root(value)
        self.assertTrue(any("root_digest must be null" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["lineage_root_authority"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_lineage_root(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("lineage_root_authority must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
