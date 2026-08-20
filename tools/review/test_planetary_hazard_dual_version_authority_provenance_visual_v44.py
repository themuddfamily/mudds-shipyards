import unittest
from tools.review.planetary_hazard_dual_version_authority_provenance_visual_v44 import validate_manifest

def manifest():
    schema = "planetary_hazard_dual_version_authority_provenance_visual_v44"; root = "world_root"; authority = "external_visual_authority"; linked = "review_authority"; provenance = "source_lineage"
    pairs = [{"id": i, "kind": k, "visual_evidence_id": "visual_" + i, "authority_version": 44, "provenance_version": 44, "schema": schema, "schema_version": 44, "parent_id": root, "authority_id": authority, "linked_authority_id": linked, "provenance_id": provenance, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 44, "authority_version": 44, "provenance_version": 44, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "linked_authority_id": linked, "provenance_id": provenance, "source_revision": "08aabff", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["dual_authority_provenance_version_approval", "native_render", "human_signoff"]}

class PlanetaryHazardDualVersionAuthorityProvenanceVisualV44Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=43; self.assertTrue(any("schema_version must be 44" in e for e in validate_manifest(x)))
    def test_authority_version_strict(self):
        x=manifest(); x["authority_version"]=43; self.assertTrue(any("authority_version must be 44" in e for e in validate_manifest(x)))
    def test_provenance_version_strict(self):
        x=manifest(); x["pairs"][0]["provenance_version"]=43; self.assertTrue(any("provenance_version must be 44" in e for e in validate_manifest(x)))
    def test_pair_schema_strict(self):
        x=manifest(); x["pairs"][0]["schema"]="other"; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(x)))
    def test_bindings_match(self):
        x=manifest(); x["pairs"][1]["linked_authority_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
