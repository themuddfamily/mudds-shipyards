import copy
import unittest

from tools.settings.review.accessibility_runtime_evidence_index_provenance_v206_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    INDEX_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_evidence_index_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-evidence-index-v206",
        "reviewer_required": "human accessibility and evidence-index QA",
        "open_gate_reason": "no human evidence-index review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "index_written": False,
        "index_replayed": False,
        "index_policy": copy.deepcopy(INDEX_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_evidence_index_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeEvidenceIndexProvenanceV206Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_evidence_index_provenance(_record()), [])

    def test_index_policy_and_binding_are_exact(self):
        value = _record()
        value["index_policy"]["invalid_reference"] = "claim_pass"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_evidence_index_provenance(value)
        self.assertTrue(any("index_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["index_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_evidence_index_provenance(value)
        self.assertTrue(any("index_policy must exactly" in error for error in errors))

    def test_native_and_index_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["index_written"] = True
        errors = validate_runtime_evidence_index_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("index_written must be false" in error for error in errors))

    def test_evidence_index_authority_fails_closed(self):
        value = _record()
        value["authority"]["evidence_index_authority"] = True
        value["evidence_index_authority"] = True
        errors = validate_runtime_evidence_index_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence_index_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["index_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_evidence_index_provenance(value)
        self.assertTrue(any("index_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
