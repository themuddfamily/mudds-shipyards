"""Focused tests for the packaged geometry/native evidence join."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import geometry_delta_validator as geometry  # noqa: E402
import geometry_package_evidence_validator as validator  # noqa: E402


COMMIT = "a" * 40


def manifest() -> dict:
    scene = {
        "schema_version": 2,
        "scenario": "station_resident",
        "loaded_instance_count": 0,
        "measurement_fingerprint": "b" * 64,
        "measurement_scope": "packaged_scene",
        "source_commit": COMMIT,
        "buckets": {"station": {"triangles": 10}},
    }
    scene.update({metric: 100 for metric in geometry.METRICS})
    metrics = {
        "frame_time_ms": {"available": True, "unit": "milliseconds", "value": 16.2, "source": "PresentMon"},
        "gpu_frame_time_ms": {"available": True, "unit": "milliseconds", "value": 8.1, "source": "GPU timestamp queries"},
        "ram_bytes": {"available": True, "unit": "bytes", "value": 2_000_000_000, "source": "Windows performance counter"},
        "vram_bytes": {"available": True, "unit": "bytes", "value": 1_000_000_000, "source": "DXGI adapter budget"},
        "draw_calls": {"available": True, "unit": "count", "value": 950, "source": "RenderDoc capture"},
    }
    return {
        "schema_version": 1,
        "report_kind": validator.REPORT_KIND,
        "package": {
            "artifact_sha256": "c" * 64,
            "source_commit": COMMIT,
            "platform": "windows-x86_64",
            "renderer": "Vulkan Forward+",
            "resolution": "1920x1080",
            "profile": "target",
        },
        "scene_census": scene,
        "native_evidence": {
            "available": True,
            "software_renderer": False,
            "platform": "windows-x86_64",
            "renderer": "NVIDIA RTX 3060 Vulkan Forward+",
            "hardware": "RTX 3060 / Ryzen 5600",
            "source": "native packaged benchmark harness",
            "source_commit": COMMIT,
            "metrics": metrics,
        },
    }


class GeometryPackageEvidenceTests(unittest.TestCase):
    def test_valid_join(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_source_commit_binding_is_required(self):
        value = manifest()
        value["native_evidence"]["source_commit"] = "d" * 40
        self.assertIn("native_evidence.source_commit must match package.source_commit", validator.validate_manifest(value))

    def test_software_renderer_is_rejected_even_with_metrics(self):
        value = manifest()
        value["native_evidence"]["renderer"] = "llvmpipe Vulkan"
        errors = validator.validate_manifest(value)
        self.assertTrue(any("software renderer is not native evidence" in error for error in errors))

    def test_unavailable_native_metric_does_not_close_gate(self):
        value = manifest()
        value["native_evidence"]["metrics"]["vram_bytes"]["available"] = False
        self.assertIn("native_evidence.metrics.vram_bytes.available must be true", validator.validate_manifest(value))

    def test_deterministic_census_scope_and_shape_are_checked(self):
        value = manifest()
        value["scene_census"]["measurement_scope"] = "headless_dummy"
        value["scene_census"]["total_triangles"] = -1
        errors = validator.validate_manifest(value)
        self.assertIn("scene_census.measurement_scope must be packaged_scene", errors)
        self.assertTrue(any("scene_census.total_triangles" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
