import unittest

from tools.world.planetary_orbit_surface_gate_ledger_validator import validate_ledger


def ledger():
    phases = []
    for phase in ("orbit", "entry", "surface", "landing"):
        phases.append({"id": phase, "native_gate": {"status": "NOT_RUN", "evidence": None, "reason": "native host unavailable"}, "human_gate": {"status": "PENDING", "evidence": None}, "acceptance_note": f"{phase} acceptance remains to be witnessed"})
    return {"schema_version": 1, "world_id": "ember_moon", "source_revision": "a7686d2", "owner": "planetary-production", "phases": phases, "native_execution": {"status": "NOT_RUN", "evidence": None, "reason": "native host unavailable"}, "human_playtest": {"status": "PENDING", "evidence": None}, "overall_status": "BLOCKED_BY_GATES", "claims_excluded": ["native_hardware_pass", "human_visual_signoff", "complete_surface_flight"]}


class PlanetaryOrbitSurfaceGateLedgerValidatorTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_phase_order_is_fixed(self):
        item = ledger(); item["phases"][1]["id"] = "surface"
        self.assertTrue(any("out of order" in error for error in validate_ledger(item)))

    def test_native_not_run_requires_reason_and_no_evidence(self):
        item = ledger(); item["native_execution"]["evidence"] = "Windows capture"
        self.assertTrue(any("evidence must be null" in error for error in validate_ledger(item)))

    def test_human_gate_cannot_claim_approval(self):
        item = ledger(); item["human_playtest"]["status"] = "PASS"
        self.assertTrue(any("must remain open" in error for error in validate_ledger(item)))

    def test_phase_acceptance_note_is_required(self):
        item = ledger(); item["phases"][0]["acceptance_note"] = ""
        self.assertTrue(any("acceptance_note" in error for error in validate_ledger(item)))

    def test_overall_status_must_remain_open(self):
        item = ledger(); item["overall_status"] = "COMPLETE"
        self.assertTrue(any("overall_status" in error for error in validate_ledger(item)))

    def test_claim_exclusions_preserve_gates(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))

    def test_each_phase_has_both_gates(self):
        item = ledger(); item["phases"][2].pop("human_gate")
        self.assertTrue(any("human_gate" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
