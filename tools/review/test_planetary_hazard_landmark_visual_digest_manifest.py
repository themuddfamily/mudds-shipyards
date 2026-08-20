import unittest

from tools.review.planetary_hazard_landmark_visual_digest_manifest import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_manifest_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "e5453f1",
        "items": [{"id": "hazard", "kind": "hazard", "path": "res://docs/evidence/hazard.png", "sha256": "a" * 64, "review_status": "pending"}, {"id": "landmark", "kind": "landmark", "path": "res://docs/evidence/landmark.png", "sha256": "b" * 64, "review_status": "not_performed"}, {"id": "route", "kind": "route", "path": "res://docs/evidence/route.png", "sha256": "c" * 64, "review_status": "pending"}],
        "aggregate": {"status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["digest_manifest", "native_render", "human_signoff"],
    }


class PlanetaryHazardLandmarkVisualDigestManifestTest(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_all_visual_kinds_are_required(self):
        item = manifest(); item["items"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_item_ids_are_unique(self):
        item = manifest(); item["items"].append(dict(item["items"][0]))
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_paths_must_be_res_paths(self):
        item = manifest(); item["items"][0]["path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_manifest(item)))

    def test_digests_must_be_strict(self):
        item = manifest(); item["items"][0]["sha256"] = "short"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_item_review_status_stays_open(self):
        item = manifest(); item["items"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_manifest(item)))

    def test_native_render_stays_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
