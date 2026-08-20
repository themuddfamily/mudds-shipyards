import unittest

from tools.review.planetary_hazard_route_landmark_connectivity_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_hazard_route_landmark_connectivity_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "b4d8387",
        "landmarks": [{"id": "pad", "role": "landing_pad", "capture_id": "pad-view", "review_status": "pending"}, {"id": "relay", "role": "hazard_anchor", "capture_id": "relay-view", "review_status": "pending"}],
        "edges": [{"from_landmark": "pad", "to_landmark": "relay", "route_id": "pad_to_relay", "capture_id": "route-view", "review_status": "not_performed"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["route_runtime", "native_render", "human_review"],
    }


class PlanetaryHazardRouteLandmarkConnectivityLedgerTest(unittest.TestCase):
    def test_open_connected_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_edge_landmarks_must_exist(self):
        item = ledger(); item["edges"][0]["to_landmark"] = "missing"
        self.assertTrue(any("known landmarks" in error for error in validate_ledger(item)))

    def test_orphan_landmark_fails_connectivity(self):
        item = ledger(); item["landmarks"].append({"id": "orphan", "role": "hazard_anchor", "capture_id": "orphan-view", "review_status": "pending"})
        self.assertTrue(any("reach every" in error for error in validate_ledger(item)))

    def test_capture_ids_are_required(self):
        item = ledger(); item["edges"][0]["capture_id"] = ""
        self.assertTrue(any("capture_id" in error for error in validate_ledger(item)))

    def test_review_status_stays_open(self):
        item = ledger(); item["landmarks"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_ledger(item)))

    def test_route_id_is_required(self):
        item = ledger(); item["edges"][0]["route_id"] = ""
        self.assertTrue(any("route_id" in error for error in validate_ledger(item)))

    def test_native_gate_stays_open(self):
        item = ledger(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
