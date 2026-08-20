"""Focused tests for the audio mix/listening claim-safety gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mix_listening_audit_validator as validator  # noqa: E402


def manifest() -> dict:
    return {
        "schema_version": 1,
        "build_label": "v0.12-candidate",
        "source_commit": "a" * 40,
        "measurement": {
            "backend": "native_output",
            "device": "headphones-reference",
            "sample_rate_hz": 48000,
            "duration_seconds": 30.0,
        },
        "bus_balance": {
            "status": "NATIVE_CAPTURED",
            "evidence": "artifacts/audio/mix-capture.json",
            "buses": [
                {"name": "Music", "observed_peak_dbfs": -8.0, "target_peak_dbfs": -8.0, "tolerance_db": 1.0},
                {"name": "Ambience", "observed_peak_dbfs": -10.5, "target_peak_dbfs": -10.0, "tolerance_db": 1.0},
            ],
        },
        "voice_ceiling": {"declared": 56, "observed_peak": 18, "evidence": "artifacts/audio/native-voice-count.json"},
        "human_listening": {
            "status": "PASS",
            "reviewer": "operator-1",
            "device": "headphones-reference",
            "mix_levels": ["quiet", "nominal", "loud"],
            "distances": ["near", "far"],
            "notes": "Cues remain distinct and no clipping was heard.",
        },
    }


class MixListeningAuditValidatorTests(unittest.TestCase):
    def test_valid_native_audit(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_dummy_audio_cannot_claim_native_balance_or_listening(self):
        value = copy.deepcopy(manifest())
        value["measurement"]["backend"] = "dummy"
        value["measurement"].pop("device")
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.bus_balance.NATIVE_CAPTURED requires native_output measurement", errors)
        self.assertIn("manifest.human_listening.PASS requires native_output measurement", errors)

    def test_voice_overrun_and_out_of_tolerance_are_reported(self):
        value = copy.deepcopy(manifest())
        value["voice_ceiling"]["observed_peak"] = 57
        value["bus_balance"]["buses"][0]["observed_peak_dbfs"] = -5.0
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.voice_ceiling.observed_peak exceeds declared ceiling", errors)
        self.assertIn("manifest.bus_balance.buses[0].observed_peak_dbfs is outside its target tolerance", errors)

    def test_incomplete_listening_requires_status_notes(self):
        value = copy.deepcopy(manifest())
        value["human_listening"] = {"status": "OUTSTANDING"}
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.human_listening.notes is required while listening is incomplete", errors)

    def test_duplicate_bus_and_bad_capture_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["bus_balance"]["buses"].append(copy.deepcopy(value["bus_balance"]["buses"][0]))
        value["bus_balance"]["evidence"] = ""
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.bus_balance.evidence is required for native capture", errors)
        self.assertIn("manifest.bus_balance.buses[2].name is duplicated", errors)


if __name__ == "__main__":
    unittest.main()
