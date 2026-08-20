"""Focused tests for audio voice-ceiling evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_voice_ceiling_evidence_validator as validator  # noqa: E402


def scenario(name: str) -> dict:
    return {"name": name, "evidence": f"artifacts/audio/{name}-voices.json", "families": [{"name": family, "declared_ceiling": 8, "observed_peak": 2} for family in sorted(validator.FAMILIES)]}


def report() -> dict:
    return {"schema": "audio_voice_ceiling_evidence_v1", "revision": "a" * 40, "evidence_bundle": "artifacts/audio/voice-ceilings.json", "measurement_scope": "scene_graph", "native_mixer_status": "OPEN", "claim": "AUTOMATED_CEILING_ONLY", "boundary_note": "Scene graph ceilings do not establish native mixer voices.", "scenarios": [scenario(name) for name in sorted(validator.REQUIRED_SCENARIOS)]}


class AudioVoiceCeilingEvidenceTests(unittest.TestCase):
    def test_complete_scenario_ceiling_report(self):
        self.assertEqual(validator.validate_report(report()), [])

    def test_overrun_and_missing_family_are_rejected(self):
        value = copy.deepcopy(report())
        value["scenarios"][0]["families"][0]["observed_peak"] = 9
        value["scenarios"][1]["families"] = value["scenarios"][1]["families"][:-1]
        errors = validator.validate_report(value)
        self.assertIn("scenarios[0].families[0].observed_peak exceeds declared_ceiling", errors)
        self.assertTrue(any("families must cover" in error for error in errors))

    def test_required_scenario_coverage_is_explicit(self):
        value = copy.deepcopy(report())
        value["scenarios"] = value["scenarios"][:-1]
        errors = validator.validate_report(value)
        self.assertIn("scenarios must cover: station", errors)

    def test_native_mixer_claim_is_blocked(self):
        value = copy.deepcopy(report())
        value["native_mixer_status"] = "OBSERVED"
        errors = validator.validate_report(value)
        self.assertIn("native_mixer_status must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
