import unittest

from tools.package.source_hash_chain_v118 import validate_v118


def record():
    commit = "9" * 40
    digest = "d" * 64
    source_id = "source-118"
    chain_id = "chain-118"
    source_version = "src-118"
    package_version = "11.8.0"
    return {
        "schema_version": 118,
        "build_label": "source-chain-v118",
        "source_id": source_id,
        "chain_id": chain_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "chain": {"status": "PASS", "evidence": "chain", "chain_id": chain_id, "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "complete": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashChainV118Test(unittest.TestCase):
    def test_accepts_complete_source_hash_chain(self):
        self.assertEqual(validate_v118(record()), [])

    def test_requires_chain_identity_and_hash_binding(self):
        item = record()
        item["chain"]["chain_id"] = "chain-other"
        item["chain"]["source_hash"] = "a" * 64
        errors = validate_v118(item)
        self.assertTrue(any("chain.chain_id must match" in error for error in errors))
        self.assertTrue(any("chain.source_hash must match" in error for error in errors))

    def test_rejects_schema_or_incomplete_chain(self):
        item = record()
        item["schema_version"] = 117
        item["chain"]["complete"] = False
        errors = validate_v118(item)
        self.assertTrue(any("schema_version must be 118" in error for error in errors))
        self.assertTrue(any("complete must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v118(item)))


if __name__ == "__main__":
    unittest.main()
