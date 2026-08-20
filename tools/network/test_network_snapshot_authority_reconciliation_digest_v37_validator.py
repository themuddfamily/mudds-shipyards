import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_reconciliation_digest_v37_validator import validate_reconciliation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_authority_reconciliation_digest_v37_validator import validate_reconciliation


def _reconciliation() -> dict:
    records = []
    for order, check_id, payload in ((1, "ship-a", b"a"), (2, "ship-b", b"b")):
        digest = hashlib.sha256(payload).hexdigest()
        record = {"order": order, "check_id": check_id, "authority": "server", "sequence": 330, "expected_digest": digest, "observed_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
        record["authority_digest"] = hashlib.sha256(f"server|{check_id}|330|{digest}".encode()).hexdigest()
        records.append(record)
    return {
        "schema_version": 37,
        "evidence_scope": "network_snapshot_authority_reconciliation_digest_v37",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "before": {"authority": "server", "sequence": 330, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "after": {"authority": "server", "sequence": 330, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "records": records,
        "reconciliation_digest": hashlib.sha256("\n".join(f"{record['order']}|{record['check_id']}|{record['authority_digest']}|{record['observed_digest']}" for record in records).encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityReconciliationDigestV37ValidatorTest(unittest.TestCase):
    def test_accepts_authority_reconciliation(self):
        self.assertEqual(validate_reconciliation(_reconciliation()), [])

    def test_rejects_authority_check_digest(self):
        report = _reconciliation()
        report["records"][0]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind authority check" in error for error in validate_reconciliation(report)))

    def test_rejects_observed_digest(self):
        report = _reconciliation()
        report["records"][0]["observed_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("observed_digest must match" in error for error in validate_reconciliation(report)))

    def test_rejects_reconciliation_digest(self):
        report = _reconciliation()
        report["reconciliation_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match ordered authority" in error for error in validate_reconciliation(report)))

    def test_rejects_mutation_and_count(self):
        report = _reconciliation()
        report["records"][0]["state_changed"] = True
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
