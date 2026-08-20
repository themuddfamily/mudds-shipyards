import unittest

from tools.review.planetary_hazard_paired_root_authority_visual_v30 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_paired_root_authority_visual_v30", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": "world_root", "authority_id": "external_visual_authority", "source_revision": "81e4e87",
        "pairs": [{"id": "hazard", "kind": "hazard", "parent_id": "world_root", "authority_id": "external_visual_authority", "runtime_authority": False, "source_sha256": "a" * 64, "review_sha256": "b" * 64, "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "world_root", "authority_id": "external_visual_authority", "runtime_authority": False, "source_sha256": "c" * 64, "review_sha256": "d" * 64, "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "world_root", "authority_id": "external_visual_authority", "runtime_authority": False, "source_sha256": "e" * 64, "review_sha256": "f" * 64, "status": "pending"}],
        "authority_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["root_authority_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardPairedRootAuthorityVisualV30Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_pair_ids_differ_from_root(self):
        item = manifest(); item["pairs"][0]["id"] = "world_root"
        self.assertTrue(any("differ from root" in error for error in validate_manifest(item)))

    def test_parent_ids_equal_root(self):
        item = manifest(); item["pairs"][0]["parent_id"] = "other"
        self.assertTrue(any("parent_id" in error for error in validate_manifest(item)))

    def test_authority_ids_match(self):
        item = manifest(); item["pairs"][0]["authority_id"] = "other"
        self.assertTrue(any("authority_id" in error for error in validate_manifest(item)))

    def test_runtime_authority_is_false(self):
        item = manifest(); item["pairs"][0]["runtime_authority"] = True
        self.assertTrue(any("runtime_authority" in error for error in validate_manifest(item)))

    def test_authority_status_stays_open(self):
        item = manifest(); item["authority_status"] = "approved"
        self.assertTrue(any("authority_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
