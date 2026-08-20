import unittest

from tools.package.native_artifact_handoff_validator import validate_handoff


def record():
    return {
        "schema_version": 1,
        "build_label": "gateE-native-42",
        "source_commit": "a" * 40,
        "artifact": {"status": "PASS", "evidence": "export record", "path": "build/game.exe", "sha256": "b" * 64},
        "embedded_pack": {"status": "PASS", "evidence": "PE inventory", "embedded": True, "inventory": "pck-manifest.sha256"},
        "signature": {"status": "NOT_RUN", "evidence": None},
        "runtime_smoke": {"status": "PASS", "evidence": "clean packaged smoke"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "reason": "Windows host unavailable", "platform": None, "hardware": None, "evidence_path": None},
    }


class NativeArtifactHandoffValidatorTest(unittest.TestCase):
    def test_accepts_package_with_explicit_native_not_run(self):
        self.assertEqual(validate_handoff(record()), [])

    def test_not_run_rejects_execution_evidence_and_metadata(self):
        item = record()
        item["native_execution"]["evidence"] = "ran on Windows"
        item["native_execution"]["platform"] = "Windows"
        errors = validate_handoff(item)
        self.assertTrue(any("evidence must be null" in error for error in errors))
        self.assertTrue(any("platform must be null" in error for error in errors))

    def test_pass_requires_artifact_and_signature_claim_details(self):
        item = record()
        item["artifact"]["sha256"] = "not-a-digest"
        item["signature"] = {"status": "PASS", "evidence": "signed"}
        errors = validate_handoff(item)
        self.assertTrue(any("artifact.sha256" in error for error in errors))
        self.assertTrue(any("signature.method" in error for error in errors))

    def test_unknown_states_cannot_smuggle_evidence(self):
        item = record()
        item["runtime_smoke"] = {"status": "UNKNOWN", "evidence": "not checked"}
        self.assertTrue(any("runtime_smoke.evidence" in error for error in validate_handoff(item)))


if __name__ == "__main__":
    unittest.main()
