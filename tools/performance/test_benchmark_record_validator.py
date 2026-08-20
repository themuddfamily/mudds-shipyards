#!/usr/bin/env python3
"""Focused fixture tests for the native benchmark record gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import benchmark_record_validator as validator  # noqa: E402


def record():
    return {
        "schema_version": 1,
        "report_kind": validator.REPORT_KIND,
        "source": {"git_sha": "a" * 40, "git_dirty": False},
        "representativeness": {"representative_pass": True},
        "configuration": {"smoke_run": False},
        "unavailable_metrics": {
            "gpu_frame_time_ms": {"available": True, "value": 8.0},
            "vram_bytes": {"available": True, "value": 1024},
        },
        "native_metrics": {
            name: {"available": False, "value": None, "unit": unit, "source": "not captured by harness"}
            for name, unit in validator.NATIVE_METRIC_FIELDS.items()
        },
        "target_profile": {
            "budgets": {
                "frame_time_ms": {"p95": 16.7, "p99": 33.3, "max": 100.0},
                "peak_working_set_bytes": 4 * 1024**3,
            }
        },
        "scenarios": [
            {
                "name": name,
                "completed": True,
                "frame_delta_ms": {"count": 10, "p50": 10.0, "p95": 15.0, "p99": 20.0, "max": 40.0},
                "ram": {"static_peak_bytes": 1000},
            }
            for name in sorted(validator.SCENARIOS)
        ],
    }


class BenchmarkRecordValidatorTests(unittest.TestCase):
    def test_valid_record(self):
        self.assertEqual(validator.validate_record(record()), [])

    def test_unavailable_gpu_is_blocking(self):
        value = record()
        value["unavailable_metrics"]["gpu_frame_time_ms"] = {"available": False, "value": None}
        self.assertIn("gpu_frame_time_ms must contain a measured native value", validator.validate_record(value))

    def test_budget_overrun_is_reported_per_scenario(self):
        value = record()
        value["scenarios"][0]["frame_delta_ms"]["p99"] = 34.0
        errors = validator.validate_record(value)
        self.assertIn(f"scenario {value['scenarios'][0]['name']} p99 exceeds budget", errors)

    def test_dirty_or_smoke_record_cannot_pass(self):
        value = record()
        value["source"]["git_dirty"] = True
        value["configuration"]["smoke_run"] = True
        errors = validator.validate_record(value)
        self.assertIn("source.git_dirty must be false", errors)
        self.assertIn("configuration.smoke_run must be false", errors)

    def test_missing_budget_fails_closed(self):
        value = copy.deepcopy(record())
        del value["target_profile"]["budgets"]
        self.assertIn("target budgets.frame_time_ms is required", validator.validate_record(value))
        self.assertIn("target budgets.peak_working_set_bytes must be positive", validator.validate_record(value))

    def test_unavailable_native_fields_do_not_claim_measurements(self):
        value = record()
        value["native_metrics"]["vram_bytes"]["available"] = True
        value["native_metrics"]["vram_bytes"]["value"] = None
        self.assertIn("native_metrics.vram_bytes.value must be non-negative when available", validator.validate_record(value))

    def test_native_field_shape_is_complete(self):
        value = record()
        del value["native_metrics"]["draw_calls"]
        self.assertIn("native_metrics.draw_calls must be an object", validator.validate_record(value))


if __name__ == "__main__":
    unittest.main()
