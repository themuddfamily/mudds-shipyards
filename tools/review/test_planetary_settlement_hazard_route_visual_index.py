import unittest

from tools.review.planetary_settlement_hazard_route_visual_index import validate_index


def index():
    return {
        "schema": "planetary_settlement_hazard_route_visual_v1", "world_id": "ember_moon", "settlement_id": "caldera_staging", "source_revision": "f6fe61b",
        "routes": [{"id": "pad_to_relay", "from_marker": "pad", "to_marker": "relay", "capture_id": "route-capture", "review_status": "pending"}],
        "hazards": [{"id": "relay_arc", "kind": "exposed_reactor", "route_id": "pad_to_relay", "recovery_id": "safe_recovery", "capture_id": "hazard-capture", "review_status": "not_performed", "runtime_resolution": "external_hazard_authority"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["hazard_runtime", "native_render", "human_review"],
    }


class PlanetarySettlementHazardRouteVisualIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_route_capture_is_required(self):
        item = index(); item["routes"][0]["capture_id"] = ""
        self.assertTrue(any("capture_id" in error for error in validate_index(item)))

    def test_hazard_kind_is_strict(self):
        item = index(); item["hazards"][0]["kind"] = "procedural_noise"
        self.assertTrue(any("kind is invalid" in error for error in validate_index(item)))

    def test_hazard_route_must_exist(self):
        item = index(); item["hazards"][0]["route_id"] = "missing"
        self.assertTrue(any("authored route" in error for error in validate_index(item)))

    def test_hazard_recovery_is_required(self):
        item = index(); item["hazards"][0]["recovery_id"] = ""
        self.assertTrue(any("recovery_id" in error for error in validate_index(item)))

    def test_external_runtime_boundary_is_required(self):
        item = index(); item["hazards"][0]["runtime_resolution"] = "runtime"
        self.assertTrue(any("external" in error for error in validate_index(item)))

    def test_human_review_stays_open(self):
        item = index(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
