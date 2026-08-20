import unittest

from tools.review.planetary_atmosphere_weather_transition_ledger import validate_ledger


def ledger():
    phases = []
    for ident, altitude in (("space", 140000), ("entry_heat", 135000), ("cloud_layer", 128000), ("surface", 120000)):
        phases.append({"id": ident, "altitude_m": altitude, "visual_hint": f"{ident} visual", "audio_hint": f"{ident} audio", "evidence_status": "pending"})
    return {"schema": "planetary_atmosphere_weather_transition_v1", "world_id": "ember_moon", "source_revision": "96113ed", "unit_system": "game_scale_si", "phases": phases, "weather_profiles": [{"id": "dust_front", "kind": "dust_front", "audio_hint": "dust_surge", "simulation": False}], "native_run": {"status": "NOT_RUN", "evidence": None}, "authority_exclusions": ["atmosphere_runtime", "weather_simulation", "audio_resolution", "native_run"]}


class PlanetaryAtmosphereWeatherTransitionLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_phase_order_is_strict(self):
        item = ledger(); item["phases"][1]["id"] = "surface"
        self.assertTrue(any("out of order" in error for error in validate_ledger(item)))

    def test_altitudes_descend(self):
        item = ledger(); item["phases"][2]["altitude_m"] = 138000
        self.assertTrue(any("descend" in error for error in validate_ledger(item)))

    def test_transition_hints_are_required(self):
        item = ledger(); item["phases"][0]["audio_hint"] = ""
        self.assertTrue(any("audio_hint" in error for error in validate_ledger(item)))

    def test_phase_evidence_stays_open(self):
        item = ledger(); item["phases"][0]["evidence_status"] = "PASS"
        self.assertTrue(any("evidence_status" in error for error in validate_ledger(item)))

    def test_weather_simulation_is_not_claimed(self):
        item = ledger(); item["weather_profiles"][0]["simulation"] = True
        self.assertTrue(any("simulation" in error for error in validate_ledger(item)))

    def test_native_run_stays_open(self):
        item = ledger(); item["native_run"]["evidence"] = "native capture"
        self.assertTrue(any("must remain NOT_RUN" in error for error in validate_ledger(item)))

    def test_runtime_exclusions_are_required(self):
        item = ledger(); item["authority_exclusions"] = []
        self.assertTrue(any("authority_exclusions" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
