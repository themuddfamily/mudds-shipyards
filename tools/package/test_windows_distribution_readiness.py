import unittest

from tools.package.windows_distribution_readiness import validate_readiness


def record():
    return {
        "schema_version": 1,
        "source_commit": "a" * 40,
        "artifact": {
            "name": "MuddsShipyards-abcdef1.exe",
            "sha256": "b" * 64,
            "size_bytes": 1024,
        },
        "signing": {"status": "NOT_RUN", "evidence": None},
        "installer": {"status": "NOT_RUN", "evidence": None},
        "desktop_validation": {"status": "NOT_RUN", "evidence": None},
        "native_execution": {"status": "NOT_RUN", "evidence": None},
        "human_playtest": {"status": "NOT_RUN", "evidence": None},
        "distribution_allowed": False,
    }


class WindowsDistributionReadinessTest(unittest.TestCase):
    def test_accepts_unrun_external_gates(self):
        self.assertEqual(validate_readiness(record()), [])

    def test_accepts_complete_signed_record(self):
        item = record()
        item["signing"] = {
            "status": "SIGNED",
            "evidence": "Authenticode verification transcript",
            "certificate_subject": "CN=Example Publisher",
            "certificate_thumbprint": "c" * 40,
            "timestamp_utc": "2026-08-23T00:00:00Z",
        }
        item["installer"] = {"status": "PASS", "evidence": "installer smoke transcript"}
        item["desktop_validation"] = {"status": "PASS", "evidence": "desktop validation transcript"}
        self.assertEqual(validate_readiness(item), [])

    def test_rejects_bad_artifact_identity(self):
        item = record()
        item["artifact"]["sha256"] = "BAD"
        item["artifact"]["size_bytes"] = 0
        errors = validate_readiness(item)
        self.assertTrue(any("artifact.sha256" in error for error in errors))
        self.assertTrue(any("artifact.size_bytes" in error for error in errors))

    def test_signed_requires_certificate_details(self):
        item = record()
        item["signing"] = {"status": "SIGNED", "evidence": "signed"}
        errors = validate_readiness(item)
        self.assertTrue(any("certificate_subject" in error for error in errors))
        self.assertTrue(any("certificate_thumbprint" in error for error in errors))

    def test_not_run_cannot_carry_evidence(self):
        item = record()
        item["native_execution"]["evidence"] = "native log"
        self.assertTrue(any("native_execution.evidence" in error for error in validate_readiness(item)))

    def test_native_and_human_gates_cannot_claim_pass(self):
        item = record()
        item["human_playtest"] = {"status": "PASS", "evidence": "player report"}
        self.assertTrue(any("human_playtest.status must remain NOT_RUN" in error for error in validate_readiness(item)))


if __name__ == "__main__":
    unittest.main()
