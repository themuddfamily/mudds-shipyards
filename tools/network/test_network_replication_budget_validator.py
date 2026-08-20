import copy
import hashlib
import unittest

try:
    from .network_replication_budget_validator import validate_budget, validate_report
except ImportError:  # Direct invocation from the tools/network directory.
    from network_replication_budget_validator import validate_budget, validate_report


def _report() -> dict:
    return {
        "schema_version": 1,
        "measurement_scope": "native_transport_replication_counters_per_peer",
        "measurement_mode": "captured",
        "native_provenance": {
            "capture_kind": "native_windows_two_client_soak",
            "platform": "windows",
            "transport": "enet",
            "build_id": "v0.12-native-42",
            "capture_sha256": hashlib.sha256(b"capture").hexdigest(),
            "client_count": 2,
        },
        "peers": [
            {
                "peer_id": 1,
                "measurement_seconds": 10,
                "sent_bytes": 10000,
                "received_bytes": 8000,
                "sent_packets": 100,
                "received_packets": 80,
                "stale_drops": 2,
                "packet_sizes": {"max_bytes": 512, "p95_bytes": 400},
                "metrics_source": "transport_counter_capture",
            },
            {
                "peer_id": 2,
                "measurement_seconds": 10,
                "sent_bytes": 9000,
                "received_bytes": 7000,
                "sent_packets": 90,
                "received_packets": 70,
                "stale_drops": 1,
                "packet_sizes": {"max_bytes": 500, "p95_bytes": 390},
                "metrics_source": "transport_counter_capture",
            },
        ],
    }


_BUDGETS = {
    "max_egress_bytes_per_second": 1100,
    "max_ingress_bytes_per_second": 900,
    "max_egress_packets_per_second": 11,
    "max_ingress_packets_per_second": 9,
    "max_packet_bytes": 512,
    "max_stale_drop_rate": 0.03,
}


class NetworkReplicationBudgetValidatorTest(unittest.TestCase):
    def test_valid_native_capture(self):
        self.assertEqual(validate_budget(_report(), _BUDGETS), [])

    def test_rates_are_derived_per_peer(self):
        report = _report()
        report["peers"][0]["sent_bytes"] = 11001
        self.assertTrue(any("peer 1 egress_bytes_per_second" in e for e in validate_budget(report, _BUDGETS)))

    def test_packet_size_ceiling(self):
        report = _report()
        report["peers"][1]["packet_sizes"]["max_bytes"] = 513
        self.assertTrue(any("max packet size" in e for e in validate_budget(report, _BUDGETS)))

    def test_stale_drop_rate_ceiling(self):
        report = _report()
        report["peers"][0]["stale_drops"] = 4
        self.assertTrue(any("stale drop rate" in e for e in validate_budget(report, _BUDGETS)))

    def test_rejects_non_native_or_estimated_metrics(self):
        report = _report()
        report["measurement_mode"] = "estimated"
        report["native_provenance"]["platform"] = "linux"
        errors = validate_report(report)
        self.assertTrue(any("measurement_mode" in e for e in errors))
        self.assertTrue(any("platform" in e for e in errors))

    def test_rejects_missing_provenance_digest(self):
        report = copy.deepcopy(_report())
        report["native_provenance"]["capture_sha256"] = "not-a-digest"
        self.assertTrue(any("capture_sha256" in e for e in validate_report(report)))

    def test_rejects_duplicate_peer_ids_and_invalid_size_order(self):
        report = _report()
        report["peers"][1]["peer_id"] = 1
        report["peers"][1]["packet_sizes"]["p95_bytes"] = 600
        errors = validate_report(report)
        self.assertTrue(any("unique" in e for e in errors))
        self.assertTrue(any("p95_bytes" in e for e in errors))

    def test_rejects_unknown_metric_source(self):
        report = _report()
        report["peers"][0]["metrics_source"] = "synthetic"
        self.assertTrue(any("metrics_source" in e for e in validate_report(report)))


if __name__ == "__main__":
    unittest.main()
