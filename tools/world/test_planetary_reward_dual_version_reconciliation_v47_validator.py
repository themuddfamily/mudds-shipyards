import copy
import unittest

from tools.world.planetary_reward_dual_version_reconciliation_v47_validator import (
    _reconciliation_digest,
    validate_reconciliation,
)


def evidence() -> dict:
    activities = (("ember_beacon_survey", "activity_director"), ("ember_caldera_patrol", "activity_director"), ("ember_kit_cargo_run", "cargo_delivery_activity"), ("ember_checkpoint_race", "timed_checkpoint_race"), ("ember_convoy_escort", "convoy_escort_activity"))
    manifest_id = "planetary_reward_manifest_v47"
    provenance_id = "planetary_reward_provenance_v47"
    lineage_id = "planetary_reward_lineage_v47"
    identity_ref = "res://evidence/dual_reconciliation_v47/manifest.json"
    records = [{"activity_id": activity_id, "manifest_id": manifest_id, "provenance_id": provenance_id, "activity_authority_id": activity_authority, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "reward_id": f"reward_{activity_id}", "leaf_id": f"{activity_id}_reward_dual_version_reconciliation_leaf_v47", "evidence_ref": f"res://evidence/dual_reconciliation_v47/{activity_id}.json", "status": "PASS", "included_once": True} for activity_id, activity_authority in activities]
    identity = {"manifest_id": manifest_id, "manifest_version": "v47", "provenance_id": provenance_id, "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_dual_version_reconciliation", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority_link = {"authority_version": "authority_v47", "link_id": "planetary_reward_manifest_authority_link_v47", "manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "linked": True, "evidence_ref": "res://evidence/dual_reconciliation_v47/authority_link.json", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    provenance_link = {"provenance_version": "provenance_v47", "link_id": "planetary_reward_manifest_provenance_link_v47", "manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "source": "detached_evidence", "linked": True, "evidence_ref": "res://evidence/dual_reconciliation_v47/provenance_link.json", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    reconciliation = {"schema_version": 47, "authority_version": "authority_v47", "provenance_version": "provenance_v47", "authority_link_id": "planetary_reward_manifest_authority_link_v47", "provenance_link_id": "planetary_reward_manifest_provenance_link_v47", "manifest_id": manifest_id, "manifest_version": "v47", "provenance_id": provenance_id, "lineage_id": lineage_id, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "evidence_ref": "res://evidence/dual_reconciliation_v47/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 8, "references_observed": 8, "records_reconciled": 5, "dual_links_reconciled": True, "authority_reconciled": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    return {"schema_version": 47, "evidence_scope": "planetary_reward_dual_version_reconciliation_v47", "evidence_mode": "detached_reward_dual_version_reconciliation_v47", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "dual-reconciliation-v47", "identity": identity, "authority": authority, "authority_link": authority_link, "provenance_link": provenance_link, "records": records, "dual_version_reconciliation": reconciliation, "dual_version_reconciliation_digest_sha256": _reconciliation_digest(identity, authority, authority_link, provenance_link, reconciliation, records), "counts": {"records": 5, "references": 8, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardDualVersionReconciliationV47ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_reconciliation(evidence()), [])

    def test_schema_version_is_v47(self):
        item = evidence()
        item["schema_version"] = 46
        self.assertTrue(any("schema_version must be 47" in error for error in validate_reconciliation(item)))

    def test_authority_version_is_required(self):
        item = evidence()
        item["authority_link"]["authority_version"] = "other"
        self.assertTrue(any("authority_link.authority_version must be authority_v47" in error for error in validate_reconciliation(item)))

    def test_reconciliation_links_are_required(self):
        item = evidence()
        item["dual_version_reconciliation"]["dual_links_reconciled"] = False
        self.assertTrue(any("dual_version_reconciliation.dual_links_reconciled must be True" in error for error in validate_reconciliation(item)))

    def test_digest_binds_reconciliation(self):
        item = evidence()
        item["dual_version_reconciliation"]["records_reconciled"] = 4
        self.assertTrue(any("dual_version_reconciliation_digest_sha256 does not match canonical v47 payload" in error for error in validate_reconciliation(item)))

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
