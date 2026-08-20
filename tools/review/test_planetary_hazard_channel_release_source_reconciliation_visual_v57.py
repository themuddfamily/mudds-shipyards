import unittest
from tools.review.planetary_hazard_channel_release_source_reconciliation_visual_v57 import validate_manifest

def manifest():
    schema = "planetary_hazard_channel_release_source_reconciliation_visual_v57"; root = "world_root"; channel = "visual_channel"; release = "release_candidate"; source = "source_manifest"; reconciliation = "reconciliation_root"
    pairs = [{"id": i, "kind": k, "channel_release_source_reconciliation_evidence_id": "evidence_" + i, "channel_version": 57, "release_version": 57, "source_version": 57, "reconciliation_version": 57, "schema": schema, "schema_version": 57, "parent_id": root, "channel_id": channel, "release_id": release, "source_id": source, "reconciliation_id": reconciliation, "runtime_authority": False, "status": st} for i, k, st in (("hazard", "hazard", "pending"), ("landmark", "landmark", "not_performed"), ("route", "route", "pending"))]
    return {"schema": schema, "schema_version": 57, "channel_version": 57, "release_version": 57, "source_version": 57, "reconciliation_version": 57, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "channel_id": channel, "release_id": release, "source_id": source, "reconciliation_id": reconciliation, "source_revision": "eb94081", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["channel_release_source_reconciliation_visual_approval", "native_render", "human_signoff"]}

class PlanetaryHazardChannelReleaseSourceReconciliationVisualV57Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        x=manifest(); x["schema_version"]=56; self.assertTrue(any("schema_version must be 57" in e for e in validate_manifest(x)))
    def test_source_version_strict(self):
        x=manifest(); x["source_version"]=56; self.assertTrue(any("source_version must be 57" in e for e in validate_manifest(x)))
    def test_reconciliation_version_strict(self):
        x=manifest(); x["pairs"][0]["reconciliation_version"]=56; self.assertTrue(any("reconciliation_version must be 57" in e for e in validate_manifest(x)))
    def test_evidence_unique(self):
        x=manifest(); x["pairs"][1]["channel_release_source_reconciliation_evidence_id"]=x["pairs"][0]["channel_release_source_reconciliation_evidence_id"]; self.assertTrue(any("evidence_id" in e for e in validate_manifest(x)))
    def test_source_binding_matches(self):
        x=manifest(); x["pairs"][1]["source_id"]="other"; self.assertTrue(any("bindings" in e for e in validate_manifest(x)))
    def test_review_gates_open(self):
        x=manifest(); x["native_render"]["status"]="PASS"; x["human_signoff"]["status"]="approved"; es=validate_manifest(x); self.assertTrue(any("native_render" in e for e in es)); self.assertTrue(any("human_signoff" in e for e in es))
    def test_exclusions_required(self):
        x=manifest(); x["claims_excluded"]=[]; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(x)))
if __name__ == "__main__": unittest.main()
