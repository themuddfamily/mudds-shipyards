import copy
import unittest

from tools.world.planetary_keyed_reward_retry_stale_event_mapping_evidence_ledger import validate_ledger


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
    mappings = []
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        for event_type, generation, accepted, rejected, suffix in (
            ("reward_retry", 2, True, False, "reward_retry_g2"),
            ("reward_stale", 0, False, True, "reward_stale_g0"),
        ):
            mappings.append(
                {
                    "activity_id": activity_id,
                    "event_type": event_type,
                    "event_id": f"{activity_id}_{suffix}",
                    "generation": generation,
                    "accepted": accepted,
                    "rejected": rejected,
                    "reward_id": reward_id,
                    "activity_authority_id": authority,
                    "reward_authority_id": "game_flow_reward_authority",
                    "reward_store_id": "game_flow_reward_store",
                    "evidence_ref": f"res://evidence/rewards/{activity_id}_{event_type}.json",
                    "status": "PASS",
                    "committed_once": True,
                }
            )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_keyed_reward_retry_stale_event_mapping_evidence",
        "evidence_mode": "detached_keyed_reward_evidence_ledger",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "mapping_count": 10,
        "source_revision": "keyed-evidence-v1",
        "mappings": mappings,
        "authority": {
            "activity": False,
            "objective": False,
            "reward": False,
            "reward_store": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryKeyedRewardRetryStaleEventMappingEvidenceLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_evidence_ref_must_be_res_path(self):
        item = evidence()
        item["mappings"][0]["evidence_ref"] = "file://evidence.json"
        self.assertTrue(any("res:// path" in error for error in validate_ledger(item)))

    def test_evidence_refs_are_unique(self):
        item = evidence()
        item["mappings"][9]["evidence_ref"] = item["mappings"][1]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_ledger(item)))

    def test_status_must_be_pass(self):
        item = evidence()
        item["mappings"][2]["status"] = "NOT_RUN"
        self.assertTrue(any("status must be PASS" in error for error in validate_ledger(item)))

    def test_event_ids_are_unique(self):
        item = evidence()
        item["mappings"][8]["event_id"] = item["mappings"][0]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_ledger(item)))

    def test_generation_outcome_is_required(self):
        item = evidence()
        item["mappings"][3]["rejected"] = False
        self.assertTrue(any("invalid mapping outcome" in error for error in validate_ledger(item)))

    def test_historical_claim_fails_closed(self):
        item = evidence()
        item["historical_claim"] = True
        self.assertTrue(any("historical_claim" in error for error in validate_ledger(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_ledger(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
