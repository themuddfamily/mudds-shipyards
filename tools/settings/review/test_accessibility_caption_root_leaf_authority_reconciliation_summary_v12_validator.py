import copy
import unittest

from tools.settings.review.accessibility_caption_root_leaf_authority_reconciliation_summary_v12_validator import (
    AUTHORITY,
    GENERATION,
    LEAF_AUTHORITY,
    LEAVES,
    SOURCE_SCHEMA,
    validate_summary,
)


def _summary() -> dict:
    leaves = [{
        "id": leaf_id,
        "source": "scripts/ui/caption_accessibility_contract.gd" if leaf_id == "contract" else ("scripts/ui/caption_presentation_service.gd" if leaf_id == "service" else "reports/caption-root-leaf-v12.json"),
        "authority": LEAF_AUTHORITY[leaf_id],
        "expected_behavior": f"The {leaf_id} authority leaf remains deterministic.",
    } for leaf_id in LEAVES]
    return {
        "schema": "accessibility_caption_root_leaf_authority_reconciliation_summary_v12_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-root-leaf-v12",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v12 reconciliation review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v12",
        "status": "planned",
        "digest": "0" * 64,
        "root_authority": "presentation_only",
        "root_generation": copy.deepcopy(GENERATION),
        "reconciliation_policy": "root_must_match_each_leaf",
        "authority": copy.deepcopy(AUTHORITY),
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "leaves": leaves,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionRootLeafAuthorityV12Tests(unittest.TestCase):
    def test_complete_summary_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_leaf_order_and_authority_reconciliation_are_exact(self):
        value = _summary()
        value["leaves"].reverse()
        value["leaves"][0]["authority"] = "audio"
        value["reconciliation_policy"] = "leaf_only"
        errors = validate_summary(value)
        self.assertTrue(any("leaves[0].authority" in error for error in errors))
        self.assertTrue(any("leaves must exactly" in error for error in errors))
        self.assertTrue(any("reconciliation_policy" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _summary()
        value["native_render_status"] = "planned"
        errors = validate_summary(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_root_generation_and_stale_authority_claims_fail_closed(self):
        value = _summary()
        value["root_generation"]["reset_step"] = 2
        value["authority"]["settings_authority"] = True
        value["settings_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_summary(value)
        self.assertTrue(any("root_generation must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("settings_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _summary()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/root-leaf-v12.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["leaves"] = []
        value["root_generation"] = []
        errors = validate_summary(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("exactly three ordered" in error for error in errors))
        self.assertTrue(any("root_generation must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
