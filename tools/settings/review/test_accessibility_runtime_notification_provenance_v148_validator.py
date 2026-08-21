import copy
import unittest

from tools.settings.review.accessibility_runtime_notification_provenance_v148_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    NOTIFICATION_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_notification_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-notification-v148",
        "reviewer_required": "human accessibility and UI QA",
        "open_gate_reason": "no human notification review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "notification_policy": copy.deepcopy(NOTIFICATION_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "notification_presentation_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeNotificationProvenanceV148Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_notification_provenance(_record()), [])

    def test_notification_policy_and_binding_are_exact(self):
        value = _record()
        value["notification_policy"]["semantic_text"] = "optional"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_notification_provenance(value)
        self.assertTrue(any("notification_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_dismissal_and_reduced_motion_boundaries_cannot_widen(self):
        value = _record()
        value["notification_policy"]["dismissal"] = "mutate_gameplay"
        value["notification_policy"]["reduced_motion"] = "animate"
        errors = validate_runtime_notification_provenance(value)
        self.assertTrue(any("notification_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_notification_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_notification_authority_fails_closed(self):
        value = _record()
        value["authority"]["notification_authority"] = True
        value["notification_authority"] = True
        errors = validate_runtime_notification_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("notification_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["notification_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_notification_provenance(value)
        self.assertTrue(any("notification_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
