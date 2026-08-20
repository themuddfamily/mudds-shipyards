import copy
import hashlib
import unittest

try:
    from .network_snapshot_paired_root_authority_digest_v32_validator import validate_digest
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_paired_root_authority_digest_v32_validator import validate_digest


def _root() -> dict:
    digest = hashlib.sha256(b"snapshot").hexdigest()
    root = {"authority": "server", "pair_id": "root-pair", "member_count": 2, "left": {"sequence": 280, "digest": digest}, "right": {"sequence": 280, "digest": digest}}
    root["authority_digest"] = hashlib.sha256(f"server|root-pair|2|280|{digest}|280|{digest}".encode()).hexdigest()
    return root


def _report() -> dict:
    root = _root()
    members = [{"order": 1, "member_id": "ship-a", "authority": "server", "authority_digest": root["authority_digest"], "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}, {"order": 2, "member_id": "ship-b", "authority": "server", "authority_digest": root["authority_digest"], "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}]
    return {
        "schema_version": 32,
        "evidence_scope": "network_snapshot_paired_root_authority_digest_v32",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root_pair": root,
        "members": members,
        "counts": {"members": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotPairedRootAuthorityDigestV32ValidatorTest(unittest.TestCase):
    def test_accepts_counted_root_digest(self):
        self.assertEqual(validate_digest(_report()), [])

    def test_rejects_member_count(self):
        report = _report()
        report["root_pair"]["member_count"] = 1
        self.assertTrue(any("member_count" in error for error in validate_digest(report)))

    def test_rejects_authority_digest(self):
        report = _report()
        report["root_pair"]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind root and member count" in error for error in validate_digest(report)))

    def test_rejects_member_authority_reference(self):
        report = _report()
        report["members"][0]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("authority_digest" in error for error in validate_digest(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["members"][0]["state_changed"] = True
        errors = validate_digest(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_digest(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
