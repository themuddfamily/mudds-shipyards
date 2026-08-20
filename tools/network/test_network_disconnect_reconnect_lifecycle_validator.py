import copy
import unittest

try:
    from .network_disconnect_reconnect_lifecycle_validator import validate_lifecycle
except ImportError:  # Direct invocation from the tools/network directory.
    from network_disconnect_reconnect_lifecycle_validator import validate_lifecycle


def _lifecycle() -> dict:
    rejection_statuses = ["unauthorized_source", "stale_peer_generation", "stale_session_generation"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_disconnect_reconnect_lifecycle",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_disconnect_lifecycle_v1",
        "native_claims": False,
        "uses_live_sessions": False,
        "audit": {
            "server_owns_disconnect_cleanup": True,
            "server_owns_session_rotation": True,
            "server_owns_interest_cleanup": True,
            "stale_rejoins_rejected": True,
            "client_can_mutate_lifecycle": False,
        },
        "peer": {"peer_id": 7, "generation_before": 1, "generation_after": 2},
        "initial_state": {"active": True, "seat_attached": True, "ship_attached": True, "interest_attached": True},
        "disconnect": {
            "accepted": True, "status": "disconnected", "source_peer_id": 99,
            "authority_peer_id": 99, "peer_generation": 1, "peer_removed": True,
            "seat_cleanup": True, "ship_cleanup": True, "interest_removed": True, "active_after": False,
        },
        "reconnect": {
            "accepted": True, "status": "admitted", "source_peer_id": 7, "peer_id": 7,
            "peer_generation": 2, "attachments_restored": True, "server_committed": True,
            "client_can_mutate_lifecycle": False,
        },
        "final_state": {"active": True, "peer_generation": 2, "seat_attached": True, "ship_attached": True, "interest_attached": True},
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkDisconnectReconnectLifecycleValidatorTest(unittest.TestCase):
    def test_accepts_server_cleanup_and_new_generation_reconnect(self):
        self.assertEqual(validate_lifecycle(_lifecycle()), [])

    def test_rejects_partial_disconnect_cleanup(self):
        report = _lifecycle()
        report["disconnect"]["interest_removed"] = False
        self.assertTrue(any("interest_removed" in error for error in validate_lifecycle(report)))

    def test_rejects_reconnect_with_old_generation(self):
        report = _lifecycle()
        report["reconnect"]["peer_generation"] = 1
        self.assertTrue(any("newer generation" in error for error in validate_lifecycle(report)))

    def test_rejects_active_state_after_disconnect(self):
        report = _lifecycle()
        report["disconnect"]["active_after"] = True
        self.assertTrue(any("active_after" in error for error in validate_lifecycle(report)))

    def test_rejects_missing_stale_rejoin_fence(self):
        report = _lifecycle()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("stale_session_generation" in error for error in validate_lifecycle(report)))

    def test_rejects_client_lifecycle_mutation(self):
        report = copy.deepcopy(_lifecycle())
        report["reconnect"]["client_can_mutate_lifecycle"] = True
        report["audit"]["client_can_mutate_lifecycle"] = True
        errors = validate_lifecycle(report)
        self.assertTrue(any("client_can_mutate_lifecycle" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
