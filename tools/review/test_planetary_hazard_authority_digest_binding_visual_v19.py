import unittest

from tools.review.planetary_hazard_authority_digest_binding_visual_v19 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_authority_digest_binding_visual_v19", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "d31e03e",
        "entries": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "runtime_authority": False, "digest_ref": "res://docs/evidence/hazard.png", "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "runtime_authority": False, "digest_ref": "res://docs/evidence/landmark.png", "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "runtime_authority": False, "digest_ref": "res://docs/evidence/route.png", "status": "pending"}],
        "binding_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["runtime_binding", "native_render", "human_signoff"],
    }


class PlanetaryHazardAuthorityDigestBindingVisualV19Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_runtime_authority_must_be_false(self):
        item = manifest(); item["entries"][0]["runtime_authority"] = True
        self.assertTrue(any("runtime_authority" in error for error in validate_manifest(item)))

    def test_digest_ref_must_be_res_path(self):
        item = manifest(); item["entries"][0]["digest_ref"] = "hazard.png"
        self.assertTrue(any("digest_ref" in error for error in validate_manifest(item)))

    def test_manifest_ids_must_match(self):
        item = manifest(); item["entries"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_binding_kinds_cover_all_categories(self):
        item = manifest(); item["entries"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_binding_status_stays_open(self):
        item = manifest(); item["binding_status"] = "approved"
        self.assertTrue(any("binding_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
