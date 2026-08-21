import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_package_v283_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_package_v283_validator import validate_snapshot


def _item(order, item_id, digest, artifact):
    item = {
        "order": order, "item_id": item_id,
        "package_id": "server-authority-package-v1", "authority": "server",
        "takeover_token": "server-authority-takeover-token-v54",
        "snapshot_id": "snapshot-authority-v166", "sequence": 42178,
        "artifact": artifact, "expected_digest": digest, "observed_digest": digest,
        "packed": True, "mutation_fields": [], "state_changed": False,
    }
    fields = (
        "package_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "artifact", "item_id", "expected_digest", "observed_digest",
    )
    item["package_digest"] = hashlib.sha256(
        "|".join(str(item[key]) for key in fields).encode()
    ).hexdigest()
    return item


def _not_run(reason):
    return {"status": "NOT_RUN", "evidence": None, "reason": reason}


def _report():
    items = [
        _item(1, "authority", hashlib.sha256(b"authority").hexdigest(), "authority"),
        _item(2, "snapshot", hashlib.sha256(b"snapshot").hexdigest(), "snapshot"),
    ]
    material = "\n".join(
        f"{item['order']}|{item['item_id']}|{item['package_digest']}" for item in items
    )
    return {
        "schema_version": 283,
        "evidence_scope": "network_snapshot_authority_takeover_package_v283",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "package_id": "server-authority-package-v1",
        "takeover_token": "server-authority-takeover-token-v54",
        "snapshot_id": "snapshot-authority-v166", "source": "server_snapshot",
        "snapshot_version": 55, "release": "release-1",
        "native_claims": False, "uses_live_network": False,
        "snapshot_detached": True, "no_mutation_guarantee": True,
        "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
        "native_run": _not_run("Native transport is outside this validator scope."),
        "hardware_run": _not_run("Hardware validation is outside this validator scope."),
        "human_review": _not_run("Human review is outside this validator scope."),
        "snapshot": {
            "package_id": "server-authority-package-v1",
            "takeover_token": "server-authority-takeover-token-v54",
            "snapshot_id": "snapshot-authority-v166", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 55,
            "sequence": 42178, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "package_items": items,
        "rollup_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"items": 2, "unique": 2, "packed": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverPackageV283ValidatorTest(unittest.TestCase):
    def test_accepts_package_rollup(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_package_binding(self):
        report = _report()
        report["package_items"][0]["takeover_token"] = "wrong-token"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority package" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["package_items"][1]["order"] = 1
        report["package_items"][1]["item_id"] = report["package_items"][0]["item_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("item_id must be unique" in error for error in errors))

    def test_rejects_rollup_and_counts(self):
        report = _report()
        report["rollup_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["items"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority package items" in error for error in errors))
        self.assertTrue(any("counts.items" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["package_items"][0]["mutation_fields"] = ["authority"]
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
