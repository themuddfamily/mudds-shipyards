import unittest

from tools.settings.review.accessibility_caption_stale_authority_summary_digest_v3_validator import (
    ENVELOPE_FIELDS,
    SOURCE_SCHEMA,
    TYPE_POLICY,
    validate_digest,
)


def _digest() -> dict:
    return {
        "schema": "accessibility_caption_stale_authority_summary_digest_v3_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-digest-v3",
        "summary_path": "reports/caption-stale-authority-summary.json",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v3 digest review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "digest_algorithm": "sha256",
        "encoding": "json_utf8_sorted_keys_no_whitespace",
        "canonicalization_version": 3,
        "scope": "summary_authority_generation_only",
        "status": "planned",
        "digest": "0" * 64,
        "envelope_fields": list(ENVELOPE_FIELDS),
        "type_policy": dict(TYPE_POLICY),
        "null_policy": "null_disallowed_in_canonical_sections",
        "evidence": None,
    }


class AccessibilityCaptionStaleAuthoritySummaryDigestV3Tests(unittest.TestCase):
    def test_complete_v3_envelope_keeps_gate_open(self):
        self.assertEqual(validate_digest(_digest()), [])

    def test_encoding_scope_and_version_are_exact(self):
        value = _digest()
        value["encoding"] = "json_unsorted"
        value["scope"] = "all_files"
        value["canonicalization_version"] = 2
        errors = validate_digest(value)
        self.assertTrue(any("encoding must" in error for error in errors))
        self.assertTrue(any("scope must" in error for error in errors))
        self.assertTrue(any("canonicalization_version" in error for error in errors))

    def test_envelope_and_type_policies_are_exact(self):
        value = _digest()
        value["envelope_fields"] = value["envelope_fields"][:-1]
        value["type_policy"]["gate"] = "string"
        value["null_policy"] = "null_allowed"
        errors = validate_digest(value)
        self.assertTrue(any("envelope_fields must exactly" in error for error in errors))
        self.assertTrue(any("type_policy must exactly" in error for error in errors))
        self.assertTrue(any("null_policy must" in error for error in errors))

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
        value["evidence"] = [{"kind": "report", "path": "reports/digest-v3.json", "sha256": "bad"}]
        errors = validate_digest(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _digest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["envelope_fields"] = {}
        value["type_policy"] = []
        errors = validate_digest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("envelope_fields must exactly" in error for error in errors))
        self.assertTrue(any("type_policy must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
