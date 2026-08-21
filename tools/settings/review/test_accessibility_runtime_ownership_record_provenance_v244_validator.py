import copy
import unittest

from tools.settings.review.accessibility_runtime_ownership_record_provenance_v244_validator import (
    AUTHORITY, BINDING, CONTRACT_ID, OWNERSHIP_POLICY, SCHEMA, SCHEMA_VERSION,
    SOURCE_ID, SOURCE_SCHEMA, validate_runtime_ownership_record_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA, "source_schema": SOURCE_SCHEMA, "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-ownership-record-v244",
        "reviewer_required": "human accessibility and ownership-record QA",
        "open_gate_reason": "no human ownership review or native render has been performed",
        "human_review_status": "not_performed", "native_render_status": "not_run",
        "human_review_performed": False, "native_render_performed": False,
        "policy_verified": False, "runtime_claimed": False, "ownership_written": False,
        "ownership_assigned": False, "ownership_policy": copy.deepcopy(OWNERSHIP_POLICY),
        "binding": copy.deepcopy(BINDING), "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID, "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_ownership_record_policy",
        "status": "planned", "evidence": None, **AUTHORITY,
    }


class AccessibilityRuntimeOwnershipRecordProvenanceV244Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_ownership_record_provenance(_record()), [])

    def test_ownership_policy_and_binding_are_exact(self):
        value = _record(); value["ownership_policy"]["missing_artifact"] = "claim_complete"; value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_ownership_record_provenance(value)
        self.assertTrue(any("ownership_policy must exactly" in error for error in errors)); self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_owned_accessibility_fields_cannot_shrink(self):
        value = _record(); value["ownership_policy"]["owned_fields"] = ["camera"]
        self.assertTrue(any("ownership_policy must exactly" in error for error in validate_runtime_ownership_record_provenance(value)))

    def test_native_and_ownership_claims_must_remain_open(self):
        value = _record(); value["native_render_status"] = "passed"; value["ownership_written"] = True
        errors = validate_runtime_ownership_record_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors)); self.assertTrue(any("ownership_written must be false" in error for error in errors))

    def test_ownership_record_authority_fails_closed(self):
        value = _record(); value["authority"]["ownership_record_authority"] = True; value["ownership_record_authority"] = True
        errors = validate_runtime_ownership_record_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors)); self.assertTrue(any("ownership_record_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record(); value["ownership_policy"] = []; value["binding"] = []; value["authority"] = []; value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_ownership_record_provenance(value)
        self.assertTrue(any("ownership_policy must exactly" in error for error in errors)); self.assertTrue(any("binding must exactly" in error for error in errors)); self.assertTrue(any("authority must exactly" in error for error in errors)); self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
