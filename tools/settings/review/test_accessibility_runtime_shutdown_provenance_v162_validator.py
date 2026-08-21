import copy
import unittest

from tools.settings.review.accessibility_runtime_shutdown_provenance_v162_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SHUTDOWN_POLICY,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_shutdown_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-shutdown-v162",
        "reviewer_required": "human accessibility and shutdown QA",
        "open_gate_reason": "no human shutdown review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "authority_mutated": False,
        "teardown_replayed": False,
        "shutdown_policy": copy.deepcopy(SHUTDOWN_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_shutdown_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeShutdownProvenanceV162Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_shutdown_provenance(_record()), [])

    def test_shutdown_policy_and_binding_are_exact(self):
        value = _record()
        value["shutdown_policy"]["pending_caption_policy"] = "replay"
        value["binding"]["teardown_rule"] = "multiple_release"
        errors = validate_runtime_shutdown_provenance(value)
        self.assertTrue(any("shutdown_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["shutdown_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_shutdown_provenance(value)
        self.assertTrue(any("shutdown_policy must exactly" in error for error in errors))

    def test_native_and_teardown_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["teardown_replayed"] = True
        errors = validate_runtime_shutdown_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("teardown_replayed must be false" in error for error in errors))

    def test_shutdown_authority_fails_closed(self):
        value = _record()
        value["authority"]["shutdown_authority"] = True
        value["shutdown_authority"] = True
        errors = validate_runtime_shutdown_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("shutdown_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["shutdown_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_shutdown_provenance(value)
        self.assertTrue(any("shutdown_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
