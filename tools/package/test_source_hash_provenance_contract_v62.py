import unittest

from tools.package.source_hash_provenance_contract_v62 import validate_v62


def record():
    commit = "2" * 40
    digest = "f" * 64
    provenance_id = "provenance-62"
    contract_id = "contract-62"
    source_version = "src-62"
    package_version = "6.2.0"
    return {
        "schema_version": 62,
        "build_label": "provenance-contract-v62",
        "provenance_id": provenance_id,
        "contract_id": contract_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": provenance_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "verified": True},
        "contract": {"status": "PASS", "evidence": "contract", "contract_id": contract_id, "provenance_id": provenance_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "bound": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceContractV62Test(unittest.TestCase):
    def test_accepts_verified_bound_contract(self):
        self.assertEqual(validate_v62(record()), [])

    def test_requires_provenance_and_contract_hash_binding(self):
        item = record()
        item["provenance"]["source_hash"] = "a" * 64
        item["contract"]["package_version"] = "6.1.0"
        errors = validate_v62(item)
        self.assertTrue(any("provenance.source_hash must match" in error for error in errors))
        self.assertTrue(any("contract.package_version must match" in error for error in errors))

    def test_rejects_schema_or_contract_flags(self):
        item = record()
        item["schema_version"] = 61
        item["provenance"]["verified"] = False
        item["contract"]["bound"] = False
        errors = validate_v62(item)
        self.assertTrue(any("schema_version must be 62" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("bound must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v62(item)))


if __name__ == "__main__":
    unittest.main()
