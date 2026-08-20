import unittest

from tools.review.planetary_hazard_landmark_visual_digest_summary_v6 import validate_summary


def summary():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_summary_v6", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "044a634", "reviewer_role": "visual-reviewer",
        "items": [{"kind": "hazard", "count": 2, "confidence": "structural_only", "evidence_path": "res://docs/evidence/hazard.png", "status": "pending"}, {"kind": "landmark", "count": 3, "confidence": "unassessed", "evidence_path": "res://docs/evidence/landmark.png", "status": "not_performed"}, {"kind": "route", "count": 2, "confidence": "structural_only", "evidence_path": "res://docs/evidence/route.png", "status": "pending"}],
        "summary_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardLandmarkVisualDigestSummaryV6Test(unittest.TestCase):
    def test_open_summary_is_valid(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_item_kinds_are_unique(self):
        item = summary(); item["items"][2]["kind"] = "hazard"
        self.assertTrue(any("unique" in error for error in validate_summary(item)))

    def test_counts_must_be_positive(self):
        item = summary(); item["items"][0]["count"] = 0
        self.assertTrue(any("count must be positive" in error for error in validate_summary(item)))

    def test_confidence_is_conservative(self):
        item = summary(); item["items"][0]["confidence"] = "approved"
        self.assertTrue(any("confidence" in error for error in validate_summary(item)))

    def test_evidence_path_must_be_res_path(self):
        item = summary(); item["items"][0]["evidence_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_summary(item)))

    def test_item_status_stays_open(self):
        item = summary(); item["items"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_summary(item)))

    def test_native_signoff_stays_open(self):
        item = summary(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_summary(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_summary(item)))

    def test_exclusions_are_required(self):
        item = summary(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
