import copy
import unittest

from tools.review.human_packaged_sortie_evidence_ledger_validator import SCENARIO_STEPS, validate_ledger


SHA = "a" * 64


def _ledger() -> dict:
    scenarios = {}
    for name, steps in SCENARIO_STEPS.items():
        scenarios[name] = {
            "status": "not_performed",
            "required_passes": {"guided": 3, "sandbox": 1, "settings_reentry": 1}[name],
            "observed_attempts": 0,
            "passed_attempts": 0,
            "fresh_process_required": True,
            "steps": list(steps),
            "attempts": [],
            "notes": "awaiting the packaged no-shortcut human run",
        }
    return {
        "schema": "human_packaged_sortie_evidence_ledger_v1",
        "human_gate_status": "pending",
        "source_revision": "working-tree-human-gate-review",
        "open_gate_reason": "no uninterrupted packaged human playtest has been recorded",
        "no_shortcuts": True,
        "package": {
            "status": "not_run",
            "platform": "Windows",
            "build_identity": "candidate-not-run",
            "source_commit": SHA,
            "artifact_sha256": None,
            "execution_evidence": None,
        },
        "scenarios": scenarios,
        "external_tuning": {
            "status": "not_performed",
            "required_players": 5,
            "required_completion_count": 4,
            "time_limit_seconds": 1800,
            "developer_intervention_allowed": False,
            "players": [],
            "evidence": None,
        },
    }


class HumanPackagedSortieLedgerTests(unittest.TestCase):
    def test_pending_ledger_preserves_open_gate(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_scenario_contract_requires_exact_steps_and_fresh_attempts(self):
        value = _ledger()
        value["scenarios"]["guided"]["steps"] = ["cold_boot"]
        value["scenarios"]["guided"]["fresh_process_required"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("guided.steps must exactly" in error for error in errors))
        self.assertTrue(any("fresh_process_required" in error for error in errors))

    def test_forbidden_gate_claim_and_package_execution_fail_closed(self):
        value = _ledger()
        value["human_gate_status"] = "passed"
        value["package"]["status"] = "passed"
        value["package"]["execution_evidence"] = [{"kind": "log", "path": "run.log", "sha256": SHA}]
        errors = validate_ledger(value)
        self.assertTrue(any("human_gate_status" in error for error in errors))
        self.assertTrue(any("package.status" in error for error in errors))

    def test_external_tuning_requires_five_players_and_thresholds_when_observed(self):
        value = _ledger()
        tuning = value["external_tuning"]
        tuning["status"] = "observed"
        tuning["players"] = [{
            "id": "player-1", "first_time": True, "developer_intervention": False,
            "duration_seconds": 1200,
            "outcomes": {"launch": True, "fight": True, "redock": True, "disembark": True},
            "camera_comfort": 5, "control_clarity": 5, "landing_clarity": 5,
            "p0_p1_findings": 0,
        }]
        errors = validate_ledger(value)
        self.assertTrue(any("requires all five players" in error for error in errors))

    def test_duplicate_attempts_and_wrong_observed_count_fail(self):
        value = _ledger()
        scenario = value["scenarios"]["sandbox"]
        attempt = {"id": "sandbox-1", "fresh_process": True, "result": "pending", "evidence": None}
        scenario["status"] = "in_progress"
        scenario["attempts"] = [copy.deepcopy(attempt), copy.deepcopy(attempt)]
        scenario["observed_attempts"] = 1
        errors = validate_ledger(value)
        self.assertTrue(any("attempts.id values must be unique" in error for error in errors))
        self.assertTrue(any("observed_attempts must equal" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
