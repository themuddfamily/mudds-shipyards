import copy
import unittest

from tools.settings.review.accessibility_caption_stale_authority_generation_summary_validator import (
    AUTHORITY_CLAIMS,
    GENERATION_CLAIMS,
    REQUIRED_SECTIONS,
    SOURCE_SCHEMA,
    SUMMARY_COUNTS,
    validate_summary,
)


def _summary() -> dict:
    return {
        "schema": "accessibility_caption_stale_authority_generation_summary_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-stale-authority-summary",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "consumer_boundary": "caption presentation snapshot consumer",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human stale-authority summary review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "authority": copy.deepcopy(AUTHORITY_CLAIMS),
        "generation": copy.deepcopy(GENERATION_CLAIMS),
        "counts": copy.deepcopy(SUMMARY_COUNTS),
        "sections": list(REQUIRED_SECTIONS),
        "coverage": {"scenarios": "all_planned", "checks": "all_planned", "human_review": "not_performed", "native_render": "not_run"},
        "gate": {"status": "not_performed", "review_required": True, "native_render_required": True},
        "evidence": None,
        "stale_payload_mutation": False,
        **AUTHORITY_CLAIMS,
    }


class AccessibilityCaptionStaleAuthorityGenerationSummaryTests(unittest.TestCase):
    def test_complete_source_only_summary_keeps_gate_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_authority_generation_and_counts_are_exact(self):
        value = _summary()
        value["authority"]["audio_authority"] = True
        value["generation"]["reset_step"] = 2
        value["counts"]["observed_count"] = 1
        errors = validate_summary(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("generation must exactly" in error for error in errors))
        self.assertTrue(any("counts must exactly" in error for error in errors))

    def test_coverage_and_gate_cannot_claim_completion(self):
        value = _summary()
        value["coverage"]["human_review"] = "observed"
        value["coverage"]["native_render"] = "complete"
        value["gate"]["status"] = "complete"
        value["gate"]["review_required"] = False
        errors = validate_summary(value)
        self.assertTrue(any("coverage.human_review" in error for error in errors))
        self.assertTrue(any("coverage.native_render" in error for error in errors))
        self.assertTrue(any("gate.status" in error for error in errors))
        self.assertTrue(any("gate.review_required" in error for error in errors))

    def test_evidence_digest_is_validated(self):
        value = _summary()
        value["evidence"] = [{"kind": "report", "path": "reports/caption-summary.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_identity_and_open_status_fail_closed(self):
        value = _summary()
        value["source_schema"] = "other"
        value["human_review_status"] = "complete"
        value["service_id"] = "other-service"
        errors = validate_summary(value)
        self.assertTrue(any("source_schema must" in error for error in errors))
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("service_id must identify" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["authority"] = []
        value["generation"] = {}
        value["coverage"] = []
        value["gate"] = []
        errors = validate_summary(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("generation must exactly" in error for error in errors))
        self.assertTrue(any("coverage must be an object" in error for error in errors))
        self.assertTrue(any("gate must be an object" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
