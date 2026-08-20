import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.geometry.visual_optimization_manifest import validate


class VisualOptimizationManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "before.png").write_bytes(b"before")
        (self.root / "after.png").write_bytes(b"after")

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        digest = lambda name: hashlib.sha256((self.root / name).read_bytes()).hexdigest()
        value = {
            "schema": "visual_optimization_manifest_v1",
            "human_inspection_status": "pending",
            "reviewer_required": "art director",
            "optimizations": [{
                "id": "berth_lighting",
                "viewpoint": "central berth / embodied player / 2560x1440",
                "captures": {"before": {"path": "before.png", "sha256": digest("before.png")},
                             "after": {"path": "after.png", "sha256": digest("after.png")}},
                "pixel_delta": {"metric": "mean_absolute_error", "value": 0.04,
                                "method": "linear-light RGB absolute difference"},
                "performance": {"metric": "frame_time_p95", "unit": "ms", "before": 18.0,
                                "after": 15.5, "direction": "lower_is_better",
                                "provenance": {"source": "benchmarks/berth.csv", "command": "capture_benchmark --berth",
                                                "hardware": "minimum GPU", "captured_at": "2026-08-20T10:00:00Z"}},
            }],
        }
        value.update(changes)
        path = self.root / "optimization.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_pair_is_ready_for_manual_inspection(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_approval_status_is_rejected(self):
        errors = validate(self.manifest(human_inspection_status="approved"))
        self.assertTrue(any("cannot claim approval" in error for error in errors))

    def test_capture_tamper_and_missing_viewpoint_fail(self):
        path = self.manifest()
        (self.root / "after.png").write_bytes(b"tampered")
        errors = validate(path)
        self.assertTrue(any("SHA-256" in error for error in errors))
        data = json.loads(path.read_text())
        data["optimizations"][0]["viewpoint"] = ""
        path.write_text(json.dumps(data))
        self.assertTrue(any("viewpoint is required" in error for error in validate(path)))

    def test_non_improving_metric_and_missing_provenance_fail(self):
        data_path = self.manifest()
        data = json.loads(data_path.read_text())
        performance = data["optimizations"][0]["performance"]
        performance["after"] = 20
        performance["provenance"].pop("command")
        data_path.write_text(json.dumps(data))
        errors = validate(data_path)
        self.assertTrue(any("does not improve" in error for error in errors))
        self.assertTrue(any("provenance.command" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
