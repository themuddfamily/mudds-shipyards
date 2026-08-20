import copy
import unittest

from tools.settings.review.accessibility_caption_authority_digest_provenance_summary_v9_validator import (
    AUTHORITY,
    GENERATION,
    PROVENANCE_FIELDS,
    SOURCE_SCHEMA,
    validate_summary,
)


def _summary() -> dict:
    provenance = {
        "source_revision": "working-tree-caption-provenance-v9",
        "source_schema": SOURCE_SCHEMA,
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "summary_path": "reports/caption-authority-provenance-v9.json",
    }
    return {
        "schema": "accessibility_caption_authority_digest_provenance_summary_v9_evidence_v1",
        "provenance": provenance,
        "source_schema": SOURCE_SCHEMA,
        "source_revision": provenance["source_revision"],
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v9 provenance review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v9",
        "status": "planned",
        "digest": "0" * 64,
        "generation": copy.deepcopy(GENERATION),
        "authority": copy.deepcopy(AUTHORITY),
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionAuthorityDigestProvenanceV9Tests(unittest.TestCase):
    def test_complete_summary_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_provenance_fields_and_source_paths_are_exact(self):
        value = _summary()
        value["provenance"]["service_source"] = "other.gd"
        value["provenance"]["contract_source"] = "other.gd"
        value["provenance"]["extra"] = "bad"
        errors = validate_summary(value)
        self.assertTrue(any("provenance must exactly" in error for error in errors))
        self.assertTrue(any("provenance.service_source" in error for error in errors))
        self.assertTrue(any("provenance.contract_source" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _summary()
        value["native_render_status"] = "planned"
        errors = validate_summary(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_generation_authority_and_stale_claims_are_exact(self):
        value = _summary()
        value["generation"]["reset_step"] = 2
        value["authority"]["audio_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_summary(value)
        self.assertTrue(any("generation must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _summary()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/provenance-v9.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["provenance"] = []
        value["authority"] = []
        errors = validate_summary(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("provenance must be an object" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
