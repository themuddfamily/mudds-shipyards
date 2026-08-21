import copy
import unittest

from tools.settings.review.accessibility_runtime_handoff_receipt_provenance_v223_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    RECEIPT_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_handoff_receipt_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-handoff-receipt-v223",
        "reviewer_required": "human accessibility and handoff-receipt QA",
        "open_gate_reason": "no human handoff-receipt review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "receipt_written": False,
        "receipt_replayed": False,
        "receipt_policy": copy.deepcopy(RECEIPT_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_handoff_receipt_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeHandoffReceiptProvenanceV223Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_handoff_receipt_provenance(_record()), [])

    def test_receipt_policy_and_binding_are_exact(self):
        value = _record()
        value["receipt_policy"]["missing_artifact"] = "claim_complete"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_handoff_receipt_provenance(value)
        self.assertTrue(any("receipt_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["receipt_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_handoff_receipt_provenance(value)
        self.assertTrue(any("receipt_policy must exactly" in error for error in errors))

    def test_native_and_receipt_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["receipt_written"] = True
        errors = validate_runtime_handoff_receipt_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("receipt_written must be false" in error for error in errors))

    def test_handoff_receipt_authority_fails_closed(self):
        value = _record()
        value["authority"]["handoff_receipt_authority"] = True
        value["handoff_receipt_authority"] = True
        errors = validate_runtime_handoff_receipt_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("handoff_receipt_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["receipt_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_handoff_receipt_provenance(value)
        self.assertTrue(any("receipt_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
