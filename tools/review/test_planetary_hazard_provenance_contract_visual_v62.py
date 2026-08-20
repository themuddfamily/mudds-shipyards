import unittest
from tools.review.planetary_hazard_provenance_contract_visual_v62 import validate_manifest

def manifest():
    schema = "planetary_hazard_provenance_contract_visual_v62"; root = "world_root"; provenance = "provenance_record"; contract = "visual_contract"
    pairs = [{"id": i, "kind": k, "provenance_contract_evidence_id": "evidence_" + i, "provenance_version": 62, "contract_version": 62, "schema": schema, "schema_version": 62, "parent_id": root, "provenance_id": provenance, "contract_id": contract, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 62, "provenance_version": 62, "contract_version": 62, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "provenance_id": provenance, "contract_id": contract, "source_revision": "d5efb0e", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["provenance_contract_visual_approval", "native_render", "human_signoff"]}

class PlanetaryHazardProvenanceContractVisualV62Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=61; self.assertTrue(any("schema_version must be 62" in e for e in validate_manifest(x)))
    def test_provenance_version_strict(self):
        x=manifest(); x["provenance_version"]=61; self.assertTrue(any("provenance_version must be 62" in e for e in validate_manifest(x)))
    def test_contract_version_strict(self):
        x=manifest(); x["pairs"][0]["contract_version"]=61; self.assertTrue(any("contract_version must be 62" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["provenance_contract_evidence_id"]=x["pairs"][0]["provenance_contract_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_contract_binding_matches(self):
        x=manifest(); x["pairs"][1]["contract_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
