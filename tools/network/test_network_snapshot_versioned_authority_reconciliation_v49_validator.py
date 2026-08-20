import copy
import hashlib
import unittest

try:
    from .network_snapshot_versioned_authority_reconciliation_v49_validator import validate_versioned
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_versioned_authority_reconciliation_v49_validator import validate_versioned


def _record(order, record_id, digest):
    record = {"order": order, "record_id": record_id, "authority": "server", "version": 1, "expected_digest": digest, "observed_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
    record["reconciliation_digest"] = hashlib.sha256(f"server|1|{record_id}|{digest}|{digest}".encode()).hexdigest()
    return record


def _versioned() -> dict:
    records = [_record(1, "ship-a", hashlib.sha256(b"a").hexdigest()), _record(2, "ship-b", hashlib.sha256(b"b").hexdigest())]
    state = {"authority": "server", "version": 1, "sequence": 410, "digest": hashlib.sha256(b"snapshot").hexdigest()}
    return {
        "schema_version": 49,
        "evidence_scope": "network_snapshot_versioned_authority_reconciliation_v49",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "snapshot_version": 1,
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "before": state,
        "after": dict(state),
        "records": records,
        "aggregate_digest": hashlib.sha256("\n".join(f"{record['order']}|{record['record_id']}|{record['reconciliation_digest']}" for record in records).encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotVersionedAuthorityReconciliationV49ValidatorTest(unittest.TestCase):
    def test_accepts_versioned_reconciliation(self):
        self.assertEqual(validate_versioned(_versioned()), [])

    def test_rejects_snapshot_version(self):
        report = _versioned()
        report["records"][0]["version"] = 2
        self.assertTrue(any("bind snapshot version" in error for error in validate_versioned(report)))

    def test_rejects_changed_after_state(self):
        report = _versioned()
        report["after"]["sequence"] = 411
        self.assertTrue(any("preserve before" in error for error in validate_versioned(report)))

    def test_rejects_aggregate_digest(self):
        report = _versioned()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match versioned records" in error for error in validate_versioned(report)))

    def test_rejects_mutation_and_count(self):
        report = _versioned()
        report["records"][0]["state_changed"] = True
        errors = validate_versioned(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_versioned())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_versioned(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
