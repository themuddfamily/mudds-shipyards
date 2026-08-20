import copy
import unittest

from tools.settings.review.accessibility_contrast_colorblind_cue_evidence_index import (
    ALL_ROLES,
    CUE_CATEGORIES,
    PALETTE_IDS,
    REQUIRED_CHECKS,
    SHAPE_CUES,
    STATE_ROLES,
    TARGET_DEFICIENCIES,
    validate_index,
)


def _index() -> dict:
    rows = [{
        "palette_id": palette_id,
        "target_deficiency": TARGET_DEFICIENCIES[palette_id],
        "roles": list(ALL_ROLES),
        "state_roles": list(STATE_ROLES),
        "shape_cue_fallback": True,
        "status": "planned",
        "evidence": None,
    } for palette_id in PALETTE_IDS]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} contrast/cue invariant remains measurable.",
        "source_test": "tests/accessibility_presets_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_contrast_colorblind_cue_evidence_v1",
        "source_revision": "working-tree-contrast-cue-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "palette_source": "scripts/ui/hud_palette.gd",
        "reviewer_required": "human accessibility and visual QA",
        "open_gate_reason": "no human contrast/colorblind visual review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "gameplay_authority": False,
        "simulation_method": "machado_oliveira_fernandes_linear_rgb",
        "delta_e_metric": "CIEDE2000",
        "contrast_metric": "WCAG_2.x",
        "minimum_state_separation": 24.0,
        "minimum_normal_separation": 20.0,
        "minimum_panel_contrast": 4.5,
        "cue_categories": list(CUE_CATEGORIES),
        "shape_cues": list(SHAPE_CUES),
        "palette_rows": rows,
        "checks": checks,
    }


class AccessibilityContrastColorblindCueTests(unittest.TestCase):
    def test_complete_source_only_index_keeps_visual_gate_open(self):
        self.assertEqual(validate_index(_index()), [])

    def test_palette_and_cue_rosters_are_exact(self):
        value = _index()
        value["cue_categories"] = value["cue_categories"][:-1]
        value["palette_rows"][0]["state_roles"] = value["palette_rows"][0]["state_roles"][:-1]
        errors = validate_index(value)
        self.assertTrue(any("cue_categories must exactly" in error for error in errors))
        self.assertTrue(any("state_roles must cover" in error for error in errors))

    def test_metrics_and_deficiency_mapping_fail_closed(self):
        value = _index()
        value["minimum_state_separation"] = 20.0
        value["palette_rows"][1]["target_deficiency"] = "tritanopia"
        errors = validate_index(value)
        self.assertTrue(any("minimum_state_separation" in error for error in errors))
        self.assertTrue(any("target_deficiency" in error for error in errors))

    def test_native_and_authority_claims_fail_closed(self):
        value = _index()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["gameplay_authority"] = True
        errors = validate_index(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("gameplay_authority" in error for error in errors))

    def test_observed_check_requires_evidence_digest(self):
        value = _index()
        value["checks"][0]["status"] = "observed"
        errors = validate_index(value)
        self.assertTrue(any("checks[0].evidence must be null" in error for error in errors))
        value["checks"][0]["evidence"] = [{"kind": "report", "path": "reports/palette.json", "sha256": "bad"}]
        errors = validate_index(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_duplicate_checks_and_malformed_values_fail_without_throwing(self):
        value = _index()
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        value["checks"][1] = {"id": [], "status": {}, "evidence": {}}
        errors = validate_index(value)
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
