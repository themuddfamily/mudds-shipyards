import copy
import hashlib
import unittest

try:
    from .network_snapshot_identity_reconciliation_authority_v24_validator import validate_identity
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_identity_reconciliation_authority_v24_validator import validate_identity


def _identity() -> dict:
    root_digest = hashlib.sha256(b"root").hexdigest()
    anchor = {"authority": "server", "anchor_id": "anchor-200", "sequence": 200, "digest": root_digest}
    anchor["anchor_digest"] = hashlib.sha256(f"server|anchor-200|200|{root_digest}".encode()).hexdigest()
    records = []
    for order, identity_id, payload in ((1, "ship-a", b"a"), (2, "ship-b", b"b")):
        source = hashlib.sha256(payload).hexdigest()
        records.append({"order": order, "identity_id": identity_id, "authority": "server", "anchor_digest": anchor["anchor_digest"], "sequence": 200, "source_digest": source, "resolved_digest": source, "identity_digest": hashlib.sha256(f"{anchor['anchor_digest']}|{identity_id}|{source}".encode()).hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False})
    return {
        "schema_version": 24,
        "evidence_scope": "network_snapshot_identity_reconciliation_authority_v24",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "before": {"authority": "server", "sequence": 200, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "after": {"authority": "server", "sequence": 200, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "anchor": anchor,
        "records": records,
        "counts": {"records": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotIdentityReconciliationAuthorityV24ValidatorTest(unittest.TestCase):
    def test_accepts_identity_reconciliation(self):
        self.assertEqual(validate_identity(_identity()), [])

    def test_rejects_anchor_digest(self):
        report = _identity()
        report["anchor"]["anchor_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind authority anchor" in error for error in validate_identity(report)))

    def test_rejects_resolved_digest(self):
        report = _identity()
        report["records"][0]["resolved_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("resolved_digest must match" in error for error in validate_identity(report)))

    def test_rejects_changed_after_state(self):
        report = _identity()
        report["after"]["digest"] = hashlib.sha256(b"changed").hexdigest()
        self.assertTrue(any("preserve before" in error for error in validate_identity(report)))

    def test_rejects_mutation_and_count(self):
        report = _identity()
        report["records"][0]["state_changed"] = True
        errors = validate_identity(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_identity())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_identity(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
