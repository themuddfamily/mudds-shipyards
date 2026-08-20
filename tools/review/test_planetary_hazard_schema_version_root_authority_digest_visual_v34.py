import unittest

from tools.review.planetary_hazard_schema_version_root_authority_digest_visual_v34 import validate_manifest


def manifest():
    root = "world_root"
    authority = "external_visual_authority"
    return {
        "schema": "planetary_hazard_schema_version_root_authority_digest_visual_v34", "schema_version": 34,
        "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest",
        "root_id": root, "authority_id": authority, "source_revision": "2c0766e",
        "pairs": [
            {"id": "hazard", "kind": "hazard", "schema": "planetary_hazard_schema_version_root_authority_digest_visual_v34", "schema_version": 34, "parent_id": root, "authority_id": authority, "source_sha256": "a" * 64, "review_sha256": "b" * 64, "runtime_authority": False, "status": "pending"},
            {"id": "landmark", "kind": "landmark", "schema": "planetary_hazard_schema_version_root_authority_digest_visual_v34", "schema_version": 34, "parent_id": root, "authority_id": authority, "source_sha256": "c" * 64, "review_sha256": "d" * 64, "runtime_authority": False, "status": "not_performed"},
            {"id": "route", "kind": "route", "schema": "planetary_hazard_schema_version_root_authority_digest_visual_v34", "schema_version": 34, "parent_id": root, "authority_id": authority, "source_sha256": "e" * 64, "review_sha256": "f" * 64, "runtime_authority": False, "status": "pending"},
        ],
        "authority_digest": {"schema": "planetary_hazard_schema_version_root_authority_digest_visual_v34", "schema_version": 34, "algorithm": "sha256", "value": "1" * 64, "status": "pending"},
        "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"},
        "claims_excluded": ["schema_authority_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardSchemaVersionRootAuthorityDigestVisualV34Test(unittest.TestCase):
    def test_valid_open_manifest(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_schema_version_strict(self):
        item = manifest(); item["schema_version"] = 33
        self.assertTrue(any("schema_version must be 34" in e for e in validate_manifest(item)))

    def test_pair_schema_strict(self):
        item = manifest(); item["pairs"][0]["schema"] = "other"
        self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(item)))

    def test_pair_version_strict(self):
        item = manifest(); item["pairs"][0]["schema_version"] = 33
        self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(item)))

    def test_digest_schema_and_algorithm_strict(self):
        item = manifest(); item["authority_digest"]["schema_version"] = 33; item["authority_digest"]["algorithm"] = "md5"
        self.assertTrue(any("v34 sha256" in e for e in validate_manifest(item)))

    def test_root_authority_bindings(self):
        item = manifest(); item["pairs"][0]["parent_id"] = "other"
        self.assertTrue(any("match manifest" in e for e in validate_manifest(item)))

    def test_runtime_and_gates_stay_open(self):
        item = manifest(); item["pairs"][0]["runtime_authority"] = True; item["native_render"]["status"] = "PASS"
        errors = validate_manifest(item)
        self.assertTrue(any("runtime_authority" in e for e in errors)); self.assertTrue(any("native_render" in e for e in errors))

    def test_exclusions_preserve_open_claims(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in e for e in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
