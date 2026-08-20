import copy
import unittest

from tools.settings.review.accessibility_caption_stale_state_generation_fence_validator import (
    FENCE_RESULTS,
    GENERATION_FIELDS,
    LIMITS,
    REQUIRED_CASES,
    validate_ledger,
)


def _ledger() -> dict:
    checks = [{
        "id": check_id,
        "expected_result": FENCE_RESULTS[check_id],
        "expected_behavior": f"The {check_id} generation fence remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CASES]
    return {
        "schema": "accessibility_caption_stale_state_generation_fence_evidence_v1",
        "source_revision": "working-tree-caption-generation-fence-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "consumer_boundary": "caption presentation snapshot consumer",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption generation-fence review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "service_id": "caption-presentation-service",
        "generation_fields": list(GENERATION_FIELDS),
        "fence_policy": "accept_only_current_generation",
        "stale_result_reason": "stale_generation",
        "reset_reason": "reset",
        "limits": copy.deepcopy(LIMITS),
        "generation_monotonic": True,
        "reset_increments_generation": True,
        "stale_payload_mutation": False,
        "checks": checks,
    }


class AccessibilityCaptionStaleStateGenerationFenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_generation_fields_policy_and_limits_are_exact(self):
        value = _ledger()
        value["generation_fields"] = ["generation"]
        value["fence_policy"] = "accept_previous_generation"
        value["limits"]["generation_step_after_reset"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("generation_fields must exactly" in error for error in errors))
        self.assertTrue(any("fence_policy must" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))

    def test_stale_result_and_reset_invariants_fail_closed(self):
        value = _ledger()
        value["stale_result_reason"] = "accepted"
        value["reset_reason"] = "clear"
        value["generation_monotonic"] = False
        value["stale_payload_mutation"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("stale_result_reason" in error for error in errors))
        self.assertTrue(any("reset_reason" in error for error in errors))
        self.assertTrue(any("generation_monotonic" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_observed_check_requires_valid_evidence_digest(self):
        value = _ledger()
        value["checks"][3]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[3].evidence must be null" in error for error in errors))
        value["checks"][3]["evidence"] = [{"kind": "report", "path": "reports/caption-generation-fence.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_authority_and_render_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["caption_queue_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("caption_queue_authority" in error for error in errors))

    def test_check_order_and_expected_result_are_exact(self):
        value = _ledger()
        value["checks"][0]["expected_result"] = "stale_generation"
        value["checks"].reverse()
        errors = validate_ledger(value)
        self.assertTrue(any("expected_result must match" in error for error in errors))
        self.assertTrue(any("checks must exactly" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["checks"][1] = {"id": {}, "expected_result": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("checks[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
