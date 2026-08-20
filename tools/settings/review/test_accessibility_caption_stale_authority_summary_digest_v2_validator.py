import unittest

from tools.settings.review.accessibility_caption_stale_authority_summary_digest_v2_validator import (
    CANONICAL_ENCODING,
    CANONICAL_FIELDS,
    CANONICALIZATION_VERSION,
    SOURCE_SCHEMA,
    validate_digest,
)


def _digest() -> dict:
    return {
        "schema": "accessibility_caption_stale_authority_summary_digest_v2_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-digest-v2",
        "summary_path": "reports/caption-stale-authority-summary.json",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human digest canonicalization review or native render has been performed",
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
        "canonical_encoding": CANONICAL_ENCODING,
        "canonicalization_version": CANONICALIZATION_VERSION,
        "digest_scope": "canonical_summary_sections",
        "digest_status": "planned",
        "summary_digest": "0" * 64,
        "canonical_fields": list(CANONICAL_FIELDS),
        "field_presence": {key: True for key in CANONICAL_FIELDS},
        "evidence": None,
    }


class AccessibilityCaptionStaleAuthoritySummaryDigestV2Tests(unittest.TestCase):
    def test_complete_canonical_record_keeps_gate_open(self):
        self.assertEqual(validate_digest(_digest()), [])

    def test_encoding_version_and_scope_are_exact(self):
        value = _digest()
        value["canonical_encoding"] = "json_unsorted"
        value["canonicalization_version"] = 2
        value["digest_scope"] = "all_files"
        errors = validate_digest(value)
        self.assertTrue(any("canonical_encoding" in error for error in errors))
        self.assertTrue(any("canonicalization_version" in error for error in errors))
        self.assertTrue(any("digest_scope" in error for error in errors))

    def test_canonical_fields_and_presence_are_exact(self):
        value = _digest()
        value["canonical_fields"] = value["canonical_fields"][:-1]
        value["field_presence"]["gate"] = False
        errors = validate_digest(value)
        self.assertTrue(any("canonical_fields must exactly" in error for error in errors))
        self.assertTrue(any("field_presence must mark" in error for error in errors))

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
        value["summary_digest"] = "bad"
        value["audio_authority"] = True
        value["evidence"] = [{"kind": "report", "path": "reports/digest-v2.json", "sha256": "bad"}]
        errors = validate_digest(value)
        self.assertTrue(any("summary_digest must" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _digest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["canonical_fields"] = {}
        value["field_presence"] = []
        errors = validate_digest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("canonical_fields must exactly" in error for error in errors))
        self.assertTrue(any("field_presence must mark" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
