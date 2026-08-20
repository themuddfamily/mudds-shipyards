import unittest

from tools.review.planetary_hazard_landmark_visual_evidence_digest_summary import validate_summary


def summary():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_summary_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "badd204",
        "counts": {"hazard": 1, "landmark": 1, "route": 1, "total": 3}, "coverage": ["hazard", "landmark", "route"], "summary_digest": {"algorithm": "sha256", "status": "pending"}, "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["summary_approval", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkVisualEvidenceDigestSummaryTest(unittest.TestCase):
    def test_open_summary_is_valid(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_counts_must_sum(self):
        item = summary(); item["counts"]["total"] = 4
        self.assertTrue(any("total must equal" in error for error in validate_summary(item)))

    def test_categories_must_be_covered(self):
        item = summary(); item["coverage"] = ["hazard"]
        self.assertTrue(any("coverage" in error for error in validate_summary(item)))

    def test_digest_algorithm_is_strict(self):
        item = summary(); item["summary_digest"]["algorithm"] = "md5"
        self.assertTrue(any("sha256" in error for error in validate_summary(item)))

    def test_digest_status_stays_open(self):
        item = summary(); item["summary_digest"]["status"] = "approved"
        self.assertTrue(any("summary_digest" in error for error in validate_summary(item)))

    def test_total_needs_all_categories(self):
        item = summary(); item["counts"]["total"] = 2; item["counts"]["hazard"] = 1; item["counts"]["landmark"] = 1; item["counts"]["route"] = 0
        self.assertTrue(any("three evidence" in error for error in validate_summary(item)))

    def test_human_review_stays_open(self):
        item = summary(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_summary(item)))

    def test_exclusions_are_required(self):
        item = summary(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
