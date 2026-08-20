import unittest
from tools.review.planetary_hazard_visual_traceability_gate_v66 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_traceability_gate_v66"; root = "world_root"; traceability = "traceability_record"; gate = "gate_record"
    pairs = [{"id": i, "kind": k, "traceability_gate_evidence_id": "evidence_" + i, "traceability_version": 66, "gate_version": 66, "schema": schema, "schema_version": 66, "parent_id": root, "traceability_id": traceability, "gate_id": gate, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 66, "traceability_version": 66, "gate_version": 66, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "traceability_id": traceability, "gate_id": gate, "source_revision": "2a5bf18", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_traceability_gate_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualTraceabilityGateV66Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=65; self.assertTrue(any("schema_version must be 66" in e for e in validate_manifest(x)))
    def test_traceability_version_strict(self):
        x=manifest(); x["traceability_version"]=65; self.assertTrue(any("traceability_version must be 66" in e for e in validate_manifest(x)))
    def test_gate_version_strict(self):
        x=manifest(); x["pairs"][0]["gate_version"]=65; self.assertTrue(any("gate_version must be 66" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["traceability_gate_evidence_id"]=x["pairs"][0]["traceability_gate_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_gate_binding_matches(self):
        x=manifest(); x["pairs"][1]["gate_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
