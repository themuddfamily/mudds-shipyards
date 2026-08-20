import unittest

from tools.package.hash_provenance_chain_validator import validate_chain


def chain():
    source = "a" * 40
    source_hash = "b" * 64
    artifact_hash = "c" * 64
    return {
        "schema_version": 1,
        "build_label": "chain-42",
        "source_commit": source,
        "source_manifest_sha256": source_hash,
        "artifact_sha256": artifact_hash,
        "source": {"status": "PASS", "evidence": "manifest report", "commit": source, "manifest_sha256": source_hash},
        "artifact": {"status": "PASS", "evidence": "hash report", "path": "build/game.exe", "sha256": artifact_hash},
        "pck": {"status": "PASS", "evidence": "embedded inventory", "path": "embedded", "sha256": "d" * 64, "embedded": True},
        "audit": {"status": "PASS", "evidence": "cross-record audit", "source_matches": True, "artifact_matches": True},
    }


class HashProvenanceChainValidatorTest(unittest.TestCase):
    def test_accepts_consistent_hash_chain(self):
        self.assertEqual(validate_chain(chain()), [])

    def test_rejects_source_identity_drift(self):
        item = chain()
        item["source"]["commit"] = "e" * 40
        self.assertTrue(any("source.commit must match" in error for error in validate_chain(item)))

    def test_rejects_artifact_hash_drift(self):
        item = chain()
        item["artifact"]["sha256"] = "e" * 64
        self.assertTrue(any("artifact.sha256 must match" in error for error in validate_chain(item)))

    def test_passed_audit_requires_match_flags(self):
        item = chain()
        item["audit"]["artifact_matches"] = False
        self.assertTrue(any("artifact_matches must be true" in error for error in validate_chain(item)))


if __name__ == "__main__":
    unittest.main()
