import copy
import unittest

from tools.settings.review.accessibility_caption_reconciliation_digest_authority_v22_validator import (
    AUTHORITY,
    BINDING,
    DIGEST_AUTHORITY,
    SOURCE_SCHEMA,
    validate_digest_authority,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_reconciliation_digest_authority_v22_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-digest-authority-v22",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v22 digest-authority review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_authority_reconciled": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_authority": copy.deepcopy(DIGEST_AUTHORITY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "digest": None,
        "status": "planned",
        "digest_owner": "caption-presentation-service",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionReconciliationDigestAuthorityV22Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_digest_authority(_record()), [])

    def test_digest_authority_and_binding_are_exact(self):
        value = _record()
        value["digest_authority"]["digest_owner"] = "audio-service"
        value["binding"]["authority"] = "audio"
        errors = validate_digest_authority(value)
        self.assertTrue(any("digest_authority must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_digest_authority(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["digest_authority_reconciled"] = True
        value["stale_payload_mutation"] = True
        errors = validate_digest_authority(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("digest_authority_reconciled must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_digest_and_evidence_require_sha256_metadata(self):
        value = _record()
        value["digest"] = "not-a-digest"
        value["evidence"] = [{"kind": "report", "path": "reports/v22.json", "sha256": "bad"}]
        errors = validate_digest_authority(value)
        self.assertTrue(any("digest must be null" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["digest_authority"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_digest_authority(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("digest_authority must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
