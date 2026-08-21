import copy
import unittest

from tools.settings.review.accessibility_runtime_typography_provenance_v137_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    TYPOGRAPHY_POLICY,
    validate_runtime_typography_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-typography-v137",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human typography review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "typography_policy": copy.deepcopy(TYPOGRAPHY_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "caption_typography_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeTypographyProvenanceV137Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_typography_provenance(_record()), [])

    def test_typography_policy_and_binding_are_exact(self):
        value = _record()
        value["typography_policy"]["overflow_policy"] = "unbounded"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_typography_provenance(value)
        self.assertTrue(any("typography_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_contrast_scale_and_text_limits_cannot_be_widened(self):
        value = _record()
        value["typography_policy"]["maximum_text_characters"] = 4096
        value["typography_policy"]["minimum_body_contrast_ratio"] = 1.0
        errors = validate_runtime_typography_provenance(value)
        self.assertTrue(any("typography_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_typography_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_caption_authority_fails_closed(self):
        value = _record()
        value["authority"]["caption_queue_authority"] = True
        value["caption_queue_authority"] = True
        errors = validate_runtime_typography_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("caption_queue_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["typography_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_typography_provenance(value)
        self.assertTrue(any("typography_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
