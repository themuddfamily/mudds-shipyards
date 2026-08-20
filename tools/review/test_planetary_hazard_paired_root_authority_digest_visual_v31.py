import unittest

from tools.review.planetary_hazard_paired_root_authority_digest_visual_v31 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_paired_root_authority_digest_visual_v31", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": "world_root", "authority_id": "external_visual_authority", "source_revision": "e3ec052",
        "pairs": [{"id": "hazard", "kind": "hazard", "parent_id": "world_root", "authority_id": "external_visual_authority", "source_sha256": "a" * 64, "review_sha256": "b" * 64, "runtime_authority": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "world_root", "authority_id": "external_visual_authority", "source_sha256": "c" * 64, "review_sha256": "d" * 64, "runtime_authority": False, "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "world_root", "authority_id": "external_visual_authority", "source_sha256": "e" * 64, "review_sha256": "f" * 64, "runtime_authority": False, "status": "pending"}],
        "authority_digest": {"sha256": "1" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["authority_digest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardPairedRootAuthorityDigestVisualV31Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_root_and_authority_bindings_match(self):
        item = manifest(); item["pairs"][0]["authority_id"] = "other"
        self.assertTrue(any("must match manifest" in error for error in validate_manifest(item)))

    def test_runtime_authority_is_false(self):
        item = manifest(); item["pairs"][0]["runtime_authority"] = True
        self.assertTrue(any("runtime_authority" in error for error in validate_manifest(item)))

    def test_source_digest_is_strict(self):
        item = manifest(); item["pairs"][0]["source_sha256"] = "bad"
        self.assertTrue(any("source_sha256" in error for error in validate_manifest(item)))

    def test_review_digest_is_strict(self):
        item = manifest(); item["pairs"][0]["review_sha256"] = "bad"
        self.assertTrue(any("review_sha256" in error for error in validate_manifest(item)))

    def test_authority_digest_is_strict(self):
        item = manifest(); item["authority_digest"]["sha256"] = "bad"
        self.assertTrue(any("authority_digest" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
