import copy
import unittest

from tools.world.planetary_reward_completeness_authority_digest_v18_validator import (
    _authority_digest,
    validate_completeness_authority,
)


def evidence() -> dict:
    activities = (
        ("ember_beacon_survey", "activity_director"),
        ("ember_caldera_patrol", "activity_director"),
        ("ember_kit_cargo_run", "cargo_delivery_activity"),
        ("ember_checkpoint_race", "timed_checkpoint_race"),
        ("ember_convoy_escort", "convoy_escort_activity"),
    )
    manifest_id = "planetary_reward_manifest_v18"
    provenance_id = "planetary_reward_provenance_v18"
    identity_ref = "res://evidence/completeness_authority_v18/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": activity_authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_authority_leaf_v18",
            "evidence_ref": f"res://evidence/completeness_authority_v18/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, activity_authority in activities
    ]
    authority = {
        "reward_authority_id": "game_flow_reward_authority",
        "reward_store_id": "game_flow_reward_store",
        "source": "detached_evidence",
        "writes_store": False,
        "writes_inventory": False,
        "writes_runtime": False,
        "runs_native": False,
    }
    completeness = {
        "records_expected": 5,
        "records_observed": 5,
        "references_expected": 6,
        "references_observed": 6,
        "authority_records_expected": 5,
        "authority_records_observed": 5,
        "all_fields_present": True,
        "all_status_pass": True,
        "complete": True,
    }
    return {
        "schema_version": 18,
        "evidence_scope": "planetary_reward_completeness_authority_digest_v18",
        "evidence_mode": "detached_reward_completeness_authority_v18",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "completeness-authority-v18",
        "identity": {
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "manifest_version": "v18",
            "source": "detached_evidence",
            "evidence_ref": identity_ref,
            "writes_store": False,
            "writes_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
        "authority": authority,
        "records": records,
        "completeness": completeness,
        "authority_digest_sha256": _authority_digest(manifest_id, provenance_id, authority, completeness, records),
        "counts": {
            "records": 5,
            "references": 6,
            "authority_records": 5,
            "complete_records": 5,
            "store_writes": 0,
            "inventory_writes": 0,
            "runtime_mutations": 0,
            "native_runs": 0,
        },
        "overall_status": "PASS",
    }


class PlanetaryRewardCompletenessAuthorityDigestV18ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_completeness_authority(evidence()), [])

    def test_schema_version_is_v18(self):
        item = evidence()
        item["schema_version"] = 17
        self.assertTrue(any("schema_version must be 18" in error for error in validate_completeness_authority(item)))

    def test_authority_digest_covers_authority_join(self):
        item = evidence()
        item["records"][0]["reward_store_id"] = "other_store"
        self.assertTrue(any("must use the existing reward authority and store" in error for error in validate_completeness_authority(item)))

    def test_authority_completeness_is_reconciled(self):
        item = evidence()
        item["completeness"]["authority_records_observed"] = 4
        self.assertTrue(any("completeness.authority_records_observed must be 5" in error for error in validate_completeness_authority(item)))

    def test_digest_must_match_canonical_authority_payload(self):
        item = evidence()
        item["records"][0]["activity_authority_id"] = "cargo_delivery_activity"
        self.assertTrue(any("does not match canonical authority payload" in error for error in validate_completeness_authority(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_completeness_authority(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_completeness_authority(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_completeness_authority(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
