import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_docket_v249_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_docket_v249_validator import validate_snapshot


def _record(order, check_id, digest):
    record = {
        "order": order,
        "check_id": check_id,
        "docket_id": "server-authority-docket-v1",
        "authority_takeover_token": "server-authority-takeover-token-v20",
        "snapshot_id": "snapshot-authority-v132",
        "authority": "server",
        "source": "server_snapshot",
        "release": "release-1",
        "version": 21,
        "sequence": 22144,
        "expected_digest": digest,
        "observed_digest": digest,
        "authorized": True,
        "mutation_fields": [],
        "state_changed": False,
    }
    fields = (
        "docket_id", "authority_takeover_token", "snapshot_id", "authority", "source",
        "release", "version", "check_id", "sequence", "expected_digest",
        "observed_digest",
    )
    record["docket_digest"] = hashlib.sha256(
        "|".join(str(record[key]) for key in fields).encode()
    ).hexdigest()
    return record


def _report():
    records = [
        _record(1, "ship-a", hashlib.sha256(b"a").hexdigest()),
        _record(2, "ship-b", hashlib.sha256(b"b").hexdigest()),
    ]
    material = "\n".join(
        f"{record['order']}|{record['check_id']}|{record['docket_digest']}"
        for record in records
    )
    return {
        "schema_version": 249,
        "evidence_scope": "network_snapshot_authority_takeover_docket_v249",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "docket_id": "server-authority-docket-v1",
        "authority_takeover_token": "server-authority-takeover-token-v20",
        "snapshot_id": "snapshot-authority-v132",
        "source": "server_snapshot",
        "snapshot_version": 21,
        "release": "release-1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "stale_check": {
            "status": "NOT_RUN", "evidence": None,
            "reason": "Detached fixture does not execute stale replay checks.",
        },
        "native_run": {
            "status": "NOT_RUN", "evidence": None,
            "reason": "Native transport is outside this validator scope.",
        },
        "snapshot": {
            "docket_id": "server-authority-docket-v1",
            "authority_takeover_token": "server-authority-takeover-token-v20",
            "snapshot_id": "snapshot-authority-v132", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 21,
            "sequence": 22144, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "records": records,
        "aggregate_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "authorized": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverDocketV249ValidatorTest(unittest.TestCase):
    def test_accepts_authority_docket(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_docket_binding(self):
        report = _report()
        report["records"][0]["docket_id"] = "server-authority-docket-old"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority docket" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["records"][1]["order"] = 1
        report["records"][1]["check_id"] = report["records"][0]["check_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("check_id must be unique" in error for error in errors))

    def test_rejects_aggregate_and_counts(self):
        report = _report()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["records"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority docket records" in error for error in errors))
        self.assertTrue(any("counts.records" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["records"][0]["state_changed"] = True
        report["counts"]["mutations"] = 1
        errors = validate_snapshot(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations must be zero" in error for error in errors))

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
