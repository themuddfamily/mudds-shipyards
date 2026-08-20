import unittest

from tools.review.planetary_hazard_digest_review_summary_v3 import validate_summary


def summary():
    return {
        "schema": "planetary_hazard_digest_review_summary_v3", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "1547d99", "reviewer_role": "visual-reviewer",
        "observations": [{"kind": "hazard", "item_count": 2, "observation": "hazard reads", "status": "pending"}, {"kind": "landmark", "item_count": 3, "observation": "landmark reads", "status": "not_performed"}, {"kind": "route", "item_count": 2, "observation": "route reads", "status": "pending"}],
        "summary_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["summary_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardDigestReviewSummaryV3Test(unittest.TestCase):
    def test_open_summary_is_valid(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_observation_kinds_are_unique(self):
        item = summary(); item["observations"][2]["kind"] = "hazard"
        self.assertTrue(any("unique" in error for error in validate_summary(item)))

    def test_item_counts_are_positive(self):
        item = summary(); item["observations"][0]["item_count"] = 0
        self.assertTrue(any("item_count" in error for error in validate_summary(item)))

    def test_observations_are_required(self):
        item = summary(); item["observations"][0]["observation"] = ""
        self.assertTrue(any("observation" in error for error in validate_summary(item)))

    def test_observation_status_stays_open(self):
        item = summary(); item["observations"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_summary(item)))

    def test_summary_status_stays_open(self):
        item = summary(); item["summary_status"] = "complete"
        self.assertTrue(any("summary_status" in error for error in validate_summary(item)))

    def test_native_render_stays_open(self):
        item = summary(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_summary(item)))

    def test_exclusions_are_required(self):
        item = summary(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
