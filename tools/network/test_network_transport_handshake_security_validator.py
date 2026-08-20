import copy
import unittest

try:
    from .network_transport_handshake_security_validator import validate_rollup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_transport_handshake_security_validator import validate_rollup


def _rollup() -> dict:
    rejection_statuses = [
        "protocol_mismatch",
        "spoofed_peer",
        "stale_session_generation",
        "replayed_or_out_of_order",
        "invalid_auth_token",
        "packet_too_large",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_transport_handshake_security",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "uses_live_network": False,
        "contains_secret_material": False,
        "handshake_policy": "network_session_handshake_v1",
        "transport_policy": "network_transport_security_v1",
        "audit": {
            "server_owns_token_generation": True,
            "server_owns_replay_cursor": True,
            "exact_packet_schema": True,
            "bounded_packet_bytes": True,
            "forged_source_rejected": True,
            "stale_generation_rejected": True,
            "server_owns_peer_admission": True,
            "client_can_mutate_session": False,
        },
        "server_offer": {
            "schema_version": 1,
            "protocol_id": "mudds_shipyards",
            "protocol_version": 4,
            "package_generation": 12,
            "session_generation": 3,
        },
        "accepted_hello": {
            "accepted": True,
            "status": "accepted",
            "source_peer_id": 7,
            "peer_id": 7,
            "peer_generation": 1,
            "server_authority": True,
        },
        "accepted_packet": {
            "accepted": True,
            "status": "packet_accepted",
            "source_peer_id": 7,
            "peer_id": 7,
            "sequence": 0,
            "server_authority": True,
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkTransportHandshakeSecurityValidatorTest(unittest.TestCase):
    def test_accepts_complete_security_rollup(self):
        self.assertEqual(validate_rollup(_rollup()), [])

    def test_rejects_missing_security_receipt(self):
        report = _rollup()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("packet_too_large" in error for error in validate_rollup(report)))

    def test_rejects_source_spoof_in_accepted_paths(self):
        report = _rollup()
        report["accepted_packet"]["source_peer_id"] = 8
        self.assertTrue(any("source_peer_id must match" in error for error in validate_rollup(report)))

    def test_rejects_client_authority_and_secret_material(self):
        report = copy.deepcopy(_rollup())
        report["audit"]["client_can_mutate_session"] = True
        report["contains_secret_material"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("client_can_mutate_session" in error for error in errors))
        self.assertTrue(any("contains_secret_material" in error for error in errors))

    def test_rejects_unserver_rejected_receipt(self):
        report = _rollup()
        report["rejections"][0]["server_rejected"] = False
        self.assertTrue(any("server_rejected" in error for error in validate_rollup(report)))

    def test_rejects_live_or_native_claim(self):
        report = _rollup()
        report["native_claims"] = True
        report["uses_live_network"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
