import unittest

from tools.review.planetary_hazard_landmark_visual_digest_manifest_validator import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_manifest_validator_v1", "world_id": "ember_moon", "source_revision": "e69d98f",
        "artifacts": [{"id": "hazard", "kind": "hazard", "path": "res://docs/evidence/hazard.png", "sha256": "a" * 64, "verification_status": "pending"}, {"id": "landmark", "kind": "landmark", "path": "res://docs/evidence/landmark.png", "sha256": "b" * 64, "verification_status": "not_performed"}, {"id": "route", "kind": "route", "path": "res://docs/evidence/route.png", "sha256": "c" * 64, "verification_status": "pending"}],
        "aggregate_verification": {"status": "pending"}, "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["artifact_verification", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkVisualDigestManifestValidatorTest(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_artifacts_cover_required_kinds(self):
        item = manifest(); item["artifacts"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_artifact_ids_are_unique(self):
        item = manifest(); item["artifacts"].append(dict(item["artifacts"][0]))
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_artifact_paths_are_res_paths(self):
        item = manifest(); item["artifacts"][0]["path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_manifest(item)))

    def test_artifact_digests_are_strict(self):
        item = manifest(); item["artifacts"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_verification_status_stays_open(self):
        item = manifest(); item["artifacts"][0]["verification_status"] = "PASS"
        self.assertTrue(any("verification_status" in error for error in validate_manifest(item)))

    def test_human_review_stays_open(self):
        item = manifest(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
