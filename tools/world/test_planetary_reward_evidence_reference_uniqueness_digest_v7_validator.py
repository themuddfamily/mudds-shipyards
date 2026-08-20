import copy
import unittest

from tools.world.planetary_reward_evidence_reference_uniqueness_digest_v7_validator import _reference_digest, validate_digest


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
    references = [f"res://evidence/reward_refs/{activity_id}.json" for activity_id in activity_ids]
    records = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "evidence_ref": reference,
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority, reference in zip(activity_ids, authorities, references)
    ]
    return {
        "schema_version": 7,
        "evidence_scope": "planetary_reward_evidence_reference_uniqueness_digest_v7",
        "evidence_mode": "detached_reward_evidence_reference_digest_v7",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "reference-digest-v7",
        "references_digest_sha256": _reference_digest(references),
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
        "counts": {"records": 5, "unique_references": 5, "pass_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardEvidenceReferenceUniquenessDigestV7ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_digest(evidence()), [])

    def test_schema_version_is_v7(self):
        item = evidence()
        item["schema_version"] = 6
        self.assertTrue(any("schema_version must be 7" in error for error in validate_digest(item)))

    def test_reference_digest_must_match(self):
        item = evidence()
        item["records"][0]["evidence_ref"] = "res://evidence/other.json"
        self.assertTrue(any("does not match canonical references" in error for error in validate_digest(item)))

    def test_references_must_be_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_digest(item)))

    def test_reference_must_be_res_path(self):
        item = evidence()
        item["records"][1]["evidence_ref"] = "file://other.json"
        self.assertTrue(any("res:// path" in error for error in validate_digest(item)))

    def test_counts_must_match_unique_references(self):
        item = evidence()
        item["counts"]["unique_references"] = 4
        self.assertTrue(any("counts.unique_references must be 5" in error for error in validate_digest(item)))

    def test_authority_writes_are_forbidden(self):
        item = evidence()
        item["authority"]["writes_store"] = True
        self.assertTrue(any("writes_store must be false" in error for error in validate_digest(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_digest(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
