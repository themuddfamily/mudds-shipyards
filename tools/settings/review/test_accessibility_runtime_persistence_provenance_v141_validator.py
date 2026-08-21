import copy
import unittest

from tools.settings.review.accessibility_runtime_persistence_provenance_v141_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PERSISTENCE_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_persistence_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-persistence-v141",
        "reviewer_required": "human accessibility and settings QA",
        "open_gate_reason": "no human persistence recovery review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "persistence_policy": copy.deepcopy(PERSISTENCE_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "validated_persistence_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimePersistenceProvenanceV141Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_persistence_provenance(_record()), [])

    def test_persistence_policy_and_binding_are_exact(self):
        value = _record()
        value["persistence_policy"]["write_mode"] = "in_place"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_persistence_provenance(value)
        self.assertTrue(any("persistence_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_corrupt_newer_and_secret_logging_boundaries_cannot_widen(self):
        value = _record()
        value["persistence_policy"]["corrupt_data"] = "overwrite_backup"
        value["persistence_policy"]["newer_schema"] = "downgrade"
        value["persistence_policy"]["crash_log"] = "full_payload"
        errors = validate_runtime_persistence_provenance(value)
        self.assertTrue(any("persistence_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_persistence_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_persistence_authority_fails_closed(self):
        value = _record()
        value["authority"]["persistence_write_authority"] = True
        value["persistence_write_authority"] = True
        errors = validate_runtime_persistence_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("persistence_write_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["persistence_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_persistence_provenance(value)
        self.assertTrue(any("persistence_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
