import unittest
from tools.review.planetary_hazard_release_version_linkage_visual_v52 import validate_manifest

def manifest():
    schema = "planetary_hazard_release_version_linkage_visual_v52"; root = "world_root"; release = "release_candidate"
    pairs = [{"id": i, "kind": k, "release_link_id": "link_" + i, "release_version": 52, "schema": schema, "schema_version": 52, "parent_id": root, "release_id": release, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 52, "release_version": 52, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "release_id": release, "source_revision": "c255def", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["release_linkage_visual_approval", "native_render", "human_signoff"]}

class PlanetaryHazardReleaseVersionLinkageVisualV52Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=51; self.assertTrue(any("schema_version must be 52" in e for e in validate_manifest(x)))
    def test_release_version_strict(self):
        x=manifest(); x["release_version"]=51; self.assertTrue(any("release_version must be 52" in e for e in validate_manifest(x)))
    def test_release_link_unique(self):
        x=manifest(); x["pairs"][1]["release_link_id"]=x["pairs"][0]["release_link_id"]; self.assertTrue(any("release_link_id" in e for e in validate_manifest(x)))
    def test_pair_schema_strict(self):
        x=manifest(); x["pairs"][0]["schema"]="other"; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(x)))
    def test_release_binding_matches(self):
        x=manifest(); x["pairs"][1]["release_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
