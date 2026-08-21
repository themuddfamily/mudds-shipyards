import copy
import unittest

from tools.settings.review.accessibility_runtime_remap_provenance_v165_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    REMAP_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_remap_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-remap-v165",
        "reviewer_required": "human accessibility and remap QA",
        "open_gate_reason": "no human remap review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "mapping_written": False,
        "remap_replayed": False,
        "remap_policy": copy.deepcopy(REMAP_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_input_remap_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeRemapProvenanceV165Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_remap_provenance(_record()), [])

    def test_remap_policy_and_binding_are_exact(self):
        value = _record()
        value["remap_policy"]["invalid_binding"] = "partial_write"
        value["binding"]["write_rule"] = "automatic"
        errors = validate_runtime_remap_provenance(value)
        self.assertTrue(any("remap_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["remap_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_remap_provenance(value)
        self.assertTrue(any("remap_policy must exactly" in error for error in errors))

    def test_native_and_write_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["mapping_written"] = True
        errors = validate_runtime_remap_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("mapping_written must be false" in error for error in errors))

    def test_remap_authority_fails_closed(self):
        value = _record()
        value["authority"]["remap_authority"] = True
        value["remap_authority"] = True
        errors = validate_runtime_remap_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("remap_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["remap_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_remap_provenance(value)
        self.assertTrue(any("remap_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
