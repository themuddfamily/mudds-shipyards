import unittest

from tools.review.planetary_hazard_manifest_count_digest_visual_v15 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_manifest_count_digest_visual_v15", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "9e0a7cd",
        "entries": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "count": 2, "sha256": "a" * 64, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "count": 3, "sha256": "b" * 64, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "count": 2, "sha256": "c" * 64, "status": "pending"}],
        "declared_total": 7, "count_digest_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["count_digest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardManifestCountDigestVisualV15Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_declared_total_must_match(self):
        item = manifest(); item["declared_total"] = 6
        self.assertTrue(any("entry count sum" in error for error in validate_manifest(item)))

    def test_entry_counts_must_be_positive(self):
        item = manifest(); item["entries"][0]["count"] = 0
        self.assertTrue(any("count must be positive" in error for error in validate_manifest(item)))

    def test_entry_digests_are_strict(self):
        item = manifest(); item["entries"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_manifest_ids_must_match(self):
        item = manifest(); item["entries"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_count_digest_status_stays_open(self):
        item = manifest(); item["count_digest_status"] = "approved"
        self.assertTrue(any("count_digest_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
