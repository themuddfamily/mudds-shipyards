import unittest

from tools.review.planetary_hazard_completeness_authority_visual_v18 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_completeness_authority_visual_v18", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "317102a",
        "entries": [{"id": "hazard", "kind": "hazard", "authority": False, "complete": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "authority": False, "complete": False, "status": "not_performed"}, {"id": "route", "kind": "route", "authority": False, "complete": False, "status": "pending"}],
        "authority_exclusions": ["hazard_runtime", "route_runtime", "visual_approval", "native_render", "human_signoff"], "authority_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"},
    }


class PlanetaryHazardCompletenessAuthorityVisualV18Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_entry_authority_must_be_false(self):
        item = manifest(); item["entries"][0]["authority"] = True
        self.assertTrue(any("authority must be false" in error for error in validate_manifest(item)))

    def test_entry_completeness_stays_false(self):
        item = manifest(); item["entries"][0]["complete"] = True
        self.assertTrue(any("complete must remain false" in error for error in validate_manifest(item)))

    def test_kinds_cover_all_categories(self):
        item = manifest(); item["entries"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["authority_exclusions"] = []
        self.assertTrue(any("authority_exclusions" in error for error in validate_manifest(item)))

    def test_authority_status_stays_open(self):
        item = manifest(); item["authority_status"] = "approved"
        self.assertTrue(any("authority_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_entry_status_stays_open(self):
        item = manifest(); item["entries"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
