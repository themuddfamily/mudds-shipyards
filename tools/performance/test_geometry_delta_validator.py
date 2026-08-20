#!/usr/bin/env python3
"""Focused tests for the geometry/material census delta gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import geometry_delta_validator as validator  # noqa: E402


def report(seed: int = 0) -> dict:
    result = {
        "schema_version": 2,
        "scenario": "station_resident",
        "loaded_instance_count": 0,
        "measurement_fingerprint": ("a" if seed == 0 else "b") * 64,
        "buckets": {"station": {"triangles": 10}},
        "optimization_evidence": {
            "authority_unchanged": True,
            "visual_review": {"status": "pass", "viewpoints": ["central berth", "aft operations"]},
        },
    }
    result.update({metric: 100 for metric in validator.METRICS})
    if seed:
        result["total_triangles"] = 90
        result["unique_meshes"] = 99
    return result


class GeometryDeltaValidatorTests(unittest.TestCase):
    def test_valid_reduction_and_budget(self):
        self.assertEqual(validator.validate_delta(report(), report(1), {"total_triangles": 100}), [])

    def test_metric_regression_is_blocking(self):
        candidate = report(1)
        candidate["lights"] = 101
        self.assertIn("candidate lights regresses (100 -> 101)", validator.validate_delta(report(), candidate))

    def test_missing_review_and_authority_fail_closed(self):
        candidate = report(1)
        del candidate["optimization_evidence"]
        errors = validator.validate_delta(report(), candidate)
        self.assertIn("candidate optimization_evidence.authority_unchanged must be true", errors)
        self.assertIn("candidate optimization_evidence.visual_review.status must be pass", errors)

    def test_noop_is_not_an_optimization(self):
        self.assertIn("candidate has no measured geometry/material reduction", validator.validate_delta(report(), report()))

    def test_invalid_structure_and_budget_fail_closed(self):
        baseline = report()
        candidate = report(1)
        candidate["measurement_fingerprint"] = "bad"
        candidate["nodes"] = -1
        errors = validator.validate_delta(baseline, candidate)
        self.assertTrue(any("measurement_fingerprint" in error for error in errors))
        self.assertTrue(any("nodes must be" in error for error in errors))
        errors = validator.validate_delta(baseline, report(1), {"unknown": 10, "total_triangles": 1})
        self.assertIn("budget names unknown metric unknown", errors)
        self.assertIn("candidate total_triangles exceeds budget (90 > 1)", errors)


if __name__ == "__main__":
    unittest.main()
