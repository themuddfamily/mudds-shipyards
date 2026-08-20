import copy
import unittest

from tools.settings.review.accessibility_caption_fallback_evidence_ledger import (
    CATEGORIES,
    LIMITS,
    REQUIRED_CASES,
    SETTING_KEYS,
    VERBOSITY_VALUES,
    validate_ledger,
)


def _ledger() -> dict:
    cases = [{
        "id": case_id,
        "expected": f"The {case_id} caption fallback remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for case_id in REQUIRED_CASES]
    return {
        "schema": "accessibility_caption_fallback_evidence_v1",
        "source_revision": "working-tree-caption-fallback-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption fallback review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "setting_keys": list(SETTING_KEYS),
        "categories": list(CATEGORIES),
        "verbosity_values": list(VERBOSITY_VALUES),
        "inaudible_fallback_text": "[inaudible]",
        "limits": copy.deepcopy(LIMITS),
        "reduced_motion_policy": "steady_no_motion",
        "reduced_flash_policy": "steady_no_flash",
        "cases": cases,
    }


class AccessibilityCaptionFallbackEvidenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_setting_category_and_verbosity_rosters_are_exact(self):
        value = _ledger()
        value["setting_keys"] = value["setting_keys"][:-1]
        value["categories"] = value["categories"][:-1]
        value["verbosity_values"] = ["all"]
        errors = validate_ledger(value)
        self.assertTrue(any("setting_keys must exactly" in error for error in errors))
        self.assertTrue(any("categories must exactly" in error for error in errors))
        self.assertTrue(any("verbosity_values must exactly" in error for error in errors))

    def test_fallback_limits_and_policies_fail_closed(self):
        value = _ledger()
        value["inaudible_fallback_text"] = ""
        value["limits"]["max_text_characters"] = 256
        value["reduced_flash_policy"] = "consumer_standard"
        errors = validate_ledger(value)
        self.assertTrue(any("inaudible_fallback_text" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))
        self.assertTrue(any("reduced_flash_policy" in error for error in errors))

    def test_native_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["audio_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("audio_authority" in error for error in errors))

    def test_observed_case_requires_evidence_digest(self):
        value = _ledger()
        value["cases"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("cases[0].evidence must be null" in error for error in errors))
        value["cases"][0]["evidence"] = [{"kind": "report", "path": "reports/captions.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_duplicate_cases_and_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["cases"].append(copy.deepcopy(value["cases"][0]))
        value["cases"][1] = {"id": [], "status": {}, "evidence": {}}
        errors = validate_ledger(value)
        self.assertTrue(any("cases.id values must be unique" in error for error in errors))
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
