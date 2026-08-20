import unittest

from tools.review.planetary_settlement_connectivity_evidence_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_settlement_connectivity_evidence_v1", "world_id": "ember_moon", "settlement_id": "caldera_staging", "source_revision": "c3a61a5",
        "nodes": [{"id": "pad", "role": "landing_pad"}, {"id": "relay", "role": "relay"}, {"id": "overlook", "role": "landmark"}],
        "edges": [{"id": "pad_relay", "from": "pad", "to": "relay", "route_id": "pad_to_relay", "review_status": "pending"}, {"id": "relay_overlook", "from": "relay", "to": "overlook", "route_id": "relay_to_overlook", "review_status": "not_performed"}],
        "connectivity_evidence": {"status": "pending"}, "native_render": {"status": "not_performed"}, "human_route_review": {"status": "pending"}, "claims_excluded": ["route_runtime", "native_render", "human_route_review"],
    }


class PlanetarySettlementConnectivityEvidenceLedgerTest(unittest.TestCase):
    def test_open_connected_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_duplicate_node_ids_fail(self):
        item = ledger(); item["nodes"].append(dict(item["nodes"][0]))
        self.assertTrue(any("id must be unique" in error for error in validate_ledger(item)))

    def test_edge_nodes_must_exist(self):
        item = ledger(); item["edges"][0]["to"] = "missing"
        self.assertTrue(any("known nodes" in error for error in validate_ledger(item)))

    def test_orphan_node_fails_connectivity(self):
        item = ledger(); item["nodes"].append({"id": "orphan", "role": "exit"})
        self.assertTrue(any("reach every" in error for error in validate_ledger(item)))

    def test_edge_review_stays_open(self):
        item = ledger(); item["edges"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_ledger(item)))

    def test_route_id_is_required(self):
        item = ledger(); item["edges"][0]["route_id"] = ""
        self.assertTrue(any("route_id" in error for error in validate_ledger(item)))

    def test_connectivity_evidence_stays_open(self):
        item = ledger(); item["connectivity_evidence"]["status"] = "PASS"
        self.assertTrue(any("connectivity_evidence" in error for error in validate_ledger(item)))

    def test_gate_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
