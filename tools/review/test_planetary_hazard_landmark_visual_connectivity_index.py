import unittest

from tools.review.planetary_hazard_landmark_visual_connectivity_index import validate_index


def index():
    return {
        "schema": "planetary_hazard_landmark_visual_connectivity_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "79262be",
        "markers": [{"id": "pad", "capture_id": "pad-view", "visibility_status": "pending"}, {"id": "hazard", "capture_id": "hazard-view", "visibility_status": "not_performed"}],
        "visual_links": [{"id": "pad_hazard_link", "from_marker": "pad", "to_marker": "hazard", "route_id": "pad_to_hazard", "hazard_id": "dust_surge", "capture_id": "link-view", "review_status": "pending", "runtime_navigation": False}],
        "gates": {"native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}}, "claims_excluded": ["runtime_navigation", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkVisualConnectivityIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_markers_need_unique_ids(self):
        item = index(); item["markers"].append(dict(item["markers"][0]))
        self.assertTrue(any("unique" in error for error in validate_index(item)))

    def test_link_markers_must_exist(self):
        item = index(); item["visual_links"][0]["to_marker"] = "missing"
        self.assertTrue(any("known markers" in error for error in validate_index(item)))

    def test_link_needs_route_and_hazard(self):
        item = index(); item["visual_links"][0]["hazard_id"] = ""
        self.assertTrue(any("hazard_id" in error for error in validate_index(item)))

    def test_link_capture_is_required(self):
        item = index(); item["visual_links"][0]["capture_id"] = ""
        self.assertTrue(any("capture_id" in error for error in validate_index(item)))

    def test_runtime_navigation_is_rejected(self):
        item = index(); item["visual_links"][0]["runtime_navigation"] = True
        self.assertTrue(any("runtime_navigation" in error for error in validate_index(item)))

    def test_human_gate_stays_open(self):
        item = index(); item["gates"]["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
