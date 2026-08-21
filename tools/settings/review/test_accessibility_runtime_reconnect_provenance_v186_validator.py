import copy
import unittest

from tools.settings.review.accessibility_runtime_reconnect_provenance_v186_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    RECONNECT_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_reconnect_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-reconnect-v186",
        "reviewer_required": "human accessibility and reconnect QA",
        "open_gate_reason": "no human reconnect review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "retry_started": False,
        "prompt_replayed": False,
        "reconnect_policy": copy.deepcopy(RECONNECT_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_reconnect_prompt_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeReconnectProvenanceV186Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_reconnect_provenance(_record()), [])

    def test_reconnect_policy_and_binding_are_exact(self):
        value = _record()
        value["reconnect_policy"]["default_choice"] = "retry"
        value["binding"]["apply_rule"] = "network_write"
        errors = validate_runtime_reconnect_provenance(value)
        self.assertTrue(any("reconnect_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["reconnect_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_reconnect_provenance(value)
        self.assertTrue(any("reconnect_policy must exactly" in error for error in errors))

    def test_native_and_retry_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["retry_started"] = True
        errors = validate_runtime_reconnect_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("retry_started must be false" in error for error in errors))

    def test_reconnect_prompt_authority_fails_closed(self):
        value = _record()
        value["authority"]["reconnect_prompt_authority"] = True
        value["reconnect_prompt_authority"] = True
        errors = validate_runtime_reconnect_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("reconnect_prompt_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["reconnect_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_reconnect_provenance(value)
        self.assertTrue(any("reconnect_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
