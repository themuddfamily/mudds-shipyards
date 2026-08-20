import unittest

from tools.review.planetary_hazard_visual_digest_summary_count_review_v2 import validate_review


def review():
    return {
        "schema": "planetary_hazard_visual_digest_summary_count_review_v2", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "6a6b297", "reviewer_role": "visual-reviewer",
        "categories": [{"kind": "hazard", "count": 2, "review_prompt": "Hazard count and read are credible", "status": "pending"}, {"kind": "landmark", "count": 3, "review_prompt": "Landmark count and read are credible", "status": "not_performed"}, {"kind": "route", "count": 2, "review_prompt": "Route count and read are credible", "status": "pending"}],
        "summary_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["count_review", "native_render", "human_signoff"],
    }


class PlanetaryHazardVisualDigestSummaryCountReviewV2Test(unittest.TestCase):
    def test_open_review_is_valid(self):
        self.assertEqual(validate_review(review()), [])

    def test_category_kinds_are_unique(self):
        item = review(); item["categories"][2]["kind"] = "hazard"
        self.assertTrue(any("unique" in error for error in validate_review(item)))

    def test_counts_must_be_positive(self):
        item = review(); item["categories"][0]["count"] = 0
        self.assertTrue(any("count must be positive" in error for error in validate_review(item)))

    def test_review_prompts_are_required(self):
        item = review(); item["categories"][0]["review_prompt"] = ""
        self.assertTrue(any("review_prompt" in error for error in validate_review(item)))

    def test_category_status_stays_open(self):
        item = review(); item["categories"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_review(item)))

    def test_summary_stays_open(self):
        item = review(); item["summary_status"] = "complete"
        self.assertTrue(any("summary_status" in error for error in validate_review(item)))

    def test_native_render_stays_open(self):
        item = review(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_review(item)))

    def test_exclusions_are_required(self):
        item = review(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_review(item)))


if __name__ == "__main__":
    unittest.main()
