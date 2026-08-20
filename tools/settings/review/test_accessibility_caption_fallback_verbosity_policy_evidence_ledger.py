import copy
import unittest

from tools.settings.review.accessibility_caption_fallback_verbosity_policy_evidence_ledger import (
    CATEGORIES,
    POLICY_RULES,
    PROFILE_KEYS,
    REQUIRED_CASES,
    VERBOSITY_VALUES,
    validate_ledger,
)


def _ledger() -> dict:
    policies = [{
        "id": mode_id,
        "included_categories": POLICY_RULES[mode_id]["included_categories"],
        "minimum_priority": POLICY_RULES[mode_id]["minimum_priority"],
        "filter_reason": POLICY_RULES[mode_id]["filter_reason"],
        "profile_keys": list(PROFILE_KEYS),
        "expected_behavior": f"The {mode_id} fallback verbosity policy remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for mode_id in VERBOSITY_VALUES]
    cases = [{
        "id": case_id,
        "mode": mode_id,
        "expected": f"The {case_id} fallback-verbosity result remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for case_id, mode_id in zip(REQUIRED_CASES, ("all", "dialogue_only", "important_only", "off", "fallback_independent", "fallback_independent"))]
    return {
        "schema": "accessibility_caption_fallback_verbosity_policy_evidence_v1",
        "source_revision": "working-tree-caption-verbosity-policy-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human fallback verbosity review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "profile_keys": list(PROFILE_KEYS),
        "default_profile": {"captions_enabled": True, "verbosity": "all"},
        "categories": list(CATEGORIES),
        "verbosity_values": list(VERBOSITY_VALUES),
        "fallback_text": "[inaudible]",
        "policies": policies,
        "cases": cases,
    }


class AccessibilityCaptionFallbackVerbosityPolicyTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_policy_rules_and_default_profile_are_exact(self):
        value = _ledger()
        value["default_profile"]["verbosity"] = "off"
        value["policies"][2]["minimum_priority"] = 0
        errors = validate_ledger(value)
        self.assertTrue(any("default_profile must" in error for error in errors))
        self.assertTrue(any("minimum_priority must match" in error for error in errors))

    def test_profile_and_category_rosters_fail_closed(self):
        value = _ledger()
        value["profile_keys"] = ["verbosity"]
        value["categories"] = value["categories"][:-1]
        value["verbosity_values"] = ["all"]
        errors = validate_ledger(value)
        self.assertTrue(any("profile_keys must exactly" in error for error in errors))
        self.assertTrue(any("categories must exactly" in error for error in errors))
        self.assertTrue(any("verbosity_values must exactly" in error for error in errors))

    def test_fallback_text_and_case_order_are_exact(self):
        value = _ledger()
        value["fallback_text"] = ""
        value["cases"].reverse()
        errors = validate_ledger(value)
        self.assertTrue(any("fallback_text must" in error for error in errors))
        self.assertTrue(any("cases must exactly" in error for error in errors))

    def test_observed_policy_requires_valid_evidence_digest(self):
        value = _ledger()
        value["policies"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("policies[0].evidence must be null" in error for error in errors))
        value["policies"][0]["evidence"] = [{"kind": "report", "path": "reports/caption-policy.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_authority_and_render_claims_fail_closed(self):
        value = _ledger()
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        value["settings_authority"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("settings_authority" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["policies"][1] = {"id": [], "included_categories": {}, "status": []}
        value["cases"].append(copy.deepcopy(value["cases"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("policies[1].id" in error for error in errors))
        self.assertTrue(any("cases.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
