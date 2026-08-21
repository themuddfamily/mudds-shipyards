import copy
import unittest

from tools.settings.review.accessibility_runtime_profile_provenance_v120_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    DIMENSION_OWNERS,
    PROFILE_OWNER,
    PROVENANCE,
    REQUIRED_DIMENSIONS,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_profile_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-accessibility-profile-v120",
        "reviewer_required": "human accessibility and settings QA",
        "open_gate_reason": "no human profile coverage review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "provenance_verified": False,
        "profile_claimed": False,
        "stale_payload_mutation": False,
        "required_dimensions": copy.deepcopy(REQUIRED_DIMENSIONS),
        "dimension_owners": copy.deepcopy(DIMENSION_OWNERS),
        "dimension_evidence": {dimension: [f"artifacts/settings/{dimension}.json"] for dimension in REQUIRED_DIMENSIONS},
        "provenance": copy.deepcopy(PROVENANCE),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "profile_owner": PROFILE_OWNER,
        "provenance_source_of_truth": "settings_accessibility_matrix",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeProfileProvenanceV120Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_profile_provenance(_record()), [])

    def test_dimension_owners_and_provenance_are_exact(self):
        value = _record()
        value["dimension_owners"]["captions"] = "settings_store"
        value["provenance"]["coverage_mode"] = "best_effort"
        errors = validate_runtime_profile_provenance(value)
        self.assertTrue(any("dimension_owners must exactly" in error for error in errors))
        self.assertTrue(any("provenance must exactly" in error for error in errors))

    def test_native_and_profile_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["profile_claimed"] = True
        errors = validate_runtime_profile_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("profile_claimed must be false" in error for error in errors))

    def test_dimension_evidence_is_required(self):
        value = _record()
        value["dimension_evidence"]["captions"] = []
        value["dimension_evidence"].pop("audio_fallback")
        errors = validate_runtime_profile_provenance(value)
        self.assertTrue(any("dimension_evidence.captions must be" in error for error in errors))
        self.assertTrue(any("dimension_evidence.audio_fallback must be" in error for error in errors))

    def test_non_presentation_authority_fails_closed(self):
        value = _record()
        value["authority"]["settings_write_authority"] = True
        value["settings_write_authority"] = True
        errors = validate_runtime_profile_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("settings_write_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["required_dimensions"] = {}
        value["dimension_owners"] = []
        value["provenance"] = []
        value["binding"] = []
        value["authority"] = []
        errors = validate_runtime_profile_provenance(value)
        self.assertTrue(any("required_dimensions must exactly" in error for error in errors))
        self.assertTrue(any("dimension_owners must exactly" in error for error in errors))
        self.assertTrue(any("provenance must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
