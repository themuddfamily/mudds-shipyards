import copy
import unittest

from tools.world.planetary_reward_linked_authority_provenance_digest_v40_validator import (
    _linked_digest,
    validate_linked_authority_provenance,
)


def evidence() -> dict:
    activities = (("ember_beacon_survey", "activity_director"), ("ember_caldera_patrol", "activity_director"), ("ember_kit_cargo_run", "cargo_delivery_activity"), ("ember_checkpoint_race", "timed_checkpoint_race"), ("ember_convoy_escort", "convoy_escort_activity"))
    manifest_id = "planetary_reward_manifest_v40"
    provenance_id = "planetary_reward_provenance_v40"
    lineage_id = "planetary_reward_lineage_v40"
    identity_ref = "res://evidence/linked_authority_provenance_v40/manifest.json"
    records = [{"activity_id": activity_id, "manifest_id": manifest_id, "provenance_id": provenance_id, "activity_authority_id": activity_authority, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "reward_id": f"reward_{activity_id}", "leaf_id": f"{activity_id}_reward_linked_authority_provenance_leaf_v40", "evidence_ref": f"res://evidence/linked_authority_provenance_v40/{activity_id}.json", "status": "PASS", "included_once": True} for activity_id, activity_authority in activities]
    identity = {"manifest_id": manifest_id, "manifest_version": "v40", "provenance_id": provenance_id, "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_linked_authority_provenance", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority_link = {"link_id": "planetary_reward_manifest_authority_link_v40", "manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "linked": True, "evidence_ref": "res://evidence/linked_authority_provenance_v40/authority_link.json", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    provenance_link = {"link_id": "planetary_reward_manifest_provenance_link_v40", "manifest_id": manifest_id, "provenance_id": provenance_id, "lineage_id": lineage_id, "source": "detached_evidence", "linked": True, "evidence_ref": "res://evidence/linked_authority_provenance_v40/provenance_link.json", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    reconciliation = {"schema_version": 40, "digest_version": "linked_authority_provenance_v40", "authority_link_id": "planetary_reward_manifest_authority_link_v40", "provenance_link_id": "planetary_reward_manifest_provenance_link_v40", "manifest_id": manifest_id, "manifest_version": "v40", "provenance_id": provenance_id, "lineage_id": lineage_id, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "evidence_ref": "res://evidence/linked_authority_provenance_v40/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 8, "references_observed": 8, "records_reconciled": 5, "links_reconciled": True, "authority_reconciled": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    return {"schema_version": 40, "evidence_scope": "planetary_reward_linked_authority_provenance_digest_v40", "evidence_mode": "detached_reward_linked_authority_provenance_v40", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "linked-authority-provenance-v40", "identity": identity, "authority": authority, "authority_link": authority_link, "provenance_link": provenance_link, "records": records, "linked_authority_provenance_reconciliation": reconciliation, "linked_authority_provenance_digest_sha256": _linked_digest(identity, authority, authority_link, provenance_link, reconciliation, records), "counts": {"records": 5, "references": 8, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardLinkedAuthorityProvenanceDigestV40ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_linked_authority_provenance(evidence()), [])

    def test_schema_version_is_v40(self):
        item = evidence()
        item["schema_version"] = 39
        self.assertTrue(any("schema_version must be 40" in error for error in validate_linked_authority_provenance(item)))

    def test_provenance_link_id_is_required(self):
        item = evidence()
        item["provenance_link"]["link_id"] = "other_link"
        self.assertTrue(any("provenance_link.link_id must be planetary_reward_manifest_provenance_link_v40" in error for error in validate_linked_authority_provenance(item)))

    def test_links_reconciliation_is_required(self):
        item = evidence()
        item["linked_authority_provenance_reconciliation"]["links_reconciled"] = False
        self.assertTrue(any("linked_authority_provenance_reconciliation.links_reconciled must be True" in error for error in validate_linked_authority_provenance(item)))

    def test_digest_binds_provenance_link(self):
        item = evidence()
        item["provenance_link"]["linked"] = False
        self.assertTrue(any("linked_authority_provenance_digest_sha256 does not match canonical linked payload" in error for error in validate_linked_authority_provenance(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_linked_authority_provenance(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_linked_authority_provenance(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_linked_authority_provenance(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
