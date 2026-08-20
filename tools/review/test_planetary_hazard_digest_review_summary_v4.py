import unittest

from tools.review.planetary_hazard_digest_review_summary_v4 import validate_summary


def summary():
    return {
        "schema": "planetary_hazard_digest_review_summary_v4", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "86cba14", "reviewer_role": "visual-reviewer",
        "sections": [{"kind": "hazard", "count": 2, "evidence_refs": ["res://docs/evidence/hazard.png"], "status": "pending"}, {"kind": "landmark", "count": 3, "evidence_refs": ["res://docs/evidence/landmark.png"], "status": "not_performed"}, {"kind": "route", "count": 2, "evidence_refs": ["res://docs/evidence/route.png"], "status": "pending"}],
        "summary_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["summary_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardDigestReviewSummaryV4Test(unittest.TestCase):
    def test_open_summary_is_valid(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_section_kinds_are_unique(self):
        item = summary(); item["sections"][2]["kind"] = "hazard"
        self.assertTrue(any("unique" in error for error in validate_summary(item)))

    def test_counts_must_be_positive(self):
        item = summary(); item["sections"][0]["count"] = 0
        self.assertTrue(any("count must be positive" in error for error in validate_summary(item)))

    def test_evidence_refs_must_be_res_paths(self):
        item = summary(); item["sections"][0]["evidence_refs"] = ["hazard.png"]
        self.assertTrue(any("evidence_refs" in error for error in validate_summary(item)))

    def test_section_status_stays_open(self):
        item = summary(); item["sections"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_summary(item)))

    def test_summary_status_stays_open(self):
        item = summary(); item["summary_status"] = "complete"
        self.assertTrue(any("summary_status" in error for error in validate_summary(item)))

    def test_human_signoff_stays_open(self):
        item = summary(); item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("human_signoff" in error for error in validate_summary(item)))

    def test_exclusions_are_required(self):
        item = summary(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
