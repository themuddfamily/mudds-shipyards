import unittest

from tools.audio.audio_memory_integration_validator import validate_manifest


def valid_manifest() -> dict:
    return {
        "schema_version": 1,
        "audit_id": "audio-memory-v1",
        "build_label": "candidate-2026-08-20",
        "source_commit": "abc1234",
        "voice_ceiling": {"declared": 56, "observed_peak": 42, "evidence": "dummy-census.json"},
        "stream_memory": {
            "retained_unique_streams": 97,
            "decoded_payload_bytes": 4052420,
            "declared_bytes_ceiling": 5000000,
            "evidence": "audio-census.json",
        },
        "bus_routing": {
            "status": "DECLARED",
            "buses": [
                {"name": "Music", "target": "music_volume", "status": "DECLARED"},
                {"name": "SFX", "target": "sfx_volume", "status": "DECLARED"},
            ],
        },
        "native_provenance": {"status": "NOT_RUN", "notes": "Native device capture remains open."},
        "human_listening": {"status": "OUTSTANDING", "notes": "Awaiting real-output listening pass."},
    }


class AudioMemoryIntegrationValidatorTest(unittest.TestCase):
    def test_valid_dummy_census_keeps_native_and_listening_open(self):
        self.assertEqual(validate_manifest(valid_manifest()), [])

    def test_rejects_voice_and_decoded_byte_overages(self):
        manifest = valid_manifest()
        manifest["voice_ceiling"]["observed_peak"] = 57
        manifest["stream_memory"]["decoded_payload_bytes"] = 5000001
        errors = validate_manifest(manifest)
        self.assertIn("manifest.voice_ceiling.observed_peak exceeds declared ceiling", errors)
        self.assertIn("manifest.stream_memory.decoded_payload_bytes exceeds declared ceiling", errors)

    def test_native_capture_requires_device_and_evidence(self):
        manifest = valid_manifest()
        manifest["native_provenance"] = {"status": "CAPTURED", "backend": "native_output"}
        errors = validate_manifest(manifest)
        self.assertIn("manifest.native_provenance.device is required", errors)
        self.assertIn("manifest.native_provenance.evidence is required", errors)

    def test_captured_routing_and_pass_require_native_provenance(self):
        manifest = valid_manifest()
        manifest["bus_routing"]["status"] = "CAPTURED"
        manifest["bus_routing"]["buses"][0]["status"] = "CAPTURED"
        manifest["bus_routing"]["buses"][0]["evidence"] = "capture.wav"
        manifest["bus_routing"]["buses"][1]["status"] = "CAPTURED"
        manifest["bus_routing"]["buses"][1]["evidence"] = "capture.wav"
        manifest["human_listening"] = {"status": "PASS", "reviewer": "A", "device": "B", "notes": "C", "mix_levels": ["low"], "distances": ["near"]}
        errors = validate_manifest(manifest)
        self.assertIn("manifest.bus_routing.CAPTURED requires captured native provenance", errors)
        self.assertIn("manifest.human_listening.PASS requires captured native provenance", errors)

    def test_duplicate_bus_and_incomplete_listening_are_rejected(self):
        manifest = valid_manifest()
        manifest["bus_routing"]["buses"].append({"name": "Music", "target": "music_volume", "status": "DECLARED"})
        manifest["human_listening"] = {"status": "PASS", "reviewer": "A", "device": "B", "notes": "C", "mix_levels": [], "distances": ["near"]}
        errors = validate_manifest(manifest)
        self.assertIn("manifest.bus_routing.buses[2].name is duplicated", errors)
        self.assertIn("manifest.human_listening.mix_levels must be a non-empty unique array", errors)


if __name__ == "__main__":
    unittest.main()
