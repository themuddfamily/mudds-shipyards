import copy
import hashlib
import unittest

try:
    from .network_visible_deferred_snapshot_digest_guard_validator import validate_guard
except ImportError:  # Direct invocation from the tools/network directory.
    from network_visible_deferred_snapshot_digest_guard_validator import validate_guard


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _guard() -> dict:
    first = _digest("partition-a")
    second = _digest("partition-b")
    return {
        "schema_version": 1,
        "evidence_scope": "network_visible_deferred_snapshot_digest_guard",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer_id": 7,
        "snapshots": [
            {"server_tick": 10, "partition_digest": first, "previous_digest": None, "partition_changed": True, "accepted": True, "server_committed": True},
            {"server_tick": 11, "partition_digest": first, "previous_digest": first, "partition_changed": False, "accepted": True, "server_committed": True},
            {"server_tick": 12, "partition_digest": second, "previous_digest": first, "partition_changed": True, "accepted": True, "server_committed": True},
        ],
        "stale_replays": [
            {"replayed_digest": first, "current_digest": second, "accepted": False, "status": "stale_snapshot_digest", "server_rejected": True, "state_changed": False}
        ],
        "snapshot_detached": True,
    }


class NetworkVisibleDeferredSnapshotDigestGuardValidatorTest(unittest.TestCase):
    def test_accepts_continuous_changed_and_unchanged_digests(self):
        self.assertEqual(validate_guard(_guard()), [])

    def test_rejects_changed_snapshot_without_digest_advance(self):
        report = _guard()
        report["snapshots"][2]["partition_digest"] = report["snapshots"][1]["partition_digest"]
        self.assertTrue(any("changed partition must advance" in error for error in validate_guard(report)))

    def test_rejects_unchanged_snapshot_with_new_digest(self):
        report = _guard()
        report["snapshots"][1]["partition_digest"] = _digest("wrong")
        self.assertTrue(any("unchanged partition must retain" in error for error in validate_guard(report)))

    def test_rejects_bad_tick_or_previous_digest(self):
        report = copy.deepcopy(_guard())
        report["snapshots"][1]["server_tick"] = 10
        report["snapshots"][2]["previous_digest"] = "0" * 64
        errors = validate_guard(report)
        self.assertTrue(any("strictly increasing" in error for error in errors))
        self.assertTrue(any("prior digest" in error for error in errors))

    def test_rejects_stale_replay_state_mutation(self):
        report = _guard()
        report["stale_replays"][0]["state_changed"] = True
        self.assertTrue(any("without state change" in error for error in validate_guard(report)))

    def test_rejects_client_or_live_claim(self):
        report = _guard()
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_guard(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
