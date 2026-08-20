import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.review.station_capture_currentness_validator import validate


class StationCaptureCurrentnessTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.revision = "a" * 40
        self.ledger = {"schema": "source_ledger_v1", "sources": [{"id": "B1", "title": "fixture source"}, {"id": "B4", "title": "fixture video"}]}
        ledger_path = self.root / "source_ledger.json"
        ledger_path.write_text(json.dumps(self.ledger), encoding="utf-8")
        self.ledger_hash = hashlib.sha256(ledger_path.read_bytes()).hexdigest()
        captures = []
        for berth in ("central", "aft", "habitat", "freight", "fleet_dock"):
            path = self.root / f"{berth}.png"
            path.write_bytes(berth.encode())
            captures.append({"berth": berth, "path": path.name,
                             "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                             "viewpoint": f"{berth} player-height approach",
                             "source_current": True, "source_revision": self.revision,
                             "source_refs": ["B1", "B4"]})
        self.data = {"schema": "station_capture_currentness_v1", "source_revision": self.revision,
                     "human_review_status": "pending", "reviewer_required": "art director",
                     "source_ledger": {"path": ledger_path.name, "sha256": self.ledger_hash},
                     "captures": captures}

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self):
        path = self.root / "rerun.json"
        path.write_text(json.dumps(self.data), encoding="utf-8")
        return path

    def test_current_five_berth_rerun_is_ready_for_manual_review(self):
        self.assertEqual(validate(self.manifest(), self.revision), [])

    def test_revision_ledger_and_source_reference_drift_fail_closed(self):
        path = self.manifest()
        self.assertTrue(any("current source revision" in error for error in validate(path, "b" * 40)))
        self.data["source_ledger"]["sha256"] = "0" * 64
        self.assertTrue(any("ledger SHA-256" in error for error in validate(self.manifest(), self.revision)))
        self.data["source_ledger"]["sha256"] = self.ledger_hash
        self.data["captures"][0]["source_refs"] = ["unlisted"]
        self.assertTrue(any("unregistered source" in error for error in validate(self.manifest(), self.revision)))

    def test_approval_and_frame_tamper_do_not_pass(self):
        self.data["human_review_status"] = "approved"
        path = self.manifest()
        self.assertTrue(any("human_review_status" in error for error in validate(path, self.revision)))
        (self.root / "central.png").write_bytes(b"changed")
        self.assertTrue(any("SHA-256" in error for error in validate(path, self.revision)))


if __name__ == "__main__":
    unittest.main()
