"""Focused tests for audio bus/polyphony budget evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_bus_polyphony_evidence_validator as validator  # noqa: E402


def report() -> dict:
    return {
        "schema": "audio_bus_polyphony_evidence_v1",
        "source": {"revision": "a" * 40, "evidence_path": "artifacts/audio/scene-graph-ceiling.json"},
        "measurement_backend": "scene_graph",
        "native_mixer_status": "OPEN",
        "claim": "AUTOMATED_BUDGET_ONLY",
        "boundary_note": "Scene graph ceilings do not establish native mixer voice count or audibility.",
        "buses": [{"name": name, "declared_polyphony": 16, "observed_peak_polyphony": 4, "evidence": f"artifacts/audio/{name.lower()}-voices.json", "native_observed": False} for name in sorted(validator.REQUIRED_BUSES)],
    }


class AudioBusPolyphonyEvidenceTests(unittest.TestCase):
    def test_valid_automated_budget_record(self):
        self.assertEqual(validator.validate_report(report()), [])

    def test_overrun_and_native_claim_are_rejected(self):
        value = copy.deepcopy(report())
        value["buses"][0]["observed_peak_polyphony"] = 17
        value["claim"] = "NATIVE_MIXER_OBSERVED"
        errors = validator.validate_report(value)
        self.assertIn("buses[0].observed_peak_polyphony exceeds declared_polyphony", errors)
        self.assertIn("NATIVE_MIXER_OBSERVED is not allowed by this non-native report", errors)

    def test_all_required_buses_and_evidence_are_required(self):
        value = copy.deepcopy(report())
        value["buses"] = value["buses"][:-1]
        value["buses"][0]["evidence"] = ""
        errors = validator.validate_report(value)
        self.assertIn("buses[0].evidence is required", errors)
        self.assertIn("buses must cover: UI", errors)

    def test_native_observed_flag_must_remain_false(self):
        value = copy.deepcopy(report())
        value["buses"][0]["native_observed"] = True
        errors = validator.validate_report(value)
        self.assertIn("buses[0].native_observed must be false for this non-native report", errors)


if __name__ == "__main__":
    unittest.main()
