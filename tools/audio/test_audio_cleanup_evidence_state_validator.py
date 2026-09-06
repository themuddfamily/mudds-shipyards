"""Shared contract tests for the equivalent v383–v1057 schema family."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_state_validator as validator

def summary(version: int = 383) -> dict:
    evidence_digest, state_digest = "a" * 64, "b" * 64
    binding = {
        "evidence_digest": evidence_digest,
        "state_digest": state_digest,
        "evidence_id": f"evidence-v{version}",
        "state_model": "cleanup-state-v1",
        "state": "closed",
    }
    return {
        **binding,
        "schema": f"audio_cleanup_evidence_state_v{version}",
        "revision": "a" * 40,
        "owner": "audio-evidence-owner",
        "summary_id": f"cleanup-evidence-state-v{version}",
        "evidence_bundle": f"artifacts/audio/evidence-state-v{version}.json",
        "claim": "AUTOMATED_EVIDENCE_STATE_ONLY",
        **{key: "NOT_RUN" for key in validator.BOUNDARY_FIELDS},
        "boundary_note": "Automated evidence does not establish detached, native, hardware, or human-review outcomes.",
        "record_ids": ["record-a", "record-b"],
        "records": [
            {**binding, "record_id": record_id, "evidence": f"artifacts/audio/{record_id}.json", "state_pass": True}
            for record_id in ("record-a", "record-b")
        ],
        "evidence_state_pass": True,
    }


class AudioCleanupEvidenceStateTests(unittest.TestCase):
    def test_every_supported_schema_and_original_regressions(self):
        for version in validator.SUPPORTED_VERSIONS:
            with self.subTest(version=version):
                value = summary(version)
                self.assertEqual(validator.validate_summary(value), [])
                self.assertEqual(validator.validate_summary(value, schema_version=version), [])
                for key in validator.BOUNDARY_FIELDS:
                    value[key] = "PASS"
                value["records"][1]["state"] = "ready"
                value["evidence_state_pass"] = False
                value["records"][0]["state_pass"] = False
                self.assertEqual(validator.validate_summary(value), [
                    *(f"{key} must be NOT_RUN" for key in validator.BOUNDARY_FIELDS),
                    "records[0].state_pass must be true",
                    "records[1].state must match summary",
                    "evidence_state_pass must be true",
                ])

    def test_digest_identity_order_and_required_fields(self):
        cases = [
            ("owner", "", "owner is required"),
            ("claim", "PASS", "claim must be AUTOMATED_EVIDENCE_STATE_ONLY"),
            ("boundary_note", " ", "boundary_note is required"),
            ("state", "invalid", "state must be open, ready, or closed"),
            ("record_ids", ["record-b", "record-a"], "record_ids must be ordered, unique, and non-empty"),
            ("record_ids", ["record-a"], "record_ids must exactly match records"),
            ("evidence_digest", "A" * 64, "evidence_digest must be a lowercase 64-character digest"),
            ("records", [], "records must be a non-empty array"),
            ("records", [None], "records[0] must be an object"),
        ]
        for key, replacement, expected in cases:
            with self.subTest(key=key, replacement=replacement):
                value = summary()
                value[key] = replacement
                self.assertIn(expected, validator.validate_summary(value))
        for key, replacement, expected in [
            ("record_id", "", "record_id is required"),
            ("record_id", "record-b", "record_id is duplicated"),
            ("state_digest", "c" * 64, "state_digest must match summary"),
            ("evidence_id", "other", "evidence_id must match summary"),
            ("state_model", "other", "state_model must match summary"),
            ("evidence", "", "evidence is required"),
        ]:
            with self.subTest(record_key=key):
                value = summary()
                value["records"][0][key] = replacement
                self.assertTrue(any(expected in error for error in validator.validate_summary(value)))

    def test_schema_selection_and_pinning(self):
        self.assertEqual(validator.validate_summary(None), ["summary must be an object"])
        for schema in (None, [], "audio_cleanup_evidence_state_v382", "audio_cleanup_evidence_state_v1058"):
            value = summary()
            value["schema"] = schema
            self.assertTrue(validator.validate_summary(value))
        self.assertEqual(validator.validate_summary(summary(383), schema_version=1057),
                         ["schema must be audio_cleanup_evidence_state_v1057"])
        with self.assertRaises(ValueError):
            validator.validate_summary(summary(), schema_version=382)

    def test_cli_preserves_versioned_banners_and_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary.json"
            for version in (383, 999, 1057):
                for invalid in (False, True):
                    value = summary(version)
                    if invalid:
                        value["native_status"] = "PASS"
                    path.write_text(json.dumps(value), encoding="utf-8")
                    output = io.StringIO()
                    with contextlib.redirect_stdout(output):
                        status = validator.main([str(path), "--schema-version", str(version)])
                    self.assertEqual(status, int(invalid))
                    suffix = "INVALID" if invalid else "VALID"
                    self.assertEqual(output.getvalue().splitlines()[0],
                                     f"AUDIO_CLEANUP_EVIDENCE_STATE_V{version}_{suffix}")
            path.write_text(json.dumps(summary(383)), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(validator.main([str(path)]), 0)
                self.assertEqual(validator.main([str(path), "--schema-version", "1057"]), 1)


if __name__ == "__main__":
    unittest.main()
