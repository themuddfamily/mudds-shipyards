import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_certificate_v168_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_certificate_v168_validator import validate_snapshot


def _record(order, check_id, digest):
    record = {
        "order": order,
        "check_id": check_id,
        "authority_certificate": "server-authority-certificate-v1",
        "snapshot_id": "snapshot-authority-v51",
        "authority": "server",
        "source": "server_snapshot",
        "release": "release-1",
        "version": 2,
        "sequence": 1757,
        "expected_digest": digest,
        "observed_digest": digest,
        "authorized": True,
        "mutation_fields": [],
        "state_changed": False,
    }
    fields = (
        "authority_certificate", "snapshot_id", "authority", "source", "release",
        "version", "check_id", "sequence", "expected_digest", "observed_digest",
    )
    record["binding_digest"] = hashlib.sha256(
        "|".join(str(record[key]) for key in fields).encode()
    ).hexdigest()
    return record


def _report():
    records = [
        _record(1, "ship-a", hashlib.sha256(b"a").hexdigest()),
        _record(2, "ship-b", hashlib.sha256(b"b").hexdigest()),
    ]
    material = "\n".join(
        f"{record['order']}|{record['check_id']}|{record['binding_digest']}"
        for record in records
    )
    return {
        "schema_version": 168,
        "evidence_scope": "network_snapshot_authority_certificate_v168",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "authority_certificate": "server-authority-certificate-v1",
        "snapshot_id": "snapshot-authority-v51",
        "source": "server_snapshot",
        "snapshot_version": 2,
        "release": "release-1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "stale_check": {
            "status": "NOT_RUN",
            "evidence": None,
            "reason": "Detached fixture does not execute stale replay checks.",
        },
        "native_run": {
            "status": "NOT_RUN",
            "evidence": None,
            "reason": "Native transport is outside this validator scope.",
        },
        "snapshot": {
            "authority_certificate": "server-authority-certificate-v1",
            "snapshot_id": "snapshot-authority-v51",
            "authority": "server",
            "source": "server_snapshot",
            "release": "release-1",
            "version": 2,
            "sequence": 1757,
            "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "records": records,
        "aggregate_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "authorized": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityCertificateV168ValidatorTest(unittest.TestCase):
    def test_accepts_authority_certificate_snapshot_records(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_certificate_binding(self):
        report = _report()
        report["records"][0]["authority_certificate"] = "server-authority-certificate-old"
        self.assertTrue(any("bind authority certificate" in error for error in validate_snapshot(report)))

    def test_rejects_snapshot_binding(self):
        report = _report()
        report["records"][0]["snapshot_id"] = "snapshot-authority-v50"
        self.assertTrue(any("bind authority certificate" in error for error in validate_snapshot(report)))

    def test_rejects_aggregate_digest(self):
        report = _report()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match authority certificate records" in error for error in validate_snapshot(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["records"][0]["state_changed"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_preserves_stale_native_not_run(self):
        report = _report()
        report["stale_check"]["status"] = "PASS"
        report["native_run"]["evidence"] = "capture"
        errors = validate_snapshot(report)
        self.assertTrue(any("stale_check.status must remain NOT_RUN" in error for error in errors))
        self.assertTrue(any("native_run.evidence must be null" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
