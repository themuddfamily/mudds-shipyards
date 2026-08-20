import unittest

from tools.review.planetary_hazard_manifest_identity_count_visual_v14 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_manifest_identity_count_visual_v14", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "bbd3385",
        "counts": {"hazard": 1, "landmark": 1, "route": 1, "total": 3}, "records": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "status": "pending"}],
        "identity_count_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["identity_count_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardManifestIdentityCountVisualV14Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_counts_must_sum(self):
        item = manifest(); item["counts"]["total"] = 4
        self.assertTrue(any("category sum" in error for error in validate_manifest(item)))

    def test_counts_must_be_positive(self):
        item = manifest(); item["counts"]["route"] = 0
        self.assertTrue(any("counts.route" in error for error in validate_manifest(item)))

    def test_record_manifest_ids_must_match(self):
        item = manifest(); item["records"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_record_kinds_cover_all_categories(self):
        item = manifest(); item["records"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_identity_count_status_stays_open(self):
        item = manifest(); item["identity_count_status"] = "approved"
        self.assertTrue(any("identity_count_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
