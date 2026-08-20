import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_digest_rollup_no_mutation_v6_validator import validate_rollup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_authority_digest_rollup_no_mutation_v6_validator import validate_rollup


def _event(order, decision, sequence, digest, accepted, after_sequence, after_digest):
    return {
        "authority": "server",
        "order": order,
        "decision": decision,
        "sequence": sequence,
        "digest": digest,
        "accepted": accepted,
        "after": {"sequence": after_sequence, "digest": after_digest},
        "mutation_fields": [],
        "state_changed": False,
    }


def _rollup() -> dict:
    initial = hashlib.sha256(b"initial").hexdigest()
    accepted = hashlib.sha256(b"accepted").hexdigest()
    final = hashlib.sha256(b"final").hexdigest()
    stale = hashlib.sha256(b"stale").hexdigest()
    return {
        "schema_version": 6,
        "evidence_scope": "network_snapshot_authority_digest_rollup_no_mutation_v6",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "initial": {"sequence": 20, "digest": initial},
        "events": [
            _event(1, "accepted", 21, accepted, True, 21, accepted),
            _event(2, "rejected_digest", 21, stale, False, 21, accepted),
            _event(3, "rejected_sequence", 20, initial, False, 21, accepted),
            _event(4, "accepted", 22, final, True, 22, final),
        ],
        "final": {"sequence": 22, "digest": final},
        "counts": {"events": 4, "accepted": 2, "rejected_digest": 1, "rejected_sequence": 1, "rejected": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityDigestRollupNoMutationV6ValidatorTest(unittest.TestCase):
    def test_accepts_authority_rollup(self):
        self.assertEqual(validate_rollup(_rollup()), [])

    def test_rejects_event_order(self):
        report = _rollup()
        report["events"][1]["order"] = 3
        self.assertTrue(any("order" in error for error in validate_rollup(report)))

    def test_rejects_wrong_authority(self):
        report = _rollup()
        report["events"][0]["authority"] = "client"
        self.assertTrue(any("authority" in error for error in validate_rollup(report)))

    def test_rejects_nonadvancing_accept(self):
        report = _rollup()
        report["events"][3]["sequence"] = 21
        self.assertTrue(any("advance once" in error for error in validate_rollup(report)))

    def test_rejects_mutation_and_count(self):
        report = _rollup()
        report["events"][0]["state_changed"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_rollup())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
