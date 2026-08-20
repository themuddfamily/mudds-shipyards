import json
import tempfile
import unittest
from pathlib import Path

from tools.input.controller_hardware_validation_manifest import validate


class ControllerHardwareValidationManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, **changes):
        manifest = {
            "schema": "controller_hardware_validation_manifest_v1",
            "hardware_test_status": "pending",
            "platform": "Windows 11 / representative desktop",
            "device_families": [{"id": "xinput", "name": "Xbox-compatible",
                                  "connection": "USB", "glyph_set": "xbox",
                                  "status": "planned"}],
            "glyphs": {"status": "pending", "required_actions": ["move", "fire", "pause"],
                        "covered_sets": ["xbox"]},
            "remap_trials": [{"id": "remap-fire", "action": "fire", "from_binding": "RT",
                               "to_binding": "RB", "conflict_result": "reported",
                               "status": "pending"}],
            "curve_hold_trials": [{"id": "hold-fire", "action": "fire", "curve": "linear",
                                    "mode": "hold", "deadzone": 0.18, "status": "pending"}],
        }
        manifest.update(changes)
        path = self.root / "hardware.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def test_complete_evidence_shape_is_valid_even_before_real_run(self):
        self.assertEqual(validate(self.write()), [])

    def test_status_is_explicit_and_unknown_status_fails(self):
        path = self.write()
        data = json.loads(path.read_text())
        data.pop("hardware_test_status")
        path.write_text(json.dumps(data))
        self.assertTrue(any("hardware_test_status is required" in e for e in validate(path)))
        data["hardware_test_status"] = "green"
        path.write_text(json.dumps(data))
        self.assertTrue(any("hardware_test_status must be one of" in e for e in validate(path)))

    def test_device_family_and_glyph_coverage_are_required(self):
        path = self.write()
        data = json.loads(path.read_text())
        data["device_families"][0].pop("glyph_set")
        data["glyphs"]["required_actions"] = []
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("glyph_set is required" in e for e in errors))
        self.assertTrue(any("required_actions must contain" in e for e in errors))

    def test_remap_conflict_and_curve_hold_parameters_are_required(self):
        path = self.write()
        data = json.loads(path.read_text())
        data["remap_trials"][0].pop("conflict_result")
        data["curve_hold_trials"][0]["deadzone"] = 1.0
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("conflict_result is required" in e for e in errors))
        self.assertTrue(any("deadzone must be a number" in e for e in errors))

    def test_duplicate_devices_and_invalid_trial_enums_fail(self):
        path = self.write(device_families=[
            {"id": "xinput", "name": "A", "connection": "USB", "glyph_set": "xbox", "status": "planned"},
            {"id": "xinput", "name": "B", "connection": "wireless", "glyph_set": "xbox", "status": "planned"},
        ])
        data = json.loads(path.read_text())
        data["curve_hold_trials"][0]["curve"] = "cubic"
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("duplicates" in e for e in errors))
        self.assertTrue(any("curve must be one of" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
