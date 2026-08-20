import copy
import unittest

from tools.settings.review.accessibility_caption_schema_manifest_authority_digest_v37_validator import (
    AUTHORITY,
    BINDING,
    SCHEMA_MANIFEST_AUTHORITY_DIGEST,
    SCHEMA_VERSION,
    SOURCE_SCHEMA,
    validate_schema_manifest_authority_digest,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_schema_manifest_authority_digest_v37_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-schema-manifest-authority-v37",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v37 schema/manifest authority review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "schema_manifest_authority_digest_verified": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "schema_manifest_authority_digest": copy.deepcopy(SCHEMA_MANIFEST_AUTHORITY_DIGEST),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "manifest_digest": None,
        "authority_digest": None,
        "status": "planned",
        "manifest_owner": "caption-presentation-service",
        "digest_owner": "caption-presentation-service",
        "authority_mode": "exact",
        "manifest_source_of_truth": "presentation_only",
        "generation_owner": "caption-presentation-service",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionSchemaManifestAuthorityDigestV37Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_schema_manifest_authority_digest(_record()), [])

    def test_schema_manifest_authority_and_binding_are_exact(self):
        value = _record()
        value["schema_version"] = "v36"
        value["schema_manifest_authority_digest"]["authority_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_schema_manifest_authority_digest(value)
        self.assertTrue(any("schema_version must be v37" in error for error in errors))
        self.assertTrue(any("schema_manifest_authority_digest must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_schema_manifest_authority_digest(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["schema_manifest_authority_digest_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_schema_manifest_authority_digest(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("schema_manifest_authority_digest_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_digests_and_evidence_require_sha256_metadata(self):
        value = _record()
        value["manifest_digest"] = "not-a-digest"
        value["authority_digest"] = "also-bad"
        value["evidence"] = [{"kind": "report", "path": "reports/v37.json", "sha256": "bad"}]
        errors = validate_schema_manifest_authority_digest(value)
        self.assertTrue(any("manifest_digest must be null" in error for error in errors))
        self.assertTrue(any("authority_digest must be null" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["schema_manifest_authority_digest"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_schema_manifest_authority_digest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("schema_manifest_authority_digest must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
