import copy
import unittest

from tools.settings.review.accessibility_caption_generation_authority_stale_guard_validator import (
    CHECK_IDS,
    CHECK_RULES,
    GUARD_INPUTS,
    LIMITS,
    validate_ledger,
)


def _ledger() -> dict:
    checks = [{
        "id": check_id,
        "expected_result": CHECK_RULES[check_id]["result"],
        "expected_reason": CHECK_RULES[check_id]["reason"],
        "expected_mutation": CHECK_RULES[check_id]["mutation"],
        "expected_behavior": f"The {check_id} generation/authority guard remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for check_id in CHECK_IDS]
    return {
        "schema": "accessibility_caption_generation_authority_stale_guard_evidence_v1",
        "source_revision": "working-tree-caption-generation-authority-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "boundary_source": "scripts/ui/caption_accessibility_contract.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption generation/authority guard review or native render has been performed",
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
        "guard_inputs": list(GUARD_INPUTS),
        "acceptance_predicate": "generation_current_and_revision_current_and_presentation_only",
        "stale_predicate": "generation_or_revision_mismatch",
        "authority_rejection_reason": "authority_boundary",
        "reset_generation_step": 1,
        "limits": copy.deepcopy(LIMITS),
        "checks": checks,
    }


class AccessibilityCaptionGenerationAuthorityStaleGuardTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_guard_inputs_and_predicates_are_exact(self):
        value = _ledger()
        value["guard_inputs"] = ["generation"]
        value["acceptance_predicate"] = "accept_any"
        value["stale_predicate"] = "never_stale"
        value["reset_generation_step"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("guard_inputs must exactly" in error for error in errors))
        self.assertTrue(any("acceptance_predicate must" in error for error in errors))
        self.assertTrue(any("stale_predicate must" in error for error in errors))
        self.assertTrue(any("reset_generation_step must" in error for error in errors))

    def test_authority_rejection_and_mutation_fail_closed(self):
        value = _ledger()
        value["authority_rejection_reason"] = "accepted"
        value["stale_payload_mutation"] = True
        value["settings_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("authority_rejection_reason" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))
        self.assertTrue(any("settings_authority" in error for error in errors))

    def test_check_rules_are_exact(self):
        value = _ledger()
        value["checks"][1]["expected_reason"] = "accepted"
        value["checks"][4]["expected_mutation"] = "gameplay_mutated"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[1].expected_reason" in error for error in errors))
        self.assertTrue(any("checks[4].expected_mutation" in error for error in errors))

    def test_observed_check_requires_valid_evidence_digest(self):
        value = _ledger()
        value["checks"][1]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[1].evidence must be null" in error for error in errors))
        value["checks"][1]["evidence"] = [{"kind": "report", "path": "reports/caption-generation-authority.json", "sha256": "bad"}]
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
        value["checks"][1] = {"id": {}, "expected_result": [], "expected_reason": {}, "expected_mutation": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("checks[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
