import unittest

from tools.package.pe_pck_metadata_validator import validate_metadata


def metadata():
    return {
        "schema_version": 1,
        "build_label": "candidate-pe-42",
        "source_commit": "a" * 40,
        "artifact_path": "build/game.exe",
        "artifact_sha256": "b" * 64,
        "pe": {"status": "PASS", "evidence": "PE inspection report", "machine": "AMD64", "file_version": "0.12.0.0", "section_count": 12},
        "pck": {"status": "PASS", "evidence": "PCK inventory", "format": 4, "entry_count": 180, "manifest_sha256": "c" * 64, "embedded_offset": 109228032, "external": False},
        "native_inspection": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class PePckMetadataValidatorTest(unittest.TestCase):
    def test_accepts_recorded_embedded_pe_pck_metadata(self):
        self.assertEqual(validate_metadata(metadata()), [])

    def test_native_not_run_cannot_carry_platform(self):
        item = metadata()
        item["native_inspection"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_metadata(item)))

    def test_pass_requires_valid_pck_format_and_manifest(self):
        item = metadata()
        item["pck"]["format"] = 3
        item["pck"]["manifest_sha256"] = "bad"
        errors = validate_metadata(item)
        self.assertTrue(any("format must be 4" in error for error in errors))
        self.assertTrue(any("manifest_sha256" in error for error in errors))

    def test_embedded_metadata_rejects_external_pck_claim(self):
        item = metadata()
        item["pck"]["external"] = True
        self.assertTrue(any("external must be false" in error for error in validate_metadata(item)))


if __name__ == "__main__":
    unittest.main()
