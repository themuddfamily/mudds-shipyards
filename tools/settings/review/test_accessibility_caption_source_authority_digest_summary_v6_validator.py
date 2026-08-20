import unittest

from tools.settings.review.accessibility_caption_source_authority_digest_summary_v6_validator import (
    AUTHORITY,
    GENERATION,
    SOURCE_AUTHORITY_FIELDS,
    SOURCE_SCHEMA,
    validate_summary,
)


def _summary() -> dict:
    return {
        "schema": "accessibility_caption_source_authority_digest_summary_v6_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-source-authority-v6",
        "summary_path": "reports/caption-source-authority-summary.json",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v6 source/authority digest review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "digest_algorithm": "sha256",
        "digest_scope": "source_authority_summary",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v6",
        "status": "planned",
        "digest": "0" * 64,
        "source_authority_fields": list(SOURCE_AUTHORITY_FIELDS),
        "generation": dict(GENERATION),
        "authority": dict(AUTHORITY),
        "stale_payload_mutation": False,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionSourceAuthorityDigestV6Tests(unittest.TestCase):
    def test_complete_summary_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_native_render_must_remain_not_run(self):
        value = _summary()
        value["native_render_status"] = "planned"
        errors = validate_summary(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_source_fields_generation_and_authority_are_exact(self):
        value = _summary()
        value["source_authority_fields"] = value["source_authority_fields"][:-1]
        value["generation"]["reset_step"] = 2
        value["authority"]["audio_authority"] = True
        errors = validate_summary(value)
        self.assertTrue(any("source_authority_fields must exactly" in error for error in errors))
        self.assertTrue(any("generation must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))

    def test_stale_mutation_and_external_authority_fail_closed(self):
        value = _summary()
        value["stale_payload_mutation"] = True
        value["settings_authority"] = True
        errors = validate_summary(value)
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))
        self.assertTrue(any("settings_authority must be false" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _summary()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/source-authority-v6.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["generation"] = []
        value["authority"] = {}
        errors = validate_summary(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("generation must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
