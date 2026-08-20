import copy
import hashlib
import unittest

try:
    from .network_snapshot_paired_digest_reconciliation_authority_v27_validator import validate_pairs
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_paired_digest_reconciliation_authority_v27_validator import validate_pairs


def _pair(order, pair_id, digest):
    pair = {"order": order, "pair_id": pair_id, "authority": "server", "left_digest": digest, "right_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
    pair["pair_digest"] = hashlib.sha256(f"server|{pair_id}|{digest}|{digest}".encode()).hexdigest()
    return pair


def _pairs() -> dict:
    state = {"authority": "server", "sequence": 230, "digest": hashlib.sha256(b"snapshot").hexdigest()}
    return {
        "schema_version": 27,
        "evidence_scope": "network_snapshot_paired_digest_reconciliation_authority_v27",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "left_state": state,
        "right_state": dict(state),
        "digest_pairs": [_pair(1, "pair-a", hashlib.sha256(b"a").hexdigest()), _pair(2, "pair-b", hashlib.sha256(b"b").hexdigest())],
        "counts": {"pairs": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotPairedDigestReconciliationAuthorityV27ValidatorTest(unittest.TestCase):
    def test_accepts_paired_digests(self):
        self.assertEqual(validate_pairs(_pairs()), [])

    def test_rejects_changed_right_state(self):
        report = _pairs()
        report["right_state"]["sequence"] = 231
        self.assertTrue(any("equal left" in error for error in validate_pairs(report)))

    def test_rejects_digest_pair_mismatch(self):
        report = _pairs()
        report["digest_pairs"][0]["right_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("right_digest must match" in error for error in validate_pairs(report)))

    def test_rejects_pair_digest(self):
        report = _pairs()
        report["digest_pairs"][0]["pair_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind paired digests" in error for error in validate_pairs(report)))

    def test_rejects_mutation_and_count(self):
        report = _pairs()
        report["digest_pairs"][0]["state_changed"] = True
        errors = validate_pairs(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_pairs())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_pairs(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
