import unittest

from tools.review.planetary_route_hazard_recovery_evidence_index import validate_index


def index():
    return {
        "schema": "planetary_route_hazard_recovery_index_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "1f19d52",
        "routes": [{"id": "caldera_route", "from_node": "pad", "to_node": "rim", "evidence_status": "pending"}],
        "hazards": [{"id": "dust_surge", "route_id": "caldera_route", "kind": "dust_surge", "recovery_id": "return_to_staging", "resolution": "external_authority", "evidence": {"status": "pending", "record": None}}],
        "recovery_handoffs": [{"id": "return_to_staging", "status": "pending", "evidence": None}],
        "gates": {"native_run": {"status": "not_performed"}, "human_route_review": {"status": "pending"}},
    }


class PlanetaryRouteHazardRecoveryEvidenceIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_route_ids_are_unique(self):
        item = index(); item["routes"].append(dict(item["routes"][0]))
        self.assertTrue(any("unique" in error for error in validate_index(item)))

    def test_hazard_route_must_exist(self):
        item = index(); item["hazards"][0]["route_id"] = "missing"
        self.assertTrue(any("authored route" in error for error in validate_index(item)))

    def test_hazard_recovery_must_exist(self):
        item = index(); item["hazards"][0]["recovery_id"] = "missing"
        self.assertTrue(any("recovery handoff" in error for error in validate_index(item)))

    def test_external_resolution_boundary_is_required(self):
        item = index(); item["hazards"][0]["resolution"] = "runtime"
        self.assertTrue(any("external_authority" in error for error in validate_index(item)))

    def test_recovery_not_performed_has_no_evidence(self):
        item = index(); item["recovery_handoffs"][0]["status"] = "not_performed"; item["recovery_handoffs"][0]["evidence"] = "run"
        self.assertTrue(any("must be null" in error for error in validate_index(item)))

    def test_native_gate_stays_open(self):
        item = index(); item["gates"]["native_run"]["status"] = "PASS"
        self.assertTrue(any("native_run" in error for error in validate_index(item)))

    def test_hazard_evidence_stays_open(self):
        item = index(); item["hazards"][0]["evidence"]["status"] = "PASS"
        self.assertTrue(any("must remain open" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
