import copy
import unittest

from tools.world.planetary_reward_manifest_count_digest_provenance_v15_validator import _manifest_digest, validate_manifest


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
    manifest_id = "planetary_reward_manifest_v15"
    provenance_id = "planetary_reward_provenance_v15"
    identity_ref = "res://evidence/count_digest_v15/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_count_digest_leaf_v15",
            "evidence_ref": f"res://evidence/count_digest_v15/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    counts = {"records": 5, "leaf_ids": 5, "evidence_refs": 6, "pass_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}
    return {
        "schema_version": 15,
        "evidence_scope": "planetary_reward_manifest_count_digest_provenance_v15",
        "evidence_mode": "detached_reward_manifest_count_digest_v15",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "count-digest-v15",
        "identity": {"manifest_id": manifest_id, "manifest_version": "v15", "provenance_id": provenance_id, "source": "detached_evidence", "evidence_ref": identity_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "records": records,
        "counts": counts,
        "manifest_digest_sha256": _manifest_digest(manifest_id, provenance_id, counts, records),
        "overall_status": "PASS",
    }


class PlanetaryRewardManifestCountDigestProvenanceV15ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_manifest(evidence()), [])

    def test_schema_version_is_v15(self):
        item = evidence()
        item["schema_version"] = 14
        self.assertTrue(any("schema_version must be 15" in error for error in validate_manifest(item)))

    def test_manifest_digest_must_match(self):
        item = evidence()
        item["records"][0]["evidence_ref"] = "res://evidence/other.json"
        self.assertTrue(any("does not match canonical manifest payload" in error for error in validate_manifest(item)))

    def test_counts_are_part_of_digest(self):
        item = evidence()
        item["counts"]["pass_records"] = 4
        self.assertTrue(any("does not match canonical manifest payload" in error for error in validate_manifest(item)))

    def test_identity_is_reconciled(self):
        item = evidence()
        item["records"][1]["manifest_id"] = "other_manifest"
        self.assertTrue(any("manifest/provenance IDs must match identity" in error for error in validate_manifest(item)))

    def test_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_manifest(item)))

    def test_counts_must_show_no_writes(self):
        item = evidence()
        item["counts"]["store_writes"] = 1
        self.assertTrue(any("counts.store_writes must be 0" in error for error in validate_manifest(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_manifest(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
