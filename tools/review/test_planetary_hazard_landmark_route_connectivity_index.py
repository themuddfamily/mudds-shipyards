import unittest

from tools.review.planetary_hazard_landmark_route_connectivity_index import validate_index


def index():
    return {
        "schema": "planetary_hazard_landmark_route_connectivity_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "d902de5",
        "landmarks": [{"id": "pad", "role": "landing_pad", "capture_id": "pad-view", "review_status": "pending"}, {"id": "hazard", "role": "hazard_anchor", "capture_id": "hazard-view", "review_status": "pending"}, {"id": "recovery", "role": "recovery_anchor", "capture_id": "recovery-view", "review_status": "not_performed"}],
        "routes": [{"id": "pad_hazard", "from_landmark": "pad", "to_landmark": "hazard", "hazard_id": "dust_surge", "capture_id": "route-a", "distance_m": 24.0, "review_status": "pending"}, {"id": "hazard_recovery", "from_landmark": "hazard", "to_landmark": "recovery", "hazard_id": "dust_surge", "capture_id": "route-b", "distance_m": 18.0, "review_status": "not_performed"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["route_runtime", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkRouteConnectivityIndexTest(unittest.TestCase):
    def test_open_connected_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_route_distance_must_be_positive(self):
        item = index(); item["routes"][0]["distance_m"] = 0
        self.assertTrue(any("distance_m" in error for error in validate_index(item)))

    def test_route_landmarks_must_exist(self):
        item = index(); item["routes"][0]["to_landmark"] = "missing"
        self.assertTrue(any("known landmarks" in error for error in validate_index(item)))

    def test_route_capture_is_required(self):
        item = index(); item["routes"][0]["capture_id"] = ""
        self.assertTrue(any("capture_id" in error for error in validate_index(item)))

    def test_orphan_landmark_fails_connectivity(self):
        item = index(); item["landmarks"].append({"id": "orphan", "role": "hazard_anchor", "capture_id": "orphan-view", "review_status": "pending"})
        self.assertTrue(any("reach every" in error for error in validate_index(item)))

    def test_route_review_stays_open(self):
        item = index(); item["routes"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_index(item)))

    def test_native_gate_stays_open(self):
        item = index(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
