import copy
import unittest

try:
    from .network_session_migration_cleanup_validator import validate_cleanup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_session_migration_cleanup_validator import validate_cleanup


def _cleanup() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_session_migration_cleanup",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_session_migration_v1",
        "native_claims": False,
        "uses_live_sessions": False,
        "audit": {
            "server_owns_rotation": True,
            "server_owns_attachment_rebind": True,
            "stale_packets_rejected": True,
            "client_can_mutate_attachment": False,
        },
        "pre_rotation_peer_ids": [7, 8],
        "rotation": {
            "accepted": True,
            "status": "server_rotated",
            "server_authority": True,
            "released_peer_ids": [7, 8],
        },
        "post_rotation": {
            "active_peer_ids": [],
            "pending_rebind_peer_ids": [7, 8],
            "attachments_retained": True,
            "old_transports_detached": True,
        },
        "rebind": {
            "accepted": True,
            "status": "peer_rebound",
            "peer_id": 7,
            "peer_generation_before": 1,
            "peer_generation_after": 2,
            "attachments_restored": True,
            "server_authority": True,
        },
        "post_rebind": {
            "active_peer_ids": [7],
            "pending_rebind_peer_ids": [8],
            "no_orphan_active_peers": True,
        },
        "stale_packet_cleanup": {
            "accepted": False,
            "status": "stale_peer_generation",
            "server_rejected": True,
            "altered_attachment": False,
        },
    }


class NetworkSessionMigrationCleanupValidatorTest(unittest.TestCase):
    def test_accepts_rotation_release_rebind_cleanup(self):
        self.assertEqual(validate_cleanup(_cleanup()), [])

    def test_rejects_partial_rotation_release_set(self):
        report = _cleanup()
        report["rotation"]["released_peer_ids"] = [7]
        self.assertTrue(any("exactly match" in error for error in validate_cleanup(report)))

    def test_rejects_active_peer_left_after_rotation(self):
        report = _cleanup()
        report["post_rotation"]["active_peer_ids"] = [8]
        self.assertTrue(any("must be empty" in error for error in validate_cleanup(report)))

    def test_rejects_rebind_without_generation_advance(self):
        report = _cleanup()
        report["rebind"]["peer_generation_after"] = 1
        self.assertTrue(any("generation must advance" in error for error in validate_cleanup(report)))

    def test_rejects_orphan_or_retained_pending_peer(self):
        report = copy.deepcopy(_cleanup())
        report["post_rebind"]["pending_rebind_peer_ids"] = [7, 8]
        report["post_rebind"]["no_orphan_active_peers"] = False
        errors = validate_cleanup(report)
        self.assertTrue(any("must remove the rebound peer" in error for error in errors))
        self.assertTrue(any("no_orphan_active_peers" in error for error in errors))

    def test_rejects_stale_packet_that_mutates_attachment(self):
        report = _cleanup()
        report["stale_packet_cleanup"]["altered_attachment"] = True
        self.assertTrue(any("altered_attachment" in error for error in validate_cleanup(report)))


if __name__ == "__main__":
    unittest.main()
