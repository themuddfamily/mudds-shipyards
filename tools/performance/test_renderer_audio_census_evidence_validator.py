"""Focused tests for the combined renderer/audio evidence join."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import renderer_audio_census_evidence_validator as validator  # noqa: E402


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
    scene.update({metric: 100 for metric in validator.geometry.METRICS})
    audio_report = {
        "schema_version": 1,
        "scenario": "station_resident",
        "loaded_instance_count": 0,
        "settle_frames": 2,
        "measurement_scope": "scene_graph_audio_players_and_reachable_AudioStream_payloads",
        "measurement_fingerprint": "c" * 64,
        "source_commit": COMMIT,
        "totals": {"player_nodes": 4, "summed_max_polyphony_ceiling": 8},
        "players": [{"path": "Main/Audio", "bus": "SFX"}] * 4,
        "retained_streams": {"unique_count": 2, "payload_bytes": 4096, "unknown_payload_count": 0, "rows": [{}, {}]},
        "authority_exclusions": [
            "native_mixer_voice_count", "native_mixer_memory", "audio_thread_cpu_time",
            "process_ram", "frame_time",
        ],
    }
    native_metrics = {
        "draw_calls": {"available": True, "unit": "count", "value": 900, "source": "RenderDoc native capture"},
        "gpu_frame_time_ms": {"available": True, "unit": "milliseconds", "value": 8.0, "source": "GPU timestamp queries"},
        "vram_bytes": {"available": True, "unit": "bytes", "value": 1_000_000, "source": "DXGI adapter budget"},
        "native_mixer_voice_count": {"available": True, "unit": "count", "value": 3, "source": "WASAPI mixer trace"},
        "native_audio_memory_bytes": {"available": True, "unit": "bytes", "value": 200_000, "source": "WASAPI allocation trace"},
    }
    return {
        "schema_version": 1,
        "report_kind": validator.REPORT_KIND,
        "package": {
            "artifact_sha256": "d" * 64,
            "source_commit": COMMIT,
            "platform": "windows-x86_64",
            "renderer": "Vulkan Forward+",
            "resolution": "1920x1080",
            "profile": "target",
        },
        "scene_census": scene,
        "audio_census": audio_report,
        "native_evidence": {
            "available": True,
            "software_renderer": False,
            "platform": "windows-x86_64",
            "renderer": "NVIDIA RTX 3060 Vulkan Forward+",
            "hardware": "RTX 3060 / Ryzen 5600",
            "source": "native packaged benchmark harness",
            "source_commit": COMMIT,
            "metrics": native_metrics,
        },
    }


class RendererAudioCensusEvidenceTests(unittest.TestCase):
    def test_valid_join_exposes_headline_metrics_and_sources(self):
        value = manifest()
        self.assertEqual(validator.validate_manifest(value), [])
        joined = validator.joined_metrics(value)
        self.assertEqual(joined["triangles"], 100)
        self.assertEqual(joined["lights"], 100)
        self.assertEqual(joined["voices"], 8)
        self.assertEqual(joined["bytes"], 4096)
        self.assertEqual(joined["native_provenance"]["native_mixer_voice_count"], "WASAPI mixer trace")

    def test_software_renderer_is_rejected_even_with_metrics(self):
        value = manifest()
        value["native_evidence"]["renderer"] = "llvmpipe Vulkan"
        errors = validator.validate_manifest(value)
        self.assertTrue(any("software renderer is not native evidence" in error for error in errors))

    def test_software_audio_identity_is_rejected(self):
        value = manifest()
        value["native_evidence"]["software_renderer"] = True
        errors = validator.validate_manifest(value)
        self.assertTrue(any("software_renderer=true" in error for error in errors))

    def test_native_source_commit_must_join_package(self):
        value = manifest()
        value["native_evidence"]["source_commit"] = "e" * 40
        self.assertIn("native_evidence.source_commit must match package.source_commit", validator.validate_manifest(value))

    def test_missing_native_audio_metric_keeps_gate_closed(self):
        value = manifest()
        value["native_evidence"]["metrics"].pop("native_audio_memory_bytes")
        self.assertIn(
            "native_evidence.metrics.native_audio_memory_bytes must be an object",
            validator.validate_manifest(value),
        )

    def test_audio_and_geometry_reports_are_both_required(self):
        value = manifest()
        value["audio_census"]["totals"]["player_nodes"] = -1
        value["scene_census"]["lights"] = -1
        errors = validator.validate_manifest(value)
        self.assertTrue(any("audio_census.totals.player_nodes" in error for error in errors))
        self.assertTrue(any("scene_census.lights" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
