"""Focused tests for music provenance/loop determinism evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import music_asset_determinism_evidence_validator as validator  # noqa: E402


def asset(index: int) -> dict:
    digest = (str(index) * 64)[:64]
    return {"asset_id": f"station-bed-{index}", "path": f"assets/audio/music/bed-{index}.wav", "sha256": digest, "regenerated_sha256": digest, "sample_rate_hz": 48000, "channels": 1, "frame_count": 384000, "loop_mode": "forward_seamless", "generation_evidence": f"artifacts/audio/music-generation-{index}.json", "loop_evidence": f"artifacts/audio/music-loop-{index}.json"}


def manifest() -> dict:
    return {"schema": "music_asset_determinism_evidence_v1", "revision": "a" * 40, "generator": "tools/audio/generate_station_music_v1.py", "generator_version": "v1", "seed": 0, "evidence_bundle": "artifacts/audio/music-determinism.json", "human_audition": "OPEN", "audition_boundary": "No human audition has occurred.", "claim": "AUTOMATED_DETERMINISM_ONLY", "assets": [asset(1), asset(2)]}


class MusicAssetDeterminismEvidenceTests(unittest.TestCase):
    def test_valid_fixed_seed_music_manifest(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_seed_and_regenerated_digest_are_required(self):
        value = copy.deepcopy(manifest())
        value["seed"] = 7
        value["assets"][0]["regenerated_sha256"] = "c" * 64
        errors = validator.validate_manifest(value)
        self.assertIn("seed must be the fixed value 0", errors)
        self.assertIn("assets[0].regenerated_sha256 must match sha256", errors)

    def test_pcm_and_loop_contract_is_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["assets"][0]["channels"] = 2
        value["assets"][0]["sample_rate_hz"] = 44100
        value["assets"][0]["loop_mode"] = "one_shot"
        errors = validator.validate_manifest(value)
        self.assertIn("assets[0].channels must be mono (1)", errors)
        self.assertIn("assets[0].sample_rate_hz must be 48000", errors)
        self.assertIn("assets[0].loop_mode must be forward_seamless", errors)

    def test_human_audition_is_not_inferred(self):
        value = copy.deepcopy(manifest())
        value["human_audition"] = "PASS"
        errors = validator.validate_manifest(value)
        self.assertIn("human_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
