import unittest

from tools.review.planetary_hazard_visual_digest_summary_count_validator import validate_counts


def summary():
    return {
        "schema": "planetary_hazard_visual_digest_summary_count_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "024406a",
        "counts": {"hazard": 2, "landmark": 3, "route": 2, "total": 7}, "coverage_status": {"hazard": "pending", "landmark": "not_performed", "route": "pending"}, "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["count_approval", "native_render", "human_review"],
    }


class PlanetaryHazardVisualDigestSummaryCountValidatorTest(unittest.TestCase):
    def test_open_counts_are_valid(self):
        self.assertEqual(validate_counts(summary()), [])

    def test_counts_must_be_positive(self):
        item = summary(); item["counts"]["hazard"] = 0
        self.assertTrue(any("counts.hazard" in error for error in validate_counts(item)))

    def test_total_must_equal_category_sum(self):
        item = summary(); item["counts"]["total"] = 6
        self.assertTrue(any("category sum" in error for error in validate_counts(item)))

    def test_coverage_categories_stay_open(self):
        item = summary(); item["coverage_status"]["route"] = "PASS"
        self.assertTrue(any("coverage_status.route" in error for error in validate_counts(item)))

    def test_coverage_status_is_required(self):
        item = summary(); item.pop("coverage_status")
        self.assertTrue(any("coverage_status" in error for error in validate_counts(item)))

    def test_native_render_stays_open(self):
        item = summary(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_counts(item)))

    def test_human_review_stays_open(self):
        item = summary(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_counts(item)))

    def test_exclusions_are_required(self):
        item = summary(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_counts(item)))


if __name__ == "__main__":
    unittest.main()
