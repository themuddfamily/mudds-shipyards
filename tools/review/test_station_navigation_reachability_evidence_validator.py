import copy
import unittest

from tools.review.station_navigation_reachability_evidence_validator import EXPECTED_MODULES, validate_ledger


SHA = "a" * 64


def _ledger() -> dict:
    modules = []
    for index, (module_id, route_id) in enumerate(EXPECTED_MODULES.items()):
        slot = f"slot-{index + 1}"
        modules.append({
            "module_id": module_id,
            "route_id": route_id,
            "slot_id": slot,
            "hub_endpoint_id": f"{slot}:hub",
            "module_endpoint_id": f"{slot}:module",
            "node_id": f"module:{module_id}:{route_id}",
            "edge_endpoints": [f"{slot}:hub", f"{slot}:module"],
            "evidence_status": "modern_interpretation",
            "historical_authentication": False,
            "reachable_from_hub": True,
            "claim_count": 2,
            "path_hops": 1,
            "evidence": {"kind": "report", "path": f"reports/{module_id}.json", "sha256": SHA[:-1] + str(index)},
        })
    return {
        "schema": "station_navigation_reachability_evidence_v1",
        "source_revision": "working-tree-station-navigation-review",
        "graph_source": "scripts/world/station_route_registry.gd",
        "open_gate_reason": "declarative edges do not prove physical player traversal",
        "human_map_sweep_status": "not_performed",
        "physical_traversability_proven": False,
        "historical_authentication": False,
        "graph_summary": {
            "hub_id": "station-hub", "module_count": 7, "node_count": 8,
            "edge_count": 7, "component_count": 1, "dangling_slot_count": 0,
            "overclaimed_slot_count": 0,
        },
        "modules": modules,
        "adjacency": {
            "edge_count": 7, "connected_slots": 7, "total_slots": 7,
            "dangling_slot_count": 0, "overclaimed_slot_count": 0,
            "dangling_slots": [], "overclaimed_slots": [],
            "server_or_world_authority": True, "client_can_mutate": False,
        },
    }


class StationNavigationReachabilityEvidenceTests(unittest.TestCase):
    def test_complete_declarative_graph_keeps_human_sweep_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_module_roster_and_edge_pairing_fail_closed(self):
        value = _ledger()
        value["modules"].pop()
        value["modules"][0]["edge_endpoints"] = ["slot-1:hub", "slot-1:hub"]
        errors = validate_ledger(value)
        self.assertTrue(any("exactly seven entries" in error for error in errors))
        self.assertTrue(any("distinct endpoints" in error for error in errors))

    def test_dangling_or_overclaimed_graph_cannot_be_ready(self):
        value = _ledger()
        value["adjacency"]["dangling_slot_count"] = 1
        value["adjacency"]["dangling_slots"] = ["slot-1"]
        value["physical_traversability_proven"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("dangling_slot_count must be 0" in error for error in errors))
        self.assertTrue(any("dangling_slots must be an empty list" in error for error in errors))
        self.assertTrue(any("physical_traversability_proven" in error for error in errors))

    def test_historical_and_human_claims_fail_closed(self):
        value = _ledger()
        value["human_map_sweep_status"] = "complete"
        value["modules"][0]["historical_authentication"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("human_map_sweep_status" in error for error in errors))
        self.assertTrue(any("historical_authentication" in error for error in errors))

    def test_duplicate_evidence_and_bad_digest_are_rejected(self):
        value = _ledger()
        value["modules"][1]["evidence"] = copy.deepcopy(value["modules"][0]["evidence"])
        value["modules"][2]["evidence"]["sha256"] = "bad"
        errors = validate_ledger(value)
        self.assertTrue(any("duplicates an earlier" in error for error in errors))
        self.assertTrue(any("sha256" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
