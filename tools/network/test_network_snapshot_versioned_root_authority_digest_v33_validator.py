import copy
import hashlib
import unittest

try:
    from .network_snapshot_versioned_root_authority_digest_v33_validator import validate_versioned
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_versioned_root_authority_digest_v33_validator import validate_versioned


def _root() -> dict:
    digest = hashlib.sha256(b"snapshot").hexdigest()
    root = {"authority": "server", "version": 3, "pair_id": "root-pair", "left": {"sequence": 290, "digest": digest}, "right": {"sequence": 290, "digest": digest}}
    root["authority_digest"] = hashlib.sha256(f"server|3|root-pair|290|{digest}|290|{digest}".encode()).hexdigest()
    return root


def _report() -> dict:
    root = _root()
    return {
        "schema_version": 33,
        "evidence_scope": "network_snapshot_versioned_root_authority_digest_v33",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root": root,
        "members": [{"order": 1, "member_id": "ship-a", "authority": "server", "version": 3, "authority_digest": root["authority_digest"], "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}, {"order": 2, "member_id": "ship-b", "authority": "server", "version": 3, "authority_digest": root["authority_digest"], "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}],
        "counts": {"members": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotVersionedRootAuthorityDigestV33ValidatorTest(unittest.TestCase):
    def test_accepts_versioned_root(self):
        self.assertEqual(validate_versioned(_report()), [])

    def test_rejects_version(self):
        report = _report()
        report["root"]["version"] = 4
        self.assertTrue(any("bind versioned root" in error for error in validate_versioned(report)))

    def test_rejects_member_version(self):
        report = _report()
        report["members"][0]["version"] = 2
        self.assertTrue(any("version must match" in error for error in validate_versioned(report)))

    def test_rejects_root_state(self):
        report = _report()
        report["root"]["right"]["sequence"] = 291
        self.assertTrue(any("right must equal left" in error for error in validate_versioned(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["members"][0]["state_changed"] = True
        errors = validate_versioned(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_versioned(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
