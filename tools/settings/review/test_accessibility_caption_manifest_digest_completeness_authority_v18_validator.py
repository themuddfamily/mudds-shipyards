import copy
import unittest

from tools.settings.review.accessibility_caption_manifest_digest_completeness_authority_v18_validator import (
    AUTHORITY,
    COMPLETENESS,
    REQUIRED_INPUTS,
    SOURCE_SCHEMA,
    validate_manifest,
)


def _manifest() -> dict:
    return {
        "schema": "accessibility_caption_manifest_digest_completeness_authority_v18_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-completeness-v18",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v18 completeness review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "digest_generated": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v18",
        "digest_scope": "manifest_digest_completeness_authority",
        "status": "planned",
        "digest": "0" * 64,
        "required_inputs": list(REQUIRED_INPUTS),
        "completeness": copy.deepcopy(COMPLETENESS),
        "generation_policy": "monotonic_reset_increment",
        "stale_policy": "reject_less_or_greater_generation",
        "authority": copy.deepcopy(AUTHORITY),
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionManifestDigestCompletenessV18Tests(unittest.TestCase):
    def test_complete_manifest_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_required_inputs_and_completeness_are_exact(self):
        value = _manifest()
        value["required_inputs"] = value["required_inputs"][:-1]
        value["completeness"]["missing_count"] = 1
        errors = validate_manifest(value)
        self.assertTrue(any("required_inputs must exactly" in error for error in errors))
        self.assertTrue(any("completeness must exactly" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _manifest()
        value["native_render_status"] = "planned"
        errors = validate_manifest(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_stale_and_authority_boundaries_fail_closed(self):
        value = _manifest()
        value["stale_policy"] = "accept_old"
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_manifest(value)
        self.assertTrue(any("stale_policy must" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _manifest()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/completeness-v18.json", "sha256": "bad"}]
        errors = validate_manifest(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _manifest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["required_inputs"] = {}
        value["completeness"] = []
        errors = validate_manifest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("required_inputs must exactly" in error for error in errors))
        self.assertTrue(any("completeness must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
