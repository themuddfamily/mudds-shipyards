import unittest

from tools.settings.review.accessibility_caption_stale_authority_summary_digest_v4_validator import (
    CANONICALIZATION,
    INTEGRITY_FIELDS,
    SOURCE_SCHEMA,
    validate_digest,
)


def _digest() -> dict:
    summary_path = "reports/caption-stale-authority-summary.json"
    return {
        "schema": "accessibility_caption_stale_authority_summary_digest_v4_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-digest-v4",
        "summary_path": summary_path,
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v4 digest review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "algorithm": "sha256",
        "scope": "summary_authority_generation_only",
        "canonicalization": CANONICALIZATION,
        "status": "planned",
        "digest": "0" * 64,
        "integrity_fields": list(INTEGRITY_FIELDS),
        "source": {"schema": SOURCE_SCHEMA, "path": summary_path},
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "evidence": None,
    }


class AccessibilityCaptionStaleAuthoritySummaryDigestV4Tests(unittest.TestCase):
    def test_complete_v4_envelope_keeps_gate_open(self):
        self.assertEqual(validate_digest(_digest()), [])

    def test_integrity_algorithm_scope_and_canonicalization_are_exact(self):
        value = _digest()
        value["algorithm"] = "sha1"
        value["scope"] = "all_files"
        value["canonicalization"] = "other"
        errors = validate_digest(value)
        self.assertTrue(any("algorithm must" in error for error in errors))
        self.assertTrue(any("scope must" in error for error in errors))
        self.assertTrue(any("canonicalization must" in error for error in errors))

    def test_integrity_fields_and_source_are_exact(self):
        value = _digest()
        value["integrity_fields"] = value["integrity_fields"][:-1]
        value["source"]["schema"] = "other"
        errors = validate_digest(value)
        self.assertTrue(any("integrity_fields must exactly" in error for error in errors))
        self.assertTrue(any("source must identify" in error for error in errors))

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
        value["audio_playback"] = True
        value["evidence"] = [{"kind": "report", "path": "reports/digest-v4.json", "sha256": "bad"}]
        errors = validate_digest(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("audio_playback must be false" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _digest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["integrity_fields"] = {}
        value["source"] = []
        errors = validate_digest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("integrity_fields must exactly" in error for error in errors))
        self.assertTrue(any("source must identify" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
