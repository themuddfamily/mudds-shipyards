import unittest

from tools.world.planetary_atmosphere_terrain_hazard_evidence_validator import validate_evidence


def evidence():
    return {
        "schema_version": 1, "world_id": "ember_moon", "region_id": "ember_caldera", "radius_datum": "body_center_to_sea_level",
        "atmosphere": {"body_radius_m": 120000, "outer_radius_m": 140000, "cloud_base_m": 123000, "cloud_top_m": 130000, "render_status": "authored"},
        "terrain": {"minimum_radius_m": 120000, "maximum_radius_m": 120300, "collision_radius_m": 120020, "lod_status": "authored"},
        "hazards": [{"id": "dust_surge_a", "kind": "dust_surge", "body_local_m": [100, 120010, 0], "recovery_id": "return_to_ship", "route_id": "caldera_route", "resolution_authority": "external_hazard_authority"}],
        "native_run": {"status": "NOT_RUN", "evidence": None},
        "authority_exclusions": ["atmosphere_rendering", "terrain_generation", "hazard_simulation", "native_run"],
    }


class PlanetaryAtmosphereTerrainHazardEvidenceValidatorTest(unittest.TestCase):
    def test_authored_evidence_is_valid(self):
        self.assertEqual(validate_evidence(evidence()), [])

    def test_atmosphere_shell_must_exceed_body(self):
        item = evidence(); item["atmosphere"]["outer_radius_m"] = 120000
        self.assertTrue(any("outer_radius" in error for error in validate_evidence(item)))

    def test_cloud_bounds_must_be_ordered(self):
        item = evidence(); item["atmosphere"]["cloud_base_m"] = 131000
        self.assertTrue(any("cloud bounds" in error for error in validate_evidence(item)))

    def test_terrain_collision_must_be_in_bounds(self):
        item = evidence(); item["terrain"]["collision_radius_m"] = 121000
        self.assertTrue(any("collision_radius" in error for error in validate_evidence(item)))

    def test_hazard_kind_must_be_authored(self):
        item = evidence(); item["hazards"][0]["kind"] = "procedural_noise"
        self.assertTrue(any("authored hazard" in error for error in validate_evidence(item)))

    def test_hazard_requires_recovery_handoff(self):
        item = evidence(); item["hazards"][0]["recovery_id"] = ""
        self.assertTrue(any("recovery_id" in error for error in validate_evidence(item)))

    def test_hazard_must_lie_in_terrain_radius(self):
        item = evidence(); item["hazards"][0]["body_local_m"] = [0, 200000, 0]
        self.assertTrue(any("outside terrain" in error for error in validate_evidence(item)))

    def test_native_run_must_remain_not_run(self):
        item = evidence(); item["native_run"] = {"status": "PASS", "evidence": "capture"}
        self.assertTrue(any("NOT_RUN" in error for error in validate_evidence(item)))


if __name__ == "__main__":
    unittest.main()
