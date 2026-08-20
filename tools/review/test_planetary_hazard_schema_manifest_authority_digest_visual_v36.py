import unittest

from tools.review.planetary_hazard_schema_manifest_authority_digest_visual_v36 import validate_manifest


def manifest():
    schema = "planetary_hazard_schema_manifest_authority_digest_visual_v36"; root = "world_root"; authority = "external_visual_authority"
    pairs = [{"id": i, "kind": k, "schema": schema, "schema_version": 36, "parent_id": root, "authority_id": authority, "source_sha256": s * 64, "review_sha256": r * 64, "runtime_authority": False, "status": st} for i, k, s, r, st in (("hazard", "hazard", "a", "b", "pending"), ("landmark", "landmark", "c", "d", "not_performed"), ("route", "route", "e", "f", "pending"))]
    return {"schema": schema, "schema_version": 36, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "source_revision": "255c641", "pairs": pairs, "authority_digest": {"schema": schema, "schema_version": 36, "algorithm": "sha256", "value": "1" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["authority_digest_approval", "native_render", "human_signoff"]}


class PlanetaryHazardSchemaManifestAuthorityDigestVisualV36Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        item = manifest(); item["schema_version"] = 35; self.assertTrue(any("schema_version must be 36" in e for e in validate_manifest(item)))
    def test_pair_schema_strict(self):
        item = manifest(); item["pairs"][0]["schema"] = "other"; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(item)))
    def test_pair_version_strict(self):
        item = manifest(); item["pairs"][0]["schema_version"] = 35; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(item)))
    def test_authority_digest_strict(self):
        item = manifest(); item["authority_digest"]["algorithm"] = "md5"; self.assertTrue(any("v36 sha256" in e for e in validate_manifest(item)))
    def test_bindings_match(self):
        item = manifest(); item["pairs"][0]["authority_id"] = "other"; self.assertTrue(any("match manifest" in e for e in validate_manifest(item)))
    def test_runtime_and_review_gates_open(self):
        item = manifest(); item["pairs"][0]["runtime_authority"] = True; item["human_signoff"]["status"] = "approved"; errors = validate_manifest(item)
        self.assertTrue(any("runtime_authority" in e for e in errors)); self.assertTrue(any("human_signoff" in e for e in errors))
    def test_exclusions_required(self):
        item = manifest(); item["claims_excluded"] = []; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(item)))


if __name__ == "__main__": unittest.main()
