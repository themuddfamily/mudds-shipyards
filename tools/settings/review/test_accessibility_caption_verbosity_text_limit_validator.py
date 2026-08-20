import copy
import unittest

from tools.settings.review.accessibility_caption_verbosity_text_limit_validator import (
    CATEGORIES,
    LIMITS,
    REQUIRED_CASES,
    VERBOSITY_RULES,
    VERBOSITY_VALUES,
    validate_ledger,
)


def _ledger() -> dict:
    modes = [{
        "id": mode_id,
        "included_categories": VERBOSITY_RULES[mode_id]["included_categories"],
        "minimum_priority": VERBOSITY_RULES[mode_id]["minimum_priority"],
        "description": f"Caption mode {mode_id}.",
        "status": "planned",
        "evidence": None,
    } for mode_id in VERBOSITY_VALUES]
    cases = [{
        "id": case_id,
        "expected": f"The {case_id} caption boundary remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for case_id in REQUIRED_CASES]
    return {
        "schema": "accessibility_caption_verbosity_text_limit_evidence_v1",
        "source_revision": "working-tree-caption-limit-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption verbosity review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "categories": list(CATEGORIES),
        "limits": copy.deepcopy(LIMITS),
        "inaudible_fallback_text": "[inaudible]",
        "verbosity_modes": modes,
        "boundary_cases": cases,
    }


class AccessibilityCaptionVerbosityTextLimitTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_mode_rules_and_category_roster_are_exact(self):
        value = _ledger()
        value["categories"] = value["categories"][:-1]
        value["verbosity_modes"][2]["minimum_priority"] = 0
        errors = validate_ledger(value)
        self.assertTrue(any("categories must exactly" in error for error in errors))
        self.assertTrue(any("minimum_priority must match" in error for error in errors))

    def test_limits_and_fallback_text_fail_closed(self):
        value = _ledger()
        value["limits"]["max_text_characters"] = 256
        value["inaudible_fallback_text"] = ""
        errors = validate_ledger(value)
        self.assertTrue(any("limits must exactly" in error for error in errors))
        self.assertTrue(any("inaudible_fallback_text" in error for error in errors))

    def test_native_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["caption_queue_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("caption_queue_authority" in error for error in errors))

    def test_observed_boundary_requires_evidence_digest(self):
        value = _ledger()
        value["boundary_cases"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("boundary_cases[0].evidence must be null" in error for error in errors))
        value["boundary_cases"][0]["evidence"] = [{"kind": "report", "path": "reports/caption-limits.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_duplicate_cases_and_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["boundary_cases"].append(copy.deepcopy(value["boundary_cases"][0]))
        value["boundary_cases"][1] = {"id": [], "status": {}, "evidence": {}}
        errors = validate_ledger(value)
        self.assertTrue(any("boundary_cases.id values must be unique" in error for error in errors))
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
