"""Focused tests for native audio capture manifest claim boundaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import native_capture_manifest_validator as validator  # noqa: E402


def manifest() -> dict:
    return {
        "schema_version": 1,
        "capture_id": "native-audio-2026-08-20-01",
        "build_label": "v0.12-candidate",
        "source_commit": "a" * 40,
        "recorded_at_utc": "2026-08-20T12:00:00Z",
        "recording": {"backend": "native_output", "device": "reference-headphones", "os": "Windows 11", "gpu": "RTX reference", "audio_driver": "WASAPI", "sample_rate_hz": 48000, "channels": 2, "duration_seconds": 90.0},
        "capture": {"status": "CAPTURED", "artifact_path": "artifacts/audio/native-capture.wav", "sha256": "b" * 64, "evidence": "artifacts/audio/native-capture.json"},
        "scenarios": ["station_rest", "combat", "return_or_reentry"],
        "listening": {"status": "PASS", "reviewer": "operator-1", "device": "reference-headphones", "mix_levels": ["quiet", "nominal", "loud"], "speaker_positions": ["near", "far"], "notes": "No clipping, masking, or abrupt loop seam heard."},
    }


class NativeCaptureManifestTests(unittest.TestCase):
    def test_valid_native_capture_record(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_dummy_backend_and_bad_digest_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["recording"]["backend"] = "dummy"
        value["capture"]["sha256"] = "not-a-digest"
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.recording.backend must be native_output", errors)
        self.assertIn("manifest.capture.sha256 must be a lowercase 64-character digest for CAPTURED", errors)

    def test_incomplete_capture_keeps_listening_claim_open(self):
        value = copy.deepcopy(manifest())
        value["capture"] = {"status": "NOT_RUN", "notes": "Native device capture remains open."}
        value["listening"] = {"status": "OUTSTANDING", "notes": "Awaiting real output-device review."}
        self.assertEqual(validator.validate_manifest(value), [])

    def test_pass_requires_scenarios_matching_device_and_capture(self):
        value = copy.deepcopy(manifest())
        value["scenarios"] = ["station_rest"]
        value["listening"]["device"] = "other-device"
        value["capture"]["status"] = "FAILED"
        value["capture"]["notes"] = "Capture was not usable."
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.scenarios must cover station_rest, combat, and return_or_reentry", errors)
        self.assertIn("manifest.listening.PASS requires CAPTURED evidence", errors)
        self.assertIn("manifest.listening.device must match recording.device", errors)


if __name__ == "__main__":
    unittest.main()
