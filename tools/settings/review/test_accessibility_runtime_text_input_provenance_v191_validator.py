import copy
import unittest

from tools.settings.review.accessibility_runtime_text_input_provenance_v191_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    TEXT_INPUT_POLICY,
    validate_runtime_text_input_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-text-input-v191",
        "reviewer_required": "human accessibility and text-input QA",
        "open_gate_reason": "no human text-input review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "input_written": False,
        "hint_replayed": False,
        "text_input_policy": copy.deepcopy(TEXT_INPUT_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_text_input_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeTextInputProvenanceV191Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_text_input_provenance(_record()), [])

    def test_text_input_policy_and_binding_are_exact(self):
        value = _record()
        value["text_input_policy"]["secret_input"] = "announce_value"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_text_input_provenance(value)
        self.assertTrue(any("text_input_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["text_input_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_text_input_provenance(value)
        self.assertTrue(any("text_input_policy must exactly" in error for error in errors))

    def test_native_and_input_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["input_written"] = True
        errors = validate_runtime_text_input_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("input_written must be false" in error for error in errors))

    def test_text_input_authority_fails_closed(self):
        value = _record()
        value["authority"]["text_input_authority"] = True
        value["text_input_authority"] = True
        errors = validate_runtime_text_input_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("text_input_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["text_input_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_text_input_provenance(value)
        self.assertTrue(any("text_input_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
