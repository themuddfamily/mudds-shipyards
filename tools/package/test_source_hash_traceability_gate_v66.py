import unittest

from tools.package.source_hash_traceability_gate_v66 import validate_v66


def record():
    commit = "6" * 40
    digest = "d" * 64
    source_id = "source-66"
    trace_id = "trace-66"
    gate_id = "gate-66"
    source_version = "src-66"
    package_version = "6.6.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 66,
        "build_label": "traceability-gate-v66",
        **common,
        "trace_id": trace_id,
        "gate_id": gate_id,
        "traceability": {"status": "PASS", "evidence": "traceability", "trace_id": trace_id, **common, "traceable": True},
        "gate": {"status": "PASS", "evidence": "gate", "gate_id": gate_id, "trace_id": trace_id, **common, "passed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashTraceabilityGateV66Test(unittest.TestCase):
    def test_accepts_traceable_passed_gate(self):
        self.assertEqual(validate_v66(record()), [])

    def test_requires_trace_and_gate_hash_binding(self):
        item = record()
        item["traceability"]["source_hash"] = "e" * 64
        item["gate"]["trace_id"] = "trace-other"
        errors = validate_v66(item)
        self.assertTrue(any("traceability.source_hash must match" in error for error in errors))
        self.assertTrue(any("gate.trace_id must match" in error for error in errors))

    def test_rejects_schema_or_gate_flags(self):
        item = record()
        item["schema_version"] = 65
        item["traceability"]["traceable"] = False
        item["gate"]["passed"] = False
        errors = validate_v66(item)
        self.assertTrue(any("schema_version must be 66" in error for error in errors))
        self.assertTrue(any("traceable must be true" in error for error in errors))
        self.assertTrue(any("passed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "arm64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v66(item)))


if __name__ == "__main__":
    unittest.main()
