import unittest

from tools.review.planetary_hazard_route_landmark_visual_index import validate_index


def index():
    return {
        "schema": "planetary_hazard_route_landmark_visual_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "f79f863",
        "landmarks": [{"id": "relay", "scene_path": "res://scenes/world/settlements/relay.tscn", "route_id": "pad_to_relay", "capture_id": "relay-view", "review_status": "pending"}],
        "hazards": [{"id": "relay_arc", "landmark_id": "relay", "recovery_id": "return_to_pad", "review_status": "not_performed"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["hazard_runtime", "native_render", "human_review"],
    }


class PlanetaryHazardRouteLandmarkVisualIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_landmark_scene_path_is_res_path(self):
        item = index(); item["landmarks"][0]["scene_path"] = "relay.tscn"
        self.assertTrue(any("res://" in error for error in validate_index(item)))

    def test_landmark_capture_is_required(self):
        item = index(); item["landmarks"][0]["capture_id"] = ""
        self.assertTrue(any("capture_id" in error for error in validate_index(item)))

    def test_hazard_landmark_must_exist(self):
        item = index(); item["hazards"][0]["landmark_id"] = "missing"
        self.assertTrue(any("authored landmark" in error for error in validate_index(item)))

    def test_hazard_recovery_is_required(self):
        item = index(); item["hazards"][0]["recovery_id"] = ""
        self.assertTrue(any("recovery_id" in error for error in validate_index(item)))

    def test_landmark_review_stays_open(self):
        item = index(); item["landmarks"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_index(item)))

    def test_native_render_stays_open(self):
        item = index(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
