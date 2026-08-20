import copy
import unittest

from tools.settings.review.accessibility_caption_authority_digest_binding_v20_validator import (
    AUTHORITY,
    BINDING,
    SOURCE_SCHEMA,
    validate_binding,
)


def _binding() -> dict:
    return {
        "schema": "accessibility_caption_authority_digest_binding_v20_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-binding-v20",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v20 binding review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "stale_payload_mutation": False,
        "binding": copy.deepcopy(BINDING),
        "digest": None,
        "status": "planned",
        "authority": copy.deepcopy(AUTHORITY),
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionAuthorityDigestBindingV20Tests(unittest.TestCase):
    def test_complete_binding_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_binding(_binding()), [])

    def test_binding_tuple_is_exact(self):
        value = _binding()
        value["binding"]["authority"] = "audio"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_binding(value)
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _binding()
        value["native_render_status"] = "planned"
        errors = validate_binding(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_authority_boundaries_fail_closed(self):
        value = _binding()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_binding(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_optional_digest_and_evidence_formats_are_validated(self):
        value = _binding()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/binding-v20.json", "sha256": "bad"}]
        errors = validate_binding(value)
        self.assertTrue(any("digest must be null" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _binding()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["binding"] = []
        value["authority"] = []
        errors = validate_binding(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
