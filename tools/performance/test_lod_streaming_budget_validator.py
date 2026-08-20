import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lod_streaming_budget_validator as validator  # noqa: E402


def report():
    return {
        "schema_version": 1, "scenario": "planetary_surface", "sample_frames": 120,
        "measurement_scope": "planetary_streamed_tiles_and_process_resident_memory",
        "tiles": {"resident_count": 8, "loaded_count": 12},
        "memory": {"resident_bytes": 8_000_000, "loaded_bytes": 12_000_000, "unknown_bytes": 0},
        "native_provenance": {"execution_mode": "native_windows", "platform": "Windows x64",
                              "executable_sha256": "a" * 64, "capture_id": "lod-20260820-01"},
        "fabricated_metrics": False,
        "metric_status": {metric: "measured" for metric in validator._METRICS},
        "authority_exclusions": ["gpu_memory", "native_frame_time", "terrain_generation", "fabricated_metrics"],
    }


def budgets():
    return {"lod_streaming_budgets": {"max_resident_tiles": 8, "max_loaded_tiles": 12,
                                      "max_resident_bytes": 8_000_000, "max_loaded_bytes": 12_000_000}}


class LodStreamingBudgetTests(unittest.TestCase):
    def test_valid_native_report(self):
        self.assertEqual(validator.validate_budget(report(), budgets()), [])

    def test_tile_and_memory_overruns_are_reported(self):
        value = report(); value["tiles"]["loaded_count"] = 13; value["memory"]["loaded_bytes"] = 13_000_000
        errors = validator.validate_budget(value, budgets())
        self.assertIn("LOD/streaming loaded_tiles exceeds budget (13 > 12)", errors)
        self.assertIn("LOD/streaming loaded_bytes exceeds budget (13000000 > 12000000)", errors)

    def test_fabricated_or_unknown_metrics_fail_closed(self):
        value = copy.deepcopy(report()); value["fabricated_metrics"] = True; value["memory"]["unknown_bytes"] = 1
        errors = validator.validate_budget(value, budgets())
        self.assertIn("report.fabricated_metrics must be false", errors)
        self.assertIn("report.memory.unknown_bytes must be zero; unknown bytes cannot pass a ceiling", errors)

    def test_native_provenance_is_required(self):
        value = copy.deepcopy(report()); del value["native_provenance"]["executable_sha256"]
        errors = validator.validate_budget(value, budgets())
        self.assertIn("report.native_provenance.executable_sha256 must be a lowercase SHA-256", errors)

    def test_invalid_relationship_and_missing_budget_fail_closed(self):
        value = copy.deepcopy(report()); value["tiles"]["resident_count"] = 20
        errors = validator.validate_budget(value, {})
        self.assertIn("report.tiles.resident_count cannot exceed loaded_count", errors)
        self.assertIn("LOD/streaming budget max_resident_tiles must be a non-negative integer", errors)


if __name__ == "__main__":
    unittest.main()
