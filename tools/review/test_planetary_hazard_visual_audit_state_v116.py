import unittest
from tools.review.planetary_hazard_visual_audit_state_v116 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_audit_state_v116"; root, audit, state = "world_root", "audit_record", "state_record"
    pairs = [{"id": kind, "kind": kind, "audit_state_record_id": "record_" + kind, "audit_version": 116, "state_version": 116, "schema": schema, "schema_version": 116, "parent_id": root, "audit_id": audit, "state_id": state, "runtime_authority": False, "status": status} for kind, status in (("hazard", "pending"), ("landmark", "not_performed"), ("route", "pending"))]
    return {"schema": schema, "schema_version": 116, "audit_version": 116, "state_version": 116, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "audit_id": audit, "state_id": state, "source_revision": "87578d7", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_audit_state_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualAuditStateV116Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        value = manifest(); value["schema_version"] = 115; self.assertTrue(any("schema_version must be 116" in error for error in validate_manifest(value)))
    def test_audit_version_strict(self):
        value = manifest(); value["audit_version"] = 115; self.assertTrue(any("audit_version must be 116" in error for error in validate_manifest(value)))
    def test_state_version_strict(self):
        value = manifest(); value["pairs"][0]["state_version"] = 115; self.assertTrue(any("state_version must be 116" in error for error in validate_manifest(value)))
    def test_record_unique(self):
        value = manifest(); value["pairs"][1]["audit_state_record_id"] = value["pairs"][0]["audit_state_record_id"]; self.assertTrue(any("record_id" in error for error in validate_manifest(value)))
    def test_audit_binding_matches(self):
        value = manifest(); value["pairs"][1]["audit_id"] = "other"; self.assertTrue(any("bindings" in error for error in validate_manifest(value)))
    def test_review_gates_open(self):
        value = manifest(); value["native_render"]["status"] = "PASS"; value["human_signoff"]["status"] = "approved"; errors = validate_manifest(value); self.assertTrue(any("native_render" in error for error in errors)); self.assertTrue(any("human_signoff" in error for error in errors))
    def test_exclusions_required(self):
        value = manifest(); value["claims_excluded"] = []; self.assertTrue(any("claims_excluded" in error for error in validate_manifest(value)))

if __name__ == "__main__": unittest.main()
