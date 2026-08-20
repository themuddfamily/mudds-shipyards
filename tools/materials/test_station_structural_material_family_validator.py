"""Focused tests for the station beam/frame/trim family declaration gate."""

import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import station_structural_material_family_validator as validator


FIXTURE = Path(__file__).with_name("station_structural_material_family.json")


class StationStructuralMaterialFamilyTests(unittest.TestCase):
    def test_checked_in_extension_fixture_is_valid(self):
        value = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(validator.validate_contract(value), [])

    def test_all_structural_roles_and_targets_are_required(self):
        value = json.loads(FIXTURE.read_text(encoding="utf-8"))
        value["targets"] = [target for target in value["targets"] if target["role"] != "beam"]
        errors = validator.validate_contract(value)
        self.assertTrue(any("missing required roles" in error for error in errors))
        self.assertTrue(any("aft_structural_beams" in error for error in errors))

    def test_ship_atlas_reuse_is_rejected(self):
        value = json.loads(FIXTURE.read_text(encoding="utf-8"))
        value["targets"][0]["ship_atlas"] = "res://assets/ships/arrow_atlas.png"
        errors = validator.validate_contract(value)
        self.assertIn("contract.targets[0].ship_atlas must be null", errors)

    def test_procedural_metadata_cannot_claim_artist_assets(self):
        value = copy.deepcopy(json.loads(FIXTURE.read_text(encoding="utf-8")))
        value["artist_asset_limitations"]["baked_sets_present"] = True
        errors = validator.validate_contract(value)
        self.assertIn(
            "contract.artist_asset_limitations.baked_sets_present must be false",
            errors,
        )


if __name__ == "__main__":
    unittest.main()
