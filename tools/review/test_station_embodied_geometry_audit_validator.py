import copy
import unittest

from tools.review.station_embodied_geometry_audit_validator import (
    CATEGORIES,
    LOCATIONS,
    PERSPECTIVES,
    ROUTES,
    validate_ledger,
)


SHA = "b" * 64


def _ledger() -> dict:
    viewpoints = []
    for location in LOCATIONS:
        for perspective in PERSPECTIVES:
            viewpoints.append({
                "id": f"{location}-{perspective}",
                "location": location,
                "location_label": f"{location} station module",
                "perspective": perspective,
                "route": ROUTES[location],
            })
    observations = []
    for viewpoint in viewpoints:
        for category in CATEGORIES:
            observations.append({
                "viewpoint": viewpoint["id"],
                "category": category,
                "result": "pending",
                "evidence": None,
            })
    return {
        "schema": "station_embodied_geometry_audit_v1",
        "source_revision": "working-tree-station-geometry-review",
        "human_review_status": "not_performed",
        "reviewer_required": "human gameplay and visual QA",
        "open_gate_reason": "no native station geometry sweep or packaged playtest has been performed",
        "human_review_complete": False,
        "native_run_performed": False,
        "detached_contract_tests_only": True,
        "viewpoints": viewpoints,
        "observations": observations,
    }


class StationEmbodiedGeometryAuditTests(unittest.TestCase):
    def test_complete_source_only_matrix_keeps_native_review_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_both_perspectives_and_all_locations_are_required(self):
        value = _ledger()
        value["viewpoints"] = [item for item in value["viewpoints"] if item["id"] != "fleet_dock-ship"]
        errors = validate_ledger(value)
        self.assertTrue(any("exactly ten" in error for error in errors))

    def test_observation_matrix_rejects_duplicates_and_missing_categories(self):
        value = _ledger()
        value["observations"].pop()
        value["observations"].append(copy.deepcopy(value["observations"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("duplicates an earlier" in error for error in errors))
        self.assertTrue(any("exactly cover every viewpoint/category" in error for error in errors))

    def test_native_or_human_approval_claims_fail_closed(self):
        value = _ledger()
        value["native_run_performed"] = True
        value["human_review_complete"] = True
        value["human_review_status"] = "approved"
        errors = validate_ledger(value)
        self.assertTrue(any("native_run_performed" in error for error in errors))
        self.assertTrue(any("human_review_complete" in error for error in errors))
        self.assertTrue(any("human_review_status" in error for error in errors))

    def test_observed_rows_require_traceable_evidence(self):
        value = _ledger()
        value["observations"][0]["result"] = "clear"
        errors = validate_ledger(value)
        self.assertTrue(any("observations[0].evidence must be null" in error for error in errors))
        value["observations"][0]["evidence"] = [{"kind": "image", "path": "captures/a.png", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_malformed_nested_values_fail_without_throwing(self):
        value = _ledger()
        value["viewpoints"][0] = {"id": [], "location": [], "perspective": {}, "route": None}
        value["observations"][0] = {"viewpoint": [], "category": {}, "result": [], "evidence": {}}
        errors = validate_ledger(value)
        self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
