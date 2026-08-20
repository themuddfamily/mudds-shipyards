import copy
import unittest

from tools.settings.review.accessibility_caption_reconciliation_manifest_authority_v13_validator import (
    AUTHORITY,
    MANIFEST_IDS,
    MANIFEST_RULES,
    SOURCE_SCHEMA,
    validate_manifest,
)


def _manifest() -> dict:
    entries = [{
        "id": entry_id,
        "source": MANIFEST_RULES[entry_id]["source"],
        "authority": MANIFEST_RULES[entry_id]["authority"],
        "generation_scope": MANIFEST_RULES[entry_id]["generation_scope"],
        "stale_policy": MANIFEST_RULES[entry_id]["stale_policy"],
        "expected_behavior": f"The {entry_id} reconciliation manifest entry remains deterministic.",
    } for entry_id in MANIFEST_IDS]
    return {
        "schema": "accessibility_caption_reconciliation_manifest_authority_v13_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-manifest-v13",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v13 manifest review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v13",
        "status": "planned",
        "digest": "0" * 64,
        "generation_owner": "caption-presentation-service",
        "global_stale_policy": "reject_less_or_greater_generation",
        "manifest_authority": "root_reconciles_all_entries",
        "authority": copy.deepcopy(AUTHORITY),
        "manifest": entries,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionReconciliationManifestV13Tests(unittest.TestCase):
    def test_complete_manifest_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_manifest_order_and_rules_are_exact(self):
        value = _manifest()
        value["manifest"].reverse()
        value["manifest"][0]["stale_policy"] = "accept_old"
        errors = validate_manifest(value)
        self.assertTrue(any("manifest must exactly" in error for error in errors))
        self.assertTrue(any("manifest[0].stale_policy" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _manifest()
        value["native_render_status"] = "planned"
        errors = validate_manifest(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_authority_and_stale_boundaries_fail_closed(self):
        value = _manifest()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["global_stale_policy"] = "accept_old"
        errors = validate_manifest(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))
        self.assertTrue(any("global_stale_policy" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _manifest()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/manifest-v13.json", "sha256": "bad"}]
        errors = validate_manifest(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _manifest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["manifest"] = []
        value["authority"] = []
        errors = validate_manifest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("exactly three ordered" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
