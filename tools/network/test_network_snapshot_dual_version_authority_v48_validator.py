import copy
import hashlib
import unittest

try:
    from .network_snapshot_dual_version_authority_v48_validator import validate_authority
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_dual_version_authority_v48_validator import validate_authority


def _record(order, record_id, digest):
    record = {"order": order, "record_id": record_id, "authority": "server", "authority_version": 1, "provenance_version": 1, "sequence": 400, "digest": digest, "valid": True, "mutation_fields": [], "state_changed": False}
    record["authority_digest"] = hashlib.sha256(f"server|1|1|{record_id}|400|{digest}".encode()).hexdigest()
    return record


def _authority() -> dict:
    digest = hashlib.sha256(b"snapshot").hexdigest()
    records = [_record(1, "ship-a", digest), _record(2, "ship-b", digest)]
    return {
        "schema_version": 48,
        "evidence_scope": "network_snapshot_dual_version_authority_v48",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "authority_version": 1,
        "provenance_version": 1,
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": {"authority": "server", "sequence": 400, "digest": digest},
        "records": records,
        "aggregate_digest": hashlib.sha256("\n".join(f"{record['order']}|{record['record_id']}|{record['authority_digest']}" for record in records).encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "valid": 2, "mutations": 0},
    }


class NetworkSnapshotDualVersionAuthorityV48ValidatorTest(unittest.TestCase):
    def test_accepts_authority_records(self):
        self.assertEqual(validate_authority(_authority()), [])

    def test_rejects_record_authority_digest(self):
        report = _authority()
        report["records"][0]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind dual-version authority" in error for error in validate_authority(report)))

    def test_rejects_snapshot_digest_reference(self):
        report = _authority()
        report["records"][0]["digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("digest must match snapshot" in error for error in validate_authority(report)))

    def test_rejects_aggregate_digest(self):
        report = _authority()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match authority records" in error for error in validate_authority(report)))

    def test_rejects_mutation_and_count(self):
        report = _authority()
        report["records"][0]["state_changed"] = True
        errors = validate_authority(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_authority())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_authority(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
