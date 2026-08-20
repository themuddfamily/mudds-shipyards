import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.review.visual_lod_review_manifest_validator import validate


class VisualLodReviewManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.captures = {}
        for tier in ("near", "mid", "far"):
            for phase in ("before", "after"):
                path = self.root / f"{tier}_{phase}.png"
                path.write_bytes(f"{tier}-{phase}".encode())
                self.captures[(tier, phase)] = path

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        tiers = []
        bounds = {"near": (0, 30), "mid": (30, 120), "far": (120, 500)}
        for tier in ("near", "mid", "far"):
            captures = {}
            for phase in ("before", "after"):
                path = self.captures[(tier, phase)]
                captures[phase] = {"path": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                   "viewpoint": f"{tier} transition camera"}
            tiers.append({"id": tier, "distance_m": {"min": bounds[tier][0], "max": bounds[tier][1]},
                          "silhouette": "readable authored outline", "readability": "role remains legible",
                          "review_status": "pending", **captures})
        value = {"schema": "visual_lod_review_manifest_v1", "source_revision": "abc123",
                 "human_review_status": "pending", "reviewer_required": "art director",
                 "rubric": {"silhouette": ["no hard pop", "outline remains authored"],
                             "readability": ["role remains legible", "materials remain separable"]}, "tiers": tiers}
        value.update(changes)
        path = self.root / "lod_review.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_three_tier_handoff(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_missing_tier_and_overlapping_distance_fail(self):
        path = self.manifest()
        data = json.loads(path.read_text())
        data["tiers"] = data["tiers"][:-1]
        data["tiers"][1]["distance_m"]["min"] = 10
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("exactly near, mid, and far" in e for e in errors))
        self.assertTrue(any("overlaps" in e for e in errors))

    def test_tamper_and_approval_fail(self):
        path = self.manifest(human_review_status="approved")
        errors = validate(path)
        self.assertTrue(any("cannot claim human approval" in e for e in errors))
        self.captures[("near", "after")].write_bytes(b"tampered")
        self.assertTrue(any("SHA-256" in e for e in validate(path)))

    def test_missing_readability_and_capture_metadata_fail(self):
        path = self.manifest()
        data = json.loads(path.read_text())
        data["tiers"][0]["readability"] = ""
        data["tiers"][0]["after"].pop("viewpoint")
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("readability" in e for e in errors))
        self.assertTrue(any("viewpoint" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
