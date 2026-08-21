import copy
import unittest

from tools.settings.review.accessibility_runtime_interruption_provenance_v161_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    INTERRUPTION_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_interruption_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-interruption-v161",
        "reviewer_required": "human accessibility and interruption QA",
        "open_gate_reason": "no human interruption review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "state_overwritten": False,
        "resume_replayed": False,
        "interruption_policy": copy.deepcopy(INTERRUPTION_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_interruption_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeInterruptionProvenanceV161Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_interruption_provenance(_record()), [])

    def test_interruption_policy_and_binding_are_exact(self):
        value = _record()
        value["interruption_policy"]["dropped_event"] = "mutate_authority"
        value["binding"]["state_rule"] = "latest_state"
        errors = validate_runtime_interruption_provenance(value)
        self.assertTrue(any("interruption_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["interruption_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_interruption_provenance(value)
        self.assertTrue(any("interruption_policy must exactly" in error for error in errors))

    def test_native_and_resume_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["resume_replayed"] = True
        errors = validate_runtime_interruption_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("resume_replayed must be false" in error for error in errors))

    def test_interruption_authority_fails_closed(self):
        value = _record()
        value["authority"]["interruption_authority"] = True
        value["interruption_authority"] = True
        errors = validate_runtime_interruption_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("interruption_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["interruption_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_interruption_provenance(value)
        self.assertTrue(any("interruption_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
