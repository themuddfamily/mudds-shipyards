import copy
import unittest

from tools.settings.review.accessibility_runtime_timeout_provenance_v197_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    TIMEOUT_POLICY,
    validate_runtime_timeout_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-timeout-v197",
        "reviewer_required": "human accessibility and timeout QA",
        "open_gate_reason": "no human timeout review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "timeout_written": False,
        "prompt_replayed": False,
        "timeout_policy": copy.deepcopy(TIMEOUT_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_timeout_prompt_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeTimeoutProvenanceV197Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_timeout_provenance(_record()), [])

    def test_timeout_policy_and_binding_are_exact(self):
        value = _record()
        value["timeout_policy"]["default_choice"] = "extend"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_timeout_provenance(value)
        self.assertTrue(any("timeout_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["timeout_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_timeout_provenance(value)
        self.assertTrue(any("timeout_policy must exactly" in error for error in errors))

    def test_native_and_timeout_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["timeout_written"] = True
        errors = validate_runtime_timeout_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("timeout_written must be false" in error for error in errors))

    def test_timeout_prompt_authority_fails_closed(self):
        value = _record()
        value["authority"]["timeout_prompt_authority"] = True
        value["timeout_prompt_authority"] = True
        errors = validate_runtime_timeout_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("timeout_prompt_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["timeout_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_timeout_provenance(value)
        self.assertTrue(any("timeout_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
