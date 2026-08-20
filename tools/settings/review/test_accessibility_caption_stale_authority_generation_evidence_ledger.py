import copy
import unittest

from tools.settings.review.accessibility_caption_stale_authority_generation_evidence_ledger import (
    LIMITS,
    REQUIRED_CHECKS,
    SCENARIO_IDS,
    SCENARIO_RULES,
    validate_ledger,
)


def _ledger() -> dict:
    scenarios = [{
        "id": scenario_id,
        "generation_relation": SCENARIO_RULES[scenario_id]["generation_relation"],
        "result": SCENARIO_RULES[scenario_id]["result"],
        "reason": SCENARIO_RULES[scenario_id]["reason"],
        "authority": SCENARIO_RULES[scenario_id]["authority"],
        "expected_behavior": f"The {scenario_id} stale-authority scenario remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for scenario_id in SCENARIO_IDS]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} stale-authority check remains deterministic.",
        "source_test": "tests/caption_presentation_service_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_caption_stale_authority_generation_evidence_v1",
        "source_revision": "working-tree-caption-stale-authority-generation-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "consumer_boundary": "caption presentation snapshot consumer",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human stale-authority generation review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "stale_payload_mutation": False,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "generation_owner": "caption-presentation-service",
        "authority_owner": "caption-accessibility-contract",
        "stale_rejection_owner": "caption_consumer_boundary",
        "generation_policy": "monotonic_reset_increment",
        "authority_policy": "presentation_only",
        "rejection_policy": "stale_generation_or_authority_boundary",
        "limits": copy.deepcopy(LIMITS),
        "scenarios": scenarios,
        "checks": checks,
    }


class AccessibilityCaptionStaleAuthorityGenerationTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_scenario_rules_and_policies_are_exact(self):
        value = _ledger()
        value["scenarios"][1]["reason"] = "accepted"
        value["generation_policy"] = "consumer_owned"
        value["authority_policy"] = "audio_owned"
        value["rejection_policy"] = "accept_all"
        value["limits"]["generation_step_after_reset"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("scenarios[1].reason" in error for error in errors))
        self.assertTrue(any("generation_policy must" in error for error in errors))
        self.assertTrue(any("authority_policy must" in error for error in errors))
        self.assertTrue(any("rejection_policy must" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))

    def test_ownership_and_mutation_claims_fail_closed(self):
        value = _ledger()
        value["generation_owner"] = "caption_consumer_boundary"
        value["authority_owner"] = "audio_system"
        value["stale_rejection_owner"] = "service"
        value["stale_payload_mutation"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("generation_owner must" in error for error in errors))
        self.assertTrue(any("authority_owner must" in error for error in errors))
        self.assertTrue(any("stale_rejection_owner must" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_observed_scenario_requires_valid_evidence_digest(self):
        value = _ledger()
        value["scenarios"][1]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("scenarios[1].evidence must be null" in error for error in errors))
        value["scenarios"][1]["evidence"] = [{"kind": "report", "path": "reports/caption-stale-authority-generation.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_authority_and_render_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["audio_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("audio_authority" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["scenarios"][1] = {"id": {}, "generation_relation": [], "result": {}, "reason": [], "authority": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("scenarios[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
