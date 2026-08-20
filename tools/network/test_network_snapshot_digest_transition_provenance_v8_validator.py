import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_transition_provenance_v8_validator import validate_provenance
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_transition_provenance_v8_validator import validate_provenance


def _transition(order, decision, source, target, accepted):
    return {
        "order": order,
        "authority": "server",
        "decision": decision,
        "provenance": f"server:{decision}:{order}",
        "from": source,
        "to": target,
        "accepted": accepted,
        "mutation_fields": [],
        "state_changed": False,
    }


def _provenance() -> dict:
    initial = {"sequence": 40, "digest": hashlib.sha256(b"initial").hexdigest()}
    accepted = {"sequence": 41, "digest": hashlib.sha256(b"accepted").hexdigest()}
    final = {"sequence": 42, "digest": hashlib.sha256(b"final").hexdigest()}
    stale = {"sequence": 41, "digest": hashlib.sha256(b"stale").hexdigest()}
    return {
        "schema_version": 8,
        "evidence_scope": "network_snapshot_digest_transition_provenance_v8",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "initial": initial,
        "transitions": [
            _transition(1, "accepted", initial, accepted, True),
            _transition(2, "rejected_digest", accepted, accepted, False),
            _transition(3, "rejected_sequence", accepted, accepted, False),
            _transition(4, "accepted", accepted, final, True),
        ],
        "final": final,
        "counts": {"transitions": 4, "accepted": 2, "rejected_digest": 1, "rejected_sequence": 1, "rejected": 2, "mutations": 0},
    }


class NetworkSnapshotDigestTransitionProvenanceV8ValidatorTest(unittest.TestCase):
    def test_accepts_ordered_provenance(self):
        self.assertEqual(validate_provenance(_provenance()), [])

    def test_rejects_wrong_provenance_key(self):
        report = _provenance()
        report["transitions"][1]["provenance"] = "client:rejected_digest:2"
        self.assertTrue(any("provenance" in error for error in validate_provenance(report)))

    def test_rejects_broken_from_chain(self):
        report = _provenance()
        report["transitions"][2]["from"] = {"sequence": 39, "digest": hashlib.sha256(b"old").hexdigest()}
        self.assertTrue(any("from must match" in error for error in validate_provenance(report)))

    def test_rejects_nonadvancing_accept(self):
        report = _provenance()
        report["transitions"][3]["to"]["sequence"] = 41
        self.assertTrue(any("advance once" in error for error in validate_provenance(report)))

    def test_rejects_mutation_and_count(self):
        report = _provenance()
        report["transitions"][0]["mutation_fields"] = ["digest"]
        errors = validate_provenance(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_provenance())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_provenance(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
