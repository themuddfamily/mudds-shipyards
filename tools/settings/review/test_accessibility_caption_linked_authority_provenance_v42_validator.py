import copy
import unittest

from tools.settings.review.accessibility_caption_linked_authority_provenance_v42_validator import (
    AUTHORITY,
    BINDING,
    LINKED_AUTHORITY_PROVENANCE,
    SCHEMA_VERSION,
    SOURCE_SCHEMA,
    validate_linked_authority_provenance,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_linked_authority_provenance_v42_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-linked-provenance-v42",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v42 linked authority/provenance review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "linked_authority_provenance_verified": False,
        "stale_payload_mutation": False,
        "linked_authority_provenance": copy.deepcopy(LINKED_AUTHORITY_PROVENANCE),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "status": "planned",
        "authority_owner": "caption-presentation-service",
        "provenance_owner": "caption-presentation-service",
        "generation_owner": "caption-presentation-service",
        "provenance_source_of_truth": "presentation_only",
        "link_mode": "exact",
        "provenance_mode": "exact",
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionLinkedAuthorityProvenanceV42Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_linked_authority_provenance(_record()), [])

    def test_linked_authority_provenance_and_binding_are_exact(self):
        value = _record()
        value["schema_version"] = "v41"
        value["linked_authority_provenance"]["provenance_mode"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_linked_authority_provenance(value)
        self.assertTrue(any("schema_version must be v42" in error for error in errors))
        self.assertTrue(any("linked_authority_provenance must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "planned"
        errors = validate_linked_authority_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_non_presentation_authority_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["linked_authority_provenance_verified"] = True
        value["stale_payload_mutation"] = True
        errors = validate_linked_authority_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("linked_authority_provenance_verified must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v42.json", "sha256": "bad"}]
        errors = validate_linked_authority_provenance(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["linked_authority_provenance"] = []
        value["binding"] = {}
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_linked_authority_provenance(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("linked_authority_provenance must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
