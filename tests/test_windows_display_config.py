from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WindowsDisplayConfigTest(unittest.TestCase):
    def test_display_contract_has_hidpi_minimum_and_resizable_canvas(self):
        text = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn("window/size/viewport_width=1600", text)
        self.assertIn("window/size/viewport_height=900", text)
        self.assertIn("window/size/min_width=960", text)
        self.assertIn("window/size/min_height=540", text)
        self.assertIn("window/dpi/allow_hidpi=true", text)
        self.assertIn("window/stretch/mode=\"canvas_items\"", text)
        self.assertIn("window/size/resizable=true", text)


if __name__ == "__main__":
    unittest.main()
