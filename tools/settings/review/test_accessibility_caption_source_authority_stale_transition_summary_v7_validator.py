import copy
import unittest

from tools.settings.review.accessibility_caption_source_authority_stale_transition_summary_v7_validator import (
    AUTHORITY,
    SOURCE_SCHEMA,
    TRANSITION_IDS,
    TRANSITION_RULES,
    validate_summary,
)


def _summary() -> dict:
    transitions = [{
        "id": transition_id,
        "source": TRANSITION_RULES[transition_id]["source"],
        "target": TRANSITION_RULES[transition_id]["target"],
        "reason": TRANSITION_RULES[transition_id]["reason"],
        "expected_behavior": f"The {transition_id} source-authority transition remains deterministic.",
    } for transition_id in TRANSITION_IDS]
    return {
        "schema": "accessibility_caption_source_authority_stale_transition_summary_v7_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-transition-v7",
        "summary_path": "reports/caption-source-authority-transition-v7.json",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v7 transition review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v7",
        "status": "planned",
        "digest": "0" * 64,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "generation_policy": "monotonic_reset_increment",
        "stale_policy": "reject_less_or_greater_generation",
        "authority": copy.deepcopy(AUTHORITY),
        "transitions": transitions,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionSourceAuthorityStaleTransitionV7Tests(unittest.TestCase):
    def test_complete_summary_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_native_render_must_remain_not_run(self):
        value = _summary()
        value["native_render_status"] = "planned"
        errors = validate_summary(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_transition_rules_and_policies_are_exact(self):
        value = _summary()
        value["transitions"][1]["reason"] = "accepted"
        value["generation_policy"] = "consumer_owned"
        value["stale_policy"] = "accept_old"
        errors = validate_summary(value)
        self.assertTrue(any("transitions[1].reason" in error for error in errors))
        self.assertTrue(any("generation_policy must" in error for error in errors))
        self.assertTrue(any("stale_policy must" in error for error in errors))

    def test_stale_and_authority_boundaries_fail_closed(self):
        value = _summary()
        value["stale_payload_mutation"] = True
        value["audio_authority"] = True
        value["authority"]["settings_authority"] = True
        errors = validate_summary(value)
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _summary()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/transition-v7.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["transitions"] = []
        value["authority"] = []
        errors = validate_summary(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("exactly five ordered" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
