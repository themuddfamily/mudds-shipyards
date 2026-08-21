import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_checkpoint_v277_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_checkpoint_v277_validator import validate_snapshot


def _checkpoint(order, item_id, digest, stage):
    item = {
        "order": order, "item_id": item_id,
        "checkpoint_id": "server-authority-checkpoint-v1", "authority": "server",
        "takeover_token": "server-authority-takeover-token-v48",
        "snapshot_id": "snapshot-authority-v160", "sequence": 42172,
        "stage": stage, "expected_digest": digest, "observed_digest": digest,
        "verified": True, "mutation_fields": [], "state_changed": False,
    }
    fields = (
        "checkpoint_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "stage", "item_id", "expected_digest", "observed_digest",
    )
    item["checkpoint_digest"] = hashlib.sha256(
        "|".join(str(item[key]) for key in fields).encode()
    ).hexdigest()
    return item


def _not_run(reason):
    return {"status": "NOT_RUN", "evidence": None, "reason": reason}


def _report():
    items = [
        _checkpoint(1, "authority", hashlib.sha256(b"authority").hexdigest(), "authority"),
        _checkpoint(2, "snapshot", hashlib.sha256(b"snapshot").hexdigest(), "snapshot"),
    ]
    material = "\n".join(
        f"{item['order']}|{item['item_id']}|{item['checkpoint_digest']}" for item in items
    )
    return {
        "schema_version": 277,
        "evidence_scope": "network_snapshot_authority_takeover_checkpoint_v277",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "checkpoint_id": "server-authority-checkpoint-v1",
        "takeover_token": "server-authority-takeover-token-v48",
        "snapshot_id": "snapshot-authority-v160", "source": "server_snapshot",
        "snapshot_version": 49, "release": "release-1",
        "native_claims": False, "uses_live_network": False,
        "snapshot_detached": True, "no_mutation_guarantee": True,
        "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
        "native_run": _not_run("Native transport is outside this validator scope."),
        "hardware_run": _not_run("Hardware validation is outside this validator scope."),
        "human_review": _not_run("Human review is outside this validator scope."),
        "snapshot": {
            "checkpoint_id": "server-authority-checkpoint-v1",
            "takeover_token": "server-authority-takeover-token-v48",
            "snapshot_id": "snapshot-authority-v160", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 49,
            "sequence": 42172, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "checkpoints": items,
        "rollup_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"checkpoints": 2, "unique": 2, "verified": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverCheckpointV277ValidatorTest(unittest.TestCase):
    def test_accepts_checkpoint_rollup(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_checkpoint_binding(self):
        report = _report()
        report["checkpoints"][0]["takeover_token"] = "wrong-token"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority checkpoint" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["checkpoints"][1]["order"] = 1
        report["checkpoints"][1]["item_id"] = report["checkpoints"][0]["item_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("item_id must be unique" in error for error in errors))

    def test_rejects_rollup_and_counts(self):
        report = _report()
        report["rollup_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["checkpoints"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority checkpoints" in error for error in errors))
        self.assertTrue(any("counts.checkpoints" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["checkpoints"][0]["mutation_fields"] = ["authority"]
        report["counts"]["mutations"] = 1
        errors = validate_snapshot(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations must be zero" in error for error in errors))

    def test_preserves_all_not_run_boundaries(self):
        report = _report()
        for key in ("stale_check", "native_run", "hardware_run", "human_review"):
            report[key]["status"] = "PASS"
            report[key]["evidence"] = "capture"
        errors = validate_snapshot(report)
        for key in ("stale_check", "native_run", "hardware_run", "human_review"):
            self.assertTrue(any(f"{key}.status must remain NOT_RUN" in error for error in errors))
            self.assertTrue(any(f"{key}.evidence must be null" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
