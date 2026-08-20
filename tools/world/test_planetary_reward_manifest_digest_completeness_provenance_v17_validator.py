import copy
import unittest

from tools.world.planetary_reward_manifest_digest_completeness_provenance_v17_validator import (
    _completeness_digest,
    validate_completeness,
)


def evidence() -> dict:
    activity_ids = (
        "ember_beacon_survey",
        "ember_caldera_patrol",
        "ember_kit_cargo_run",
        "ember_checkpoint_race",
        "ember_convoy_escort",
    )
    authorities = (
        "activity_director",
        "activity_director",
        "cargo_delivery_activity",
        "timed_checkpoint_race",
        "convoy_escort_activity",
    )
    manifest_id = "planetary_reward_manifest_v17"
    provenance_id = "planetary_reward_provenance_v17"
    identity_ref = "res://evidence/completeness_v17/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_complete_leaf_v17",
            "evidence_ref": f"res://evidence/completeness_v17/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    completeness = {
        "records_expected": 5,
        "records_observed": 5,
        "references_expected": 6,
        "references_observed": 6,
        "all_fields_present": True,
        "all_status_pass": True,
        "complete": True,
    }
    return {
        "schema_version": 17,
        "evidence_scope": "planetary_reward_manifest_digest_completeness_provenance_v17",
        "evidence_mode": "detached_reward_manifest_completeness_v17",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "completeness-v17",
        "identity": {
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "manifest_version": "v17",
            "source": "detached_evidence",
            "evidence_ref": identity_ref,
            "writes_store": False,
            "writes_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
        "authority": {
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "source": "detached_evidence",
            "writes_store": False,
            "writes_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
        "records": records,
        "completeness": completeness,
        "completeness_digest_sha256": _completeness_digest(manifest_id, provenance_id, completeness, records),
        "counts": {
            "records": 5,
            "references": 6,
            "complete_records": 5,
            "store_writes": 0,
            "inventory_writes": 0,
            "runtime_mutations": 0,
            "native_runs": 0,
        },
        "overall_status": "PASS",
    }


class PlanetaryRewardManifestDigestCompletenessProvenanceV17ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_completeness(evidence()), [])

    def test_schema_version_is_v17(self):
        item = evidence()
        item["schema_version"] = 16
        self.assertTrue(any("schema_version must be 17" in error for error in validate_completeness(item)))

    def test_completeness_count_is_reconciled(self):
        item = evidence()
        item["completeness"]["records_observed"] = 4
        self.assertTrue(any("completeness.records_observed must be 5" in error for error in validate_completeness(item)))

    def test_digest_must_match_canonical_completeness_payload(self):
        item = evidence()
        item["records"][0]["evidence_ref"] = "res://evidence/completeness_v17/changed.json"
        self.assertTrue(any("does not match canonical completeness payload" in error for error in validate_completeness(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_completeness(item)))

    def test_all_fields_must_be_present(self):
        item = evidence()
        item["completeness"]["all_fields_present"] = False
        self.assertTrue(any("completeness.all_fields_present must be True" in error for error in validate_completeness(item)))

    def test_counts_must_show_no_store_writes(self):
        item = evidence()
        item["counts"]["store_writes"] = 1
        self.assertTrue(any("counts.store_writes must be 0" in error for error in validate_completeness(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_completeness(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
