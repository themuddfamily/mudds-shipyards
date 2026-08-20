import copy
import unittest

from tools.world.planetary_reward_guard_summary_digest_validator import _digest_payload, validate_digest


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
    records = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_id": f"reward_{activity_id}",
            "retry_guard_id": f"{activity_id}_reward_retry_g2",
            "stale_guard_id": f"{activity_id}_reward_stale_g0",
            "status": "PASS",
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_guard_summary_digest",
        "evidence_mode": "detached_reward_guard_digest",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "record_count": 5,
        "source_revision": "guard-digest-v1",
        "records": records,
        "digest_sha256": _digest_payload(records),
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


class PlanetaryRewardGuardSummaryDigestValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_digest(evidence()), [])

    def test_digest_must_match_records(self):
        item = evidence()
        item["records"][0]["status"] = "NOT_RUN"
        self.assertTrue(any("does not match canonical records" in error for error in validate_digest(item)))

    def test_digest_format_is_lowercase_sha256(self):
        item = evidence()
        item["digest_sha256"] = "A" * 64
        self.assertTrue(any("lowercase SHA-256" in error for error in validate_digest(item)))

    def test_guard_ids_are_unique(self):
        item = evidence()
        item["records"][4]["stale_guard_id"] = item["records"][0]["stale_guard_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_digest(item)))

    def test_record_order_is_required(self):
        item = evidence()
        item["records"].reverse()
        self.assertTrue(any("authored activity order" in error for error in validate_digest(item)))

    def test_status_must_be_pass(self):
        item = evidence()
        item["records"][2]["status"] = "NOT_RUN"
        self.assertTrue(any("status must be PASS" in error for error in validate_digest(item)))

    def test_claim_flags_fail_closed(self):
        item = evidence()
        item["historical_claim"] = True
        self.assertTrue(any("historical_claim" in error for error in validate_digest(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_digest(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
