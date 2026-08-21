"""Focused tests for v196 audio cleanup evidence/state summaries."""
import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_state_v196_validator as validator # noqa: E402
def summary()->dict:
    d,t="a"*64,"b"*64
    def r(i,a):return {"record_id":i,"evidence_digest":d,"state_digest":t,"evidence_id":"evidence-v196","state_model":"cleanup-state-v1","state":"closed","evidence":a,"state_pass":True}
    return {"schema":"audio_cleanup_evidence_state_v196","revision":"a"*40,"owner":"audio-evidence-owner","summary_id":"cleanup-evidence-state-v196","evidence_bundle":"artifacts/audio/evidence-state-v196.json","evidence_id":"evidence-v196","state_model":"cleanup-state-v1","state":"closed","claim":"AUTOMATED_EVIDENCE_STATE_ONLY","native_status":"NOT_RUN","stale_callback_status":"NOT_RUN","boundary_note":"Evidence state does not establish native audibility.","evidence_digest":d,"state_digest":t,"record_ids":["record-a","record-b"],"records":[r("record-a","artifacts/audio/a.json"),r("record-b","artifacts/audio/b.json")],"evidence_state_pass":True}
class AudioCleanupEvidenceStateV196Tests(unittest.TestCase):
    def test_valid_evidence_state_summary(self):self.assertEqual(validator.validate_summary(summary()),[])
    def test_not_run_semantics_are_required(self):
        v=copy.deepcopy(summary());v["native_status"]=v["stale_callback_status"]="PASS";e=validator.validate_summary(v);self.assertIn("native_status must be NOT_RUN",e);self.assertIn("stale_callback_status must be NOT_RUN",e)
    def test_state_binding_is_required(self):
        v=copy.deepcopy(summary());v["records"][1]["state"]="ready";self.assertIn("records[1].state must match summary",validator.validate_summary(v))
    def test_pass_flags_are_required(self):
        v=copy.deepcopy(summary());v["evidence_state_pass"]=False;v["records"][0]["state_pass"]=False;e=validator.validate_summary(v);self.assertIn("evidence_state_pass must be true",e);self.assertIn("records[0].state_pass must be true",e)
if __name__=="__main__":unittest.main()
