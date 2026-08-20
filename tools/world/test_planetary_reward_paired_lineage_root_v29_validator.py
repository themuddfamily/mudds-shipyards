import copy
import unittest

from tools.world.planetary_reward_paired_lineage_root_v29_validator import (
    _root_digests,
    validate_lineage_root,
)


def evidence() -> dict:
    activities = (("ember_beacon_survey", "activity_director"), ("ember_caldera_patrol", "activity_director"), ("ember_kit_cargo_run", "cargo_delivery_activity"), ("ember_checkpoint_race", "timed_checkpoint_race"), ("ember_convoy_escort", "convoy_escort_activity"))
    manifest_id = "planetary_reward_manifest_v29"
    provenance_id = "planetary_reward_provenance_v29"
    lineage_id = "planetary_reward_lineage_v29"
    identity_ref = "res://evidence/paired_lineage_root_v29/manifest.json"
    records = [{"activity_id": activity_id, "manifest_id": manifest_id, "provenance_id": provenance_id, "activity_authority_id": activity_authority, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "reward_id": f"reward_{activity_id}", "leaf_id": f"{activity_id}_reward_lineage_root_leaf_v29", "evidence_ref": f"res://evidence/paired_lineage_root_v29/{activity_id}.json", "status": "PASS", "included_once": True} for activity_id, activity_authority in activities]
    identity = {"manifest_id": manifest_id, "provenance_id": provenance_id, "manifest_version": "v29", "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_paired_lineage_root", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    root = {"lineage_id": lineage_id, "root_id": "detached_reward_evidence_root_v29", "source": "detached_evidence", "evidence_ref": "res://evidence/paired_lineage_root_v29/root.json"}
    reconciliation = {"algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "root_id": "detached_reward_evidence_root_v29", "evidence_ref": "res://evidence/paired_lineage_root_v29/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 6, "references_observed": 6, "records_reconciled": 5, "root_reconciled": True, "identity_digest_present": True, "authority_digest_present": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    identity_digest, authority_digest, root_digest = _root_digests(identity, authority, root, reconciliation, records)
    return {"schema_version": 29, "evidence_scope": "planetary_reward_paired_lineage_root_v29", "evidence_mode": "detached_reward_paired_lineage_root_v29", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "paired-lineage-root-v29", "identity": identity, "authority": authority, "records": records, "lineage_root": root, "paired_reconciliation": reconciliation, "identity_digest_sha256": identity_digest, "authority_digest_sha256": authority_digest, "lineage_root_digest_sha256": root_digest, "counts": {"records": 5, "references": 6, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardPairedLineageRootV29ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_lineage_root(evidence()), [])

    def test_schema_version_is_v29(self):
        item = evidence()
        item["schema_version"] = 28
        self.assertTrue(any("schema_version must be 29" in error for error in validate_lineage_root(item)))

    def test_root_id_is_required(self):
        item = evidence()
        item["lineage_root"]["root_id"] = "other_root"
        self.assertTrue(any("lineage_root.root_id must be detached_reward_evidence_root_v29" in error for error in validate_lineage_root(item)))

    def test_root_reconciliation_is_required(self):
        item = evidence()
        item["paired_reconciliation"]["root_reconciled"] = False
        self.assertTrue(any("paired_reconciliation.root_reconciled must be True" in error for error in validate_lineage_root(item)))

    def test_root_digest_binds_root(self):
        item = evidence()
        item["lineage_root"]["root_id"] = "other_root"
        self.assertTrue(any("lineage_root_digest_sha256 does not match canonical lineage-root digest payload" in error for error in validate_lineage_root(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_lineage_root(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_lineage_root(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_lineage_root(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
