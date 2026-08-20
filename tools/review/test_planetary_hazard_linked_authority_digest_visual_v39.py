import unittest
from tools.review.planetary_hazard_linked_authority_digest_visual_v39 import validate_manifest

def manifest():
    schema = "planetary_hazard_linked_authority_digest_visual_v39"; root = "world_root"; authority = "external_visual_authority"; linked = "review_authority"
    pairs = [{"id": i, "kind": k, "schema": schema, "schema_version": 39, "parent_id": root, "authority_id": authority, "linked_authority_id": linked, "source_sha256": s * 64, "review_sha256": r * 64, "runtime_authority": False, "status": st} for i, k, s, r, st in (("hazard", "hazard", "a", "b", "pending"), ("landmark", "landmark", "c", "d", "not_performed"), ("route", "route", "e", "f", "pending"))]
    return {"schema": schema, "schema_version": 39, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "linked_authority_id": linked, "source_revision": "824ca6d", "pairs": pairs, "linked_authority_digest": {"schema": schema, "schema_version": 39, "algorithm": "sha256", "value": "1" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["linked_authority_approval", "native_render", "human_signoff"]}

class PlanetaryHazardLinkedAuthorityDigestVisualV39Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=38; self.assertTrue(any("schema_version must be 39" in e for e in validate_manifest(x)))
    def test_pair_schema_strict(self):
        x=manifest(); x["pairs"][0]["schema"]="other"; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(x)))
    def test_linked_digest_strict(self):
        x=manifest(); x["linked_authority_digest"]["algorithm"]="md5"; self.assertTrue(any("v39 sha256" in e for e in validate_manifest(x)))
    def test_linked_binding_matches(self):
        x=manifest(); x["pairs"][1]["linked_authority_id"]="other"; self.assertTrue(any("authority bindings" in e for e in validate_manifest(x)))
    def test_runtime_authority_false(self):
        x=manifest(); x["pairs"][0]["runtime_authority"]=True; self.assertTrue(any("runtime_authority" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
