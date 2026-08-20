import copy
import unittest

from tools.settings.review.accessibility_caption_authority_reentry_generation_evidence_ledger import (
    AUTHORITY_VALUES,
    CHECK_IDS,
    CHECK_RULES,
    LIMITS,
    POST_COMMIT_ORDER,
    validate_ledger,
)


def _ledger() -> dict:
    checks = [{
        "id": check_id,
        "expected_result": CHECK_RULES[check_id]["result"],
        "mutation": CHECK_RULES[check_id]["mutation"],
        "generation": CHECK_RULES[check_id]["generation"],
        "expected_behavior": f"The {check_id} authority/reentry behavior remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for check_id in CHECK_IDS]
    value = {
        "schema": "accessibility_caption_authority_reentry_generation_evidence_v1",
        "source_revision": "working-tree-caption-reentry-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "signal_source": "scripts/ui/caption_presentation_service.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption authority/reentry review or native render has been performed",
        "service_id": "caption-presentation-service",
        "dispatch_guard": "signal_dispatch_active",
        "reentrant_reason": "reentrant_call",
        "post_commit_order": list(POST_COMMIT_ORDER),
        "limits": copy.deepcopy(LIMITS),
        "generation_fields": ["generation", "revision"],
        "generation_monotonic": True,
        "checks": checks,
    }
    value.update(AUTHORITY_VALUES)
    return value


class AccessibilityCaptionAuthorityReentryGenerationTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_guard_reason_and_post_commit_order_are_exact(self):
        value = _ledger()
        value["dispatch_guard"] = "other_guard"
        value["reentrant_reason"] = "busy"
        value["post_commit_order"] = ["signal_emit"]
        errors = validate_ledger(value)
        self.assertTrue(any("dispatch_guard must" in error for error in errors))
        self.assertTrue(any("reentrant_reason must" in error for error in errors))
        self.assertTrue(any("post_commit_order must exactly" in error for error in errors))

    def test_reentrant_check_and_generation_rules_fail_closed(self):
        value = _ledger()
        value["checks"][1]["mutation"] = "queue_mutated"
        value["checks"][6]["generation"] = "unchanged"
        value["generation_monotonic"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("checks[1].mutation" in error for error in errors))
        self.assertTrue(any("checks[6].generation" in error for error in errors))
        self.assertTrue(any("generation_monotonic" in error for error in errors))

    def test_authority_roster_fails_closed(self):
        value = _ledger()
        value["audio_playback"] = True
        value["settings_authority"] = True
        value["presentation_only"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("audio_playback must be false" in error for error in errors))
        self.assertTrue(any("settings_authority must be false" in error for error in errors))
        self.assertTrue(any("presentation_only must be true" in error for error in errors))

    def test_observed_check_requires_valid_evidence_digest(self):
        value = _ledger()
        value["checks"][1]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[1].evidence must be null" in error for error in errors))
        value["checks"][1]["evidence"] = [{"kind": "report", "path": "reports/caption-reentry.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_limits_and_generation_fields_are_exact(self):
        value = _ledger()
        value["limits"]["generation_step_after_reset"] = 2
        value["generation_fields"] = ["revision"]
        errors = validate_ledger(value)
        self.assertTrue(any("limits must exactly" in error for error in errors))
        self.assertTrue(any("generation_fields must exactly" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["checks"][2] = {"id": {}, "expected_result": [], "mutation": {}, "generation": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("checks[2].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
