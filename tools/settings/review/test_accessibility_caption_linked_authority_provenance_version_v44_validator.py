import copy
import unittest

from tools.settings.review.accessibility_caption_linked_authority_provenance_version_v44_validator import (
    AUTHORITY,
    BINDING,
    LINKED_AUTHORITY_PROVENANCE_VERSION,
    SCHEMA_VERSION,
    SOURCE_SCHEMA,
    validate_linked_authority_provenance_version,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_linked_authority_provenance_version_v44_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-linked-provenance-version-v44",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v44 linked authority/provenance/version review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "linked_authority_provenance_version_verified": False,
        "stale_payload_mutation": False,
        "linked_authority_provenance_version": copy.deepcopy(LINKED_AUTHORITY_PROVENANCE_VERSION),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "status": "planned",
        "authority_owner": "caption-presentation-service",
        "provenance_owner": "caption-presentation-service",
        "generation_owner": "caption-presentation-service",
        "provenance_source_of_truth": "presentation_only",
        "version_mode": "exact",
        "link_mode": "exact",
        "provenance_mode": "exact",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionLinkedAuthorityProvenanceVersionV44Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_linked_authority_provenance_version(_record()), [])

    def test_linked_authority_provenance_version_and_binding_are_exact(self):
        value = _record()
        value["schema_version"] = "v43"
        value["linked_authority_provenance_version"]["version_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_linked_authority_provenance_version(value)
        self.assertTrue(any("schema_version must be v44" in error for error in errors))
        self.assertTrue(any("linked_authority_provenance_version must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_linked_authority_provenance_version(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["linked_authority_provenance_version_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_linked_authority_provenance_version(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("linked_authority_provenance_version_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v44.json", "sha256": "bad"}]
        errors = validate_linked_authority_provenance_version(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["linked_authority_provenance_version"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_linked_authority_provenance_version(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("linked_authority_provenance_version must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
