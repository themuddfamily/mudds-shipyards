import json
import tempfile
import unittest
from pathlib import Path

from .native_windows_review_manifest import validate


class NativeWindowsReviewManifestTest(unittest.TestCase):
    def manifest(self, **overrides):
        data = {
            "schema": "native_windows_review_manifest_v1",
            "target": {"os": "Windows", "architecture": "x86_64", "build_identity": "gateE-test"},
            "package": {"path": "build/game.exe", "sha256": "a" * 64},
            "controller_only_run": {"status": "NOT_RUN", "evidence": None},
            "visual_review": {"status": "NOT_RUN", "evidence": None},
            "performance_review": {"status": "NOT_RUN", "evidence": None},
        }
        data.update(overrides)
        handle = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        json.dump(data, handle)
        handle.close()
        self.addCleanup(lambda: Path(handle.name).unlink(missing_ok=True))
        return Path(handle.name)

    def test_explicit_not_run_manifest_is_valid(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_complete_review_requires_evidence(self):
        errors = validate(self.manifest(controller_only_run={"status": "COMPLETE", "evidence": None}))
        self.assertTrue(any("controller_only_run.evidence" in error for error in errors))

    def test_rejects_non_windows_and_bad_hash(self):
        path = self.manifest(target={"os": "Linux", "architecture": "x86_64", "build_identity": "x"}, package={"path": "x", "sha256": "bad"})
        errors = validate(path)
        self.assertTrue(any("target.os" in error for error in errors))
        self.assertTrue(any("sha256" in error for error in errors))

    def test_complete_review_accepts_evidence(self):
        review = {"status": "COMPLETE", "evidence": "native Windows run log#42"}
        self.assertEqual(validate(self.manifest(controller_only_run=review, visual_review=review, performance_review=review)), [])


if __name__ == "__main__":
    unittest.main()
