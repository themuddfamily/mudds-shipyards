import copy
import hashlib
import unittest

try:
    from .network_snapshot_dual_version_authority_provenance_v44_validator import validate_dual_version
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_dual_version_authority_provenance_v44_validator import validate_dual_version


def _record(order, record_id, digest):
    record = {"order": order, "record_id": record_id, "authority": "server", "authority_version": 1, "provenance_version": 1, "sequence": 370, "expected_digest": digest, "observed_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
    record["binding_digest"] = hashlib.sha256(f"server|1|1|{record_id}|370|{digest}".encode()).hexdigest()
    return record


def _dual_version() -> dict:
    records = [_record(1, "ship-a", hashlib.sha256(b"a").hexdigest()), _record(2, "ship-b", hashlib.sha256(b"b").hexdigest())]
    return {
        "schema_version": 44,
        "evidence_scope": "network_snapshot_dual_version_authority_provenance_v44",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "authority_version": 1,
        "provenance_version": 1,
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": {"authority": "server", "sequence": 370, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "records": records,
        "aggregate_digest": hashlib.sha256("\n".join(f"{record['order']}|{record['record_id']}|{record['binding_digest']}" for record in records).encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotDualVersionAuthorityProvenanceV44ValidatorTest(unittest.TestCase):
    def test_accepts_dual_version_records(self):
        self.assertEqual(validate_dual_version(_dual_version()), [])

    def test_rejects_authority_version(self):
        report = _dual_version()
        report["records"][0]["authority_version"] = 2
        self.assertTrue(any("bind both versions" in error for error in validate_dual_version(report)))

    def test_rejects_binding_digest(self):
        report = _dual_version()
        report["records"][0]["binding_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind both versions" in error for error in validate_dual_version(report)))

    def test_rejects_aggregate_digest(self):
        report = _dual_version()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match dual-version" in error for error in validate_dual_version(report)))

    def test_rejects_mutation_and_count(self):
        report = _dual_version()
        report["records"][0]["state_changed"] = True
        errors = validate_dual_version(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_dual_version())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_dual_version(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
