import copy
import hashlib
import unittest

try:
    from .network_snapshot_lineage_root_authority_digest_v10_validator import validate_root
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_lineage_root_authority_digest_v10_validator import validate_root


def _root_digest(state):
    return hashlib.sha256(f"server|{state['sequence']}|{state['digest']}".encode()).hexdigest()


def _transition(order, decision, source, target, accepted):
    return {
        "order": order,
        "authority": "server",
        "decision": decision,
        "from": source,
        "to": target,
        "accepted": accepted,
        "mutation_fields": [],
        "state_changed": False,
    }


def _root() -> dict:
    initial = {"sequence": 60, "digest": hashlib.sha256(b"initial").hexdigest()}
    accepted = {"sequence": 61, "digest": hashlib.sha256(b"accepted").hexdigest()}
    final = {"sequence": 62, "digest": hashlib.sha256(b"final").hexdigest()}
    return {
        "schema_version": 10,
        "evidence_scope": "network_snapshot_lineage_root_authority_digest_v10",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root": {"authority": "server", **initial, "authority_digest": _root_digest(initial)},
        "transitions": [
            _transition(1, "accepted", initial, accepted, True),
            _transition(2, "rejected_digest", accepted, accepted, False),
            _transition(3, "rejected_sequence", accepted, accepted, False),
            _transition(4, "accepted", accepted, final, True),
        ],
        "final": final,
        "counts": {"transitions": 4, "accepted": 2, "rejected_digest": 1, "rejected_sequence": 1, "rejected": 2, "mutations": 0},
    }


class NetworkSnapshotLineageRootAuthorityDigestV10ValidatorTest(unittest.TestCase):
    def test_accepts_root_anchored_lineage(self):
        self.assertEqual(validate_root(_root()), [])

    def test_rejects_root_authority_digest(self):
        report = _root()
        report["root"]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor authority" in error for error in validate_root(report)))

    def test_rejects_broken_root_chain(self):
        report = _root()
        report["transitions"][0]["from"]["sequence"] = 59
        self.assertTrue(any("root lineage state" in error for error in validate_root(report)))

    def test_rejects_nonadvancing_transition(self):
        report = _root()
        report["transitions"][3]["to"]["sequence"] = 61
        self.assertTrue(any("advance once" in error for error in validate_root(report)))

    def test_rejects_mutation_and_count(self):
        report = _root()
        report["transitions"][1]["state_changed"] = True
        errors = validate_root(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_root())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_root(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
