import copy
import unittest

from tools.settings.review.accessibility_runtime_invite_prompt_provenance_v188_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    INVITE_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_invite_prompt_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-invite-prompt-v188",
        "reviewer_required": "human accessibility and invite prompt QA",
        "open_gate_reason": "no human invite-prompt review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "invite_written": False,
        "prompt_replayed": False,
        "invite_policy": copy.deepcopy(INVITE_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_invite_prompt_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeInvitePromptProvenanceV188Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_invite_prompt_provenance(_record()), [])

    def test_invite_policy_and_binding_are_exact(self):
        value = _record()
        value["invite_policy"]["default_choice"] = "send"
        value["binding"]["apply_rule"] = "network_write"
        errors = validate_runtime_invite_prompt_provenance(value)
        self.assertTrue(any("invite_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["invite_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_invite_prompt_provenance(value)
        self.assertTrue(any("invite_policy must exactly" in error for error in errors))

    def test_native_and_invite_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["invite_written"] = True
        errors = validate_runtime_invite_prompt_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("invite_written must be false" in error for error in errors))

    def test_invite_prompt_authority_fails_closed(self):
        value = _record()
        value["authority"]["invite_prompt_authority"] = True
        value["invite_prompt_authority"] = True
        errors = validate_runtime_invite_prompt_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("invite_prompt_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["invite_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_invite_prompt_provenance(value)
        self.assertTrue(any("invite_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
