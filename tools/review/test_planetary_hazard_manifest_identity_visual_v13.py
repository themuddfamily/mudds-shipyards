import unittest

from tools.review.planetary_hazard_manifest_identity_visual_v13 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_manifest_identity_visual_v13", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "e180eb6",
        "records": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "status": "pending"}],
        "identity_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["identity_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardManifestIdentityVisualV13Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_id_is_distinct(self):
        item = manifest(); item["manifest_id"] = item["region_id"]
        self.assertTrue(any("distinct" in error for error in validate_manifest(item)))

    def test_record_ids_are_unique(self):
        item = manifest(); item["records"][1]["id"] = item["records"][0]["id"]
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_record_manifest_id_must_match(self):
        item = manifest(); item["records"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_record_kinds_cover_all_categories(self):
        item = manifest(); item["records"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_identity_status_stays_open(self):
        item = manifest(); item["identity_status"] = "approved"
        self.assertTrue(any("identity_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
