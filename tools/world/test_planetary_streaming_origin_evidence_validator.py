import unittest

from tools.world.planetary_streaming_origin_evidence_validator import validate_manifest


def manifest():
    return {
        "schema_version": 1, "world_id": "ember_moon", "unit_system": "game_scale_si_body_local",
        "cell_size_m": 4096.0, "origin_generation": 2,
        "cells": [
            {"id": "caldera_0_0", "coordinate": [0, 0, 0], "state": "AUTHORED", "scene_path": "res://scenes/world/planets/ember_moon.tscn"},
            {"id": "caldera_1_0", "coordinate": [1, 0, 0], "state": "OPTIONAL", "scene_path": "res://scenes/world/planets/ember_moon.tscn"},
        ],
        "rebase_events": [
            {"generation": 1, "translation_m": [4096.0, 0.0, 0.0], "absolute_position_preserved": True},
            {"generation": 2, "translation_m": [0.0, -4096.0, 0.0], "absolute_position_preserved": True},
        ],
        "evidence": {"record": "coordinate-frame capture ledger"},
        "authority": {"streaming_runtime": False, "node_rebase": False, "terrain_generation": False, "movement": False},
    }


class PlanetaryStreamingOriginEvidenceValidatorTest(unittest.TestCase):
    def test_authored_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_cell_coordinates_must_be_unique(self):
        item = manifest(); item["cells"][1]["coordinate"] = [0, 0, 0]
        self.assertTrue(any("coordinates must be unique" in error for error in validate_manifest(item)))

    def test_scene_path_must_be_res_path(self):
        item = manifest(); item["cells"][0]["scene_path"] = "scene.tscn"
        self.assertTrue(any("scene_path" in error for error in validate_manifest(item)))

    def test_rebase_generations_must_increase(self):
        item = manifest(); item["rebase_events"][1]["generation"] = 1
        self.assertTrue(any("increase strictly" in error for error in validate_manifest(item)))

    def test_latest_generation_must_match_origin(self):
        item = manifest(); item["origin_generation"] = 1
        self.assertTrue(any("latest rebase" in error for error in validate_manifest(item)))

    def test_rebase_requires_absolute_preservation(self):
        item = manifest(); item["rebase_events"][0]["absolute_position_preserved"] = False
        self.assertTrue(any("preserve absolute" in error for error in validate_manifest(item)))

    def test_runtime_authority_is_explicitly_denied(self):
        item = manifest(); item["authority"]["node_rebase"] = True
        self.assertTrue(any("authority.node_rebase" in error for error in validate_manifest(item)))

    def test_cell_size_must_be_positive(self):
        item = manifest(); item["cell_size_m"] = 0
        self.assertTrue(any("cell_size_m" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
