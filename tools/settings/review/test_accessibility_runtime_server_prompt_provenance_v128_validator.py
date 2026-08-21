import copy
import unittest

from tools.settings.review.accessibility_runtime_server_prompt_provenance_v128_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PROMPTS,
    ROW_FIELDS,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_server_prompt_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-server-prompt-v128",
        "reviewer_required": "human accessibility and multiplayer UI QA",
        "open_gate_reason": "no human server-browser review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "prompt_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "prompts": copy.deepcopy(PROMPTS),
        "row_fields": copy.deepcopy(ROW_FIELDS),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "server_browser_presenter",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeServerPromptProvenanceV128Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_server_prompt_provenance(_record()), [])

    def test_prompts_and_row_fields_are_exact(self):
        value = _record()
        value["prompts"]["refresh"] = "Join now"
        value["row_fields"]["stale"] = "join_authority"
        errors = validate_runtime_server_prompt_provenance(value)
        self.assertTrue(any("prompts must exactly" in error for error in errors))
        self.assertTrue(any("row_fields must exactly" in error for error in errors))

    def test_join_and_stale_binding_are_exact(self):
        value = _record()
        value["binding"]["join_authority"] = "presenter"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_server_prompt_provenance(value)
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_server_prompt_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_join_and_network_authority_fail_closed(self):
        value = _record()
        value["authority"]["join_authority"] = True
        value["join_authority"] = True
        errors = validate_runtime_server_prompt_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("join_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["prompts"] = []
        value["row_fields"] = {}
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_server_prompt_provenance(value)
        self.assertTrue(any("prompts must exactly" in error for error in errors))
        self.assertTrue(any("row_fields must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
