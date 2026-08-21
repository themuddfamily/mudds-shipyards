import copy
import unittest

from tools.settings.review.accessibility_runtime_cue_provenance_v124_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    CUE_FIELDS,
    FALLBACK_CHANNELS,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_cue_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-cue-v124",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human cue review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "cue_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "cue_fields": copy.deepcopy(CUE_FIELDS),
        "fallback_channels": copy.deepcopy(FALLBACK_CHANNELS),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "caller_observation",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeCueProvenanceV124Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_cue_provenance(_record()), [])

    def test_cue_ownership_and_fallback_channels_are_exact(self):
        value = _record()
        value["cue_fields"]["text"] = "settings_store"
        value["fallback_channels"] = ["captions"]
        errors = validate_runtime_cue_provenance(value)
        self.assertTrue(any("cue_fields must exactly" in error for error in errors))
        self.assertTrue(any("fallback_channels must exactly" in error for error in errors))

    def test_binding_and_stale_policy_are_exact(self):
        value = _record()
        value["binding"]["stale_policy"] = "accept_old"
        value["stale_payload_mutation"] = True
        errors = validate_runtime_cue_provenance(value)
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_cue_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_authority_fails_closed(self):
        value = _record()
        value["authority"]["caption_queue_authority"] = True
        value["caption_queue_authority"] = True
        errors = validate_runtime_cue_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("caption_queue_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["cue_fields"] = []
        value["fallback_channels"] = {}
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_cue_provenance(value)
        self.assertTrue(any("cue_fields must exactly" in error for error in errors))
        self.assertTrue(any("fallback_channels must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
