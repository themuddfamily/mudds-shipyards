import unittest
from tools.review.planetary_hazard_visual_attestation_lineage_v115 import validate_manifest

def manifest():
    schema = "planetary_hazard_visual_attestation_lineage_v115"; root, attestation, lineage = "world_root", "attestation_record", "lineage_record"
    pairs = [{"id": kind, "kind": kind, "attestation_lineage_record_id": "record_" + kind, "attestation_version": 115, "lineage_version": 115, "schema": schema, "schema_version": 115, "parent_id": root, "attestation_id": attestation, "lineage_id": lineage, "runtime_authority": False, "status": status} for kind, status in (("hazard", "pending"), ("landmark", "not_performed"), ("route", "pending"))]
    return {"schema": schema, "schema_version": 115, "attestation_version": 115, "lineage_version": 115, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": root, "attestation_id": attestation, "lineage_id": lineage, "source_revision": "8f62719", "pairs": pairs, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_attestation_lineage_approval", "native_render", "human_signoff"]}

class PlanetaryHazardVisualAttestationLineageV115Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        value = manifest(); value["schema_version"] = 114; self.assertTrue(any("schema_version must be 115" in error for error in validate_manifest(value)))
    def test_attestation_version_strict(self):
        value = manifest(); value["attestation_version"] = 114; self.assertTrue(any("attestation_version must be 115" in error for error in validate_manifest(value)))
    def test_lineage_version_strict(self):
        value = manifest(); value["pairs"][0]["lineage_version"] = 114; self.assertTrue(any("lineage_version must be 115" in error for error in validate_manifest(value)))
    def test_record_unique(self):
        value = manifest(); value["pairs"][1]["attestation_lineage_record_id"] = value["pairs"][0]["attestation_lineage_record_id"]; self.assertTrue(any("record_id" in error for error in validate_manifest(value)))
    def test_lineage_binding_matches(self):
        value = manifest(); value["pairs"][1]["lineage_id"] = "other"; self.assertTrue(any("bindings" in error for error in validate_manifest(value)))
    def test_review_gates_open(self):
        value = manifest(); value["native_render"]["status"] = "PASS"; value["human_signoff"]["status"] = "approved"; errors = validate_manifest(value); self.assertTrue(any("native_render" in error for error in errors)); self.assertTrue(any("human_signoff" in error for error in errors))
    def test_exclusions_required(self):
        value = manifest(); value["claims_excluded"] = []; self.assertTrue(any("claims_excluded" in error for error in validate_manifest(value)))

if __name__ == "__main__": unittest.main()
