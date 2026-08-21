import copy
import unittest

from tools.settings.review.accessibility_runtime_outcome_record_provenance_v265_validator import (
    AUTHORITY, BINDING, CONTRACT_ID, OUTCOME_POLICY, SCHEMA, SCHEMA_VERSION,
    SOURCE_ID, SOURCE_SCHEMA, validate_runtime_outcome_record_provenance,
)


def _record() -> dict:
    return {"schema": SCHEMA, "source_schema": SOURCE_SCHEMA, "schema_version": SCHEMA_VERSION,
            "source_revision": "working-tree-runtime-outcome-record-v265",
            "reviewer_required": "human accessibility and outcome-record QA",
            "open_gate_reason": "human and native outcome validation have not been performed",
            "human_review_status": "not_performed", "native_render_status": "not_run",
            "human_review_performed": False, "native_render_performed": False,
            "policy_verified": False, "runtime_claimed": False, "outcome_written": False,
            "outcome_confirmed": False, "outcome_policy": copy.deepcopy(OUTCOME_POLICY),
            "binding": copy.deepcopy(BINDING), "authority": copy.deepcopy(AUTHORITY),
            "source_id": SOURCE_ID, "contract_id": CONTRACT_ID,
            "provenance_source_of_truth": "runtime_accessibility_outcome_record_policy",
            "status": "planned", "evidence": None, **AUTHORITY}


class AccessibilityRuntimeOutcomeRecordProvenanceV265Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_outcome_record_provenance(_record()), [])
    def test_outcome_policy_and_binding_are_exact(self):
        value = _record(); value["outcome_policy"]["missing_artifact"] = "claim_complete"; value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_outcome_record_provenance(value)
        self.assertTrue(any("outcome_policy must exactly" in e for e in errors)); self.assertTrue(any("binding must exactly" in e for e in errors))
    def test_outcome_fields_cannot_shrink(self):
        value = _record(); value["outcome_policy"]["outcome_fields"] = ["camera"]
        self.assertTrue(any("outcome_policy must exactly" in e for e in validate_runtime_outcome_record_provenance(value)))
    def test_native_and_outcome_claims_remain_open(self):
        value = _record(); value["native_render_status"] = "passed"; value["outcome_written"] = True
        errors = validate_runtime_outcome_record_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in e for e in errors)); self.assertTrue(any("outcome_written must be false" in e for e in errors))
    def test_outcome_record_authority_fails_closed(self):
        value = _record(); value["authority"]["outcome_record_authority"] = True; value["outcome_record_authority"] = True
        errors = validate_runtime_outcome_record_provenance(value)
        self.assertTrue(any("authority must exactly" in e for e in errors)); self.assertTrue(any("outcome_record_authority must be false" in e for e in errors))
    def test_malformed_shapes_fail_without_throwing(self):
        value = _record(); value["outcome_policy"] = []; value["binding"] = []; value["authority"] = []; value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_outcome_record_provenance(value)
        self.assertTrue(any("outcome_policy must exactly" in e for e in errors)); self.assertTrue(any("binding must exactly" in e for e in errors)); self.assertTrue(any("authority must exactly" in e for e in errors)); self.assertTrue(any("evidence[0].kind" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
