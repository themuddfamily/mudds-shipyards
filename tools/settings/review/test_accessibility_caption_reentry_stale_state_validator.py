import copy
import unittest

from tools.settings.review.accessibility_caption_reentry_stale_state_validator import (
    CHECK_IDS,
    CHECK_RULES,
    FENCE_DIMENSIONS,
    LIMITS,
    validate_ledger,
)


def _ledger() -> dict:
    checks = [{
        "id": check_id,
        "expected_result": CHECK_RULES[check_id]["result"],
        "expected_mutation": CHECK_RULES[check_id]["mutation"],
        "expected_reason": CHECK_RULES[check_id]["reason"],
        "expected_behavior": f"The {check_id} stale-reentry behavior remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for check_id in CHECK_IDS]
    return {
        "schema": "accessibility_caption_reentry_stale_state_evidence_v1",
        "source_revision": "working-tree-caption-reentry-stale-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "consumer_boundary": "caption signal consumer",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption stale-reentry review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "service_id": "caption-presentation-service",
        "fence_dimensions": list(FENCE_DIMENSIONS),
        "acceptance_policy": "current_generation_revision_and_dispatch_idle",
        "stale_generation_reason": "stale_generation",
        "stale_revision_reason": "stale_revision",
        "reentry_reason": "reentrant_call",
        "limits": copy.deepcopy(LIMITS),
        "stale_payload_mutation": False,
        "checks": checks,
    }


class AccessibilityCaptionReentryStaleStateTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_fence_dimensions_and_acceptance_policy_are_exact(self):
        value = _ledger()
        value["fence_dimensions"] = ["generation"]
        value["acceptance_policy"] = "accept_any_callback"
        value["limits"]["generation_step_after_reset"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("fence_dimensions must exactly" in error for error in errors))
        self.assertTrue(any("acceptance_policy must" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))

    def test_stale_rejection_reasons_and_mutation_fail_closed(self):
        value = _ledger()
        value["stale_generation_reason"] = "accepted"
        value["stale_revision_reason"] = "accepted"
        value["reentry_reason"] = "busy"
        value["stale_payload_mutation"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("stale_generation_reason" in error for error in errors))
        self.assertTrue(any("stale_revision_reason" in error for error in errors))
        self.assertTrue(any("reentry_reason" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_check_rules_are_exact(self):
        value = _ledger()
        value["checks"][1]["expected_reason"] = "reentrant_call"
        value["checks"][2]["expected_mutation"] = "queue_mutated"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[1].expected_reason" in error for error in errors))
        self.assertTrue(any("checks[2].expected_mutation" in error for error in errors))

    def test_observed_check_requires_valid_evidence_digest(self):
        value = _ledger()
        value["checks"][1]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[1].evidence must be null" in error for error in errors))
        value["checks"][1]["evidence"] = [{"kind": "report", "path": "reports/caption-reentry-stale.json", "sha256": "bad"}]
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
        value["checks"][1] = {"id": {}, "expected_result": [], "expected_mutation": {}, "expected_reason": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("checks[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
