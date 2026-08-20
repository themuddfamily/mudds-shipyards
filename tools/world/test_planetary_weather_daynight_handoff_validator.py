import copy
import unittest

from tools.world.planetary_weather_daynight_handoff_validator import validate_handoff


def handoff() -> dict:
    detached = {"accepted": True, "runtime_owner": None, "renderer_applied": False, "evidence_ref": "res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md"}
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_weather_daynight_handoff",
        "evidence_mode": "detached_presentation_fixture",
        "source_revision": "planetary-weather-daynight-v1",
        "production_wiring": False,
        "native_claims": False,
        "weather_clock_owner": False,
        "ephemeris_owner": False,
        "renderer_application": False,
        "world_id": "ember_moon",
        "weather": {
            "policy_version": "game_scale_weather_field_v1",
            "caller_time_only": True,
            "cloud_layer_top_exclusive": True,
            "fog_clamped": True,
            "cloud_coverage_unitless": 0.55,
            "weather_intensity_unitless": 0.35,
            "fog_factor_unitless": 0.2,
            "gust_factor_unitless": 1.0,
            "wind_velocity_mps": [12.0, 0.0, -4.0],
            "evidence_ref": "res://scripts/world/planetary_weather_field.gd",
        },
        "lighting": {
            "policy_version": "planetary_day_night_lighting_v1",
            "observation_frame": "planetary_body_local",
            "caller_clock_only": True,
            "twilight_min_clearance_degrees": -6.0,
            "moonlight_energy_factor_unitless": 0.12,
            "states": ["direct_daylight", "atmospheric_twilight", "night", "interior"],
            "evidence_ref": "res://scripts/world/planetary_day_night_lighting_contract.gd",
        },
        "weather_to_clouds": detached.copy(),
        "weather_to_fog": detached.copy(),
        "lighting_to_sun_moon": detached.copy(),
        "interior_exterior_audio": detached.copy(),
        "transitions": [
            {"id": "space", "atmosphere_factor_unitless": 0.0, "cloud_factor_unitless": 0.0, "interior_direct_sources_suppressed": False},
            {"id": "atmospheric_entry", "atmosphere_factor_unitless": 0.5, "cloud_factor_unitless": 0.1, "interior_direct_sources_suppressed": False},
            {"id": "surface_exterior", "atmosphere_factor_unitless": 1.0, "cloud_factor_unitless": 0.55, "interior_direct_sources_suppressed": False},
            {"id": "interior", "atmosphere_factor_unitless": 1.0, "cloud_factor_unitless": 0.0, "interior_direct_sources_suppressed": True},
        ],
        "authority": {"clock": False, "ephemeris": False, "weather_simulation": False, "renderer": False, "audio": False, "gameplay": False, "save": False, "network": False, "physics": False},
    }


class PlanetaryWeatherDaynightHandoffValidatorTest(unittest.TestCase):
    def test_detached_weather_daynight_handoff_is_valid(self):
        self.assertEqual(validate_handoff(handoff()), [])

    def test_weather_policy_is_required(self):
        item = handoff(); item["weather"]["policy_version"] = "other_weather"
        self.assertTrue(any("weather.policy_version" in error for error in validate_handoff(item)))

    def test_lighting_policy_is_required(self):
        item = handoff(); item["lighting"]["policy_version"] = "other_lighting"
        self.assertTrue(any("lighting.policy_version" in error for error in validate_handoff(item)))

    def test_transition_order_is_required(self):
        item = handoff(); item["transitions"].reverse()
        self.assertTrue(any("space-to-interior" in error for error in validate_handoff(item)))

    def test_interior_suppresses_direct_sources(self):
        item = handoff(); item["transitions"][3]["interior_direct_sources_suppressed"] = False
        self.assertTrue(any("inconsistent" in error for error in validate_handoff(item)))

    def test_handoff_cannot_claim_renderer_application(self):
        item = handoff(); item["lighting_to_sun_moon"]["renderer_applied"] = True
        self.assertTrue(any("renderer_applied" in error for error in validate_handoff(item)))

    def test_weather_and_lighting_authority_stays_external(self):
        item = copy.deepcopy(handoff()); item["authority"]["clock"] = True
        self.assertTrue(any("authority.clock" in error for error in validate_handoff(item)))

    def test_native_and_production_claims_are_closed(self):
        item = handoff(); item["native_claims"] = True; item["production_wiring"] = True
        errors = validate_handoff(item)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("production_wiring" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
