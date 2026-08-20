import unittest

from tools.world.planetary_wildlife_authorship_boundary_validator import validate_boundary


def boundary():
    return {
        "schema_version": 1, "world_id": "ember_moon", "region_id": "caldera_rim", "wildlife_enabled": True,
        "species": [{"id": "ash_grazer", "kind": "grazer", "authorship": "deliberately_authored", "asset_path": "res://scenes/world/wildlife/ash_grazer.tscn", "procedural_population": False}],
        "encounters": [{"id": "ash_grazer_rim", "species_id": "ash_grazer", "body_local_m": [40, 120030, 5], "route_id": "caldera_rim_route", "recovery_id": "return_to_staging", "runtime_resolution": "external_wildlife_authority"}],
        "native_run": {"status": "NOT_RUN", "evidence": None},
        "authority_exclusions": ["actor_spawn", "ai_simulation", "damage_resolution", "native_run"],
    }


class PlanetaryWildlifeAuthorshipBoundaryValidatorTest(unittest.TestCase):
    def test_deliberately_authored_boundary_is_valid(self):
        self.assertEqual(validate_boundary(boundary()), [])

    def test_species_ids_are_unique(self):
        item = boundary(); item["species"].append(dict(item["species"][0]))
        self.assertTrue(any("unique" in error for error in validate_boundary(item)))

    def test_species_must_be_deliberately_authored(self):
        item = boundary(); item["species"][0]["authorship"] = "procedural"
        self.assertTrue(any("deliberately_authored" in error for error in validate_boundary(item)))

    def test_procedural_population_is_rejected(self):
        item = boundary(); item["species"][0]["procedural_population"] = True
        self.assertTrue(any("procedural_population" in error for error in validate_boundary(item)))

    def test_encounter_references_known_species(self):
        item = boundary(); item["encounters"][0]["species_id"] = "unknown"
        self.assertTrue(any("authored species" in error for error in validate_boundary(item)))

    def test_encounter_requires_recovery(self):
        item = boundary(); item["encounters"][0]["recovery_id"] = ""
        self.assertTrue(any("recovery_id" in error for error in validate_boundary(item)))

    def test_native_run_stays_open(self):
        item = boundary(); item["native_run"] = {"status": "PASS", "evidence": "capture"}
        self.assertTrue(any("NOT_RUN" in error for error in validate_boundary(item)))

    def test_runtime_exclusions_are_required(self):
        item = boundary(); item["authority_exclusions"] = []
        self.assertTrue(any("authority_exclusions" in error for error in validate_boundary(item)))


if __name__ == "__main__":
    unittest.main()
