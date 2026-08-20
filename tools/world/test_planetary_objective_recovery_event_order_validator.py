import copy
import unittest

from tools.world.planetary_objective_recovery_event_order_validator import validate_order


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
    contracts = (
        ("return_to_landed_ship", "ember_landed_ship_beacon", "landed_ship"),
        ("abort_to_orbit_return", "ember_orbit_return_beacon", "orbit_return"),
        ("reset_at_start_beacon", "ember_start_beacon", "start_beacon"),
        ("reset_at_start_beacon", "ember_start_beacon", "start_beacon"),
        ("recover_convoy_at_return_beacon", "ember_convoy_return_beacon", "convoy_return_beacon"),
    )
    event_types = (
        "objective_failed",
        "recovery_requested",
        "recovery_accepted",
        "return_beacon_arrived",
        "retry_started",
        "objective_retried",
        "return_presented",
        "returned",
    )
    generations = (1, 1, 1, 1, 2, 2, 2, 2)
    activities = []
    for activity_id, activity_authority, (recovery_id, beacon_id, target) in zip(activity_ids, authorities, contracts):
        events = [
            {
                "type": event_type,
                "event_id": f"{activity_id}_{event_type}",
                "sequence": sequence,
                "generation": generation,
                "committed_once": True,
            }
            for sequence, (event_type, generation) in enumerate(zip(event_types, generations))
        ]
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": activity_authority,
                "recovery_authority_id": "planetary_landing_return_contract",
                "recovery_id": recovery_id,
                "recovery_target": target,
                "return_beacon_id": beacon_id,
                "return_route_id": "return_to_mudds",
                "return_target_id": "mudds_shipyards",
                "stale_event_rejected": True,
                "duplicate_recovery_rejected": True,
                "retry_once": True,
                "return_once": True,
                "events": events,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_recovery_event_order",
        "evidence_mode": "detached_recovery_event_order",
        "runtime_authority": False,
        "objective_runtime": False,
        "recovery_runtime": False,
        "movement_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "source_revision": "recovery-event-order-v1",
        "activities": activities,
        "authority": {
            "activity": False,
            "objective": False,
            "recovery": False,
            "movement": False,
            "landing": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryObjectiveRecoveryEventOrderValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_order(evidence()), [])

    def test_event_order_is_required(self):
        item = evidence()
        item["activities"][0]["events"][1], item["activities"][0]["events"][2] = item["activities"][0]["events"][2], item["activities"][0]["events"][1]
        self.assertTrue(any("authored recovery order" in error for error in validate_order(item)))

    def test_sequence_must_be_contiguous(self):
        item = evidence()
        item["activities"][1]["events"][3]["sequence"] = 7
        self.assertTrue(any("contiguous from zero" in error for error in validate_order(item)))

    def test_retry_generation_boundary_is_fenced(self):
        item = evidence()
        item["activities"][2]["events"][4]["generation"] = 1
        self.assertTrue(any("retry boundary" in error for error in validate_order(item)))

    def test_recovery_contract_must_be_existing(self):
        item = evidence()
        item["activities"][3]["recovery_id"] = "invented_recovery"
        self.assertTrue(any("existing recovery contract" in error for error in validate_order(item)))

    def test_duplicate_event_ids_are_rejected(self):
        item = evidence()
        item["activities"][4]["events"][7]["event_id"] = item["activities"][0]["events"][7]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_order(item)))

    def test_stale_event_guard_is_required(self):
        item = evidence()
        item["activities"][0]["stale_event_rejected"] = False
        self.assertTrue(any("stale_event_rejected" in error for error in validate_order(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_order(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
