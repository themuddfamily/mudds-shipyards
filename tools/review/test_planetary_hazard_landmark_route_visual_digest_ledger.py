import unittest

from tools.review.planetary_hazard_landmark_route_visual_digest_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_hazard_landmark_route_visual_digest_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "8b49a33",
        "captures": [{"id": "route-view", "path": "res://docs/evidence/route.png", "sha256": "a" * 64, "review_status": "pending"}],
        "routes": [{"id": "pad_hazard", "capture_id": "route-view", "hazard_id": "dust_surge", "landmark_id": "hazard_marker", "review_status": "not_performed"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["capture_verification", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkRouteVisualDigestLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_capture_digest_is_strict(self):
        item = ledger(); item["captures"][0]["sha256"] = "short"
        self.assertTrue(any("sha256" in error for error in validate_ledger(item)))

    def test_capture_path_is_res_path(self):
        item = ledger(); item["captures"][0]["path"] = "route.png"
        self.assertTrue(any("res://" in error for error in validate_ledger(item)))

    def test_route_capture_must_exist(self):
        item = ledger(); item["routes"][0]["capture_id"] = "missing"
        self.assertTrue(any("reference a capture" in error for error in validate_ledger(item)))

    def test_route_needs_hazard_and_landmark(self):
        item = ledger(); item["routes"][0]["hazard_id"] = ""
        self.assertTrue(any("hazard_id" in error for error in validate_ledger(item)))

    def test_capture_review_stays_open(self):
        item = ledger(); item["captures"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_ledger(item)))

    def test_human_gate_stays_open(self):
        item = ledger(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
