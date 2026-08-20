import copy
import unittest

from tools.settings.review.accessibility_caption_generation_authority_stale_evidence_ledger import (
    LIMITS,
    PHASE_IDS,
    PHASE_RULES,
    REQUIRED_CHECKS,
    validate_ledger,
)


def _ledger() -> dict:
    phases = [{
        "id": phase_id,
        "relation": PHASE_RULES[phase_id]["relation"],
        "result": PHASE_RULES[phase_id]["result"],
        "reason": PHASE_RULES[phase_id]["reason"],
        "authority": PHASE_RULES[phase_id]["authority"],
        "expected_behavior": f"The {phase_id} generation-authority phase remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for phase_id in PHASE_IDS]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} generation-authority check remains deterministic.",
        "source_test": "tests/caption_presentation_service_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_caption_generation_authority_stale_evidence_v1",
        "source_revision": "working-tree-caption-generation-authority-stale-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "consumer_boundary": "caption presentation snapshot consumer",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human generation-authority stale review or native render has been performed",
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
        "stale_policy": "reject_less_or_greater_generation",
        "limits": copy.deepcopy(LIMITS),
        "phases": phases,
        "checks": checks,
    }


class AccessibilityCaptionGenerationAuthorityStaleTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_phase_rules_and_policies_are_exact(self):
        value = _ledger()
        value["phases"][2]["reason"] = "accepted"
        value["generation_policy"] = "consumer_owned"
        value["authority_policy"] = "audio_owned"
        value["stale_policy"] = "accept_all"
        value["limits"]["generation_step_after_reset"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("phases[2].reason" in error for error in errors))
        self.assertTrue(any("generation_policy must" in error for error in errors))
        self.assertTrue(any("authority_policy must" in error for error in errors))
        self.assertTrue(any("stale_policy must" in error for error in errors))
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

    def test_observed_phase_requires_valid_evidence_digest(self):
        value = _ledger()
        value["phases"][2]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("phases[2].evidence must be null" in error for error in errors))
        value["phases"][2]["evidence"] = [{"kind": "report", "path": "reports/caption-generation-authority-stale.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_identity_and_render_claims_fail_closed(self):
        value = _ledger()
        value["service_id"] = "other-service"
        value["contract_id"] = "other-contract"
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("service_id must identify" in error for error in errors))
        self.assertTrue(any("contract_id must identify" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["phases"][1] = {"id": {}, "relation": [], "result": {}, "reason": [], "authority": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("phases[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
