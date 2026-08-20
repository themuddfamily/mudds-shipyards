import copy
import unittest

try:
    from .network_server_browser_admission_validator import validate_evidence
except ImportError:  # Direct invocation from the tools/network directory.
    from network_server_browser_admission_validator import validate_evidence


def _evidence() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_server_browser_session_admission",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "browser_audit": {
            "policy_version": "network_server_browser_v1",
            "directory_owns_records": True,
            "client_can_mutate_records": False,
            "browser_owns_join_authority": False,
            "uses_live_sockets": False,
        },
        "snapshot": {
            "directory_generation": 4,
            "server_tick": 120,
            "last_seen_tick": 118,
            "stale_after_ticks": 3,
        },
        "admission": {
            "policy_version": "network_session_handshake_v1",
            "accepted": True,
            "server_authority": True,
            "browser_grants_authority": False,
            "client_can_mutate_authority": False,
            "source": "server_adapter",
            "session_id": "cinder_run",
            "host_peer_id": 7,
        },
    }


class NetworkServerBrowserAdmissionValidatorTest(unittest.TestCase):
    def test_accepts_fresh_directory_entry_forwarded_to_server(self):
        self.assertEqual(validate_evidence(_evidence()), [])

    def test_rejects_browser_as_join_authority(self):
        report = _evidence()
        report["browser_audit"]["browser_owns_join_authority"] = True
        report["admission"]["browser_grants_authority"] = True
        errors = validate_evidence(report)
        self.assertTrue(any("browser_owns_join_authority" in error for error in errors))
        self.assertTrue(any("browser_grants_authority" in error for error in errors))

    def test_rejects_stale_snapshot(self):
        report = _evidence()
        report["snapshot"]["server_tick"] = 122
        report["snapshot"]["stale_after_ticks"] = 3
        self.assertTrue(any("stale" in error for error in validate_evidence(report)))

    def test_rejects_invalid_handshake_policy_or_client_mutation(self):
        report = _evidence()
        report["admission"]["policy_version"] = "network_server_browser_v1"
        report["admission"]["client_can_mutate_authority"] = True
        errors = validate_evidence(report)
        self.assertTrue(any("admission.policy_version" in error for error in errors))
        self.assertTrue(any("client_can_mutate_authority" in error for error in errors))

    def test_rejects_native_claims_and_live_sockets(self):
        report = copy.deepcopy(_evidence())
        report["native_claims"] = True
        report["browser_audit"]["uses_live_sockets"] = True
        errors = validate_evidence(report)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("uses_live_sockets" in error for error in errors))

    def test_rejects_newer_last_seen_tick(self):
        report = _evidence()
        report["snapshot"]["last_seen_tick"] = 121
        self.assertTrue(any("newer than server_tick" in error for error in validate_evidence(report)))


if __name__ == "__main__":
    unittest.main()
