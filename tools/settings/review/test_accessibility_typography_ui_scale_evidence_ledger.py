import copy
import unittest

from tools.settings.review.accessibility_typography_ui_scale_evidence_ledger import (
    BASE_FONT_SIZES,
    LAYOUT_CONTRACT,
    REQUIRED_CHECKS,
    SETTING_KEYS,
    TYPOGRAPHY_ROLES,
    validate_ledger,
)


def _ledger() -> dict:
    roles = [{
        "id": role_id,
        "base_font_size": BASE_FONT_SIZES[role_id],
        "textual": True,
        "contrast_ratio_minimum": 7.0,
        "status": "planned",
        "evidence": None,
    } for role_id in TYPOGRAPHY_ROLES]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} typography/layout contract remains deterministic.",
        "source_test": "tests/caption_presenter_layout_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_typography_ui_scale_evidence_v1",
        "source_revision": "working-tree-typography-scale-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "presenter_source": "scripts/ui/caption_presenter.gd",
        "reviewer_required": "human accessibility and UI layout QA",
        "open_gate_reason": "no human readability review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "gameplay_authority": False,
        "setting_keys": list(SETTING_KEYS),
        "layout_contract": copy.deepcopy(LAYOUT_CONTRACT),
        "safe_area_anchoring": True,
        "wraps_text": True,
        "reduced_flash_policy": "steady_no_animation",
        "typography_roles": roles,
        "checks": checks,
    }


class AccessibilityTypographyUiScaleEvidenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_setting_and_layout_contracts_are_exact(self):
        value = _ledger()
        value["setting_keys"] = value["setting_keys"][:-1]
        value["layout_contract"]["maximum_text_characters"] = 256
        errors = validate_ledger(value)
        self.assertTrue(any("setting_keys must exactly" in error for error in errors))
        self.assertTrue(any("layout_contract must exactly" in error for error in errors))

    def test_typography_role_sizes_and_contrast_fail_closed(self):
        value = _ledger()
        value["typography_roles"][0]["base_font_size"] = 12
        value["typography_roles"][1]["contrast_ratio_minimum"] = 4.5
        errors = validate_ledger(value)
        self.assertTrue(any("base_font_size" in error for error in errors))
        self.assertTrue(any("contrast_ratio_minimum" in error for error in errors))

    def test_native_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["audio_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("audio_authority" in error for error in errors))

    def test_observed_check_requires_evidence_digest(self):
        value = _ledger()
        value["checks"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[0].evidence must be null" in error for error in errors))
        value["checks"][0]["evidence"] = [{"kind": "image", "path": "captures/type.png", "sha256": "bad"}]
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
