import copy
import unittest

from tools.world.planetary_reward_authority_binding_reconciliation_v20_validator import (
    _reconciliation_digest,
    validate_reconciliation,
)


def evidence() -> dict:
    activities = (
        ("ember_beacon_survey", "activity_director"),
        ("ember_caldera_patrol", "activity_director"),
        ("ember_kit_cargo_run", "cargo_delivery_activity"),
        ("ember_checkpoint_race", "timed_checkpoint_race"),
        ("ember_convoy_escort", "convoy_escort_activity"),
    )
    manifest_id = "planetary_reward_manifest_v20"
    provenance_id = "planetary_reward_provenance_v20"
    identity_ref = "res://evidence/authority_reconciliation_v20/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": activity_authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_reconciliation_leaf_v20",
            "evidence_ref": f"res://evidence/authority_reconciliation_v20/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, activity_authority in activities
    ]
    authority = {
        "reward_authority_id": "game_flow_reward_authority",
        "reward_store_id": "game_flow_reward_store",
        "authority_scope": "planetary_reward_binding_reconciliation",
        "source": "detached_evidence",
        "writes_store": False,
        "writes_inventory": False,
        "writes_runtime": False,
        "runs_native": False,
    }
    reconciliation = {
        "records_expected": 5,
        "records_observed": 5,
        "references_expected": 6,
        "references_observed": 6,
        "bound_records_expected": 5,
        "bound_records_observed": 5,
        "authority_ids_reconciled": True,
        "store_ids_reconciled": True,
        "all_fields_present": True,
        "all_status_pass": True,
        "complete": True,
    }
    return {
        "schema_version": 20,
        "evidence_scope": "planetary_reward_authority_binding_reconciliation_v20",
        "evidence_mode": "detached_reward_authority_reconciliation_v20",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "authority-reconciliation-v20",
        "identity": {
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "manifest_version": "v20",
            "source": "detached_evidence",
            "evidence_ref": identity_ref,
            "writes_store": False,
            "writes_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
        "authority": authority,
        "records": records,
        "reconciliation": reconciliation,
        "reconciliation_digest_sha256": _reconciliation_digest(manifest_id, provenance_id, authority, reconciliation, records),
        "counts": {
            "records": 5,
            "references": 6,
            "bound_records": 5,
            "reconciled_records": 5,
            "complete_records": 5,
            "store_writes": 0,
            "inventory_writes": 0,
            "runtime_mutations": 0,
            "native_runs": 0,
        },
        "overall_status": "PASS",
    }


class PlanetaryRewardAuthorityBindingReconciliationV20ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_reconciliation(evidence()), [])

    def test_schema_version_is_v20(self):
        item = evidence()
        item["schema_version"] = 19
        self.assertTrue(any("schema_version must be 20" in error for error in validate_reconciliation(item)))

    def test_authority_scope_is_required(self):
        item = evidence()
        item["authority"]["authority_scope"] = "other_scope"
        self.assertTrue(any("authority.authority_scope must be planetary_reward_binding_reconciliation" in error for error in validate_reconciliation(item)))

    def test_reconciliation_count_is_reconciled(self):
        item = evidence()
        item["reconciliation"]["bound_records_observed"] = 4
        self.assertTrue(any("reconciliation.bound_records_observed must be 5" in error for error in validate_reconciliation(item)))

    def test_digest_binds_reconciled_authority(self):
        item = evidence()
        item["records"][0]["activity_authority_id"] = "cargo_delivery_activity"
        self.assertTrue(any("does not match canonical reconciliation payload" in error for error in validate_reconciliation(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_reconciliation(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_reconciliation(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_reconciliation(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
