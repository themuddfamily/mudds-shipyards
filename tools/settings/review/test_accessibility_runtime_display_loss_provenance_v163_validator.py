import copy
import unittest

from tools.settings.review.accessibility_runtime_display_loss_provenance_v163_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    DISPLAY_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_display_loss_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-display-loss-v163",
        "reviewer_required": "human accessibility and display-loss QA",
        "open_gate_reason": "no human display-loss review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "authority_mutated": False,
        "restore_replayed": False,
        "display_policy": copy.deepcopy(DISPLAY_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_display_loss_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeDisplayLossProvenanceV163Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_display_loss_provenance(_record()), [])

    def test_display_policy_and_binding_are_exact(self):
        value = _record()
        value["display_policy"]["loss_behavior"] = "write_settings"
        value["binding"]["restore_rule"] = "replay_authority"
        errors = validate_runtime_display_loss_provenance(value)
        self.assertTrue(any("display_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["display_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_display_loss_provenance(value)
        self.assertTrue(any("display_policy must exactly" in error for error in errors))

    def test_native_and_restore_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["restore_replayed"] = True
        errors = validate_runtime_display_loss_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("restore_replayed must be false" in error for error in errors))

    def test_display_loss_authority_fails_closed(self):
        value = _record()
        value["authority"]["display_loss_authority"] = True
        value["display_loss_authority"] = True
        errors = validate_runtime_display_loss_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("display_loss_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["display_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_display_loss_provenance(value)
        self.assertTrue(any("display_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
