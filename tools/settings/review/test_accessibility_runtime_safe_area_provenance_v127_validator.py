import copy
import unittest

from tools.settings.review.accessibility_runtime_safe_area_provenance_v127_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PROMPT_FIELDS,
    SAFE_AREA_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_safe_area_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-safe-area-v127",
        "reviewer_required": "human accessibility and ultrawide QA",
        "open_gate_reason": "no human safe-area review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "safe_area_policy": copy.deepcopy(SAFE_AREA_POLICY),
        "prompt_fields": copy.deepcopy(PROMPT_FIELDS),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "safe_area_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeSafeAreaProvenanceV127Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_safe_area_provenance(_record()), [])

    def test_safe_area_policy_and_prompt_fields_are_exact(self):
        value = _record()
        value["safe_area_policy"]["prompt_clipping_policy"] = "allow_clip"
        value["prompt_fields"].remove("join_hint")
        errors = validate_runtime_safe_area_provenance(value)
        self.assertTrue(any("safe_area_policy must exactly" in error for error in errors))
        self.assertTrue(any("prompt_fields must exactly" in error for error in errors))

    def test_supported_aspects_and_scale_policy_cannot_be_widened(self):
        value = _record()
        value["safe_area_policy"]["aspect_buckets"].append("48:9")
        value["safe_area_policy"]["maximum_ui_scale"] = 2.0
        errors = validate_runtime_safe_area_provenance(value)
        self.assertTrue(any("safe_area_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_safe_area_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_authority_fails_closed(self):
        value = _record()
        value["authority"]["network_authority"] = True
        value["network_authority"] = True
        errors = validate_runtime_safe_area_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("network_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["safe_area_policy"] = []
        value["prompt_fields"] = {}
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_safe_area_provenance(value)
        self.assertTrue(any("safe_area_policy must exactly" in error for error in errors))
        self.assertTrue(any("prompt_fields must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
