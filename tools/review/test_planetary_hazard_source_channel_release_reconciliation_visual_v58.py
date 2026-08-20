import unittest
from tools.review.planetary_hazard_source_channel_release_reconciliation_visual_v58 import validate_manifest

def manifest():
    schema = "planetary_hazard_source_channel_release_reconciliation_visual_v58"; root = "world_root"; source = "source_manifest"; channel = "visual_channel"; release = "release_candidate"; reconciliation = "reconciliation_root"
    pairs = [{"id": i, "kind": k, "source_channel_release_reconciliation_evidence_id": "evidence_" + i, "source_version": 58, "channel_version": 58, "release_version": 58, "reconciliation_version": 58, "schema": schema, "schema_version": 58, "parent_id": root, "source_id": source, "channel_id": channel, "release_id": release, "reconciliation_id": reconciliation, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 58, "source_version": 58, "channel_version": 58, "release_version": 58, "reconciliation_version": 58, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "source_id": source, "channel_id": channel, "release_id": release, "reconciliation_id": reconciliation, "source_revision": "2a0930c", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["source_channel_release_reconciliation_visual_approval", "native_render", "human_signoff"]}

class PlanetaryHazardSourceChannelReleaseReconciliationVisualV58Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=57; self.assertTrue(any("schema_version must be 58" in e for e in validate_manifest(x)))
    def test_source_version_strict(self):
        x=manifest(); x["source_version"]=57; self.assertTrue(any("source_version must be 58" in e for e in validate_manifest(x)))
    def test_channel_version_strict(self):
        x=manifest(); x["pairs"][0]["channel_version"]=57; self.assertTrue(any("channel_version must be 58" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["source_channel_release_reconciliation_evidence_id"]=x["pairs"][0]["source_channel_release_reconciliation_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_source_binding_matches(self):
        x=manifest(); x["pairs"][1]["source_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
