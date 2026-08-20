import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import geometry_package_evidence_validator as geometry_package  # noqa: E402
import performance_budget_rollup_validator as validator  # noqa: E402
import test_geometry_package_evidence_validator as geometry_fixture  # noqa: E402
import test_renderer_audio_census_evidence_validator as renderer_fixture  # noqa: E402
import test_startup_teardown_performance_validator as startup_fixture  # noqa: E402


COMMIT = "a" * 40


def rollup() -> dict:
    geometry = geometry_fixture.manifest()
    renderer = renderer_fixture.manifest()
    startup = startup_fixture.report()
    startup["source"]["git_sha"] = COMMIT
    lod_report = {
        "schema_version": 1, "scenario": "planetary_surface", "sample_frames": 120,
        "measurement_scope": "planetary_streamed_tiles_and_process_resident_memory",
        "tiles": {"resident_count": 8, "loaded_count": 12},
        "memory": {"resident_bytes": 8_000_000, "loaded_bytes": 12_000_000, "unknown_bytes": 0},
        "native_provenance": {"execution_mode": "native_windows", "platform": "Windows x64",
                              "executable_sha256": "b" * 64, "capture_id": "lod-01"},
        "fabricated_metrics": False,
        "metric_status": {metric: "measured" for metric in ("resident_tiles", "loaded_tiles", "resident_bytes", "loaded_bytes")},
        "authority_exclusions": ["gpu_memory", "native_frame_time", "terrain_generation", "fabricated_metrics"],
    }
    native = {name: {"available": True, "unit": unit, "value": 1, "source": "native capture"}
              for name, unit in validator.native_collector.METRIC_FIELDS.items()}
    return {"schema_version": 1, "report_kind": validator.REPORT_KIND,
            "provenance": {"source_commit": COMMIT, "platform": "windows-x86_64",
                           "capture_id": "rollup-01", "artifact_sha256": "c" * 64},
            "reports": {"geometry_evidence": geometry, "renderer_audio_evidence": renderer,
                        "startup_teardown": startup, "lod_streaming": lod_report,
                        "native_metrics": native}}


class PerformanceBudgetRollupTests(unittest.TestCase):
    @staticmethod
    def target() -> dict:
        return {"lod_target": {"lod_streaming_budgets": {
            "max_resident_tiles": 8, "max_loaded_tiles": 12,
            "max_resident_bytes": 8_000_000, "max_loaded_bytes": 12_000_000,
        }}}

    def test_valid_join_and_summary(self):
        value = rollup()
        # Make the two package artifacts/source identities agree with rollup.
        value["reports"]["geometry_evidence"]["package"]["artifact_sha256"] = "c" * 64
        value["reports"]["renderer_audio_evidence"]["package"]["artifact_sha256"] = "c" * 64
        self.assertEqual(validator.validate_rollup(value, self.target()), [])
        self.assertEqual(validator.summarize(value)["source_commit"], COMMIT)

    def test_missing_native_provenance_fails_closed(self):
        value = rollup()
        value["provenance"].pop("capture_id")
        value["reports"]["native_metrics"]["draw_calls"]["source"] = ""
        errors = validator.validate_rollup(value, self.target())
        self.assertIn("provenance.capture_id is required", errors)
        self.assertIn("native_metrics.draw_calls.source is required", errors)

    def test_missing_report_and_unavailable_metric_fail_closed(self):
        value = rollup()
        value["reports"].pop("lod_streaming")
        value["reports"]["native_metrics"]["vram_bytes"]["available"] = False
        errors = validator.validate_rollup(value, self.target())
        self.assertIn("reports.lod_streaming is required", errors)
        self.assertIn("native_metrics.vram_bytes.available must be true", errors)

    def test_source_commit_must_join_every_report(self):
        value = rollup()
        value["reports"]["startup_teardown"]["source"]["git_sha"] = "f" * 40
        self.assertIn("provenance.source_commit must match startup source commit", validator.validate_rollup(value, self.target()))


if __name__ == "__main__":
    unittest.main()
