import unittest

from tools.review.planetary_hazard_visual_digest_summary_index import validate_index


def index():
    return {
        "schema": "planetary_hazard_visual_digest_summary_index_v1", "world_id": "ember_moon", "source_revision": "b80fa06",
        "regions": [{"region_id": "caldera_rim", "counts": {"hazard": 1, "route": 1, "landmark": 1}, "summary_status": "pending", "source_path": "res://docs/evidence/caldera_summary.json"}],
        "aggregate_status": "not_performed", "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["summary_index", "native_render", "human_review"],
    }


class PlanetaryHazardVisualDigestSummaryIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_region_ids_are_unique(self):
        item = index(); item["regions"].append(dict(item["regions"][0]))
        self.assertTrue(any("unique" in error for error in validate_index(item)))

    def test_counts_must_cover_categories(self):
        item = index(); item["regions"][0]["counts"]["route"] = 0
        self.assertTrue(any("counts.route" in error for error in validate_index(item)))

    def test_summary_status_stays_open(self):
        item = index(); item["regions"][0]["summary_status"] = "approved"
        self.assertTrue(any("summary_status" in error for error in validate_index(item)))

    def test_source_path_is_res_path(self):
        item = index(); item["regions"][0]["source_path"] = "summary.json"
        self.assertTrue(any("res://" in error for error in validate_index(item)))

    def test_aggregate_status_stays_open(self):
        item = index(); item["aggregate_status"] = "complete"
        self.assertTrue(any("aggregate_status" in error for error in validate_index(item)))

    def test_human_review_stays_open(self):
        item = index(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
