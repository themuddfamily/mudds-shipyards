import unittest

from tools.review.planetary_visual_settlement_landmark_rollup import validate_rollup


def rollup():
    return {
        "schema": "planetary_visual_settlement_landmark_rollup_v1", "world_id": "ember_moon", "region_id": "caldera_staging", "source_revision": "d962ecc",
        "landmarks": [
            {"id": "caldera_pad", "kind": "landing_pad", "route_id": "pad_to_relay", "scene_path": "res://scenes/world/settlements/caldera_pad.tscn", "review_status": "pending", "procedural_generation": False},
            {"id": "staging_relay", "kind": "relay", "route_id": "pad_to_relay", "scene_path": "res://scenes/world/settlements/staging_relay.tscn", "review_status": "pending", "procedural_generation": False},
            {"id": "sample_rack", "kind": "sample_station", "route_id": "relay_to_rack", "scene_path": "res://scenes/world/settlements/sample_rack.tscn", "review_status": "not_performed", "procedural_generation": False},
        ],
        "capture_evidence": {"status": "pending", "record": None}, "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["native_render", "human_review", "production_settlement"],
    }


class PlanetaryVisualSettlementLandmarkRollupTest(unittest.TestCase):
    def test_open_rollup_is_valid(self):
        self.assertEqual(validate_rollup(rollup()), [])

    def test_minimum_landmark_roster_is_required(self):
        item = rollup(); item["landmarks"] = item["landmarks"][:2]
        self.assertTrue(any("at least three" in error for error in validate_rollup(item)))

    def test_pad_and_relay_are_required(self):
        item = rollup(); item["landmarks"][0]["kind"] = "overlook"
        self.assertTrue(any("landing_pad and relay" in error for error in validate_rollup(item)))

    def test_landmark_paths_must_be_res_paths(self):
        item = rollup(); item["landmarks"][0]["scene_path"] = "pad.tscn"
        self.assertTrue(any("res://" in error for error in validate_rollup(item)))

    def test_procedural_generation_is_rejected(self):
        item = rollup(); item["landmarks"][0]["procedural_generation"] = True
        self.assertTrue(any("procedural_generation" in error for error in validate_rollup(item)))

    def test_review_status_stays_open(self):
        item = rollup(); item["landmarks"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_rollup(item)))

    def test_capture_evidence_stays_open(self):
        item = rollup(); item["capture_evidence"]["status"] = "PASS"
        self.assertTrue(any("capture_evidence" in error for error in validate_rollup(item)))

    def test_gate_exclusions_are_required(self):
        item = rollup(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_rollup(item)))


if __name__ == "__main__":
    unittest.main()
