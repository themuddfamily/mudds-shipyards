import unittest

from tools.package.source_hash_provenance_v128 import validate_v128


def record():
    common = {"source_id": "source-128", "source_commit": "2" * 40, "source_hash": "f" * 64, "source_version": "src-128", "package_version": "12.8.0", "release_channel": "stable", "attestation_id": "attest-128"}
    return {
        "schema_version": 128, "build_label": "source-provenance-v128", **common, "provenance_id": "provenance-128",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-128", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV128Test(unittest.TestCase):
    def test_accepts_channel_attestation_binding(self):
        self.assertEqual(validate_v128(record()), [])

    def test_requires_channel_and_attestation_binding(self):
        item = record()
        item["source"]["release_channel"] = "beta"
        item["provenance"]["attestation_id"] = "attest-other"
        errors = validate_v128(item)
        self.assertTrue(any("source.release_channel must match" in error for error in errors))
        self.assertTrue(any("provenance.attestation_id must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 127
        item["provenance"]["proven"] = False
        errors = validate_v128(item)
        self.assertTrue(any("schema_version must be 128" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v128(item)))


if __name__ == "__main__":
    unittest.main()
