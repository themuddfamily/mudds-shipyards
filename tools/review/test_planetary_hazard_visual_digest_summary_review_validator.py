import unittest

from tools.review.planetary_hazard_visual_digest_summary_review_validator import validate_review


def review():
    return {
        "schema": "planetary_hazard_visual_digest_summary_review_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "5264848", "reviewer_role": "visual-reviewer",
        "questions": [{"id": "hazard", "kind": "hazard", "prompt": "Does the hazard read?", "status": "pending"}, {"id": "route", "kind": "route", "prompt": "Does the route read?", "status": "not_performed"}, {"id": "landmark", "kind": "landmark", "prompt": "Does the landmark read?", "status": "pending"}],
        "summary": {"status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["summary_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardVisualDigestSummaryReviewValidatorTest(unittest.TestCase):
    def test_open_review_is_valid(self):
        self.assertEqual(validate_review(review()), [])

    def test_question_ids_are_unique(self):
        item = review(); item["questions"].append(dict(item["questions"][0]))
        self.assertTrue(any("unique" in error for error in validate_review(item)))

    def test_question_kinds_are_strict(self):
        item = review(); item["questions"][0]["kind"] = "other"
        self.assertTrue(any("kind is invalid" in error for error in validate_review(item)))

    def test_prompt_is_required(self):
        item = review(); item["questions"][0]["prompt"] = ""
        self.assertTrue(any("prompt" in error for error in validate_review(item)))

    def test_question_status_stays_open(self):
        item = review(); item["questions"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_review(item)))

    def test_summary_stays_open(self):
        item = review(); item["summary"]["status"] = "complete"
        self.assertTrue(any("summary" in error for error in validate_review(item)))

    def test_human_signoff_stays_open(self):
        item = review(); item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("human_signoff" in error for error in validate_review(item)))

    def test_exclusions_are_required(self):
        item = review(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_review(item)))


if __name__ == "__main__":
    unittest.main()
