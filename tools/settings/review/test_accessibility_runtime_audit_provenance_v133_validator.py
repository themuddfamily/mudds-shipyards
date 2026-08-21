import copy
import unittest

from tools.settings.review.accessibility_runtime_audit_provenance_v133_validator import (
    AUDIT_BOUNDARY,
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_audit_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-audit-v133",
        "reviewer_required": "human accessibility QA",
        "open_gate_reason": "no human or native accessibility audit has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "audit_verified": False,
        "release_claimed": False,
        "stale_payload_mutation": False,
        "audit_boundary": copy.deepcopy(AUDIT_BOUNDARY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "bounded_automated_evidence",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeAuditProvenanceV133Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_audit_provenance(_record()), [])

    def test_audit_boundary_and_binding_are_exact(self):
        value = _record()
        value["audit_boundary"]["automated_scope"] = "release_certification"
        value["binding"]["audit_mode"] = "unbounded"
        errors = validate_runtime_audit_provenance(value)
        self.assertTrue(any("audit_boundary must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_human_and_native_claims_must_remain_open(self):
        value = _record()
        value["human_review_performed"] = True
        value["release_claimed"] = True
        errors = validate_runtime_audit_provenance(value)
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("release_claimed must be false" in error for error in errors))

    def test_native_status_must_remain_not_run(self):
        value = _record()
        value["native_render_status"] = "passed"
        errors = validate_runtime_audit_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_authority_fails_closed(self):
        value = _record()
        value["authority"]["audio_playback"] = True
        value["audio_playback"] = True
        errors = validate_runtime_audit_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_playback must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["audit_boundary"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_audit_provenance(value)
        self.assertTrue(any("audit_boundary must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
