import copy
import unittest

from tools.settings.review.accessibility_caption_lineage_root_authority_summary_v11_validator import (
    AUTHORITY,
    LINEAGE,
    ROOT,
    SOURCE_SCHEMA,
    validate_summary,
)


def _summary() -> dict:
    lineage = [{
        "stage": stage,
        "source": ROOT["source"] if stage == "contract" else ("scripts/ui/caption_presentation_service.gd" if stage == "service" else "reports/caption-lineage-root-v11.json"),
        "parent": "" if stage == "contract" else ("contract" if stage == "service" else "service"),
        "authority": "presentation_only" if stage != "summary" else "review_index_only",
    } for stage in LINEAGE]
    return {
        "schema": "accessibility_caption_lineage_root_authority_summary_v11_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-lineage-root-v11",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v11 lineage-root review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v11",
        "status": "planned",
        "digest": "0" * 64,
        "root": copy.deepcopy(ROOT),
        "authority": copy.deepcopy(AUTHORITY),
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "lineage": lineage,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionLineageRootAuthorityV11Tests(unittest.TestCase):
    def test_complete_summary_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_root_authority_generation_and_stale_policy_are_exact(self):
        value = _summary()
        value["root"]["authority"] = "audio"
        value["root"]["reset_step"] = 2
        value["root"]["stale_policy"] = "accept_old"
        errors = validate_summary(value)
        self.assertTrue(any("root must exactly" in error for error in errors))

    def test_lineage_order_and_native_gate_are_exact(self):
        value = _summary()
        value["lineage"].reverse()
        value["native_render_status"] = "planned"
        errors = validate_summary(value)
        self.assertTrue(any("lineage must exactly" in error for error in errors))
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_authority_and_stale_mutation_fail_closed(self):
        value = _summary()
        value["authority"]["settings_authority"] = True
        value["settings_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_summary(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("settings_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _summary()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/lineage-root-v11.json", "sha256": "bad"}]
        errors = validate_summary(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _summary()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["lineage"] = []
        value["root"] = []
        errors = validate_summary(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("exactly three ordered" in error for error in errors))
        self.assertTrue(any("root must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
