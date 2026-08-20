import copy
import unittest

try:
    from .network_packet_schema_size_audit_validator import validate_audit
except ImportError:  # Direct invocation from the tools/network directory.
    from network_packet_schema_size_audit_validator import validate_audit


def _audit() -> dict:
    rejection_statuses = [
        "invalid_packet_schema", "packet_too_large", "payload_too_large",
        "invalid_stream_id", "invalid_sequence",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_packet_schema_size_audit",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_transport_security_v1",
        "native_claims": False,
        "uses_live_network": False,
        "contains_auth_secret": False,
        "limits": {
            "max_packet_bytes": 1024,
            "max_payload_bytes": 768,
            "max_stream_id_length": 64,
            "auth_token_bytes": 32,
        },
        "accepted_packets": [
            {
                "accepted": True,
                "status": "packet_accepted",
                "keys": [
                    "schema_version", "protocol_id", "session_generation", "peer_id",
                    "peer_generation", "stream_id", "sequence", "auth_token", "payload",
                ],
                "schema_version": 1,
                "protocol_id": "mudds_shipyards",
                "session_generation": 7,
                "peer_id": 7,
                "peer_generation": 1,
                "stream_id": "movement",
                "sequence": 0,
                "encoded_bytes": 300,
                "payload_bytes": 100,
                "auth_token_hex_chars": 64,
                "server_validated": True,
            }
        ],
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkPacketSchemaSizeAuditValidatorTest(unittest.TestCase):
    def test_accepts_exact_bounded_packet_fixture(self):
        self.assertEqual(validate_audit(_audit()), [])

    def test_rejects_unknown_schema_key(self):
        report = _audit()
        report["accepted_packets"][0]["keys"][-1] = "unexpected"
        self.assertTrue(any("exact packet schema" in error for error in validate_audit(report)))

    def test_rejects_packet_and_payload_overflow(self):
        report = _audit()
        report["accepted_packets"][0]["encoded_bytes"] = 1025
        report["accepted_packets"][0]["payload_bytes"] = 769
        errors = validate_audit(report)
        self.assertTrue(any("max_packet_bytes" in error for error in errors))
        self.assertTrue(any("max_payload_bytes" in error for error in errors))

    def test_rejects_stream_and_token_bounds(self):
        report = _audit()
        report["accepted_packets"][0]["stream_id"] = "x" * 65
        report["accepted_packets"][0]["auth_token_hex_chars"] = 62
        errors = validate_audit(report)
        self.assertTrue(any("max_stream_id_length" in error for error in errors))
        self.assertTrue(any("auth_token_hex_chars" in error for error in errors))

    def test_rejects_missing_malformed_packet_receipt(self):
        report = copy.deepcopy(_audit())
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("invalid_sequence" in error for error in validate_audit(report)))

    def test_rejects_secret_or_live_claim(self):
        report = _audit()
        report["contains_auth_secret"] = True
        report["uses_live_network"] = True
        errors = validate_audit(report)
        self.assertTrue(any("contains_auth_secret" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
