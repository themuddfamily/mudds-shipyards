"""Focused tests for the five-craft interaction/evidence manifest."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fleet_craft_interaction_validator as validator  # noqa: E402


MANIFEST_PATH = HERE / "fleet_craft_interaction_manifest.json"


def manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


class FleetCraftInteractionValidatorTests(unittest.TestCase):
    def test_checked_in_five_craft_manifest_is_valid(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_roster_and_role_differentiation_are_frozen(self):
        value = manifest()
        value["ships"][0]["ship_id"] = value["ships"][1]["ship_id"]
        value["ships"][2]["role"] = value["ships"][3]["role"]
        errors = validator.validate_manifest(value)
        self.assertIn("ships.ship_id values must be unique", errors)
        self.assertIn("ships.role values must be unique", errors)

    def test_physical_route_cannot_be_replaced_by_teleport_or_prompt(self):
        value = manifest()
        boarding = value["ships"][0]["boarding"]
        boarding["staged_beyond_fallback_reach"] = False
        boarding["route_clear"] = False
        boarding["minimum_walk_m"] = 0.0
        errors = validator.validate_manifest(value)
        self.assertTrue(any("staged_beyond_fallback_reach" in error for error in errors))
        self.assertTrue(any("route_clear" in error for error in errors))
        self.assertTrue(any("minimum_walk_m" in error for error in errors))

    def test_unknown_name_mapping_cannot_claim_bounded_silhouette(self):
        value = manifest()
        value["ships"][1]["silhouette"]["claim"] = "bounded_partial"
        errors = validator.validate_manifest(value)
        self.assertIn("ships[1].unknown name-to-model mapping cannot claim bounded silhouette", errors)

    def test_interior_requires_connected_route_and_scale(self):
        value = manifest()
        interior = value["ships"][2]["interior"]
        interior["connected_to_ship_frame"] = False
        interior["route_markers"] = ["pilot_seat"]
        value["ships"][2]["scale_band"] = "small"
        errors = validator.validate_manifest(value)
        self.assertTrue(any("walkable interior requires medium scale band" in error for error in errors))
        self.assertTrue(any("must be connected to the ship frame" in error for error in errors))
        self.assertTrue(any("route must cover" in error for error in errors))

    def test_new_design_cannot_smuggle_in_historical_references(self):
        value = manifest()
        value["ships"][4]["evidence_references"] = ["B7: unrelated footage"]
        errors = validator.validate_manifest(value)
        self.assertIn("ships[4].new design cannot attach historical evidence references", errors)

    def test_non_walkable_large_hull_cannot_hide_as_a_fighter(self):
        value = manifest()
        value["ships"][0]["silhouette"]["width_m"] = 16.0
        errors = validator.validate_manifest(value)
        self.assertIn("ships[0].non-walkable craft exceeds the small-craft envelope", errors)

    def test_mutations_do_not_modify_fixture(self):
        original = manifest()
        mutated = copy.deepcopy(original)
        mutated["ships"][0]["cockpit"]["head_hull_clearance_m"] = 0.0
        self.assertNotEqual(mutated, original)
        self.assertEqual(validator.validate_manifest(original), [])


if __name__ == "__main__":
    unittest.main()
