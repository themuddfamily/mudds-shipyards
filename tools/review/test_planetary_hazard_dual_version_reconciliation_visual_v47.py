import unittest
from tools.review.planetary_hazard_dual_version_reconciliation_visual_v47 import validate_manifest

def manifest():
    schema = "planetary_hazard_dual_version_reconciliation_visual_v47"; root = "world_root"; authority = "external_visual_authority"; linked = "review_authority"; provenance = "source_lineage"; reconciliation = "reconciliation_root"
    pairs = [{"id": i, "kind": k, "reconciliation_evidence_id": "evidence_" + i, "authority_version": 47, "provenance_version": 47, "reconciliation_version": 47, "schema": schema, "schema_version": 47, "parent_id": root, "authority_id": authority, "linked_authority_id": linked, "provenance_id": provenance, "reconciliation_id": reconciliation, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 47, "authority_version": 47, "provenance_version": 47, "reconciliation_version": 47, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "linked_authority_id": linked, "provenance_id": provenance, "reconciliation_id": reconciliation, "source_revision": "41f2712", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["dual_reconciliation_visual_approval", "native_render", "human_signoff"]}

class PlanetaryHazardDualVersionReconciliationVisualV47Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=46; self.assertTrue(any("schema_version must be 47" in e for e in validate_manifest(x)))
    def test_reconciliation_version_strict(self):
        x=manifest(); x["reconciliation_version"]=46; self.assertTrue(any("reconciliation_version must be 47" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["reconciliation_evidence_id"]=x["pairs"][0]["reconciliation_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_pair_schema_strict(self):
        x=manifest(); x["pairs"][0]["schema"]="other"; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(x)))
    def test_reconciliation_binding_matches(self):
        x=manifest(); x["pairs"][1]["reconciliation_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
