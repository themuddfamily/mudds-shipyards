import unittest

from tools.package.matrix_evidence_rollup_validator import validate_matrix


def matrix():
    source = "a" * 40
    digest = "b" * 64
    return {
        "schema_version": 1,
        "build_label": "candidate-matrix-42",
        "source_commit": source,
        "artifact_sha256": digest,
        "rows": [
            {"name": "linux-dummy-startup", "status": "PASS", "evidence": "300-frame log", "source_commit": source, "artifact_sha256": digest, "assertions": 12},
            {"name": "windows-native", "status": "NOT_RUN", "evidence": None, "source_commit": source, "artifact_sha256": digest, "assertions": None},
        ],
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class MatrixEvidenceRollupValidatorTest(unittest.TestCase):
    def test_accepts_rows_bound_to_one_artifact(self):
        self.assertEqual(validate_matrix(matrix()), [])

    def test_rejects_row_identity_drift(self):
        item = matrix()
        item["rows"][0]["artifact_sha256"] = "c" * 64
        self.assertTrue(any("must match matrix.artifact_sha256" in error for error in validate_matrix(item)))

    def test_rejects_duplicate_rows_and_missing_pass_assertions(self):
        item = matrix()
        item["rows"][1]["name"] = "linux-dummy-startup"
        item["rows"][0]["assertions"] = None
        errors = validate_matrix(item)
        self.assertTrue(any("name must be unique" in error for error in errors))
        self.assertTrue(any("assertions must be an integer" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = matrix()
        item["native_execution"]["hardware"] = "RTX"
        self.assertTrue(any("hardware must be null" in error for error in validate_matrix(item)))


if __name__ == "__main__":
    unittest.main()
