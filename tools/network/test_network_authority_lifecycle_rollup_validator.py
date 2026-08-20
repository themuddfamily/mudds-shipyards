import copy
import unittest

try:
    from .network_authority_lifecycle_rollup_validator import validate_rollup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_authority_lifecycle_rollup_validator import validate_rollup


def _rollup() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_authority_interest_lifecycle",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "fixture_id": "network-lifecycle-fixture-01",
        "authority_peer_id": 99,
        "phases": [
            {
                "name": "admit",
                "policy_version": "network_session_handshake_v1",
                "accepted": True,
                "server_authority": True,
                "event_sequence": 1,
                "source": "server",
            },
            {
                "name": "bind",
                "policy_version": "network_disconnect_lifecycle_v1",
                "accepted": True,
                "server_authority": True,
                "event_sequence": 2,
                "source": "server_adapter",
            },
            {
                "name": "interest",
                "policy_version": "network_replication_interest_authority_v1",
                "accepted": True,
                "server_authority": True,
                "event_sequence": 3,
                "source": "server_adapter",
            },
            {
                "name": "replicate",
                "policy_version": "network_replication_interest_authority_v1",
                "accepted": True,
                "server_authority": True,
                "event_sequence": 4,
                "source": "server_adapter",
            },
            {
                "name": "correct",
                "policy_version": "network_prediction_correction_guard_v1",
                "accepted": True,
                "server_authority": True,
                "event_sequence": 5,
                "source": "server_adapter",
                "client_can_mutate_state": False,
            },
            {
                "name": "cleanup",
                "policy_version": "network_disconnect_lifecycle_v1",
                "accepted": True,
                "server_authority": True,
                "event_sequence": 6,
                "source": "server",
                "active_after": False,
            },
        ],
    }


class NetworkAuthorityLifecycleRollupValidatorTest(unittest.TestCase):
    def test_valid_rollup_covers_ordered_server_owned_slice(self):
        self.assertEqual(validate_rollup(_rollup()), [])

    def test_rejects_phase_reordering(self):
        report = _rollup()
        report["phases"][1], report["phases"][2] = report["phases"][2], report["phases"][1]
        self.assertTrue(any("required order" in error for error in validate_rollup(report)))

    def test_rejects_policy_substitution_and_client_authority(self):
        report = _rollup()
        report["phases"][2]["policy_version"] = "synthetic_interest_v1"
        report["phases"][2]["server_authority"] = False
        errors = validate_rollup(report)
        self.assertTrue(any("policy_version" in error for error in errors))
        self.assertTrue(any("server_authority" in error for error in errors))

    def test_rejects_native_claims_and_mutable_correction(self):
        report = copy.deepcopy(_rollup())
        report["native_claims"] = True
        report["phases"][4]["client_can_mutate_state"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("client_can_mutate_state" in error for error in errors))

    def test_rejects_replayed_event_sequence(self):
        report = _rollup()
        report["phases"][5]["event_sequence"] = report["phases"][4]["event_sequence"]
        self.assertTrue(any("strictly increasing" in error for error in validate_rollup(report)))

    def test_rejects_active_cleanup(self):
        report = _rollup()
        report["phases"][5]["active_after"] = True
        self.assertTrue(any("active_after" in error for error in validate_rollup(report)))


if __name__ == "__main__":
    unittest.main()
