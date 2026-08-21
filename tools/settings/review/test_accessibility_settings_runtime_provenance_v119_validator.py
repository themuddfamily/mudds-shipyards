import copy
import unittest

from tools.settings.review.accessibility_settings_runtime_provenance_v119_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PROFILE_OWNER,
    PROVENANCE,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_FILES,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_settings_runtime_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-settings-runtime-v119",
        "reviewer_required": "human accessibility and settings QA",
        "open_gate_reason": "no human settings handoff review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "handoff_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "provenance": copy.deepcopy(PROVENANCE),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_files": copy.deepcopy(SOURCE_FILES),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "profile_owner": PROFILE_OWNER,
        "provenance_source_of_truth": "retained_settings_profile",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilitySettingsRuntimeProvenanceV119Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_settings_runtime_provenance(_record()), [])

    def test_provenance_and_binding_are_exact(self):
        value = _record()
        value["provenance"]["migration_boundary"] = "best_effort"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_settings_runtime_provenance(value)
        self.assertTrue(any("provenance must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_settings_runtime_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_read_write_authority_fails_closed(self):
        value = _record()
        value["authority"]["settings_write_authority"] = True
        value["settings_write_authority"] = True
        errors = validate_settings_runtime_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("settings_write_authority must be false" in error for error in errors))

    def test_source_chain_and_evidence_are_bounded(self):
        value = _record()
        value["source_files"] = SOURCE_FILES[:-1]
        value["evidence"] = [{"kind": "report", "path": "reports/v119.json", "sha256": "bad"}]
        errors = validate_settings_runtime_provenance(value)
        self.assertTrue(any("source_files must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["provenance"] = []
        value["binding"] = []
        value["authority"] = []
        value["source_files"] = {}
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_settings_runtime_provenance(value)
        self.assertTrue(any("provenance must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("source_files must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
