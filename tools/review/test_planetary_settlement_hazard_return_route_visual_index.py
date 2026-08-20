import unittest

from tools.review.planetary_settlement_hazard_return_route_visual_index import validate_index


def index():
    return {
        "schema": "planetary_settlement_hazard_return_route_v1", "world_id": "ember_moon", "settlement_id": "caldera_staging", "source_revision": "306bdfe",
        "return_routes": [{"id": "dust_return", "hazard_id": "dust_surge", "safe_anchor_id": "relay", "return_anchor_id": "pad", "capture_id": "return-capture", "scene_path": "res://scenes/world/settlements/caldera_return_route.tscn", "review_status": "pending", "runtime_teleport": False}],
        "hazards": [{"id": "dust_surge", "return_route_id": "dust_return", "evidence_status": "not_performed"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["runtime_teleport", "native_render", "human_review"],
    }


class PlanetarySettlementHazardReturnRouteVisualIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_route_requires_all_anchors(self):
        item = index(); item["return_routes"][0]["safe_anchor_id"] = ""
        self.assertTrue(any("safe_anchor_id" in error for error in validate_index(item)))

    def test_route_scene_path_must_be_res_path(self):
        item = index(); item["return_routes"][0]["scene_path"] = "route.tscn"
        self.assertTrue(any("scene_path" in error for error in validate_index(item)))

    def test_runtime_teleport_is_rejected(self):
        item = index(); item["return_routes"][0]["runtime_teleport"] = True
        self.assertTrue(any("runtime_teleport" in error for error in validate_index(item)))

    def test_route_hazard_must_exist(self):
        item = index(); item["return_routes"][0]["hazard_id"] = "missing"
        self.assertTrue(any("authored hazard" in error for error in validate_index(item)))

    def test_hazard_return_route_must_exist(self):
        item = index(); item["hazards"][0]["return_route_id"] = "missing"
        self.assertTrue(any("return route" in error for error in validate_index(item)))

    def test_human_review_stays_open(self):
        item = index(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
