import unittest

from tools.review.planetary_hazard_review_v644 import validate_manifest


def manifest() -> dict:
    schema = "planetary_hazard_review_v644"; root, review = "world_root", "review_record"; consistency, state = "consistency_record", "state_record"; source = "working-tree-planetary-review-v644"
    fixed = {
        "receipt_scope": "planetary_hazard_review", "evidence_phase": "review", "evidence_channel": "planetary-hazard", "review_owner": "review-ledger", "review_mode": "evidence_only", "authority_class": "non_runtime_review", "retention_policy": "review_scope_only", "closure_state": "open", "gate_policy": "native_human_open", "evidence_boundary": "pre_native_human", "evidence_surface": "review_manifest", "evidence_purpose": "consistency_audit", "evidence_class": "planetary_hazard", "evidence_contract": "planetary_hazard_review", "evidence_revision": "v644", "lineage_label": "root_receipt", "lineage_scope": "manifest_root", "lineage_root_kind": "manifest", "root_identity": "root_id", "root_identity_format": "id", "source_revision": source,
    }
    policies = {f"runtime_{name}_policy": "forbidden" for name in ("write", "process", "network", "environment", "filesystem", "time", "random", "thread", "signal", "mutex", "ipc", "subprocess", "ui", "audio", "haptic", "display", "input", "storage", "cache", "gpu", "sensor")}
    shared = {**fixed, **policies}
    receipts = [{"receipt_id": "receipt_" + kind, "kind": kind, "review_evidence_id": "evidence_" + kind, "review_version": 644, **shared, "root_identity_value": root, "lineage_anchor": root, "schema": schema, "schema_version": 644, "parent_id": root, "review_id": review, "consistency_id": consistency, "state_id": state, "runtime_authority": False, "status": status} for kind, status in (("hazard", "pending"), ("landmark", "not_performed"), ("route", "pending"))]
    return {"schema": schema, "schema_version": 644, "review_version": 644, "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_review_manifest", "root_id": root, "review_id": review, "consistency_id": consistency, "state_id": state, **shared, "root_identity_value": root, "receipts": receipts, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["visual_consistency_state_approval", "visual_review_consistency_approval", "native_render", "human_signoff"]}


class PlanetaryHazardReviewV644Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_manifest_version_strict(self):
        value = manifest(); value["schema_version"] = 187; self.assertTrue(any("schema_version must be 644" in e for e in validate_manifest(value)))
    def test_review_version_strict(self):
        value = manifest(); value["review_version"] = 187; self.assertTrue(any("review_version must be 644" in e for e in validate_manifest(value)))
    def test_receipt_version_strict(self):
        value = manifest(); value["receipts"][0]["review_version"] = 187; self.assertTrue(any("review_version must be 644" in e for e in validate_manifest(value)))
    def test_receipt_identity_unique(self):
        value = manifest(); value["receipts"][1]["receipt_id"] = value["receipts"][0]["receipt_id"]; self.assertTrue(any("receipt_id" in e for e in validate_manifest(value)))
    def test_sensor_policy_binding(self):
        value = manifest(); value["receipts"][1]["runtime_sensor_policy"] = "allowed"; self.assertTrue(any("runtime_sensor_policy must match" in e for e in validate_manifest(value)))
    def test_filesystem_policy_binding(self):
        value = manifest(); value["runtime_filesystem_policy"] = "allowed"; self.assertTrue(any("runtime_filesystem_policy must be forbidden" in e for e in validate_manifest(value)))
    def test_source_revision_binding(self):
        value = manifest(); value["receipts"][1]["source_revision"] = "other"; self.assertTrue(any("source_revision must match" in e for e in validate_manifest(value)))
    def test_review_gates_open(self):
        value = manifest(); value["native_render"]["status"] = "passed"; value["human_signoff"]["status"] = "approved"; errors = validate_manifest(value); self.assertTrue(any("native_render" in e for e in errors)); self.assertTrue(any("human_signoff" in e for e in errors))
    def test_exclusions_required(self):
        value = manifest(); value["claims_excluded"] = []; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(value)))
    def test_non_object_receipt_fails_closed(self):
        value = manifest(); value["receipts"][0] = None; self.assertTrue(any("receipts[0] must be an object" in e for e in validate_manifest(value)))


if __name__ == "__main__": unittest.main()
