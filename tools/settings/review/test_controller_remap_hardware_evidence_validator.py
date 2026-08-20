import copy
import unittest

from tools.settings.review.controller_remap_hardware_evidence_validator import (
    FAMILIES,
    GLYPH_FAMILIES,
    REQUIRED_ACTIONS,
    REQUIRED_REVIEW_STEPS,
    validate_manifest,
)


SHA = "a" * 64


def _manifest() -> dict:
    devices = []
    for family in FAMILIES:
        devices.append({
            "family": family,
            "name": family,
            "connection": "source-only fixture",
            "glyph_family": family,
            "status": "planned",
        })
    remaps = []
    for index, policy in enumerate(("reject", "replace", "reject")):
        remaps.append({
            "id": f"remap-{index}",
            "device_family": ("gamepad_xbox", "gamepad_playstation", "gamepad_nintendo")[index],
            "action": "fire_primary",
            "from_binding": "button_a",
            "to_binding": f"button_{index + 1}",
            "conflict_policy": policy,
            "status": "not_run",
            "evidence": None,
        })
    return {
        "schema": "controller_remap_hardware_evidence_v1",
        "hardware_test_status": "not_run",
        "source_revision": "working-tree-controller-review",
        "reviewer_required": "input QA with physical devices",
        "open_gate_reason": "no real controller or native Windows run has been performed",
        "hardware_execution_performed": False,
        "detached_contract_tests_only": True,
        "review_steps": list(REQUIRED_REVIEW_STEPS),
        "device_families": devices,
        "glyph_review": {
            "status": "not_run",
            "hardware_claim": False,
            "required_families": list(GLYPH_FAMILIES),
            "covered_actions": list(REQUIRED_ACTIONS),
            "evidence": None,
        },
        "remap_trials": remaps,
        "curve_hold_trials": [{
            "id": "curve-fire",
            "action": "fire_primary",
            "curve": "linear",
            "hold_mode": "hold",
            "deadzone": 0.18,
            "status": "not_run",
            "evidence": None,
        }, {
            "id": "toggle-camera",
            "action": "camera_cycle",
            "curve": "squared",
            "hold_mode": "toggle",
            "deadzone": 0.18,
            "status": "not_run",
            "evidence": None,
        }],
        "hardware_target": {"platform": "Windows", "status": "not_run", "evidence": None},
    }


class ControllerRemapHardwareEvidenceTests(unittest.TestCase):
    def test_source_only_ledger_is_valid_and_hardware_gate_open(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_exact_device_and_glyph_rosters_are_required(self):
        value = _manifest()
        value["device_families"] = value["device_families"][:-1]
        value["glyph_review"]["covered_actions"] = value["glyph_review"]["covered_actions"][:-1]
        errors = validate_manifest(value)
        self.assertTrue(any("device_families must contain exactly" in error for error in errors))
        self.assertTrue(any("covered_actions must exactly" in error for error in errors))

    def test_passed_hardware_and_trial_statuses_fail_closed(self):
        value = _manifest()
        value["hardware_test_status"] = "passed"
        value["hardware_execution_performed"] = True
        value["remap_trials"][0]["status"] = "passed"
        errors = validate_manifest(value)
        self.assertTrue(any("hardware_test_status" in error for error in errors))
        self.assertTrue(any("hardware_execution_performed" in error for error in errors))
        self.assertTrue(any("remap_trials[0].status" in error for error in errors))

    def test_conflict_policies_and_curve_options_are_required(self):
        value = _manifest()
        value["remap_trials"] = [value["remap_trials"][0]]
        value["curve_hold_trials"][0]["curve"] = "cubic"
        errors = validate_manifest(value)
        self.assertTrue(any("both reject and replace" in error for error in errors))
        self.assertTrue(any("curve must be linear or squared" in error for error in errors))

    def test_observed_trial_requires_hardware_evidence(self):
        value = _manifest()
        value["remap_trials"][0]["status"] = "observed"
        errors = validate_manifest(value)
        self.assertTrue(any("remap_trials[0].evidence must be null before a run" in error for error in errors))

    def test_duplicate_trial_and_bad_target_fail_closed(self):
        value = _manifest()
        value["remap_trials"].append(copy.deepcopy(value["remap_trials"][0]))
        value["hardware_target"]["platform"] = "Linux"
        errors = validate_manifest(value)
        self.assertTrue(any("remap_trials.id values must be unique" in error for error in errors))
        self.assertTrue(any("platform must be Windows" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
