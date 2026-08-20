import copy
import unittest

from tools.review.p0_p1_regression_evidence_ledger_validator import validate_ledger


SHA_A = "a" * 64
SHA_B = "b" * 64


def _evidence(kind: str = "log", name: str = "witness.log") -> dict:
    return {"kind": kind, "path": f"evidence/{name}", "sha256": SHA_A}


def _item(status: str = "CLOSED", severity: str = "P1") -> dict:
    return {
        "id": "BOARDING-001",
        "severity": severity,
        "status": status,
        "title": "boarding prompt absent from intended approach",
        "reporter": "qa",
        "reported_at": "2026-08-20",
        "owner": "gameplay",
        "disposition": "fixed and independently verified",
        "status_history": ["CANDIDATE", "NEW", "REPRODUCED", "FIXING", "VERIFYING", status],
        "source_artifacts": {
            "first_source_hash": SHA_A,
            "last_source_hash": SHA_B,
            "first_artifact_hash": SHA_A,
            "last_artifact_hash": SHA_B,
        },
        "environment": {
            "os": "Linux WSL2", "cpu": "fixture CPU", "gpu": "llvmpipe",
            "ram": "16 GB", "driver": "fixture driver", "audio": "Dummy",
            "input": "keyboard/mouse", "resolution": "1920x1080", "profile": "clean",
            "user_data_state": "clean",
        },
        "reproduction": {
            "steps": ["walk to the approach", "request interaction"],
            "expected": "boarding prompt appears",
            "actual": "prompt is absent",
            "loop_beat": "boarding",
            "failure_frequency": {"failures": 10, "attempts": 10, "configurations": ["linux-clean", "linux-retained"]},
            "evidence": [_evidence()],
        },
        "linked_regression": {"path": "tests/boarding_accessibility_test.gd", "name": "intended approach prompt"},
        "closure": {
            "regression_test": "tests/boarding_accessibility_test.gd",
            "before_failing": True,
            "after_green": True,
            "focused_matrix": {"status": "passed", "evidence": "focused-log"},
            "full_matrix": {"status": "passed", "evidence": "matrix-record"},
            "current_package_rerun": {"status": "passed", "evidence": "package-run"},
            "independent_verification": {"status": "passed", "evidence": "review-record"},
        },
    }


def _ledger() -> dict:
    open_item = _item("REPRODUCED", "P0")
    open_item["id"] = "SAVE-001"
    open_item["status_history"] = ["CANDIDATE", "NEW", "REPRODUCED"]
    return {
        "schema": "p0_p1_regression_evidence_ledger_v1",
        "ledger_revision": "review-2026-08-20",
        "source_revision": "working-tree-source",
        "full_matrix_status": "not_run",
        "items": [_item(), open_item],
    }


class P0P1RegressionLedgerTests(unittest.TestCase):
    def test_closed_and_reproduced_p0_p1_records_are_coherent(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_closed_record_requires_all_four_closure_gates(self):
        value = _ledger()
        del value["items"][0]["closure"]["full_matrix"]
        value["items"][0]["closure"]["after_green"] = False
        errors = validate_ledger(value)
        self.assertTrue(any("full_matrix must be an object" in error for error in errors))
        self.assertTrue(any("after_green must be true" in error for error in errors))

    def test_status_history_and_p0_p1_scope_fail_closed(self):
        value = _ledger()
        value["items"][0]["status_history"] = ["CANDIDATE", "FIXING", "NEW", "CLOSED"]
        value["items"][1]["severity"] = "P2"
        errors = validate_ledger(value)
        self.assertTrue(any("cannot move backward" in error for error in errors))
        self.assertTrue(any("severity must be P0 or P1" in error for error in errors))

    def test_not_reproduced_requires_ten_attempts_and_two_configurations(self):
        value = _ledger()
        item = _item("NOT_REPRODUCED")
        item["status_history"] = ["CANDIDATE", "NEW", "NOT_REPRODUCED"]
        item["reproduction"]["failure_frequency"] = {"failures": 0, "attempts": 3, "configurations": ["one"]}
        value["items"] = [item]
        errors = validate_ledger(value)
        self.assertTrue(any("at least ten attempts" in error for error in errors))
        self.assertTrue(any("two documented configurations" in error for error in errors))

    def test_bad_hash_evidence_and_duplicate_ids_are_rejected(self):
        value = _ledger()
        value["items"][0]["source_artifacts"]["last_source_hash"] = "not-a-hash"
        value["items"].append(copy.deepcopy(value["items"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("last_source_hash" in error for error in errors))
        self.assertTrue(any("items.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
