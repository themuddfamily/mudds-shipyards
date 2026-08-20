import copy
import unittest

from tools.settings.review.accessibility_caption_fallback_stale_state_evidence_ledger import (
    BOUNDARY_RULES,
    FALLBACK_TEXT,
    LIMITS,
    REQUIRED_CASES,
    STALE_BOUNDARIES,
    validate_ledger,
)


def _ledger() -> dict:
    boundaries = [{
        "id": boundary_id,
        "result": BOUNDARY_RULES[boundary_id]["result"],
        "authority": BOUNDARY_RULES[boundary_id]["authority"],
        "expected_behavior": f"The {boundary_id} stale-state boundary remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for boundary_id in STALE_BOUNDARIES]
    cases = [{
        "id": case_id,
        "boundary": STALE_BOUNDARIES[index],
        "expected": f"The {case_id} stale-state result remains deterministic.",
        "source_test": "tests/caption_presentation_service_test.gd",
        "status": "planned",
        "evidence": None,
    } for index, case_id in enumerate(REQUIRED_CASES)]
    return {
        "schema": "accessibility_caption_fallback_stale_state_evidence_v1",
        "source_revision": "working-tree-caption-stale-state-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption stale-state review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "fallback_text": FALLBACK_TEXT,
        "limits": copy.deepcopy(LIMITS),
        "wall_clock_authority": False,
        "reset_increments_generation": True,
        "boundaries": boundaries,
        "cases": cases,
    }


class AccessibilityCaptionFallbackStaleStateTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_stale_boundaries_and_limits_are_exact(self):
        value = _ledger()
        value["boundaries"] = value["boundaries"][:-1]
        value["limits"]["maximum_dedupe_ids"] = 10
        value["fallback_text"] = ""
        errors = validate_ledger(value)
        self.assertTrue(any("boundaries must contain exactly" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))
        self.assertTrue(any("fallback_text must" in error for error in errors))

    def test_generation_and_time_authority_invariants_fail_closed(self):
        value = _ledger()
        value["reset_increments_generation"] = False
        value["wall_clock_authority"] = True
        value["boundaries"][3]["result"] = "paused"
        errors = validate_ledger(value)
        self.assertTrue(any("reset_increments_generation" in error for error in errors))
        self.assertTrue(any("wall_clock_authority" in error for error in errors))
        self.assertTrue(any("boundaries[3].result" in error for error in errors))

    def test_observed_boundary_requires_valid_evidence_digest(self):
        value = _ledger()
        value["boundaries"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("boundaries[0].evidence must be null" in error for error in errors))
        value["boundaries"][0]["evidence"] = [{"kind": "report", "path": "reports/caption-stale-state.json", "sha256": "bad"}]
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

    def test_boundary_order_and_identity_are_exact(self):
        value = _ledger()
        value["boundaries"][1]["id"] = "reset_generation_boundary"
        value["service_id"] = "other-service"
        errors = validate_ledger(value)
        self.assertTrue(any("boundaries.id values must be unique" in error for error in errors))
        self.assertTrue(any("service_id must identify" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["boundaries"][1] = {"id": {}, "result": [], "authority": [], "status": []}
        value["cases"].append(copy.deepcopy(value["cases"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("boundaries[1].id" in error for error in errors))
        self.assertTrue(any("cases.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
