import copy
import unittest

try:
    from .network_ownership_seat_authority_validator import validate_rollup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_ownership_seat_authority_validator import validate_rollup


def _rollup() -> dict:
    rejection_statuses = [
        "unauthorized_source", "role_mismatch", "stale_ship_generation",
        "owner_mismatch", "stale_request_sequence",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_ownership_seat_authority",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "uses_live_network": False,
        "seat_policy": "network_seat_role_authority_v1",
        "ship_policy": "network_ship_ownership_authority_v1",
        "audit": {
            "server_owns_seat_reservation": True,
            "server_owns_role_assignment": True,
            "server_owns_ship_claims": True,
            "server_owns_ship_transfers": True,
            "server_owns_ship_generations": True,
            "server_owns_disconnect_cleanup": True,
            "client_can_mutate_ledger": False,
            "client_can_mutate_ownership": False,
        },
        "seats": [
            {"seat_id": "jovian_pilot", "vessel_id": "jovian", "role": "pilot", "seat_generation": 4},
            {"seat_id": "jovian_passenger", "vessel_id": "jovian", "role": "passenger", "seat_generation": 2},
        ],
        "assignments": [
            {
                "occupant_peer_id": 7,
                "avatar_id": "avatar_a",
                "seat_id": "jovian_pilot",
                "role": "pilot",
                "seat_generation": 4,
                "server_committed": True,
            }
        ],
        "ships": [
            {"ship_id": "jovian_a", "ship_generation": 7, "owner_peer_id": 8, "ownership_generation": 2},
        ],
        "claim": {
            "accepted": True, "status": "claimed", "ship_id": "jovian_a",
            "claimant_peer_id": 7, "server_committed": True,
        },
        "transfer": {
            "accepted": True, "status": "transferred", "ship_id": "jovian_a",
            "ship_generation": 7, "from_peer_id": 7, "to_peer_id": 8, "server_committed": True,
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
        "cleanup": {
            "accepted": True, "status": "peer_released", "seat_assignments_released": True,
            "ship_ownership_released": True, "server_committed": True, "client_invoked": False,
        },
    }


class NetworkOwnershipSeatAuthorityValidatorTest(unittest.TestCase):
    def test_accepts_server_owned_seat_and_ship_rollup(self):
        self.assertEqual(validate_rollup(_rollup()), [])

    def test_rejects_seat_role_or_generation_mismatch(self):
        report = _rollup()
        report["assignments"][0]["role"] = "gunner"
        report["assignments"][0]["seat_generation"] = 3
        errors = validate_rollup(report)
        self.assertTrue(any("role must match" in error for error in errors))
        self.assertTrue(any("seat_generation must match" in error for error in errors))

    def test_rejects_transfer_from_wrong_owner(self):
        report = _rollup()
        report["transfer"]["from_peer_id"] = 8
        self.assertTrue(any("from_peer_id must match" in error for error in validate_rollup(report)))

    def test_rejects_missing_generation_rejection(self):
        report = _rollup()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("stale_request_sequence" in error for error in validate_rollup(report)))

    def test_rejects_client_mutation_and_client_cleanup(self):
        report = copy.deepcopy(_rollup())
        report["audit"]["client_can_mutate_ledger"] = True
        report["cleanup"]["client_invoked"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("client_can_mutate_ledger" in error for error in errors))
        self.assertTrue(any("client_invoked" in error for error in errors))

    def test_rejects_live_or_native_claim(self):
        report = _rollup()
        report["native_claims"] = True
        report["uses_live_network"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
