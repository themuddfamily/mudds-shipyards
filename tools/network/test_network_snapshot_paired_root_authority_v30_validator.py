import copy
import hashlib
import unittest

try:
    from .network_snapshot_paired_root_authority_v30_validator import validate_root
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_paired_root_authority_v30_validator import validate_root


def _root() -> dict:
    digest = hashlib.sha256(b"snapshot").hexdigest()
    state = {"sequence": 260, "digest": digest}
    root = {"authority": "server", "pair_id": "root-pair", "left": state, "right": dict(state)}
    root["pair_digest"] = hashlib.sha256(f"server|root-pair|{digest}|{digest}".encode()).hexdigest()
    return root


def _report() -> dict:
    root = _root()
    members = [{"order": 1, "member_id": "ship-a", "authority": "server", "root_pair_digest": root["pair_digest"], "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}, {"order": 2, "member_id": "ship-b", "authority": "server", "root_pair_digest": root["pair_digest"], "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}]
    return {
        "schema_version": 30,
        "evidence_scope": "network_snapshot_paired_root_authority_v30",
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


class NetworkSnapshotPairedRootAuthorityV30ValidatorTest(unittest.TestCase):
    def test_accepts_paired_root(self):
        self.assertEqual(validate_root(_report()), [])

    def test_rejects_root_state_mismatch(self):
        report = _report()
        report["root_pair"]["right"]["sequence"] = 261
        self.assertTrue(any("right must equal left" in error for error in validate_root(report)))

    def test_rejects_pair_digest(self):
        report = _report()
        report["root_pair"]["pair_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind root pair" in error for error in validate_root(report)))

    def test_rejects_member_root_reference(self):
        report = _report()
        report["members"][0]["root_pair_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("root_pair_digest" in error for error in validate_root(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["members"][0]["state_changed"] = True
        errors = validate_root(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_root(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
