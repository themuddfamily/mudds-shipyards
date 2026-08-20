import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_stale_replay_validator import validate_replays
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_stale_replay_validator import validate_replays


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _replay() -> dict:
    current_digest = _digest("current")
    statuses = ["stale_snapshot_digest", "stale_server_tick", "stale_snapshot_sequence", "stale_peer_generation"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_digest_stale_replay",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"peer_id": 7, "peer_generation": 3, "server_tick": 12, "snapshot_sequence": 8, "partition_digest": current_digest},
        "accepted_current": {"accepted": True, "status": "snapshot_accepted", "peer_id": 7, "peer_generation": 3, "server_tick": 12, "snapshot_sequence": 8, "partition_digest": current_digest, "server_committed": True, "snapshot_detached": True},
        "replays": [
            {"status": status, "accepted": False, "server_rejected": True, "state_changed": False, "current_peer_id": 7, "current_peer_generation": 3, "current_server_tick": 12, "current_snapshot_sequence": 8, "current_partition_digest": current_digest, "attempted_partition_digest": _digest("old") if status == "stale_snapshot_digest" else _digest("current"), "attempted_server_tick": 11 if status == "stale_server_tick" else 12, "attempted_snapshot_sequence": 7 if status == "stale_snapshot_sequence" else 8, "attempted_peer_generation": 2 if status == "stale_peer_generation" else 3}
            for status in statuses
        ],
    }


class NetworkSnapshotDigestStaleReplayValidatorTest(unittest.TestCase):
    def test_accepts_complete_stale_replay_ledger(self):
        self.assertEqual(validate_replays(_replay()), [])

    def test_rejects_stale_tick_at_current_tick(self):
        report = _replay()
        report["replays"][1]["attempted_server_tick"] = 12
        self.assertTrue(any("attempted_server_tick must be older" in error for error in validate_replays(report)))

    def test_rejects_stale_sequence_at_current_sequence(self):
        report = _replay()
        report["replays"][2]["attempted_snapshot_sequence"] = 8
        self.assertTrue(any("attempted_snapshot_sequence must be older" in error for error in validate_replays(report)))

    def test_rejects_replay_that_changes_state(self):
        report = _replay()
        report["replays"][0]["state_changed"] = True
        self.assertTrue(any("state_changed" in error for error in validate_replays(report)))

    def test_rejects_missing_stale_status(self):
        report = _replay()
        report["replays"] = report["replays"][:-1]
        self.assertTrue(any("stale_peer_generation" in error for error in validate_replays(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_replay())
        report["uses_live_network"] = True
        report["accepted_current"]["snapshot_detached"] = False
        errors = validate_replays(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
