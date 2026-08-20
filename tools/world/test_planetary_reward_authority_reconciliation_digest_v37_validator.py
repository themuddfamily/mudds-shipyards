import copy
import unittest

from tools.world.planetary_reward_authority_reconciliation_digest_v37_validator import (
    _authority_reconciliation_digest,
    validate_authority_reconciliation,
)


def evidence() -> dict:
    activities = (("ember_beacon_survey", "activity_director"), ("ember_caldera_patrol", "activity_director"), ("ember_kit_cargo_run", "cargo_delivery_activity"), ("ember_checkpoint_race", "timed_checkpoint_race"), ("ember_convoy_escort", "convoy_escort_activity"))
    manifest_id = "planetary_reward_manifest_v37"
    provenance_id = "planetary_reward_provenance_v37"
    lineage_id = "planetary_reward_lineage_v37"
    identity_ref = "res://evidence/authority_reconciliation_v37/manifest.json"
    records = [{"activity_id": activity_id, "manifest_id": manifest_id, "provenance_id": provenance_id, "activity_authority_id": activity_authority, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "reward_id": f"reward_{activity_id}", "leaf_id": f"{activity_id}_reward_authority_reconciliation_leaf_v37", "evidence_ref": f"res://evidence/authority_reconciliation_v37/{activity_id}.json", "status": "PASS", "included_once": True} for activity_id, activity_authority in activities]
    identity = {"manifest_id": manifest_id, "manifest_version": "v37", "provenance_id": provenance_id, "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_authority_reconciliation", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    reconciliation = {"schema_version": 37, "digest_version": "authority_reconciliation_v37", "manifest_id": manifest_id, "manifest_version": "v37", "provenance_id": provenance_id, "lineage_id": lineage_id, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "evidence_ref": "res://evidence/authority_reconciliation_v37/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 6, "references_observed": 6, "records_reconciled": 5, "authority_reconciled": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    return {"schema_version": 37, "evidence_scope": "planetary_reward_authority_reconciliation_digest_v37", "evidence_mode": "detached_reward_authority_reconciliation_v37", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "authority-reconciliation-v37", "identity": identity, "authority": authority, "records": records, "authority_reconciliation": reconciliation, "authority_reconciliation_digest_sha256": _authority_reconciliation_digest(authority, reconciliation, records), "counts": {"records": 5, "references": 6, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardAuthorityReconciliationDigestV37ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_authority_reconciliation(evidence()), [])

    def test_schema_version_is_v37(self):
        item = evidence()
        item["schema_version"] = 36
        self.assertTrue(any("schema_version must be 37" in error for error in validate_authority_reconciliation(item)))

    def test_reconciliation_digest_version_is_required(self):
        item = evidence()
        item["authority_reconciliation"]["digest_version"] = "other"
        self.assertTrue(any("authority_reconciliation.digest_version must be authority_reconciliation_v37" in error for error in validate_authority_reconciliation(item)))

    def test_authority_reconciliation_is_required(self):
        item = evidence()
        item["authority_reconciliation"]["authority_reconciled"] = False
        self.assertTrue(any("authority_reconciliation.authority_reconciled must be True" in error for error in validate_authority_reconciliation(item)))

    def test_digest_binds_authority(self):
        item = evidence()
        item["authority"]["reward_store_id"] = "other_store"
        self.assertTrue(any("authority_reconciliation_digest_sha256 does not match canonical authority/reconciliation payload" in error for error in validate_authority_reconciliation(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_authority_reconciliation(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_authority_reconciliation(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_authority_reconciliation(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
