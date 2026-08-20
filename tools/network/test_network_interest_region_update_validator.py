import copy
import unittest

try:
    from .network_interest_region_update_validator import validate_update
except ImportError:  # Direct invocation from the tools/network directory.
    from network_interest_region_update_validator import validate_update


def _update() -> dict:
    rejection_statuses = ["unauthorized_source", "unknown_peer", "invalid_interest_region", "invalid_interest_capacity"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_interest_region_update",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer_id": 7,
        "audit": {"server_owns_interest": True, "server_owns_replication_budget": True, "client_can_mutate_state": False},
        "region_before": {"center": [0, 0, 0], "radius": 20, "max_entities": 1},
        "region_after": {"center": [10, 0, 0], "radius": 30, "max_entities": 2},
        "entities": [
            {"entity_id": "near", "position": [10, 0, 0], "replication_radius": 30},
            {"entity_id": "outside", "position": [100, 0, 0], "replication_radius": 30},
        ],
        "visible_before": ["near"],
        "visible_after": ["near"],
        "receipt": {"accepted": True, "status": "interest_updated", "source_peer_id": 99, "authority_peer_id": 99, "peer_id": 7, "snapshot_detached": True},
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True, "region_changed": False}
            for status in rejection_statuses
        ],
    }


class NetworkInterestRegionUpdateValidatorTest(unittest.TestCase):
    def test_accepts_geometric_region_update(self):
        self.assertEqual(validate_update(_update()), [])

    def test_rejects_visible_entity_outside_updated_region(self):
        report = _update()
        report["visible_after"] = ["outside"]
        self.assertTrue(any("outside updated region" in error for error in validate_update(report)))

    def test_rejects_region_capacity_overflow(self):
        report = _update()
        report["region_after"]["max_entities"] = 1
        report["visible_after"] = ["near", "outside"]
        self.assertTrue(any("visible_after exceeds" in error for error in validate_update(report)))

    def test_rejects_unchanged_region_update(self):
        report = _update()
        report["region_after"] = copy.deepcopy(report["region_before"])
        self.assertTrue(any("must change" in error for error in validate_update(report)))

    def test_rejects_missing_invalid_capacity_fence(self):
        report = _update()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("invalid_interest_capacity" in error for error in validate_update(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _update()
        report["audit"]["client_can_mutate_state"] = True
        report["uses_live_network"] = True
        errors = validate_update(report)
        self.assertTrue(any("client_can_mutate_state" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
