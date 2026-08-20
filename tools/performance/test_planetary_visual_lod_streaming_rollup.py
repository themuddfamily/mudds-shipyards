import unittest

from tools.performance.planetary_visual_lod_streaming_rollup import validate_rollup


def rollup():
    return {
        "schema_version": 1, "world_id": "ember_moon", "source_revision": "a47f30c",
        "lod_tiers": [
            {"id": "near", "distance_m": {"min": 0, "max": 100}, "capture_id": "near-capture", "human_review_status": "pending", "triangle_budget": 120000},
            {"id": "mid", "distance_m": {"min": 100, "max": 1000}, "capture_id": "mid-capture", "human_review_status": "pending", "triangle_budget": 40000},
            {"id": "far", "distance_m": {"min": 1000, "max": 10000}, "capture_id": "far-capture", "human_review_status": "not_performed", "triangle_budget": 12000},
        ],
        "streaming": {"resident_tiles": 12, "resident_bytes": 4000000, "max_resident_tiles": 16, "max_resident_bytes": 8000000, "metric_status": "measured", "fabricated_metrics": False},
        "native_review": {"status": "NOT_RUN", "evidence": None},
        "authority_exclusions": ["native_gpu_performance", "human_visual_approval"],
    }


class PlanetaryVisualLodStreamingRollupTest(unittest.TestCase):
    def test_valid_rollup(self):
        self.assertEqual(validate_rollup(rollup()), [])

    def test_tiers_must_not_overlap(self):
        item = rollup(); item["lod_tiers"][1]["distance_m"]["min"] = 50
        self.assertTrue(any("overlaps" in error for error in validate_rollup(item)))

    def test_tier_budget_must_be_positive(self):
        item = rollup(); item["lod_tiers"][0]["triangle_budget"] = 0
        self.assertTrue(any("triangle_budget" in error for error in validate_rollup(item)))

    def test_human_approval_cannot_be_claimed(self):
        item = rollup(); item["lod_tiers"][0]["human_review_status"] = "approved"
        self.assertTrue(any("human_review_status" in error for error in validate_rollup(item)))

    def test_streaming_ceiling_is_checked(self):
        item = rollup(); item["streaming"]["resident_tiles"] = 99
        self.assertTrue(any("exceeds ceiling" in error for error in validate_rollup(item)))

    def test_streaming_metrics_cannot_be_fabricated(self):
        item = rollup(); item["streaming"]["fabricated_metrics"] = True
        self.assertTrue(any("non-fabricated" in error for error in validate_rollup(item)))

    def test_native_gate_must_remain_not_run(self):
        item = rollup(); item["native_review"] = {"status": "PASS", "evidence": "capture"}
        self.assertTrue(any("NOT_RUN" in error for error in validate_rollup(item)))

    def test_human_and_native_exclusions_are_required(self):
        item = rollup(); item["authority_exclusions"] = []
        self.assertTrue(any("authority_exclusions" in error for error in validate_rollup(item)))


if __name__ == "__main__":
    unittest.main()
