import unittest

from tools.package.artifact_chain_validator import validate_chain


def chain():
    return {
        "schema_version": 1, "release_version": "v1.2.3", "build_label": "release-42", "source_commit": "a" * 40,
        "build": {"status": "PASS", "evidence": "clean export", "executable_path": "build/game.exe", "executable_sha256": "b" * 64, "pck_path": "build/game.pck", "pck_sha256": "c" * 64},
        "embedded_pck": {"status": "PASS", "evidence": "PE inventory", "inventory_status": "PASS", "embedded": True},
        "source_manifest": {"status": "PASS", "evidence": "manifest", "manifest_sha256": "d" * 64},
        "signature": {"status": "PASS", "evidence": "detached signature"},
        "runtime_matrix": {"status": "PASS", "evidence": "packaged smoke"},
        "update_compatibility": {"status": "PASS", "evidence": "schema migration manifest"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "reason": "native Windows hardware unavailable"},
    }


class ArtifactChainValidatorTest(unittest.TestCase):
    def test_accepts_complete_chain_with_explicit_native_not_run(self):
        self.assertEqual(validate_chain(chain()), [])

    def test_requires_embedded_pck_inventory(self):
        item = chain(); item["embedded_pck"]["embedded"] = False
        self.assertTrue(any("embedded must be true" in e for e in validate_chain(item)))

    def test_rejects_native_claim_without_evidence(self):
        item = chain(); item["native_execution"] = {"status": "PASS", "evidence": None}
        self.assertTrue(any("native_execution.evidence" in e for e in validate_chain(item)))

    def test_rejects_invalid_hash(self):
        item = chain(); item["build"]["pck_sha256"] = "bad"
        self.assertTrue(any("pck_sha256" in e for e in validate_chain(item)))


if __name__ == "__main__":
    unittest.main()
