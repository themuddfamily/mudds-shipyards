import unittest

from tools.review.planetary_hazard_versioned_root_authority_digest_visual_v33 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_versioned_root_authority_digest_visual_v33", "schema_version": 33, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": "world_root", "authority_id": "external_visual_authority", "source_revision": "4fac2aa",
        "pairs": [{"id": "hazard", "kind": "hazard", "parent_id": "world_root", "authority_id": "external_visual_authority", "schema_version": 33, "source_sha256": "a" * 64, "review_sha256": "b" * 64, "runtime_authority": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "world_root", "authority_id": "external_visual_authority", "schema_version": 33, "source_sha256": "c" * 64, "review_sha256": "d" * 64, "runtime_authority": False, "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "world_root", "authority_id": "external_visual_authority", "schema_version": 33, "source_sha256": "e" * 64, "review_sha256": "f" * 64, "runtime_authority": False, "status": "pending"}],
        "authority_digest": {"schema_version": 33, "algorithm": "sha256", "value": "1" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["versioned_authority_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardVersionedRootAuthorityDigestVisualV33Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_version_is_strict(self):
        item = manifest(); item["schema_version"] = 32
        self.assertTrue(any("schema_version must be 33" in error for error in validate_manifest(item)))

    def test_pair_version_is_strict(self):
        item = manifest(); item["pairs"][0]["schema_version"] = 32
        self.assertTrue(any("schema_version must be 33" in error for error in validate_manifest(item)))

    def test_digest_version_and_algorithm_are_strict(self):
        item = manifest(); item["authority_digest"]["schema_version"] = 32; item["authority_digest"]["algorithm"] = "md5"
        self.assertTrue(any("v33 sha256" in error for error in validate_manifest(item)))

    def test_bindings_match_root_authority(self):
        item = manifest(); item["pairs"][0]["authority_id"] = "other"
        self.assertTrue(any("must match manifest" in error for error in validate_manifest(item)))

    def test_runtime_authority_is_false(self):
        item = manifest(); item["pairs"][0]["runtime_authority"] = True
        self.assertTrue(any("runtime_authority" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
