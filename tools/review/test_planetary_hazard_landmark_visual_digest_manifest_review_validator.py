import unittest

from tools.review.planetary_hazard_landmark_visual_digest_manifest_review_validator import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_manifest_review_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "90b75d6", "reviewer_role": "art-reviewer",
        "records": [{"id": "hazard", "sha256": "a" * 64, "question": "does hazard read?", "answer_space": "pending reviewer observation", "status": "pending"}, {"id": "route", "sha256": "b" * 64, "question": "does route read?", "answer_space": "pending reviewer observation", "status": "not_performed"}],
        "review_summary": {"status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["review_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardLandmarkVisualDigestManifestReviewValidatorTest(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_record_ids_are_unique(self):
        item = manifest(); item["records"].append(dict(item["records"][0]))
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_record_digest_is_strict(self):
        item = manifest(); item["records"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_question_and_answer_space_are_required(self):
        item = manifest(); item["records"][0]["answer_space"] = ""
        self.assertTrue(any("answer_space" in error for error in validate_manifest(item)))

    def test_record_status_stays_open(self):
        item = manifest(); item["records"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_manifest(item)))

    def test_summary_stays_open(self):
        item = manifest(); item["review_summary"]["status"] = "complete"
        self.assertTrue(any("review_summary" in error for error in validate_manifest(item)))

    def test_native_gate_stays_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
