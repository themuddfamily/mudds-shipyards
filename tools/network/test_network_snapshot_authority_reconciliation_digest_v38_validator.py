import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_reconciliation_digest_v38_validator import validate_checks
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_authority_reconciliation_digest_v38_validator import validate_checks


def _report() -> dict:
    snapshot = {"authority": "server", "sequence": 340, "digest": hashlib.sha256(b"snapshot").hexdigest()}
    checks = []
    for order, check_id, payload in ((1, "ship-a", b"a"), (2, "ship-b", b"b")):
        digest = hashlib.sha256(payload).hexdigest()
        check = {"order": order, "check_id": check_id, "authority": "server", "sequence": 340, "source_digest": digest, "target_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
        check["authority_check_digest"] = hashlib.sha256(f"server|{check_id}|340|{digest}|{digest}".encode()).hexdigest()
        checks.append(check)
    return {
        "schema_version": 38,
        "evidence_scope": "network_snapshot_authority_reconciliation_digest_v38",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": snapshot,
        "reconciled": dict(snapshot),
        "authority_checks": checks,
        "aggregate_digest": hashlib.sha256("\n".join(f"{check['order']}|{check['check_id']}|{check['authority_check_digest']}" for check in checks).encode()).hexdigest(),
        "counts": {"checks": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityReconciliationDigestV38ValidatorTest(unittest.TestCase):
    def test_accepts_authority_checks(self):
        self.assertEqual(validate_checks(_report()), [])

    def test_rejects_changed_reconciled_state(self):
        report = _report()
        report["reconciled"]["sequence"] = 341
        self.assertTrue(any("must equal snapshot" in error for error in validate_checks(report)))

    def test_rejects_authority_check_digest(self):
        report = _report()
        report["authority_checks"][0]["authority_check_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind authority check" in error for error in validate_checks(report)))

    def test_rejects_aggregate_digest(self):
        report = _report()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match authority checks" in error for error in validate_checks(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["authority_checks"][0]["state_changed"] = True
        errors = validate_checks(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_checks(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
