import copy
import unittest

from tools.world.planetary_recovery_duplicate_stale_guard_validator import validate_guards


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
    recovery_ids = (
        "return_to_landed_ship",
        "abort_to_orbit_return",
        "reset_at_start_beacon",
        "reset_at_start_beacon",
        "recover_convoy_at_return_beacon",
    )
    submission_specs = (
        ("fresh_recovery", 1, True, False, False),
        ("duplicate_recovery", 1, False, True, False),
        ("stale_recovery", 0, False, False, True),
        ("retry_recovery", 2, True, False, False),
    )
    activities = []
    for activity_id, authority, recovery_id in zip(activity_ids, authorities, recovery_ids):
        submissions = [
            {
                "kind": kind,
                "generation": generation,
                "accepted": accepted,
                "duplicate_rejected": duplicate_rejected,
                "stale_rejected": stale_rejected,
                "event_id": f"{activity_id}_{kind}",
                "committed_once": True,
            }
            for kind, generation, accepted, duplicate_rejected, stale_rejected in submission_specs
        ]
        activities.append(
            {
                "activity_id": activity_id,
                "activity_authority_id": authority,
                "recovery_authority_id": "planetary_landing_return_contract",
                "recovery_id": recovery_id,
                "attempt_generation": 1,
                "retry_generation": 2,
                "recovery_accept_once": True,
                "duplicate_recovery_rejected": True,
                "stale_recovery_rejected": True,
                "retry_once": True,
                "submissions": submissions,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_recovery_duplicate_stale_guards",
        "evidence_mode": "detached_recovery_guard_fixture",
        "runtime_authority": False,
        "recovery_runtime": False,
        "objective_runtime": False,
        "movement_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "source_revision": "recovery-guard-v1",
        "activities": activities,
        "authority": {
            "activity": False,
            "objective": False,
            "recovery": False,
            "movement": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryRecoveryDuplicateStaleGuardValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_guards(evidence()), [])

    def test_guard_order_is_required(self):
        item = evidence()
        item["activities"][0]["submissions"][1], item["activities"][0]["submissions"][2] = item["activities"][0]["submissions"][2], item["activities"][0]["submissions"][1]
        self.assertTrue(any("authored guard order" in error for error in validate_guards(item)))

    def test_duplicate_submission_must_be_rejected(self):
        item = evidence()
        item["activities"][1]["submissions"][1]["accepted"] = True
        self.assertTrue(any("accepted has an invalid guard outcome" in error for error in validate_guards(item)))

    def test_stale_submission_must_be_rejected(self):
        item = evidence()
        item["activities"][2]["submissions"][2]["stale_rejected"] = False
        self.assertTrue(any("stale_rejected has an invalid guard outcome" in error for error in validate_guards(item)))

    def test_retry_generation_is_two(self):
        item = evidence()
        item["activities"][3]["submissions"][3]["generation"] = 3
        self.assertTrue(any("generation must be 2" in error for error in validate_guards(item)))

    def test_recovery_id_must_be_existing(self):
        item = evidence()
        item["activities"][4]["recovery_id"] = "invented_recovery"
        self.assertTrue(any("existing recovery ID" in error for error in validate_guards(item)))

    def test_duplicate_event_ids_are_rejected(self):
        item = evidence()
        item["activities"][4]["submissions"][3]["event_id"] = item["activities"][0]["submissions"][3]["event_id"]
        self.assertTrue(any("guard_event_ids must not contain duplicates" in error for error in validate_guards(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_guards(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
