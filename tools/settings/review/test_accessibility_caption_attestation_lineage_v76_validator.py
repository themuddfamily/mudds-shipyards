import copy
import unittest

from tools.settings.review.accessibility_caption_attestation_lineage_v76_validator import (
    ATTESTATION_CHECKS,
    ATTESTATION_ID,
    ATTESTATION_LINEAGE,
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PREVIOUS_VERSION,
    SCHEMA_VERSION,
    SOURCE_CLOSURE_ID,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_attestation_lineage,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_attestation_lineage_v76_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-attestation-v76",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v76 attestation/lineage review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "attestation_claimed": False,
        "lineage_verified": False,
        "attestation_verified": False,
        "stale_payload_mutation": False,
        "binding": copy.deepcopy(BINDING),
        "attestation_lineage": copy.deepcopy(ATTESTATION_LINEAGE),
        "attestation_checks": copy.deepcopy(ATTESTATION_CHECKS),
        "authority": copy.deepcopy(AUTHORITY),
        "attestation_id": ATTESTATION_ID,
        "attestation_status": "unverified",
        "lineage_status": "unverified",
        "lineage_mode": "exact",
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "source_closure_id": SOURCE_CLOSURE_ID,
        "source_closure_status": "open",
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


class AccessibilityCaptionAttestationLineageV76Tests(unittest.TestCase):
    def test_complete_record_keeps_attestation_unverified_and_native_gate_closed(self):
        self.assertEqual(validate_attestation_lineage(_record()), [])

    def test_v75_source_chain_is_exact(self):
        value = _record()
        value["source_schema"] = "accessibility_caption_source_closure_v74_evidence_v1"
        value["source_closure_id"] = "caption-accessibility-source-v74"
        value["attestation_lineage"]["previous_version"] = "v74"
        errors = validate_attestation_lineage(value)
        self.assertTrue(any("source_schema must be" in error for error in errors))
        self.assertTrue(any("source_closure_id must be" in error for error in errors))
        self.assertTrue(any("attestation_lineage must exactly" in error for error in errors))

    def test_human_native_and_attestation_gates_remain_open(self):
        value = _record()
        value["native_render_status"] = "planned"
        value["human_review_performed"] = True
        value["attestation_claimed"] = True
        errors = validate_attestation_lineage(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("attestation_claimed must be false" in error for error in errors))

    def test_authority_and_stale_policy_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_attestation_lineage(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_attestation_checks_are_exact(self):
        value = _record()
        value["attestation_checks"]["attestation_owner"] = False
        value["lineage_mode"] = "best_effort"
        errors = validate_attestation_lineage(value)
        self.assertTrue(any("attestation_checks must exactly" in error for error in errors))
        self.assertTrue(any("lineage_mode must be exact" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v76.json", "sha256": "bad"}]
        errors = validate_attestation_lineage(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["binding"] = []
        value["attestation_lineage"] = []
        value["attestation_checks"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_attestation_lineage(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("attestation_lineage must exactly" in error for error in errors))
        self.assertTrue(any("attestation_checks must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
