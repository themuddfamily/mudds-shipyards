import unittest
from tools.review.planetary_hazard_visual_release_authority_v63 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_release_authority_v63"; root = "world_root"; release = "release_candidate"; authority = "visual_authority"
    pairs = [{"id": i, "kind": k, "release_authority_evidence_id": "evidence_" + i, "release_version": 63, "authority_version": 63, "schema": schema, "schema_version": 63, "parent_id": root, "release_id": release, "authority_id": authority, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 63, "release_version": 63, "authority_version": 63, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "release_id": release, "authority_id": authority, "source_revision": "b8d88f4", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_release_authority_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualReleaseAuthorityV63Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=62; self.assertTrue(any("schema_version must be 63" in e for e in validate_manifest(x)))
    def test_release_version_strict(self):
        x=manifest(); x["release_version"]=62; self.assertTrue(any("release_version must be 63" in e for e in validate_manifest(x)))
    def test_authority_version_strict(self):
        x=manifest(); x["pairs"][0]["authority_version"]=62; self.assertTrue(any("authority_version must be 63" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["release_authority_evidence_id"]=x["pairs"][0]["release_authority_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_authority_binding_matches(self):
        x=manifest(); x["pairs"][1]["authority_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
