import copy
import unittest

try:
    from .network_transport_replay_generation_validator import validate_ledger
except ImportError:  # Direct invocation from the tools/network directory.
    from network_transport_replay_generation_validator import validate_ledger


def _ledger() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_transport_replay_generation",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_transport_security_v1",
        "native_claims": False,
        "uses_live_network": False,
        "contains_auth_secret": False,
        "audit": {
            "server_owns_token_generation": True,
            "server_owns_replay_cursor": True,
            "stale_generation_rejected": True,
            "client_can_mutate_replay_cursor": False,
        },
        "peer": {"peer_id": 7, "generation_before": 1, "generation_after": 2},
        "streams": [
            {"stream_id": "movement", "accepted_sequences": [0, 1, 4], "high_water_mark": 4, "server_owns_cursor": True},
            {"stream_id": "command", "accepted_sequences": [0, 2], "high_water_mark": 2, "server_owns_cursor": True},
        ],
        "replay_rejections": [
            {"stream_id": "movement", "attempted_sequence": 4, "accepted": False, "status": "replayed_or_out_of_order", "server_rejected": True},
            {"stream_id": "command", "attempted_sequence": 1, "accepted": False, "status": "replayed_or_out_of_order", "server_rejected": True},
        ],
        "token_rotation": {
            "token_generation_before": 1, "token_generation_after": 2,
            "token_changed": True, "stream_cursors_reset": True,
            "server_committed": True, "contains_token_material": False,
        },
        "generation_fence": {
            "old_generation_packet": {"accepted": False, "status": "stale_peer_generation", "source_peer_id": 7, "packet_peer_id": 7},
            "new_generation_packet": {"accepted": True, "status": "packet_accepted", "source_peer_id": 7, "packet_peer_id": 7},
            "stale_packet_altered_cursor": False,
        },
    }


class NetworkTransportReplayGenerationValidatorTest(unittest.TestCase):
    def test_accepts_monotonic_stream_and_generation_fence(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_rejects_nonmonotonic_stream_cursor(self):
        report = _ledger()
        report["streams"][0]["accepted_sequences"] = [0, 4, 1]
        self.assertTrue(any("strictly increasing" in error for error in validate_ledger(report)))

    def test_rejects_replay_ahead_of_high_water_mark(self):
        report = _ledger()
        report["replay_rejections"][0]["attempted_sequence"] = 5
        self.assertTrue(any("must not exceed" in error for error in validate_ledger(report)))

    def test_rejects_token_rotation_without_cursor_reset(self):
        report = _ledger()
        report["token_rotation"]["stream_cursors_reset"] = False
        self.assertTrue(any("stream_cursors_reset" in error for error in validate_ledger(report)))

    def test_rejects_stale_packet_cursor_mutation(self):
        report = copy.deepcopy(_ledger())
        report["generation_fence"]["stale_packet_altered_cursor"] = True
        self.assertTrue(any("altered_cursor" in error for error in validate_ledger(report)))

    def test_rejects_secret_or_client_cursor_claim(self):
        report = _ledger()
        report["contains_auth_secret"] = True
        report["audit"]["client_can_mutate_replay_cursor"] = True
        errors = validate_ledger(report)
        self.assertTrue(any("contains_auth_secret" in error for error in errors))
        self.assertTrue(any("client_can_mutate_replay_cursor" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
