import copy
import unittest

from tools.settings.review.accessibility_caption_paired_digest_lineage_authority_v29_validator import (
    AUTHORITY,
    BINDING,
    PAIRED_DIGEST_LINEAGE,
    SOURCE_SCHEMA,
    validate_paired_digest_lineage,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_paired_digest_lineage_authority_v29_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-paired-lineage-v29",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v29 paired-digest lineage review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "paired_digest_lineage_verified": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "paired_digest_lineage": copy.deepcopy(PAIRED_DIGEST_LINEAGE),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "primary_digest": None,
        "secondary_digest": None,
        "status": "planned",
        "primary_owner": "caption-presentation-service",
        "secondary_owner": "caption-presentation-service",
        "generation_owner": "caption-presentation-service",
        "source_of_truth": "presentation_only",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionPairedDigestLineageAuthorityV29Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_paired_digest_lineage(_record()), [])

    def test_lineage_and_binding_are_exact(self):
        value = _record()
        value["paired_digest_lineage"]["lineage_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_paired_digest_lineage(value)
        self.assertTrue(any("paired_digest_lineage must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_paired_digest_lineage(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["paired_digest_lineage_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_paired_digest_lineage(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("paired_digest_lineage_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_pair_digests_and_evidence_require_sha256_metadata(self):
        value = _record()
        value["primary_digest"] = "not-a-digest"
        value["secondary_digest"] = "also-bad"
        value["evidence"] = [{"kind": "report", "path": "reports/v29.json", "sha256": "bad"}]
        errors = validate_paired_digest_lineage(value)
        self.assertTrue(any("primary_digest must be null" in error for error in errors))
        self.assertTrue(any("secondary_digest must be null" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["paired_digest_lineage"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_paired_digest_lineage(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("paired_digest_lineage must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
