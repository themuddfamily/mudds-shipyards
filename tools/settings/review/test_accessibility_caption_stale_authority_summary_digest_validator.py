import unittest

from tools.settings.review.accessibility_caption_stale_authority_summary_digest_validator import (
    DIGEST_FIELDS,
    REQUIRED_SECTIONS,
    SOURCE_SUMMARY_SCHEMA,
    validate_digest,
)


def _digest() -> dict:
    return {
        "schema": "accessibility_caption_stale_authority_summary_digest_evidence_v1",
        "source_summary_schema": SOURCE_SUMMARY_SCHEMA,
        "source_revision": "working-tree-caption-stale-authority-digest",
        "summary_path": "reports/caption-stale-authority-summary.json",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human digest review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "digest_algorithm": "sha256",
        "digest_scope": "canonical_summary_fields",
        "digest_status": "planned",
        "summary_digest": "0" * 64,
        "covered_fields": list(DIGEST_FIELDS),
        "covered_sections": list(REQUIRED_SECTIONS),
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "evidence": None,
    }


class AccessibilityCaptionStaleAuthoritySummaryDigestTests(unittest.TestCase):
    def test_complete_planned_digest_keeps_gate_open(self):
        self.assertEqual(validate_digest(_digest()), [])

    def test_algorithm_scope_and_digest_format_are_exact(self):
        value = _digest()
        value["digest_algorithm"] = "sha1"
        value["digest_scope"] = "all_files"
        value["summary_digest"] = "bad"
        errors = validate_digest(value)
        self.assertTrue(any("digest_algorithm" in error for error in errors))
        self.assertTrue(any("digest_scope" in error for error in errors))
        self.assertTrue(any("summary_digest" in error for error in errors))

    def test_covered_fields_and_sections_are_exact(self):
        value = _digest()
        value["covered_fields"] = value["covered_fields"][:-1]
        value["covered_sections"] = ["authority"]
        errors = validate_digest(value)
        self.assertTrue(any("covered_fields must exactly" in error for error in errors))
        self.assertTrue(any("covered_sections must exactly" in error for error in errors))

    def test_digest_cannot_claim_verification_or_human_completion(self):
        value = _digest()
        value["digest_verified"] = True
        value["human_review_performed"] = True
        value["native_render_status"] = "observed"
        errors = validate_digest(value)
        self.assertTrue(any("digest_verified" in error for error in errors))
        self.assertTrue(any("human_review_performed" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))

    def test_authority_roster_and_evidence_digest_fail_closed(self):
        value = _digest()
        value["audio_playback"] = True
        value["evidence"] = [{"kind": "report", "path": "reports/digest.json", "sha256": "bad"}]
        errors = validate_digest(value)
        self.assertTrue(any("audio_playback must be false" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _digest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["covered_fields"] = {}
        value["covered_sections"] = []
        errors = validate_digest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("covered_fields must exactly" in error for error in errors))
        self.assertTrue(any("covered_sections must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
