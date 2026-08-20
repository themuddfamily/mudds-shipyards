import unittest

from tools.review.planetary_water_shoreline_review_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_water_shoreline_review_v1", "world_id": "aurora_temperate", "region_id": "basin_shore", "source_revision": "870ab77",
        "water_surface": {"material_id": "temperate_water_v1", "audio_hint": "shoreline_water", "material_status": "authored", "procedural_generation": False},
        "shoreline": {"route_id": "basin_pad_to_shore", "surface_material_id": "wet_rock_v1", "slope_policy": "shoreline_walkable", "review_status": "pending"},
        "shoreline_hazards": [{"id": "tidal_debris", "kind": "submerged_debris", "recovery_id": "return_to_shore", "route_id": "basin_pad_to_shore", "review_status": "pending"}],
        "native_render": {"status": "NOT_RUN", "evidence": None}, "human_review": {"status": "pending"}, "claims_excluded": ["water_runtime", "hazard_resolution", "native_render", "human_review"],
    }


class PlanetaryWaterShorelineReviewLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_water_material_and_audio_are_required(self):
        item = ledger(); item["water_surface"]["audio_hint"] = ""
        self.assertTrue(any("audio_hint" in error for error in validate_ledger(item)))

    def test_water_procedural_generation_is_rejected(self):
        item = ledger(); item["water_surface"]["procedural_generation"] = True
        self.assertTrue(any("procedural_generation" in error for error in validate_ledger(item)))

    def test_shoreline_route_is_required(self):
        item = ledger(); item["shoreline"]["route_id"] = ""
        self.assertTrue(any("route_id" in error for error in validate_ledger(item)))

    def test_hazard_kind_must_be_authored(self):
        item = ledger(); item["shoreline_hazards"][0]["kind"] = "procedural_wave"
        self.assertTrue(any("kind is invalid" in error for error in validate_ledger(item)))

    def test_hazard_recovery_is_required(self):
        item = ledger(); item["shoreline_hazards"][0]["recovery_id"] = ""
        self.assertTrue(any("recovery_id" in error for error in validate_ledger(item)))

    def test_native_render_stays_not_run(self):
        item = ledger(); item["native_render"]["evidence"] = "render capture"
        self.assertTrue(any("NOT_RUN" in error for error in validate_ledger(item)))

    def test_gate_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
