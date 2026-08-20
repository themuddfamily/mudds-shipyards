import unittest

from tools.review.planetary_hazard_manifest_digest_count_visual_v16 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_manifest_digest_count_visual_v16", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "cf875d1",
        "entries": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "count": 2, "sha256": "a" * 64, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "count": 3, "sha256": "b" * 64, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "count": 2, "sha256": "c" * 64, "status": "pending"}],
        "declared_total": 7, "manifest_digest": {"algorithm": "sha256", "value": "d" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["manifest_digest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardManifestDigestCountVisualV16Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_declared_total_must_match(self):
        item = manifest(); item["declared_total"] = 6
        self.assertTrue(any("declared_total" in error for error in validate_manifest(item)))

    def test_entry_digest_is_strict(self):
        item = manifest(); item["entries"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_manifest_digest_algorithm_and_value_are_strict(self):
        item = manifest(); item["manifest_digest"]["algorithm"] = "md5"; item["manifest_digest"]["value"] = "bad"
        self.assertTrue(any("manifest_digest" in error for error in validate_manifest(item)))

    def test_manifest_ids_must_match(self):
        item = manifest(); item["entries"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_digest_status_stays_open(self):
        item = manifest(); item["manifest_digest"]["status"] = "approved"
        self.assertTrue(any("manifest_digest.status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
