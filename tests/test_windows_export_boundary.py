from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WindowsExportBoundaryTest(unittest.TestCase):
    def test_generated_builds_are_ignored_and_excluded_from_exports(self):
        boundary = ROOT / "builds" / ".gdignore"
        self.assertTrue(boundary.is_file())
        self.assertIn("not project resources", boundary.read_text(encoding="utf-8"))

        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("builds/*", gitignore)
        self.assertIn("!builds/.gdignore", gitignore)

        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('exclude_filter="tests/**,artifacts/**,tools/**,builds/**"', preset)


if __name__ == "__main__":
    unittest.main()
