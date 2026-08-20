"""Focused tests for authored audio provenance/listening claims."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import authored_audio_asset_audit_validator as validator  # noqa: E402


def manifest() -> dict:
    return {
        "schema_version": 1,
        "audit_id": "audio-authored-v1",
        "source_commit": "b" * 40,
        "assets": [{
            "asset_id": "mudds.audio.music.station.v1",
            "paths": ["assets/audio/music/station_bed_drone_v1.wav"],
            "sha256": "a" * 64,
            "rights": {"status": "project_original", "source": "offline generator", "license": "project_original", "redistributable": True},
            "routing": {"bus": "Music", "status": "CAPTURED", "evidence": "artifacts/audio/music-route.json"},
            "human_listening": {"status": "PASS", "reviewer": "operator-1", "device": "reference-headphones", "notes": "No clipping; loop remains unobtrusive."},
        }],
    }


class AuthoredAudioAssetAuditTests(unittest.TestCase):
    def test_valid_authored_asset_audit(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_duplicate_identity_and_bad_digest_fail(self):
        value = manifest()
        value["assets"].append(copy.deepcopy(value["assets"][0]))
        value["assets"][1]["sha256"] = "not-a-digest"
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.assets[1].asset_id is duplicated", errors)
        self.assertIn("manifest.assets[1].sha256 must be a lowercase 64-character digest", errors)

    def test_rights_must_be_explicit_and_shippable(self):
        value = manifest()
        value["assets"][0]["rights"] = {"status": "unknown", "source": "", "license": "", "redistributable": False}
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.assets[0].rights.source is required", errors)
        self.assertIn("manifest.assets[0].rights.redistributable must be true for a shipped asset", errors)
        self.assertIn("manifest.assets[0].rights.status does not establish shipping rights", errors)

    def test_pass_requires_captured_route_and_reviewer(self):
        value = manifest()
        value["assets"][0]["routing"] = {"bus": "Music", "status": "DECLARED"}
        value["assets"][0]["human_listening"] = {"status": "PASS"}
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.assets[0].human_listening.reviewer is required for PASS", errors)
        self.assertIn("manifest.assets[0].human_listening.PASS requires CAPTURED routing evidence", errors)

    def test_incomplete_listening_requires_boundary_note(self):
        value = manifest()
        value["assets"][0]["human_listening"] = {"status": "OUTSTANDING"}
        errors = validator.validate_manifest(value)
        self.assertIn("manifest.assets[0].human_listening.notes is required while listening is incomplete", errors)


if __name__ == "__main__":
    unittest.main()
