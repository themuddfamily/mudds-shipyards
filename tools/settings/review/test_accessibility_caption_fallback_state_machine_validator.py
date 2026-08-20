import copy
import unittest

from tools.settings.review.accessibility_caption_fallback_state_machine_validator import (
    EVENTS,
    FALLBACK_TEXT,
    REQUIRED_CASES,
    STATES,
    TERMINAL_STATES,
    TRANSITIONS,
    validate_index,
)


def _index() -> dict:
    states = [{
        "id": state_id,
        "terminal": state_id in TERMINAL_STATES,
        "description": f"The {state_id} fallback state is deterministic.",
    } for state_id in STATES]
    transitions = [{
        "source": source,
        "event": event,
        "target": target,
        "reason": reason,
    } for source, event, target, reason in TRANSITIONS]
    cases = [{
        "id": case_id,
        "transition": f"{TRANSITIONS[index][0]} -> {TRANSITIONS[index][2]}",
        "expected": f"The {case_id} fallback transition remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for index, case_id in enumerate(REQUIRED_CASES)]
    return {
        "schema": "accessibility_caption_fallback_state_machine_evidence_v1",
        "source_revision": "working-tree-caption-fallback-state-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human fallback state review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "fallback_text": FALLBACK_TEXT,
        "states": states,
        "transitions": transitions,
        "cases": cases,
    }


class AccessibilityCaptionFallbackStateMachineTests(unittest.TestCase):
    def test_complete_source_only_index_keeps_human_gate_open(self):
        self.assertEqual(validate_index(_index()), [])

    def test_state_terminal_flags_and_transition_order_are_exact(self):
        value = _index()
        value["states"][0]["terminal"] = True
        value["transitions"][5]["target"] = "presenting_text"
        errors = validate_index(value)
        self.assertTrue(any("states[0].terminal" in error for error in errors))
        self.assertTrue(any("transitions must exactly" in error for error in errors))

    def test_fallback_text_and_fallback_event_are_fail_closed(self):
        value = _index()
        value["fallback_text"] = "[missing]"
        value["transitions"][5]["event"] = EVENTS[4]
        errors = validate_index(value)
        self.assertTrue(any("fallback_text must" in error for error in errors))
        self.assertTrue(any("transitions must exactly" in error for error in errors))

    def test_observed_case_requires_valid_evidence_digest(self):
        value = _index()
        value["cases"][5]["status"] = "observed"
        errors = validate_index(value)
        self.assertTrue(any("cases[5].evidence must be null" in error for error in errors))
        value["cases"][5]["evidence"] = [{"kind": "report", "path": "reports/caption-state.json", "sha256": "bad"}]
        errors = validate_index(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_authority_claims_and_render_status_fail_closed(self):
        value = _index()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["audio_authority"] = True
        errors = validate_index(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("audio_authority" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _index()
        value["human_review_status"] = []
        value["transitions"][0] = {"source": {}, "event": [], "target": [], "reason": []}
        value["cases"].append(copy.deepcopy(value["cases"][0]))
        errors = validate_index(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("transitions[0].source" in error for error in errors))
        self.assertTrue(any("cases.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
