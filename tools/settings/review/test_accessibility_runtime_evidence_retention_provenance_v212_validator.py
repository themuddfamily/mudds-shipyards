import copy
import unittest

from tools.settings.review.accessibility_runtime_evidence_retention_provenance_v212_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    RETENTION_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_evidence_retention_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-evidence-retention-v212",
        "reviewer_required": "human accessibility and evidence-retention QA",
        "open_gate_reason": "no human evidence-retention review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "retention_written": False,
        "expiry_replayed": False,
        "retention_policy": copy.deepcopy(RETENTION_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_evidence_retention_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeEvidenceRetentionProvenanceV212Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_evidence_retention_provenance(_record()), [])

    def test_retention_policy_and_binding_are_exact(self):
        value = _record()
        value["retention_policy"]["expired_reference"] = "replay"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_evidence_retention_provenance(value)
        self.assertTrue(any("retention_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["retention_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_evidence_retention_provenance(value)
        self.assertTrue(any("retention_policy must exactly" in error for error in errors))

    def test_native_and_retention_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["retention_written"] = True
        errors = validate_runtime_evidence_retention_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("retention_written must be false" in error for error in errors))

    def test_evidence_retention_authority_fails_closed(self):
        value = _record()
        value["authority"]["evidence_retention_authority"] = True
        value["evidence_retention_authority"] = True
        errors = validate_runtime_evidence_retention_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence_retention_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["retention_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_evidence_retention_provenance(value)
        self.assertTrue(any("retention_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
