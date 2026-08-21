import unittest
from tools.review.planetary_hazard_visual_attestation_lineage_v107 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_attestation_lineage_v107"; root = "world_root"; attestation = "attestation_record"; lineage = "lineage_record"
    pairs = [{"id": i, "kind": k, "attestation_lineage_evidence_id": "evidence_" + i, "attestation_version": 107, "lineage_version": 107, "schema": schema, "schema_version": 107, "parent_id": root, "attestation_id": attestation, "lineage_id": lineage, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 107, "attestation_version": 107, "lineage_version": 107, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "attestation_id": attestation, "lineage_id": lineage, "source_revision": "1f0cb12", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_attestation_lineage_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualAttestationLineageV107Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=106; self.assertTrue(any("schema_version must be 107" in e for e in validate_manifest(x)))
    def test_attestation_version_strict(self):
        x=manifest(); x["attestation_version"]=106; self.assertTrue(any("attestation_version must be 107" in e for e in validate_manifest(x)))
    def test_lineage_version_strict(self):
        x=manifest(); x["pairs"][0]["lineage_version"]=106; self.assertTrue(any("lineage_version must be 107" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["attestation_lineage_evidence_id"]=x["pairs"][0]["attestation_lineage_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_lineage_binding_matches(self):
        x=manifest(); x["pairs"][1]["lineage_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
