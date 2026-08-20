import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_reconciliation_authority_v26_validator import validate_reconciliation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_reconciliation_authority_v26_validator import validate_reconciliation


def _pair(pair_id, digest):
    pair = {"order": int(pair_id[-1]), "pair_id": pair_id, "authority": "server", "expected_digest": digest, "reconciled_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
    pair["pair_digest"] = hashlib.sha256(f"server|{pair_id}|{digest}|{digest}".encode()).hexdigest()
    return pair


def _reconciliation() -> dict:
    digest_a = hashlib.sha256(b"a").hexdigest()
    digest_b = hashlib.sha256(b"b").hexdigest()
    state = {"authority": "server", "sequence": 220, "digest": hashlib.sha256(b"snapshot").hexdigest()}
    return {
        "schema_version": 26,
        "evidence_scope": "network_snapshot_digest_reconciliation_authority_v26",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "source_state": state,
        "reconciled_state": dict(state),
        "pairs": [_pair("pair-1", digest_a), _pair("pair-2", digest_b)],
        "counts": {"pairs": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotDigestReconciliationAuthorityV26ValidatorTest(unittest.TestCase):
    def test_accepts_digest_pairs(self):
        self.assertEqual(validate_reconciliation(_reconciliation()), [])

    def test_rejects_changed_reconciled_state(self):
        report = _reconciliation()
        report["reconciled_state"]["sequence"] = 221
        self.assertTrue(any("must equal source" in error for error in validate_reconciliation(report)))

    def test_rejects_digest_pair_mismatch(self):
        report = _reconciliation()
        report["pairs"][0]["reconciled_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("must match expected" in error for error in validate_reconciliation(report)))

    def test_rejects_pair_digest(self):
        report = _reconciliation()
        report["pairs"][0]["pair_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind digest pair" in error for error in validate_reconciliation(report)))

    def test_rejects_mutation_and_count(self):
        report = _reconciliation()
        report["pairs"][0]["state_changed"] = True
        errors = validate_reconciliation(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_reconciliation())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_reconciliation(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
