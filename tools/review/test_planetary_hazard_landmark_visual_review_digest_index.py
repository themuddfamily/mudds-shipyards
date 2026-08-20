import unittest

from tools.review.planetary_hazard_landmark_visual_review_digest_index import validate_index


def index():
    return {
        "schema": "planetary_hazard_landmark_visual_review_digest_index_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "6729134",
        "digests": [{"id": "hazard", "kind": "hazard", "sha256": "a" * 64, "source_path": "res://docs/evidence/hazard.png", "review_status": "pending", "review_question": "hazard reads"}, {"id": "route", "kind": "route", "sha256": "b" * 64, "source_path": "res://docs/evidence/route.png", "review_status": "not_performed", "review_question": "route reads"}],
        "aggregate": {"sha256": "c" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["digest_index", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkVisualReviewDigestIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_digest_ids_are_unique(self):
        item = index(); item["digests"].append(dict(item["digests"][0]))
        self.assertTrue(any("unique" in error for error in validate_index(item)))

    def test_digest_kind_is_strict(self):
        item = index(); item["digests"][0]["kind"] = "other"
        self.assertTrue(any("kind is invalid" in error for error in validate_index(item)))

    def test_digest_hash_is_strict(self):
        item = index(); item["digests"][0]["sha256"] = "short"
        self.assertTrue(any("64-character" in error for error in validate_index(item)))

    def test_source_path_is_res_path(self):
        item = index(); item["digests"][0]["source_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_index(item)))

    def test_review_question_is_required(self):
        item = index(); item["digests"][0]["review_question"] = ""
        self.assertTrue(any("review_question" in error for error in validate_index(item)))

    def test_native_gate_stays_open(self):
        item = index(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
