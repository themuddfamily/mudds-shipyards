import unittest

from tools.review.planetary_hazard_return_route_visual_review_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_hazard_return_route_visual_review_v1", "world_id": "ember_moon", "route_id": "dust_return", "source_revision": "5ff27d1",
        "stages": [{"id": "hazard", "capture_id": "hazard-view", "visual_question": "is the hazard legible?", "review_status": "pending"}, {"id": "safe_anchor", "capture_id": "safe-view", "visual_question": "is recovery anchor readable?", "review_status": "pending"}, {"id": "return_anchor", "capture_id": "return-view", "visual_question": "is return route obvious?", "review_status": "not_performed"}],
        "recovery": {"recovery_id": "return_to_pad", "safe_anchor_id": "relay", "return_anchor_id": "pad", "runtime_resolution": "external_recovery_authority", "review_status": "pending"},
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["recovery_runtime", "native_render", "human_review"],
    }


class PlanetaryHazardReturnRouteVisualReviewLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_stages_are_ordered(self):
        item = ledger(); item["stages"][1]["id"] = "return_anchor"
        self.assertTrue(any("out of order" in error for error in validate_ledger(item)))

    def test_stage_capture_and_question_are_required(self):
        item = ledger(); item["stages"][0]["visual_question"] = ""
        self.assertTrue(any("visual_question" in error for error in validate_ledger(item)))

    def test_recovery_anchors_are_required(self):
        item = ledger(); item["recovery"]["safe_anchor_id"] = ""
        self.assertTrue(any("safe_anchor_id" in error for error in validate_ledger(item)))

    def test_recovery_runtime_boundary_is_external(self):
        item = ledger(); item["recovery"]["runtime_resolution"] = "teleport"
        self.assertTrue(any("external" in error for error in validate_ledger(item)))

    def test_stage_review_stays_open(self):
        item = ledger(); item["stages"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_ledger(item)))

    def test_human_review_stays_open(self):
        item = ledger(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
