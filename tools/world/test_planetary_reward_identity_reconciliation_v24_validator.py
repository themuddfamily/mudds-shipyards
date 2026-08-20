import copy
import unittest

from tools.world.planetary_reward_identity_reconciliation_v24_validator import (
    _identity_reconciliation_digest,
    validate_identity_reconciliation,
)


def evidence() -> dict:
    activities = (
        ("ember_beacon_survey", "activity_director"),
        ("ember_caldera_patrol", "activity_director"),
        ("ember_kit_cargo_run", "cargo_delivery_activity"),
        ("ember_checkpoint_race", "timed_checkpoint_race"),
        ("ember_convoy_escort", "convoy_escort_activity"),
    )
    manifest_id = "planetary_reward_manifest_v24"
    provenance_id = "planetary_reward_provenance_v24"
    lineage_id = "planetary_reward_lineage_v24"
    identity_ref = "res://evidence/identity_reconciliation_v24/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": activity_authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_identity_reconciliation_leaf_v24",
            "evidence_ref": f"res://evidence/identity_reconciliation_v24/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, activity_authority in activities
    ]
    identity = {"manifest_id": manifest_id, "provenance_id": provenance_id, "manifest_version": "v24", "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_identity_reconciliation", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    reconciliation = {"manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "evidence_ref": "res://evidence/identity_reconciliation_v24/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 6, "references_observed": 6, "identity_records_reconciled": 5, "authority_reconciled": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    return {"schema_version": 24, "evidence_scope": "planetary_reward_identity_reconciliation_v24", "evidence_mode": "detached_reward_identity_reconciliation_v24", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "identity-reconciliation-v24", "identity": identity, "authority": authority, "records": records, "identity_reconciliation": reconciliation, "identity_reconciliation_digest_sha256": _identity_reconciliation_digest(identity, authority, reconciliation, records), "counts": {"records": 5, "references": 6, "identity_records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardIdentityReconciliationV24ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_identity_reconciliation(evidence()), [])

    def test_schema_version_is_v24(self):
        item = evidence()
        item["schema_version"] = 23
        self.assertTrue(any("schema_version must be 24" in error for error in validate_identity_reconciliation(item)))

    def test_identity_lineage_is_required(self):
        item = evidence()
        item["identity"]["lineage_id"] = "other_lineage"
        self.assertTrue(any("identity.lineage_id must be planetary_reward_lineage_v24" in error for error in validate_identity_reconciliation(item)))

    def test_authority_reconciliation_is_required(self):
        item = evidence()
        item["identity_reconciliation"]["authority_reconciled"] = False
        self.assertTrue(any("identity_reconciliation.authority_reconciled must be True" in error for error in validate_identity_reconciliation(item)))

    def test_digest_binds_reconciliation(self):
        item = evidence()
        item["identity_reconciliation"]["identity_records_reconciled"] = 4
        self.assertTrue(any("does not match canonical identity reconciliation payload" in error for error in validate_identity_reconciliation(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_identity_reconciliation(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_identity_reconciliation(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_identity_reconciliation(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
