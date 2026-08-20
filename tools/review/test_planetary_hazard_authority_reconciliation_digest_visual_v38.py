import unittest
from tools.review.planetary_hazard_authority_reconciliation_digest_visual_v38 import validate_manifest

def manifest():
    schema = "planetary_hazard_authority_reconciliation_digest_visual_v38"; root = "world_root"; authority = "external_visual_authority"
    pairs = [{"id": i, "kind": k, "schema": schema, "schema_version": 38, "parent_id": root, "authority_id": authority, "source_sha256": s * 64, "review_sha256": r * 64, "runtime_authority": False, "status": st} for i, k, s, r, st in (("hazard", "hazard", "a", "b", "pending"), ("landmark", "landmark", "c", "d", "not_performed"), ("route", "route", "e", "f", "pending"))]
    digest = lambda v: {"schema": schema, "schema_version": 38, "algorithm": "sha256", "value": v * 64, "status": "pending"}
    return {"schema": schema, "schema_version": 38, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "source_revision": "6a81738", "pairs": pairs, "authority_digest": digest("1"), "reconciliation_digest": digest("2"), "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["authority_reconciliation_approval", "native_render", "human_signoff"]}

class PlanetaryHazardAuthorityReconciliationDigestVisualV38Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=37; self.assertTrue(any("schema_version must be 38" in e for e in validate_manifest(x)))
    def test_pair_version_strict(self):
        x=manifest(); x["pairs"][0]["schema_version"]=37; self.assertTrue(any("schema and schema_version" in e for e in validate_manifest(x)))
    def test_reconciliation_digest_strict(self):
        x=manifest(); x["reconciliation_digest"]["algorithm"]="md5"; self.assertTrue(any("reconciliation_digest" in e for e in validate_manifest(x)))
    def test_bindings_match(self):
        x=manifest(); x["pairs"][0]["authority_id"]="other"; self.assertTrue(any("match manifest" in e for e in validate_manifest(x)))
    def test_runtime_authority_false(self):
        x=manifest(); x["pairs"][0]["runtime_authority"]=True; self.assertTrue(any("runtime_authority" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
