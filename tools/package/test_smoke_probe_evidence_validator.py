import unittest

from tools.package.smoke_probe_evidence_validator import validate_smoke


def smoke():
    return {
        "schema_version": 1,
        "build_label": "candidate-smoke-42",
        "source_commit": "a" * 40,
        "artifact_path": "build/game.exe",
        "artifact_sha256": "b" * 64,
        "packaged_startup": {"status": "PASS", "evidence": "clean startup log", "exit_code": 0, "frame_count": 300},
        "probes": [{"name": "embedded-pack", "status": "PASS", "evidence": "PCK inventory", "result": "embedded"}],
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SmokeProbeEvidenceValidatorTest(unittest.TestCase):
    def test_accepts_clean_packaged_smoke_with_native_not_run(self):
        self.assertEqual(validate_smoke(smoke()), [])

    def test_native_not_run_cannot_carry_platform_or_evidence(self):
        item = smoke()
        item["native_execution"]["platform"] = "Windows"
        item["native_execution"]["evidence"] = "native log"
        errors = validate_smoke(item)
        self.assertTrue(any("evidence must be null" in error for error in errors))
        self.assertTrue(any("platform must be null" in error for error in errors))

    def test_passed_startup_requires_zero_exit_and_frame_count(self):
        item = smoke()
        item["packaged_startup"]["exit_code"] = 1
        item["packaged_startup"]["frame_count"] = -1
        errors = validate_smoke(item)
        self.assertTrue(any("exit_code must be 0" in error for error in errors))
        self.assertTrue(any("frame_count" in error for error in errors))

    def test_probe_names_and_results_are_required(self):
        item = smoke()
        item["probes"].append({"name": "embedded-pack", "status": "PASS", "evidence": "x"})
        errors = validate_smoke(item)
        self.assertTrue(any("unique" in error for error in errors))
        self.assertTrue(any("result is required" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
