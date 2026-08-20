import copy
import unittest

try:
    from .network_ownership_generation_cleanup_validator import validate_ledger
except ImportError:  # Direct invocation from the tools/network directory.
    from network_ownership_generation_cleanup_validator import validate_ledger


def _ledger() -> dict:
    rejection_statuses = ["unauthorized_source", "stale_ship_generation", "stale_request_sequence", "owner_mismatch"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_ownership_generation_cleanup",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_ship_ownership_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "audit": {
            "server_owns_ship_claims": True,
            "server_owns_ship_generations": True,
            "server_owns_disconnect_cleanup": True,
            "client_can_mutate_ownership": False,
        },
        "before": {
            "ship_id": "jovian_a", "ship_generation": 3, "owner_peer_id": 7,
            "ownership_generation": 1, "last_request_sequence": 4,
        },
        "release": {
            "accepted": True, "status": "peer_released", "server_committed": True,
            "client_invoked": False, "peer_id": 7, "ship_ids": ["jovian_a"],
            "owner_after": 0, "ownership_generation_after": 2, "request_sequence_after": -1,
        },
        "retire": {
            "accepted": True, "status": "retired", "server_committed": True,
            "ship_id": "jovian_a", "ship_generation": 3, "present_after": False,
        },
        "reuse": {
            "accepted": True, "status": "registered", "server_committed": True,
            "ship_id": "jovian_a", "ship_generation": 4, "owner_peer_id": 0,
            "ownership_generation": 0,
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkOwnershipGenerationCleanupValidatorTest(unittest.TestCase):
    def test_accepts_release_retire_and_fresh_generation_reuse(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_rejects_release_without_owner_clear(self):
        report = _ledger()
        report["release"]["owner_after"] = 7
        self.assertTrue(any("owner_after" in error for error in validate_ledger(report)))

    def test_rejects_generation_reuse_rollback(self):
        report = _ledger()
        report["reuse"]["ship_generation"] = 3
        self.assertTrue(any("newer than" in error for error in validate_ledger(report)))

    def test_rejects_retired_ship_still_present(self):
        report = _ledger()
        report["retire"]["present_after"] = True
        self.assertTrue(any("present_after" in error for error in validate_ledger(report)))

    def test_rejects_missing_stale_request_fence(self):
        report = _ledger()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("owner_mismatch" in error for error in validate_ledger(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = copy.deepcopy(_ledger())
        report["audit"]["client_can_mutate_ownership"] = True
        report["uses_live_network"] = True
        errors = validate_ledger(report)
        self.assertTrue(any("client_can_mutate_ownership" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
