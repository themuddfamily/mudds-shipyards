import copy
import unittest

from tools.settings.review.accessibility_runtime_onboarding_provenance_v192_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    ONBOARDING_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_onboarding_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-onboarding-v192",
        "reviewer_required": "human accessibility and onboarding QA",
        "open_gate_reason": "no human onboarding review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "step_written": False,
        "onboarding_replayed": False,
        "onboarding_policy": copy.deepcopy(ONBOARDING_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_onboarding_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeOnboardingProvenanceV192Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_onboarding_provenance(_record()), [])

    def test_onboarding_policy_and_binding_are_exact(self):
        value = _record()
        value["onboarding_policy"]["missing_step"] = "show_secret"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_onboarding_provenance(value)
        self.assertTrue(any("onboarding_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["onboarding_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_onboarding_provenance(value)
        self.assertTrue(any("onboarding_policy must exactly" in error for error in errors))

    def test_native_and_step_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["step_written"] = True
        errors = validate_runtime_onboarding_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("step_written must be false" in error for error in errors))

    def test_onboarding_authority_fails_closed(self):
        value = _record()
        value["authority"]["onboarding_authority"] = True
        value["onboarding_authority"] = True
        errors = validate_runtime_onboarding_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("onboarding_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["onboarding_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_onboarding_provenance(value)
        self.assertTrue(any("onboarding_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
