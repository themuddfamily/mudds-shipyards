"""Focused tests for v1038 audio cleanup evidence/state summaries."""
import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_state_v1038_validator as validator # noqa: E402
def summary()->dict:
    ed,sd="a"*64,"b"*64
    def record(rid,ev):return {"record_id":rid,"evidence_digest":ed,"state_digest":sd,"evidence_id":"evidence-v1038","state_model":"cleanup-state-v1","state":"closed","evidence":ev,"state_pass":True}
    return {"schema":"audio_cleanup_evidence_state_v1038","revision":"a"*40,"owner":"audio-evidence-owner","summary_id":"cleanup-evidence-state-v1038","evidence_bundle":"artifacts/audio/evidence-state-v1038.json","evidence_id":"evidence-v1038","state_model":"cleanup-state-v1","state":"closed","claim":"AUTOMATED_EVIDENCE_STATE_ONLY","detached_status":"NOT_RUN","native_status":"NOT_RUN","hardware_status":"NOT_RUN","human_review_status":"NOT_RUN","boundary_note":"Automated evidence does not establish detached, native, hardware, or human-review outcomes.","evidence_digest":ed,"state_digest":sd,"record_ids":["record-a","record-b"],"records":[record("record-a","artifacts/audio/a.json"),record("record-b","artifacts/audio/b.json")],"evidence_state_pass":True}
class AudioCleanupEvidenceStateV1038Tests(unittest.TestCase):
    def test_valid_evidence_state_summary(self):self.assertEqual(validator.validate_summary(summary()),[])
    def test_all_boundary_statuses_require_not_run(self):
        v=copy.deepcopy(summary())
        for k in validator.BOUNDARY_FIELDS:v[k]="PASS"
        e=validator.validate_summary(v)
        for k in validator.BOUNDARY_FIELDS:self.assertIn(f"{k} must be NOT_RUN",e)
    def test_state_binding_is_required(self):
        v=copy.deepcopy(summary());v["records"][1]["state"]="ready"
        self.assertIn("records[1].state must match summary",validator.validate_summary(v))
    def test_pass_flags_are_required(self):
        v=copy.deepcopy(summary());v["evidence_state_pass"],v["records"][0]["state_pass"]=False,False;e=validator.validate_summary(v)
        self.assertIn("evidence_state_pass must be true",e);self.assertIn("records[0].state_pass must be true",e)
if __name__=="__main__":unittest.main()
