import unittest

from tools.package.source_artifact_label_validator import validate_labels


def labels():
    commit = "a" * 40
    label = "candidate-42"
    item = lambda evidence: {"status": "PASS", "evidence": evidence, "candidate_label": label, "source_commit": commit}
    return {
        "schema_version": 1,
        "candidate_label": label,
        "source_commit": commit,
        "source": item("source manifest"),
        "artifact": item("artifact manifest"),
        "package": item("package record"),
        "pck": item("PCK inventory"),
        "consistency_audit": {"status": "PASS", "evidence": "cross-label audit", "labels_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceArtifactLabelValidatorTest(unittest.TestCase):
    def test_accepts_consistent_source_and_artifact_labels(self):
        self.assertEqual(validate_labels(labels()), [])

    def test_rejects_candidate_label_drift(self):
        item = labels()
        item["artifact"]["candidate_label"] = "other"
        self.assertTrue(any("artifact.candidate_label must match" in error for error in validate_labels(item)))

    def test_rejects_source_commit_drift(self):
        item = labels()
        item["pck"]["source_commit"] = "b" * 40
        self.assertTrue(any("pck.source_commit must match" in error for error in validate_labels(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = labels()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_labels(item)))


if __name__ == "__main__":
    unittest.main()
