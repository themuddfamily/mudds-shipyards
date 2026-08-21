import copy
import unittest

from tools.settings.review.accessibility_runtime_focus_provenance_v164_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    FOCUS_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_focus_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-focus-v164",
        "reviewer_required": "human accessibility and focus QA",
        "open_gate_reason": "no human focus review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "authority_mutated": False,
        "focus_replayed": False,
        "focus_policy": copy.deepcopy(FOCUS_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_focus_navigation_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeFocusProvenanceV164Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_focus_provenance(_record()), [])

    def test_focus_policy_and_binding_are_exact(self):
        value = _record()
        value["focus_policy"]["missing_target"] = "write_settings"
        value["binding"]["restore_rule"] = "latest_focus"
        errors = validate_runtime_focus_provenance(value)
        self.assertTrue(any("focus_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["focus_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_focus_provenance(value)
        self.assertTrue(any("focus_policy must exactly" in error for error in errors))

    def test_native_and_focus_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["focus_replayed"] = True
        errors = validate_runtime_focus_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("focus_replayed must be false" in error for error in errors))

    def test_focus_authority_fails_closed(self):
        value = _record()
        value["authority"]["focus_authority"] = True
        value["focus_authority"] = True
        errors = validate_runtime_focus_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("focus_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["focus_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_focus_provenance(value)
        self.assertTrue(any("focus_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
