import unittest
from tools.review.planetary_hazard_visual_release_state_v80 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_release_state_v80"; root = "world_root"; release = "release_record"; state = "state_record"
    pairs = [{"id": i, "kind": k, "release_state_evidence_id": "evidence_" + i, "release_version": 80, "state_version": 80, "schema": schema, "schema_version": 80, "parent_id": root, "release_id": release, "state_id": state, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 80, "release_version": 80, "state_version": 80, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "release_id": release, "state_id": state, "source_revision": "dde3753", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_release_state_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualReleaseStateV80Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=79; self.assertTrue(any("schema_version must be 80" in e for e in validate_manifest(x)))
    def test_release_version_strict(self):
        x=manifest(); x["release_version"]=79; self.assertTrue(any("release_version must be 80" in e for e in validate_manifest(x)))
    def test_state_version_strict(self):
        x=manifest(); x["pairs"][0]["state_version"]=79; self.assertTrue(any("state_version must be 80" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["release_state_evidence_id"]=x["pairs"][0]["release_state_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_state_binding_matches(self):
        x=manifest(); x["pairs"][1]["state_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
