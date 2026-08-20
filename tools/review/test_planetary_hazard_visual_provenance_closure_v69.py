import unittest
from tools.review.planetary_hazard_visual_provenance_closure_v69 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_provenance_closure_v69"; root = "world_root"; provenance = "provenance_record"; closure = "closure_record"
    pairs = [{"id": i, "kind": k, "provenance_closure_evidence_id": "evidence_" + i, "provenance_version": 69, "closure_version": 69, "schema": schema, "schema_version": 69, "parent_id": root, "provenance_id": provenance, "closure_id": closure, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 69, "provenance_version": 69, "closure_version": 69, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "provenance_id": provenance, "closure_id": closure, "source_revision": "8e7179f", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_provenance_closure_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualProvenanceClosureV69Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=68; self.assertTrue(any("schema_version must be 69" in e for e in validate_manifest(x)))
    def test_provenance_version_strict(self):
        x=manifest(); x["provenance_version"]=68; self.assertTrue(any("provenance_version must be 69" in e for e in validate_manifest(x)))
    def test_closure_version_strict(self):
        x=manifest(); x["pairs"][0]["closure_version"]=68; self.assertTrue(any("closure_version must be 69" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["provenance_closure_evidence_id"]=x["pairs"][0]["provenance_closure_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_closure_binding_matches(self):
        x=manifest(); x["pairs"][1]["closure_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
