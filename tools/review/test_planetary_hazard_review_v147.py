import unittest

from tools.review.planetary_hazard_review_v147 import validate_manifest


def manifest() -> dict:
    schema = "planetary_hazard_review_v147"
    root, review = "world_root", "review_record"
    consistency, state = "consistency_record", "state_record"
    source, scope = "working-tree-planetary-review-v147", "planetary_hazard_review"
    phase, channel, owner, mode = "review", "planetary-hazard", "review-ledger", "evidence_only"
    receipts = [
        {
            "receipt_id": "receipt_" + kind, "kind": kind,
            "review_evidence_id": "evidence_" + kind, "review_version": 147,
            "evidence_phase": phase, "evidence_channel": channel, "review_owner": owner,
            "review_mode": mode, "receipt_scope": scope, "source_revision": source,
            "schema": schema, "schema_version": 147, "parent_id": root,
            "review_id": review, "consistency_id": consistency, "state_id": state,
            "runtime_authority": False, "status": status,
        }
        for kind, status in (("hazard", "pending"), ("landmark", "not_performed"), ("route", "pending"))
    ]
    return {
        "schema": schema, "schema_version": 147, "review_version": 147,
        "world_id": "ember_moon", "region_id": "caldera_rim",
        "manifest_id": "caldera_review_manifest", "root_id": root,
        "review_id": review, "consistency_id": consistency, "state_id": state,
        "source_revision": source, "receipt_scope": scope, "evidence_phase": phase,
        "evidence_channel": channel, "review_owner": owner, "review_mode": mode,
        "receipts": receipts, "native_render": {"status": "not_performed"},
        "human_signoff": {"status": "pending"},
        "claims_excluded": [
            "visual_consistency_state_approval", "visual_review_consistency_approval",
            "native_render", "human_signoff",
        ],
    }


class PlanetaryHazardReviewV147Test(unittest.TestCase):
    def test_valid_open_manifest(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_version_strict(self):
        value = manifest(); value["schema_version"] = 146
        self.assertTrue(any("schema_version must be 147" in e for e in validate_manifest(value)))

    def test_review_version_strict(self):
        value = manifest(); value["review_version"] = 146
        self.assertTrue(any("review_version must be 147" in e for e in validate_manifest(value)))

    def test_receipt_version_strict(self):
        value = manifest(); value["receipts"][0]["review_version"] = 146
        self.assertTrue(any("review_version must be 147" in e for e in validate_manifest(value)))

    def test_receipt_identity_unique(self):
        value = manifest(); value["receipts"][1]["receipt_id"] = value["receipts"][0]["receipt_id"]
        self.assertTrue(any("receipt_id" in e for e in validate_manifest(value)))

    def test_mode_binding(self):
        value = manifest(); value["receipts"][1]["review_mode"] = "approval"
        self.assertTrue(any("review_mode must match" in e for e in validate_manifest(value)))

    def test_owner_binding(self):
        value = manifest(); value["receipts"][1]["review_owner"] = "other"
        self.assertTrue(any("review_owner must match" in e for e in validate_manifest(value)))

    def test_source_revision_binding(self):
        value = manifest(); value["receipts"][1]["source_revision"] = "other"
        self.assertTrue(any("source_revision must match" in e for e in validate_manifest(value)))

    def test_review_gates_open(self):
        value = manifest(); value["native_render"]["status"] = "passed"; value["human_signoff"]["status"] = "approved"
        errors = validate_manifest(value)
        self.assertTrue(any("native_render" in e for e in errors))
        self.assertTrue(any("human_signoff" in e for e in errors))

    def test_exclusions_required(self):
        value = manifest(); value["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in e for e in validate_manifest(value)))

    def test_non_object_receipt_fails_closed(self):
        value = manifest(); value["receipts"][0] = None
        self.assertTrue(any("receipts[0] must be an object" in e for e in validate_manifest(value)))


if __name__ == "__main__":
    unittest.main()
