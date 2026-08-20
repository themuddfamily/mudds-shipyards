import copy
import hashlib
import unittest

try:
    from .network_snapshot_paired_digest_lineage_authority_v28_validator import validate_lineage
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_paired_digest_lineage_authority_v28_validator import validate_lineage


def _lineage() -> dict:
    pairs = []
    for order, pair_id, payload in ((1, "pair-a", b"a"), (2, "pair-b", b"b")):
        digest = hashlib.sha256(payload).hexdigest()
        pairs.append({"order": order, "pair_id": pair_id, "lineage_id": f"server|{pair_id}|{order}", "authority": "server", "left_digest": digest, "right_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False})
    return {
        "schema_version": 28,
        "evidence_scope": "network_snapshot_paired_digest_lineage_authority_v28",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "left_state": {"authority": "server", "sequence": 240, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "right_state": {"authority": "server", "sequence": 240, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "pairs": pairs,
        "lineage_digest": hashlib.sha256("\n".join(f"{pair['order']}|{pair['lineage_id']}|{pair['left_digest']}|{pair['right_digest']}" for pair in pairs).encode()).hexdigest(),
        "counts": {"pairs": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotPairedDigestLineageAuthorityV28ValidatorTest(unittest.TestCase):
    def test_accepts_paired_lineage(self):
        self.assertEqual(validate_lineage(_lineage()), [])

    def test_rejects_lineage_id(self):
        report = _lineage()
        report["pairs"][0]["lineage_id"] = "client|pair-a|1"
        self.assertTrue(any("lineage_id" in error for error in validate_lineage(report)))

    def test_rejects_changed_right_state(self):
        report = _lineage()
        report["right_state"]["sequence"] = 241
        self.assertTrue(any("equal left" in error for error in validate_lineage(report)))

    def test_rejects_lineage_digest(self):
        report = _lineage()
        report["lineage_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match paired lineage" in error for error in validate_lineage(report)))

    def test_rejects_mutation_and_count(self):
        report = _lineage()
        report["pairs"][0]["state_changed"] = True
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
