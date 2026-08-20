import copy
import hashlib
import unittest

try:
    from .network_snapshot_release_version_linkage_v52_validator import validate_checks
except ImportError:
    from network_snapshot_release_version_linkage_v52_validator import validate_checks


def _check(order, check_id, digest):
    check = {
        "order": order, "check_id": check_id, "authority": "server", "release": "release-1",
        "version": 2, "sequence": 420, "expected_digest": digest, "observed_digest": digest,
        "linked": True, "mutation_fields": [], "state_changed": False,
    }
    material = "|".join(str(check[key]) for key in ("release", "version", "check_id", "sequence", "expected_digest", "observed_digest"))
    check["linkage_digest"] = hashlib.sha256(material.encode()).hexdigest()
    return check


def _report():
    snapshot = {"authority": "server", "release": "release-1", "version": 2, "sequence": 420, "digest": hashlib.sha256(b"snapshot").hexdigest()}
    checks = [_check(1, "ship-a", hashlib.sha256(b"a").hexdigest()), _check(2, "ship-b", hashlib.sha256(b"b").hexdigest())]
    snapshot_linkage = "|".join(str(snapshot[key]) for key in ("release", "version", "sequence", "digest"))
    return {
        "schema_version": 52,
        "evidence_scope": "network_snapshot_release_version_linkage_v52",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "snapshot_version": 2, "release": "release-1",
        "native_claims": False, "uses_live_network": False, "snapshot_detached": True,
        "no_mutation_guarantee": True, "snapshot": snapshot,
        "linkage_digest": hashlib.sha256(snapshot_linkage.encode()).hexdigest(), "checks": checks,
        "aggregate_digest": hashlib.sha256("\n".join(f"{c['order']}|{c['check_id']}|{c['linkage_digest']}" for c in checks).encode()).hexdigest(),
        "counts": {"checks": 2, "unique": 2, "linked": 2, "mutations": 0},
    }


class NetworkSnapshotReleaseVersionLinkageV52ValidatorTest(unittest.TestCase):
    def test_accepts_linked_checks(self):
        self.assertEqual(validate_checks(_report()), [])

    def test_rejects_snapshot_linkage(self):
        report = _report()
        report["linkage_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind release/version snapshot" in error for error in validate_checks(report)))

    def test_rejects_check_linkage(self):
        report = _report()
        report["checks"][0]["release"] = "release-0"
        self.assertTrue(any("bind release/version check" in error for error in validate_checks(report)))

    def test_rejects_aggregate_digest(self):
        report = _report()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match linked checks" in error for error in validate_checks(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["checks"][0]["state_changed"] = True
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
