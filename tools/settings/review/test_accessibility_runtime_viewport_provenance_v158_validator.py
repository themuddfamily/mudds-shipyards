import copy
import unittest

from tools.settings.review.accessibility_runtime_viewport_provenance_v158_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    VIEWPORT_POLICY,
    validate_runtime_viewport_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-viewport-v158",
        "reviewer_required": "human accessibility and ultrawide QA",
        "open_gate_reason": "no human viewport review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "viewport_policy": copy.deepcopy(VIEWPORT_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "viewport_safe_area_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeViewportProvenanceV158Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_viewport_provenance(_record()), [])

    def test_viewport_policy_and_binding_are_exact(self):
        value = _record()
        value["viewport_policy"]["resize"] = "retain_old_rect"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_viewport_provenance(value)
        self.assertTrue(any("viewport_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_aspects_anchors_and_invalid_viewport_boundaries_cannot_widen(self):
        value = _record()
        value["viewport_policy"]["aspect_buckets"].append("48:9")
        value["viewport_policy"]["anchors"] = ["bottom_center"]
        value["viewport_policy"]["invalid_viewport"] = "claim_default"
        errors = validate_runtime_viewport_provenance(value)
        self.assertTrue(any("viewport_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_viewport_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_layout_authority_fails_closed(self):
        value = _record()
        value["authority"]["layout_authority"] = True
        value["layout_authority"] = True
        errors = validate_runtime_viewport_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("layout_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["viewport_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_viewport_provenance(value)
        self.assertTrue(any("viewport_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
