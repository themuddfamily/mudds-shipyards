from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def _value(text: str, key: str) -> str:
    prefix = f'{key}="'
    for line in text.splitlines():
        if line.startswith(prefix) and line.endswith('"'):
            return line[len(prefix):-1]
    return ""


class WindowsApplicationMetadataTest(unittest.TestCase):
    def test_project_identity_and_windows_metadata_are_explicit(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertEqual(_value(project, "config/name"), "Mudds Shipyards")
        self.assertEqual(_value(project, "config/version"), "0.12.0")
        self.assertEqual(_value(project, "config/icon"), "res://assets/keth-icon.png")
        self.assertEqual(_value(preset, "application/company_name"), "Mudds Shipyards")
        self.assertEqual(_value(preset, "application/product_name"), "Mudds Shipyards")
        self.assertEqual(_value(preset, "application/file_version"), "0.12.0.0")
        self.assertEqual(_value(preset, "application/product_version"), "0.12.0.0")
        self.assertEqual(_value(preset, "application/icon"), "res://assets/keth-icon.png")
        self.assertTrue((ROOT / "assets/keth-icon.png").is_file())


if __name__ == "__main__":
    unittest.main()
