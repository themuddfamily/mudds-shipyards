import copy
import unittest

from tools.world.planetary_route_settlement_return_validator import validate_manifest


def manifest() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_settlement_return_loop",
        "evidence_mode": "detached_authored_route_record",
        "world_id": "ember_moon",
        "landing_region_id": "ember_caldera",
        "return_target_id": "mudds_shipyards",
        "unit_system": "game_scale_si_body_local",
        "procedural_generation": False,
        "nodes": [
            {"id": "orbit", "role": "orbit_approach", "body_local_m": [0, 120000, 0]},
            {"id": "descent", "role": "descent_gate", "body_local_m": [12, 120000, 0]},
            {"id": "pad", "role": "landing_pad", "body_local_m": [18, 120000, 0]},
            {"id": "settlement", "role": "settlement", "body_local_m": [120, 120005, -20]},
            {"id": "return_beacon", "role": "return_beacon", "body_local_m": [260, 120012, -90]},
            {"id": "shipyard", "role": "shipyard_return", "body_local_m": [0, 0, 0]},
        ],
        "edges": [
            {"from": "orbit", "to": "descent", "maximum_length_m": 100},
            {"from": "descent", "to": "pad", "maximum_length_m": 100},
            {"from": "pad", "to": "settlement", "maximum_length_m": 500},
            {"from": "settlement", "to": "return_beacon", "maximum_length_m": 500},
            {"from": "return_beacon", "to": "shipyard", "maximum_length_m": 1000000},
            {"from": "settlement", "to": "pad", "maximum_length_m": 500},
        ],
        "routes": [
            {"id": "outbound_surface", "nodes": ["orbit", "descent", "pad"], "evidence": {"status": "PASS", "evidence": "authored approach route"}},
            {"id": "settlement_loop", "nodes": ["pad", "settlement", "return_beacon"], "evidence": {"status": "PASS", "evidence": "authored settlement route"}},
            {"id": "return_to_shipyard", "nodes": ["return_beacon", "shipyard"], "destination": "mudds_shipyards", "evidence": {"status": "PASS", "evidence": "authored return handoff"}},
            {"id": "failure_recovery", "nodes": ["settlement", "pad"], "evidence": {"status": "PASS", "evidence": "authored recover-to-pad edge"}},
        ],
        "settlement": {
            "id": "ember_caldera_settlement",
            "landing_node_id": "pad",
            "return_beacon_node_id": "return_beacon",
            "objective_ids": ["relay_repair", "supply_run"],
            "hazard_ids": ["unstable_slope", "relay_arc"],
            "recoverable_failure": True,
        },
        "loop": {
            "phase_path": ["orbit_approach", "descent", "surface_flight", "landed", "on_foot", "objective", "reboarded", "takeoff", "orbit_return"],
            "outbound_route_id": "outbound_surface",
            "settlement_route_id": "settlement_loop",
            "return_route_id": "return_to_shipyard",
            "recovery_route_id": "failure_recovery",
            "same_shipyard_identity": True,
            "loading_dead_end": False,
            "stranded_player": False,
        },
        "native_playtest": {"status": "NOT_RUN", "evidence": None, "reason": "native gate remains open"},
        "authority": {"navigation_runtime": False, "settlement_runtime": False, "hazard_runtime": False, "landing_runtime": False, "movement": False, "reward": False},
    }


class PlanetaryRouteSettlementReturnValidatorTest(unittest.TestCase):
    def test_authored_settlement_return_loop_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_missing_return_edge_fails(self):
        item = manifest(); item["routes"][2]["nodes"] = ["return_beacon", "pad"]
        self.assertTrue(any("without an authored edge" in error for error in validate_manifest(item)))

    def test_route_order_is_required(self):
        item = manifest(); item["routes"][0], item["routes"][1] = item["routes"][1], item["routes"][0]
        self.assertTrue(any("four authored" in error for error in validate_manifest(item)))

    def test_settlement_must_be_recoverable(self):
        item = manifest(); item["settlement"]["recoverable_failure"] = False
        self.assertTrue(any("recoverable_failure" in error for error in validate_manifest(item)))

    def test_loading_dead_end_is_rejected(self):
        item = manifest(); item["loop"]["loading_dead_end"] = True
        self.assertTrue(any("loading_dead_end" in error for error in validate_manifest(item)))

    def test_unknown_settlement_node_fails(self):
        item = manifest(); item["settlement"]["landing_node_id"] = "missing"
        self.assertTrue(any("unknown node" in error for error in validate_manifest(item)))

    def test_native_not_run_cannot_claim_capture(self):
        item = manifest(); item["native_playtest"]["evidence"] = "Windows route capture"
        self.assertTrue(any("native_playtest.evidence" in error for error in validate_manifest(item)))

    def test_runtime_authority_stays_external(self):
        item = copy.deepcopy(manifest()); item["authority"]["movement"] = True
        self.assertTrue(any("authority.movement" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
