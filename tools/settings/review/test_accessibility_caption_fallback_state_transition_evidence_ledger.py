import copy
import unittest

from tools.settings.review.accessibility_caption_fallback_state_transition_evidence_ledger import (
    EVENTS,
    LIMITS,
    REQUIRED_CASES,
    SERVICE_STATES,
    TRANSITIONS,
    validate_ledger,
)


def _ledger() -> dict:
    transitions = [{
        "source": source,
        "event": event,
        "target": target,
        "reason": reason,
        "preserves_queue": preserves_queue,
    } for source, event, target, reason, preserves_queue in TRANSITIONS]
    cases = [{
        "id": case_id,
        "transition_ids": f"{TRANSITIONS[index][1]} -> {TRANSITIONS[index][3]}",
        "expected": f"The {case_id} service transition remains deterministic.",
        "source_test": "tests/caption_presentation_service_test.gd",
        "status": "planned",
        "evidence": None,
    } for index, case_id in enumerate(REQUIRED_CASES)]
    return {
        "schema": "accessibility_caption_fallback_state_transition_evidence_v1",
        "source_revision": "working-tree-caption-service-transition-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption state-transition review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "service_id": "caption-presentation-service",
        "states": list(SERVICE_STATES),
        "events": list(EVENTS),
        "limits": copy.deepcopy(LIMITS),
        "disabled_caption_time_continues": True,
        "reset_clears_queue_and_ledger": True,
        "transitions": transitions,
        "cases": cases,
    }


class AccessibilityCaptionFallbackStateTransitionTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_states_events_and_limits_are_exact(self):
        value = _ledger()
        value["states"] = value["states"][:-1]
        value["events"][0] = "wrong_event"
        value["limits"]["maximum_stored_captions"] = 4
        errors = validate_ledger(value)
        self.assertTrue(any("states must exactly" in error for error in errors))
        self.assertTrue(any("events must exactly" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))

    def test_visibility_and_reset_invariants_fail_closed(self):
        value = _ledger()
        value["disabled_caption_time_continues"] = False
        value["reset_clears_queue_and_ledger"] = False
        value["transitions"][6]["preserves_queue"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("disabled_caption_time_continues" in error for error in errors))
        self.assertTrue(any("reset_clears_queue_and_ledger" in error for error in errors))
        self.assertTrue(any("transitions must exactly" in error for error in errors))

    def test_observed_case_requires_valid_evidence_digest(self):
        value = _ledger()
        value["cases"][5]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("cases[5].evidence must be null" in error for error in errors))
        value["cases"][5]["evidence"] = [{"kind": "report", "path": "reports/caption-transitions.json", "sha256": "bad"}]
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

    def test_transition_order_and_reasons_are_exact(self):
        value = _ledger()
        value["transitions"][0]["reason"] = "queued"
        value["transitions"][1]["target"] = "idle"
        errors = validate_ledger(value)
        self.assertTrue(any("transitions must exactly" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["transitions"][0] = {"source": {}, "event": [], "target": [], "reason": [], "preserves_queue": {}}
        value["cases"].append(copy.deepcopy(value["cases"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("transitions[0].source" in error for error in errors))
        self.assertTrue(any("cases.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
