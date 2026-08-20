#!/usr/bin/env python3
"""Focused tests for the external native benchmark normalizer."""

import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import native_benchmark_record_collector as collector  # noqa: E402


class NativeBenchmarkCollectorTests(unittest.TestCase):
    def test_normalizes_scalar_and_object_metrics(self):
        result = collector.collect_native_metrics(
            {
                "source": "PresentMon/Windows",
                "metrics": {
                    "frame_time_ms": 12.5,
                    "gpu_frame_time_ms": {"value": 8.0, "unit": "milliseconds"},
                    "ram_bytes": {"value": 1024, "unit": "bytes", "source": "ETW"},
                },
            }
        )
        self.assertEqual(result["frame_time_ms"]["value"], 12.5)
        self.assertTrue(result["gpu_frame_time_ms"]["available"])
        self.assertEqual(result["ram_bytes"]["source"], "ETW")
        self.assertFalse(result["vram_bytes"]["available"])

    def test_missing_and_explicit_unavailable_fail_closed(self):
        result = collector.collect_native_metrics(
            {"native_metrics": {"vram_bytes": {"available": False, "source": "driver omitted"}}}
        )
        for name in collector.METRIC_FIELDS:
            self.assertFalse(result[name]["available"], name)
            self.assertIsNone(result[name]["value"], name)

    def test_invalid_nan_negative_and_unit_are_unavailable(self):
        result = collector.collect_native_metrics(
            {
                "source": "harness",
                "metrics": {
                    "frame_time_ms": float("nan"),
                    "ram_bytes": -1,
                    "vram_bytes": {"value": 10, "unit": "megabytes"},
                },
            }
        )
        self.assertFalse(result["frame_time_ms"]["available"])
        self.assertFalse(result["ram_bytes"]["available"])
        self.assertFalse(result["vram_bytes"]["available"])

    def test_invalid_payload_shape_is_rejected(self):
        with self.assertRaises(ValueError):
            collector.collect_native_metrics([])
        with self.assertRaises(ValueError):
            collector.collect_native_metrics({"metrics": []})


if __name__ == "__main__":
    unittest.main()
