import copy
import unittest

from tools.settings.review.accessibility_runtime_privacy_provenance_v154_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PRIVACY_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_privacy_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-privacy-v154",
        "reviewer_required": "human accessibility and privacy QA",
        "open_gate_reason": "no human privacy review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "privacy_policy": copy.deepcopy(PRIVACY_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "privacy_bounded_presentation",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimePrivacyProvenanceV154Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_privacy_provenance(_record()), [])

    def test_privacy_policy_and_binding_are_exact(self):
        value = _record()
        value["privacy_policy"]["caption_text"] = "collect"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_privacy_provenance(value)
        self.assertTrue(any("privacy_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_identity_and_profile_payload_boundaries_cannot_widen(self):
        value = _record()
        value["privacy_policy"]["user_identity"] = "hashed_identity"
        value["privacy_policy"]["profile_payload"] = "collect"
        errors = validate_runtime_privacy_provenance(value)
        self.assertTrue(any("privacy_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_privacy_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_telemetry_authority_fails_closed(self):
        value = _record()
        value["authority"]["telemetry_authority"] = True
        value["telemetry_authority"] = True
        errors = validate_runtime_privacy_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("telemetry_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["privacy_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_privacy_provenance(value)
        self.assertTrue(any("privacy_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
