import copy
import unittest

try:
    from .network_migration_handoff_validator import validate_handoff
except ImportError:  # Direct invocation from the tools/network directory.
    from network_migration_handoff_validator import validate_handoff


def _handoff() -> dict:
    rejection_statuses = [
        "stale_package_generation", "stale_session_generation",
        "stale_migration_generation", "spoofed_peer", "stale_packet_sequence",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_migration_handoff",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_session_migration_v1",
        "native_claims": False,
        "uses_live_sessions": False,
        "peer_id": 7,
        "peer_generation_before": 5,
        "initial_epoch": {"package_generation": 12, "session_generation": 3, "migration_generation": 1},
        "rotated_epoch": {"package_generation": 13, "session_generation": 4, "migration_generation": 2},
        "audit": {
            "server_owns_rotation": True,
            "server_owns_package_generation": True,
            "server_owns_session_generation": True,
            "server_owns_attachment_rebind": True,
            "stale_packets_rejected": True,
            "client_can_mutate_attachment": False,
        },
        "rotation": {
            "accepted": True, "status": "server_rotated", "server_authority": True,
            "rebind_required": True, "package_generation": 13, "session_generation": 4,
            "migration_generation": 2,
        },
        "attachment": {
            "seat": {"seat_id": "gunner", "seat_generation": 9},
            "ship": {"ship_id": "ship_b", "ship_generation": 12},
            "interest": {"center": [9, 1, -4], "radius": 80, "max_entities": 3},
        },
        "rebind": {
            "accepted": True, "status": "peer_rebound", "peer_generation": 6,
            "server_authority": True, "attachments_restored": True,
            "client_can_mutate_attachment": False,
        },
        "accepted_packet": {
            "accepted": True, "status": "packet_accepted", "packet_sequence": 1,
            "server_authority": True,
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkMigrationHandoffValidatorTest(unittest.TestCase):
    def test_accepts_current_epoch_attachment_rebind(self):
        self.assertEqual(validate_handoff(_handoff()), [])

    def test_rejects_epoch_rollback(self):
        report = _handoff()
        report["rotated_epoch"]["migration_generation"] = 1
        self.assertTrue(any("must advance" in error for error in validate_handoff(report)))

    def test_rejects_rotation_receipt_mismatch(self):
        report = _handoff()
        report["rotation"]["session_generation"] = 3
        self.assertTrue(any("rotation.session_generation" in error for error in validate_handoff(report)))

    def test_rejects_old_rebind_generation(self):
        report = _handoff()
        report["rebind"]["peer_generation"] = 5
        self.assertTrue(any("peer_generation must advance" in error for error in validate_handoff(report)))

    def test_rejects_missing_stale_packet_fence(self):
        report = _handoff()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("stale_packet_sequence" in error for error in validate_handoff(report)))

    def test_rejects_client_mutation_and_live_claims(self):
        report = copy.deepcopy(_handoff())
        report["audit"]["client_can_mutate_attachment"] = True
        report["uses_live_sessions"] = True
        errors = validate_handoff(report)
        self.assertTrue(any("client_can_mutate_attachment" in error for error in errors))
        self.assertTrue(any("uses_live_sessions" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
