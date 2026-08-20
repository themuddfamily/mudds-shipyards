import copy
import unittest

from tools.settings.review.accessibility_reduced_motion_flash_policy_evidence_ledger import (
    POLICY_IDS,
    POLICIES,
    REQUIRED_CHECKS,
    SETTING_KEYS,
    validate_ledger,
)


def _ledger() -> dict:
    policies = [{
        "id": policy_id,
        "normal": POLICIES[policy_id]["normal"],
        "reduced": POLICIES[policy_id]["reduced"],
        "owner": "detached presentation policy",
        "status": "planned",
        "evidence": None,
    } for policy_id in POLICY_IDS]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} reduced accessibility behavior remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_reduced_motion_flash_policy_evidence_v1",
        "source_revision": "working-tree-reduced-policy-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "visual_source": "scripts/ui/accessibility_visual_preset.gd",
        "caption_source": "scripts/ui/caption_accessibility_contract.gd",
        "hud_source": "scripts/ui/hud.gd",
        "loading_source": "scripts/ui/loading_screen.gd",
        "reviewer_required": "human accessibility and visual QA",
        "open_gate_reason": "no human reduced-motion/flash review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "gameplay_authority": False,
        "audio_authority": False,
        "settings_authority": False,
        "setting_keys": list(SETTING_KEYS),
        "normal_policy": "consumer_standard",
        "reduced_motion_policy": "steady_no_motion",
        "reduced_flash_policy": "steady_no_flash",
        "policies": policies,
        "checks": checks,
    }


class AccessibilityReducedMotionFlashEvidenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_visual_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_setting_and_policy_rosters_are_exact(self):
        value = _ledger()
        value["setting_keys"] = value["setting_keys"][:-1]
        value["policies"].pop()
        errors = validate_ledger(value)
        self.assertTrue(any("setting_keys must exactly" in error for error in errors))
        self.assertTrue(any("exactly eight reduced-motion/flash policies" in error for error in errors))

    def test_reduced_policy_values_fail_closed(self):
        value = _ledger()
        value["policies"][0]["reduced"] = "1.0"
        value["reduced_flash_policy"] = "consumer_standard"
        errors = validate_ledger(value)
        self.assertTrue(any("frozen normal/reduced policy" in error for error in errors))
        self.assertTrue(any("reduced_flash_policy" in error for error in errors))

    def test_native_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["settings_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("settings_authority" in error for error in errors))

    def test_observed_check_requires_evidence_digest(self):
        value = _ledger()
        value["checks"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[0].evidence must be null" in error for error in errors))
        value["checks"][0]["evidence"] = [{"kind": "video", "path": "captures/reduced.mp4", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_duplicate_checks_and_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        value["checks"][1] = {"id": [], "status": {}, "evidence": {}}
        errors = validate_ledger(value)
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
