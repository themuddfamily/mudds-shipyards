import copy
import unittest

from tools.settings.review.runtime_remap_production_handoff_validator import (
    CONFLICT_POLICIES,
    GAMEPLAY_ACTIONS,
    REQUIRED_CASES,
    SHIP_IDS,
    validate_ledger,
)


def _ledger() -> dict:
    sources = [{
        "ship_id": ship_id,
        "source_kind": "LocalShipInputSource",
        "exact_action_roster": True,
        "generation_guarded": True,
        "status": "planned",
        "evidence": None,
    } for ship_id in SHIP_IDS]
    cases = [{
        "id": case_id,
        "expected": f"Production handoff preserves {case_id} atomically.",
        "production_owner": "GameFlow._apply_runtime_input_bindings_and_options",
        "detached_contract_test": "tools/settings/runtime_input_remap_evidence_validator.py",
        "status": "planned",
        "evidence": None,
    } for case_id in REQUIRED_CASES]
    return {
        "schema": "runtime_remap_production_handoff_v1",
        "source_revision": "working-tree-runtime-remap-production-review",
        "production_handoff_status": "not_performed",
        "hardware_validation_status": "not_run",
        "contract_source": "scripts/settings/input_rebind_service.gd",
        "production_owner": "scripts/game/game_flow.gd",
        "open_gate_reason": "no hardware or native production remap run has been performed",
        "hardware_run_performed": False,
        "detached_contract_tests_only": True,
        "runtime_authority_unchanged": True,
        "conflict_policies": list(CONFLICT_POLICIES),
        "action_roster": {
            "required_actions": list(GAMEPLAY_ACTIONS),
            "covered_actions": list(GAMEPLAY_ACTIONS),
        },
        "fleet_sources": sources,
        "cases": cases,
    }


class RuntimeRemapProductionHandoffTests(unittest.TestCase):
    def test_complete_source_only_handoff_keeps_hardware_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_exact_action_and_fleet_rosters_are_required(self):
        value = _ledger()
        value["action_roster"]["covered_actions"] = value["action_roster"]["covered_actions"][:-1]
        value["fleet_sources"].pop()
        errors = validate_ledger(value)
        self.assertTrue(any("covered_actions" in error for error in errors))
        self.assertTrue(any("exactly five retained" in error for error in errors))

    def test_conflict_policies_and_authority_claims_fail_closed(self):
        value = _ledger()
        value["conflict_policies"] = ["replace"]
        value["runtime_authority_unchanged"] = False
        value["fleet_sources"][0]["generation_guarded"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("conflict_policies" in error for error in errors))
        self.assertTrue(any("runtime_authority_unchanged" in error for error in errors))
        self.assertTrue(any("generation_guarded" in error for error in errors))

    def test_hardware_claim_fails_closed(self):
        value = _ledger()
        value["hardware_validation_status"] = "observed"
        value["hardware_run_performed"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("hardware_validation_status" in error for error in errors))
        self.assertTrue(any("hardware_run_performed" in error for error in errors))

    def test_observed_case_requires_evidence_digest(self):
        value = _ledger()
        value["cases"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("cases[0].evidence must be null" in error for error in errors))
        value["cases"][0]["evidence"] = [{"kind": "report", "path": "reports/remap.json", "sha256": "bad"}]
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
