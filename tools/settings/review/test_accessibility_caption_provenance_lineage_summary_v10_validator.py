import copy
import unittest

from tools.settings.review.accessibility_caption_provenance_lineage_summary_v10_validator import (
    AUTHORITY,
    GENERATION,
    LINEAGE_RULES,
    LINEAGE_STAGES,
    SOURCE_SCHEMA,
    validate_summary,
)


def _summary() -> dict:
    lineage = [{
        "stage": stage,
        "source": LINEAGE_RULES[stage]["source"],
        "parent": LINEAGE_RULES[stage]["parent"],
        "authority": LINEAGE_RULES[stage]["authority"],
        "expected_behavior": f"The {stage} provenance stage remains deterministic.",
    } for stage in LINEAGE_STAGES]
    return {
        "schema": "accessibility_caption_provenance_lineage_summary_v10_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-lineage-v10",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v10 lineage review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v10",
        "status": "planned",
        "digest": "0" * 64,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "generation": copy.deepcopy(GENERATION),
        "authority": copy.deepcopy(AUTHORITY),
        "lineage": lineage,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionProvenanceLineageV10Tests(unittest.TestCase):
    def test_complete_summary_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_lineage_order_and_sources_are_exact(self):
        value = _summary()
        value["lineage"].reverse()
        value["lineage"][0]["source"] = "other.gd"
        errors = validate_summary(value)
        self.assertTrue(any("lineage[0].source" in error for error in errors))
        self.assertTrue(any("lineage must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _summary()
        value["native_render_status"] = "planned"
        errors = validate_summary(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_generation_authority_and_stale_claims_are_exact(self):
        value = _summary()
        value["generation"]["reset_step"] = 2
        value["authority"]["audio_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_summary(value)
        self.assertTrue(any("generation must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _summary()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/lineage-v10.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["lineage"] = []
        value["authority"] = []
        errors = validate_summary(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("exactly three ordered" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
