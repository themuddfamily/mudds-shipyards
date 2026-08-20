import copy
import unittest

from tools.world.planetary_reward_digest_reconciliation_v26_validator import (
    _reconciliation_digest,
    validate_digest_reconciliation,
)


def evidence() -> dict:
    activities = (("ember_beacon_survey", "activity_director"), ("ember_caldera_patrol", "activity_director"), ("ember_kit_cargo_run", "cargo_delivery_activity"), ("ember_checkpoint_race", "timed_checkpoint_race"), ("ember_convoy_escort", "convoy_escort_activity"))
    manifest_id = "planetary_reward_manifest_v26"
    provenance_id = "planetary_reward_provenance_v26"
    lineage_id = "planetary_reward_lineage_v26"
    identity_ref = "res://evidence/digest_reconciliation_v26/manifest.json"
    records = [{"activity_id": activity_id, "manifest_id": manifest_id, "provenance_id": provenance_id, "activity_authority_id": activity_authority, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "reward_id": f"reward_{activity_id}", "leaf_id": f"{activity_id}_reward_digest_reconciliation_leaf_v26", "evidence_ref": f"res://evidence/digest_reconciliation_v26/{activity_id}.json", "status": "PASS", "included_once": True} for activity_id, activity_authority in activities]
    identity = {"manifest_id": manifest_id, "provenance_id": provenance_id, "manifest_version": "v26", "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_digest_reconciliation", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    reconciliation = {"algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "evidence_ref": "res://evidence/digest_reconciliation_v26/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 6, "references_observed": 6, "records_reconciled": 5, "authority_reconciled": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    return {"schema_version": 26, "evidence_scope": "planetary_reward_digest_reconciliation_v26", "evidence_mode": "detached_reward_digest_reconciliation_v26", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "digest-reconciliation-v26", "identity": identity, "authority": authority, "records": records, "digest_reconciliation": reconciliation, "digest_reconciliation_sha256": _reconciliation_digest(identity, authority, reconciliation, records), "counts": {"records": 5, "references": 6, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardDigestReconciliationV26ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_digest_reconciliation(evidence()), [])

    def test_schema_version_is_v26(self):
        item = evidence()
        item["schema_version"] = 25
        self.assertTrue(any("schema_version must be 26" in error for error in validate_digest_reconciliation(item)))

    def test_algorithm_is_sha256(self):
        item = evidence()
        item["digest_reconciliation"]["algorithm"] = "md5"
        self.assertTrue(any("digest_reconciliation.algorithm must be sha256" in error for error in validate_digest_reconciliation(item)))

    def test_canonicalization_is_required(self):
        item = evidence()
        item["digest_reconciliation"]["canonicalization"] = "other"
        self.assertTrue(any("digest_reconciliation.canonicalization must be json_sort_keys_compact" in error for error in validate_digest_reconciliation(item)))

    def test_digest_binds_reconciliation(self):
        item = evidence()
        item["digest_reconciliation"]["records_reconciled"] = 4
        self.assertTrue(any("does not match canonical digest payload" in error for error in validate_digest_reconciliation(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_digest_reconciliation(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_digest_reconciliation(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_digest_reconciliation(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
