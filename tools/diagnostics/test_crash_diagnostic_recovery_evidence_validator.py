import copy
import unittest

from tools.diagnostics.crash_diagnostic_recovery_evidence_validator import validate_evidence


def evidence() -> dict:
    vocabulary = [
        "attempt_count", "damage_ratio", "duration_physics_seconds", "entity_count",
        "error_code", "frame_delta_seconds", "input_device_code", "peer_count",
        "recovered", "speed_metres_per_second",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "crash_diagnostic_recovery",
        "evidence_mode": "detached_contract_fixture",
        "diagnostic_policy": "session_diagnostic_record_v1",
        "recovery_policy": "crash_recovery_coordinator_v1",
        "source_revision": "working-tree-diagnostics-review",
        "fixture_description": "one unfinished marker followed by typed recovery and clean close",
        "native_claims": False,
        "uses_os_crash_hook": False,
        "uploader_invoked": False,
        "stack_trace_retained": False,
        "initial_marker": {
            "state": "running", "session_id": 41, "startup_generation": 1,
            "unclean_start_count": 0, "last_physics_tick": 3,
            "last_elapsed_physics_seconds": 0.05,
        },
        "recovery_marker": {
            "state": "running", "session_id": 42, "startup_generation": 2,
            "unclean_start_count": 1, "last_physics_tick": 0,
            "last_elapsed_physics_seconds": 0.0,
        },
        "recovery_event": {
            "event_code": "crash_detected", "severity": "error", "session_id": 42,
            "physics_tick": 1, "session_elapsed_physics_seconds": 0.01,
            "fields": {"attempt_count": 1, "recovered": True},
            "redacted_field_count": 0,
        },
        "clean_marker": {
            "state": "clean", "session_id": 42, "startup_generation": 2,
            "unclean_start_count": 0, "last_physics_tick": 4,
            "last_elapsed_physics_seconds": 0.1,
        },
        "retention": {
            "capacity": 64, "observed_event_count": 1,
            "dropped_event_count": 0, "next_sequence": 2,
        },
        "privacy": {
            "secret_fields_redacted": True,
            "private_text_rejected": True,
            "paths_rejected": True,
            "arbitrary_fields_rejected": True,
            "retained_values_are_primitive": True,
            "retained_field_vocabulary": vocabulary,
        },
        "atomic_persistence": {
            "namespace": "session_diagnostics",
            "injected_store": True,
            "generation_fenced": True,
            "failed_write_preserves_existing": True,
            "merges_unrelated_namespaces": False,
        },
        "authority_exclusions": {
            "os_crash_capture": False,
            "filesystem_path_access": False,
            "stack_trace_capture": False,
            "uploader": False,
            "settings_application": False,
            "gameplay_recovery": False,
        },
    }


class CrashDiagnosticRecoveryEvidenceTests(unittest.TestCase):
    def test_accepts_bounded_recovery_and_privacy_fixture(self):
        self.assertEqual(validate_evidence(evidence()), [])

    def test_rejects_generation_or_lifecycle_regression(self):
        report = evidence()
        report["recovery_marker"]["startup_generation"] = 1
        report["clean_marker"]["state"] = "running"
        errors = validate_evidence(report)
        self.assertTrue(any("startup_generation must advance" in error for error in errors))
        self.assertTrue(any("clean_marker.state" in error for error in errors))

    def test_rejects_event_identity_and_attempt_count_drift(self):
        report = evidence()
        report["recovery_event"]["session_id"] = 41
        report["recovery_event"]["fields"]["attempt_count"] = 2
        errors = validate_evidence(report)
        self.assertTrue(any("session_id must match" in error for error in errors))
        self.assertTrue(any("attempt_count must match" in error for error in errors))

    def test_rejects_unbounded_or_private_evidence_claims(self):
        report = evidence()
        report["retention"]["observed_event_count"] = 65
        report["privacy"]["paths_rejected"] = False
        report["authority_exclusions"]["uploader"] = True
        errors = validate_evidence(report)
        self.assertTrue(any("exceeds capacity" in error for error in errors))
        self.assertTrue(any("privacy.paths_rejected" in error for error in errors))
        self.assertTrue(any("authority_exclusions.uploader" in error for error in errors))

    def test_rejects_native_os_capture_or_wrong_namespace_persistence(self):
        report = copy.deepcopy(evidence())
        report["native_claims"] = True
        report["uses_os_crash_hook"] = True
        report["atomic_persistence"]["namespace"] = "other"
        errors = validate_evidence(report)
        self.assertTrue(any("native_claims must be false" in error for error in errors))
        self.assertTrue(any("uses_os_crash_hook must be false" in error for error in errors))
        self.assertTrue(any("namespace must be session_diagnostics" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
