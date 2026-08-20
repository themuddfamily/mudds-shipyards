import copy
import unittest

from tools.world.planetary_navigation_evidence_validator import validate_manifest


def manifest():
    return {
        "schema_version": 1, "world_id": "ember_moon", "region_id": "ember_caldera",
        "unit_system": "game_scale_si_body_local",
        "nodes": [
            {"id": "pad", "body_local_m": [18, 120000, 0]},
            {"id": "staging", "body_local_m": [42, 120000, 0]},
            {"id": "overlook", "body_local_m": [420, 120025, -180]},
        ],
        "edges": [
            {"from": "pad", "to": "staging", "maximum_length_m": 100},
            {"from": "staging", "to": "overlook", "maximum_length_m": 1000},
        ],
        "landing_sites": [{"id": "caldera_pad", "node_id": "pad", "route_id": "pad_to_staging", "evidence": {"status": "PASS", "evidence": "authored landing-region record"}}],
        "native_playtest": {"status": "NOT_RUN", "evidence": None, "reason": "native hardware gate remains open"},
        "authority": {"navigation_runtime": False, "landing_runtime": False, "terrain_generation": False, "movement": False},
    }


class PlanetaryNavigationEvidenceValidatorTest(unittest.TestCase):
    def test_authored_route_and_landing_record_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_unknown_landing_node_fails(self):
        item = manifest(); item["landing_sites"][0]["node_id"] = "missing"
        self.assertTrue(any("unknown node" in error for error in validate_manifest(item)))

    def test_unreachable_route_node_fails(self):
        item = manifest(); item["nodes"].append({"id": "orphan", "body_local_m": [1, 1, 1]})
        self.assertTrue(any("reach every" in error for error in validate_manifest(item)))

    def test_edge_length_is_checked(self):
        item = manifest(); item["edges"][0]["maximum_length_m"] = 1
        self.assertTrue(any("maximum length" in error for error in validate_manifest(item)))

    def test_pass_evidence_is_required(self):
        item = manifest(); item["landing_sites"][0]["evidence"]["evidence"] = ""
        self.assertTrue(any("evidence is required" in error for error in validate_manifest(item)))

    def test_native_not_run_cannot_claim_execution(self):
        item = manifest(); item["native_playtest"]["evidence"] = "Windows capture"
        self.assertTrue(any("native_playtest.evidence" in error for error in validate_manifest(item)))

    def test_runtime_authority_must_remain_false(self):
        item = manifest(); item["authority"]["movement"] = True
        self.assertTrue(any("authority.movement" in error for error in validate_manifest(item)))

    def test_duplicate_route_edges_fail(self):
        item = manifest(); item["edges"].append(copy.deepcopy(item["edges"][0]))
        self.assertTrue(any("duplicate" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
