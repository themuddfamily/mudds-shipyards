import copy
import unittest

from tools.world.planetary_reward_versioned_authority_reconciliation_v49_validator import (
    _authority_digest,
    validate_authority_reconciliation,
)


def evidence() -> dict:
    activities = (
        ("ember_beacon_survey", "activity_director"),
        ("ember_caldera_patrol", "activity_director"),
        ("ember_kit_cargo_run", "cargo_delivery_activity"),
        ("ember_checkpoint_race", "timed_checkpoint_race"),
        ("ember_convoy_escort", "convoy_escort_activity"),
    )
    manifest_id = "planetary_reward_manifest_v49"
    provenance_id = "planetary_reward_provenance_v49"
    lineage_id = "planetary_reward_lineage_v49"
    identity = {
        "manifest_id": manifest_id,
        "manifest_version": "v49",
        "provenance_id": provenance_id,
        "lineage_id": lineage_id,
        "source": "detached_evidence",
        "evidence_ref": "res://evidence/versioned_authority_v49/manifest.json",
        "writes_store": False,
        "writes_inventory": False,
        "writes_runtime": False,
        "runs_native": False,
    }
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": activity_authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_versioned_authority_leaf_v49",
            "evidence_ref": f"res://evidence/versioned_authority_v49/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, activity_authority in activities
    ]
    authority = {
        "reward_authority_id": "game_flow_reward_authority",
        "reward_store_id": "game_flow_reward_store",
        "authority_scope": "planetary_reward_versioned_authority_reconciliation",
        "source": "detached_evidence",
        "writes_store": False,
        "writes_inventory": False,
        "writes_runtime": False,
        "runs_native": False,
    }
    link = {
        "authority_version": "authority_v49",
        "link_id": "planetary_reward_manifest_authority_link_v49",
        "manifest_id": manifest_id,
        "provenance_id": provenance_id,
        "lineage_id": lineage_id,
        "reward_authority_id": "game_flow_reward_authority",
        "reward_store_id": "game_flow_reward_store",
        "source": "detached_evidence",
        "linked": True,
        "evidence_ref": "res://evidence/versioned_authority_v49/authority_link.json",
        "writes_store": False,
        "writes_inventory": False,
        "writes_runtime": False,
        "runs_native": False,
    }
    reconciliation = {
        "schema_version": 49,
        "authority_version": "authority_v49",
        "authority_link_id": "planetary_reward_manifest_authority_link_v49",
        "manifest_id": manifest_id,
        "manifest_version": "v49",
        "provenance_id": provenance_id,
        "lineage_id": lineage_id,
        "reward_authority_id": "game_flow_reward_authority",
        "reward_store_id": "game_flow_reward_store",
        "algorithm": "sha256",
        "canonicalization": "json_sort_keys_compact",
        "evidence_ref": "res://evidence/versioned_authority_v49/reconciliation.json",
        "records_expected": 5,
        "records_observed": 5,
        "references_expected": 7,
        "references_observed": 7,
        "records_reconciled": 5,
        "authority_link_reconciled": True,
        "authority_reconciled": True,
        "all_fields_present": True,
        "all_status_pass": True,
        "complete": True,
    }
    return {
        "schema_version": 49,
        "evidence_scope": "planetary_reward_versioned_authority_reconciliation_v49",
        "evidence_mode": "detached_reward_versioned_authority_reconciliation_v49",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "versioned-authority-v49",
        "identity": identity,
        "authority": authority,
        "authority_link": link,
        "records": records,
        "authority_reconciliation": reconciliation,
        "versioned_authority_digest_sha256": _authority_digest(identity, authority, link, reconciliation, records),
        "counts": {"records": 5, "references": 7, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardVersionedAuthorityReconciliationV49ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_authority_reconciliation(evidence()), [])

    def test_schema_version_is_v49(self):
        item = evidence()
        item["schema_version"] = 48
        self.assertTrue(any("schema_version must be 49" in error for error in validate_authority_reconciliation(item)))

    def test_authority_link_version_is_required(self):
        item = evidence()
        item["authority_link"]["authority_version"] = "authority_v48"
        self.assertTrue(any("authority_link.authority_version must be authority_v49" in error for error in validate_authority_reconciliation(item)))

    def test_reconciliation_binds_manifest_version(self):
        item = evidence()
        item["authority_reconciliation"]["manifest_version"] = "v48"
        self.assertTrue(any("authority_reconciliation.manifest_version must be v49" in error for error in validate_authority_reconciliation(item)))

    def test_digest_binds_authority(self):
        item = evidence()
        item["authority"]["reward_store_id"] = "other_store"
        self.assertTrue(any("versioned_authority_digest_sha256 does not match canonical v49 payload" in error for error in validate_authority_reconciliation(item)))

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
