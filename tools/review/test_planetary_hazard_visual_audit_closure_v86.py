import unittest
from tools.review.planetary_hazard_visual_audit_closure_v86 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_audit_closure_v86"; root = "world_root"; audit = "audit_record"; closure = "closure_record"
    pairs = [{"id": i, "kind": k, "audit_closure_evidence_id": "evidence_" + i, "audit_version": 86, "closure_version": 86, "schema": schema, "schema_version": 86, "parent_id": root, "audit_id": audit, "closure_id": closure, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 86, "audit_version": 86, "closure_version": 86, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "audit_id": audit, "closure_id": closure, "source_revision": "fe32a5b", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_audit_closure_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualAuditClosureV86Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=85; self.assertTrue(any("schema_version must be 86" in e for e in validate_manifest(x)))
    def test_audit_version_strict(self):
        x=manifest(); x["audit_version"]=85; self.assertTrue(any("audit_version must be 86" in e for e in validate_manifest(x)))
    def test_closure_version_strict(self):
        x=manifest(); x["pairs"][0]["closure_version"]=85; self.assertTrue(any("closure_version must be 86" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["audit_closure_evidence_id"]=x["pairs"][0]["audit_closure_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_closure_binding_matches(self):
        x=manifest(); x["pairs"][1]["closure_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
