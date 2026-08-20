import unittest

from tools.settings.review.accessibility_caption_stale_authority_summary_digest_v5_validator import (
    KEY_POLICY,
    NORMALIZED_SECTIONS,
    SOURCE_SCHEMA,
    VALUE_POLICY,
    validate_digest,
)


def _digest() -> dict:
    return {
        "schema": "accessibility_caption_stale_authority_summary_digest_v5_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-digest-v5",
        "summary_path": "reports/caption-stale-authority-summary.json",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v5 digest review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "algorithm": "sha256",
        "scope": "summary_authority_generation_only",
        "key_policy": KEY_POLICY,
        "value_policy": VALUE_POLICY,
        "version": 5,
        "status": "planned",
        "digest": "0" * 64,
        "normalized_sections": list(NORMALIZED_SECTIONS),
        "null_policy": "null_disallowed",
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "evidence": None,
    }


class AccessibilityCaptionStaleAuthoritySummaryDigestV5Tests(unittest.TestCase):
    def test_complete_v5_envelope_keeps_gate_open(self):
        self.assertEqual(validate_digest(_digest()), [])

    def test_normalization_policies_and_version_are_exact(self):
        value = _digest()
        value["key_policy"] = "insertion_order"
        value["value_policy"] = "arbitrary"
        value["version"] = 4
        value["null_policy"] = "null_allowed"
        errors = validate_digest(value)
        self.assertTrue(any("key_policy" in error for error in errors))
        self.assertTrue(any("value_policy" in error for error in errors))
        self.assertTrue(any("version must" in error for error in errors))
        self.assertTrue(any("null_policy must" in error for error in errors))

    def test_sections_and_scope_are_exact(self):
        value = _digest()
        value["normalized_sections"] = value["normalized_sections"][:-1]
        value["scope"] = "all_files"
        errors = validate_digest(value)
        self.assertTrue(any("normalized_sections must exactly" in error for error in errors))
        self.assertTrue(any("scope must" in error for error in errors))

    def test_digest_cannot_claim_verification_or_human_completion(self):
        value = _digest()
        value["digest_verified"] = True
        value["human_review_performed"] = True
        value["native_render_status"] = "observed"
        errors = validate_digest(value)
        self.assertTrue(any("digest_verified" in error for error in errors))
        self.assertTrue(any("human_review_performed" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))

    def test_digest_format_and_authority_fail_closed(self):
        value = _digest()
        value["digest"] = "bad"
        value["audio_authority"] = True
        value["evidence"] = [{"kind": "report", "path": "reports/digest-v5.json", "sha256": "bad"}]
        errors = validate_digest(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _digest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["normalized_sections"] = {}
        value["key_policy"] = []
        errors = validate_digest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("normalized_sections must exactly" in error for error in errors))
        self.assertTrue(any("key_policy" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
