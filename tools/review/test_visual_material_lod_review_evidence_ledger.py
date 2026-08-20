import copy
import unittest

from tools.review.visual_material_lod_review_evidence_ledger import (
    MATERIAL_ASPECTS,
    TARGETS,
    TARGET_ROLES,
    TIER_BOUNDS,
    TIERS,
    validate_ledger,
)


SHA = "c" * 64


def _ledger() -> dict:
    materials = [{
        "target_id": target,
        "role": TARGET_ROLES[target],
        "material_family": f"{target}_authored_family",
        "lod_source": f"source/{target}/lod_contract.json",
        "lod_tiers": list(TIERS),
        "status": "planned",
    } for target in TARGETS]
    reviews = []
    for target in TARGETS:
        for tier in TIERS:
            reviews.append({
                "target_id": target,
                "tier": tier,
                "distance_m": {"min": TIER_BOUNDS[tier][0], "max": TIER_BOUNDS[tier][1]},
                "camera": f"{target} {tier} review camera",
                "result": "pending",
                "material_aspects": {aspect: "pending" for aspect in MATERIAL_ASPECTS},
                "evidence": None,
                "notes": "Native render capture remains outstanding.",
            })
    return {
        "schema": "visual_material_lod_review_evidence_v1",
        "source_revision": "working-tree-material-lod-review",
        "human_review_status": "not_performed",
        "reviewer_required": "human art and rendering QA",
        "open_gate_reason": "no native render capture or human visual comparison has been performed",
        "human_review_complete": False,
        "native_render_performed": False,
        "detached_contract_tests_only": True,
        "materials": materials,
        "reviews": reviews,
    }


class VisualMaterialLodReviewEvidenceTests(unittest.TestCase):
    def test_complete_source_only_matrix_keeps_render_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_target_and_lod_rosters_are_exact(self):
        value = _ledger()
        value["materials"].pop()
        value["reviews"] = value["reviews"][:-1]
        errors = validate_ledger(value)
        self.assertTrue(any("exactly five visual target" in error for error in errors))
        self.assertTrue(any("every target/tier pair" in error for error in errors))

    def test_distance_band_and_duplicate_reviews_fail_closed(self):
        value = _ledger()
        value["reviews"][1]["distance_m"]["min"] = 31.0
        value["reviews"].append(copy.deepcopy(value["reviews"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("frozen mid distance band" in error for error in errors))
        self.assertTrue(any("duplicates an earlier target/tier pair" in error for error in errors))

    def test_material_aspect_roster_is_required(self):
        value = _ledger()
        value["reviews"][0]["material_aspects"].pop("normal_detail")
        errors = validate_ledger(value)
        self.assertTrue(any("material_aspects must exactly cover" in error for error in errors))

    def test_non_pending_review_requires_traceable_evidence(self):
        value = _ledger()
        value["reviews"][0]["result"] = "clear"
        errors = validate_ledger(value)
        self.assertTrue(any("reviews[0].evidence must be null" in error for error in errors))
        value["reviews"][0]["evidence"] = [{"kind": "image", "path": "captures/near.png", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_native_render_or_human_approval_claim_fails_closed(self):
        value = _ledger()
        value["native_render_performed"] = True
        value["human_review_complete"] = True
        value["human_review_status"] = "approved"
        errors = validate_ledger(value)
        self.assertTrue(any("native_render_performed" in error for error in errors))
        self.assertTrue(any("human_review_complete" in error for error in errors))
        self.assertTrue(any("human_review_status" in error for error in errors))

    def test_malformed_nested_values_report_errors_without_throwing(self):
        value = _ledger()
        value["materials"][0] = {"target_id": [], "status": {}}
        value["reviews"][0] = {"target_id": [], "tier": [], "result": [], "material_aspects": [], "evidence": {}}
        errors = validate_ledger(value)
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
