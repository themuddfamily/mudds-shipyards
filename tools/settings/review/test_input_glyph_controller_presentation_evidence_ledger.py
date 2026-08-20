import copy
import unittest

from tools.settings.review.input_glyph_controller_presentation_evidence_ledger import (
    FAMILIES,
    REQUIRED_ACTIONS,
    REQUIRED_CHECKS,
    TOKEN_PREFIXES,
    validate_ledger,
)


def _ledger() -> dict:
    families = []
    for family in FAMILIES:
        families.append({
            "id": family,
            "token_prefix": TOKEN_PREFIXES[family],
            "fallback_text_required": True,
            "metadata_only": family.startswith("gamepad_"),
            "status": "planned",
            "evidence": None,
        })
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} presentation contract remains deterministic.",
        "source_test": "tests/input_glyph_resolver_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "input_glyph_controller_presentation_evidence_v1",
        "source_revision": "working-tree-glyph-review",
        "presentation_review_status": "not_performed",
        "hardware_validation_status": "not_run",
        "resolver_source": "scripts/ui/input_glyph_resolver.gd",
        "reviewer_required": "human UI and controller presentation QA",
        "open_gate_reason": "no hardware glyph review or native device run has been performed",
        "hardware_run_performed": False,
        "reads_input_map": False,
        "mutates_input_map": False,
        "gameplay_authority": False,
        "text_fallback_required": True,
        "detached_contract_tests_only": True,
        "families_order": list(FAMILIES),
        "covered_actions": list(REQUIRED_ACTIONS),
        "families": families,
        "checks": checks,
    }


class InputGlyphControllerPresentationTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_hardware_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_family_and_action_rosters_are_exact(self):
        value = _ledger()
        value["families_order"] = value["families_order"][:-1]
        value["covered_actions"] = value["covered_actions"][:-1]
        errors = validate_ledger(value)
        self.assertTrue(any("families_order" in error for error in errors))
        self.assertTrue(any("covered_actions" in error for error in errors))

    def test_token_prefix_and_metadata_boundaries_fail_closed(self):
        value = _ledger()
        value["families"][3]["token_prefix"] = "gamepad.generic."
        value["families"][3]["metadata_only"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("token_prefix" in error for error in errors))
        self.assertTrue(any("metadata_only" in error for error in errors))

    def test_authority_and_hardware_claims_fail_closed(self):
        value = _ledger()
        value["hardware_validation_status"] = "observed"
        value["hardware_run_performed"] = True
        value["reads_input_map"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("hardware_validation_status" in error for error in errors))
        self.assertTrue(any("hardware_run_performed" in error for error in errors))
        self.assertTrue(any("reads_input_map" in error for error in errors))

    def test_observed_check_requires_evidence_digest(self):
        value = _ledger()
        value["checks"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("checks[0].evidence must be null" in error for error in errors))
        value["checks"][0]["evidence"] = [{"kind": "image", "path": "captures/glyphs.png", "sha256": "bad"}]
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
