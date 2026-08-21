import copy
import unittest

from tools.settings.review.accessibility_runtime_error_dialog_provenance_v182_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    ERROR_DIALOG_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_error_dialog_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-error-dialog-v182",
        "reviewer_required": "human accessibility and error-dialog QA",
        "open_gate_reason": "no human error-dialog review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "dialog_written": False,
        "dialog_replayed": False,
        "error_dialog_policy": copy.deepcopy(ERROR_DIALOG_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_error_dialog_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeErrorDialogProvenanceV182Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_error_dialog_provenance(_record()), [])

    def test_error_dialog_policy_and_binding_are_exact(self):
        value = _record()
        value["error_dialog_policy"]["unknown_error"] = "dump_secret"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_error_dialog_provenance(value)
        self.assertTrue(any("error_dialog_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["error_dialog_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_error_dialog_provenance(value)
        self.assertTrue(any("error_dialog_policy must exactly" in error for error in errors))

    def test_native_and_dialog_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["dialog_written"] = True
        errors = validate_runtime_error_dialog_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("dialog_written must be false" in error for error in errors))

    def test_error_dialog_authority_fails_closed(self):
        value = _record()
        value["authority"]["error_dialog_authority"] = True
        value["error_dialog_authority"] = True
        errors = validate_runtime_error_dialog_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("error_dialog_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["error_dialog_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_error_dialog_provenance(value)
        self.assertTrue(any("error_dialog_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
