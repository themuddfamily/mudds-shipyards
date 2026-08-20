"""Focused tests for native performance/audio observation evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import native_performance_audio_observation_validator as validator  # noqa: E402


METRICS = {metric: {"available": False, "value": None, "source": "not-run"} for metric in validator.REQUIRED_METRICS}


def record() -> dict:
    return {
        "schema": "native_performance_audio_observation_v1",
        "source": {"revision": "a" * 40, "dirty": False},
        "target_hardware": {"status": "OPEN", "platform": "Windows 11 target", "cpu": "reference CPU", "gpu": "reference GPU", "audio_device": "reference output"},
        "claim": "SCHEMA_ONLY",
        "boundary_note": "No native benchmark or audio observation was run on this host.",
        "scenarios": [{"name": name, "evidence": f"artifacts/performance/{name}.json", "observations": copy.deepcopy(METRICS)} for name in sorted(validator.REQUIRED_SCENARIOS)],
    }


class NativePerformanceAudioObservationTests(unittest.TestCase):
    def test_open_schema_record_is_valid_without_measurements(self):
        self.assertEqual(validator.validate_record(record()), [])

    def test_required_scenarios_and_metrics_are_explicit(self):
        value = record()
        value["scenarios"] = value["scenarios"][:1]
        value["scenarios"][0]["observations"].pop("audio_native_voices")
        errors = validator.validate_record(value)
        self.assertIn("scenarios must cover station_route, combat_route, and return_reentry", errors)
        self.assertIn("scenarios[0].observations missing audio_native_voices", errors)

    def test_unavailable_metric_cannot_have_value(self):
        value = record()
        value["scenarios"][0]["observations"]["frame_time_ms"]["value"] = 16.7
        errors = validator.validate_record(value)
        self.assertIn("scenarios[0].observations.frame_time_ms.value must be null when unavailable", errors)

    def test_native_claim_requires_observed_target(self):
        value = record()
        value["claim"] = "NATIVE_OBSERVED"
        errors = validator.validate_record(value)
        self.assertIn("NATIVE_OBSERVED requires target_hardware.status OBSERVED", errors)


if __name__ == "__main__":
    unittest.main()
