import copy
import unittest

from tools.settings.review.accessibility_runtime_snapshot_provenance_v123_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SNAPSHOT_FIELDS,
    SNAPSHOT_SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    SCHEMA,
    SCHEMA_VERSION,
    TEXTUAL_PROMPTS,
    validate_runtime_snapshot_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-snapshot-v123",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human snapshot review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "snapshot_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "snapshot_schema_version": SNAPSHOT_SCHEMA_VERSION,
        "snapshot_fields": copy.deepcopy(SNAPSHOT_FIELDS),
        "textual_prompts": copy.deepcopy(TEXTUAL_PROMPTS),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "detached_runtime_snapshot",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeSnapshotProvenanceV123Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_snapshot_provenance(_record()), [])

    def test_snapshot_ownership_and_prompt_keys_are_exact(self):
        value = _record()
        value["snapshot_fields"]["captions"] = "settings_store"
        value["textual_prompts"].remove("refresh")
        errors = validate_runtime_snapshot_provenance(value)
        self.assertTrue(any("snapshot_fields must exactly" in error for error in errors))
        self.assertTrue(any("textual_prompts must exactly" in error for error in errors))

    def test_snapshot_schema_and_binding_are_exact(self):
        value = _record()
        value["snapshot_schema_version"] = 2
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_snapshot_provenance(value)
        self.assertTrue(any("snapshot_schema_version must be 1" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_snapshot_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_authority_fails_closed(self):
        value = _record()
        value["authority"]["caption_queue_authority"] = True
        value["caption_queue_authority"] = True
        errors = validate_runtime_snapshot_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("caption_queue_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["snapshot_fields"] = []
        value["textual_prompts"] = {}
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_snapshot_provenance(value)
        self.assertTrue(any("snapshot_fields must exactly" in error for error in errors))
        self.assertTrue(any("textual_prompts must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
