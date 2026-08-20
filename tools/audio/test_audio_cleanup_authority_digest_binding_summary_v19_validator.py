"""Focused tests for v19 cleanup authority/digest bindings."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_authority_digest_binding_summary_v19_validator as validator  # noqa: E402


def summary() -> dict:
    exclusions = ["gameplay_damage", "gameplay_phase", "reward"]
    digest = "a" * 64
    bindings = [{"binding_id": "binding-a", "manifest_sha256": digest, "authority_sha256": "b" * 64, "authority": "presentation_only", "authority_exclusions": exclusions, "evidence": "artifacts/audio/binding-a.json", "bound": True}, {"binding_id": "binding-b", "manifest_sha256": "c" * 64, "authority_sha256": "d" * 64, "authority": "presentation_only", "authority_exclusions": exclusions, "evidence": "artifacts/audio/binding-b.json", "bound": True}]
    return {"schema": "audio_cleanup_authority_digest_binding_summary_v19", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-binding-v19", "evidence_bundle": "artifacts/audio/binding-v19.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_AUTHORITY_DIGEST_BINDING_ONLY", "boundary_note": "Authority binding does not establish native audibility.", "bindings": bindings, "binding_count": 2, "consensus_manifest_sha256": digest, "binding_pass": True}


class AudioCleanupAuthorityBindingV19Tests(unittest.TestCase):
    def test_valid_authority_digest_bindings(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_and_exclusions_are_required(self):
        value = copy.deepcopy(summary())
        value["bindings"][0]["authority"] = "gameplay"
        value["bindings"][1]["authority_exclusions"] = ["gameplay_damage"]
        errors = validator.validate_summary(value)
        self.assertIn("bindings[0].authority must be presentation_only", errors)
        self.assertIn("bindings[1].authority_exclusions must include gameplay_damage, gameplay_phase, and reward", errors)

    def test_binding_count_and_digest_are_required(self):
        value = copy.deepcopy(summary())
        value["binding_count"] = 1
        value["consensus_manifest_sha256"] = "e" * 64
        errors = validator.validate_summary(value)
        self.assertIn("binding_count must match bindings length", errors)
        self.assertIn("consensus_manifest_sha256 must match a binding manifest_sha256", errors)

    def test_binding_identity_and_digest_formats_are_required(self):
        value = copy.deepcopy(summary())
        value["bindings"][1]["binding_id"] = value["bindings"][0]["binding_id"]
        value["bindings"][1]["authority_sha256"] = "bad"
        errors = validator.validate_summary(value)
        self.assertIn("bindings[1].binding_id is duplicated", errors)
        self.assertIn("bindings[1].authority_sha256 must be a lowercase 64-character digest", errors)


if __name__ == "__main__":
    unittest.main()
