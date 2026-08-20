import copy
import json
import unittest
from pathlib import Path

from tools.review.playthrough_route_manifest import REQUIRED_ROUTE, validate


ROOT = Path(__file__).parent


class PlaythroughRouteTests(unittest.TestCase):
    def setUp(self):
        self.record = json.loads((ROOT / "playthrough_route_manifest.json").read_text())

    def test_pending_route_is_valid_and_complete(self):
        self.assertEqual(validate(self.record), [])
        self.assertEqual({step["id"] for step in self.record["route"]}, set(REQUIRED_ROUTE))

    def test_missing_route_step_fails(self):
        record = copy.deepcopy(self.record)
        record["route"].pop()
        self.assertTrue(any("missing required steps" in e for e in validate(record)))

    def test_pass_requires_all_steps_and_source(self):
        record = copy.deepcopy(self.record)
        record["human_run_status"] = "pass"
        errors = validate(record)
        self.assertIn("pass requires source_commit", errors)
        self.assertIn("pass requires every route step to pass", errors)

    def test_defect_requires_repro_details_and_visual_flag(self):
        record = copy.deepcopy(self.record)
        record["defects"] = [{"severity": "P1", "route_step": "combat", "location": "arena", "state": "destroyed"}]
        errors = validate(record)
        self.assertTrue(any("source_commit is required" in e for e in errors))
        self.assertTrue(any("visual_evidence" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
