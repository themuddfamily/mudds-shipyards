import unittest

from tools.package.source_hash_provenance_v126 import validate_v126


def record():
    commit = "1" * 40
    digest = "e" * 64
    common = {"source_id": "source-126", "source_commit": commit, "source_hash": digest, "source_version": "src-126", "package_version": "12.6.0", "audit_id": "audit-126"}
    return {
        "schema_version": 126,
        "build_label": "source-provenance-v126",
        **common,
        "provenance_id": "provenance-126",
        "source": {"status": "PASS", "evidence": "source", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": "provenance-126", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV126Test(unittest.TestCase):
    def test_accepts_bound_provenance_with_audit_id(self):
        self.assertEqual(validate_v126(record()), [])

    def test_requires_digest_and_audit_binding(self):
        item = record()
        item["source_hash"] = "E" * 64
        item["provenance"]["audit_id"] = "audit-other"
        errors = validate_v126(item)
        self.assertTrue(any("source_hash must be lowercase sha256" in error for error in errors))
        self.assertTrue(any("provenance.audit_id must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 125
        item["provenance"]["proven"] = False
        errors = validate_v126(item)
        self.assertTrue(any("schema_version must be 126" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_runtime_evidence(self):
        item = record()
        item["native_execution"]["evidence_path"] = "runtime.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v126(item)))


if __name__ == "__main__":
    unittest.main()
