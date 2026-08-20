import unittest

from tools.package.export_manifest_validator import validate_manifest


def valid_manifest():
    return {
        "schema_version": 1,
        "build_label": "gateE-20260820-ab12cd3",
        "source_commit": "ab12cd3",
        "godot_version": "4.7.1",
        "artifact_path": "builds/windows/MuddsShipyards.exe",
        "artifact_sha256": "a" * 64,
        "artifact_size_bytes": 1234,
        "signing_status": "UNSIGNED",
        "embedded_pck_inventory": ["project.godot", "scenes/main.tscn"],
        "smoke_status": "PASS",
        "native_playtest_status": "NOT_RUN",
        "native_playtest_evidence": None,
    }


class ExportManifestValidatorTest(unittest.TestCase):
    def test_accepts_complete_metadata_without_claiming_native_run(self):
        self.assertEqual(validate_manifest(valid_manifest()), [])

    def test_requires_artifact_identity_and_inventory(self):
        manifest = valid_manifest()
        manifest["artifact_sha256"] = "short"
        manifest["artifact_size_bytes"] = 0
        manifest["embedded_pck_inventory"] = []
        errors = validate_manifest(manifest)
        self.assertEqual(len(errors), 3)

    def test_not_run_cannot_carry_playtest_evidence(self):
        manifest = valid_manifest()
        manifest["native_playtest_evidence"] = "operator said it launched"
        self.assertTrue(any("must be null" in error for error in validate_manifest(manifest)))

    def test_completed_native_run_requires_evidence(self):
        manifest = valid_manifest()
        manifest["native_playtest_status"] = "PASS"
        self.assertTrue(any("evidence is required" in error for error in validate_manifest(manifest)))


if __name__ == "__main__":
    unittest.main()
