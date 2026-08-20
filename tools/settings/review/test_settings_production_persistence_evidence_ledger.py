import copy
import unittest

from tools.settings.review.settings_production_persistence_evidence_ledger import (
    REQUIRED_CASES,
    REQUIRED_SETTING_KEYS,
    validate_ledger,
)


SHA = "e" * 64


def _ledger() -> dict:
    cases = [{
        "id": case_id,
        "expected": f"The {case_id} persistence invariant remains deterministic and atomic.",
        "source_test": "tests/runtime_settings_production_persistence_test.gd",
        "status": "planned",
        "evidence": None,
    } for case_id in REQUIRED_CASES]
    return {
        "schema": "settings_production_persistence_evidence_v1",
        "source_revision": "working-tree-settings-persistence-review",
        "production_review_status": "not_performed",
        "os_interruption_status": "not_run",
        "reviewer_required": "production settings and platform QA",
        "open_gate_reason": "no OS interruption or native production persistence run has been performed",
        "os_interruption_performed": False,
        "detached_contract_tests_only": True,
        "setting_keys": list(REQUIRED_SETTING_KEYS),
        "authority": {
            "store_count": 1,
            "adapter_count": 1,
            "identity_scope": "process_lifetime",
            "load_once": True,
            "load_before_first_apply": True,
            "reentry_reloads": False,
            "detached_report_only": True,
            "wall_clock_used": False,
            "automatic_repair": False,
            "delete_policy": False,
            "os_crash_hook": False,
            "nested_transaction_rejected": True,
            "unrelated_namespaces_preserved": True,
        },
        "cases": cases,
    }


class SettingsProductionPersistenceEvidenceTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_os_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_setting_and_case_rosters_are_exact(self):
        value = _ledger()
        value["setting_keys"] = value["setting_keys"][:-1]
        value["cases"].pop()
        errors = validate_ledger(value)
        self.assertTrue(any("setting_keys must exactly" in error for error in errors))
        self.assertTrue(any("exactly fifteen" in error for error in errors))

    def test_authority_boundaries_fail_closed(self):
        value = _ledger()
        value["authority"]["reentry_reloads"] = True
        value["authority"]["wall_clock_used"] = True
        value["authority"]["store_count"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("reentry_reloads" in error for error in errors))
        self.assertTrue(any("wall_clock_used" in error for error in errors))
        self.assertTrue(any("store_count must be 1" in error for error in errors))

    def test_os_interruption_and_production_claims_fail_closed(self):
        value = _ledger()
        value["os_interruption_status"] = "observed"
        value["os_interruption_performed"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("os_interruption_status" in error for error in errors))
        self.assertTrue(any("os_interruption_performed" in error for error in errors))

    def test_observed_case_requires_traceable_evidence(self):
        value = _ledger()
        value["cases"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("cases[0].evidence must be null" in error for error in errors))
        value["cases"][0]["evidence"] = [{"kind": "log", "path": "logs/settings.json", "sha256": "bad"}]
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
