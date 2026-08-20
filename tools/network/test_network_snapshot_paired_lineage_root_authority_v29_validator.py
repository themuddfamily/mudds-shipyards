import copy
import hashlib
import unittest

try:
    from .network_snapshot_paired_lineage_root_authority_v29_validator import validate_root
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_paired_lineage_root_authority_v29_validator import validate_root


def _root() -> dict:
    state = {"authority": "server", "sequence": 250, "digest": hashlib.sha256(b"root").hexdigest()}
    state["root_digest"] = hashlib.sha256(f"server|250|{state['digest']}".encode()).hexdigest()
    return state


def _report() -> dict:
    root = _root()
    pairs = []
    for order, pair_id, payload in ((1, "pair-a", b"a"), (2, "pair-b", b"b")):
        digest = hashlib.sha256(payload).hexdigest()
        pairs.append({"order": order, "pair_id": pair_id, "lineage_id": f"server|{pair_id}|{order}", "authority": "server", "root_digest": root["root_digest"], "left_digest": digest, "right_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False})
    payload = f"{root['root_digest']}\n" + "\n".join(f"{pair['order']}|{pair['lineage_id']}|{pair['left_digest']}|{pair['right_digest']}" for pair in pairs)
    return {
        "schema_version": 29,
        "evidence_scope": "network_snapshot_paired_lineage_root_authority_v29",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root": root,
        "left_state": {"authority": "server", "sequence": 250, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "right_state": {"authority": "server", "sequence": 250, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "pairs": pairs,
        "lineage_root_digest": hashlib.sha256(payload.encode()).hexdigest(),
        "counts": {"pairs": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotPairedLineageRootAuthorityV29ValidatorTest(unittest.TestCase):
    def test_accepts_lineage_root(self):
        self.assertEqual(validate_root(_report()), [])

    def test_rejects_root_digest(self):
        report = _report()
        report["root"]["root_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor root authority" in error for error in validate_root(report)))

    def test_rejects_lineage_id(self):
        report = _report()
        report["pairs"][0]["lineage_id"] = "client|pair-a|1"
        self.assertTrue(any("lineage_id" in error for error in validate_root(report)))

    def test_rejects_lineage_root_digest(self):
        report = _report()
        report["lineage_root_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match root and pairs" in error for error in validate_root(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["pairs"][0]["state_changed"] = True
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
