import unittest

from tools.review.planetary_settlement_route_landmark_evidence_index import validate_index


def index():
    return {
        "schema": "planetary_settlement_route_landmark_index_v1", "world_id": "ember_moon", "settlement_id": "caldera_staging", "source_revision": "7972f53",
        "route_nodes": [{"id": "pad", "scene_path": "res://scenes/world/settlements/pad.tscn", "review_status": "pending"}, {"id": "relay", "scene_path": "res://scenes/world/settlements/relay.tscn", "review_status": "pending"}],
        "routes": [{"id": "pad_to_relay", "from_node": "pad", "to_node": "relay", "landmark_id": "relay_landmark", "evidence_status": "pending"}],
        "landmarks": [{"id": "relay_landmark", "node_id": "relay", "procedural_generation": False, "review_status": "not_performed"}],
        "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["native_render", "human_review", "route_runtime"],
    }


class PlanetarySettlementRouteLandmarkEvidenceIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_nodes_require_res_paths(self):
        item = index(); item["route_nodes"][0]["scene_path"] = "pad.tscn"
        self.assertTrue(any("res://" in error for error in validate_index(item)))

    def test_routes_require_known_nodes(self):
        item = index(); item["routes"][0]["to_node"] = "missing"
        self.assertTrue(any("known route nodes" in error for error in validate_index(item)))

    def test_routes_require_known_landmarks(self):
        item = index(); item["routes"][0]["landmark_id"] = "missing"
        self.assertTrue(any("authored landmark" in error for error in validate_index(item)))

    def test_landmarks_cannot_be_procedural(self):
        item = index(); item["landmarks"][0]["procedural_generation"] = True
        self.assertTrue(any("procedural_generation" in error for error in validate_index(item)))

    def test_route_evidence_stays_open(self):
        item = index(); item["routes"][0]["evidence_status"] = "approved"
        self.assertTrue(any("evidence_status" in error for error in validate_index(item)))

    def test_human_gate_stays_open(self):
        item = index(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_index(item)))

    def test_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
