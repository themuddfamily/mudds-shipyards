import copy
import unittest

from tools.settings.review.accessibility_caption_category_coverage_evidence_index import (
    CATEGORIES,
    CATEGORY_LABELS,
    REQUIRED_CHECKS,
    SURFACE_FIELDS,
    validate_index,
)


def _index() -> dict:
    rows = [{
        "id": category,
        "category": category,
        "expected_category_label": CATEGORY_LABELS[category],
        "surface_fields": list(SURFACE_FIELDS),
        "representative_cue": f"{category}_sample",
        "expected_behavior": f"The {category} caption exposes stable category, speaker, and text surfaces.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for category in CATEGORIES]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} category check remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_caption_category_coverage_evidence_v1",
        "source_revision": "working-tree-caption-category-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "contract_source": "scripts/ui/caption_presentation_event.gd",
        "presenter_source": "scripts/ui/caption_presenter.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption category review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "presentation_only": True,
        "audio_authority": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "categories": list(CATEGORIES),
        "surface_fields": list(SURFACE_FIELDS),
        "coverage_rows": rows,
        "checks": checks,
    }


class AccessibilityCaptionCategoryCoverageTests(unittest.TestCase):
    def test_complete_source_only_index_keeps_human_gate_open(self):
        self.assertEqual(validate_index(_index()), [])

    def test_category_order_and_labels_are_exact(self):
        value = _index()
        value["categories"] = ["dialogue", "system", "radio", "ambient"]
        value["coverage_rows"][1]["expected_category_label"] = "WRONG"
        errors = validate_index(value)
        self.assertTrue(any("categories must exactly" in error for error in errors))
        self.assertTrue(any("expected_category_label" in error for error in errors))

    def test_surface_fields_and_rows_cannot_drop_a_category(self):
        value = _index()
        value["surface_fields"] = ["category", "text"]
        value["coverage_rows"] = value["coverage_rows"][:-1]
        errors = validate_index(value)
        self.assertTrue(any("surface_fields must exactly" in error for error in errors))
        self.assertTrue(any("exactly four ordered category rows" in error for error in errors))

    def test_observed_row_requires_valid_evidence_digest(self):
        value = _index()
        value["coverage_rows"][0]["status"] = "observed"
        errors = validate_index(value)
        self.assertTrue(any("coverage_rows[0].evidence must be null" in error for error in errors))
        value["coverage_rows"][0]["evidence"] = [{"kind": "report", "path": "reports/caption-categories.json", "sha256": "bad"}]
        errors = validate_index(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_human_and_native_authority_claims_fail_closed(self):
        value = _index()
        value["human_review_performed"] = True
        value["native_render_status"] = "observed"
        value["caption_queue_authority"] = True
        errors = validate_index(value)
        self.assertTrue(any("human_review_performed" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("caption_queue_authority" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _index()
        value["human_review_status"] = []
        value["coverage_rows"][1] = {"id": [], "category": {}, "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_index(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("coverage_rows[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
