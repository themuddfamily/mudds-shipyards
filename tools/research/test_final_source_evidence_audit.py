import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.research.final_source_evidence_audit import validate, _sha

ROOT = Path(__file__).parents[2]
MANIFEST = ROOT / "docs/research/final_source_evidence_audit.json"

class FinalSourceEvidenceAuditTest(unittest.TestCase):
    def test_repository_manifest_is_ready(self):
        self.assertEqual(validate(MANIFEST), [])

    def test_authenticated_claim_and_source_drift_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ledger = json.loads((ROOT / "docs/research/source_ledger.json").read_text())
            ledger["sources"][0]["status"] = "authenticated"
            ledger_path = root / "source_ledger.json"
            ledger_path.write_text(json.dumps(ledger))
            manifest = json.loads(MANIFEST.read_text())
            manifest["ledger"]["path"] = "source_ledger.json"
            manifest["ledger"]["sha256"] = _sha(ledger_path)
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            self.assertTrue(any("authenticated source claim" in error for error in validate(manifest_path)))

if __name__ == "__main__":
    unittest.main()
