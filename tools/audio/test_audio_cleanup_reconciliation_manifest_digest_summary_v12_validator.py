"""Focused tests for v12 cleanup reconciliation manifest digests."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_reconciliation_manifest_digest_summary_v12_validator as validator  # noqa: E402


def summary() -> dict:
    paths = ["artifacts/audio/a.json", "artifacts/audio/b.json"]
    digest = "a" * 64
    manifests = [{"path": path, "sha256": ("b" if index == 0 else "c") * 64, "canonicalization": "json-sorted-v1", "evidence": f"artifacts/audio/{index}.json"} for index, path in enumerate(paths)]
    records = [{"record_id": "record-1", "reconciliation_digest": digest, "manifest_paths": paths, "reconciled": True, "evidence": "artifacts/audio/rec-1.json"}, {"record_id": "record-2", "reconciliation_digest": digest, "manifest_paths": paths, "reconciled": True, "evidence": "artifacts/audio/rec-2.json"}]
    return {"schema": "audio_cleanup_reconciliation_manifest_digest_summary_v12", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-reconcile-v12", "evidence_bundle": "artifacts/audio/reconcile-v12.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_RECONCILIATION_MANIFEST_ONLY", "boundary_note": "Manifest reconciliation does not establish native audibility.", "reconciliation_digest": digest, "manifests": manifests, "records": records, "reconciliation_pass": True}


class AudioCleanupReconciliationManifestV12Tests(unittest.TestCase):
    def test_valid_manifest_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_manifest_order_and_duplicates_are_rejected(self):
        value = copy.deepcopy(summary())
        value["manifests"] = [value["manifests"][1], value["manifests"][0], value["manifests"][0]]
        errors = validator.validate_summary(value)
        self.assertIn("manifests paths must be lexicographically ordered", errors)
        self.assertIn("manifests paths must be unique", errors)

    def test_record_digest_and_roster_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "d" * 64
        value["records"][1]["manifest_paths"] = ["artifacts/audio/other.json"]
        errors = validator.validate_summary(value)
        self.assertIn("records reconciliation_digest values must agree", errors)
        self.assertIn("records[1].manifest_paths must match ordered manifest paths", errors)

    def test_canonicalization_and_reconciled_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["manifests"][0]["canonicalization"] = "other"
        value["records"][0]["reconciled"] = False
        errors = validator.validate_summary(value)
        self.assertIn("manifests[0].canonicalization must match summary canonicalization", errors)
        self.assertIn("records[0].reconciled must be true", errors)


if __name__ == "__main__":
    unittest.main()
