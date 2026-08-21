import copy
import hashlib
import unittest

try:
    from .network_snapshot_audit_lineage_v103_validator import validate_snapshot
except ImportError:
    from network_snapshot_audit_lineage_v103_validator import validate_snapshot


def _record(order, check_id, digest):
    record = {
        "order": order,
        "check_id": check_id,
        "authority": "server",
        "audit_id": "snapshot-audit-v4",
        "lineage": "snapshot-lineage-root-v4",
        "source": "server_snapshot",
        "release": "release-1",
        "version": 2,
        "sequence": 421,
        "expected_digest": digest,
        "observed_digest": digest,
        "audited": True,
        "mutation_fields": [],
        "state_changed": False,
    }
    fields = (
        "authority", "audit_id", "lineage", "source", "release", "version",
        "check_id", "sequence", "expected_digest", "observed_digest",
    )
    material = "|".join(str(record[key]) for key in fields)
    record["audit_digest"] = hashlib.sha256(material.encode()).hexdigest()
    return record


def _report():
    records = [
        _record(1, "ship-a", hashlib.sha256(b"a").hexdigest()),
        _record(2, "ship-b", hashlib.sha256(b"b").hexdigest()),
    ]
    aggregate = "\n".join(
        f"{record['order']}|{record['check_id']}|{record['audit_digest']}"
        for record in records
    )
    return {
        "schema_version": 103,
        "evidence_scope": "network_snapshot_audit_lineage_v103",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "audit_id": "snapshot-audit-v4",
        "lineage": "snapshot-lineage-root-v4",
        "source": "server_snapshot",
        "snapshot_version": 2,
        "release": "release-1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": {
            "authority": "server",
            "audit_id": "snapshot-audit-v4",
            "lineage": "snapshot-lineage-root-v4",
            "source": "server_snapshot",
            "release": "release-1",
            "version": 2,
            "sequence": 421,
            "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "records": records,
        "aggregate_digest": hashlib.sha256(aggregate.encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "audited": 2, "mutations": 0},
    }


class NetworkSnapshotAuditLineageV103ValidatorTest(unittest.TestCase):
    def test_accepts_audit_lineage_records(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_audit_binding(self):
        report = _report()
        report["records"][0]["audit_id"] = "snapshot-audit-v3"
        self.assertTrue(any("bind audit/lineage" in error for error in validate_snapshot(report)))

    def test_rejects_lineage_binding(self):
        report = _report()
        report["records"][0]["lineage"] = "snapshot-lineage-root-v3"
        self.assertTrue(any("bind audit/lineage" in error for error in validate_snapshot(report)))

    def test_rejects_aggregate_digest(self):
        report = _report()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match audit records" in error for error in validate_snapshot(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["records"][0]["state_changed"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
