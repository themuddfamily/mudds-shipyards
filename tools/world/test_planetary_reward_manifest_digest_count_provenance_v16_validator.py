import copy
import unittest

from tools.world.planetary_reward_manifest_digest_count_provenance_v16_validator import _digest, validate_manifest


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
    manifest_id = "planetary_reward_manifest_v16"
    provenance_id = "planetary_reward_provenance_v16"
    identity_ref = "res://evidence/digest_count_v16/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_digest_count_leaf_v16",
            "evidence_ref": f"res://evidence/digest_count_v16/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    counts = {"records": 5, "reward_ids": 5, "leaf_ids": 5, "evidence_refs": 6, "pass_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
    return {
        "schema_version": 16,
        "evidence_scope": "planetary_reward_manifest_digest_count_provenance_v16",
        "evidence_mode": "detached_reward_manifest_digest_count_v16",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "digest-count-v16",
        "identity": {"manifest_id": manifest_id, "provenance_id": provenance_id, "manifest_version": "v16", "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "records": records,
        "counts": counts,
        "manifest_digest_sha256": _digest(manifest_id, provenance_id, counts, records),
        "overall_status": "PASS",
    }


class PlanetaryRewardManifestDigestCountProvenanceV16ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_manifest(evidence()), [])

    def test_schema_version_is_v16(self):
        item = evidence()
        item["schema_version"] = 15
        self.assertTrue(any("schema_version must be 16" in error for error in validate_manifest(item)))

    def test_digest_must_match_payload(self):
        item = evidence()
        item["records"][0]["status"] = "NOT_RUN"
        self.assertTrue(any("does not match canonical digest payload" in error for error in validate_manifest(item)))

    def test_count_field_is_in_digest(self):
        item = evidence()
        item["counts"]["reward_ids"] = 4
        self.assertTrue(any("does not match canonical digest payload" in error for error in validate_manifest(item)))

    def test_identity_is_reconciled(self):
        item = evidence()
        item["records"][1]["provenance_id"] = "other_provenance"
        self.assertTrue(any("manifest/provenance IDs must match identity" in error for error in validate_manifest(item)))

    def test_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_manifest(item)))

    def test_counts_must_show_no_writes(self):
        item = evidence()
        item["counts"]["inventory_writes"] = 1
        self.assertTrue(any("counts.inventory_writes must be 0" in error for error in validate_manifest(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_manifest(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
