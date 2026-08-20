import copy
import unittest

from tools.settings.review.accessibility_caption_traceability_gate_v67_validator import (
    AUTHORITY,
    CONTRACT_ID,
    GATE,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_READINESS_ID,
    SOURCE_SCHEMA,
    TRACEABILITY,
    TRACEABILITY_CHECKS,
    TRACEABILITY_ID,
    validate_traceability_gate,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_traceability_gate_v67_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-traceability-v67",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v67 traceability/gate review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "traceability_verified": False,
        "gate_closed": False,
        "stale_payload_mutation": False,
        "gate": copy.deepcopy(GATE),
        "traceability": copy.deepcopy(TRACEABILITY),
        "traceability_checks": copy.deepcopy(TRACEABILITY_CHECKS),
        "authority": copy.deepcopy(AUTHORITY),
        "traceability_id": TRACEABILITY_ID,
        "gate_status": "open",
        "traceability_mode": "exact",
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "source_readiness_id": SOURCE_READINESS_ID,
        "source_readiness_status": "open",
        "contract_id": CONTRACT_ID,
        "contract_mode": "exact",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "provenance_source_of_truth": "presentation_only",
        "status": "planned",
        "authority_owner": SOURCE_ID,
        "generation_owner": SOURCE_ID,
        "service_id": SOURCE_ID,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionTraceabilityGateV67Tests(unittest.TestCase):
    def test_complete_record_keeps_gate_open_and_native_gate_closed(self):
        self.assertEqual(validate_traceability_gate(_record()), [])

    def test_v66_source_chain_is_exact(self):
        value = _record()
        value["source_schema"] = "accessibility_caption_readiness_consistency_v65_evidence_v1"
        value["source_readiness_id"] = "caption-accessibility-readiness-v65"
        value["traceability"]["previous_version"] = "v65"
        errors = validate_traceability_gate(value)
        self.assertTrue(any("source_schema must be" in error for error in errors))
        self.assertTrue(any("source_readiness_id must be" in error for error in errors))
        self.assertTrue(any("traceability must exactly" in error for error in errors))

    def test_human_and_native_gates_remain_open(self):
        value = _record()
        value["native_render_status"] = "planned"
        value["human_review_performed"] = True
        value["gate_closed"] = True
        errors = validate_traceability_gate(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("gate_closed must be false" in error for error in errors))

    def test_authority_and_stale_policy_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["gate"]["stale_policy"] = "accept_old"
        errors = validate_traceability_gate(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))
        self.assertTrue(any("gate must exactly" in error for error in errors))

    def test_traceability_checks_are_exact(self):
        value = _record()
        value["traceability_checks"]["native_boundary"] = False
        value["traceability_mode"] = "best_effort"
        errors = validate_traceability_gate(value)
        self.assertTrue(any("traceability_checks must exactly" in error for error in errors))
        self.assertTrue(any("traceability_mode must be exact" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v67.json", "sha256": "bad"}]
        errors = validate_traceability_gate(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["gate"] = []
        value["traceability"] = []
        value["traceability_checks"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_traceability_gate(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("gate must exactly" in error for error in errors))
        self.assertTrue(any("traceability must exactly" in error for error in errors))
        self.assertTrue(any("traceability_checks must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
