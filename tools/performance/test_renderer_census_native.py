#!/usr/bin/env python3
"""Focused tests for native renderer census normalization."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import renderer_census_native as census  # noqa: E402


class RendererCensusNativeTests(unittest.TestCase):
    def test_normalizes_samples_and_percentiles(self):
        report = census.normalize_renderer_census(
            {
                "source": "PresentMon + DXGI",
                "platform": "windows-x86_64",
                "renderer": "NVIDIA Vulkan Forward+",
                "metrics": {
                    "draw_calls": [100, 120, 140],
                    "gpu_frame_time_ms": {"samples": [4.0, 5.0], "unit": "milliseconds"},
                    "vram_bytes": {"value": 2_000_000, "unit": "bytes"},
                },
            }
        )
        self.assertEqual(report["report_kind"], census.REPORT_KIND)
        self.assertEqual(report["metrics"]["draw_calls"]["summary"]["p50"], 120.0)
        self.assertEqual(report["metrics"]["vram_bytes"]["samples"], [2_000_000])
        self.assertTrue(report["metrics"]["gpu_frame_time_ms"]["available"])

    def test_missing_and_unavailable_metrics_are_explicit(self):
        report = census.normalize_renderer_census(
            {"renderer": "AMD Vulkan", "metrics": {"gpu_frame_time_ms": {"available": False}}}
        )
        for entry in report["metrics"].values():
            self.assertFalse(entry["available"])
            self.assertEqual(entry["samples"], [])

    def test_rejects_software_renderer_claims(self):
        for payload in (
            {"renderer": "llvmpipe (LLVM 15)", "metrics": {}},
            {"software_renderer": True, "renderer": "Vulkan", "metrics": {}},
            {"adapter": "SwiftShader", "metrics": {}},
        ):
            with self.assertRaisesRegex(ValueError, "software renderer"):
                census.normalize_renderer_census(payload)

    def test_rejects_bad_shapes_values_and_units(self):
        with self.assertRaises(ValueError):
            census.normalize_renderer_census([])
        with self.assertRaises(ValueError):
            census.normalize_renderer_census({"metrics": []})
        report = census.normalize_renderer_census(
            {"renderer": "Intel Vulkan", "metrics": {
                "draw_calls": {"value": -1},
                "vram_bytes": {"value": 3, "unit": "megabytes"},
            }}
        )
        self.assertFalse(report["metrics"]["draw_calls"]["available"])
        self.assertFalse(report["metrics"]["vram_bytes"]["available"])


if __name__ == "__main__":
    unittest.main()
