import copy
import hashlib
import unittest

try:
    from .network_snapshot_transition_lineage_digest_v9_validator import validate_lineage
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_transition_lineage_digest_v9_validator import validate_lineage


def _transition(order, decision, source, target, accepted):
    return {
        "lineage_id": f"server/{order}/{decision}",
        "order": order,
        "authority": "server",
        "decision": decision,
        "from": source,
        "to": target,
        "accepted": accepted,
        "mutation_fields": [],
        "state_changed": False,
    }


def _lineage() -> dict:
    initial = {"sequence": 50, "digest": hashlib.sha256(b"initial").hexdigest()}
    accepted = {"sequence": 51, "digest": hashlib.sha256(b"accepted").hexdigest()}
    final = {"sequence": 52, "digest": hashlib.sha256(b"final").hexdigest()}
    transitions = [
        _transition(1, "accepted", initial, accepted, True),
        _transition(2, "rejected_digest", accepted, accepted, False),
        _transition(3, "rejected_sequence", accepted, accepted, False),
        _transition(4, "accepted", accepted, final, True),
    ]
    lineage_digest = hashlib.sha256("\n".join(item["lineage_id"] for item in transitions).encode()).hexdigest()
    return {
        "schema_version": 9,
        "evidence_scope": "network_snapshot_transition_lineage_digest_v9",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "initial": initial,
        "transitions": transitions,
        "final": final,
        "lineage_digest": lineage_digest,
        "counts": {"transitions": 4, "accepted": 2, "rejected_digest": 1, "rejected_sequence": 1, "rejected": 2, "mutations": 0},
    }


class NetworkSnapshotTransitionLineageDigestV9ValidatorTest(unittest.TestCase):
    def test_accepts_lineage_digest(self):
        self.assertEqual(validate_lineage(_lineage()), [])

    def test_rejects_lineage_digest_mismatch(self):
        report = _lineage()
        report["lineage_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match ordered lineage IDs" in error for error in validate_lineage(report)))

    def test_rejects_lineage_id_order(self):
        report = _lineage()
        report["transitions"][1]["lineage_id"] = "server/3/rejected_digest"
        self.assertTrue(any("lineage_id" in error for error in validate_lineage(report)))

    def test_rejects_broken_predecessor(self):
        report = _lineage()
        report["transitions"][2]["from"] = {"sequence": 49, "digest": hashlib.sha256(b"old").hexdigest()}
        self.assertTrue(any("lineage predecessor" in error for error in validate_lineage(report)))

    def test_rejects_mutation_and_count(self):
        report = _lineage()
        report["transitions"][0]["state_changed"] = True
        errors = validate_lineage(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_lineage())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_lineage(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
