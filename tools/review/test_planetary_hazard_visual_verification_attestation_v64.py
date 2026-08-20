import unittest
from tools.review.planetary_hazard_visual_verification_attestation_v64 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_verification_attestation_v64"; root = "world_root"; verification = "verification_record"; attestation = "attestation_record"
    pairs = [{"id": i, "kind": k, "verification_attestation_evidence_id": "evidence_" + i, "verification_version": 64, "attestation_version": 64, "schema": schema, "schema_version": 64, "parent_id": root, "verification_id": verification, "attestation_id": attestation, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 64, "verification_version": 64, "attestation_version": 64, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "verification_id": verification, "attestation_id": attestation, "source_revision": "5e90a6a", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_verification_attestation_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualVerificationAttestationV64Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=63; self.assertTrue(any("schema_version must be 64" in e for e in validate_manifest(x)))
    def test_verification_version_strict(self):
        x=manifest(); x["verification_version"]=63; self.assertTrue(any("verification_version must be 64" in e for e in validate_manifest(x)))
    def test_attestation_version_strict(self):
        x=manifest(); x["pairs"][0]["attestation_version"]=63; self.assertTrue(any("attestation_version must be 64" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["verification_attestation_evidence_id"]=x["pairs"][0]["verification_attestation_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_attestation_binding_matches(self):
        x=manifest(); x["pairs"][1]["attestation_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
