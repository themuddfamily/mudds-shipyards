import unittest
from tools.review.planetary_hazard_visual_source_integrity_linkage_v61 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_source_integrity_linkage_v61"; root = "world_root"; integrity = "source_integrity"; linkage = "source_linkage"
    pairs = [{"id": i, "kind": k, "source_link_id": "link_" + i, "source_integrity_id": integrity, "source_linkage_id": linkage, "source_sha256": s * 64, "integrity_sha256": h * 64, "schema": schema, "schema_version": 61, "parent_id": root, "runtime_authority": False, "status": st} for i, k, s, h, st in (("hazard", "hazard", "a", "b", "pending"), ("landmark", "landmark", "c", "d", "not_performed"), ("route", "route", "e", "f", "pending"))]
    return {"schema": schema, "schema_version": 61, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "source_integrity_id": integrity, "source_linkage_id": linkage, "source_revision": "9112e5d", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_source_integrity_linkage_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualSourceIntegrityLinkageV61Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=60; self.assertTrue(any("schema_version must be 61" in e for e in validate_manifest(x)))
    def test_source_digest_strict(self):
        x=manifest(); x["pairs"][0]["source_sha256"]="short"; self.assertTrue(any("source_sha256" in e for e in validate_manifest(x)))
    def test_integrity_digest_strict(self):
        x=manifest(); x["pairs"][0]["integrity_sha256"]="short"; self.assertTrue(any("integrity_sha256" in e for e in validate_manifest(x)))
    def test_source_link_unique(self):
        x=manifest(); x["pairs"][1]["source_link_id"]=x["pairs"][0]["source_link_id"]; self.assertTrue(any("source_link_id" in e for e in validate_manifest(x)))
    def test_integrity_binding_matches(self):
        x=manifest(); x["pairs"][1]["source_integrity_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
