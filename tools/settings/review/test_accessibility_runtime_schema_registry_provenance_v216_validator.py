import copy
import unittest

from tools.settings.review.accessibility_runtime_schema_registry_provenance_v216_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    REGISTRY_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_schema_registry_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-schema-registry-v216",
        "reviewer_required": "human accessibility and schema-registry QA",
        "open_gate_reason": "no human schema-registry review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "registry_written": False,
        "registry_replayed": False,
        "registry_policy": copy.deepcopy(REGISTRY_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_schema_registry_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeSchemaRegistryProvenanceV216Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_schema_registry_provenance(_record()), [])

    def test_registry_policy_and_binding_are_exact(self):
        value = _record()
        value["registry_policy"]["unknown_entry"] = "claim_registered"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_schema_registry_provenance(value)
        self.assertTrue(any("registry_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["registry_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_schema_registry_provenance(value)
        self.assertTrue(any("registry_policy must exactly" in error for error in errors))

    def test_native_and_registry_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["registry_written"] = True
        errors = validate_runtime_schema_registry_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("registry_written must be false" in error for error in errors))

    def test_schema_registry_authority_fails_closed(self):
        value = _record()
        value["authority"]["schema_registry_authority"] = True
        value["schema_registry_authority"] = True
        errors = validate_runtime_schema_registry_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("schema_registry_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["registry_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_schema_registry_provenance(value)
        self.assertTrue(any("registry_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
