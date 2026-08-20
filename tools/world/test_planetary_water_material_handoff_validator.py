import copy
import unittest

from tools.world.planetary_water_material_handoff_validator import validate_handoff


def handoff() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_water_surface_material_handoff",
        "evidence_mode": "detached_authored_material_fixture",
        "renderer_binding": False,
        "water_simulation": False,
        "hazard_resolution": False,
        "audio_playback": False,
        "native_claims": False,
        "runtime_authority": False,
        "identity": {"world_id": "aurora_temperate_world", "landing_region_id": "aurora_foundation_landing", "surface_feature_id": "aurora_coastal_shelf", "display_name": "Aurora Coastal Shelf"},
        "water": {"water_appropriate": True, "body_id": "aurora_coastal_shelf_water", "body_kind": "coastal_inlet"},
        "materials": [
            {"id": "aurora_water_surface", "kind": "water", "audio_route_id": "planetary_water_surface"},
            {"id": "aurora_wet_shoreline", "kind": "shoreline", "audio_route_id": "planetary_shoreline_contact"},
            {"id": "aurora_shore_substrate", "kind": "substrate", "audio_route_id": "planetary_shore_substrate"},
        ],
        "material_handoffs": {"water": "aurora_water_surface", "shoreline": "aurora_wet_shoreline", "substrate": "aurora_shore_substrate"},
        "shoreline_hazards": [
            {"id": "aurora_shelf_undertow", "kind": "undertow", "body_local_m": [180.0, 120000.0, -240.0], "route_id": "aurora_coastal_access_route", "recovery_id": "return_to_landed_ship"},
            {"id": "aurora_slick_ledge", "kind": "slippery_shore", "body_local_m": [260.0, 120003.0, -198.0], "route_id": "aurora_coastal_access_route", "recovery_id": "recover_at_aurora_egress"},
        ],
        "audio": {"authority_id": "planetary_surface_audio_policy", "route_ids": ["planetary_water_surface", "planetary_shoreline_contact", "planetary_shore_substrate"], "routes_are_opaque_hints": True, "profile_resolution_requested": False, "playback_requested": False},
        "evidence": {"status": "modern_interpretation", "historical_claim": False, "procedural_generation": False, "references": ["res://docs/PLANETARY_SURFACE_AUDIO_POLICY.md", "res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md"]},
        "authority": {"renderer": False, "material_binding": False, "water_simulation": False, "terrain_generation": False, "collision_generation": False, "physics": False, "hazard_resolution": False, "audio_route_resolution": False, "audio_playback": False, "streaming": False, "save": False, "network": False},
    }


class PlanetaryWaterMaterialHandoffValidatorTest(unittest.TestCase):
    def test_authored_water_material_handoff_is_valid(self):
        self.assertEqual(validate_handoff(handoff()), [])

    def test_material_order_is_required(self):
        item = handoff(); item["materials"].reverse()
        self.assertTrue(any("kind must be water" in error for error in validate_handoff(item)))

    def test_duplicate_material_layer_fails(self):
        item = handoff(); item["materials"][1]["id"] = item["materials"][0]["id"]
        self.assertTrue(any("materials IDs" in error for error in validate_handoff(item)))

    def test_shoreline_hazard_requires_recovery(self):
        item = handoff(); item["shoreline_hazards"][0]["recovery_id"] = ""
        self.assertTrue(any("recovery_id" in error for error in validate_handoff(item)))

    def test_audio_playback_stays_external(self):
        item = handoff(); item["audio"]["playback_requested"] = True
        self.assertTrue(any("resolution or playback" in error for error in validate_handoff(item)))

    def test_procedural_evidence_fails(self):
        item = handoff(); item["evidence"]["procedural_generation"] = True
        self.assertTrue(any("historical or procedural" in error for error in validate_handoff(item)))

    def test_renderer_and_water_runtime_claims_are_closed(self):
        item = copy.deepcopy(handoff()); item["renderer_binding"] = True; item["authority"]["water_simulation"] = True
        errors = validate_handoff(item)
        self.assertTrue(any("renderer_binding" in error for error in errors))
        self.assertTrue(any("authority.water_simulation" in error for error in errors))

    def test_native_claim_fails_closed(self):
        item = handoff(); item["native_claims"] = True
        self.assertTrue(any("native_claims" in error for error in validate_handoff(item)))


if __name__ == "__main__":
    unittest.main()
