"""Focused tests for the authored/baked/ORM metadata gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import orm_material_validator as validator  # noqa: E402


def contract() -> dict:
    def m(kind: str, path: str | None) -> dict:
        return {"kind": kind, "path": path}

    return {
        "schema_version": 1,
        "status": "metadata_only",
        "source_mesh": "art_source/station/berth_surface_source.blend",
        "claim_scope": "metadata_contract_only",
        "materials": [{
            "id": "station_panel",
            "role": "structural_panel",
            "maps": {
                "albedo": m("derived", "res://materials/station_panel_albedo.tres"),
                "normal": m("missing", None),
                "roughness": m("missing", None),
                "metallic": m("missing", None),
                "orm": {"kind": "missing", "path": None, "packed": False,
                        "channels": {"r": "occlusion", "g": "roughness", "b": "metallic"}},
            },
        }],
    }


class OrmMaterialValidatorTests(unittest.TestCase):
    def test_metadata_only_contract_is_valid(self):
        self.assertEqual(validator.validate_contract(contract()), [])

    def test_packed_orm_requires_frozen_channel_mapping(self):
        value = copy.deepcopy(contract())
        orm = value["materials"][0]["maps"]["orm"]
        orm.update({"packed": True, "kind": "baked", "path": "res://artist/station_panel_orm.png"})
        orm["channels"]["g"] = "metallic"
        errors = validator.validate_contract(value)
        self.assertTrue(any("channels must map" in error for error in errors))

    def test_artist_status_is_not_claimed_by_placeholder_metadata(self):
        value = copy.deepcopy(contract())
        value["status"] = "baked"
        errors = validator.validate_contract(value)
        self.assertIn("contract.status cannot claim artist output before human bake evidence", errors)

    def test_duplicate_ids_and_missing_map_path_fail_closed(self):
        value = copy.deepcopy(contract())
        value["materials"].append(copy.deepcopy(value["materials"][0]))
        value["materials"][1]["maps"]["normal"] = {"kind": "baked", "path": None}
        errors = validator.validate_contract(value)
        self.assertIn("contract.materials[1].id must be unique", errors)
        self.assertIn("contract.materials[1].maps.normal.path is required for baked", errors)


if __name__ == "__main__":
    unittest.main()
