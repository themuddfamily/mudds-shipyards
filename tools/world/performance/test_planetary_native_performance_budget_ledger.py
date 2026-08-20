import copy
import unittest

from tools.world.performance.planetary_native_performance_budget_ledger import validate_ledger


def ledger() -> dict:
    budget = {
        "frame_time_ms": 33.3,
        "vram_mb": 2048.0,
        "resident_tiles": 64,
        "physics_bodies": 5000,
        "audio_voices": 32,
        "startup_seconds": 20.0,
    }
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_native_performance_budget",
        "evidence_mode": "budget_ledger_native_not_run",
        "source_revision": "planetary-performance-budget-v1",
        "platform": "windows-x86_64",
        "world_id": "ember_moon",
        "native_claims": False,
        "fabricated_metrics": False,
        "runtime_authority": False,
        "package_launched": False,
        "native_playtest": {"status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "native Windows measurement remains open"},
        "profiles": [
            {"id": "minimum", "status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "minimum native profile remains open", "budget": budget.copy(), "observations": {key: None for key in budget}},
            {"id": "target", "status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "target native profile remains open", "budget": budget.copy(), "observations": {key: None for key in budget}},
        ],
        "scenarios": [
            {"id": "orbit_to_surface", "status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "route capture remains open"},
            {"id": "settlement_route", "status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "settlement capture remains open"},
            {"id": "save_reentry", "status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "re-entry capture remains open"},
            {"id": "long_session_orbit_surface", "status": "NOT_RUN", "native_executed": False, "evidence": None, "reason": "long-session capture remains open"},
        ],
        "authority": {"renderer": False, "physics": False, "streaming": False, "terrain": False, "movement": False, "audio": False, "save": False, "network": False, "gameplay": False},
    }


class PlanetaryNativePerformanceBudgetLedgerTest(unittest.TestCase):
    def test_not_run_budget_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_native_status_must_remain_not_run(self):
        item = ledger(); item["profiles"][0]["status"] = "PASS"
        self.assertTrue(any("status must be NOT_RUN" in error for error in validate_ledger(item)))

    def test_observations_must_not_be_fabricated(self):
        item = ledger(); item["profiles"][1]["observations"]["frame_time_ms"] = 16.6
        self.assertTrue(any("observations.frame_time_ms" in error for error in validate_ledger(item)))

    def test_budget_metric_is_required(self):
        item = ledger(); del item["profiles"][0]["budget"]["vram_mb"]
        self.assertTrue(any("budget.vram_mb" in error for error in validate_ledger(item)))

    def test_profile_order_is_required(self):
        item = ledger(); item["profiles"][0], item["profiles"][1] = item["profiles"][1], item["profiles"][0]
        self.assertTrue(any("minimum and target in order" in error for error in validate_ledger(item)))

    def test_native_claim_fails_closed(self):
        item = ledger(); item["native_claims"] = True; item["native_playtest"]["native_executed"] = True
        errors = validate_ledger(item)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("native_executed" in error for error in errors))

    def test_scenario_order_is_required(self):
        item = ledger(); item["scenarios"].reverse()
        self.assertTrue(any("required authored route scenarios" in error for error in validate_ledger(item)))

    def test_runtime_authority_stays_external(self):
        item = copy.deepcopy(ledger()); item["authority"]["physics"] = True
        self.assertTrue(any("authority.physics" in error for error in validate_ledger(item)))

    def test_platform_must_be_windows(self):
        item = ledger(); item["platform"] = "linux-x86_64"
        self.assertTrue(any("platform must be a Windows" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
