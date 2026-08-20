import copy
import hashlib
import unittest

try:
    from .network_snapshot_release_state_v80_validator import validate_snapshot
except ImportError:
    from network_snapshot_release_state_v80_validator import validate_snapshot


def _record(order, check_id, digest):
    record = {
        "order": order, "check_id": check_id, "authority": "server", "release": "release-1", "state": "stable", "source": "server_snapshot", "version": 2, "sequence": 420,
        "expected_digest": digest, "observed_digest": digest, "released": True, "mutation_fields": [], "state_changed": False,
    }
    material = "|".join(str(record[key]) for key in ("authority", "release", "state", "source", "version", "check_id", "sequence", "expected_digest", "observed_digest"))
    record["release_digest"] = hashlib.sha256(material.encode()).hexdigest()
    return record


def _report():
    records = [_record(1, "ship-a", hashlib.sha256(b"a").hexdigest()), _record(2, "ship-b", hashlib.sha256(b"b").hexdigest())]
    return {
        "schema_version": 80, "evidence_scope": "network_snapshot_release_state_v80", "evidence_mode": "detached_contract_fixture", "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "release": "release-1", "state": "stable", "source": "server_snapshot", "snapshot_version": 2,
        "native_claims": False, "uses_live_network": False, "snapshot_detached": True, "no_mutation_guarantee": True,
        "snapshot": {"authority": "server", "release": "release-1", "state": "stable", "source": "server_snapshot", "version": 2, "sequence": 420, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "records": records,
        "aggregate_digest": hashlib.sha256("\n".join(f"{r['order']}|{r['check_id']}|{r['release_digest']}" for r in records).encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "released": 2, "mutations": 0},
    }


class NetworkSnapshotReleaseStateV80ValidatorTest(unittest.TestCase):
    def test_accepts_release_state_records(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_release_binding(self):
        report = _report()
        report["records"][0]["release"] = "release-0"
        self.assertTrue(any("bind release/state" in error for error in validate_snapshot(report)))

    def test_rejects_state_binding(self):
        report = _report()
        report["records"][0]["state"] = "transitioning"
        self.assertTrue(any("bind release/state" in error for error in validate_snapshot(report)))

    def test_rejects_aggregate_digest(self):
        report = _report()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match release records" in error for error in validate_snapshot(report)))

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
