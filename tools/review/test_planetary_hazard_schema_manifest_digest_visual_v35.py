import unittest

from tools.review.planetary_hazard_schema_manifest_digest_visual_v35 import validate_manifest


def manifest():
    schema = "planetary_hazard_schema_manifest_digest_visual_v35"
    root, authority = "world_root", "external_visual_authority"
    pairs = []
    for ident, kind, source, review, status in (("hazard", "hazard", "a", "b", "pending"), ("landmark", "landmark", "c", "d", "not_performed"), ("route", "route", "e", "f", "pending")):
        pairs.append({"id": ident, "kind": kind, "schema": schema, "schema_version": 35, "parent_id": root, "authority_id": authority, "source_sha256": source * 64, "review_sha256": review * 64, "runtime_authority": False, "status": status})
    return {"schema": schema, "schema_version": 35, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "source_revision": "b77fe17", "pairs": pairs, "manifest_digest": {"schema": schema, "schema_version": 35, "algorithm": "sha256", "value": "1" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["manifest_digest_approval", "native_render", "human_signoff"]}


class PlanetaryHazardSchemaManifestDigestVisualV35Test(unittest.TestCase):
    def test_valid_open_manifest(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_version_strict(self):
        item = manifest(); item["schema_version"] = 34
        self.assertTrue(any("schema_version must be 35" in e for e in validate_manifest(item)))

    def test_pair_schema_and_version_strict(self):
        item = manifest(); item["pairs"][0]["schema"] = "other"
        self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(item)))

    def test_manifest_digest_strict(self):
        item = manifest(); item["manifest_digest"]["algorithm"] = "md5"; item["manifest_digest"]["schema_version"] = 34
        self.assertTrue(any("v35 sha256" in e for e in validate_manifest(item)))

    def test_root_authority_bindings(self):
        item = manifest(); item["pairs"][1]["authority_id"] = "other"
        self.assertTrue(any("match manifest" in e for e in validate_manifest(item)))

    def test_digest_value_format(self):
        item = manifest(); item["manifest_digest"]["value"] = "short"
        self.assertTrue(any("64-character" in e for e in validate_manifest(item)))

    def test_native_human_gates_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        errors = validate_manifest(item)
        self.assertTrue(any("native_render" in e for e in errors)); self.assertTrue(any("human_signoff" in e for e in errors))

    def test_exclusions_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in e for e in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
