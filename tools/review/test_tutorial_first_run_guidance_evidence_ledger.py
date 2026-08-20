import copy
import unittest

from tools.review.tutorial_first_run_guidance_evidence_ledger import (
    INPUT_FAMILIES,
    REQUIRED_CHECKPOINTS,
    REQUIRED_STEPS,
    validate_ledger,
)


SHA = "d" * 64


def _ledger() -> dict:
    steps = []
    for index, step_id in enumerate(REQUIRED_STEPS):
        steps.append({
            "id": step_id,
            "checkpoint_id": REQUIRED_CHECKPOINTS[index],
            "title": f"First-run {step_id}",
            "controller_prompt": f"Controller: {step_id}",
            "keyboard_prompt": f"Keyboard: {step_id}",
            "accessible_prompt": f"Use your preferred controls to {step_id}.",
            "expected_outcome": f"The player can understand and perform {step_id}.",
            "source": "scripts/ui/tutorial_progression_contract.gd",
            "status": "planned",
            "evidence": None,
        })
    return {
        "schema": "tutorial_first_run_guidance_evidence_v1",
        "source_revision": "working-tree-tutorial-review",
        "human_playthrough_status": "not_performed",
        "reviewer_required": "first-time player and accessibility QA",
        "open_gate_reason": "no human first-run playthrough has been performed",
        "human_playthrough_performed": False,
        "presentation_only": True,
        "reads_input_map": False,
        "gameplay_authority": False,
        "save_authority": False,
        "developer_intervention_allowed": False,
        "input_families": list(INPUT_FAMILIES),
        "steps": steps,
    }


class TutorialFirstRunGuidanceEvidenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_playthrough_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_ordered_step_and_checkpoint_rosters_are_required(self):
        value = _ledger()
        value["steps"].reverse()
        errors = validate_ledger(value)
        self.assertTrue(any("frozen first-run order" in error for error in errors))
        self.assertTrue(any("frozen checkpoint order" in error for error in errors))

    def test_all_prompt_variants_are_required(self):
        value = _ledger()
        value["steps"][0]["controller_prompt"] = ""
        value["steps"][1]["accessible_prompt"] = None
        errors = validate_ledger(value)
        self.assertTrue(any("controller_prompt" in error for error in errors))
        self.assertTrue(any("accessible_prompt" in error for error in errors))

    def test_playthrough_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["human_playthrough_status"] = "complete"
        value["human_playthrough_performed"] = True
        value["gameplay_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("human_playthrough_status" in error for error in errors))
        self.assertTrue(any("human_playthrough_performed" in error for error in errors))
        self.assertTrue(any("gameplay_authority" in error for error in errors))

    def test_observed_step_requires_traceable_evidence(self):
        value = _ledger()
        value["steps"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("steps[0].evidence must be null" in error for error in errors))
        value["steps"][0]["evidence"] = [{"kind": "video", "path": "captures/tutorial.mp4", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_duplicate_steps_and_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["steps"].append(copy.deepcopy(value["steps"][0]))
        value["steps"][1] = {"id": [], "checkpoint_id": {}, "status": [], "evidence": {}}
        errors = validate_ledger(value)
        self.assertTrue(any("steps.id values must be unique" in error for error in errors))
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
