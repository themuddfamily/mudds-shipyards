import unittest
from tools.review.planetary_hazard_linked_authority_provenance_digest_visual_v40 import validate_manifest

def manifest():
    schema = "planetary_hazard_linked_authority_provenance_digest_visual_v40"; root = "world_root"; authority = "external_visual_authority"; linked = "review_authority"; provenance = "source_lineage"
    pairs = [{"id": i, "kind": k, "schema": schema, "schema_version": 40, "parent_id": root, "authority_id": authority, "linked_authority_id": linked, "provenance_id": provenance, "source_sha256": s * 64, "review_sha256": r * 64, "provenance_sha256": p * 64, "runtime_authority": False, "status": st} for i, k, s, r, p, st in (("hazard", "hazard", "a", "b", "1", "pending"), ("landmark", "landmark", "c", "d", "2", "not_performed"), ("route", "route", "e", "f", "3", "pending"))]
    digest = lambda v: {"schema": schema, "schema_version": 40, "algorithm": "sha256", "value": v * 64, "status": "pending"}
    return {"schema": schema, "schema_version": 40, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "authority_id": authority, "linked_authority_id": linked, "provenance_id": provenance, "source_revision": "3ed2836", "pairs": pairs, "linked_authority_digest": digest("4"), "provenance_digest": digest("5"), "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["linked_authority_provenance_approval", "native_render", "human_signoff"]}

class PlanetaryHazardLinkedAuthorityProvenanceDigestVisualV40Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=39; self.assertTrue(any("schema_version must be 40" in e for e in validate_manifest(x)))
    def test_pair_provenance_strict(self):
        x=manifest(); x["pairs"][0]["provenance_sha256"]="short"; self.assertTrue(any("provenance_sha256" in e for e in validate_manifest(x)))
    def test_digest_schema_strict(self):
        x=manifest(); x["provenance_digest"]["algorithm"]="md5"; self.assertTrue(any("provenance_digest" in e for e in validate_manifest(x)))
    def test_provenance_binding_matches(self):
        x=manifest(); x["pairs"][1]["provenance_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_runtime_authority_false(self):
        x=manifest(); x["pairs"][0]["runtime_authority"]=True; self.assertTrue(any("runtime_authority" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
