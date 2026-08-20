"""Focused tests for the renderer-independent audio budget gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_voice_budget_validator as validator  # noqa: E402


def report() -> dict:
    players = [
        {"path": "Music/Voice0", "class": "AudioStreamPlayer", "max_polyphony": 1},
        {"path": "Ship/Engine", "class": "AudioStreamPlayer3D", "max_polyphony": 2},
    ]
    return {
        "schema_version": 1,
        "scenario": "station_resident",
        "loaded_instance_count": 0,
        "settle_frames": 8,
        "measurement_scope": "scene_graph_audio_players_and_reachable_AudioStream_payloads",
        "totals": {"player_nodes": 2, "summed_max_polyphony_ceiling": 3},
        "players": players,
        "bus_split": {"Music": {"summed_max_polyphony_ceiling": 1}},
        "retained_streams": {
            "unique_count": 2,
            "payload_bytes": 2048,
            "unknown_payload_count": 0,
            "rows": [{"resource_path": "res://a.wav"}, {"resource_path": "res://b.wav"}],
        },
        "authority_exclusions": [
            "native_mixer_voice_count", "native_mixer_memory", "audio_thread_cpu_time",
            "process_ram", "frame_time",
        ],
        "measurement_fingerprint": "a" * 64,
    }


def budgets() -> dict:
    return {
        "audio_budgets": {
            "player_nodes": 2,
            "summed_max_polyphony_ceiling": 3,
            "retained_unique_streams": 2,
            "retained_payload_bytes": 2048,
            "per_bus": {"Music": 1},
        }
    }


class AudioVoiceBudgetValidatorTests(unittest.TestCase):
    def test_valid_census_and_budget(self):
        self.assertEqual(validator.validate_budget(report(), budgets()), [])

    def test_voice_and_memory_overruns_are_reported(self):
        value = report()
        value["totals"]["summed_max_polyphony_ceiling"] = 4
        value["retained_streams"]["payload_bytes"] = 4096
        errors = validator.validate_budget(value, budgets())
        self.assertIn("audio summed_max_polyphony_ceiling exceeds budget (4 > 3)", errors)
        self.assertIn("audio retained_payload_bytes exceeds budget (4096 > 2048)", errors)

    def test_per_bus_overrun_is_reported(self):
        value = report()
        value["bus_split"]["Music"]["summed_max_polyphony_ceiling"] = 2
        errors = validator.validate_budget(value, budgets())
        self.assertIn("audio bus Music polyphony exceeds budget (2 > 1)", errors)

    def test_missing_native_exclusion_fails_closed(self):
        value = copy.deepcopy(report())
        value["authority_exclusions"].remove("native_mixer_memory")
        errors = validator.validate_budget(value, budgets())
        self.assertIn("report.authority_exclusions missing native_mixer_memory", errors)

    def test_malformed_census_and_missing_budget_fail_closed(self):
        value = copy.deepcopy(report())
        value["totals"]["player_nodes"] = 1
        errors = validator.validate_budget(value, {})
        self.assertIn("report.totals.player_nodes does not match players length", errors)
        self.assertIn("audio budget player_nodes must be a non-negative integer", errors)


if __name__ == "__main__":
    unittest.main()
