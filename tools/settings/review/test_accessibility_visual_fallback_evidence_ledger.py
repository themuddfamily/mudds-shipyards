import copy
import unittest

from tools.settings.review.accessibility_visual_fallback_evidence_ledger import (
    CUE_CATEGORIES,
    PALETTE_TARGETS,
    PALETTES,
    REQUIRED_CHECKS,
    SETTING_KEYS,
    SHAPE_CUES,
    validate_ledger,
)


def _ledger() -> dict:
    palettes = [{
        "id": palette_id,
        "target_deficiency": PALETTE_TARGETS[palette_id],
        "fallback_to_authored": True,
        "status": "planned",
        "evidence": None,
    } for palette_id in PALETTES]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} accessibility fallback remains deterministic.",
        "source_test": "tests/accessibility_presets_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_visual_fallback_evidence_v1",
        "source_revision": "working-tree-accessibility-fallback-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "visual_source": "scripts/ui/accessibility_visual_preset.gd",
        "reviewer_required": "human accessibility and visual QA",
        "open_gate_reason": "no human accessibility review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "gameplay_authority": False,
        "audio_authority": False,
        "caption_authority": False,
        "setting_keys": list(SETTING_KEYS),
        "cue_categories": list(CUE_CATEGORIES),
        "shape_cues": list(SHAPE_CUES),
        "contrast_ratio_minimum": 4.5,
        "large_text_contrast_ratio_minimum": 3.0,
        "ui_scale_bounds": {"min": 0.75, "max": 1.6},
        "palettes": palettes,
        "checks": checks,
    }


class AccessibilityVisualFallbackEvidenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_accessibility_rosters_and_bounds_are_exact(self):
        value = _ledger()
        value["setting_keys"] = value["setting_keys"][:-1]
        value["cue_categories"] = value["cue_categories"][:-1]
        value["ui_scale_bounds"]["max"] = 2.0
        errors = validate_ledger(value)
        self.assertTrue(any("setting_keys must exactly" in error for error in errors))
        self.assertTrue(any("cue_categories must exactly" in error for error in errors))
        self.assertTrue(any("ui_scale_bounds" in error for error in errors))

    def test_palette_target_and_non_colour_fallback_contract_fail_closed(self):
        value = _ledger()
        value["palettes"][1]["target_deficiency"] = "tritanopia"
        value["palettes"][0]["fallback_to_authored"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("target_deficiency" in error for error in errors))
        self.assertTrue(any("fallback_to_authored" in error for error in errors))

    def test_render_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["gameplay_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("gameplay_authority" in error for error in errors))

    def test_observed_check_requires_evidence_digest(self):
        value = _ledger()
        value["checks"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[0].evidence must be null" in error for error in errors))
        value["checks"][0]["evidence"] = [{"kind": "image", "path": "captures/accessibility.png", "sha256": "bad"}]
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
