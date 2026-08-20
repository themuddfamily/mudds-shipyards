import copy
import unittest

from tools.world.planetary_recovery_return_beacon_evidence_validator import validate_evidence


def evidence() -> dict:
    beacon_specs = (
        ("ember_landed_ship_beacon", "return_to_landed_ship", "landed_ship"),
        ("ember_orbit_return_beacon", "abort_to_orbit_return", "orbit_return"),
        ("ember_start_beacon", "reset_at_start_beacon", "start_beacon"),
        ("ember_convoy_return_beacon", "recover_convoy_at_return_beacon", "convoy_return_beacon"),
    )
    beacons = [
        {
            "id": beacon_id,
            "recovery_id": recovery_id,
            "recovery_target": target,
            "recovery_route_id": f"route_to_{beacon_id}",
            "route_destination": beacon_id,
            "return_route_id": "return_to_mudds",
            "authored_once": True,
        }
        for beacon_id, recovery_id, target in beacon_specs
    ]
    activity_ids = (
        "ember_beacon_survey",
        "ember_caldera_patrol",
        "ember_kit_cargo_run",
        "ember_checkpoint_race",
        "ember_convoy_escort",
    )
    beacon_ids = (
        "ember_landed_ship_beacon",
        "ember_orbit_return_beacon",
        "ember_start_beacon",
        "ember_start_beacon",
        "ember_convoy_return_beacon",
    )
    recovery_by_beacon = {beacon["id"]: beacon for beacon in beacons}
    activities = []
    for activity_id, beacon_id in zip(activity_ids, beacon_ids):
        beacon = recovery_by_beacon[beacon_id]
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "recovery_id": beacon["recovery_id"],
                "recovery_target": beacon["recovery_target"],
                "recovery_beacon_id": beacon_id,
                "recovery_route_id": beacon["recovery_route_id"],
                "return_route_id": "return_to_mudds",
                "recovery_event_id": f"recovery_{activity_id}",
                "attempt_generation": 1,
                "retry_generation": 2,
                "recovery_requested_once": True,
                "recovery_accepted_once": True,
                "beacon_arrival_once": True,
                "stale_recovery_rejected": True,
                "retry_allowed": True,
                "return_presented_once": True,
                "returned_once": True,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_recovery_return_beacon",
        "evidence_mode": "detached_beacon_evidence",
        "runtime_authority": False,
        "recovery_runtime": False,
        "movement_runtime": False,
        "save_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "source_revision": "recovery-beacon-v1",
        "beacons": beacons,
        "return_route": {
            "id": "return_to_mudds",
            "destination": "mudds_shipyards",
            "arrival_once": True,
            "loading_dead_end": False,
        },
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


class PlanetaryRecoveryReturnBeaconEvidenceValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_evidence(evidence()), [])

    def test_beacon_identity_is_authored(self):
        item = evidence()
        item["beacons"][0]["id"] = "invented_beacon"
        self.assertTrue(any("existing authored recovery beacon" in error for error in validate_evidence(item)))

    def test_route_must_terminate_at_beacon(self):
        item = evidence()
        item["beacons"][1]["route_destination"] = "other_beacon"
        self.assertTrue(any("route_destination" in error for error in validate_evidence(item)))

    def test_activity_must_match_beacon_recovery(self):
        item = evidence()
        item["activities"][0]["recovery_id"] = "abort_to_orbit_return"
        self.assertTrue(any("match the recovery beacon" in error for error in validate_evidence(item)))

    def test_all_beacons_must_be_covered(self):
        item = evidence()
        item["activities"][4]["recovery_beacon_id"] = "ember_start_beacon"
        self.assertTrue(any("cover every authored recovery beacon" in error for error in validate_evidence(item)))

    def test_retry_generation_is_fenced(self):
        item = evidence()
        item["activities"][2]["retry_generation"] = 3
        self.assertTrue(any("retry generation two" in error for error in validate_evidence(item)))

    def test_return_route_must_reach_mudds(self):
        item = evidence()
        item["return_route"]["destination"] = "other_destination"
        self.assertTrue(any("return_route.destination" in error for error in validate_evidence(item)))

    def test_runtime_authority_stays_external(self):
        item = evidence()
        item["authority"]["recovery"] = True
        self.assertTrue(any("authority.recovery" in error for error in validate_evidence(item)))

    def test_native_claim_fails_closed(self):
        item = copy.deepcopy(evidence())
        item["native_claims"] = True
        self.assertTrue(any("native_claims" in error for error in validate_evidence(item)))


if __name__ == "__main__":
    unittest.main()
