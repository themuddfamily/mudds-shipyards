import copy
import unittest

try:
    from .network_session_recovery_evidence_validator import validate_evidence
except ImportError:  # Direct invocation from the tools/network directory.
    from network_session_recovery_evidence_validator import validate_evidence


def _evidence() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_session_reconnect_recovery",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "uses_live_network": False,
        "lifecycle_policy": "network_disconnect_lifecycle_v1",
        "migration_policy": "network_session_migration_v1",
        "peer_id": 7,
        "peer_generation_before": 5,
        "initial_epoch": {
            "package_generation": 12,
            "session_generation": 3,
            "migration_generation": 1,
        },
        "rotated_epoch": {
            "package_generation": 13,
            "session_generation": 4,
            "migration_generation": 2,
        },
        "rotation": {
            "accepted": True,
            "status": "server_rotated",
            "server_authority": True,
            "rebind_required": True,
        },
        "stale_attempt": {
            "accepted": False,
            "rejection_statuses": ["stale_session_generation", "stale_peer_generation"],
        },
        "rebind": {
            "accepted": True,
            "status": "peer_rebound",
            "peer_generation": 6,
            "attachments_restored": True,
            "client_can_mutate_attachment": False,
        },
        "cleanup": {
            "accepted": True,
            "status": "disconnected",
            "peer_removed": True,
            "interest_removed": True,
            "attachments_released": True,
            "client_invoked": False,
        },
    }


class NetworkSessionRecoveryEvidenceValidatorTest(unittest.TestCase):
    def test_accepts_generation_fenced_rotation_rebind_cleanup(self):
        self.assertEqual(validate_evidence(_evidence()), [])

    def test_rejects_epoch_rollback(self):
        report = _evidence()
        report["rotated_epoch"]["session_generation"] = 3
        self.assertTrue(any("must advance" in error for error in validate_evidence(report)))

    def test_rejects_missing_stale_generation_fence(self):
        report = _evidence()
        report["stale_attempt"]["rejection_statuses"] = ["stale_session_generation"]
        self.assertTrue(any("stale_peer_generation" in error for error in validate_evidence(report)))

    def test_rejects_old_peer_generation_rebind(self):
        report = _evidence()
        report["rebind"]["peer_generation"] = 5
        self.assertTrue(any("peer_generation must advance" in error for error in validate_evidence(report)))

    def test_rejects_client_owned_attachment_or_cleanup(self):
        report = copy.deepcopy(_evidence())
        report["rebind"]["client_can_mutate_attachment"] = True
        report["cleanup"]["client_invoked"] = True
        errors = validate_evidence(report)
        self.assertTrue(any("client_can_mutate_attachment" in error for error in errors))
        self.assertTrue(any("client_invoked" in error for error in errors))

    def test_rejects_live_or_native_evidence_claim(self):
        report = _evidence()
        report["native_claims"] = True
        report["uses_live_network"] = True
        errors = validate_evidence(report)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
