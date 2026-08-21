import copy
import unittest

from tools.settings.review.accessibility_runtime_localization_provenance_v150_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    LOCALIZATION_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_localization_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-localization-v150",
        "reviewer_required": "human accessibility and localization QA",
        "open_gate_reason": "no human localization review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "localization_policy": copy.deepcopy(LOCALIZATION_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "localized_semantic_text",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeLocalizationProvenanceV150Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_localization_provenance(_record()), [])

    def test_localization_policy_and_binding_are_exact(self):
        value = _record()
        value["localization_policy"]["missing_translation"] = "empty"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_localization_provenance(value)
        self.assertTrue(any("localization_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_rtl_and_text_boundaries_cannot_be_removed(self):
        value = _record()
        value["localization_policy"]["rtl_layout"] = "ignore"
        value["localization_policy"]["maximum_text_characters"] = 4096
        errors = validate_runtime_localization_provenance(value)
        self.assertTrue(any("localization_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_localization_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_localization_authority_fails_closed(self):
        value = _record()
        value["authority"]["localization_authority"] = True
        value["localization_authority"] = True
        errors = validate_runtime_localization_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("localization_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["localization_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_localization_provenance(value)
        self.assertTrue(any("localization_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
