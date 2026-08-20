import unittest

from tools.review.planetary_hazard_digest_review_summary_v5 import validate_summary


def summary():
    return {
        "schema": "planetary_hazard_digest_review_summary_v5", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "2426ff4", "reviewer_role": "visual-reviewer",
        "sections": [{"kind": "hazard", "count": 2, "evidence_path": "res://docs/evidence/hazard.png", "review_prompt": "Hazard reads", "status": "pending"}, {"kind": "landmark", "count": 3, "evidence_path": "res://docs/evidence/landmark.png", "review_prompt": "Landmark reads", "status": "not_performed"}, {"kind": "route", "count": 2, "evidence_path": "res://docs/evidence/route.png", "review_prompt": "Route reads", "status": "pending"}],
        "summary_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["summary_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardDigestReviewSummaryV5Test(unittest.TestCase):
    def test_open_summary_is_valid(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_section_kinds_are_unique(self):
        item = summary(); item["sections"][2]["kind"] = "hazard"
        self.assertTrue(any("unique" in error for error in validate_summary(item)))

    def test_count_must_be_positive(self):
        item = summary(); item["sections"][0]["count"] = 0
        self.assertTrue(any("count must be positive" in error for error in validate_summary(item)))

    def test_evidence_path_must_be_res_path(self):
        item = summary(); item["sections"][0]["evidence_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_summary(item)))

    def test_review_prompt_is_required(self):
        item = summary(); item["sections"][0]["review_prompt"] = ""
        self.assertTrue(any("review_prompt" in error for error in validate_summary(item)))

    def test_section_status_stays_open(self):
        item = summary(); item["sections"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_summary(item)))

    def test_native_gate_stays_open(self):
        item = summary(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_summary(item)))

    def test_exclusions_are_required(self):
        item = summary(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
