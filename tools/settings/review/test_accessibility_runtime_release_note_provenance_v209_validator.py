import copy
import unittest

from tools.settings.review.accessibility_runtime_release_note_provenance_v209_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    RELEASE_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_release_note_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-release-note-v209",
        "reviewer_required": "human accessibility and release-note QA",
        "open_gate_reason": "no human release-note review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "note_written": False,
        "release_replayed": False,
        "release_policy": copy.deepcopy(RELEASE_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_release_note_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeReleaseNoteProvenanceV209Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_release_note_provenance(_record()), [])

    def test_release_policy_and_binding_are_exact(self):
        value = _record()
        value["release_policy"]["known_limit_policy"] = "hide_unresolved"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_release_note_provenance(value)
        self.assertTrue(any("release_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["release_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_release_note_provenance(value)
        self.assertTrue(any("release_policy must exactly" in error for error in errors))

    def test_native_and_note_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["note_written"] = True
        errors = validate_runtime_release_note_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("note_written must be false" in error for error in errors))

    def test_release_note_authority_fails_closed(self):
        value = _record()
        value["authority"]["release_note_authority"] = True
        value["release_note_authority"] = True
        errors = validate_runtime_release_note_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("release_note_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["release_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_release_note_provenance(value)
        self.assertTrue(any("release_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
