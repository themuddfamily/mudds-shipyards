import copy
import unittest

try:
    from .network_seat_ship_transfer_generation_validator import validate_transfer
except ImportError:  # Direct invocation from the tools/network directory.
    from network_seat_ship_transfer_generation_validator import validate_transfer


def _transfer() -> dict:
    rejection_statuses = ["stale_seat_generation", "stale_request_sequence", "owner_mismatch", "unauthorized_source"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_seat_ship_transfer_generation",
        "evidence_mode": "detached_contract_fixture",
        "seat_policy": "network_seat_role_authority_v1",
        "ship_policy": "network_ship_ownership_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "audit": {
            "server_owns_seat_reservation": True,
            "server_owns_role_assignment": True,
            "server_owns_ship_transfers": True,
            "server_owns_ship_generations": True,
            "client_can_mutate_ledger": False,
            "client_can_mutate_ownership": False,
        },
        "seat": {
            "seat_id": "jovian_pilot", "role": "pilot", "old_avatar_id": "avatar_a",
            "new_avatar_id": "avatar_b", "seat_generation": 4, "release_sequence": 2,
            "claim_sequence": 3,
            "release": {"accepted": True, "status": "released", "server_committed": True, "seat_generation": 4, "avatar_id": "avatar_a"},
            "claim": {"accepted": True, "status": "claimed", "server_committed": True, "seat_generation": 4, "avatar_id": "avatar_b", "role": "pilot"},
        },
        "ship": {
            "ship_id": "jovian_a", "ship_generation": 7, "from_peer_id": 7, "to_peer_id": 8,
            "ownership_generation_before": 1, "ownership_generation_after": 2,
            "request_sequence_before": 4, "request_sequence_after": 5,
            "transfer": {"accepted": True, "status": "transferred", "server_committed": True, "ship_generation": 7, "from_peer_id": 7, "to_peer_id": 8},
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkSeatShipTransferGenerationValidatorTest(unittest.TestCase):
    def test_accepts_generation_fenced_seat_and_ship_transfer(self):
        self.assertEqual(validate_transfer(_transfer()), [])

    def test_rejects_seat_generation_change_during_transfer(self):
        report = _transfer()
        report["seat"]["claim"]["seat_generation"] = 5
        self.assertTrue(any("preserve generation" in error for error in validate_transfer(report)))

    def test_rejects_ship_generation_change_during_transfer(self):
        report = _transfer()
        report["ship"]["transfer"]["ship_generation"] = 8
        self.assertTrue(any("lifecycle generation" in error for error in validate_transfer(report)))

    def test_rejects_nonadvancing_ownership_generation(self):
        report = _transfer()
        report["ship"]["ownership_generation_after"] = 1
        self.assertTrue(any("advance exactly once" in error for error in validate_transfer(report)))

    def test_rejects_missing_stale_owner_fence(self):
        report = _transfer()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("unauthorized_source" in error for error in validate_transfer(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = copy.deepcopy(_transfer())
        report["audit"]["client_can_mutate_ownership"] = True
        report["uses_live_network"] = True
        errors = validate_transfer(report)
        self.assertTrue(any("client_can_mutate_ownership" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
