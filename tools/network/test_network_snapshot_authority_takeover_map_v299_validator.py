import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_map_v299_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_map_v299_validator import validate_snapshot


def _item(order, item_id, digest, region):
    item = {
        "order": order, "item_id": item_id,
        "map_id": "server-authority-map-v1", "authority": "server",
        "takeover_token": "server-authority-takeover-token-v70",
        "snapshot_id": "snapshot-authority-v182", "sequence": 42194,
        "region": region, "expected_digest": digest, "observed_digest": digest,
        "mapped": True, "mutation_fields": [], "state_changed": False,
    }
    fields = (
        "map_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "region", "item_id", "expected_digest", "observed_digest",
    )
    item["map_digest"] = hashlib.sha256(
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
        f"{item['order']}|{item['item_id']}|{item['map_digest']}" for item in items
    )
    return {
        "schema_version": 299,
        "evidence_scope": "network_snapshot_authority_takeover_map_v299",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "map_id": "server-authority-map-v1",
        "takeover_token": "server-authority-takeover-token-v70",
        "snapshot_id": "snapshot-authority-v182", "source": "server_snapshot",
        "snapshot_version": 71, "release": "release-1",
        "native_claims": False, "uses_live_network": False,
        "snapshot_detached": True, "no_mutation_guarantee": True,
        "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
        "native_run": _not_run("Native transport is outside this validator scope."),
        "hardware_run": _not_run("Hardware validation is outside this validator scope."),
        "human_review": _not_run("Human review is outside this validator scope."),
        "snapshot": {
            "map_id": "server-authority-map-v1",
            "takeover_token": "server-authority-takeover-token-v70",
            "snapshot_id": "snapshot-authority-v182", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 71,
            "sequence": 42194, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "map_entries": items,
        "rollup_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"entries": 2, "unique": 2, "mapped": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverMapV299ValidatorTest(unittest.TestCase):
    def test_accepts_map_rollup(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_map_binding(self):
        report = _report()
        report["map_entries"][0]["takeover_token"] = "wrong-token"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority map" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["map_entries"][1]["order"] = 1
        report["map_entries"][1]["item_id"] = report["map_entries"][0]["item_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("item_id must be unique" in error for error in errors))

    def test_rejects_rollup_and_counts(self):
        report = _report()
        report["rollup_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["entries"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority map entries" in error for error in errors))
        self.assertTrue(any("counts.entries" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["map_entries"][0]["mutation_fields"] = ["authority"]
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
